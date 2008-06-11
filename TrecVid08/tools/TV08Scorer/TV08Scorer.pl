#!/usr/bin/env perl

# TrecVid08 Scorer
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Scorer" is an experimental system.
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

my $versionid = "TrecVid08 Scorer (Version: $version)";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $tv08pl, $tv08plv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = $ENV{$f4b} . "/lib";
  $tv08pl = "TV08_PERL_LIB";
  $tv08plv = $ENV{$tv08pl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";

# MMisc (part of this tool)
unless (eval "use MMisc; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"TrecVid08ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# TrecVid08ECF (part of this tool)
unless (eval "use TrecVid08ECF; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"TrecVid08ECF\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# TrecVid08EventList (part of this tool)
unless (eval "use TrecVid08EventList; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"TrecVid08EventList\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# MetricTV08 (part of this tool)
unless (eval "use MetricTV08; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"MetricTV08\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# BipartiteMatch (part of this tool)
unless (eval "use BipartiteMatch; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"BipartiteMatch\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# Trials (part of this tool)
unless (eval "use Trials; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"Trials\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# TrialSummaryTable (part of this tool)
unless (eval "use TrialSummaryTable; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"TrialSummaryTable\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# SimpleAutoTable (part of this tool)
unless (eval "use SimpleAutoTable; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"SimpleAutoTable\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# DETCurve (part of this tool)
unless (eval "use DETCurve; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"DETCurve\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }


# DETCurveSet (part of this tool)
unless (eval "use DETCurveSet; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"DETCurveSet\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1")
  {
    warn_print
      (
       "\"Getopt::Long\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
      );
    $have_everything = 0;
  }

# Something missing ? Abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
my @ok_events = $dummy->get_full_events_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

# Get some values from TrecVid08ECF
my $ecfobj = new TrecVid08ECF();
my @ecf_xsdfilesl = $ecfobj->get_required_xsd_files_list();

##########

# Required parameters

my $E_d = 1E-6;
my $E_t = 1E-8;

########################################
# Options processing

my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $usage = &set_usage();

# Default values for variables
my $show = 0;
my $showi = 0;
my $perfStat = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $fps = -1;
my $gtfs = 0;
my $delta_t = undef;
my $ecffile = "";
my $duration = 0;
my $doDC = 0;
my $gzipPROG = "gzip";
my $gnuplotPROG = "gnuplot";
my $noPNG = 0;
my $sysTitle = "";
my $outputRootFile = undef;
my $observationContingencyTable = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:    DEFG       O   ST     Z  cdefgh     nop  st v x  

my %opt;
my $dbgftmp = "";
my @leftover;
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => sub {$gtfs++; @leftover = @ARGV},
   'fps=s'           => \$fps,
   'deltat=f'        => \$delta_t,
   'Ed=f'            => \$E_d,
   'Et=f'            => \$E_t,
   'show'            => \$show,
   'perfStat'        => \$perfStat,
   'Duration=f'      => \$duration,
   'ecf=s'           => \$ecffile,
   'computeDETCurve' => \$doDC,
   'ZipPROG=s'       => \$gzipPROG,
   'GnuplotPROG=s'   => \$gnuplotPROG,
   'noPNG'           => \$noPNG,
   'titleOfSys=s'    => \$sysTitle,
   'OutputFileRoot=s' => \$outputRootFile,
   'observationCont' => \$observationContingencyTable,
   # Hidden option
   'Show_internals+' => \$showi,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

ok_quit("\n$usage\n") if ($opt{'help'});
ok_quit("$versionid\n") if ($opt{'version'});

ok_quit("\n$usage\n") if (scalar @ARGV == 0);

error_quit("\'fps\' must set in order to do any scoring work") if ($fps == -1);
error_quit("\'delta_t\' must set in order to do any scoring work") if (! defined $delta_t);

if ($xmllint ne "") {
  error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

error_quit("Only one \'gtf\' separator allowed per command line, aborting")
  if ($gtfs > 1);

my ($rref, $rsys) = &get_sys_ref_filelist(\@leftover, @ARGV);
my @ref = @{$rref};
my @sys = @{$rsys};
error_quit("No SYS file(s) provided, can not perform scoring")
  if (scalar @sys == 0);
error_quit("No REF file(s) provided, can not perform scoring")
  if (scalar @ref == 0);

error_quit("Option OutputFileRoot required to compute produce the PNGs")
    if ($doDC && !$noPNG && (!defined($outputRootFile)));

########## Main processing
my $stepc = 1;

## Load Pre-processing
print "***** STEP ", $stepc++, ": Loading files in Memory\n";
my ($sysdone, $systodo, %sys_hash) = &load_preprocessing(0, @sys);
my ($refdone, $reftodo, %ref_hash) = &load_preprocessing(1, @ref);

my $ndone = $sysdone + $refdone;
my $ntodo = $systodo + $reftodo;

print "\n** SUMMARY: All files loaded\n";
print "** REF: $systodo files (", ($sysdone == $systodo) ? "all" : $sysdone, " ok)\n";
print "** SYS: $reftodo files (", ($refdone == $reftodo) ? "all" : $refdone, " ok)\n\n";
error_quit("Can not continue, not all files passed the loading/validation step, aborting\n")
  if ($ndone != $ntodo);

## Loading of the ECF file
my $useECF = (MMisc::is_blank($ecffile)) ? 0 : 1;
if ($useECF) {
  print "\n\n***** STEP ", $stepc++, ": Loading the ECF file\n";
  $ecfobj->set_default_fps($fps);
  error_quit("Problem setting the ECF object's default FPS (" . $ecfobj->get_errormsg() . ")")
    if ($ecfobj->error());
  my ($errmsg) = &load_ecf($ecffile, $ecfobj);
  error_quit("Problem loading the ECF file: $errmsg")
    if (! MMisc::is_blank($errmsg));
  my $td = $ecfobj->get_duration();
  error_quit("Problem obtaining the ECF duration (" . $ecfobj->get_errormsg() . ")")
    if ($ecfobj->error());
  if ($duration == 0) {
    $duration = $td;
  } else {
    warn_print("Command line \'Duration\' ($duration) overrides (for scoring) the one found in the ECF file ($td)")
      if ($td != $duration);
  }
  print "\n** SUMMARY: ECF file loaded\n";
  print $ecfobj->txt_summary();
#  $ecfobj->_display();
}

## Generate event lists
print "\n\n***** STEP ", $stepc++, ": Generating EventLists",
  (($useECF) ? " (only adding observations matching loaded ECF)" : ""), "\n";
my $tmpecfobj = ($useECF) ? $ecfobj : undef;
my $sysEL = &generate_EventList("SYS", $tmpecfobj, %sys_hash);
my $refEL = &generate_EventList("REF", $tmpecfobj, %ref_hash);
## Can we score after all ?
my ($rc, $rs, $rr) = $sysEL->comparable_filenames($refEL);
error_quit("While trying to obtain a list of scorable referred to files (" . $sysEL->get_errormsg() .")")
  if ($sysEL->error());
my @common = @{$rc};
my @only_in_sys = @{$rs};
my @only_in_ref = @{$rr};
print "\n** SUMMARY: All EventLists generated\n";
print "** Common referred to files (", scalar @common, "): ", join(" ", @common), "\n";
print "** Only in SYS (", scalar @only_in_sys, "): ", join(" ", @only_in_sys), "\n";
print "** Only in REF (", scalar @only_in_ref, "): ", join(" ", @only_in_ref), "\n\n";
my $fcount = (scalar @common) + (scalar @only_in_sys) + (scalar @only_in_ref);
error_quit("Can not continue, no file in any list ?") if ($fcount == 0);

## Prepare event lists for scoring
print "\n\n***** STEP ", $stepc++, ": Scoring\n";
$sysEL->set_delta_t($delta_t);
$sysEL->set_E_t($E_t);
$sysEL->set_E_d($E_d);
my @kp = $sysEL->get_kernel_params();
error_quit("Error while obtaining the EventList kernel function parameters (" . $sysEL->get_errormsg() . ")")
  if ($sysEL->error());

my %all_bpm;
my %metrics_params = ( TOTALDURATION => $duration ) ;
my @all_events;
my $key_allevents= "AllEvents";
push @all_events, $key_allevents;
push @all_events, @ok_events;
my %all_trials;
my %all_metric;
my %trials_c;
foreach my $event (@all_events) {
  my $trial = new Trials("Event Detection", "Event", "Observation", \%metrics_params);
  $all_trials{$event} = $trial;
  $all_metric{$event} = new MetricTV08({ ('CostMiss' => 10, 'CostFA' => 1, 'Rtarget' => 1.8 ) }, $trial);
}
my $gtrial = $all_trials{$key_allevents};

print "** Aligning Files\n";
&do_alignment(@common, @only_in_sys, @only_in_ref);

if ($trials_c{$key_allevents} == 0) {
  error_quit("No Trials ever added");
}

if ($observationContingencyTable) {
## Dump Trial Contingency Table
  print "\n\n***** STEP ", $stepc++, ": Dump of Trial Contingency Table\n";
  MMisc::writeTo($outputRootFile, ".contigency.txt", 1, 0, $all_trials{$key_allevents}->dumpCountSummary());
}

print "\n\n***** STEP ", $stepc++, ": Dump of Analysis Report\n";
my $detSet = new DETCurveSet($sysTitle);
  
print " (only printing seen events)\n\n";
foreach my $event (@all_events) {
    next if ($trials_c{$event} == 0);
    next if ($event eq $key_allevents);
    my $trials = $all_trials{$event};
    my $metric = $all_metric{$event};
    # print "** Computing DET Curves for event: $event\n";
    my $det = new DETCurve($trials, $metric, "blocked", "Event $event: ". $sysTitle, [()], $gzipPROG);
    if ($det->getMessages() ne "") { 
        print $det->getMessages();
    }
    my $rtn = $detSet->addDET($event." Event", $det);
    error_quit("Error adding Event '$event' to the DETSet: $rtn") if ($rtn ne "success");                     
  }

MMisc::writeTo($outputRootFile, ".scores.txt", 1, 0, 
               $detSet->renderAsTxt($outputRootFile.".det", $doDC, 1, 
                                    { (xScale => "log", Ymin => "0.00001", Ymax => "90", Xmin => "0.00001", Xmax => "100", 
                                       gnuplotPROG => $gnuplotPROG, BuildPNG => ($noPNG ? 0 : 1)) }));

#my $trials->dump(*STDOUT);

#### TODO #####


ok_quit("\n\n***** Done *****\n");

########## END

########################################

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $ecf_xsdf = join(" ", @ecf_xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 --deltat deltat --fps fps [--Duration seconds] [--ecf ecffile]  [--help] [--version] [--showAT] [--perfStat] [--computeDETCurve rfile] [--xmllint location] [--TrecVid08xsd location] [-Ed value] [-Et value] sys_file.xml [sys_file.xml [...]] -gtf ref_file.xml [ref_file.xml [...]]

Will Score the XML file(s) provided (Truth vs System)

 Where:
  --gtf           Specify that the files post this marker on the command line are Ground Truth Files
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --Duration      Specify the scoring duration for the Metric (warning: override any ECF file)
  --ecf           Specify the ECF file to load and perform scoring against
  --deltat        Set the deltat value
  --Et / Ed       Change the default values for Et / Ed (Default: $E_t / $E_d)
  --showAT        Show Alignment Table (per File/Event processed)
  --perfStat      Dump Performance Statistics
  --computeDETCurve  Generate DETCurve (requires GNUPlot and PNG support)
  --version       Print version number and exit
  --GnuplotPROG   Specify the full path name to gnuplot.  Default is to have 'gnuplot' in your path 
  --ZipPROG       Specify the full path name to gzip.  Default is to have 'gzip' in your path
  --noPNG         Do not create PNGs if a DET Curve is computed 
  --titleOfSys    Specifiy the title of the system for use in the reports
  --help          Print this usage information and exit

Note:
- Program will ignore the <config> section of the XML file.
- List of recognized events: $ro
- 'TrecVid08xsd' files are: $xsdfiles (and if the 'ecf' option is used, also: $ecf_xsdf)
EOF
;

  return $tmp;
}

####################

sub warn_print {
  print "WARNING: ", @_;

  print "\n";
}

##########

sub error_quit {
  print("${ekw}: ", @_);

  print "\n";
  exit(1);
}

##########

sub ok_quit {
  print @_;

  print "\n";
  exit(0);
}

########################################

sub get_sys_ref_filelist {
  my $rlo = shift @_;
  my @args = @_;

  my @lo = @{$rlo};

  @args = reverse @args;
  @lo = reverse @lo;

  my @ref;
  my @sys;
  while (my $l = shift @lo) {
    if ($l eq $args[0]) {
      push @ref, $l;
      shift @args;
    }
  }
  @ref = reverse @ref;
  @sys = reverse @args;

return (\@ref, \@sys);
}

########################################

sub valok {
  my ($fname, $isgtf, $txt) = @_;

  print "(" . ($isgtf ? "REF" : "SYS") . ") $fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $isgtf, $txt) = @_;

  &valok($fname, $isgtf, "[ERROR] $txt");
}

##########

sub load_preprocessing {
  my ($isgtf, @filelist) = @_;

  my $tmp;
  my %all = ();
  my $ntodo = scalar @filelist;
  my $ndone = 0;
  while ($tmp = shift @filelist) {
    if (! -e $tmp) {
      &valerr($tmp, $isgtf, "file does not exists, skipping");
      next;
    }
    if (! -f $tmp) {
      &valerr($tmp, $isgtf, "is not a file, skipping\n");
      next;
    }
    if (! -r $tmp) {
      &valerr($tmp, $isgtf, "file is not readable, skipping\n");
      next;
    }

    # Prepare the object
    my $object = new TrecVid08ViperFile();
    error_quit("While trying to set \'xmllint\' (" . $object->get_errormsg() . ")")
      if ( ($xmllint ne "") && (! $object->set_xmllint($xmllint)) );
    error_quit("While trying to set \'TrecVid08xsd\' (" . $object->get_errormsg() . ")")
      if ( ($xsdpath ne "") && (! $object->set_xsdpath($xsdpath)) );
    error_quit("While setting \'gtf\' status (" . $object->get_errormsg() . ")")
      if ( ($isgtf) && ( ! $object->set_as_gtf()) );
    error_quit("While setting \'fps\' ($fps) (" . $object->get_errormsg() . ")")
      if ( ! $object->set_fps($fps) );
    error_quit("While setting \'file\' ($tmp) (" . $object->get_errormsg() . ")")
      if ( ! $object->set_file($tmp) );

    # Validate (important to confirm that we can have a memory representation)
    if (! $object->validate()) {
      &valerr($tmp, $isgtf, $object->get_errormsg());
      next;
    } else {
      &valok($tmp, $isgtf, "Loaded");
    }

    # This is really if you are a debugger
    print("** Memory Representation:\n", $object->_display_all()) if ($showi > 1);

    # This is really if you are a debugger
    if ($showi > 2) {
      print("** Observation representation:\n");
      foreach my $i (@ok_events) {
	print("-- EVENT: $i\n");
	my @bucket = $object->get_event_observations($i);
	error_quit("While \'get_event\'observations\' (" . $object->get_errormsg() .")")
	  if ($object->error());
	foreach my $obs (@bucket) {
	  print $obs->_display();
	}
      }
    }

    $all{$tmp} = $object;
    $ndone++;
  }

  return($ndone, $ntodo, %all);
}

########################################

sub generate_EventList {
  my ($mode, $lecfobj, %ohash) = @_;

  my $tmpEL = new TrecVid08EventList();
  error_quit("Problem creating the $mode EventList (" . $tmpEL->get_errormsg() . ")")
    if ($tmpEL->error());

  my $rej_val = $tmpEL->Observation_Rejected();
  my $acc_val = $tmpEL->Observation_Added();
  my $spa_val = $tmpEL->Observation_SpecialAdd();
  error_quit("Problem obtaining EventList's Observation \'Added\', \'SpecialAdd\' or \'Rejected\' values (" . $tmpEL->get_errormsg() . ")")
    if ($tmpEL->error());
  if (defined $lecfobj) {
    error_quit("Problem tying $mode EventList to ECF " . $tmpEL->get_errormsg() . ")")
      if (! $tmpEL->tie_to_ECF($lecfobj));
  }

  my $added = 0;
  my $rejected = 0;
  my $sfile = 0;
  my $tobs = 0;
  foreach my $key (keys %ohash) {
    my $vf = $ohash{$key};

    my @ao = $vf->get_all_events_observations();
    error_quit("Problem obtaining all Observations from $mode ViperFile object (" . $vf->get_errormsg() . ")")
      if ($vf->error());

    foreach my $o (@ao) {
      my $status = $tmpEL->add_Observation($o);
      error_quit("Problem adding Observation to $mode EventList (" . $tmpEL->get_errormsg() . ")")
	if ($tmpEL->error());

#      print "[$status] ";
      my $toadd = 1;
      if ($status == $rej_val) {
	$rejected++;
      } elsif ($status == $acc_val) {
	$added++;
      } elsif ($status == $spa_val) {
	$toadd = 0;
      } else {
	error_quit("Weird EventList \'add_Observation\' return code ($status) at this stage");
      }
      $tobs += $toadd;
    }
    $sfile++;
  }

  print "* $mode EventList: $added Observation(s) added";
  print " ($rejected rejected)" if (($rejected > 0) || (defined $lecfobj));
  print " [Seen $tobs Observations inside $sfile file(s)]";
  print "\n";

  return($tmpEL);
}

########################################

sub uniquer {
  my @all = @_;

  my %it;
  foreach my $e (@all) {
    $it{$e}++;
  }

  my @u = keys %it;

  return(@u);
}

####################

sub Obs_array_to_hash {
  my @all = @_;

  my %ohash;

  foreach my $o (@all) {
    my $key = $o->get_unique_id();
    error_quit("While trying to obtain a unique Observation id (". $o->get_errormsg() . ")")
      if ($o->error());

    error_quit("WEIRD: This key ($key) already exists, was this file already loaded ?")
      if (exists $ohash{$key});

    $ohash{$key} = $o;
  }

  return(%ohash);
}

############################################################

sub do_alignment {
  my @todo = @_;

  my $ksep = 0;
  
  ##### Add values to the 'Trials' (and 'SimpleAutoTable')
  my $alignmentRep = new SimpleAutoTable();
  if (! $alignmentRep->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" })){
     print "Error building alignment table: ".$alignmentRep->get_errormsg()."\n";
   }

  foreach my $file (@todo) {
    my @sys_events = ($sysEL->is_filename_in($file)) ? $sysEL->get_events_list($file) : ();
    error_quit("While trying to obtain a list of SYS events for file ($file) (" . $sysEL->get_errormsg() . ")")
      if ($sysEL->error());
    my @ref_events = ($refEL->is_filename_in($file)) ? $refEL->get_events_list($file) : ();
    error_quit("While trying to obtain a list of REF events for file ($file) (" . $refEL->get_errormsg() . ")")
      if ($refEL->error());

    my @listed_events = &uniquer(@sys_events, @ref_events);

    foreach my $evt (@listed_events) {
      my @sys_events_obs = ($sysEL->is_filename_in($file)) ? $sysEL->get_Observations_list($file, $evt) : ();
      error_quit("While trying to obtain a list of observations for SYS event ($evt) and file ($file) (" . $sysEL->get_errormsg() . ")")
	if ($sysEL->error());
      my @ref_events_obs = ($refEL->is_filename_in($file)) ? $refEL->get_Observations_list($file, $evt) : ();
      error_quit("While trying to obtain a list of observations for REF event ($evt) and file ($file) (" . $refEL->get_errormsg() . ")")
	if ($refEL->error());

      my %sys_bpm = &Obs_array_to_hash(@sys_events_obs);
      my %ref_bpm = &Obs_array_to_hash(@ref_events_obs);

      my $tomatch = scalar @sys_events_obs + scalar @ref_events_obs;
      print "|-> Filename: $file | Event: $evt | SYS elements: ", scalar @sys_events_obs, " | REF elements: ", scalar @ref_events_obs, " | Total Observations: $tomatch elements\n";
      my $bpm = new BipartiteMatch(\%ref_bpm, \%sys_bpm, \&TrecVid08Observation::kernel_function, \@kp);
      error_quit("While creating the Bipartite Matching object for event ($evt) and file ($file) (" . $bpm->get_errormsg() . ")")
	if ($bpm->error());

      $bpm->compute();
      error_quit("While computing the Bipartite Matching for event ($evt) and file ($file) (" . $bpm->get_errormsg() . ")")
	if ($bpm->error());

      # I am the coder, I know what I want to display/debug ... trust me !
      $bpm->_display("joint_values") if ($showi > 1);
      $bpm->_display("mapped", "unmapped_ref", "unmapped_sys") if ($showi);

      my $trials = $all_trials{$evt};

      # First, the mapped sys observations
      my @mapped = $bpm->get_mapped_objects();
      error_quit("Problem obtaining the mapped objects from the BPM (" . $bpm->get_errormsg() . ")")
	if ($bpm->error());
      foreach my $mop (@mapped) {
	my ($sys_obj, $ref_obj) = @{$mop};

	my $detscr = $sys_obj->get_DetectionScore();
	my $detdec = $sys_obj->get_DetectionDecision();
	error_quit("Could not obtain some of the Observation's information (" . $sys_obj->get_errormsg() . ")")
	  if ($sys_obj->error());

	$trials->addTrial($evt, $detscr, ($detdec) ? "YES" : "NO", 1);
	$trials_c{$evt}++;
	$gtrial->addTrial($evt, $detscr, ($detdec) ? "YES" : "NO", 1); 
	$trials_c{$key_allevents}++;
	# The last '1' is because the elements match an element in the ref list (target)

	my $trialID = &make_trialID($file, $evt, $ref_obj, $sys_obj, $ksep++);
	$alignmentRep->addData($file, "File", $trialID);
	$alignmentRep->addData($evt, "Event", $trialID);
	$alignmentRep->addData("Mapped", "TYPE", $trialID);
	$alignmentRep->addData(&get_obj_id($ref_obj), "R.ID", $trialID);
	$alignmentRep->addData(&get_obj_fs_value($ref_obj), "R.range", $trialID);
	$alignmentRep->addData(&get_obj_fs_duration($ref_obj),  "Dur.r", $trialID);
	$alignmentRep->addData(&get_obj_id($sys_obj), "S.ID", $trialID);
	$alignmentRep->addData(&get_obj_fs_value($sys_obj), "S.range", $trialID);
	$alignmentRep->addData(&get_obj_fs_duration($sys_obj),  "Dur.s", $trialID);
	$alignmentRep->addData($detscr, "S.DetScr", $trialID);
	$alignmentRep->addData($detdec ? "YES" : "NO", "S.DetDec", $trialID);
	my $ov = &get_obj_fs_ov($ref_obj, $sys_obj);
	$alignmentRep->addData((defined($ov) ? &get_fs_value($ov) : "NULL"), "ISec.range", $trialID);
	$alignmentRep->addData((defined($ov) ? &get_fs_duration($ov): "NULL"), "Dur.ISec", $trialID);
	my ($rb, $re) = &get_obj_fs_beg_end($ref_obj);
	my ($sb, $se) = &get_obj_fs_beg_end($sys_obj);
	$alignmentRep->addData($rb - $sb, "Beg.r-Beg.s", $trialID);
	$alignmentRep->addData($re - $se, "End.r-End.s", $trialID);
      }

      # Second, the False Alarms
      my @unmapped_sys = $bpm->get_unmapped_sys_objects();
      error_quit("Problem obtaining the unmapped_sys objects from the BPM (" . $bpm->get_errormsg() . ")")
	if ($bpm->error());
      foreach my $sys_obj (@unmapped_sys) {
	my $detscr = $sys_obj->get_DetectionScore();
	my $detdec = $sys_obj->get_DetectionDecision();
	error_quit("Could not obtain some of the Observation's information (" . $sys_obj->get_errormsg() . ")")
	  if ($sys_obj->error());

	$trials->addTrial($evt, $detscr, ($detdec) ? "YES" : "NO", 0);
	$trials_c{$evt}++;
	$gtrial->addTrial($evt, $detscr, ($detdec) ? "YES" : "NO", 0);
	$trials_c{$key_allevents}++;
	# The last '0' is because the elements does not match an element in the ref list (target)

	my $trialID = &make_trialID($file, $evt, undef, $sys_obj, $ksep++);
	$alignmentRep->addData($file, "File", $trialID);
	$alignmentRep->addData($evt, "Event", $trialID);
	$alignmentRep->addData("Unmapped_Sys", "TYPE", $trialID);
	$alignmentRep->addData("", "R.ID", $trialID);
	$alignmentRep->addData("", "R.range", $trialID);
	$alignmentRep->addData("", "Dur.r", $trialID);
	$alignmentRep->addData(&get_obj_id($sys_obj), "S.ID", $trialID);
	$alignmentRep->addData(&get_obj_fs_value($sys_obj), "S.range", $trialID);
	$alignmentRep->addData(&get_obj_fs_duration($sys_obj), "Dur.s", $trialID);
	$alignmentRep->addData($detscr, "S.DetScr", $trialID);
	$alignmentRep->addData($detdec ? "YES" : "NO", "S.DetDec", $trialID);
	$alignmentRep->addData("", "ISec.range", $trialID);
	$alignmentRep->addData("", "Dur.ISec", $trialID);
	$alignmentRep->addData("", "Beg.r-Beg.s", $trialID);
	$alignmentRep->addData("", "End.r-End.s", $trialID);
      }

      # Third, the Missed Detects
      my @unmapped_ref = $bpm->get_unmapped_ref_objects();
      error_quit("Problem obtaining the unmapped_ref objects from the BPM (" . $bpm->get_errormsg() . ")")
	if ($bpm->error());
      foreach my $ref_obj (@unmapped_ref) {
	$trials->addTrial($evt, undef, "OMITTED", 1);
	$trials_c{$evt}++;
	$gtrial->addTrial($evt, undef, "OMITTED", 1);
	$trials_c{$key_allevents}++;
	# Here we only care about the number of entries in this array

	my $trialID = &make_trialID($file, $evt, $ref_obj, undef, $ksep++);
	$alignmentRep->addData($file, "File", $trialID);
	$alignmentRep->addData($evt, "Event", $trialID);
	$alignmentRep->addData("Unmapped_Ref", "TYPE", $trialID);
	$alignmentRep->addData(&get_obj_id($ref_obj), "R.ID", $trialID);
	$alignmentRep->addData(&get_obj_fs_value($ref_obj), "R.range", $trialID);
	$alignmentRep->addData(&get_obj_fs_duration($ref_obj), "Dur.r", $trialID);
	$alignmentRep->addData("", "S.DetScr", $trialID);
	$alignmentRep->addData("", "S.DetDec", $trialID);
	$alignmentRep->addData("", "S.ID", $trialID);
	$alignmentRep->addData("", "S.range", $trialID);
	$alignmentRep->addData("", "Dur.s", $trialID);
	$alignmentRep->addData("", "ISec.range", $trialID);
	$alignmentRep->addData("", "Dur.ISec", $trialID);
	$alignmentRep->addData("", "Beg.r-Beg.s", $trialID);
	$alignmentRep->addData("", "End.r-End.s", $trialID);
      }
      # 'Trials' done

      $all_bpm{$file}{$evt} = $bpm;
      
      my $matched = (2 * scalar @mapped)
	+ scalar @unmapped_sys + scalar @unmapped_ref;
      print " -- Summary: ",
	scalar @mapped, " Mapped (Pairs) / ",
	  scalar @unmapped_sys, " Unmapped Sys  / ",
	    scalar @unmapped_ref, " Unmapped Ref | Total Observations: $matched elements\n\n";
      error_quit("WEIRD: To match ($tomatch) != Matched ($matched) ?")
	if ($tomatch != $matched);
    }
  }

  if ($show){
     my $tbl = $alignmentRep->renderTxtTable(2);
     if (! defined($tbl)){
        print "Error Generating Alignment Report:\n". $alignmentRep->get_errormsg();
     }
     MMisc::writeTo($outputRootFile, ".ali.txt", 1, 0, $tbl);
     if (defined($outputRootFile) && $outputRootFile ne ""){
        my $tbl = $alignmentRep->renderCSV(2);
        if (! defined($tbl)){
           print "Error Generating Alignment Report:\n". $alignmentRep->get_errormsg();
         }
        MMisc::writeTo($outputRootFile, ".ali.csv", 1, 0, $tbl);
      }
   }
}

#####

sub get_fs_value {
  my ($fs_fs) = @_;

  my $v = $fs_fs->get_value();
  error_quit("Error obtaining the framespan's value (" . $fs_fs->get_errormsg() . ")")
    if ($fs_fs->error());

  return($v);
}  

#####

sub get_fs_duration {
  my ($fs_fs) = @_;

  my $d = $fs_fs->duration();
  error_quit("Error obtaining the framespan's duration (" . $fs_fs->get_errormsg() . ")")
    if ($fs_fs->error());

  return($d);
}  

#####

sub get_obj_fs {
  my ($obj) = @_;

  error_quit("Can not call \'get_framespan\' on an undefined object")
    if (! defined $obj);

  my $fs_fs = $obj->get_framespan();
  error_quit("Error obtaining the object's framespan (" . $obj->get_errormsg() . ")")
    if ($obj->error());

  return($fs_fs);
}

#####

sub get_obj_fs_value {
  my ($obj) = @_;

  error_quit("Can not obtain a framespan value for an undefined object")
    if (! defined $obj);

  my $fs_fs = &get_obj_fs($obj);

  return(&get_fs_value($fs_fs));
}

#####

sub get_obj_fs_duration {
  my ($obj) = @_;

  error_quit("Can not obtain a framespan duration for an undefined object")
    if (! defined $obj);

  my $fs_fs = &get_obj_fs($obj);

  return(&get_fs_duration($fs_fs));
}

#####

sub get_obj_fs_ov {
  my ($obj1, $obj2) = @_;

  error_quit("Can not obtain overlap for undefined objects")
    if ((! defined $obj1) || (! defined $obj2));

  my $fs_fs1 = &get_obj_fs($obj1);
  my $fs_fs2 = &get_obj_fs($obj2);

  my $ov = $fs_fs1->get_overlap($fs_fs2);
  error_quit("Error obtaining overlap (" . $fs_fs1->get_errormsg() . ")")
    if ($fs_fs1->error());

  return($ov);
}

#####

sub get_obj_fs_beg_end {
  my ($obj) = @_;

  error_quit("Can not obtain framespan beg/end for undefined object")
    if (! defined $obj);

  my $fs_fs = &get_obj_fs($obj);

  my ($b, $e) = $fs_fs->get_beg_end_fs();
  error_quit("Error obtaining framespan's beg/end (" . $fs_fs->get_errormsg() . ")")
    if ($fs_fs->error());

  return($b, $e);
}

#####

sub get_obj_id {
  my ($obj) = @_;

  error_quit("Can not obtain framespan beg/end for undefined object")
    if (! defined $obj);

  my $id = $obj->get_id();
  error_quit("Error obtaining object's ID (" . $obj->get_errormsg() . ")")
    if ($obj->error());

  return($id)
}

#####

sub _num {return ($a <=> $b);}

#####

sub make_trialID {
  my ($fn, $evt, $ref_obj, $sys_obj, $ksep) = @_;

  my @ar;

  push @ar, &get_obj_fs_beg_end($ref_obj) if (defined $ref_obj);
  push @ar, &get_obj_fs_beg_end($sys_obj) if (defined $sys_obj);

  my @o = sort _num @ar;

  my $txt = sprintf("Filename: $fn | Event: $evt | MIN: %012d | MAX: %012d | KeySeparator: %012d", $o[0], $o[-1], $ksep);

  return($txt);
}

############################################################

sub load_ecf {
  my ($ecffile, $ecfobj) = @_;

  return("file does not exists")
    if (! -e $ecffile);

  return("is not a file")
    if (! -f $ecffile);

  return("file is not readable")
    if (! -r $ecffile);

  error_quit("While trying to set \'xmllint\' (" . $ecfobj->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $ecfobj->set_xmllint($xmllint)) );
  error_quit("While trying to set \'TrecVid08xsd\' (" . $ecfobj->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $ecfobj->set_xsdpath($xsdpath)) );
  error_quit("While setting \'file\' ($ecffile) (" . $ecfobj->get_errormsg() . ")")
    if ( ! $ecfobj->set_file($ecffile) );

  # Validate (important to confirm that we can have a memory representation)
  return("file did not validate (" . $ecfobj->get_errormsg() . ")")
    if (! $ecfobj->validate());

  return("");
}
