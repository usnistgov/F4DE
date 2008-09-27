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

use CSVHelper;

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
my @array_file_attributes_keys = ();
my $dummy_et = "Fake_Event-Merger_Dummy_Type";

my $attr_framespan_key = "ViperFramespan";
my $attr_content_key   = "Content";

my $key_tc = "";
my $char_tcs = "";

my @ok_csv_keys = 
  (
   # Required
   "EventType", "Framespan", # 0,1
   # Optional
   "DetectionScore", "DetectionDecision", "Filename", "XMLFile", # 2,3,4,5
   "BoundingBox", "Point", "EventSubType", "ID", "isGTF", # 6,7,8,9,10
   "Comment", "FileFramespan", "OtherFileInformation", # 11,12,13
   # Used by TV08Stats
   "Duration", "Beginning", "End", "MiddlePoint", # 14,15,16,17
   # Xtra
   "Xtra", # 18
  );
my @required_csv_keys = @ok_csv_keys[0,1];
my $csv_quote_char = '~';

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
     fps         => -1, # Gets defined when framespan or fs_file is defined
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
  my %tmp = $dummy->_get_hash_file_attributes_types();
  @array_file_attributes_keys = keys %tmp;
  $char_tcs = $dummy->get_char_tc_separator();
  $key_tc = $dummy->get_key_xtra_trackingcomment();
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

  return(0) if (! $self->set_eventsubtype($stype));

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

  return(TrecVid08ViperFile::get_printable_full_event($etype, $stype, 1));
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

########## 'fps'

sub set_fps {
  my ($self, $fps) = @_;

  return(0) if ($self->error());

  # use ViperFramespan to create the accepted value
  my $fs_tmp = new ViperFramespan();
  if (! $fs_tmp->set_fps($fps)) {
    $self->_set_errormsg("While setting the file fps ($fps) error (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }
  # And get it back
  $fps = $fs_tmp->get_fps();
  if ($fs_tmp->error()) {
    $self->_set_errormsg("While obtaining back the file fps ($fps) error (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  $self->{fps} = $fps;
  return(1);
}

#####

sub is_fps_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(0) if ($self->{fps} == -1);

  return(1);
}

#####

sub get_fps {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_fps_set()) {
    $self->_set_errormsg("\'fps\' is not set");
    return(0);
  }

  return($self->{fps});
}

########## 'framespan'

sub set_framespan {
  my ($self, $fs_fs) = @_;

  return(0) if ($self->error());

  if ( (! defined $fs_fs) || (! $fs_fs->is_value_set() ) ) {
    $self->_set_errormsg("Invalid \'framespan\'. ");
    return(0);
  }
  if (! $fs_fs->is_fps_set() ) {
    $self->_set_errormsg("\'fps\' not set in \'framespan\'. ");
    return(0);
  }

  my $ffps = $fs_fs->get_fps();
  if ($self->is_fps_set()) {
    my $sfps = $self->get_fps();
    if ($sfps != $ffps) {
      $self->_set_errormsg("\'fps\' value from framespan ($ffps) differs from already set value ($sfps)");
      return(0);
    }
  } else {
    $self->set_fps($ffps);
  }
  return(0) if ($self->error());

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

  if ( (! defined $fs_file) || (! $fs_file->is_value_set() ) ) {
    $self->_set_errormsg("Invalid \'fs_file\'. ");
    return(0);
  }
  if (! $fs_file->is_fps_set() ) {
    $self->_set_errormsg("\'fps\' not set in \'fs_file\'. ");
    return(0);
  }
  my $ffps = $fs_file->get_fps();
  if ($self->is_fps_set()) {
    my $sfps = $self->get_fps();
    if ($sfps != $ffps) {
      $self->_set_errormsg("\'fps\' value from framespan ($ffps) differs from already set value ($sfps)");
      return(0);
    }
  } else {
    $self->set_fps($ffps);
  }
  return(0) if ($self->error());

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

  foreach my $key (@array_file_attributes_keys) {
    if (! exists $entries{$key}) {
      $self->_set_errormsg("One of the \'ofi\' \'s required key ($key) is missing");
      return(0);
    }
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

sub is_BoundingBox_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{BoundingBox});

  return(0);
}

#####

sub get_BoundingBox {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_BoundingBox_set()) {
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

sub is_Point_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{Point});

  return(0);
}

#####

sub get_Point {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_Point_set()) {
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

sub key_attr_framespan { return($attr_framespan_key); }
sub key_attr_content   { return($attr_content_key);   }

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
    if (! exists $oneelt{$attr_content_key}) {
      $self->_set_errormsg("WEIRD: In \'set_selected\' can not obtain the \'content\' key. ");
      return(0);
    }
    my $rvalues = $oneelt{$attr_content_key};
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
    return(0, ()) if (! $self->is_BoundingBox_set());
    return(1, $self->get_BoundingBox());
  } elsif ($choice =~ m%^$ok_choices[3]$%) { # 'Point'
    return(0, ()) if (! $self->is_Point_set());
    return(1, $self->get_Point());
  } else {
    $self->_set_errormsg("WEIRD: Could not select a choice in \'get_selected\' ($choice). ");
    return(0, ());
  }
}

########## 'xtra'

sub set_xtra_attribute {
  my $self = shift @_;
  my ($attr, $value, $replace) = MMisc::iuav(\@_, "", "", 0);

  return(0) if ($self->error());

  if (MMisc::is_blank($attr)) {
    $self->_set_errormsg("Can not set an empty attribute");
    return(0);
  }

  if ((! $self->is_xtra_attribute_set($attr)) || ($replace)) {
    $self->{Xtra}{$attr} = $value;
  } else {
    $self->{Xtra}{$attr} .= " $char_tcs $value";
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

sub list_all_xtra_attributes {
  my ($self) = @_;

  my @aa = ();

  return(@aa) if ($self->error());

  return(@aa) if (! $self->is_xtra_set());

  @aa = keys %{$self->{Xtra}};

  return(@aa);
}

#####

sub list_xtra_attributes {
  my ($self) = @_;

  my @aa = $self->list_all_xtra_attributes();
  return(@aa) if (scalar @aa == 0);

  my @xl = grep(! m%^$key_tc$%, @aa);

  return(@xl);
}

#####

sub unset_xtra {
  my ($self, $attr) = @_;

  return(0) if ($self->error());

  return(0)
    if (! exists $self->{Xtra}{$attr});

  delete $self->{Xtra}{$attr};

  $self->{Xtra} = undef
    if (scalar(keys %{$self->{Xtra}}) == 0);

  return(1);
}

#####

sub unset_all_xtra {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! defined $self->{Xtra});

  my @list = $self->list_xtra_attributes();
  foreach my $attr (@list) {
    $self->unset_xtra($attr);
  }

  return(0) if ($self->error());

  return(1);
}

#####

sub is_trackingcomment_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(0) if (! $self->is_xtra_set());

  return(1) if (exists $self->{Xtra}{$key_tc});

  return(0);
}

######

sub get_trackingcomment_txt {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_trackingcomment_set()) {
    $self->_set_errormsg("Can not obtain \'tracking comment\', it is not set");
    return(0);
  }

  my $tc = $self->{Xtra}{$key_tc};

  return($tc);
}

#####

sub unset_trackingcomment {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! $self->is_trackingcomment_set());

  return($self->unset_xtra($key_tc));;
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

#####

sub redo_validation {
  my ($self) = @_;

  return(0) if ($self->error());

  $self->{validated} = 0;

  return($self->validate());
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
  return(0) if ($self->error());

  if ($isgtf) {
    $self->_set_errormsg("Can not get the \'DetectionScore' for a GTF observation. ");
    return(0);
  }

  my $ds = $self->get_DetectionScore();
  return(0) if ($self->error());

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
  my ($self, $choice, $val, $neg) = @_;

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

    if ($neg) {
      $fs_tmp->negative_value_shift($val);
    } else {
      $fs_tmp->value_shift($val);
    }
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

sub negative_shift_framespan {
  my ($self, $val) = @_;

  return(0) if ($self->error());

  return($self->shift_framespan($val, 1));
}

#####

sub shift_framespan {
  my ($self, $val, $neg) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only shift framespan on validated Observations");
    return(0);
  }

  my $fs_fs = $self->get_framespan();
  return(0) if ($self->error());

  my $fs_file = $self->get_fs_file();
  return(0) if ($self->error());

  if ($neg) {
    $fs_fs->negative_value_shift($val);
  } else {
    $fs_fs->value_shift($val);
  }
  if ($fs_fs->error()) {
    $self->_set_errormsg("Problem while shifting the framespan (" . $fs_fs->get_errormsg() . "). ");
    return(0);
  }

  if ($neg) {
    $fs_file->negative_value_shift($val);
  } else {
    $fs_file->value_shift($val);
  }
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
  if ($neg) {
    $ofi{$key} -= $val;
    $ofi{$key} = 1 if ($ofi{$key} < 1);
  } else {
    $ofi{$key} += $val;
  }
  $self->set_ofi(%ofi);

  # other attributes
  my @ok_choices = &_get_set_selected_ok_choices();
  foreach my $choice (@ok_choices) {
    $self->_shift_framespan_selected($choice, $val, $neg);
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

  $clone->set_fps($self->get_fps()) if ($self->is_fps_set());

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
    if ($self->is_BoundingBox_set());
  $clone->set_Point(&__clone($self->get_Point())) 
    if ($self->is_Point_set());

  if ($self->is_xtra_set()) {
    foreach my $xtra ($self->list_all_xtra_attributes()) {
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

######################################## CSV Helpers

sub get_ok_csv_keys       { return(@ok_csv_keys); }
sub get_required_csv_keys { return(@required_csv_keys); }

##

sub get_EventType_csv_key            { return $ok_csv_keys[0]; }
sub get_Framespan_csv_key            { return $ok_csv_keys[1]; }
sub get_DetectionScore_csv_key       { return $ok_csv_keys[2]; }
sub get_DetectionDecision_csv_key    { return $ok_csv_keys[3]; }
sub get_Filename_csv_key             { return $ok_csv_keys[4]; }
sub get_XMLFile_csv_key              { return $ok_csv_keys[5]; }
sub get_BoundingBox_csv_key          { return $ok_csv_keys[6]; }
sub get_Point_csv_key                { return $ok_csv_keys[7]; }
sub get_EventSubType_csv_key         { return $ok_csv_keys[8]; }
sub get_ID_csv_key                   { return $ok_csv_keys[9]; }
sub get_isGTF_csv_key                { return $ok_csv_keys[10]; }
sub get_Comment_csv_key              { return $ok_csv_keys[11]; }
sub get_FileFramespan_csv_key        { return $ok_csv_keys[12]; }
sub get_OtherFileInformation_csv_key { return $ok_csv_keys[13]; }
sub get_Duration_csv_key             { return $ok_csv_keys[14]; }
sub get_Beginning_csv_key            { return $ok_csv_keys[15]; }
sub get_End_csv_key                  { return $ok_csv_keys[16]; }
sub get_MiddlePoint_csv_key          { return $ok_csv_keys[17]; }
sub get_Xtra_csv_key                 { return $ok_csv_keys[18]; }

#####

sub _array2csvtxt {
  my ($self, @array) = @_;

  my $ch = CSVHelper::get_csv_handler($csv_quote_char);
  if (! defined $ch) {
    $self->_set_errormsg("Problem creating the CSV object");
    return("");
  }

  my $txt = CSVHelper::array2csvtxt($ch, @array);

  if (! defined $txt) {
    $self->_set_errormsg("Problem adding entries to CSV");
    return("");
  }

  return($txt);
}

#####

sub _csvtxt2array {
  my ($self, $value) = @_;

  my @out = ();

  my $ch = CSVHelper::get_csv_handler($csv_quote_char);
  if (! defined $ch) {
    $self->_set_errormsg("Problem creating the CSV object");
    return(@out);
  }

  my @columns = CSVHelper::csvtxt2array($ch, $value);
  if (! defined @columns) {
    $self->_set_errormsg("Problem extracting inlined-CSV line");
    return(@out);
  }

  return(@columns);
}

#####

sub CF_check_csv_keys {
  my @keys = @_;

  my ($rla, $rlb) = MMisc::confirm_first_array_values(\@keys, @ok_csv_keys);
  return("Found unauthorized keys for CSV work: " . join(" ", @$rlb))
    if (scalar @$rlb > 0);

  my ($rla, $rlb) = MMisc::confirm_first_array_values(\@required_csv_keys, @keys);
  return("Not all required keys (" . join(" ", @required_csv_keys) . ") could be found (only seen: " . join(" ", @$rla) .")")
    if (scalar @$rla != scalar @required_csv_keys);

  return("");
}

##### 

sub check_csv_keys {
  my ($self, @keys) = @_;

  return(0) if ($self->error());

  my $tmp = &CF_check_csv_keys(@keys);

  if (! MMisc::is_blank($tmp)) {
    $self->_set_errormsg($tmp);
    return(0);
  }

  return(1);
}

#####

sub mod_from_csv_array {
  my ($self, $rh, @values) = @_;
  
  return(0) if ($self->error());

  my @headers = @$rh;
  if (scalar @headers == 0) {
    $self->_set_errormsg("No key requested");
    return(0);
  }
  return(0) if (! $self->check_csv_keys(@headers));

  if (scalar @headers != scalar @values) {
    $self->_set_errormsg("Not the same number of values in the header and in the given array");
    return(0);
  }
  
  for (my $i = 0; $i < scalar @headers; $i++) {
    my $task = $headers[$i];
    my $value = $values[$i];
    return(0) if (! $self->_csv_set_XXX($task, $value));
  }

  return(1);
}

##########

sub _csv_set_XXX {
  my ($self, $task, $value) = @_;

  if ($task eq $self->get_EventType_csv_key()) {
    return($self->set_eventtype($value));
  } elsif ($task eq $self->get_EventSubType_csv_key()) {
    return(1) if (MMisc::is_blank($value));
    return($self->set_eventsubtype($value));
  } elsif ($task eq $self->get_Filename_csv_key()) {
    return($self->set_filename($value));
  } elsif ($task eq $self->get_XMLFile_csv_key()) {
    return($self->set_xmlfilename($value));
  } elsif ($task eq $self->get_DetectionScore_csv_key()) {
    return(1) if (MMisc::is_blank($value));
    return($self->set_DetectionScore($value));
  } elsif ($task eq $self->get_DetectionDecision_csv_key()) {
    return(1) if (MMisc::is_blank($value));
    return($self->set_DetectionDecision($value));
  } elsif ($task eq $self->get_isGTF_csv_key()) {
    return($self->set_isgtf($value));
  } elsif ($task eq $self->get_ID_csv_key()) {
    return($self->set_id($value));
  } elsif ($task eq $self->get_Comment_csv_key()) {
    $self->clear_comment();
    return($self->addto_comment($value));
  } elsif (grep(m%^$task$%, ($self->get_Duration_csv_key(), $self->get_Beginning_csv_key(), $self->get_End_csv_key(), $self->get_MiddlePoint_csv_key()))) {
    return(1); # discard those entirely
  } elsif ($task eq $self->get_Framespan_csv_key()) {
    return($self->_csvset_aframespan("frame", $value));
  } elsif ($task eq $self->get_FileFramespan_csv_key()) {
    return($self->_csvset_aframespan("file", $value));
  } elsif ($task eq $self->get_BoundingBox_csv_key()) {
    return($self->_csvset_BB_Pt($task, $value));
  } elsif ($task eq $self->get_Point_csv_key()) {
    return($self->_csvset_BB_Pt($task, $value));
  } elsif ($task eq $self->get_OtherFileInformation_csv_key()) {
    return($self->_csvset_ofi($value));
  } elsif ($task eq $self->get_Xtra_csv_key()) {
    return(1) if (MMisc::is_blank($value));
    return($self->_csvset_Xtra($value));
  }

  # No proper path ?
  $self->_set_errormsg("Unknow request ($task)");
  return(0);
}

#####

sub _csvset_Xtra {
  my ($self, $value) = @_;

  return(1) if (MMisc::is_blank($value));

  my @columns = $self->_csvtxt2array($value);
  if ((scalar @columns) % 2 != 0) {
    $self->_set_errormsg("inlined-CSV does not contains an even number of elements");
    return(0);
  }

  while (my $attr = shift @columns) {
    my $v = shift @columns;

    return(0)
      if (! $self->set_xtra_attribute($attr, $v, 1));
  }

  return(1);
}

#####

sub _csvset_aframespan {
  my ($self, $xxx, $value) = @_;

  if (! $self->is_fps_set()) {
    $self->_set_errormsg("Can not set a framespan without a fps value");
    return(0);
  }

  my $fps = $self->get_fps();

  my $fs_tmp = new ViperFramespan($value);
  $fs_tmp->set_fps($fps);
  if ($fs_tmp->error()) {
    $self->_set_errormsg("Problem creating a ViperFramespan: " . $fs_tmp->get_errormsg());
    return(0);
  }

  if ($xxx eq "frame") {
    return($self->set_framespan($fs_tmp));
  } elsif ($xxx eq "file") {
    return($self->set_fs_file($fs_tmp));
  }

  # All the proper path were not used ...
  $self->_set_errormsg("Unknown mode ($xxx) for setting a framespan");
  return(0);
}
  
#####

sub _csvset_BB_Pt {
  my ($self, $mode, $value) = @_;

  if ( ($mode ne $self->get_BoundingBox_csv_key()) 
       && ($mode ne $self->get_Point_csv_key()) ) {
    $self->_set_errormsg("Unknown mode requested (neither Point or BoundingBox)");
    return(0);
  }

  return(1)
    if (MMisc::is_blank($value));

  my $fps = $self->get_fps();
  return(0) if ($self->error());

  my @columns = $self->_csvtxt2array($value);
  if ((scalar @columns) % 2 != 0) {
    $self->_set_errormsg("inlined-CSV does not contains an even number of elements");
    return(0);
  }

  my %tmp = ();
  while (my $fs = shift @columns) {
    my $v = shift @columns;

    my @array = split(m%\,%, $v);
    if (scalar @array == 0) {
      $self->_set_errormsg("No element in array for \'$mode\' framespan ($fs)");
      return(0);
    }
    my $fs_fs = new ViperFramespan($fs);
    $fs_fs->set_fps($fps);
    if ($fs_fs->error()) {
      $self->_set_errormsg("Problem while creating ViperFramespan: " . $fs_fs->get_errormsg());
      return(0);
    }

    my %x = ();
    $x{$attr_content_key} = \@array;
    $x{$attr_framespan_key} = $fs_fs;
    $tmp{$fs} = \%x;
  }
  return(0) if ($self->error());

  if ($mode eq $self->get_BoundingBox_csv_key()) {
    return($self->set_BoundingBox(%tmp));
  } else {
    return($self->set_Point(%tmp));
  }

  # Wrong path
  $self->_set_errormsg("Unkown mode ($mode) for setting a BoundingBox or Point");
  return(0);
}

#####

sub _csvset_ofi {
  my ($self, $value) = @_;
  
  return(0) if ($self->error());
  
  my %tmp = $self->_csvtxt2array($value);
  return(0) if ($self->error());
  
  return($self->set_ofi(%tmp));
}

####################

sub get_csv_array {
  my ($self, @keys) = @_;

  my @tmp = ();

  return(@tmp) if ($self->error());

  if (scalar @keys == 0) {
    $self->_set_errormsg("No key requested");
    return(@tmp);
  }

  return(@tmp) if (! $self->check_csv_keys(@keys));

  my @out = ();
  foreach my $key (@keys) {
    my $txt = $self->_csv_get_XXX($key);
    return(@tmp) if ($self->error());
    push @out, $txt;
  }

  return(@tmp) if ($self->error());

  if (scalar @out != scalar @keys) {
    $self->_set_errormsg("No enough information extracted");
    return(@tmp);
  }

  return(@out);
}

#####

sub _csv_get_XXX {
  my ($self, $key) = @_;

  if ($key eq $self->get_EventType_csv_key()) {
    return($self->get_eventtype());
  } elsif ($key eq $self->get_EventSubType_csv_key()) {
    return("") if (! $self->is_eventsubtype_set());
    return($self->get_eventsubtype());
  } elsif ($key eq $self->get_Filename_csv_key()) {
    return($self->get_filename());
  } elsif ($key eq $self->get_XMLFile_csv_key()) {
    return($self->get_xmlfilename());
  } elsif ($key eq $self->get_DetectionScore_csv_key()) {
    return("") if ($self->get_isgtf());
    return($self->get_DetectionScore());
  } elsif ($key eq $self->get_DetectionDecision_csv_key()) {
    return("") if ($self->get_isgtf());
    return($self->get_DetectionDecision());
  } elsif ($key eq $self->get_isGTF_csv_key()) {
    return($self->get_isgtf());
  } elsif ($key eq $self->get_ID_csv_key()) {
    return($self->get_id());
  } elsif ($key eq $self->get_Comment_csv_key()) {
    return("") if (! $self->is_comment_set());
    return($self->get_comment());
  } elsif ($key eq $self->get_Duration_csv_key()) {
    return($self->Dur());
  } elsif ($key eq $self->get_Beginning_csv_key()) {
    return($self->Beg());
  } elsif ($key eq $self->get_End_csv_key()) {
    return($self->End());
  } elsif ($key eq $self->get_MiddlePoint_csv_key()) {
    return($self->Mid());
  } elsif ($key eq $self->get_Framespan_csv_key()) {
    return($self->_csvget_aframespan("frame"));
  } elsif ($key eq $self->get_FileFramespan_csv_key()) {
    return($self->_csvget_aframespan("file"));
  } elsif ($key eq $self->get_BoundingBox_csv_key()) {
    return($self->_csvget_BB_Pt($key));
  } elsif ($key eq $self->get_Point_csv_key()) {
    return($self->_csvget_BB_Pt($key));
  } elsif ($key eq $self->get_OtherFileInformation_csv_key()) {
    return($self->_csvget_ofi());
  } elsif ($key eq $self->get_Xtra_csv_key()) {
    return($self->_csvget_Xtra());
  }

  $self->_set_errormsg("Unknow request");
}

#####

sub _csvget_Xtra {
  my ($self) = @_;

  my $txt = "";
  return($txt) if (! $self->is_xtra_set());

  my @todo = $self->list_all_xtra_attributes();
  my @array = ();
  foreach my $attr (sort @todo) {
    my $v = $self->get_xtra_value($attr);
    return($txt) if ($self->error());
    push @array, $attr;
    push @array, $v;
  }

  $txt = $self->_array2csvtxt(@array);
  return($txt);
}

#####

sub _csvget_aframespan {
  my ($self, $xxx) = @_;

  my $fs_tmp = undef;

  if ($xxx eq "frame") {
    $fs_tmp = $self->get_framespan();
  } elsif ($xxx eq "file") {
    $fs_tmp = $self->get_fs_file();
  }

  return("") if ($self->error());
  if (! defined $fs_tmp) {
    $self->_set_errormsg("Could not obtain framespan ($xxx)");
    return("");
  }

  my $txt = $fs_tmp->get_value();
  if ($fs_tmp->error()) {
    $self->_set_errormsg("Could not obtain framespan ($xxx)'s value: " . $fs_tmp->get_errormsg());
    return("");
  }

  return($txt);
}
  
#####

sub _fs_sort {
  my ($b1, $e1) = split(m%\:%, $a);
  my ($b2, $e2) = split(m%\:%, $b);

  # Order by beginning first
  return($b1 <=> $b2) if ($b1 != $b2);
  # by end if the beginning is the same
  return($e1 <=> $e2);
}

#####

sub _csvget_BB_Pt {
  my ($self, $mode) = @_;

  my %tmp = ();

  if ($mode eq $self->get_BoundingBox_csv_key()) {
    return("") if (! $self->is_BoundingBox_set());
    %tmp = $self->get_BoundingBox();
  } elsif ($mode eq $self->get_Point_csv_key()) {
    return("") if (! $self->is_Point_set());
    %tmp = $self->get_Point();
  } else {
    $self->_set_errormsg("Unknown mode requested (neither Point or BoundingBox)");
    return("");
  }

  my @all = ();
  my @todo = keys %tmp;
  foreach my $key (sort _fs_sort @todo) {
    my %in = %{$tmp{$key}};
    if (! exists $in{$attr_content_key}) {
      $self->_set_errormsg("Could not find the \'$attr_framespan_key\' information");
      return("");
    }
    my $rtmp = $in{$attr_content_key};
    my $txt = join(",", @$rtmp);
    push @all, $key;
    push @all, $txt;
  }
  
  my $txt = $self->_array2csvtxt(@all);
  return($txt);
}

#####

sub _csvget_ofi {
  my ($self) = @_;

  return("") if ($self->error());

  if (! $self->_is_ofi_set()) {
    $self->_set_errormsg("\'Other File Information\' not set");
    return("");
  }

  my %tmp = $self->get_ofi();

  my @a = ();
  foreach my $key (@array_file_attributes_keys) {
    if (! exists $tmp{$key}) {
      $self->_set_errormsg("One of the \'Other File Information\' key ($key) is not set");
      return("");
    }
    my $v = $tmp{$key};
    push @a, $key;
    push @a, $v;
  }

  return($self->_array2csvtxt(@a));
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

sub clear_error {
  my ($self) = @_;
  return($self->{errormsg}->clear());
}

############################################################

1;
