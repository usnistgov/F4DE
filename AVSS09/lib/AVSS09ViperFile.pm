package AVSS09ViperFile;

# AVSS09 ViPER File handler

# Original Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS09ViperFile.pm" is an experimental system.
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

my $versionid = "AVSS09iperFile.pm Version: $version";

##########
# Check we have every module (perl wise)

# ViperFramespan.pm (part of this tool)
use ViperFramespan;

# MErrorH.pm
use MErrorH;

# "MMisc.pm"
use MMisc;

# CLEARDTViperFile (part of this tool)
use CLEARDTViperFile;

# CLEARDTHelperFunctions (part of this tool)
use CLEARDTHelperFunctions;

# Sequence (part of this tool [CLEARDT])
use Sequence;

# For internal dispay
use Data::Dumper;

########################################

my $ok_domain = "SV";

my @ok_elements = 
  ( # Order is important ('PERSON' first and 'file' last)
   "PERSON",
   "FRAME",
   "I-FRAMES",
   "file",
  );

my @ok_objects = ();
my @xsdfilesl  = ();

########################################

sub __set_full_objects_list {
  return if (scalar @ok_objects != 0);

    my $dummy = new CLEARDTViperFile();
    @ok_objects = $dummy->get_full_objects_list();
}  

#####

sub get_full_objects_list {
  &__set_full_objects_list() if (scalar @ok_objects == 0);

  return(@ok_objects);
}

##########

sub __set_required_xsd_files_list {
  return if (scalar @xsdfilesl != 0);

  my $dummy = new CLEARDTViperFile();
  @xsdfilesl = $dummy->get_required_xsd_files_list();
}

#####

sub get_required_xsd_files_list {
  &__set_required_xsd_files_list() if (scalar @xsdfilesl == 0);
  return(@xsdfilesl);
}

###############

## Constructor
sub new {
  my $class = shift @_;
  my $tmp = MMisc::iuv(shift @_, undef);

  my $errortxt = "";

  if (! defined $tmp) {
    $tmp = CLEARDTViperFile->new($ok_domain);
    $errortxt .= $tmp->get_errormsg() if ($tmp->error());
  }

  &__set_full_objects_list();
  &__set_required_xsd_files_list();

  my $errormsg = MErrorH->new("AVSS09ViperFile");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     cldt           => $tmp,
     errormsg       => $errormsg,
     validated      => 0,
    };

  bless $self;
  return($self);
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errormsg}->set_errormsg($txt);
}

##########

sub get_errormsg {
  my ($self) = @_;
  return($self->{errormsg}->errormsg());
}

##########

sub error {
  my ($self) = @_;
  return($self->{errormsg}->error());
}

##########

sub _set_error_and_return {
  my $self = shift @_;
  my $errormsg = shift @_;

  $self->_set_errormsg($errormsg);

  return(@_);
}

############################################################
# A lot of the code relies on simpleCLEARDTViperFile functionalities

sub __get_cldt {
  my ($self) = @_;

  my $cldt = $self->{cldt};
  return($self->_set_error_and_return("Undefined CLEARDTViperFile", undef))
    if (! defined $cldt);

  return($cldt);
}

#####

sub __cldt_caller {
  my ($self, $func, $rderr, @params) = @_;

  return(@$rderr) if ($self->error());

  my $cldt = $self->__get_cldt();
  return(@$rderr) if (! defined $cldt);

  my @ok = &{$func}($cldt, @params);
  return($self->_set_error_and_return($cldt->get_errormsg(), @$rderr))
    if ($cldt->error());

  return(@ok);
}

##########

sub get_required_xsd_files_list {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::get_required_xsd_files_list, [-1]));
}

########## 'xmllint'

sub set_xmllint {
  my ($self, $xmllint) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::set_xmllint, [0], $xmllint));
}

#####

sub _is_xmllint_set {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::_is_xmllint_set, [0]));
}

#####

sub get_xmllint {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::get_xmllint, [-1]));
}

########## 'xsdpath'

sub set_xsdpath {
  my ($self, $xsdpath) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::set_xsdpath, [0], $xsdpath));
}

#####

sub _is_xsdpath_set {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::_is_xsdpath_set, [0]));
}

#####

sub get_xsdpath {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::get_xsdpath, [-1]));
}

########## 'gtf'

sub set_as_gtf {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::set_as_gtf, [0]));
}

#####

sub check_if_gtf {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::check_if_gtf, [0]));
}

#####

sub check_if_sys {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::check_if_sys, [0]));
}

########## 'file'

sub set_file {
  my ($self, $file) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::set_file, [0], $file));
}

#####

sub get_file {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::get_file, [-1]));
}

##########

sub set_frame_tolerance {
  my ($self, $tif) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::set_frame_tolerance, [0], $tif));
}

#####

sub get_frame_tolerance {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::get_frame_tolerance, [0]));
}

######################################## Internal queries

sub get_sourcefile_filename {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::get_sourcefile_filename, [-1]));
}

#####

sub change_sourcefile_filename {
  my ($self, $nfn) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::change_sourcefile_filename, [-1], $nfn));
}

########## 'comment'

sub _addto_comment {
  my ($self, $comment) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::_addto_comment, [0]));
}

#####

sub _is_comment_set {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::_is_comment_set, [0]));
}

#####

sub _get_comment {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::_get_comment, [0]));
}

########################################

sub _display_all {
  my ($self) = @_;

  return(-1) if ($self->error());

  return(Dumper(\$self));
}

########## 'validate'

sub is_validated {
  my ($self) = @_;

  return(1)
    if ($self->{validated});

  return(0);
}

#####

sub _validate {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::validate, [0]));
}

######################################## 
## Access to CLEARDTViperFile's internal structures
# Note: we have to modify its 'fhash' directly since no "Observation" or
# "EventList" is available in the CLEAR code

sub _get_cldt_fhash {
  my ($self) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::_get_fhash, [-1]));
}

#####

sub _set_cldt_fhash {
  my ($self, %fhash) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::_set_fhash, [0], %fhash));
}

##########

sub __check_cldt_validity {
  my ($self) = @_;

  return(0) if ($self->error());

  # First check the domain
  my ($domain) = $self->__cldt_caller
    (\&CLEARDTViperFile::get_domain, [""]);
  return(0) if ($self->error());
  return($self->_set_error_and_return("Wrong domain for type [$domain] (expected: $ok_domain)", 0))
    if ($domain ne $ok_domain);

  # Then check the keys in 'fhash'
  my %fhash = $self->_get_cldt_fhash();
  return(0) if ($self->error());

  my @fh_keys = keys %fhash;
  my ($rin, $rout) = MMisc::compare_arrays(\@fh_keys, @ok_elements);
  return($self->_set_error_and_return("Found unknown elements in file [" . join(", ", @$rout) . "]", 0))
    if (scalar @$rout > 0);

  return(1);
}

##########

sub validate {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->is_validated());

  # cldt not yet validated ?
  my $ok = $self->_validate();
  return($ok) if ($ok != 1);

  # Checks
  my $ok = $self->__check_cldt_validity();
  return($ok) if ($ok != 1);

  $self->{validated} = 1;
  return(1);
}

########## Helper Functions

sub load_ViperFile {
  my ($isgtf, $filename, $frameTol, $xmllint, $xsdpath) = @_;

  my ($ok, $cldt, $err) = CLEARDTHelperFunctions::load_ViperFile
    ($isgtf, $filename, $ok_domain, $frameTol, $xmllint, $xsdpath);

  return($ok, undef, $err)
    if ((! $ok) || (! MMisc::is_blank($err)));

  my $it = AVSS09ViperFile->new($cldt);
  return(0, undef, $it->get_errormsg())
    if ($it->error());

  my $ok = $it->validate();
  return(0, undef, $it->get_errormsg())
    if ($it->error());
  return($ok, undef, "Problem during validation process")
    if (! $ok);

  return(1, $it, "");
}

#################### Add to each ID

sub add_to_id {
  my ($self, $toadd) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"add_to_id\" on validated XML files", 0))
    if (! $self->is_validated());

  my %fhash = $self->_get_cldt_fhash();
  return(0) if ($self->error());

  # No 'PERSON' in this file, return now
  my $pk = $ok_elements[0];
  return(1) if (! exists $fhash{$pk});

  my @keys = MMisc::reorder_array_numerically(keys %{$fhash{$pk}});
  @keys = reverse @keys
    if ($toadd > 0); # start from the end if we add to value to avoid duplicate

  foreach my $key (@keys) {
    my $nk = $key + $toadd;
    return($self->_set_error_and_return("Can not change ID to \"$nk\" (from \"$key\"), not an authorized value", 0))
      if ($nk < 0);

    return($self->_set_error_and_return("Can not add ($toadd) to ID ($key), an element with the expected value ($nk) already exists", 0))
      if (exists $fhash{$pk}{$nk});

    # Create the new one
    $fhash{$pk}{$nk} = $fhash{$pk}{$key};
    # Delete the old one
    delete $fhash{$pk}{$key};
  }

  my $ok = $self->_set_cldt_fhash(%fhash);
  return(0) if ($self->error());

  $self->_addto_comment("Added $toadd to each $pk ID");
  return(0) if ($self->error());

  return(1);
}

#################### Modify bounding boxes

sub _adddiv_bbv {
  my $v = shift @_;
  my $add = shift @_;
  my $mul = shift @_;

  $v *= $mul;
  $v += $add;
  $v = sprintf("%d", $v); # Rounding

  return($v);
}

#####

sub modify_bboxes {
  my ($self, $xadd, $yadd, $hwmul) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"modify_bboxes\" on validated XML files", 0))
    if (! $self->is_validated());

  my %fhash = $self->_get_cldt_fhash();
  return(0) if ($self->error());

  # No 'PERSON' in this file, return now
  my $pk = $ok_elements[0];
  return(1) if (! exists $fhash{$pk});

  my @keys = keys %{$fhash{$pk}};
  my $lk = "LOCATION";

  foreach my $key (@keys) {
    next if (! exists $fhash{$pk}{$key}{$lk});
    foreach my $fs (keys %{$fhash{$pk}{$key}{$lk}}) {
      my @bbox = @{$fhash{$pk}{$key}{$lk}{$fs}};
      my $x = shift @bbox;
      $x = &_adddiv_bbv($x, $xadd, $hwmul);
      my $y = shift @bbox;
      $y = &_adddiv_bbv($y, $yadd, $hwmul);
      my $h = shift @bbox;
      $h = &_adddiv_bbv($h, 0, $hwmul);
      my $w = shift @bbox;
      $w = &_adddiv_bbv($w, 0, $hwmul);
      return($self->_set_error_and_return("WEIRD: bbox contains more than just x,y,h,w ?", 0))
        if (scalar @bbox > 0);
      push @bbox, $x, $y, $h, $w;
      
      foreach my $v (@bbox) {
        return($self->_set_error_and_return("Modified bbox contains negative values", 0))
          if ($v < 0);
      }
      
      @{$fhash{$pk}{$key}{$lk}{$fs}} = @bbox;
    }
  }

  my $ok = $self->_set_cldt_fhash(%fhash);
  return(0) if ($self->error());

  $self->_addto_comment("Modified $pk bounding boxes using (x * $hwmul + $xadd, y * $hwmul + $yadd, h * $hwmul, w * $hwmul)");
  return(0) if ($self->error());

  return(1);
}

#################### Frames modifications

sub _extend_framespan_max {
  my ($self, $max) = @_;
  return($self->__cldt_caller
         (\&CLEARDTViperFile::_set_framespan_max_value, [0], "1:$max"));
}

#####

sub _shift_fs {
  my ($v, $fss) = @_;

  my $err = "";

  my $tmp_fs = ViperFramespan->new();
  return("Creating framespan: " . $tmp_fs->get_errormsg())
    if ($tmp_fs->error());

  $tmp_fs->set_value($v);
  return("Setting framespan value: " . $tmp_fs->get_errormsg())
    if ($tmp_fs->error());

  # Note: we are using value_shift and not negative_value_shift
  # because we want an error message if the shift create a non
  # valid framespan
  $tmp_fs->value_shift($fss);
  return("Shifting framespan value: " . $tmp_fs->get_errormsg())
    if ($tmp_fs->error());

  my $r = $tmp_fs->get_value();
  my $m = $tmp_fs->get_end_fs();

  return("", $r, $m);
}

#####

sub _fs_sort_core {
  my ($a, $b) = @_;

  my (@l1) = split(m%\:%, $a);
  my ($b1, $e1) = ($l1[0], $l1[-1]);

  my (@l2) = split(m%\:%, $b);
  my ($b2, $e2) = ($l2[0], $l2[-1]);

  # Order by beginning first
  return($b1 <=> $b2) if ($b1 != $b2);
  # by end if the beginning is the same
  return($e1 <=> $e2);
}

#####

sub _fs_sort {
  return(&_fs_sort_core($a, $b));
}

#####

sub _shift_fhash_set {
  my ($k, $fss, %fhash) = @_;

  return("", 0, %fhash)
    if (! exists $fhash{$k});

  my $fsk = "framespan";
  my $max = 0;

  foreach my $id (keys %{$fhash{$k}}) {
    foreach my $key (keys %{$fhash{$k}{$id}}) {
      if ($key eq $fsk) { # Special case, no depth
        my $v = $fhash{$k}{$id}{$key};
        (my $err, $v, my $tm) = &_shift_fs($v, $fss);
        return("While trying to shift \"$k\"'s \"$key\" entry by ($fss): $err")
          if (! MMisc::is_blank($err));
        $fhash{$k}{$id}{$key} = $v;
        $max = $tm if ($tm > $max);
      } else { # 1 additional depth to keys of framespan
        my @fsl = sort _fs_sort keys %{$fhash{$k}{$id}{$key}};
        @fsl = reverse @fsl
          if ($fss > 0); # start from the end if we add to framespan values
        foreach my $csf (@fsl) {
          my ($err, $v, $tm) = &_shift_fs($csf, $fss);
          return("While trying to shift \"$k\"'s \"$key\" entry by ($fss): $err")
            if (! MMisc::is_blank($err));
          return("While trying to shift \"$k\"'s \"$key\" entry by ($fss): An element already exists for \"$v\" key")
            if (exists $fhash{$k}{$id}{$key}{$v});
          # Create the new one
          $fhash{$k}{$id}{$key}{$v} = $fhash{$k}{$id}{$key}{$csf};
          # Delete the old one
          delete $fhash{$k}{$id}{$key}{$csf};

          $max = $tm if ($tm > $max);
        }
      }
    }
  }
  
  return("", $max, %fhash);
}

#####

sub shift_frames {
  my ($self, $fss) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"shift_frames\" on validated XML files", 0))
    if (! $self->is_validated());

  my %fhash = $self->_get_cldt_fhash();
  return(0) if ($self->error());

  my @ak = MMisc::clone(@ok_elements);
  my $max = 0;
  my @atc = ();

  # PERSON
  my $k = shift @ak;
  (my $err, my $tm, %fhash) = &_shift_fhash_set($k, $fss, %fhash);
  return($self->_set_error_and_return($err, 0))
    if (! MMisc::is_blank($err));
  $max = $tm if ($tm > $max);

  # I-FRAMES
  my $k = shift @ak;
  (my $err, my $tm, %fhash) = &_shift_fhash_set($k, $fss, %fhash);
  return($self->_set_error_and_return($err, 0))
    if (! MMisc::is_blank($err));
  $max = $tm if ($tm > $max);

  # FRAME
  my $k = shift @ak;
  (my $err, my $tm, %fhash) = &_shift_fhash_set($k, $fss, %fhash);
  return($self->_set_error_and_return($err, 0))
    if (! MMisc::is_blank($err));
  $max = $tm if ($tm > $max);
  
  # file's NUMFRAMES
  my $k = shift @ak;
  my $nf = "NUMFRAMES";
  return($self->_set_error_and_return("Could not find \"$k\"'s \"$nf\" key", 0))
    if (! exists $fhash{$k}{$nf});
  my $cm = $fhash{$k}{$nf};
  if ($cm < $max) {
    $fhash{$k}{$nf} = $max;
    push @atc, "Modified $nf from $cm to $max";
    # We also have to modify the 'framespan_max'
    $self->_extend_framespan_max($max);
    return(0) if ($self->error());
  }
  
  my $ok = $self->_set_cldt_fhash(%fhash);
  return(0) if ($self->error());

  push @atc, "Shifted framespans by $fss";
  foreach my $cmt (@atc) {
    $self->_addto_comment($cmt);
    return(0) if ($self->error());
  }

  return(1);
}

############################################################
## Helper functions

sub extract_transformations {
  my ($tmp) = @_;

  my $err = "";
  my $fname = $tmp;
  my $fsshift = 0;
  my @boxmod = ();
  my $idadd = 0;

  while ($tmp =~ s%([\@\:\#][^\@\:\#]+)$%%) {
    my $wrk = $1;
    if ($wrk =~ m%^\@([+-]?[\d\.]+)([+-][\d\.]+)x([\d\.]+)$%) {
      push @boxmod, $1, $2, $3;
      return("Filename extraction process: Can not have a muliplier value of 0")
        if ($3 == 0);
    } elsif ($wrk =~ m%^\:([+-]?\d+)$%) {
      $fsshift = $1;
    } elsif ($wrk =~ m%\#([+-]?\d+)$%) {
      $idadd = $1;
    } else {
      return("Unable to extract information for given command line option ($fname) [trying to extract from \"$wrk\"]");
    }
    $fname = $tmp;
  }
  
  return($err, $fname, $fsshift, $idadd, @boxmod);
}

#####

sub get_key_from_transformations {
  my ($fname, $fsshift, $idadd, $bmx, $bmy, $bmm) = 
    MMisc::iuav(\@_, "", 0, 0, 0, 0, 1);
  
  my $key = sprintf("%s|%012d|%012d|%012d|%012d|%012d",
                    $fname, $fsshift, $idadd, $bmx, $bmy, $bmm);
  
  return($key);
}

#####

sub get_transformations_from_key {
  my ($key) = @_;

  my ($fname, @allk) = split(m%\|%, $key);
  
  return("Could not extract key information")
    if (scalar @allk != 5);
  
  my @out = ();
  foreach my $entry (@allk) {
    push @out, sprintf("%d", $entry);
  }

  return("", $fname, @out);
}

##########

sub Transformation_Helper {
  my ($self, $forceFilename, $fsshift, $idadd, @boxmod) = @_;

  return(-1) if ($self->error());

  return($self->_set_error_and_return("Can only use \"Transformation_Helper\" on validated XML files", -1))
    if (! $self->is_validated());

  my $mods = 0;

  if (! MMisc::is_blank($forceFilename)) {
    $self->change_sourcefile_filename($forceFilename);
    return(-1)
      if ($self->error());
    $mods++;
  }

  if ($idadd != 0) {
    $self->add_to_id($idadd);
    return(-1)
      if ($self->error());
    $mods++;
  }

  if (scalar @boxmod == 3) {
    $self->modify_bboxes(@boxmod);
    return(-1)
      if ($self->error());
    $mods++;
  }

  if ($fsshift != 0) {
    $self->shift_frames($fsshift);
    return(-1)
      if ($self->error());
    $mods++;
  }

  # Return the number of modifications done
  return($mods);
}

########################################

sub reformat_xml {
  my ($self, $isgtf) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"reformat_xml\" on validated XML files", 0))
    if (! $self->is_validated());

  return($self->__cldt_caller
         (\&CLEARDTViperFile::reformat_xml, [0], $isgtf, @ok_objects));
}

##########

sub write_MemDumps {
  my ($self, $fname, $isgtf, $mdm, $skip_ss) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"write_MemDump\" on validated XML files", 0))
    if (! $self->is_validated());

  my $cldt = $self->__get_cldt();
  return(0) if ($self->error());

  # First write the ViperFile MemDump
  return($self->_set_error_and_return("Problem writing the \'Memory Dump\' representation of the ViperFile object"), 0)
    if (! CLEARDTHelperFunctions::save_ViperFile_MemDump($fname, $cldt, $mdm));

  # Then process the "sequence" (unless skip requested)
  return(1) if ($skip_ss);

  my $eval_sequence = Sequence->new($fname);
  $self->_set_error_and_return("Failed scoring 'Sequence' instance creation. $eval_sequence", 0)
    if (ref($eval_sequence) ne "Sequence");

  $cldt->reformat_ds($eval_sequence, $isgtf, @ok_objects);
  $self->_set_error_and_return("Could not reformat Viper File: $fname. " . $cldt->get_errormsg(), 0)
    if ($cldt->error());

  $self->_set_error_and_return("Problem writing the 'Memory Dump' representation of the Scoring Sequence object", 0)
    if (! CLEARDTHelperFunctions::save_ScoringSequence_MemDump($fname, $eval_sequence, $mdm));

  return(1);
}

############################################################

1;
