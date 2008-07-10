package CLEARViperFile;

# CLEAR ViperFile
#
# Original Author(s): Martial Michel
# Modified by Vasant Manohar to suit CLEAR/VACE evaluation framework
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEARViperFile.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  # CVS version ID is irrelevant. Since a lot of changes were done to suit CLEAR/VACE evaluation, I did not
  # update the latest version of TrecVid08ViperFile. Instead ported the relevant changes from the latest CVS version 1.29 (07/09/08).
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CLEARViperFile.pm Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";

# ViperFramespan.pm (part of this tool)
unless (eval "use ViperFramespan; 1")
 {
   my $pe = &eo2pe($@);
   warn_print("\"ViperFramespan\" is not available in your Perl installation. ", $partofthistool, $pe);
   $have_everything = 0;
 }

# MErrorH.pm
unless (eval "use MErrorH; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"MErrorH\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# "MMisc.pm"
unless (eval "use MMisc; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# For the '_display()' function
unless (eval "use Data::Dumper; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"Data::Dumper\" is not available in your Perl installation. ", 
                "Please visit \"http://search.cpan.org/~ilyam/Data-Dumper-2.121/Dumper.pm\" for installation information\n");
    $have_everything = 0;
  }

# File::Temp (usualy part of the Perl Core)
unless (eval "use File::Temp qw / tempfile /; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"File::Temp\" is not available in your Perl installation. ", 
                "Please visit \"http://search.cpan.org/~tjenness/File-Temp-0.20/Temp.pm\" for installation information\n");
    $have_everything = 0;
  }

# Something missing ? Abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

########################################
##########

# Required XSD files
my @xsdfilesl = ( "CLEAR.xsd", "CLEAR-viper.xsd", "CLEAR-viperdata.xsd" ); # Important that the main file be first

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

my %list_objects_attributes;
@{$list_objects_attributes{"I-Frames"}} = ();
@{$list_objects_attributes{"FRAME"}} = ("EVALUATE");
@{$list_objects_attributes{"TEXT"}} = ();
@{$list_objects_attributes{"FACE"}} = ("LOCATION", "VISIBLE", "SYNTHETIC", "HEADGEAR", "AMBIGUITY FACTOR");
@{$list_objects_attributes{"HAND"}} = ("LOCATION", "VISIBLE", "SYNTHETIC", "HANDGEAR", "LARGEBOX", "OCCLUSION");
@{$list_objects_attributes{"PERSON"}} = ();
@{$list_objects_attributes{"VEHICLE"}} = ();

# Authorized Object List
my @ok_objects = keys %list_objects_attributes;

my %list_objects_attributes_types; # Order is important (has to match previous)
@{$list_objects_attributes_types{"I-Frames"}} = ();
@{$list_objects_attributes_types{"FRAME"}} = ("bvalue");
@{$list_objects_attributes_types{"TEXT"}} = ();
@{$list_objects_attributes_types{"FACE"}} = ("obox", "bvalue", "bvalue", "bvalue", "dvalue");
@{$list_objects_attributes_types{"HAND"}} = ("point", "bvalue", "bvalue", "bvalue", "obox", "bvalue");
@{$list_objects_attributes_types{"PERSON"}} = ();
@{$list_objects_attributes_types{"VEHICLE"}} = ();

my %list_objects_attributes_isd; # Order is important (has to match previous too)
@{$list_objects_attributes_isd{"I-Frames"}} = ();
@{$list_objects_attributes_isd{"FRAME"}} = (1);
@{$list_objects_attributes_isd{"TEXT"}} = ();
@{$list_objects_attributes_isd{"FACE"}} = (1, 1, 1, 1, 1);
@{$list_objects_attributes_isd{"HAND"}} = (1, 1, 1, 1, 1, 1);
@{$list_objects_attributes_isd{"PERSON"}} = ();
@{$list_objects_attributes_isd{"VEHICLE"}} = ();
  
my %opt_list_objects_attributes;
@{$opt_list_objects_attributes{"FRAME"}} = ("CROWD", "MULTIPLE VEHICLE", "MULTIPLE TEXT AREAS");

my %opt_list_objects_attributes_types; # Order is important (has to match previous)
@{$opt_list_objects_attributes_types{"FRAME"}} = ("bvalue", "bvalue", "bvalue");

my %opt_list_objects_attributes_isd; # Order is important (has to match previous too)
@{$opt_list_objects_attributes_isd{"FRAME"}} = (1, 1, 1);

my @not_gtf_required_objects_attributes = ();

my %hash_objects_attributes_types;
my %hash_objects_attributes_types_dynamic;

my %hasharray_inline_attributes;
@{$hasharray_inline_attributes{"bbox"}} = ("x", "y", "height", "width");
@{$hasharray_inline_attributes{"obox"}} = ("x", "y", "height", "width", "rotation");
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

########## Some rules that can be changed (here, specific for CLEAR)
# Maximum number of pair per framespan found
# For Trecvid08, only one pair (ie one framespan range) is authorized per framespan (0 for unlimited)
my $max_pair_per_fs = 0; # positive number / 0 for unlimited
## Update (20080421): After talking with Jon, we decided that IDs do not have to start at 0 or be consecutive after all
# Check if IDs list have to start at 0
my $check_ids_start_at_zero = 0;
# Check that IDs are consecutive
my $check_ids_are_consecutive = 0;


########################################

## Constructor
sub new {
  my ($class) = shift @_;

  my $errortxt = (scalar @_ > 0) ? "CLEARViperFile does not accept parameters" : "";

  &_fill_required_hashes();

  ## Run the ViperFramespan test_unit just to be sure
  my $fs_tmp = ViperFramespan->new();
  $errortxt .= $fs_tmp->get_errormsg() if (! $fs_tmp->unit_test());

  my $errormsg = new MErrorH("CLEARViperFile");
  $errormsg->set_errormsg($errortxt);

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
     errormsg       => $errormsg,
    };

  bless $self;
  return($self);
}

#####

sub _fill_required_hashes {
  for (my $outloop = 0; $outloop < scalar @ok_objects; $outloop++) {
    my $key = $ok_objects[$outloop];
    my @this_object_attributes = @{$list_objects_attributes{$ok_objects[$outloop]}};
    my @this_object_attributes_types = @{$list_objects_attributes_types{$ok_objects[$outloop]}};
    my @this_object_attributes_isd = @{$list_objects_attributes_isd{$ok_objects[$outloop]}};
    my ( %this_hash_object_attributes_types, %this_hash_object_attributes_types_dynamic );
    for (my $inloop = 0; $inloop < scalar @this_object_attributes; $inloop++) {
      my $keya  = $this_object_attributes[$inloop];
      my $keyt  = $this_object_attributes_types[$inloop];

      $this_hash_object_attributes_types{$keya} = $keyt;
      $this_hash_object_attributes_types_dynamic{$keya} = $this_object_attributes_isd[$inloop];
    }

    if ( exists $opt_list_objects_attributes{$ok_objects[$outloop]} ) {
        my @this_object_opt_attributes = @{$opt_list_objects_attributes{$ok_objects[$outloop]}};
        my @this_object_opt_attributes_types = @{$opt_list_objects_attributes_types{$ok_objects[$outloop]}};
        my @this_object_opt_attributes_isd = @{$opt_list_objects_attributes_isd{$ok_objects[$outloop]}};
        for (my $inloop = 0; $inloop < scalar @this_object_opt_attributes; $inloop++) {
          my $keya  = $this_object_opt_attributes[$inloop];
          my $keyt  = $this_object_opt_attributes_types[$inloop];

          $this_hash_object_attributes_types{$keya} = $keyt;
          $this_hash_object_attributes_types_dynamic{$keya} = $this_object_opt_attributes_isd[$inloop];
        }
    }

    $hash_objects_attributes_types{$key}{1} = \%this_hash_object_attributes_types;
    $hash_objects_attributes_types_dynamic{$key}{1} = \%this_hash_object_attributes_types_dynamic;

    my ( %sys_hash_object_attributes_types, %sys_hash_object_attributes_types_dynamic );
    my $keya = ${$list_objects_attributes{$ok_objects[$outloop]}}[0];
    my $keyt = ${$list_objects_attributes_types{$ok_objects[$outloop]}}[0];
    $sys_hash_object_attributes_types{$keya} = $keyt;
    $sys_hash_object_attributes_types_dynamic{$keya} = ${$list_objects_attributes_isd{$ok_objects[$outloop]}}[0];
    $hash_objects_attributes_types{$key}{0} = \%sys_hash_object_attributes_types;
    $hash_objects_attributes_types_dynamic{$key}{0} = \%sys_hash_object_attributes_types_dynamic;
  }
}

####################

sub get_version {
  my ($self) = @_;

  return($versionid);
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

sub get_required_xsd_files_list {
  my ($self) = @_;

  return(-1) if ($self->error());

  return(@xsdfilesl);
}

#####

sub validate_objects_list {
  my ($self, @objects) = @_;

  @objects = split(m%\,%, join(",", @objects));
  @objects = &_make_array_of_unique_values(@objects);
  my ($in, $out) = MMisc::compare_arrays(\@ok_objects, @objects);
  if (scalar @$out > 0) {
    $self->_set_errormsg("Found some unknown object type: " . join(" ", @$out));
    return();
  }

  return(@objects);
}

#####

sub get_full_objects_list {
  my ($self) = @_;

  return(-1) if ($self->error());

  return(@ok_objects);
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
  if (! MMisc::is_blank($error)) {
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

  return(1) if (! MMisc::is_blank($self->{xmllint}));

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
  if (! MMisc::is_blank($error)) {
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

  return(1) if (! MMisc::is_blank($self->{xsdpath}));

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
  my $fs_tmp = ViperFramespan->new();
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

  return(0) if (MMisc::is_blank($self->{file}));

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

  return(1) if (! MMisc::is_blank($self->{comment}));

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
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }
  # No data from xmllint ?
  if (MMisc::is_blank($bigstring)) {
    $self->_set_errormsg("WEIRD: The XML data returned by xmllint seems empty");
    return(0);
  }

  # Initial Cleanups & Check
  ($res, $bigstring) = &_data_cleanup($bigstring);
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }

  # Process the data part
  my %fdata;
  my $isgtf = $self->check_if_gtf();
  ($res, %fdata) = $self->_data_processor($bigstring, $isgtf);
  if (! MMisc::is_blank($res)) {
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
  my $isgtf = shift @_;
  my @limitto_objects = @_;

  return(-1) if ($self->error());

  if (scalar @limitto_objects == 0) {
    @limitto_objects = @ok_objects;
  } else {
    @limitto_objects = $self->validate_objects_list(@limitto_objects);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only rewrite the XML for a validated file");
    return(0);
  }

  my $comment = "";
  $comment = $self->_get_comment() if ($self->_is_comment_set());

  my %tmp = $self->_get_fhash();

  return(&_writeback2xml($comment, $isgtf, \%tmp, @limitto_objects));
}

##########

sub get_base_xml {
  my ( $self, $isgtf, @limitto_objects ) = @_;

  return(-1) if ($self->error());

  if (scalar @limitto_objects == 0) {
    @limitto_objects = @ok_objects;
  } else {
    @limitto_objects = $self->validate_objects_list(@limitto_objects);
    return(0) if ($self->error());
  }

  my %tmp = ();
  return(&_writeback2xml("", $isgtf, \%tmp, @limitto_objects));
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
  my @limitto_objects = @_;

  return(-1) if ($self->error());

  if (scalar @limitto_objects == 0) {
    @limitto_objects = @ok_objects;
  } else {
    @limitto_objects = $self->validate_objects_list(@limitto_objects);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'_display\' for a validated file");
    return(0);
  }

  my %in = $self->_get_fhash();
  my %out = &_clone_fhash_selected_objects(\%in, @limitto_objects);

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



#####



#####



##########



####################

sub remove_all_objects {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only \"remove all objects\" for a validated file");
    return(0);
  }

  my %in = $self->_get_fhash();
  my %out = &_clone_fhash_selected_objects(\%in);

  $self->_set_fhash(%out);
  return(1);
}

##########

sub _clone_core {
  my ($self, $keep_objects) = @_;

  return(undef) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only \'clone\' a validated file");
    return(undef);
  }
  
  my $clone = new CLEARViperFile();
  
  $clone->set_xmllint($self->get_xmllint());
  $clone->set_xsdpath($self->get_xsdpath());
  $clone->set_as_gtf() if ($self->check_if_gtf());
  $clone->set_fps($self->get_fps()) if ($self->_is_fps_set());
  $clone->set_file($self->get_file());
  my %in = $self->_get_fhash();
  my %out;
  if ($keep_objects) {
    %out = &_clone_fhash_selected_objects(\%in, @ok_objects);
  } else {
    %out = &_clone_fhash_selected_objects(\%in);
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

sub clone_with_no_objects {
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
  $self->_addto_comment("NUMFRAMES extended from $cnf to $numframes" . ((! MMisc::is_blank($commentadd)) ? " ($commentadd)" : ""));
  return(0) if ($self->error());

  return(1);
}

#####

sub extend_numframes {
  my ($self, $numframes, $commentadd) = @_;

  return($self->_set_fhash_file_numframes($numframes, 1, $commentadd));
}

##########

sub get_first_available_object_id {
  my ($self, $object) = @_;

  return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only get first available object id for a validated file");
    return(-1);
  }

  if (! grep(m%^$object$%, @ok_objects)) {
    $self->set_errormsg("Eventtype ($object) is not a recognized one");
    return(-1);
  }

  my %tmp = $self->_get_fhash();

  # No object of this type set yet, so the first id available (0)
  return(0) if (! exists $tmp{$object});

  my @keys = sort _numerically  keys %{$tmp{$object}};

  return(1 + $keys[-1]);
}

##########

sub _bvalue_convert {
  my ($attr, @values) = @_;

  print "[_bvalue_convert] Somebody called me. Am not ready yet\n";
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
    if (! MMisc::is_blank($string));
  # Parse it
  ($res, %fdata) = $self->_parse_sourcefile_section($name, $section, $isgtf);
  if (! MMisc::is_blank($res)){
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
      if (MMisc::is_blank($name));

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
    if (! MMisc::is_blank($line));
  
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
  return($err, ()) if (! MMisc::is_blank($err));
  return("", ()) if (scalar @all == 0); # None found

  my ($res, %hash) = &_split_xml_tag_list_to_hash(@all);
  return($res, ()) if (! MMisc::is_blank($res));

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
    if (! &_remove_xml_tags($name, \$str));

  #####
  # Get the 'file' section
  my $sec = &_get_named_xml_section("file", \$str);
  return("No \'file\' section found in the \'sourcefile\'", ())
    if ($sec eq $default_error_value);
  ($text, my %fattr) = $self->_parse_file_section($sec);
  return($text, ()) if (! MMisc::is_blank($text));
  
  # Complete %fattr and start filling %res
  $fattr{"filename"} = $filename;
  %{$res{"file"}} = %fattr;

  ##########
  # Process all that is left in the string (should only be objects)
  $str = &_clean_begend_spaces($str);
  
  my @error_list = ();
  while (! MMisc::is_blank($str)) {
    my $sec = &_get_named_xml_section("object", \$str);
    if ($sec eq $default_error_value) {
       push (@error_list, ("No \'object\' section left in the \'sourcefile\'"));
    } else {
        ($text, my $object_type, my $object_id, my $object_framespan, my %oattr)
          = $self->_parse_object_section($sec, $isgtf);
        if (! MMisc::is_blank($text)){
            if (! grep(/^warning/i, $text)) {
                push (@error_list, $text);
            }
            else {
                my $filename = $self->get_file();
                print "$filename: $text\n";
            }
        } else {

            ##### Sanity
    
            # Check that the object name is an authorized object name
            if (! grep(/^$object_type$/, @ok_objects)){
                push (@error_list, "Found unknown object type ($object_type) in \'object\'");
            } else {
               # Check that the object type/id key does not already exist
               if (exists $res{$object_type}{$object_id}){
                  push (@error_list, "Only one unique (object type, id) key authorized ($object_type, $object_id)");
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
    foreach my $object (@ok_objects) {
      next if (! exists $res{$object});
      my @list = sort _numerically keys %{$res{$object}};
      
      if ($check_ids_start_at_zero) {
	return("Event ID list must always start at 0 (for object \'$object\', start at " . $list[0] . ")", ())
	  if ($list[0] != 0);
      }
      
      if ($check_ids_are_consecutive) {
	return("Event ID list must always start at 0 and have no gap (for object \'$object\', seen "
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

sub _parse_file_section {
  my ($self) = shift @_;
  my $str = shift @_;

  my $wtag = "file";
  my %file_hash;

  my ($text, %attr) = &_get_inline_xml_attributes($wtag, $str);
  return($text, ()) if (! MMisc::is_blank($text));

  my $framespan_max = $framespan_max_default;

  my @expected = @array_file_inline_attributes;
  my ($in, $out) = MMisc::compare_arrays(\@expected, keys %attr);
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
    if (! MMisc::is_blank($text));

  # Confirm they are the ones we want
  my %expected_hash = %hash_file_attributes_types;
  @expected = keys %expected_hash;
  ($in, $out) = MMisc::compare_arrays(\@expected, keys %attr);
  return("Could not find all the expected \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'$wtag\' attributes", ())
    if (scalar @$out > 0);

  # Check they are of valid type & reformat them for the output file hash
  foreach my $key (@expected) {
    $file_hash{uc($key)} = undef;
    my $val = $expected_hash{$key};
    next if (! defined $val);
    my @comp = keys %{$attr{$key}};
    next if (scalar @comp == 0);
    my @expected2;
    push @expected2, $val;
    ($in, $out) = MMisc::compare_arrays(\@expected2, @comp);
    return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type", ())
      if (scalar @$out > 0);

    return("WEIRD: Could not find the value associated with the \'$key\' \'$wtag\' attribute", ())
      if (! exists $attr{$key}{$val}{$framespan_max});
    $file_hash{uc($key)} = ${$attr{$key}{$val}{$framespan_max}}[0];
  }

  # Set the "framespan_max" from the NUMFRAMES entry
  my $key = "NUMFRAMES";
  return("No \'$key\' \'$wtag\' attribute defined", ())
    if (! defined $file_hash{uc($key)});
  my $val = $file_hash{uc($key)};
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

  # print "$str\n";
  my $wtag = "object";

  my $object_name;
  my $object_id;
  my $object_framespan;
  my %object_hash;

  my ($text, %attr) = &_get_inline_xml_attributes($wtag, $str);
  return($text, ()) if (! MMisc::is_blank($text));

  my $framespan_max = $self->_get_framespan_max_value();
  return("Problem obtaining the \'framespan_max\' value", ()) if ($self->error());
  my $fs_framespan_max = $self->_get_framespan_max_object();
  return("Problem obtaining the \'framespan_max\' object", ()) if ($self->error());

  my @expected = @array_objects_inline_attributes;
  my ($in, $out) = MMisc::compare_arrays(\@expected, keys %attr);
  return("WARNING: Could not find all the expected inline \'$wtag\' attributes. Skipping \'$wtag\' section", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected inline \'$wtag\' attributes", ())
    if (scalar @$out > 0);

  # Get the object name
  return("WARNING: Could not obtain the \'name\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[0]});
  $object_name = $attr{$expected[0]};

  # Get the object id
  return("WARNING: Could not obtain the \'id\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[1]});
  $object_id = $attr{$expected[1]};

  # Get the object framespan
  return("WARNING: Could not obtain the \'framespan\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[2]});
  my $tmp = $attr{$expected[2]};

  my $fs_tmp = ViperFramespan->new();
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
    if (! MMisc::is_blank($text));

  # Confirm they are the ones we want
  my %expected_hash = %{$hash_objects_attributes_types{$object_name}{$isgtf}};
  @expected = keys %expected_hash;
  ($in, $out) = MMisc::compare_arrays(\@expected, keys %attr);
  if ((scalar @$in != scalar @expected) && $isgtf) {
     # If you don't find all the attributes, check if all the required ones are present.
     foreach my $attr_name (@{$list_objects_attributes{$object_name}}) {
        return("Could not find all the expected \'$wtag\' attributes", ())
           if (! grep(m%^$attr_name$%i, @$in));
     }
  }

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
    ($in, $out) = MMisc::compare_arrays(\@expected2, @comp);
    return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type", ())
      if (scalar @$out > 0);

    foreach my $fs (keys %{$attr{$key}{$val}}) {
      @{$object_hash{uc($key)}{$fs}} = @{$attr{$key}{$val}{$fs}};
    }
  }

  return("", $object_name, $object_id, $object_framespan, %object_hash);
}

####################

sub _data_process_array_core {
  my $name = shift @_;
  my $rattr = shift @_;
  my @expected = @_;

  my ($in, $out) = MMisc::compare_arrays(\@expected, keys %$rattr);
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
  my ( $self, $str, $fspan, $allow_nofspan, $type ) = @_;

  my %attr;
  my @afspan;

  my $fs_fspan = ViperFramespan->new();
  if (! $allow_nofspan) {
    return("ViperFramespan ($fspan) error (" . $fs_fspan->get_errormsg() . ")", ())
      if (! $fs_fspan->set_value($fspan));
  }

  while (! MMisc::is_blank($str)) {
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
    return($text, ()) if (! MMisc::is_blank($text));

    # From here we work per 'data:' type
    $name =~ s%^data\:%%;

    # Check the framespan (if any)
    my $lfspan;
    my $key = "framespan";
    if (exists $iattr{$key}) {
      $lfspan = $iattr{$key};

      my $fs_lfspan = ViperFramespan->new();
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
	if (! exists $hash_objects_attributes_types_dynamic{$name}{1}->{$type});

      # If it is, a framespan should have been provided
      return("No framespan provided for dynamic \'data\:\' type ($name)", ())
	if ($hash_objects_attributes_types_dynamic{$name}{1}->{$type} == 1);

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
  my %attrs;

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
    my $sec = &_get_named_xml_section("attribute", $rstr);
    return("Could not find an \'attribute\'", ()) if ($sec eq $default_error_value);

    # Get its name
    my ($text, %iattr) = &_get_inline_xml_attributes("attribute", $sec);
    return($text, ()) if (! MMisc::is_blank($text));

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
    
    if (MMisc::is_blank($sec)) {
      $attrs{uc($name)} = undef;
    } else {
      ($text, my %tmp) = $self->_extract_data($sec, $fspan, $allow_nofspan, $name);
      return("Error while processing the \'data\:\' content of the \'$name\' \'attribute\' ($text)", ())
	if (! MMisc::is_blank($text));
      %{$attrs{uc($name)}} = %tmp;
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
    or die("[CLEARViperFile] Internal error: Can not open file to slurp ($fname): $!\n");
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
  my $isgtf = shift @_;
  my $indent = shift @_;
  my $object = shift @_;
  my $id = shift @_;
  my %object_hash = @_;

  my $txt = "";

  $txt .= &_wb_print($indent++, "<object name=\"$object\" id=\"$id\" framespan=\"" . $object_hash{'framespan'} . "\">\n");

  # comment (optional)
  $txt .= &_wb_print($indent, "<!-- " . $object_hash{"comment"} . " -->\n")
    if (exists $object_hash{"comment"});

  # attributes
  foreach my $key (sort keys %{$hash_objects_attributes_types{$object}{$isgtf}}) {
    # If an optional attribute is not defined, don't write to file.
    next if ((! defined $object_hash{$key}) && grep(m%^$key$%, @{$opt_list_objects_attributes{$object}}));
    $txt .= &_wb_print($indent, "<attribute name=\"$key\"");
    if (defined $object_hash{$key}) {
      $txt .= ">\n";

      $indent++;
      my @afs;
      foreach my $fs (keys %{$object_hash{$key}}) {
	my $fs_tmp = ViperFramespan->new();
	die("[CLEARViperFile] Internal Error: WEIRD: In \'_writeback_object\' (" . $fs_tmp->get_errormsg() .")")
	  if (! $fs_tmp->set_value($fs));
	push @afs, $fs_tmp;
      }
      foreach my $fs_fs (sort _framespan_sort @afs) {
	my $fs = $fs_fs->get_value();
	$txt .= &_wb_print
	  ($indent,
	   "<data:" . $hash_objects_attributes_types{$object}{$isgtf}->{$key},
	   ($hash_objects_attributes_types_dynamic{$object}{$isgtf}->{$key}) ? " framespan=\"$fs\"" : "",
	   " ");
        
	my @subtxta;
	my @name_a = @{$hasharray_inline_attributes{$hash_objects_attributes_types{$object}{$isgtf}->{$key}}};
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
  my ( $comment, $isgtf, $rlhash, @asked_objects ) = @_;

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
  foreach my $object (@asked_objects) {
    next if (! exists $lhash{$object});
    $txt .= &_wb_print($indent++, "<descriptor name=\"$object\" type=\"OBJECT\">\n");
    foreach my $key (sort keys %{$hash_objects_attributes_types{$object}{$isgtf}}) {
      $txt .= &_wb_print
	($indent,
	 "<attribute dynamic=\"",
	 ($hash_objects_attributes_types_dynamic{$object}{$isgtf}->{$key}) ? "true" : "false",
	 "\" name=\"$key\" type=\"http://lamp.cfar.umd.edu/viperdata#",
	 $hash_objects_attributes_types{$object}{$isgtf}->{$key}, 
	 "\"/>\n");
    }
    $txt .= &_wb_print(--$indent, "</descriptor>\n");
  }

  # End 'config', begin 'data'
  $txt .= &_wb_print(--$indent, "</config>\n");
  $txt .= &_wb_print($indent++, "<data>\n");

  if (scalar %lhash > 0) { # Are we just writing a spec XML file ?
    $txt .= &_wb_print($indent++, "<sourcefile filename=\"" . $lhash{'file'}{'filename'} . "\">\n");

    # comment (optional)
    $txt .= &_wb_print($indent, "<!-- " . $comment . " -->\n")
      if (! MMisc::is_blank($comment));

    # file
    $txt .= &_writeback_file($indent, %{$lhash{'file'}});

    # Objects
    foreach my $object (@asked_objects) {
      if (exists $lhash{$object}) {
	my @ids = keys %{$lhash{$object}};
	foreach my $id (sort _numerically @ids) {
	  $txt .= &_writeback_object($isgtf, $indent, $object, $id, %{$lhash{$object}{$id}});
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

sub _clone_fhash_selected_objects {
  my $rin_hash = shift @_;
  my @asked_objects = @_;

  my %in_hash = %{$rin_hash};
  my %out_hash;

  %{$out_hash{"file"}} = %{$in_hash{"file"}};

  foreach my $object (@asked_objects) {
    if (exists $in_hash{$object}) {
      %{$out_hash{$object}} = %{$in_hash{$object}};
    }
  }

  return(%out_hash);
}

##########

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

1;
