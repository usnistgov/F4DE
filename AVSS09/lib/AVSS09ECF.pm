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
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
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
my @tt_keys = ("evaluate_fs", "type", "sffn", "target_training", "camid");
my @ttp_keys = ("dont_care_region", "dont_care_frames", "template_xml", $tt_keys[3], $tt_keys[4]);

## Constructor
sub new {
  my ($class) = @_;

  my $errortxt = (scalar @_ > 1) ? "AVSS09ECF does not accept parameters" : "";

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

    my ($err, $sffn, $targt) = $self->_camera_processor($sec, $name, $id, $type, $fs);
    return("Problem extracting \'$name\' data ($err). ", $string)
      if (! MMisc::is_blank($err));
    
    if ((! MMisc::is_blank($targt)) && (($targt eq "true") || ($targt == 1))) {
      MMisc::error_quit("No more than one \'sffn\' can claim to be the \"true\" \'target_training\'. \"" . $self->{tracking_trials}{$id}{$tt_keys[3]} . "\" already says it is, \"$sffn\" can not be too")
          if (exists $self->{tracking_trials}{$id}{$tt_keys[3]});
      $self->{tracking_trials}{$id}{$tt_keys[3]} = $sffn;
    }
    # For "scpst", force tracking_trials to the only sffn
    $self->{tracking_trials}{$id}{$tt_keys[3]} = $sffn
      if ($type eq $ok_types[0]);

    $camc++;
    return("For \'$type\' ($id), found more \"$name\" ($camc) than the expected number ($max_exp)", $string)
      if (($max_exp > 0) && ($camc > $max_exp));
  }
  return("For \'$type\' ($id), found a different number of \"$name\" ($camc) than expected ($max_exp)", $string)
    if (($max_exp > 0) && ($camc > $max_exp));
  return("For \'$type\' ($id), found a very small amount of \"$name\" ($camc) for a \"$type\"", $string)
    if (($max_exp == 0) && ($camc < 3));

  if (($type eq $ok_types[1]) || ($type eq $ok_types[2])) {
    # Confirm that there is one "target_training"
    MMisc::error_quit("For \'$type\' ($id), we need one \'sffn\' to be the \'$tt_keys[3]\', found none")
        if (! exists $self->{tracking_trials}{$id}{$tt_keys[3]});
  }

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

  my $f="camid";
  return("Could not find \'$f\'") if (! exists $res{$f});
  my $camid = $res{$f};
  return("For \"$tt_id\", there is already one definition of this \"$f\" ($camid)")
    if (exists $self->{tt_types}{$tt_type}{$tt_id}{$ttp_keys[4]}{$camid});

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
  $self->{tt_types}{$tt_type}{$tt_id}{$ttp_keys[4]}{$camid}++;
  $self->{tt_sffn}{$sffn}{$tt_id}++;
  $tt_params{$ttp_keys[2]} = $txml 
    if (! MMisc::is_blank($txml));
  $tt_params{$ttp_keys[3]} = $targt 
    if (! MMisc::is_blank($targt));
  $tt_params{$ttp_keys[4]} = $camid;

  ## Clean up string
  return("Could not remove the \'$name\' tag, aborting")
    if (! MtXML::remove_xml_tags($name, \$string));  

  ## Get DCR & DCF
  my  ($err, $dcf) = $self->_get_dcfs(\$string, $tt_fs);
  return("While looking for DCFs in \"$name\" [$tt_id / $sffn] : $err")
    if (! MMisc::is_blank($err));
  my ($err, @dcrs) = $self->_get_dcrs(\$string, $tt_fs);
  return("While looking for DCRs in \"$name\" [$tt_id / $sffn] : $err")
    if (! MMisc::is_blank($err));
  return("Leftover data when processing \"$name\" [$sffn] : $string")
    if (! MMisc::is_blank($string));

  # Add DCF
  $tt_params{$ttp_keys[1]} = $dcf if (! MMisc::is_blank($dcf));
  # And DCR
  @{$tt_params{$ttp_keys[0]}} = @dcrs
      if (scalar @dcrs > 0);

  # Set parameters
  %{$self->{tracking_trials}{$tt_id}{$tt_keys[2]}{$sffn}} = %tt_params;

  return("", $sffn, $targt);
}

#####

sub _get_dcfs {
  my ($self, $rstr, $gfs) = @_;

  my $name = $ttp_keys[1];
  # Only 1x DCF entry
  my $sec = MtXML::get_named_xml_section($name, $rstr, $default_error_value);
  return("", undef) if ($sec eq $default_error_value); # No DCF

  my ($err, %res) = MtXML::get_inline_xml_attributes($name, $sec);
  return($err) if (! MMisc::is_blank($err));

  my $f="framespan";
  return("Could not find \'$f\'") if (! exists $res{$f});
  my $fs = $res{$f};
  my ($err, $fs) = &__validate_fs($fs);
  return($err) if (! MMisc::is_blank($err));
  my ($err) = &__fully_within($fs, $gfs);
  return($err) if (! MMisc::is_blank($err));

  return("", $fs);
}

#####

sub _get_dcr_core {  	 
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

sub _get_dcrs {
  my ($self, $rstr, $gfs) = @_;

  my $name = $ttp_keys[0];
  # Multiple DCR entry
  my ($err, %res) = &_get_dcr_core($rstr, $gfs, $name);
  return($err) if (! MMisc::is_blank($err));

  my @out = ();
  foreach my $fs (keys %res) {
    my $t = $res{$fs};
    return("In \"$name\", found no content")
      if (MMisc::is_blank($t));
    
    my ($err, %tmp) = &_confirm_dcr_bbox($t, $fs);
    return($err) if (! MMisc::is_blank($err));
    
    # We want the DCR array to contain a list of hash of hash.
    # - the "list" allow for separation of each separate "PERSON" to be created
    # - the first hash is mainly to have an easy access to the global framespan
    #   covered by this DCR
    # - the second level hash is the DCR represented in a form that can directly
    #   be used by the 'create_DCR' function
    push @out, { $fs => { %tmp } };
  }

  return("", @out);
}

#####

sub _confirm_dcr_bbox {
  my ($str, $gfs) = @_;

  my %out = ();
  my $prevfs = "";
  my $name = "bbox";
  my $cont = 1;
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
    foreach $f ("x", "y", "width", "height") {
      return("Could not find \'$f\'") if (! exists $res{$f});
      push @tmp, $res{$f};
    }

    @{$out{$fs}} = @tmp;
  }
  return("\"$prevfs\" does not cover all of \"$gfs\"") if ($prevfs ne $gfs);
  return("Leftover elements in string ($str)") if (! MMisc::is_blank($str));
  return("Found no bbox") if (scalar(keys %out) == 0);

  return("", %out);
}

############################################################

sub is_sffn_in_ttid {
  my ($self, $ttid, $sffn) = @_;

  return(0) if ($self->error());

  return(0) if (! exists $self->{tt_sffn}{$sffn}{$ttid});

  return(1);
}

##########

sub get_ttid_list_for_sffn {
  my ($self, $sffn) = @_;
  
  my @out = ();
  return(@out) if ($self->error());

  return(@out) if (! exists $self->{tt_sffn}{$sffn});

  @out = keys %{$self->{tt_sffn}{$sffn}};

  return(@out);
}

##########

sub get_ttid_type {
  my ($self, $ttid) = @_;

  return(undef) if ($self->error());

  return($self->_set_errormsg_and_return("No \"$ttid\" \'tracking_trial\'", undef))
    if (! exists $self->{tracking_trials}{$ttid});

  return($self->{tracking_trials}{$ttid}{$tt_keys[1]});
}

##########

sub get_ttid_evaluate {
  my ($self, $ttid) = @_;

  return($self->_set_error_and_return_scalar("Requested TTID ($ttid) not present in ECF", undef))
    if (! $self->is_ttid_in($ttid));

  return($self->{tracking_trials}{$ttid}{$tt_keys[0]});
}

#####

sub get_ttid_sffn_evaluate {
  my ($self, $ttid, $sffn) = @_;

  return(undef) if ($self->error());

  return($self->_set_error_and_return_scalar("Tracking Trial ($ttid) and sourcefile ($sffn) not present", undef))
    if (! $self->is_sffn_in_ttid($ttid, $sffn));

  return($self->_set_error_and_return_scalar("Internal Error: " . $tt_keys[0] . " for Tracking Trial ($ttid) and sourcefile ($sffn) not present", undef))
    if (! exists $self->{tracking_trials}{$ttid}{$tt_keys[0]});

  return($self->{tracking_trials}{$ttid}{$tt_keys[0]});
}

##########

sub _get_ttid_sffn_dcrf {
  my ($self, $ttid, $sffn, $key) = @_;
  
  return(undef) if ($self->error());

  return($self->_set_error_and_return_scalar("Tracking Trial ($ttid) and sourcefile ($sffn) not present", undef))
    if (! $self->is_sffn_in_ttid($ttid, $sffn));

  return($self->_set_error_and_return_scalar("Internal Error: $key for Tracking Trial ($ttid) and sourcefile ($sffn) not present", undef))
    if (! exists $self->{tracking_trials}{$ttid}{$tt_keys[2]}{$sffn});

  return(undef)
    if (! exists $self->{tracking_trials}{$ttid}{$tt_keys[2]}{$sffn}{$key});

  return($self->{tracking_trials}{$ttid}{$tt_keys[2]}{$sffn}{$key});
}

#####

sub get_ttid_sffn_dcr {
  my ($self, $ttid, $sffn) = @_;
  return($self->_get_ttid_sffn_dcrf($ttid, $sffn, $ttp_keys[0]));
}

#####

sub get_ttid_sffn_dcf {
  my ($self, $ttid, $sffn) = @_;
  return($self->_get_ttid_sffn_dcrf($ttid, $sffn, $ttp_keys[1]));
}

##########

sub get_ttid_expected_path_base {
  my ($self, $ttid) = @_;

  return(undef) if (! $self->is_ttid_in($ttid));

  my ($out) = $self->get_ttid_type($ttid);
  $out .= "/$ttid";

  return($out);
}

#####  

sub get_sffn_ttid_expected_path_base {
  my ($self, $sffn, $ttid, $isgtf) = @_;

  return(undef) if (! $self->is_sffn_in_ttid($ttid, $sffn));

  my ($out) = $self->get_ttid_type($ttid);
  $out .= "/$ttid/$sffn";
  
  return($out) if (! defined $isgtf);

  return("$out/GTF") if ($isgtf);

  return("$out/SYS");
}

#####

sub get_sffn_ttid_expected_XML_filename {
  my ($self, $sffn, $ttid, $isgtf, $bd) = @_;

  return(undef) if (! defined $isgtf);

  my $dd = $self->get_sffn_ttid_expected_path_base($sffn, $ttid, $isgtf);
  return(undef) if (! defined $dd);

  my $res = "";
  $res .= "$bd/" if (defined $bd);
  $res .= "$dd/$sffn.xml";

  return($res);
}

####################

sub get_ttid_list {
  my ($self) = @_;

  my @ttl = ();

  return(@ttl) if ($self->error());

  @ttl = keys %{$self->{tracking_trials}};

  return(@ttl);
}

#####

sub is_ttid_in {
  my ($self, $ttid) = @_;

  return(0) if ($self->error());

  return(1) if (exists $self->{tracking_trials}{$ttid});

  return(0);
}

#####

sub get_sffn_list_for_ttid {
  my ($self, $ttid) = @_;

  my @out = ();

  return(@out) if ($self->error());

  return($self->_set_error_and_return_array("Requested \'ttid\' ($ttid) not found", @out))
    if (! exists $self->{tracking_trials}{$ttid});

  @out = keys %{$self->{tracking_trials}{$ttid}{$tt_keys[2]}};

  return(@out);
}

##########

sub get_camid_from_ttid_sffn {
  my ($self, $rttid, $sffn) = @_;

  return($self->_set_error_and_return_scalar("Could not find \'camid\' for \'ttid\' ($rttid) and \'sffn\' ($sffn)", ""))
    if (! exists $self->{tracking_trials}{$rttid}{$tt_keys[2]}{$sffn}{$ttp_keys[4]});

  return($self->{tracking_trials}{$rttid}{$tt_keys[2]}{$sffn}{$ttp_keys[4]});
}

#####

sub get_ttid_primary_camid {
  my ($self, $rttid) = @_;

  return($self->_set_error_and_return_scalar("Could not find primary \'camid\' for \'ttid\' ($rttid)", ""))
    if (! exists $self->{tracking_trials}{$rttid}{$tt_keys[3]});

  my $sffn = $self->{tracking_trials}{$rttid}{$tt_keys[3]};

  return($self->get_camid_from_ttid_sffn($rttid, $sffn));
}

##########

sub is_ttid_of_type {
  my ($self, $rttid, $rtype) = @_;

  return(0) if ($self->error());

  my $type = $self->ok_type($rtype);
  return(0) if ($self->error());

  my $lt = $self->get_ttid_type($rttid);
  return(0) if ($self->error());

  return(1) if ($lt eq $type);

  return(0);
}

##########

sub ok_type {
  my ($self, $type) = @_;

  return("") if ($self->error());

  return($self->_set_errormsg_and_return("Empty type", ""))
    if (MMisc::is_blank($type));

  foreach my $t (@ok_types) {
    return($t) if ($t =~ m%^$type$%i);
  }

  $self->_set_errormsg("Unknown type ($type)");
  return("");
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errormsg}->set_errormsg($txt);
}

#####

sub get_errormsg {
  my ($self) = @_;
  return($self->{errormsg}->errormsg());
}

#####

sub error {
  my ($self) = @_;
  return($self->{errormsg}->error());
}

#####

sub _set_error_and_return_array {
  my $self = shift @_;
  my $errormsg = shift @_;
  $self->_set_errormsg($errormsg);
  return(@_);
}

#####

sub _set_error_and_return_scalar {
  $_[0]->_set_errormsg($_[1]);
  return($_[2]);
}

#####

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
