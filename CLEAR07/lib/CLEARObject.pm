package CLEARObject;

# CLEARObject
#
# Author(s): Vasant Manohar
# Additions: Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEARObject.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CLEARObject.pm Version: $version";

use Levenshtein;
use MErrorH;
use MMisc;
use Data::Dumper;

# Constructor 
# Using double-argument form of bless() for an inheritable constructor
# Rather than being uniquely a class method, we'll set it up so that 
# it can be called as either a class method or an object method.

#######################

sub new {
    my ( $proto, $objectId ) = @_;
    my $class = ref($proto) || $proto;

    my $_errormsg = MErrorH->new("CLEARObject");
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
    return "'objectId' cannot be negative" if ($objectId < 0);
    bless ($self, $class);
    return $self;
}

#######################

sub unitTest {
    print "Test CLEARObject\n";

    return 1;
}

#######################

sub getId {
    my $self = $_[0];
    return $self->{_objectId};
}

#######################

sub setOBox {
    my ($self, $oBox) = @_;

    if (! defined $oBox)   { $self->_set_errormsg("'oBox' not defined in setOBox"); return -1;}
    $self->{_oBox} = $oBox;
}

sub getOBox {
    my $self = $_[0];
    return $self->{_oBox};
}

#######################

sub setPoint {
    my ($self, $point) = @_;

    if (! defined $point)   { $self->_set_errormsg("'point' not defined in setPoint"); return -1;}
    $self->{_point} = $point;
}

sub getPoint {
    my $self = $_[0];
    return $self->{_point};
}

#######################

sub setContent {
    my ($self, $content) = @_;

    if (! defined $content)   { $self->_set_errormsg("'content' not defined in setContent"); return -1; }
    $self->{_content} = $content;
}

sub getContent {
    my $self = $_[0];
    return $self->{_content};
}

#######################

sub setOffset {
    my ($self, $offset) = @_;

    if (! defined $offset)   { $self->_set_errormsg("'offset' not defined in setOffset"); return -1; }
    $self->{_offset} = $offset;
}

sub getOffset {
    my $self = $_[0];
    return $self->{_offset};
}

#######################

sub setDontCare {
    my ($self, $dontCare) = @_;

    if (! defined $dontCare)   { $self->_set_errormsg("'dontCare' not defined in setDontCare"); return -1; }
    $self->{_dontCare} = $dontCare;
}

sub getDontCare {
    my $self = $_[0];
    return $self->{_dontCare};
}

#######################

sub setOBoxCentroid {
    my $self = $_[0];

    my $oBox = $self->getOBox();
    if (! defined $oBox) {
        $self->_set_errormsg("Undefined OBox while computing centroid");
        return -1;
    }

    my $point = $self->getPoint();
    if (! defined $point) {
        my $boxCentroid = $oBox->computeCentroid();
        $self->setPoint($boxCentroid);
    }
}

#######################

sub computeOverlapRatio {
    my ($self, $other, $thres, $bin) = @_;

    # We handle thresholded metric value computation and regular
    # metric value computation through one sub-routine. When computing 
    # the regular way, pass 1.0 as the value for $thres without the 
    # binary option ($bin = 0).

    my $gtOBox = $self->getOBox();
    my $soOBox = $other->getOBox();

    my $gtBoxArea = $gtOBox->computeArea();
    my $soBoxArea = $soOBox->computeArea();
    my $intersectionArea = $gtOBox->computeIntersectionArea($soOBox);
    my $unionArea = $gtBoxArea + $soBoxArea - $intersectionArea;
    my $retVal;

    if ($intersectionArea > 0) { 
        my $value = $intersectionArea/$unionArea; 
        if ($bin) { $retVal = ($value >= $thres) ? 1 : undef; }
        else { $retVal = ($value >= $thres) ? 1 : $value; }
    }

    return ( "", $retVal );
}

#######################

sub computeNormDistance {
    my ($self, $other, $thres, $bin, @frameDims) = @_;

    my $gtPoint = $self->getPoint();

    # If there is no point defined, compute the centroid of the OBox and use that for computing distance
    if (! defined $gtPoint) {
        $self->setOBoxCentroid();
        if ($self->error()) { return ($self->get_errormsg(), undef); }
        $gtPoint = $self->getPoint();
    }
    my $gtOBox  = $self->getOBox();

    my $soPoint = $other->getPoint();

    # If there is no point defined, compute the centroid of the OBox and use that for computing distance
    if (! defined $soPoint) {
        $other->setOBoxCentroid();
        if ($other->error()) { return ($other->get_errormsg(), undef); }
        $soPoint = $other->getPoint();
    }

    my $distance = $gtPoint->computeDistance($soPoint);
    
    my $normFactor;
    if (defined $gtOBox) { $normFactor = ($gtOBox->getWidth() + $gtOBox->getHeight())/2; }
    else { $normFactor = ($frameDims[0] + $frameDims[1])/4; }

    my $normDistance;
    my $value = $distance/$normFactor;
    if ( $value >= 1.0 ) { $normDistance = undef; }
    else {
        $value = 1 - $value;
        if ($bin) { $normDistance = ($value >= $thres) ? 1 : undef; }
        else { $normDistance = ($value >= $thres) ? 1 : $value; }
    }

    return ("", $normDistance);
}

#######################

sub computeEditDistance {
    my ($refText, $sysText, $costInsDel, $costSub) = @_;
    return (Levenshtein(lc($refText), lc($sysText), $costInsDel, $costSub, 0, 0, 0));
}

#######################

sub computeCharacterErrorRate {
    my ($self, $other, $costInsDel, $costSub) = @_;

    my $gtText = $self->getContent();
    return ("Cannot evaluate against an undefined 'content' (reference)", undef) if (! defined $gtText);
    my $gtTextLength = length($gtText);

    my $soText = $other->getContent();
    return ("Cannot evaluate against an undefined 'content' (system)", undef) if (! defined $soText);

    my $CER = &computeEditDistance($gtText, $soText, $costInsDel, $costSub);

    my $retVal = 1 - ($CER/$gtTextLength);
    return ("", $retVal);
}

#######################

sub padHypSys {
    my $self = $_[0];

    return($self->get_errormsg(), 0) if ($self->error());

    my $kernel = 0;
    return("", $kernel);    
}

#######################

sub padHypRef {
    my $self = $_[0];

    return($self->get_errormsg(), 0) if ($self->error());

    my $kernel = 0;
    return("", $kernel);    
}

#######################

sub kernelFunction {
    my ($ref, $sys, $params) = @_;
    
    my @kernel_params = @$params;
    my $thres = shift @kernel_params;
    my $bin = shift @kernel_params;

    if ( (defined $ref) && (defined $sys) ) {
        if ( scalar @kernel_params > 0 ) { return ($ref->computeNormDistance( $sys, $thres, $bin, @kernel_params )); }
        else { return ($ref->computeOverlapRatio( $sys, $thres, $bin )); }
    } elsif ( (! defined $ref) && (defined $sys) ) {
        return ($sys->padHypRef());
    } elsif ( (defined $ref) && (! defined $sys) ) {
        return ($ref->padHypSys());
    } 

    # Return error if both are undefined
    return("This case is undefined", undef);
}

#######################

sub textRecKernelFunction {
    my ($ref, $sys, $params) = @_;
    
    my @kernel_params = @$params;
    my $thres = shift @kernel_params;
    my $bin = shift @kernel_params;
    my $spatialWeight = shift @kernel_params;
    my $cerWeight = shift @kernel_params;
    my $costInsDel = shift @kernel_params;
    my $costSub = shift @kernel_params;

    if ( (defined $ref) && (defined $sys) ) {
        my ($txt, $spatialValue, $textValue);

        if ( scalar @kernel_params > 0 ) { ($txt, $spatialValue) = $ref->computeNormDistance( $sys, $thres, $bin, @kernel_params ); }
        else { ($txt, $spatialValue) = $ref->computeOverlapRatio( $sys, $thres, $bin ); }
        if (! MMisc::is_blank($txt)) { return ($txt, undef); }

        ($txt, $textValue) = $ref->computeCharacterErrorRate( $sys, $costInsDel, $costSub );
        if (! MMisc::is_blank($txt)) { return ($txt, undef); }

        my $retVal = (defined $spatialValue) ? (($spatialWeight*$spatialValue) + ($cerWeight*$textValue)) : undef;
        return ("", $retVal);
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
  my ($self, @todisplay) = @_;

  foreach my $td (@todisplay) {
    print "[$td] ", Dumper($self->{$td});
  }
}

#######################

sub displayAll {
  my $self = $_[0];

  print Dumper($self);
}

#######################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{_errormsg}->set_errormsg($txt);
}

sub get_errormsg {
  my $self = $_[0];
  return($self->{_errormsg}->errormsg());
}

sub error {
  my $self = $_[0];
  return($self->{_errormsg}->error());
}

########################################

1;
