package CLEARDTHelperFunctions;

# CLEAR Detection and Tracking HelperFunctions
#
# Original Author(s) & Additions: Martial Michel
# Modified by Vasant Manohar to suit CLEAR/VACE evaluation framework
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEARDTHelperFunctions.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CLEARDTHelperFunctions.pm Version: $version";

use ViperFramespan;
use CLEARDTViperFile;
use Sequence;

use MErrorH;
use MMisc;

use Data::Dumper;

############################################################
#################### 'save' / 'load' Memmory Dump functions

my $VF_MemDump_Suffix = ".VFmemdump";

my $VF_MemDump_FileHeader_cmp = "\#  CLEARDTViperFile MemDump";
my $VF_MemDump_FileHeader_gz_cmp = $VF_MemDump_FileHeader_cmp . " (Gzip)";
my $VF_MemDump_FileHeader_add = "\n\n";

my $VF_MemDump_FileHeader = $VF_MemDump_FileHeader_cmp 
  . $VF_MemDump_FileHeader_add;
my $VF_MemDump_FileHeader_gz = $VF_MemDump_FileHeader_gz_cmp
  . $VF_MemDump_FileHeader_add;

my $SS_MemDump_Suffix = ".SSmemdump";

my $SS_MemDump_FileHeader_cmp = "\#  CLEARDTScorinSequence MemDump";
my $SS_MemDump_FileHeader_gz_cmp = $SS_MemDump_FileHeader_cmp . " (Gzip)";
my $SS_MemDump_FileHeader_add = "\n\n";

my $SS_MemDump_FileHeader = $SS_MemDump_FileHeader_cmp 
  . $SS_MemDump_FileHeader_add;
my $SS_MemDump_FileHeader_gz = $SS_MemDump_FileHeader_gz_cmp
  . $SS_MemDump_FileHeader_add;

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

sub save_ScoringSequence_MemDump {
  my ($fname, $object, $mode) = @_;

  return(MMisc::dump_memory_object
	 ($fname, $SS_MemDump_Suffix, $object,
	  $SS_MemDump_FileHeader,
	  ($mode eq "gzip") ? $SS_MemDump_FileHeader_gz : undef )
	);
}

##########

sub load_ViperFile {
  my ($isgtf, $filename, $evaldomain, $frameTol, $xmllint, $xsdpath) = @_;

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
  
  return(&_load_XML_ViperFile($isgtf, $filename, $evaldomain, $frameTol, $xmllint, $xsdpath));
}

#####

sub _load_XML_ViperFile {
  my ($isgtf, $tmp, $evaldomain, $frameTol, $xmllint, $xsdpath) = @_;

  # Prepare the object
  my $object = new CLEARDTViperFile($evaldomain);

  return(0, undef, "While trying to set \'frameTol\' ("
         . $object->get_errormsg() . ")")
    if (! $object->set_frame_tolerance($frameTol));

  return(0, undef, "While trying to set \'xmllint\' (" 
	 . $object->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $object->set_xmllint($xmllint)) );

  return(0, undef, "While trying to set \'CLEARxsd\' (" 
	 . $object->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $object->set_xsdpath($xsdpath)) );

  return(0, undef, "While setting \'gtf\' status (" 
	 . $object->get_errormsg() . ")")
    if ( ($isgtf) && ( ! $object->set_as_gtf()) );

  return(0, undef, "While setting \'file\' ($tmp) (" 
	 . $object->get_errormsg() . ")")
    if ( ! $object->set_file($tmp) );

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

  return(0, undef, $rtxt . "Problem reading memory representation: Not a ViperFile MemDump") 
    if (ref $object ne "CLEARDTViperFile");

  # Error ?
  return(0, undef, $rtxt . $object->get_errormsg())
    if ($object->error());

  # Validate
  return(0, undef, $rtxt . $object->get_errormsg())
    if (! $object->is_validated());

  # GTF ?
 return(0, undef, $rtxt . "Object is not a GTF as expected")
   if ( ($isgtf) && (! $object->check_if_gtf()) );
  # or SYS ?
  return(0, undef, $rtxt . "Object is not SYS as expected")
    if ( (! $isgtf) && (! $object->check_if_sys()) );

  $object->set_required_hashes($object->get_domain());
  return(1, $object, $rtxt . "validates");
}

#####

sub load_ScoringSequence {
  my ($isgtf, $filename, $evaldomain, $frameTol, $xmllint, $xsdpath) = @_;

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

  return(&_load_MemDump_ScoringSequence($isgtf, $filename))
    if ( ($header eq $SS_MemDump_FileHeader_cmp)
	|| ($header eq $SS_MemDump_FileHeader_gz_cmp) );
  
  return(&_load_ScoringSequence_from_XML($isgtf, $filename, $evaldomain, $frameTol, $xmllint, $xsdpath));

}

#####

sub _load_ScoringSequence_from_XML {
  my ($isgtf, $filename, $evaldomain, $frameTol, $xmllint, $xsdpath) = @_;

  my ($ok, $object, $txt) = &load_ViperFile($isgtf, $filename, $evaldomain, $frameTol, $xmllint, $xsdpath);
  return(0, undef, $txt) if (! $ok);

  my @ok_objects = $object->get_full_objects_list();
  my $eval_sequence = Sequence->new($filename);
  return(0, undef, "Failed scoring 'Sequence' instance creation. $eval_sequence\n")
    if (ref($eval_sequence) ne "Sequence");

  $object->reformat_ds($eval_sequence, $isgtf, @ok_objects);
  return(0, undef, "Could not reformat Viper File: $filename. " . $object->get_errormsg() . "\n")
    if ($object->error());

  return(1, $eval_sequence, "");
}

#####

sub _load_MemDump_ScoringSequence {
  my ($isgtf, $file) = @_;

  my $object = MMisc::load_memory_object($file, $SS_MemDump_FileHeader_gz);

  my $rtxt = "[MemDump] ";

  return(0, undef, $rtxt . "Problem reading memory representation")
    if (! defined $object);

  return(0, undef, $rtxt . "Problem reading memory representation: Not a ScoringSequence MemDump") 
    if (ref $object ne "Sequence");

  # Error ?
  return(0, undef, $rtxt . $object->get_errormsg())
    if ($object->error());

  # Validate
  return(0, undef, $rtxt . $object->get_errormsg())
    if (! $object->is_validated());

  # GTF ?
 return(0, undef, $rtxt . "Object is not a GTF as expected")
   if ( ($isgtf) && (! $object->check_if_gtf()) );
  # or SYS ?
  return(0, undef, $rtxt . "Object is not SYS as expected")
    if ( (! $isgtf) && (! $object->check_if_sys()) );

  return(1, $object, $rtxt . "validates");
}

########################################

1;
