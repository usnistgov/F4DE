package TrecVid08ViperFile;

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

# For the '_display()' function
use Data::Dumper;

# File::Temp (usualy part of the Perl Core)
use File::Temp qw / tempfile /;

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

##### Memory representations

my %hash_file_attributes_types = 
  (
   "NUMFRAMES" => "dvalue",
   "SOURCETYPE" => undef,
   "H-FRAME-SIZE" => "dvalue",
   "V-FRAME-SIZE" => "dvalue",
   "FRAMERATE" => "fvalue",
  );

my @array_file_inline_attributes =
  ( "id", "name" ); # 'id' is to be first

my @list_objects_attributes = # Order is important
  ("DetectionScore", "DetectionDecision", "Point", "BoundingBox");

my @list_objects_attributes_types = # Order is important (has to match previous)
  ("fvalue", "bvalue", "point", "bbox");

my @list_objects_attributes_isd = # Order is important (has to match previous too)
  (0, 0, 1, 1);

my @not_gtf_required_objects_attributes =
  ($list_objects_attributes[0], $list_objects_attributes[1]);

my %hash_objects_attributes_types;

my %hash_objects_attributes_types_dynamic;

my %hasharray_inline_attributes;
@{$hasharray_inline_attributes{"bbox"}} = ("x", "y", "height", "width");
@{$hasharray_inline_attributes{"point"}} = ("x", "y");
@{$hasharray_inline_attributes{"fvalue"}} = ("value");
@{$hasharray_inline_attributes{"bvalue"}} = ("value");
@{$hasharray_inline_attributes{"dvalue"}} = ("value");

my @array_objects_inline_attributes = 
  ("name", "id", "framespan"); # order is important

my %not_gtf_required_dummy_values =
  (
   $not_gtf_required_objects_attributes[0] => 0,
   $not_gtf_required_objects_attributes[1] => 0,
  );

##########
# Default values to compare against (constant values)
my $default_error_value = "default_error_value";
my $framespan_max_default = "all";

########## Some rules that can be changed (here, specific for TrecVid08)
# Maximum number of pair per framespan found
# For Trecvid08, only one pair (ie one framespan range) is authorized per framespan (0 for unlimited)
my $max_pair_per_fs = 1; # positive number / 0 for unlimited
## Update (20080421): After talking with Jon, we decided that IDs do not have to start at 0 or be consecutive after all
# Check if IDs list have to start at 0
my $check_ids_start_at_zero = 0;
# Check that IDs are consecutive
my $check_ids_are_consecutive = 0;


########################################

## Constructor
sub new {
  my ($class) = shift @_;

  my $errormsg = (scalar @_ > 0) ? "TrecVid08ViperFile does not accept parameters" : "";

  ## Run the ViperFramespan test_unit just to be sure
  my $fs_tmp = new ViperFramespan();
  $errormsg .= $fs_tmp->get_errormsg() if (! $fs_tmp->unit_test());

  &_fill_required_hashes();

  my $self =
    {
     xmllint        => "",
     xsdpath        => "",
     gtf            => 0, # By default, files are not GTF
     fps            => -1, # Not needed to validate a file, but needed for observations creation
     file           => "",
     fhash          => undef,
     comment        => "", # Comment to be written to write (or to each 'Observation' when generated)
     validated      => 0, # To confirm file was validated
     fs_framespan_max => $fs_tmp,
     errormsg       => &_set_errormsg_txt("", $errormsg),
    };

  bless $self;
  return($self);
}

#####

sub _fill_required_hashes {
  for (my $i = 0; $i < scalar @list_objects_attributes; $i++) {
    my $key  = $list_objects_attributes[$i];
    my $keyt = $list_objects_attributes_types[$i];

    $hash_objects_attributes_types{$key} = 
      $keyt;

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

####################

sub _set_errormsg_txt {
  my ($oh, $add) = @_;

  my $txt = "$oh$add";
#  print "VF * [$oh | $add]\n";

  $txt =~ s%\[TrecVid08ViperFile\]\s+%%g;

  return("") if (&_is_blank($txt));

  $txt = "[TrecVid08ViperFile] $txt";
#  print "VF -> [$txt]\n";
  return($txt);
}

#####

sub _set_errormsg {
  my ($self, $txt) = @_;

  $self->{errormsg} = &_set_errormsg_txt($self->{errormsg}, $txt);
}

#####

sub get_errormsg {
  my ($self) = @_;

  return($self->{errormsg});
}

#####

sub error {
  my ($self) = @_;

  return(1) if (! &_is_blank($self->get_errormsg()));

  return(0);
}

########################################

sub get_required_xsd_files_list {
  my ($self) = @_;

  return(-1) if ($self->error());

  return(@xsdfilesl);
}

#####

sub validate_events_list {
  my ($self, @events) = @_;

  @events = split(m%\,%, join(",", @events));
  @events = &_make_array_of_unique_values(@events);
  my ($in, $out) = &_compare_arrays(\@events, @ok_events);
  if (scalar @$out > 0) {
    $self->_set_errormsg("Found some unknown event type: " . join(" ", @$out));
    return();
  }

  return(@events);
}

#####

sub get_full_events_list {
  my ($self) = @_;

  return(-1) if ($self->error());

  return(@ok_events);
}

#####

sub _get_hasharray_inline_attributes {
  my ($self) = @_;

  return(-1) if ($self->error());

  return(%hasharray_inline_attributes);
}

#####

sub _get_hash_objects_attributes_types_dynamic {
  my ($self) = @_;

  return(-1) if ($self->error());

  return(%hash_objects_attributes_types_dynamic);
}

########## 'xmllint'

sub set_xmllint {
  my ($self, $xmllint) = @_;

  return(0) if ($self->error());

  my $error = "";
  # Confirm xmllint is present and at least 2.6.30
  ($xmllint, $error) = &_check_xmllint($xmllint);
  if (! &_is_blank($error)) {
    $self->_set_errormsg($error);
    return(0);
  }
  
  $self->{xmllint} = $xmllint;
  return(1);
}

#####

sub _is_xmllint_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! &_is_blank($self->{xmllint}));

  return(0);
}

#####

sub get_xmllint {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_xmllint_set()) {
    $self->_set_errormsg("\'xmllint\' is not set");
    return(0);
  }

  return($self->{xmllint});
}

########## 'xsdpath'

sub set_xsdpath {
  my ($self, $xsdpath) = @_;

  return(0) if ($self->error());

  my $error = "";
  # Confirm that the required xsdfiles are available
  ($xsdpath, $error) = &_check_xsdfiles($xsdpath, @xsdfilesl);
  if (! &_is_blank($error)) {
    $self->_set_errormsg($error);
    return(0);
  }

  $self->{xsdpath} = $xsdpath;
  return(1);
}

#####

sub _is_xsdpath_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! &_is_blank($self->{xsdpath}));

  return(0);
}

#####

sub get_xsdpath {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_xsdpath_set()) {
    $self->_set_errormsg("\'xsdpath\' is not set");
    return(0);
  }

  return($self->{xsdpath});
}

########## 'gtf'

sub set_as_gtf {
  my ($self) = @_;

  return(0) if ($self->error());

  $self->{gtf} = 1;
  return(1);
}

#####

sub check_if_gtf {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{gtf});
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
  $fps = $fs_tmp->get_fps($fps);
  if ($fs_tmp->error()) {
    $self->_set_errormsg("While obtaining back the file fps ($fps) error (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  $self->{fps} = $fps;
  return(1);
}

#####

sub _is_fps_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(0) if ($self->{fps} == -1);

  return(1);
}

#####

sub get_fps {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_fps_set()) {
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

  return(-1) if ($self->error());

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

  return(0) if (&_is_blank($self->{file}));

  return(1);
}

#####

sub get_file {
  my ($self) = @_;

  return(-1) if ($self->error());

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

sub _addto_comment {
  my ($self, $comment) = @_;

  return(0) if ($self->error());

  $self->{comment} .= "\n" if ($self->_is_comment_set());

  $self->{comment} .= $comment;
  return(1);
}

#####

sub _is_comment_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! &_is_blank($self->{comment}));

  return(0);
}

#####

sub _get_comment {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_comment_set()) {
    $self->_set_errormsg("\'comment\' not set");
    return(0);
  }

  return($self->{comment});
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

  my $xmllint = $self->get_xmllint();
  my $xsdpath = $self->get_xsdpath();
  # Load the XML through xmllint
  my ($res, $bigstring) = &_run_xmllint($xmllint, $xsdpath, $ifile);
  if (! &_is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }
  # No data from xmllint ?
  if (&_is_blank($bigstring)) {
    $self->_set_errormsg("WEIRD: The XML data returned by xmllint seems empty");
    return(0);
  }

  # Initial Cleanups & Check
  ($res, $bigstring) = &_data_cleanup($bigstring);
  if (! &_is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }

  # Process the data part
  my %fdata;
  my $isgtf = $self->check_if_gtf();
  ($res, %fdata) = $self->_data_processor($bigstring, $isgtf);
  if (! &_is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }

  $self->_set_fhash(%fdata);
  $self->{validated} = 1;

  return(1);
}

####################

sub reformat_xml {
  my ($self) = shift @_;
  my @limitto_events = @_;

  return(-1) if ($self->error());

  if (scalar @limitto_events == 0) {
    @limitto_events = @ok_events;
  } else {
    @limitto_events = $self->validate_events_list(@limitto_events);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only rewrite the XML for a validated file");
    return(0);
  }

  my $comment = "";
  $comment = $self->_get_comment() if ($self->_is_comment_set());

  my %tmp = $self->_get_fhash();

  return(&_writeback2xml($comment, \%tmp, @limitto_events));
}

##########

sub get_base_xml {
  my ($self) = shift @_;
  my @limitto_events = @_;

  return(-1) if ($self->error());

  if (scalar @limitto_events == 0) {
    @limitto_events = @ok_events;
  } else {
    @limitto_events = $self->validate_events_list(@limitto_events);
    return(0) if ($self->error());
  }

  my %tmp = ();
  return(&_writeback2xml("", \%tmp, @limitto_events));
}

####################

sub _display_all {
  my ($self) = shift @_;

  return(-1) if ($self->error());

  return(Dumper(\$self));
}

#####

sub _display {
  my ($self) = shift @_;
  my @limitto_events = @_;

  return(-1) if ($self->error());

  if (scalar @limitto_events == 0) {
    @limitto_events = @ok_events;
  } else {
    @limitto_events = $self->validate_events_list(@limitto_events);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'_display\' for a validated file");
    return(0);
  }

  my %in = $self->_get_fhash();
  my %out = &_clone_fhash_selected_events(\%in, @limitto_events);

  return(Dumper(\%out));
}

########################################

sub _get_short_sf_file {
  my ($txt) = shift @_;

  # Remove all 'file:' or related
  $txt =~ s%^.+\:%%g;

  # Remove all paths
  $txt =~ s%^.+\/%%g;

  # lowercase
#  $txt = lc($txt);

  return($txt);
}

#####

sub get_sourcefile_filename {
  my ($self) = shift @_;

  return(-1) if ($self->error());

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

  if (! $self->_is_fps_set()) {
    $self->_set_errormsg("\'fps\' need to be set to create any observation");
    return(0);
  }

  my $xmlfile = $self->get_file();
  my $filename = $self->get_sourcefile_filename();
  my $fps = $self->get_fps();
  my $isgtf = $self->check_if_gtf();
  my $file_fs = $self->_get_fhash_file_numframes();
  
  return(0) if ($self->error());

  return($xmlfile, $filename, $fps, $isgtf, $file_fs);
}

#####

sub get_dummy_observation {
  my ($self) = @_;
  # This function is really only used by the merger in case there are no observations in a file

  my ($xmlfile, $filename, $fps, $isgtf, $file_fs) = $self->_get_event_observation_common();
  return(0) if ($self->error());

  my $id = 0;
  my %in = $self->_get_fhash();
  my %file_info = %{$in{"file"}};

  my $obs = new TrecVid08Observation();
  my $event = $obs->get_key_dummy_eventtype();
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
      $obs->set_selected($key, $not_gtf_required_dummy_values{$key});
      if ($obs->error()) {
	$self->_set_errormsg("Problem while using \'set_selected\' ($key) on observation (" . $obs->get_errormsg() .")");
	return(0);
      }
    }
  }

  if (! $obs->validate()) {
    $self->_set_errormsg("Problem validating observation (" . $obs->get_errormsg() .")");
    return(0);
  }

  return($obs);
}

#####

sub get_event_observations {
  my ($self, $event) = @_;

  return(0) if ($self->error());

  if (! grep(m%^$event$%, @ok_events)) {
    $self->_set_errormsg("Requested event ($event) is not a recognized event");
    return(0);
  }

  my ($xmlfile, $filename, $fps, $isgtf, $file_fs) = $self->_get_event_observation_common();
  return(0) if ($self->error());

  my %in = $self->_get_fhash();
  my %out = &_clone_fhash_selected_events(\%in, $event);

  my %file_info = %{$out{"file"}};

  my @res = ();
  return(@res) if (! defined $out{$event});
  
  my %all_obs = %{$out{$event}};
  foreach my $id (sort _numerically keys %all_obs) {
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
    if ($self->_is_comment_set()) {
      my $comment = $self->_get_comment();
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

    my $key = "framespan";
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

    ## This is past the validation step, so we know that types are ok, so simply process the dynamic vs non dynamic elements
    my @all_obj_attrs = keys %hash_objects_attributes_types_dynamic;
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
  my ($self) = @_;

   return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only create observations for a validated file");
    return(0);
  }

  my @res;
  foreach my $event (@ok_events) {
    my @tmp = $self->get_event_observations($event);
    return(0) if ($self->error());
    push @res, @tmp;
  }

  return(@res);
}

####################

sub remove_all_events {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only \"remove all events\" for a validated file");
    return(0);
  }

  my %in = $self->_get_fhash();
  my %out = &_clone_fhash_selected_events(\%in);

  $self->_set_fhash(%out);
  return(1);
}

##########

sub _clone_core {
  my ($self, $keep_events) = @_;

  return(undef) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only \'clone\' a validated file");
    return(undef);
  }
  
  my $clone = new TrecVid08ViperFile();
  
  $clone->set_xmllint($self->get_xmllint());
  $clone->set_xsdpath($self->get_xsdpath());
  $clone->set_as_gtf() if ($self->check_if_gtf());
  $clone->set_fps($self->get_fps()) if ($self->_is_fps_set());
  $clone->set_file($self->get_file());
  my %in = $self->_get_fhash();
  my %out;
  if ($keep_events) {
    %out = &_clone_fhash_selected_events(\%in, @ok_events);
  } else {
    %out = &_clone_fhash_selected_events(\%in);
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

  return($self->_clone_core(1));
}

#####

sub clone_with_no_events {
 my ($self) = @_;

  return($self->_clone_core(0));
}

##########

sub _get_fhash_file_numframes {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only get \'numframes\' for a validated file");
    return(0);
  }

  my %tmp = $self->_get_fhash();

  if (! exists $tmp{"file"}{"NUMFRAMES"}) {
    $self->_set_errormsg("WEIRD: Can not access file's \'numframes\'");
    return(0);
  }

  return($tmp{"file"}{"NUMFRAMES"});
}

####

sub _set_fhash_file_numframes {
  my ($self, $numframes, $ignoresmallervalues, $commentadd) = @_;

  if ($numframes <= 0) {
    $self->_set_errormsg("Can not set file's \'numframes\' to a negative or zero value");
    return(0);
  }

  my $cnf = $self->_get_fhash_file_numframes();
  return(0) if ($self->error());

  if ($numframes <= $cnf) {
    return(1) if ($ignoresmallervalues);

    $self->_set_errormsg("Can not reduce the file\'s \'numframes\' value");
    return(0);
  }

  my %tmp = $self->_get_fhash();

  if (! exists $tmp{"file"}{"NUMFRAMES"}) {
    $self->_set_errormsg("WEIRD: Can not access file's \'numframes\'");
    return(0);
  }

  $tmp{"file"}{"NUMFRAMES"} = $numframes;

  $self->_set_fhash(%tmp);
  $self->_addto_comment("NUMFRAMES extended from $cnf to $numframes" . ((! &_is_blank($commentadd)) ? " ($commentadd)" : ""));
  return(0) if ($self->error());

  return(1);
}

#####

sub extend_numframes {
  my ($self, $numframes, $commentadd) = @_;

  return($self->_set_fhash_file_numframes($numframes, 1, $commentadd));
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
    $self->set_errormsg("Eventtype ($event) is not a recognized one");
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

  my @out;
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
  return(-1) if ($self->error());

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
  my $key = "NUMFRAMES";
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
  my ($self, $obs) = @_;

  $self->_add_obs_core($obs);
  return(-1) if ($self->error());

  # Get observation's eventtype
  my $event = $obs->get_eventtype();

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

  # Get the next available event id
  my $id = $self->get_first_available_event_id($event);
  return(0) if ($self->error());

  ##### From now on we make changes to the structure

  return(0) if (! $self->extend_numframes_from_observation($obs));

  my %tmp = $self->_get_fhash();
  my %sp_out; # will be added to $fhash{event}{id}

  # Get the global framespan
  my $key = "framespan";
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
  foreach my $attr (keys %hash_objects_attributes_types) {
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

  ## Finished setting %sp_out, commit it to the local copy of fhash before recreating fhash
  %{$tmp{$event}{$id}} = %sp_out;

  $self->_set_fhash(%tmp);
  return(0) if ($self->error());

  return(1);
}

##############################

sub change_sourcefile_filename {
  my ($self, $nfname) = @_;

  return(-1) if ($self->error());

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

  $self->_addto_comment("\'sourcefile\' changed from \'$oname\' (short: \'$soname\') to \'$nfname\'");

  return(-1) if ($self->error());

  return(1);
}


############################################################
# Internals
########################################

sub _run_xmllint {
  my $xmllint = shift @_;
  my $xsdpath = shift @_;
  my $file = shift @_;

  $file =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  my ($retcode, $stdout, $stderr) =
    &_do_system_call($xmllint, "--path", "\"$xsdpath\"", "--schema", $xsdpath . "/" . $xsdfilesl[0], $file);

  return("Problem validating file with \'xmllint\' ($stderr), aborting", "")
    if ($retcode != 0);

  return("", $stdout);
}

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
    if (! &_remove_xml_tags("viper", \$bigstring));

  # Remove <config> section
  return("Could not find a proper \'config\' section, aborting", $bigstring)
    if (! &_remove_xml_section("config", \$bigstring));

  # At this point, all we ought to have left is the '<data>' content
  return("After initial cleanup, we found more than just viper \'data\', aborting", $bigstring)
    if (! ( ($bigstring =~ m%^\s*\<data>%is) && ($bigstring =~ m%\<\/data\>\s*$%is) ) );

  return("", $bigstring);
}

####################

sub _remove_xml_tags {
  my $name = shift @_;
  my $rstr = shift @_;

  if ($$rstr =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    return(1 == 1);
  } elsif ($$rstr =~ s%\s*\<${name}(\>|\s+[^\>]+\>)(.+?)\<\/${name}\>%$2%s) {
    return(1 == 1);
  }

  return(1 == 0);
}

#####

sub _remove_xml_section {
  my $name = shift @_;
  my $rstr = shift @_;

  if ($$rstr =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    return(1 == 1);
  } elsif ($$rstr =~ s%\s*\<${name}(\>|\s+[^\>]+\>).+?\<\/${name}\>%%s) {
    return(1 == 1);
  }

  return(1 == 0);
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
  my $name = &_get_next_xml_name($string);
  return("Problem obtaining a valid XML name, aborting", $string)
    if ($name eq $default_error_value);
  return("\'data\' section not present (instead: $name), aborting", $string)
    if ($name !~ m%^data$%i);
  return("Problem cleaning \'data\' tags", $string)
    if (! &_remove_xml_tags($name, \$string));

  #####
  # Now, the next --and only-- section is to be a 'sourcefile'
  my $name = &_get_next_xml_name($string);
  return("Problem obtaining a valid XML name, aborting", $string)
    if ($name eq $default_error_value);
  return("\'sourcefile\' section not present (instead: $name), aborting", $string)
    if ($name !~ m%^sourcefile$%i);
  my $tmp = $string;
  my $section = &_get_named_xml_section($name, \$string);
  return("Problem obtaining the \'sourcefile\' XML section, aborting", $tmp)
    if ($name eq $default_error_value);
  # And nothing else should be left in the file
  return("Data left in addition to the \'sourcefile\' XML section, aborting", $string)
    if (! &_is_blank($string));
  # Parse it
  ($res, %fdata) = $self->_parse_sourcefile_section($name, $section, $isgtf);
  if (! &_is_blank($res)){
    my @resA = split(/\n/, $res);
    my $str = "";
    for (my $_i=0; $_i<@resA; $_i++){  
        $str .= "Problem while processing the \'sourcefile\' XML section (" . 
                "Error ".($_i+1)." of ".scalar(@resA).": $resA[$_i])\n";
    }
    return($str, ());
  }
  return($res, %fdata);
}

#################### 

sub _get_next_xml_name {
  my $str = shift @_;
  my $txt = $default_error_value;

  if ($str =~ m%^\s*\<\s*([^\>]+)%s) {
    my $tmp = $1;
    my @a = split(m%\s+%, $tmp);
    $txt = $a[0];
  }

  return($txt);
}

##########

sub _get_named_xml_section {
  my $name = shift @_;
  my $rstr = shift @_;

  my $txt = $default_error_value;
  
  if ($$rstr =~ s%\s*(\<${name}(\/\>|\s+[^\>]+\/\>))%%s) {
    $txt = $1;
  } elsif ($$rstr =~ s%\s*(\<${name}(\>|\s+[^\>]+\>).+?\<\/${name}\>)%%s) {
    $txt = $1;
  }

  return($txt);
}

##########

sub _get_next_xml_section {
  my $rstr = shift @_;
  
  my $name = $default_error_value;
  my $section = $default_error_value;

  $name = &_get_next_xml_name($$rstr);
  if ($name eq $default_error_value) {
    return($name,  "");
  }

  $section = &_get_named_xml_section($name, $rstr);

  return($name, $section);
}

##########

sub _split_xml_tag {
  my $tag = shift @_;

  my @split = split(m%\=%, $tag);
  return("", "")
    if (scalar @split != 2);

  my ($name, $value) = @split;
  $value =~ s%^\s*\"%%;
  $value =~ s%\"\s*$%%;

  return($name, $value);
}

#####

sub _split_xml_tag_list_to_hash {
  my @list = @_;

  my %hash;
  foreach my $tag (@list) {
    my ($name, $value) = &_split_xml_tag($tag);
    return("Problem splitting inlined attribute ($tag)", ())
      if (&_is_blank($name));

    return("Inlined attribute ($name) appears to be present multiple times")
      if (exists $hash{$name});
    
    $hash{$name} = $value;
  }

  return("", %hash);
}

#####

sub _split_line_into_tags {
  my $line = shift @_;
  my @all;

  while ($line =~ s%([^\s]+?)\s*(\=)\s*(\"[^\"]+?\")%%) {
    push @all, "$1$2$3";
  }
  return("Leftover text after tag extraction ($line)", ())
    if (! &_is_blank($line));
  
  return("", @all);
}

#####

sub _get_inline_xml_attributes {
  my $name = shift @_;
  my $str = shift @_;

  my $txt = "";
  if ($str =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    $txt = $1;
  } elsif ($str =~ s%\s*\<${name}(\>|\s+[^\>]+\>)%%s) {
    $txt = $1;
  }
  $txt =~ s%^\s+%%;
  $txt =~ s%\/?\>$%%;

  my ($err, @all) = &_split_line_into_tags($txt);
  return($err, ()) if (! &_is_blank($err));
  return("", ()) if (scalar @all == 0); # None found

  my ($res, %hash) = &_split_xml_tag_list_to_hash(@all);
  return($res, ()) if (! &_is_blank($res));

  return("", %hash);
}
  
##########

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

  my %res;
  
  #####
  # First, get the inline attributes from the 'sourcefile' inline attribute itself
  my ($text, %iattr) = &_get_inline_xml_attributes($name, $str);
  return($text, ()) if (! &_is_blank($text));

  # We should only have a \'filename\'
  my @keys = keys %iattr;
  return("Found multiple keys in the \'sourcefile\' inlined attributes", ())
    if (scalar @keys > 1);
  ($text, my $found) = &_find_hash_key("filename", %iattr);
  return($text, ()) if (! &_is_blank($text));

  my $filename = $iattr{$found};

  #####
  # We can now remove the \'sourcefile\' header and trailer tags
  return("WEIRD: could not remove the \'$name\' header and trailer tags", ())
    if (! &_remove_xml_tags($name, \$str));

  #####
  # Get the 'file' section
  my $sec = &_get_named_xml_section("file", \$str);
  return("No \'file\' section found in the \'sourcefile\'", ())
    if ($sec eq $default_error_value);
  ($text, my %fattr) = $self->_parse_file_section($sec);
  return($text, ()) if (! &_is_blank($text));
  
  # Complete %fattr and start filling %res
  $fattr{"filename"} = $filename;
  %{$res{"file"}} = %fattr;

  ##########
  # Process all that is left in the string (should only be objects)
  $str = &_clean_begend_spaces($str);
  
  my @error_list = ();
  while (! &_is_blank($str)) {
    my $sec = &_get_named_xml_section("object", \$str);
    if ($sec eq $default_error_value) {
       push (@error_list, ("No \'object\' section left in the \'sourcefile\'"));
    } else {
        ($text, my $object_type, my $object_id, my $object_framespan, my %oattr)
          = $self->_parse_object_section($sec, $isgtf);
        if (! &_is_blank($text)){
            push (@error_list, $text);
        } else {

            ##### Sanity
    
            # Check that the object name is an authorized event name
            if (! grep(/^$object_type$/, @ok_events)){
                push (@error_list, "Found unknown event type ($object_type) in \'object\'");
            } else {
               # Check that the object type/id key does not already exist
               if (exists $res{$object_type}{$object_id}){
                  push (@error_list, "Only one unique (event type, id) key authorized ($object_type, $object_id)");
               } else {
                  ##### Add to %res
                  %{$res{$object_type}{$object_id}} = %oattr;
                  $res{$object_type}{$object_id}{"framespan"} = $object_framespan;
               }
            }
        }
    }        

    # Prepare string for the next run
    $str = &_clean_begend_spaces($str);
  }
  if (@error_list > 0){
     return(join("\n",@error_list), ());
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

sub _make_array_of_unique_values {
  my @a = @_;

  my %tmp;
  foreach my $key (@a) {
    $tmp{$key}++;
  }

  return(keys %tmp);
}

#####

sub _compare_arrays {
  my $rexp = shift @_;
  my @list = @_;

  my @in;
  my @out;
  foreach my $elt (@$rexp) {
    if (grep(m%^$elt$%, @list)) {
      push @in, $elt;
    } else {
      push @out, $elt;
    }
  }

  return(\@in, \@out);
}

#####

sub _parse_file_section {
  my ($self) = shift @_;
  my $str = shift @_;

  my $wtag = "file";
  my %file_hash;

  my ($text, %attr) = &_get_inline_xml_attributes($wtag, $str);
  return($text, ()) if (! &_is_blank($text));

  my $framespan_max = $framespan_max_default;

  my @expected = @array_file_inline_attributes;
  my ($in, $out) = &_compare_arrays(\@expected, keys %attr);
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
    if (! &_remove_xml_tags($wtag, \$str));

  #####
  # Process each "attribute" left now
  ($text, %attr) = $self->_parse_attributes(\$str);
  return("While parsing the \'$wtag\' \'attribute\'s : $text", ())
    if (! &_is_blank($text));

  # Confirm they are the ones we want
  my %expected_hash = %hash_file_attributes_types;
  @expected = keys %expected_hash;
  ($in, $out) = &_compare_arrays(\@expected, keys %attr);
  return("Could not find all the expected \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'$wtag\' attributes", ())
    if (scalar @$out > 0);

  # Check they are of valid type & reformat them for the output file hash
  foreach my $key (@expected) {
    $file_hash{$key} = undef;
    my $val = $expected_hash{$key};
    next if (! defined $val);
    my @comp = keys %{$attr{$key}};
    next if (scalar @comp == 0);
    my @expected2;
    push @expected2, $val;
    ($in, $out) = &_compare_arrays(\@expected2, @comp);
   return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type", ())
      if (scalar @$out > 0);

    return("WEIRD: Could not find the value associated with the \'$key\' \'$wtag\' attribute", ())
      if (! exists $attr{$key}{$val}{$framespan_max});
    $file_hash{$key} = ${$attr{$key}{$val}{$framespan_max}}[0];
  }

  # Set the "framespan_max" from the NUMFRAMES entry
  my $key = "NUMFRAMES";
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

  my $object_name;
  my $object_id;
  my $object_framespan;
  my %object_hash;

  my ($text, %attr) = &_get_inline_xml_attributes($wtag, $str);
  return($text, ()) if (! &_is_blank($text));

  my $framespan_max = $self->_get_framespan_max_value();
  return("Problem obtaining the \'framespan_max\' value", ()) if ($self->error());
  my $fs_framespan_max = $self->_get_framespan_max_object();
  return("Problem obtaining the \'framespan_max\' object", ()) if ($self->error());

  my @expected = @array_objects_inline_attributes;
  my ($in, $out) = &_compare_arrays(\@expected, keys %attr);
  return("Could not find all the expected inline \'file\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected inline \'file\' attributes", ())
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
    if (! &_remove_xml_tags($wtag, \$str));

  #####
  # Process each "attribute" left now
  ($text, %attr) = $self->_parse_attributes(\$str, $object_framespan);
  return("While parsing the \'$wtag\' \'attribute\'s : $text", ())
    if (! &_is_blank($text));
  
  # Confirm they are the ones we want
  my %expected_hash = %hash_objects_attributes_types;
  @expected = keys %expected_hash;
  ($in, $out) = &_compare_arrays(\@expected, keys %attr);
  return("Could not find all the expected \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'$wtag\' attributes", ())
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
    my @expected2;
    push @expected2, $val;
    ($in, $out) = &_compare_arrays(\@expected2, @comp);
   return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type", ())
      if (scalar @$out > 0);

    foreach my $fs (keys %{$attr{$key}{$val}}) {
      @{$object_hash{$key}{$fs}} = @{$attr{$key}{$val}{$fs}};
    }
  }

  return("", $object_name, $object_id, $object_framespan, %object_hash);
}

####################

sub _data_process_array_core {
  my $name = shift @_;
  my $rattr = shift @_;
  my @expected = @_;

  my ($in, $out) = &_compare_arrays(\@expected, keys %$rattr);
  return("Could not find all the expected \'data\:$name\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'data\:$name\' attributes", ())
    if (scalar @$out > 0);

  my @res;
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

  my %attr;
  my @afspan;

  my $fs_fspan = new ViperFramespan();
  if (! $allow_nofspan) {
    return("ViperFramespan ($fspan) error (" . $fs_fspan->get_errormsg() . ")", ())
      if (! $fs_fspan->set_value($fspan));
  }

  while (! &_is_blank($str)) {
    my $name = &_get_next_xml_name($str);
    return("Problem obtaining a valid XML name, aborting", $str)
      if ($name eq $default_error_value);
    return("\'data\' extraction process does not seem to have found one, aborting", $str)
      if ($name !~ m%^data\:%i);
    my $section = &_get_named_xml_section($name, \$str);
    return("Problem obtaining the \'data\:\' XML section, aborting", "")
      if ($name eq $default_error_value);

    # All within a data: entry is inlined, so get the inlined content
    my ($text, %iattr) = &_get_inline_xml_attributes($name, $section);
    return($text, ()) if (! &_is_blank($text));

    # From here we work per 'data:' type
    $name =~ s%^data\:%%;

    # Check the framespan (if any)
    my $lfspan;
    my $key = "framespan";
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
    return($text, ()) if (! &_is_blank($text));
  }

  return("", %attr);
}

#####

sub _parse_attributes {
  my ($self) = shift @_;
  my $rstr = shift @_;
  my $fspan = shift @_;
  my %attrs;

  my $allow_nofspan = 0;
  if (&_is_blank($fspan)) {
    if (! $self->_is_framespan_max_set()) {
      $fspan = $framespan_max_default;
    } else {
      return("WEIRD: At this point the framespan range should be defined", ());
    }
    $allow_nofspan = 1;
  }
  
  # We process all the "attributes"
  while (! &_is_blank($$rstr)) {
    my $sec = &_get_named_xml_section("attribute", $rstr);
    return("Could not find an \'attribute\'", ()) if ($sec eq $default_error_value);

    # Get its name
    my ($text, %iattr) = &_get_inline_xml_attributes("attribute", $sec);
    return($text, ()) if (! &_is_blank($text));

    return("Found more than one inline attribute for \'attribute\'", ())
      if (scalar %iattr != 1);
    return("Could not find the \'name\' of the \'attribute\'", ())
      if (! exists $iattr{"name"});

    my $name = $iattr{"name"};

    # Now get its content
    return("WEIRD: could not remove the \'attribute\' header and trailer tags", ())
      if (! &_remove_xml_tags("attribute", \$sec));

    # Process the content
    $sec = &_clean_begend_spaces($sec);
    
    if (&_is_blank($sec)) {
      $attrs{$name} = undef;
    } else {
      ($text, my %tmp) = $self->_extract_data($sec, $fspan, $allow_nofspan, $name);
      return("Error while processing the \'data\:\' content of the \'$name\' \'attribute\' ($text)", ())
	if (! &_is_blank($text));
      %{$attrs{$name}} = %tmp;
    }
    
  } # while

  return("", %attrs);
}

########################################
# xmllint check

sub _get_tmpfilename {
  my (undef, $name) = tempfile( OPEN => 0 );

  return($name);
}

#####

sub _slurp_file {
  my $fname = shift @_;

  open FILE, "<$fname"
    or die("[TrecVid08ViperFile] Internal error: Can not open file to slurp ($fname): $!\n");
  my @all = <FILE>;
  close FILE;

  my $tmp = join(" ", @all);
  chomp $tmp;

  return($tmp);
}

#####

sub _do_system_call {
  my @args = @_;
  
  my $cmdline = join(" ", @args);

  my $retcode = -1;
  # Get temporary filenames (created by the command line call)
  my $stdoutfile = &_get_tmpfilename();
  my $stderrfile = &_get_tmpfilename();

  open (CMD, "$cmdline 1> $stdoutfile 2> $stderrfile |");
  close CMD;
  $retcode = $?;

  # Get the content of those temporary files
  my $stdout = &_slurp_file($stdoutfile);
  my $stderr = &_slurp_file($stderrfile);

  # Erase the temporary files
  unlink($stdoutfile);
  unlink($stderrfile);

  return($retcode, $stdout, $stderr);
}

#####

sub _check_xmllint {
  my $xmllint = shift @_;

  # If none provided, check if it is available in the path
  if ($xmllint eq "") {
    my ($retcode, $stdout, $stderr) = &_do_system_call('which', 'xmllint');
    return("", "Could not find a valid \'xmllint\' command in the PATH, aborting\n")
      if ($retcode != 0);
    $xmllint = $stdout;
  }

  $xmllint =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  # Check that the file for xmllint exists and is an executable file
  return("", "\'xmllint\' ($xmllint) does not exist, aborting\n")
    if (! -e $xmllint);

  return("", "\'xmllint\' ($xmllint) is not a file, aborting\n")
    if (! -f $xmllint);

  return("", "\'xmllint\' ($xmllint) is not executable, aborting\n")
    if (! -x $xmllint);

  # Now check that it actually is xmllint
  my ($retcode, $stdout, $stderr) = &_do_system_call($xmllint, '--version');
  return("", "\'xmllint\' ($xmllint) does not seem to be a valid \'xmllint\' command, aborting\n")
    if ($retcode != 0);
  
  if ($stderr =~ m%using\s+libxml\s+version\s+(\d+)%) {
    # xmllint print the command name followed by the version number
    my $version = $1;
    return("", "\'xmllint\' ($xmllint) version too old: requires at least 2.6.30 (ie 20630, installed $version), aborting\n")
      if ($version <= 20630);
  } else {
    return("", "Could not confirm that \'xmllint\' is valid, aborting\n");
  }

  return($xmllint, "");
}

#####

sub _check_xsdfiles {
  my $xsdpath = shift @_;
  my @xsdfiles = @_;

  $xsdpath =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;
  $xsdpath =~ s%(.)\/$%$1%;

  foreach my $fname (@xsdfiles) {
    my $file = "$xsdpath/$fname";
    return("", "Could not find required XSD file ($fname) at selected path ($xsdpath), aborting\n")
      if (! -e $file);
  }

  return($xsdpath, "");
}


########################################

sub _clean_begend_spaces {
  my $txt = shift @_;

  $txt =~ s%^\s+%%s;
  $txt =~ s%\s+$%%s;

  return($txt);
}

####################

sub _numerically {
  return($a <=> $b);
}

##########

sub _framespan_sort {
  return($a->sort_cmp($b));
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
  my %object_hash = @_;

  my $txt = "";

  $txt .= &_wb_print($indent++, "<object name=\"$event\" id=\"$id\" framespan=\"" . $object_hash{'framespan'} . "\">\n");

  # comment (optional)
  $txt .= &_wb_print($indent, "<!-- " . $object_hash{"comment"} . " -->\n")
    if (exists $object_hash{"comment"});

  # attributes
  foreach my $key (sort keys %hash_objects_attributes_types) {
    $txt .= &_wb_print($indent, "<attribute name=\"$key\"");
    if (defined $object_hash{$key}) {
      $txt .= ">\n";

      $indent++;
      my @afs;
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

	my @subtxta;
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
  

  $txt .= &_wb_print(--$indent, "</object>\n");

  return($txt);
}

##########

sub _writeback2xml {
  my $comment = shift @_;
  my $rlhash = shift @_;
  my @asked_events = @_;

  my $txt = "";
  my $indent = 0;

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

  # Write all objects
  foreach my $object (@asked_events) {
    $txt .= &_wb_print($indent++, "<descriptor name=\"$object\" type=\"OBJECT\">\n");
    foreach my $key (sort keys %hash_objects_attributes_types) {
      $txt .= &_wb_print
	($indent,
	 "<attribute dynamic=\"",
	 ($hash_objects_attributes_types_dynamic{$key}) ? "true" : "false",
	 "\" name=\"$key\" type=\"http://lamp.cfar.umd.edu/viperdata#",
	 $hash_objects_attributes_types{$key}, 
	 "\"/>\n");
    }
    $txt .= &_wb_print(--$indent, "</descriptor>\n");
  }

  # End 'config', begin 'data'
  $txt .= &_wb_print(--$indent, "</config>\n");
  $txt .= &_wb_print($indent++, "<data>\n");

  if (scalar %lhash > 0) { # Are we just writting a spec XML file ?
    $txt .= &_wb_print($indent++, "<sourcefile filename=\"" . $lhash{'file'}{'filename'} . "\">\n");

    # comment (optional)
    $txt .= &_wb_print($indent, "<!-- " . $comment . " -->\n")
      if (! &_is_blank($comment));

    # file
    $txt .= &_writeback_file($indent, %{$lhash{'file'}});

    # Objects
    foreach my $object (@asked_events) {
      if (exists $lhash{$object}) {
	my @ids = keys %{$lhash{$object}};
	foreach my $id (sort _numerically @ids) {
	  $txt .= &_writeback_object($indent, $object, $id, %{$lhash{$object}{$id}});
	}
      }
    }

    # End the sourcefile
    $txt .= &_wb_print(--$indent, "</sourcefile>\n");
  }

  # end data and viper
  $txt .= &_wb_print(--$indent, "</data>\n");
  $txt .= &_wb_print(--$indent, "</viper>\n");

  # We discard this warning for all but debug runs
  #warn_print("(WEIRD) End indentation is not equal to 0 ? (= $indent)\n") if ($indent != 0);

  return($txt);
}

########################################

sub _clone_fhash_selected_events {
  my $rin_hash = shift @_;
  my @asked_events = @_;

  my %in_hash = %{$rin_hash};
  my %out_hash;

  %{$out_hash{"file"}} = %{$in_hash{"file"}};

  foreach my $event (@asked_events) {
    if (exists $in_hash{$event}) {
      %{$out_hash{$event}} = %{$in_hash{$event}};
    }
  }

  return(%out_hash);
}

############################################################

sub _is_blank {
  my $txt = shift @_;
  return(($txt =~ m%^\s*$%));
}

################################################################################

1;
