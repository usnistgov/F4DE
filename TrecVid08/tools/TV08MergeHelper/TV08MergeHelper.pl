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
       "\"TrecVid08EventList\" is not available in your Perl installation. ",
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

# Default values for variables

my $usage = &set_usage();
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $xmllint = "";
my $xsdpath = ".";
my $writetodir = "";
my $fps = -1;
my $forceFilename = "";
my $checkOverlap = 0;
my $show = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:                    T   X        gh   l      s  vwx  

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
   'overlap'         => \$checkOverlap,
   # Hidden option
   'show_internals+' => \$show,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

die("\n$usage\n") if (scalar @ARGV == 0);

die("ERROR: \'fps\' must set in order to do be able to use \'observations\' objects\n\n$usage") if ($fps == -1);
die("ERROR: No \'writetodir\' set, aborting\n\n$usage\n") if ($writetodir =~ m%^\s*$%);

die("ERROR: \'ForceFilename\' option selected but no value set\n$usage") if (($opt{'ForceFilename'}) && ($forceFilename eq ""));

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
my $tmp;
my $ntodo = scalar @ARGV;
my $ndone = 0;
my %all_vf;
my %all_fs_shift;

##########
print "\n\n** STEP 1: Load all files to be merged\n";
while ($tmp = shift @ARGV) {
  my $fname = $tmp;
  my $fs_shift = 0;

  if ($tmp =~ m%^(.+?)\:(\d+)$%) {
    $fname = $1;
    $fs_shift = $2;
  }

  my ($ok, $object) = &load_file($isgtf, $fname);
  next if (! $ok);

  $all_vf{$fname} = $object;
  $all_fs_shift{$fname} = $fs_shift;
  $ndone++;

  if ($show > 3) {
    print "** FILE: $fname\n";
    print $object->_display();
  }
}
print "* -> Loaded $ndone ok / $ntodo\n";
error_quit("Could not succesfully load all files processed, aborting\n")
  if ($ndone != $ntodo);
error_quit("No file loaded, aborting\n")
  if ($ndone == 0);

##########
print "\n\n** STEP 2: Process all observations\n";

my %mergefiles;
my $EL = new TrecVid08EventList();
my ($adone, $akept);
error_quit("Problem creating the EventList (" . $EL->get_errormsg() . ")")
  if ($EL->error());


foreach my $key (keys %all_vf) {
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
  my @ao = $object->get_all_events_observations();
  error_quit("While duplicating the source object (" . $object->get_errormsg() .")")
    if ($object->error());
  my @kept = ();

  # Debugging
  if ($show > 2) {
    foreach my $obs (@ao) {
      print "** OBSERVATION MEMORY REPRESENATION (Before Processing):\n", $obs->_display();
    }
  }

  # Timeshift
  if ($all_fs_shift{$key} != 0) {
    foreach my $obs (@ao) {
      $obs->shift_framespan($all_fs_shift{$key});
      error_quit("While shifitng an observation's framespan (" . $obs->get_errormsg() .")")
	if ($obs->error());
    }
    $step2add .= " [Timeshifted]";
  }

  # Overlap
  if ($checkOverlap) {
  } else {
    @kept = @ao;
  }

  # Debugging
  if (($show > 2) && ($step2add !~ m%^\s*$%)) {
    foreach my $obs (@ao) {
      print "** OBSERVATION MEMORY REPRESENATION (Post Processing):\n", $obs->_display();
    }
  }

  # Add the observations to the EventList
  $EL->add_Observations(@kept);
  error_quit("Problem adding Observations to EventList (" . $EL->get_errormsg() . ")")
    if ($EL->error());

  print "- Done processing Observations from '$key' (Found: ", scalar @ao, (($checkOverlap) ? (" / Kept: " . scalar @kept) : ""), ")$step2add\n";
  $adone += scalar @ao;
  $akept += scalar @kept;
}
print "* -> Found $adone Observations", (($checkOverlap) ? " (Kept: $akept)" : ""), "\n";


##########
print "\n\n** STEP 3: Writting merge file(s)\n";

my $fdone;
my $ftodo = scalar keys %mergefiles;
foreach my $key (keys %mergefiles) {
  my $mf = $mergefiles{$key};

  # Now add all observations from the current file to the output file
  foreach my $i (@ok_events) {
    my @bucket = $EL->get_Observations_list($key, $i);
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
  print "Wrote: $writeto\n";

  $fdone++;
}
print "* -> Wrote $fdone files (out of $ftodo)\n";

error_quit("Not all file could be written, aborting")
  if ($fdone != $ftodo);

die("\nDone.\n");

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
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

Usage: $0 [--help] [--version] [--gtf] [--xmllint location] [--TrecVid08xsd location] viper_source_file.xml[:frame_shift] [viper_source_file.xml[:frame_shift] [...]] --fps fps --writetodir dir

Will perform a semantic validation of the Viper XML file(s) provided.

 Where:
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable
  --TrecVid08xsd  Path where the XSD files can be found ($xsdfiles)
  --writetodir    Once processed in memory, print the new XML dump files to this directory
  --fps           Set the number of frames per seconds (float value) (also recognined: PAL, NTSC)
  --ForceFilename Specify that all files loaded refers to the same 'sourcefile' file
  --overlap       Consider framespan shift and overlap processing
  --version       Print version number and exit
  --help          Print this usage information and exit

Note:
- This prerequisite that the file has already been validated against the 'TrecVid08.xsd' file (using xmllint)
- Program will ignore the <config> section of the XML file.
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


sub load_file {
  my ($isgtf, $tmp) = @_;

  if (! -e $tmp) {
    &valerr($tmp, $isgtf, "file does not exists, skipping");
    return(0, ());
  }
  if (! -f $tmp) {
    &valerr($tmp, $isgtf, "is not a file, skipping\n");
    return(0, ());
  }
  if (! -r $tmp) {
    &valerr($tmp, $isgtf, "file is not readable, skipping\n");
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
  error_quit("While setting \'file\' ($tmp) (" . $object->get_errormsg() . ")")
    if ( ! $object->set_file($tmp) );
  
  # Validate (important to confirm that we can have a memory representation)
  if (! $object->validate()) {
    &valerr($tmp, $object->get_errormsg());
    return(0, ());
  }

  &valok($tmp, "Loaded");
  
  return(1, $object);
}
