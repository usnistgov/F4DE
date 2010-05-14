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

my $defusedmetric = "MetricNormLinearCostFunct";
my @ok_scales = ('nd', 'log', 'linear'); # order is important
my $mancmd = "perldoc -F $0";

my ($sqlite_cfg_helper, $sqlite_tables_creator, $sqlite_load_csv, 
  $deva_filter, $deva_sci) =
  ( "SQLite_cfg_helper", "SQLite_tables_creator", "SQLite_load_csv", 
    "DEVA_filter", "DEVA_sci");

my $usage = &set_usage();

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
my $syscsv = "";

my $wrefDBfile = '';
my $wsysDBfile = '';
my $wmdDBfile  = '';
my @addResDBfiles = ();

my @addDBs = ();

my $usedmetric = '';
my @usedmetparams = ();
my @trialsparams = ();
my $listparams = 0;

my $devadetname = '';
my ($xm, $xM, $ym, $yM, $xscale, $yscale) 
  = (undef, undef, undef, undef, undef, undef);

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used: A CD F     LM    RSTUVWXYZa cd fgh   lm o  rstuvwxyz  #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'outdir=s' => \$outdir,
   'refcsv=s' => \$refcsv,
   'syscsv=s' => \$syscsv,
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
   'listParams' => \$listparams,
   'wREFcfg=s'  => \$wrefCFfile,
   'WSYScfg=s'  => \$wsysCFfile,
   'VMDcfg=s'   => \$wmdCFfile,
   'detName=s'          => \$devadetname,
   'xmin=i'             => \$xm,
   'Xmax=i'             => \$xM,
   'ymin=i'             => \$ym,
   'Ymax=i'             => \$yM,
   'zusedXscale=i'       => \$xscale,
   'ZusedYscale=i'       => \$yscale,
   'AdditionalFilterDB=s'  => \@addDBs,
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

my $sysDBb    = "systemDB";
my $sysDBbase = "$outdir/$sysDBb";
my $sysDBcfg  = (MMisc::is_blank($wsysCFfile)) ? "$sysDBbase.cfg" : $wsysCFfile;
my $sysDBfile = (MMisc::is_blank($wsysDBfile)) ? "$sysDBbase.db" : $wsysDBfile;

my $resDBb    = "filterDB";
my $resDBbase = "$outdir/$resDBb";
my $resDBfile = "$resDBbase.db";

my $finalDBb    = "scoreDB";
my $finalDBbase = "$outdir/$finalDBb";
my $finalDBfile = "$finalDBbase.db";

if ($doCfg) {
  print "***** Generating config files\n";
  my $done = 0;
#  MMisc::warn_print("No CVS file list given, no metadataDB file will be generated")
#    if (scalar @csvlist == 0);

  if (! MMisc::is_blank($refcsv)) {
    print "** REF\n";
    my $tmp = &do_cfgfile
      ($refDBcfg, "$logdir/CfgGen_${refDBb}.log", "-T Reference -p TrialID", $refcsv);
    &check_isin($tmp, '^newtable:\s+Reference$', '^column\*:\s+TrialID;', '^column:\s+Targ;TEXT$');
    $done++;
  }
  
  if (! MMisc::is_blank($syscsv)) {
    print "** SYS\n";
    my $tmp = &do_cfgfile
      ($sysDBcfg, "$logdir/CfgGen_${sysDBb}.log", "-T System -p TrialID", $syscsv);
    &check_isin($tmp, '^newtable: System$', '^column\*:\s+TrialID;', '^column:\s+Decision;TEXT$', '^column:\s+Score;');
    $done++;
  }
  
  if (scalar @csvlist > 0) {
    print "** Metadata\n";
    my $tmp = &do_cfgfile
      ($mdDBcfg, "$logdir/CfgGen_${mdDBb}.log", 
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
    &db_create($refDBcfg, $refDBfile, "$logdir/DBgen_${refDBb}.log");
    $done++;
  }
  
  if (MMisc::does_file_exists($sysDBcfg)) {
    print "** SYS\n";
    &db_create($sysDBcfg, $sysDBfile, "$logdir/DBgen_${sysDBb}.log");
    $done++;
  }
  
  if (MMisc::does_file_exists($mdDBcfg)) {
    print "** Metadata\n";
    &db_create($mdDBcfg, $mdDBfile, "$logdir/DBgen_${mdDBb}.log");
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

  &run_filter("$logdir/${resDBb}.log", $refDBfile, $sysDBfile, $mdDBfile, $filtercmdfile, $resDBfile, $addcmd);
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
  my ($cfgfile, $log, $cmdadd, @csvfl) = @_;

  my $tool = &path_tool($sqlite_cfg_helper, "../../../common/tools/SQLite_tools");

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

  my $tool = &path_tool($sqlite_tables_creator, "../../../common/tools/SQLite_tools");
  my $tool2 = (exists $ENV{$f4b}) ? "" : 
    &path_tool($sqlite_load_csv, "../../../common/tools/SQLite_tools");

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, 
              "-l" . (MMisc::is_blank($tool2) ? "" : " -L $tool2") 
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
  my ($log, $refDBfile, $sysDBfile, $mdDBfile, $filtercmdfile, $resDBfile, $addcmd) = @_;

  my $tool = &path_tool($deva_filter, "../../../DEVA/tools/DEVA_filter");

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
  $cmdp .= " -b ${finalDBbase}_DET";
  $cmdp .= " -m $usedmetric" if (! MMisc::is_blank($usedmetric));
  foreach my $mk (@usedmetparams) {
    $cmdp .= " -M $mk";
  }
  foreach my $mk (@trialsparams) {
    $cmdp .= " -T $mk";
  }
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

############################################################ Manual

=pod

=head1 NAME

DEVA_cli - DEVA Command Line Interface

=head1 SYNOPSIS

B<DEVA_cli> S<[ B<--help> | B<--man> | B<--version> ]>
  S<B<--outdir> I<dir>>
  S<[B<--configSkip>] [B<--CreateDBSkip>] [B<--filterSkip>] [B<--DETScoreSkip>]>
  S<[B<--refcsv> I<csvfile>] [B<--syscsv> I<csvfile>]>
  S<[B<--wREFcfg> I<file>] [B<--WSYScfg> I<file>] [B<--VMDcfg> I<file>]>
  S<[B<--RefDBfile> I<file>] [B<--SysDBfile> I<file>] [B<--MetadataDBfile> I<file>]>
  S<[B<--FilterCMDfile> I<SQLite_commands_file>]> 
  S<[B<--AdditionalFilterDB> I<file:name> [B<--AdditionalFilterDB> I<file:name> [...]]]>
 S<[B<--usedMetric> I<package>]>
  S<[B<--UsedMetricParameters> I<parameter=value> [B<--UsedMetricParameters> I<parameter=value> [...]]>
  S<[B<--TrialsParameters> I<parameter=value> [B<--TrialsParameters> I<parameter=value> [...]]]>
  S<[B<--listParameters>] [B<--detName> I<name>]>
  S<[B<--xmin> I<val>] [B<--Xmax> I<val>] [B<--ymin> I<val>] [B<--Ymax> I<val>]>
  S<[B<--zusedXscale> I<set>] [B<--ZusedYscale> I<set>]>
  S<[B<--additionalResDBfile> I<file> [B<--additionalResDBfile> I<file> [...]]]>
  [I<csvfile> [I<csvfile> [I<...>]]
  
=head1 DESCRIPTION

B<DEVA_cli> is a wrapper script to start from a set of CSV files, generate its configuraion file, then its database, apply a select filter on the database to obtain DETCurve information.

The script will work with the following tools (lookup their help page for more details):

=over

=item B<SQLite_cfg_helper> 

=item B<SQLite_tables_creator>

=item B<DEVA_filter>

=item B<DEVA_sci>

=back

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

=item B<--CreateDBSkip>

Skip the database and tables generation.

This step uses the files created in the configuration generation step and generate multiple SQLite databases containing the tables specified their respective configuration files.

Files created during this step would be S<outdir/referenceDB.sql>, S<outdir/systemDB.sql> and S<outdir/metadataDB.sql>

=item B<--configSkip>

Skip the generation of the configuration files required for the generation of the database tables.

This process read each CSV file (I<refcsv>, I<syscsv> and metadata I<csvfile(s)>), determine the tables name, columns names and types and write them in S<outdir/referenceDB.cfg>, S<outdir/systemDB.cfg> and S<outdir/metadataDB.cfg> files.

=item B<--DETScoreSkip>

Skip the Trial Scoring step (including DETCurve processing).

This step rely on the S<outdir/referenceDB.sql>, S<outdir/systemDB.sql> and S<<outdir/filterDB.sql> files to extract into S<outdir/scoreDB.sql> a I<ref> and I<sys> table that only contains the I<TrialID>s left post-filtering.
This step also generate a few files starting with S<outdir/scoreDB_DET> that are the results of the DETCurve generation process.

=item B<--detName> I<name>

Specify the name added to the DETCurve (as well as the specialzied file generated for this process)

=item B<--FilterCMDfile> I<SQLite_commands_file>

Specify the location of the SQL commands file used to extract the list of I<TrialID> that will be inserted in I<output/filterDB.sql>.

=item B<--filterSkip>

Skip step that uses the SQL I<SELECT>s commands specified in the B<--FilterCMDfile> step to create the S<outdir/filterDB.sql> database (which only contains S<TrialID> information).

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--listParameters>

List Metric and Trial package authorized parameters

=item B<--MetadataDBfile> I<file>

Specify the location of the Metadata database file to use/generate.

=item B<--man>

Display this man page.

=item B<--outdir> I<dir>

Specify the directory in which all files relevant to this call to B<DEVA_cli> will be placed (or looked for).

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

=item B<--detName> I<name>

Specify the name added to the DET curve (as well as the specialzied file generated for this process)

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

B<DEVA_cli --outdir outdir --refcsv ref.csv --syscsv sys.csv md.csv --FilterCMDfile filter1.sql --usedMetric MetricNormLinearCostFunct --UsedMetricParameters Ptarg=0.1  --UsedMetricParameters CostMiss=1 --UsedMetricParameters CostFA=1>

This will process the four steps expected of the command line interface:

=over

=item Step 1 (uses B<SQLite_cfg_helper>)

Will use I<ref.csv> as the Reference CSV file, I<sys.csv> as the System CSV file and I<md.csv> as the one Metadata CSV file (multiple Metadata CSV can be used, we only use one in this example).

From those files, the first step will generate the database creation configuration files by loading each rows and columns in the CSV to determine their SQLite type, and determine if the column header name has to be adapted to avoid characters not recognized by SQLite. 

To be proper, the I<ref.csv> must contain at least a I<TrialID> and I<Targ> columns (I<TrialID> must be a primary key and I<Targ> values must be a either I<y> or I<n>). 
The I<sys.csv> must contain at least a I<TrialID>, I<Score> and I<Decision> columns (I<TrialID> must be a primary key, I<Score> a numerical value and I<Targ> values must be a either I<y> or I<n>).

The metadata CSV(s) should contain the information that should be important to be I<SELECT>ed during the I<filtering> step (3rd step of this process) as well as at least one table with a I<TrialID> and optionally a I<BlockID> column , both of which are expected during the I<filtering> step (if I<BlockID> is not provided, a default value will be used).

Please note that it is the user's responsiblity to provide properly formatted CSV files with the expected columns (especially for the Reference and System CSV files).

This process will create the I<outdir/referenceDB.cfg>, I<outdir/systemDB.cfg> and I<outdir/metadataDB.cfg> files. Note that the location of the CSV files is embedded within the config file. A configuration file structure specify a corresponding I<SQLite> S<CREATE TABLE> but is human readable and composed of simple one line definitions:

=over

=item S<newtable: tablename> starts the definition of a new table and specify the table name as I<tablename> (must be the first line for each new table definition). Note that this step tries to infer the I<tablename> from the I<csvfile>'s I<filename>. 

=item S<csvfile: location> specify the full path I<location> of the CSV file to load. If I<location> is of the form: S<path/filename.suffix>, the default --unless it is overridden by the user or for specific tables (such as I<Reference> and I<System>-- is to TODO

TODO complete

=item S<column: usedname>

=back

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

=item if a given entry is both in I<Reference> and I<System> it is I<mapped> (the I<System>'s I<Score> and I<Decision> columns as well as the I<Reference>'s I<Targ> column are used to specify the I<Trial>'s I<sysScore>, I<decision> and I<isTarg> information).

=item if an entry is only in <System>, it is an I<unmapped_sys> entry (the I<System>'s I<Score> and I<Decision> columns specify the I<Trial>'s I<sysScore> and I<decision> information, I<isTarg> is always 0 in this case).

=item if an entry is only in I<Reference> it is an I<unmapped_ref> entry, but only I<y>es I<Targ> entries are added as I<OMMITTED> I<Trial>.

=back

I<DETCurve>s are then generated using the I<Trials> using the I<MetricNormLinearCostFunct> specified I<Metric> (and the specified I<UsedMetricParameters>) 
Each file starting with I<outdir/scoreDB_DET> is one of those results:

=over

=item I<outdir/scoreDB_DET.scores.txt> contains the I<DETCurve>'s I<Performance Summary Over and Ensemble of Subsets>

=item I<outdir/scoreDB_DET.csv> is a Comma Separated Value dump of the previous data's table.

=item Files starting with I<outidr/scoreDB_DET.det> are used by and for the graphic representation of the curve points:

=over

=item files with a I<.dat.X> suffix (where I<X> is a numerical value) are S<gnuplot> data files. 

=item files with a I<.plt> suffix are S<gnuplot> command files

=item files with a I<.png> suffix are I<Portable Network Graphics> image files results from the corresponding I<.plt> S<gnuplot> commands files

=item files with a I<.srl> (or I<.srl.gz>) suffix are I<serialized> I<DETCurve> files and can be used as input to tools such as S<DETUtil> to merge multiple curves together

=back

=back

=item Notes:

=over

=item A I<outdir/_logs> is created and populated by each step, so that files starting with I<CfgGen_> and I<DBgen_> are generated respectively during Step 1 and 2, I<filterDB.log> during Step 3 and I<scoreDB.log> during Step 4. In case a file of the expected name is already present, a tag consisting of S<-YYYYMMDD-HHMMSS> (year, month, day, hour, minute, seconds) will be added to the newly created log file.

=item It is possible to I<bypass> entirely some steps. For example:

=over

=item B<DEVA_cli --outdir outdir --refcsv ref.csv --syscsv sys.csv md.csv --CreateDBSkip --filterSkip --DETScoreSkip>

Will only create the configuration files, but not the database, or run the filter or scorer. This is useful if one wants to edit the I<outdir/metadataDB.cfg> file to rename some columns or look at the automatic renaming of some metadata table (adapted from the file name) or columns names (to avoid SQLite unauthorized characters) in order to adapt the filter step.

Note that since the location of the CSV files is embedded within the config files, one can not do the following after running the previous command:

B<DEVA_cli --outdir outdir --refcsv ref2.csv --syscsv sys2.csv md2.csv --configSkip --filterSkip --DETScoreSkip>

I<ref2.csv>, I<sys2.csv> and I<md2.csv> will not be used by the database creation process (Step 2), since I<ref.csv>, I<sys.csv> and I<md.csv> are specified in the S<csvfile:> line of the respective config file.

TODO more examples

=back

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

$0 [--help | --man | --version] --outdir dir [--configSkip] [--CreateDBSkip] [--filterSkip] [--DETScoreSkip] [--refcsv csvfile] [--syscsv csvfile] [--wREFcfg file] [--WSYScfg file] [--VMDcfg file] [--RefDBfile file] [--SysDBfile file] [--MetadataDBfile file] [--FilterCMDfile SQLite_commands_file] [--AdditionalFilterDB file:name [--AdditionalFilterDB file:name [...]]] [--usedMetric package] [--UsedMetricParameters parameter=value [--UsedMetricParameters parameter=value [...]] [--TrialsParameters parameter=value [--TrialsParameters parameter=value [...]]] [--listParameters] [--detName name] [--xmin val] [--Xmax val] [--ymin val] [--Ymax val] [--zusedXscale set] [--ZusedYscale set] [--additionalResDBfile file [--additionalResDBfile file [...]]] [csvfile [csvfile [...]]

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
  --RefDBfile  Specify the Reference SQLite database file
  --SysDBfile  Specify the System SQLite database file
  --MetadataDBfile  Specify the metadata SQLite database file
Filter (Step 3) specific options:
  --FilterCMDfile  Specify the SQLite command file
  --AdditionalFilterDB  Load additional SQLite database 'file' for the filtering step (loaded as 'name')
DETCurve generation (Step 4) specific options:
  --usedMetric    Package to load for metric uses (if none provided, default used: $defusedmetric)
  --UsedMetricParameters Metric Package parameters
  --TrialsParameters Trials Package parameters
  --listParameters   List Metric and Trial package authorized parameters
  --detName          Specify the name added to the DET curve (as well as the specialzied file generated for this process) (*1)
  --xmin --Xmax      Specify the min and max value of the X axis (PFA) of the DET curve (*1)
  --ymin --Ymax      Specify the min and max value of the Y axis (PMiss) of the DET curve (*1)
  --zusedXscale --ZusedYscale    Specify the scale used for the X and Y axis of the DET curve (Possible values: $pv) (*1)
  --additionalResDBfile  Additional Filter results database files to give the scorer (will do an AND on the TrialIDs)

*1: default values can be obtained from \"$deva_sci\" 's help

EOF
;

  return($tmp);
}

