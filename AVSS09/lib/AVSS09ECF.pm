package AVSS09ECF;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# AVSS09 ECF XML Handler
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS09ECF.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

use ViperFramespan;
use xmllintHelper;
use MtXML;
use MErrorH;
use MMisc;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "AVSS09ECF.pm Version: $version";

########################################

# Required XSD files
my @xsdfilesl = ( "AVSS09-ecf.xsd" );
# Default values to compare against (constant values)
my $default_error_value = "default_error_value";

# Order is important
my @ok_types = ("scspt", "mcspt", "cpspt");
my @tt_keys = ("evaluate_fs", "type", "sffn");
my @ttp_keys = ("dont_care_region", "dont_care_frames", "template_xml", "target_training");

## Constructor
sub new {
  my ($class) = shift @_;

  my $errortxt = (scalar @_ > 0) ? "AVSS09ECF does not accept parameters" : "";

  my $xmllintobj = new xmllintHelper();
  $xmllintobj->set_xsdfilesl(@xsdfilesl);
  $errortxt .= $xmllintobj->get_errormsg() if ($xmllintobj->error());

  my $errormsg = new MErrorH("AVSS09ECF");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     file            => "",
     xmllintobj      => $xmllintobj,
     tracking_trials => undef,
     tt_types        => undef,
     tt_sffn         => undef,
     validated       => 0,       # To confirm file was validated
     errormsg        => $errormsg,
    };

  bless $self;
  return($self);
}

####################

sub get_version {
  my ($self) = @_;

  return($versionid);
}

########################################

sub get_required_xsd_files_list {
  my ($self) = @_;

  return(-1) if ($self->error());

  return(@xsdfilesl);
}

########## 'xmllint'

sub set_xmllint {
  my ($self, $xmllint) = @_;

  return(0) if ($self->error());

  $self->{xmllintobj}->set_xmllint($xmllint);

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

  return(-1) if ($self->error());

  if (! $self->_is_xmllint_set()) {
    $self->_set_errormsg("\'xmllint\' is not set");
    return(0);
  }

  return($self->{xmllintobj}->get_xmllint());
}

########## 'xsdpath'

sub set_xsdpath {
  my ($self, $xsdpath) = @_;

  return(0) if ($self->error());

  $self->{xmllintobj}->set_xsdpath($xsdpath);
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

  return(-1) if ($self->error());

  if (! $self->_is_xsdpath_set()) {
    $self->_set_errormsg("\'xsdpath\' is not set");
    return(0);
  }

  return($self->{xmllintobj}->get_xsdpath());
}

########## 'file'

sub set_file {
  my ($self, $file) = @_;

  return(0) if ($self->error());

  my $err = MMisc::check_file_r($file);
  if (! MMisc::is_blank($err)) {
    $self->_set_errormsg($err);
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

########## 'validate'

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
  # Initial Cleanups, Checks and Global Values Extraction
  ($res, $bigstring) = $self->_data_cleanup_globalextract($bigstring);
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }
  
  # Process the data part
  ($res, $bigstring) = $self->_data_processor($bigstring);
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }
  
  $self->{validated} = 1;
  return(1);
}

##########

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

sub __validate_fs {
  my ($fs) = @_;

  my ($err, $fs_fs) = __fs2vfs($fs);
  return($err, undef) if (! MMisc::is_blank($err));

  return("", $fs_fs->get_value());
}

#####

sub __fully_within {
  my ($fs1, $fs2, $mode) = @_;

  my ($err, $fs_fs1) = &__fs2vfs($fs1);
  return($err) if (! MMisc::is_blank($err));

  my ($err, $fs_fs2) = &__fs2vfs($fs2);
  return($err) if (! MMisc::is_blank($err));

  my $ov = $fs_fs1->get_overlap($fs_fs2);
  return($fs_fs1->get_errormsg()) if ($fs_fs1->error());
  if (! defined $ov) {
    return("", $ov) if ($mode eq "oo");
    return("\"$fs1\" does not overlap \"$fs2\"");
  }
  return($ov->get_errormsg()) if ($ov->error());
  my $ovfs = $ov->get_value();

  return("", $ovfs) if ($mode eq "oo");

  my $fs1fs = $fs_fs1->get_value();

  return("\"$fs1\" is not fully within \"$fs2\", only overlaps \"$ovfs\"")
    if ($fs1fs ne $ovfs);

  return("");
}

#####

sub __overlap {
  my ($fs1, $fs2) = @_;
  return(&__fully_within($fs1, $fs2, "oo"));
}

#####

sub _data_cleanup_globalextract {
  my ($self, $bigstring) = @_;

  # Remove all XML comments
  $bigstring =~ s%\<\!\-\-.+?\-\-\>%%sg;

  # Remove <?xml ...?> header
  return("Could not find a proper \'<?xml ... ?>\' header, skipping", $bigstring)
    if (! ($bigstring =~ s%^\s*\<\?xml.+?\?\>%%is));

  # Remove <ecf ...> and </ecf> header and trailer
  return("Could not find a proper \'ecf\' tag, aborting", $bigstring)
    if (! MtXML::remove_xml_tags("ecf", \$bigstring));

  # Get the optional version information (in the header usualy)
  my $name = "version";
  my $version = MtXML::get_named_xml_section($name, \$bigstring, $default_error_value);
  if ($version ne $default_error_value) {
    return("Could not remove the \'$name\' tag, aborting", $bigstring)
      if (! MtXML::remove_xml_tags($name, \$version));
    $self->{version}=$version;
  }

  return("", $bigstring);
}

#####

sub _data_processor {
  my ($self, $string) = @_;

  ##### Process all that is left in the string (should only be tracking_trials)
  my $name = "tracking_trial";
  while (! MMisc::is_blank($string)) {
    my $sec = MtXML::get_named_xml_section($name, \$string, $default_error_value);
    return("Found some content other than \'$name\'", $string)
      if ($sec eq $default_error_value);

    my ($err) = $self->_tt_processor($sec, $name);
    return("Problem extracting \'$name\' data ($err). ", $string)
      if (! MMisc::is_blank($err));
  }

  return("", "");
}

#####

sub _tt_processor {
  my ($self, $string, $name) = @_;

  my ($err, %res) = MtXML::get_inline_xml_attributes($name, $string);
  return($err, $string) if (! MMisc::is_blank($err));

  my $f = "type";
  return("Could not find \'$f\'", $string) if (! exists $res{$f});
  my $type = $res{$f};
  return("Unknown type ($type)", $string) if (! grep(m%^$type$%, @ok_types));

  $f = "id";
  return("Could not find \'$f\'", $string) if (! exists $res{$f});
  my $id = $res{$f};
  return("ID [$id] already exists", $string)
    if (exists $self->{tracking_trials}{$id});
                                              
  $f = "framespan";
  return("Could not find \'$f\'", $string) if (! exists $res{$f});
  my $fs = $res{$f};
  my ($err, $fs) = &__validate_fs($fs);
  return($err, $string) if (! MMisc::is_blank($err));

  ## How many camera entries max are we exptecting
  my $max_exp = 0; # Infinite
  $max_exp = 1 if ($type eq $ok_types[0]);
  $max_exp = 2 if ($type eq $ok_types[2]);

  ## Clean up string
  return("Could not remove the \'$name\' tag, aborting", $string)
    if (! MtXML::remove_xml_tags($name, \$string));  

  ## "camera" processing
  my $camc = 0;
  $name = "camera";
  while (! MMisc::is_blank($string)) {
    my $sec = MtXML::get_named_xml_section($name, \$string, $default_error_value);
    return("Found some content other than \'$name\'", $string)
      if ($sec eq $default_error_value);

    my $err = $self->_camera_processor($sec, $name, $id, $type, $fs);
    return("Problem extracting \'$name\' data ($err). ", $string)
      if (! MMisc::is_blank($err));

    $camc++;
    return("Found more \"$name\" ($camc) than the expected number ($max_exp)", $string)
      if (($max_exp > 0) && ($camc > $max_exp));
  }
  return("Found a different number of \"$name\" ($camc) than expected ($max_exp)", $string)
    if (($max_exp > 0) && ($camc > $max_exp));
  return("Found a very small amount of \"$name\" ($camc) for a \"$type\"", $string)
    if (($max_exp == 0) && ($camc < 3));

  return("", $string);
}

#####

sub _camera_processor {
  my ($self, $string, $name, $tt_id, $tt_type, $tt_fs) = @_;

  my ($err, %res) = MtXML::get_inline_xml_attributes($name, $string);
  return($err) if (! MMisc::is_blank($err));

  my $f="file";
  return("Could not find \'$f\'") if (! exists $res{$f});
  my $sffn = $res{$f};
  return("For \"$tt_id\", there is already one definition of this \"$f\" ($sffn)")
    if (exists $self->{tt_sffn}{$sffn}{$tt_id});

  my $txml = "";
  $f = $ttp_keys[2]; # template_xml
  $txml = $res{$f} if (exists $res{$f});

  my $targt = "";
  $f = $ttp_keys[3]; # target_training
  $targt = $res{$f} if (exists $res{$f});

  # Start filling some hashes
  my %tt_params = ();
  $self->{tracking_trials}{$tt_id}{$tt_keys[0]} = $tt_fs; # evaluate fs
  $self->{tracking_trials}{$tt_id}{$tt_keys[1]} = $tt_type; # type
  $self->{tt_types}{$tt_type}{$tt_id}++;
  $self->{tt_sffn}{$sffn}{$tt_id}++;
  $tt_params{$ttp_keys[2]} = $txml 
    if (! MMisc::is_blank($txml));
  $tt_params{$ttp_keys[3]} = $targt 
    if (! MMisc::is_blank($targt));

  ## Clean up string
  return("Could not remove the \'$name\' tag, aborting")
    if (! MtXML::remove_xml_tags($name, \$string));  

  ## Get DCR & DCF
  my  ($err, @dcfs) = $self->_get_dcfs(\$string, $tt_fs);
  return("While looking for DCFs in \"$name\" [$tt_id / $sffn] : $err")
    if (! MMisc::is_blank($err));
  my ($err, @dcrs) = $self->_get_dcrs(\$string, $tt_fs);
  return("While looking for DCRs in \"$name\" [$tt_id / $sffn] : $err")
    if (! MMisc::is_blank($err));
  return("Leftover data when processing \"$name\" [$sffn] : $string")
    if (! MMisc::is_blank($string));

  # Consolidate DCF
  my $dcf = "";
  if (scalar @dcfs > 0) {
    $dcf = join(" ", @dcfs);
    my ($err, $dcf) = &__validate_fs($dcf);
    return("While consolidating DCF: $err") if (! MMisc::is_blank($err));
  }
  $tt_params{$ttp_keys[1]} = $dcf if (! MMisc::is_blank($dcf));

  # Add DCRs
  @{$tt_params{$ttp_keys[0]}} = @dcrs
      if (scalar @dcrs > 0);

  # Set parameters
  %{$self->{tracking_trials}{$tt_id}{$tt_keys[2]}{$sffn}} = %tt_params;

  return("");
}

#####

sub _get_dcrf_commom {
  my ($rstr, $gfs, $name) = @_;

  my %ids = ();
  my %out = ();

  my $cont = 1;
  while ($cont) {
    my $sec = MtXML::get_named_xml_section($name, $rstr, $default_error_value);
    if ($sec eq $default_error_value) {
      $cont = 0;
      next;
    }

    my ($err, %res) = MtXML::get_inline_xml_attributes($name, $sec);
    return($err) if (! MMisc::is_blank($err));

    my $f="id";
    return("Could not find \'$f\'") if (! exists $res{$f});
    my $id = $res{$f};
    return("\"$f\" [$id] already present")
      if (exists $ids{$id});
    $ids{$id}++;

    $f="framespan";
    return("Could not find \'$f\'") if (! exists $res{$f});
    my $fs = $res{$f};
    my ($err, $fs) = &__validate_fs($fs);
    return($err) if (! MMisc::is_blank($err));
    my ($err) = &__fully_within($fs, $gfs);
    return($err) if (! MMisc::is_blank($err));

    ## Clean up string
    return("Could not remove the \'$name\' tag, aborting")
      if (! MtXML::remove_xml_tags($name, \$sec));  

    # Store the lefover string for further processing
    $out{$fs} = $sec;
  }

  return("", %out);
}

#####

sub _get_dcfs {
  my ($self, $rstr, $gfs) = @_;

  my $name = $ttp_keys[1];
  my ($err, %res) = &_get_dcrf_commom($rstr, $gfs, $name);
  return($err) if (! MMisc::is_blank($err));

  my @out = ();
  foreach my $fs (keys %res) {
    my $t = $res{$fs};
    return("In \"$name\", found unexpected content [$t]")
      if (! MMisc::is_blank($t));
    push @out, $fs;
  }

  return("", @out);
}

#####

sub _get_dcrs {
  my ($self, $rstr, $gfs) = @_;

  my $name = $ttp_keys[0];
  my ($err, %res) = &_get_dcrf_commom($rstr, $gfs, $name);
  return($err) if (! MMisc::is_blank($err));

  my @out = ();
  foreach my $fs (keys %res) {
    my $t = $res{$fs};
    return("In \"$name\", found no content")
      if (MMisc::is_blank($t));

    my ($err, @tmp) = &_confirm_dcr_bbox($t, $fs);
    return($err) if (! MMisc::is_blank($err));

    push @out, [ @tmp ];
  }

  return("", @out);
}

#####

sub _confirm_dcr_bbox {
  my ($str, $gfs) = @_;

  my $prevfs = "";
  my $name = "bbox";
  my $cont = 1;
  my @out = ();
  while ($cont) {
    my $sec = MtXML::get_named_xml_section($name, \$str, $default_error_value);
    if ($sec eq $default_error_value) {
      $cont = 0;
      next;
    }

    my ($err, %res) = MtXML::get_inline_xml_attributes($name, $sec);
    return($err) if (! MMisc::is_blank($err));

    my $f="framespan";
    return("Could not find \'$f\'") if (! exists $res{$f});
    my $fs = $res{$f};
    my ($err, $fs) = &__validate_fs($fs);
    return($err) if (! MMisc::is_blank($err));
    my ($err) = &__fully_within($fs, $gfs);
    return($err) if (! MMisc::is_blank($err));
    if (! MMisc::is_blank($prevfs)) {
      my ($err, $ov) = &__overlap($fs, $prevfs);
      return("overlap error: $err") if (! MMisc::is_blank($err));
      return("framespan ($fs) overlaps previous combined framespans ($prevfs)")
        if (defined $ov);
    }
    ($err, $prevfs) = &__validate_fs("$prevfs $fs");
    return($err) if (! MMisc::is_blank($err));

    my @tmp = ();
    push @tmp, $fs;

    foreach $f ("x", "y", "width", "height") {
      return("Could not find \'$f\'") if (! exists $res{$f});
      push @tmp, $res{$f};
    }

    push @out, [ @tmp ];
  }
  return("\"$prevfs\" does not cover all of \"$gfs\"") if ($prevfs ne $gfs);
  return("Leftover elements in string ($str)") if (! MMisc::is_blank($str));
  return("Found no bbox") if (scalar @out == 0);

  return("", @out);
}


########################################

# Access functions

sub is_filename_in {
}

#####

sub get_file_ViperFramespans {
}

#####

sub get_files_list {
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

##########

sub _display {
  my ($self) = @_;

  return(MMisc::get_sorted_MemDump(\$self));
}

############################################################

1;
