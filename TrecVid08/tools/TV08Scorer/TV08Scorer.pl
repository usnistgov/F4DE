#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 Scorer
#
# Author(s): Martial Michel, Jonathan Fiscus
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
my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../lib", "../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "TrecVid08ViperFile", "TrecVid08ECF", "TrecVid08EventList", "KernelFunctions", "MetricTV08", "BipartiteMatch", "Trials", "TrialSummaryTable", "SimpleAutoTable", "DETCurve", "DETCurveSet", "TrecVid08HelperFunctions", "CSVHelper") {
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

my $CostMiss = 10;
my $CostFA = 1;
my $Rtarget = 1.8;

########################################
# Options processing

my $xmllint_env = "F4DE_XMLLINT";
my $mancmd = "perldoc -F $0";
my @xtend_modes = ("copy_sys", "copy_ref", "overlap", "extended"); # Order is important
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $usage = &set_usage();

# Default values for variables
my $showAT = 0;
my $allAT = 0;
my $showi = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../data";
my $fps = undef;
my $gtfs = 0;
my $delta_t = undef;
my $ecffile = "";
my $duration = 0;
my $doDC = 0;
my $gzipPROG = "gzip";
my $gnuplotPROG = "gnuplot";
my $noPNG = 0;
my $nodetfiles = 0;
my $sysTitle = "";
my $outputRootFile = undef;
my $observationContingencyTable = 0;
my $writexml = undef;
my $autolt = 0;
my $ltse = 0;
my @asked_events = ();
my $xtend = "";
my $MemDump = undef;
my @inputAliCSV = ();
my $schc = 0; # Skip CSV Header Check
my $befc = 0; # Bypass ECF Files Check

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: ABCDEFG    LMNO  RST  WX Zab cdefgh  lmnop  st vwx   #

my %opt = ();
my @sys = ();
my @ref = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => sub {$gtfs++;},
   'fps=s'           => \$fps,
   'deltat=f'        => \$delta_t,
   'Ed=f'            => \$E_d,
   'Et=f'            => \$E_t,
   'allAT'           => \$allAT,
   'showAT'          => \$showAT,
   'Duration=f'      => \$duration,
   'ecf=s'           => \$ecffile,
   'computeDETCurve' => \$doDC,
   'ZipPROG=s'       => \$gzipPROG,
   'GnuplotPROG=s'   => \$gnuplotPROG,
   'NoDetFiles'      => \$nodetfiles,
   'noPNG'           => \$noPNG,
   'titleOfSys=s'    => \$sysTitle,
   'OutputFileRoot=s' => \$outputRootFile,
   'observationCont' => \$observationContingencyTable,
   'writexml:s'      => \$writexml,
   'pruneEvents'     => \$autolt,
   'LimittoSYSEvents' => \$ltse,
   'limitto=s'       => \@asked_events,
   'MissCost=f'      => \$CostMiss,
   'CostFA=f'        => \$CostFA,
   'Rtarget=f'       => \$Rtarget,
   'XtraMappedObservations=s' => \$xtend,
   'WriteMemDump:s'  => \$MemDump,
   'AlignmentCSV=s'  => \@inputAliCSV,
   'bypassCSVHeader' => \$schc,
   'BypassECFFilesCheck' => \$befc,
   # Hidden option
   'Show_internals+' => \$showi,
   # Non options (SYS + REF)
   '<>' => sub { if ($gtfs) { push @ref, @_; } else { push @sys, @_; } },
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::ok_quit("\n$usage\n") 
  if ((scalar @ARGV == 0) && (scalar @ref == 0) && (scalar @sys == 0) && (scalar @inputAliCSV == 0));

MMisc::error_quit("Leftover arguments on the command line: " . join(", ", @ARGV))
  if (scalar @ARGV > 0);

MMisc::error_quit("\'fps\' must set in order to do any scoring work") if (! defined $fps);
MMisc::error_quit("\'delta_t\' must set in order to do any scoring work") if (! defined $delta_t);
MMisc::error_quit("\'duration\' must be set unless \'ecf'\ is used") 
  if (($duration == 0) && (MMisc::is_blank($ecffile)));

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

if (defined $MemDump) {
  MMisc::error_quit("\'WriteMemDump\' can only be used in conjunction with \'writexml\'")
    if (! defined $writexml);
  $MemDump = $ok_md[0]
    if (MMisc::is_blank($MemDump));
  MMisc::error_quit("Unknown \'WriteMemDump\' mode ($MemDump), authorized: " . join(" ", @ok_md))
    if (! grep(m%^$MemDump$%, @ok_md));
}

MMisc::error_quit("\'pruneEvents\' is only usable if \'writexml\' is selected")
  if (($autolt) && ( ! defined $writexml));

MMisc::error_quit("\'XtraMappedObservations\' is only usable if \'writexml\' is selected")
  if ((! MMisc::is_blank($xtend)) && (! defined $writexml));
MMisc::error_quit("Wrong \'XtraMappedObservations\' mode ($xtend), authorized modes list: " . join(" ", @xtend_modes))
  if (! grep(m%$xtend$%, @xtend_modes));

MMisc::error_quit("Only one \'gtf\' separator allowed per command line, aborting")
  if ($gtfs > 1);

if (scalar @inputAliCSV == 0) {
  MMisc::error_quit("No SYS file(s) provided, can not perform scoring")
    if (scalar @sys == 0);
  MMisc::error_quit("No REF file(s) provided, can not perform scoring")
    if (scalar @ref == 0);
} else {
  MMisc::error_quit("\'ecf\' can not be used with \'AlignmentCSV\'; \'Duration\' is to be used instead")
    if (! MMisc::is_blank($ecffile));
  MMisc::error_quit("\'Duration\' not set while required when using \'AlignmentCSV\'")
    if ($duration == 0);
}

MMisc::error_quit("\'BypassECFFilesCheck\' can ony be used when \'ecf\' is used")
  if (($befc) && (MMisc::is_blank($ecffile)));

MMisc::error_quit("\'NoDetFiles\' can not be used unless \'noPNG\' is selected too")
  if ((! $noPNG) && $nodetfiles);
MMisc::error_quit("\'OutputFileRoot\' required to produce the \'.det\' files")
  if ($doDC && (! $nodetfiles) && (! defined $outputRootFile));
MMisc::error_quit("\'OutputFileRoot\' required to produce the PNGs")
  if ($doDC && (! $noPNG) && (! defined $outputRootFile));

if (scalar @asked_events == 0) {
  @asked_events = @ok_events;
} else {
  MMisc::error_quit("Can not use \'limitto\' in conjunction with \'LimittoSYSEvents\'")
    if ($ltse);
  @asked_events = $dummy->validate_events_list(@asked_events);
  MMisc::error_quit("While checking \'limitto\' events list (" . $dummy->get_errormsg() .")")
    if ($dummy->error());
}

########## Main processing
my $stepc = 1;
  
my %all_trials = ();
my %all_metric = ();
my $gtrial = undef;
my %trials_c = ();
my $key_allevents= "AllEvents";
my @all_events = ();
my %xmlwriteback = ();
my %metrics_params = ();

if (scalar @inputAliCSV == 0) {
  ## Load Pre-processing
  print "***** STEP ", $stepc++, ": Loading files in Memory\n";
  my ($sysdone, $systodo, %sys_hash) = &load_preprocessing(0, @sys);
  my ($refdone, $reftodo, %ref_hash) = &load_preprocessing(1, @ref);
  
  my $ndone = $sysdone + $refdone;
  my $ntodo = $systodo + $reftodo;
  
  print "\n** SUMMARY: All files loaded\n";
  print "** REF: $systodo files (", ($sysdone == $systodo) ? "all" : $sysdone, " ok)\n";
  print "** SYS: $reftodo files (", ($refdone == $reftodo) ? "all" : $refdone, " ok)\n\n";
  MMisc::error_quit("Can not continue, not all files passed the loading/validation step, aborting\n")
    if ($ndone != $ntodo);
  
  ## Loading of the ECF file
  my $useECF = (MMisc::is_blank($ecffile)) ? 0 : 1;
  if ($useECF) {
    print "\n\n***** STEP ", $stepc++, ": Loading the ECF file\n";
    my ($errmsg) = TrecVid08HelperFunctions::load_ECF($ecffile, $ecfobj, $xmllint, $xsdpath, $fps);
    MMisc::error_quit("Problem loading the ECF file: $errmsg")
      if (! MMisc::is_blank($errmsg));
    my $td = $ecfobj->get_duration();
    MMisc::error_quit("Problem obtaining the ECF duration (" . $ecfobj->get_errormsg() . ")")
      if ($ecfobj->error());
    if ($duration == 0) {
      $duration = $td;
    } else {
      MMisc::warn_print("Command line \'Duration\' ($duration) overrides (for scoring) the one found in the ECF file ($td)")
        if ($td != $duration);
    }
    print "\n** SUMMARY: ECF file loaded\n";
    print $ecfobj->txt_summary();
  }
  %metrics_params = ( TOTALDURATION => $duration );

  ## Generate event lists
  print "\n\n***** STEP ", $stepc++, ": Generating EventLists",
    (($useECF) ? " (only adding observations matching loaded ECF)" : ""), "\n";
  my $tmpecfobj = ($useECF) ? $ecfobj : undef;
  my $sysEL = &generate_EventList("SYS", $tmpecfobj, %sys_hash);
  my $refEL = &generate_EventList("REF", $tmpecfobj, %ref_hash);
  ## Can we score after all ?
  my ($rc, $rs, $rr) = $sysEL->comparable_filenames($refEL);
  MMisc::error_quit("While trying to obtain a list of scorable referred to files (" . $sysEL->get_errormsg() .")")
    if ($sysEL->error());
  my @common = @{$rc};
  my @only_in_sys = @{$rs};
  my @only_in_ref = @{$rr};
  print "\n** SUMMARY: All EventLists generated\n";
  print "** Common referred to files (", scalar @common, "): ", join(" ", @common), "\n";
  print "** Only in SYS (", scalar @only_in_sys, "): ", join(" ", @only_in_sys), "\n";
  print "** Only in REF (", scalar @only_in_ref, "): ", join(" ", @only_in_ref), "\n\n";
  my $fcount = (scalar @common) + (scalar @only_in_sys) + (scalar @only_in_ref);
  MMisc::error_quit("Can not continue, no file in any list ?") if ($fcount == 0);
  
  if ($useECF) {
    my ($err, $rmiss, $rnotin) = TrecVid08HelperFunctions::confirm_all_ECF_sffn_are_listed($ecfobj, @common);
    MMisc::error_quit($err)
      if (! MMisc::is_blank($err));
    MMisc::warn_print("FYI (comparing ECF to common list): the following files are not listed in the ECF, and therefore will not be scored against: " . join(" ", @$rnotin))
      if (scalar @$rnotin > 0);
    if (scalar @$rmiss > 0) {
      MMisc::error_quit("Can not perform soring (comparing ECF to common list): the following files are present in the ECF but not in the common list: " . join(" ", @$rmiss))
        if (! $befc);
      MMisc::warn_print("FYI (comparing ECF to common list): the following files are present in the ECF but not in the common list: " . join(" ", @$rmiss) . ". This is cause for exiting with error status but \'BypassECFFilesCheck\' was requested, will continue scoring");
    }
  }
  
  ## Aligning Files and Events
  print "\n\n***** STEP ", $stepc++, ": Aligning Files and Events\n\n";
  my $kernel = new KernelFunctions();
  $kernel->set_delta_t($delta_t);
  $kernel->set_E_t($E_t);
  $kernel->set_E_d($E_d);
  $kernel->set_sysEL($sysEL);
  my @kp = $kernel->get_kernel_params();
  MMisc::error_quit("Error while obtaining the kernel function parameters (" . $kernel->get_errormsg() . ")")
    if ($kernel->error());
  
  push @all_events, $key_allevents;
  push @all_events, @asked_events;
  foreach my $event (@all_events) {
    my $trial = new Trials("Event Detection", "Event", "Observation", \%metrics_params);
    $all_trials{$event} = $trial;
    $all_metric{$event} = new MetricTV08({ ('CostMiss' => $CostMiss, 'CostFA' => $CostFA, 'Rtarget' => $Rtarget ) }, $trial);
  }
  $gtrial = $all_trials{$key_allevents};

  my @todo = ();
  push @todo, @common;
  push @todo, @only_in_sys;
  push @todo, @only_in_ref;
  my $ald = &do_alignment(\@todo, $sysEL, $refEL, @kp);
  print "NOTE: No alignment ever done\n"
    if ($ald == 0);
} else { # scalar @inputAliCSV != 0
  my @tmp = ();
  foreach my $entry (@inputAliCSV) {
    push @tmp, split(m%\,%, $entry);
  }
  @inputAliCSV = @tmp;

  %metrics_params = ( TOTALDURATION => $duration );
  $all_trials{$key_allevents} = new Trials("Event Detection", "Event", "Observation", \%metrics_params);
  my %allEvents = ();

  ### Load the Trial Structures from CSV alignment files
  foreach my $csvf (@inputAliCSV) {
    print "* Loading CSV file [$csvf]";

    open (CSV, $csvf) 
      or MMisc::error_quit("Failed to open CSV alignment file ($csvf): $!");

    my $csv = new CSVHelper();
    MMisc::error_quit("Problem creating the CSV object: " . $csv->get_errormsg())
      if ($csv->error());

    if (! $schc) {
      my $header = <CSV>;
      if (! defined $header) {
        print "File [$csvf] contains no data, skipping\n";
        next;
      }
      my @headers = $csv->csvline2array($header);
      MMisc::error_quit("Problem extracting csv line:" . $csv->get_errormsg())
        if ($csv->error());
      if (scalar @headers == 1) {
        print "File [$csvf] contains no usable data, skipping\n";
        next;
      }
      MMisc::error_quit("File [$csvf] does not contain enough CSV columns (" . scalar @headers .") vs 16 expected")
        if (scalar @headers != 16);
      $csv->set_number_of_columns(scalar @headers);
      MMisc::error_quit("Problem setting the number of columns for the csv file:" . $csv->get_errormsg())
        if ($csv->error());

      foreach my $tmp_ft (qw(2:Event 3:TYPE 10:S.DetScr 11:S.DetDec)) {
        my ($tmp_loc, $tmp_ev) = split(m%\:%, $tmp_ft); 
        my $tmp_val = $headers[$tmp_loc];
        MMisc::error_quit("In file [$csvf]: CSV field [$tmp_loc] != \'$tmp_ev\' (is \"$tmp_val\"")
          if ($tmp_val ne $tmp_ev);
      }
    }

    my ($type, $evt, $detscr, $detdec);
    while (<CSV>){
      my @data =  $csv->csvline2array($_);
      MMisc::error_quit("Problem extracting data from csv line: " . $csv->get_errormsg())
        if ($csv->error());

      ($type, $evt, $detscr, $detdec) =
        ($data[3], $data[2], $data[10], $data[11]);

      if (! exists($all_trials{$evt})){
        $all_trials{$evt} = new Trials("Event Detection", "Event", "Observation", \%metrics_params);
        $all_metric{$evt} = new MetricTV08({ ('CostMiss' => $CostMiss, 'CostFA' => $CostFA, 'Rtarget' => $Rtarget ) }, $all_trials{$evt});
      }

      if ($type eq "Mapped"){
        $all_trials{$evt}->addTrial($evt, $detscr, $detdec, 1);
        $all_trials{$key_allevents}->addTrial($evt, $detscr, $detdec, 1); 
      } elsif ($type eq "Unmapped_Sys") {
        $all_trials{$evt}->addTrial($evt, $detscr, $detdec, 0);
        $all_trials{$key_allevents}->addTrial($evt, $detscr, $detdec, 0);
      } else {
        $all_trials{$evt}->addTrial($evt, undef, "OMITTED", 1);
        $all_trials{$key_allevents}->addTrial($evt, undef, "OMITTED", 1);
      }
      $trials_c{$evt}++;
      $trials_c{$key_allevents}++;
      $allEvents{$evt} = 1;
    }

    close CSV;
  } # foreach @inputAliCSV

  push @all_events, $key_allevents;
  push @all_events, keys %allEvents;
}

my $alc = $trials_c{$key_allevents};
print "WARNING: No Trials ever added, will force skip some steps\n"
  if ($alc == 0);

## Dump Trial Contingency Table (optional)

if ($observationContingencyTable) {
  print "\n\n***** STEP ", $stepc++, ": Dump of Trial Contingency Table\n";

  if ($alc == 0) {
    print "  ** Skipped **\n";
  } else {
    MMisc::writeTo($outputRootFile, ".contigency.txt", 1, 0, $all_trials{$key_allevents}->dumpCountSummary());
  }
}

## Dump of Analysis Report

print "\n\n***** STEP ", $stepc++, ": Dump of Analysis Report\n";
my $detSet = new DETCurveSet($sysTitle);

print "Computed using:  Rtarget = $Rtarget | CostMiss = $CostMiss | CostFA = $CostFA\n";
print " (only printing seen events)\n\n";
foreach my $event (@all_events) {
  next if (! exists $trials_c{$event});
  next if ($trials_c{$event} == 0);
  next if ($event eq $key_allevents);
  my $trials = $all_trials{$event};
  my $metric = $all_metric{$event};
#  print "** Computing DET Curves for event: $event\n";
  my $det = new DETCurve($trials, $metric, "Event $event: ". $sysTitle, [()], $gzipPROG);
  print $det->getMessages()
    if (! MMisc::is_blank($det->getMessages()));
  my $rtn = $detSet->addDET($event." Event", $det);
  MMisc::error_quit("Error adding Event '$event' to the DETSet: $rtn") if ($rtn ne "success");                     
}

if ($alc == 0) {
  print "  ** Skipped **\n";
} else {
  MMisc::writeTo
    ($outputRootFile, ".scores.txt", 1, 0, 
     $detSet->renderAsTxt
     ($outputRootFile . ".det", $doDC, 1, 
      { (xScale => "log", Ymin => "0.00001", Ymax => "90",
         Xmin => "0.00001", Xmax => "100", 
         gnuplotPROG => $gnuplotPROG,
         createDETfiles => ($nodetfiles ? 0: 1),
         BuildPNG => ($noPNG ? 0 : 1))
      } ) );
}

## reWrite XML files
if (defined $writexml) {
  print "\n\n***** STEP ", $stepc++, ": reWrite of XML files\n";

  foreach my $key (keys %xmlwriteback) {
    my $vf = $xmlwriteback{$key};
    my @used_events = ($autolt) ? $vf->list_used_full_events() : @ok_events;
    my $of = (! MMisc::is_blank($writexml)) ? "$writexml/$key.xml" : "";
    (my $err, $of) = TrecVid08HelperFunctions::save_ViperFile_XML($of, $vf, 1, "", @used_events);
    MMisc::error_quit($err)
      if (! MMisc::is_blank($err));

    if (defined $MemDump) {
      (my $err, $of) = TrecVid08HelperFunctions::save_ViperFile_MemDump($of, $vf, $MemDump, 1, 1);
      MMisc::error_quit("Problem writing the \'Memory Dump\' representation of the ViperFile object ($err)")
        if (! MMisc::is_blank($err));
    }
  }
}

MMisc::ok_quit("\n\n***** Done *****\n");

########## END

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
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

  my $tmp = "";
  my %all = ();
  my $ntodo = scalar @filelist;
  my $ndone = 0;
  while ($tmp = shift @filelist) {
    my ($retstatus, $object, $msg) =
      TrecVid08HelperFunctions::load_ViperFile($isgtf, $tmp, 
					       $fps, $xmllint, $xsdpath);

    if ($retstatus) { # OK return
      &valok($tmp, $isgtf, "Loaded");
    } else {
      &valerr($tmp, $isgtf, $msg);
      next;
    }

    # This is really if you are a debugger
    print("** Memory Representation:\n", $object->_display_all()) if ($showi > 1);

    # This is really if you are a debugger
    if ($showi > 2) {
      print("** Observation representation:\n");
      foreach my $i (@asked_events) {
        print("-- EVENT: $i\n");
        my @bucket = $object->get_event_observations($i);
        MMisc::error_quit("While \'get_event\'observations\' (" . $object->get_errormsg() .")")
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
  MMisc::error_quit("Problem creating the $mode EventList (" . $tmpEL->get_errormsg() . ")")
    if ($tmpEL->error());

  if (defined $lecfobj) {
    MMisc::error_quit("Problem tying $mode EventList to ECF " . $tmpEL->get_errormsg() . ")")
      if (! $tmpEL->tie_to_ECF($lecfobj));
  }

  my $added = 0;
  my $rejected = 0;
  my $sfile = 0;
  my $tobs = 0;
  foreach my $key (keys %ohash) {
    my $vf = $ohash{$key};
    
    my ($terr, $ttobs, $tadded, $trejected) = 
      TrecVid08HelperFunctions::add_ViperFileObservations2EventList($vf, $tmpEL, 1);
    MMisc::error_quit("Problem adding $mode ViperFile Observations to EventList: $terr")
      if (! MMisc::is_blank($terr));
   
    $tobs += $ttobs;
    $added += $tadded;
    $rejected += $trejected;
 
    $sfile++;
  }

  print "* $mode EventList: $added Observation(s) added";
  print " ($rejected rejected)" if (($rejected > 0) || (defined $lecfobj));
  print " [Seen $tobs Observations inside $sfile file(s)]";
  print "\n";

  return($tmpEL);
}

########################################

sub Obs_array_to_hash {
  my @all = @_;

  my %ohash = ();

  foreach my $o (@all) {
    my $key = $o->get_unique_id();
    MMisc::error_quit("While trying to obtain a unique Observation id (". $o->get_errormsg() . ")")
      if ($o->error());

    MMisc::error_quit("WEIRD: This key ($key) already exists, was this file already loaded ?")
      if (exists $ohash{$key});

    $ohash{$key} = $o;
  }

  return(%ohash);
}

############################################################

sub add_obs2vf {
  my ($obs) = @_;
  
  MMisc::error_quit("Observation error (" . $obs->get_errormsg(). ")")
    if ($obs->error());
  MMisc::error_quit("Observation is not validated")
    if (! $obs->is_validated());

  my $file = $obs->get_filename();
  if (! exists $xmlwriteback{$file}) {
    my ($numframes, $framerate, $sourcetype, $hframesize, $vframesize) 
      = $obs->get_ofi_VF_empty_order();
    my $xf = $obs->get_xmlfilename();

    my $tmp_vf = new TrecVid08ViperFile();
    $tmp_vf->fill_empty($file, 0, $numframes, $framerate, $sourcetype, $hframesize, $vframesize);
    $tmp_vf->set_xmllint("xmllint", 1);
    $tmp_vf->set_xsdpath(".", 1);
    $tmp_vf->set_file($xf, 1); 

    MMisc::error_quit("Problem creating a new TrecVid08ViperFile (" . $tmp_vf->get_errormsg() . ")")
      if ($tmp_vf->error());

    $xmlwriteback{$file} = $tmp_vf;
  }
 
  my $vf = $xmlwriteback{$file};

  $vf->add_observation($obs);
  MMisc::error_quit("Problem while adding obserbation to viper file (" . $vf->get_errormsg() . ")")
    if ($vf->error());
}

#####

sub add_data2sat {
  my ($sat, $trialid, $file, $event, $type, 
      $rid, $rrange, $durr,
      $sid, $srange, $durs, $sdetscr, $sdetdec,
      $isecrange, $durisec,
      $begrbegs, $endrends) = @_;

  $sat->addData($file, "File", $trialid) if (defined $file);
  $sat->addData($event, "Event", $trialid) if (defined $event);
  $sat->addData($type, "TYPE", $trialid);
  $sat->addData($rid, "R.ID", $trialid);
  $sat->addData($rrange, "R.range", $trialid);
  $sat->addData($durr, "Dur.r", $trialid);
  $sat->addData($sid, "S.ID", $trialid);
  $sat->addData($srange, "S.range", $trialid);
  $sat->addData($durs, "Dur.s", $trialid);
  $sat->addData($sdetscr, "S.DetScr", $trialid);
  $sat->addData($sdetdec, "S.DetDec", $trialid);
  $sat->addData($isecrange, "ISec.range", $trialid);
  $sat->addData($durisec, "Dur.ISec", $trialid);
  $sat->addData($begrbegs, "Beg.r-Beg.s", $trialid);
  $sat->addData($endrends, "End.r-End.s", $trialid);
}

#####

sub do_alignment {
  my ($rtodo, $sysEL, $refEL, @kp) = @_;

  my @todo = @{$rtodo};

  my $ksep = 0;
  
  ##### Add values to the 'Trials' (and 'SimpleAutoTable')
  my $alignmentRep = new SimpleAutoTable();
  MMisc::error_quit("Error building alignment table: ".$alignmentRep->get_errormsg()."\n")
    if (! $alignmentRep->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

  foreach my $file (@todo) {
    my @sys_events = ($sysEL->is_filename_in($file)) ? $sysEL->get_events_list($file) : ();
    MMisc::error_quit("While trying to obtain a list of SYS events for file ($file) (" . $sysEL->get_errormsg() . ")")
      if ($sysEL->error());
    my @ref_events = ($refEL->is_filename_in($file)) ? $refEL->get_events_list($file) : ();
    MMisc::error_quit("While trying to obtain a list of REF events for file ($file) (" . $refEL->get_errormsg() . ")")
      if ($refEL->error());

    if (scalar @ref_events + scalar @sys_events == 0) {
      print "|->File: $file\n";
      print " -- No Events, skipping\n\n";

      my $tmp_obs = $sysEL->get_1st_dummy_observation($file);
      MMisc::error_quit("**WEIRD** Could not obtain a \'dummy observation\' for file ($file)")
        if (! defined $tmp_obs);
      &add_obs2vf($tmp_obs);

      next;
    }

    # limit to sys events ?
    if ($ltse) {
      my ($rla, $rlb) = MMisc::confirm_first_array_values(\@ref_events, @sys_events);
      my @leftover = @$rlb;
      @ref_events = ();

      print "|->File: $file\n";
      if (scalar @leftover > 0) {
        print " -- Will not process the following event(s) (not present in the matching sys files): ", join(" ", @leftover), "\n";
      }
        
      my @listed_events = MMisc::make_array_of_unique_values(@sys_events, @ref_events);
      if (scalar @listed_events == 0) {
        print " -- No Events left, skipping\n\n";
        
        my $tmp_obs = $sysEL->get_1st_dummy_observation($file);
        MMisc::error_quit("**WEIRD** Could not obtain a \'dummy observation\' for file ($file)")
          if (! defined $tmp_obs);
        &add_obs2vf($tmp_obs);
        
        next;
      }
      print " -- Will only process the following event(s): ", join(" ", @listed_events), "\n";
      print "\n";
    } elsif (scalar @asked_events != scalar @ok_events) {
      print "|->File: $file\n";
      print " -- Will only score on the following events: ", join(" ", @asked_events), "\n";
      my ($rla, $rlb) = MMisc::confirm_first_array_values(\@asked_events, @sys_events);
      @sys_events = @$rla;
      print " -- Left in SYS Event list: ", join(" ", @sys_events), "\n";
      
      my ($rla, $rlb) = MMisc::confirm_first_array_values(\@asked_events, @ref_events);
      @ref_events = @$rla;
      print " -- Left in REF Event list: ", join(" ", @ref_events), "\n";
    }

    my @listed_events = MMisc::make_array_of_unique_values(@sys_events, @ref_events);

    if (scalar @listed_events == 0) {
      print "|->File: $file\n";
      print " -- No Events, skipping\n\n";

      my $tmp_obs = $sysEL->get_1st_dummy_observation($file);
      MMisc::error_quit("**WEIRD** Could not obtain a \'dummy observation\' for file ($file)")
        if (! defined $tmp_obs);
      &add_obs2vf($tmp_obs);

      next;
    }

    foreach my $evt (TrecVid08ViperFile::sort_events(@listed_events)) {
      my @sys_events_obs = ($sysEL->is_filename_in($file)) ? $sysEL->get_Observations_list($file, $evt) : ();
      MMisc::error_quit("While trying to obtain a list of observations for SYS event ($evt) and file ($file) (" . $sysEL->get_errormsg() . ")")
        if ($sysEL->error());
      my @ref_events_obs = ($refEL->is_filename_in($file)) ? $refEL->get_Observations_list($file, $evt) : ();
      MMisc::error_quit("While trying to obtain a list of observations for REF event ($evt) and file ($file) (" . $refEL->get_errormsg() . ")")
        if ($refEL->error());

      my %sys_bpm = &Obs_array_to_hash(@sys_events_obs);
      my %ref_bpm = &Obs_array_to_hash(@ref_events_obs);

      my $tomatch = scalar @sys_events_obs + scalar @ref_events_obs;
      print "|-> Filename: $file | Event: $evt | SYS elements: ", scalar @sys_events_obs, " | REF elements: ", scalar @ref_events_obs, " | Total Observations: $tomatch elements\n";
      my $bpm = new BipartiteMatch(\%ref_bpm, \%sys_bpm, \&KernelFunctions::kernel_function, \@kp);
      MMisc::error_quit("While creating the Bipartite Matching object for event ($evt) and file ($file) (" . $bpm->get_errormsg() . ")")
        if ($bpm->error());

      # Force the use of the clique_cohorts algorithm
      $bpm->use_clique_cohorts();

      $bpm->compute();
      MMisc::error_quit("While computing the Bipartite Matching for event ($evt) and file ($file) (" . $bpm->get_errormsg() . ")")
        if ($bpm->error());

      # I am the coder, I know what I want to display/debug ... trust me !
      $bpm->_display("joint_values") if ($showi > 1);
      $bpm->_display("mapped", "unmapped_ref", "unmapped_sys") if ($showi);

      my $lsat = undef;
      if ($allAT) {
        $lsat = new SimpleAutoTable();
        MMisc::error_quit("Error building alignment table: ".$lsat->get_errormsg()."\n")
          if (! $lsat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));
      }
      
      my $trials = $all_trials{$evt};

      # First, the mapped sys observations
      my @mapped = $bpm->get_mapped_objects();
      MMisc::error_quit("Problem obtaining the mapped objects from the BPM (" . $bpm->get_errormsg() . ")")
        if ($bpm->error());
      foreach my $mop (@mapped) {
        my ($sys_obj, $ref_obj) = @{$mop};

        my $detscr = $sys_obj->get_DetectionScore();
        my $detdec = $sys_obj->get_DetectionDecision();
        MMisc::error_quit("Could not obtain some of the Observation's information (" . $sys_obj->get_errormsg() . ")")
          if ($sys_obj->error());

        $trials->addTrial($evt, $detscr, ($detdec) ? "YES" : "NO", 1);
        $trials_c{$evt}++;
        $gtrial->addTrial($evt, $detscr, ($detdec) ? "YES" : "NO", 1); 
        $trials_c{$key_allevents}++;
        # The last '1' is because the elements match an element in the ref list (target)

	if (defined $writexml) {
	  my $tmp_obs = $sys_obj->clone();
	  $tmp_obs->set_eventsubtype(TrecVid08ViperFile::get_Mapped_subeventkey());
	  MMisc::error_quit("Problem adding sub event type to Observation (" . $tmp_obs->get_errormsg() . ")")
	    if ($tmp_obs->error());

	  my $ref_uid = $ref_obj->get_unique_id();
	  MMisc::error_quit("While trying to obtain a unique Observation id (". $ref_obj->get_errormsg() . ")")
	    if ($ref_obj->error());

	  $tmp_obs->addto_comment("Mapped to REF \"$ref_uid\"");
	  MMisc::error_quit("Problem adding comment to Observation (" . $tmp_obs->get_errormsg() . ")")
	    if ($tmp_obs->error());

    if (! MMisc::is_blank($xtend)) {

      my $fs_fs = undef;
      if ($xtend eq $xtend_modes[1]) { # 'copy_ref'
        $fs_fs = $ref_obj->get_framespan();
        MMisc::error_quit("Problem obtaining REF observation's framespan (" . $ref_obj->get_errormsg() . ")")
          if ($ref_obj->error());
      } elsif ($xtend eq $xtend_modes[2]) { # 'overlap'
        $fs_fs = $ref_obj->get_framespan_overlap_from_obs($sys_obj);
        MMisc::error_quit("Problem obtaining SYS to REF observation's framespan overlap (" . $ref_obj->get_errormsg() . ")")
          if ($ref_obj->error());
      } elsif ($xtend eq $xtend_modes[3]) { # 'extended'
        $fs_fs = $ref_obj->get_extended_framespan_from_obs($sys_obj);
        MMisc::error_quit("Problem obtaining SYS to REF observation's extended framespan (" . $ref_obj->get_errormsg() . ")")
          if ($ref_obj->error());
      }
      # For 'copy_sys', do nothing it is already copied
      
      if (defined $fs_fs) {
        $tmp_obs->set_framespan($fs_fs);
        MMisc::error_quit("Problem setting SYS observation's framespan (" . $tmp_obs->get_errormsg() . ")")
          if ($tmp_obs->error());
      }

      # copy 'xtra' attributes (include tracking comment)
      if ($ref_obj->is_xtra_set()) {
        foreach my $xtra ($ref_obj->list_all_xtra_attributes()) {
          my $v = $ref_obj->get_xtra_value($xtra);
          $tmp_obs->set_xtra_attribute($xtra, $v);
          MMisc::error_quit("Problem adding \'xtra\' attribute (" . $tmp_obs->get_errormsg() . ")")
            if ($tmp_obs->error());
        }
      }

    }

	  &add_obs2vf($tmp_obs);
	}

        my $trialID = &make_trialID($file, $evt, $ref_obj, $sys_obj, $ksep++);
	my $ov = &get_obj_fs_ov($ref_obj, $sys_obj);
	my ($rb, $re) = &get_obj_fs_beg_end($ref_obj);
        my ($sb, $se) = &get_obj_fs_beg_end($sys_obj);
	&add_data2sat($alignmentRep, $trialID, $file, $evt, "Mapped",
		      &get_obj_id($ref_obj), &get_obj_fs_value($ref_obj),
		      &get_obj_fs_duration($ref_obj),
		      &get_obj_id($sys_obj), &get_obj_fs_value($sys_obj),
		      &get_obj_fs_duration($sys_obj), 
		      $detscr, ($detdec ? "YES" : "NO"),
		      (defined($ov) ? &get_fs_value($ov) : "NULL"),
		      (defined($ov) ? &get_fs_duration($ov): "NULL"),
		      $rb - $sb, $re - $se);
	&add_data2sat($lsat, $trialID, undef, undef, "Mapped",
		      &get_obj_id($ref_obj), &get_obj_fs_value($ref_obj),
		      &get_obj_fs_duration($ref_obj),
		      &get_obj_id($sys_obj), &get_obj_fs_value($sys_obj),
		      &get_obj_fs_duration($sys_obj), 
		      $detscr, ($detdec ? "YES" : "NO"),
		      (defined($ov) ? &get_fs_value($ov) : "NULL"),
		      (defined($ov) ? &get_fs_duration($ov): "NULL"),
		      $rb - $sb, $re - $se) if ($allAT);
      }

      # Second, the False Alarms
      my @unmapped_sys = $bpm->get_unmapped_sys_objects();
      MMisc::error_quit("Problem obtaining the unmapped_sys objects from the BPM (" . $bpm->get_errormsg() . ")")
        if ($bpm->error());
      foreach my $sys_obj (@unmapped_sys) {
        my $detscr = $sys_obj->get_DetectionScore();
        my $detdec = $sys_obj->get_DetectionDecision();
        MMisc::error_quit("Could not obtain some of the Observation's information (" . $sys_obj->get_errormsg() . ")")
          if ($sys_obj->error());

        $trials->addTrial($evt, $detscr, ($detdec) ? "YES" : "NO", 0);
        $trials_c{$evt}++;
        $gtrial->addTrial($evt, $detscr, ($detdec) ? "YES" : "NO", 0);
        $trials_c{$key_allevents}++;
        # The last '0' is because the elements does not match an element in the ref list (target)

	if (defined $writexml) {
	  my $tmp_obs = $sys_obj->clone();
	  $tmp_obs->set_eventsubtype(TrecVid08ViperFile::get_UnmappedSys_subeventkey());
	  MMisc::error_quit("Problem adding sub event type to Observation (" . $tmp_obs->get_errormsg() . ")")
	    if ($tmp_obs->error());
	  &add_obs2vf($tmp_obs);
	}

        my $trialID = &make_trialID($file, $evt, undef, $sys_obj, $ksep++);
	&add_data2sat($alignmentRep, $trialID, $file, $evt, "Unmapped_Sys",
		      "", "", "", 
		      &get_obj_id($sys_obj), &get_obj_fs_value($sys_obj),
		      &get_obj_fs_duration($sys_obj), 
		      $detscr, ($detdec ? "YES" : "NO"),
		      "", "", "", "");
	&add_data2sat($lsat, $trialID, undef, undef, "Unmapped_Sys",
		      "", "", "", 
		      &get_obj_id($sys_obj), &get_obj_fs_value($sys_obj),
		      &get_obj_fs_duration($sys_obj), 
		      $detscr, ($detdec ? "YES" : "NO"),
		      "", "", "", "") if ($allAT);
      }

      # Third, the Missed Detects
      my @unmapped_ref = $bpm->get_unmapped_ref_objects();
      MMisc::error_quit("Problem obtaining the unmapped_ref objects from the BPM (" . $bpm->get_errormsg() . ")")
        if ($bpm->error());
      foreach my $ref_obj (@unmapped_ref) {
        $trials->addTrial($evt, undef, "OMITTED", 1);
        $trials_c{$evt}++;
        $gtrial->addTrial($evt, undef, "OMITTED", 1);
        $trials_c{$key_allevents}++;
        # Here we only care about the number of entries in this array

	if (defined $writexml) {
	  my $tmp_obs = $ref_obj->clone();
	  $tmp_obs->set_eventsubtype(TrecVid08ViperFile::get_UnmappedRef_subeventkey());
	  MMisc::error_quit("Problem adding sub event type to Observation (" . $tmp_obs->get_errormsg() . ")")
	    if ($tmp_obs->error());
	  $tmp_obs->set_DetectionScore(0);
	  $tmp_obs->set_DetectionDecision(0);
	  $tmp_obs->set_isgtf(0);
	  $tmp_obs->addto_comment("Observation converted from REF to SYS: DetectionScore and DetectionDecision are faked values");
	  $tmp_obs->validate();
	  MMisc::error_quit("Problem validating REF->SYS converted Observation (" . $tmp_obs->get_errormsg() . ")")
	    if ($tmp_obs->error());
	  &add_obs2vf($tmp_obs);
	}

        my $trialID = &make_trialID($file, $evt, $ref_obj, undef, $ksep++);
	&add_data2sat($alignmentRep, $trialID, $file, $evt, "Unmapped_Ref",
		      &get_obj_id($ref_obj), &get_obj_fs_value($ref_obj),
		      &get_obj_fs_duration($ref_obj),
		      "", "", "", "", "",
		      "", "", "", "");
	&add_data2sat($lsat, $trialID, undef, undef, "Unmapped_Ref",
		      &get_obj_id($ref_obj), &get_obj_fs_value($ref_obj),
		      &get_obj_fs_duration($ref_obj),
		      "", "", "", "", "",
		      "", "", "", "") if ($allAT);
      }
      # 'Trials' done

      if ($allAT) {
        my $tbl = $lsat->renderTxtTable(2);
        MMisc::error_quit("ERROR: Generating Alignment Report (". $lsat->get_errormsg() . ")") if (! defined($tbl));
        print $tbl;      
      }      

      my $matched = (2 * scalar @mapped)
        + scalar @unmapped_sys + scalar @unmapped_ref;
      print " -- Summary: ",
        scalar @mapped, " Mapped (Pairs) / ",
          scalar @unmapped_sys, " Unmapped Sys  / ",
            scalar @unmapped_ref, " Unmapped Ref | Total Observations: $matched elements\n\n";
      MMisc::error_quit("WEIRD: To match ($tomatch) != Matched ($matched) ?")
        if ($tomatch != $matched);
    }
  }
    
  if ($showAT) {
    my $tbl = $alignmentRep->renderTxtTable(2);
    if (! defined($tbl)) {
      print "Error Generating Alignment Report:\n". $alignmentRep->get_errormsg();
    }
    MMisc::writeTo($outputRootFile, ".ali.txt", 1, 0, $tbl);
    if ( (defined($outputRootFile)) && ($outputRootFile ne "") ) {
      my $tbl = $alignmentRep->renderCSV(2);
      if (! defined($tbl)) {
        print "Error Generating Alignment Report:\n". $alignmentRep->get_errormsg();
      }
      MMisc::writeTo($outputRootFile, ".ali.csv", 1, 0, $tbl);
    }
  }

  return($ksep);
}

#####

sub get_fs_value {
  my ($fs_fs) = @_;

  my $v = $fs_fs->get_value();
  MMisc::error_quit("Error obtaining the framespan's value (" . $fs_fs->get_errormsg() . ")")
    if ($fs_fs->error());

  return($v);
}  

#####

sub get_fs_duration {
  my ($fs_fs) = @_;

  my $d = $fs_fs->duration();
  MMisc::error_quit("Error obtaining the framespan's duration (" . $fs_fs->get_errormsg() . ")")
    if ($fs_fs->error());

  return($d);
}  

#####

sub get_obj_fs {
  my ($obj) = @_;

  MMisc::error_quit("Can not call \'get_framespan\' on an undefined object")
    if (! defined $obj);

  my $fs_fs = $obj->get_framespan();
  MMisc::error_quit("Error obtaining the object's framespan (" . $obj->get_errormsg() . ")")
    if ($obj->error());

  return($fs_fs);
}

#####

sub get_obj_fs_value {
  my ($obj) = @_;

  MMisc::error_quit("Can not obtain a framespan value for an undefined object")
    if (! defined $obj);

  my $fs_fs = &get_obj_fs($obj);

  return(&get_fs_value($fs_fs));
}

#####

sub get_obj_fs_duration {
  my ($obj) = @_;

  MMisc::error_quit("Can not obtain a framespan duration for an undefined object")
    if (! defined $obj);

  my $fs_fs = &get_obj_fs($obj);

  return(&get_fs_duration($fs_fs));
}

#####

sub get_obj_fs_ov {
  my ($obj1, $obj2) = @_;

  MMisc::error_quit("Can not obtain overlap for undefined objects")
    if ((! defined $obj1) || (! defined $obj2));

  my $fs_fs1 = &get_obj_fs($obj1);
  my $fs_fs2 = &get_obj_fs($obj2);

  my $ov = $fs_fs1->get_overlap($fs_fs2);
  MMisc::error_quit("Error obtaining overlap (" . $fs_fs1->get_errormsg() . ")")
    if ($fs_fs1->error());

  return($ov);
}

#####

sub get_obj_fs_beg_end {
  my ($obj) = @_;

  MMisc::error_quit("Can not obtain framespan beg/end for undefined object")
      if (! defined $obj);

  my $fs_fs = &get_obj_fs($obj);

  my ($b, $e) = $fs_fs->get_beg_end_fs();
  MMisc::error_quit("Error obtaining framespan's beg/end (" . $fs_fs->get_errormsg() . ")")
    if ($fs_fs->error());

  return($b, $e);
}

#####

sub get_obj_id {
  my ($obj) = @_;

  MMisc::error_quit("Can not obtain framespan beg/end for undefined object")
    if (! defined $obj);

  my $id = $obj->get_id();
  MMisc::error_quit("Error obtaining object's ID (" . $obj->get_errormsg() . ")")
    if ($obj->error());

  return($id)
}

#####

sub _num {return ($a <=> $b);}

#####

sub make_trialID {
  my ($fn, $evt, $ref_obj, $sys_obj, $ksep) = @_;

  my @ar = ();

  push @ar, &get_obj_fs_beg_end($ref_obj) if (defined $ref_obj);
  push @ar, &get_obj_fs_beg_end($sys_obj) if (defined $sys_obj);

  my @o = sort _num @ar;

  my $txt = sprintf("Filename: $fn | Event: $evt | MIN: %012d | MAX: %012d | KeySeparator: %012d", $o[0], $o[-1], $ksep);

  return($txt);
}

############################################################ Manual

=pod

=head1 NAME

TV08Scorer - TrecVid08 ViPER XML System to Reference Scoring Tool

=head1 SYNOPSIS

B<TV08Scorer> S<[ B<--help> | B<--man> | B<--version> ]>
  S<[B<--xmllint> I<location>] [B<--TrecVid08xsd> I<location>]>
  S<[B<--showAT>] [B<--allAT>] [B<--observationCont>]>
  S<[B<--LimittoSYSEvents> | B<--limitto> I<event1>[,I<event2>[I<...>]]]>
  S<[B<--writexml> [I<dir>] [B<--WriteMemDump> [I<mode>]] [B<--pruneEvents>]>
  S<[B<--XtraMappedObservations> I<mode>]]>
  S<[B<--Duration> I<seconds>] [B<--ecf> I<ecffile> [B<--BypassECFFilesCheck>]]>
  S<[B<--MissCost> I<value>] [B<--CostFA> I<value>] [B<--Rtarget> I<value>]> 
  S<[B<--computeDETCurve> [B<--titleOfSys> I<title>] [B<--ZipPROG> I<gzip>]>
  S<[B<--OutputFileRoot> I<filebase>]>
  S<[B<--GnuplotPROG> I<gnuplot>] | [B<--noPNG> B<--NoDetFiles>]]>
  S<[B<--Ed> S<value>] [B<--Et> S<value>]>
  S<B<--deltat> I<deltat> B<--fps> I<fps>>
  S<[I<sys_file.xml> [I<...>] B<--gtf> I<ref_file.xml> [I<...>]>
  S<| B<--AlignmentCSV> I<file.csv>[,I<file.csv>[,I<...>]] [B<--bypassCSVHeader>]]>
  
=head1 DESCRIPTION

B<TV08Scorer> performs an alignment scoring comparing I<reference> and I<system> I<Event> I<Observations> for the 2008 TRECVid Event Detection (ED) Evaluation.
The produced reports implement the evaluation metrics as described on the L<http://www.nist.gov/speech/tests/trecvid/2008/>.

There are 5 required elements to use the program: the limit temporal observation alignment parameter (via B<--delta_t>), the number of frames per second in the video files (via B<--fps>), the ground truth ViPER files (via B<--gtf>), the duration of the test set (via B<--ecf> or B<--Duration>), and the system generated ViPER files.

The program generates several reports: the default report, alignment reports by file/event or globally (via B<--showATY> and B<--allAT>), and a contingency table of observation decision (via B<--observationCont>).  If the B<--OutputFileRoot> option is used, the reports are written to a file  beginning with the string specified by this option.  See the option descriptions below for the naming conventions.  

The program does not generate Decision Error Tradeoff (DET) curves by default because of the computation required.  If the B<--computDETCurve> option in used, then the curves are computed.

=head1 PREREQUISITES

B<TV08Scorer> system and reference ViPER files need to pass the B<TV08ViperValidator> validation process.  The scorer will quit on validation errors.  The scoring program relies on the following software and files.
 
=over

=item B<SOFTWARE>

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<F4DE_XMLLINT> environment variable to the full path location of the I<xmllint> executable.

For I<DETCurve> files generation, I<gzip> is required in your path.  If it is not, use B<--ZipPROG>.
For I<DETCurve> PNG generation, a recent version of I<GNUPlot> is required in your path.  If it is not, use B<--GnuplotPROG>.

=item B<FILES>

The syntactic validation requires some XML schema files (full list can be obtained using the B<--help> option).
It is possible to specify their location using the B<--xsdpath> option.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

Once you have installed the software, setting B<F4DE_BASE> to the installation location, and extending your B<PATH> to include B<$F4DE_BASE/bin> should be sufficient for the tools to find their components.

=back

=head1 GENERAL NOTES

B<TV08Scorer> expects that the system and reference ViPER files can be been validated using 'xmllint' against the TrecVid08 XSD file(s) (see B<--help> for files list).

B<TV08Scorer> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--AlignmentCSV> I<file.csv>[,I<file.csv>[,I<...>]]

Load I<Alignemt CSV> file(s) (generated by previous S<TV08Scorer> runs) and use them to generate the I<Dump of Analysis Report> (and optionally the I<Dump of Trial Contingency Table>).

Multiple B<--AlignmentCSV> can be used on the same command line.

Note that when specifying this mode, it is not possible to use I<SYS> or I<REF> files anymore.

=item B<--allAT>

Show I<Alignment Table>, per File/Event as they are being processed.  

=item B<--BypassECFFilesCheck>

Do not quit with error status if not all the files listed in the ECF are present. Note that the duration found in the ECF will still be used.

=item B<--bypassCSVHeader>

When loading I<Alignment CSV> file(s), do not check the first line in the file for column header content, use it as data.

=item B<--CostFA> I<value>

Set the Metric's Cost of a False Alarm (for DCR computation).
Default value can be obtained by the B<--help> option.

=item B<--computeDETCurve>

Generates I<DETCurve> plot data files as well as png files (requires GNUPlot with PNG support).  The option requires either B<--OutputFileRoot> <ROOT> to write the output files, or B<--noPPNG> to skip building the PNGs and writing the plots to file.  When the plots are written to file, the following files will be generated: 

=over 

=item <ROOT>.det.plt

a gnuplot file to produce a composite DET Curve including all events

=item <ROOT>.det.png

a PNG (if requested) of the composite DET Curve

=back

For each event, a set of individual DET Curves are produced where sub## is an individual event:

=over

=item <ROOT>.det.sub##.png

a PNG (if requested) of the event's DET Curve

=item <ROOT>.det.sub##.thresh.png

a PNG (if requested) of RFA, PMiss, and DCR as a function of the Detection score

=item <ROOT>.det.sub##.{dat.1,dat.2,plt,thresh.plt}

driver files for producing the gnuplot curves

=item <ROOT>.det.sub##.srl.gz

a serialized version of the DET Curve Object.  It can be used by I<DETUtil.pl> (soon to be added to the release) to plot composite DEV Curves

=back   

=item B<--Duration> I<seconds>

Specify the I<duration> value (required for the I<DCR> metric).
If an I<ECF> is specified, override its I<duration> value.

=item B<--deltat> I<deltat>

Specify the I<delta t> value (in seconds) required for ref/sys observation alignments to be possible (see Eval Plan). 

=item B<--Ed> I<value>

Override the default value for I<E d> required for the ref/sys observation alignment (see Eval Plan). It is the weight placed on the detection decision scores during alignment.
Default value can be obtained by the B<--help> option.

=item B<--Et> I<value>

Override the default value for I<E t> required for the ref/sys observation alignment (see Eval Plan).  It is the weight placed on the temporal error between the reference and system observations.
Default value can be obtained by the B<--help> option.

=item B<--ecf> I<ecffile>

Specify the I<ECF> to load. The ECF provides the duration of the test set for the error calculations.  The ECF can also be used as a source file filter for performing conditional scoring by reducing both the reference and system I<Observations> whose sourcefile is listed in the ECF, but also whose time range's middlepoint is within the time range specified in the ECF.
The program will refuse to score if not all the files listed inside the ECF file have been provided.

=item B<--fps> I<fps>

Specify the default sample rate (in frames per second) of the ViPER files.

=item B<--GnuplotPROG> I<gnuplot>

Specify the full path location of S<gnuplot> if the version you want to use is not first in your PATH.

=item B<--gtf>

Specify that the files past this marker are reference files.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--LimittoSYSEvents>

Request that scoring only be done on I<Events> present in the sys files for a given sourcefile filename. In other words, if a ref file contains all event type, and the sys file only a handful of events, only align and score on the events seen in the sys file.

=item B<--limitto> I<event1>[,I<event2>[I<...>]]

Only perform alignment on the events listed on the command line.

=item B<--MissCost> I<value>

Set the Metric's Cost of a Miss (for DCR computation).
Default value can be obtained by the B<--help> option.

=item B<--man>

Display this man page.

=item B<--NoDetFiles>

Do not create .det files if a DET Curve is computed.
Prevent creation of PNGs.

=item B<--noPNG>

Do not create PNG files if a DET Curve is computed.

=item B<--OutputFileRoot> I<filebase>

Will generate a file to disk for most reports, using I<filebase> as the file's basename and adding to it a report-specific extension.  See the report options for naming conventions.

=item B<--observationCont>

Show a I<Trials Contingency Table> listing per event: mapped observations (I<Corr:YesTarg>), unmapped reference observations (I<Miss:OmitTarg> and I<Miss:NoTarg>), and unmapped system observations (I<FA:YesNontarg> and I<Corr:NoNontarg>).  If B<--OutputFileRoot> <ROOT> is used, then the file <ROOT>.contigency.txt

=item B<--pruneEvents>

For each validated event that is written, only add to this file's config section, events for which observations are seen.

=item B<--Rtarget> I<value>

Set the Metric's Rate of Target value (for DET Curves computation).
Default value can be obtained by the B<--help> option.

=item B<--showAT>

Show a global I<Alignment Table>. If B<--OutputFileRoot> <ROOT> is used, then the file <ROOT>.ali.txt is a human readable text file of the alignments, and <ROOT>.ali.csv is a Comma Separated Value-formatted file.

=item B<--titleOfSys> I<title>

When creating DETCurves reports, I<title> is used for the result's title.

=item B<--TrecVid08xsd> I<location>

Specify the default location of the required XSD files (use B<--help> to get the list of required files).

=item B<--version>

Display B<TV08Scorer> version information.

=item B<--WriteMemDump> [I<mode>]

In addition to writing the XML file, write a MemDump of the same file.

I<mode> information can be obtained using B<--help>.

=item B<--writexml> [I<dir>]

Write a ViPER File to disk (or stdout if no I<dir> specified) containing the I<Mapped>, I<Unmapped_Sys> and I<Unmapped_Ref> event observations alignment from scoring the SYS file to the REF file.

=item B<--XtraMappedObservations> I<mode>

For I<Mapped> I<Event> I<Observation>s, copy the I<Xtra Attributes> of both the I<REF> and the I<SYS> into a new I<Observation> to be written to file.
Without this option, only I<SYS> I<Xtra Attributes> are copied to the new I<Observation>.

It will also modify the framespan written depending of the I<mode> selected:

=over 

=item S<copy_sys>

will copy the framespan of the I<SYS> I<Observation> as the framespan of the new I<Observation>. It is the default behavior of the B<--write> function when B<--XtraMappedObservations> is not selected.

=item S<copy_ref>

will copy the framespan of the I<REF> I<Observation> as the framespan of the new I<Observation>.

=item S<overlap>

will perform a framespan overlap operation between the I<REF> and I<SYS> I<Observation>s, and use this value as the framespan of the new I<Observation>.
For example if ref is 10:20 and sys is 15:30, the overlap will be 15:20.

=item S<extended>

will take the absolute min and absolute max of the framespans of the I<REF> and I<SYS> I<Observation>s, and use this value as the framespan of the new I<Observation>.
For example if ref is 10:20 and sys is 15:30, the overlap will be 10:30.

=back

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<F4DE_XMLLINT> environment variable.

=item B<--ZipPROG> I<gzip>

Specify the full path location of gzip if it is not your PATH.

=back

=head1 USAGE

=item B<TV08Scorer --fps 25 --deltat 1 test1-sys.xml --gtf test1-gtf.xml --showAT -allAT --observationCont --Duration 1000 --Ed 0.0002 --Et 0.004>

Will score the I<test1-sys.xml> I<system> file against the I<test1-gtf.xml> I<refefence> file, specifying that the default sample rate is 25 fps, I<delta t> is 1 frame, I<duration> is 1000 seconds, I<E d> is 0.0002 and I<E t> is 0.004.
It will print an I<Alignment Table> as it process each sourcefile's filename event type, as well as a I<Global Alignment Table>.
It will also print the I<Trial Contingency Table> table once all the scoring/alignment are done.

=item B<TV08Scorer --xmllint /local/bin/xmllint --TrecVid08xsd /local/F4DE-CVS/data --fps 25 --deltat 10 test1-sys.xml test2-sys.xml test3-sys.xml test4-sys.xml test5-sys.xml --gtf test1-gtf.xml test2-gtf.xml test3-gtf.xml test4-gtf.xml --showAT --computeDETCurve --noPNG --ecf test.ecf>

Will score the I<test1-sys.xml>, I<test2-sys.xml>, I<test3-sys.xml>, I<test4-sys.xml> and I<test5-sys.xml> I<system> files against the I<test1-gtf.xml>, I<test2-gtf.xml>, I<test3-gtf.xml> and I<test4-gtf.xml> I<refefence> files, specifying that the default sample rate is 25 fps, I<delta t> is 10 frames, using the I<xmllint> executable located at I</local/bin/xmllint> and the required XSD files found in the I</local/F4DE/data> directory.
It will load the I<test.ecf> I<ECF> file and only score the I<Event(s)>/I<Observation(s)> whose sourcefile's filename and time range match the ones listed in the I<ECF> file.
It will print the I<Global Alignment Table>.
It will also try to generate a I<DETCurve> result table but not plot PNGs.

=item B<TV08Scorer --fps 29.97 --deltat 50 test1-sys.xml test2-sys.xml --gtf test1-gtf.xml test2-gtf.xml --showAT --observationCont --OutputFileRoot results --computeDETCurve --titleOfSys "Analysis result" --zipPROG /local/bin/gzip --GnuplotPROG /local/bin/gnuplot --ecf test.ecf>

Will load the I<test1-sys.xml> and I<test2-sys.xml> I<system> files against the I<test1-gtf.xml> and I<test2-gtf.xml> I<refefence> files, specifying that the default sample rate is 29.97 fps, I<delta t> is 50 frames.
It will load the I<test.ecf> I<ECF> file and only score the I<Event(s)>/I<Observation(s)> whose sourcefile's filename and time range match the ones listed in the I<ECF> file.
It specifies that the base output filename is I<results>.
It will write a I<Global Alignment Table> in the I<results.ali.txt> file.
It will write a I<Trial Contingency Table> in the I<results.contingency.txt> file.
It will use the title S<Analysis result> when generated the I<DETCurve> result tables and PNGs (using S</local/bin/gzip> and S</local/bin/gnuplot> for the B<gzip> and B<gnuplot> commands).

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

Jonathan Fiscus <jonathan.fiscus@nist.gov>

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut

########################################

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $ecf_xsdf = join(" ", @ecf_xsdfilesl);
  my $xtend_modes_txt = join(" ", @xtend_modes);
  my $wmd = join(" ", @ok_md);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --man | --version] [--xmllint location] [--TrecVid08xsd location] [--showAT] [--allAT] [--observationCont] [--LimittoSYSEvents | --limitto event1[,event2[...]]] [--writexml [dir] [--WriteMemDump [mode]] [--pruneEvents] [--XtraMappedObservations mode]] [--Duration seconds] [--ecf ecffile [--BypassECFFilesCheck]] [--MissCost value] [--CostFA value] [--Rtarget value] [--computeDETCurve [--titleOfSys title] [--ZipPROG gzip_fullpath] [--OutputFileRoot filebase] [--GnuplotPROG gnuplot_fullpath | --NoDetFiles --noPNG]] [--Ed value] [--Et value] --deltat deltat --fps fps [sys_file.xml [sys_file.xml [...]] --gtf ref_file.xml [ref_file.xml [...]] | --AlignmentCSV file.csv[,file.csv[,...]] [--bypassCSVHeader]]

Will Score the XML file(s) provided (System vs Reference)

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found
  --showAT        Show Gloabl Alignment Table
  --allAT         Show Alignment Table per File and Event processed
  --observationCont  Dump the Trials Contingency Table
  --LimittoSYSEvents  For each sourcfile filename, only process events that are listed in the sys ViPER files.
  --limitto       Only care about provided list of events
  --writexml      Write a ViPER XML file containing the Mapped, Unmapped Reference and Unmapped System Event Observations to disk (if dir is specified, stdout otherwise)
  --WriteMemDump  Write a memory representation of validated ViPER Files that can be used by the Scorer and Merger tools. Two modes possible: $wmd (1st default)
  --pruneEvents   Only keep in the new file's config section events for which observations are seen
  --XtraMappedObservations  For Mapped events, copy the 'Xtra Attributes' of both the REF and the SYS into the event observation to be written to file. Will also modify the framespan written depending of the 'mode' selected (one of: $xtend_modes_txt)
  --Duration      Specify the scoring duration for the Metric (warning: override any ECF file)
  --ecf           Specify the ECF file to load and perform scoring against
  --BypassECFFilesCheck    Do not quit with error status if not all the files in the ECF are present
  --MissCost      Set the Metric's Cost of a Miss (for DCR computation) (default: $CostMiss)
  --CostFA        Set the Metric's Cost of a False Alarm (for DCR computation) (default: $CostFA)
  --Rtarget       Set the Metric's Rate of Target value (for DCR computation) (default: $Rtarget)
  --computeDETCurve  Generate DETCurve 
  --titleOfSys    Specifiy the title of the system for use in the reports
  --ZipPROG       Specify the full path name to gzip (Default is to have 'gzip' in your path)
  --OutputFileRoot   Specify the file base of most output files generated (default is to print)
  --GnuplotPROG   Specify the full path name to gnuplot (Default is to have 'gnuplot' in your path)
  --NoDetFiles    Do not write any \'.det\' files (required for gnuplot)
  --noPNG         Do not create PNGs if a DET Curve is computed 
  --Et / Ed       Change the default values for Et / Ed (Default: $E_t / $E_d)
  --deltat        Set the deltat value (s) that is a temporal limit observation alignments 
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --gtf           Specify that the files post this marker on the command line are Ground Truth Files
  --AlignmentCSV  Skip alignment step and use Alignment CSV as post alignment step input file(s) to generate results
  --bypassCSVHeader    Use CSV file(s)\'s first line as data, not column headers


Note:
- Program will ignore the <config> section of the XML file.
- List of recognized events: $ro
- 'TrecVid08xsd' files are: $xsdfiles (and if the 'ecf' option is used, also: $ecf_xsdf)
EOF
    ;
  
    return $tmp;
}
