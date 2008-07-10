package Sequence;

# Sequence
#
# Author(s): Vasant Manohar
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Sequence.pm" is an experimental system.
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
use BipartiteMatch;

# Constructor 
# Using double-argument form of bless() for an inheritable constructor
# Rather than being uniquely a class method, we'll set it up so that 
# it can be called as either a class method or an object method.

#######################

sub new {
    my ( $proto, $parms ) = @_;
    my $class = ref($proto) || $proto;

    my $_errormsg = new MErrorH("Sequence");
    my $errortxt  = defined $parms ? "[Sequence] No default input parameters" : "";
    $_errormsg->set_errormsg($errortxt);

    my $self = 
        {
         _seqFileName           => undef,
         _seqBeginFr            => undef,
         _seqEndFr              => undef,
         _sourceFileName        => undef,
         _videoBeginFr          => undef,
         _videoEndFr            => undef,
         _iFrameRate            => undef,
         _frameDims             => undef,
         _numOfObjects          => undef,
         _seqObjectIds          => undef,
         _frameList             => undef,
         _isAreaEval            => undef,
         #ErrorHandler
         _errormsg              => $_errormsg,
        };
    bless ( $self, $class );
    return $self;
}

#######################

sub setSeqFileName {
    my ( $self, $seqFileName ) = @_;

    if(! defined $seqFileName) { $self->_set_errormsg("Invalid 'seqFileName' in setSeqFileName"); return -1; }
    $self->{_seqFileName} = $seqFileName;
}

sub getSeqFileName {
    my ( $self ) = @_;
    return $self->{_seqFileName};
}

#######################

sub setSeqFrSpan {
    my ( $self, $seqBeginFr, $seqEndFr ) = @_;

    if(! defined $seqBeginFr)  { $self->_set_errormsg("Invalid 'seqBeginFr' in setSeqFrSpan"); return -1;}
    if(! defined $seqEndFr)    { $self->_set_errormsg("Invalid 'seqEndFr' in setSeqFrSpan"); return -1;}
    $self->{_seqBeginFr} = $seqBeginFr;
    $self->{_seqEndFr}   = $seqEndFr;
}

sub getSeqFrSpan {
    my ( $self ) = @_;
    return ( $self->{_seqBeginFr}, $self->{_seqEndFr} );
}

#######################

sub setSourceFileName {
    my ( $self, $sourceFileName ) = @_;

    if(! defined $sourceFileName) { $self->_set_errormsg("Invalid 'sourceFileName' in setSourceFileName"); return -1; }
    $self->{_sourceFileName} = $sourceFileName;
}

sub getSourceFileName {
    my ( $self ) = @_;
    return $self->{_sourceFileName};
}

#######################

sub setVideoFrSpan {
    my ( $self, $videoBeginFr, $videoEndFr ) = @_;

    if(! defined $videoBeginFr)  { $self->_set_errormsg("Invalid 'videoBeginFr' in setVideoFrSpan"); return -1;}
    if(! defined $videoEndFr)    { $self->_set_errormsg("Invalid 'videoEndFr' in setVideoFrSpan"); return -1;}
    $self->{_videoBeginFr} = $videoBeginFr;
    $self->{_videoEndFr}   = $videoEndFr;
}

sub getVideoFrSpan {
    my ( $self ) = @_;
    return ( $self->{_videoBeginFr}, $self->{_videoEndFr} );
}

#######################

sub setIFrameRate {
    my ( $self, $iFrameRate ) = @_;

    if(! defined $iFrameRate)  { $self->_set_errormsg("Invalid 'iFrameRate' in setIFrameSet"); return -1; }
    $self->{_iFrameRate} = $iFrameRate;
}

sub getIFrameRate {
    my ( $self ) = @_;
    return $self->{_iFrameRate};
}

#######################

sub setFrameDims {
    my ( $self, $frameDims ) = @_;

    if(! defined $frameDims) { $self->_set_errormsg("Invalid 'frameDims' in setFrameDims"); return -1;}
    $self->{_frameDims} = $frameDims;
}

sub getFrameDims {
    my ( $self ) = @_;
    return @{ $self->{_frameDims} };
}

#######################

sub setNumOfObjects {
    my ( $self, $numOfObjects ) = @_;

    if(! defined $numOfObjects) { $self->_set_errormsg("Invalid 'numOfObjects' in setNumOfObjects"); return -1; }
    $self->{_numOfObjects} = $numOfObjects;
}

sub getNumOfObjects {
    my ( $self ) = @_;
    return $self->{_numOfObjects};
}

#######################

sub addToSeqObjectIds {
    my ( $self, $objectId ) = @_;

    if (! defined $objectId)   { $self->_set_errormsg("Invalid 'objectId' in addToSeqObjectIds"); return -1; }
    if (! defined $self->{_seqObjectIds}) { $self->{_seqObjectIds} = []; }
    push( @{ $self->{_seqObjectIds} }, $objectId );
}

sub getSeqObjectIds {
    my ( $self ) = @_;
    return @{ $self->{_seqObjectIds} };
}

#######################

sub setFrameList {
    my ( $self, $frameList ) = @_;

    if (! defined $frameList)   { $self->_set_errormsg("Invalid 'frameList' in setFrameList"); return -1; }
    $self->{_frameList} = $frameList;
}

sub addToFrameList {
    my ( $self, $frame ) = @_;

    if (! defined $frame)  { $self->_set_errormsg("Invalid 'frame' in addToFrameList"); return -1; }
    my $frameNum = $frame->getFrameNum();
    if (! defined $frameNum) { $self->_set_errormsg("Invalid Frame Number in addToFrameList"); return -1; } 
    if (! defined $self->{_frameList} ) { $self->{_frameList} = {}; }
    if (exists $self->{_frameList}{$frameNum}) { $self->_set_errormsg("Two frames with the same frame number"); return -1; }
    $self->{_frameList}{$frameNum} = $frame;
}

sub getFrameList {
    my ( $self ) = @_;
    return $self->{_frameList};
}

#######################

sub computeSFDA {
    my ( $self, $other, @params ) = @_;
    my ( $cfda, $sfda );

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();
    my $frameCount = 0;

    # Just loop through the reference frames to evaluate. If systems report outside
    # of these frames, those frames will not be evaluated.
    # The reference annotations start one I-Frame earlier and end one I-Frame later
    # than the framespan mentioned in the index files. So, exclude the first
    # and the last frames from evaluation

    my @frameNums = MMisc::reorder_array_numerically keys %$gtFrameList;
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $fda;

        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getDetOutDefined()) { $gtFrame->computeAndSetSpatialMeasures($soFrame, @params); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing spatial measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1;
        }
        
        my ( $mappedOverlapRatio, %evalGTIDs, %evalSOIDs, %mdIDs, %faIDs, $numOfEvalGT, $numOfEvalSO, $md, $fa );

        $mappedOverlapRatio = $gtFrame->getMappedOverlapRatio();
        if (defined $gtFrame->getEvalObjectIDs()) { %evalGTIDs = $gtFrame->getEvalObjectIDs(); }
        if (defined $gtFrame->getEvalSOIDs())     { %evalSOIDs = $gtFrame->getEvalSOIDs(); }
        if (defined $gtFrame->getMissDetectIDs()) { %mdIDs = $gtFrame->getMissDetectIDs(); }
        if (defined $gtFrame->getFalseAlarmIDs()) { %faIDs = $gtFrame->getFalseAlarmIDs(); }

        if (%evalGTIDs) { $numOfEvalGT = scalar keys %evalGTIDs; }
        if (%evalSOIDs) { $numOfEvalSO = scalar keys %evalSOIDs; }
        if (%mdIDs) { $md = scalar keys %mdIDs; }
        if (%faIDs) { $fa = scalar keys %faIDs; }

        if (defined $mappedOverlapRatio) { $fda = (2*$mappedOverlapRatio)/($numOfEvalGT + $numOfEvalSO); }
        elsif (defined $numOfEvalGT) {
            if ( ($md > 0) || ( (defined $numOfEvalSO) && ($fa > 0) ) ) { $fda = 0.0; }
            else { $fda = 1.0; }
        }

        if (defined $fda) {
            $frameCount++;
            if (defined $cfda) { $cfda += $fda; }
            else { $cfda = $fda; }
        }

    }

    if (defined $cfda) { $sfda = $cfda/$frameCount; }
    return $sfda;
}

#######################

sub computeMODA {
    my ( $self, $other, $costMD, $costFA, @params ) = @_;
    my ( $cerror, $cng, $nmoda );

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();

    # Just loop through the reference frames to evaluate. If systems report outside
    # of these frames, those frames will not be evaluated.
    # The reference annotations start one I-Frame earlier and end one I-Frame later
    # than the framespan mentioned in the index files. So, exclude the first
    # and the last frames from evaluation

    $cng = 0;
    my @frameNums = MMisc::reorder_array_numerically keys %$gtFrameList;
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getDetOutDefined) { $gtFrame->computeAndSetSpatialMeasures($soFrame, @params); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing spatial measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1; 
        }

        my ( %mdIDs, %faIDs, %evalGTIDs, $md, $fa, $numOfEvalGT );
        
        if (defined $gtFrame->getMissDetectIDs()) { %mdIDs = $gtFrame->getMissDetectIDs(); }
        if (defined $gtFrame->getFalseAlarmIDs()) { %faIDs = $gtFrame->getFalseAlarmIDs(); }
        if (defined $gtFrame->getEvalObjectIDs()) { %evalGTIDs = $gtFrame->getEvalObjectIDs(); }
        if (%mdIDs) { $md = scalar keys %mdIDs; }
        if (%faIDs) { $fa = scalar keys %faIDs; }
        if (%evalGTIDs) { $numOfEvalGT = scalar keys %evalGTIDs; }

        if (defined $md) { 
            if (defined $cerror) { $cerror += $costMD*$md; }
            else { $cerror = $costMD*$md; }
        }

        if (defined $fa) { 
            if (defined $cerror) { $cerror += $costFA*$fa; }
            else { $cerror = $costFA*$fa; }
        }

        if (defined $numOfEvalGT) {
            if (defined $cng) { $cng += $numOfEvalGT; }
            else { $cng = $numOfEvalGT; }
        }

    }

    if ( (defined $cerror) && (defined $cng) ) { $nmoda = 1 - ($cerror/$cng); }
    return $nmoda;
}

#######################

sub computeMODP {
    my ( $self, $other, @params ) = @_;
    my ( $cmodp, $nmodp );

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();
    my $frameCount = 0;

    # Just loop through the reference frames to evaluate. If systems report outside
    # of these frames, those frames will not be evaluated.
    # The reference annotations start one I-Frame earlier and end one I-Frame later
    # than the framespan mentioned in the index files. So, exclude the first
    # and the last frames from evaluation

    my @frameNums = MMisc::reorder_array_numerically keys %$gtFrameList;
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $modp;

        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getDetOutDefined) { $gtFrame->computeAndSetSpatialMeasures($soFrame, @params); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing spatial measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1;
        }

        my ($mappedOverlapRatio, @mappedObjIDs, $numOfMappedObjs );
        
        $mappedOverlapRatio = $gtFrame->getMappedOverlapRatio();
        if (defined $gtFrame->getMappedObjIDs()) { @mappedObjIDs = $gtFrame->getMappedObjIDs(); }
        if ( @mappedObjIDs ) { $numOfMappedObjs = scalar @mappedObjIDs; }

        if ( (defined $mappedOverlapRatio) && (defined $numOfMappedObjs) ) { $modp = $mappedOverlapRatio/$numOfMappedObjs; }

        if (defined $modp) {
            $frameCount++;
            if (defined $cmodp) { $cmodp += $modp; }
            else { $cmodp = $modp; }
        }

    }

    if (defined $cmodp) { $nmodp = $cmodp/$frameCount; }
    return $nmodp;
}

#######################

sub computeATA {
    my ( $self, $other, @params ) = @_;

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();

    # First re-organize the hash. Currently it is a hash of frames with each frame being a hash of objects present in that frame.
    # Re-organize it as a hash of objects with each object being a hash of frames in which the object was present.
    my ( %gtObjTrks, %soObjTrks );

    foreach my $fkey (keys %$gtFrameList) {
        my $gtFrame = $gtFrameList->{$fkey};
        my $gtObjList = $gtFrame->getObjectList();
        foreach my $okey (keys %$gtObjList) {
            $gtObjTrks{$okey}{$fkey} = $gtObjList->{$okey};
        }
    }

    foreach my $fkey (keys %$soFrameList) {
        my $soFrame = $soFrameList->{$fkey};
        my $soObjList = $soFrame->getObjectList();
        foreach my $okey (keys %$soObjList) {
            $soObjTrks{$okey}{$fkey} = $soObjList->{$okey};
        }
    }

    # Compute spatio-temporal measures using the above two hashes
    # When passed with additional parameters (frame width & frame height), the kernel function computes distance-based measures
    # Without any additional parameters, the kernel function computes area-based measures
    my $evalBPM = new BipartiteMatch(\%gtObjTrks, \%soObjTrks, \&kernelFunction, \@params);
    if ($evalBPM->error()) { 
        $self->_set_errormsg( "Error while creating Evaluation Bipartite Matching object in computeATA (" . $evalBPM->get_errormsg() . ")" ); 
        return -1; 
    }
    $evalBPM->compute();
    if ($evalBPM->error()) { 
        $self->_set_errormsg( "Error while computing Evaluation Bipartite Matching in computeATA (" . $evalBPM->get_errormsg() . ")" ); 
        return -1; 
    }
    

}

#######################

sub computeMOTA {
    my ( $self, $other, $costMD, $costFA, $costIS, @params ) = @_;
    my ( $mota, $cerror, $cng );

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();

    # Just loop through the reference frames to evaluate. If systems report outside
    # of these frames, those frames will not be evaluated.
    # The reference annotations start one I-Frame earlier and end one I-Frame later
    # than the framespan mentioned in the index files. So, exclude the first
    # and the last frames from evaluation

    my ( $prevGTMap, $prevSOMap );
    my @frameNums = MMisc::reorder_array_numerically keys %$gtFrameList;
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getTrkOutDefined) { $gtFrame->computeAndSetTemporalMeasures($soFrame, $prevGTMap, $prevSOMap, @params); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing temporal measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1; 
        }

        my ( %mdIDs, %faIDs, %idSplitObjIDs, %idMergeObjIDs, %evalGTIDs, $md, $fa, $idSplits, $idMerges, $numOfEvalGT );
        
        if (defined $gtFrame->getMissDetectIDs()) { %mdIDs = $gtFrame->getMissDetectIDs(); }
        if (defined $gtFrame->getFalseAlarmIDs()) { %faIDs = $gtFrame->getFalseAlarmIDs(); }
        if (defined $gtFrame->getIDSplitObjIDs()) { %idSplitObjIDs = $gtFrame->getIDSplitObjIDs(); }
        if (defined $gtFrame->getIDMergeObjIDs()) { %idMergeObjIDs = $gtFrame->getIDMergeObjIDs(); }
        if (defined $gtFrame->getEvalObjectIDs()) { %evalGTIDs = $gtFrame->getEvalObjectIDs(); }
        if (%mdIDs) { $md = scalar keys %mdIDs; }
        if (%faIDs) { $fa = scalar keys %faIDs; }
        if (%idSplitObjIDs) { $idSplits = scalar keys %idSplitObjIDs; }
        if (%idMergeObjIDs) { $idMerges = scalar keys %idMergeObjIDs; }
        if (%evalGTIDs) { $numOfEvalGT = scalar keys %evalGTIDs; }

        if (defined $md) { 
            if (defined $cerror) { $cerror += $costMD*$md; }
            else { $cerror = $costMD*$md; }
        }

        if (defined $fa) { 
            if (defined $cerror) { $cerror += $costFA*$fa; }
            else { $cerror = $costFA*$fa; }
        }

        if (defined $idSplits) {
            if (defined $cerror) { $cerror += $costIS*$idSplits; }
            else { $cerror = $costIS*$idSplits; }
        }

        if (defined $idMerges) {
            if (defined $cerror) { $cerror += $costIS*$idMerges; }
            else { $cerror = $costIS*$idMerges; }
        }

        if (defined $numOfEvalGT) {
            if (defined $cng) { $cng += $numOfEvalGT; }
            else { $cng = $numOfEvalGT; }
        }

    }

    if ( (defined $cerror) && (defined $cng) ) { $mota = 1 - ($cerror/$cng); }
    return $mota;
}

#######################

sub computeMOTP {
    my ( $self, $other, @params ) = @_;
    my ( $motp, $covlpRatio, $cnumOfMappedObjs );

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();

    # Just loop through the reference frames to evaluate. If systems report outside
    # of these frames, those frames will not be evaluated.
    # The reference annotations start one I-Frame earlier and end one I-Frame later
    # than the framespan mentioned in the index files. So, exclude the first
    # and the last frames from evaluation

    my ( $prevGTMap, $prevSOMap );
    my @frameNums = MMisc::reorder_array_numerically keys %$gtFrameList;
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getTrkOutDefined) { $gtFrame->computeAndSetTemporalMeasures($soFrame, $prevGTMap, $prevSOMap, @params); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing temporal measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1; 
        }

        my ($mappedOverlapRatio, @mappedObjIDs, $numOfMappedObjs );
        
        $mappedOverlapRatio = $gtFrame->getMappedOverlapRatio();
        if (defined $gtFrame->getMappedObjIDs()) { @mappedObjIDs = $gtFrame->getMappedObjIDs(); }
        if ( @mappedObjIDs ) { $numOfMappedObjs = scalar @mappedObjIDs; }

        if ( (defined $mappedOverlapRatio) && (defined $numOfMappedObjs) ) {
            if (defined $covlpRatio) { $covlpRatio += $mappedOverlapRatio; }
            else { $covlpRatio = $mappedOverlapRatio; }
            if (defined $cnumOfMappedObjs) { $cnumOfMappedObjs += $numOfMappedObjs; }
            else { $cnumOfMappedObjs = $numOfMappedObjs; }
        }

    }

    if ( (defined $covlpRatio) && (defined $cnumOfMappedObjs) ) { $motp = $covlpRatio/$cnumOfMappedObjs; }
    return $motp;
}

#######################

sub kernelFunction {

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
