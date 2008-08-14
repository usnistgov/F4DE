package TrecVid08Observation;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 Observation
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08Observation.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;
use ViperFramespan;
use TrecVid08ViperFile;

use MErrorH;
use MMisc;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08Observation.pm Version: $version";

my @ok_events = ();
my @full_ok_events = ();
my @ok_subevents = ();
my %hasharray_inline_attributes = ();
my %hash_objects_attributes_types_dynamic = ();
my $dummy_et = "Fake_Event-Merger_Dummy_Type";

## Constructor
sub new {
  my ($class) = shift @_;

  my $errortxt = "";

  $errortxt .= "TrecVid08Observation's new does not accept any parameter. "
    if (scalar @_ > 0);

  my $tmp = &_get_TrecVid08ViperFile_infos();
  $errortxt .= "Could not obtain the list authorized events ($tmp). "
    if (! MMisc::is_blank($tmp));

  my $errormsg = new MErrorH("TrecVid08Observation");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     eventtype   => "",
     eventsubtype => "",
     id          => -1,
     filename    => "", # The 'sourcefile' referenced file
     xmlfilename => "", # The xml file that described this observation
     framespan   => undef,      # ViperFramespan object
     fs_file     => undef, # 'sourcefile filename' framespan (important for overlap computation and shift operations)
     isgtf       => -1,
     ofi         => undef,      # hash ref / Other File Information
     comment     => "", # Text that will be added to the XML file when rewritting it (used by merger)
     DetectionScore      => undef, # float
     DetectionDecision   => -1,    # binary
     BoundingBox => undef, # hash ref (with "real" ViperFramespan this time)
     Point       => undef, # hash ref (with "real" ViperFramespan this time)
     Xtra        => undef, # xtra attributes
     validated   => 0,    # To confirm all the values required are set
     cloneid     => 0,    # When cloning, still confirm that the uid is unique
     errormsg    => $errormsg,
    };

  bless $self;
  return($self);
}

#####

sub _get_TrecVid08ViperFile_infos {
  my $dummy = new TrecVid08ViperFile();
  @ok_events = $dummy->get_full_events_list();
  @full_ok_events = @ok_events;
  push @full_ok_events, $dummy_et;
  @ok_subevents = $dummy->get_full_subevents_list();
  %hasharray_inline_attributes = $dummy->_get_hasharray_inline_attributes();
  %hash_objects_attributes_types_dynamic = $dummy->_get_hash_objects_attributes_types_dynamic();
  return($dummy->get_errormsg());
}

##########

sub get_version {
  my ($self) = @_;

  return($versionid);
}

########## 'eventtype'

sub set_eventtype {
  my ($self, $etype) = @_;

  return(0) if ($self->error());

  if (! grep(m%^$etype$%, @full_ok_events) ) {
    $self->_set_errormsg("Type given ($etype) is not part of the authorized events list. ");
    return(0);
  }
  
  $self->{eventtype} = $etype;
  return(1);
}

#####

sub _is_eventtype_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{eventtype}));

  return(0);
}

#####

sub get_key_dummy_eventtype {
  my ($self) = @_;

  return(0) if ($self->error());

  return($dummy_et);
}

#####

sub get_eventtype {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_eventtype_set()) {
    $self->_set_errormsg("\'eventtype\' not set. ");
    return(0);
  }

  return($self->{eventtype});
}

########## 'eventsubtype'

sub set_eventsubtype {
  my ($self, $stype) = @_;

  return(0) if ($self->error());

  if (! grep(m%^$stype$%, @ok_subevents) ) {
    $self->_set_errormsg("Type given ($stype) is not part of the authorized event subtypes list. ");
    return(0);
  }
  
  $self->{eventsubtype} = $stype;
  return(1);
}

#####

sub is_eventsubtype_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{eventsubtype}));

  return(0);
}

#####

sub get_eventsubtype {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_eventsubtype_set()) {
    $self->_set_errormsg("\'eventsubtype\' not set. ");
    return(0);
  }

  return($self->{eventsubtype});
}

########## 'full event type' (ie type & subtype)

sub set_full_eventtype {
  my ($self, $ftype) = @_;

  return(0) if ($self->error());

  my ($etype, $stype) = TrecVid08ViperFile::split_full_event($ftype);

  return(0) if (! $self->set_eventtype($etype));
    
  return(1) if (MMisc::is_blank($stype));

  return(0) if (! $self->set_subeventtype($stype));

  return(1);
}

#####

sub get_full_eventtype {
  my ($self) = @_;

  my $etype = $self->get_eventtype();
  return("") if ($self->error());

  return(TrecVid08ViperFile::get_printable_full_event($etype, ""))
    if (! $self->is_eventsubtype_set());
  
  my $stype = $self->get_eventsubtype();
  return("") if ($self->error());

  return(TrecVid08ViperFile::get_printable_full_event($etype, $stype));
}

########## 'id'

sub set_id {
  my ($self, $id) = @_;

  return(0) if ($self->error());

  if ($id < 0) {
    $self->_set_errormsg("\'id\' can not be negative. ");
    return(0);
  }
  
  $self->{id} = $id;
  return(1);
}

#####

sub _is_id_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{id} != -1);

  return(0);
}

#####

sub get_id {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_id_set()) {
    $self->_set_errormsg("\'id\' not set. ");
    return(-1);
  }
  return($self->{id});
}

########## 'filename'

sub set_filename {
  my ($self, $fname) = @_;

  return(0) if ($self->error());

  if (MMisc::is_blank($fname)) {
    $self->_set_errormsg("Empty \'filename\'. ");
    return(0);
  }
  
  $self->{filename} = $fname;
  return(1);
}

#####

sub _is_filename_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{filename}));

  return(0);
}

#####

sub get_filename {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_filename_set()) {
    $self->_set_errormsg("\'filename\' not set. ");
    return(0);
  }
  return($self->{filename});
}

########## 'xmlfilename'

sub set_xmlfilename {
  my ($self, $fname) = @_;

  return(0) if ($self->error());

  if (MMisc::is_blank($fname)) {
    $self->_set_errormsg("Empty \'xmlfilename\'. ");
    return(0);
  }
  
  $self->{xmlfilename} = $fname;
  return(1);
}

#####

sub _is_xmlfilename_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{xmlfilename}));

  return(0);
}

#####

sub get_xmlfilename {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_xmlfilename_set()) {
    $self->_set_errormsg("\'xmlfilename\' not set. ");
    return(0);
  }
  return($self->{xmlfilename});
}

########## 'framespan'

sub set_framespan {
  my ($self, $fs_fs) = @_;

  return(0) if ($self->error());

  if ( (! defined $fs_fs) || (! $fs_fs->is_value_set() ) || (! $fs_fs->is_fps_set() ) ) {
    $self->_set_errormsg("Invalid \'framespan\'. ");
    return(0);
  }
  
  $self->{framespan} = $fs_fs;
  return(1);
}

#####

sub _is_framespan_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(0) if (! defined $self->{framespan});

  return(1) if ($self->{framespan}->is_value_set());

  return(0);
}

#####

sub get_framespan {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_framespan_set()) {
    $self->_set_errormsg("\'framespan\' not set. ");
    return(0);
  }

  return($self->{framespan});
}

########## 'fs_file'

sub set_fs_file {
  my ($self, $fs_file) = @_;

  return(0) if ($self->error());

  if ( (! defined $fs_file) || (! $fs_file->is_value_set() ) || (! $fs_file->is_fps_set() ) ) {
    $self->_set_errormsg("Invalid \'fs_file\'. ");
    return(0);
  }

  $self->{fs_file} = $fs_file;
  return(1);
}

#####

sub _is_fs_file_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(0) if (! defined $self->{fs_file});

  return(1) if ($self->{fs_file}->is_value_set());

  return(0);
}

#####

sub get_fs_file {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_fs_file_set()) {
    $self->_set_errormsg("\'fs_file\' not set. ");
    return(0);
  }

  return($self->{fs_file});
}

########## 'isgtf'

sub set_isgtf {
  my ($self, $status) = @_;

  return(0) if ($self->error());

  $self->{isgtf} = $status;
  return(1);
}

#####

sub _is_isgtf_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{isgtf} != -1);

  return(0);
}

#####

sub get_isgtf {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_isgtf_set()) {
    $self->_set_errormsg("\'isgtf\' not set. ");
    return(0);
  }

  return($self->{isgtf});
}

########## 'ofi'

sub set_ofi {
  my ($self, %entries) = @_;

  return(0) if ($self->error());

  if (scalar %entries == 0) {
    $self->_set_errormsg("Empty \'ofi\'. ");
    return(0);
  }

  $self->{ofi} = \%entries;
  return(1);
}

#####

sub _is_ofi_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{ofi});

  return(0);
}

#####

sub get_ofi {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_ofi_set()) {
    $self->_set_errormsg("\'ofi\' not set. ");
    return(0);
  }
  
  my $rofi = $self->{ofi};

  my %res = %{$rofi};

  return(%res);
}

########## 'comment'

sub addto_comment {
  my ($self, $comment) = @_;

  return(0) if ($self->error());

  $self->{comment} .= "\n" if ($self->is_comment_set());

  $self->{comment} .= $comment;
  return(1);
}

#####

sub is_comment_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{comment}));

  return(0);
}

#####

sub get_comment {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_comment_set()) {
    $self->_set_errormsg("\'comment\' not set. ");
    return(0);
  }

  return($self->{comment});
}

#####

sub clear_comment {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! $self->is_comment_set());

  $self->{comment} = "";

  return(1);
}

########## 'DetectionScore'

sub set_DetectionScore {
  my ($self, $DetectionScore) = @_;

  return(0) if ($self->error());

  $self->{DetectionScore} = $DetectionScore;
  return(1);
}

#####

sub _is_DetectionScore_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{DetectionScore});

  return(0);
}

#####

sub get_DetectionScore {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_DetectionScore_set()) {
    $self->_set_errormsg("\'DetectionScore\' not set. ");
    return(0);
  }

  return($self->{DetectionScore});
}

########## 'DetectionDecision'

sub set_DetectionDecision {
  my ($self, $DetectionDecision) = @_;

  return(0) if ($self->error());

  if ($DetectionDecision =~ m%^true$%i) {
    $DetectionDecision = 1;
  } elsif ($DetectionDecision =~ m%^false$%i) {
    $DetectionDecision = 0;
  } elsif (($DetectionDecision != 0) && ($DetectionDecision != 1)) {
    $self->_set_errormsg("Strange \'DetectionDecision\' value ($DetectionDecision). ");
    return(0);
  }
  
  $self->{DetectionDecision} = $DetectionDecision;
  return(1);
}

#####

sub _is_DetectionDecision_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{DetectionDecision} != -1);

  return(0);
}

#####

sub get_DetectionDecision {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_DetectionDecision_set()) {
    $self->_set_errormsg("\'DetectionDecision\' not set. ");
    return(0);
  }
  return($self->{DetectionDecision});
}

########## 'BoundingBox'

sub set_BoundingBox {
  my ($self, %entries) = @_;

  return(0) if ($self->error());

  if (scalar %entries == 0) {
    $self->_set_errormsg("Empty \'BoundingBox\'. ");
    return(0);
  }

  $self->{BoundingBox} = \%entries;
  return(1);
}

#####

sub _is_BoundingBox_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{BoundingBox});

  return(0);
}

#####

sub get_BoundingBox {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_BoundingBox_set()) {
    $self->_set_errormsg("\'BoundingBox\' not set. ");
    return(0);
  }

  my $rbb = $self->{BoundingBox};

  my %res = %{$rbb};

  return(%res);
}

########## 'Point'

sub set_Point {
  my ($self, %entries) = @_;

  return(0) if ($self->error());

  if (scalar %entries == 0) {
    $self->_set_errormsg("Empty \'Point\'. ");
    return(0);
  }

  $self->{Point} = \%entries;
  return(1);
}

#####

sub _is_Point_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{Point});

  return(0);
}

#####

sub get_Point {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_Point_set()) {
    $self->_set_errormsg("\'Point\' not set. ");
    return(0);
  }

  my $rp = $self->{Point};

  my %res = %{$rp};

  return(%res);
}

##########

sub _get_1keyhash_content {
  my %tmp = @_;        # Only one key in this hash, return its content

  my @keys = keys %tmp;

  return ("Found more than 1 key in the hash", ())
    if (scalar @keys > 1);
  return ("Found no key in the hash", ())
    if (scalar @keys == 0);

  return("", %{$tmp{$keys[0]}});
}

#####

sub key_attr_framespan {
  my ($self) = shift @_;
  return("ViperFramspan");
}

#####

sub key_attr_content {
  my ($self) = shift @_;
  return("Content");
}

#####

sub _get_set_selected_ok_choices {
  my @ok_choices = ("DetectionScore", "DetectionDecision", "BoundingBox", "Point"); # Order matters
  return(@ok_choices);
}

#####

sub _set_selected_core {
  my $self = shift @_;
  my $choice = shift @_;

  my @ok_choices = &_get_set_selected_ok_choices();

  if ($choice =~ m%^$ok_choices[0]$%) { # 'DetectionScore'
    return($self->set_DetectionScore(@_));
  } elsif ($choice =~ m%^$ok_choices[1]$%) { # 'DetectionDecision'
    return($self->set_DetectionDecision(@_));
  } elsif ($choice =~ m%^$ok_choices[2]$%) { # 'BoundingBox'
    return($self->set_BoundingBox(@_));
  } elsif ($choice =~ m%^$ok_choices[3]$%) { # 'Point'
    return($self->set_Point(@_));
  } else {
    $self->_set_errormsg("WEIRD: Could not select a choice in \'set_selected\' ($choice). ");
    return(0);
  }
}

#####

sub unset_selected {
  my $self = shift @_;
  
  my $choice = shift @_;

  return(0) if ($self->error());

  my @ok_choices = &_get_set_selected_ok_choices();
  if (! grep(m%^$choice$%, @ok_choices)) {
    $self->_set_errormsg("In \'set_selected\', choice ($choice) is not recognized. ");
    return(0);
  }

  $self->{$choice} = undef;
}

#####

sub set_selected {
  my $self = shift @_;
  
  my $choice = shift @_;

  return(0) if ($self->error());

  my @ok_choices = &_get_set_selected_ok_choices();
  if (! grep(m%^$choice$%, @ok_choices)) {
    $self->_set_errormsg("In \'set_selected\', choice ($choice) is not recognized. ");
    return(0);
  }

  # We have to worry about the "dynamic" and "number of inline attributes"

  if (! exists $hash_objects_attributes_types_dynamic{$choice}) {
    $self->_set_errormsg("In \'set_selected\', can not confirm the dynamic status of choice ($choice). ");
    return(0);
  }
  my $isd = $hash_objects_attributes_types_dynamic{$choice};

  if (! exists $hasharray_inline_attributes{$choice}) {
    $self->_set_errormsg("In \'set_selected\', can not confirm the number of inline attributes of choice ($choice). ");
    return(0);
  }
  my @attrs = $hasharray_inline_attributes{$choice};
  my $nattr = scalar @attrs;

  my %inhash = @_;
  # Master key is the "framespan" (string)
  # Sub level keys are obtained via key_attr_framespan and key_attr_content

  # For dynamic ones, we keep everything as is (including the number of inlines attributes)
  if ($isd) {
    return($self->_set_selected_core($choice, %inhash));
  } else {
    # For non dynamic elements we always drop the Viper framespan
    my ($errtxt , %oneelt) = &_get_1keyhash_content(%inhash);
    if (! MMisc::is_blank($errtxt)) {
      $self->_set_errormsg("In \'set_selected\', problem while extracting the one hash element for choice ($choice) ($errtxt). ");
      return(0);
    }
    if (! exists $oneelt{$self->key_attr_content()}) {
      $self->_set_errormsg("WEIRD: In \'set_selected\' can not obtain the \'content\' key. ");
      return(0);
    }
    my $rvalues = $oneelt{$self->key_attr_content()};
    my @values = @$rvalues;
    # For non dynamic 1 inline attribute, we only care about that one element
    if ($nattr == 1) {
      my $v = shift @values;
      return($self->_set_selected_core($choice, $v));
    } else {
      # For non dynamic multiple inline attributes, we keep the array
      return($self->_set_selected_core($choice, @values));
    }
  }
}

##########

sub get_selected {
  my ($self) = shift @_;
  my $choice = shift @_;

  my @ok_choices = &_get_set_selected_ok_choices();

  if ($choice =~ m%^$ok_choices[0]$%) { # 'DetectionScore'
    return(0, ()) if (! $self->_is_DetectionScore_set());
    return(1, $self->get_DetectionScore());
  } elsif ($choice =~ m%^$ok_choices[1]$%) { # 'DetectionDecision'
    return(0, ()) if (! $self->_is_DetectionDecision_set());
    return(1, $self->get_DetectionDecision());
  } elsif ($choice =~ m%^$ok_choices[2]$%) { # 'BoundingBox'
    return(0, ()) if (! $self->_is_BoundingBox_set());
    return(1, $self->get_BoundingBox());
  } elsif ($choice =~ m%^$ok_choices[3]$%) { # 'Point'
    return(0, ()) if (! $self->_is_Point_set());
    return(1, $self->get_Point());
  } else {
    $self->_set_errormsg("WEIRD: Could not select a choice in \'get_selected\' ($choice). ");
    return(0, ());
  }
}

########## 'xtra'

sub set_xtra_attribute {
  my ($self, $attr, $value, $replace) = @_;

  return(0) if ($self->error());

  if ((! $self->is_xtra_attribute_set($attr)) || ($replace)) {
    $self->{Xtra}{$attr} = $value;
  } else {
    $self->{Xtra}{$attr} .= " # $value";
  }

  return(1);
}

#####

sub is_xtra_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{Xtra});

  return(0);
}

#####

sub is_xtra_attribute_set {
  my ($self, $attr) = @_;

  return(0) if ($self->error());

  return(0) if (! $self->is_xtra_set());

  return(1) if (exists $self->{Xtra}{$attr});

  return(0);
}

#####

sub get_xtra_value {
  my ($self, $attr) = @_;

  return(0) if ($self->error());

  if (! $self->is_xtra_set()) {
    $self->_set_errormsg("\'Xtra\' not set. ");
    return(0);
  }

  if (! exists $self->{Xtra}{$attr}) {
    $self->_set_errormsg("\'Xtra\' for requested attribute ($attr) not set. ");
    return(0);
  }

  return($self->{Xtra}{$attr});
}

#####

sub list_xtra_attributes {
  my ($self) = @_;

  my @aa = ();

  return(@aa) if ($self->error());

  if (! $self->is_xtra_set()) {
    $self->_set_errormsg("\'Xtra\' not set. ");
    return(@aa);
  }

  @aa = keys %{$self->{Xtra}};

  return(@aa);
}

#####

sub unset_xtra {
  my ($self, $attr) = @_;

  return(0) if ($self->error());

  return(0)
    if (! exists $self->{Xtra}{$attr});

  delete $self->{Xtra}{$attr};

  my @aa = keys %{$self->{Xtra}};
  $self->{Xtra} = undef
    if (scalar @aa == 0);

  return(1);
}

#####

sub unset_all_xtra {
  my ($self) = @_;

  return(0) if ($self->error());

  # Thank you garbage collector
  $self->{Xtra} = undef;

  return(1);
}

########################################

sub is_validated {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{validated} == 1);

  return(0);
}

#####

sub validate {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->is_validated());
  # Confirm all is set in the observation
  
  # Required types:
  if (! $self->_is_eventtype_set()) {
    $self->set_errormsg("In \'validate\': \'eventtype\' not set");
    return(0);
  }
  if (! $self->_is_id_set()) {
    $self->set_errormsg("In \'validate\': \'id\' not set");
    return(0);
  }
  if (! $self->_is_filename_set()) {
    $self->set_errormsg("In \'validate\': \'filename\' not set");
    return(0);
  }
  if (! $self->_is_xmlfilename_set()) {
    $self->set_errormsg("In \'validate\': \'xmlfilename\' not set");
    return(0);
  }
  if (! $self->_is_framespan_set()) {
    $self->set_errormsg("In \'validate\': \'framespan\' not set");
    return(0);
  }
  if (! $self->_is_fs_file_set()) {
    $self->set_errormsg("In \'validate\': \'fs_file\' not set");
    return(0);
  }
  if (! $self->_is_isgtf_set()) {
    $self->set_errormsg("In \'validate\': \'isgtf\' not set");
    return(0);
  }
  if (! $self->_is_ofi_set()) {
    $self->set_errormsg("In \'validate\': \'ofi\' not set");
    return(0);
  }

  # For non GTF
  if (! $self->get_isgtf) { 
    if (! $self->_is_DetectionScore_set()) {
      $self->_set_errormsg("In \'validate\': \'DetectionScore\' not set (and observation is not a GTF)");
      return(0);
    }
    if (! $self->_is_DetectionDecision_set()) {
      $self->_set_errormsg("In \'validate\': \'DetectionDecision\' not set (and observation is not a GTF). ");
      return(0);
    }
  }
  return(0) if ($self->error());

  # We do not really care if 'BoundingBox' or 'Point' are present or not

  $self->{validated} = 1;
  return(1);
}

####################

sub _display {
  my ($self) = @_;

  return(0) if ($self->error());

  return MMisc::get_sorted_MemDump(\$self);
}

####################

sub is_comparable_to {
  my ($self, $other) = @_;

  # Error (pre)
  return(0) if ($self->error());
  if ($other->error()) {
    $self->_set_errormsg("Problem in the compared to object (" . $other->get_errormsg() ."). ");
    return(0);
  }

  # Validated ?
  if (! $self->is_validated()) {
    $self->_set_errormsg("Can not use calling object, it has not been validated yet. ");
    return(0);
  }
  if (! $other->is_validated()) {
    $self->_set_errormsg("Can not use compared to object, it has not been validated yet. ");
    return(0);
  }

  # Same eventtype ?
  my $e1 = $self->get_eventtype();
  my $e2 = $other->get_eventtype();
  return(0) if ($e1 ne $e2);

  # Same filename ?
  my $f1 = $self->get_filename();
  my $f2 = $other->get_filename();
  return(0) if ($f1 ne $f2);

  # Error (post)
  return(0) if ($self->error());
  if ($other->error()) {
    $self->_set_errormsg("Problem in the compared to object (" . $other->get_errormsg() ."). ");
    return(0);
  }

  return(1);
}

########################################

sub get_unique_id {
  my ($self) = @_;

  return(0) if ($self->error());

  return(0) if (!$self->is_validated());

  my $fl = $self->get_filename();
  my $fn = $self->get_xmlfilename();
  my $et = $self->get_eventtype();
  my $id = $self->get_id();
  my $isgtf = $self->get_isgtf();
  my $dec = (! $isgtf) ? $self->Dec() : "N/A";
  my $decd =(! $isgtf) ? (($self->get_DetectionDecision()) ? "true" : "false") : "N/A";
  my $fs_fs = $self->get_framespan();
  my $fs_file = $self->get_fs_file();
  my $cl = $self->get_clone_id();

  if ($self->error()) {
    $self->_set_errormsg("Problem while generating a unique id. ");
    return(0);
  }

  my $fs = $fs_fs->get_value();
  if ($fs_fs->error()) {
    $self->_set_errormsg("Problem while generating a unique id to obtain the fs value (" . $fs_fs->get_errormsg() . "). ");
    return(0);
  }

  my $fsf = $fs_file->get_value();
  if ($fs_file->error()) {
    $self->_set_errormsg("Problem while generating a unique id to obtain the fs value (" . $fs_file->get_errormsg() . "). ");
    return(0);
  }

  my $uid = "FILE: $fl | EVENT: $et | ID: $id | FS: $fs | FILE FS: $fsf | GTF : $isgtf | Dec: $dec ($decd) | XML FILE: $fn";
  $uid .= sprintf(" [Observation Clone #%04d]", $cl) if ($cl > 0);

  # One advantage of this unique string ID is that it can be 'sort'-ed
  return($uid);
}

######################################## Scoring prerequisites

sub _get_obs_framespan_core {
  my ($self) = @_;

  return(0, undef) if ($self->error());

  if (! $self->_is_framespan_set()) {
    $self->_set_errormsg("\'framespan\' not set. ");
    return(0, undef);
  }

  my $fs_v = $self->get_framespan();

  return (1, $fs_v);
}

#####

sub Dur {
  my ($self) = @_;

  my ($ok, $fs_v) = $self->_get_obs_framespan_core();
  return($ok) if (! $ok);

  my $d = $fs_v->extent_duration_ts();
  if ($fs_v->error()) {
    $self->_set_errormsg("While getting framespan's duration (" . $fs_v->get_errormsg() . "). ");
    return(0);
  }

  return($d);
}

#####

sub Beg {
  my ($self) = @_;

  my ($ok, $fs_v) = $self->_get_obs_framespan_core();
  return($ok) if (! $ok);

  my $d = $fs_v->get_beg_ts();
  if ($fs_v->error()) {
    $self->_set_errormsg("While getting framespan's beginning timestamp (" . $fs_v->get_errormsg() . "). ");
    return(0);
  }

  return($d);
}
  
#####

sub End {
  my ($self) = @_;

  my ($ok, $fs_v) = $self->_get_obs_framespan_core();
  return($ok) if (! $ok);

  my $d = $fs_v->get_end_ts();
  if ($fs_v->error()) {
    $self->_set_errormsg("While getting framespan's end timestamp (" . $fs_v->get_errormsg() . "). ");
    return(0);
  }

  return($d);
}

#####

sub Mid {
  my ($self) = @_;

  my ($ok, $fs_v) = $self->_get_obs_framespan_core();
  return($ok) if (! $ok);

  my $d = $fs_v->extent_middlepoint_ts();
  if ($fs_v->error()) {
    $self->_set_errormsg("While getting framespan's middlepoint (" . $fs_v->get_errormsg() . "). ");
    return(0);
  }

  return($d);
}

#####

sub Dec {
  my ($self) = @_;

  return(0) if ($self->error());

  my $isgtf = $self->get_isgtf();
  return($isgtf) if ($self->error());

  if ($isgtf) {
    $self->_set_errormsg("Can not get the \'DetectionScore' for a GTF observation. ");
    return(0);
  }

  my $ds = $self->get_DetectionScore();
  return($ds) if ($self->error());

  return($ds);
}

#####

# A get it all function
sub _get_BOTH_Beg_Mid_End_Dur{
  my ($self) = @_;

  return(0) if ($self->error());

  my $b = $self->Beg();
  return(0) if ($self->error());

  my $m = $self->Mid();
  return(0) if ($self->error());

  my $e = $self->End();
  return(0) if ($self->error());

  my $du = $self->Dur();
  return(0) if ($self->error());

  return ($b, $m, $e, $du);
}

#####

sub get_REF_Beg_Mid_End_Dur {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->_get_BOTH_Beg_Mid_End_Dur());
}

#####

sub get_SYS_Beg_Mid_End_Dur_Dec {
  my ($self) = @_;

  return(0) if ($self->error());

  my @o = $self->_get_BOTH_Beg_Mid_End_Dur();
  return(0) if ($self->error());

  my $de = $self->Dec();
  return(0) if ($self->error());

  return(@o, $de);
}

############################################################ framespan shift function

sub _shift_framespan_selected {
  my ($self, $choice, $val) = @_;

  my @ok_choices = &_get_set_selected_ok_choices();
  if (! grep(m%^$choice$%, @ok_choices)) {
    $self->_set_errormsg("In \'set_selected\', choice ($choice) is not recognized. ");
    return(0);
  }

  # We only need to worry about dynamic elements
  my $isd = $hash_objects_attributes_types_dynamic{$choice};
  return(1) if (! $isd);

  # Here we only have to worry about 'BoundingBox' and 'Point'
  # No ViperFramespan object is embedded in the structure itself (other than the key)
  # therefore we can simply perform a simple shift on the ViperFramespan "keys"
  # and regenerate the primary key from the shifted value
  my ($isset, %chash) = $self->get_selected($choice);
  return(0) if ($self->error());
  return(1) if (! $isset);

  my %ohash = ();
  my $key_fs = $self->key_attr_framespan();
  my $key_ct = $self->key_attr_content();
  foreach my $key (keys %chash) {
    my $fs_tmp = $chash{$key}{$key_fs};
    my $ct = $chash{$key}{$key_ct};

    $fs_tmp->value_shift($val);
    if ($fs_tmp->error()) {
      $self->_set_errormsg("Problem while shifting the framespan of $key (" . $fs_tmp->get_errormsg() . "). ");
      return(0);
    }

    my $txt_fs = $fs_tmp->get_value();

    $ohash{$txt_fs}{$key_fs} = $fs_tmp;
    $ohash{$txt_fs}{$key_ct} = $ct;
  }

  $self->set_selected($choice, %ohash);
  return(1);
}

#####

sub shift_framespan {
  my ($self, $val) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only shift framespan on validated Observations");
    return(0);
  }

  my $fs_fs = $self->get_framespan();
  return(0) if ($self->error());

  my $fs_file = $self->get_fs_file();
  return(0) if ($self->error());

  $fs_fs->value_shift($val);
  if ($fs_fs->error()) {
    $self->_set_errormsg("Problem while shifting the framespan (" . $fs_fs->get_errormsg() . "). ");
    return(0);
  }

  $fs_file->value_shift($val);
  if ($fs_file->error()) {
    $self->_set_errormsg("Problem while shifting the file framespan (" . $fs_file->get_errormsg() . "). ");
    return(0);
  }
  # Since we work with objects, no need to set the values back

  # 'ofi' NUMFRAMES
  my $key = TrecVid08ViperFile::get_Numframes_fileattrkey();
  my %ofi = $self->get_ofi();
  if (! exists $ofi{$key}) {
    $self->_set_errormsg("WEIRD: Problem accessing the ofi \'$key\' information. ");
    return(0);
  }
  $ofi{$key} += $val;
  $self->set_ofi(%ofi);

  # other attributes
  my @ok_choices = &_get_set_selected_ok_choices();
  foreach my $choice (@ok_choices) {
    $self->_shift_framespan_selected($choice, $val);
    return(0) if ($self->error());
  }

  # Add a comment
  $self->addto_comment("Framespan was shifted by $val");
  return(0) if ($self->error());

  return(1);
}

############################################################ trim functions

sub _trim_framespan_selected {
  my ($self, $choice, $fs_ov) = @_;

  my @ok_choices = &_get_set_selected_ok_choices();
  if (! grep(m%^$choice$%, @ok_choices)) {
    $self->_set_errormsg("In \'set_selected\', choice ($choice) is not recognized. ");
    return(0);
  }

  # We only need to worry about dynamic elements
  my $isd = $hash_objects_attributes_types_dynamic{$choice};
  return(1) if (! $isd);

  # No ViperFramespan object is embedded in the structure itself (other than the key)
  # therefore we can simply perform a prunning
  # and regenerate the primary key from the shifted value
  my ($isset, %chash) = $self->get_selected($choice);
  return(0) if ($self->error());
  return(1) if (! $isset);

  my %ohash = ();
  my $key_fs = $self->key_attr_framespan();
  my $key_ct = $self->key_attr_content();
  my $doneany = 0;
  foreach my $key (keys %chash) {
    my $fs_tmp = $chash{$key}{$key_fs};
    my $ct = $chash{$key}{$key_ct};

    my $fs_nov = $fs_tmp->get_overlap($fs_ov);
    if ($fs_tmp->error()) {
      $self->_set_errormsg("Problem while checking \'get_overlap\' for the framespan of $key (" . $fs_tmp->get_errormsg() . "). ");
      return(0);
    }

    # We only want to keep framespans that are overlapping
    next if (! defined $fs_nov);

    my $txt_fs = $fs_nov->get_value();

    $ohash{$txt_fs}{$key_fs} = $fs_nov;
    $ohash{$txt_fs}{$key_ct} = $ct;
    $doneany++;
  }

  # If all elements were trimmed, make sure to clean the type
  if ($doneany == 0) {
    $self->unset_selected($choice);
  } else {
    $self->set_selected($choice, %ohash);
  }

  return(0) if ($self->error());

  return(1)
}

#####

sub trim_to_fs {
  my ($self, $lfs) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only trim framespan on validated Observations");
    return(0);
  }

  # Obtain a copy of the requested framespan in order not to use
  # the same object in future operations
  my $fs = $lfs->clone();
  if ($lfs->error()) {
    $self->_set_errormsg("Problem cloning Framespan (" . $lfs->get_errormsg() . "(");
    return(0);
  }

  my $fs_ov = $self->get_framespan_overlap_from_fs($fs);
  return(0) if ($self->error());

  # If there is no overlap possible, simply return '0' but do not set an error
  return(0) if (! defined $fs_ov);
  
  ## From here on, we know there is an overlap possible
  my $fs_fs = $self->get_framespan();
  return(0) if ($self->error());
  my $beg_range = $fs_fs->get_value();
  if ($fs_fs->error()) {
    $self->_set_errormsg("Prolem obtaining the Observation framespan value (" . $fs_fs . ")");
    return(0);
  }
  
  # First, set the file framespan to the requested range
  $self->set_fs_file($fs);
  return(0) if ($self->error());
  
  # Then, set the observation framespan to the overlap range
  $self->set_framespan($fs_ov);
  return(0) if ($self->error());

  # 'ofi' NUMFRAMES
  my $key = TrecVid08ViperFile::get_Numframes_fileattrkey();
  my %ofi = $self->get_ofi();
  if (! exists $ofi{$key}) {
    $self->_set_errormsg("WEIRD: Problem accessing the ofi \'$key\' information. ");
    return(0);
  }
  my $end = $fs->get_end_fs();
  if ($fs->error()) {
    $self->_set_errormsg("Problem obtaining the trim framespan's end value (" . $fs->get_errormsg() . ")");
    return(0);
  }
  $ofi{$key} = $end;
  $self->set_ofi(%ofi);

  # trim other attributes
  my @ok_choices = &_get_set_selected_ok_choices();
  foreach my $choice (@ok_choices) {
    $self->_trim_framespan_selected($choice, $fs_ov);
    return(0) if ($self->error());
  }

  # Add a comment
  my $fs_fs = $self->get_framespan();
  return(0) if ($self->error());
  my $end_range = $fs_fs->get_value();
  if ($fs_fs->error()) {
    $self->_set_errormsg("Problem obtaining the Observation framespan value (" . $fs_fs . ")");
    return(0);
  }

  $self->addto_comment("Trimmed from [$beg_range] to [$end_range]");
  return(0) if ($self->error());

  return(1);
}

############################################################ overlap functions

#################### 'fs_file'

sub _ov_get_fs_file {
  my ($self) = @_;

  # Error (pre)
  return(0) if ($self->error());

  # Validated ?
  if (! $self->is_validated()) {
    $self->_set_errormsg("Observation has not been validated yet. ");
    return(0);
  }

  my $fs_self = $self->get_fs_file();
  return(0) if ($self->error());

  return($fs_self);
}

##########

sub get_fs_file_extent_middlepoint_distance {
  my ($self, $fs_self, $fs_other) = @_;

  my $mpd = $fs_self->extent_middlepoint_distance($fs_other);
  if ($fs_self->error()) {
    $self->_set_errormsg("Problem obtaining \'fs_file\' 's \'extent_middlepoint_distance\' (" . $self->get_errormsg() ."). ");
    return(undef);
  }

  return($mpd);
}

#####

sub get_fs_file_extent_middlepoint_distance_from_obs {
  my ($self, $other) = @_;

  my $fs_self = $self->_ov_get_fs_file();
  return(undef) if ($self->error());

  my $fs_other = $other->_ov_get_fs_file();
  if ($other->error()) {
    $self->_set_errormsg("Error in compared to Observation (" . $other->get_errormsg() . "). ");
    return(undef);
  }

  return($self->get_fs_file_extent_middlepoint_distance($fs_self, $fs_other));
}

#####

sub get_fs_file_extent_middlepoint_distance_from_ts {
  my ($self, $fs_other) = @_;

  my $fs_self = $self->_ov_get_fs_file();
  return(undef) if ($self->error());

  return($self->get_fs_file_extent_middlepoint_distance($fs_self, $fs_other));
}

##########

sub get_fs_file_overlap {
  my ($self, $fs_self, $fs_other) = @_;

  my $ov = $fs_self->get_overlap($fs_other);
  if ($fs_self->error()) {
    $self->_set_errormsg("Problem obtaining \'fs_file\' 's \'overlap\' (" . $fs_self->get_errormsg() ."). ");
    return(undef);
  }

  return($ov);
}

#####

sub get_fs_file_overlap_from_obs {
  my ($self, $other) = @_;

  my $fs_self = $self->_ov_get_fs_file();
  return(undef) if ($self->error());

  my $fs_other = $other->_ov_get_fs_file();
  if ($other->error()) {
    $self->_set_errormsg("Error in compared to Observation (" . $other->get_errormsg() . "). ");
    return(undef);
  }

  return($self->get_fs_file_overlap($fs_self, $fs_other));
}

#####

sub get_fs_file_overlap_from_fs {
  my ($self, $fs_other) = @_;

  my $fs_self = $self->_ov_get_fs_file();
  return(undef) if ($self->error());

  return($self->get_fs_file_overlap($fs_self, $fs_other));
}

#################### 'framespan'

sub _ov_get_framespan {
  my ($self) = @_;

  # Error (pre)
  return(0) if ($self->error());

  # Validated ?
  if (! $self->is_validated()) {
    $self->_set_errormsg("Observation has not been validated yet. ");
    return(0);
  }

  my $fs_self = $self->get_framespan();
  return(0) if ($self->error());

  return($fs_self);
}

##########

sub get_framespan_extent_middlepoint_distance {
  my ($self, $fs_self, $fs_other) = @_;

  my $mpd = $fs_self->middplepoint_distance($fs_other);
  if ($fs_self->error()) {
    $self->_set_errormsg("Problem obtaining \'framespan\' 's \'extent_middlepoint_distance\' (" . $self->get_errormsg() ."). ");
    return(undef);
  }

  return($mpd);
}

#####

sub get_framespan_extent_middlepoint_distance_from_obs {
  my ($self, $other) = @_;

  my $fs_self = $self->_ov_get_framespan();
  return(undef) if ($self->error());

  my $fs_other = $other->_ov_get_framespan();
  if ($other->error()) {
    $self->_set_errormsg("Error in compared to Observation (" . $other->get_errormsg() . "). ");
    return(undef);
  }

  return($self->get_framespan_extent_middlepoint_distance($fs_self, $fs_other));
}

#####

sub get_framespan_extent_middlepoint_distance_from_fs {
  my ($self, $fs_other) = @_;

  my $fs_self = $self->_ov_get_framespan();
  return(undef) if ($self->error());

  return($self->get_framespan_extent_middlepoint_distance($fs_self, $fs_other));
}

##########

sub get_framespan_overlap {
  my ($self, $fs_self, $fs_other) = @_;

  my $ov = $fs_self->get_overlap($fs_other);
  if ($fs_self->error()) {
    $self->_set_errormsg("Problem obtaining \'framespan\' 's \'overlap\' (" . $self->get_errormsg() ."). ");
    return(undef);
  }

  return($ov);
}

#####

sub get_framespan_overlap_from_obs {
  my ($self, $other) = @_;

  my $fs_self = $self->_ov_get_framespan();
  return(undef) if ($self->error());

  my $fs_other = $other->_ov_get_framespan();
  if ($other->error()) {
    $self->_set_errormsg("Error in compared to Observation (" . $other->get_errormsg() . "). ");
    return(undef);
  }

  return($self->get_framespan_overlap($fs_self, $fs_other));
}

#####

sub get_framespan_overlap_from_fs {
  my ($self, $fs_other) = @_;

  my $fs_self = $self->_ov_get_framespan();
  return(undef) if ($self->error());

  return($self->get_framespan_overlap($fs_self, $fs_other));
}

##########

sub get_extended_framespan {
  my ($self, $fs_self, $fs_other) = @_;

  my @s_be = $fs_self->get_beg_end_fs();
  my @o_be = $fs_other->get_beg_end_fs();

  my $fps = $fs_self->get_fps();

  my ($min, $max) = MMisc::min_max(@s_be, @o_be);

  my $fs_fs = new ViperFramespan();
  $fs_fs->set_value_beg_end($min, $max);
  $fs_fs->set_fps($fps);

  if ($fs_fs->error()) {
    $self->set_errormsg("Problem creating a ViperFramespan (" . $fs_fs->get_errormsg() .")");
    return(undef);
  }
    
  return($fs_fs);
}

#####

sub get_extended_framespan_from_obs {
  my ($self, $other) = @_;

  my $fs_self = $self->_ov_get_framespan();
  return(undef) if ($self->error());

  my $fs_other = $other->_ov_get_framespan();
  if ($other->error()) {
    $self->_set_errormsg("Error in compared to Observation (" . $other->get_errormsg() . "). ");
    return(undef);
  }

  return($self->get_extended_framespan($fs_self, $fs_other));
}

#####

sub get_extended_framespan_from_fs {
  my ($self, $fs_other) = @_;

  my $fs_self = $self->_ov_get_framespan();
  return(undef) if ($self->error());

  return($self->get_extended_framespan($fs_self, $fs_other));
}

############################################################ 'clone'

sub get_clone_id {
  my ($self) = @_;

  return($self->{cloneid});
}

#####

sub is_cloned {
  my ($self) = @_;

  my $val = $self->get_clone_id();

  return(1) if ($val > 0);

  return(0);
}

#####

sub __clone {
  map { ! ref() ? $_ 
	  : ref eq 'HASH' ? {__clone(%$_)} 
	    : ref eq 'ARRAY' ? [__clone(@$_)] 
	      : ref eq 'ViperFramespan' ? $_->clone() 
		: die "$_ not supported" } @_;
}

#####

sub clone {
  my ($self) = @_;

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can not clone a non validated object. ");
    return(0);
  }

  my $clone = new TrecVid08Observation();

  # First clone the data
  $clone->set_full_eventtype($self->get_full_eventtype());
  $clone->set_id($self->get_id());
  $clone->set_filename($self->get_filename());
  $clone->set_xmlfilename($self->get_xmlfilename());

  my $fs_tmp = $self->get_framespan();
  $clone->set_framespan($fs_tmp->clone());
  $fs_tmp = $self->get_fs_file();
  $clone->set_fs_file($fs_tmp->clone());

  my $isgtf = $self->get_isgtf();
  $clone->set_isgtf($isgtf);

  my %ofi = MMisc::clone($self->get_ofi());
  $clone->set_ofi(%ofi);
  $clone->addto_comment($self->get_comment()) 
    if ($self->is_comment_set());

  if (! $isgtf) {
    $clone->set_DetectionScore($self->get_DetectionScore());
    $clone->set_DetectionDecision($self->get_DetectionDecision());
  }

  $clone->set_BoundingBox(&__clone($self->get_BoundingBox())) 
    if ($self->_is_BoundingBox_set());
  $clone->set_Point(&__clone($self->get_Point())) 
    if ($self->_is_Point_set());

  if ($self->is_xtra_set()) {
    foreach my $xtra ($self->list_xtra_attributes()) {
      my $v = $self->get_xtra_value($xtra);
      $clone->set_xtra_attribute($xtra, $v);
    }
  }

  my $cloneid = $self->get_clone_id();
  $clone->{cloneid} = ++$cloneid;

  if ($clone->error()) {
    $self->_set_errormsg("Error during cloning (".  $clone->get_errormsg() . "). ");
    return(undef);
  }

  $clone->validate();
  if ($clone->error()) {
    $self->_set_errormsg("Error during clone validation (".  $clone->get_errormsg() . "). ");
    return(undef);
  }
  
  # Add a comment
  my $uid = $self->get_unique_id();
  my $c = sprintf("Clone #%04d of UID ($uid)", $cloneid);
  $clone->addto_comment($c);

  return($clone);
}

##############################

sub _get_ofi_core {
  my ($self, $key) = @_;

  my %ofi = $self->get_ofi();
  if (! exists $ofi{$key}) {
    $self->_set_errormsg("WEIRD: Problem accessing the ofi \'$key\' information. ");
    return(0);
  }

  return($ofi{$key});
}

#####

sub get_ofi_numframes {
  my ($self) = @_;
  return($self->_get_ofi_core(TrecVid08ViperFile::get_Numframes_fileattrkey()));
}

#####

sub get_ofi_framerate {
  my ($self) = @_;
  return($self->_get_ofi_core(TrecVid08ViperFile::get_Framerate_fileattrkey()));
}

#####

sub get_ofi_hframesize {
  my ($self) = @_;
  return($self->_get_ofi_core(TrecVid08ViperFile::get_HFramesize_fileattrkey()));
}

#####

sub get_ofi_vframesize {
  my ($self) = @_;
  return($self->_get_ofi_core(TrecVid08ViperFile::get_VFramesize_fileattrkey()));
}

#####

sub get_ofi_sourcetype {
  my ($self) = @_;
  return($self->_get_ofi_core(TrecVid08ViperFile::get_Sourcetype_fileattrkey()));
}

#####

sub get_ofi_VF_empty_order {
  my ($self) = @_;

  my @out = ();
  push @out, $self->get_ofi_numframes();
  push @out, $self->get_ofi_framerate();
  push @out, $self->get_ofi_sourcetype();
  push @out, $self->get_ofi_hframesize();
  push @out, $self->get_ofi_vframesize();

  return(@out);
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

############################################################

1;
