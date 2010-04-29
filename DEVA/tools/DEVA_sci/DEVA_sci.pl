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
foreach my $pn ("MMisc", "CSVHelper", "MtSQLite", "Trials", "MetricFuncs", "DETCurve", "DETCurveSet") {
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
my @resDBfiles = ();
my $resDBname = "resultsDB";
#
my $tablename = "resultsTable";
my $TrialIDcolumn = "TrialID";
my $BlockIDcolumn = "BlockID";

my $bDETf = "DET";

my @ok_modes = ("AND", "OR"); # order is important
my $mode = $ok_modes[0];

my $metric = "";
my %metparams = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:             M    R               h    m o  rs  v      #

my $usage = &set_usage();
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'ResultDBfile=s'     => \@resDBfiles,
   'referenceDBfile=s'  => \$refDBfile,
   'systemDBfile=s'     => \$sysDBfile,
   'operator=s'         => \$mode,
   'baseDETfile=s'      => \$bDETf,
   'metricPackage=s'    => \$metric,
   'MetricParameters=s' => \%metparams,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No ScoreDBfile information provided\n\n$usage") 
  if (scalar @ARGV != 1);
MMisc::error_quit("No \'referenceDBfile\' provided\n\n$usage")
  if (MMisc::is_blank($refDBfile));
MMisc::error_quit("No \'systemDBfile\' provided\n\n$usage")
  if (MMisc::is_blank($sysDBfile));
MMisc::error_quit("No \'referenceDBfile\' provided\n\n$usage")
  if (scalar @resDBfiles == 0);
&check_DBs_r($refDBfile, $sysDBfile, @resDBfiles);
MMisc::error_quit("Unrecognized \'mode\' [$mode], authorized values are: " . join(" ", @ok_modes))
  if (! grep(m%^$mode$%, @ok_modes));

MMisc::error_quit("No \'metric\' specified, aborting")
  if (MMisc::is_blank($metric));
unless (eval "use $metric; 1") {
  MMisc::error_quit("Metric package \"$metric\" is not available in your Perl installation. " . &eo2pe($@));
}

my ($dbfile) = @ARGV;

my ($err, $sqlitecmd) = MtSQLite::get_sqlitecmd();
MMisc::error_quit($err)
  if (MMisc::is_blank($sqlitecmd));

my $cmdlines = "";

# Attach the REF and SYS databases
MtSQLite::commandAdd(\$cmdlines, "ATTACH DATABASE \"$refDBfile\" AS $refDBname");
MtSQLite::commandAdd(\$cmdlines, "ATTACH DATABASE \"$sysDBfile\" AS $sysDBname");
my $used_resDBname = "";
my @resDBnames = ();
my %tid2bid = ();
for (my $i = 0; $i < scalar @resDBfiles; $i++) {
  my $resDBfile = $resDBfiles[$i];
  &confirm_table(\%tid2bid, $resDBfile, $tablename, $TrialIDcolumn, $BlockIDcolumn);
  my $lresDBname = $resDBname . sprintf("_%03d", $i);
  MtSQLite::commandAdd(\$cmdlines, "ATTACH DATABASE \"$resDBfile\" AS $lresDBname");
  push @resDBnames, $lresDBname;
}
$used_resDBname = &joinResDBfiles(\$cmdlines, $mode, @resDBnames);

# Create the Final table

my $tmp=<<EOF
DROP TABLE IF EXISTS ref;
DROP TABLE IF EXISTS sys;

CREATE TABLE ref AS SELECT $tablename.$TrialIDcolumn,Targ FROM $used_resDBname.$tablename INNER JOIN $refDBname.Reference WHERE $tablename.$TrialIDcolumn = Reference.$TrialIDcolumn;

CREATE TABLE sys AS SELECT $tablename.$TrialIDcolumn,Decision,Score FROM $used_resDBname.$tablename INNER JOIN $sysDBname.System WHERE $tablename.$TrialIDcolumn = System.$TrialIDcolumn;
EOF
  ;

MtSQLite::commandAdd(\$cmdlines, $tmp);

my ($err, $log, $stdout, $stderr) = 
  MtSQLite::sqliteCommands($sqlitecmd, $dbfile, $cmdlines);
MMisc::error_quit($err) if (! MMisc::is_blank($err));

my %ref = ();
&confirm_table(\%ref, $dbfile, 'ref', $TrialIDcolumn, 'Targ');
my %sys = ();
&confirm_table(\%sys, $dbfile, 'sys', $TrialIDcolumn, 'Decision', 'Score');

my $tot1 = scalar(keys %ref) + scalar(keys %sys);

#print MMisc::get_sorted_MemDump(\%ref);
#print MMisc::get_sorted_MemDump(\%sys);

my $trial = new Trials("REF_SYS", "Trials", "NotSure", { ("TOTALTRIALS" => 10) });
my ($mapped, $unmapped_sys, $unmapped_ref) = (0, 0, 0);

foreach my $key (keys %sys) {
  my $bid = (MMisc::safe_exists(\%tid2bid, $key, $BlockIDcolumn)) 
    ? $tid2bid{$key}{$BlockIDcolumn} : $BlockIDcolumn;
  if (exists $ref{$key}) { # mapped
    $trial->addTrial($bid, $sys{$key}{'Score'}, ($sys{$key}{'Decision'} eq 'y') ? 'YES' : 'NO', 1);
    $mapped++;
  } else { # unmapped sys
    $trial->addTrial($bid, $sys{$key}{'Score'}, ($sys{$key}{'Decision'} eq 'y') ? 'YES' : 'NO', 0);
    $unmapped_sys++;
  }
}

foreach my $key (keys %ref) {
  if (! exists $sys{$key}) { # unmapped ref
    my $bid = (MMisc::safe_exists(\%tid2bid, $key, $BlockIDcolumn)) 
      ? $tid2bid{$key}{$BlockIDcolumn} : $BlockIDcolumn;
    $trial->addTrial($bid, undef, "OMITTED", 1);
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

my $met = undef;
my $metcmd = "\$met = new $metric (\\\%metparams, \$trial);";
unless (eval "$metcmd; 1") {
  MMisc::error_quit("Problem creating Metric ($metric) object (" . join(" ", @_) . ")");
}
MMisc::error_quit("Problem with metric ($metric)")
  if (! defined $met);
my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
my $det = new DETCurve($trial, $met, "footitle", \@isolinecoef, "gzip");
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
    ($bDETf, ".scores.txt", 1, 0, 
     $detSet->renderAsTxt
     ("$bDETf.det", 1, 1, 
      { (xScale => "log", Xmin => $xm, Xmax => $xM, Ymin => $ym, Ymax => $yM,
         gnuplotPROG => MMisc::cmd_which("gnuplot"),
         createDETfiles => 1,
         BuildPNG => 1),
      },
      "$bDETf.csv")
    );

MMisc::ok_quit("Done");

####################

sub check_DBs_r {
  for (my $i = 0; $i < scalar @_; $i++) {
    my $fn = $_[$i];
    my $err = MMisc::check_file_r($fn);
    MMisc::error_quit("Problem with DB file [$fn]: $err")
      if (! MMisc::is_blank($err));
  }
}

####################

sub ANDtworesDB {
  my ($rcmd, $in1, $in2, $out) = @_;

  my $tmp=<<EOF
DROP TABLE IF EXISTS $out.$tablename;
CREATE TABLE $out.$tablename AS SELECT $in1.$tablename.$TrialIDcolumn FROM $in1.$tablename INNER JOIN $in2.$tablename WHERE $in1.$tablename.$TrialIDcolumn = $in2.$tablename.$TrialIDcolumn;

EOF
  ;

  MtSQLite::commandAdd($rcmd, $tmp);
}

#####

sub ANDresDBs {
  my ($rcmd, @dbl) = @_;

  # We know we have at least 2 tables in the list at this point
  my $in1 = shift @dbl;
  my $in2 = shift @dbl;
  my $jres = "temp.${resDBname}_init";
  &ANDtworesDB($rcmd, $in1, $in2, $jres);
  my $pjres = $jres;
  for (my $i = 0; $i < scalar @dbl; $i++) {
    $jres = "temp.${resDBname}_" . sprint("%04d", $i);
    &ANDtworesDB($rcmd, $pjres, $dbl[$i], $jres);
  }

  return($jres);
}

#####

sub joinResDBfiles {
  my ($rcmd, $mode, @dbl) = @_;

  return($dbl[0]) if (scalar @dbl == 1);

  return(&ANDresDBs($rcmd, @dbl))
    if ($mode eq $ok_modes[0]);

  MMisc::error_quit("Not yet ready mode");
}

####################

sub confirm_table {
  my ($rh, $dbfile, $tablename, @columns) = @_;
  
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
      MMisc::error_quit("In DB ($dbfile)'s table ($tablename), $mk / $c = $v was already found and its previous value was different : " . $$rh{$mk}{$c})
        if ((MMisc::safe_exists($rh, $mk, $c)) && ($$rh{$mk}{$c} ne $v));
      $$rh{$mk}{$c} = $v;
#      print "# $mk / $c / $v\n";
    }

  }

  my $err = MtSQLite::sth_finish($sth);
  MMisc::error_quit("Problem while completing statement: $err")
    if (! MMisc::is_blank($err));

  print "* Extracted from $tablename ". scalar(keys %$rh) . "x datum\n";
  
  MtSQLite::release_dbh($dbh);
}

########## 

sub set_usage {  
  my $tmp=<<EOF
$versionid

$0 [--help | --version] --referenceDBfile file --systemDBfile file --ResultDBfile resultsDBfile [--ResultDBfile resultsDBfile [...]] --metricPackage package --MetricParameters parameter=value [--MetricParameters parameter=value [...]] [--baseDETfile filebase] ScoreDBfile

Will load Trials information and create DETcurves

NOTE: will create ScoreDBfile

Where:
  --help     This help message
  --version  Version information
  --referenceDBfile  The Reference SQLite file (must contains the 'Reference' table, whose columns are: TrialID, Targ)
  --systemDBfile     The System SQLite file (must contains the 'System' table, whose columns are: TrialID, Decision, Score)
  --ResultDBfile     The Filter tool resulting DB (must contain the \'$tablename\' table, with the following columns: $TrialIDcolumn $BlockIDcolumn)
  --metricPackage    Package to load for metric uses
  --MetricParameters Metric Package parameters
  --baseDETfile      When working with DET curves, all the relevant files will start with this value (default: $bDETf)
EOF
;

  return($tmp);
}

