package TrecVid08xmllint;

# TrecVid08 "xmllint" (& XSD) Functions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08xmllint.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

use MErrorH;
use MMisc;

sub new {
  my ($class) = shift @_;

  my $errortxt = (scalar @_ > 0) ? "TrecVid08xmllint does not accept parameters" : "";

  my $errormsg = new MErrorH("TrecVid08xmllint");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     xmllint        => "",
     xsdpath        => "",
     xsdfilesl      => undef,
     errormsg       => $errormsg,
    };

  bless $self;
  return($self);
}

##########

sub set_xmllint {
  my ($self, $xmllint) = @_;

  my ($nxmllint, $error) = &_check_xmllint($xmllint);

  if (! MMisc::is_blank($error)) {
    $self->_set_errormsg($error);
    return(0);
  }

  $self->{xmllint} = $nxmllint;
  return(1);
}

#####

sub is_xmllint_set {
  my ($self) = @_;

  return(1) if (! MMisc::is_blank($self->{xmllint}));

  return(0);
}

#####

sub get_xmllint {
  my ($self) = @_;

  if (! $self->is_xmllint_set()) {
    $self->_set_errormsg("\'xmllint\' is not set");
    return(0);
  }

  return($self->{xmllint});
}

#####

sub _check_xmllint {
  my ($xmllint) = shift @_;

  if ($xmllint eq "") {
    my ($retcode, $stdout, $stderr) = &MMisc::do_system_call('which', 'xmllint');
    return("", "Could not find a valid \'xmllint\' command in the PATH, aborting\n") if ($retcode != 0);
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
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call($xmllint, '--version');
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

############################################################

sub set_xsdfilesl {
  my ($self, @xsdfilesl) = @_;

  return(0) if ($self->error());

  if (scalar @xsdfilesl == 0) {
    $self->_set_errormsg("No \'xsdfilesl\' provided");
    return(0);
  }

  push @{$self->{xsdfilesl}}, @xsdfilesl;
  return(1);
}

#####

sub get_xsdfilesl {
  my ($self) = @_;

  my @xsdfilesl = @{$self->{xsdfilesl}};

  return(@xsdfilesl);
}

#####

sub is_xsdfilesl_set {
  my ($self) = @_;

  my @xsdfilesl = $self->get_xsdfilesl();

  return(0) if (scalar @xsdfilesl == 0);

  return(1);
}

############################################################

sub set_xsdpath {
  my ($self, $xsdpath) = @_;

  return(0) if ($self->error());

  if (! $self->is_xsdfilesl_set()) {
    $self->_set_errormsg("Can only \'set_xsdpath\' once \'xsdfilesl\' has been set");
    return(0);
  }

  my @xsdfilesl = $self->get_xsdfilesl();
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

sub is_xsdpath_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{xsdpath}));

  return(0);
}

#####

sub get_xsdpath {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_xsdpath_set()) {
    $self->_set_errormsg("\'xsdpath\' is not set");
    return(0);
  }

  return($self->{xsdpath});
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

############################################################

sub run_xmllint {
  my ($self, $file) = @_;

  my $xmllint = $self->get_xmllint();
  my $xsdpath = $self->get_xsdpath();
  my @xsdfilesl = $self->get_xsdfilesl();

  return("") if ($self->error());

  $file =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  my ($retcode, $stdout, $stderr) = MMisc::do_system_call
    ($xmllint, "--path", "\"$xsdpath\"", 
     "--schema", $xsdpath . "/" . $xsdfilesl[0], $file);

  if ($retcode != 0) {
    $self->_set_errormsg("Problem validating file with \'xmllint\' ($stderr), aborting");
    return("");
  }

  return($stdout);
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
