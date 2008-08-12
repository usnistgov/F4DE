package KernelFunctions;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# Kernel Functions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "KernelFunctions.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

use TrecVid08Observation;
use MErrorH;
use MMisc;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "KernelFunctions.pm Version: $version";

####################

my @kernel_params_list = ("delta_t", "MinDec_s", "RangeDec_s", "E_t", "E_d"); # Order is important

## Constructor
sub new {
  my ($class) = shift @_;

  my $errormsg = new MErrorH("KernelFunctions");

  $errormsg->set_errormsg("\'new\' does not accept any parameter. ") 
    if (scalar @_ > 0);

  my $self =
    {
     delta_t     => undef,
     E_t         => undef,
     E_d         => undef,
     sysEL       => undef,
     errormsg    => $errormsg,
    };

  bless $self;
  return($self);
}

##########

sub get_kp_key_delta_t    { return($kernel_params_list[0]); }
sub get_kp_key_MinDec_s   { return($kernel_params_list[1]); }
sub get_kp_key_RangeDec_s { return($kernel_params_list[2]); }
sub get_kp_key_E_t        { return($kernel_params_list[3]); }
sub get_kp_key_E_d        { return($kernel_params_list[4]); }

########## 'delta_t'

sub set_delta_t {
  my ($self, $value) = @_;

  return(0) if ($self->error());

  $self->{delta_t} = $value;
  return(1);
}

#####

sub _is_delta_t_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{delta_t});

  return(0);
}

#####

sub get_delta_t {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_delta_t_set()) {
    $self->_set_errormsg("\'delta_t\' not set");
    return(0);
  }

  return($self->{delta_t});
}

########## 'E_t'

sub set_E_t {
  my ($self, $value) = @_;

  return(0) if ($self->error());

  $self->{E_t} = $value;
  return(1);
}

#####

sub _is_E_t_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{E_t});

  return(0);
}

#####

sub get_E_t {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_E_t_set()) {
    $self->_set_errormsg("\'E_t\' not set");
    return(0);
  }

  return($self->{E_t});
}

########## 'E_d'

sub set_E_d {
  my ($self, $value) = @_;

  return(0) if ($self->error());

  $self->{E_d} = $value;
  return(1);
}

#####

sub _is_E_d_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{E_d});

  return(0);
}

#####

sub get_E_d {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_E_d_set()) {
    $self->_set_errormsg("\'E_d\' not set");
    return(0);
  }

  return($self->{E_d});
}

########## 'sysEL'

sub set_sysEL {
  my ($self, $sysEL) = @_;

  return(0) if ($self->error());

  $self->{sysEL} = $sysEL;
  return(1);
}

#####

sub _is_sysEL_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{sysEL});

  return(0);
}

#####

sub get_sysEL {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_sysEL_set()) {
    $self->_set_errormsg("\'sysEL\' not set");
    return(0);
  }

  return($self->{sysEL});
}

########## 'MinDec_s'

sub get_MinDec_s {
  my ($self) = @_;

  return(-1) if ($self->error());

  my $sysEL = $self->get_sysEL();
  return(0) if ($self->error());

  my $v = $sysEL->get_MinDec_s();
  $self->_set_errormsg("Problem obtaining MinDec (" . $sysEL->get_errormsg() . ")")
    if ($sysEL->error());

  return($v);
}

########## 'RangeDec_s'

sub get_RangeDec_s {
  my ($self) = @_;

  return(-1) if ($self->error());

  my $sysEL = $self->get_sysEL();
  return(0) if ($self->error());

  my $v = $sysEL->get_RangeDec_s();
  $self->_set_errormsg("Problem obtaining RangeDec (" . $sysEL->get_errormsg() . ")")
    if ($sysEL->error());

  return($v);
}

##########

sub get_kernel_params_list {
  my ($self) = @_;

  return(0) if ($self->error());

  return(@kernel_params_list);
}

#####

sub _get_selected_param {
  my ($self, $key) = @_;

  if (! grep(m%^$key$%, @kernel_params_list)) {
    $self->_set_errormsg("Unknown parameter list ($key). ");
    return(0);
  }

  if ($key eq &get_kp_key_delta_t()) {
    return($self->get_delta_t());
  } elsif ($key eq &get_kp_key_MinDec_s()) {
    return($self->get_MinDec_s());
  } elsif ($key eq &get_kp_key_RangeDec_s()) {
    return($self->get_RangeDec_s());
  } elsif ($key eq &get_kp_key_E_t()) {
    return($self->get_E_t());
  } elsif ($key eq &get_kp_key_E_d()) {
    return($self->get_E_d());
  }

  $self->_set_errormsg("WEIRD: Unknow parameter key ($key)");
  return(0);
}

#####

sub get_kernel_params {
  my ($self) = @_;

  return(0) if ($self->error());

  my @out = ();
  foreach my $key (@kernel_params_list) {
    my $val = $self->_get_selected_param($key);
    if ($self->error()) {
      $self->_set_errormsg("Problem trying to obtain the kernel parameters list for \'$key\'. ");
      return(0);
    }
    push @out, $val;
  }

  return(@out);
}

######################################## class functions

sub joint_kernel {
  my ($sysobj, $refobj, $delta_t, $MinDec_s, $RangeDec_s, $E_t, $E_d) = @_;

  # Check the base for a possible comparison (validate, no error, same file, same eventtype)
  return($sysobj->get_errormsg(), undef)
    if (! $sysobj->is_comparable_to($refobj));

  # For kernel: Can only compare SYS to REF ($sysobj -> $refobj)
  my $etxt = "";
  $etxt .= "Calling object has to be a SYSTEM observation"
    if ($sysobj->get_isgtf());
  $etxt .= "Compared to object can not be a SYSTEM observation"
    if (! $refobj->get_isgtf());
  # Return yet ?
  return($etxt, undef) if (! MMisc::is_blank($etxt));

  # Error ?
  $etxt .= "Problem in calling object (" . $sysobj->get_errormsg() ."). "
    if ($sysobj->error());
  $etxt .= "Problem in compared to object (" . $refobj->get_errormsg() ."). "
    if ($refobj->error());
  # Return yet ?
  return($etxt, undef) if (! MMisc::is_blank($etxt));

  ########## Now the scoring can begin

  # Kernel (O(s,i), O(r,j)) <=> ($sysobj, $refobj)
  my ($Beg_Osi, $Mid_Osi, $End_Osi, $Dur_Osi, $Dec_Osi)
    = $sysobj->get_SYS_Beg_Mid_End_Dur_Dec();
  return("Problem obtaining some element related to the SYS Observation (" . $sysobj->get_errormsg() . ")", undef) if ($sysobj->error());
  my ($Beg_Orj, $Mid_Orj, $End_Orj, $Dur_Orj)
    = $refobj->get_REF_Beg_Mid_End_Dur();
  return("Problem obtaining some element related to the REF Observation (" . $refobj->get_errormsg() . ")", undef) if ($refobj->error());
  
  if ($Mid_Osi > ($End_Orj + $delta_t)) {
    return("", undef);
  } elsif ($Mid_Osi < ($Beg_Orj - $delta_t)) {
    return("", undef);
  } # implicit "else"

  my $TimeCongru_Osi_Orj 
    = ( MMisc::min($End_Orj, $End_Osi) - MMisc::max($Beg_Orj, $Beg_Osi) )
      / MMisc::max((1/25), $Dur_Orj);

  my $DecScoreCongru_Osi
    = ($RangeDec_s == 0) ? 1 :
      ( $Dec_Osi - $MinDec_s ) / $RangeDec_s;

  my $kernel 
    = 1
      + $E_t * $TimeCongru_Osi_Orj
        + $E_d * $DecScoreCongru_Osi;

  return("", $kernel);
}

#####

sub falsealarms_kernel {
  my ($sysobj) = @_;

  return($sysobj->get_errormsg(), undef) if ($sysobj->error());

  my $isgtf = $sysobj->get_isgtf();
  return($sysobj->get_errormsg(), undef) if ($sysobj->error());

  return("Can not generate the \'false alarms kernel\' for a GTF observation. ", undef)
    if ($isgtf);

  my $kernel = -1;

  return("", $kernel);
}

#####

sub misseddetections_kernel {
  my ($refobj) = @_;

  return($refobj->get_errormsg(), undef) if ($refobj->error());

  my $isgtf = $refobj->get_isgtf();
  return($refobj->get_errormsg(), undef) if ($refobj->error());

  return("Can only generate the \'missed detections kernel\' for a GTF observation. ", undef)
    if (! $isgtf);

  my $kernel = 0;

  return("", $kernel);
}

#####

# Class method (to hide implementation details to calling function)
sub kernel_function {
  my ($refobj, $sysobj, @params) = @_;

  # 4 cases
  if ((defined $sysobj) && (defined $refobj)) {
    return(&joint_kernel($sysobj, $refobj, @params));
  } elsif ((defined $sysobj) && (! defined $refobj)) {
    return(&falsealarms_kernel($sysobj));
  } elsif ((! defined $sysobj) && (defined $refobj)) {
    return(&misseddetections_kernel($refobj));
  }

  # 4th case: both values are undefined
  return("This case is undefined", undef);
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
