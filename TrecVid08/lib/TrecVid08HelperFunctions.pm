package TrecVid08HelperFunctions;

# TrecVid08 HelperFunctions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08HelperFunctions.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;
use ViperFramespan;
use TrecVid08ViperFile;
use TrecVid08Observation;

use MErrorH;
use MMisc;

use Data::Dumper;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08HelperFunctions.pm Version: $version";


############################################################
#################### 'ViperFile_crop' functions

sub ViperFile_crop {
  my ($vf, $beg, $end) = @_;

  return("ViperFile is not validated, aborting", undef)
    if (! $vf->is_validated());
  
  return("End frame before Beginning frame, aborting", undef)
    if ($beg > $end);
  
  return("Beginning frame less than 1, aborting", undef)
    if ($beg < 1);

  my $onf = $vf->get_numframes_value();
  return("Problem obtaining the ViperFile NUMFRAMES value (" . $vf->get_errormsg() . ")", undef)
    if ($vf->error());

  return("Requested end goes past the File's NUMFRAMES, can only crop known values", undef)
    if ($end > $onf);

  ## Cropping is a 2 steps operations:
  # - trim to select values
  # - shifting all elements to the beginning of the 

  # Get an observation representation of all the viper file
  my @ao = $vf->get_all_events_observations();
  return("Problem while obtaining Observations (" . $vf->get_errormsg() . ")", undef)
    if ($vf->error());

  # We need a ViperFramespan to work overlap
  my $fps = $vf->get_fps();
  return("Problem obtaining the ViperFile's fps (" . $vf->get_errormsg() . ")", undef)
    if ($vf->error());
  my $fs_range = new ViperFramespan();
  $fs_range->set_value_beg_end($beg, $end);
  $fs_range->set_fps($fps);
  return("Problem creating a ViperFramespan (" . $fs_range->get_errormsg() . ")", undef)
    if ($fs_range->error());
  my $fsr_txt = $fs_range->get_value();
  return("Problem obtaining the ViperFramespan's value (" . $fs_range->get_errormsg() . ")", undef)
    if ($fs_range->error());

  # Trim each observation in turn
  my @left = ();
  foreach my $obs (@ao) {
    # Check if the observation is even overlapping with the area
    my $fs_ov = $obs->get_framespan_overlap_from_fs($fs_range);
    return("Problem computing the range overlap (" . $obs->get_errormsg() . ")", undef)
      if ($obs->error());
    next if (! defined $fs_ov);

    # Now, Trim to the fs_range
    my $trim_done = $obs->trim_to_fs($fs_range);
    return("Problem trimming observation to selected range (" . $obs->get_errormsg() . ")", undef)
      if ($obs->error());
    next if (! $trim_done);

    push @left, $obs;
  }

  # Now we simply shift by (1 - beg)
  # ex: new beg is 2000 we shift by -1999 to start at 1
  my $fsshift = 1 - $beg;
  if ($fsshift != 0) {
    foreach my $obs (@left) {
      $obs->shift_framespan($fsshift);
      return("Problem shifting observation (" . $obs->get_errormsg() . ")", undef)
	if ($obs->error());
    }
  }

  # Prepare the output ViperFile
  my $vfc = $vf->clone_with_no_events();

  # Next step is to adapt the ViperFile's NUMFRAMES to its new boundaries
  my $nf = $end + $fsshift; # fsshift is negative
  my $an = $vfc->modify_numframes($nf, "Trimmed to [$fsr_txt], then shifted by $fsshift to have the first frame start at 1");
  return("Problem modifying numframes (" . $vfc->get_errormsg() . ")", undef)
    if ($vfc->error());

  # And finaly to add the observations to the newly created file
  foreach my $obs (@left) {
    $vfc->add_observation($obs, 1);
    return("Problem adding cropped observations to viper file (" . $vfc->get_errormsg() . ")", undef)
      if ($vfc->error());
  }

  return("", $vfc);
}

############################################################
#################### 'save' / 'load' Memmory Dump functions

my $VF_MemDump_Suffix = ".memdump";

my $VF_MemDump_FileHeader_cmp = "\#  TrecVid08ViperFile MemDump";
my $VF_MemDump_FileHeader_gz_cmp = $VF_MemDump_FileHeader_cmp . " (Gzip)";
my $VF_MemDump_FileHeader_add = "\n\n";

my $VF_MemDump_FileHeader = $VF_MemDump_FileHeader_cmp 
  . $VF_MemDump_FileHeader_add;
my $VF_MemDump_FileHeader_gz = $VF_MemDump_FileHeader_gz_cmp
  . $VF_MemDump_FileHeader_add;

##########

sub save_ViperFile_MemDump {
  my ($fname, $object, $mode) = @_;

  return(MMisc::dump_memory_object
	 ($fname, $VF_MemDump_Suffix, $object,
	  $VF_MemDump_FileHeader,
	  ($mode eq "gzip") ? $VF_MemDump_FileHeader_gz : undef )
	);
}

##########

sub load_ViperFile {
  my ($isgtf, $filename, $fps, $xmllint, $xsdpath) = @_;

  return(0, undef, "file does not exists") 
    if (! -e $filename);

  return(0, undef, "is not a file")
    if (! -f $filename);

  return(0, undef, "file is not readable")
    if (! -r $filename);

  open FILE, "<$filename"
    or return(0, undef, "Problem opening file ($filename) : $!");

  my $header = <FILE>;
  close FILE;
  chomp $header;

  return(&_load_MemDump_ViperFile($isgtf, $filename))
    if ( ($header eq $VF_MemDump_FileHeader_cmp)
	|| ($header eq $VF_MemDump_FileHeader_gz_cmp) );
  
  return(&_load_XML_ViperFile($isgtf, $filename, $fps, $xmllint, $xsdpath));
}

#####

sub _load_XML_ViperFile {
  my ($isgtf, $tmp, $fps, $xmllint, $xsdpath) = @_;

  # Prepare the object
  my $object = new TrecVid08ViperFile();

  return(0, undef, "While trying to set \'xmllint\' (" 
	 . $object->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $object->set_xmllint($xmllint)) );

  return(0, undef, "While trying to set \'TrecVid08xsd\' (" 
	 . $object->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $object->set_xsdpath($xsdpath)) );

  return(0, undef, "While setting \'gtf\' status (" 
	 . $object->get_errormsg() . ")")
    if ( ($isgtf) && ( ! $object->set_as_gtf()) );

  return(0, undef, "While setting \'file\' ($tmp) (" 
	 . $object->get_errormsg() . ")")
    if ( ! $object->set_file($tmp) );

  return(0, undef, "While setting \'fps\' ($fps) (" 
	 . $object->get_errormsg() . ")")
    if ( (defined $fps) &&  ( ! $object->set_fps($fps) ) );

  # Validate
  return(0, undef, $object->get_errormsg())
    if (! $object->validate());

  return(1, $object, "");
}

#####

sub _load_MemDump_ViperFile {
  my ($isgtf, $file) = @_;

  my $object = MMisc::load_memory_object($file, $VF_MemDump_FileHeader_gz);

  my $rtxt = "[MemDump] ";

  return(0, undef, $rtxt . "Problem reading memory representation")
    if (! defined $object);

  return(0, undef, $rtxt . "Problem reading memory representation: Not a ViperFile MeMDump") 
    if (ref $object ne "TrecVid08ViperFile");

  # Error ?
  return(0, undef, $rtxt . $object->get_errormsg())
    if ($object->error());

  # Validate
  return(0, undef, $rtxt . $object->get_errormsg())
    if (! $object->validate());

  # GTF ?
 return(0, undef, $rtxt . "Object is not a GTF as expected")
   if ( ($isgtf) && (! $object->check_if_gtf()) );
  # or SYS ?
  return(0, undef, $rtxt . "Object is not SYS as expected")
    if ( (! $isgtf) && (! $object->check_if_sys()) );

  return(1, $object, $rtxt . "validates");
}
