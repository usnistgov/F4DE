package TrecVid08Observation;

# $Id$

use strict;
use ViperFramespan;
use TrecVid08ViperFile;

use Data::Dumper;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08Observation.pm Version: $version";

my @ok_events;
my %hasharray_inline_attributes;
my %hash_objects_attributes_types_dynamic;

## Constructor
sub new {
  my ($class) = shift @_;

  my $errormsg = "";

  $errormsg .= "TrecVid08Observation's new does not accept any parameter. "
    if (scalar @_ > 0);

  my $tmp = &_get_TrecVid08ViperFile_infos();
  $errormsg .= "Could not obtain the list authorized events ($tmp). "
    if ($tmp !~ m%^\s*$%);

  $errormsg = &_set_errormsg_txt("", $errormsg);

  my $self =
    {
     eventtype   => "",
     id          => -1,
     filename    => "", # The 'sourcefile' referenced file
     xmlfilename => "", # The xml file that described this observation
     framespan   => undef, # ViperFramespan object
     isgtf       => -1,
     ofi         => undef, # hash ref / Other File Information
     DetectionScore      => -1, # float
     DetectionDecision   => -1, # binary
     BoundingBox => undef, # hash ref (with "real" ViperFramespan this time)
     Point       => undef, # hash ref (with "real" ViperFramespan this time)
     validated   => 0, # To confirm all the values required are set
     errormsg    => $errormsg,
    };

  bless $self;
  return($self);
}

#####

sub _get_TrecVid08ViperFile_infos {
  my $dummy = new TrecVid08ViperFile();
  @ok_events = $dummy->get_full_events_list();
  %hasharray_inline_attributes = $dummy->_get_hasharray_inline_attributes();
  %hash_objects_attributes_types_dynamic = $dummy->_get_hash_objects_attributes_types_dynamic();
  return($dummy->get_errormsg());
}

##########

sub get_version {
  my ($self) = @_;

  return($versionid);
}

########## 'errormsg'

sub _set_errormsg_txt {
  my ($oh, $add) = @_;

  my $txt = "$oh$add";

  $txt =~ s%\[TrecVid08Observation\]\s+%%g;

  return("") if ($txt =~ m%^\s*$%);

  $txt = "[TrecVid08Observation] $txt";

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

  return(1) if ($self->get_errormsg() !~ m%^\s*$%);

  return(0);
}

########## 'eventtype'

sub set_eventtype {
  my ($self, $etype) = @_;

  return(0) if ($self->error());

  if (! grep(m%^$etype$%, @ok_events) ) {
    $self->_set_errormsg("Type given ($etype) is not part of the authorized events list");
    return(0);
  }
  
  $self->{eventtype} = $etype;
  return(1);
}

#####

sub _is_eventtype_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{eventtype} !~ m%^\s*$%);

  return(0);
}

#####

sub get_eventtype {
  my ($self) = @_;

  return(-1) if ($self->error());
  if (! $self->_is_eventtype_set()) {
    $self->_set_errormsg("\'eventtype\' not set");
    return(0);
  }

  return($self->{eventtype});
}

########## 'id'

sub set_id {
  my ($self, $id) = @_;

  return(0) if ($self->error());

  if ($id < 0) {
    $self->_set_errormsg("\'id\' can not be negative");
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
    $self->_set_errormsg("\'id\' not set");
    return(0);
  }
  return($self->{id});
}

########## 'filename'

sub set_filename {
  my ($self, $fname) = @_;

  return(0) if ($self->error());

  if ($fname =~ m%^\s*$%) {
    $self->_set_errormsg("Empty \'filename\'");
    return(0);
  }
  
  $self->{filename} = $fname;
  return(1);
}

#####

sub _is_filename_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{filename} !~ m%^\s*$%);

  return(0);
}

#####

sub get_filename {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_filename_set()) {
    $self->_set_errormsg("\'filename\' not set");
    return(0);
  }
  return($self->{filename});
}

########## 'xmlfilename'

sub set_xmlfilename {
  my ($self, $fname) = @_;

  return(0) if ($self->error());

  if ($fname =~ m%^\s*$%) {
    $self->_set_errormsg("Empty \'xmlfilename\'");
    return(0);
  }
  
  $self->{xmlfilename} = $fname;
  return(1);
}

#####

sub _is_xmlfilename_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{xmlfilename} !~ m%^\s*$%);

  return(0);
}

#####

sub get_xmlfilename {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_xmlfilename_set()) {
    $self->_set_errormsg("\'xmlfilename\' not set");
    return(0);
  }
  return($self->{xmlfilename});
}

########## 'framespan'

sub set_framespan {
  my ($self, $fs_fs) = @_;

  return(0) if ($self->error());

  if ( (! defined $fs_fs) || (! $fs_fs->_is_value_set() ) ) {
    $self->_set_errormsg("Empty \'framespan\'");
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

  return(1) if ($self->{framespan}->_is_value_set());

  return(0);
}

#####

sub get_framespan {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_framespan_set()) {
    $self->_set_errormsg("\'framespan\' not set");
    return(0);
  }
  return($self->{framespan});
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

  return(-1) if ($self->error());

  if (! $self->_is_isgtf_set()) {
    $self->_set_errormsg("\'isgtf\' not set");
    return(0);
  }
  return($self->{isgtf});
}

########## 'ofi'

sub set_ofi {
  my ($self, %entries) = @_;

  return(0) if ($self->error());

  if (scalar %entries == 0) {
    $self->_set_errormsg("Empty \'ofi\'");
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

  return(-1) if ($self->error());

  if (! $self->_is_ofi_set()) {
    $self->_set_errormsg("\'ofi\' not set");
    return(0);
  }
  
  my $rofi = $self->{ofi};

  my %res = %{$rofi};

  return(%res);
}

########## 'DetectionScore'

sub set_DetectionScore {
  my ($self, $DetectionScore) = @_;

  return(0) if ($self->error());

  if ($DetectionScore < 0) {
    $self->_set_errormsg("\'DetectionScore\' can not be negative");
    return(0);
  }
  
  $self->{DetectionScore} = $DetectionScore;
  return(1);
}

#####

sub _is_DetectionScore_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{DetectionScore} != -1);

  return(0);
}

#####

sub get_DetectionScore {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_DetectionScore_set()) {
    $self->_set_errormsg("\'DetectionScore\' not set");
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
  } elsif (($DetectionDecision != 0) || ($DetectionDecision != 1)) {
    $self->_set_errormsg("Strange \'DetectionDecision\' value ($DetectionDecision)");
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

  return(-1) if ($self->error());

  if (! $self->_is_DetectionDecision_set()) {
    $self->_set_errormsg("\'DetectionDecision\' not set");
    return(0);
  }
  return($self->{DetectionDecision});
}

########## 'BoundingBox'

sub set_BoundingBox {
  my ($self, %entries) = @_;

  return(0) if ($self->error());

  if (scalar %entries == 0) {
    $self->_set_errormsg("Empty \'BoundingBox\'");
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

  return(-1) if ($self->error());

  if (! $self->_is_BoundingBox_set()) {
    $self->_set_errormsg("\'BoundingBox\' not set");
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
    $self->_set_errormsg("Empty \'Point\'");
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

  return(-1) if ($self->error());

  if (! $self->_is_Point_set()) {
    $self->_set_errormsg("\'Point\' not set");
    return(0);
  }

  my $rp = $self->{Point};

  my %res = %{$rp};

  return(%res);
}

##########

sub _get_1keyhash_content {
  my %tmp = @_; # Only one key in this hash, return its content

  my @keys = keys %tmp;

  return ("Found more than 1 key in the hash", ())
    if (scalar @keys > 1);
  return ("Found no key in the hash", ())
    if (scalar @keys > 1);

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
  my ($self) = shift @_;
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
  } else{
    $self->_set_errormsg("WEIRD: Could not select a choice in \'set_selected\' ($choice)");
    return(0);
  }
}

#####

sub set_selected {
  my ($self) = shift @_;
  my $choice = shift @_;

  return(0) if ($self->error());

  my @ok_choices = &_get_set_selected_ok_choices();
  if (! grep(m%^$choice$%, @ok_choices)) {
    $self->_set_errormsg("In \'set_selected\', choice ($choice) is not recognized");
    return(0);
  }

  # We have to worry about the "dynamic" and "number of inline attributes"

  if (! exists $hash_objects_attributes_types_dynamic{$choice}) {
    $self->_set_errormsg("In \'set_selected\', can not confirm the dynmaic status of choice ($choice)");
    return(0);
  }
  my $isd = $hash_objects_attributes_types_dynamic{$choice};

  if (! exists $hasharray_inline_attributes{$choice}) {
    $self->_set_errormsg("In \'set_selected\', can not confirm the number of inline attributes of choice ($choice)");
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
    if ($errtxt !~ m%^\s*$%) {
      $self->_set_errormsg("In \'set_selected\', problem while extracting the one hash element for choice ($choice) ($errtxt)");
      return(0);
    }
    if (! exists $oneelt{$self->key_attr_content()}) {
      $self->_set_errormsg("WEIRD: In \'set_selected\' can not obtain the \'content\' key");
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

########################################

sub _is_validated {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{validated} == 1);

  return(0);
}

#####

sub validate {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->_is_validated());
  # Confirm all is set in the observation
  
  # Required types:
  if (! $self->_is_eventtype_set()) {
    $self->set_errormsg("While \'validate\': \'eventtype\' not set");
    return(0);
  }
  if (! $self->_is_id_set()) {
    $self->set_errormsg("While \'validate\': \'id\' not set");
    return(0);
  }
  if (! $self->_is_filename_set()) {
    $self->set_errormsg("While \'validate\': \'filename\' not set");
    return(0);
  }
  if (! $self->_is_xmlfilename_set()) {
    $self->set_errormsg("While \'validate\': \'xmlfilename\' not set");
    return(0);
  }
  if (! $self->_is_framespan_set()) {
    $self->set_errormsg("While \'validate\': \'framespan\' not set");
    return(0);
  }
   if (! $self->_is_isgtf_set()) {
    $self->set_errormsg("While \'validate\': \'isgtf\' not set");
    return(0);
  }
  if (! $self->_is_ofi_set()) {
    $self->set_errormsg("While \'validate\': \'ofi\' not set");
    return(0);
  }

  # For non GTF
  if (! $self->get_isgtf) { 
    if (! $self->_is_DetectionScore_set()) {
      $self->_set_errormsg("While \'validate\': \'DetectionScore\' not set (and observation is not a GTF)");
      return(0);
    }
    if (! $self->_is_DetectionDecision_set()) {
      $self->_set_errormsg("While \'validate\': \'DetectionDecision\' not set (and observation is not a GTF)");
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

  return Dumper(\$self);
}

############################################################
1;
