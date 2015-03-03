package TrecVid08ECF;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 ECF XML Handler
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08ECF.pm" is an experimental system.
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

my $versionid = "TrecVid08ECF.pm Version: $version";

########################################

# Required XSD files
my @xsdfilesl = ( "TrecVid08-ecf.xsd" );
# Default values to compare against (constant values)
my $default_error_value = "default_error_value";

my @required_excerpt_tags = ("filename", "begin", "duration"); # Order is important
my @optional_excerpt_tags = ("sample_rate", "language", "source_type", ); # Order is important here too
my $key_fs = "key_fs";
my $key_ots = "key_ots";

## Constructor
sub new {
  my ($class) = shift @_;

  my $errortxt = (scalar @_ > 0) ? "TrecVid08ECF does not accept parameters" : "";

  my $xmllintobj = new xmllintHelper();
  $xmllintobj->set_xsdfilesl(@xsdfilesl);
  $errortxt .= $xmllintobj->get_errormsg() if ($xmllintobj->error());

  my $errormsg = new MErrorH("TrecVid08ECF");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     file           => "",
     xmllintobj     => $xmllintobj,
     duration       => 0,
     computed_duration => 0,
     dfps           => -1,
     fhash          => undef,
     validated      => 0,       # To confirm file was validated
     errormsg       => $errormsg,
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

########## 'default_fps'

sub set_default_fps {
  my ($self, $fps) = @_;

  return(0) if ($self->error());

  # use ViperFramespan to create the accepted value
  my $fs_tmp = new ViperFramespan();
  if (! $fs_tmp->set_fps($fps)) {
    $self->_set_errormsg("While setting the file fps ($fps) error (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }
  # And get it back
  my $nfps = $fs_tmp->get_fps();
  if ($fs_tmp->error()) {
    $self->_set_errormsg("While obtaining back the default_fps ($fps) error (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  $self->{dfps} = $nfps;
  return(1);
}

#####

sub is_default_fps_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(0) if ($self->{dfps} == -1);

  return(1);
}

#####

sub get_default_fps {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_default_fps_set()) {
    $self->_set_errormsg("\'default_fps\' is not set");
    return(0);
  }

  return($self->{dfps});
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

  if (! $self->is_default_fps_set()) {
    $self->_set_errormsg("Can not validate unless a \'default_fps\' is set");
    return(0);
  }

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
  ($res, $bigstring) = $self->_excerpt_list_processor($bigstring);
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }

  # Sanity check
  return(0) if (! $self->_file_fs_sanity_check());
  
  $self->{validated} = 1;
  return(1);
}

##########

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

  # Get the required source_signal_duration data (in the header usualy)
  my $name = "source_signal_duration";
  my $ssd = MtXML::get_named_xml_section($name, \$bigstring, $default_error_value);
  return("Could not find the \'$name\' required data, aborting", $bigstring)
    if ($ssd eq $default_error_value);
  return("Could not remvoe the \'$name\' tag, aborting", $bigstring)
    if (! MtXML::remove_xml_tags($name, \$ssd));
  $self->{duration}=$ssd;

  # Get the optional version informaion (in the header usualy)
  $name = "version";
  my $version = MtXML::get_named_xml_section($name, \$bigstring, $default_error_value);
  if ($version ne $default_error_value) {
    return("Could not remvoe the \'$name\' tag, aborting", $bigstring)
      if (! MtXML::remove_xml_tags($name, \$version));
    $self->{version}=$version;
  }

  # At this point, all we ought to have left is the '<excerpt_list>' content
  $name = "excerpt_list";
  return("After initial cleanup, we found more than just viper \'excerpt_list\', aborting", $bigstring)
    if (! ( ($bigstring =~ m%^\s*\<excerpt_list>%is) 
            && ($bigstring =~ m%\<\/excerpt_list\>\s*$%is) ) );

  return("", $bigstring);
}

#####

sub _excerpt_list_processor {
  my ($self, $string) = @_;

  # Remove the excerpt_list header/trailer tags
  my $name = "excerpt_list";
  return("Could not remvoe the \'$name\' tag, aborting", $string)
    if (! MtXML::remove_xml_tags($name, \$string));  

  ##### Process all that is left in the string (should only be excerpts)
  $name = "excerpt";
  while (! MMisc::is_blank($string)) {
    my $sec = MtXML::get_named_xml_section($name, \$string, $default_error_value);
    return("Found some content other than \'$name\'", $string)
      if ($sec eq $default_error_value);

    my $err = $self->_excerpt_processor($sec);
    return("Problem extracting \'$name\' data ($err). ", $string)
      if (! MMisc::is_blank($err));
  }

  return("", "");
}

#####

sub _excerpt_processor {
  my ($self, $string) = @_;

  my %tmp = ();

  # Remove the excerpt header/trailer tags
  my $name = "excerpt";
  return("Could not remvoe the \'$name\' tag, aborting", $string)
    if (! MtXML::remove_xml_tags($name, \$string));  

  foreach my $tag (@required_excerpt_tags) {
    my ($err, $value) = &_get_named_xml_value($tag, \$string);
    return("Could not find required \'excerpt\' tag ($tag), aborting", $value)
      if (! MMisc::is_blank($err)); 
    $tmp{$tag} = $value;
  }

  foreach my $tag (@optional_excerpt_tags) {
    my ($err, $value) = &_get_named_xml_value($tag, \$string);
    next if (! MMisc::is_blank($err)); 
    $tmp{$tag} = $value;
  }
  #  print "[*]", MMisc::get_sorted_MemDump(\%tmp), "\n";

  my %fhash = ();
  %fhash = $self->_get_fhash() if ($self->_is_fhash_set());
  
  my @tmpa = ();
  foreach my $tag (@required_excerpt_tags) {
    push @tmpa, $tmp{$tag};
  }
  my ($fn, $beg_ts, $duration_ts) = @tmpa;
  my $end_ts = $beg_ts + $duration_ts;

  my @tmpa = ();
  foreach my $tag (@optional_excerpt_tags) {
    if (! exists $tmp{$tag}) {
      push @tmpa, $default_error_value;
    } else {
      push @tmpa, $tmp{$tag};
    }
  }
  my ($fps, $lang, $stype) = @tmpa;

  $fps = $self->get_default_fps() if ($fps eq $default_error_value);

  my $fs_tmp = new ViperFramespan();
  $fs_tmp->set_fps($fps);
  return("Problem working with the 'fps' (" . $fs_tmp->get_errormsg() . ")")
    if ($fs_tmp->error());

  my $beg = $fs_tmp->ts_to_frame($beg_ts);
  my $end = $fs_tmp->end_ts_to_frame($end_ts);
  return("Problem converting ts to frame (" . $fs_tmp->get_errormsg() . ")")
    if ($fs_tmp->error());

  #  print "[$beg / $beg_ts -> $end / $end_ts]\n";
  
  $fs_tmp->set_value_beg_end($beg, $end);
  return("Problem setting a ViperFramespan (" . $fs_tmp->get_errormsg() . ")")
    if ($fs_tmp->error());
  
  my $terr = "";
  if (exists $fhash{$fn}) {
    # Previous values set, confirm it is the same
    my $k = $optional_excerpt_tags[0]; # fps
    if (exists $fhash{$fn}{$k}) {
      my $tv = $fhash{$fn}{$k};
      $terr .= "A previous \'$k\' value existed ($tv) for this 'excerpt' (file: $fn), and the value differs from the new found value ($fps). "
        if ($fps != $tv);
    }
      
    $k = $optional_excerpt_tags[1]; # language
    if ((exists $fhash{$fn}{$k}) && ($lang ne $default_error_value)) {
      my $tv = $fhash{$fn}{$k};
      $terr .= "A previous \'$k\' value existed ($tv) for this 'excerpt' (file: $fn), and the value differs from the new found value ($lang). "
        if ($lang != $tv);
    }

    $k = $optional_excerpt_tags[2]; # source type
    if ((exists $fhash{$fn}{$k}) && ($stype ne $default_error_value)) {
      my $tv = $fhash{$fn}{$k};
      $terr .= "A previous \'$k\' value existed ($tv) for this 'excerpt' (file: $fn), and the value differs from the new found value ($stype). "
        if ($stype != $tv);
    }
  }
  return($terr) if (! MMisc::is_blank($terr));

  # Now simply fill the %fhash
  my $k = $optional_excerpt_tags[0]; # fps
  $fhash{$fn}{$k} = $fps;
  $k = $optional_excerpt_tags[1]; # language
  $fhash{$fn}{$k} = $lang if ($lang ne $default_error_value);
  $k = $optional_excerpt_tags[2]; # source_type
  $fhash{$fn}{$k} = $stype if ($stype ne $default_error_value);
  push @{$fhash{$fn}{$key_fs}}, $fs_tmp; # the framespan itself
  push @{$fhash{$fn}{$key_ots}}, "[$beg_ts : $end_ts]"; # the original ts

  return("Problem adding the 'excerpt' information to the object")
    if (! $self->_set_fhash(%fhash));

  $self->{'computed_duration'} += $duration_ts;
  
  return("");
}

#####

sub _get_named_xml_value {
  my ($name, $rstring) = @_;

  my $sec = MtXML::get_named_xml_section($name, $rstring, $default_error_value);
  return("Could not find \'$name\' data", $$rstring)
    if ($sec eq $default_error_value);

  return("Could not remove the \'$name\' tag, aborting", $$rstring)
    if (! MtXML::remove_xml_tags($name, \$sec));  
  
  return("", $sec);
}

########## 'framespan' sanity check

sub _file_fs_sanity_check {
  my ($self) = @_;

  return(0) if ($self->error());

  my %fhash = $self->_get_fhash();
  return(0) if ($self->error());

  my $txt = "";
  foreach my $fk (sort keys %fhash) {
    my @a = @{$fhash{$fk}{$key_fs}};
    my $la = scalar @a;
    next if ($la < 2); # We can only compare if there are at least 2 elements

    for (my $i = 0; $i < $la; $i++) {
      for (my $j = $i + 1; $j < $la; $j++) {
        my $fs1 = $a[$i];
        my $fs2 = $a[$j];
        
        my $v = $fs1->check_if_overlap($fs2);
        if ($fs1->error()) {
          $self->_set_errormsg("Error checking fs overlap (" . $fs1->get_errormsg() . ")");
          return(0);
        }
        
        if ($v) {
          my ($b1, $e1) = $fs1->get_beg_end_ts();
          my ($b2, $e2) = $fs2->get_beg_end_ts();
          if ($fs1->error()) {
            $self->_set_errormsg("Error obtaining fs beg and end ts (" . $fs1->get_errormsg() . ")");
            return(0);
          }
          if ($fs2->error()) {
            $self->_set_errormsg("Error obtaining fs beg and end ts (" . $fs2->get_errormsg() . ")");
            return(0);
          }
          $txt .= "Found framespan overlap for file key $fk 's \[$b1:$e1\] and \[$b2:$e2\]. ";
        }

      }
    }
  }

  if (! MMisc::is_blank($txt)) {
    $self->_set_errormsg($txt);
    return(0);
  }

  return(1);
}

########## 'duration', 'version'

sub _get_XXX {
  my ($self, $XXX) = @_;

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only obtain this information from a validated ECF");
    return(0);
  }

  return($self->{$XXX});
}

#####

sub get_duration {
  my ($self) = @_;
  return($self->_get_XXX("duration"));
}

sub get_compduration {
  my ($self) = @_;
  return($self->_get_XXX("computed_duration"));
}


#####

sub get_version {
  my ($self) = @_;
  return($self->_get_XXX("version"));
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
    $self->_set_errormsg("\'fhash\' is not set");
    return(0);
  }

  my $rfhash = $self->{fhash};

  my %res = %{$rfhash};

  return(%res);
}

####################

sub _sptsord {
  my $v = shift @_;

  my ($b, $e) = ($v =~ m%\[\s*([\d\.]+)\s*\:\s*([\d\.]+)\s*\]%);

  return($b, $e);
}

#####

sub _tsord {
  my $t1 = $a;
  my $t2 = $b;

  my ($b1, $e1) = &_sptsord($t1);
  my ($b2, $e2) = &_sptsord($t2);

  return ($e1 <=> $e2)
    if ($b1 == $b2);
  return($b1 <=> $b2);
}

#####

sub txt_summary {
  my ($self) = @_;
  
  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only obtain a summary from a validated ECF");
    return("");
  }

  my $txt = "";

  my $fn = $self->get_file();
  return("") if ($self->error());
  $txt .= " - source file: $fn\n";

  my $d = $self->get_duration();
  return("") if ($self->error());
  $txt .= " - Duration: $d\n";

  my $cd = $self->get_compduration();
  return("") if ($self->error());
  $txt .= " !! Computed Duration differs: $cd\n" if ($d != $cd);

  my %fhash = $self->_get_fhash();
  return("") if ($self->error());

  foreach my $fk (sort keys %fhash) {
    my @a = @{$fhash{$fk}{$key_ots}};
    $txt .= " - File key: $fk | Time range(s): " . join(" ", sort _tsord @a) . "\n";
  }

  return($txt);
}

#####

sub _display {
  my ($self, $pretext) = @_;

  print "$pretext" if (! MMisc::is_blank($pretext));
  print MMisc::get_sorted_MemDump(\$self);
}

########################################

# Access functions

sub is_filename_in {
  my ($self, $fn) = @_;

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'is_filename_in\' on a validated file");
    return(0);
  }

  my %fhash = $self->_get_fhash();
  return(0) if ($self->error());

  return(1) if (exists $fhash{$fn});

  return(0);
}

#####

sub get_file_ViperFramespans {
  my ($self, $fn) = @_;

  my @res = ();

  return(@res) if (! $self->is_filename_in($fn));

  my %fhash = $self->_get_fhash();
  return(@res) if ($self->error());
  
  push @res, @{$fhash{$fn}{$key_fs}};

  return(@res);
}

#####

sub get_files_list {
  my ($self) = @_;

  my @res = ();

  return(@res) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'get_files_list\' on a validated file");
    return(@res);
  }

  my %fhash = $self->_get_fhash();
  return(@res) if ($self->error());

  @res = keys %fhash;
  return(@res);
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
