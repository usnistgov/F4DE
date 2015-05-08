package MErrorH;
#
# $Id$
#
# M's Error Handler
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "MErrorH.pm" is an experimental system.
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

use strict;

use MMisc;


## Constructor
sub new {
  my ($class, $header) = @_;

  my $self =
    {
     header   => $header,
     errormsg => "",
     errorset => 0,
    };

  bless $self;
  return($self);
}

####################

sub set_header {
  # arg 0: self
  # arg 1: header
  $_[0]->{header} = $_[1];

  return(1);
}

##########

sub _set_errormsg_txt {
  my ($oh, $add, $header) = @_;

  my $txt = "$oh$add";

  $txt = &_remove_header($txt, $header);

  return("") if (MMisc::is_blank($txt));

  $txt = "[$header] $txt" if (! MMisc::is_blank($header));

  return($txt);
}

#####

sub _remove_header {
  my ($txt, $header) = @_;

  $txt =~ s%\[$header\]\s+%%g if (! MMisc::is_blank($header));

  return($txt);
}

#####

sub set_errormsg {
  # arg 0: self
  # arg 1: text
  $_[0]->{errormsg} = &_set_errormsg_txt($_[0]->{errormsg}, $_[1], $_[0]->{header});
  $_[0]->{errorset} = (length($_[0]->{errormsg}) > 0) ? 1 : 0;
}

##########

sub errormsg {
  # arg 0: self
  return($_[0]->{errormsg});
}

#####

sub clean_errormsg {
  # arg 0: self
  return(&_remove_header($_[0]->{errormsg}));
}

##########

## returns 0 if no error, something else otherwise
sub error {
  # arg 0: self
  return($_[0]->{errorset});
}

##########

sub clear {
  # arg 0: self
  $_[0]->{errormsg} = "";
  $_[0]->{errorset} = 0;
  return(1);
}

##########

sub set_error_and_return {
  my $self = shift @_;
  my $errormsg = shift @_;

  $self->set_errormsg($errormsg);
  return(@_);
}

############################################################

1;
