package Point;

# Point
#
# Author(s): Vasant Manohar
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Point.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

# use module
use strict;
use Data::Dumper;
use MErrorH;
use MMisc;

# Constructor 
# Using double-argument form of bless() for an inheritable constructor
# Rather than being uniquely a class method, we'll set it up so that 
# it can be called as either a class method or an object method.

#######################

sub new {
    my ( $proto, $x, $y ) = @_;
    my $class = ref($proto) || $proto;

    my $_errormsg = new MErrorH("Point");
    my $errortxt = "";
    $_errormsg->set_errormsg($errortxt);

    my $self =
        {
         _x              => $x,
         _y              => $y,
         #ErrorHandler
         _errormsg       => $_errormsg,
        };

    return "'x' not defined" if (! defined $x);
    return "'y' not defined" if (! defined $y);
    bless ( $self, $class );
    return $self;
}

#######################

sub getX {
    my ( $self ) = @_;
    return $self->{_x};
}

sub getY {
    my ( $self ) = @_;
    return $self->{_y}; 
}

#######################

sub computeDistance {
    my ( $self, $other ) = @_;

    my $gtPoint = {
                   x => $self->getX(),
                   y => $self->getY(),
                  };
    my $soPoint = {
                   x => $other->getX(),
                   y => $other->getY(),
                  };

    my $distance = sqrt(($gtPoint->{x} - $soPoint->{x})*($gtPoint->{x} - $soPoint->{x}) + ($gtPoint->{y} - $soPoint->{y})*($gtPoint->{y} - $soPoint->{y}));

    return $distance;
}

#######################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{_errormsg}->set_errormsg($txt);
}

sub get_errormsg {
  my ($self) = @_;
  return($self->{_errormsg}->errormsg());
}

sub error {
  my ($self) = @_;
  return($self->{_errormsg}->error());
}

#######################

1;
