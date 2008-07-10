package Object;

# Object
#
# Author(s): Vasant Manohar
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Object.pm" is an experimental system.
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
    my ( $proto, $objectId ) = @_;
    my $class = ref($proto) || $proto;

    my $_errormsg = new MErrorH("Object");
    my $errortxt  = "";
    $_errormsg->set_errormsg($errortxt);

    my $self =
        {
        _objectId    => $objectId,
        _oBox        => undef,
        _point       => undef,
        _content     => undef,
        _offset      => undef,
        _dontCare    => undef,
        #ErrorHandler
        _errormsg    => $_errormsg,
        };

    return "'objectId' not defined" if (! defined $objectId);
    bless ($self, $class);
    return $self;
}

#######################

sub getId {
    my ( $self ) = @_;
    return $self->{_objectId};
}

#######################

sub setOBox {
    my ( $self, $oBox ) = @_;

    if (! defined $oBox)   { $self->_set_errormsg("'oBox' not defined in setOBox"); return -1;}
    $self->{_oBox} = $oBox;
}

sub getOBox {
    my ( $self ) = @_;
    return $self->{_oBox};
}

#######################

sub setPoint {
    my ( $self, $point ) = @_;

    if (! defined $point)   { $self->_set_errormsg("'point' not defined in setPoint"); return -1;}
    $self->{_point} = $point;
}

sub getPoint {
    my ( $self ) = @_;
    return $self->{_point};
}

#######################

sub setContent {
    my ( $self, $content ) = @_;

    if (! defined $content)   { $self->_set_errormsg("'content' not defined in setContent"); return -1; }
    $self->{_content} = $content;
}

sub getContent {
    my ( $self ) = @_;
    return @{ $self->{_content} };
}

#######################

sub setOffset {
    my ( $self, $offset ) = @_;

    if (! defined $offset)   { $self->_set_errormsg("'offset' not defined in setOffset"); return -1; }
    $self->{_offset} = $offset;
}

sub getOffset {
    my ( $self ) = @_;
    return @{ $self->{_offset} };
}

#######################

sub setDontCare {
    my ( $self, $dontCare ) = @_;

    if (! defined $dontCare)   { $self->_set_errormsg("'dontCare' not defined in setDontCare"); return -1; }
    $self->{_dontCare} = $dontCare;
}

sub getDontCare {
    my ( $self ) = @_;
    return $self->{_dontCare};
}

#######################

sub setOBoxCentroid {
    my ( $self ) = @_;

    my $oBox = $self->getOBox();
    my $point = $self->getPoint();

    if (! defined $point) {
        my $boxCentroid = $oBox->computeCentroid();
        $self->setPoint($boxCentroid);
    }
}

#######################

sub computeOverlapRatio {
    my ( $self, $other ) = @_;

    my $gtOBox = $self->getOBox();
    my $soOBox = $other->getOBox();

    my $gtBoxArea = $gtOBox->computeArea();
    my $soBoxArea = $soOBox->computeArea();
    my $intersectionArea = $gtOBox->computeIntersectionArea($soOBox);
    my $unionArea = $gtBoxArea + $soBoxArea - $intersectionArea;
    my $retVal;

    if ($intersectionArea > 0) { $retVal = $intersectionArea/$unionArea; }

    return ( "", $retVal );
}

#######################

sub computeNormDistance {
    my ( $self, $other, @frameDims ) = @_;

    my $gtPoint = $self->getPoint();
    my $gtOBox  = $self->getOBox();
    my $soPoint = $other->getPoint();

    my $distance = $gtPoint->computeDistance($soPoint);
    
    my $normFactor;
    if (defined $gtOBox) { $normFactor = ($gtOBox->getWidth() + $gtOBox->getHeight())/2; }
    else { $normFactor = ($frameDims[0] + $frameDims[1])/4; }

    my $normDistance = $distance/$normFactor;
    if ( $normDistance > 1.0 ) { $normDistance = undef; }

    return ("", $normDistance);
}

#######################

sub padHypSys {
    my ($self) = @_;

    return($self->get_errormsg(), 0) if ($self->error());

    my $kernel = 0;
    return("", $kernel);    
}

#######################

sub padHypRef {
    my ($self) = @_;

    return($self->get_errormsg(), 0) if ($self->error());

    my $kernel = 0;
    return("", $kernel);    
}

#######################

sub kernelFunction {
    my ( $ref, $sys, @params ) = @_;

    if ( (defined $ref) && (defined $sys) ) {
        if ( @params ) { return ($ref->computeNormDistance( $sys, @params )); }
        else { return ($ref->computeOverlapRatio( $sys )); }
    } elsif ( (! defined $ref) && (defined $sys) ) {
        return ($sys->padHypRef());
    } elsif ( (defined $ref) && (! defined $sys) ) {
        return ($ref->padHypSys());
    } 

    # Return error if both are undefined
    return("This case is undefined", undef);
}

#######################

sub display {
  my ( $self, @todisplay ) = @_;

  foreach my $td (@todisplay) {
    print "[$td] ", Dumper($self->{$td});
  }
}

#######################

sub displayAll {
  my ( $self ) = @_;

  print Dumper($self);
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
