package CLEARSequence;

# CLEARSequence
#
# Author(s): Vasant Manohar
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEARSequence.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

my $version = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CLEARSequence.pm Version: $version";

use CLEARObject;
use BipartiteMatch;
use MErrorH;
use MMisc;
use Data::Dumper;
use File::Basename;
use CSVHelper;

use CLEARMetrics;

# Constructor 
# Using double-argument form of bless() for an inheritable constructor
# Rather than being uniquely a class method, we'll set it up so that 
# it can be called as either a class method or an object method.

#######################

sub new {
    my ( $proto, $seqFileName ) = @_;
    my $class = ref($proto) || $proto;

    my $_errormsg = MErrorH->new("CLEARSequence");
    $_errormsg->set_errormsg("");
    $seqFileName = uc(basename($seqFileName));

    my $self = 
        {
         _seqFileName           => $seqFileName,
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
         _isgtf                 => 0,
         _evalObj               => undef,
         #Validation Check
         _validated             => 0,
         #Output
        _mappedOverlapRatio     => undef,
        _mappedObjIDs           => undef,
        _evalSOIDs              => undef,
        _noPenaltySysIDs        => undef,
        _missDetectIDs          => undef,
        _falseAlarmIDs          => undef,
        _isOut                  => 0,
         #ErrorHandler
         _errormsg              => $_errormsg,
        };

    return "Invalid 'seqFileName'" if (! defined $seqFileName);
    bless ( $self, $class );
    return $self;
}

#######################

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

sub getSeqBegFr {
    my ( $self ) = @_;
    return ($self->{_seqBeginFr});
}

sub getSeqEndFr {
    my ( $self ) = @_;
    return ($self->{_seqEndFr} );
}

#######################

sub setSourceFileName {
    my ( $self, $sourceFileName ) = @_;

    if(! defined $sourceFileName) { $self->_set_errormsg("Invalid 'sourceFileName' in setSourceFileName"); return -1; }
    $sourceFileName = uc(basename($sourceFileName));
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

    if (! defined $self->{_frameDims}) { $self->_set_errormsg("'frameDims' is not defined"); return $self->{_frameDims}; }
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

sub setSeqObjectIds {
    my ( $self, $seqObjectIds ) = @_;

    if (! defined $seqObjectIds) { $self->_set_errormsg("Invalid 'seqObjectIds' in setSeqObjectIds"); return -1;}
    $self->{_seqObjectIds} = $seqObjectIds;
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

sub _setSpatioTemporalMeasures {
    my ( $self, $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $missDetectIDs, $falseAlarmIDs ) = @_;

    if ( $self->error() ) { return -1; }
    
    $self->_setOutDefined();
    if ( $self->error() ) { return -1; }

    $self->{_mappedOverlapRatio}    = $mappedOverlapRatio;
    $self->{_mappedObjIDs}          = $mappedObjIDs;
    $self->{_evalObjectIDs}         = $evalObjectIDs;
    $self->{_evalSOIDs}             = $evalSOIDs;
    $self->{_noPenaltySysIDs}       = $noPenaltySysIDs;
    $self->{_missDetectIDs}         = $missDetectIDs;
    $self->{_falseAlarmIDs}         = $falseAlarmIDs;
}

#######################

sub _setOutDefined {
    my ( $self ) = @_;
    if ($self->getOutDefined) { $self->_set_errormsg("Output already defined for sequence"); return -1; }
    $self->{_isOut} = 1;
}

sub _unsetOutDefined {
    my ( $self ) = @_;
    $self->{_isOut} = 0;
}

sub getOutDefined {
    my ( $self ) = @_;
    return $self->{_isOut};
}

#######################

sub computeSFDA {
    my ( $self, $other, $eval_type, $thres, $bin ) = @_;
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

    my @tmpa = keys %$gtFrameList;
    my @frameNums = MMisc::reorder_array_numerically(\@tmpa);
    my @frame_dims = ($eval_type eq "Point") ? $self->getFrameDims() : ();
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $fda;

        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getDetOutDefined()) { $gtFrame->computeAndSetSpatialMeasures($soFrame, $thres, $bin, @frame_dims); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing spatial measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1;
        }
        
        my ( $mappedOverlapRatio, %evalGTIDs, %evalSOIDs, %mdIDs, %faIDs );
        my ( $numOfEvalGT, $numOfEvalSO, $md, $fa ) = ( 0, 0, 0, 0 );

        $mappedOverlapRatio = $gtFrame->getMappedOverlapRatio();
        if (defined $gtFrame->getEvalObjectIDs()) { %evalGTIDs = $gtFrame->getEvalObjectIDs(); }
        if (defined $gtFrame->getEvalSOIDs())     { %evalSOIDs = $gtFrame->getEvalSOIDs(); }
        if (defined $gtFrame->getMissDetectIDs()) { %mdIDs = $gtFrame->getMissDetectIDs(); }
        if (defined $gtFrame->getFalseAlarmIDs()) { %faIDs = $gtFrame->getFalseAlarmIDs(); }

        if (%evalGTIDs) { $numOfEvalGT = scalar keys %evalGTIDs; }
        if (%evalSOIDs) { $numOfEvalSO = scalar keys %evalSOIDs; }
        if (%mdIDs) { $md = scalar keys %mdIDs; }
        if (%faIDs) { $fa = scalar keys %faIDs; }

        if (($numOfEvalGT > 0) || ($numOfEvalSO > 0)) { $fda = (2*$mappedOverlapRatio)/($numOfEvalGT + $numOfEvalSO); }
        elsif (($md > 0) || ($fa > 0)) { $fda = 0.0; }
        elsif (! $gtFrame->getDontCare()) { $fda = 1.0; }

        if (defined $fda) {
            $frameCount++;
            # my $b = sprintf("%.6f", $fda);
            # print "Frame Num: $frameNums[$loop]\t FDA: $b\n";
            # print "Missed detects are: ", join(", ", keys %mdIDs), "\n";
            # print "False alarms are: ", join(", ", keys %faIDs), "\n";
            if (defined $cfda) { $cfda += $fda; }
            else { $cfda = $fda; }
        }

    }

    if ( $frameCount > 0 ) { 
        $sfda = $cfda/$frameCount; 
        # print "CFDA: $cfda\tFRAMECOUNT: $frameCount\n"; 
    }
    return $sfda;
}

#######################

sub computeMODA {
    my ( $self, $other, $costMD, $costFA, $eval_type, $thres, $bin ) = @_;
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
    my @tmpa = keys %$gtFrameList;
    my @frameNums = MMisc::reorder_array_numerically(\@tmpa);
    my @frame_dims = ($eval_type eq "Point") ? $self->getFrameDims() : ();
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getDetOutDefined) { $gtFrame->computeAndSetSpatialMeasures($soFrame, $thres, $bin, @frame_dims); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing spatial measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1; 
        }

        my ( %mdIDs, %faIDs, %evalGTIDs );
        my ( $md, $fa, $numOfEvalGT ) = ( 0, 0, 0 );
        
        if (defined $gtFrame->getMissDetectIDs()) { %mdIDs = $gtFrame->getMissDetectIDs(); }
        if (defined $gtFrame->getFalseAlarmIDs()) { %faIDs = $gtFrame->getFalseAlarmIDs(); }
        if (defined $gtFrame->getEvalObjectIDs()) { %evalGTIDs = $gtFrame->getEvalObjectIDs(); }
        if (%mdIDs) { $md = scalar keys %mdIDs; }
        if (%faIDs) { $fa = scalar keys %faIDs; }
        if (%evalGTIDs) { $numOfEvalGT = scalar keys %evalGTIDs; }

        if ($md > 0) { 
            if (defined $cerror) { $cerror += $costMD*$md; }
            else { $cerror = $costMD*$md; }
        }

        if ($fa > 0) { 
            if (defined $cerror) { $cerror += $costFA*$fa; }
            else { $cerror = $costFA*$fa; }
        }

        if ($numOfEvalGT > 0) {
            if (defined $cng) { $cng += $numOfEvalGT; }
            else { $cng = $numOfEvalGT; }
        }

    }

    if ( $cng > 0 ) { 
        $nmoda = 1 - ($cerror/$cng); 
        # print "CERROR: $cerror\tTNG: $cng\n"; 
    }
    return $nmoda;
}

#######################

sub computeMODP {
    my ( $self, $other, $eval_type, $thres, $bin ) = @_;
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

    my @tmpa = keys %$gtFrameList;
    my @frameNums = MMisc::reorder_array_numerically(\@tmpa);
    my @frame_dims = ($eval_type eq "Point") ? $self->getFrameDims() : ();
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $modp;

        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getDetOutDefined) { $gtFrame->computeAndSetSpatialMeasures($soFrame, $thres, $bin, @frame_dims); }
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

    if ( $frameCount > 0 ) { $nmodp = $cmodp/$frameCount; }
    return $nmodp;
}

#######################

sub computeATA {
    my ( $self, $other, $eval_type, $thres, $bin ) = @_;
    my ($mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs);    

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();

    # First re-organize the hash. Currently it is a hash of frames with each frame being a hash of objects present in that frame.
    # Re-organize it as a hash of objects with each object being a hash of frames in which the object was present.
    my ( %gtObjTrks, %dcObjTrks, %soObjTrks, %gtIsEvalObj ); # gtIsEvalObj is a hash to check if a reference object was a dont care in the entire sequence

    my @tmpa = keys %$gtFrameList;
    my @frameNums = MMisc::reorder_array_numerically(\@tmpa);
    my @evalFrameNums;
    for (my $loop = 1; $loop < $#frameNums; $loop++) { 
        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        next if ($gtFrame->getDontCare());
        push @evalFrameNums, $frameNums[$loop];
        my $gtObjList = $gtFrame->getObjectList();
        
        foreach my $okey (keys %$gtObjList) {
          $gtObjTrks{$okey}{$frameNums[$loop]} = $gtObjList->{$okey};
          if (! $gtObjList->{$okey}->getDontCare()) { $gtIsEvalObj{$okey} = 1; }
          elsif (! exists $gtIsEvalObj{$okey}) { $gtIsEvalObj{$okey} = undef; }
        }
    }

    # Remove from gtObjTrks, objects that remained a dont care throughout the sequence
    foreach my $okey (keys %gtObjTrks) {
        if (! defined $gtIsEvalObj{$okey}) { 
           $dcObjTrks{$okey} = $gtObjTrks{$okey}; 
           delete $gtObjTrks{$okey};
        }
    }

    my @tmpa = keys %gtObjTrks;
    $evalObjectIDs = { MMisc::array1d_to_count_hash(\@tmpa) };
    my @tmpa = keys %dcObjTrks;
    my $dcoIDs = { MMisc::array1d_to_count_hash(\@tmpa) };

    for (my $fki = 0; $fki < scalar @evalFrameNums; $fki++) {
      my $fkey = $evalFrameNums[$fki];
      next if (($fkey == $frameNums[0]) || ($fkey == $frameNums[-1]) || (! exists $soFrameList->{$fkey}));
      my $soFrame = $soFrameList->{$fkey};
      my $soObjList = $soFrame->getObjectList();
      foreach my $okey (keys %$soObjList) {
        $soObjTrks{$okey}{$fkey} = $soObjList->{$okey};
      }
    }

    my @tmpa = keys %soObjTrks;
    $evalSOIDs = { MMisc::array1d_to_count_hash(\@tmpa) };

    my @frame_dims = ($eval_type eq "Point") ? $self->getFrameDims() : ();
    my @params = [$thres, $bin, @frame_dims];

    # Compute spatio-temporal measures using the above two hashes
    # When passed with additional parameters (frame width & frame height), the kernel function computes distance-based measures
    # Without any additional parameters, the kernel function computes area-based measures
    my $evalBPM;
    if (scalar keys %gtObjTrks > 0) {
        $evalBPM = BipartiteMatch->new(\%gtObjTrks, \%soObjTrks, \&kernelFunction, \@params);
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

    if (0 && defined $evalBPM) {
        print "EVAL OBJECT MAPPING:\n";
	$evalBPM->_display("joint_values");
   	$evalBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    my ( @unmapped_sys_ids, @temp_unmapped_sys_ids );
    if (defined $evalBPM) {
        my @mapped_ids = $evalBPM->get_mapped_ids();
        $mappedOverlapRatio = 0.0;
        $mappedObjIDs = [ @mapped_ids ];
        for (my $loop = 0; $loop < scalar @{$mappedObjIDs}; $loop++) {
            $mappedOverlapRatio += $evalBPM->get_jointvalues_refsys_value($mapped_ids[$loop][1], $mapped_ids[$loop][0]); 
        }

        my @unmapped_ref_ids = $evalBPM->get_unmapped_ref_ids();
        $mdIDs = { MMisc::array1d_to_count_hash(\@unmapped_ref_ids) };
        
        @temp_unmapped_sys_ids = $evalBPM->get_unmapped_sys_ids();
    }
    else { @temp_unmapped_sys_ids = keys %$evalSOIDs; }

    # For each unmapped_sys, check if it overlaps with a dont care object in each frame. If yes, don't penalize it. Reduce
    # the sys_count by 1.
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getDetOutDefined) { $gtFrame->computeAndSetSpatialMeasures($soFrame, $thres, $bin, @frame_dims); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing spatial measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1;
        }

        my @delIndices;
        my %frEvalSOIDs = $gtFrame->getEvalSOIDs();
        if (%frEvalSOIDs) {
            for (my $inloop = 0; $inloop < scalar @temp_unmapped_sys_ids; $inloop++) {
                # print "Checking $temp_unmapped_sys_ids[$inloop]\n";
                if ( (exists $frEvalSOIDs{$temp_unmapped_sys_ids[$inloop]}) && (! $gtFrame->isDCOOverlap($temp_unmapped_sys_ids[$inloop])) ) {
                    # print "Adding index: $inloop\n";
                    push @delIndices, $inloop;
                }
            }

            my $shiftCount = 0;
            for (my $inloop = 0; $inloop < scalar @delIndices; $inloop++) {
                my $sys_id = splice(@temp_unmapped_sys_ids, $delIndices[$inloop] - $shiftCount++, 1);
                # print "Adding $sys_id in frame $frameNums[$loop]\n";
                push @unmapped_sys_ids, $sys_id;
            }
        }
        
        # Quit if we are done already
        last if (scalar @temp_unmapped_sys_ids == 0);
    }
    
    $noPenaltySysIDs = { MMisc::array1d_to_count_hash(\@temp_unmapped_sys_ids) };

    # print "Actual false alarms: " , join(" ", MMisc::reorder_array_numerically(\@unmapped_sys_ids)) , "\n";
    $faIDs = { MMisc::array1d_to_count_hash(\@unmapped_sys_ids) };

    $self->_setSpatioTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs );

    my ($md, $fa, $numOfMappedObjs) = (0, 0, 0);
    $md = scalar keys %$mdIDs if (defined $mdIDs);
    $fa = scalar keys %$faIDs if (defined $faIDs);
    $numOfMappedObjs = scalar @$mappedObjIDs if (defined $mappedObjIDs);

    my $denominator = $numOfMappedObjs + ($md + $fa)/2;
    # print "Numerator: $mappedOverlapRatio\tDenominator: $denominator\tMD: $md\tFA: $fa\tMapped Objs: $numOfMappedObjs\n";

    my $ata = 1.0;
    
    if ($denominator > 0) { $ata = $mappedOverlapRatio/$denominator; }
    return $ata;
}

#######################

sub computeMOTA {
  my ($self, $other, $costMD, $costFA, $costIS, $eval_type, $thres, $bin,
      $logfile, $csvfile ) = @_;

  if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

  my $cerror;
  my $mota = "NA";
  my $cng = 0;

  my $outstr = "";

  if (defined $logfile) {
    $outstr .= "MOTA = 1 - ( CostMD*SumMD + CostFA*SumFA + CostIS*(SumIDSplit + SumIDMerge) ) / NumberOfEvalGT\n";
    $outstr .= "  with: [CostMD = $costMD] [CostFA = $costFA] [CostIS = $costIS]\n";
  }

  my $gtFrameList = $self->getFrameList();
  my $soFrameList = $other->getFrameList();
  
  # Just loop through the reference frames to evaluate. If systems report outside
  # of these frames, those frames will not be evaluated.
  # The reference annotations start one I-Frame earlier and end one I-Frame later
  # than the framespan mentioned in the index files. So, exclude the first
  # and the last frames from evaluation
  
  my ( $prevGTMap, $prevSOMap ) = ( {}, {} );
  my %opgtm = ();
  my @tmpa = keys %$gtFrameList;
  my @frameNums = MMisc::reorder_array_numerically(\@tmpa);
  my @frame_dims = ($eval_type eq "Point") ? $self->getFrameDims() : ();
  my $gtOcclCount = {};
  
  my ($sumMD, $sumFA, $sumIDsplit, $sumIDmerge) = (0, 0, 0, 0);
  
  for (my $loop = 1; $loop < $#frameNums; $loop++) {
    my $gtFrame = $gtFrameList->{$frameNums[$loop]};
    my $soFrame;
    if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }
    
    if (! $gtFrame->getTrkOutDefined) { $gtFrame->computeAndSetTemporalMeasures($soFrame, $prevGTMap, $prevSOMap, $gtOcclCount, $thres, $bin, @frame_dims); }
    if ( $gtFrame->error() ) { 
      $self->_set_errormsg("Error while computing temporal measures (" . $gtFrame->get_errormsg() . ")" ); 
      return -1; 
    }
    
    my ( %mdIDs, %faIDs, %idSplitObjIDs, %idMergeObjIDs, %evalGTIDs );
    my ( $md, $fa, $idSplits, $idMerges, $numOfEvalGT ) = ( 0, 0, 0, 0, 0 );
    
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
    
    my $tmp = 0;
    if ($md > 0) { 
      $tmp += $md;
      $sumMD += $md;
      if (defined $cerror) { $cerror += $costMD*$md; }
      else { $cerror = $costMD*$md; }
    }
    
    if ($fa > 0) { 
      $tmp += $fa;
      $sumFA += $fa;
      if (defined $cerror) { $cerror += $costFA*$fa; }
      else { $cerror = $costFA*$fa; }
    }
    
    if ($idSplits > 0) {
      $tmp += $idSplits;
      $sumIDsplit += $idSplits;
      if (defined $cerror) { $cerror += $costIS*$idSplits; }
      else { $cerror = $costIS*$idSplits; }
    }
    
    if ($idMerges > 0) {
      $tmp += $idMerges;
      $sumIDmerge += $idMerges;
      if (defined $cerror) { $cerror += $costIS*$idMerges; }
      else { $cerror = $costIS*$idMerges; }
    }
    
    if ($numOfEvalGT > 0) {
      if (defined $cng) { $cng += $numOfEvalGT; }
      else { $cng = $numOfEvalGT; }
    }
    
    if (defined $logfile) {
      %opgtm = $self->_MOTA_decomposer
        ($frameNums[$loop], $gtFrame, $soFrame,
         \%mdIDs, \%faIDs, \%idSplitObjIDs, \%idMergeObjIDs,
         $prevGTMap, \%opgtm, \$outstr);
      
      $outstr .= "-- MOTA frame summary : [NumberOfEvalGT: $numOfEvalGT] [MissedDetect: $md] [FalseAlarm: $fa] [IDSplit: $idSplits] [IDMerge: $idMerges]\n";
      $outstr .= "-- MOTA global summary: [NumberOfEvalGT: $cng] [MissedDetect: $sumMD] [FalseAlarm: $sumFA] [IDSplit: $sumIDsplit] [IDMerge: $sumIDmerge] => [MOTA = " . &Compute_printable_MOTA($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng) . "]\n";
    }
    # print "FRAME NUMBER: $frameNums[$loop]\tERROR: $tmp\tNG: $numOfEvalGT\n"; 
    # print "MD: $md\tFA: $fa\tSWITCH: " . ($idSplits + $idMerges) . "\n";
  }
  
  if ( $cng > 0 ) { 
    $mota = 1 - ($cerror/$cng);
    # print "CERROR: $cerror\tTNG: $cng\n";
  }

  if (defined $logfile) {
    $outstr .= "\n\n@@ END PROCESSING @@\n\n";
    $outstr .= "MOTA = 1 - ( CostMD*SumMD + CostFA*SumFA + CostIS*(SumIDSplit + SumIDMerge) ) / NumberOfEvalGT\n";
    $outstr .= "     = 1 - ( $costMD*$sumMD + $costFA*$sumFA + $costIS*($sumIDsplit + $sumIDmerge) ) / $cng\n";
    $outstr .= sprintf
      ("     = %s [conf: %s]\n",
       &Compute_printable_MOTA($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng),
       (MMisc::is_float($mota) ? sprintf("%.06f", $mota) : $mota)
      );

    $outstr .= "\n\n\n" if (MMisc::is_blank($logfile)); # Add extra CR for stdout print
    MMisc::error_quit("Problem while trying to write MOTA log file ($logfile)")
        if (! MMisc::writeTo($logfile, ".tracking_log", 1, 0, $outstr));
  }

  if (defined $csvfile) {
    my @cheader = ("CostMD", "SumMD", "CostFA", "SumFA", "CostIS", "SumIDSplit", "SumIDMerge", "NumberOfEvalGT", "MOTA");
    my @cvals = ($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng, $mota);
    my $csvh = new CSVHelper();
    $csvh->set_number_of_columns(scalar @cheader);

    my $csvstr = "";

    my $line = $csvh->array2csvline(@cheader);
    MMisc::error_quit("Problem with CSV line: " . $csvh->get_errormsg())
        if ($csvh->error());
    $csvstr .= "$line\n";

    my $line = $csvh->array2csvline(@cvals);
    MMisc::error_quit("Problem with CSV line: " . $csvh->get_errormsg())
        if ($csvh->error());
    $csvstr .= "$line\n";

    MMisc::error_quit("Problem while trying to write MOTA CSV file ($csvfile)")
        if (! MMisc::writeTo($csvfile, "-MOTA_Components.csv", 1, 0, $csvstr));
  }

  return($mota);
}

#######################

sub computeMOTP {
    my ( $self, $other, $eval_type, $thres, $bin ) = @_;
    my ( $motp, $covlpRatio, $cnumOfMappedObjs );

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();

    # Just loop through the reference frames to evaluate. If systems report outside
    # of these frames, those frames will not be evaluated.
    # The reference annotations start one I-Frame earlier and end one I-Frame later
    # than the framespan mentioned in the index files. So, exclude the first
    # and the last frames from evaluation

    my ( $prevGTMap, $prevSOMap ) = ( {}, {} );
    my @tmpa = keys %$gtFrameList;
    my @frameNums = MMisc::reorder_array_numerically(\@tmpa);
    my @frame_dims = ($eval_type eq "Point") ? $self->getFrameDims() : ();
    my $gtOcclCount = {};

    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getTrkOutDefined) { $gtFrame->computeAndSetTemporalMeasures($soFrame, $prevGTMap, $prevSOMap, $gtOcclCount, $thres, $bin, @frame_dims); }
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

    if ( $cnumOfMappedObjs > 0 ) { $motp = $covlpRatio/$cnumOfMappedObjs; }
    return $motp;
}

#######################

sub computeARPM {
    my ( $self, $other, $spatialWeight, $cerWeight, $costInsDel, $costSub, $eval_type, $thres, $bin ) = @_;
    my ( $cwerror, $totwords, $ccerror, $totchars, $arpm_w, $arpm_c );

    if (! defined $other ) { $self->_set_errormsg("Undefined system output"); return -1; }

    my $gtFrameList = $self->getFrameList();
    my $soFrameList = $other->getFrameList();
    my $frameCount = 0;

    # Just loop through the reference frames to evaluate. If systems report outside
    # of these frames, those frames will not be evaluated.
    # The reference annotations start one I-Frame earlier and end one I-Frame later
    # than the framespan mentioned in the index files. So, exclude the first
    # and the last frames from evaluation

    my @tmpa = keys %$gtFrameList;
    my @frameNums = MMisc::reorder_array_numerically(\@tmpa);
    my @frame_dims = ($eval_type eq "Point") ? $self->getFrameDims() : ();
    for (my $loop = 1; $loop < $#frameNums; $loop++) {
        my $gtFrame = $gtFrameList->{$frameNums[$loop]};
        my $soFrame;
        if (exists $soFrameList->{$frameNums[$loop]}) { $soFrame = $soFrameList->{$frameNums[$loop]}; }

        if (! $gtFrame->getTRecOutDefined()) { $gtFrame->computeAndSetTextRecMeasures($soFrame, $thres, $bin, $spatialWeight, $cerWeight, $costInsDel, $costSub, @frame_dims); }
        if ( $gtFrame->error() ) { 
            $self->_set_errormsg("Error while computing text recognition measures (" . $gtFrame->get_errormsg() . ")" ); 
            return -1;
        }
        
        my ( %evalGTIDs, %mdIDs, %faIDs, @subIDs );
        my ( $numOfEvalGT, $md, $fa, $subs ) = ( 0, 0, 0, 0 );
		  
        if (defined $gtFrame->getEvalObjectIDs())   { %evalGTIDs = $gtFrame->getEvalObjectIDs(); }
        if (defined $gtFrame->getMissDetectIDs())   { %mdIDs = $gtFrame->getMissDetectIDs(); }
        if (defined $gtFrame->getFalseAlarmIDs())   { %faIDs = $gtFrame->getFalseAlarmIDs(); }
	if (defined $gtFrame->getSubstitutionIDs()) { @subIDs = $gtFrame->getSubstitutionIDs(); }

        if (%evalGTIDs) { $numOfEvalGT = scalar keys %evalGTIDs; }
        if (%mdIDs)     { $md = scalar keys %mdIDs; } # Word Deletion errors
        if (%faIDs)     { $fa = scalar keys %faIDs; } # Word Insertion errors
	if (@subIDs)    { $subs = scalar @subIDs; }   # Word Substitution errors

        if ($md > 0) { 
            if (defined $cwerror) { $cwerror += $costInsDel*$md; }
            else { $cwerror = $costInsDel*$md; }
        }

        if ($fa > 0) { 
            if (defined $cwerror) { $cwerror += $costInsDel*$fa; }
            else { $cwerror = $costInsDel*$fa; }
        }

        if ($subs > 0) { 
            if (defined $cwerror) { $cwerror += $costSub*$subs; }
            else { $cwerror = $costSub*$subs; }
        }

        if ($numOfEvalGT > 0) {
            if (defined $totwords) { $totwords += $numOfEvalGT; }
            else { $totwords = $numOfEvalGT; }
        }

        if (defined $ccerror) { $ccerror += $gtFrame->getNumOfCharErrs(); }
        else { $ccerror = $gtFrame->getNumOfCharErrs(); }

        if (defined $totchars) { $totchars += $gtFrame->getNumOfChars(); }
        else { $totchars = $gtFrame->getNumOfCharErrs(); }

    }

    if ( defined $totwords ) { $arpm_w = 1 - ($cwerror/$totwords); }
    if ( defined $totchars ) { $arpm_c = 1 - ($ccerror/$totchars); }

    return ($arpm_w, $arpm_c);
}

#######################

sub kernelFunction {
    my ( $ref, $sys, $params ) = @_;

    if ( (defined $ref) && (defined $sys) ) {
        return (&computeSpatioTemporalOverlapRatio( $ref, $sys, $params ));
    } elsif ( (! defined $ref) && (defined $sys) ) {
        return ("", 0);
    } elsif ( (defined $ref) && (! defined $sys) ) {
        return ("", 0);
    }

    # Return error if both are undefined
    return ("This case is undefined", undef);
}

#######################

sub computeSpatioTemporalOverlapRatio {
    my ( $ref, $sys, $params ) = @_;

    my %gtObjFrameList = %$ref;
    my %soObjFrameList = %$sys;

    my @tmpa = keys %gtObjFrameList;
    my @gtObjFrameNums = MMisc::reorder_array_numerically(\@tmpa);
    my ( $intCount, $gtDCCount, $spatioTemporalOverlap ) = ( 0, 0, 0 );

    my ( $ref_object_id, $sys_object_id);

    for (my $gtoi = 0; $gtoi < scalar @gtObjFrameNums; $gtoi++) {
      my $gtObjFrameNum = $gtObjFrameNums[$gtoi];
      my $refObject = $gtObjFrameList{$gtObjFrameNum};
      if ($refObject->getDontCare()) { $gtDCCount++; }
      
      next if (! exists $soObjFrameList{$gtObjFrameNum});
      my $sysObject = $soObjFrameList{$gtObjFrameNum};
      
      $ref_object_id = $refObject->getId();
      $sys_object_id = $sysObject->getId();
      
      my ($txt, $overlap) = CLEARObject::kernelFunction($refObject, $sysObject, $params);
      if (! MMisc::is_blank($txt)) { return("Error while computing overlap between objects ($txt). ", undef); }
      
      if (defined $overlap) { 
        if (! $refObject->getDontCare()) { $spatioTemporalOverlap += $overlap; }
        $intCount++;
      }
    }

    my $numOfFrames = (scalar keys %gtObjFrameList) - $gtDCCount + (scalar keys %soObjFrameList) - $intCount;
    my $retVal;
    
    if ($spatioTemporalOverlap > 0) { 
        $retVal = $spatioTemporalOverlap/$numOfFrames; 
        # print "GT ID: $ref_object_id \tGTCount: " . ((scalar keys %gtObjFrameList) - $gtDCCount) . "\tSO ID: $sys_object_id \tSOCount: " . (scalar keys %soObjFrameList) . "\tintCount: $intCount \tunionNum: $numOfFrames \t Overlap: $spatioTemporalOverlap \tValue: $retVal\tDCCount: $gtDCCount\n"; 
        # print "GT frames are: ", join(", ", @gtObjFrameNums) , "\n";
        # my @tmpa = keys %soObjFrameList;
        # print "SO frames are: ", join(", ", MMisc::reorder_array_numerically(\@tmpa)) , "\n";
        # print(Dumper(\%gtObjFrameList));
    }

    return("", $retVal);
}

#######################

sub set_as_validated {
  my ($self) = @_;

  $self->{_validated} = 1;
}

sub is_validated {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{_validated} == 1);

  return(0);
}

########## 'gtf'

sub set_as_gtf {
  my ($self) = @_;

  return(0) if ($self->error());

  $self->{gtf} = 1;
  return(1);
}

#####

sub check_if_gtf {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{gtf});
}

#####

sub check_if_sys {
  my ($self) = @_;

  return(0) if ($self->error());

  my $r = ($self->{gtf}) ? 0 : 1;

  return($r);
}

#######################

sub setEvalObj {
    my ( $self, $evalObj ) = @_;

    if(! defined $evalObj ) { $self->_set_errormsg("Invalid 'evalObj' in setEvalObj"); return -1; }
    $self->{_evalObj} = $evalObj;
}

sub getEvalObj {
    my ( $self ) = @_;
    return $self->{_evalObj};
}

#######################

sub splitTextLineObjects {
    my ( $self ) = @_;

    my $PI = 3.1415926535897932384626433;

    my $frameList = $self->getFrameList();
    my @tmpa = keys %$frameList;
    my @frameNums = MMisc::reorder_array_numerically(\@tmpa);
    
    for (my $fni = 0; $fni < scalar @frameNums; $fni++) {
      my $frameNum = $frameNums[$fni];

        my $objectList = $frameList->{$frameNum}->getObjectList();

        next if (! defined $objectList);
        foreach my $object_id (keys %$objectList) {
            # Go to the next object if it is a dont care object.
            next if ( $objectList->{$object_id}->getDontCare() );

            my $tmp = $objectList->{$object_id}->getOffset();
            my @offsets = split(/\s+/, $tmp);

            my $tmp = $objectList->{$object_id}->getContent();
            my @content = split(/\s+/, $tmp);

            # Check if number of offsets is one less than the number of words in content
            # If not, make this object a dont care object
            if (scalar @offsets != $#content) {
                $objectList->{$object_id}->setDontCare(1);
                next;
            }

            # Cannot break down further if there are no offsets specified.
            next if ( scalar @offsets == 0 );

            my $currOBox            = $objectList->{$object_id}->getOBox();
            my $currX               = $currOBox->getX();
            my $currY               = $currOBox->getY();
            my $currWidth           = $currOBox->getWidth();
            my $currHeight          = $currOBox->getHeight();
            my $currOrientation     = $currOBox->getOrientation();
            my $orientation_rads    = $currOrientation/180.0*$PI;

            for (my $inloop = 0; $inloop < scalar @content; $inloop++) {
                my $child_object_id = sprintf("%d.%02d", $object_id, $inloop);

                my ($newX, $newY, $newWidth, $newHeight, $newOrientation);

                if ($inloop == 0) { 
                    $newX           = $currX;
                    $newY           = $currY;
                    $newWidth       = $offsets[$inloop]; 
                    $newHeight      = $currHeight;
                    $newOrientation = $currOrientation;
                }
                elsif ($inloop == scalar @offsets) {
                    $newX           = sprintf("%.0f", $currX + $offsets[$inloop-1]*cos($orientation_rads));
                    $newY           = sprintf("%.0f", $currY - $offsets[$inloop-1]*sin($orientation_rads));
                    $newWidth       = $currWidth - $offsets[$inloop-1]; 
                    $newHeight      = $currHeight;
                    $newOrientation = $currOrientation;
                }
                elsif ($inloop < scalar @offsets) {
                    $newX           = sprintf("%.0f", $currX + $offsets[$inloop-1]*cos($orientation_rads));
                    $newY           = sprintf("%.0f", $currY - $offsets[$inloop-1]*sin($orientation_rads));
                    $newWidth       = $offsets[$inloop] - $offsets[$inloop-1]; 
                    $newHeight      = $currHeight;
                    $newOrientation = $currOrientation;
                }
                else {
                    $self->_set_errormsg("WEIRD: We shouldn't have got here. The number of words is greater than the number of offsets specified (Object ID: $object_id).");
                    return(0);
                }
                
                my $child_object = CLEARObject->new($child_object_id);
                if(ref($child_object) ne "CLEARObject") {
                  $self->_set_errormsg("Failed 'CLEARObject' instance creation ($child_object)");
                  return(0);
                }
                
                my $child_location = CLEAROBox->new($newX, $newY, $newHeight, $newWidth, $newOrientation);
                if (ref($child_location) ne "CLEAROBox") {
                  $self->_set_errormsg("Failed 'CLEAROBox' object instance creation ($child_location)");
                  return(0);
                }

                $child_object->setOBox($child_location);
                $child_object->setContent($content[$inloop]);
                $child_object->setDontCare($objectList->{$object_id}->getDontCare());
                
                $frameList->{$frameNum}->addToObjectList($child_object);
                if ($frameList->{$frameNum}->error()) {
                  $self->_set_errormsg("Error adding object ID: $child_object_id to framenum: $frameNum (" . $frameList->{$frameNum}->get_errormsg() . ")");
                  return(0);
                }
                    
            }
            $frameList->{$frameNum}->removeObjectFromFrame($object_id);
        }
    }

    return(1);
}

########################################

sub __get_obj_info {
  my ($obj) = @_;

  my $id = $obj->getId();
  my $ob = $obj->getOBox();
  my $pt = $obj->getPoint();
  my ($x, $y, $w, $h, $o, $sptxt) = (0, 0, 0, 0, 0, "");
  if (defined $ob) {
    ($x, $y, $w, $h, $o) = 
      ( $ob->getX(), $ob->getY(), $ob->getWidth(), $ob->getHeight(),
        $ob->getOrientation() );
  } elsif (defined $pt) {
    ($x, $y) = ( $pt->getX(), $pt->getY() );
  } else {
    $sptxt = "Warning: No obox or point defined";
  }
  my $dc = ($obj->getDontCare() == 1) ? "DCO" : "";

  return($id, $x, $y, $w, $h, $o, $dc, $sptxt);
}
 
##### 

sub __find_hash_key {
  my ($key, %h) = @_;

  foreach my $k (keys %h) {
    return($k) if ($h{$k} eq $key);
  }

  return(undef);
}

#####

sub __print_prevmatch {
  my ($rgtIDs, $rsoIDs, $pgt, $routstr) = @_;

  foreach my $rid (sort keys %$rgtIDs) {
    next if (! exists $$pgt{$rid});
    my $sid = $$pgt{$rid};
    next if (! exists $$rsoIDs{$sid});
    $$routstr .= "== Mapped : SYS $sid -> REF $rid [previously matched]\n";
  }
}

#####

sub Compute_MOTA {
  my ($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng) = @_;
  return(CLEARMetrics::computeMOTA($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng));
}

#####

sub Compute_printable_MOTA {
  my ($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng) = @_;

  return(CLEARMetrics::computePrintableMOTA($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng));
}

#####

sub _sprintf_object_values {
  my ($id, $x, $y, $w, $h, $o, $dc, $spstr) = @_;

  my $str = "$id";

  if (! MMisc::is_blank($spstr)) {
    $str .= " {$spstr} $dc";
    return($str);
  }

  my $type = (($w == 0) && ($h == 0) && ($o == 0)) ? "point" : "obox";
  $str .= " $type";
  $str .= "[x=$x y=$y";
  if ($type eq "obox") {
    $str .= " w=$w h=$h o=$o";
  }
  $str .= "] $dc";

  return($str);
}

#####

sub _MOTA_decomposer {
  my ($self, $fnum, $gtFrame, $soFrame,
     $rmdIDs, $rfaIDs, $rspIDs, $rmrIDs,
      $pgt, $opgt, $routstr)
    = @_;

  $$routstr .= "\n\n***** Evaluated Frame: $fnum\n";

  my $gtObjList = $gtFrame->getObjectList();
  my $NG = scalar keys %$gtObjList;
  my %gtIDs = ();

  $$routstr .= "## Number of REF Objects: $NG\n";
  foreach my $key (sort keys %$gtObjList) {
    my $obj = $$gtObjList{$key};
    my ($id, $x, $y, $w, $h, $o, $dc, $spstr) = &__get_obj_info($obj);
    $$routstr .= "++ REF "
      . &_sprintf_object_values($id, $x, $y, $w, $h, $o, $dc, $spstr) . "\n";
    $gtIDs{$id}++ if ($dc eq "");
  }

  my $soObjList = undef;
  my $NS = 0;
  my %soIDs = ();
  if ($soFrame) {
    $soObjList = $soFrame->getObjectList();
    $NS = scalar keys %$soObjList;
  }
  $$routstr .= "## Number of SYS Objects: $NS\n";
  if ($NS > 0) {
    foreach my $key (sort keys %$soObjList) {
      my $obj = $$soObjList{$key};
      my ($id, $x, $y, $w, $h, $o, $dc, $spstr) = &__get_obj_info($obj);
      $$routstr .= "++ SYS "
        . &_sprintf_object_values($id, $x, $y, $w, $h, $o, $dc, $spstr) . "\n";
      $soIDs{$id}++ if ($dc eq "");
    }
  }

  # Prints
  if ((defined $rmdIDs) && (%$rmdIDs)) {
    foreach my $key (keys %$rmdIDs) {
      $$routstr .= "== MD : REF $key\n";
      delete $gtIDs{$key}; # to avoid that a MD be relisted as mapped
    }
  }

  if ((defined $rfaIDs) && (%$rfaIDs)) {
    foreach my $key (keys %$rfaIDs) {
      $$routstr .= "== FA : SYS $key\n";
      delete $soIDs{$key}; # to avoid that a FA be relisted as mapped
    }
  }

  if ((defined $rspIDs) && (%$rspIDs)) {
    foreach my $key (keys %$rspIDs) {
      my $from = $$opgt{$key};
      my $to = $$pgt{$key};
      $$routstr .= "== ID Split : REF $key (SYS $from -> $to)\n"; 
    }
  }

  if ((defined $rmrIDs) && (%$rmrIDs)) {
    foreach my $key (keys %$rmrIDs) {
      my $id1 = &__find_hash_key($key, %$opgt);
      my $id2 = &__find_hash_key($key, %$pgt);
      $$routstr .= "== ID Merge : SYS $key (REF $id1 & $id2)\n";
    }
  }

  # BPM check
  my $bpm = $gtFrame->getEvalBPM();
  if (! defined $bpm) {
#    $$routstr .= "-> Undefined BPM\n";
    &__print_prevmatch(\%gtIDs, \%soIDs, $pgt, $routstr);
    return(MMisc::clone(%$pgt));
  }

  my @mapl = $bpm->get_mapped_ids();
  if (@mapl) {
    for (my $mai = 0; $mai < scalar @mapl; $mai++) {
      my $ra = $mapl[$mai];
      my @a = @$ra;
      my $rid = $a[1];
      my $sid = $a[0];
      my ($ov) = $bpm->get_jointvalues_refsys_value($rid, $sid);
      MMisc::error_quit("Problem obtaining jointvalue ($rid/$sid) : " . $bpm->get_errormsg()) if ($bpm->error());
      $$routstr .= "== Mapped : SYS $sid -> REF $rid [ov: $ov]\n";
      delete $gtIDs{$rid}; # to avoid that a Mapped REF be relisted as prev mapped
      delete $soIDs{$sid}; # to avoid that a Mapped SYS be relisted as prev mapped
    }
  }
  # Previously mapped ?
  &__print_prevmatch(\%gtIDs, \%soIDs, $pgt, $routstr);

  return(MMisc::clone(%$pgt));
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

########################################

1;
