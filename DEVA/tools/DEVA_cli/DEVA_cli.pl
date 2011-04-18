#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# DEVA Command Line Interface
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "DEVA_cli" is an experimental system.
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

my $versionid = "DEVA Command Line Interfce Version: $version";

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

my $defusedmetric = "MetricNormLinearCostFunct";
my @ok_scales = ('nd', 'log', 'linear'); # order is important
my $mancmd = "perldoc -F $0";

my ($sqlite_cfg_helper, $sqlite_tables_creator, $sqlite_load_csv, 
  $deva_filter, $deva_sci) =
  ( "SQLite_cfg_helper", "SQLite_tables_creator", "SQLite_load_csv", 
    "DEVA_filter", "DEVA_sci");

my $usage = &set_usage();

my ($err, $sqlitecmd) = MtSQLite::get_sqlitecmd();
MMisc::error_quit($err)
  if (MMisc::is_blank($sqlitecmd));

my $outdir = "";
my $filtercmdfile = '';

my $doCfg = 1;
my $createDBs = 1;
my $filter = 1;
my $score = 1;

my $wrefCFfile = '';
my $wsysCFfile = '';
my $wmdCFfile  = '';

my $refcsv = "";
my @syscsvs = ();

my $wrefDBfile = '';
my $wsysDBfile = '';
my $wmdDBfile  = '';

my $wresDBfile = '';
my @addDBs = ();

my @addResDBfiles = ();
my $usedmetric = '';
my @usedmetparams = ();
my @trialsparams = ();
my $listparams = 0;
my $devadetname = '';
my $taskName = '';
my ($xm, $xM, $ym, $yM, $xscale, $yscale) 
  = (undef, undef, undef, undef, undef, undef);
my $blockavg = 0;
my $GetTrialsDB = 0;
my $quickConfig = undef;
my $nullmode = 0;
my $dividedSys = undef;
my $blockIDname = undef;
my $profile = undef;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used: ABCD FG    LMN P RSTUVWXYZabcd fghi  lm opqrstuvwxyz  #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'outdir=s' => \$outdir,
   'refcsv=s' => \$refcsv,
   'syscsv=s' => \@syscsvs,
   'configSkip' => sub { $doCfg = 0},
   'CreateDBSkip' => sub { $createDBs = 0},
   'filterSkip' => sub { $filter = 0},
   'FilterCMDfile=s' => \$filtercmdfile,
   'DETScoreSkip' => sub { $score = 0},
   'RefDBfile=s' => \$wrefDBfile,
   'SysDBfile=s' => \$wsysDBfile,
   'MetadataDBfile=s' => \$wmdDBfile,
   'additionalResDBfile=s' => \@addResDBfiles,
   'usedMetric=s' => \$usedmetric,
   'UsedMetricParameters=s' => \@usedmetparams,
   'TrialsParameters=s' => \@trialsparams,
   'listParameters' => \$listparams,
   'wREFcfg=s'  => \$wrefCFfile,
   'WSYScfg=s'  => \$wsysCFfile,
   'VMDcfg=s'   => \$wmdCFfile,
   'blockName=s'        => \$devadetname,
   'xmin=f'             => \$xm,
   'Xmax=f'             => \$xM,
   'ymin=f'             => \$ym,
   'Ymax=f'             => \$yM,
   'zusedXscale=s'      => \$xscale,
   'ZusedYscale=s'      => \$yscale,
   'AdditionalFilterDB=s'  => \@addDBs,
   'iFilterDBfile=s' => \$wresDBfile,
   'BlockAverage'    => \$blockavg,
   'taskName=s'      => \$taskName,
   'GetTrialsDB'     => \$GetTrialsDB,
   'quickConfig:i'   => \$quickConfig,
   'NULLfields'      => \$nullmode,
   'dividedSys:s'    => \$dividedSys,
   'PrintedBlockID=s' => \$blockIDname, 
#   'profile=s'       => \$profile,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

if ($listparams) {
  MMisc::error_quit("Specified \'metric\' does not seem to be using a valid name ($usedmetric), should start with \"Metric\"")
    if ((! MMisc::is_blank($usedmetric)) && (! ($usedmetric =~ m%^metric%i)));

  my $tool = &path_tool($deva_sci, "../../../DEVA/tools/DEVA_sci");

  my $cmdp = "-l";
  $cmdp .= " -m $usedmetric" if (! MMisc::is_blank($usedmetric));

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool("", $tool, $cmdp);

  MMisc::ok_quit($so);
}

MMisc::error_quit("Invalid value for \'usedXscale\' ($xscale) (possible values: " . join(", ", @ok_scales) . ")")
  if ((defined $xscale) && (! grep(m%^$xscale$%, @ok_scales)));
MMisc::error_quit("Invalid value for \'UsedYscale\' ($yscale) (possible values: " . join(", ", @ok_scales) . ")")
  if ((defined $yscale) && (! grep(m%^$yscale$%, @ok_scales)));

my @csvlist = @ARGV;

my $err = MMisc::check_dir_w($outdir);
MMisc::error_quit("Problem with output directory ($outdir): $err\n$usage\n")
  if (! MMisc::is_blank($err));

my $logdir = "$outdir/_logs";
MMisc::error_quit("Could not create log dir ($logdir)")
  if (! MMisc::make_dir($logdir));

my $mdDBb    = "metadataDB";
my $mdDBbase = "$outdir/$mdDBb";
my $mdDBcfg  = (MMisc::is_blank($wmdCFfile)) ? "$mdDBbase.cfg" : $wmdCFfile;
my $mdDBfile = (MMisc::is_blank($wmdDBfile)) ? "$mdDBbase.db" : $wmdDBfile;

my $refDBb    = "referenceDB";
my $refDBbase = "$outdir/$refDBb";
my $refDBcfg  = (MMisc::is_blank($wrefCFfile)) ? "$refDBbase.cfg" : $wrefCFfile;
my $refDBfile = (MMisc::is_blank($wrefDBfile)) ? "$refDBbase.db" : $wrefDBfile;
my $refTN     = "Reference";

my $sysDBb    = "systemDB";
my $sysDBbase = "$outdir/$sysDBb";
my $sysDBcfg  = (MMisc::is_blank($wsysCFfile)) ? "$sysDBbase.cfg" : $wsysCFfile;
my $sysDBfile = (MMisc::is_blank($wsysDBfile)) ? "$sysDBbase.db" : $wsysDBfile;
my $sysTN     = "System";

my $resDBb    = "filterDB";
my $resDBbase = "$outdir/$resDBb";
my $resDBfile = (MMisc::is_blank($wresDBfile)) ? "$resDBbase.db" : $wresDBfile;

my $finalDBb    = "scoreDB";
my $finalDBbase = "$outdir/$finalDBb";
my $finalDBfile = "$finalDBbase.db";

if ($doCfg) {
  ## Pre-check(s)
  MMisc::error_quit("\'dividedSys\' selected but less than 2 \'syscsv' files provided on the command line, aborting")
    if ((scalar @syscsvs > 0) && (defined $dividedSys) && (scalar @syscsvs < 2));
  MMisc::error_quit("More than one \'syscsv\' provided on the command line, aborting")
    if ((scalar @syscsvs > 0) && (! defined $dividedSys) && (scalar @syscsvs != 1));
  
  print "***** Generating config files\n";
  my $done = 0;
#  MMisc::warn_print("No CVS file list given, no metadataDB file will be generated")
#    if (scalar @csvlist == 0);

  if (! MMisc::is_blank($refcsv)) {
    print "** REF\n";
    my $tmp = &do_cfgfile
      ($refDBcfg, 0, "$logdir/CfgGen_${refDBb}.log", "-T $refTN -p TrialID", $refcsv);
    &check_isin($tmp, '^newtable:\s+Reference$', '^column\*:\s+TrialID;', '^column:\s+Targ;TEXT$');
    $done++;
  }
  
  if (scalar @syscsvs > 0) {
    if (! defined $dividedSys) {
      my $syscsv = $syscsvs[0];
      if (! MMisc::is_blank($syscsv)) {
        print "** SYS\n";
        my $tmp = &do_cfgfile
          ($sysDBcfg, 0, "$logdir/CfgGen_${sysDBb}.log", "-T $sysTN -p TrialID", $syscsv);
        &check_isin($tmp, '^newtable: System$', '^column\*:\s+TrialID;', '^column:\s+Decision;TEXT$', '^column:\s+Score;');
        $done++;
      }
    } else { # dividedSys mode
      print "** Divided SYS\n";
      my $tmp = &do_cfgfile
        ($sysDBcfg, 1, "$logdir/CfgGen_${sysDBb}.log", 
         "-c ${sysDBbase}_columninfo.txt -t ${sysDBbase}_tableinfo.txt", 
         @syscsvs);
      $done++;
    }
  }
      
  if (scalar @csvlist > 0) {
    print "** Metadata\n";
    my $tmp = &do_cfgfile
      ($mdDBcfg, 1, "$logdir/CfgGen_${mdDBb}.log", 
       "-c ${mdDBbase}_columninfo.txt -t ${mdDBbase}_tableinfo.txt", 
       @csvlist);
    $done++;
  }

  print "-> $done config file generated\n";
}

if ($createDBs) {
  print "***** Creating initial DataBases (if not already present)\n";
  my $done = 0;
  
  if (MMisc::does_file_exists($mdDBcfg)) {
    print "** Metadata\n";
    &db_create($mdDBcfg, 1, $mdDBfile, "$logdir/DBgen_${mdDBb}.log");
    $done++;
  }

  if (MMisc::does_file_exists($refDBcfg)) {
    print "** REF\n";
    &db_create($refDBcfg, 0, $refDBfile, "$logdir/DBgen_${refDBb}.log");
    $done++;
  }
  
  if (MMisc::does_file_exists($sysDBcfg)) {
    print "** SYS\n";
    &db_create($sysDBcfg, 0, $sysDBfile, "$logdir/DBgen_${sysDBb}.log");
    $done++;

    &dividedSys_Merge($sysDBfile, $mdDBfile);
  }
  
  print "-> $done DB file generated\n";
}

if ($filter) {
  print "***** Running Filter\n";
  
  MMisc::error_quit("No such \'FilterCMDfile\' ($filtercmdfile)")
    if ((MMisc::is_blank($filtercmdfile)) || (! MMisc::is_file_r($filtercmdfile)));
  
  &check_file_r($refDBfile);
  &check_file_r($sysDBfile);
  $mdDBfile = &check_file_r($mdDBfile, 1);

  &run_filter("$logdir/${resDBb}.log", $refDBfile, $sysDBfile, $mdDBfile, $filtercmdfile, $resDBfile, @addDBs);
}

if ($score) {
  print "***** Scoring\n";

  &check_file_r($refDBfile);
  &check_file_r($sysDBfile);
  $resDBfile = &check_file_r($resDBfile, 0);
  for (my $i = 0; $i < scalar @addResDBfiles; $i++) {
    &check_file_r($addResDBfiles[$i]);
  }

  &run_scorer("$logdir/${finalDBb}.log", $refDBfile, $sysDBfile, $finalDBfile, $resDBfile, @addResDBfiles);
}

MMisc::ok_quit("Done");

########################################

sub check_fn4 {
  my ($fn, $in) = @_;

  my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($fn);
  MMisc::error_quit("Problem checking file name ($fn): $err")
    if (! MMisc::is_blank($err));
  
  MMisc::error_quit("File ($fn) does not share expected base ($in), is ($f)")
    if ($in ne $f);
}

#####

sub do_cfgfile {
  my ($cfgfile, $nullok, $log, $cmdadd, @csvfl) = @_;

  my $tool = &path_tool($sqlite_cfg_helper, "../../../common/tools/SQLite_tools");

  if (defined $quickConfig) {
    $cmdadd .= " -q";
    $cmdadd .= " $quickConfig" if ($quickConfig > 0);
  }

  $cmdadd .= " -N" if (($nullok) && ($nullmode));

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, $cmdadd, @csvfl);

  MMisc::error_quit("Problem writing config file ($cfgfile)")
    if (! MMisc::writeTo($cfgfile, "", 0, 0, $so));

  return($so);
}

##########

sub db_create {
  my ($cfgfile, $nullok, $dbfile, $log) = @_;

  if (MMisc::does_file_exists($dbfile)) {
    print " -> DB file already exists, not overwriting it\n";
    return();
  }

  my $err = MMisc::check_file_r($cfgfile);
  MMisc::error_quit("Problem with config file ($cfgfile): $err")
    if (! MMisc::is_blank($err));

  my $tool = &path_tool($sqlite_tables_creator, "../../../common/tools/SQLite_tools");
  my $tool2 = (exists $ENV{$f4b}) ? "" : 
    &path_tool($sqlite_load_csv, "../../../common/tools/SQLite_tools");

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, 
              "-l" . (MMisc::is_blank($tool2) ? "" : " -L $tool2") 
              . (($nullok && $nullmode) ? " -N" : "")
              . " $dbfile $cfgfile");
}

##########

sub check_file_r {
  my ($file, $lenient) = @_;

  my $err = MMisc::check_file_r($file);
  if (! MMisc::is_blank($err)) {
    if ($lenient) {
      MMisc::warn_print("Issue with non mandatory file ($file): $err");
      return("");
    }
    MMisc::error_quit("Problem with file ($file): $err")
  }

  return($file);
}

#####

sub run_filter {
  my ($log, $refDBfile, $sysDBfile, $mdDBfile, $filtercmdfile, $resDBfile, @addDBs) = @_;

  my $tool = &path_tool($deva_filter, "../../../DEVA/tools/DEVA_filter");

  my $addcmd = "";
  for (my $i = 0; $i < scalar @addDBs; $i++) {
    my $v = $addDBs[$i];
    my ($file, $name, @rest) = split(m%\:%, $v);
    MMisc::error_quit("Too many values for \'AdditionalFilterDB\', expected \'file:name\' got more ($v)")
      if (scalar @rest > 0);
    MMisc::error_quit("Missing arguments for \'AdditionalFilterDB\', expected \'file:name\' (got: $v)")
      if ((MMisc::is_blank($name)) || (MMisc::is_blank($file)));
    $addcmd .= " -a $v";
  }

  if (defined $blockIDname) {
    $addcmd .= " -B $blockIDname";
  }

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, "-r $refDBfile -s $sysDBfile" .
              ((MMisc::is_blank($mdDBfile)) ? "" : " -m $mdDBfile" ) .
              "$addcmd -F $filtercmdfile $resDBfile");
}

##########

sub run_scorer {
  my ($log, $refDBfile, $sysDBfile, $finalDBfile, @xres) = @_;

  my $tool = &path_tool($deva_sci, "../../../DEVA/tools/DEVA_sci");

  my $cmdp = "-r $refDBfile -s $sysDBfile";
  for (my $i = 0; $i < scalar @xres; $i++) {
    $cmdp .= " -R " . $xres[$i];
  }
  $cmdp .= " -D ${finalDBbase}";
  $cmdp .= " -b ${devadetname}" if (! MMisc::is_blank($devadetname));
  $cmdp .= " -t ${taskName}" if (! MMisc::is_blank($taskName));
  $cmdp .= " -m $usedmetric" if (! MMisc::is_blank($usedmetric));
  foreach my $mk (@usedmetparams) {
    $cmdp .= " -M $mk";
  }
  foreach my $mk (@trialsparams) {
    $cmdp .= " -T $mk";
  }
  $cmdp .= " -x $xm" if (defined $xm);
  $cmdp .= " -X $xM" if (defined $xM);
  $cmdp .= " -y $ym" if (defined $ym);
  $cmdp .= " -Y $yM" if (defined $yM);
  $cmdp .= " -u $xscale" if (defined $xscale);
  $cmdp .= " -U $yscale" if (defined $yscale);
  $cmdp .= " -B" if ($blockavg);
  $cmdp .= " -G" if ($GetTrialsDB);
  $cmdp .= " $finalDBfile";
  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, $cmdp);
}

##########

sub check_isin {
  my ($txt, @entries) = @_;

  for (my $i = 0; $i < scalar @entries; $i++) {
    my $v = $entries[$i];
    MMisc::error_quit("Could not find expected entry [$v]")
      if (! ($txt =~ m%$v%m));
  }
}

#####

sub path_tool {
  my ($toolb, $relpath) = @_;
  my $tool = (exists $ENV{$f4b}) 
    ? MMisc::cmd_which($toolb) 
    : "$relpath/${toolb}.pl";
  &check_tool($tool, $toolb);
  return($tool);
}

#####

sub check_tool {
  my ($tool, $toolb) = @_;
  MMisc::error_quit("No location found for tool ($toolb)")
    if (MMisc::is_blank($tool));
  my $err = MMisc::check_file_x($tool);
  MMisc::error_quit("Problem with tool ($tool): $err")
    if (! MMisc::is_blank($err));
}

#####

sub run_tool {
  my ($lf, $tool, @cmds) = @_;

  $lf = MMisc::get_tmpfilename() if (MMisc::is_blank($lf));

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    MMisc::write_syscall_smart_logfile($lf, $tool, @cmds); 
  MMisc::error_quit("There was a problem running the tool ($tool) command, see: $of")
    if ((! $ok) || ($rc != 0));

  return($ok, $otxt, $so, $se, $rc, $of);
}

########################################

sub dividedSys_Merge {
  my ($dbfile, $mddb) = @_;

  return() if (! defined $dividedSys);

  my $err = MMisc::check_file_r($dividedSys);
  MMisc::error_quit("Problem with \'dividedSys\' file ($dividedSys) : $err")
    if (! MMisc::is_blank($err));

  my $cmd = "";

  $cmd .= "DROP TABLE IF EXISTS $sysTN;\n";
  $cmd .= "CREATE TABLE $sysTN (TrialID TEXT PRIMARY KEY, Score REAL, Decision TEXT);\n";
  $cmd .= "ATTACH DATABASE \"$mddb\" AS $mdDBb;\n" if (MMisc::does_file_exists($mddb));
  
  $cmd .= MMisc::slurp_file($dividedSys);

  ## SQLite usage
  my ($err, $log, $stdout, $stderr) = 
    MtSQLite::sqliteCommands($sqlitecmd, $dbfile, $cmd);
  MMisc::error_quit($err) if (! MMisc::is_blank($err));
}

############################################################ Manual

=pod

=head1 NAME

DEVA_cli - Detection EVAluation Scorer Command Line Interface

=head1 SYNOPSIS

B<DEVA_cli> 
  S<[B<--help> | B<--man> | B<--version>]>
  S<B<--outdir> I<dir>>
  S<[B<--configSkip>] [B<--CreateDBSkip>] [B<--filterSkip>] [B<--DETScoreSkip>]>
  S<[B<--refcsv> I<csvfile>] [B<--syscsv> I<csvfile>]>
  S<[B<--quickConfig> [I<linecount>]] [B<--NULLfields>]>
  S<[B<--wREFcfg> I<file>] [B<--WSYScfg> I<file>] [B<--VMDcfg> I<file>]>
  S<[B<--RefDBfile> I<file>] [B<--SysDBfile> I<file>]>
  S<[B<--MetadataDBfile> I<file>] [B<--iFilterDBfile> I<file>]>
  S<[B<--FilterCMDfile> I<SQLite_commands_file>]> 
  S<[B<--AdditionalFilterDB> I<file:name> [B<--AdditionalFilterDB> I<file:name> [...]]]>
  S<[B<--GetTrialsDB>]>
  S<[B<--usedMetric> I<package>]>
  S<[B<--UsedMetricParameters> I<parameter=value> [B<--UsedMetricParameters> I<parameter=value> [...]]]>
  S<[B<--TrialsParameters> I<parameter=value> [B<--TrialsParameters> I<parameter=value> [...]]]>
  S<[B<--listParameters>] [B<--blockName> I<name>] [B<--taskName> I<name>]>
  S<[B<--xmin> I<val>] [B<--Xmax> I<val>] [B<--ymin> I<val>] [B<--Ymax> I<val>]>
  S<[B<--zusedXscale> I<set>] [B<--ZusedYscale> I<set>]>
  S<[B<--BlockAverage>]>
  S<[B<--additionalResDBfile> I<file> [B<--additionalResDBfile> I<file> [...]]]>
  S<[I<csvfile> [I<csvfile> [I<...>]]>


=head1 DESCRIPTION

B<DEVA_cli> is the main wrapper script for the Detection EVAluation
(DEVA) tool set.  The DEVA tools are designed to score the output of a
binary detection system using a variety of evaluation metrics.  The tool set reads a set of comma
separated value (CSV) input data files and then uses a SQLite database backend to
select what to score. 

The wrapper performs four steps to complete thes scoring process.  The USAGE section describes the process with an example.

=over  

=item Step 1: Scheme configuration generation

Required arguments:
 S<B<--outdir> I<dir>>

Optional arguments:
 S<[B<--quickConfig> [I<linecount>]]>
 S<[B<--NULLfields>]>
 S<[B<--refcsv> I<csvfile>]>
 S<[B<--syscsv> I<csvfile>]>
 S<[B<--wREFcfg> I<file>]>
 S<[B<--WSYScfg> I<file>]>
 S<[B<--VMDcfg> I<file>]>
 S<[I<csvfile> [I<csvfile> [I<...>]]]>

Bypass step:
 S<[B<--configSkip>]>

=item Step 2: SQL table creation and populating

Required arguments:
 S<B<--outdir> I<dir>>

Optional arguments:
 S<[B<--NULLfields>]>
 S<[B<--wREFcfg> I<file>]>
 S<[B<--WSYScfg> I<file>]>
 S<[B<--VMDcfg> I<file>]>
 S<[B<--RefDBfile> I<file>]>
 S<[B<--SysDBfile> I<file>]>
 S<[B<--MetadataDBfile> I<file>]>

Bypass step: 
 S<[B<--CreateDBSkip>]>

=item Step 3: SQL Filtering

Required arguments:
 S<B<--outdir> I<dir>>

Optional arguments:
 S<[B<--RefDBfile> I<file>]>
 S<[B<--SysDBfile> I<file>]>
 S<[B<--MetadataDBfile> I<file>]>
 S<[B<--iFilterDBfile> I<file>]>
 S<[B<--FilterCMDfile> I<SQLite_commands_file>]>
 S<[B<--AdditionalFilterDB> I<file:name> [B<--AdditionalFilterDB> I<file:name> [...]]]>

Bypass step: 
 S<[B<--filterSkip>]>

=item Step 4: Scoring with DETCurve generation

Required arguments:
 S<B<--outdir> I<dir>>

Optional arguments:
 S<[B<--RefDBfile> I<file>]>
 S<[B<--SysDBfile> I<file>]>
 S<[B<--iFilterDBfile> I<file>]>
 S<[B<--GetTrialsDB>]>
 S<[B<--usedMetric> I<package>]>
 S<[B<--UsedMetricParameters> I<parameter=value> [B<--UsedMetricParameters> I<parameter=value> [...]]]>
 S<[B<--TrialsParameters> I<parameter=value> [B<--TrialsParameters> I<parameter=value> [...]]]>
 S<[B<--listParameters>]>
 S<[B<--blockName> I<name>]>
 S<[B<--taskName> I<name>]>
 S<[B<--xmin> I<val>]>
 S<[B<--Xmax> I<val>]>
 S<[B<--ymin> I<val>]>
 S<[B<--Ymax> I<val>]>
 S<[B<--zusedXscale> I<set>]>
 S<[B<--ZusedYscale> I<set>]>
 S<[B<--additionalResDBfile> I<file> [B<--additionalResDBfile> I<file> [...]]]>
 S<[B<--BlockAverage>]>

Bypass step: 
 S<[B<--DETScoreSkip>]>

=back

The DEVA tool set uses the notion of a 'detection trial' as the
fundmental building block for the tool.  A detection trial is a test
probe of a detection system in which a system is given a particular
piece of data and the system provides a numeric estimate expressing
the confidence that the peice of data is a member of the target class.  A
trial can be a 'target trial' in which the piece of data IS an
instance of the class or a 'non-target trial' in which the piece of
data IS NOT a member of the class.  The tool does not interact with
the source data in any manner so the probe data and class definition can be of
any construction.

The DEVA tool set has three design features that make it a powerful
evaluation tool: 

=over

1. There are two modes of operation, simple and
wizard mode. 

2. The tool set uses SQLite data bases to store the
input data and SQL queries to condition the scoring based on supplied
metadata.  See the SQL FILTERS section to understand how to use SQL filters.

3. Commandline-selectable evaluation metrics and parameters.  See the
METRICS section for how to select and provide parameters for the
metrics.

=back

The two modes of operations make it possible for a casual user to use
the scoring tools quickely without understanding the intricacies of
the tool while providing richer functionality for the more advanced
user.  In simple mode, a user provides CSV-formatted system and
reference files and a simple SQL query, the tool then performs the
full scoring pipeline.  In wizard mode, a user re-uses previous
computations to speed execution by skipping steps that are often repetative.  

The SQLite provides both an efficient data store and a mechanism to
performed conditioned scoring by filtering the system output based on
additional factors.  The filter operation is performed by an SQL query
that selects both the target and non-target trials to score.  See the SQL FILTERS section below.

Commandline-selectable evaluation metrics permit the same tool to be
used for a variety of evaluations. The metrics are implemented as
source code modules provided with the tool set.  The metrics set
expanded only through additional coding.

=head1 INPUT FILES

=head2 CSV files

To generate the mutliple tables for the SQLite database, we rely on I<Comma Separated Values> (CSV) to contain the data to be processed.
The CSV file names will be used as SQL table name, and must have as a first row the column headers that will be used as the SQL table column name.
To avoid issues in processing the data, it is recommended that each column content be quoted and comma separated. For example, a table whose SQL table name is expected to be "Employee" will be represented as the "Employee.csv" file and contain a first row: S<"ID","FirstName","LastName"> and an examplar entry could be: S<"1","John","Doe">

The program leave the content of the database free for most I<metadata> content. One of the table that is part of that database should contain a I<TrialID> column that match the one present in the I<reference> or I<system> CSV.

The I<reference> CSV file must contain two columns: I<TrialID> and I<Targ>, where I<TrialID> must be a primary key and I<Targ> values must be a either I<y> or I<n>.

The I<system> CSV file must contain three columns: I<TrialID>, I<Score> and I<Decision>, where I<TrialID> must be a primary key, I<Score> a numerical value and I<Targ> values must be a either I<y> or I<n>.

Examples of CSV files can be found in the F4DE source in:
 F<common/test/common/ref.csv>
 F<common/test/common/sys.csv>
 F<common/test/common/md.csv>

=head2 Configuration files

Configuration files are generated by Step 1.

A configuration file structure specify a corresponding I<SQLite> S<CREATE TABLE> but is human readable and composed of simple one line definitions:

=over

=item S<newtable: tablename>

Starts the definition of a new table and specify the table name as I<tablename> (must be the first line for each new table definition). Note that this step tries to infer the I<tablename> from the I<csvfile>'s I<filename>.

=item S<csvfile: location>

Specify the full path I<location> of the CSV file to load. If I<location> is of the form S<path/filename.suffix>, the default --unless it is overridden by the user or for specific tables (such as I<Reference> and I<System>)-- is to use I<filename> as the I<tablename>.

An I<entry renaming rule> apply to all I<tablename> and I<columnUsedName> so that any character other than S<a> to S<z>, S<A> to S<Z>, S<0> to S<9> and S<_> are replaced by S<_>. In addition, if a I<location> has multiple I<suffix> entries, only the last one if removed.
Therefore, f I<location> if of the form S<filename.suffix1.suffix>, the default corresponding I<tablename> would be S<filename_suffix1>.

Note that the I<path> is the exact same as specified on the command line for the corresponding CSV file (if the specified CSV file is S<../test.csv>, the I<location> will be S<../test.csv> too) it is therefore important to run the tools from the same location when creating the configuration file and its database creation.

=item S<column: columnUsedName;columnType>

Specify a column seen in the CSV file, each column seen has to be detailed this way and the order in the configuration file as to match to column order in the CSV file. If a CSV file has I<X> columns, the configuration file must have I<X> S<column:> definitions.

S<column*:> specify that the column is the table's primary key. A given table can only have one primary key.

S<columnUsedName> specify the column name as it can be accessed from its I<tablename> within I<SQLite>. If a column has a name to which the I<entry renaming rule> applis, S<column:> gets redifined as S<column: columnName=columnUsedName;columnType>, where S<columnName> is the original column name. For example if the original column name is
 S<name.has;to:fixed> (of I<TEXT> S<columnType>)
, the S<column:> definition will read
 S<column: name.has;to:fixed=name_has_to_fixed;TEXT>

S<columnType> is one of S<INT>, S<REAL> or S<TEXT>.

=back

Examples of configuration files can be found in the F4DE source in:
 F<common/test/common/ref1.cfg>
 F<common/test/common/sys2.cfg>
 F<common/test/common/md2.cfg>
 F<common/test/common/mix2.cfg>

=head1 SQL FILTERS

Step 3 use a user provided SQLite select command file.
The filter file contains a SQLite set of commands. It is left to the user to create and store all temporary tables in the non permanent I<temp> internal database (automatically deleted when the database connection is closed).

For this step, the reference database is loaded as I<referenceDB> and contains a table named I<Reference>, the system database is loaded as I<systemDB> and contains a table named I<System>.
If provided, the metadata database is loaded as I<metadataDB> and contain the table list specified during the metadata configuration file.

Users should not output anything but the final select that must contain only the following data in the expected order: I<TrialID> and I<BlockID>.
If no I<BlockID> is provided, a default value will be inserted in its stead.
Both columns will then be made to populate I<outdir/filterDB.db>'s I<resultsTable> table.

An example of such select can be:

 SELECT system.TrialID FROM system INNER JOIN md WHERE system.TrialID=md.TrialID;

which will "select the list of TrialID from the system table and the metadata table where both TrialID match". Note that this will use the default I<BlockID>.

A more complex example given a I<color> column in the metadata database that will be used as the I<BlockID>:

 SELECT system.TrialID,color FROM system INNER JOIN md WHERE system.TrialID=md.TrialID AND Decision>"1.2";

which will "select the list of TrialIDs and corresponding color from the system table and the metadata table where both TrialID match and the system's decision is more than 1.2". This will use the I<color> entry as the I<BlockID>.

Examples of SQL filter files can be found in the F4DE source in:
 F<DEVA/test/common/filter1.sql>
 F<DEVA/test/common/filter2.sql>

=head1 METRICS

Please refer to the I<Evaluation Scoring Primer> and I<Evaluation webpage> for details on the I<Metric> to be used (specified using B<--usedMetric>), as well as the parameters both for the Metric itself (specified using B<--UsedMetricParameters>) and the associated I<Trial> (specified using B<--TrialsParameters>).

=head1 PREREQUISITES

B<DEVA_cli> relies on some external software and files.

=over

=item B<SOFTWARE> 

I<sqlite3> (S<http://www.sqlite.org/>) is required (at least version 3.6.12) to perform all the SQL work.

I<gnuplot> (S<http://www.gnuplot.info/>) is also required (at least version 4.2) to generate the DETCurve plots.

=item B<GLOBAL ENVIRONMENT VARIABLE>

Once you have installed the software, setting the enviroment variable B<F4DE_BASE> to the installation location, and extending your B<PATH> environment variable to include B<$F4DE_BASE/bin> should be sufficient for the tools to find their components.

=back

=head1 OPTIONS

=over

=item B<--AdditionalFilterDB> I<file:name>

Attach additional SQLite database(s) during I<Filtering Step>. Load I<file> as I<name> (tables within can be accessed as I<name>.I<tablename>).

=item B<--additionalResDBfile> I<file>

Attach additional I<Filtering Step> result SQLite database(s) during I<DETCurve generation Step>. Tables will be merged by doing an B<AND> on the I<TrialID>s.

=item B<--BlockAverage>

For scoring step, combine all Trial in one DET instead of splitting them per BlockID

=item B<--blockName> I<name>

Specify the name of the blocking factor.  The block name is the type of object that the system is detection, e.g., an event, speaker, etc.  The block name will be added to the reports and generated files.

=item B<--CreateDBSkip>

Skip the database and tables generation.

This step uses the files created in the configuration generation step and generate multiple SQLite databases containing the tables specified in their respective configuration files.

Files created during this step would be S<outdir/referenceDB.sql>, S<outdir/systemDB.sql> and S<outdir/metadataDB.sql>

=item B<--configSkip>

Skip the generation of the configuration files required for the generation of the database tables.

This process read each CSV file (I<refcsv>, I<syscsv> and metadata I<csvfile(s)>), determine the tables name, columns names and types and write them in S<outdir/referenceDB.cfg>, S<outdir/systemDB.cfg> and S<outdir/metadataDB.cfg> files.

=item B<--DETScoreSkip>

Skip the Trial Scoring step (including DETCurve processing).

This step rely on the S<outdir/referenceDB.sql>, S<outdir/systemDB.sql> and S<<outdir/filterDB.sql> files to extract into S<outdir/scoreDB.sql> a I<ref> and I<sys> table that only contains the I<TrialID>s left post-filtering.
This step also generate a few files starting with S<outdir/scoreDB.det> that are the results of the DETCurve generation process.

=item B<--FilterCMDfile> I<SQLite_commands_file>

Specify the location of the SQL commands file used to extract the list of I<TrialID> that will be inserted in I<output/filterDB.sql>.

=item B<--filterSkip>

Skip step that uses the SQL I<SELECT>s commands specified in the B<--FilterCMDfile> step to create the S<outdir/filterDB.sql> database (which only contains S<TrialID> information).

=item B<--GetTrialsDB>

Add a table to the scoring database containing each individual Trial component.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--iFilterDBfile> I<file>

Specify the filtering SQLite database file

=item B<--listParameters>

List Metric and Trial package authorized parameters

=item B<--MetadataDBfile> I<file>

Specify the location of the Metadata database file to use/generate.

=item B<--man>

Display this man page.

=item B<--NULLfields>

Empty columns will be inserted as the NULL value to allow proper JOIN (the default is to insert them as the empty value of the defined type, ie '' for TEXTs). This behavior only apply to metadata CSV files.

=item B<--outdir> I<dir>

Specify the directory in which all files relevant to this call to B<DEVA_cli> will be placed (or looked for).

=item B<--quickConfig> [I<linecount>]

Specify the number of lines to be read in Step 1 to decide on file content for config helper step (wihtout quickConfig, process all lines)

=item B<--RefDBfile> I<file>

Specify the location of the Reference database file to use/generate.

=item B<--refcsv> I<csvfile>

Specify the location of the Reference CSV file (expected to contain a S<TrialID> and S<Targ> columns).

=item B<--SysDBfile> I<file>

Specify the location of the System database file to use/generate.

=item B<--syscsv> I<csvfile>

Specify the location of the System CSV file (expected to contain S<TrialID>, S<Score> and S<Decision> columns).

=item B<--TrialsParameters> I<parameter=value>

Specify the parameters given during the Trial creation process.

=item B<--taskName> I<name>

Specify the name of the task (the type of evaluation, for example: detection).

=item B<--UsedMetricParameters> I<parameter=value>

Specify the parameters given during the Metric creation process.

=item B<--usedMetric> I<package>

Specify the Metric package to use for scoring data (must be in your perl serch path -- or part of F4DE).

=item B<--VMDcfg> I<file>

Specify the metadata configuration file

=item B<--version>

Display the B<DEVA_cli> version information.

=item B<--WSYScfg> I<file>

Specify the System configuration file

=item B<--wREFcfg> I<file>

Specify the Refefence configuration file

=item B<--Xmax> I<val>

Specify the max value of the X axis (PFA) of the DET curve

=item B<--xmin> I<val>

Specify the min value of the X axis (PFA) of the DET curve

=item B<--Ymax> I<val>

Specify the max value of the Y axis (PMisss) of the DET curve

=item B<--ymin> I<val>

Specify the min value of the Y axis (PMisss) of the DET curve

=item B<--ZusedYscale> I<set>

Specify the scale used for the Y axis of the DET curve

=item B<--zusedXscale> I<set>

Specify the scale used for the X axis of the DET curve

=back

=head1 USAGE

B<DEVA_cli --outdir outdir --refcsv ref.csv --syscsv sys.csv md.csv --FilterCMDfile filter1.sql --usedMetric MetricNormLinearCostFunct --UsedMetricParameters 'Ptarg=0.1'  --UsedMetricParameters 'CostMiss=1' --UsedMetricParameters 'CostFA=1'>

This will process the four steps expected of the command line interface:

=over

=item Step 1 (uses B<SQLite_cfg_helper>)

Will use I<ref.csv> as the Reference CSV file, I<sys.csv> as the System CSV file and I<md.csv> as the one Metadata CSV file (multiple Metadata CSV can be used, we only use one in this example).

From those files, the first step will generate the database creation configuration files by loading each rows and columns in the CSV to determine their SQLite type, and determine if the column header name has to be adapted to avoid characters not recognized by SQLite. 

As a reminder, to be proper, the I<ref.csv> must contain a I<TrialID> and I<Targ> columns.
The I<sys.csv> must contain a I<TrialID>, I<Score> and I<Decision> columns.

The metadata CSV(s) should contain the information that should be important to be I<SELECT>ed during the I<filtering> step (3rd step of this process) as well as at least one table with a I<TrialID> and optionally a I<BlockID> column , both of which are expected during the I<filtering> step (if I<BlockID> is not provided, a default value will be used).

Please note that it is the user's responsiblity to provide properly formatted CSV files with the expected columns (especially for the Reference and System CSV files).

This process will create the I<outdir/referenceDB.cfg>, I<outdir/systemDB.cfg> and I<outdir/metadataDB.cfg> files. Note that the location of the CSV files is embedded within the config file. 

This step also create I<outdir/metadataDB_columninfo.txt> and I<outdir/metadataDB_tableinfo.txt>, which contain details on the relationship between columns and tables that will compose the metadata database. 

=item Step 2 (uses B<SQLite_tables_creator>)

The next step will use those configuration files to create SQLite database files containing:

=over

=item

One table called I<Reference> (containing at least one primary key column called I<TrialID> and one column called I<Targ> with S<y> or S<n> value) for I<outdir/referenceDB.db> which content is loaded from I<ref.csv>.

=item

One table called I<System> (containing at least on primary key column called I<TrialID> as well as one I<Score> column with numerical value and one I<Decision> with S<y> or S<n> value) for I<outdir/systemDB.db> which content is loaded from I<sys.csv>

=item

As many tables as metadata CSV files (here only one) are added to <outdir/metadataDB.db> loaded from the metadata CSV file list provided (here only I<md.csv>).

=back

=item Step 3 (uses B<DEVA_filter>)

The next step will use the I<filter1.sql> SQL command lines file to apply the given filter. For this step I<outdir/referenceDB.db> is loaded as I<referenceDB> (and contains a table named I<Reference>). I<outdir/systemDB.db> is loaded as I<systemDB> (and contains a table named I<System>). And I<outdir/metadataDB.db> is loaded as I<metadataDB> and contain the table list specified in I<outdir/metadataDB.cfg>.
The filter file contains a SQLite set of commands. It is left to the user to create and store all temporary tables in the non permanent I<temp> internal database (automatically deleted when the database connection is closed).
Users should not output anything but the final select that must contain only the following data in the expected order: I<TrialID> and I<BlockID>.
If no I<BlockID> is provided, a default value will be inserted in its stead.
Both columns will then be made to populate I<outdir/filterDB.db>'s I<resultsTable> table.

=item Step 4 (uses B<DEVA_sci>)

The final step will use I<outdir/referenceDB.db>, I<outdir/systemDB.db> and I<outdir/filterDB.db> to select from the I<Reference> and I<System> tables only the I<TrialID>s present in I<resultsTables> and create the I<outdir/scoreDB.db> SQLite database file a I<Reference> and I<System> tables that only contain the rows  matching the given I<TrialID>s.

I<Trials> are then generated, using the I<BlockID> column from I<resultsTable> as the I<Trial>'s block information, so that:

=over

=item

If a given entry is both in I<Reference> and I<System> it is I<mapped> (the I<System>'s I<Score> and I<Decision> columns as well as the I<Reference>'s I<Targ> column are used to specify the I<Trial>'s I<sysScore>, I<decision> and I<isTarg> information).

=item

If an entry is only in <System>, it is an I<unmapped_sys> entry (the I<System>'s I<Score> and I<Decision> columns specify the I<Trial>'s I<sysScore> and I<decision> information, I<isTarg> is always 0 in this case).

=item

If an entry is only in I<Reference> it is an I<unmapped_ref> entry, but only I<y>es I<Targ> entries are added as I<OMMITTED> I<Trial>.

=back

I<DETCurve>s are then generated using the I<Trials> using the I<MetricNormLinearCostFunct> specified I<Metric> (and the specified I<UsedMetricParameters>) 
Each file starting with I<outdir/scoreDB.scores> is one of those results:

=over

=item

I<outdir/scoreDB.scores.txt>
contains the I<DETCurve>'s I<Performance Summary Over and Ensemble of Subsets>

=item

I<outdir/scoreDB.scores.csv>
is a Comma Separated Value dump of the previous data's table.

=item

Files starting with I<outidr/scoreDB.det> are used by and for the graphic representation of the curve points:

=item

files with a I<.dat.X> suffix (where I<X> is a numerical value) are S<gnuplot> data files. 

=item

files with a I<.plt> suffix are S<gnuplot> command files

=item

files with a I<.png> suffix are I<Portable Network Graphics> image files results from the corresponding I<.plt> S<gnuplot> commands files

=item

files with a I<.srl> (or I<.srl.gz>) suffix are I<serialized> I<DETCurve> files and can be used as input to tools such as S<DETUtil> to merge multiple curves together

=back

=back

=head1 Notes

=over

=item Logdirs

A I<outdir/_logs> is created and populated by each step, so that files starting with I<CfgGen_> and I<DBgen_> are generated respectively during Step 1 and 2, I<filterDB.log> during Step 3 and I<scoreDB.log> during Step 4.

In case a file of the expected name is already present, a tag consisting of S<-YYYYMMDD-HHMMSS> (year, month, day, hour, minute, seconds) will be added to the newly created log file.

=item Step(s) bypass

It is possible to I<bypass> entirely some steps. For example:

=over

=item 

B<DEVA_cli --outdir outdir --refcsv ref.csv --syscsv sys.csv md.csv --CreateDBSkip --filterSkip --DETScoreSkip>

Will only create the configuration files, but not the database, or run the filter or scorer. This is useful if one wants to edit the I<outdir/metadataDB.cfg> file to rename some columns or look at the automatic renaming of some metadata table (adapted from the file name) or columns names (to avoid SQLite unauthorized characters) in order to adapt the filter step.

Note that since the location of the CSV files is embedded within the config files, one can not do the following after running the previous command:

=item

B<DEVA_cli --outdir outdir --refcsv ref2.csv --syscsv sys2.csv md2.csv --configSkip --filterSkip --DETScoreSkip>

I<ref2.csv>, I<sys2.csv> and I<md2.csv> will not be used by the database creation process (Step 2), since I<ref.csv>, I<sys.csv> and I<md.csv> are specified in the S<csvfile:> line of the respective config file.

=back

=back

=head1 RELATED TOOLS

The script will work with the following tools (lookup their help page for more details):

=over

=item B<SQLite_cfg_helper> 

=item B<SQLite_tables_creator> (and B<SQLite_load_csv>)

=item B<DEVA_filter>

=item B<DEVA_sci>

=back

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut

##########

sub set_usage {
  my $pv = join(", ", @ok_scales);

  my $tmp=<<EOF
$versionid

$0 [--help | --man | --version] --outdir dir [--configSkip] [--CreateDBSkip] [--filterSkip] [--DETScoreSkip] [--refcsv csvfile] [--syscsv csvfile | --dividedSys [join.sql] --sycsv csvfile[:tablename] --syscsv csvfile[:tablename] [--syscsv csvfile[:tablename] [...]]] [--quickConfig [linecount]] [--NULLfields] [--wREFcfg file] [--WSYScfg file] [--VMDcfg file] [--RefDBfile file] [--SysDBfile file] [--MetadataDBfile file] [--iFilterDBfile file] [--FilterCMDfile SQLite_commands_file] [--AdditionalFilterDB file:name [--AdditionalFilterDB file:name [...]]] [--GetTrialsDB] [--usedMetric package] [--UsedMetricParameters parameter=value [--UsedMetricParameters parameter=value [...]]] [--TrialsParameters parameter=value [--TrialsParameters parameter=value [...]]] [--listParameters] [--blockName name] [--taskName name] [--xmin val] [--Xmax val] [--ymin val] [--Ymax val] [--zusedXscale set] [--ZusedYscale set] [--BlockAverage] [--additionalResDBfile file [--additionalResDBfile file [...]]] [csvfile[:tablename] [csvfile[:tablename] [...]]]

Wrapper for all steps involved in a DEVA scoring step
Arguments left on the command line are csvfile used to create the metadataDB

NOTE: will create _logs directory in outdir

Where:
  --help     This help message
  --version  Version information
  --outdir   Specify the directory where are all the steps are being processed
  --configSkip    Bypass csv config helper step
  --CreateDBSkip  Bypasss Databases creation step
  --filterSkip    Bypasss Filter tool step
  --DETScoreSkip  Bypass Scoring Interface step
  --wREFcfg    Specify the Refefence configuration file
  --WSYScfg    Specify the System configuration file
  --VMDcfg     Specify the metadata configuration file
  --refcsv     Specify the Reference csv file
  --syscsv     Specify the System csv file
  --quickConfig    Specify the number of lines to be read in Step 1 to decide on file content for config helper step (wihtout quickConfig, process all lines) (*2)
  --NULLfields   Empty columns will be inserted as the NULL value (the default is to insert them as the empty value of the defined type, ie '' for TEXTs). This behavior only apply to metadata CSV files.
  --RefDBfile  Specify the Reference SQLite database file
  --SysDBfile  Specify the System SQLite database file
  --MetadataDBfile  Specify the metadata SQLite database file
  --iFilterDBfile  Specify the filtering SQLite database file
Filter (Step 3) specific options:
  --FilterCMDfile  Specify the SQLite command file
  --AdditionalFilterDB  Load additional SQLite database 'file' for the filtering step (loaded as 'name')
DETCurve generation (Step 4) specific options:
  --GetTrialsDB   Add a table to the scoring database containing each individual Trial component
  --usedMetric    Package to load for metric uses (if none provided, default used: $defusedmetric)
  --UsedMetricParameters Metric Package parameters
  --TrialsParameters Trials Package parameters
  --listParameters   List Metric and Trial package authorized parameters
  --blockName        Specify the name of the type of blocks (*1)
  --taskName         Specify the name of the task (*1)
  --xmin --Xmax      Specify the min and max value of the X axis (PFA) of the DET curve (*1)
  --ymin --Ymax      Specify the min and max value of the Y axis (PMiss) of the DET curve (*1)
  --zusedXscale --ZusedYscale    Specify the scale used for the X and Y axis of the DET curve (Possible values: $pv) (*1)
  --BlockAverage    Combine all Trial in one DET instead of splitting them per BlockID
  --additionalResDBfile  Additional Filter results database files to give the scorer (will do an AND on the TrialIDs)


*1: default values can be obtained from \"$deva_sci\" 's help
*2: default number of lines if no value is set can be obtained from \"$sqlite_cfg_helper\" 's help

EOF
;

  return($tmp);
}

