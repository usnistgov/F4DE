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

my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1")
  {
    warn_print
      (
       "\"TrecVid08ViperFile\" is not available in your Perl installation. ",
       "It should have been part of this tools' files."
      );
    $have_everything = 0;
  }

# TrecVid08EventList (part of this tool)
unless (eval "use TrecVid08EventList; 1")
  {
    warn_print
      (
       "\"TrecVid08ViperFile\" is not available in your Perl installation. ",
       "It should have been part of this tools' files."
      );
    $have_everything = 0;
  }

# BipartiteMatch (part of this tool)
unless (eval "use BipartiteMatch; 1")
  {
    warn_print
      (
       "\"BipartiteMatch\" is not available in your Perl installation. ",
       "It should have been part of this tools' files."
      );
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
$versionid .= "\nusing:\n" . $dummy->get_version();
my @ok_events = $dummy->get_full_events_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

##########

# Required parameters

my $E_d = 1E-6;
my $E_t = 1E-8;

########################################
# Options processing

# Default values for variables

my $usage = &set_usage();
my $show = 0;
my $xmllint = "";
my $xsdpath = ".";
my $fps = -1;
my $gtfs = 0;
my $delta_t = undef;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:     E              T         d fgh          s  v x  

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
   # Hidden option
   'show_internals+' => \$show,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

die("\n$usage\n") if (scalar @ARGV == 0);

die("ERROR: \'fps\' must set in order to do any scoring work") if ($fps == -1);
die("ERROR: \'delta_t\' must set in order to do any scoring work") if (! defined $delta_t);

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

########## Main processing

## Load Pre-processing
print "***** STEP 1: Loading files in Memory\n";
my ($sysdone, $systodo, %sys_hash) = &load_preprocessing(0, @sys);
my ($refdone, $reftodo, %ref_hash) = &load_preprocessing(1, @ref);

my $ndone = $sysdone + $refdone;
my $ntodo = $systodo + $reftodo;

print "\n** SUMMARY: All files loaded\n";
print "** REF: $systodo files (", ($sysdone == $systodo) ? "all" : $sysdone, " ok)\n";
print "** SYS: $reftodo files (", ($refdone == $reftodo) ? "all" : $refdone, " ok)\n\n";
error_quit("Can not continue, not all files passed the loading/validation step, aborting\n")
  if ($ndone != $ntodo);

## Generate event lists
print "\n\n***** STEP 2: Generating EventLists\n";
my $sysEL = &generate_EventList("SYS", %sys_hash);
my $refEL = &generate_EventList("REF", %ref_hash);
## Can we score after all ?
my ($rc, $rs, $rr) = $sysEL->comparable_filenames($refEL);
error_quit("While trying to obtain a list of scorable referred to files (" . $sysEL->get_errormsg() .")")
  if ($sysEL->error());
my @common = @{$rc};
my @only_in_sys = @{$rs};
my @only_in_ref = @{$rr};
print "\n** SUMMARY: All EventLists generated\n";
print "** Common referred to files [Scorable] (", scalar @common, "): ", join(" ", @common), "\n";
print "** Only in SYS [Can not Score] (", scalar @only_in_sys, "): ", join(" ", @only_in_sys), "\n";
print "** Only in REF [Can not Score] (", scalar @only_in_ref, "): ", join(" ", @only_in_ref), "\n\n";
error_quit("Can not continue, no file in the \"Scorable\" list") if (scalar @common == 0);

## Prepare event lists for scoring
print "\n\n***** STEP 3: Scoring \"scorable\"\n";
$sysEL->set_delta_t($delta_t);
$sysEL->set_E_t($E_t);
$sysEL->set_E_d($E_d);
my @kp = $sysEL->get_kernel_params();
error_quit("Error while obtaining the EventList kernel function parameters (" . $sysEL->get_errormsg() . ")")
  if ($sysEL->error());

my %all_bpm;
foreach my $file (@common) {
  my @sys_events = $sysEL->get_events_list($file);
  error_quit("While trying to obtain a list of SYS events for file ($file) (" . $sysEL->get_errormsg() . ")")
    if ($sysEL->error());
  my @ref_events = $refEL->get_events_list($file);
  error_quit("While trying to obtain a list of REF events for file ($file) (" . $refEL->get_errormsg() . ")")
    if ($refEL->error());

  my @listed_events = &uniquer(@sys_events, @ref_events);

  foreach my $evt (@listed_events) {
    my @sys_events_obs = $sysEL->get_Observations_list($file, $evt);
    error_quit("While trying to obtain a list of observations for SYS event ($evt) and file ($file) (" . $sysEL->get_errormsg() . ")")
      if ($sysEL->error());
    my @ref_events_obs = $refEL->get_Observations_list($file, $evt);
    error_quit("While trying to obtain a list of observations for REF event ($evt) and file ($file) (" . $refEL->get_errormsg() . ")")
      if ($refEL->error());

    my %sys_bpm = &Obs_array_to_hash(@sys_events_obs);
    my %ref_bpm = &Obs_array_to_hash(@ref_events_obs);

    print "|-> Filename: $file | Event: $evt | SYS elements: ", scalar @sys_events_obs, " | REF elements: ", scalar @ref_events_obs, "\n";
    my $bpm = new BipartiteMatch(\%ref_bpm, \%sys_bpm, \&TrecVid08Observation::kernel_function, \@kp);
    error_quit("While creating the Bipartite Matching object for event ($evt) and file ($file) (" . $bpm->get_errormsg() . ")")
      if ($bpm->error());

    $bpm->compute();
    error_quit("While computing the Bipartite Matching for event ($evt) and file ($file) (" . $bpm->get_errormsg() . ")")
      if ($bpm->error());

    # I am the coder, I know what I want to display/debug ... trust me !
    $bpm->_display("joint_values", "mapped", "unmapped_ref", "unmapped_sys");
    
    $all_bpm{$file}{$evt} = $bpm;
  }
}

#### TODO #####

die("Done\n");

########## END

########################################

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 --deltat deltat --fps fps [--help] [--version] [--xmllint location] [--TrecVid08xsd location] [-Ed value] [-Et value] sys_file.xml [sys_file.xml [...]] -gtf ref_file.xml [ref_file.xml [...]]

Will Score the XML file(s) provided (Truth vs System)

 Where:
  --gtf           Specify that the files post this marker on the command line are Ground Truth Files
  --xmllint       Full location of the \'xmllint\' executable
  --TrecVid08xsd  Path where the XSD files can be found ($xsdfiles)
  --fps           Set the number of frames per seconds (float value) (also recognined: PAL, NTSC)
  --deltat        Set the deltat value (required for the scoring part)
  --Et / Ed       Change the default values for Et / Ed (Default: $E_t / $E_d)
  --version       Print version number and exit
  --help          Print this usage information and exit

Note:
- This prerequisite that the file has already been validated against the 'TrecVid08.xsd' file (using xmllint)
- Program will ignore the <config> section of the XML file.
- List of recognized events: $ro
EOF
;

  return $tmp;
}

####################

sub warn_print {
  print "WARNING: ", @_;
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

  print "(" . ($isgtf ? "SYS" : "REF") . ") $fname: $txt\n";
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
    print("** Memory Representation:\n", $object->_display_all()) if ($show);
    
    # This is really if you are a debugger 
    if ($show > 1) {
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
  my ($mode, %ohash) = @_;

  my $tmpEL = new TrecVid08EventList();
  error_quit("Problem creating the $mode EventList (" . $tmpEL->get_errormsg() . ")")
    if ($tmpEL->error());

  foreach my $key (keys %ohash) {
    my $vf = $ohash{$key};

    my @ao = $vf->get_all_events_observations();
    error_quit("Problem obtaining all Observations from $mode ViperFile object (" . $vf->get_errormsg() . ")")
      if ($vf->error());

    $tmpEL->add_Observations(@ao);
    error_quit("Problem add Observations to $mode EventList (" . $tmpEL->get_errormsg() . ")")
      if ($tmpEL->error());
  }

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

    $ohash{$key} = $o;
  }

  return(%ohash);
}
