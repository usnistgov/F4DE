package AdjudicationViPERfile;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# Adjudication ViPER File
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AdjudicationViPERfile.pm" is an experimental system.
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

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "AdjudicationViPERfile.pm Version: $version";

# "TrecVid08ViperFile.pm" (part of this program sources)
use TrecVid08ViperFile;

# "TrecVid08Observation.pm" (part of this program sources)
use TrecVid08Observation;

# "ViperFramespan.pm" (part of this program sources)
use ViperFramespan;

# "MErrorH.pm" (part of this program sources)
use MErrorH;

# "MMisc.pm" (part of this program sources)
use MMisc;

########################################

my $vf = undef;

my $key_se_Undefined   = TrecVid08ViperFile::get_Undefined_subeventkey();
my $key_se_Mapped      = TrecVid08ViperFile::get_Mapped_subeventkey();
my $key_se_UnmappedRef = TrecVid08ViperFile::get_UnmappedRef_subeventkey();
my $key_se_UnmappedSys = TrecVid08ViperFile::get_UnmappedSys_subeventkey();
my @xtra_tc_list     = TrecVid08ViperFile::get_array_tc_list();


## Constructor
sub new {
  my ($class) = shift @_;

  my $errortxt = (scalar @_ > 0) ? "TrecVid08ViperFile does not accept parameters" : "";

  $vf = new TrecVid08ViperFile();
  $errortxt .= ($vf->error()) ? "Problem creating ViperFile (" . $vf->get_errormsg() . ")" : "";

  my $errormsg = new MErrorH("AdjudicationViPERfile");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     sffn           => "",
     numframes      => 0,
     origstartframe => 1,
     framerate      => "1.0",
     hframesize     => undef,
     vframesize     => undef,
     sourcetype     => undef,
     ##
     annot_key      => "",
     events         => undef,
     ## 
     Agree          => undef,
     UnmapAnnot     => undef,
     Ref            => undef,
     ##
     maxAgree       => 0,
     maxAgreeDS     => 0,
     ##
     errormsg       => $errormsg,
    };

  bless $self;
  return($self);
}

##########

sub is_sffn_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{sffn}));

  return(0);
}

#####

sub set_sffn {
  my $self = shift @_;
  my $sffn = MMisc::iuv(shift @_, "");

  return(0) if ($self->error());

  if (MMisc::is_blank($sffn)) {
    $self->_set_errormsg("Can not set an empty \'sffn\'");
    return(0);
  }

  $self->{sffn} = $sffn;

  return(1);
}

#####

sub get_sffn {
  my $self = shift @_;

  return(0) if ($self->error());

  if (! $self->is_sffn_set()) {
    $self->_set_errormsg("\'sffn\' not set");
    return(0);
  }

  return($self->{sffn});
}

##########

sub is_numframes_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{numframes} != 0);

  return(0);
}

#####

sub set_numframes {
  my $self = shift @_;
  my $nf = MMisc::iuv(shift @_, 0);

  return(0) if ($self->error());

  if ($nf < 1) {
    $self->_set_errormsg("Can not set a \'numframes\' less than 1");
    return(0);
  }

  $self->{numframes} = $nf;

  return(1);
}

#####

sub get_numframes {
  my $self = shift @_;

  return(0) if ($self->error());

  if (! $self->is_numframes_set()) {
    $self->_set_errormsg("\'numframes\' not set");
    return(0);
  }

  return($self->{numframes});
}

##########

sub set_origstartframe {
  my $self = shift @_;
  my $v = MMisc::iuv(shift @_, 0);

  return(0) if ($self->error());

  if ($v < 1) {
    $self->_set_errormsg("Can not set a \'origstartframe\' less than 1");
    return(0);
  }
    
  $self->{origstartframe} = $v;

  return(1);
}

#####

sub get_origstartframe {
  my $self = shift @_;

  return(0) if ($self->error());

  return($self->{origstartframe});
}

##########

sub is_annot_key_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{annot_key}));

  return(0);
}

#####

sub set_annot_key {
  my $self = shift @_;
  my $annot_key = MMisc::iuv(shift @_, "");

  return(0) if ($self->error());

  if (MMisc::is_blank($annot_key)) {
    $self->_set_errormsg("Can not set an empty \'annotator key\'");
    return(0);
  }

  $self->{annot_key} = $annot_key;

  return(1);
}

#####

sub get_annot_key {
  my $self = shift @_;

  return(0) if ($self->error());

  if (! $self->is_annot_key_set()) {
    $self->_set_errormsg("\'annotator key\' not set");
    return(0);
  }

  return($self->{annot_key});
}

##########

sub setif_maxAgree {
  my ($self, $agc) = @_;
  
  return(0) if ($self->error());
  
  if ($agc >= $self->{maxAgree}) {
    # The equal is important to insure that the DS get changed too
    # in case the agree level is equal to the last max agree level
    $self->{maxAgree} = $agc;
    return(1);
  }

  return(0);
}

#####

sub setif_maxAgreeDS {
  my ($self, $ds) = @_;

  return(0) if ($self->error());

  $self->{maxAgreeDS} = $ds
    if ($ds > $self->{maxAgreeDS});

  return(1);
}

#####

sub get_maxAgree {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{maxAgree});
}

#####

sub get_maxAgreeDS {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{maxAgreeDS});
}

##########

sub _pre_self_tests {
  my ($self) = @_;
  
  return(0) if ($self->error());

  if (! $self->is_annot_key_set()) {
    $self->_set_errormsg("Can not work unless the \'annotator key\' is set");
    return(0);
  }

  if (! $self->is_sffn_set()) {
    $self->_set_errormsg("Can not work unless \'sffn\' is set");
    return(0);
  }

  if (! $self->is_numframes_set()) {
    $self->_set_errormsg("Can not work unless \'numframes\' is set");
    return(0);
  }

  return(1);
}

#####

sub get_align_array_from_obs {
  my ($self, $obs) = @_;

  my @out = ();
  if (! $self->is_annot_key_set()) {
    $self->_set_errormsg("Can not work unless the \'annotator key\' is set");
    return(@out);
  }

  return(@out)
    if (! $obs->is_xtra_set());

  my $ak = $self->get_annot_key();
  my @al = $obs->list_xtra_attributes();
  my @l = grep(m%$ak%, sort @al);
  
  return(@l);
}

#####

sub get_observation_agree_level {
  my ($self, $obs) = @_;

  my @l = $self->get_align_array_from_obs($obs);
  return(0) if ($self->error());

  return(scalar @l);
}

#####

sub extract_trackingcomment_information {
  my ($self, $obs) = @_;

  my $tcv = ($obs->is_trackingcomment_set()) ? $obs->get_trackingcomment_txt() : "";

  my @empty = ();

  return(@empty)
    if (MMisc::is_blank($tcv));

  my @atc = ();
  # We want the "mods add" (to get the added annotator key) and the
  # first added (per file) since mods are added to the end and we 
  # proces in temporal add, "first" and "last" value for a given file
  # have a meaning
  (my $err, @atc) = TrecVid08HelperFunctions::extract_trackingcomment_information($tcv, TrecVid08ViperFile::get_xtra_tc_modsadd(), 1, $self->get_annot_key(), 1);
  if (! MMisc::is_blank($err)) {
    $self->_set_errormsg("While extracting tracking comment information: $err");
    return(@empty);
  }

  return(@atc);
}

#####

sub get_observation_meanDS {
  my ($self, $obs) = @_;

  my $st = $obs->get_eventsubtype();
  if (MMisc::is_blank($st)) {
    $self->_set_errormsg("Events with no subtypes are not valid for Adjudication work");
    return(0);
  }

  if ($st ne $key_se_UnmappedSys) {
    $self->_set_errormsg("Can only compute meanDetectionScore on UnmappedSys observations");
    return(0);
  }

  my @atc = $self->extract_trackingcomment_information($obs);
  return(0) if ($self->error());
  return(0) if (scalar @atc == 0);

  my $detscrsum = 0;
  foreach my $rh (@atc) {
    my $detscr = $$rh{$xtra_tc_list[8]};
    if ($detscr =~ m%^\.%) { $detscr = "0$detscr"; }
    if ($detscr =~ s%^\-\.%%) { $detscr = "-0$detscr"; }

    if (! MMisc::is_float($detscr)) {
      $self->_set_errormsg("Found an UnmappedSys entry without a proper \"DetectionScore\" ($detscr)");
      return(0);
    }
    $detscrsum += $detscr;
  }
  my $meandetscr = $detscrsum / scalar @atc;
  
  return($meandetscr);
}

#####

sub add_tv08obs {
  my ($self, $obs, $osf) = @_;

  if (! $obs->is_validated()) {
    $self->_set_errormsg("Can not add an observation which is not validated");
    return(0);
  }

  if (! $obs->is_eventsubtype_set()) {
    $self->_set_errormsg("Can not add an observation whose \'event subtype\' is not set");
    return(0);
  }
  
  return(0) if (! $self->_pre_self_tests());

  if ($osf != 0) {
    my $tobs = $obs->clone();
    if ($obs->error()) {
      $self->_set_errormsg("Could not clone observation: " . $obs->get_errormsg());
      return(0);
    }

    if ($osf > 0) {
      $tobs->shift_framespan($osf);
      if ($tobs->error()) {
        $self->_set_errormsg("Problem shifting framespan: " . $tobs->get_errormsg());
        return(0);
      }
    } else {
      $tobs->negative_shift_framespan(-$osf);
      if ($tobs->error()) {
        $self->_set_errormsg("Problem negative shifting framespan: " . $tobs->get_errormsg());
        return(0);
      }
    }

    $obs = $tobs;
  }

  my $lsffn = $self->get_sffn();
  my $sffn = $obs->get_filename();
  if ($lsffn ne $sffn) {
    $self->_set_errormsg("Can not add this observation, the sffn differs (obs: $sffn / adj: $lsffn)");
    return(0);
  }

  my $event = $obs->get_eventtype();
  if ($obs->error()) {
    $self->_set_errormsg("Problem obtaining the Observation's Event Type (" . $obs->get_errormsg() . ")");
    return(0);
  }
  # Add event to event list
  $self->{events}{$event}++; # Creates it if it does not exists
  
  my $fs_fs = $obs->get_framespan();
  if ($obs->error()) {
    $self->_set_errormsg("Problem obtaining the Observation's framespan (" . $obs->get_errormsg() . ")");
    return(0);
  }
  my $fs = $fs_fs->get_value();
  if ($fs_fs->error()) {
    $self->_set_errormsg("Problem obtaining the Framespan's value (" . $fs_fs->get_errormsg() . ")");
    return(0);
  }

  my $st = $obs->get_eventsubtype();

  if (MMisc::is_blank($st)) {
    $self->_set_errormsg("Events with no subtypes are not valid for Adjudication work");
    return(0);
  }

  if (($st eq $key_se_Undefined) || ($st eq $key_se_Mapped)) {
    $self->_set_errormsg("\'$key_se_Undefined\' or \'$key_se_Mapped\' Events' subtypes are not valid for Adjudication work");
    return(0);
  }
  
  my @aligna = $self->get_align_array_from_obs($obs);
  return(0) if ($self->error());
  my $alignc = scalar @aligna;
  my $align = ($alignc > 0) ? join(" ", @aligna) : "";


  my @atc = $self->extract_trackingcomment_information($obs);
  return(0) if ($self->error());

  if ($st eq $key_se_UnmappedSys) {
    if (scalar @atc != $alignc) {
      $self->_set_errormsg("Found a different amount of tracking comment (" . scalar @atc . ") comapred to the number of Xtra Attributes ($alignc)");
      return(0);
    }
    if (scalar @atc == 0) {
      $self->_set_errormsg("Found a zero count for tracking comment");
      return(0);
    }
    my ($ag_txt, $id, $ismax) = $self->add_agree($event, $alignc, $align, $fs);
    return(0) if (MMisc::is_blank($ag_txt));
    my $detscrsum = 0;

    foreach my $rh (@atc) {
      my $fs_value = $$rh{$xtra_tc_list[6]};
      my $annot = $$rh{$xtra_tc_list[7]};
      my $detscr = $$rh{$xtra_tc_list[8]};
      if ($detscr =~ m%^\.%) { $detscr = "0$detscr"; }
      if ($detscr =~ s%^\-\.%%) { $detscr = "-0$detscr"; }

      if (! MMisc::is_float($detscr)) {
        $self->_set_errormsg("Found an UnmappedSys entry without a proper \"DetectionScore\" ($detscr)");
        return(0);
      }
      $detscrsum += $detscr;

      if ($osf != 0) {
        my $fs_fs = new ViperFramespan($fs_value);

        if ($osf > 0) {
          $fs_fs->value_shift($osf);
          if ($fs_fs->error()) {
            $self->_set_errormsg("Problem shifting framespan: " . $fs_fs->get_errormsg());
            return(0);
          }
        } else {
          $fs_fs->negative_value_shift(-$osf);
          if ($fs_fs->error()) {
            $self->_set_errormsg("Problem negative shifting framespan: " . $fs_fs->get_errormsg());
            return(0);
          }
        }
        $fs_value = $fs_fs->get_value();
      }
    
      return(0) if (! $self->add_Unmapped_annot($event, $fs_value, "$ag_txt $annot", $detscr));
    }

    my $meandetscr = $detscrsum / scalar @atc;
    my $cmeandetscr = $self->get_observation_meanDS($obs);
    if (! MMisc::are_float_equal($meandetscr, $cmeandetscr, 0)) {
      $self->_set_errormsg("Localy computed Mean DetectionScore ($meandetscr) is different from observation computed one ($cmeandetscr)");
      return(0);
    }

    return($self->set_agree_DetectionScore($event, $alignc, $id, $meandetscr, $ismax));
  }

  if ($st eq $key_se_UnmappedRef) {
    return(0) if (! $self->add_Ref($event, $fs));

    return(1);
  }

  $self->_set_errormsg("We should not be here");
  return(0);
}

##########

sub set_agree_DetectionScore {
  my ($self, $event, $agc, $id, $detscr, $ismax) = @_;

  return(0) if (! exists $self->{Agree}{$event}{$agc});

  my @tmp = @{$self->{Agree}{$event}{$agc}};
  return(0) if (scalar @tmp < $id);

  my @a = @{$tmp[$id]};

  $a[2] = $detscr;

  ${$self->{Agree}{$event}{$agc}}[$id] = \@a;

  return($self->setif_maxAgreeDS($detscr))
    if ($ismax);

  return(1);
}

#####

sub add_agree {
  my ($self, $event, $agc, $agt, $fs) = @_;
  # Set and empty DetectionScore for now

  my $txt = "";

  if ($agc < 1) {
    $self->_set_errormsg("Agreement value must be at least 1");
    return($txt);
  }

#  print "** AGREE ($event / Agree: $agc [$fs] $agt)\n";

  if (! exists $self->{Agree}{$event}{$agc}) {
    my @tmp = ();
    push @tmp, [ $fs, $agt, undef ];
    @{$self->{Agree}{$event}{$agc}} = @tmp;
  } else {
    push @{$self->{Agree}{$event}{$agc}}, [ $fs, $agt, undef ];
  }

  my $id  = scalar @{$self->{Agree}{$event}{$agc}} - 1;
  $txt = "Agree=$agc ID=$id";

  return($txt, $id, $self->setif_maxAgree($agc));
} 

#####

sub add_Unmapped_annot {
  my ($self, $event, $fs, $annot, $detscr) = @_;

#  print "** Unmapped Annot ($event / $fs / $annot)\n";

  if (! exists $self->{UnmapAnnot}{$event}) {
    my @tmp = ();
    push @tmp, [ $fs, $annot, $detscr ];
    @{$self->{UnmapAnnot}{$event}} = @tmp;
  } else {
    push @{$self->{UnmapAnnot}{$event}}, [ $fs, $annot, $detscr ];
  }

  return(1);
}

#####

sub add_Ref {
  my ($self, $event, $fs) = @_;

#  print "** REF\n";

  if (! exists $self->{Ref}{$event}) {
    my @tmp = ();
    push @tmp, $fs;
    @{$self->{Ref}{$event}} = @tmp;
  } else {
    push @{$self->{Ref}{$event}}, $fs;
  }

  return(1);
}

########################################

sub clear {
  my ($self) = @_;

  return(0) if ($self->error());

  $self->{Agree} = undef;
  $self->{UnmapAnnot} = undef;
  $self->{Ref} = undef;

  return(1);
}

########################################

sub _num { $a <=> $b; }

#####

sub sort_observations_by_max_agree_and_max_mean_detection_score {
  my ($self, $check_sffn, @lo) = @_;

  return(undef, undef) if ($self->error());

  # checks
  my $sffn = "";
  if ($check_sffn) {
      $sffn = $self->get_sffn();
      return(undef, undef) if ($self->error());
  }

  my @ur = ();
  my %us = ();
  foreach my $obs (@lo) {
      if ($check_sffn) {
	  my $osffn = $obs->get_filename();
	  if ($obs->error()) {
	      $self->_set_errormsg("Problem obtaining observation's sffn: " . $obs->get_errormsg());
	      return(undef, undef);
	  }
	  if ($osffn ne $sffn) {
	      $self->_set_errormsg("Observation's sffn ($osffn) is different from adj sffn ($sffn)");
	      return(undef, undef);
	  }
      }

    my $st = $obs->get_eventsubtype();
    if (MMisc::is_blank($st)) {
      $self->_set_errormsg("Events with no subtypes are not valid for Adjudication work");
      return(undef, undef);
    }
    if (($st ne $key_se_UnmappedSys) && ($st ne $key_se_UnmappedRef)) {
      $self->_set_errormsg("Only \'$key_se_UnmappedSys\' and \'$key_se_UnmappedRef\' Events' subtypes are valid for Adjudication work (not: $st)");
      return(undef, undef);
    }

    if ($st eq $key_se_UnmappedRef) {
      push @ur, $obs;
      next;
    }

    # Only UnmappedSys left

    my $agreec = $self->get_observation_agree_level($obs);
    return(undef, undef) if ($self->error());

    my $meands = $self->get_observation_meanDS($obs);
    return(undef, undef) if ($self->error());
      # Reformat it to have a fixed value (of higer precision than the filename printout)
      $meands = sprintf("%.08f", $meands);

    if ($obs->error()) {
      $self->_set_errormsg("Problem in Observation: " . $obs->get_errormsg());
      return(undef, undef);
    }

    # Store it now (we can have more than 1 with the same DS, so we need an array
    push @{$us{$agreec}{$meands}}, $obs;
  }

  my @outus = ();
  # We work in reverse to have the top candidates first (sort keys: Agree then meanDS)
  foreach my $al (reverse sort _num keys %us) {
    foreach my $ds (reverse sort _num keys %{$us{$al}}) {
      if (! exists $us{$al}{$ds}) {
	$self->_set_errormsg("WEIRD -- Could not find UnmappedSys Observation [$al / $ds]");
	return(undef, undef);
      }
      foreach my $obs (@{$us{$al}{$ds}}) {
	push @outus, $obs;
      }
    }
  }

  if ((scalar @ur + scalar @outus) != scalar @lo) {
    $self->_set_errormsg
      ("Not the same number of observations out (" . scalar @ur + scalar @outus . 
       " = " . scalar @outus . " $key_se_UnmappedSys + " . scalar @ur . " $key_se_UnmappedRef) vs in ("
       . scalar @lo . ")");
    return(undef, undef);
  }

  return(\@outus, \@ur);
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

sub _writexml_Agree {
  my ($in, $agree, $fs, $id, $detscr) = @_;

  my $txt = "";

  $txt .= &_wb_print($in++, "<object framespan=\"$fs\" id=\"$id\" name=\"Agree=$agree\">\n");
  $txt .= &_wb_print($in, "<attribute name=\"Note\"/>\n");
  $txt .= &_wb_print($in++, "<attribute name=\"isGood\">\n");
  $txt .= &_wb_print($in--, "<data:bvalue value=\"false\"/>\n");
  $txt .= &_wb_print($in--, "</attribute>\n");
  $txt .= &_wb_print($in++, "<attribute name=\"DetectionScore\">\n");
  $txt .= &_wb_print($in--, "<data:fvalue value=\"$detscr\"/>\n");
  $txt .= &_wb_print($in--, "</attribute>\n");
  $txt .= &_wb_print($in, "</object>\n");

  return($txt);
}

#####

sub _writexml_UnmapAnnot {
  my ($in, $id, $fs, $annot, $detscr) = @_;

  my $txt = "";

  $txt .= &_wb_print($in++, "<object framespan=\"$fs\" id=\"$id\" name=\"Unmapped Annot\">\n");
  $txt .= &_wb_print($in++, "<attribute name=\"location\">\n");
  $txt .= &_wb_print($in--, "<data:svalue value=\"$annot\"/>\n");
  $txt .= &_wb_print($in--, "</attribute>\n");
  $txt .= &_wb_print($in++, "<attribute name=\"DetectionScore\">\n");
  $txt .= &_wb_print($in--, "<data:fvalue value=\"$detscr\"/>\n");
  $txt .= &_wb_print($in--, "</attribute>\n");
  $txt .= &_wb_print($in, "</object>\n");

  return($txt);
}

#####

sub _writexml_Ref {
  my ($in, $event, $id, $fs) = @_;

  my $txt = "";

  $txt .= &_wb_print($in, "<object framespan=\"$fs\" id=\"$id\" name=\"$event REF\">\n");
  $txt .= &_wb_print($in, "</object>\n");

  return($txt);
}

#####

sub _writexml_file {
  my $in = shift @_;

  my @ito = 
    (
     "NUMFRAMES", "ORIGSTARTFRAME", "FRAMERATE",
     "H-FRAME-SIZE", "V-FRAME-SIZE", "SOURCETYPE", 
    );

  my %file;
  foreach my $k (@ito) { $file{$k} = shift @_; }

  my %it = 
    (
     $ito[0] => "dvalue",
     $ito[1] => "dvalue",
     $ito[2] => "fvalue",
     $ito[3] => "dvalue",
     $ito[4] => "dvalue",
     $ito[5] => undef,
    );

  my $txt = "";

  $txt .= &_wb_print($in++, "<file id=\"0\" name=\"Information\">\n");

  foreach my $key (@ito) {
    my $t = $it{$key};
    my $v = (exists $file{$key}) ? $file{$key} : undef;
    
    if ((! defined $v) || (! defined $t)) {
      $txt .= &_wb_print($in, "<attribute name=\"$key\"/>\n");
    } else {
      $txt .= &_wb_print($in++, "<attribute name=\"$key\">\n");
      $txt .= &_wb_print($in--, "<data:$t value=\"$v\"/>\n");
      $txt .= &_wb_print($in, "</attribute>\n");
    }
  }
  $txt .= &_wb_print(--$in, "</file>\n");

  return($txt);
}

#####

sub get_xml {
  my $self  = shift @_;
  my $event = shift @_;

  return("") if (! $self->_pre_self_tests());

  my $sffn = $self->get_sffn();
  my $nf   = $self->get_numframes();
  my $osf  = $self->get_origstartframe();
  # TODO: add access functions
  my $fr  = $self->{framerate};
  my $hfs = $self->{hframesize};
  my $vfs = $self->{vframesize};
  my $st  = $self->{sourcetype};
  return("") if ($self->error());

  my $txt = "";
  my $in = 0;
  
  $txt .= &_wb_print($in, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  $txt .= &_wb_print($in, "<viper xmlns=\"http://lamp.cfar.umd.edu/viper#\" xmlns:data=\"http://lamp.cfar.umd.edu/viperdata#\">\n");
  $txt .= &_wb_print(++$in, "<config>\n");
  $txt .= &_wb_print(++$in, "<descriptor name=\"Information\" type=\"FILE\">\n");
  $txt .= &_wb_print(++$in, "<attribute dynamic=\"false\" name=\"SOURCETYPE\" type=\"http://lamp.cfar.umd.edu/viperdata#lvalue\">\n");
  $txt .= &_wb_print(++$in, "<data:lvalue-possibles>\n");
  $txt .= &_wb_print(++$in, "<data:lvalue-enum value=\"SEQUENCE\"/>\n");
  $txt .= &_wb_print($in--, "<data:lvalue-enum value=\"FRAMES\"/>\n");
  $txt .= &_wb_print($in, "</data:lvalue-possibles>\n");
  $txt .= &_wb_print(--$in, "</attribute>\n");
  $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"ORIGSTARTFRAME\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"NUMFRAMES\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"FRAMERATE\" type=\"http://lamp.cfar.umd.edu/viperdata#fvalue\"/>\n");
  $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"H-FRAME-SIZE\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"V-FRAME-SIZE\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print(--$in, "</descriptor>\n");
  if (exists $self->{Agree}{$event}) {
    foreach my $level (reverse sort {$a <=> $b} keys %{$self->{Agree}{$event}}) {
      $txt .= &_wb_print($in++, "<descriptor name=\"Agree=$level\" type=\"OBJECT\">\"\n");
      $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"Note\" type=\"http://lamp.cfar.umd.edu/viperdata#svalue\"/>\n");
      $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"isGood\" type=\"http://lamp.cfar.umd.edu/viperdata#bvalue\"/>\n");
      $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"DetectionScore\" type=\"http://lamp.cfar.umd.edu/viperdata#fvalue\"/>\n");
      $txt .= &_wb_print(--$in, "</descriptor>\n");
    }
  }
  if (exists $self->{UnmapAnnot}{$event}) {
    $txt .= &_wb_print($in++, "<descriptor name=\"Unmapped Annot\" type=\"OBJECT\">\n");
    $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"location\" type=\"http://lamp.cfar.umd.edu/viperdata#svalue\"/>\n");
    $txt .= &_wb_print($in, "<attribute dynamic=\"false\" name=\"DetectionScore\" type=\"http://lamp.cfar.umd.edu/viperdata#fvalue\"/>\n");
    $txt .= &_wb_print(--$in, "</descriptor>\n");
  }
  $txt .= &_wb_print($in, "<descriptor name=\"$event REF\" type=\"OBJECT\">\n");
  $txt .= &_wb_print($in, "</descriptor>\n");
  $txt .= &_wb_print(--$in, "</config>\n");
  $txt .= &_wb_print($in++, "<data>\n");
  $txt .= &_wb_print($in++, "<sourcefile filename=\"$sffn\">\n");

  $txt .= &_writexml_file($in, $nf, $osf, $fr, $hfs, $vfs, $st);

  if (exists $self->{Agree}{$event}) {
    foreach my $level (reverse sort {$a <=> $b} keys %{$self->{Agree}{$event}}) {
      my $inc = 0;
      foreach my $ra (@{$self->{Agree}{$event}{$level}}) {
        my ($fs, $agtm, $detscr) = @$ra;
        $txt .= &_writexml_Agree($in, $level, $fs, $inc++, $detscr);
      }
    }
  }
  
  if (exists $self->{UnmapAnnot}{$event}) {
    my $inc = 0;
    foreach my $ra (@{$self->{UnmapAnnot}{$event}}) {
      my ($fs, $annot, $detscr) = @$ra;
      $txt .= &_writexml_UnmapAnnot($in, $inc++, $fs, $annot, $detscr);
    }
  }

  if (exists $self->{Ref}{$event}) {
    my $inc = 0;
    foreach my $fs (@{$self->{Ref}{$event}}) {
      $txt .= &_writexml_Ref($in, $event, $inc++, $fs);
    }
  }

  $txt .= &_wb_print(--$in, "</sourcefile>\n");
  $txt .= &_wb_print(--$in, "</data>\n");
  $txt .= &_wb_print(--$in, "</viper>\n");

  return($txt);
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
