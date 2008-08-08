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
use Trials;
use MetricTestStub;
use DETCurve;

sub new
  {
    my ($class, $title) = @_;
        
    my $self =
      { 
       Title => $title,
       DETList => [ () ], ### an array of hashes containing the det curves,  
       KEYLUT => {}
      };

    bless $self;
    return $self;
  }

sub unitTest(){
  print "Test DETCurveSet\n";

  my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
  my $trial = new Trials("Term Detection", "Term", "Occurrence", { ("TOTALTRIALS" => undef) });
    
  $trial->addTrial("she", 0.10, "NO", 0);
  $trial->addTrial("she", 0.15, "NO", 0);
  $trial->addTrial("she", 0.20, "NO", 0);
  $trial->addTrial("she", 0.25, "NO", 0);
  $trial->addTrial("she", 0.30, "NO", 1);
  $trial->addTrial("she", 0.35, "NO", 0);
  $trial->addTrial("she", 0.40, "NO", 0);
  $trial->addTrial("she", 0.45, "NO", 1);
  $trial->addTrial("she", 0.50, "NO", 0);
  $trial->addTrial("she", 0.55, "YES", 1);
  $trial->addTrial("she", 0.60, "YES", 1);
  $trial->addTrial("she", 0.65, "YES", 0);
  $trial->addTrial("she", 0.70, "YES", 1);
  $trial->addTrial("she", 0.75, "YES", 1);
  $trial->addTrial("she", 0.80, "YES", 1);
  $trial->addTrial("she", 0.85, "YES", 1);
  $trial->addTrial("she", 0.90, "YES", 1);
  $trial->addTrial("she", 0.95, "YES", 1);
  $trial->addTrial("she", 1.0, "YES", 1);

  my $trial2 = new Trials("Term Detection", "Term", "Occurrence", { ("TOTALTRIALS" => undef) });
    
  $trial2->addTrial("she", 0.10, "NO", 0);
  $trial2->addTrial("she", 0.15, "NO", 0);
  $trial2->addTrial("she", 0.20, "NO", 0);
  $trial2->addTrial("she", 0.25, "NO", 0);
  $trial2->addTrial("she", 0.30, "NO", 1);
  $trial2->addTrial("she", 0.35, "NO", 1);
  $trial2->addTrial("she", 0.40, "NO", 0);
  $trial2->addTrial("she", 0.45, "NO", 1);
  $trial2->addTrial("she", 0.50, "NO", 0);
  $trial2->addTrial("she", 0.55, "YES", 1);
  $trial2->addTrial("she", 0.60, "YES", 1);
  $trial2->addTrial("she", 0.65, "YES", 0);
  $trial2->addTrial("she", 0.70, "YES", 0);
  $trial2->addTrial("she", 0.75, "YES", 1);
  $trial2->addTrial("she", 0.80, "YES", 0);
  $trial2->addTrial("she", 0.85, "YES", 1);
  $trial2->addTrial("she", 0.90, "YES", 1);
  $trial2->addTrial("she", 0.95, "YES", 1);
  $trial2->addTrial("she", 1.0, "YES", 1);

  my $det1 = new DETCurve($trial, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
                          "pooled", "DET1", \@isolinecoef, undef);
  my $det2 = new DETCurve($trial2, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial2),
                          "pooled", "DET2", \@isolinecoef, undef);
    
  print " Added DETs... ";
  my $ds = new DETCurveSet("title");
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("Name 1", $det1));
  die "Error: Successful add of duplicate name" if ("success" eq $ds->addDET("Name 1", $det2));
  my $exp = "Name______________________";
  my $k2 = "Name !@#\$%^&*(){}[]?'\"\<\>:;";
  die "Error: Failed to add second det" if ("success" ne $ds->addDET($k2, $det2));
  print "OK\n";
  
  print " Check File System Safe keys... ";
  die "Error: Filesystem safe name by key /".$ds->getFSKeyForKey("Name 1")."/ != /Name_1/" if ($ds->getFSKeyForKey("Name 1") ne "Name_1");
  die "Error: Filesystem safe name by key /".$ds->getFSKeyForKey($k2)."/ != /$exp/" if ($ds->getFSKeyForKey($k2) ne $exp);
  die "Error: Filesystem safe name by id /".$ds->getFSKeyForID(0)."/ != /Name_1/" if ($ds->getFSKeyForID(0) ne "Name_1");
  die "Error: Filesystem safe name by id /".$ds->getFSKeyForID(1)."/ != /$exp/" if ($ds->getFSKeyForID(1) ne $exp);
  
#  DETCurve::writeMultiDetGraph("foomerge", [($det1, $det2)]);
#  print DETCurve::writeMultiDetSummary([($det1, $det2)], "text");


  print "OK\n";
} 


sub addDET(){
  my ($self, $name, $det) = @_;
    
  return "Name not defined" unless defined $name;
  return "DET not defined" unless defined $det;

  #check that the name is uniq
  return "Error: DET curve with name /$name/ already exists" if (exists($self->{KEYLUT}{$name}));
  #Check that the filesystem-safe name is uniq
  my $fskey = $name;
  $fskey =~ s/[\s\/!\@\#\$\%\^\&\*\(\)\[\]\{\}\'\"\?\:\;\<\>]/_/g;
  # Loop through the DET list
  my $try = 1;
  my $suffix = "";
  my $done = 0;
  while (! $done){
    $done = 1;
    foreach (@{ $self->{DETList} }){
      if ($fskey.$suffix eq $_->{FSSafeKey}){
        $suffix = "_$try";
        $try ++;
        $done = 0; 
      }
    }
  }
  $fskey .= $suffix;

  ### Check to make sure the Metrics are all the same in the DETS
  for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    return "Error: the new det and DET[$d] are non-compatible objects" 
      if (! $det->isCompatible($self->{DETList}->[$d]->{DET}));
  }

  push @{ $self->{DETList} }, { KEY => $name, DET => $det, FSSafeKey => $fskey};
  $self->{KEYLUT}{$name} = $#{ $self->{DETList} };
  return "success";
}

sub getDETForKey(){
  my ($self, $key) = @_;
  
  return undef if (! exists($self->{KEYLUT}{$key}));
  return $self->{DETList}->[$self->{KEYLUT}{$key}]->{DET};
}

sub getDETForID(){
  my ($self, $id) = @_;
  
  return undef if (@{ $self->{DETList} } < $id);
  return $self->{DETList}->[$id]->{DET};
}

sub getFSKeyForID(){
  my ($self, $id) = @_;
  
  return undef if (@{ $self->{DETList} } < $id);
  return $self->{DETList}->[$id]->{FSSafeKey};
}

sub getFSKeyForKey(){
  my ($self, $key) = @_;
  
  return undef if (! exists($self->{KEYLUT}{$key}));
  return $self->{DETList}->[$self->{KEYLUT}{$key}]->{FSSafeKey};
}

sub getDETList(){
  my ($self, $key) = @_;
  
  return $self->{DETList};
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
  my ($self, $buildCurves, $includeCounts, $reportActual) = @_;
    
  my $at = new SimpleAutoTable();

  for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    my $det = $self->{DETList}[$d]->{DET};
    my $key = $self->{DETList}[$d]->{KEY};
        
    my $trial = $det->getTrials();
    my $metric = $det->getMetric();
        
    my %combData = ();
    foreach my $block (sort $trial->getBlockIDs()) {
      $combData{$block}{MMISS} = $trial->getNumMiss($block);     
      $combData{$block}{MFA} = $trial->getNumFalseAlarm($block); 
    }                                                              
    my ($BScombAvg, $BScombSSD, $BSmissAvg, $BSmissSSD, $BSfaAvg, $BSfaSSD) = 
      $metric->combBlockSetCalc(\%combData);                     

    if ($includeCounts) {
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
    
    if ($reportActual){
      my $act = "Act. ";
      $at->addData(&_PN($metric->errFAPrintFormat(), $BSfaAvg),     $act . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $BSmissAvg), $act . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $BScombAvg),    $act . $metric->combLab(),    $key);
  }    
    if ($buildCurves) {
      my $opt = ($metric->combType() eq "maximizable" ? "Max " : "Min ");
      $at->addData(&_PN($metric->errFAPrintFormat(), $det->getBestCombMFA()),     $opt . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getBestCombMMiss()),     $opt . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $det->getBestCombComb()),       $opt . $metric->combLab(),    $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getBestCombDetectionScore()), "Det. Score", $key);
        
      if ($det->getDETPng() ne "") {
        $at->addData($det->getDETPng(), "DET Curve", $key);
      }
      if ($det->getThreshPng() ne "") {
        $at->addData($det->getThreshPng(), "Threshold Curve", $key);
      }
    }
  }
  $at;
}


sub renderAsTxt(){
  my ($self, $fileRoot, $buildCurves, $includeCounts, $DETOptions) = @_;
    
  if (@{ $self->{DETList} } == 0) {
    return "Error: No DETs provided to produce a report from";
  }
  
  my $reportActual = 1;
  $reportActual = $DETOptions->{ReportActual} if (exists($DETOptions->{ReportActual}));

  ### Build the combined and separate DET PNGs
  my $multiInfo = {()};
  if ($buildCurves && $DETOptions->{createDETfiles}) {
    $multiInfo = DETCurve::writeMultiDetGraph($fileRoot, $self, $DETOptions);
  }
    
  my $at = $self->_buildAutoTable($buildCurves, $includeCounts, $reportActual);
    
  my $trial = $self->{DETList}[0]->{DET}->getTrials();
  my $metric = $self->{DETList}[0]->{DET}->getMetric();

  ### Add all the parameters:
  my $info = "Performance Summary Over and Ensemble of Subsets\n\n";
  $info .= "System Title: ".(defined($self->{Title}) ? $self->{Title} : 'N/A')."\n\n"; 
  $info .= "Constant parameters:\n";
  foreach my $key ($trial->getMetricParamKeys()) {
    $info .= "   $key = ".$trial->getMetricParamValue($key)."\n";
  }
  foreach my $key ($metric->getParamKeys()) {
    $info .= "   $key = ".$metric->getParamValue($key)."\n";
  }
  $info .= "\n";
  if ($buildCurves) {
    if (exists($multiInfo->{COMBINED_DET_PNG})) {
      $info .= "Combined DET Plot: $multiInfo->{COMBINED_DET_PNG}\n\n";
    }
  }
  $info . $at->renderTxtTable(2);
}



1;
