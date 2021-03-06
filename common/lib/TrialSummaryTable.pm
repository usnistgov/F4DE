# F4DE
#
# $Id$
#
# TrialSummaryTable.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# F4DE is an experimental system.  
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

sub _PN(){
  my ($fmt, $value) = @_;
  if (! defined($value)) {
    "NA";
  } else {
    sprintf($fmt, $value);
  }
}

sub _buildAutoTable(){
  my ($self) = @_;
    
  my $at = new SimpleAutoTable();
  my $trial = $self->{Trial};
  my $metric = $self->{Metric};
  my $str = "";
  my %combData = ();
  foreach my $block (sort $trial->getBlockIDs()) {
    $at->addData($trial->getNumTarg($block),                   "#Ref", $block);
    $at->addData($trial->getNumSys($block),                    "#Sys", $block);
    $at->addData($trial->getNumCorr($block),                   "#CorDet", $block);
    $at->addData($trial->getNumFalseAlarm($block),             "#FA", $block);
    $at->addData($trial->getNumMiss($block),                   "#Miss", $block);

    $str = &_PN($metric->errFAPrintFormat(),
                $metric->errFABlockCalc($trial->getNumMiss($block), $trial->getNumFalseAlarm($block), $block));
    $at->addData($str,                                         $metric->errFALab(), $block);

    $str = &_PN($metric->errMissPrintFormat(),
                $metric->errMissBlockCalc($trial->getNumMiss($block), $trial->getNumFalseAlarm($block), $block));
    $at->addData($str,                                         $metric->errMissLab(), $block);

    $str = &_PN($metric->combPrintFormat(),
                $metric->combBlockCalc($trial->getNumMiss($block), $trial->getNumFalseAlarm($block), $block));
    $at->addData($str,                            
                 $metric->combLab(), $block);

    $combData{$block}{MMISS} = $trial->getNumMiss($block);
    $combData{$block}{MFA} = $trial->getNumFalseAlarm($block);
  }
  my ($BScombAvg, $BScombSSD, $BSmissAvg, $BSmissSSD, $BSfaAvg, $BSfaSSD) = 
    $metric->combBlockSetCalc(\%combData);
        
  my ($refSum, $refAvg, $refSSD) = $trial->getTotNumTarg(); 
  my ($sysSum, $sysAvg, $sysSSD) = $trial->getTotNumCorr(); 
  my ($corrSum, $corrAvg, $corrSSD) = $trial->getTotNumCorr(); 
  my ($faSum, $faAvg, $faSSD) = $trial->getTotNumFalseAlarm(); 
  my ($missSum, $missAvg, $missSSD) = $trial->getTotNumMiss(); 
    
    
  $at->addData("--------",                "#Ref",  "----------");
  $at->addData("--------",                "#Sys",  "----------");
  $at->addData("--------",                "#CorDet",  "----------");
  $at->addData("--------",                "#FA",   "----------");
  $at->addData("--------",                "#Miss", "----------");
  $at->addData("--------",    $metric->errFALab(), "----------");
  $at->addData("--------",  $metric->errMissLab(), "----------");
  $at->addData("--------",     $metric->combLab(), "----------");

  $at->addData($refSum,                   "#Ref",  "Sum");
  $at->addData($sysSum,                   "#Sys",  "Sum");
  $at->addData($corrSum,                  "#CorDet",  "Sum");
  $at->addData($faSum,                    "#FA",   "Sum");
  $at->addData($missSum,                  "#Miss", "Sum");

  $at->addData(&_PN("%.2f", $refAvg),    "#Ref",    "Average");
  $at->addData(&_PN("%.2f", $sysAvg),    "#Sys",    "Average");
  $at->addData(&_PN("%.2f", $corrAvg),   "#CorDet",    "Average");
  $at->addData(&_PN("%.2f", $faAvg),     "#FA",     "Average");
  $at->addData(&_PN("%.2f", $missAvg),   "#Miss",   "Average");
  $at->addData(&_PN($metric->errFAPrintFormat(), $BSfaAvg),     $metric->errFALab(),   "Average");
  $at->addData(&_PN($metric->errMissPrintFormat(), $BSmissAvg), $metric->errMissLab(), "Average");
  $at->addData(&_PN($metric->combPrintFormat(), $BScombAvg),    $metric->combLab(),    "Average");

  $at->addData(&_PN("%.2f", $refSSD),    "#Ref",    "SSD");
  $at->addData(&_PN("%.2f", $sysSSD),    "#Sys",    "SSD");
  $at->addData(&_PN("%.2f", $corrSSD),   "#CorDet",    "SSD");
  $at->addData(&_PN("%.2f", $faSSD),     "#FA",     "SSD");
  $at->addData(&_PN("%.2f", $missSSD),   "#Miss",   "SSD");
  $at->addData(&_PN($metric->errFAPrintFormat(), $BSfaSSD),     $metric->errFALab(),   "SSD");
  $at->addData(&_PN($metric->errMissPrintFormat(), $BSmissSSD), $metric->errMissLab(), "SSD");
  $at->addData(&_PN($metric->combPrintFormat(), $BScombSSD),    $metric->combLab(),    "SSD");

  $at;
}

sub renderAsTxt(){
  my ($self) = @_;
    
  my $at = $self->_buildAutoTable();
    
  ### Add all the parameters:
  my $info = "Constant parameters:\n";
  foreach my $key ($self->{Trial}->getTrialParamKeys()) {
    next if ($key =~ m%^__%); # Skip hidden keys
    $info .= "   $key = ".$self->{Trial}->getTrialParamValue($key)."\n";
  }
  foreach my $key ($self->{Metric}->getParamKeys()) {
    next if ($key =~ m%^__%); # Skip hidden keys
    $info .= "   $key = ".$self->{Metric}->getParamValue($key)."\n";
  }
  $info .= "\n";
    
  $info . $at->renderTxtTable(2);
}

1;
