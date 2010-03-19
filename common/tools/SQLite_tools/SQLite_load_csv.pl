#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# SQLite CSV loader
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "SQLite_load_csv" is an experimental system.
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

my $versionid = "SQLite CSV loader Version: $version";

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
foreach my $pn ("MMisc", "MtSQLite") {
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

# Default values for variables
my $dbfile  = "";
my $csvfile = "";
my @tmpc = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                             c    h             v      #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'columnsname=s'=> \@tmpc,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if (($opt{'help'}) || (scalar @ARGV == 0));
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
MMisc::error_quit("Missing one of dbfile/csvfile/tablename\n\n$usage") 
  if (scalar @ARGV < 3);

my ($dbfile, $csvfile, $tablename) = @ARGV;

my @colsname = ();
for (my $i = 0; $i < scalar @tmpc; $i++) {
  push @colsname, split(m%\,%, $tmpc[$i]);
}

##
my $err = MMisc::check_file_w($dbfile);
MMisc::error_quit("Problem with DB file ($dbfile): $err")
  if (! MMisc::is_blank($err));

##
my $err = MMisc::check_file_r($csvfile);
MMisc::error_quit("Problem with CSV file ($csvfile): $err")
  if (! MMisc::is_blank($err));

##
my ($t) = MtSQLite::fix_entries($tablename);
MMisc::error_quit("Asked tablename ($tablename) does not comply with name requiremetnts (should have been: \'$t\')")
  if ($t ne $tablename);

my @tmpc = MtSQLite::fix_entries(@colsname);
my @bad = ();
for (my $i = 0; $i < scalar @colsname; $i++) {
  push(@bad, $colsname[$i])
    if ($tmpc[$i] ne $colsname[$i]);
}
MMisc::error_quit("The following requested column names are improperly formatted: " . join(", ", @bad))
  if (scalar @bad > 0);

##
my ($err, $dbh) = MtSQLite::get_dbh($dbfile);
MMisc::error_quit("Problem using DB ($dbfile): $err")
  if (! MMisc::is_blank($err));

my ($err, $inserted) = MtSQLite::insertCSV($dbh, $csvfile, $tablename, @colsname);
MMisc::error_quit("Problem inserting CSV file ($csvfile) into DB ($dbfile)'s table ($tablename): $err")
  if (! MMisc::is_blank($err));

print "\nInserted $inserted records\n";

MtSQLite::release_dbh($dbh);

MMisc::ok_quit("Done");

####################


sub set_usage {  
  my $tmp=<<EOF
$versionid

$0 [--help | --version] [--columnsname col1,col2[,...]] dbfile csvfile tablename

Will load a given csvfile into the SQLite dbfile's table called tablename.

NOTE: dbfile must already exist with a properly created table named tablename in itNOTE: columns name will ne copied from the first row of cvsfile

Where:
  --help     This help message
  --version  Version information
  --columnsname  Discard the information provided in the first row of csvfile and force the column names

EOF
;

  return($tmp);
}
