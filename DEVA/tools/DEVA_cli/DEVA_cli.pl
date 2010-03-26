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
foreach my $pn ("MMisc") {
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
my $outdir = "";
my $filtercmdfile = "";

my $doCfg = 1;
my $createDBs = 1;
my $filter = 1;
my $score = 1;

my $refcsv = "";
my $syscsv = "";

my $wrefDBfile = "";
my $wsysDBfile = "";
my $wmdDBfile  = "";
my @addResDBfiles = ();
my $resDBbypass = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used: A C  F           RST      a c  f h    m o  rs  v      #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'outdir=s'   => \$outdir,
   'refcsv=s'   => \$refcsv,
   'syscsv=s'   => \$syscsv,
   'configSkip' => sub { $doCfg = 0},
   'CreateDBSkip' => sub { $createDBs = 0},
   'filterSkip' => sub { $filter = 0},
   'FilterCMDfile=s' => \$filtercmdfile,
   'TrialScoreSkip' => sub { $score = 0},
   'RefDBfile=s'    => \$wrefDBfile,
   'SysDBfile=s'    => \$wsysDBfile,
   'metadataDBfile=s' => \$wmdDBfile,
   'addResDBfiles=s'   => \@addResDBfiles,
   'AllowResDBfileBypass' => \$resDBbypass,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

my @csvlist = @ARGV;

my $err = MMisc::check_dir_w($outdir);
MMisc::error_quit("Problem with output directory ($outdir): $err\n$usage\n")
  if (! MMisc::is_blank($err));

my $logdir = "$outdir/_logs";
MMisc::error_quit("Could not create log dir ($logdir)")
  if (! MMisc::make_dir($logdir));

my $mdDBbase = "$outdir/metadataDB";
my $mdDBcfg  = "$mdDBbase.cfg";
my $mdDBfile = (MMisc::is_blank($wmdDBfile)) ? "$mdDBbase.sql" : $wmdDBfile;
my $mdDBlogb = "$logdir/metadataDB";

my $refDBbase = "$outdir/referenceDB";
my $refDBcfg  = "$refDBbase.cfg";
my $refDBfile = (MMisc::is_blank($wrefDBfile)) ? "$refDBbase.sql" : $wrefDBfile;
my $refDBlogb = "$logdir/referenceDB";

my $sysDBbase = "$outdir/systemDB";
my $sysDBcfg  = "$sysDBbase.cfg";
my $sysDBfile = (MMisc::is_blank($wsysDBfile)) ? "$sysDBbase.sql" : $wsysDBfile;
my $sysDBlogb = "$logdir/systemDB";

my $resDBbase = "$outdir/filterDB";
my $resDBfile = "$resDBbase.sql";

my $finalDBbase = "$outdir/scoreDB";
my $finalDBfile = "$finalDBbase.sql";


if ($doCfg) {
  print "***** Generating config files\n";
  my $done = 0;
#  MMisc::warn_print("No CVS file list given, no metadataDB file will be generated")
#    if (scalar @csvlist == 0);

  if (! MMisc::is_blank($refcsv)) {
    print "** REF\n";
    my $tmp = &do_cfgfile
      ($refDBcfg, "${refDBlogb}_cfggen.log", "-T Reference -p TrialID", $refcsv);
    &check_isin($tmp, '^newtable:\s+Reference$', '^column\*:\s+TrialID;', '^column:\s+Targ;TEXT$');
    $done++;
  }
  
  if (! MMisc::is_blank($syscsv)) {
    print "** SYS\n";
    my $tmp = &do_cfgfile
      ($sysDBcfg, "${sysDBlogb}_cfggen.log", "-T System -p TrialID", $syscsv);
    &check_isin($tmp, '^newtable: System$', '^column\*:\s+TrialID;', '^column:\s+Decision;TEXT$', '^column:\s+Score;');
    $done++;
  }
  
  if (scalar @csvlist > 0) {
    print "** Metadata\n";
    my $tmp = &do_cfgfile
      ($mdDBcfg, "${mdDBlogb}_cfggen.log", 
       "-c ${mdDBbase}_columninfo.txt -t ${mdDBbase}_tableinfo.txt", 
       @csvlist);
    $done++;
  }

  print "-> $done config file generated\n";
}

if ($createDBs) {
  print "***** Creating initial DataBases (if not already present)\n";
  my $done = 0;
  
  if (MMisc::does_file_exists($refDBcfg)) {
    print "** REF\n";
    &db_create($refDBcfg, $refDBfile, "${refDBlogb}_DBgen.log");
    $done++;
  }
  
  if (MMisc::does_file_exists($sysDBcfg)) {
    print "** SYS\n";
    &db_create($sysDBcfg, $sysDBfile, "${sysDBlogb}_DBgen.log");
    $done++;
  }
  
  if (MMisc::does_file_exists($mdDBcfg)) {
    print "** Metadata\n";
    &db_create($mdDBcfg, $mdDBfile, "${mdDBlogb}_DBgen.log");
    $done++;
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
  
  &run_filter("$logdir/filterTool.log", $refDBfile, $sysDBfile, $mdDBfile, $filtercmdfile, $resDBfile);
}

if ($score) {
  print "***** Scoring\n";

  &check_file_r($refDBfile);
  &check_file_r($sysDBfile);
  $resDBfile = &check_file_r($resDBfile, $resDBbypass);
  for (my $i = 0; $i < scalar @addResDBfiles; $i++) {
    &check_file_r($addResDBfiles[$i]);
  }

  &run_scorer("$logdir/TrialScore.log", $refDBfile, $sysDBfile, $finalDBfile, $resDBfile, @addResDBfiles);
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
  my ($cfgfile, $log, $cmdadd, @csvfl) = @_;

  my $tool = "../../../common/tools/SQLite_tools/SQLite_cfg_helper.pl";
  &check_tool($tool);

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, $cmdadd, @csvfl);

  MMisc::error_quit("Problem writing config file ($cfgfile)")
    if (! MMisc::writeTo($cfgfile, "", 0, 0, $so));

  return($so);
}

##########

sub db_create {
  my ($cfgfile, $dbfile, $log) = @_;

  if (MMisc::does_file_exists($dbfile)) {
    print " -> DB file already exists, not overwriting it\n";
    return();
  }

  my $err = MMisc::check_file_r($cfgfile);
  MMisc::error_quit("Problem with config file ($cfgfile): $err")
    if (! MMisc::is_blank($err));

  my $tool = "../../../common/tools/SQLite_tools/SQLite_tables_creator.pl";
  &check_tool($tool);

  my $tool2 = "../../../common/tools/SQLite_tools/SQLite_load_csv.pl";
  &check_tool($tool2);

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, "-l -L $tool2 $dbfile $cfgfile");
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
  my ($log, $refDBfile, $sysDBfile, $mdDBfile, $filtercmdfile, $resDBfile) = @_;

  my $tool = "../DEVA_filter/DEVA_filter.pl";
  &check_tool($tool);

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, "-r $refDBfile -s $sysDBfile" .
              ((MMisc::is_blank($mdDBfile)) ? "" : " -m $mdDBfile" ) .
              " -F $filtercmdfile $resDBfile");
}

##########

sub run_scorer {
  my ($log, $refDBfile, $sysDBfile, $finalDBfile, @xres) = @_;

  my $tool = "../DEVA_sci/DEVA_sci.pl";
  &check_tool($tool);

  my $cmdp = "-r $refDBfile -s $sysDBfile";
  for (my $i = 0; $i < scalar @xres; $i++) {
    $cmdp .= " -R " . $xres[$i];
  }
  $cmdp .= " -b ${finalDBbase}_DET";
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

sub check_tool {
  my ($tool) = @_;
  my $err = MMisc::check_file_x($tool);
  MMisc::error_quit("Problem with tool ($tool): $err")
    if (! MMisc::is_blank($err));
}

#####

sub run_tool {
  my ($lf, $tool, @cmds) = @_;
  
  my ($ok, $otxt, $so, $se, $rc, $of) = 
    MMisc::write_syscall_smart_logfile($lf, $tool, @cmds); 
  MMisc::error_quit("There was a problem running the tool ($tool) command, see: $of")
    if ((! $ok) || ($rc != 0));

  return($ok, $otxt, $so, $se, $rc, $of);
}

##########

sub set_usage {  
  my $tmp=<<EOF
$versionid

$0 [--help | --version] --outdir dir [--configSkip] [--CreateDBSkip] [--filterSkip] [--TrialScoreSkip] [--refcsv csvfile] [--syscsv csvfile] [--RefDBfile file] [--SysDBfile file] [--metadataDBfile file] [--FilterCMDfile SQLite_commands_file] [csvfile [csvfile [...]]

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
  --TrialScoreSkip  Bypass Scoring Interface step
  --refcsv     Specify the Reference csv file
  --syscsv     Specify the System csv file
  --RefDBfile  Specify the Reference SQLite database file
  --SysDBfile  Specify the System SQLite database file
  --metadataDBfile  Specify the metadata SQLite database file
  --FilterCMDfile  Specify the SQLite command file
  --addResDBfiles  Additional filter results database files to give the scorer (will do an AND on the TrialIDs)
EOF
;

  return($tmp);
}

