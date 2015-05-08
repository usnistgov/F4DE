package CLEARFrame;
#
# $Id$
#
# CLEARFrame
#
# Author(s): Vasant Manohar
# Additions: Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEARFrame.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

use CLEARObject;
use BipartiteMatch;
use MErrorH;
use MMisc;
use Data::Dumper;

# Constructor 
# Using double-argument form of bless() for an inheritable constructor
# Rather than being uniquely a class method, we'll set it up so that 
# it can be called as either a class method or an object method.

#######################

sub new {
    my ( $proto, $frameNum ) = @_;
    my $class = ref($proto) || $proto;

    my $_errormsg = MErrorH->new("CLEARFrame");
    my $errortxt  = "";
    $_errormsg->set_errormsg($errortxt);

    my $self = 
        {
        _frameNum           => $frameNum,
        _objectList         => undef,
        _dontCare           => undef,
        _evalObjectIDs      => undef,
        _dontCareObjectIDs  => undef,
        #Output
        _mappedOverlapRatio => undef,
        _mappedObjIDs       => undef,
        _evalSOIDs          => undef,
        _noPenaltySysIDs    => undef,
        _missDetectIDs      => undef,
        _falseAlarmIDs      => undef,
	_substitutionIDs    => undef,
        _idSplitObjIDs      => undef,
        _idMergeObjIDs      => undef,
        _evalBPM            => undef,
        _dcoBPM             => undef,
        _numOfChars         => undef,
        _numOfCharErrs      => undef,
        _isDet              => 0,
        _isTrk              => 0,
        _isTRec             => 0,
        #ErrorHandler
        _errormsg           => $_errormsg,
        };

    return "'frameNum' not defined" if (! defined $frameNum);
    return "'frameNum' cannot be negative" if ($frameNum < 0);
    bless ( $self, $class );
    return $self;
}

#######################

sub unitTest {
    print "Test CLEARFrame\n";

    return 1;
}

#######################

sub getFrameNum {
    my ( $self ) = @_;
    
    return $self->{_frameNum};
}

#######################

sub setDontCare {
    my ( $self, $dontCare ) = @_;

    if (! defined $dontCare)   { $self->_set_errormsg("'dontCare' not defined in setDontCare"); return -1;}
    $self->{_dontCare} = $dontCare;
}

sub getDontCare {
    my ( $self ) = @_;
    return $self->{_dontCare};
}

#######################

sub addToObjectList {
    my ( $self, $object ) = @_;

    if (! defined $object)   { $self->_set_errormsg("Invalid 'object' in addToObjectList"); return -1; } 
    my $objectId = $object->getId();
    if (! defined $objectId) { $self->_set_errormsg("Invalid Object ID in addToObjectList"); return -1; }
    if (! defined $self->{_objectList}) { $self->{_objectList} = {}; }
    if (exists $self->{_objectList}{$objectId}) { $self->_set_errormsg("Two objects with the same ID"); return -1; }
    $self->{_objectList}{$objectId} = $object;
}

sub getObjectList {
    my ( $self ) = @_;
    return $self->{_objectList};
}

sub setObjectList {
    my ( $self, $objectList ) = @_;

    if (! defined $objectList) { $self->_set_errormsg("Invalid 'objectList' in setObjectList"); return -1; }
    $self->{_objectList} = $objectList;
}

#######################

sub setDontCareObjectIDs {
    my ( $self ) = @_;
    my $objList = $self->getObjectList();

    $self->{_dontCareObjectIDs} = {};
    my @tmpa = keys %$objList;
    for (my $oi = 0; $oi < scalar @tmpa; $oi++) {
      my $okey = $tmpa[$oi];
        if ( $objList->{$okey}->getDontCare() ) { 
            $self->{_dontCareObjectIDs}{$okey} = 1; 
        }
    }
}

sub getDontCareObjectIDs {
    my ( $self ) = @_;
    if (! defined $self->{_dontCareObjectIDs} ) { return $self->{_dontCareObjectIDs}; }
    return %{$self->{_dontCareObjectIDs}};
}

#######################

sub removeObjectFromFrame {
    my ( $self, $objectId ) = @_;
    my $objList = $self->getObjectList();

    if (! defined $objectId)             { $self->_set_errormsg("Invalid 'objectId' in removeObjectFromFrame"); return -1; }
    if (! exists $objList->{$objectId} ) { $self->_set_errormsg("'objectId' not present in removeObjectFromFrame"); return -1; }

    delete $objList->{$objectId};
}

#######################

sub _setNumOfChars {
    my ( $self, $numOfChars ) = @_;
    $self->{_numOfChars} = $numOfChars;
}

sub getNumOfChars {
    my ( $self ) = @_;
    return $self->{_numOfChars};
}

#######################

sub _setNumOfCharErrs {
    my ( $self, $numOfCharErrs ) = @_;
    $self->{_numOfCharErrs} = $numOfCharErrs;
}

sub getNumOfCharErrs {
    my ( $self ) = @_;
    return $self->{_numOfCharErrs};
}

#######################

sub _setDetOutDefined {
    my ( $self ) = @_;
    if ($self->getDetOutDefined) { $self->_set_errormsg("Detection output already defined for frame"); return -1; }
    $self->{_isDet} = 1;
}

sub _unsetDetOutDefined {
    my ( $self ) = @_;
    $self->{_isDet} = 0;
}

sub getDetOutDefined {
    my ( $self ) = @_;
    return $self->{_isDet};
}

#######################

sub _setTrkOutDefined {
    my ( $self ) = @_;
    if ($self->getTrkOutDefined) { $self->_set_errormsg("Tracking output already defined for frame"); return -1; }
    $self->{_isTrk} = 1;
}

sub _unsetTrkOutDefined {
    my ( $self ) = @_;
    $self->{_isTrk} = 0;
}

sub getTrkOutDefined {
    my ( $self ) = @_;
    return $self->{_isTrk};
}

#######################

sub _setTRecOutDefined {
    my ( $self ) = @_;
    if ($self->getTRecOutDefined) { $self->_set_errormsg("Text Recognition output already defined for frame"); return -1; }
    $self->{_isTRec} = 1;
}

sub _unsetTRecOutDefined {
    my ( $self ) = @_;
    $self->{_isTRec} = 0;
}

sub getTRecOutDefined {
    my ( $self ) = @_;
    return $self->{_isTRec};
}

#######################

sub setEvalObjectIDs {
    my ( $self ) = @_;
    my $objList = $self->getObjectList();

    if (! defined $self->{_evalObjectIDs}) { $self->{_evalObjectIDs} = {}; }
    my @tmpa = keys %$objList;
    for (my $oi = 0; $oi < scalar @tmpa; $oi++) {
      my $okey = $tmpa[$oi];
        if (! $objList->{$okey}->getDontCare() ) { 
            $self->{_evalObjectIDs}{$okey} = 1; 
        }
    }
}

sub getEvalObjectIDs {
    my ( $self ) = @_;
    if (! defined $self->{_evalObjectIDs}) { return $self->{_evalObjectIDs}; }
    return %{$self->{_evalObjectIDs}};
}

#######################

sub _setSpatialMeasures {
    my ( $self, $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $missDetectIDs, $falseAlarmIDs ) = @_;

    if ( $self->error() ) { return -1; }
    
    $self->_setDetOutDefined();
    if ( $self->error() ) { return -1; }

    $self->{_mappedOverlapRatio}    = $mappedOverlapRatio;
    $self->{_mappedObjIDs}          = $mappedObjIDs;
    $self->{_evalObjectIDs}         = $evalObjectIDs;
    $self->{_evalSOIDs}             = $evalSOIDs;
    $self->{_noPenaltySysIDs}       = $noPenaltySysIDs;
    $self->{_missDetectIDs}         = $missDetectIDs;
    $self->{_falseAlarmIDs}         = $falseAlarmIDs;
}

sub _setTemporalMeasures {
    my ( $self, $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $missDetectIDs, $falseAlarmIDs, $idSplitObjIDs, $idMergeObjIDs ) = @_;

    if ( $self->error() ) { return -1; }
    
    $self->_setTrkOutDefined();
    if ( $self->error() ) { return -1; }

    $self->{_mappedOverlapRatio}    = $mappedOverlapRatio;
    $self->{_mappedObjIDs}          = $mappedObjIDs;
    $self->{_evalObjectIDs}         = $evalObjectIDs;
    $self->{_evalSOIDs}             = $evalSOIDs;
    $self->{_noPenaltySysIDs}       = $noPenaltySysIDs;
    $self->{_missDetectIDs}         = $missDetectIDs;
    $self->{_falseAlarmIDs}         = $falseAlarmIDs;
    $self->{_idSplitObjIDs}         = $idSplitObjIDs;
    $self->{_idMergeObjIDs}         = $idMergeObjIDs;
}

sub _setTextRecMeasures {
    my ( $self, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $missDetectIDs, $falseAlarmIDs, $substitutionIDs ) = @_;

    if ( $self->error() ) { return -1; }
    
    $self->_setTRecOutDefined();
    if ( $self->error() ) { return -1; }

    $self->{_mappedObjIDs}          = $mappedObjIDs;
    $self->{_evalObjectIDs}         = $evalObjectIDs;
    $self->{_evalSOIDs}             = $evalSOIDs;
    $self->{_noPenaltySysIDs}       = $noPenaltySysIDs;
    $self->{_missDetectIDs}         = $missDetectIDs;
    $self->{_falseAlarmIDs}         = $falseAlarmIDs;
    $self->{_substitutionIDs}       = $substitutionIDs;
}

#######################

sub getMappedOverlapRatio {
    my ( $self ) = @_;
    return $self->{_mappedOverlapRatio};
}

sub getMappedObjIDs {
    my ( $self ) = @_;
    if (! defined $self->{_mappedObjIDs}) { return $self->{_mappedObjIDs}; }
    return ( @{$self->{_mappedObjIDs}} );
}

sub getEvalSOIDs {
    my ( $self ) = @_;
    if (! defined $self->{_evalSOIDs}) { return $self->{_evalSOIDs}; }
    return %{$self->{_evalSOIDs}};
}

sub getNoPenaltySysIDs {
    my ( $self ) = @_;
    if (! defined $self->{_noPenaltySysIDs}) { return $self->{_noPenaltySysIDs}; }
    return ( %{$self->{_noPenaltySysIDs}} );
}

sub getMissDetectIDs {
    my ( $self ) = @_;
    if (! defined $self->{_missDetectIDs}) { return $self->{_missDetectIDs}; }
    return ( %{$self->{_missDetectIDs}} );
}

sub getFalseAlarmIDs {
    my ( $self ) = @_;
    if (! defined $self->{_falseAlarmIDs}) { return $self->{_falseAlarmIDs}; }
    return ( %{$self->{_falseAlarmIDs}} );
}

sub getSubstitutionIDs {
    my ( $self ) = @_;
    if (! defined $self->{_substitutionIDs}) { return $self->{_substitutionIDs}; }
    return ( @{$self->{_substitutionIDs}} );
}

sub getIDSplitObjIDs {
    my ( $self ) = @_;
    if (! defined $self->{_idSplitObjIDs}) { return $self->{_idSplitObjIDs}; }
    return ( %{$self->{_idSplitObjIDs}} );
}

sub getIDMergeObjIDs {
    my ( $self ) = @_;
    if (! defined $self->{_idMergeObjIDs}) { return $self->{_idMergeObjIDs}; }
    return ( %{$self->{_idMergeObjIDs}} );
}

#######################

sub _storeBPM {
    my ( $self, $evalBPM, $dcoBPM ) = @_;

    if ( $self->error() ) { return -1; }

    $self->{_evalBPM}   = $evalBPM;
    $self->{_dcoBPM}    = $dcoBPM;
}

sub getEvalBPM {
    my ( $self ) = @_;
    return ( $self->{_evalBPM} );
}

sub getDCOBPM {
    my ( $self ) = @_;
    return ( $self->{_dcoBPM} );
}

#######################

sub computeAndSetSpatialMeasures {
    my ($self, $other, $thres, $bin, @frame_dims) = @_;
    my ($mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs);
    my @params = [$thres, $bin, @frame_dims];

    if ($self->getDontCare()) { 
        $self->_setSpatialMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs ); 
        return 1;
    }

    my $gtObjList = $self->getObjectList();
    my $NG = scalar keys %$gtObjList;

    my $dcoIDs;
    if (defined $self->getDontCareObjectIDs() ) { $dcoIDs = { $self->getDontCareObjectIDs() }; }
    else {
        $self->setDontCareObjectIDs();
        $dcoIDs = { $self->getDontCareObjectIDs() };
    }

    if (defined $self->getEvalObjectIDs() ) { $evalObjectIDs = { $self->getEvalObjectIDs() }; } 
    else {
        $self->setEvalObjectIDs();
        $evalObjectIDs = { $self->getEvalObjectIDs() }; 
    }

    if (! defined $other ) { 
        $mdIDs = $evalObjectIDs;
        $self->_setSpatialMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs );
        return 1;
    }

    my $soFrameNum = $other->getFrameNum();
    my $soObjList = $other->getObjectList();
    my @tmpa = keys %$soObjList;
    $evalSOIDs = { MMisc::array1d_to_count_hash(\@tmpa) };
    my $ND = scalar keys %$evalSOIDs;

    # Check for simple cases
    if ( ($NG == 0) || ($ND == 0) ) {
        $mdIDs = $evalObjectIDs;
        $faIDs = $evalSOIDs;
        $self->_setSpatialMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs );
        return 1;
    }

    # Start computation when both NG and ND is > 0
    my ( $evalGTObjs, $dcGTObjs );
    my @tmpa = keys %$gtObjList;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      my $key = $tmpa[$ki];
        if ($self->{_dontCareObjectIDs}{$key}) { $dcGTObjs->{$key} = $gtObjList->{$key}; } 
        else { $evalGTObjs->{$key} = $gtObjList->{$key}; }
    }
    
    # When passed with additional parameters (frame width & frame height), the kernel function computes distance-based measures
    # Without any additional parameters, the kernel function computes area-based measures
    my $evalBPM;
    if (scalar keys %$evalObjectIDs > 0) {
        $evalBPM = BipartiteMatch->new($evalGTObjs, $soObjList, \&CLEARObject::kernelFunction, \@params);
        if ($evalBPM->error()) { 
            $self->_set_errormsg( "Error while creating Evaluation Bipartite Matching object in computeAndSetSpatialMeasures (" . $evalBPM->get_errormsg() . ")" ); 
            return -1; 
        }
        $evalBPM->compute();
        if ($evalBPM->error()) { 
            $self->_set_errormsg( "Error while computing Evaluation Bipartite Matching in computeAndSetSpatialMeasures (" . $evalBPM->get_errormsg() . ")" ); 
            return -1; 
        }
    }

    my $dcoBPM;
    if (scalar keys %$dcoIDs > 0) {
        $dcoBPM = BipartiteMatch->new($dcGTObjs, $soObjList, \&CLEARObject::kernelFunction, \@params);
        if ($dcoBPM->error()) { 
            $self->_set_errormsg( "Error while creating Dont Care Bipartite Matching object in computeAndSetSpatialMeaures (" . $dcoBPM->get_errormsg() . ")" ); 
            return -1; 
        }
        $dcoBPM->compute();
        if ($dcoBPM->error()) { 
            $self->_set_errormsg( "Error while computing Dont Care Bipartite Matching in computeAndSetSpatialMeasures (" . $dcoBPM->get_errormsg() . ")" ); 
            return -1; 
        }
    }

    # First display reference eval objects mapping
    if (0 && defined $evalBPM) {
        print "EVAL OBJECT MAPPING:\n";
	$evalBPM->_display("joint_values");
   	$evalBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    # Next display reference dont care objects mapping
    if (0 && defined $dcoBPM) {
        print "DONT CARE OBJECT MAPPING:\n";
        $dcoBPM->_display("joint_values");
        $dcoBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    if (defined $evalBPM) {
            my @mapped_ids = $evalBPM->get_mapped_ids();
            $mappedObjIDs = [ @mapped_ids ];
            $mappedOverlapRatio = 0.0;
            for (my $loop = 0; $loop < scalar @{$mappedObjIDs}; $loop++) {
                     $mappedOverlapRatio += $evalBPM->get_jointvalues_refsys_value($mapped_ids[$loop][1], $mapped_ids[$loop][0]); 
            }

            my @unmapped_ref_ids = $evalBPM->get_unmapped_ref_ids();
            $mdIDs = { MMisc::array1d_to_count_hash(\@unmapped_ref_ids) };
            
            # For each unmapped_sys, check if it overlaps with a dont care object. If yes, don't penalize it. Reduce
            # the sys_count by 1.
            my @unmapped_sys_ids = $evalBPM->get_unmapped_sys_ids();
            if (defined $dcoBPM) {
                     for (my $loop = 0; $loop < scalar @unmapped_sys_ids; $loop++) {
                                   my @gtDCOList = $dcoBPM->get_jointvalues_sys_defined_list($unmapped_sys_ids[$loop]);
                                   if (scalar @gtDCOList > 0) { 
                                            $noPenaltySysIDs->{$unmapped_sys_ids[$loop]} = 1; 
                                            delete $evalSOIDs->{$unmapped_sys_ids[$loop]};
                                   }
                                   else {
                                            $faIDs->{$unmapped_sys_ids[$loop]} = 1;
                                   }
                     }
            }
            else { $faIDs = { MMisc::array1d_to_count_hash(\@unmapped_sys_ids) }; }
    }
    elsif (defined $dcoBPM) {
      my @tmpa = keys %$evalSOIDs;
      for (my $si = 0; $si < scalar @tmpa; $si++) {
         my $sys_id = $tmpa[$si];
                           my @gtDCOList = $dcoBPM->get_jointvalues_sys_defined_list($sys_id);
                           if (scalar @gtDCOList > 0) { 
                                    $noPenaltySysIDs->{$sys_id} = 1; 
                                    delete $evalSOIDs->{$sys_id};
                           }
                           else {
                                    $faIDs->{$sys_id} = 1;
                           }
            }
    } else {
      my @tmpa = keys %$evalSOIDs;
      $faIDs = { MMisc::array1d_to_count_hash(\@tmpa) };
    }

    $self->_setSpatialMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs );
    $self->_storeBPM( $evalBPM, $dcoBPM );
    return 1;
}

#######################

sub computeAndSetTemporalMeasures {
    my ( $self, $other, $prevGTMap, $prevSOMap, $gtOcclCount, $thres, $bin, @frame_dims ) = @_;
    my ($mappedOverlapRatio,$mappedObjIDs,$evalObjectIDs,$evalSOIDs,$noPenaltySysIDs,$mdIDs,$faIDs,$idSplitObjIDs,$idMergeObjIDs);
    my @params = [$thres, $bin, @frame_dims];

    if ($self->getDontCare()) { 
        $self->_setTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $idSplitObjIDs, $idMergeObjIDs ); 
        return 1;
    }

    my $gtObjList = $self->getObjectList();
    my $NG = scalar keys %$gtObjList;
   
    my $dcoIDs;
    if (defined $self->getDontCareObjectIDs() ) { $dcoIDs = { $self->getDontCareObjectIDs() }; }
    else {
        $self->setDontCareObjectIDs();
        $dcoIDs = { $self->getDontCareObjectIDs() };
    }

    if (defined $self->getEvalObjectIDs() ) { $evalObjectIDs = { $self->getEvalObjectIDs() }; } 
    else {
        $self->setEvalObjectIDs();
        $evalObjectIDs = { $self->getEvalObjectIDs() }; 
    }

    # For each object in the occlusion count list, first increment the count by 1. This will include
    # all objects that have appeared at least once in the sequence prior to this frame. Remember
    # this also includes all valid evaluation objects. We will reset their count to 0 in subsequent
    # step (we do not do it in this step because some of the eval objects might appear for the first
    # time in this frame meaning they will not appear in occlusion count list).
    # We do it this way instead of just incrementing the count for dont care objects because eval objects
    # might have left the frame and might re-appear later in the sequence. They have to be handled
    # the same way as objects that are occluded.

    # Create a key (if it doesn't exist already) in the occlusion list for each object in the current frame
    my @tmpa = keys %$gtObjList;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      my $key = $tmpa[$ki];
        if (! exists $gtOcclCount->{$key}) { $gtOcclCount->{$key} = 0; }
    }
    my @tmpa = keys %$gtOcclCount;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      $gtOcclCount->{$tmpa[$ki]}++;
    }

    # For each valid evaluation object in current frame, reduce the count by 1 to get to the occlusion count before this frame.
    my @tmpa = keys %$evalObjectIDs;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      $gtOcclCount->{$tmpa[$ki]}--;
    }

    if (! defined $other ) { 
        $mdIDs = $evalObjectIDs;
        $self->_setTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $idSplitObjIDs, $idMergeObjIDs );
        my @tmpa = keys %$evalObjectIDs;
        for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
          $gtOcclCount->{$tmpa[$ki]} = 0; 
        }
        return 1;
    }

    my $soFrameNum = $other->getFrameNum();
    my $soObjList = $other->getObjectList();
    my @tmpa = keys %$soObjList;
    $evalSOIDs = { MMisc::array1d_to_count_hash(\@tmpa) };
    my $ND = scalar keys %$evalSOIDs;

    # Check for simple cases
    if ( ($NG == 0) || ($ND == 0) ) {
        $mdIDs = $evalObjectIDs;
        $faIDs = $evalSOIDs;
        $self->_setTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $idSplitObjIDs, $idMergeObjIDs );
        my @tmpa = keys %$evalObjectIDs;
        for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
          $gtOcclCount->{$tmpa[$ki]} = 0;
        }
        return 1;
    }

    if ( scalar keys %$prevGTMap == 0 ) {
        if (! $self->getDetOutDefined()) { $self->computeAndSetSpatialMeasures($other, $thres, $bin, @frame_dims); } 
        if ( $self->error() ) { 
            $self->_set_errormsg("Error while computing temporal measures (" . $self->get_errormsg() . ")" ); 
            return -1;
        }

        $self->_unsetDetOutDefined();
        $self->_setTrkOutDefined();

        # Save the current mapping for future computations.
        my @mappedIDs = $self->getMappedObjIDs();
        for (my $loop = 0; $loop < scalar @mappedIDs; $loop++) {
            $prevGTMap->{$mappedIDs[$loop][1]} = $mappedIDs[$loop][0];
            $prevSOMap->{$mappedIDs[$loop][0]} = $mappedIDs[$loop][1];
        }
        my @tmpa = keys %$evalObjectIDs;
        for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
          $gtOcclCount->{$tmpa[$ki]} = 0;
        }
        return 1;
    }

    # Start computation when both NG and ND is > 0 and there exists a previous mapping
    my ( $evalGTObjs, $dcGTObjs );
    my @tmpa = keys %$gtObjList;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      my $key = $tmpa[$ki];
      if ($self->{_dontCareObjectIDs}{$key}) { $dcGTObjs->{$key} = $gtObjList->{$key}; } 
      else { $evalGTObjs->{$key} = $gtObjList->{$key}; }
    }

    # Retain existing mapping from previous frame if the current mapping satifies criterion.
    my $threshold = 0.2;
    my %new_sys_objs = %{$soObjList};
    my ( %new_ref_objs, %continuing_map, %continuing_joint_values );
    my @tmpa = keys %$evalGTObjs;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      my $key = $tmpa[$ki];
      if ( (! exists $prevGTMap->{$key}) || (! exists $new_sys_objs{$prevGTMap->{$key}}) ) { 
        $new_ref_objs{$key} = $evalGTObjs->{$key}; 
      }
      else {
        my ( $msg, $res ) = CLEARObject::kernelFunction( $evalGTObjs->{$key}, $new_sys_objs{$prevGTMap->{$key}}, @params);
        if (! MMisc::is_blank($msg)) {
          $self->_set_errormsg("Error while computing temporal measures (" . $msg . ")" );
          return -1;
        }

        if ( $res >= $threshold ) { 
          $continuing_map{$key} = $prevGTMap->{$key};
          $continuing_joint_values{$key}{$prevGTMap->{$key}} = $res;
          delete $new_sys_objs{$prevGTMap->{$key}};
        }
        else { $new_ref_objs{$key} = $evalGTObjs->{$key}; }
      }
    }

    # Proceed to do a Hungarian matching on the remaining reference and system output objects
    my $evalBPM;
    if (scalar keys %new_ref_objs > 0) {
        $evalBPM = BipartiteMatch->new(\%new_ref_objs, \%new_sys_objs, \&CLEARObject::kernelFunction, \@params);
        if ($evalBPM->error()) { 
            $self->_set_errormsg( "Error while creating Evaluation Bipartite Matching object in computeAndSetTemporalMeasures (" . $evalBPM->get_errormsg() . ")" ); 
            return -1; 
        }
        $evalBPM->compute();
        if ($evalBPM->error()) { 
            $self->_set_errormsg( "Error while computing Evaluation Bipartite Matching in computeAndSetTemporalMeasures (" . $evalBPM->get_errormsg() . ")" ); 
            return -1; 
        }
    }

    my $dcoBPM;
    if (scalar keys %$dcoIDs > 0) {
        $dcoBPM = BipartiteMatch->new($dcGTObjs, \%new_sys_objs, \&CLEARObject::kernelFunction, \@params);
        if ($dcoBPM->error()) { 
            $self->_set_errormsg( "Error while creating Dont Care Bipartite Matching object in computeAndSetTemporalMeasures (" . $dcoBPM->get_errormsg() . ")" ); 
            return -1; 
        }
        $dcoBPM->compute();
        if ($dcoBPM->error()) { 
            $self->_set_errormsg( "Error while computing Dont Care Bipartite Matching in computeAndSetTemporalMeasures (" . $dcoBPM->get_errormsg() . ")" ); 
            return -1; 
        }
    }

    # First display continuing maps
    # print "Continuing Maps:\n", Dumper(\%continuing_joint_values);

    # Next display reference eval objects mapping
    if (0 && defined $evalBPM) {
        $evalBPM->_display("joint_values");
        $evalBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    # Finally display reference dont care objects mapping
    if (0 && scalar keys %$dcoIDs > 0) {
        $dcoBPM->_display("joint_values");
        $dcoBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    # Compute mapped overlap ratio for the newly established mappings in this frame
    $mappedOverlapRatio = 0.0;
    my $maxIFrameDiff = 50;
    if (defined $evalBPM) {
        my @mapped_ids = $evalBPM->get_mapped_ids();
        $mappedObjIDs = [ @mapped_ids ];
        for (my $loop = 0; $loop < scalar @{$mappedObjIDs}; $loop++) {
            $mappedOverlapRatio += $evalBPM->get_jointvalues_refsys_value($mapped_ids[$loop][1], $mapped_ids[$loop][0]); 
            if ( (exists $prevGTMap->{$mapped_ids[$loop][1]}) && ($prevGTMap->{$mapped_ids[$loop][1]} != $mapped_ids[$loop][0]) && ($gtOcclCount->{$mapped_ids[$loop][1]} <= $maxIFrameDiff) ) {
                push( @{$idSplitObjIDs->{$mapped_ids[$loop][1]}}, ( $prevGTMap->{$mapped_ids[$loop][1]}, $mapped_ids[$loop][0] ) );
            }
            $prevGTMap->{$mapped_ids[$loop][1]} = $mapped_ids[$loop][0];
            
            # A bug in USF-DATE duplicated here to match scores. ID-Merges were not checked in USF-DATE. Will remove once score validation is done. 
            if ( (exists $prevSOMap->{$mapped_ids[$loop][0]}) && ($prevSOMap->{$mapped_ids[$loop][0]} != $mapped_ids[$loop][1]) && ($gtOcclCount->{$prevSOMap->{$mapped_ids[$loop][0]}} <= $maxIFrameDiff) ) {
               push( @{$idMergeObjIDs->{$mapped_ids[$loop][0]}}, ( $prevSOMap->{$mapped_ids[$loop][0]}, $mapped_ids[$loop][1] ) );
            }
            $prevSOMap->{$mapped_ids[$loop][0]} = $mapped_ids[$loop][1];
        }

        my @unmapped_ref_ids = $evalBPM->get_unmapped_ref_ids();
        $mdIDs = { MMisc::array1d_to_count_hash(\@unmapped_ref_ids) };
        
        # For each unmapped_sys, check if it overlaps with a dont care object. If yes, don't penalize it. Reduce
        # the sys_count by 1.
        my @unmapped_sys_ids = $evalBPM->get_unmapped_sys_ids();
        if (defined $dcoBPM) {
            for (my $loop = 0; $loop < scalar @unmapped_sys_ids; $loop++) {
                my @gtDCOList = $dcoBPM->get_jointvalues_sys_defined_list($unmapped_sys_ids[$loop]);
                if (scalar @gtDCOList > 0) { 
                    $noPenaltySysIDs->{$unmapped_sys_ids[$loop]} = 1; 
                    delete $evalSOIDs->{$unmapped_sys_ids[$loop]};
                }
                else {
                    $faIDs->{$unmapped_sys_ids[$loop]} = 1;
                }
            }
        }
        else { $faIDs = { MMisc::array1d_to_count_hash(\@unmapped_sys_ids) }; }
    }
    elsif (defined $dcoBPM) {
      my @tmpa = keys %new_sys_objs;
      for (my $si = 0; $si < scalar @tmpa; $si++) {
         my $sys_id = $tmpa[$si];
                           my @gtDCOList = $dcoBPM->get_jointvalues_sys_defined_list($sys_id);
                           if (scalar @gtDCOList > 0) { 
                                    $noPenaltySysIDs->{$sys_id} = 1; 
                                    delete $evalSOIDs->{$sys_id};
                           }
                           else {
                                    $faIDs->{$sys_id} = 1;
                           }
            }
    } else {
      my @tmpa = keys %new_sys_objs;
      $faIDs = { MMisc::array1d_to_count_hash(\@tmpa) }; 
    }

    # Add to that the overlap ratio from mappings that are being carried from previous frames
    # Also, add the ref-sys pair to the mappedObjIDs array
    my @tmpa = keys %continuing_map;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
       my $key = $tmpa[$ki];
        $mappedOverlapRatio += $continuing_joint_values{$key}{$continuing_map{$key}};
        push( @{$mappedObjIDs->[scalar @{$mappedObjIDs}]}, ($continuing_map{$key}, $key) );
    }

    $self->_setTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $idSplitObjIDs, $idMergeObjIDs );
    $self->_storeBPM( $evalBPM, $dcoBPM );
    my @tmpa = keys %$evalObjectIDs;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      $gtOcclCount->{$tmpa[$ki]} = 0; 
    }
    return 1;
}

#######################

sub computeAndSetTextRecMeasures {
    my ($self, $other, $thres, $bin, $spatialWeight, $cerWeight, $costInsDel, $costSub, @frame_dims) = @_;
    my ($mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $subIDs);
    my @spatialparams  = [$thres, $bin, @frame_dims];
    my @combinedparams = [$thres, $bin, $spatialWeight, $cerWeight, $costInsDel, $costSub, @frame_dims];

    if ($self->getDontCare()) { 
        $self->_setTextRecMeasures( $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $subIDs ); 
        $self->_computeAndSetCharacterErrors($other, $costInsDel, $costSub);
        return 1;
    }

    my $gtObjList = $self->getObjectList();
    my $NG = scalar keys %$gtObjList;

    my $dcoIDs;
    if (defined $self->getDontCareObjectIDs() ) { $dcoIDs = { $self->getDontCareObjectIDs() }; }
    else {
        $self->setDontCareObjectIDs();
        $dcoIDs = { $self->getDontCareObjectIDs() };
    }

    if (defined $self->getEvalObjectIDs() ) { $evalObjectIDs = { $self->getEvalObjectIDs() }; } 
    else {
        $self->setEvalObjectIDs();
        $evalObjectIDs = { $self->getEvalObjectIDs() }; 
    }

    if (! defined $other ) { 
        $mdIDs = $evalObjectIDs;
        $self->_setTextRecMeasures( $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $subIDs ); 
        $self->_computeAndSetCharacterErrors($other, $costInsDel, $costSub);
        return 1;
    }

    my $soFrameNum = $other->getFrameNum();
    my $soObjList = $other->getObjectList();
    my @tmpa = keys %$soObjList;
    $evalSOIDs = { MMisc::array1d_to_count_hash(\@tmpa) };
    my $ND = scalar keys %$evalSOIDs;

    # Check for simple cases
    if ( ($NG == 0) || ($ND == 0) ) {
        $mdIDs = $evalObjectIDs;
        $faIDs = $evalSOIDs;
        $self->_setTextRecMeasures( $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $subIDs ); 
        $self->_computeAndSetCharacterErrors($other, $costInsDel, $costSub);
        return 1;
    }

    # Start computation when both NG and ND is > 0
    my ( $evalGTObjs, $dcGTObjs );
    my @tmpa = keys %$gtObjList;
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      my $key = $tmpa[$ki];
        if ($self->{_dontCareObjectIDs}{$key}) { $dcGTObjs->{$key} = $gtObjList->{$key}; } 
        else { $evalGTObjs->{$key} = $gtObjList->{$key}; }
    }
    
    # When passed with additional parameters (frame width & frame height), the kernel function computes distance-based measures
    # Without any additional parameters, the kernel function computes area-based measures
    my $evalBPM;
    if (scalar keys %$evalObjectIDs > 0) {
        $evalBPM = BipartiteMatch->new($evalGTObjs, $soObjList, \&CLEARObject::kernelFunction, \@spatialparams);
        if ($evalBPM->error()) { 
            $self->_set_errormsg( "Error while creating Evaluation Bipartite Matching object in computeAndSetTextRecMeasures (" . $evalBPM->get_errormsg() . ")" ); 
            return -1; 
        }
        $evalBPM->compute();
        if ($evalBPM->error()) { 
            $self->_set_errormsg( "Error while computing Evaluation Bipartite Matching in computeAndSetTextRecMeasures (" . $evalBPM->get_errormsg() . ")" ); 
            return -1; 
        }
    }

    my $dcoBPM;
    if (scalar keys %$dcoIDs > 0) {
        $dcoBPM = BipartiteMatch->new($dcGTObjs, $soObjList, \&CLEARObject::kernelFunction, \@spatialparams);
        if ($dcoBPM->error()) { 
            $self->_set_errormsg( "Error while creating Dont Care Bipartite Matching object in computeAndSetTextRecMeaures (" . $dcoBPM->get_errormsg() . ")" ); 
            return -1; 
        }
        $dcoBPM->compute();
        if ($dcoBPM->error()) { 
            $self->_set_errormsg( "Error while computing Dont Care Bipartite Matching in computeAndSetTextRecMeasures (" . $dcoBPM->get_errormsg() . ")" ); 
            return -1; 
        }
    }

    # If two system objects are equi-distant from a ref object, we break the tie by computing the Character Error Rate
    my $redoMapping = 0;
    foreach my $ref_id (scalar keys %$evalObjectIDs) { # MM[20100211]: this seems strange
      my @tmpa = $self->get_jointvalues_ref_defined_values;
        my @refsys_jointvalues = MMisc::reorder_array_numerically(\@tmpa);
        if ($refsys_jointvalues[0] == $refsys_jointvalues[1]) {
            $redoMapping = 1;
            last;
        }
    }

    if ($redoMapping && (scalar keys %$evalObjectIDs > 0)) {
        $evalBPM = BipartiteMatch->new($evalGTObjs, $soObjList, \&CLEARObject::textRecKernelFunction, \@combinedparams);
        if ($evalBPM->error()) { 
            $self->_set_errormsg( "Error while creating Evaluation Bipartite Matching object in computeAndSetTextRecMeasures re-mapping (" . $evalBPM->get_errormsg() . ")" ); 
            return -1; 
        }
        $evalBPM->compute();
        if ($evalBPM->error()) { 
            $self->_set_errormsg( "Error while computing Evaluation Bipartite Matching in computeAndSetTextRecMeasures re-mapping (" . $evalBPM->get_errormsg() . ")" ); 
            return -1; 
        }
    }

    # First display reference eval objects mapping
    if (0 && defined $evalBPM) {
       print "EVAL OBJECT MAPPING:\n";
       $evalBPM->_display("joint_values");
       $evalBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    # Next display reference dont care objects mapping
    if (0 && defined $dcoBPM) {
       print "DONT CARE OBJECT MAPPING:\n";
       $dcoBPM->_display("joint_values");
       $dcoBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    if (defined $evalBPM) {
      	    my @mapped_ids = $evalBPM->get_mapped_ids();

  	    for (my $inloop = 0; $inloop < scalar @mapped_ids; $inloop++) {
		my $sysText = $soObjList->{$mapped_ids[$inloop][0]}->getContent();
		my $refText = $gtObjList->{$mapped_ids[$inloop][1]}->getContent();
	        if (lc($refText) ne lc($sysText)) { push( @{$subIDs->[scalar @{$subIDs}]}, @{$mapped_ids[$inloop]} ); }
		else { push( @{$mappedObjIDs->[scalar @{$mappedObjIDs}]}, @{$mapped_ids[$inloop]} ); }
	    }

            my @unmapped_ref_ids = $evalBPM->get_unmapped_ref_ids();
            $mdIDs = { MMisc::array1d_to_count_hash(\@unmapped_ref_ids) };
            
            # For each unmapped_sys, check if it overlaps with a dont care object. If yes, don't penalize it. Reduce
            # the sys_count by 1.
            my @unmapped_sys_ids = $evalBPM->get_unmapped_sys_ids();
            if (defined $dcoBPM) {
               for (my $loop = 0; $loop < scalar @unmapped_sys_ids; $loop++) {
                   my @gtDCOList = $dcoBPM->get_jointvalues_sys_defined_list($unmapped_sys_ids[$loop]);
                   if (scalar @gtDCOList > 0) { 
                      $noPenaltySysIDs->{$unmapped_sys_ids[$loop]} = 1; 
                      delete $evalSOIDs->{$unmapped_sys_ids[$loop]};
                   }
                   else {
                      $faIDs->{$unmapped_sys_ids[$loop]} = 1;
                   }
               }
            }
            else { $faIDs = { MMisc::array1d_to_count_hash(\@unmapped_sys_ids) }; }
    }
    elsif (defined $dcoBPM) {
      my @tmpa = keys %$evalSOIDs;
      for (my $si = 0; $si < scalar @tmpa; $si++) {
        my $sys_id = $tmpa[$si];
                           my @gtDCOList = $dcoBPM->get_jointvalues_sys_defined_list($sys_id);
                           if (scalar @gtDCOList > 0) { 
                                    $noPenaltySysIDs->{$sys_id} = 1; 
                                    delete $evalSOIDs->{$sys_id};
                           }
                           else {
                                    $faIDs->{$sys_id} = 1;
                           }
            }
    } else {
      my @tmpa = keys %$evalSOIDs;
      $faIDs = { MMisc::array1d_to_count_hash(\@tmpa) };
    }

    $self->_setTextRecMeasures( $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $subIDs ); 
    $self->_computeAndSetCharacterErrors($other, $costInsDel, $costSub);
    $self->_storeBPM( $evalBPM, $dcoBPM );
    return 1;
}

#######################

sub _computeAndSetCharacterErrors {
    my ( $self, $other, $costInsDel, $costSub ) = @_;
    my ( $numOfCharErrs, $numOfChars ) = ( 0, 0 );

    if (! $self->getTRecOutDefined()) {
        $self->_set_errormsg("Cannot compute character error rates before aligning ref and sys objects");
        return -1;
    }

    my ( %mdIDs, %faIDs, @mappedIDs, @subIDs );

    if (defined $self->getMissDetectIDs())  { %mdIDs = $self->getMissDetectIDs(); }
    if (defined $self->getFalseAlarmIDs())  { %faIDs = $self->getFalseAlarmIDs(); }
    if (defined $self->getMappedObjIDs())   { @mappedIDs = $self->getMappedObjIDs(); }      
    if (defined $self->getSubstitutionIDs()){ @subIDs = $self->getSubstitutionIDs(); }

    my $gtObjList = $self->getObjectList();
    my $soObjList = $other->getObjectList();

    if (%mdIDs) {
      my @tmpa = keys %mdIDs;
      for (my $mi = 0; $mi < scalar @tmpa; $mi++) {
        my $mdID = $tmpa[$mi];
	    my $refText = $gtObjList->{$mdID}->getContent();
            $numOfCharErrs += length($refText);
            $numOfChars += length($refText);
        }
    }

    if (%faIDs) {
      my @tmpa = keys %faIDs;
      for (my $fi = 0; $fi < scalar @tmpa; $fi++) {
        my $faID = $tmpa[$fi];
	    my $sysText = $soObjList->{$faID}->getContent();
            $numOfCharErrs += length($sysText);
        }
    }

    if (@subIDs) {
       for (my $inloop = 0; $inloop < scalar @subIDs; $inloop++) {
	    my $sysText = $soObjList->{$subIDs[$inloop][0]}->getContent();
	    my $refText = $gtObjList->{$subIDs[$inloop][1]}->getContent();
            $numOfCharErrs += &CLEARObject::computeEditDistance($refText, $sysText, $costInsDel, $costSub);
            $numOfChars += length($refText);
       }
    }

    if (@mappedIDs) {
       for (my $inloop = 0; $inloop < scalar @mappedIDs; $inloop++) {
	    my $sysText = $soObjList->{$mappedIDs[$inloop][0]}->getContent();
	    my $refText = $gtObjList->{$mappedIDs[$inloop][1]}->getContent();
            $numOfChars += length($refText);
       }
    }

    $self->_setNumOfCharErrs($numOfCharErrs);
    $self->_setNumOfChars($numOfChars);

    return 1;
}

#######################

sub isDCOOverlap {
   my ( $self, $sys_id ) = @_; 

   my $dcoBPM = $self->getDCOBPM();
   my $frameNum = $self->getFrameNum();

   if (! defined $dcoBPM) { return 0; }

   my @gtDCOList = $dcoBPM->get_jointvalues_sys_defined_list($sys_id);
   if (scalar @gtDCOList > 0) { 
        # print "Object $sys_id overlaps with: ", join(", ", @gtDCOList) , "\n";
        return 1; 
   }

   return 0;
}

#######################

sub get_jointvalues_ref_defined_values {
   my ( $self, $ref_id ) = @_;

   my $evalBPM = $self->getEvalBPM();

   my @out;
   if (! defined $evalBPM) { return(@out); }

   my @sysList = $evalBPM->get_jointvalues_ref_defined_list($ref_id);
   for (my $si = 0; $si < scalar @sysList; $si++) {
     my $sys_id = $sysList[$si];
     push @out, $evalBPM->get_jointvalues_refsys_value($ref_id, $sys_id);
   }

   return(@out);
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
