package TrecVid08ViperFile;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 ViperFile
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08ViperFile.pm" is an experimental system.
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

my $versionid = "TrecVid08ViperFile.pm Version: $version";

# "ViperFramespan.pm" (part of this program sources)
use ViperFramespan;
# A note about 'ViperFramespan': 
# we are using functions to facilitate work on framespans but are always storing a text value
# in memory to make it easier to process the first level information.
# (it is easy to recreate a 'ViperFramespan' from the text value, which we do multiple times in this code)
# This choice to make an object of it was driven by re-usability of the framespan code for other needs.

# "TrecVid08Observation.pm" (part of this program sources)
use TrecVid08Observation;

# "TrecVid08xmllint.pm" (part of this program sources)
use TrecVid08xmllint;

# "MtXML.pm" (part of this program sources)
use MtXML;

# "MErrorH.pm" (part of this program sources)
use MErrorH;

# "MMisc.pm" (part of this program sources)
use MMisc;

########################################
##########

# Required XSD files
my @xsdfilesl = ( "TrecVid08.xsd", "TrecVid08-viper.xsd", "TrecVid08-viperdata.xsd" ); # Important that the main file be first

# Authorized Events List
my @ok_events = 
  (
   # Required events
   "PersonRuns", "CellToEar", "ObjectPut", "PeopleMeet", "PeopleSplitUp", 
   "Embrace", "Pointing", "ElevatorNoEntry", "OpposingFlow", "TakePicture", 
   # Optional events
   "DoorOpenClose", "UseATM", "ObjectGet", "VestAppears", "SitDown", 
   "StandUp", "ObjectTransfer", 
   # Removed events
   ##
  );

# Authorized sub Events List (usualy those would be results from the scorer)
my $key_subevent_Undefined   = "Undefined";
my $key_subevent_Mapped      = "Mapped";
my $key_subevent_UnmappedRef = "Unmapped_Ref";
my $key_subevent_UnmappedSys = "Unmapped_Sys";
my @ok_subevents = 
  (
   # No set mode
   $key_subevent_Undefined,
   # Know set mode
   $key_subevent_Mapped,
   $key_subevent_UnmappedRef,
   $key_subevent_UnmappedSys,
  ); # order is important (esp for the first element which is used in case no sub type is set but sub type writing as been requested)

my %for_event_sort = ();

##### Memory representations

my $key_fat_numframes  = "NUMFRAMES";
my $key_fat_sourcetype = "SOURCETYPE";
my $key_fat_hframesize = "H-FRAME-SIZE";
my $key_fat_vframesize = "V-FRAME-SIZE";
my $key_fat_framerate  = "FRAMERATE";

my %hash_file_attributes_types = 
  (
   $key_fat_numframes   => "dvalue",
   $key_fat_sourcetype  => undef,
   $key_fat_hframesize  => "dvalue",
   $key_fat_vframesize => "dvalue",
   $key_fat_framerate  => "fvalue",
  );

my $key_xtra = "xtra_"; # A very special type, is both optional and a partial match
my $key_xtra_trackingcomment = "Tracking_Comment";
my $spval_xtra_trackingcomment = "Special Values for xtra Tracking_Comment";

my $key_xtra_tc_original = "Original";
my $key_xtra_tc_modsadd  = "Post Modification";
my @keys_xtra_tc_authorized = ($key_xtra_tc_original, $key_xtra_tc_modsadd);

my @array_xtra_tc_list = # Order is important
  ( "File", "Sourcefile", "Type", "Event", "SubType",
    "ID", "Framespan", "XtraAttributes");

# Important to properly separate those values in other pacakges
my $char_tc_separator = "\#";
my $char_tc_beg_entry = "\[";
my $char_tc_end_entry = "\]";
my $char_tc_entry_sep = " \| ";
my $char_tc_comp_sep  = " \= ";
my $char_tc_beg_pre   = "\(";
my $char_tc_end_pre   = "\)";

my @array_file_inline_attributes =
  ( "id", "name" );             # 'id' is to be first

my @list_objects_attributes =   # Order is important
  ("DetectionScore", "DetectionDecision", "Point", "BoundingBox", "$key_xtra");

my @list_objects_attributes_types = # Order is important (has to match previous)
  ("fvalue", "bvalue", "point", "bbox", "svalue");

my @list_objects_attributes_isd = # Order is important (has to match previous too)
  (0, 0, 1, 1, 0);

my @list_objects_attributes_expected = # Order is important (has to match previous too)
  (1, 1, 1, 1, 0);

my @not_gtf_required_objects_attributes =
  ($list_objects_attributes[0], $list_objects_attributes[1]);

my %hash_objects_attributes_types = ();
my %hash_objects_attributes_types_expected = ();

my %hash_objects_attributes_types_dynamic = ();

my %hasharray_inline_attributes = ();
@{$hasharray_inline_attributes{"bbox"}} = ("x", "y", "height", "width");
@{$hasharray_inline_attributes{"point"}} = ("x", "y");
@{$hasharray_inline_attributes{"fvalue"}} = ("value");
@{$hasharray_inline_attributes{"bvalue"}} = ("value");
@{$hasharray_inline_attributes{"dvalue"}} = ("value");
@{$hasharray_inline_attributes{"svalue"}} = ("value");

my @array_objects_inline_attributes = 
  ("name", "id", "framespan");  # order is important

my %not_gtf_required_dummy_values =
  (
   $not_gtf_required_objects_attributes[0] => [ 0 ],
   $not_gtf_required_objects_attributes[1] => [ 0 ],
  );

my $key_framespan = $array_objects_inline_attributes[2];
my $key_subtype = "subtype";

my $full_event_separator = "\:";

##########
# Default values to compare against (constant values)
my $default_error_value = "default_error_value";
my $framespan_max_default = "all";

########## Some rules that can be changed (here, specific for TrecVid08)
# Maximum number of pair per framespan found
# For Trecvid08, only one pair (ie one framespan range) is authorized per framespan (0 for unlimited)
my $max_pair_per_fs = 1;        # positive number / 0 for unlimited
## Update (20080421): After talking with Jon, we decided that IDs do not have to start at 0 or be consecutive after all
# Check if IDs list have to start at 0
my $check_ids_start_at_zero = 0;
# Check that IDs are consecutive
my $check_ids_are_consecutive = 0;

##### Random seed
my $rseed = undef;
my $rseed_lastfound = undef;
# To avoid any call to 'rand' in any other library to interefere with us
# we store 10,000 values in advance (and will reuse them -- it should be
# enough to work with a few files)
my @rseed_vals = ();
my $rseed_pos = 0;
my $rseed_max = 1E4;

########################################

## Constructor
sub new {
  my ($class) = shift @_;

  my $errortxt = (scalar @_ > 0) ? "TrecVid08ViperFile does not accept parameters" : "";

  &_fill_required_hashes();

  my $fs_tmp = new ViperFramespan();
  my $xmllintobj = new TrecVid08xmllint();
  $xmllintobj->set_xsdfilesl(@xsdfilesl);
  $errortxt .= $xmllintobj->get_errormsg() if ($xmllintobj->error());

  my $errormsg = new MErrorH("TrecVid08ViperFile");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     xmllintobj     => $xmllintobj,
     gtf            => 0,       # By default, files are not GTF
     fps            => -1, # Not needed to validate a file, but needed for observations creation
     file           => "",
     fhash          => undef,
     comment        => "", # Comment to be written to write (or to each 'Observation' when generated)
     validated      => 0,  # To confirm file was validated
     force_subtype  => 0,
     fs_framespan_max => $fs_tmp,
     errormsg       => $errormsg,
    };

  bless $self;
  return($self);
}

#####

sub _fill_required_hashes {
  return() if (scalar keys %hash_objects_attributes_types > 0);

  for (my $i = 0; $i < scalar @list_objects_attributes; $i++) {
    my $key  = $list_objects_attributes[$i];
    my $keyt = $list_objects_attributes_types[$i];

    $hash_objects_attributes_types{$key} = 
      $keyt;

    if ($list_objects_attributes_expected[$i]) {
      $hash_objects_attributes_types_expected{$key} =
        $keyt;
    }

    $hash_objects_attributes_types_dynamic{$key} =
      $list_objects_attributes_isd[$i];

    @{$hasharray_inline_attributes{$key}} =
      @{$hasharray_inline_attributes{$keyt}};
  }
}

####################

sub get_version {
  my ($self) = @_;

  return($versionid);
}

########################################

sub get_required_xsd_files_list {
  my ($self) = @_;

  return(0) if ($self->error());

  return(@xsdfilesl);
}

#####

sub _expand_events_star {
  my ($self, @events) = @_;

  my @out = ();
  foreach my $key (@events) {
    my ($e, $s) = split_full_event($key, 0);
    
    # special cases
    return(@ok_events) if (($e eq "*") && ($s eq "*"));
    return(@ok_events) if (($e eq "*") && (MMisc::is_blank($s)));

    if ($e eq "*") { # $s is not blank
      foreach my $ev (@ok_events) {
	push @out, &get_printable_full_event($ev, $s, 1);
      }
      next;
    }

    if ($s eq "*") { # $e is not blank
      foreach my $sev (@ok_subevents) {
	push @out, &get_printable_full_event($e, $sev, 1);
      }
      next;
    }

    push @out, $key;
  }

  return(@out);
}

#####

sub validate_events_list {
  my ($self, @events) = @_;

  @events = split(m%\,%, join(",", @events));
  @events = $self-> _expand_events_star(@events);
  @events = MMisc::make_array_of_unique_values(@events);

  # A non validated entry does not have 'subtype' set yet, so any subtype
  # would be dropped, so skip the 'reformat_events' function until then
  @events = $self->reformat_events(@events)
    if ($self->is_validated());

  my ($rev, $rsev) = $self->split_events_subevents(@events);

  my ($in, $out) = MMisc::confirm_first_array_values($rev, @ok_events);
  if (scalar @$out > 0) {
    $self->_set_errormsg("Found some unknown event type: " . join(" ", @$out));
    return();
  }

  if (scalar @$rsev > 0) {
    my ($in, $out) = MMisc::confirm_first_array_values($rsev, @ok_subevents);
    if (scalar @$out > 0) {
      $self->_set_errormsg("Found some unknown sub event type: " . join(" ", @$out));
      return();
    }
  }

  return(@events);
}

#####

sub reformat_events {
  my ($self, @evl) = @_;

  my %all = $self->make_full_events_hash(@evl);

  my @out = ();
  if ($self->check_force_subtype()) {
    foreach my $ev (keys %all) {
      foreach my $sev (keys %{$all{$ev}}) {
	my $v = &get_printable_full_event($ev, $sev, 1);
	push @out, $v;
      }
    }
  } else {
    push @out, keys %all;
  }

  return(@out);
}  

#####

sub get_full_events_list {
  my ($self) = @_;

  return(0) if ($self->error());

  return(@ok_events);
}

#####

sub get_full_subevents_list {
  my ($self) = @_;

  return(0) if ($self->error());

  return(@ok_subevents);
}

#####

sub _get_hasharray_inline_attributes {
  my ($self) = @_;

  return(0) if ($self->error());

  return(%hasharray_inline_attributes);
}

#####

sub _get_hash_objects_attributes_types_dynamic {
  my ($self) = @_;

  return(0) if ($self->error());

  return(%hash_objects_attributes_types_dynamic);
}

#####

sub get_Undefined_subeventkey { return($key_subevent_Undefined); }
sub get_Mapped_subeventkey { return($key_subevent_Mapped); }
sub get_UnmappedRef_subeventkey { return($key_subevent_UnmappedRef); }
sub get_UnmappedSys_subeventkey { return($key_subevent_UnmappedSys); }

sub get_Numframes_fileattrkey { return($key_fat_numframes); }
sub get_Sourcetype_fileattrkey { return($key_fat_sourcetype); }
sub get_HFramesize_fileattrkey { return($key_fat_hframesize); }
sub get_VFramesize_fileattrkey { return($key_fat_vframesize); }
sub get_Framerate_fileattrkey { return($key_fat_framerate); }

sub _get_hash_file_attributes_types { return(%hash_file_attributes_types); }

########## 'xmllint'

sub set_xmllint {
  my ($self, $xmllint, $nocheck) = MMisc::iuav(\@_, undef, "", 0);

  return(0) if ($self->error());

  $self->{xmllintobj}->set_xmllint($xmllint, $nocheck);

  if ($self->{xmllintobj}->error()) {
    $self->_set_errormsg($self->{xmllintobj}->get_errormsg());
    return(0);
  }
  
  return(1);
}

#####

sub _is_xmllint_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{xmllintobj}->is_xmllint_set());
}

#####

sub get_xmllint {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_xmllint_set()) {
    $self->_set_errormsg("\'xmllint\' is not set");
    return(0);
  }

  return($self->{xmllintobj}->get_xmllint());
}

########## 'xsdpath'

sub set_xsdpath {
  my ($self, $xsdpath, $nocheck) = MMisc::iuav(\@_, undef, "", 0);

  return(0) if ($self->error());

  $self->{xmllintobj}->set_xsdpath($xsdpath, $nocheck);
  if ($self->{xmllintobj}->error()) {
    $self->_set_errormsg($self->{xmllintobj}->get_errormsg());
    return(0);
  }

  return(1);
}

#####

sub _is_xsdpath_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{xmllintobj}->is_xsdpath_set());
}

#####

sub get_xsdpath {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_xsdpath_set()) {
    $self->_set_errormsg("\'xsdpath\' is not set");
    return(0);
  }

  return($self->{xmllintobj}->get_xsdpath());
}

########## 'gtf'

sub set_as_gtf {
  my ($self) = @_;

  return(0) if ($self->error());

  $self->{gtf} = 1;
  return(1);
}

#####

sub set_as_sys {
  my ($self) = @_;

  return(0) if ($self->error());

  $self->{gtf} = 0;
  return(1);
}

#####

sub check_if_gtf {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{gtf});
}

#####

sub check_if_sys {
  my ($self) = @_;

  return(0) if ($self->error());

  my $r = ($self->{gtf}) ? 0 : 1;

  return($r);
}


########## 'force_subtype'

sub set_force_subtype {
  my ($self) = @_;

  return(0) if ($self->error());

  $self->{force_subtype} = 1;
  return(1);
}

#####

sub unset_force_subtype {
  my ($self) = @_;

  return(0) if ($self->error());

  $self->{force_subtype} = 0;
  return(1);
}

#####

sub check_force_subtype {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{force_subtype});
}

#####

sub is_subtype_undefined {
  my ($self, $stype) = @_;

  return(0) if ($self->error());

  if ($self->check_force_subtype()) {
    return(1) if ($stype eq $ok_subevents[0]);
  } else {
    return(1) if (MMisc::is_blank($stype));
  }
  
  return(0);
}

#####

sub get_printable_full_event {
  my ($e, $s, $mode) = @_;

  my $out = $e;

  if ($mode) {
    if (MMisc::is_blank($s)) {
      $out .= $full_event_separator . $ok_subevents[0];
    } else {
      $out .= $full_event_separator . $s;
    } 
  }

  return($out);
}

#####

sub split_full_event {
  my ($fevent, $mode) = @_;

  my ($e, $s) = ($fevent =~ m%^(.+?)(${full_event_separator}.+)?$%);
  $s =~ s%^${full_event_separator}%%;
  if (! defined $s) {
    if ($mode) {
      $s = $ok_subevents[0];
    } else {
      $s = "";
    }
  }
  
  return($e, $s);
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

########## 'fhash'

sub _set_fhash {
  my ($self, %fhash) = @_;

  return(0) if ($self->error());

  $self->{fhash} = \%fhash;
  return(1);
}

#####

sub _is_fhash_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{fhash});

  return(0);
}

#####

sub _get_fhash {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_fhash_set()) {
    $self->_set_erromsg("\'fhash\' is not set");
    return(0);
  }

  my $rfhash = $self->{fhash};

  my %res = %{$rfhash};

  return(%res);
}

########## 'file'

sub set_file {
  my ($self, $file) = @_;

  return(0) if ($self->error());

  if (! -e $file) {
    $self->_set_errormsg("File does not exists ($file)");
    return(0);
  }
  if (! -r $file) {
    $self->set_errormsg("File is not readable ($file)");
    return(0);
  }
  if (! -f $file) {
    $self->set_errormsg("Parameter is not a file ($file)");
    return(0);
  }

  $self->{file} = $file;
  return(1);
}

#####

sub _is_file_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(0) if (MMisc::is_blank($self->{file}));

  return(1);
}

#####

sub get_file {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_file_set()) {
    $self->_set_errormsg("\'file\' is not set");
    return(0);
  }

  return($self->{file});
}

########## 'framespan_max'

sub _is_framespan_max_set {
  my ($self) = @_;

  return(0) if ($self->error());

  my $fs_tmp = $self->{fs_framespan_max};

  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error accessing the \'framespan_max\' object (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  return(1) if ($fs_tmp->is_value_set());

  return(0);
}

#####

sub _get_framespan_max_value {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_framespan_max_set()) {
    $self->_set_errormsg("Can not get \'framespan_max\', it appears not to be set yet");
    return(0);
  }

  my $fs_tmp = $self->{fs_framespan_max};

  my $v = $fs_tmp->get_value();

  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error accessing the \'framespan_max\' object (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  return($v);
}

#####

sub _get_framespan_max_object {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->_is_framespan_max_set()) {
    $self->_set_errormsg("Can not get \'framespan_max\', it appears not to be set yet");
    return(0);
  }

  my $fs_tmp = $self->{fs_framespan_max};

  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error accessing the \'framespan_max\' object (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  return($fs_tmp);
}

#####

sub _set_framespan_max_value {
  my ($self, $fs) = @_;

  return(0) if ($self->error());

  my $fs_tmp = $self->{fs_framespan_max};

  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error accessing the \'framespan_max\' object (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  my $v = $fs_tmp->set_value($fs);
  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error setting the \'framespan_max\' (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  return(1);
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
    $self->_set_errormsg("\'comment\' not set");
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

  # No need to re-validate if the file was already validated :)
  return(1) if ($self->is_validated());

  if (! $self->_is_file_set()) {
    $self->_set_errormsg("No file set (use \'set_file\') before calling the \'validate\' function");
    return(0);
  }
  my $ifile = $self->get_file();

  if (! $self->_is_xmllint_set()) {
    # We will try to set it up from PATH
    return(0) if (! $self->set_xmllint());
  }

  if (! $self->_is_xsdpath_set()) {
    # We will try to set it up from '.'
    return(0) if (! $self->set_xsdpath("."));
  }

  # Load the XML through xmllint
  my ($bigstring) = $self->{xmllintobj}->run_xmllint($ifile);
  if ($self->{xmllintobj}->error()) {
    $self->_set_errormsg($self->{xmllintobj}->get_errormsg());
    return(0);
  }
  # No data from xmllint ?
  if (MMisc::is_blank($bigstring)) {
    $self->_set_errormsg("WEIRD: The XML data returned by xmllint seems empty");
    return(0);
  }

  my $res = "";
  # Initial Cleanups & Check
  ($res, $bigstring) = &_data_cleanup($bigstring);
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }

  # Process the data part
  my %fdata = ();
  my $isgtf = $self->check_if_gtf();
  ($res, %fdata) = $self->_data_processor($bigstring, $isgtf);
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }

  $self->_set_fhash(%fdata);
  $self->_enforce_subtype() if ($self->check_force_subtype());

  $self->{validated} = 1;

  return(1);
}

####################

sub _call_writeback2xml {
  my ($self, $comment, $rfhash, $rxtra_list, @limitto_events) = @_;

  return(0) if ($self->error());

  if (scalar @limitto_events == 0) {
    @limitto_events = $self->validate_events_list(@ok_events);
  } else {
    @limitto_events = $self->validate_events_list(@limitto_events);
    return(0) if ($self->error());
  }

  @limitto_events = $self->reformat_events(@limitto_events);

  return(0) if ($self->error());

  return($self->_writeback2xml($comment, $rfhash, $rxtra_list, @limitto_events));
}

#####

sub reformat_xml {
  my ($self, @limitto_events) = @_;

  my $comment = "";
  $comment = $self->get_comment() if ($self->is_comment_set());

  my %tmp = $self->_get_fhash();

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only rewrite the XML for a validated file");
    return(0);
  }

  my @xtra_list = $self->list_all_xtra_attributes();
  return(0) if ($self->error());

  return($self->_call_writeback2xml($comment, \%tmp, \@xtra_list, @limitto_events));
}

#####

sub get_base_xml {
  my ($self, @limitto_events) = @_;

  my %tmp = ();
  my @xtra_list = ();

  return($self->_call_writeback2xml("", \%tmp, \@xtra_list, @limitto_events));
}

####################

sub _display_all {
  my ($self) = shift @_;

  return("") if ($self->error());

  return(MMisc::get_sorted_MemDump(\$self));
}

#####

sub _display {
  my ($self, @limitto_events) = @_;

  return("") if ($self->error());

  if (scalar @limitto_events == 0) {
    @limitto_events = $self->validate_events_list(@ok_events);
  } else {
    @limitto_events = $self->validate_events_list(@limitto_events);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'_display\' for a validated file");
    return(0);
  }

  my %out = $self->_clone_fhash_selected_events(@limitto_events);

  return(MMisc::get_sorted_MemDump(\%out));
}

########################################

sub _get_short_sf_file {
  my ($txt) = shift @_;

  # Remove all 'file:' or related
  $txt =~ s%^.+\:%%g;

  # Remove all paths
  $txt =~ s%^.*\/%%g;

  # lowercase
  #  $txt = lc($txt);

  return($txt);
}

#####

sub get_sourcefile_filename {
  my ($self) = shift @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'get_sourcefile_filename\' for a validated file");
    return(0);
  }

  my %lk = $self->_get_fhash();

  if (! defined $lk{"file"}{"filename"}) {
    $self->_set_errormsg("WEIRD: In \'get_sourcefile_filename\': Could not find the filename");
    return(0);
  }

  my $fname = $lk{"file"}{"filename"};

  $fname = &_get_short_sf_file($fname);

  return($fname);
}

##########

sub _get_event_observation_common {
  my ($self) = @_;

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only create observations for a validated file");
    return(0);
  }

  if (! $self->is_fps_set()) {
    $self->_set_errormsg("\'fps\' need to be set to create any observation");
    return(0);
  }

  my $xmlfile = $self->get_file();
  my $filename = $self->get_sourcefile_filename();
  my $fps = $self->get_fps();
  my $isgtf = $self->check_if_gtf();
  my $file_fs = $self->get_numframes_value();

  return(0) if ($self->error());

  return($xmlfile, $filename, $fps, $isgtf, $file_fs);
}

#####

sub get_dummy_observation {
  my ($self) = @_;
  # This function is really only used by the tools in case there are no observations in a file

  my ($xmlfile, $filename, $fps, $isgtf, $file_fs) = $self->_get_event_observation_common();
  return(0) if ($self->error());

  my $id = 0;
  my %in = $self->_get_fhash();
  my %file_info = %{$in{"file"}};

  my $obs = new TrecVid08Observation();
  my $event = $obs->get_key_dummy_eventtype();
  my $key_attr_content = $obs->key_attr_content();
  if ($obs->error()) {
    $self->_set_errormsg("Problem getting \'dummy eventtype\' from observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  if (! $obs->set_filename($filename) ) {
    $self->_set_errormsg("Problem adding \'file\' ($filename) to observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  if (! $obs->set_xmlfilename($xmlfile) ) {
    $self->_set_errormsg("Problem adding \'xmlfile\' ($xmlfile) to observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  if (! $obs->set_eventtype($event) ) {
    $self->_set_errormsg("Problem adding \'eventtype\' ($event) to observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  if (! $obs->set_id($id) ) {
    $self->_set_errormsg("Problem adding \'id\' ($id) to observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  if (! $obs->set_ofi(%file_info) ) {
    $self->_set_errormsg("Problem adding \'other file informations\' to observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  if (! $obs->set_isgtf($isgtf) ) {
    $self->_set_errormsg("Problem adding \'isgtf\' to observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  my $fs_file = new ViperFramespan();
  if (! $fs_file->set_value_from_beg_to($file_fs)) {
    $self->_set_errormsg("In observation creation: File's ViperFramespan ($file_fs) error (" . $fs_file->get_errormsg() . ")");
    return(0);
  }
  if (! $fs_file->set_fps($fps)) {
    $self->_set_errormsg("In observation creation: File's ViperFramespan ($file_fs) error (" . $fs_file->get_errormsg() . ")");
    return(0);
  }
  if (! $obs->set_fs_file($fs_file) ) {
    $self->_set_errormsg("Problem adding \'fs_file\' to observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  my $fs = $file_fs; # to validate, it needs a obs' framespan
  my $fs_fs = new ViperFramespan();
  if (! $fs_fs->set_value_from_beg_to($fs)) {
    $self->_set_errormsg("In observation creation: ViperFramespan ($fs) error (" . $fs_fs->get_errormsg() . ")");
    return(0);
  }
  if (! $fs_fs->set_fps($fps)) {
    $self->_set_errormsg("In observation creation: ViperFramespan ($fs) error (" . $fs_fs->get_errormsg() . ")");
    return(0);
  }
  if (! $obs->set_framespan($fs_fs) ) {
    $self->_set_errormsg("Problem adding \'framespan\' to observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  # No a GTF ? Add required fake infos to the observation
  # Note that we do not worry about dynamic ojects here (ie: TODO)
  if (! $isgtf) {
    foreach my $key (@not_gtf_required_objects_attributes) {
      my %dtmp = ();
      $dtmp{"dummytxtfs"}{$key_attr_content} = \@{$not_gtf_required_dummy_values{$key}};
      $obs->set_selected($key, %dtmp);
      if ($obs->error()) {
        $self->_set_errormsg("Problem while using \'set_selected\' ($key) on observation (" . $obs->get_errormsg() .")");
        return(0);
      }
    }
  }
  # Skip xtra attributes

  if (! $obs->validate()) {
    $self->_set_errormsg("Problem validating observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  return($obs);
}

#####

sub get_event_observations {
  my ($self, $full_event) = @_;

  return(0) if ($self->error());

  my ($event, $stype) = &split_full_event($full_event, $self->check_force_subtype());

  if (! grep(m%^$event$%, @ok_events)) {
    $self->_set_errormsg("Requested event ($event) is not a recognized event");
    return(0);
  }

  if (! MMisc::is_blank($stype)) {
    if (! grep(m%^$stype$%, @ok_subevents)) {
      $self->_set_errormsg("Requested subevent ($stype) is not recognized");
      return(0);
    }
  }

  my ($xmlfile, $filename, $fps, $isgtf, $file_fs) = $self->_get_event_observation_common();
  return(0) if ($self->error());

  my %out = $self->_clone_fhash_selected_events($event);

  my %file_info = %{$out{"file"}};

  my @res = ();
  return(@res) if (! defined $out{$event});
  
  my %all_obs = %{$out{$event}};
  foreach my $id (sort _numerically keys %all_obs) {
    # If subtype was requested, only process events of this subtype
    next if ((! MMisc::is_blank($stype)) && ($stype ne $all_obs{$id}{$key_subtype}));

    # Note: we sort the 'id' to keep the same order in the output array (should we need to recreate it later)
    my $obs = new TrecVid08Observation();

    if (! $obs->set_filename($filename) ) {
      $self->_set_errormsg("Problem adding \'file\' ($filename) to observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    if (! $obs->set_xmlfilename($xmlfile) ) {
      $self->_set_errormsg("Problem adding \'xmlfile\' ($xmlfile) to observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    if (! $obs->set_full_eventtype($full_event) ) {
      $self->_set_errormsg("Problem adding \'full_eventtype\' ($full_event) to observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    if (! $obs->set_id($id) ) {
      $self->_set_errormsg("Problem adding \'id\' ($id) to observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    if (! $obs->set_ofi(%file_info) ) {
      $self->_set_errormsg("Problem adding \'other file informations\' to observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    if (! $obs->set_isgtf($isgtf) ) {
      $self->_set_errormsg("Problem adding \'isgtf\' to observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    my $fs_file = new ViperFramespan();
    if (! $fs_file->set_value_from_beg_to($file_fs)) {
      $self->_set_errormsg("In observation creation: File ViperFramespan ($file_fs) error (" . $fs_file->get_errormsg() . ")");
      return(0);
    }
    if (! $fs_file->set_fps($fps)) {
      $self->_set_errormsg("In observation creation: File ViperFramespan ($file_fs) error (" . $fs_file->get_errormsg() . ")");
      return(0);
    }
    if (! $obs->set_fs_file($fs_file) ) {
      $self->_set_errormsg("Problem adding \'fs_file\' to observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    # 'comment' is an optional key of the hash
    my $key = "comment";
    if ($self->is_comment_set()) {
      my $comment = $self->get_comment();
      if (! $obs->addto_comment($comment) ) {
        $self->_set_errormsg("Problem adding \'comment\' to observation (" . $obs->get_errormsg() .")");
        return(0);
      }
    }
    if (exists $all_obs{$id}{$key} ) {
      my $comment = $all_obs{$id}{$key};
      if (! $obs->addto_comment($comment) ) {
        $self->_set_errormsg("Problem adding \'comment\' to observation (" . $obs->get_errormsg() .")");
        return(0);
      }
    }

    my $key = $key_framespan;
    if (! exists $all_obs{$id}{$key} ) { 
      $self->_set_errormsg("WEIRD: Could not get the \'$key\' for event: $event and id: $id");
      return(0);
    }
    my $fs = $all_obs{$id}{$key};
    my $fs_fs = new ViperFramespan();
    if (! $fs_fs->set_value($fs)) {
      $self->_set_errormsg("In observation creation: ViperFramespan ($fs) error (" . $fs_fs->get_errormsg() . ")");
      return(0);
    }
    if (! $fs_fs->set_fps($fps)) {
      $self->_set_errormsg("In observation creation: ViperFramespan ($fs) error (" . $fs_fs->get_errormsg() . ")");
      return(0);
    }
    if (! $obs->set_framespan($fs_fs) ) {
      $self->_set_errormsg("Problem adding \'$key\' to observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    ## This is past the ViperFile validation step, so we know
    # that types are ok, so simply process the dynamic vs
    # non dynamic elements
    my @all_obj_attrs = keys %hash_objects_attributes_types_expected;
    foreach my $okey (@all_obj_attrs) {
      if (exists $all_obs{$id}{$okey}) {
        my %ih = %{$all_obs{$id}{$okey}};
        my %oh = ();
        my $isd = $hash_objects_attributes_types{$okey};

        if ((! $isd) && (scalar keys %ih > 1)) {
          $self->_set_errormsg("WEIRD: There should only be one framepsan per non dynamic attribute ($okey)");
          return(0);
        }

        foreach my $afs (keys %ih) {
          # Here we do not worry about dynamic & non dynamic object, nor about the number of inline attributes
          my $fs_afs = new ViperFramespan();
          if (! $fs_afs->set_value($afs)) {
            $self->_set_errormsg("In observation creation ($okey): ViperFramespan ($afs) error (" . $fs_afs->get_errormsg() . ")");
            return(0);
          }
          if (! $fs_afs->set_fps($fps)) {
            $self->_set_errormsg("In observation creation ($okey): ViperFramespan ($afs) error (" . $fs_afs->get_errormsg() . ")");
            return(0);
          }
          # Since I can not have '@{$oh{$fs_afs}} = @{$ih{$afs}}', ie use the 'ViperFramespan' object as the hash key
          # (which would have been great, but is not authorized by perl since a key has to be a scalar)
          # we will have to rely on a two dimensionnal hash with '$afs' (the string) as its master key
          # (wasteful but insure a proper database key, and more useable/searchable than an array
          # and we can always go from the 'ViperFramespan' to its 'string' value easily)
          my $mkey = $fs_afs->get_value();
          $oh{$mkey}{$obs->key_attr_framespan()} = $fs_afs;
          $oh{$mkey}{$obs->key_attr_content()} = $ih{$afs};
        }

        # Done processing all framespans, now add the entity to the observation
        if (! $obs->set_selected($okey, %oh) ) {
          $self->_set_errormsg("Problem adding \'$okey\' to observation (" . $obs->get_errormsg() .")");
          return(0);
        }
      }
    }

    ## And the xtra attributes (if any)
    if (exists $all_obs{$id}{$key_xtra}) {
      foreach my $xtra (keys %{$all_obs{$id}{$key_xtra}}) {
        if (! $obs->set_xtra_attribute($xtra, $all_obs{$id}{$key_xtra}{$xtra})) {
          $self->_set_errormsg("Problem adding xtra attribute to observation (" . $obs->get_errormsg() . ")");
          return(0);
        }
      }
    }

    ## Validate observation
    if (! $obs->validate()) {
      $self->_set_errormsg("Problem validating observation (" . $obs->get_errormsg() .")");
      return(0);
    }

    push @res, $obs;
  }

  return(@res);
}

##########

sub get_all_events_observations {
  my ($self) = shift @_;
  my @limitto_events = @_;

  return(0) if ($self->error());

  if (scalar @limitto_events == 0) {
    @limitto_events = $self->validate_events_list(@ok_events);
  } else {
    @limitto_events = $self->validate_events_list(@limitto_events);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only create observations for a validated file");
    return(0);
  }

  my @res = ();
  foreach my $event (@limitto_events) {
    my @tmp = $self->get_event_observations($event);
    return(0) if ($self->error());
    push @res, @tmp;
  }

  return(@res);
}

####################

sub remove_all_events {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only \"remove all events\" for a validated file");
    return(0);
  }

  my %out = $self->_clone_fhash_selected_events();

  $self->_set_fhash(%out);
  return(1);
}

##########

sub __clone {
  map { ! ref() ? $_ 
	  : ref eq 'HASH' ? {__clone(%$_)} 
	    : ref eq 'ARRAY' ? [__clone(@$_)] 
	      : ref eq 'ViperFramespan' ? $_->clone() 
		: die "$_ not supported" } @_;
}

#####

sub _clone_core {
  my ($self) = shift @_;
  my @limitto_events = @_;

  return(undef) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only \'clone\' a validated file");
    return(undef);
  }

  my $keep_events = 1;
  if (scalar @limitto_events == 0) {
    $keep_events = 0;
  } else {
    @limitto_events = $self->validate_events_list(@limitto_events);
    return(undef) if ($self->error());
  }
  
  my $clone = new TrecVid08ViperFile();
  
  $clone->set_xmllint($self->get_xmllint(), 1);
  $clone->set_xsdpath($self->get_xsdpath(), 1);
  $clone->set_as_gtf() if ($self->check_if_gtf());
  $clone->set_fps($self->get_fps()) if ($self->is_fps_set());
  $clone->set_file($self->get_file());
  $clone->set_force_subtype() if ($self->check_force_subtype);
  $clone->_set_framespan_max_value($self->_get_framespan_max_value()) if ($self->_is_framespan_max_set());
  $clone->addto_comment($self->get_comment()) if ($self->is_comment_set());
  my %out = ();
  if ($keep_events) {
    %out = $self->_clone_fhash_selected_events(@limitto_events);
  } else {
    %out = $self->_clone_fhash_selected_events();
  }
  $clone->_set_fhash(%out);
  $clone->{validated} = 1;

  return(undef) if ($self->error());
  if ($clone->error()) {
    $self->_set_errormsg("A problem occurred while \'clone\'-ing (" . $clone->get_errormsg() .")");
    return(undef);
  }

  return($clone);
}

#####

sub clone {
  my ($self) = @_;

  return($self->_clone_core(@ok_events));
}

#####

sub clone_with_no_events {
  my ($self) = @_;

  return($self->_clone_core());
}

#####

sub clone_with_selected_events {
  my ($self, @limitto_events) = @_;

  return($self->_clone_core(@limitto_events));
}

##########

sub fill_empty {
  my ($self, $sf_filename, $isgtf, $numframes, $framerate,
      $sourcetype, $hframesize, $vframesize) = @_;

  return(0) if ($self->error());
  
  if (defined $self->{fhash}) {
    $self->_set_errormsg("Can only call \'set_empty_file\' with an empty ViperFile");
    return(0);
  }

  if (MMisc::is_blank($sf_filename)) {
    $self->_set_errormsg("\'set_empty_file\' needs a non empty sourcefile filename");
    return(0);
  }

  my %fhash = ();
  $fhash{"file"}{"filename"} = $sf_filename;
  $fhash{"file"}{"file_id"} = 0;
  $fhash{"file"}{$key_fat_numframes} = ($numframes) ? $numframes : 1; # At least 1
  $fhash{"file"}{$key_fat_framerate} = ($framerate) ? $framerate : undef;
  $fhash{"file"}{$key_fat_sourcetype} = (! MMisc::is_blank($sourcetype)) ? $sourcetype : undef;
  $fhash{"file"}{$key_fat_hframesize} = ($hframesize) ? $hframesize : undef;
  $fhash{"file"}{$key_fat_vframesize} = ($vframesize) ? $vframesize : undef;
  $self->_set_fhash(%fhash);

  $self->set_as_gtf() if ($isgtf);

  return(0) if ($self->error());

  # We have added the strict minimum information required to work
  $self->{"validated"} = 1;
  
  return(1);
}

##########

sub _get_fhash_file_XXX {
  my ($self, $xxx) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only get \'numframes\' for a validated file");
    return(0);
  }

  my %tmp = $self->_get_fhash();

  if (! exists $tmp{"file"}{$xxx}) {
    $self->_set_errormsg("WEIRD: Can not access file's \'$xxx\'");
    return(0);
  }

  return($tmp{"file"}{$xxx});
}

#####

sub get_numframes_value {
  my ($self) = @_;
  return($self->_get_fhash_file_XXX($key_fat_numframes));
}

#####

sub _set_fhash_file_numframes {
  my ($self, $numframes, $ignoresmallervalues, $commentadd) = @_;

  if ($numframes <= 0) {
    $self->_set_errormsg("Can not set file's \'numframes\' to a negative or zero value");
    return(0);
  }

  my $cnf = $self->get_numframes_value();
  return(0) if ($self->error());

  if ($numframes <= $cnf) {
    return(1) if ($ignoresmallervalues);

    my $ha = $self->has_events();
    return(0) if ($self->error());

    if ($ha) { # We can not shrink numframes is there is any event
      $self->_set_errormsg("Can not reduce the file\'s \'numframes\' value");
      return(0);
    }
  }

  my %tmp = $self->_get_fhash();

  if (! exists $tmp{"file"}{$key_fat_numframes}) {
    $self->_set_errormsg("WEIRD: Can not access file's \'numframes\'");
    return(0);
  }

  $tmp{"file"}{$key_fat_numframes} = $numframes;

  $self->_set_fhash(%tmp);
  $self->addto_comment("NUMFRAMES modified from $cnf to $numframes" . ((! MMisc::is_blank($commentadd)) ? " ($commentadd)" : ""));
  return(0) if ($self->error());

  return(1);
}

#####

sub extend_numframes {
  my ($self, $numframes, $commentadd) = @_;

  return($self->_set_fhash_file_numframes($numframes, 1, $commentadd));
}

#####

sub modify_numframes {
  my ($self, $numframes, $commentadd) = @_;

  return($self->_set_fhash_file_numframes($numframes, 0, $commentadd));
}

##########

sub get_first_available_event_id {
  my ($self, $event) = @_;

  return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only get first available event id for a validated file");
    return(-1);
  }

  if (! grep(m%^$event$%, @ok_events)) {
    $self->_set_errormsg("Eventtype ($event) is not a recognized one");
    return(-1);
  }

  my %tmp = $self->_get_fhash();

  # No event of this type set yet, so the first id available (0)
  return(0) if (! exists $tmp{$event});

  my @keys = sort _numerically  keys %{$tmp{$event}};

  return(1 + $keys[-1]);
}

##########

sub _bvalue_convert {
  my ($attr, @values) = @_;

  return(@values) if ($hash_objects_attributes_types{$attr} ne "bvalue");

  my @out = ();
  foreach my $i (@values) {
    if ($i == 1) {
      push @out, "true";
    } elsif ($i == 0) {
      push @out, "false";
    } else {
      push @out, $i;
    }
  }

  return(@out);
}

#####

sub _add_obs_core {
  my ($self, $obs) = @_;

  return(0) if ($self->error());

  if ($obs->error()) {
    $self->_set_errormsg("Proposed Observation seems to have problems (" . $obs->get_errormsg() .")");
    return(0);
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only add an observation to an already validated file");
    return(0);
  }

  if (! $obs->is_validated()) {
    $self->_set_errormsg("Can only add a validated observation");
    return(0);
  }

  return(1);
}

#####

sub extend_numframes_from_observation {
  my ($self, $obs) = @_;

  $self->_add_obs_core($obs);
  return(0) if ($self->error());

  my %ofi = $obs->get_ofi();
  if ($obs->error()) {
    $self->_set_errormsg("Proposed Observation encountered a problems (" . $obs->get_errormsg() .")");
    return(0);
  }

  my $uid = $obs->get_unique_id();
  if ($obs->error()) {
    $self->_set_errormsg("Problem getting the Observation's unique_id (" . $obs->get_errormsg() .")");
    return(0);
  }

  # Try to extend the "NUMFRAMES" (if required)
  my $key = $key_fat_numframes;
  if (! exists $ofi{$key}) {
    $self->_set_errormsg("WEIRD: Problem accessing the observation's file \'$key\' information");
    return(0);
  }
  my $nf = $ofi{$key};

  return(0) if (! $self->extend_numframes($nf, $uid) );

  return(1);
}

#####

sub add_observation {
  my ($self, $obs, $keep_obs_id) = @_;

  $self->_add_obs_core($obs);
  return(0) if ($self->error());

  # Get observation's eventtype
  my $event = $obs->get_eventtype();
  my $stype = ($obs->is_eventsubtype_set()) ? $obs->get_eventsubtype() : "";

  # Confirm the cleaned up filename is the same
  my $obs_filename = $obs->get_filename();
  my $self_filename = $self->get_sourcefile_filename();
  if ($obs_filename ne $self_filename) {
    $self->_set_errormsg("Can only add an observation to a file which \'filename\' match");
    return(0);
  }

  # Confirm that the GTF status is the same
  my $obs_gtf = $obs->get_isgtf();
  my $self_gtf = $self->check_if_gtf();
  if ($obs_gtf ne $self_gtf) {
    $self->_set_errormsg("Can only add an observation to a file whose \'GTF status\' match");
    return(0);
  }

  # For the dummy observation, do nothing more
  my $dummy_obs_key = $obs->get_key_dummy_eventtype();
  return(1)
    if ($event eq $dummy_obs_key);

  my $id = "";
  if ($keep_obs_id) {
    $id = $obs->get_id();
    if ($self->is_event_id_used($event, $id)) {
      $self->_set_errormsg("Can not keep Observation ID into XML file (already exists)");
      return(0);
    }
  } else {
    # Get the next available event id
    $id = $self->get_first_available_event_id($event);
    return(0) if ($self->error());
  }

  ##### From now on we make changes to the structure

  return(0) if (! $self->extend_numframes_from_observation($obs));

  my %tmp = $self->_get_fhash();
  my %sp_out = (); # will be added to $fhash{event}{id}

  # Get the global framespan
  my $key = $key_framespan;
  my $fs_obs = $obs->get_framespan();
  if ($obs->error()) {
    $self->_set_errormsg("Problem accessing the observation's framespan (" . $obs->get_errormsg() .")");
    return(0);
  }
  my $obs_fs = $fs_obs->get_value();
  if ($fs_obs->error()) {
    $self->_set_errormsg("Problem accessing the observation's framespan value (" . $fs_obs->get_errormsg() .")");
    return(0);
  }
  # Set it into the event representation
  $sp_out{$key} = $obs_fs;

  # 'comment' is an optional Observation 'attribute'
  $key = "comment";
  if ($obs->is_comment_set()) {
    my $comment = $obs->get_comment();
    if ($obs->error()) {
      $self->_set_errormsg("Problem accessing the observation's comment (" . $obs->get_errormsg() .")");
      return(0);
    }
    $sp_out{$key} = $comment;
  }

  # Now process the attributes information
  foreach my $attr (keys %hash_objects_attributes_types_expected) {
    if ($hash_objects_attributes_types_dynamic{$attr}) {
      # Dynamic objects
      my ($set, %values) = $obs->get_selected($attr);
      if ($obs->error()) {
        $self->_set_errormsg("Problem obtaining the \'$attr\' observation attribute[1] (" . $obs->get_errormsg() .")");
        return(0);
      }
      next if (! $set);
      foreach my $akey (keys %values) {
        if (! defined $values{$akey}{$obs->key_attr_content()}) {
          $self->_set_errormsg("WEIRD: Could not obtain the \'$attr\' observation attribute value");
          return(0);
        }
        my @a = @{$values{$akey}{$obs->key_attr_content()}};
        @a = &_bvalue_convert($attr, @a);
        @{$sp_out{$attr}{$akey}} = @a;
      }
    } else {
      # Non-Dynamic objects
      my ($set, @values) = $obs->get_selected($attr);
      if ($obs->error()) {
        $self->_set_errormsg("Problem obtaining the \'$attr\' observation attribute[2] (" . $obs->get_errormsg() .")");
        return(0);
      }
      next if (! $set);
      @values = &_bvalue_convert($attr, @values);
      @{$sp_out{$attr}{$obs_fs}} = @values;
    }
  }

  ## and the xtra attributes
  if ($obs->is_xtra_set()) {
    my @xl = $obs->list_all_xtra_attributes();
    foreach my $xtra (@xl) {
      my $v = $obs->get_xtra_value($xtra);
      $self->_set_errormsg("Problem obtaining observation xtra attribute value (" . $obs->get_errormsg() . ")")
        if ($obs->error());
      $sp_out{$key_xtra}{$xtra} = $v;
    }
  }

  ## Finished setting %sp_out, commit it to the local copy of fhash before recreating fhash
  %{$tmp{$event}{$id}} = %sp_out;

  # Add the subtype
  if  (! MMisc::is_blank($stype)) {
    if (! grep(/^$stype$/, @ok_subevents)) {
      $self->_set_errormsg("Found unknown event subtype ($stype) in \'observation\'");
      return(0);
    }
    $self->set_force_subtype();
  }
  $tmp{$event}{$id}{$key_subtype} = $stype;

  $self->_set_fhash(%tmp);
  $self->_enforce_subtype() if ($self->check_force_subtype()); # Just to be safe
  return(0) if ($self->error());

  return(1);
}

##############################

sub change_sourcefile_filename {
  my ($self, $nfname) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'change_sourcefile_filename\' for a validated file");
    return(0);
  }

  my %lk = $self->_get_fhash();

  if (! defined $lk{"file"}{"filename"}) {
    $self->_set_errormsg("WEIRD: In \'get_sourcefile_filename\': Could not find the filename");
    return(0);
  }

  my $oname = $lk{"file"}{"filename"};
  my $soname = &_get_short_sf_file($oname);

  $lk{"file"}{"filename"} = $nfname;
  $self->_set_fhash(%lk);

  $self->addto_comment("\'sourcefile\' changed from \'$oname\' (short: \'$soname\') to \'$nfname\'");

  return(0) if ($self->error());

  return(1);
}

##########

sub _make_full_events_hash_core {
  my ($self, @fevl) = @_;

  my %out = ();
  my %ev = ();
  my %sev = ();
  foreach my $fev (@fevl) {
    my ($e, $s) = &split_full_event($fev, $self->check_force_subtype());
    if ($e eq $fev) { # Requested all the subtypes of the event
      foreach my $st (@ok_subevents) {
	$out{$e}{$st}++;
	$sev{$st}++;
      }
      $ev{$e}++;
    } else {
      $out{$e}{$s}++;
      $ev{$e}++;
      $sev{$s}++ if (! MMisc::is_blank($s));
    }
  }

  my @evl = keys %ev;
  my @sevl = keys %sev;

  return(\@evl, \@sevl, %out);
}

#####

sub make_full_events_hash {
  my ($self, @fevl) = @_;
  my ($d1, $d2, %out) = $self->_make_full_events_hash_core(@fevl);
  return(%out);
}

#####

sub split_events_subevents {
  my ($self, @fevl) = @_;
  my ($rev, $rsev, %dummyh) = $self->_make_full_events_hash_core(@fevl);
  return($rev, $rsev);
}

##########

sub _list_used_full_events {
  my ($self, $mode) = @_;

  my @out = ();

  return(@out) if ($self->error());
  
  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'change_sourcefile_filename\' for a validated file");
    return(@out);
  }

  foreach my $event (@ok_events) {
    if ($mode) {
      foreach my $sev (@ok_subevents) {
	my $fev = &get_printable_full_event($event, $sev, 1);
	push @out, $fev if ($self->exists_event($fev));
      }
    } else {
      push @out, $event if ($self->exists_event($event)); 
    }
  }

  return(@out);
}

#####

sub list_used_events {
  my ($self) = @_;

  return($self->_list_used_full_events(0));
}

#####

sub list_used_full_events {
  my ($self) = @_;

  return($self->_list_used_full_events($self->check_force_subtype()));
}

#####

sub has_events {
  my ($self) = @_;

  return(0) if ($self->error());

  my @used = $self->list_used_events();

  return(1) if (scalar @used > 0);

  return(0);
}

##########

sub _enforce_subtype {
  my ($self) = @_;

  return if (! $self->check_force_subtype());

  my %fhash = $self->_get_fhash();

  foreach my $event (@ok_events) {
    next if (! exists $fhash{$event});
    foreach my $id (keys %{$fhash{$event}}) {
      $fhash{$event}{$id}{$key_subtype} = $ok_subevents[0]
	if (MMisc::is_blank($fhash{$event}{$id}{$key_subtype}));
    }
  }

  $self->_set_fhash(%fhash);
}

##########

sub get_event_ids {
  my ($self, $fev) = @_;

  my @ids = ();

  return(@ids) if ($self->error());

  my ($e, $s) = &split_full_event($fev, 0);
  
  my %fhash = $self->_get_fhash();

  return(@ids) if (! exists $fhash{$e});

  # At this point we know the event is in fhash

  # return 'true' is no subtype is requested (we know because we requested the subtype value to not be undefined is none given)
  if (MMisc::is_blank($s)) {
    @ids = keys %{$fhash{$e}};
    return(@ids);
  } 

  # Otherwise, see if we can find it
  foreach my $id (keys %{$fhash{$e}}) {
    push @ids, $id if ($fhash{$e}{$id}{$key_subtype} eq $s);
  }
  
  return(@ids);
}

#####

sub exists_event {
  my ($self, $fev) = @_;

  my @all = $self->get_event_ids($fev);

  return(0) if ($self->error());

  return(1) if (scalar @all > 0);

  return(0);
}

#####

sub is_event_id_used {
  my ($self, $fev, $id) = @_;

  my @all = $self->get_event_ids($fev);

  return(0) if ($self->error());

  return(1) if (grep(m%^$id$%, @all));

  return(0);
}

#################### change type

sub type_changer_init_randomseed { ## Class function
  my ($seed_found) = @_;

  return(1) if (! defined $seed_found);
  return(1) if (MMisc::is_blank($seed_found));

  my ($seed, $lastfound) = split(m%\:%, $seed_found);

  $rseed = $seed;
  srand($seed);

  $rseed_lastfound = $lastfound if (defined $lastfound);

  &_init_rseed_vals();

  return(1);
}

#####

sub _init_rseed_vals {
  @rseed_vals = ();
  for (my $i = 0; $i < $rseed_max; $i++) {
    push @rseed_vals, rand();
  }
  $rseed_pos = 0;
}

#####

sub _rand {
  my $mul = shift @_;

  $mul = 1 if (! defined $mul);
  $mul = 1 if ($mul == 0);

  # If we did not init rseed_vals, we are in true random mode
  return(rand($mul)) if (scalar @rseed_vals == 0);

  my $v = $rseed_vals[$rseed_pos];
  $rseed_pos = ($rseed_pos == $rseed_max - 1) ? 0 : $rseed_pos + 1;

  return($mul * $v);
}

#####

sub _get_comment_random_value {
  return(sprintf("%.12f", &_rand())) if (! defined $rseed_lastfound);

  my $v = 0;
  my $found = 0;
  my $run = 0;
  my $maxrun = $rseed_max;
  while (! $found) {
    $v = &_rand();
    $found = 1 if (MMisc::are_float_equal($v, $rseed_lastfound, 0));
    $run++;
    die("TrecVid08ViperFile Internal Error: Could not find the requested pseudo random value after $maxrun iterations, aborting\n") 
      if ($run > $maxrun);
  }

  $rseed_lastfound = undef; # Do not do that step next time
  return(sprintf("%.12f", $v)); # the printed value is below the float precision
}

#####

sub _get_random_XXX {
  my ($xxx, $fs) = @_;

  my $type = $hash_objects_attributes_types{$xxx};

  # I cheat a little: I know the required types are not dynamic
  # but just in case they are extended "crash"
  die("TrecVid08ViperFile Internal Error: Type ($xxx) dynamic status not defined by _get_random_XXX method\n") 
    if (! exists $hash_objects_attributes_types_dynamic{$xxx});
  die("TrecVid08ViperFile Internal Error: Type ($xxx) is dynamic and dynamic types are not handled by _get_random_XXX method\n") 
    if ($hash_objects_attributes_types_dynamic{$xxx});

  my $v = 0;
  if ($type eq $list_objects_attributes_types[0]) { # fvalue
    # -127 -> 128
    $v = &_rand(256.0) - 128.0;
  } elsif ($type eq $list_objects_attributes_types[1]) { # bvalue
    # 0 / 1
    $v = int(&_rand(256)) % 2;
  } else {
    die("TrecVid08ViperFile Internal Error: Type ($type) is yet not handled by _get_random_XXX method\n");
  }

  my %out = ();
  push @{$out{$fs}}, $v;

  return(%out);
}

#####

sub change_autoswitch {
  my ($self) = @_;

  return(0) if ($self->error());
  
  if (! $self->is_validated()) {
    $self->_set_errormsg("Can not call \"type changer\" functions on non validated data");
    return(0);
  }

  $self->addto_comment
    ( (defined $rseed)
      ? ("REF to SYS Seed : $rseed (first value: " . &_get_comment_random_value(). ")")
      : "Random REF to SYS Seed" )
      if ($self->check_if_gtf());
  
  my %fhash = $self->_get_fhash();
  foreach my $event (@ok_events) {
    next if (! exists $fhash{$event});
    foreach my $id (sort _numerically keys %{$fhash{$event}}) {
      foreach my $key (@not_gtf_required_objects_attributes) {
	if ($self->check_if_sys()) {
	  # For sys files, we remove the "Detection" values
	  delete $fhash{$event}{$id}{$key};
	} else {
	  my $fs = $fhash{$event}{$id}{$key_framespan};
	  # For ref files, we add random "Detection" values
	  %{$fhash{$event}{$id}{$key}} = &_get_random_XXX($key, $fs);
	}
      }
    }
  }
  $self->_set_fhash(%fhash);
  if ($self->check_if_sys()) {
    $self->set_as_gtf();
  } else {
    $self->set_as_sys();
  }

  return(0) if ($self->error());

  return(1);
}

#####

sub change_sys_to_ref {
  my ($self) = @_;

  if (! $self->check_if_sys()) {
    $self->_set_errormsg("Can not call \'change_sys_to_ref\' on a ref");
    return(0);
  }

  $self->addto_comment("Changed from SYS to REF file");
  return(0) if ($self->error());

  return($self->change_autoswitch());
}

#####

sub change_ref_to_sys {
  my ($self) = @_;

  if (! $self->check_if_gtf()) {
    $self->_set_errormsg("Can not call \'change_ref_to_sys\' on a sys");
    return(0);
  }

  $self->addto_comment("Changed from REF to SYS file");
  return(0) if ($self->error());

  return($self->change_autoswitch());
}

########## 'Summary'

sub get_txt_and_number_of_events {
  my ($self, $v) = @_;

  return("", -1, -1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'get_summary\' on a validated file");
    return("", -1, -1);
  }

  my $txt = "";

  my @et = $self->list_used_full_events();
  my $et = scalar @et;
  my $tot = 0;
  foreach my $event (sort_events(@et)) {
    $txt .= " $event";
    my @ids = $self->get_event_ids($event);
    $tot += scalar @ids;
    next if ($v < 2);
    $txt .= "(x" . scalar @ids . ")";
    next if ($v < 3);
    $txt .= "[IDs: " . join(" ", sort {$a <=> $b} @ids) . "]";
  }
  
  return(MMisc::clean_begend_spaces($txt), $et, $tot);
}

#####

sub get_summary {
  my ($self, $v) = @_;

  return("") if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'get_summary\' on a validated file");
    return("");
  }

  my $ns = "-- NOT SET --";
  $v -= 3 if ($v > 3);

  my $txt = "";
  $txt .= "|--> Summary for file:  " . $self->get_file() . "\n";
  $txt .= "| |    Sourcefile : " . $self->get_sourcefile_filename() . "\n";
  $txt .= "| |          Type : " . (($self->check_if_gtf()) ? "REF" : "SYS") . "\n";
  $txt .= "| |   cmdline FPS : " . (($self->is_fps_set()) ? $self->get_fps() : $ns) . "\n";

  my $tmp = $self->_get_fhash_file_XXX($key_fat_framerate);
  $txt .= "| |     Framerate : ". (MMisc::is_blank($tmp) ? $ns : $tmp) . "\n";

  $txt .= "| |     NumFrames : " . $self->get_numframes_value() . "\n";

  $tmp = $self->_get_fhash_file_XXX($key_fat_sourcetype);
  $txt .= "| |    Sourcetype : " . (MMisc::is_blank($tmp) ? $ns : $tmp) . "\n";

  $tmp = $self->_get_fhash_file_XXX($key_fat_hframesize);
  $txt .= "| |  H Frame Size : " . (MMisc::is_blank($tmp) ? $ns : $tmp) . "\n";

  $tmp = $self->_get_fhash_file_XXX($key_fat_vframesize);
  $txt .= "| |  V Frame Size : " . (MMisc::is_blank($tmp) ? $ns : $tmp) . "\n";

  my ($ettxt, $te, $tot) = $self->get_txt_and_number_of_events($v);
  $txt .= "| |   Event Types : $ettxt\n";
  $txt .= "| |  Total Events : $tot\n";

  $txt .= "| |       Comment : " . (($self->is_comment_set()) ? $self->get_comment() : $ns) . "\n";
  
  return("") if ($self->error());

  return($txt);
}

######################################## 'xtra'

sub get_key_xtra_trackingcomment { return($key_xtra_trackingcomment); }

##

sub get_char_tc_separator { return($char_tc_separator); }
sub get_char_tc_beg_entry { return($char_tc_beg_entry); }
sub get_char_tc_end_entry { return($char_tc_end_entry); }
sub get_char_tc_entry_sep { return($char_tc_entry_sep); }
sub get_char_tc_comp_sep  { return($char_tc_comp_sep); }
sub get_char_tc_beg_pre   { return($char_tc_beg_pre); }
sub get_char_tc_end_pre   { return($char_tc_end_pre); }

sub get_array_tc_list     { return(@array_xtra_tc_list); }

##

sub get_xtra_tc_original { return($key_xtra_tc_original); }
sub get_xtra_tc_modsadd  { return($key_xtra_tc_modsadd); }

sub get_xtra_tc_authorized_keys { return(@keys_xtra_tc_authorized); }

#####

sub set_xtra_Tracking_Comment {
  my ($self, $add) = @_;

  if ( (! MMisc::is_blank($add)) && (! grep(m%$add$%, @keys_xtra_tc_authorized)) ) {
    $self->_set_errormsg("Requested add for \'Tracking Comment\' is not an authorized value");
    return(0);
  }

  return($self->set_xtra_attribute($key_xtra_trackingcomment, $spval_xtra_trackingcomment, 0, $add));
}

#####

sub unset_xtra_Tracking_Comment {
  my ($self) = @_;

  return($self->unset_xtra_attribute($key_xtra_trackingcomment));
}

##########

sub __write_entry_line {
  my ($k, $v, $s) = @_;

  my $txt = "$k$char_tc_comp_sep$v";
  $txt .= "$char_tc_entry_sep" if (! $s);

  return($txt);
}

#####

sub set_xtra_attribute {
  my ($self, $attr, $value, $replace, $addtotc) = @_;
  # 'addtotc' is ignored unless we are writting an xtra_Tracking_Comment

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'set_xtra_attribute\' on a validated file");
    return(0);
  }

  if ( (MMisc::is_blank($attr)) || (MMisc::is_blank($value)) ) {
    $self->_set_errormsg("Can only call \'set_xtra_attribute\' with values for both \'attr\' and \'value\'");
    return(0);
  }
    
  if (($attr eq $key_xtra_trackingcomment) && ($value ne $spval_xtra_trackingcomment)) {
    $self->_set_errormsg("\'$key_xtra_trackingcomment\' is a reserved keyword, refusing to add");
    return(0);
  }

  my $addvalue = $value;
  my %fhash = $self->_get_fhash();
  foreach my $event (@ok_events) {
    next if (! exists $fhash{$event});
    foreach my $id (sort _numerically keys %{$fhash{$event}}) {
      if ($value eq $spval_xtra_trackingcomment) {
        my $pretxt = (MMisc::is_blank($addtotc)) ? "" 
          : " $char_tc_beg_pre$addtotc$char_tc_end_pre";
        my $file = $self->get_file();
        my $sffn = $self->get_sourcefile_filename();
        my $gtftxt = $self->check_if_gtf() ? "GTF" : "SYS";
        my $subtype = $fhash{$event}{$id}{$key_subtype};
        $subtype = MMisc::is_blank($subtype) ? "Not Set" : $subtype;
        my $range = $fhash{$event}{$id}{$key_framespan};
        my $xtra_txt = "Not Set";
        if (exists $fhash{$event}{$id}{$key_xtra}) {
          my @xtra_list = grep(! m%$key_xtra_trackingcomment$%, 
                               sort keys %{$fhash{$event}{$id}{$key_xtra}} );
          $xtra_txt = join(" ", @xtra_list);
        }

        $addvalue 
          = "$char_tc_beg_entry$pretxt " .
            &__write_entry_line($array_xtra_tc_list[0], $file) .
            &__write_entry_line($array_xtra_tc_list[1], $sffn) .
            &__write_entry_line($array_xtra_tc_list[2], $gtftxt) .
            &__write_entry_line($array_xtra_tc_list[3], $event) .
            &__write_entry_line($array_xtra_tc_list[4], $subtype) .
            &__write_entry_line($array_xtra_tc_list[5], $id) .
            &__write_entry_line($array_xtra_tc_list[6], $range) .
            &__write_entry_line($array_xtra_tc_list[7], $xtra_txt, 1) .
            $char_tc_end_entry;
      }
      if ((! exists $fhash{$event}{$id}{$key_xtra}{$attr}) || ($replace)) {
        $fhash{$event}{$id}{$key_xtra}{$attr} = $addvalue;
      } else {
        $fhash{$event}{$id}{$key_xtra}{$attr} .= " $char_tc_separator $addvalue";
      }
    }
  }
  $self->_set_fhash(%fhash);

  return(1);
}

##########

sub unset_xtra_attribute {
  my ($self, $attr) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'unset_xtra_attribute\' on a validated file");
    return(0);
  }

  my %fhash = $self->_get_fhash();
  foreach my $event (@ok_events) {
    next if (! exists $fhash{$event});
    foreach my $id (sort _numerically keys %{$fhash{$event}}) {
      next if (! exists $fhash{$event}{$id}{$key_xtra});
      delete $fhash{$event}{$id}{$key_xtra}{$attr} 
        if (exists $fhash{$event}{$id}{$key_xtra}{$attr});
      delete $fhash{$event}{$id}{$key_xtra}
        if (scalar(keys %{$fhash{$event}{$id}{$key_xtra}}) == 0);
    }
  }
  $self->_set_fhash(%fhash);

  return(1);
}

##########

sub list_all_xtra_attributes {
  my ($self) = @_;

  my @aa = ();

  return(@aa)
    if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'list_all_xtra_attributes\' on a validated file");
    return(@aa);
  }

  my %fhash = $self->_get_fhash();
  foreach my $event (@ok_events) {
    next if (! exists $fhash{$event});
    foreach my $id (sort _numerically keys %{$fhash{$event}}) {
      next if (! exists $fhash{$event}{$id}{$key_xtra});
      push @aa, keys %{$fhash{$event}{$id}{$key_xtra}};
    }
  }
  @aa = MMisc::make_array_of_unique_values(@aa);

  return(@aa);
}

#####

sub list_xtra_attributes {
  my ($self) = @_;

  my @aa = $self->list_all_xtra_attribute();
  my @xl = ();

  return(@xl) 
    if ($self->error());

  @xl = grep(! m%^$key_xtra_trackingcomment$%, @aa);

  return(@xl);
}

##########

sub unset_all_xtra_attributes {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'unset_all_xtra_attributes\' on a validated file");
    return(0);
  }

  my %fhash = $self->_get_fhash();
  foreach my $event (@ok_events) {
    next if (! exists $fhash{$event});
    foreach my $id (sort _numerically keys %{$fhash{$event}}) {
      next if (! exists $fhash{$event}{$id}{$key_xtra});
      my @xl = keys %{$fhash{$event}{$id}{$key_xtra}};
      @xl = grep(! m%^$key_xtra_trackingcomment$%, @xl);
      foreach my $x (@xl) {
        delete $fhash{$event}{$id}{$key_xtra}{$x};
      }
      delete $fhash{$event}{$id}{$key_xtra}
        if (scalar(keys %{$fhash{$event}{$id}{$key_xtra}}) == 0);
    }
  }
  $self->_set_fhash(%fhash);

  return(1);
}

############################################################
# Internals
########################################

sub _data_cleanup {
  my $bigstring = shift @_;

  # Remove all XML comments
  $bigstring =~ s%\<\!\-\-.+?\-\-\>%%sg;

  # Remove <?xml ...?> header
  return("Could not find a proper \'<?xml ... ?>\' header, skipping", $bigstring)
    if (! ($bigstring =~ s%^\s*\<\?xml.+?\?\>%%is));

  # Remove <viper ...> and </viper> header and trailer
  return("Could not find a proper \'viper\' tag, aborting", $bigstring)
    if (! MtXML::remove_xml_tags("viper", \$bigstring));

  # Remove <config> section
  return("Could not find a proper \'config\' section, aborting", $bigstring)
    if (! MtXML::remove_xml_section("config", \$bigstring));

  # At this point, all we ought to have left is the '<data>' content
  return("After initial cleanup, we found more than just viper \'data\', aborting", $bigstring)
    if (! ( ($bigstring =~ m%^\s*\<data>%is) && ($bigstring =~ m%\<\/data\>\s*$%is) ) );

  return("", $bigstring);
}

########################################

sub _data_processor {
  my ($self) = shift @_;
  my $string = shift @_;
  my $isgtf = shift @_;

  my $res = "";
  my %fdata = ();

  #####
  # First off, confirm the first section is 'data' and remove it
  my $name = MtXML::get_next_xml_name($string, $default_error_value);
  return("Problem obtaining a valid XML name, aborting", $string)
    if ($name eq $default_error_value);
  return("\'data\' section not present (instead: $name), aborting", $string)
    if ($name !~ m%^data$%i);
  return("Problem cleaning \'data\' tags", $string)
    if (! MtXML::remove_xml_tags($name, \$string));

  #####
  # Now, the next --and only-- section is to be a 'sourcefile'
  my $name = MtXML::get_next_xml_name($string, $default_error_value);
  return("Problem obtaining a valid XML name, aborting", $string)
    if ($name eq $default_error_value);
  return("\'sourcefile\' section not present (instead: $name), aborting", $string)
    if ($name !~ m%^sourcefile$%i);
  my $tmp = $string;
  my $section = MtXML::get_named_xml_section($name, \$string, $default_error_value);
  return("Problem obtaining the \'sourcefile\' XML section, aborting", $tmp)
    if ($name eq $default_error_value);
  # And nothing else should be left in the file
  return("Data left in addition to the \'sourcefile\' XML section, aborting", $string)
    if (! MMisc::is_blank($string));
  # Parse it
  ($res, %fdata) = $self->_parse_sourcefile_section($name, $section, $isgtf);
  if (! MMisc::is_blank($res)) {
    my @resA = split(/\n/, $res);
    my $str = "";
    for (my $_i=0; $_i<@resA; $_i++) {  
      $str .= "Problem while processing the \'sourcefile\' XML section (" . 
        "Error ".($_i+1)." of ".scalar(@resA).": $resA[$_i])\n";
    }
    return($str, ());
  }
  return($res, %fdata);
}

#################### 

sub _find_hash_key {
  my $name = shift @_;
  my %hash = @_;

  my @keys = keys %hash;

  my @list = grep(m%^${name}$%i, @keys);
  return("key ($name) does not seem to be present", "")
    if (scalar @list == 0);
  return("key ($name) seems to be present multiple time (" . join(", ", @list) .")", "")
    if (scalar @list > 1);
  
  return("", $list[0]);
}

####################

sub _parse_sourcefile_section {
  my ($self) = shift @_;
  my $name = shift @_;
  my $str = shift @_;
  my $isgtf = shift @_;

  my %res = ();
  
  #####
  # First, get the inline attributes from the 'sourcefile' inline attribute itself
  my ($text, %iattr) = MtXML::get_inline_xml_attributes($name, $str);
  return($text, ()) if (! MMisc::is_blank($text));

  # We should only have a \'filename\'
  my @keys = keys %iattr;
  return("Found multiple keys in the \'sourcefile\' inlined attributes", ())
    if (scalar @keys > 1);
  ($text, my $found) = &_find_hash_key("filename", %iattr);
  return($text, ()) if (! MMisc::is_blank($text));

  my $filename = $iattr{$found};

  #####
  # We can now remove the \'sourcefile\' header and trailer tags
  return("WEIRD: could not remove the \'$name\' header and trailer tags", ())
    if (! MtXML::remove_xml_tags($name, \$str));

  #####
  # Get the 'file' section
  my $sec = MtXML::get_named_xml_section("file", \$str, $default_error_value);
  return("No \'file\' section found in the \'sourcefile\'", ())
    if ($sec eq $default_error_value);
  ($text, my %fattr) = $self->_parse_file_section($sec);
  return($text, ()) if (! MMisc::is_blank($text));
  
  # Complete %fattr and start filling %res
  $fattr{"filename"} = $filename;
  %{$res{"file"}} = %fattr;

  ##########
  # Process all that is left in the string (should only be objects)
  $str = MMisc::clean_begend_spaces($str);
  
  my @error_list = ();
  while (! MMisc::is_blank($str)) {
    my $sec = MtXML::get_named_xml_section("object", \$str, $default_error_value);
    # Prepare string for the next run
    $str = MMisc::clean_begend_spaces($str);
    
    # Now process the extracted section
    if ($sec eq $default_error_value) {
      push (@error_list, ("No \'object\' section left in the \'sourcefile\'"));
      next;
    }
    
    ($text, my $object_type, my $object_subtype, my $object_id, my $object_framespan, my %oattr)
      = $self->_parse_object_section($sec, $isgtf);
    if (! MMisc::is_blank($text)) {
      push (@error_list, $text);
      next;
    }
    
    ##### Sanity
    
    # Check that the object name is an authorized event name
    if (! grep(/^$object_type$/, @ok_events)) {
      push (@error_list, "Found unknown event type ($object_type) in \'object\'");
      next;
    }
    
    # Check that the object type/id key does not already exist
    if (exists $res{$object_type}{$object_id}) {
      push (@error_list, "Only one unique (event type, id) key authorized ($object_type, $object_id)");
      next;
    }
    
    # Check the subtype
    if  (! MMisc::is_blank($object_subtype)) {
      if (! grep(/^$object_subtype$/, @ok_subevents)) {
	push (@error_list, "Found unknown event subtype ($object_subtype) in \'object\'");
	next;
      }
      $self->set_force_subtype();
    }
	 
    ##### Add to %res
    %{$res{$object_type}{$object_id}} = %oattr;
    $res{$object_type}{$object_id}{$key_framespan} = $object_framespan;
    $res{$object_type}{$object_id}{$key_subtype} = $object_subtype;
  }

  if (@error_list > 0) {
    return(join(". ",@error_list), ());
  }
  
  ##### Final Sanity Checks
  if (($check_ids_start_at_zero) || ($check_ids_are_consecutive)) {
    foreach my $event (@ok_events) {
      next if (! exists $res{$event});
      my @list = sort _numerically keys %{$res{$event}};
      
      if ($check_ids_start_at_zero) {
        return("Event ID list must always start at 0 (for event \'$event\', start at " . $list[0] . ")", ())
          if ($list[0] != 0);
      }
      
      if ($check_ids_are_consecutive) {
        return("Event ID list must always start at 0 and have no gap (for event \'$event\', seen "
               . scalar @list . " elements (0 -> " . $list[-1] . ")", ())
          if (scalar @list != $list[-1] + 1); 
      }
    }
  }

  return("", %res);
}

####################

sub _parse_file_section {
  my ($self) = shift @_;
  my $str = shift @_;

  my $wtag = "file";
  my %file_hash = ();

  my ($text, %attr) = MtXML::get_inline_xml_attributes($wtag, $str);
  return($text, ()) if (! MMisc::is_blank($text));

  my $framespan_max = $framespan_max_default;

  my @expected = @array_file_inline_attributes;
  my ($in, $out) = MMisc::confirm_first_array_values(\@expected, keys %attr);
  return("Could not find all the expected inline \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected inline \'$wtag\' attributes", ())
    if (scalar @$out > 0);

  # Get the file id
  return("WEIRD: Could not find the \'id\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[0]});
  my $fid = $attr{$expected[0]};
  return("Only one authorized $wtag id [0, here $fid]", ())
    if ($fid != 0);
  $file_hash{"file_id"} = $fid;

  # Remove the \'file\' header and trailer tags
  return("WEIRD: could not remove the \'$wtag\' header and trailer tags", ())
    if (! MtXML::remove_xml_tags($wtag, \$str));

  #####
  # Process each "attribute" left now
  ($text, %attr) = $self->_parse_attributes(\$str);
  return("While parsing the \'$wtag\' \'attribute\'s : $text", ())
    if (! MMisc::is_blank($text));

  # Confirm they are the ones we want
  my %expected_hash = %hash_file_attributes_types;
  @expected = keys %expected_hash;
  ($in, $out) = MMisc::confirm_first_array_values(\@expected, keys %attr);
  return("Could not find all the expected \'$wtag\' attributes [Found: " . join(" ", @$in) ."] [Expected: " . join(" ", @expected) . "]", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'$wtag\' attributes [" . join(" ", @$out) . "]", ())
    if (scalar @$out > 0);

  # Check they are of valid type & reformat them for the output file hash
  foreach my $key (@expected) {
    $file_hash{$key} = undef;
    my $val = $expected_hash{$key};
    next if (! defined $val);
    my @comp = keys %{$attr{$key}};
    next if (scalar @comp == 0);
    my @expected2 = ();
    push @expected2, $val;
    ($in, $out) = MMisc::confirm_first_array_values(\@expected2, @comp);
    return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type", ())
      if (scalar @$out > 0);

    return("WEIRD: Could not find the value associated with the \'$key\' \'$wtag\' attribute", ())
      if (! exists $attr{$key}{$val}{$framespan_max});
    $file_hash{$key} = ${$attr{$key}{$val}{$framespan_max}}[0];
  }

  # Set the "framespan_max" from the NUMFRAMES entry
  my $key = $key_fat_numframes;
  return("No \'$key\' \'$wtag\' attribute defined", ())
    if (! defined $file_hash{$key});
  my $val = $file_hash{$key};
  return("Invalid value for \'$key\' \'$wtag\' attribute", ())
    if ($val < 0);

  $framespan_max = "1:$val";
  return("Problem setting the framespan_max object value ($framespan_max)")
    if (! $self->_set_framespan_max_value($framespan_max));

  return("", %file_hash);
}

##########

sub _parse_object_section {
  my ($self) = shift @_;
  my $str = shift @_;
  my $isgtf = shift @_;

  my $wtag = "object";

  my $object_name = "";
  my $object_id = "";
  my $object_framespan = "";
  my %object_hash = ();

  my ($text, %attr) = MtXML::get_inline_xml_attributes($wtag, $str);
  return($text, ()) if (! MMisc::is_blank($text));

  my $framespan_max = $self->_get_framespan_max_value();
  return("Problem obtaining the \'framespan_max\' value", ()) if ($self->error());
  my $fs_framespan_max = $self->_get_framespan_max_object();
  return("Problem obtaining the \'framespan_max\' object", ()) if ($self->error());

  my @expected = @array_objects_inline_attributes;
  my ($in, $out) = MMisc::confirm_first_array_values(\@expected, keys %attr);
  return("Could not find all the expected inline \'object\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected inline \'object\' attributes", ())
    if (scalar @$out > 0);

  # Get the object name
  return("WEIRD: Could not obtain the \'name\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[0]});
  $object_name = $attr{$expected[0]};

  # Get the object id
  return("WEIRD: Could not obtain the \'id\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[1]});
  $object_id = $attr{$expected[1]};

  # Get the object framespan
  return("WEIRD: Could not obtain the \'framespan\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[2]});
  my $tmp = $attr{$expected[2]};

  my $fs_tmp = new ViperFramespan();
  return("ViperFramespan ($tmp) error (" . $fs_tmp->get_errormsg() . ")", ())
    if (! $fs_tmp->set_value($tmp));
  my $ok = $fs_tmp->is_within($fs_framespan_max);
  return("ViperFramespan ($tmp) error (" . $fs_tmp->get_errormsg() . ")", ()) if ($fs_tmp->error());
  return("ViperFramespan ($tmp) is not within range (" . $fs_framespan_max->get_original_value() . ")", ()) if (! $ok);
  my $pc = $fs_tmp->count_pairs_in_original_value();
  return("ViperFramespan ($tmp) error (" . $fs_tmp->get_errormsg() . ")", ()) if ($fs_tmp->error());
  return("ViperFramespan ($tmp) contains more than $max_pair_per_fs range pair(s)") if (($max_pair_per_fs) && ($pc > $max_pair_per_fs));
  $object_framespan = $fs_tmp->get_value();

  # Remove the \'object\' header and trailer tags
  return("WEIRD: could not remove the \'$wtag\' header and trailer tags", ())
    if (! MtXML::remove_xml_tags($wtag, \$str));

  #####
  # Process each "attribute" left now
  ($text, %attr) = $self->_parse_attributes(\$str, $object_framespan);
  return("While parsing the \'$wtag\' \'attribute\'s : $text", ())
    if (! MMisc::is_blank($text));
  
  # Confirm they are the ones we want (except for xtra ones)
  my %expected_hash = %hash_objects_attributes_types_expected;
  @expected = keys %expected_hash;
  ($in, $out) = MMisc::confirm_first_array_values(\@expected, keys %attr);
  return("Could not find all the expected \'$wtag\' attributes [Found: " . join(" ", @$in) ."] [Expected: " . join(" ", @expected) . "]", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'$wtag\' attributes[" . join(" ", @$out) . "]", ())
    if (scalar @$out > 0);

  my @det_sub = @not_gtf_required_objects_attributes;

  # Check they are of valid type & reformat them for the output object hash
  foreach my $key (@expected) {
    my $val = $expected_hash{$key};
    next if (! defined $val);
    my @comp = keys %{$attr{$key}};
    if (scalar @comp == 0) {
      next if ($isgtf);
      return("Expected \'$wtag\' required attribute ($key) does not have a value", ())
        if (grep(m%^$key$%, @det_sub));
      next;
    } else {
      # GTF must not have the Detection attributes set
      return("\'$wtag\' attribute ($key) should not have a value for GTF", ())
        if (($isgtf) && (grep(m%^$key$%, @det_sub)));
    }
    my @expected2 = ();
    push @expected2, $val;
    ($in, $out) = MMisc::confirm_first_array_values(\@expected2, @comp);
    return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type", ())
      if (scalar @$out > 0);

    foreach my $fs (keys %{$attr{$key}{$val}}) {
      @{$object_hash{$key}{$fs}} = @{$attr{$key}{$val}{$fs}};
    }
  }

  # simply copy the xtra ones
  $object_hash{$key_xtra} = $attr{$key_xtra}
      if (exists $attr{$key_xtra});

  my ($etype, $stype) = &split_full_event($object_name, $self->check_force_subtype()); 

  return("", $etype, $stype, $object_id, $object_framespan, %object_hash);
}

####################

sub _data_process_array_core {
  my $name = shift @_;
  my $rattr = shift @_;
  my @expected = @_;

  my ($in, $out) = MMisc::confirm_first_array_values(\@expected, keys %$rattr);
  return("Could not find all the expected \'data\:$name\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'data\:$name\' attributes", ())
    if (scalar @$out > 0);

  my @res = ();
  foreach my $key (@expected) {
    push @res, $$rattr{$key};
  }

  return("", @res);
}

#####

sub _data_process_type {
  my $type = shift @_;
  my %attr = @_;

  return("Found some unknown \'data\:\' type ($type)", ())
    if (! exists $hasharray_inline_attributes{$type});

  my @expected = @{$hasharray_inline_attributes{$type}};

  return(&_data_process_array_core($type, \%attr, @expected));
}

#####

sub _extract_data {
  my ($self) = shift @_;
  my $str = shift @_;
  my $fspan = shift @_;
  my $allow_nofspan = shift @_;
  my $type = shift @_;

  my %attr = ();
  my @afspan = ();

  my $fs_fspan = new ViperFramespan();
  if (! $allow_nofspan) {
    return("ViperFramespan ($fspan) error (" . $fs_fspan->get_errormsg() . ")", ())
      if (! $fs_fspan->set_value($fspan));
  }

  while (! MMisc::is_blank($str)) {
    my $name = MtXML::get_next_xml_name($str, $default_error_value);
    return("Problem obtaining a valid XML name, aborting", ())
      if ($name eq $default_error_value);
    return("\'data\' extraction process does not seem to have found one, aborting", ())
      if ($name !~ m%^data\:%i);
    my $section = MtXML::get_named_xml_section($name, \$str, $default_error_value);
    return("Problem obtaining the \'data\:\' XML section, aborting", ())
      if ($name eq $default_error_value);

    # All within a data: entry is inlined, so get the inlined content
    my ($text, %iattr) = MtXML::get_inline_xml_attributes($name, $section);
    return($text, ()) if (! MMisc::is_blank($text));

    # From here we work per 'data:' type
    $name =~ s%^data\:%%;

    # Check the framespan (if any)
    my $lfspan = "";
    my $key = $key_framespan;
    if (exists $iattr{$key}) {
      $lfspan = $iattr{$key};

      my $fs_lfspan = new ViperFramespan();
      return("ViperFramespan ($lfspan) error (" . $fs_lfspan->get_errormsg() . ")", ())
        if (! $fs_lfspan->set_value($lfspan));
      my $iw = $fs_lfspan->is_within($fs_fspan);
      return("ViperFramespan ($lfspan) error (" . $fs_lfspan->get_errormsg() . ")", ()) if ($fs_lfspan->error());
      return("ViperFramespan ($lfspan) is not within range (" . $fs_fspan->get_original_value() . ")", ()) if (! $iw);
      my $pc = $fs_lfspan->count_pairs_in_original_value();
      return("ViperFramespan ($lfspan) error (" . $fs_lfspan->get_errormsg() . ")", ()) if ($fs_lfspan->error());
      return("ViperFramespan ($lfspan) contains more than $max_pair_per_fs range pair(s)") if (($max_pair_per_fs) && ($pc > $max_pair_per_fs));

      foreach my $fs_tmp (@afspan) {
        my $ov = $fs_lfspan->check_if_overlap($fs_tmp);
        return("ViperFramespan ($lfspan) error (" . $fs_lfspan->get_errormsg() . ")", ()) if ($fs_tmp->error());
        return("ViperFramespan ($lfspan) overlap another framespan (" . $fs_tmp->get_original_value() . ") within the same object attribute", ()) if ($ov);
      }
      push @afspan, $fs_lfspan;

      delete $iattr{$key};
      $lfspan = $fs_lfspan->get_value();
    } elsif ($allow_nofspan) {
      # This is an element for which we know at this point we do not have to worry about its framespan status
      # (most likely not processing any "object" but a "file"), make it valid for the entire provided framespan
      $lfspan = $fspan;
    } elsif (&_is_an_xtra_attribute($type)) {
      # valid for the entire provided framespan
      $lfspan = $fspan;
    } else {
      # if none was specified, check if the type is dynamic
      return("Can not confirm the dynamic status of found \'data\:\' type ($name)", ())
        if (! exists $hash_objects_attributes_types_dynamic{$type});

      # If it is, a framespan should have been provided
      return("No framespan provided for dynamic \'data\:\' type ($name)", ())
        if ($hash_objects_attributes_types_dynamic{$type} == 1);

      # otherwise, it means that it is valid for the entire provided framespan
      $lfspan = $fspan;
    }

    # Process the leftover elements
    ($text, @{$attr{$name}{$lfspan}}) = &_data_process_type($name, %iattr);
    return($text, ()) if (! MMisc::is_blank($text));
  }

  return("", %attr);
}

#####

sub _parse_attributes {
  my ($self) = shift @_;
  my $rstr = shift @_;
  my $fspan = shift @_;
  my %attrs = ();

  my $allow_nofspan = 0;
  if (MMisc::is_blank($fspan)) {
    if (! $self->_is_framespan_max_set()) {
      $fspan = $framespan_max_default;
    } else {
      return("WEIRD: At this point the framespan range should be defined", ());
    }
    $allow_nofspan = 1;
  }
  
  # We process all the "attributes"
  while (! MMisc::is_blank($$rstr)) {
    my $sec = MtXML::get_named_xml_section("attribute", $rstr, $default_error_value);
    return("Could not find an \'attribute\'", ()) if ($sec eq $default_error_value);

    # Get its name
    my ($text, %iattr) = MtXML::get_inline_xml_attributes("attribute", $sec);
    return($text, ()) if (! MMisc::is_blank($text));

    return("Found more than one inline attribute for \'attribute\'", ())
      if (scalar %iattr != 1);
    return("Could not find the \'name\' of the \'attribute\'", ())
      if (! exists $iattr{"name"});

    my $name = $iattr{"name"};

    # Now get its content
    return("WEIRD: could not remove the \'attribute\' header and trailer tags", ())
      if (! MtXML::remove_xml_tags("attribute", \$sec));

    # Process the content
    $sec = MMisc::clean_begend_spaces($sec);

    if (&_is_an_xtra_attribute($name)) {
      if (! MMisc::is_blank($sec)) {
        my $kn = &_get_xtra_attribute_name($name);
        ($text, my %tmp) = $self->_extract_data($sec, $fspan, $allow_nofspan, $name);
        return("Error while processing the \'data\:\' content of the xtra ($kn) \'attribute\' ($text)", ())
          if (! MMisc::is_blank($text));
        ($text, my $kv) = MMisc::dive_structure(\%tmp);
        return("Error while extracting the \'data\:\' content of the xtra ($kn) \'attribute\' ($text)", ())
          if (! defined $kv);
        $attrs{$key_xtra}{$kn} = $kv;
      }
    } else { # Not an xtra attribute
      if (MMisc::is_blank($sec)) {
        $attrs{$name} = undef;
      } else {
        ($text, my %tmp) = $self->_extract_data($sec, $fspan, $allow_nofspan, $name);
        return("Error while processing the \'data\:\' content of the \'$name\' \'attribute\' ($text)", ())
          if (! MMisc::is_blank($text));
        %{$attrs{$name}} = %tmp;
      }
    }

  } # while

  return("", %attrs);
}

########################################

sub _is_an_xtra_attribute {
  my $type = shift @_;

  return(1) if ($type =~ m%^$key_xtra%);

  return(0);
}

#####

sub _get_xtra_attribute_name {
  my $name = shift @_;

  $name =~ s%^$key_xtra%%;

  return($name);
}

#####

sub _make_xtra_attribute_name {
  my $name = shift @_;

  return("$key_xtra$name");
}

########################################

sub _numerically {
  return($a <=> $b);
}

##########

sub _framespan_sort {
  return($a->sort_cmp($b));
}

##########

sub _set_for_event_sort {
  return() if (exists $for_event_sort{'is_set'});
  my $inc = 1;
  foreach my $e (@ok_events) {
    foreach my $se (@ok_subevents) {
      my $fev = &get_printable_full_event($e, $se, 1);
      $for_event_sort{$fev} = $inc++;
    }
  }
  $for_event_sort{'is_set'}++;
}

#####

sub _event_sort {
  &_set_for_event_sort();

  my ($a_e, $a_se) = split_full_event($a, 1);
  my ($b_e, $b_se) = split_full_event($b, 1);

  my $fa = &get_printable_full_event($a_e, $a_se, 1);
  my $fb = &get_printable_full_event($b_e, $b_se, 1);

  return($for_event_sort{$fa} <=> $for_event_sort{$fb});
}

#####

sub sort_events {
  my (@events) = @_;

  return(sort _event_sort @events);
}

########################################

sub _wbi { # writeback indent
  my $indent = shift @_;
  my $spacer = "  ";
  my $txt = "";
  
  for (my $i = 0; $i < $indent; $i++) {
    $txt .= $spacer;
  }

  return($txt);
}     

#####

sub _wb_print { # writeback print
  my $indent = shift @_;
  my @content = @_;

  my $txt = "";

  $txt .= &_wbi($indent);
  $txt .= join("", @content);

  return($txt);
}

#####

sub _writeback_file {
  my $indent = shift @_;
  my %file_hash = @_;
  my $txt = "";

  $txt .= &_wb_print($indent++, "<file id=\"" . $file_hash{'file_id'} . "\" name=\"Information\">\n");

  foreach my $key (sort keys %hash_file_attributes_types) {
    $txt .= &_wb_print($indent, "<attribute name=\"$key\"");
    if (defined $file_hash{$key}) {
      $txt .= ">\n";
      $txt .= &_wb_print(++$indent, "<data:" . $hash_file_attributes_types{$key} . " value=\"" . $file_hash{$key} . "\"/>\n");
      $txt .= &_wb_print(--$indent, "</attribute>\n");
    } else {
      $txt .= "/>\n";
    }
  }

  $txt .= &_wb_print(--$indent, "</file>\n");

  return($txt);
}

#####

sub _writeback_object {
  my $indent = shift @_;
  my $event = shift @_;
  my $id = shift @_;
  my $fst = shift @_;
  my $rxtra_list = shift @_;
  my %object_hash = @_;

  my $txt = "";

  my @xtra_list = sort @$rxtra_list;

  my $stype = $object_hash{$key_subtype};
  my $ftype = &get_printable_full_event($event, $stype, $fst);

  $txt .= &_wb_print($indent++, "<object name=\"$ftype\" id=\"$id\" framespan=\"" . $object_hash{'framespan'} . "\">\n");

  # comment (optional)
  $txt .= &_wb_print($indent, "<!-- " . $object_hash{"comment"} . " -->\n")
    if (exists $object_hash{"comment"});

  # attributes
  foreach my $key (sort keys %hash_objects_attributes_types_expected) {
    $txt .= &_wb_print($indent, "<attribute name=\"$key\"");
    if (defined $object_hash{$key}) {
      $txt .= ">\n";

      $indent++;
      my @afs = ();
      foreach my $fs (keys %{$object_hash{$key}}) {
        my $fs_tmp = new ViperFramespan();
        die("[TrecVid08ViperFile] Internal Error: WEIRD: In \'_writeback_object\' (" . $fs_tmp->get_errormsg() .")")
          if (! $fs_tmp->set_value($fs));
        push @afs, $fs_tmp;
      }
      foreach my $fs_fs (sort _framespan_sort @afs) {
        my $fs = $fs_fs->get_value();
        $txt .= &_wb_print
          ($indent,
           "<data:" . $hash_objects_attributes_types{$key},
           ($hash_objects_attributes_types_dynamic{$key}) ? " framespan=\"$fs\"" : "",
           " ");

        my @subtxta = ();
        my @name_a = @{$hasharray_inline_attributes{$key}};
        my @value_a = @{$object_hash{$key}{$fs}};
        while (scalar @name_a > 0) {
          my $name= shift @name_a;
          my $value = shift @value_a;
          push @subtxta, "$name\=\"$value\"";
        }
        $txt .= join(" ", @subtxta);

        $txt .= "/>\n";
      }

      $txt .= &_wb_print(--$indent, "</attribute>\n");
    } else {
      $txt .= "/>\n";
    }
  }
  
  # xtra attributes
  if (scalar @xtra_list > 0) {
    foreach my $xtra (@xtra_list) {
      $txt .= &_wb_print($indent, "<attribute name=\"" . &_make_xtra_attribute_name($xtra) . "\"");
      if ( (exists $object_hash{$key_xtra})
           && (exists $object_hash{$key_xtra}{$xtra}) ) {
        $txt .= ">\n";
        $txt .= &_wb_print($indent + 1, "<data:svalue value=\"" . $object_hash{$key_xtra}{$xtra} . "\"/>\n");
        $txt .= &_wb_print($indent, "</attribute>\n");
      } else {
        $txt .= "/>\n";
      }
    }
  }

  # end object
  $txt .= &_wb_print(--$indent, "</object>\n");

  return($txt);
}

##########

sub _writeback2xml {
  my $self = shift @_;
  my $comment = shift @_;
  my $rlhash = shift @_;
  my $rxtra_list = shift @_;
  my @asked_events = @_;

  my $txt = "";
  my $indent = 0;

  my $fst = $self->check_force_subtype();
  return($txt) if ($self->error());

  my %lhash = %{$rlhash};

  # Common header
  $txt .= &_wb_print($indent, "<?xml version\=\"1.0\" encoding=\"UTF-8\"?>\n");
  $txt .= &_wb_print($indent, "<viper xmlns=\"http://lamp.cfar.umd.edu/viper\#\" xmlns:data=\"http://lamp.cfar.umd.edu/viperdata\#\">\n");
  $txt .= &_wb_print(++$indent, "<config>\n");
  $txt .= &_wb_print(++$indent, "<descriptor name=\"Information\" type=\"FILE\">\n");
  $txt .= &_wb_print(++$indent, "<attribute dynamic=\"false\" name=\"SOURCETYPE\" type=\"http://lamp.cfar.umd.edu/viperdata#lvalue\">\n");
  $txt .= &_wb_print(++$indent, "<data:lvalue-possibles>\n");
  $txt .= &_wb_print(++$indent, "<data:lvalue-enum value=\"SEQUENCE\"/>\n");
  $txt .= &_wb_print($indent, "<data:lvalue-enum value=\"FRAMES\"/>\n");
  $txt .= &_wb_print(--$indent, "</data:lvalue-possibles>\n");
  $txt .= &_wb_print(--$indent, "</attribute>\n");
  $txt .= &_wb_print($indent, "<attribute dynamic=\"false\" name=\"NUMFRAMES\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print($indent, "<attribute dynamic=\"false\" name=\"FRAMERATE\" type=\"http://lamp.cfar.umd.edu/viperdata#fvalue\"/>\n");
  $txt .= &_wb_print($indent, "<attribute dynamic=\"false\" name=\"H-FRAME-SIZE\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print($indent, "<attribute dynamic=\"false\" name=\"V-FRAME-SIZE\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print(--$indent, "</descriptor>\n");

  # Get the list of extra attributes
  my @xtra_list = @$rxtra_list;

  # Write all objects
  foreach my $ftype (&sort_events(@asked_events)) {
    $txt .= &_wb_print($indent++, "<descriptor name=\"$ftype\" type=\"OBJECT\">\n");

    foreach my $key (sort keys %hash_objects_attributes_types_expected) {
      $txt .= &_wb_print
	($indent,
	 "<attribute dynamic=\"",
	 ($hash_objects_attributes_types_dynamic{$key}) ? "true" : "false",
	 "\" name=\"$key\" type=\"http://lamp.cfar.umd.edu/viperdata#",
	 $hash_objects_attributes_types{$key}, 
	 "\"/>\n");
    }

    foreach my $key (sort @xtra_list) {
      $txt .= &_wb_print
	($indent,
	 "<attribute dynamic=\"false\" name=\"" . &_make_xtra_attribute_name($key) . "\" type=\"http://lamp.cfar.umd.edu/viperdata#svalue\"/>\n");
    }
 
    $txt .= &_wb_print(--$indent, "</descriptor>\n");
  }

  # End 'config', begin 'data'
  $txt .= &_wb_print(--$indent, "</config>\n");
  $txt .= &_wb_print($indent++, "<data>\n");

  if (scalar %lhash > 0) { # Are we just writting more than just a spec XML file ?
    $txt .= &_wb_print($indent++, "<sourcefile filename=\"" . $lhash{'file'}{'filename'} . "\">\n");

    # comment (optional)
    $txt .= &_wb_print($indent, "<!-- " . $comment . " -->\n")
      if (! MMisc::is_blank($comment));

    # file
    $txt .= &_writeback_file($indent, %{$lhash{'file'}});

    # Objects
    foreach my $ftype (sort _event_sort @asked_events) {
      my @ids = $self->get_event_ids($ftype);
      my ($ev, $sev) = &split_full_event($ftype, $fst); 
      foreach my $id (sort _numerically @ids) {
	$txt .= &_writeback_object($indent, $ev, $id, $fst, \@xtra_list, %{$lhash{$ev}{$id}});
      }
    }

    # End the sourcefile
    $txt .= &_wb_print(--$indent, "</sourcefile>\n");
  }

  # end data and viper
  $txt .= &_wb_print(--$indent, "</data>\n");
  $txt .= &_wb_print(--$indent, "</viper>\n");

  # Remember to enable this this warning for all but debug runs
  #warn_print("(WEIRD) End indentation is not equal to 0 ? (= $indent)\n") if ($indent != 0);

  return($txt);
}

########################################

sub _clone_fhash_selected_events {
  my $self = shift @_;
  my @asked_events = @_;

  my %in_hash = $self->_get_fhash();
  my %out_hash = ();

  %{$out_hash{"file"}} = &__clone(%{$in_hash{"file"}});

  foreach my $event (@asked_events) {
    my @ids = $self->get_event_ids($event);
    my ($etype, $stype) = split_full_event($event, 0);
    foreach my $id (@ids) {
      %{$out_hash{$etype}{$id}} = &__clone(%{$in_hash{$etype}{$id}});
    }
  }

  return(%out_hash);
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
