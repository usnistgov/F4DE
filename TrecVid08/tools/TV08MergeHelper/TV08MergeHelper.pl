#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 ViPER XML File Merger
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 ViPER XML File Merger" is an experimental system.
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

my $versionid = "TrecVid08 ViPER XML File Merger Version: $version";

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
  $f4deplv = $ENV{$f4depl} || "../../../common/lib"; # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08EventList (part of this tool)
unless (eval "use TrecVid08EventList; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08EventList\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add
    (
     "\"Getopt::Long\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
  $have_everything = 0;
}

# TrecVid08HelperFunctions (part of this tool)
unless (eval "use TrecVid08HelperFunctions; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08HelperFunctions\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
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

########################################
# Options processing

my @ov_modes = ("FrameShiftedFiles", "SameFramespanFiles", "All"); # Order is important
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $mancmd = "perldoc -F $0";
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $writetodir = "";
my $fps = undef;
my $forceFilename = "";
my $olfile = undef;
my $show = 0;
my $do_shift_ov = 0;
my $do_same_ov = 0;
my $ecff = "";
my $autolt = 0;
my $ovoxml = 0;
my $MemDump = undef;
my $keepid = 0;
my $noco = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# Used:      F        O   ST  WX      efgh  k mnop  s  vwx  

my %opt = ();
my $dbgftmp = "";
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => \$isgtf,
   'writetodir=s'    => \$writetodir,
   'fps=s'           => \$fps,
   'ForceFilename=s' => \$forceFilename,
   'shift_overlap'   => \$do_shift_ov,
   'Same_overlap'    => \$do_same_ov,
   'overlaplistfile:s' => \$olfile,
   'ecfhelperfile=s' => \$ecff,
   'pruneEvents'     => \$autolt,
   'OverlapOnlyXML'  => \$ovoxml,
   'WriteMemDump:s'  => \$MemDump,
   "keep_id"         => \$keepid,
   "no_comment"      => \$noco,
   # Hidden option
   'X_show_internals+' => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::error_quit("Not enough arguments\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'fps\' must set in order to do be able to use \'observations\' objects\n\n$usage") if (! defined $fps);

MMisc::error_quit("\'ForceFilename\' option selected but no value set\n$usage") if (($opt{'ForceFilename'}) && ($forceFilename eq ""));

my %cov_todo = ();
$cov_todo{$ov_modes[0]}++ if ($do_shift_ov);
$cov_todo{$ov_modes[1]}++ if ($do_same_ov);
my $checkOverlap = scalar keys %cov_todo;

MMisc::error_quit("\'overlaplistfile\' can only be used in conjunction with one of the overlap check mode\n$usage")
  if ((defined $olfile) && ($checkOverlap == 0));
MMisc::error_quit("\'OverlapOnlyXML\' can only be used in conjunction with one of the overlap check mode\n$usage")
  if (($ovoxml) && ($checkOverlap == 0));

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

MMisc::error_quit("Problem with \'writetodir\': $!")
  if ( (! MMisc::is_blank($writetodir)) 
       && ((! -e $writetodir) || (! -d $writetodir)) );

##############################
# Main processing

my $step = 1;
##########
print "\n\n** STEP ", $step++, ": Load all files to be merged\n";
my $ntodo = scalar @ARGV;
my $ndone = 0;
my %all_vf = ();
foreach my $tmp (@ARGV) {
  my ($fname, $fsshift) = &get_fname_fsshift($tmp);
  my $key = &make_key_from_fname_fsshift($fname, $fsshift);

  MMisc::error_quit("File key ($key) seems to have already been loaded; can not load same file key multiple times, aborting")
    if (exists $all_vf{$key});

  my ($ok, $object) = &load_file($isgtf, $fname, $tmp);
  next if (! $ok);

  $all_vf{$key} = $object;
  $ndone++;

  if ($show > 3) {
    print "** FILE Key: $key\n";
    print $object->_display();
  }
}
print "* -> Loaded $ndone ok / $ntodo\n";
MMisc::error_quit("Could not succesfully load all files processed, aborting\n")
  if ($ndone != $ntodo);
MMisc::error_quit("No file loaded, aborting\n")
  if ($ndone == 0);

##########
print "\n\n** STEP ", $step++, ": Process all observations\n";

my %mergefiles = ();
my %ovofiles = ();
my $ovo_vf = undef; # Global variable (will be used in the overlap detection code)
my $EL = new TrecVid08EventList();
my $adone = 0;
MMisc::error_quit("Problem creating the EventList (" . $EL->get_errormsg() . ")")
  if ($EL->error());
my %overlap_list = ();
my %overlap_ids = ();

my @ecfh = ("SourceFile Filename", "Framespan", "XGTF File", "FPS"); # Order is important
my %ecfv = ();

foreach my $key (sort keys %all_vf) {
  my ($fname, $fsshift) = &get_fname_fsshift_from_key($key);

  my $object = $all_vf{$key};
  my $step2add = "";

  if ($forceFilename ne "") {
    $object->change_sourcefile_filename($forceFilename);
    MMisc::error_quit("Problem while changing the sourcefile filename (" . $object->get_errormsg() .")")
      if ($object->error());
  }

  # Get the sourcefile filename
  my $sffn = $object->get_sourcefile_filename();
  MMisc::error_quit("Problem obtaining the sourcefile filename (" . $object->get_errormsg() .")")
    if ($object->error());

  # Create the mergefile object for this sourcefile filename (if not existant yet)
  if (! defined $mergefiles{$sffn}) {
    my $mf = $object->clone_with_no_events();
    $mf->clear_comment();
    MMisc::error_quit("While duplicating the source ViperFile (" . $object->get_errormsg() .")")
      if ($object->error());
    
    $mergefiles{$sffn} = $mf;
  }

  # Create the merge Overlap Only file and set the global handler variable
  if ($ovoxml) {
    if (! defined $ovofiles{$sffn}) {
      my $vf = $object->clone_with_no_events();
      $vf->clear_comment();
      MMisc::error_quit("While duplicating the source object (" . $object->get_errormsg() .")")
	if ($object->error());
      $ovofiles{$sffn} = $vf;
    }
    $ovo_vf = $ovofiles{$sffn};
  }

  # Get the observation list for this viper file
  my @ao = ();
  # Starting with the dummy one
  my $dummy_obs = $object->get_dummy_observation();
  MMisc::error_quit("While obtaining the dummy observation (" . $object->get_errormsg() .")")
    if ($object->error());
  push @ao, $dummy_obs;
  # Now all the others
  my @tao = $object->get_all_events_observations();
  MMisc::error_quit("While obtaining all events' observations (" . $object->get_errormsg() .")")
    if ($object->error());
  push @ao, @tao;

  # Debugging
  if ($show > 2) {
    foreach my $obs (@ao) {
      print "** OBSERVATION MEMORY REPRESENATION (Before Processing):\n", $obs->_display();
    }
  }

  # Frameshift
  if ($fsshift != 0) {
    foreach my $obs (@ao) {
      $obs->shift_framespan($fsshift);
      MMisc::error_quit("While shifitng an observation's framespan (" . $obs->get_errormsg() .")")
        if ($obs->error());
    }
    $step2add .= " [FrameShifted ($fsshift frames)]";
  }

  # ECF Helper File
  if (! MMisc::is_blank($ecff)) {
    my $obs = $ao[0];    # Always true thanks to the dummy observation

    my $fl = $obs->get_filename();
    my $fn = $obs->get_xmlfilename();
    my $fs_file = $obs->get_fs_file();
    MMisc::error_quit("Problem obtaining Observation's information (" . $obs->get_errormsg() . ")")
      if ($obs->error());

    my $value = $fs_file->get_value();
    my $ofps = $fs_file->get_fps();
    MMisc::error_quit("Problem obtaining Observation's Framespan's information (" . $fs_file->get_errormsg() . ")")
      if ($fs_file->error());

    my $key = "$fl-$value-$fn-$ofps";

    MMisc::error_quit("WEIRD: This \'unique id\' ($key) seem to already have been added")
      if (exists $ecfv{$key});

    my $inc = 0;
    $ecfv{$key}{$ecfh[$inc++]} = $fl;
    $ecfv{$key}{$ecfh[$inc++]} = $value;
    $ecfv{$key}{$ecfh[$inc++]} = $fn;
    $ecfv{$key}{$ecfh[$inc++]} = $ofps;
  }

  # Overlap
  my $ovf = 0;
  if ($checkOverlap) {
    $step2add .= " [OverlapCheck:";
    if (exists $cov_todo{$ov_modes[0]}) { # frameshift
      my $tovf = &check_frameshift_overlap($sffn, @ao);
      $step2add .= " " . $ov_modes[0] . " ($tovf found)";
      $ovf += $tovf;
    }
    if (exists $cov_todo{$ov_modes[1]}) { # same fs
      my $tovf = &check_samefs_overlap($sffn, @ao);
      $step2add .= " " . $ov_modes[1] . " ($tovf found)";
      $ovf += $tovf;
    }
    $step2add .= "]";
  }

  # Debugging
  if (($show > 2) && ($step2add !~ m%^\s*$%)) {
    foreach my $obs (@ao) {
      print "** OBSERVATION MEMORY REPRESENATION (Post Processing):\n", $obs->_display();
    }
  }

  # Add the observations to the EventList
  foreach my $obs (@ao) {
    $EL->add_Observation($obs);
    MMisc::error_quit("Problem adding Observations to EventList (" . $EL->get_errormsg() . ")")
      if ($EL->error());
  }

  my $fobs = scalar @ao - 1;    # Remove the dummy obs
  print "- Done processing Observations from '$fname' [File key: $sffn]" . (($fsshift != 0) ? " [requested frameshift: $fsshift]" : "") . " (Found: $fobs", (($checkOverlap) ? " | Overlap Found: $ovf" : ""), ")$step2add\n";
  $adone += $fobs;
}
print "* -> Found $adone Observations\n";


##########
print "\n\n** STEP ", $step++, ": Writting merge file(s)\n";

my $fdone = 0;
my $ftodo = scalar keys %mergefiles;
foreach my $key (sort keys %mergefiles) {
  my $mf = $mergefiles{$key};

  my $fobs = 0;
  # Now add all observations from the current file to the output file
  # Note that thanks to the dummy observation we always have an entry in the EL
  ## We start by the dummy observation, and we only want to extend the
  # mergefile's NUMFRAMES with it
  my @bucket = $EL->get_dummy_Observations_list($key);
  MMisc::error_quit("While obtaining dummy Observations list ($key) (" . $EL->get_errormsg() .")")
    if ($EL->error());
  foreach my $obs (@bucket) {
    $mf->extend_numframes_from_observation($obs);
    MMisc::error_quit("While \'extend_numframes_from_observation\' (" . $mf->get_errormsg() .")")
      if ($mf->error());
  }    
  # Then we add the rest of the observations
  foreach my $i (@ok_events) {
    my @bucket = $EL->get_Observations_list($key, $i);
    $fobs += scalar @bucket;
    MMisc::error_quit("While obatining Observations list ($key / $i) (" . $EL->get_errormsg() .")")
      if ($EL->error());
    foreach my $obs (@bucket) {
      if (! $noco) {
        # Add a comment to the observation to indicate where it came from
        my $comment = "Was originally: " . $obs->get_unique_id();
        $obs->addto_comment($comment);
        MMisc::error_quit("While adding a comment to observation (" . $obs->get_errormsg() .")")
          if ($obs->error());
      }

      # Debugging
      if ($show > 1) {
        print "** OBSERVATION MEMORY REPRESENATION:\n", $obs->_display();
      }
      
      $mf->add_observation($obs, $keepid);
      MMisc::error_quit("While \'add_observation\' (" . $mf->get_errormsg() .")")
        if ($mf->error());
    }
  }

  if ($show) {
    print "** MERGED FILE MEMORY REPRESENTATION:\n";
    print $mf->_display();
  }

  # Duplicate the object in memory with only the selected types
  my @used_events = ($autolt) ? $mf->list_used_full_events() : @ok_events;

  my $writeto = (MMisc::is_blank($writetodir)) ? "" : "$writetodir/$key.xml";
  (my $errm, $writeto) = TrecVid08HelperFunctions::save_ViperFile_XML($writeto, $mf, 1, "", @used_events);
  MMisc::error_quit($errm)
    if (! MMisc::is_blank($errm));
  if (defined $MemDump) {
    (my $err, $writeto) = TrecVid08HelperFunctions::save_ViperFile_MemDump($writeto, $mf, $MemDump, 1, 1, ($autolt) ? @used_events : ());
      MMisc::error_quit("Problem writing the \'Memory Dump\' representation of the ViperFile object ($err)")
        if (! MMisc::is_blank($err));
    }

  $fdone++;
}
print "* -> Wrote $fdone files (out of $ftodo)\n";

MMisc::error_quit("Not all file could be processed, aborting")
  if ($fdone != $ftodo);

########## Optional Step: write Overlap Only XML files
if ($ovoxml) {
  print "\n\n** STEP ", $step++, ": Writting Overlap Only XML files\n";

  my $fdone = 0;
  my $ftodo = scalar keys %ovofiles;
  foreach my $key (sort keys %mergefiles) {
    my $mf = $ovofiles{$key};

    if ($show) {
      print "** MERGED FILE MEMORY REPRESENTATION:\n";
      print $mf->_display();
    }

    my @used_events = ($autolt) ? $mf->list_used_full_events() : @ok_events;
    my $writeto = (MMisc::is_blank($writetodir)) ? "" : "$writetodir/${key}_OverlapOnly.xml";
    (my $errm, $writeto) = TrecVid08HelperFunctions::save_ViperFile_XML($writeto, $mf, 1, "", @used_events);
    MMisc::error_quit($errm)
      if (! MMisc::is_blank($errm));
    if (defined $MemDump) {
      (my $err, $writeto) = TrecVid08HelperFunctions::save_ViperFile_MemDump($writeto, $mf, $MemDump, 1, 1, ($autolt) ? @used_events : ());
      MMisc::error_quit("Problem writing the \'Memory Dump\' representation of the ViperFile object ($err)")
        if (! MMisc::is_blank($err));
    }

    $fdone++;
  }
  print "* -> Wrote $fdone files (out of $ftodo)\n";
  
  MMisc::error_quit("Not all file could be processed, aborting")
    if ($fdone != $ftodo);
}

####################
# Optional step: write ecf helper file

if ($ecff ne "") {
  print "\n\n** STEP ", $step++, ": ECF Helper File\n";
  my $txt = &do_csv(\@ecfh, %ecfv);
  MMisc::error_quit("Problem writing \'ecfhelperfile\'\n")
    if (! MMisc::writeTo($ecff, "", 1, 0, $txt));
}

MMisc::ok_quit("\nDone.\n") if (! defined $olfile);

##########
# Optional step only performed if overlap list is requested

print "\n\n** STEP ", $step++, ": Overlap List\n";
my %ovl = ();
foreach my $key (keys %overlap_list) {
  $ovl{$key}++;
}
foreach my $key (sort keys %mergefiles) {
  my ($seen, $txt) = &prepare_overlap_list($key);

  MMisc::writeTo($olfile, "", 1, 0, $txt);

  delete $ovl{$key};
}
MMisc::error_quit("Some filenames left in overlap list ? (" . join(" ", keys %ovl), "), aborting")
  if (scalar keys %ovl > 0);

MMisc::ok_quit("\nDone.\n");

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "\'$fname\': $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;

  &valok($fname, "[ERROR] $txt");
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

########################################

sub get_fname_fsshift {
  my $tmp = shift @_;

  my $fname = $tmp;
  my $fsshift = 0;

  if ($tmp =~ m%^(.+?)\:(\d+)$%) {
    $fname = $1;
    $fsshift = $2;
  }

  return($fname, $fsshift);
}

#####

sub make_key_from_fname_fsshift {
  my ($fname, $fsshift) = @_;

  my $key = sprintf("%012d:%s", $fsshift, $fname);

  return($key);
}

#####

sub get_fname_fsshift_from_key {
  my ($key) = @_;

  my ($fsshift, $fname, @rest) = split(m%\:+%, $key);

  MMisc::error_quit("WEIRD: Left over in file key ? (" . join(" ", @rest) .")")
    if (scalar @rest > 0);

  return($fname, sprintf("%d", $fsshift));
}

#####

sub load_file {
  my ($isgtf, $tmp, $pname) = @_;

  my ($retstatus, $object, $msg) = 
    TrecVid08HelperFunctions::load_ViperFile($isgtf, $tmp, 
					     $fps, $xmllint, $xsdpath);

  if ($retstatus) { # OK return
    &valok($pname, "Loaded");
  } else {
    &valerr($pname, $msg);
  }

  return($retstatus, $object);
}

########################################


sub _ovc_core_get_eventlist {
  my $sffn = shift @_;

  # First, Do we already have observations for this file ?
  my $ifi = $EL->is_filename_in($sffn);
  MMisc::error_quit("While trying to check if a file was in the EventList (" . $EL->get_errormsg() . ")")
    if ($EL->error());

  return() if (! $ifi);

  # Get the event list
  my @el = $EL->get_events_list($sffn);
  MMisc::error_quit("While trying to obtain the events from the EventList (" . $EL->get_errormsg() . ")")
    if ($EL->error());

  return(@el);
}

#####

sub _check_overlap_core {
  my $mode = shift @_;
  my $sffn = shift @_;
  my @ao = @_;

  my $pov = 0; # overlap found

  my @events = &_ovc_core_get_eventlist($sffn);
  return($pov) if (scalar @events == 0); # No events for this file

  foreach my $event (@events) {
    my @obsl = $EL->get_Observations_list($sffn, $event);
    foreach my $el_obs (@obsl) {
      foreach my $ao_obs (@ao) {
        my $iscmp = $ao_obs->is_comparable_to($el_obs);
        MMisc::error_quit("Problem comparing observations while checking overlap (" . $ao_obs->get_errormsg() . ")")
          if ($ao_obs->error());
        next if (! $iscmp); # If those are not comparable (different filename or event), no need to keep going

        my $lpov = 0;
        my $fs_ov = undef;
        if ($mode eq $ov_modes[0]) { # frameshift
          $fs_ov = &_ovc_frameshift($ao_obs, $el_obs);
        } elsif ($mode eq $ov_modes[1]) { # samefs
          $fs_ov = &_ovc_samefs($ao_obs, $el_obs);
        } else {
          MMisc::error_quit("WEIRD: Not a recognized overlapcheck mode while checking the overlap");
        }
        if (defined $fs_ov) {   # Overlap detected
          my $ao_id = $ao_obs->get_unique_id();
          my $el_id = $el_obs->get_unique_id();
          my $ovr_txt = $fs_ov->get_value();
          MMisc::error_quit("Problem obtaining Framespan value (" . $fs_ov->get_errormsg() . ")")
            if ($fs_ov->error());
          my $ov_id = "${mode}-${event}-" . sprintf("%03d", $overlap_ids{$sffn}{$mode}{$event}++);

	  if ($ovoxml) {
	    my $new_obs = $ao_obs->clone();

	    $new_obs->clear_comment();
      if (! $noco) {
        my $no_txt = "\'$mode\' Overlap [ID: $ov_id] between \"$ao_id\" and \"$el_id\" [overlap: $ovr_txt]";
        $new_obs->addto_comment($no_txt);
      }
	    my $fs_no_ov = &_ovc_get_extended_framespan_obs2obs($ao_obs, $el_obs);
	    $new_obs->set_framespan($fs_no_ov);
	    MMisc::error_quit("Problem with OverlapOnly observation (" . $new_obs->get_errormsg() .")")
	      if ($new_obs->error());

	    # Add new observation to ovo_vf
	    $ovo_vf->add_observation($new_obs);
	    MMisc::error_quit("While adding observation to OverlapOnly XML (" . $ovo_vf->get_errormsg() . ")")
	      if ($ovo_vf->error());
	  }

          @{$overlap_list{$sffn}{$mode}{$event}{$ov_id}} = ($ao_id, $el_id, $ovr_txt);
          if (! $noco) {
            $ao_obs->addto_comment("\'$mode\' Overlap [ID: $ov_id] with \"$el_id\" [overlap: $ovr_txt]");
            MMisc::error_quit("Problem adding a comment to observation (" . $ao_obs->get_errormsg() . ")")
              if ($ao_obs->error());
            $el_obs->addto_comment("\'$mode\' Overlap [ID: $ov_id] with \"$ao_id\" [overlap: $ovr_txt]");
            MMisc::error_quit("Problem adding a comment to observation (" . $el_obs->get_errormsg() . ")")
              if ($el_obs->error());
          }
          $lpov = 1;
        }
        $pov += $lpov;
      }
    }
  }

  return($pov);
}

##########

sub _ovc_get_file_mpd {
  my ($ao, $el) = @_;

  my $mpd = $ao->get_fs_file_extent_middlepoint_distance_from_obs($el);
  MMisc::error_quit("Problem obtaining the observation's middlepoint distance (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($mpd);
}

#####

sub _ovc_get_file_ov {
  my ($ao, $el) = @_;

  my $ov = $ao->get_fs_file_overlap_from_obs($el);
  MMisc::error_quit("Problem obtaining the observation's overlap (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($ov);
}

#####

sub _ovc_do_fs_overlap_obs2obs {
  my ($ao, $el) = @_;

  my $ov = $ao->get_framespan_overlap_from_obs($el);
  MMisc::error_quit("Problem obtaining the fs overlap [obs2obs] (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($ov);
}

#####

sub _ovc_get_extended_framespan_obs2obs {
  my ($ao, $el) = @_;

  my $ov = $ao->get_extended_framespan_from_obs($el);
  MMisc::error_quit("Problem obtaining the fs extended overlap [obs2obs] (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($ov);
}

#####

sub _ovc_do_fs_overlap_obs2fs {
  my ($ao, $fs) = @_;

  my $ov = $ao->get_framespan_overlap_from_fs($fs);
  MMisc::error_quit("Problem obtaining the fs overlap [obs2fs] (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($ov);
}

##########

sub _ovc_frameshift {
  my ($ao, $el) = @_;

  my $mpd = &_ovc_get_file_mpd($ao, $el);
  # If the file's framespan middlepoint distance is differnt from 0,
  # it means they are shifted from one to the other
  return(undef) if ($mpd == 0);

  my $ov = &_ovc_get_file_ov($ao, $el);
  # We get a ViperFramespan if there is an overlap at all or 'undef' otherwise
  # if the files do not overlap, we should not have to worry
  # about a possible observation continuation
  return(undef) if (! defined $ov);

  # Do the observations overlap with the file overlap areas ?
  my $ao_ov = &_ovc_do_fs_overlap_obs2fs($ao, $ov);
  return(undef) if (! defined $ao_ov);
  my $el_ov = &_ovc_do_fs_overlap_obs2fs($el, $ov);
  return(undef) if (! defined $el_ov);
  
  # They do, Now let us see if the observations overlaps
  # If they do, the function returns either undef or a ViperFramespan
  # which is what we return also, so ...
  return(&_ovc_do_fs_overlap_obs2obs($ao, $el));
}

#####

sub _ovc_samefs {
  my ($ao, $el) = @_;

  my $mpd = &_ovc_get_file_mpd($ao, $el);
  # If the file's framespan middlepoint distance is 0, it means they use 
  # they have the same framespan (or that one is exactly at the center of
  # the other), so they are not shifted from one to the other
  return(undef) if ($mpd != 0);

  # Both observations are in the same fs_file; let us see if the
  # observations overlaps
  # If they do, the function returns either undef or a ViperFramespan
  # which is what we return also, so ...
  return(&_ovc_do_fs_overlap_obs2obs($ao, $el));
}

##########

sub check_frameshift_overlap {
  my $sffn = shift @_;
  my @ao = @_;

  return(&_check_overlap_core($ov_modes[0], $sffn, @ao));
}

#####

sub check_samefs_overlap {
  my $sffn = shift @_;
  my @ao = @_;

  return(&_check_overlap_core($ov_modes[1], $sffn, @ao));
}

########################################

sub _get_modes_list {
  my @res = ();

  foreach (my $i = 0; $i < scalar @ov_modes; $i++) { 
    push @res, $ov_modes[$i]
      if (exists $cov_todo{$ov_modes[$i]});
  }

  return(@res);
}

#####

sub prepare_overlap_list {
  my $file = shift @_;

  my $txt = "";

  $txt .=  "|--> File: $file\n";

  my @todo_files = keys %overlap_list;
  if (! grep(m%^$file$%, @todo_files)) {
    $txt .= "| |--> No Overlap found\n";
    return(0, $txt);
  }

  my @modes = _get_modes_list();
  foreach my $mode (@modes) {
    my @smodes = keys %{$overlap_list{$file}};
    if (! grep(m%^$mode$%, @smodes)) {
      $txt .= "| |--> Mode: $mode -- No Overlap found\n";
      next;
    }
    $txt .= "| |--> Mode: $mode\n";
    foreach my $event (sort keys %{$overlap_list{$file}{$mode}}) {
      $txt .= "| | |--> Event: $event\n";
      foreach my $ov_id (sort keys %{$overlap_list{$file}{$mode}{$event}}) {
        my ($ao_id, $el_id, $ovr_txt) = @{$overlap_list{$file}{$mode}{$event}{$ov_id}};
        $txt .= "| | | |--> ID: [$ov_id]\n";
        $txt .= "| | | |  Overlap range: $ovr_txt\n";
        $txt .= "| | | |  Between: \"$ao_id\"\n";
        $txt .= "| | | |      And: \"$el_id\"\n";
      }
      $txt .= "| | |\n";
    }
    $txt .= "| |\n";
  }
  $txt .= "|\n";

  return(1, $txt);
}

########################################

sub quc {                       # Quote clean
  my $in = shift @_;

  $in =~ s%\"%\'%g;

  return($in);
}

#####

sub qua {                       # Quote Array
  my @todo = @_;

  my @out = ();
  foreach my $in (@todo) {
    $in = &quc($in);
    push @out, "\"$in\"";
  }

  return(@out);
}

#####

sub generate_csvline {
  my @in = @_;

  @in = &qua(@in);
  my $txt = join(",", @in);

  return($txt);
}

#####

sub get_csvline {
  my ($rord, $uid, %ohash) = @_;

  my @keys = @{$rord};

  my @todo = ();
  foreach my $key (@keys) {
    MMisc::error_quit("Problem accessing key ($key) from observation hash")
      if (! exists $ohash{$uid}{$key});
    push @todo, $ohash{$uid}{$key};
  }

  return(&generate_csvline(@todo));
}

#####

sub do_csv {
  my ($rord, %ohash) = @_;

  my @header = @{$rord};
  my $txt = "";

  $txt .= &generate_csvline(@header);
  $txt .= "\n";

  foreach my $uid (sort keys %ohash) {
    $txt .= &get_csvline($rord, $uid, %ohash);
    $txt .= "\n";
  }

  return($txt);
}

############################################################ Manual

=pod

=head1 NAME

TV08Mergehelper - TrecVid08 ViPER XML Events Observations Merger Helper

=head1 SYNOPSIS

B<TV08Mergehelper> S<[ B<--help> | B<--man> | B<--version> ]>
  S<[B<--xmllint> I<location>] [B<--TrecVid08xsd> I<location>]>
  S<[B<--gtf>] [B<--ForceFilename> I<filename>]>
  S<[B<--shift_overlap> B<--Same_overlap> [B<--overlaplistfile> [I<file>]]>
  S<[B<--OverlapOnlyXML>]] [B<--ecfhelperfile> [I<file.csv>]]>
  S<[B<--writetodir> I<directory> [B<--WriteMemDump> [I<mode>]]]>
  S<[B<--pruneEvents>]  [B<--keep_id>] [B<--no_comment>]>
  S<B<--fps> I<fps>>
  I<viper_source_file.xml[I<:frame_shift>]> [I<...>]

=head1 DESCRIPTION

B<TV08MergeHelper> will load ViPER XML files, extract all their I<Event> I<Observations> and for each I<Sourcefile filename> will generate a new ViPER XML file containing all its I<Event> I<Observations>.
The program can also perform I<frame shift> of input files, and if requested provide a list of possible overlaps found in the file's overlap framespans.
It can also geneate a CVS file to help the generation of an I<ECF> (used by B<TV08Scorer>).
XML comments are added within output files for each modifications to I<Events>, making it easier to find modifications and adaptations to I<Event> I<Observations>.

=head1 PREREQUISITES

B<TV08MergeHelper> input files need to pass the B<TV08ViperValidator> validation process, and relies on some external software and files.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<TV08_XMLLINT> environment variable.

=item B<FILES>

The syntactic validation requires some XML schema files (full list can be obtained using the B<--help> option).
It is possible to specify their location using the B<--xsdpath> option or the B<TV08_XSDPATH> environment variable.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

B<TV08MergeHelper> relies on some internal and external Perl libraries to function.

Simply running the B<TV08MergeHelper> script should provide you with the list of missing libraries. 
The following environment variables should be set in order for Perl to use the B<F4DE> libraries:

=over

=item B<F4DE_BASE>

The main variable once you have installed the software, it should be sufficient to run this program.

=item B<F4DE_PERL_LIB>

Allows you to specify a different directory for the B<F4DE> libraries.

=item B<TV08_PERL_LIB>

Allows you to specify a different directory for the B<TrecVid08> libraries.

=back

=back

=head1 GENERAL NOTES

B<TV08MergeHelper> expects that the file can be been validated using 'xmllint' against the TrecVid08 XSD file(s) (see B<--help> for files list).

B<TV08MergeHelper> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--ecfhelperfile> [I<file.csv>]

Ask B<TV08MergeHelper> to generate a CVS I<file.csv> (if provided, standard output otherwise) containing an entry per ViPER file with information required to help in the generation of an ECF file.

=item B<--ForceFilename> I<filename>

Force every ViPER XML file loaded to use I<filename> as its I<sourcefile> I<filename>.

=item B<--fps> I<fps>

Specify the default sample rate of the ViPER files.

=item B<--gtf>

Specify that the file to validate is a Reference file (also known as a Ground Truth File)

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--keep_id>

When adding an I<observation> to the merged file, keep the input file I<observation> ID or exit with an error message.

By default, when adding an I<observation> to the merged file, the newly created observation will have the first available ID.

=item B<--man>

Display this man page.

=item B<--no_comment>

Do not add any comment to the merged file explaining the source of the event I<observation>.

=item B<--OverlapOnlyXML>

Create a ViPER XML file containing only an extended framespan I<Observation> per I<Observation>s that overlapped. For example, if the first framespan is 10:20 and the second 15:30, the overlap region is 15:20 but the new observation's framespan will be 10:30.

=item B<--overlaplistfile> [I<file>]

Generate a report (written to I<file> if provided, standard output otherwise) listing all possible I<Event> I<Observation> overlaps seen according to the B<--shift_overlap> and B<--Same_overlap> heuristics.

=item B<--pruneEvents>

For each validated that is re-written, only add to this file's config section, events for which observations are seen

=item B<--Same_overlap>

Find I<Event> I<Observation> overlap found within the framespan where the I<Observation>'s ViPER file overlaps, for files whose framespan's middlepoint does match.

=item B<--shift_overlap>

Find I<Event> I<Observation> overlap found within the framespan where the I<Observation>'s ViPER file overlaps, for files whose framespan's middlepoint does not match.

=item B<--TrecVid08xsd> I<location>

Specify the default location of the required XSD files (use B<--help> to get the list of required files).
Can also be set using the B<TV08_XSDPATH> environment variable.

=item B<--version>

Display B<TV08MergeHelper> version information.

=item B<--WriteMemDump> [I<mode>]

In addition to writing the XML file, write a MemDump of the same file.

I<mode> information can be obtained using B<--help>.

=item B<--writetodir> I<directory>

Once merging has been completed, B<TV08MergeHelper> will write a new XML representation of the sourcefile's filename file to the provided I<directory>.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<TV08_XMLLINT> environment variable.

=back

=head1 USAGE

=item B<TV08MergeHelper --xmllint /local/bin/xmllint --TrecVid08xsd /local/F4DE-CVS/data sys_test1.xml sys_test2.xml sys_test3.xml --fps PAL --writetodir /tmp>

Will load the three I<system> files (specifying the default sample rate at the I<PAL> frame rate), using the I<xmllint> executable located at I</local/bin/xmllint> and the required XSD files found in the I</local/F4DE/data> directory. It will then write to the I</tmp> directory, one file per sourcefile's filename found in the input file. If I<sys_test1.xml> sourcefile's filename is I<testa.mpg>, and I<sys_test2.xml> and I<sys_test3.xml> sourcefile's filename is I<testb.mpg>, the program will write the files I</tmp/testas.mpg.xml> and I</tmp/testb.mpg.xml> containing the I<Event> I<Observations> seen in the I<system> files.

=item B<TV08MergeHelper --gtf -ForceFilename myvideo.mpg ref_test1.xml ref_test2.xml:2500 ref_test3.xml --fps NTSC --writetodir /tmp --shift_overlap --Same_overlap --overlaplistfile /tmp/ovlist.txt --ecfhelperfile ecfbase.csv>

Will load the three I<reference> files (specifying the default sample rate at the I<NTSC> frame rate), shifting I<ref_test2.xml> by I<2500> frames.
It will write a CVS file I<ecfbase.csv> that contains one entry per ViPER XML file (here one for I<rest_test1.xml>, I<ref_test2.xml> and I<ref_test3.xml>) containing among other things the ViPER file's sourcefile's filename, as well as the file's framespan range.
It forces all ViPER file's sourcefile's filename to be I<myvideo.mpg>, meaning that there will be only one output file I</tmp/myideo.mpg.xml>.
It will also write an B<overlaplistfile> I</tmp/ovlist.txt> that will contain both:

=over

=item * 
the list of B<Same_overlap> I<Event> I<Observations> overlaps.
By checking that for each pair of comparable I<Observations>, their file framespan range is the same for both related file (ie the ViPER file's I<NUMFRAMES> is equal), it will find I<Event> I<Observations> overlap within the files overlap zone (here the full file framespan range).

=item *
the list of B<shift_overlap> I<Event> I<Observations> overlaps.
By checking that for each pair of comparable I<Observations>, the file framespan range is different for two I<Observations>' file (ie the files middlepoint distance is not zero), it will find the I<Event> I<Observations> that overlap within the files overlap zone (if file1 has a framespan range of 1:100 and file2 50:200, the overlap zone is 50:100).

=back

Note that the program will give a unique ID to each overlap it found and store them within the output XML file.
The B<overlaplistfile> is just a way to easily see the list of overlap found. 

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=cut

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $wmd = join(" ", @ok_md);
  my $tmp=<<EOF

$versionid

Usage: $0 [--help | --man | --version] [--xmllint location] [--TrecVid08xsd location] [--gtf] [--ForceFilename filename] [--shift_overlap --Same_overlap [--overlaplistfile [file]] [--OverlapOnlyXML]] [--ecfhelperfile [file.csv]] [--writetodir dir [--WriteMemDump [mode]]] [--pruneEvents] [--keep_id] [--no_comment] --fps fps viper_source_file.xml[:frame_shift] [viper_source_file.xml[:frame_shift] [...]] 

Will merge event observations found in given files related to the same sourcefile's filename, and will try to provide help in merging overlapping or repeating observations.

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --gtf           Specify that the file to validate is a Ground Truth File
  --ForceFilename Specify that all files loaded refers to the same 'sourcefile' file
  --shift_overlap Will find overlap for frameshifted file's sourcefile which obersvations overlap in the file overlap section
  --Same_overlap  Will find overlap for the same file's sourcefile (ie not framshifted) which observations overlap
  --overlaplistfile   Save list of overlap found into file (or stdout if not provided)
  --OverlapOnlyXML    Create a XML file containing only overlap observations
  --ecfhelperfile Save a CSV file thaf contains information needed to generate the ECF file
  --writetodir    Once processed in memory, print the new XML dump files to this directory (the output filename will the sourcefile's filename with the xml extension) (If no writetodir option is specified, print to stdout)
  --WriteMemDump  Write a memory representation of validated ViPER Files that can be used by the Scorer and Merger tools. Two modes possible: $wmd (1st default)
  --pruneEvents   Only keep in the new file\'s config section events for which observations are seen
  --keep_id       Keep the event observation ID from the source file to the merged version (exit in error if impossible)
  --no_comment    Do not add comment(s) to the merged file 
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)

Note:
- This prerequisite that the file has already been validated against the 'TrecVid08.xsd' file (using xmllint)
- Program will ignore the <config> section of the XML file.
- 'TrecVid08xsd' files are: $xsdfiles
EOF
    ;

    return $tmp;
}
