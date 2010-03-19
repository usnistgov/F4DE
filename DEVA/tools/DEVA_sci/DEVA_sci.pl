#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# DEVA Scoring Interface
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "DEVA_sci" is an experimental system.
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

my $versionid = "DEVA Scoring Interface Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../../common/lib");
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
foreach my $pn ("MMisc", "CSVHelper", "MtSQLite", "Trials", "MetricFuncs", "MetricTestStub", "DETCurve", "DETCurveSet") {
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


# Default values for variables
#
my $refDBfile = "";
my $refDBname = "referenceDB";
my $sysDBfile = "";
my $sysDBname = "systemDB";
my $resDBfile = "";
my $resDBname = "resultsDB";
#
my $tablename = "resultsTable";
my $TrialIDcolumn = "TrialID";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                  R               h         rs  v      #

my $usage = &set_usage();
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'ResultDBfile=s'     => \$resDBfile,
   'referenceDBfile=s'  => \$refDBfile,
   'systemDBfile=s'     => \$sysDBfile,

  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No resultsDBfile information provided\n\n$usage") 
  if (scalar @ARGV != 1);

my ($dbfile) = @ARGV;

my $cmdlines = "";

# Attach the REF and SYS databases
MtSQLite::commandAdd(\$cmdlines, "ATTACH DATABASE \"$refDBfile\" AS $refDBname");
MtSQLite::commandAdd(\$cmdlines, "ATTACH DATABASE \"$sysDBfile\" AS $sysDBname");
MtSQLite::commandAdd(\$cmdlines, "ATTACH DATABASE \"$resDBfile\" AS $resDBname");

# Create the Final table

my $tmp=<<EOF
DROP TABLE IF EXISTS ref;
DROP TABLE IF EXISTS sys;

CREATE TABLE ref AS SELECT $tablename.TrialID,Targ FROM $resDBname.$tablename INNER JOIN $refDBname.Reference WHERE $tablename.$TrialIDcolumn = Reference.$TrialIDcolumn;

CREATE TABLE sys AS SELECT $tablename.TrialID,Decision,Score FROM $resDBname.$tablename INNER JOIN $sysDBname.System WHERE $tablename.$TrialIDcolumn = System.$TrialIDcolumn;
EOF
  ;

MtSQLite::commandAdd(\$cmdlines, $tmp);

my ($err, $log, $stdout, $stderr) = 
  MtSQLite::sqliteCommands("sqlite3", $dbfile, $cmdlines);
MMisc::error_quit($err) if (! MMisc::is_blank($err));

my %ref = &confirm_table($dbfile, 'ref', 'TrialID', 'Targ');
my %sys = &confirm_table($dbfile, 'sys', 'TrialID', 'Decision', 'Score');

my $tot1 = scalar(keys %ref) + scalar(keys %sys);

#print MMisc::get_sorted_MemDump(\%ref);
#print MMisc::get_sorted_MemDump(\%sys);

my $trial = new Trials("REF_SYS", "Trials", "NotSure", { ("TOTALTRIALS" => 10) });
my ($mapped, $unmapped_sys, $unmapped_ref) = (0, 0, 0);

foreach my $key (keys %sys) {
  if (exists $ref{$key}) { # mapped
    $trial->addTrial("NotSure", $sys{$key}{'Score'}, ($sys{$key}{'Decision'} eq 'y') ? 'YES' : 'NO', 1);
    $mapped++;
  } else { # unmapped sys
    $trial->addTrial("NotSure", $sys{$key}{'Score'}, ($sys{$key}{'Decision'} eq 'y') ? 'YES' : 'NO', 0);
    $unmapped_sys++;
  }
}

foreach my $key (keys %ref) {
  if (! exists $sys{$key}) { # unmapped ref
    $trial->addTrial("NotSure", undef, "OMITTED", 1);
    $unmapped_ref++;
  }
  
# mapped: already done
}

print "Mapped      : $mapped\n";
print "UnMapped REF: $unmapped_ref\n";
print "UnMapped SYS: $unmapped_sys\n";

my $tot2 = 2*$mapped + $unmapped_ref + $unmapped_sys;
print "Check:\n";
print "-- Total number of entries in REF + SYS    = $tot1\n";
print "-- 2x mapped + Unmapped REF + Unmapped SYS = $tot2\n";
MMisc::error_quit("Problem at check point") if ($tot1 != $tot2);

my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
my $det = new DETCurve
  ($trial,
   new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
   "footitle", \@isolinecoef, "gzip");
#$det->computePoints();
#my $sroot = "serialize";
#$det->serialize($sroot);
my $detSet = new DETCurveSet("sysTitle");
my $rtn = $detSet->addDET(" Event", $det);
MMisc::error_quit("Error adding DET to the DETSet: $rtn")
  if ($rtn ne "success");
my @dc_range = (0.01, 1000, 5, 99.99); # order is important (xmin;xmax) (ymin;ymax)
my ($xm, $xM, $ym, $yM)= @dc_range;
MMisc::writeTo
    ("DET", ".scores.txt", 1, 0, 
     $detSet->renderAsTxt
     ("DET" . ".det", 1, 1, 
      { (xScale => "log", Xmin => $xm, Xmax => $xM, Ymin => $ym, Ymax => $yM,
         gnuplotPROG => "gnuplot",
         createDETfiles => 1,
         BuildPNG => 1),
      },
      "DET.csv")
    );

MMisc::ok_quit("Done");

####################

sub confirm_table {
  my ($dbfile, $tablename, @columns) = @_;
  
  my ($err, $dbh) = MtSQLite::get_dbh($dbfile);
  MMisc::error_quit($err)
    if (! MMisc::is_blank($err));

  my $cmd = "SELECT " . join(",", @columns) . " FROM $tablename";
  my ($err, $sth) = MtSQLite::get_command_sth($dbh, $cmd);
  MMisc::error_quit("Problem doing a SELECT on \'$tablename\': $err")
   if (! MMisc::is_blank($err));

  my $err = MtSQLite::execute_sth($sth);
  MMisc::error_quit("Problem processing SELECT on \'$tablename\': $err")
    if (! MMisc::is_blank($err));

  my %res = ();
  my $doit = 1;
  while ($doit) {
    my ($err, @data) = MtSQLite::sth_fetchrow_array($sth);
    MMisc::error_quit("Problem obtaining row: $err")
      if (! MMisc::is_blank($err));
    if (scalar @data == 0) {
      $doit = 0;
      next;
    }

    my $mk = $data[0]; # _must be_ the TrialID key
    for (my $i = 1; $i < scalar @columns; $i++) {
      my $c = $columns[$i];
      my $v = $data[$i];
      $res{$mk}{$c} = $v;
#      print "# $mk / $c / $v\n";
    }

  }

  my $err = MtSQLite::sth_finish($sth);
  MMisc::error_quit("Problem while completing statement: $err")
    if (! MMisc::is_blank($err));

  print "* Extracted from $tablename ". scalar(keys %res) . "x datum\n";
  
  MtSQLite::release_dbh($dbh);

  return(%res);
}

########## 

sub set_usage {  
  my $tmp=<<EOF
$versionid

$0 [--help | --version] --referenceDBfile file --systemDBfile file --ResultDBfile resultsDBfile ScoreDBfile

Will load Trials information and create DETcurves

NOTE: will create ScoreDBfile

Where:
  --help     This help message
  --version  Version information
  --referenceDBfile  The Reference SQLite file (must contains the 'Reference' table, whose columns are: TrialID, Targ)
  --systemDBfile     The System SQLite file (must contains the 'System' table, whose columns are: TrialID, Decision, Score)
  --ResultDBfile     The Filter tool resulting DB (must contain the \'$tablename\' table, which only column is: $TrialIDcolumn)

EOF
;

  return($tmp);
}

