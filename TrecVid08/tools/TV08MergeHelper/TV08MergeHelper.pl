#!/usr/bin/env perl

# TrecVid08 Viper XML File Merger
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Viper XML File Merger" is an experimental system.
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

my $versionid = "TrecVid08 Viper XML File Merger Version: $version";

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

# TrecVid08EventList (part of this tool)
unless (eval "use TrecVid08EventList; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"TrecVid08EventList\" is not available in your Perl installation. ", $partofthistool, $pe);
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

use Data::Dumper;

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

########################################
# Options processing

my @ov_modes = ("FrameShiftedFiles", "SameFramespanFiles", "All"); # Order is important
my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $writetodir = "";
my $fps = -1;
my $forceFilename = "";
my $olfile = undef;
my $show = 0;
my $do_shift_ov = 0;
my $do_same_ov = 0;
my $ecff = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:      F            ST   X      efgh      o   s  vwx  

my %opt;
my $dbgftmp = "";
GetOptions
  (
   \%opt,
   'help',
   'version',
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
   # Hidden option
   'X_show_internals+' => \$show,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

ok_quit("\n$usage\n") if ($opt{'help'});
ok_quit("$versionid\n") if ($opt{'version'});

error_quit("Not enough arguments\n$usage\n") if (scalar @ARGV == 0);

error_quit("\'fps\' must set in order to do be able to use \'observations\' objects\n\n$usage") if ($fps == -1);
error_quit("No \'writetodir\' set, aborting\n\n$usage\n") if ($writetodir =~ m%^\s*$%);

error_quit("\'ForceFilename\' option selected but no value set\n$usage") if (($opt{'ForceFilename'}) && ($forceFilename eq ""));

my %cov_todo;
$cov_todo{$ov_modes[0]}++ if ($do_shift_ov);
$cov_todo{$ov_modes[1]}++ if ($do_same_ov);
my $checkOverlap = scalar keys %cov_todo;

error_quit("\'overlaplistfile\' can only be used in conjunction with one of the overlap check mode\n$usage")
  if ((defined $olfile) && ($checkOverlap == 0));

if ($xmllint ne "") {
  error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

error_quit("Problem with \'writetodir\': $!")
  if ((! -e $writetodir) || (! -d $writetodir));

##############################
# Main processing

my $step = 1;
##########
print "\n\n** STEP ", $step++, ": Load all files to be merged\n";
my $ntodo = scalar @ARGV;
my $ndone = 0;
my %all_vf;
foreach my $tmp (@ARGV) {
  my ($fname, $fsshift) = &get_fname_fsshift($tmp);
  my $key = &make_key_from_fname_fsshift($fname, $fsshift);

  error_quit("File key ($key) seems to have already been loaded; can not load same file key multiple times, aborting")
    if (exists $all_vf{$key});

  my ($ok, $object) = &load_file($isgtf, $tmp, $fname, $fsshift);
  next if (! $ok);

  $all_vf{$key} = $object;
  $ndone++;

  if ($show > 3) {
    print "** FILE Key: $key\n";
    print $object->_display();
  }
}
print "* -> Loaded $ndone ok / $ntodo\n";
error_quit("Could not succesfully load all files processed, aborting\n")
  if ($ndone != $ntodo);
error_quit("No file loaded, aborting\n")
  if ($ndone == 0);

##########
print "\n\n** STEP ", $step++, ": Process all observations\n";

my %mergefiles;
my $EL = new TrecVid08EventList();
my ($adone, $akept);
error_quit("Problem creating the EventList (" . $EL->get_errormsg() . ")")
  if ($EL->error());
my %overlap_list;
my %overlap_ids;

my @ecfh = ("SourceFile Filename", "Framespan", "XGTF File"); # Order is important
my %ecfv;

foreach my $key (sort keys %all_vf) {
  my ($fname, $fsshift) = &get_fname_fsshift_from_key($key);

  my $object = $all_vf{$key};
  my $step2add = "";

  if ($forceFilename ne "") {
    $object->change_sourcefile_filename($forceFilename);
    error_quit("Problem while changing the sourcefile filename (" . $object->get_errormsg() .")")
      if ($object->error());
  }

  # Get the sourcefile filename
  my $sffn = $object->get_sourcefile_filename();
  error_quit("Problem obtaining the sourcefile filename (" . $object->get_errormsg() .")")
    if ($object->error());

  # Create the mergefile object for this sourcefile filename (if not existant yet)
  if (! defined $mergefiles{$sffn}) {
    my $mf = $object->clone_with_no_events();
    error_quit("While duplicating the source object (" . $object->get_errormsg() .")")
      if ($object->error());
    $mergefiles{$sffn} = $mf;
  }

  # Get the observation list for this viper file
  my @ao;
  # Starting with the dummy one
  my $dummy_obs = $object->get_dummy_observation();
  error_quit("While obtaining the dummy observation (" . $object->get_errormsg() .")")
    if ($object->error());
  push @ao, $dummy_obs;
  # Now all the others
  my @tao = $object->get_all_events_observations();
  error_quit("While obtaining all events' observations (" . $object->get_errormsg() .")")
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
      error_quit("While shifitng an observation's framespan (" . $obs->get_errormsg() .")")
	if ($obs->error());
    }
    $step2add .= " [FrameShifted ($fsshift frames)]";
  }

  # ECF Helper File
  if ($ecff ne "") {
    my $obs = $ao[0]; # Always true thanks to the dummy observation

    my $fl = $obs->get_filename();
    my $fn = $obs->get_xmlfilename();
    my $fs_file = $obs->get_fs_file();

    error_quit("Problem obtaining Observation's information (" . $obs->get_errormsg() . ")")
      if ($obs->error());

    my $value = $fs_file->get_value();

    error_quit("Problem obtaining Observation's Framespan's information (" . $fs_file->get_errormsg() . ")")
      if ($fs_file->error());

    my $key = "$fl-$value-$fn";

    my $inc = 0;
    $ecfv{$key}{$ecfh[$inc++]} = $fl;
    $ecfv{$key}{$ecfh[$inc++]} = $value;
    $ecfv{$key}{$ecfh[$inc++]} = $fn;
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
  $EL->add_Observations(@ao);
  error_quit("Problem adding Observations to EventList (" . $EL->get_errormsg() . ")")
    if ($EL->error());

  my $fobs = scalar @ao - 1; # Remove the dummy obs
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
  error_quit("While obtaining dummy Observations list ($key) (" . $EL->get_errormsg() .")")
    if ($EL->error());
  foreach my $obs (@bucket) {
    $mf->extend_numframes_from_observation($obs);
    error_quit("While \'extend_numframes_from_observation\' (" . $mf->get_errormsg() .")")
      if ($mf->error());
  }    
  # Then we add the rest of the observations
  foreach my $i (@ok_events) {
    my @bucket = $EL->get_Observations_list($key, $i);
    $fobs += scalar @bucket;
    error_quit("While obatining Observations list ($key / $i) (" . $EL->get_errormsg() .")")
      if ($EL->error());
    foreach my $obs (@bucket) {
      # Add a comment to the observation to indicate where it came from
      my $comment = "Was originally: " . $obs->get_unique_id();
      $obs->addto_comment($comment);
      error_quit("While adding a comment to observation (" . $obs->get_errormsg() .")")
	if ($obs->error());
      
      # Debugging
      if ($show > 1) {
	print "** OBSERVATION MEMORY REPRESENATION:\n", $obs->_display();
      }
      
      $mf->add_observation($obs);
      error_quit("While \'add_observation\' (" . $mf->get_errormsg() .")")
	if ($mf->error());
    }
  }

  if ($show) {
    print "** MERGED FILE MEMORY REPRESENTATION:\n";
    print $mf->_display();
  }

  my $txt = $mf->reformat_xml();
  error_quit("While trying to re-represent XML (" . $mf->get_errormsg() . ")")
    if ($mf->error());

  my $writeto = "$writetodir/$key.xml";
  open WRITETO, ">$writeto"
    or error_quit("Could not create output XML file ($writeto): $!\n");
  print WRITETO $txt;
  close WRITETO;
  print "Wrote: $writeto", (($fobs == 0) ? " (No observation)" : ""), "\n";

  $fdone++;
}
print "* -> Wrote $fdone files (out of $ftodo)\n";

error_quit("Not all file could be processed, aborting")
  if ($fdone != $ftodo);

####################
# Optional step: write ecf helper file

if ($ecff ne "") {
  print "\n\n** STEP ", $step++, ": ECF Helper File\n";
  open ECFF, ">$ecff"
    or error_quit("Can not create \'ecfhelperfile\' ($ecff): $!");

  my $txt = &do_csv(\@ecfh, %ecfv);

  print ECFF $txt;
  close ECCF;
  print "Wrote: $ecff\n";
}

ok_quit("\nDone.\n") if (! defined $olfile);

##########
# Optional step only performed if overlap list is requested

print "\n\n** STEP ", $step++, ": Overlap List\n";
my %ovl;
foreach my $key (keys %overlap_list) {
  $ovl{$key}++;
}
foreach my $key (sort keys %mergefiles) {
  my ($seen, $txt) = &prepare_overlap_list($key);
#  next if (! $seen); # Write the file even if no overlap is found

  if ($olfile ne "") {
    open OLF, ">$olfile"
      or error_quit("Could not create output \'overlaplistfile\' ($olfile): $!\n");
    print OLF $txt;
    close OLF;
    print "Wrote \'overlaplistfile\': $olfile\n";
  } else {
    print $txt
  }
  delete $ovl{$key};
}
error_quit("Some filenames left in overlap list ? (" . join(" ", keys %ovl), "), aborting")
  if (scalar keys %ovl > 0);

ok_quit("\nDone.\n");

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

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF

$versionid

Usage: $0 [--help] [--version] [--gtf] [--xmllint location] [--TrecVid08xsd location] [--ForceFilename filename] [--shift_overlap --Same_overlap [--overlaplistfile [file]]] [--ecfhelperfile file.csv] viper_source_file.xml[:frame_shift] [viper_source_file.xml[:frame_shift] [...]] --fps fps --writetodir dir

Will perform a semantic validation of the Viper XML file(s) provided.

 Where:
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --writetodir    Once processed in memory, print the new XML dump files to this directory
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --ForceFilename Specify that all files loaded refers to the same 'sourcefile' file
  --shift_overlap Will find overlap for frameshifted file's sourcefile which obersvations overlap in the file overlap section
  --Same_overlap  Will find overlap for the same file's sourcefile (ie not framshifted) which observations overlap
  --overlaplistfile   Save list of overlap found into file (or stdout if not provided)
  --ecfhelperfile Save a CSV file thaf contains information needed to generate the ECF file
  --version       Print version number and exit
  --help          Print this usage information and exit

Note:
- This prerequisite that the file has already been validated against the 'TrecVid08.xsd' file (using xmllint)
- Program will ignore the <config> section of the XML file.
- 'TrecVid08xsd' files are: $xsdfiles
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

  error_quit("WEIRD: Left over in file key ? (" . join(" ", @rest) .")")
    if (scalar @rest > 0);

  return($fname, 0 + $fsshift);
}

#####

sub load_file {
  my ($isgtf, $tmp, $fname, $fsshift) = @_;

  if (! -e $fname) {
    &valerr($tmp, "file does not exists, skipping");
    return(0, ());
  }
  if (! -f $fname) {
    &valerr($tmp, "is not a file, skipping\n");
    return(0, ());
  }
  if (! -r $fname) {
    &valerr($tmp, "file is not readable, skipping\n");
    return(0, ());
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
  error_quit("While setting \'file\' ($fname) (" . $object->get_errormsg() . ")")
    if ( ! $object->set_file($fname) );
  
  # Validate (important to confirm that we can have a memory representation)
  if (! $object->validate()) {
    &valerr($tmp, $object->get_errormsg());
    return(0, ());
  }

  &valok($tmp, "Loaded");
  
  return(1, $object);
}

########################################


sub _ovc_core_get_eventlist {
  my $sffn = shift @_;

  # First, Do we already have observations for this file ?
  my $ifi = $EL->is_filename_in($sffn);
  error_quit("While trying to check if a file was in the EventList (" . $EL->get_errormsg() . ")")
    if ($EL->error());

  return() if (! $ifi);

  # Get the event list
  my @el = $EL->get_events_list($sffn);
  error_quit("While trying to obtain the events from the EventList (" . $EL->get_errormsg() . ")")
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
	error_quit("Problem comparing observations while checking overlap (" . $ao_obs->get_errormsg() . ")")
	  if ($ao_obs->error());
	next if (! $iscmp); # If those are not comparable (different filename or event), no need to keep going

	my $lpov = 0;
	my $fs_ov = undef;
	if ($mode eq $ov_modes[0]) { # frameshift
	  $fs_ov = &_ovc_frameshift($ao_obs, $el_obs);
	} elsif ($mode eq $ov_modes[1]) { # samefs
	  $fs_ov = &_ovc_samefs($ao_obs, $el_obs);
	} else {
	  error_quit("WEIRD: Not a recognized overlapcheck mode while checking the overlap");
	}
	if (defined $fs_ov) { # Overlap detected
	  my $ao_id = $ao_obs->get_unique_id();
	  my $el_id = $el_obs->get_unique_id();
	  my $ovr_txt = $fs_ov->get_value();
	  error_quit("Problem obtaining Framespan value (" . $fs_ov->get_errormsg() . ")")
	    if ($fs_ov->error());
	  my $ov_id = "${mode}-${event}-" . sprintf("%03d", $overlap_ids{$sffn}{$mode}{$event}++);
	  @{$overlap_list{$sffn}{$mode}{$event}{$ov_id}} = ($ao_id, $el_id, $ovr_txt);
	  $ao_obs->addto_comment("\'$mode\' Overlap [ID: $ov_id] with \"$el_id\" [overlap: $ovr_txt]");
	  error_quit("Problem adding a comment to observation (" . $ao_obs->get_errormsg() . ")")
	    if ($ao_obs->error());
	  $el_obs->addto_comment("\'$mode\' Overlap [ID: $ov_id] with \"$ao_id\" [overlap: $ovr_txt]");
	  error_quit("Problem adding a comment to observation (" . $el_obs->get_errormsg() . ")")
	    if ($el_obs->error());
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
  error_quit("Problem obtaining the observation's middlepoint distance (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($mpd);
}

#####

sub _ovc_get_file_ov {
  my ($ao, $el) = @_;

  my $ov = $ao->get_fs_file_overlap_from_obs($el);
  error_quit("Problem obtaining the observation's overlap (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($ov);
}

#####

sub _ovc_do_fs_overlap_obs2obs {
  my ($ao, $el) = @_;

  my $ov = $ao->get_framespan_overlap_from_obs($el);
  error_quit("Problem obtaining the fs overlap [obs2obs] (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($ov);
}

#####

sub _ovc_do_fs_overlap_obs2fs {
  my ($ao, $fs) = @_;

  my $ov = $ao->get_framespan_overlap_from_fs($fs);
  error_quit("Problem obtaining the fs overlap [obs2fs] (" . $ao->get_errormsg() . ")")
    if ($ao->error());

  return($ov);
}

##########

sub _ovc_frameshift {
  my ($ao, $el) = @_;

  my $mpd = &_ovc_get_file_mpd($ao, $el);
  # If the file's framespan middlepoint distance is 0, it means they use they have the same framespan, so they are not shifted from one to the other
  return(undef) if ($mpd == 0);

  my $ov = &_ovc_get_file_ov($ao, $el);
  # We get a ViperFramespan if there is an overlap at all or 'undef' otherwise
  # if the files do not overlap, we should not have to worry about a possible observation continuation
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
  # If the file's framespan middlepoint distance is 0, it means they use they have the same framespan, so they are not shifted from one to the other
  return(undef) if ($mpd != 0);

  # Both observations are in the same fs_file; let us see if the observations overlaps
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
  my @res;

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

sub quc { # Quote clean
  my $in = shift @_;

  $in =~ s%\"%\'%g;

  return($in);
}

#####

sub qua { # Quote Array
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
  my $txt = join(",", @in), "\n";

  return($txt);
}

#####

sub get_csvline {
  my ($rord, $uid, %ohash) = @_;

  my @keys = @{$rord};

  my @todo;
  foreach my $key (@keys) {
    error_quit("Problem accessing key ($key) from observation hash")
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
