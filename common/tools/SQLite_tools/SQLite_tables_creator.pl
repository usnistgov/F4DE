#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# SQLite Tables Creator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "SQLite Tables Creator" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "SQLite Tables Creator Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "CSVHelper", "MtSQLite") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Options processing

my $usage = &set_usage();
my $tool = "./SQLite_load_csv.pl";
my $loadcsv = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:            L                     h   l         v      #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'loadCSV'    =>   \$loadcsv,
   'LoadCSV=s'  =>   \$tool,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

if ($loadcsv) {
  my $err = MMisc::check_file_x($tool);
  MMisc::error_quit("Problem with tool ($tool): $err")
    if (! MMisc::is_blank($err));
}

my ($dbfile, $conffile) = @ARGV;

my $err = MMisc::check_file_r($conffile);
MMisc::error_quit("Problem with configfile ($conffile): $err")
  if (! MMisc::is_blank($err));

my $dbh = undef;

my %colinfo = ();
my @ok_keys = ("newtable", "csvfile", "column"); # order is important
my ($rtablenames, $rcsvfiles) = &load_info($conffile);
MMisc::error_quit("Mismatch in tablename/csvfile lists")
  if (scalar @$rtablenames != scalar @$rcsvfiles);

MMisc::error_quit("No DB/table created, aborting")
  if (! defined $dbh);

MtSQLite::release_dbh($dbh);

if ($loadcsv) {
  for (my $i = 0; $i < scalar @$rtablenames; $i++) {
    my $tablename = $$rtablenames[$i];
    my $csvfile   = $$rcsvfiles[$i];
    my @cinfo = @{$colinfo{$tablename}};
    my $cmd = "$tool $dbfile $csvfile $tablename";
    if (scalar @cinfo > 0) {
      $cmd .= " --columnsname " . join(",", @cinfo);
    }
    my ($retcode, $stdout, $stderr) = MMisc::do_system_call($cmd);
    MMisc::error_quit("[CMD: $cmd]\n** STDOUT:\n$stdout\n\n\n** STDERR:\n$stderr\n")
      if ($retcode != 0);

#    print "[CMD: $cmd]\n** STDOUT:\n$stdout\n\n\n** STDERR:\n$stderr\n";
  }
}

MMisc::ok_quit("Done");

####################

sub load_info {
  my ($file) = @_;

  open FILE, "<$file"
    or MMisc::error_quit("Problem loading file ($file): $!");

  my $tcc = ""; # Table creation command
  my ($tn, $ccf) = ("", "");
  my @tnl = ();
  my %tnh = ();
  my $hmk = 0;
  while (my $line = <FILE>) {
    next if (MMisc::is_blank($line));
    next if ($line =~ m%^\#%);
    
    my ($err, $key, $val) = &split_line($line);
    MMisc::error_quit($err) if (! MMisc::is_blank($err));

    if ($key eq $ok_keys[0]) { # newtable
      # first, process the previous entry if possible
      &create_table($tcc, $tn, $hmk);
      # Empty previous values
      ($tn, $tcc) = ("", "");

      my $ctn = MMisc::clean_begend_spaces($val);
      ($tn) = MtSQLite::fix_entries($ctn);
#      print "[TN: $tn]\n";
      next;
    }

    if ($key eq $ok_keys[1]) { # csvfile
      my $ccf = MMisc::clean_begend_spaces($val);
      my $err = MMisc::check_file_r($ccf);
      MMisc::error_quit("Problem with \'" . $ok_keys[1] . "\' ($ccf): $err")
          if (! MMisc::is_blank($err));
      push @tnl, $tn;
      $tnh{$tn} = $ccf;
#      print "[CSV: $ccf]\n";
      next;
    }

    if ($key =~ m%$ok_keys[2](\*?)%) { # columns
      my $mk = ($1 eq "*") ? 1 : 0;

      my ($cn, $ucn, $type) = ("", "", "");
 
     if ($val =~ s%\;(\w+)$%%) {
        $type = MMisc::clean_begend_spaces($1);
      } else {
        $type = "BLOB";
      }

      $ucn = MMisc::clean_begend_spaces($1)
        if ($val =~ s%\=(.+)$%%);

      my $cn = MMisc::clean_begend_spaces($val);
      $ucn = $cn if (MMisc::is_blank($ucn));

      my $tccadd = "$ucn $type" . (($mk) ? " PRIMARY KEY" : "");
      $tcc .= ((MMisc::is_blank($tcc)) ? "" : ", ") . $tccadd;

      push @{$colinfo{$tn}}, $ucn;
#      print "[TCC: $tccadd]\n";
      $hmk += $mk;
      next;
    }

    MMisc::error_quit("Unknown command [$line]");
  }
  &create_table($tcc, $tn, $hmk);

  my @cfl = ();
  for (my $i = 0; $i < scalar @tnl; $i++) { push @cfl, $tnh{$tnl[$i]}; }

  return(\@tnl, \@cfl);
}

#####

sub split_line {
  my $line = $_[0];

  return("", $1, $2)
    if ($line =~ m%^([^\:]+)\:(.+)$%);

  return("Problem extracting line content [$line]");
}

##########

sub create_table {
  my ($tcc, $tn, $hmk) = @_;

  return() if (MMisc::is_blank($tn));

  if (! defined $dbh) {
    (my $err, $dbh) = MtSQLite::get_dbh($dbfile);
    MMisc::error_quit("Problem with DB ($dbfile): $err")
      if (! MMisc::is_blank($err));
  }

  my $cmd = "DROP TABLE IF EXISTS $tn";
  my $err = MtSQLite::doOneCommand($dbh, $cmd);
  MMisc::error_quit("Problem with command [$cmd]: $err")
    if (! MMisc::is_blank($err));

  $cmd = "CREATE TABLE $tn (";
  $cmd .= " __autoinckey INTEGER PRIMARY KEY, " if ($hmk == 0);
  $cmd .= $tcc;
  $cmd .= ")";
  
#  print "[$cmd]\n";
  my $err = MtSQLite::doOneCommand($dbh, $cmd);
  MMisc::error_quit("Problem with command [$cmd]: $err")
    if (! MMisc::is_blank($err));
}

####################

sub set_usage {  
  my $tmp=<<EOF
$versionid

$0 [--help | --version] [--loadCSV [--LoadCSV toollocation]] dbfile configfile

Will create SQLite tables within dbfile based on the information provided in configfile (generated by SQLite_cfg_helper).

WARNING: if a table listed in the configuration file already exists, it will be destroyed from dbfile

Where:
  --help     This help message
  --version  Version information
  --loadCSV  In addition to creating the table, insert the entire CSV file (specified in configfile (into the table)
  --LoadCSV  Location of the 'SQLite_load_csv' tool

EOF
;

  return($tmp);
}
