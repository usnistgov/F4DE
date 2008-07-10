package Frame;

# Frame
#
# Author(s): Vasant Manohar
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Frame.pm" is an experimental system.
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
use Object;
use BipartiteMatch;

# Constructor 
# Using double-argument form of bless() for an inheritable constructor
# Rather than being uniquely a class method, we'll set it up so that 
# it can be called as either a class method or an object method.

#######################

sub new {
    my ( $proto, $frameNum ) = @_;
    my $class = ref($proto) || $proto;

    my $_errormsg = new MErrorH("Frame");
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
        _idSplitObjIDs      => undef,
        _idMergeObjIDs      => undef,
        _isDet              => 0,
        _isTrk              => 0,
        #ErrorHandler
        _errormsg           => $_errormsg,
        };

    return "'frameNum' not defined" if (! defined $frameNum);
    bless ( $self, $class );
    return $self;
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

#######################

sub setDontCareObjectIDs {
    my ( $self ) = @_;
    my $objList = $self->getObjectList();

    $self->{_dontCareObjectIDs} = {};
    foreach my $okey (keys %$objList) {
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

sub setEvalObjectIDs {
    my ( $self ) = @_;
    my $objList = $self->getObjectList();

    if (! defined $self->{_evalObjectIDs}) { $self->{_evalObjectIDs} = {}; }
    foreach my $okey (keys %$objList) {
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

sub computeAndSetSpatialMeasures {
    my ($self, $other, @params ) = @_;
    my ($mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs);

    if ($self->getDontCare()) { 
        $self->_setSpatialMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs ); 
        return 0;
    }

    my $gtFrameNum = $self->getFrameNum();
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
        return 0;
    }

    my $soFrameNum = $other->getFrameNum();
    my $soObjList = $other->getObjectList();
    $evalSOIDs = { MMisc::array1d_to_hash(keys %$soObjList) };
    my $ND = scalar keys %$evalSOIDs;

    # Check for simple cases
    if ( ($NG == 0) || ($ND == 0) ) {
        $mdIDs = $evalObjectIDs;
        $faIDs = $evalSOIDs;
        $self->_setSpatialMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs );
        return 0;
    }

    # Start computation when both NG and ND is > 0
    my ( $evalGTObjs, $dcGTObjs );
    foreach my $key (keys %$gtObjList) {
        if ($self->{_dontCareObjectIDs}{$key}) { $dcGTObjs->{$key} = $gtObjList->{$key}; } 
        else { $evalGTObjs->{$key} = $gtObjList->{$key}; }
    }
    
    # When passed with additional parameters (frame width & frame height), the kernel function computes distance-based measures
    # Without any additional parameters, the kernel function computes area-based measures
    my $evalBPM = new BipartiteMatch($evalGTObjs, $soObjList, \&Object::kernelFunction, \@params);
    if ($evalBPM->error()) { 
        $self->_set_errormsg( "Error while creating Evaluation Bipartite Matching object in computeAndSetSpatialMeasures (" . $evalBPM->get_errormsg() . ")" ); 
        return -1; 
    }
    $evalBPM->compute();
    if ($evalBPM->error()) { 
        $self->_set_errormsg( "Error while computing Evaluation Bipartite Matching in computeAndSetSpatialMeasures (" . $evalBPM->get_errormsg() . ")" ); 
        return -1; 
    }

    my $dcoBPM;
    if (scalar keys %$dcoIDs > 0) {
        $dcoBPM = new BipartiteMatch($dcGTObjs, $soObjList, \&Object::kernelFunction, \@params);
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
    $evalBPM->_display("joint_values");
    $evalBPM->_display("mapped", "unmapped_ref", "unmapped_sys");

    # Next display reference dont care objects mapping
    if (scalar keys %$dcoIDs > 0) {
        $dcoBPM->_display("joint_values");
        $dcoBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    my @mapped_ids = $evalBPM->get_mapped_ids();
    $mappedOverlapRatio = 0.0;
    $mappedObjIDs = [ @mapped_ids ];
    for (my $loop = 0; $loop < scalar @{$mappedObjIDs}; $loop++) {
        $mappedOverlapRatio += $evalBPM->get_jointvalues_refsys_value($mapped_ids[$loop][1], $mapped_ids[$loop][0]); 
    }

    my @unmapped_ref_ids = $evalBPM->get_unmapped_ref_ids();
    $mdIDs = { MMisc::array1d_to_hash(@unmapped_ref_ids) };
    
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
    else { $faIDs = { MMisc::array1d_to_hash(@unmapped_sys_ids) }; }

    $self->_setSpatialMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs );
    return 0;
}

#######################

sub computeAndSetTemporalMeasures {
    my ( $self, $other, $prevGTMap, $prevSOMap, $gtOcclCount, @params ) = @_;
    my ($mappedOverlapRatio,$mappedObjIDs,$evalObjectIDs,$evalSOIDs,$noPenaltySysIDs,$mdIDs,$faIDs,$idSplitObjIDs,$idMergeObjIDs);

    if ($self->getDontCare()) { 
        $self->_setTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $idSplitObjIDs, $idMergeObjIDs ); 
        return 0;
    }

    my $gtFrameNum = $self->getFrameNum();
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
    foreach my $key (keys %$gtOcclCount) { $gtOcclCount->{$key}++; }

    # For each valid evaluation object in current frame, reset its occlusion count to 0.
    foreach my $key (keys %$evalObjectIDs) { $gtOcclCount->{$key} = 0; }

    if (! defined $other ) { 
        $mdIDs = $evalObjectIDs;
        $self->_setTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $idSplitObjIDs, $idMergeObjIDs );
        return 0;
    }

    my $soFrameNum = $other->getFrameNum();
    my $soObjList = $other->getObjectList();
    $evalSOIDs = { MMisc::array1d_to_hash(keys %$soObjList) };
    my $ND = scalar keys %$evalSOIDs;

    # Check for simple cases
    if ( ($NG == 0) || ($ND == 0) ) {
        $mdIDs = $evalObjectIDs;
        $faIDs = $evalSOIDs;
        $self->_setTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $idSplitObjIDs, $idMergeObjIDs );
        return 0;
    }

    if ( $prevGTMap == undef ) {
        if (! $self->getDetOutDefined()) { $self->computeAndSetSpatialMeasures($other, @params); } 
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
        return 0;
    }

    # Start computation when both NG and ND is > 0 and there exists a previous mapping
    my ( $evalGTObjs, $dcGTObjs );
    foreach my $key (keys %$gtObjList) {
        if ($self->{_dontCareObjectIDs}{$key}) { $dcGTObjs->{$key} = $gtObjList->{$key}; } 
        else { $evalGTObjs->{$key} = $gtObjList->{$key}; }
    }

    # Retain existing mapping from previous frame if the current mapping satifies criterion.
    my $threshold = 0.2;
    my %new_sys_objs = %{$soObjList};
    my ( %new_ref_objs, %continuing_map, %continuing_joint_values );
    foreach my $key (keys %$evalGTObjs) {
        if ( (! exists $prevGTMap->{$key}) || (! exists $new_sys_objs{$prevGTMap->{$key}}) ) { 
            $new_ref_objs{$key} = $evalGTObjs->{$key}; 
        }
        else {
            my ( $msg, $res ) = Object::kernelFunction( $evalGTObjs->{$key}, $new_sys_objs{$prevGTMap->{$key}}, @params);
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
    my $evalBPM = new BipartiteMatch(\%new_ref_objs, \%new_sys_objs, \&Object::kernelFunction, \@params);
    if ($evalBPM->error()) { 
        $self->_set_errormsg( "Error while creating Evaluation Bipartite Matching object in computeAndSetTemporalMeasures (" . $evalBPM->get_errormsg() . ")" ); 
        return -1; 
    }
    $evalBPM->compute();
    if ($evalBPM->error()) { 
        $self->_set_errormsg( "Error while computing Evaluation Bipartite Matching in computeAndSetTemporalMeasures (" . $evalBPM->get_errormsg() . ")" ); 
        return -1; 
    }

    my $dcoBPM;
    if (scalar keys %$dcoIDs > 0) {
        $dcoBPM = new BipartiteMatch($dcGTObjs, \%new_sys_objs, \&Object::kernelFunction, \@params);
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
    print "Continuing Maps:\n", Dumper(%continuing_joint_values);

    # First display reference eval objects mapping
    $evalBPM->_display("joint_values");
    $evalBPM->_display("mapped", "unmapped_ref", "unmapped_sys");

    # Next display reference dont care objects mapping
    if (scalar keys %$dcoIDs > 0) {
        $dcoBPM->_display("joint_values");
        $dcoBPM->_display("mapped", "unmapped_ref", "unmapped_sys");
    }

    # Compute mapped overlap ratio for the newly established mappings in this frame
    my @mapped_ids = $evalBPM->get_mapped_ids();
    $mappedOverlapRatio = 0.0;
    $mappedObjIDs = [ @mapped_ids ];
    for (my $loop = 0; $loop < scalar @{$mappedObjIDs}; $loop++) {
        $mappedOverlapRatio += $evalBPM->get_jointvalues_refsys_value($mapped_ids[$loop][1], $mapped_ids[$loop][0]); 
        if ( (exists $prevGTMap->{$mapped_ids[$loop][1]}) && ($prevGTMap->{$mapped_ids[$loop][1]} != $mapped_ids[$loop][0]) ) {
            push( @{$idSplitObjIDs->{$mapped_ids[$loop][1]}}, ( $prevGTMap->{$mapped_ids[$loop][1]}, $mapped_ids[$loop][0] ) );
        }
        $prevGTMap->{$mapped_ids[$loop][1]} = $mapped_ids[$loop][0];
        
        # Should ask John/Jon how we want to count ID Switch penalties. For now, have are counting by checking both ref and sys ID switches
        if ( (exists $prevSOMap->{$mapped_ids[$loop][0]}) && ($prevSOMap->{$mapped_ids[$loop][0]} != $mapped_ids[$loop][1]) ) {
            push( @{$idMergeObjIDs->{$mapped_ids[$loop][0]}}, ( $prevSOMap->{$mapped_ids[$loop][0]}, $mapped_ids[$loop][1] ) );
        }
        $prevSOMap->{$mapped_ids[$loop][0]} = $mapped_ids[$loop][1];
    }
    
    # Add to that the overlap ratio from mappings that are being carried from previous frames
    # Also, add the ref-sys pair to the mappedObjIDs array
    foreach my $key (keys %continuing_map) {
        $mappedOverlapRatio += $continuing_joint_values{$key}{$continuing_map{$key}};
        push( @{$mappedObjIDs}, ($key, $continuing_map{$key}) );
    }

    my @unmapped_ref_ids = $evalBPM->get_unmapped_ref_ids();
    $mdIDs = { MMisc::array1d_to_hash(@unmapped_ref_ids) };
    
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
    else { $faIDs = { MMisc::array1d_to_hash(@unmapped_sys_ids) }; }

    $self->_setTemporalMeasures( $mappedOverlapRatio, $mappedObjIDs, $evalObjectIDs, $evalSOIDs, $noPenaltySysIDs, $mdIDs, $faIDs, $idSplitObjIDs, $idMergeObjIDs );
    return 0;
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
