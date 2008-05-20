# STDEval
# TrialSummaryTable.pm
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

package TrialSummaryTable;
use strict;
use Data::Dumper;
use SimpleAutoTable;
 

sub new
{
    my ($class, $trial, $metric) = @_;

    die "Error: new TrialSummaryTable() called without a \$metric value" if (! defined($metric));

    my $self =
    {
        "Trial" => $trial,
        "Metric" => $metric,
    };

    bless $self;
    return $self;
}

sub renderAsTxt()
{
    my ($self) = @_;
    
    my $at = new SimpleAutoTable();
    my $trial = $self->{Trial};
    my $metric = $self->{Metric};
    my $str = "";
    my %combData = ();
    foreach my $block(sort $trial->getBlockIDs())
    {
        $at->addData($trial->getNumTarg($block),                   "#Ref", $block);
        $at->addData($trial->getNumCorr($block),                   "#Cor", $block);
        $at->addData($trial->getNumFalseAlarm($block),             "#FA", $block);
        $at->addData($trial->getNumMiss($block),                   "#Miss", $block);
        $str = sprintf($metric->combPrintFormat(),
                       $metric->combBlockCalc($trial->getNumMiss($block), $trial->getNumFalseAlarm($block), $block));
        $at->addData($str,                                         $metric->combLab(), $block);
        $str = sprintf($metric->errFAPrintFormat(),
                       $metric->errFABlockCalc($trial->getNumFalseAlarm($block), $block));
        $at->addData($str,                                         $metric->errFALab(), $block);
        $str = sprintf($metric->errMissPrintFormat(),
                       $metric->errMissBlockCalc($trial->getNumMiss($block), $block));
        $at->addData($str,                                         $metric->errMissLab(), $block);
        $combData{$block}{MMISS} = $trial->getNumMiss($block);
        $combData{$block}{MFA} = $trial->getNumFalseAlarm($block);
    }
    my ($combAvg, $combSSD, $missAvg, $missSSD, $faAvg, $faSSD) = 
        $metric->combBlockSetCalc(\%combData);
    my ($refSum, $refAvg, $refSSD) = $trial->getTotNumTarg(); 
    my ($corrSum, $corrAvg, $corrSSD) = $trial->getTotNumCorr(); 
    my ($faSum, $faAvg, $faSSD) = $trial->getTotNumFalseAlarm(); 
    my ($missSum, $missAvg, $missSSD) = $trial->getTotNumMiss(); 
    
    
    $at->addData("--------",                "#Ref",  "----------");
    $at->addData("--------",                "#Cor",  "----------");
    $at->addData("--------",                "#FA",   "----------");
    $at->addData("--------",                "#Miss", "----------");
    $at->addData("--------",     $metric->combLab(), "----------");
    $at->addData("--------",    $metric->errFALab(), "----------");
    $at->addData("--------",  $metric->errMissLab(), "----------");

    $at->addData($refSum,                   "#Ref",  "Sum");
    $at->addData($corrSum,                  "#Cor",  "Sum");
    $at->addData($faSum,                    "#FA",   "Sum");
    $at->addData($missSum,                  "#Miss", "Sum");

    $at->addData(sprintf("%.2f", $refAvg),    "#Ref",    "Average");
    $at->addData(sprintf("%.2f", $corrAvg),   "#Cor",    "Average");
    $at->addData(sprintf("%.2f", $faAvg),     "#FA",     "Average");
    $at->addData(sprintf("%.2f", $missAvg),   "#Miss",   "Average");
    $at->addData(sprintf($metric->combPrintFormat(), $combAvg),    $metric->combLab(),    "Average");
    $at->addData(sprintf($metric->errFAPrintFormat(), $faAvg),     $metric->errFALab(),   "Average");
    $at->addData(sprintf($metric->errMissPrintFormat(), $missAvg), $metric->errMissLab(), "Average");

    $at->addData(sprintf("%.2f", $refSSD),    "#Ref",    "SSD");
    $at->addData(sprintf("%.2f", $corrSSD),   "#Cor",    "SSD");
    $at->addData(sprintf("%.2f", $faSSD),     "#FA",     "SSD");
    $at->addData(sprintf("%.2f", $missSSD),   "#Miss",   "SSD");
    $at->addData(sprintf($metric->combPrintFormat(), $combSSD),    $metric->combLab(),    "SSD");
    $at->addData(sprintf($metric->errFAPrintFormat(), $faSSD),     $metric->errFALab(),   "SSD");
    $at->addData(sprintf($metric->errMissPrintFormat(), $missSSD), $metric->errMissLab(), "SSD");
    
    $at->renderTxtTable_core(2);
}

1;
