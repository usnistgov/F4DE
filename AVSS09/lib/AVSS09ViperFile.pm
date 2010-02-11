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

# CLEARSequence (part of this tool [CLEARDT])
use CLEARSequence;

########################################

my $ok_domain = "SV";

my @ok_elements = 
  ( # Order is important ('PERSON' first and 'file' last)
   "PERSON",
   "FRAME",
   "I-FRAMES",
   "file",
  );

my @ok_person_elements =
  ( # Order is important:
   # - 'framespan' is to be present in all
   # - 'LOCATION' is the only other authorized in SYS files
   # - for GTFs, 'LOCATION' and 'OCCLUSION' are the only elements authorized
   # to have sparse values (ie not covering the entire framespan _without_ gap)
   "framespan",
   "LOCATION",
   "OCCLUSION",
   "AMBIGUOUS",
   "PRESENT",
   "SYNTHETIC",
   );

my @ok_objects = ();
my @xsdfilesl  = ();
my $cdtspmode = "";

#####

sub get_okdomain { return($ok_domain); } 

########################################

sub get_cdtspmode {
  &__set_cdtspmode() if (MMisc::is_blank($cdtspmode));

  return($cdtspmode);
}

#####

sub __set_cdtspmode {
  return if (! MMisc::is_blank($cdtspmode));

  my $dummy = new CLEARDTViperFile();
  $cdtspmode = $dummy->get_AVSS09_spmode_key();
}

##########

sub __set_full_objects_list {
  return if (scalar @ok_objects != 0);

  my $dummy = new CLEARDTViperFile($ok_domain, &get_cdtspmode());
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

  my $dummy = new CLEARDTViperFile($ok_domain, &get_cdtspmode());
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
    $tmp = CLEARDTViperFile->new($ok_domain, &get_cdtspmode());
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
         (\&CLEARDTViperFile::_addto_comment, [0], $comment));
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

  return(MMisc::get_sorted_MemDump(\$self));
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
  my ($rin, $rout) = MMisc::compare_arrays(\@ok_elements, \@fh_keys);
  return($self->_set_error_and_return("Found unknown elements in file [" . join(", ", @$rout) . "]", 0))
    if (scalar @$rout > 0);

  # Then do a deeper check on PERSON keys and framespans
  my ($issys) = $self->check_if_sys();
  return(0) if ($self->error());

  my $pk = $ok_elements[0];

  # No PERSON defintion, nothing else to do
  return(1) if (! exists $fhash{$pk});

  my @pid = keys %{$fhash{$pk}};

  foreach my $id (@pid) {
    my @keys = keys %{$fhash{$pk}{$id}};

    my @lope = MMisc::clone(@ok_person_elements);

    my @slope = @lope; # Selected "local" ok_person_elements
    @slope = @lope[0..1] if ($issys);

#    my ($rin, $rout) = MMisc::compare_arrays(\@keys, \@slope);
    my ($rin, $rout) = MMisc::compare_arrays(\@slope, \@keys);
    return($self->_set_error_and_return("Found unknown elements in file [" . join(", ", @$rout) . "]", 0))
      if (scalar @$rout > 0);

    my $dummy = shift @slope; # Get 'framespan'
    my $fsv = $fhash{$pk}{$id}{$dummy};
    $fsv = $self->__validate_fs($fsv);
    return(0) if ($self->error());

    # For SYS files, that is all the needed to be checked
    next if ($issys);

    # For GTFs, check the remaining elements' framespan for full coverage
    my ($b, $e) = $self->__get_fs_beg_end($fsv);
    $fsv = $self->__validate_fs("$b:$e");
    return(0) if ($self->error());

    $dummy = shift @slope; # Remove LOCATION
    $dummy = shift @slope; # and OCCLUSION
    foreach my $attr (@slope) {
      next if (! exists $fhash{$pk}{$id}{$attr});
      my @fsl = keys %{$fhash{$pk}{$id}{$attr}};
      my $tfs = join(" ", @fsl);
      $tfs = $self->__validate_fs($tfs);
      return(0) if ($self->error());
      # On a text level, both values should be the same
      return($self->_set_error_and_return("Value framespan ($tfs) does not cover full range ($fsv) for $pk / $id / $attr", 0))
        if ($tfs ne $fsv);
    }
  }
    
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

  my @tmpa = keys %{$fhash{$pk}};
  my @keys = MMisc::reorder_array_numerically(\@tmpa);
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

sub __fs2vfs {
  my ($fs) = @_;

  my $fs_fs = new ViperFramespan();
  return("Problem creating ViperFramespan", undef)
    if ((!defined $fs_fs) || ($fs_fs->error()));

  $fs_fs->set_value($fs);
  return("Problem with framespan ($fs): " . $fs_fs->get_errormsg(), undef)
    if ($fs_fs->error());

  return("", $fs_fs);
}

#####

sub __self_fs2vfs {
  my ($self, $fs) = @_;

  my ($err, $fs_fs) = &__fs2vfs($fs);
  return($self->_set_error_and_return($err, undef))
    if (! MMisc::is_blank($err));

  return($fs_fs);
}

#####

sub _shift_fs {
  my ($v, $fss) = @_;

  my ($err, $tmp_fs) = &__fs2vfs($v);
  return($err) if (! MMisc::is_blank($err));

  # Note: we are using value_shift and not negative_value_shift
  # because we want an error message if the shift create a non
  # valid framespan
  $tmp_fs->value_shift_auto($fss);
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
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"reformat_xml\" on validated XML files", 0))
    if (! $self->is_validated());

  return($self->__cldt_caller
         (\&CLEARDTViperFile::reformat_xml, [0], @ok_objects));
}

##########

sub get_XML_filename { 
  my ($fn) = @_;
  return(CLEARDTHelperFunctions::get_XML_filename($fn));
}

#####

sub get_VFMemDump_filename { 
  my ($fn) = @_;
  return(CLEARDTHelperFunctions::get_VFMD_filename($fn));
}

#####

sub get_SSMemDump_filename { 
  my ($fn) = @_;
  return(CLEARDTHelperFunctions::get_SSMD_filename($fn));
}

#####

sub write_XML {
  my ($self, $fname, $isgtf, $ptxt) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"write_XML\" on validated XML files", 0))
    if (! $self->is_validated());

  my $cldt = $self->__get_cldt();
  return(0) if ($self->error());

  return(CLEARDTHelperFunctions::save_ViperFile_XML($fname, $cldt, 1, $ptxt, @ok_objects));
}

##########

sub write_MemDumps {
  my ($self, $fname, $isgtf, $mdm, $skip_smd) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"write_MemDump\" on validated XML files", 0))
    if (! $self->is_validated());

  my $cldt = $self->__get_cldt();
  return(0) if ($self->error());

  # First write the ViperFile MemDump
  return($self->_set_error_and_return("Problem writing the \'Memory Dump\' representation of the ViperFile object"), 0)
    if (! CLEARDTHelperFunctions::save_ViperFile_MemDump($fname, $cldt, $mdm));

  # Then process the "sequence" (unless skip requested)
  return(1) if ($skip_smd);

  my $eval_sequence = CLEARSequence->new($fname);
  $self->_set_error_and_return("Failed scoring 'CLEARSequence' instance creation. $eval_sequence", 0)
    if (ref($eval_sequence) ne "CLEARSequence");

  $cldt->reformat_ds($eval_sequence, $isgtf, @ok_objects);
  $self->_set_error_and_return("Could not reformat Viper File: $fname. " . $cldt->get_errormsg(), 0)
    if ($cldt->error());

  $self->_set_error_and_return("Problem writing the 'Memory Dump' representation of the Scoring Sequence object", 0)
    if (! CLEARDTHelperFunctions::save_ScoringSequence_MemDump($fname, $eval_sequence, $mdm));

  return(1);
}

########################################

sub _union_fs {
  my ($v1, $v2) = @_;

  my ($err, $v1_fs) = &__fs2vfs($v1);
  return($err) if (! MMisc::is_blank($err));
  my ($err, $v2_fs) = &__fs2vfs($v2);
  return($err) if (! MMisc::is_blank($err));

  $v1_fs->union($v2_fs);
  return("While framespan union: " . $v1_fs->get_errormsg())
    if ($v1_fs->error());

  my $v = $v1_fs->get_value();

  return("", $v);
}

#####

sub _union_fhash_set {
  my ($k, $rfhash1, %fhash2) = @_;
  
  my %fhash1 = %{$rfhash1};
  
  return("Could not find \'$k\' in \"other\"")
    if (! exists $fhash2{$k});
  return("Could not find \'$k\'")
    if (! exists $fhash1{$k});
  
  my $fsk = "framespan";
  my $max = 0;

  foreach my $id (keys %{$fhash2{$k}}) {
    foreach my $key (keys %{$fhash2{$k}{$id}}) {
      return("Could not find corresonding entity in master hash ($k / $id / $key)")
        if (! exists $fhash1{$k}{$id}{$key});

      if ($key eq $fsk) { # Special case, no depth
        my $v1 = $fhash1{$k}{$id}{$key};
        my $v2 = $fhash2{$k}{$id}{$key};
        my ($err, $v) = &_union_fs($v1, $v2);
        return("While trying to do union over \"$k\"'s \"$key\": $err")
          if (! MMisc::is_blank($err));
        $fhash1{$k}{$id}{$key} = $v;
      } else { # 1 additional depth to keys of framespan
        my @fs1l = keys %{$fhash1{$k}{$id}{$key}};
        return("More than 1 entry for master hash's $k / $id / $key")
          if (scalar @fs1l > 1);
        my @fs2l = keys %{$fhash2{$k}{$id}{$key}};
        return("More than 1 entry for \"other\" hash's $k / $id / $key")
          if (scalar @fs2l > 1);
        my $v1 = $fs1l[0];
        my $v2 = $fs2l[0];
        my ($err, $v) = &_union_fs($v1, $v2);
        return("While trying to do union over \"$k\"'s \"$key\": $err")
          if (! MMisc::is_blank($err));
        # Nothing to do if $v == $v1 (ie no change in framespan)
        next if ($v1 eq $v);
        # Otherwise, create the new one
        $fhash1{$k}{$id}{$key}{$v} = $fhash1{$k}{$id}{$key}{$v1};
        # Delete the old one
        delete $fhash1{$k}{$id}{$key}{$v1};
        # Note that we do not care of the content, we simply copy the
        # first object's content
      }
    }
  }
  
  return("");
}

#####

sub merge {
  my ($self, $other) = @_;

  return(0) if ($self->error());

  return($self->_set_error_and_return("Can only use \"merge\" on validated XML files", 0))
    if (! $self->is_validated());

  return($self->_set_error_and_return("Problem with \"other\" entity of \"merge\": " . $other->get_errormsg()))
    if ($other->error());

  return($self->_set_error_and_return("Can only use \"merge\" on validated XML files (other)", 0))
    if (! $other->is_validated());

  my $sffn1 = $self->get_sourcefile_filename();
  my $sffn2 = $other->get_sourcefile_filename();

  return($self->_set_error_and_return("Sourcefile's filename do not match ($sffn1 vs $sffn2)", 0))
    if ($sffn1 ne $sffn2);
  
  # Get the 'fhash's
  my %fhash1 = $self->_get_cldt_fhash();
  return(0) if ($self->error());
  my %fhash2 = $other->_get_cldt_fhash();
  return($self->_set_error_and_return("Problem obtaining \"other\"'s data:" . $other->get_errormsg(), 0))
    if ($other->error());

  ### Process in order
  my @ak = MMisc::clone(@ok_elements);
  my @atc = ();

  # PERSON (the easy one: copy each ID from 2 to 1 and error if already exist)
  my $k = shift @ak;
  if (exists $fhash2{$k}) {
    foreach my $id (keys %{$fhash2{$k}}) {
      return($self->_set_error_and_return("\"$k\" ID ($id) already exist, will not overwrite it", 0))
        if (exists $fhash1{$k}{$id});
      %{$fhash1{$k}{$id}} = MMisc::clone(%{$fhash2{$k}{$id}});
    }
  } # else: nothing to duplicate to first hash

  # I-FRAMES (ViperFramespan overlap entries)
  my $k = shift @ak;
  my ($err) = &_union_fhash_set($k, \%fhash1, %fhash2);
  return($self->_set_error_and_return("Problem while working on \"$k\": $err", 0))
    if (! MMisc::is_blank($err));

  # FRAMES
  my $k = shift @ak;
  my ($err) = &_union_fhash_set($k, \%fhash1, %fhash2);
  return($self->_set_error_and_return("Problem while working on \"$k\": $err", 0))
    if (! MMisc::is_blank($err));

  # file's NUMFRAMES
  my $k = shift @ak;
  my $nf = "NUMFRAMES";
  return($self->_set_error_and_return("Could not find master's \"$k\"'s \"$nf\" key", 0))
    if (! exists $fhash1{$k}{$nf});
  return($self->_set_error_and_return("Could not find \"other\"'s \"$k\"'s \"$nf\" key", 0))
    if (! exists $fhash2{$k}{$nf});
  if ($fhash2{$k}{$nf} > $fhash1{$k}{$nf}) {
    my $cm = $fhash1{$k}{$nf};
    my $max = $fhash2{$k}{$nf};
    push @atc, "Merge-Modified $nf from $cm to $max";
    # We also have to modify the 'framespan_max'
    $self->_extend_framespan_max($max);
    return(0) if ($self->error());
    $fhash1{$k}{$nf} = $max;
  }
  
  my $ok = $self->_set_cldt_fhash(%fhash1);
  return(0) if ($self->error());

  push @atc, "Merged another file onto this one";
  foreach my $cmt (@atc) {
    $self->_addto_comment($cmt);
    return(0) if ($self->error());
  }

  return(1);
}

######################################## DCO, DCR, DCF add

sub _num_ { $a <=> $b; }

my $dcor_key = "AMBIGUOUS";
my $dcf_key = "EVALUATE";
my $occ_key = "OCCLUSION";

my $dco_kw = "DCO";
my $dcr_kw = "DCR";
my $dcf_kw = "DCF";

my $k_person = $ok_elements[0];
my $k_frame  = $ok_elements[1];
my $k_true = "true";
my $k_false = "false";

#####

sub __validate_fs {
  my ($self, $fs) = @_;

  my $fs_fs = $self->__self_fs2vfs($fs);
  return(undef) if ($self->error());

  return($fs_fs->get_value());
}

#####

sub __get_fs_beg_end {
  my ($self, $fs) = @_;

  my ($fs_fs) = $self->__self_fs2vfs($fs);
  return(undef, undef) if ($self->error());

  my ($b, $e) = $fs_fs->get_beg_end_fs();
  return($self->_set_error_and_return("Problem with ViperFramespan: " . $fs_fs->get_errormsg(), undef, undef))
    if ($fs_fs->error());

  return($b, $e);
}

#####

sub __vc_gfhash {
  my ($self) = @_;

  return($self->_set_error_and_return("Not a validated XML files", undef))
    if (! $self->is_validated());
  
  return($self->_get_cldt_fhash());
}

#####

sub is_person_id_in {
  my ($self, $id) = @_;

  my (%fhash) = $self->__vc_gfhash();
  return(-1) if ($self->error());

  return(1) if (exists $fhash{$k_person}{$id});

  return(0);
}

#####

sub get_person_id_list {
  my ($self) = @_;

  my (%fhash) = $self->__vc_gfhash();
  return(undef) if ($self->error());

  my @list = keys %{$fhash{$k_person}};

  return(@list);
}

#####

sub __get_fslist {
  my ($self, $k1, $k2, $k3) = @_;

  my (%fhash) = $self->__vc_gfhash();
  return(undef) if ($self->error());

  return($self->_set_error_and_return("Can not find request \"$k1\" ID ($k2)", undef))
    if (! exists $fhash{$k1}{$k2});
  return($self->_set_error_and_return("Can not find request \"$k1\" ID ($$k2)'s key ($k3)", undef))
    if (! exists $fhash{$k1}{$k2}{$k3});

  my @fs_list = keys %{$fhash{$k1}{$k2}{$k3}};
  return($self->_set_error_and_return("Could not find any framespan for requested \"$k1\" ID ($k2)'s key ($k3)", undef))
    if (scalar @fs_list == 0);

  return(@fs_list);
}

#####

sub get_person_fs {
  my ($self, $id) = @_;

  my @fs_list = $self->__get_fslist($k_person, $id, $dcor_key);
  return(undef) if ($self->error());

  my $fs= join(" ", @fs_list);
  
  return($self->__validate_fs($fs));
}

#####

sub __get_fslist_key_is {
  my ($self, $k1, $k2, $k3, $val, $oth_val) = @_;

  # Get the framespan list
  my (@fs_list) = $self->__get_fslist($k1, $k2, $k3);
  return(undef) if ($self->error());

  # Then check the keys in 'fhash'
  my %fhash = $self->_get_cldt_fhash();
  return(undef) if ($self->error());

  my @ofs = ();
  foreach my $fs (@fs_list) {
    return($self->_set_error_and_return("Can not find fhash location [$k1 / $k2 / $k3 / $fs]", undef))
      if (! exists $fhash{$k1}{$k2}{$k3}{$fs});
    my $tv = $fhash{$k1}{$k2}{$k3}{$fs};
    my ($err, $v) = MMisc::dive_structure($tv);
    return($self->_set_error_and_return("While checking variable status: $err", undef))
      if (! MMisc::is_blank($err));

    if ($v eq $val) {
      push @ofs, $fs;
      next;
    }

    return($self->_set_error_and_return("Unknow $k3 status ($v) for framespan ($fs)", undef))
      if ($v ne $oth_val);
  }

  return(@ofs);
}

##########

sub _is_DCX {
  # return the framespan where object is a DCO/R/F, undef otherwise 
  my ($self, $k1, $k2, $k3, $mode, $fk, $ofk) = @_;

  my ($ig) = $self->check_if_gtf();
  return(undef) if ($self->error());
  return($self->_set_error_and_return("$mode is only valid for GTF", undef))
    if (! $ig);

  my (@ofs) = $self->__get_fslist_key_is($k1, $k2, $k3, $fk, $ofk);
  return(undef) if ($self->error());

  # Not ?
  return(undef) if (scalar @ofs == 0);

  my $fs= join(" ", @ofs);
  
  return($self->__validate_fs($fs));
}

## 
sub is_DCO {
  my ($self, $id) = @_;
  return($self->_is_DCX($k_person, $id, $dcor_key, $dco_kw, $k_true, $k_false));
}

##
sub is_DCR {
  my ($self, $id) = @_;
  return($self->_is_DCX($k_person, $id, $dcor_key, $dcr_kw, $k_true, $k_false));
}
 
##
sub get_DCF {
  my ($self) = @_;
  return($self->_is_DCX($k_frame, '0', $dcf_key, $dcf_kw, $k_false, $k_true));
}

#####

sub __set_key_truefalse_fs_to {
  my ($self, $k1, $k2, $k3, $fstc, $to, $other) = @_;

  my @fs_list = $self->__get_fslist($k1, $k2, $k3);
  return(0) if ($self->error());

  my $ffs = $self->__validate_fs(join(" ", @fs_list));
  return(0) if ($self->error());
  
  my ($b, $e) = $self->__get_fs_beg_end($ffs);
  return(0) if ($self->error());
  
  my $fs_ffs = $self->__self_fs2vfs("$b:$e");
  return(0) if ($self->error());
  $ffs = $fs_ffs->get_value();

  my (%fhash) = $self->__vc_gfhash();
  return(0) if ($self->error());

  ##### If no framespan was specified, set everything to the requested value
  if (! defined $fstc) {
    # First, delete any previous value
    delete $fhash{$k1}{$k2}{$k3};

    # Set the replacement value
    $fhash{$k1}{$k2}{$k3}{$ffs} = [ $to ];    

    $self->_set_cldt_fhash(%fhash);
    return(0) if ($self->error());

    # We are done in this case
    return(1);
  }

  ##### If a framespan was specified
  
  # Confirm the requested framespan is within the actual framespan
  my $fs_fstc = $self->__self_fs2vfs($fstc);
  return(0) if ($self->error());
  $fstc = $fs_fstc->get_value();

  my $fs_ov = $fs_fstc->get_overlap($fs_ffs);
  return($self->_set_error_and_return("Problem with framespan overlap: " . $fs_fstc->get_errormsg(), 0))
    if ($fs_fstc->error());
  return($self->_set_error_and_return("Requested framespan ($fstc) is not within [$k1 / $k2 / $k3] 's framespan ($ffs)", 0))
    if (! defined $fs_ov);
  my $ov = $fs_ov->get_value();
  return($self->_set_error_and_return("Requested framespan ($fstc) goes beyond [$k1 / k2 / $k3] 's framespan ($ffs)", 0))
    if ($ov ne $fstc);

  # Now get the values in the object that are already at the requested value
  my (@to_fslist) = $self->__get_fslist_key_is($k1, $k2, $k3, $to, $other);
  return(0) if ($self->error());

  my $fs_to = undef;
  my $tofslist = "";
  # If any is already set
  if (scalar @to_fslist != 0) {
    # Make a framespan out of them
    $fs_to = $self->__self_fs2vfs(join(" ", @to_fslist));
    return(0) if ($self->error());
    $tofslist = $fs_to->get_value();
    
    # Do its union with the requested framespan to obtain the total list
    # of values to be set to this value
    my $ok = $fs_to->union($fs_ov);
    return($self->_set_error_and_return("Problem while doing the union of \'$to\' framespan ($tofslist) and requested framespans ($ov): " . $fs_to->get_errormsg(), 0))
      if ($fs_to->error());
  } else {
    # Otherwise, no union is possible and fs_to is equal to fs_ov
    $fs_to = $fs_ov;
  }
  my $fto = $fs_to->get_value();

  # Just do a check to see if it is all of the original object framespan ?
  if ($fto eq $ffs) {
    # First, delete any previous value
    delete $fhash{$k1}{$k2}{$k3};

    # Set the replacement value
    $fhash{$k1}{$k2}{$k3}{$ffs} = [ $to ];    

    $self->_set_cldt_fhash(%fhash);
    return(0) if ($self->error());

    # We are done in this case
    return(1);
  }

  # Otherwise, get "other" framespan values
  my $fs_other = $fs_to->bounded_not($b, $e);
  return($self->_set_error_and_return("Problem while obtaining \'$other\' framespan: " . $fs_to->get_errormsg(), 0))
    if ($fs_to->error());
  return($self->_set_error_and_return("Problem while obtaining \'$other\' framespan", 0))
    if (! defined $fs_other);

  # At this point, we have the final list of "to" and "other" framespans
  my @to_list = $fs_to->list_pairs();
  return($self->_set_error_and_return("Problem while obtaining \'$to\' framespan list: " . $fs_to->get_errormsg(), 0))
    if ($fs_to->error());
  my @other_list = $fs_other->list_pairs();
  return($self->_set_error_and_return("Problem while obtaining \'$other\' framespan list: " . $fs_other->get_errormsg(), 0))
    if ($fs_other->error());
  
  # Delete any previous value
  delete $fhash{$k1}{$k2}{$k3};

  # Fill the "to" values
  foreach my $fs (@to_list) {
    $fhash{$k1}{$k2}{$k3}{$fs} = [ $to ];    
  }
  # Then the "other" values
  foreach my $fs (@other_list) {
    $fhash{$k1}{$k2}{$k3}{$fs} = [ $other ];    
  }

  $self->_set_cldt_fhash(%fhash);
  return(0) if ($self->error());

  return(1);
}

##########

sub _flip_DCX {
  my ($self, $opt_fs, $k1, $k2, $k3, $mode, $fk, $ofk, $soc) = @_;

  my (@fs_list) = $self->__get_fslist($k1, $k2, $k3);
  return(undef) if ($self->error());

  my ($ig) = $self->check_if_gtf();
  return(undef) if ($self->error());
  return($self->_set_error_and_return("$mode is only valid for GTF", undef))
    if (! $ig);
  
  my $ok = $self->__set_key_truefalse_fs_to($k1, $k2, $k3, $opt_fs, $fk, $ofk);
  return(undef) if ($self->error());
  return($self->_set_error_and_return("An error occurred while $mode set", undef))
    if (! $ok);
  
  # Same order check
  my $ck  = ($soc) ? $fk : $ofk;
  my $ock = ($soc) ? $ofk : $fk;
  return($self->_is_DCX($k1, $k2, $k3, $mode, $ck, $ock));
}  

##### 'DCO'
sub _flip_DCO {
  my ($self, $ofs, $id, $fk, $ofk, $soc) = @_;
  return($self->_flip_DCX($ofs, $k_person, $id, $dcor_key, $dco_kw, $fk, $ofk, $soc));
}

## 
sub set_DCO {
  my ($self, $id, $ofs) = @_;
  return($self->_flip_DCO($ofs, $id, $k_true, $k_false, 1)); 
}

## 
sub unset_DCO {
  my ($self, $id, $ofs) = @_;
  return($self->_flip_DCO($ofs, $id, $k_false, $k_true, 0));
}

##### 'DCR'
sub _flip_DCR {
  my ($self, $ofs, $id, $fk, $ofk, $soc) = @_;
  return($self->_flip_DCX($ofs, $k_person, $id, $dcor_key, $dcr_kw, $fk, $ofk, $soc));
}

##
sub set_DCR {
  my ($self, $id, $ofs) = @_;
  return($self->_flip_DCR($ofs, $id, $k_true, $k_false, 1));
}

##
sub unset_DCR {
  my ($self, $id, $ofs) = @_;
  return($self->_flip_DCR($ofs, $id, $k_false, $k_true, 0));
}

##### 'DCF'
sub _flip_DCF {
  my ($self, $fs, $fk, $ofk, $soc) = @_;
  
  return($self->_set_error_and_return("No framespan provided for \'set_DCF\'", undef))
    if (! defined $fs);
  return($self->_flip_DCX($fs, $k_frame, '0', $dcf_key, $dcf_kw, $fk, $ofk, $soc));
}
  
##
sub add_DCF {
  my ($self, $fs) = @_;
  return($self->_flip_DCF($fs, $k_false, $k_true, 1));
}

##
sub remove_DCF {
  my ($self, $fs) = @_;
  return($self->_flip_DCF($fs, $k_true, $k_false, 0));
}

##### 'EVALUATE'
sub set_evaluate_all {
  my ($self) = @_;
  return($self->_flip_DCX(undef, $k_frame, '0', $dcf_key, $dcf_kw, $k_true, $k_false, 1));
}

##
sub set_evaluate_range {
  my ($self, $fs) = @_;

  return($self->_set_error_and_return("No framespan provided for \'set_evaluate_range\'", undef))
    if (! defined $fs);

  # First, "evaluate none"
  $self->_flip_DCX(undef, $k_frame, '0', $dcf_key, $dcf_kw, $k_false, $k_true, 1);
  return(undef) if ($self->error());

  # Then "evaluate the specified range"
  return($self->_flip_DCX($fs, $k_frame, '0', $dcf_key, $dcf_kw, $k_true, $k_false, 1));
}

##
sub get_evaluate_range {
  my ($self) = @_;
  return($self->_is_DCX($k_frame, '0', $dcf_key, $dcf_kw, $k_true, $k_false));
}

##########

sub _create_object_core {
  my ($self, $req_fs, $rloc_fs_bbox) = @_;

  return(undef) if ($self->error());

  return($self->_set_error_and_return("No location information", undef))
    if ((! defined $rloc_fs_bbox) || (scalar(keys %$rloc_fs_bbox) == 0));

  my ($err, $fs_fs) = &__fs2vfs($req_fs);
  return($self->_set_error_and_return("Invalid $k_person global framespan ($req_fs): $err", undef))
    if (! MMisc::is_blank($err));
  my $fs = $fs_fs->get_value();

  my %object;

  my ($ig) = $self->check_if_gtf();
  %object =  (
              'AMBIGUOUS' => { $fs => [ $k_false ] },
              'OCCLUSION' => { $fs => [ $k_false ] },
              'PRESENT'   => { $fs => [ $k_true  ] },
              'SYNTHETIC' => { $fs => [ $k_false ] }
             ) if ($ig);

  $object{'framespan'} = $fs;

  foreach my $lfs (keys %$rloc_fs_bbox) {
    my ($err, $fs_lfs) = &__fs2vfs($lfs);
    return($self->_set_error_and_return("Invalid location framespan ($lfs): $err", undef))
      if (! MMisc::is_blank($err));

    my @bbox = @{$$rloc_fs_bbox{$lfs}};
    return($self->_set_error_and_return("Not a valid location boundingbox for framespan ($lfs)", undef))
    if (scalar @bbox != 4);

    return($self->_set_error_and_return("Location framespan ($lfs) is not within englobing framespan ($fs)", undef))
      if (! $fs_lfs->is_within($fs_fs));

    $object{'LOCATION'}{$lfs} = [ @bbox ];
  }
    
  return(%object);
}

#####

sub create_SYS_object {
  my ($self, $req_fs, $rloc_fs_bbox) = @_;

  my $ig = $self->check_if_gtf();
  return(0) if ($self->error());
  return($self->_set_error_and_return("Can not add a SYS object to a GTF", 0))
    if ($ig);

  my (%fhash) = $self->__vc_gfhash();
  return(0) if ($self->error());

  my %object = $self->_create_object_core($req_fs, %{$rloc_fs_bbox});
  return(0) if ($self->error());

  my @idl = $self->get_person_id_list();
  return(0) if ($self->error());
  
  my $id = 1;
  if (scalar @idl > 0) {
    my @sidl = sort _num_ @idl;
    $id = $sidl[-1] + 1;
  }

  %{$fhash{$k_person}{$id}} = %object;

  my $ok = $self->_set_cldt_fhash(%fhash);
  return(0) if ($self->error());

  return($id);
}

#####

sub create_REF_object {
  my ($self, $req_fs, $rloc_fs_bbox, $rocc_fs) = @_;

  my $ig = $self->check_if_gtf();
  return(0) if ($self->error());
  return($self->_set_error_and_return("Can not add a GTf object to a SYS", 0))
    if (! $ig);

  my ($err, $fs_fs) = &__fs2vfs($req_fs);
  return($self->_set_error_and_return("Invalid $k_person global framespan ($req_fs): $err", 0))
    if (! MMisc::is_blank($err));
  my $fs = $fs_fs->get_value();

  return($self->_set_error_and_return("Invalid list of occluded framespans", 0))
    if (! defined $rocc_fs);
  my @occ_fsl = ();
  foreach my $lfs (@{$rocc_fs}) {
    my ($err, $fs_lfs) = &__fs2vfs($lfs);
    return($self->_set_error_and_return("Invalid occluded framespan ($lfs): $err", 0))
      if (! MMisc::is_blank($err));
    
    return($self->_set_error_and_return("occluded framespan ($lfs) is not within englobing framespan ($fs)", undef))
      if (! $fs_lfs->is_within($fs_fs));
 
    push @occ_fsl, $fs_lfs->get_value();
  }
  my $occ_fs = "";
  $occ_fs = $self->__validate_fs(join(" ", @occ_fsl))
    if (scalar @occ_fsl > 0);
  return(0) if ($self->error());

  my (%fhash) = $self->__vc_gfhash();
  return(0) if ($self->error());

  my %object = $self->_create_object_core($req_fs, $rloc_fs_bbox);
  return(0) if ($self->error());

  my @idl = $self->get_person_id_list();
  return(0) if ($self->error());
  
  my $id = 1;
  if (scalar @idl > 0) {
    my @sidl = sort _num_ @idl;
    $id = $sidl[-1] + 1;
  }

  %{$fhash{$k_person}{$id}} = %object;

  my $ok = $self->_set_cldt_fhash(%fhash);
  return(0) if ($self->error());

  if (! MMisc::is_blank($occ_fs)) { # Do we have anything to occlude ?
    my $ok = $self->_flip_DCX($occ_fs, $k_person, $id, $occ_key, "OCCLUDED", $k_true, $k_false);
    return(0) if ($self->error());
    return($self->_set_error_and_return("Could not add \"OCCLUDED\" entries to newly created $k_person (id $id)", 0))
      if (! defined $ok);
  }

  return($id);
}

##########

sub _create_DCOR {
  my ($self, $req_fs, $rloc_fs_bbox, $opt_fs, $mode) = @_;

  return(0) if ($self->error());

  my $ig = $self->check_if_gtf();
  return(0) if ($self->error());
  return($self->_set_error_and_return("$mode is only valid for GTF", 0))
    if (! $ig);

  # Create a REF object with no occluded frames
  my @occ_fs = ();
  my $id = $self->create_REF_object($req_fs, $rloc_fs_bbox, \@occ_fs);
  return(0) if ($self->error());
    
  # and then set it as a DCX
  my $ok = $self->_flip_DCX($opt_fs, $k_person, $id, $dcor_key, $mode, $k_true, $k_false, 1);
  return(0) if ($self->error());
  return($self->_set_error_and_return("Could not convert newly created $k_person (id $id) to a $mode", 0))
    if (! defined $ok);

  return($id);
}

## 
sub create_DCO {
  my ($self, $rfs, $rloc_fs_bbox, $ofs) = @_;
  return($self->_create_DCOR($rfs, $rloc_fs_bbox, $ofs, $dco_kw));
}

##
sub create_DCR {
  my ($self, $rfs, $rloc_fs_bbox, $ofs) = @_;
  return($self->_create_DCOR($rfs, $rloc_fs_bbox, $ofs, $dcr_kw));
}

############################################################

sub clone {
  my ($self) = @_;

  return(undef) if ($self->error());

  return($self->_set_error_and_return("Can only \"clone\" validated objects", undef))
    if (! $self->is_validated());

  my $cldt = $self->__get_cldt();
  my $new_cldt = $cldt->clone();

  my $ret = new AVSS09ViperFile($new_cldt);
  return($self->_set_error_and_return($ret->get_errormsg(), undef))
    if ($ret->error());

  # Force validation
  $ret->{validated} = 1;

  return($ret);
}

####################

sub clone_selected_ids {
  my ($self, @ids) = @_;

  return(undef) if ($self->error());
  my @kidl = $self->get_person_id_list();
  @ids = MMisc::make_array_of_unique_values(\@ids);

  my ($rin, $rout) = MMisc::confirm_first_array_values(\@ids, \@kidl);
  $self->_set_error_and_return("IDs not present: " . join(", ", @$rout), undef)
  if (scalar @$rout > 0);

  my ($rin, $rout) = MMisc::compare_arrays(\@ids, \@kidl);
 
  # We do not need to remove anything ? simply clone
  my $ret = $self->clone();
  return($ret) if (scalar @$rout == 0);
  
  my (%fhash) = $ret->_get_cldt_fhash();
 
 my $pk = $ok_elements[0];
  foreach my $id (@$rout) {
    delete $fhash{$pk}{$id};
  }

  my $ok = $ret->_set_cldt_fhash(%fhash);
  return($self->_set_error_and_return("Problem in clone: " . $ret->get_errormsg(), undef))
    if ($ret->error());

  # Force validation
  $ret->{validated} = 1;

  return($ret);
}

############################################################

1;
