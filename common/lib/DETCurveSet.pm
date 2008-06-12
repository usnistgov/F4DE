# STDEval
# DETCurveSet.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. STDEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package DETCurveSet;

use strict;
use Data::Dumper;

sub new
{
	my ($class, $title) = @_;
	
	my $self =
	{ 
	    Title => $title,
		DETList => [ () ],  ### an array of hashes containing the det curves,  
	};

	bless $self;
	return $self;
}

sub addDET(){
    my ($self, $name, $det) = @_;
    
    return "Name not defined" unless defined $name;
    return "DET not defined" unless defined $det;
    
    push @{ $self->{DETList} }, { KEY => $name, DET => $det };
    if (@{ $self->{DETList} } > 1){
        ### Check to make sure the Metrics are all the same in the DETS
        for (my $d=0; $d<@{ $self->{DETList} }; $d++){
            return "Error: DET[0] and DET[$d] are non-compatible objects" 
                if (! $self->{DETList}->[0]->{DET}->isCompatible($self->{DETList}->[$d]->{DET}));
        }   
    }
    return "success";
}

sub _PN(){
    my ($fmt, $value) = @_;
    if (! defined($value)){
        "NA";
    } else {
        sprintf($fmt, $value);
    }
}

sub _buildAutoTable(){
    my ($self, $buildCurves, $includeCounts) = @_;
    
    my $at = new SimpleAutoTable();

    for (my $d=0; $d<@{ $self->{DETList} }; $d++){
        my $det = $self->{DETList}[$d]->{DET};
        my $key = $self->{DETList}[$d]->{KEY};
        
        my $trial = $det->getTrials();
        my $metric = $det->getMetric();
        
        my %combData = ();
        foreach my $block(sort $trial->getBlockIDs())
        {
            $combData{$block}{MMISS} = $trial->getNumMiss($block);     
            $combData{$block}{MFA} = $trial->getNumFalseAlarm($block); 
        }                                                              
        my ($BScombAvg, $BScombSSD, $BSmissAvg, $BSmissSSD, $BSfaAvg, $BSfaSSD) = 
            $metric->combBlockSetCalc(\%combData);                     

        if ($includeCounts){
            my ($refSum, $refAvg, $refSSD) = $trial->getTotNumTarg(); 
            my ($sysSum, $sysAvg, $sysSSD) = $trial->getTotNumCorr(); 
            my ($corrSum, $corrAvg, $corrSSD) = $trial->getTotNumCorr(); 
            my ($faSum, $faAvg, $faSSD) = $trial->getTotNumFalseAlarm(); 
            my ($missSum, $missAvg, $missSSD) = $trial->getTotNumMiss(); 
            $at->addData($refSum,           "#Ref",   $key);
            $at->addData($sysSum,           "#Sys",   $key);
            $at->addData($corrSum,          "#CorDet",   $key);
            $at->addData($faSum,            "#FA",   $key);
            $at->addData($missSum,          "#Miss",   $key);
           
        }
    
        my $act = "Act. ";
        $at->addData(&_PN($metric->errFAPrintFormat(), $BSfaAvg),     $act . $metric->errFALab(),   $key);
        $at->addData(&_PN($metric->errMissPrintFormat(), $BSmissAvg), $act . $metric->errMissLab(), $key);
        $at->addData(&_PN($metric->combPrintFormat(), $BScombAvg),    $act . $metric->combLab(),    $key);
        
        if ($buildCurves){
            my $opt = ($metric->combType() eq "maximizable" ? "Max " : "Min ");
            $at->addData(&_PN($metric->errFAPrintFormat(), $det->getBestCombMFA()),     $opt . $metric->errFALab(),   $key);
            $at->addData(&_PN($metric->errMissPrintFormat(), $det->getBestCombMMiss()),     $opt . $metric->errMissLab(), $key);
            $at->addData(&_PN($metric->combPrintFormat(), $det->getBestCombComb()),       $opt . $metric->combLab(),    $key);
            $at->addData(&_PN($metric->errMissPrintFormat(), $det->getBestCombDetectionScore()), "Det. Score", $key);
        
            if ($det->getDETPng() ne ""){  $at->addData($det->getDETPng(), "DET Curve", $key); }
            if ($det->getThreshPng() ne ""){  $at->addData($det->getThreshPng(), "Threshold Curve", $key);  }
        }
    }
    $at;
}


sub renderAsTxt(){
    my ($self, $fileRoot, $buildCurves, $includeCounts, $DETOptions) = @_;
    
    if (@{ $self->{DETList} } == 0){
        return "Error: No DETs provided to produce a report from";
    }

    ### Biuld the combined and separate DET PNGs
    my $multiInfo = {()};
    if ($buildCurves && $DETOptions->{BuildPNG}){
        my @DETs = ();
        foreach my $item(@{ $self->{DETList} }){
            push @DETs, $item->{DET} if ($item->{DET}->successful);
        }  
        $multiInfo = DETCurve::writeMultiDetGraph($fileRoot, \@DETs, $DETOptions);
    }
    
    my $at = $self->_buildAutoTable($buildCurves, $includeCounts);
    
    my $trial = $self->{DETList}[0]->{DET}->getTrials();
    my $metric = $self->{DETList}[0]->{DET}->getMetric();

    ### Add all the parameters:
    my $info = "Performance Summary Over and Ensemble of Subsets\n\n";
    $info .= "System Title: ".(defined($self->{Title}) ? $self->{Title} : 'N/A')."\n\n"; 
    $info .= "Constant parameters:\n";
    foreach my $key($trial->getMetricParamKeys()){
        $info .= "   $key = ".$trial->getMetricParamValue($key)."\n";
    }
    foreach my $key($metric->getParamKeys()){
        $info .= "   $key = ".$metric->getParamValue($key)."\n";
    }
    $info .= "\n";
    if ($buildCurves){
        if (exists($multiInfo->{COMBINED_DET_PNG})){
            $info .= "Combined DET Plot: $multiInfo->{COMBINED_DET_PNG}\n\n";
        }
    }
    $info . $at->renderTxtTable(2);
}



1;
