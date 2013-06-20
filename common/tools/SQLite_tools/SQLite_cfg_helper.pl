#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# SQLite CSV Config Helper
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "SQLite_cfg_helper" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
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

my $versionid = "SQLite CSV Config Helper Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../../common/lib");
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

my $qcd = 500;
my $usage = &set_usage();
my $xcolinfo = undef;
my $xtabinfo = undef;
my $forcedtn = "";
my $primkey = "";
my $quickConfig = undef;
my $nullmode = 0;
my @colConstr = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   C          N     T        c    h       pq  t v      #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'columninfo:s' => \$xcolinfo,
   'tableinfo:s'  => \$xtabinfo,
   'Tablename=s'  => \$forcedtn,
   'primaryKey=s' => \$primkey,
   'quickConfig:i'   => \$quickConfig,
   'NULLfields'      => \$nullmode,
   'ColumnConstraint=s' => \@colConstr,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No arguments given\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("When \'Tablename\' is used, only one CSV file can be specified")
  if ((! MMisc::is_blank($forcedtn)) && (scalar @ARGV > 1));

$quickConfig = $qcd if ((defined $quickConfig) && ($quickConfig == 0));

my %colC = ();
foreach my $cc (@colConstr) {
  my ($cn, $cstr) = ("", "");
  if ($cc =~ s%^([^\:]+?)\:%%) {
    $cn = $1;
    $cstr = $cc;
  } else {
    MMisc::error_quit("Problem obtaining \'columnname:constraint\' from \'--ColumnConstraint\'");
  }
  MMisc::error_quit("Empty \'columnname\' for \'--ColumnConstraint\'")
    if (MMisc::is_blank($cn));
  MMisc::error_quit("Empty \'constraint\' for \'--ColumnConstraint\'")
    if (MMisc::is_blank($cstr));
  $colC{$cn} = $cstr;
}

my %tns = ();
my %cnl = ();
my %fcm = ();
for (my $inc = 0; $inc < scalar @ARGV; $inc++) {
  &load_csv($inc + 1, $ARGV[$inc]);
}
&print_xcolinfo();
&print_xtabinfo();

MMisc::ok_quit("## Done");

####################

sub load_csv {
  my ($nbr, $xcsvfile) = @_;

  my ($csvfile, $utn, $rest) = ("", "", "");
  if ($xcsvfile =~ m%^([^\:^\%]+?)(\:[^\%]+?)?(\%.+)?$%) {
    ($csvfile, $utn, $rest) = ($1, $2, $3);
    $utn =~ s%^\:%%;
    $rest =~ s%^\%%%;
  } else {
    MMisc::error_quit("Could not process \'csvfile[:tablename][\%columnname:constraint[...]]\' entry");
  }

  my %sp_colC = ();
  my @cCstr = split(m%\%%, $rest);
  foreach my $cc (@cCstr) {
    my ($cn, $cstr) = ("", "");
    if ($cc =~ s%^([^\:]+?)\:%%) {
      $cn = $1;
      $cstr = $cc;
    } else {
      MMisc::error_quit("While extracting \'csvfile[:tablename][\%columnname:constraint[...]]\' entry: problem obtaining \'columnname:constraint\' from leftover string [$cc]");
    }
    MMisc::error_quit("While extracting \'csvfile[:tablename][\%columnname:constraint[...]]\' entry: Empty \'columnname\'")
      if (MMisc::is_blank($cn));
    MMisc::error_quit("While extracting \'csvfile[:tablename][\%columnname:constraint[...]]\' entry: Empty \'constraint\'")
      if (MMisc::is_blank($cstr));
    $sp_colC{$cn} = $cstr;
  }
  
  my @ok_types = ("INT", "REAL", "TEXT"); # in order
  my $csvh = new CSVHelper();
  MMisc::error_quit("While processing file [$csvfile], problem with CSV handler: " . $csvh->get_errormsg())
      if ($csvh->error());
  open CSV, "<$csvfile"
    or MMisc::error_quit("Problem with CSV file ($csvfile): $!");
  my $line = <CSV>;
  my @csvheader = $csvh->csvline2array($line);
  MMisc::error_quit("While processing file [$csvfile], problem with CSV header extraction: " . $csvh->get_errormsg())
      if ($csvh->error());
  MMisc::error_quit("No header in CSV ?")
      if (scalar @csvheader == 0);
  my @tmpa = MMisc::make_array_of_unique_values(\@csvheader);
  MMisc::error_quit("While processing file [$csvfile]: Header has multiple entries with the same name ?")
      if (scalar @tmpa != scalar @csvheader);
  $csvh->set_number_of_columns(scalar @csvheader);
#  print scalar @csvheader , " --- ", join(" | ", @csvheader), "\n";

  my %all = ();
  my %type = ();
  my %is_pkc = ();  # Primary Key candidate ?
  for (my $i = 0; $i < scalar @csvheader; $i++) {
    $is_pkc{$csvheader[$i]} = 1;
    $type{$csvheader[$i]} = 0;
  }

  my $linec = 0;
  my $kr = 1;
  while (($kr) && (my $line = <CSV>)) {

    my @fieldvals = $csvh->csvline2array($line);
    MMisc::error_quit("While processing file [$csvfile], problem with CSV line extraction (data line #$linec): " . $csvh->get_errormsg())
        if ($csvh->error());

    for (my $i = 0; $i < scalar @csvheader; $i++) {
      my $h = $csvheader[$i];
      my $v = $fieldvals[$i];

      next if (($nullmode) && ($v eq ''));

      $is_pkc{$h} = 0 if (($is_pkc{$h}) && (++$all{$h}{$v} > 1));
 
      next if ($type{$h} == 2);

      next if (($type{$h} == 0) && (MMisc::is_integer($v)));

      $type{$h} = 1;

      next if (MMisc::is_float($v));

      $type{$h} = 2;
    }
    $linec++;
    $kr = 0 if (($quickConfig) && ($linec >= $quickConfig));
  }
  close FILE;

  print "\#\# Automaticaly generated table definition \#$nbr (seen $linec lines of data)" . ($quickConfig ? " [quickConfig]" : "") . "\n";

  my $tn = (! MMisc::is_blank($forcedtn)) ? $forcedtn : $utn;
  if (MMisc::is_blank($tn)) {
    my ($err, $dir, $filen, $ext) = MMisc::split_dir_file_ext($csvfile);
    return("Problem with filename: $err") if (! MMisc::is_blank($err));
    $tn = "$filen.$ext"; # we want to keep the big picture name here
    $tn =~ s%\.[^\.]+$%%; # remove the trailing _last_ extension
    ($tn) = MtSQLite::fix_entries($tn);
  }
  print "# Warning: this is possibly a duplicate table, as a table named \'$tn\' already exists, will use a different name\n"
    if (exists $tns{$tn});
  while (exists $tns{$tn}) { $tn .= "_"; }
  print "newtable: $tn\n";
  $tns{$tn}++;

  print "csvfile: $csvfile\n";

  my %tncs = ();
#  my $pkc = 0;
  my @pkcl = ();
  my @rc = ();
#  for (my $i = 0; $i < scalar @csvheader; $i++) { $pkc += $is_pkc{$csvheader[$i]}; }
  for (my $i = 0; $i < scalar @csvheader; $i++) {
    my $h = $csvheader[$i];
    my ($n) = MtSQLite::fix_entries($h);
    while (exists $tncs{$n}) { $n .= "_"; }
    $tncs{$n}++;
    print "column";
    print "*" if ((!MMisc::is_blank($primkey)) && ($primkey eq $h));
    print ": $h";
    $cnl{$h}{$tn} = $n;
    $fcm{$tn}{$h} = $n;
    if ($h ne $n) {
      print "=$n";
      push @rc, [$h, $n];
    }
    print ";" . $ok_types[$type{$h}];
    if (exists $sp_colC{$h}) {
      print ":" . $sp_colC{$h};
    } else {
      print(":" . $colC{$h}) if (exists $colC{$h});
    }
    print "\n";
#    push(@pkcl, $n) if (($pkc == 1) && ($is_pkc{$h}));
    push(@pkcl, $n) if ($is_pkc{$h});
  }

  # renammed columns list
  for (my $i = 0; $i < scalar @rc; $i++) {
    my ($h, $n) = @{$rc[$i]};
    print "# Renamed \'$h\' to \'$n\'\n";
  }

  # SQLite can only have one primary key, so we let the user to make the choice
  print "# Primary key candidate(s): " . join(" ", @pkcl) . "\n" 
    if (scalar @pkcl > 0);

  print "\n";
}

##########

sub print_xcolinfo {
  return() if (! defined $xcolinfo);
  return() if (scalar(keys %cnl) == 0);

  my $txt = "";

  $txt .= "\n## FYI: Original Columns name information:\n";
  foreach my $col (sort keys %cnl) {
    $txt .= "# Column \'$col\' is in the following tables:\n";
    foreach my $tn (sort keys %{$cnl{$col}}) {
      my $rn = $cnl{$col}{$tn};
      $txt .= "#   - \'$tn\'";
      $txt .= " (renamed as: \'$rn\')" if ($col ne $rn);
      $txt .= "\n";
    }
  }
  $txt .= "\n";

  $txt .= "\n";

  MMisc::writeTo($xcolinfo, "", 0, 0, $txt);
}

sub print_xtabinfo {
  return() if (! defined $xtabinfo);
  return() if (scalar(keys %fcm) == 0);

  my $txt = "";

  $txt .= "\n## FYI: Tables / Original Columns matches :\n";
  foreach my $tn (sort keys %fcm) {
    $txt .= "# Table \'$tn\' uses the following columns:\n";
    foreach my $col (sort keys %{$fcm{$tn}}) {
      my $rn = $fcm{$tn}{$col};
      $txt .= "#   - \'$col\'";
      $txt .= " (column renamed: \'$rn\')" if ($col ne $rn);
      my @tmp = keys %{$cnl{$col}};
      if (scalar @tmp > 0) {
        $txt .= " also is used in the following table(s):\n";
        foreach my $tn2 (sort @tmp) {
          my $rn2 = $cnl{$col}{$tn2};
          $txt .= "#      + \'$tn2\' ";
          $txt .= " (column renamed: \'$rn2\')" if ($col ne $rn2);
          $txt .= "\n";
        }
      } else {
        $txt .= " does not appear in any other table\n";
      }
    }
  }
  $txt .= "\n";

  MMisc::writeTo($xtabinfo, "", 0, 0, $txt);
}

########## 

sub set_usage {  
  my $tmp=<<EOF
$versionid

$0 [--help | --version] [--columninfo [filename]] [--tableinfo [filename]] [--Tablename name] [--primaryKey key] [--ColumnConstraint columnname:constraint [...]] [--quickConfig [linecount]] [--NULLfields] csvfile[:tablename][\%columnname:constraint[...]] [csvfile[:tablename][...]] [...]]

Will provide a config file entry for given csvfile.
If a tablename is provided after the csvfile, try to use that name for the table (does not override \'--Tablename\' option).
One or more 'columnname:constraint' can be used for a specific table (separated by a %) (does overide \'--ColumnConstraint\').

WARNING: There can be only one \'PRIMARY KEY\' per table, and is selected using the \'--primaryKey\' option. If you want to insure that all data are unique in a column, use a \'UNIQUE\' constraint.

NOTE: output will be printed to stdout.

Where:
  --help     This help message
  --version  Version information
  --columninfo   Will print columns information to stdout (or filename is specified)
  --tableinfo    Will print tables information to stdout (or filename is specfied)
  --Tablename    Will force the tablename to be specified name (can only load one csvfile when using this mode)
  --primarykey   Will treat any matching key as the table's primary key
  --ColumnConstraint   Add the specified SQLite-proper constraint when creating the column. Note that this will apply to all columns found with the specified columnname.
  --quickConfig  Specify the number of lines to be read to decide on file's column content (wihtout quickConfig, process all lines) (when used without a value, read $qcd lines)
  --NULLfields   Empty fields will be skipped to not force type detection, and can therefore be later inserted as the NULL value (the default is to insert them as the empty value of the defined type, ie '' for TEXTs)
EOF
;

  return($tmp);
}
