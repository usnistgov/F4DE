# F4DE
#
# $Id$
#
# DETCurveSet.pm
# Author: Jon Fiscus
# Additions: David Joy
#
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
#
# F4DE is  an experimental system.  
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
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package DETCurveSet;

use strict;
use Data::Dumper;
use TrialsFuncs;
use MetricTestStub;
use DETCurve;
use AutoTable;
use SimpleAutoTable;
use DETCurveGnuplotRenderer;
use MMisc;

sub new
  {
    my ($class, $title) = @_;

    my $self =
      { 
       Title => $title,
       DETList => [ () ], ### an array of hashes containing the det curves,  
       LAST_GNU_MEASURE_THRESHPLOT_PNG => undef,
       KEYLUT => {},
      };

    bless $self;
    return $self;
  }

sub unitTest(){
  print "Test DETCurveSet\n";

  my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
  my $trial = new TrialsFuncs({ ("TOTALTRIALS" => 1000) },
                              "Term Detection", "Term", "Occurrence");
    
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

  my $trial2 = new TrialsFuncs({ ("TOTALTRIALS" => 1000) },
                               "Term Detection", "Term", "Occurrence");
    
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

  my $emptyTrial = new TrialsFuncs({ ("TOTALTRIALS" => 1000) },
                                   "Term Detection", "Term", "Occurrence");

  $emptyTrial->addTrial("he", undef, "OMITTED", 1);
  $emptyTrial->addTrial("he", undef, "OMITTED", 1);
  $emptyTrial->addTrial("he", undef, "OMITTED", 1);
  $emptyTrial->addTrial("she", undef, "OMITTED", 1);
  $emptyTrial->addTrial("she", undef, "OMITTED", 1);
  $emptyTrial->addTrial("she", undef, "OMITTED", 1);

  my $det1 = new DETCurve($trial, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
                          "DET1", \@isolinecoef, undef);
  my $det2 = new DETCurve($trial2, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial2),
                          "DET2", \@isolinecoef, undef);
  my $det3 = new DETCurve($emptyTrial, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $emptyTrial),
                          "DETEmpty", \@isolinecoef, undef);
  
  $det3->successful();
                          
  print " Added DETs... ";
  my $ds = new DETCurveSet("title");
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("Name 1", $det1));
  die "Error: Successful add of duplicate name" if ("success" eq $ds->addDET("Name 1", $det2));

  my $exp = "Name________________"; # fixed by MM
# was:  my $exp = "Name______________________";

  my $k2 = "Name !@#\$%^&*(){}[]?'\"\<\>:;";
  die "Error: Failed to add second det" if ("success" ne $ds->addDET($k2, $det2));
  die "Error: Failed to add third (empty) det" if ("success" ne $ds->addDET("EmptyDETCurve", $det3));
  print "OK\n";

  print " Added Non-Compatible DETs... ";
  my $k2Diff  = "Name non-compatable";
  my $ncTrial = new TrialsFuncs({ ("TOTAL" => 1000) },
                                "Term Detection", "Term", "Occurrence");
  my $det2Diff = new DETCurve($ncTrial, 
                              new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial2),
                              "DET2", \@isolinecoef, undef);
  my $ret = $ds->addDET($k2Diff, $det2Diff);
  die "Error: Add of non-compatiable DET succeeded returning \"$ret\"" if ("success" eq $ret);
  print "OK\n";
  
  print " Check File System Safe keys... ";
  die "Error: Filesystem safe name by key /".$ds->getFSKeyForKey("Name 1")."/ != /Name_1/" if ($ds->getFSKeyForKey("Name 1") ne "Name_1");
  die "Error: Filesystem safe name by key /".$ds->getFSKeyForKey($k2)."/ != /$exp/" if ($ds->getFSKeyForKey($k2) ne $exp);
  die "Error: Filesystem safe name by id /".$ds->getFSKeyForID(0)."/ != /Name_1/" if ($ds->getFSKeyForID(0) ne "Name_1");
  die "Error: Filesystem safe name by id /".$ds->getFSKeyForID(1)."/ != /$exp/" if ($ds->getFSKeyForID(1) ne $exp);
  
#  my $txt = $ds->renderAsTxt("foomerge", 1, 1, {(createDETfiles => 1)});  print $txt;
#  my $txt = $ds->renderIsoRatioIntersection();   print $txt;

  print "OK\n";

  sortTest($ds);
} 

sub sortTest {
    my ($ds) = @_;
    print " Sort det curves test ... ";

    #####
    # DET1 Actual: -0.192839415387444
    # DET2 Actual: -2.33
    # DET3 Actual: 0
    $ds->sort('actual');

    my @tmp = $ds->getDETForID(0)->getMetric()->getActualDecisionPerformance();
    my $score1 = $tmp[0];

    @tmp = $ds->getDETForID(1)->getMetric()->getActualDecisionPerformance();
    my $score2 = $tmp[0];

    @tmp = $ds->getDETForID(2)->getMetric()->getActualDecisionPerformance();
    my $score3 = $tmp[0];

    # Desired Results: -2.33, -0.192839415387444, 0
    die " Error: Det curves are improperly sorted for actual cost" 
        if ($score1 > $score2 || $score2 > $score3);

    #####
    # DET1 Best: 0.636363636363636
    # DET2 Best: 0.4
    # DET3 Best: 0
    $ds->sort('best');

    $score1 = $ds->getDETForID(0)->getBestCombComb();
    $score2 = $ds->getDETForID(1)->getBestCombComb();
    $score3 = $ds->getDETForID(2)->getBestCombComb();

    # Desired Results: 0, 0.4, 0.636363636363636
    die " Error: Det curves are improperly sorted for best cost" 
        if ($score1 > $score2 || $score2 > $score3);

    print "OK\n";
}

##########

sub addDET(){
  my ($self, $name, $det) = @_;
    
  return "Name not defined" unless defined $name;
  return "DET not defined" unless defined $det;

  #check that the name is uniq
  return "Error: DET curve with name /$name/ already exists" if (exists($self->{KEYLUT}{$name}));
  #Check that the filesystem-safe name is uniq
  my $fskey = $name;
  $fskey =~ s/[\s\/!\@\#\$\%\^\&\*\(\)\[\]\{\}\'\"\?\:\;\<\>]/_/g;
  # Limit filename to 20 chars
  $fskey = substr($fskey, 0, 20);
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
#  print "[$name] => [$fskey]\n";

  ### Check to make sure the Metrics are all the same in the DETS
  for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    return "Error: the new det /".$det->getLineTitle()."/ and DET[$d] /".$self->{DETList}->[$d]->{DET}->getLineTitle()."/ are non-compatible objects" 
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

sub getTitleForKey(){
  my ($self, $key) = @_;
  
  return undef if (! exists($self->{KEYLUT}{$key}));
  return $self->{DETList}->[$self->{KEYLUT}{$key}]->{KEY};
}

sub getTitleForID(){
  my ($self, $id) = @_;
  
  return undef if (@{ $self->{DETList} } < $id);
  return $self->{DETList}->[$id]->{KEY}; 
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
  my @arr = ();
  foreach (@{ $self->{DETList} }){
    push @arr, $_->{DET};
  }
  
  return \@arr;
}

sub setMeasureThreshPng(){
  my ($self, $measure, $png) = @_;
  $self->{LAST_GNU_MEASURE_THRESHPLOT_PNG}{$measure} = $png;
}

sub getMeasureThreshPngHT(){
  my ($self) = @_;
  $self->{LAST_GNU_MEASURE_THRESHPLOT_PNG}
}

sub hasDETs(){
    my ($self) = @_;
    my @keys = keys %{ $self->{DETS} };
    scalar @keys;
}

sub _PN(){
  my ($fmt, $value) = @_;
  if (! defined($value)) {
    return("NA");
  } elsif ($value !~ m%^[\-\d\.]+%) {
    return($value);
  } else {
    return(sprintf($fmt, $value));
  }
}

sub _buildAutoTable(){
  my ($self, $buildCurves, $DETOptions) = @_;
  my $useAT = 1;
  #print Dumper($DETOptions);
  my $at = ($useAT ? new AutoTable() : new SimpleAutoTable());
	$at->setProperties( { "KeyColumnCsv" => "Remove", "KeyColumnTxt" => "Remove", 
                              "SortRowKeyTxt" => "Alpha", "SortRowKeyCsv" => "Alpha" } );

  my $includeCounts = 1;    $includeCounts = 0 if (exists($DETOptions->{ExcludeCountsFromReports}) && $DETOptions->{ExcludeCountsFromReports} == 1);
  my $includePNG    = 1;    $includePNG = 0    if (exists($DETOptions->{ExcludePNGFileFromTextTable}) && $DETOptions->{ExcludePNGFileFromTextTable} == 1);
  my $reportActual  = 1;    $reportActual = 0  if (exists($DETOptions->{ReportActual}) && $DETOptions->{ReportActual} == 0);
  my $reportBest    = 1;    $reportBest = 0    if (exists($DETOptions->{ReportBest}) && $DETOptions->{ReportBest} == 0);
  my $reportGlobal  = 0;    $reportGlobal = 1    if (exists($DETOptions->{ReportGlobal}) && $DETOptions->{ReportGlobal} == 1);
  my $reportOptimum  = 0;   $reportOptimum = 1   if (exists($DETOptions->{ReportOptimum}) && $DETOptions->{ReportOptimum} == 1);
  my $reportSupremum  = 0;  $reportSupremum = 1  if (exists($DETOptions->{ReportSupremum}) && $DETOptions->{ReportSupremum} == 1);
  my $reportRowTotals = 0;  $reportRowTotals=1   if (exists($DETOptions->{ReportRowTotals}) && $DETOptions->{ReportRowTotals} == 1);
  my $reportIsoRatios = 0;  $reportIsoRatios=1   if (exists($DETOptions->{ReportIsoRatios}) && ($DETOptions->{ReportIsoRatios} == 1));

  ## Variable params get added to the report
  my $variableParams = $self->_findVariableParams();

  for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    my $det = $self->{DETList}[$d]->{DET};
    my $key = $self->{DETList}[$d]->{KEY};
        
    my $trial = $det->getTrials();
    my $metric = $det->getMetric();
    my $comblab = $metric->combLab();

    my %combData = ();
    foreach my $block (sort $trial->getBlockIDs()) {
      next if (! $trial->isBlockEvaluated($block));
      $combData{$block}{MMISS} = $trial->getNumMiss($block);
      $combData{$block}{MFA} = $trial->getNumFalseAlarm($block); 
    }
    my ($BScombAvg, $BScombSSD, $BSmissAvg, $BSmissSSD, $BSfaAvg, $BSfaSSD) = 
      $metric->combBlockSetCalc(\%combData);
    my $BSDecThresh = $trial->getTrialActualDecisionThreshold();

    $at->addData($det->getLineTitle(),  ($useAT ? " |" : "" ) .                       "Title",   $key);

    ## if There are variable params, add them
    foreach my $pmter ($trial->getTrialParamKeys()) {
      next unless (exists($variableParams->{$pmter}));
      $at->addData($trial->getTrialParamValue($pmter),  ($useAT ? "Parameters|$pmter" : "$pmter" ),   $key);
    }
    foreach my $pmter ($metric->getParamKeys()) {
      next unless (exists($variableParams->{$pmter}));
      $at->addData($metric->getParamValue($pmter),  ($useAT ? "Parameters|$pmter" : "$pmter" ),   $key);
    }

#    $at->addData("|",  ($useAT ? " |" : "" ) .                       "sw5d",   $key);
    if ($includeCounts) {
      my ($targSum, $targAvg, $targSSD) = $trial->getTotNumTarg();
      my ($ntargSum, $ntargAvg, $ntargSSD) = $trial->getTotNumNonTarg();
      my ($sysSum, $sysAvg, $sysSSD) = $trial->getTotNumSys();
      my ($corrDetectSum, $corrDetectAvg, $corrDetectSSD) = $trial->getTotNumCorrDetect();
      my ($corrNonDetectSum, $corrNonDetectAvg, $corrNonDetectSSD) = $trial->getTotNumCorrNonDetect();
      my ($faSum, $faAvg, $faSSD) = $trial->getTotNumFalseAlarm();
      my ($missSum, $missAvg, $missSSD) = $trial->getTotNumMiss();  
      my ($numBlocks) = $trial->getNumEvaluatedBlocks();
      $at->addData($numBlocks,  ($useAT ? "Inputs|" : "" ) . "#".$trial->getBlockID,   $key) if (scalar(keys %combData) > 1);
      $at->addData($targSum,  ($useAT ? "Inputs|" : "" ) .                  "#Targ",   $key);
      $at->addData($ntargSum,  ($useAT ? "Inputs|" : "" ) .               "#NTarg",   $key);
      $at->addData($sysSum,  ($useAT ? "Inputs|" : "" ) .               "#Sys",   $key);
      $at->addData($corrDetectSum, ($useAT ? "Actual Decision $comblab Analysis|" : "" ) . "#CorDet",   $key);
      $at->addData($corrNonDetectSum, ($useAT ? "Actual Decision $comblab Analysis|" : "" ) . "#Cor!Det",   $key);
      $at->addData($faSum,   ($useAT ? "Actual Decision $comblab Analysis|" : "" ) . "#FA",   $key);
      $at->addData($missSum, ($useAT ? "Actual Decision $comblab Analysis|" : "" ) . "#Miss",   $key);
    }
    
    if ($reportActual){
      my $act = "Act. ";
      $act = "";
      $at->addData(&_PN($metric->errFAPrintFormat(), $BSfaAvg),     ($useAT ? "Actual Decision $comblab Analysis|" : "" ) . $act . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $BSmissAvg), ($useAT ? "Actual Decision $comblab Analysis|" : "" ) . $act . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $BScombAvg),    ($useAT ? "Actual Decision $comblab Analysis|" : "" ) . $act . $comblab,    $key);
      $at->addData(&_PN($metric->combPrintFormat(), $BSDecThresh),    ($useAT ? "Actual Decision $comblab Analysis|" : "" ) . $act . "Dec. Tresh",    $key);
    }    
    my $opt = ($metric->combType() eq "maximizable" ? "Max " : "Min ");
    my $optFull = ($metric->combType() eq "maximizable" ? "Maximum" : "Minimum");
    if ($reportBest){
      $at->addData(&_PN($metric->errFAPrintFormat(), $det->getBestCombMFA()),              ($useAT ? "$optFull $comblab Analysis|" : "" ) . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getBestCombMMiss()),          ($useAT ? "$optFull $comblab Analysis|" : "" ) . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $det->getBestCombComb()),              ($useAT ? "$optFull $comblab Analysis|" : "" ) . $metric->combLab(),    $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getBestCombDetectionScore()), ($useAT ? "$optFull $comblab Analysis|" : "" ) ."Dec. Thresh", $key);
    }
    if ($reportOptimum){
      $at->addData(&_PN($metric->errFAPrintFormat(), $det->getOptimumCombMFA()),              ($useAT ? "Optimum $comblab Analysis|" : "" ) . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getOptimumCombMMiss()),          ($useAT ? "Optimum $comblab Analysis|" : "" ) . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $det->getOptimumCombComb()),              ($useAT ? "Optimum $comblab Analysis|" : "" ) . $metric->combLab(),    $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getOptimumCombDetectionScore()), ($useAT ? "Optimum $comblab Analysis|" : "" ) ."Dec. Thresh", $key);
    }
    if ($reportSupremum){
      $at->addData(&_PN($metric->errFAPrintFormat(), $det->getSupremumCombMFA()),              ($useAT ? "Supremum $comblab Analysis|" : "" ) . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getSupremumCombMMiss()),          ($useAT ? "Supremum $comblab Analysis|" : "" ) . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $det->getSupremumCombComb()),              ($useAT ? "Supremum $comblab Analysis|" : "" ) . $metric->combLab(),    $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getSupremumCombDetectionScore()), ($useAT ? "Supremum $comblab Analysis|" : "" ) ."Dec. Thresh", $key);
    }
    if ($buildCurves) {
      my $detpng = $det->getDETPng();
      if ($includePNG){
        if ($detpng ne "") {
  	      if ($detpng =~ m:([^/]+)/([^/]+)$:) {
  	        $detpng = $1 . "/" . $2;
  	      }
  	      my $deturl = "url={" . $detpng . "}";
          $at->addData($det->getDETPng(), ($useAT ? "DET Curve Graphs|" : "" ) . "DET Curve", $key, $deturl);
        }
        my $threshpng = $det->getThreshPng();
        if ($threshpng ne "") {
        	if ($threshpng =~ m/([^\/]+)\/([^\/]+)$/) {
  	        $threshpng = $1 . "/" . $2;
        	}
  	      my $threshdeturl = "url={" . $threshpng . "}";
          $at->addData($det->getThreshPng(), ($useAT ? "DET Curve Graphs|" : "" ) . "Threshold Curve", $key, $threshdeturl);
        }
      }
    }
    if ($reportGlobal){
     	foreach my $gm($det->getGlobalMeasureIDs()){
    	  $at->addData(&_PN($det->getGlobalMeasureFormat($gm), $det->getGlobalMeasure($gm)),
	                    ($useAT ? "Global Measures|" : "" ) . $det->getGlobalMeasureString($gm). $det->getGlobalMeasureUnit($gm),
	          $key);
      }
    }
    if ($reportIsoRatios){
   		foreach my $cof ( sort {$a <=> $b} @{ $det->{ISOLINE_COEFFICIENTS} } ) {		
  			if(defined($det->{ISOPOINTS}{$cof}))	{
  				$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_MFA}),   
  				  ($useAT ? "Ratio=$cof|" : "" ) . $det->getMetric()->errFALab(),   $key);
	   			$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS}), 
	   			  ($useAT ? "Ratio=$cof|" : "" ) . $det->getMetric()->errMissLab(), $key);
		  		$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_COMB}),  
		  		  ($useAT ? "Ratio=$cof|" : "" ) . $det->getMetric()->combLab(),    $key);
  				$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_DETECTSCORE}),   
  				  ($useAT ? "Ratio=$cof|" : "" ) . "Dec. Thresh",                   $key);
			  }
		  }  
    }

### JF, not sure this is needed  
###    if ($includeFixedMFA && defined($det->{FIXED_MFA_VALUES})){
###      my $MFAFixedResults = $det->{FIXED_MFA_VALUES};
###      for (my $i=0; $i<@$MFAFixedResults; $i++){
###        my $MFA = $MFAFixedResults->[$i]->{MFA};
###        my $MMISS = $MFAFixedResults->[$i]->{InterpMMiss};
###        my $THR = $MFAFixedResults->[$i]->{InterpScore};
###				$at->addData(sprintf("%.4f", $MFA),    
###  				  ($useAT ? "FixedFA|" : "" ) . sprintf("%.4f-".$det->getMetric()->errFALab(), $MFA),   $key);
###  			$at->addData(sprintf("%.4f", $MMISS),    
###     		  ($useAT ? "FixedFA|" : "" ) . sprintf("%.4f-".$det->getMetric()->errMissLab(), $MFA),   $key);
###  			$at->addData(sprintf("%.4f", $THR),    
###     		  ($useAT ? "FixedFA|" : "" ) . sprintf("%.4f-Dec. Thresh", $MFA),   $key);
###			 
###		  }  
###    }
  }

  $at->{Properties}->{KEYS}{"KeyColumnHTML"} = "Remove";
  $at->{Properties}->{KEYS}{"KeyColumnTxt"} = "Remove";
  $at->{Properties}->{KEYS}{"KeyColumnCsv"} = "Remove";
  $at->{Properties}->{KEYS}{"KeyColumnLaTeX"} = "Remove";

  if ($reportRowTotals){
    my @dataRowIDs = $at->getRowIDs("AsAdded");
    my @dataColIDs = $at->getColIDs("AsAdded");
		$at->addData("Count",  " |Title", "<<FOOTER>>"."Count");
		$at->addData("Mean",   " |Title", "<<FOOTER>>"."Mean");
 		$at->addData("StdDev", " |Title", "<<FOOTER>>"."StdDev");
 		$at->addData("+2SE",   " |Title", "<<FOOTER>>"."StdErrP");
 		$at->addData("-2SE",   " |Title", "<<FOOTER>>"."StdErrM");
    

    foreach my $column(@dataColIDs){
      next if ($column =~ /(Title|Curve Graphs)/);
      my($sum, $num, $sumSqr) = (0, 0, 0);
      my $prec = 1;
      foreach my $rowID(@dataRowIDs){
        my $val = $at->getData($column, $rowID);
        if (defined($val)){
          (my $dec = $val) =~ s/^[^\.]+.?//;
          $prec = length($dec) if ($prec < length($dec));
          $num++;
          $sum += $val;
          $sumSqr += $val * $val;
        }
      }
      my $mean = $sum / $num;
      my $var = ($num <= 1 ? undef : (($num * $sumSqr) - ($sum * $sum)) / ($num * ($num - 1)));
      my $stddev = (defined($var) ? MMisc::safe_sqrt($var) : undef);
      
  		$at->addData(sprintf("%d", $num),              $column, "<<FOOTER>>"."Count");
  		$at->addData(sprintf("%.${prec}f", $mean),     $column, "<<FOOTER>>"."Mean");
  		$at->addData(sprintf("%.${prec}f", $stddev),   $column, "<<FOOTER>>"."StdDev");
  		$at->addData(sprintf("%.${prec}f", $mean - $stddev*2), $column, "<<FOOTER>>"."StdErrM");
  		$at->addData(sprintf("%.${prec}f", $mean + $stddev*2), $column, "<<FOOTER>>"."StdErrP");
    }
  }

  return($at);
}

sub _buildBlockedAutoTable()
{
 
  my ($self, $includeCorrNonDetect, $DETOptions) = @_;
  my $at = new AutoTable();
  my %totals = ();
  my %means = ();
  my %combs = ();

  if (not defined $self->{DETList}) {
    print "Empty DETList\n";
    die;
  }

  my $reportGlobal  = 0;   $reportGlobal = 1     if (exists($DETOptions->{ReportGlobal}) && $DETOptions->{ReportGlobal} == 1);
  my $reportOptimum  = 0;   $reportOptimum = 1   if (exists($DETOptions->{ReportOptimum}) && $DETOptions->{ReportOptimum} == 1);
  my $reportSupremum  = 0;  $reportSupremum = 1  if (exists($DETOptions->{ReportSupremum}) && $DETOptions->{ReportSupremum} == 1);
  my $reportIsoRatios = 0;  $reportIsoRatios=1   if (exists($DETOptions->{ReportIsoRatios}) && ($DETOptions->{ReportIsoRatios} == 1));
  my %globSum = ();
  
  for (my $i=0; $i<@{ $self->{DETList} }; $i++) {
    my $det = $self->{DETList}[$i]->{DET};
    my $key = $self->{DETList}[$i]->{KEY};

    my $trial = $det->getTrials();
    my $metric = $det->getMetric();
    my $comblab = $metric->combLab();

    my $blockID = $trial->{"BlockID"};
    
    foreach my $block (sort $trial->getBlockIDs()) {
      foreach my $metaKey (sort keys %{ $trial->{"metaData"}{$block} }) {
	$at->setData($trial->{"metaData"}{$block}{$metaKey}, "MetaData|" . $metaKey, $blockID . "|" . $block);
      }
      next if (! $trial->isBlockEvaluated($block));

      $at->addData($trial->getNumTarg($block), $key . "|#Targ", $blockID . "|" . $block);
      $at->addData($trial->getNumYesTarg($block), $key . "|#Corr", $blockID . "|" . $block);
      $at->addData($trial->getNumNoNonTarg($block), $key . "|#Corr!Det", $blockID . "|" . $block) if ($includeCorrNonDetect == 1);
      my $nFA = $trial->getNumYesNonTarg($block);
      $at->addData($nFA, $key . "|#FA", $blockID . "|" . $block);
      my $nMiss = $trial->getNumMiss($block);
      $at->addData($nMiss, $key . "|#Miss", $blockID . "|" . $block);
      my $comb = &_PN($metric->combPrintFormat(), $metric->combBlockCalc($nMiss, $nFA, $block));
      $at->addData($comb, $key . "|" . $comblab, $blockID . "|" . $block);
      my $nPFA = &_PN($metric->errFAPrintFormat(), $metric->errFABlockCalc($nMiss, $nFA, $block));
      $nPFA = ($nPFA ne "NA") ? $nPFA : 0;
      $at->addData($nPFA, $key . "|PFA", $blockID . "|" . $block);
      my $nPMISS = &_PN($metric->errMissPrintFormat(), $metric->errMissBlockCalc($nMiss, $nFA, $block));
      $at->addData($nPMISS, $key . "|PMISS", $blockID . "|" . $block);

      if ($reportOptimum){
        my $key = $blockID . "|" . $block;
        $at->addData(&_PN($metric->errFAPrintFormat(), $det->getOptimumCombMFAForBlock($block)),              "Optimum $comblab|" . $metric->errFALab(),   $key);
        $at->addData(&_PN($metric->errMissPrintFormat(), $det->getOptimumCombMMissForBlock($block)),          "Optimum $comblab|" . $metric->errMissLab(), $key);
        $at->addData(&_PN($metric->combPrintFormat(), $det->getOptimumCombCombForBlock($block)),              "Optimum $comblab|" . $metric->combLab(),    $key);
        $at->addData(&_PN($metric->errMissPrintFormat(), $det->getOptimumCombDetectionScoreForBlock($block)), "Optimum $comblab|" . "Dec. Thresh", $key);
      }
      if ($reportSupremum){
        my $key = $blockID . "|" . $block;
        $at->addData(&_PN($metric->errFAPrintFormat(), $det->getSupremumCombMFAForBlock($block)),              "Supremum $comblab|" . $metric->errFALab(),   $key);
        $at->addData(&_PN($metric->errMissPrintFormat(), $det->getSupremumCombMMissForBlock($block)),          "Supremum $comblab|" . $metric->errMissLab(), $key);
        $at->addData(&_PN($metric->combPrintFormat(), $det->getSupremumCombCombForBlock($block)),              "Supremum $comblab|" . $metric->combLab(),    $key);
        $at->addData(&_PN($metric->errMissPrintFormat(), $det->getSupremumCombDetectionScoreForBlock($block)), "Supremum $comblab|" . "Dec. Thresh", $key);
      }

      if ($reportGlobal){
       	foreach my $gm($det->getGlobalMeasureIDsWithBlocks()){
       	  my $val = $det->getGlobalMeasureForBlock($gm, $block);
       	  $at->addData(&_PN($det->getGlobalMeasureFormat($gm), $val),
	                     "Global Measures|" . $det->getGlobalMeasureAbbrevStringForBlock($gm) . $det->getGlobalMeasureUnit($gm),
	                     $blockID . "|" . $block);
 	        push(@{ $globSum{$gm} }, $val) if (defined($val));
        }
      }
      if ($reportIsoRatios){
        my $key = $blockID . "|" . $block;
     		foreach my $cof ( sort {$a <=> $b} @{ $det->{ISOLINE_COEFFICIENTS} } ) {		
    			if(defined($det->{ISOPOINTS}{$cof}))	{
            $at->addData(&_PN($metric->errFAPrintFormat(),   $det->{ISOPOINTS}{$cof}{BLOCKS}{$block}{MFA}),      "Ratio=$cof $comblab|" . $metric->errFALab(),   $key);
            $at->addData(&_PN($metric->errMissPrintFormat(), $det->{ISOPOINTS}{$cof}{BLOCKS}{$block}{MMISS}),    "Ratio=$cof $comblab|" . $metric->errMissLab(), $key);
            $at->addData(&_PN($metric->combPrintFormat(),    $det->{ISOPOINTS}{$cof}{BLOCKS}{$block}{COMB}),     "Ratio=$cof $comblab|" . $metric->combLab(),    $key);
            $at->addData(&_PN($metric->errMissPrintFormat(), $det->{ISOPOINTS}{$cof}{INTERPOLATED_DETECTSCORE}), "Ratio=$cof $comblab|" . "Dec. Thresh", $key);
          }
        }
      }
    }

    my ($targSum, $targAvg, $targSSD) = $trial->getTotNumTarg();
    my ($ntargSum, $ntargAvg, $ntargSSD) = $trial->getTotNumNonTarg();
    my ($sysSum, $sysAvg, $sysSSD) = $trial->getTotNumSys();
    my ($corrDetectSum, $corrDetectAvg, $corrDetectSSD) = $trial->getTotNumCorrDetect();
    my ($corrNonDetectSum, $corrNonDetectAvg, $corrNonDetectSSD) = $trial->getTotNumCorrNonDetect();
    my ($faSum, $faAvg, $faSSD) = $trial->getTotNumFalseAlarm();
    my ($missSum, $missAvg, $missSSD) = $trial->getTotNumMiss();  
#    my ($numBlocks) = $trial->getNumEvaluatedBlocks();

    #Totals
    $totals{$key}{"|#Targ"} = $targSum;
    $totals{$key}{"|#Corr"} = $corrDetectSum;
    $totals{$key}{"|#Corr!Det"} = $corrNonDetectSum if ($includeCorrNonDetect == 1);
    $totals{$key}{"|#FA"} = $faSum;
    $totals{$key}{"|#Miss"} = $missSum;

    my %combData = ();
    foreach my $block (sort $trial->getBlockIDs()) {
      next if (! $trial->isBlockEvaluated($block));
      $combData{$block}{MMISS} = $trial->getNumMiss($block);
      $combData{$block}{MFA} = $trial->getNumFalseAlarm($block); 
    }
    my ($BScombAvg, $BScombSSD, $BSmissAvg, $BSmissSSD, $BSfaAvg, $BSfaSSD) = 
      $metric->combBlockSetCalc(\%combData);

    #Means
    my $nBlocks = $trial->getNumBlocks();
    $means{$key}{"|#Targ"} = sprintf ("%.0f", $targAvg);
    $means{$key}{"|#Corr"} = sprintf ("%.0f", $corrDetectAvg);
    $means{$key}{"|#Corr!Det"} = sprintf ("%.0f", $corrNonDetectAvg) if ($includeCorrNonDetect == 1);
    $means{$key}{"|#FA"} = sprintf ("%.0f", $faAvg);
    $means{$key}{"|#Miss"} = sprintf ("%.0f", $missAvg);
    $means{$key}{"|PFA"} = &_PN($metric->errFAPrintFormat(), $BSfaAvg);
    $means{$key}{"|PMISS"} = &_PN($metric->errMissPrintFormat(), $BSmissAvg);

    #Combs
    $combs{$key}{"|" . $comblab} = &_PN($metric->combPrintFormat(), $BScombAvg);
  }

  for (my $i=0; $i<@{ $self->{DETList} }; $i++) {
    my $det = $self->{DETList}[$i]->{DET};
    my $key = $self->{DETList}[$i]->{KEY};

    my $metric = $det->getMetric();
    my $comblab = $metric->combLab();

    foreach my $tcol (keys %{ $totals{$key} }) {
      $at->addData($totals{$key}{$tcol}, $key . $tcol, "Summary|Totals");
    }
    foreach my $mcol (keys %{ $means{$key} }) {
      $at->addData($means{$key}{$mcol}, $key . $mcol, "Summary|Means");
    }
    foreach my $ccol (keys %{ $combs{$key} }) {
      $at->addData($combs{$key}{$ccol}, $key . $ccol, "Summary|" . $comblab);
    }

    if ($reportGlobal){
     	foreach my $gm($det->getGlobalMeasureIDsWithBlocks()){
        if (exists($globSum{$gm})){
          my ($sum, $mean, $ssd) = $det->getTrials()->_stater($globSum{$gm});
       	  $at->addData(&_PN($det->getGlobalMeasureFormat($gm), $mean),
	                     "Global Measures|" . $det->getGlobalMeasureAbbrevStringForBlock($gm) . $det->getGlobalMeasureUnit($gm),
	                     "Summary|Means");
        } else {
       	  $at->addData("NA",
	                     "Global Measures|" . $det->getGlobalMeasureAbbrevStringForBlock($gm) . $det->getGlobalMeasureUnit($gm),
	                     "Summary|Means");
        }
      }
    }
    if ($reportOptimum){
	    my $key = "Summary|Means";
      $at->addData(&_PN($metric->errFAPrintFormat(), $det->getOptimumCombMFA()),              "Optimum $comblab|" . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getOptimumCombMMiss()),          "Optimum $comblab|" . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $det->getOptimumCombComb()),              "Optimum $comblab|" . $metric->combLab(),    $key);
    }
    if ($reportSupremum){
	    my $key = "Summary|Means";
      $at->addData(&_PN($metric->errFAPrintFormat(), $det->getSupremumCombMFA()),              "Supremum $comblab|" . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getSupremumCombMMiss()),          "Supremum $comblab|" . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $det->getSupremumCombComb()),              "Supremum $comblab|" . $metric->combLab(),    $key);
    }
    if ($reportIsoRatios){
	    my $key = "Summary|Means";
  		foreach my $cof ( sort {$a <=> $b} @{ $det->{ISOLINE_COEFFICIENTS} } ) {		
   			if(defined($det->{ISOPOINTS}{$cof}))	{
          $at->addData(&_PN($metric->errFAPrintFormat(),   $det->{ISOPOINTS}{$cof}{INTERPOLATED_MFA}),         "Ratio=$cof $comblab|" . $metric->errFALab(),   $key);
          $at->addData(&_PN($metric->errMissPrintFormat(), $det->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS}),       "Ratio=$cof $comblab|" . $metric->errMissLab(), $key);
          $at->addData(&_PN($metric->combPrintFormat(),    $det->{ISOPOINTS}{$cof}{INTERPOLATED_COMB}),        "Ratio=$cof $comblab|" . $metric->combLab(),    $key);
          $at->addData(&_PN($metric->errMissPrintFormat(), $det->{ISOPOINTS}{$cof}{INTERPOLATED_DETECTSCORE}), "Ratio=$cof $comblab|" . "Dec. Thresh", $key);
        }
      }
    }
  }

  return $at;
}

sub _buildHeaderTable 
{
  my ($self, $combinedDETpng, $xpng) = @_;

  my $at = new AutoTable();
  my $trial = $self->{DETList}[0]->{DET}->getTrials();
  my $metric = $self->{DETList}[0]->{DET}->getMetric();
  my $variableParams = $self->_findVariableParams();  
  my $col = "Performance Summary Over and Ensemble of Subsets";

  my $rowid = 0;
  $at->addData("System Title", $col . "|Key", $rowid);
  $at->addData((defined($self->{Title}) ? $self->{Title} : 'NA'), $col . "|Value", $rowid);
  $rowid++;
  $at->addData("Decision ID", $col . "|Key", $rowid);
  $at->addData($trial->{"DecisionID"}, $col . "|Value", $rowid);
  $rowid++;
  #Constant Params
  foreach my $ckey ($trial->getTrialParamKeys()) {
    next if ($ckey =~ m%^_%); #Skip hidden keys
    next if (exists($variableParams->{$ckey}));
    $at->addData($ckey, $col . "|Key", $rowid);
    $at->addData($trial->getTrialParamValue($ckey), $col . "|Value", $rowid);
    $rowid++;
  }
  #Variable Params
  foreach my $vkey ($metric->getParamKeys()) {
    next if ($vkey =~ m%^_%); #Skip hidden keys
    next if (exists($variableParams->{$vkey}));
    $at->addData($vkey, $col . "|Key", $rowid);
    $at->addData($metric->getParamValue($vkey), $col . "|Value", $rowid);
    $rowid++;
  }

  my $deturl = "";
  if (($combinedDETpng) && ($xpng != 1)) {
    if ($combinedDETpng =~ m:([^/]+)/([^/]+)$:) {
      $deturl = $1 . "/" . $2;
    }
    my $deturl = "url={" . $deturl . "}";
    $at->addData("Combined DET Plot", $col . "|Key", $rowid);
    $at->addData($combinedDETpng, $col . "|Value", $rowid, $deturl);
    $rowid++;
  }

  $at->{Properties}->{KEYS}{"KeyColumnHTML"} = "Remove";
  $at->{Properties}->{KEYS}{"html.cell.justification"} = "left";
  $at->{Properties}->{KEYS}{"KeyColumnTxt"} = "Remove";
  $at->{Properties}->{KEYS}{"KeyColumnCsv"} = "Remove";
  $at->{Properties}->{KEYS}{"KeyColumnLaTeX"} = "Remove";
  return $at;
}

sub _findVariableParams(){
  my ($self) = @_;
  
  ### Some parameters are variable based on the inputs.  Find them 
  my %vals = ();
  my %variableParams = ();
  foreach my $det(@{ $self->getDETList() }){
    my $tr = $det->getTrials();
    foreach my $key ($tr->getTrialParamKeys()) {
      $vals{$key}{$tr->getTrialParamValue($key)} = 1;
    }
    my $met = $det->getMetric();
    foreach my $key ($met->getParamKeys()) {
      $vals{$key}{$met->getParamValue($key)} = 1;
    }
  }
  foreach my $key(keys %vals){
    my @skey = keys %{ $vals{$key}};
    if (@skey != 1){
      $variableParams{$key} = 1;
    }
  }

  return (\%variableParams);  
}

#Temporary backwards compatability sub
sub renderAsTxt(){
  my ($self, $fileRoot, $buildCurves, $DETOptions, $csvfn) = @_;
  #return $self->renderReport($fileRoot, $buildCurves, $includeCounts, $DETOptions, "TXT", $csvfn);
  return $self->renderReport($fileRoot, $buildCurves, $DETOptions, undef, undef, undef);
}

sub renderReport(){
  my ($self, $fileRoot, $buildCurves, $overrideDETOptions, $txtfn, $csvfn, $htmlfn, $binmode) = @_;

  if (@{ $self->{DETList} } == 0) {
    return "Error: No DETs provided to produce a report from";
  }

  ### Merge in default options if not set
  my $DETOptions = {};
  my $defOpt = $self->{DETList}->[0]->{DET}->getMetric()->getDefaultPlotOptions();
  foreach my $key(keys %$defOpt){               $DETOptions->{$key} = $defOpt->{$key}   } 
  foreach my $key(keys %$overrideDETOptions){   $DETOptions->{$key} = $overrideDETOptions->{$key}; }
  #print Dumper($defOpt);  print Dumper($overrideDETOptions);  print Dumper($DETOptions);
  
  ### Build the combined and separate DET PNGs
  my $multiInfo = {()};
  if ($buildCurves && (exists($DETOptions->{createDETfiles}) && $DETOptions->{createDETfiles} == 1)) {
    my $dcRend = new DETCurveGnuplotRenderer($DETOptions);
    $multiInfo = $dcRend->writeMultiDetGraph($fileRoot,  $self);
  } 

  my $variableParams = $self->_findVariableParams();
  my $at = $self->_buildAutoTable($buildCurves, $DETOptions);

#  my $trial = $self->{DETList}[0]->{DET}->getTrials();
#  my $metric = $self->{DETList}[0]->{DET}->getMetric();

  my $hat = $self->_buildHeaderTable($multiInfo->{COMBINED_DET_PNG});
  my $that = undef;
  if ($DETOptions->{ExcludePNGFileFromTextTable} == 1) {
    $that = $self->_buildHeaderTable($multiInfo->{COMBINED_DET_PNG}, 1);
  } else {
    $that = $hat;
  }

  my $renderedTxt = $that->renderTxtTable(2) . "\n\n" . $at->renderTxtTable(2);
  MMisc::writeTo($csvfn, "", 1, 0, $at->renderCSV()) if (! MMisc::is_blank($csvfn));
  MMisc::writeTo($txtfn, "", 1, 0, $renderedTxt, undef, undef, undef, undef, undef, $binmode) if (! MMisc::is_blank($txtfn));
  MMisc::writeTo($htmlfn, "", 1, 0, $hat->renderHTMLTable("") . "<br><br>" . $at->renderHTMLTable(""), undef, undef, undef, undef, undef, $binmode) if (! MMisc::is_blank($htmlfn));

  return $renderedTxt;
}

##sub renderCSV {
##    my ($self, $fileRoot, $DETOptions, $fixedMFAValues) = @_;
##
##  if (@{ $self->{DETList} } == 0) {
##    return "Error: No DETs provided to produce a report from";
##  }
##  
##  my $multiInfo = {()};
##  if ($DETOptions->{createDETfiles}) {
##      my $dcRend = new DETCurveGnuplotRenderer($DETOptions);
##      $multiInfo = $dcRend->writeMultiDetGraph($fileRoot, $self);
##  }
##
##  my $at = $self->_buildAutoTable(1, $DETOption2);
##    
##  return($at->renderCSV());
##}     

sub renderBlockedReport {
  my ($self, $includeCorrNonDetect, $txtfn, $csvfn, $htmlfn, $binmode, $DETOptions) = @_;

  my $hat = $self->_buildHeaderTable();
  my $at = $self->_buildBlockedAutoTable($includeCorrNonDetect, $DETOptions);

  my $renderedTxt = $hat->renderTxtTable(2) . "\n\n" . $at->renderTxtTable(2);
  MMisc::writeTo($csvfn, "", 1, 0, $at->renderCSV()) if (! MMisc::is_blank($csvfn));
  MMisc::writeTo($txtfn, "", 1, 0, $renderedTxt, undef, undef, undef, undef, undef, $binmode) if (! MMisc::is_blank($txtfn));
  MMisc::writeTo($htmlfn, "", 1, 0, $hat->renderHTMLTable("") . "<br><br>" . $at->renderHTMLTable(""), undef, undef, undef, undef, undef, $binmode) if (! MMisc::is_blank($htmlfn));
  return $renderedTxt
}

#####

sub writeAllTargScr {
  my ($self, $file) = @_;

  if (@{ $self->{DETList} } == 0) {
    return "Error: No DETs provided to produce a Target Score report from";
  }
 
 for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    my $trial = $self->{DETList}[$d]->{DET}->getTrials();
    for (my $xxx = 0; $xxx < 2; $xxx++) {
      my @scr = ();
      foreach my $block (sort $trial->getBlockIDs()) {
        my $ra = undef;
        if ($xxx) {
           $ra = $trial->getTargScr($block);
        } else {
          $ra = $trial->getNonTargScr($block);
        }
        push @scr, @$ra;
      }

      my $txt = join("\n", @scr) . "\n";
      my $ofn = $file . ".dat.$d" . (($xxx) ? ".targ" : ".nontarg");
      MMisc::writeTo($ofn, "", 1, 0, $txt);
    }
  }

  return(1);
}

#####

sub intersection
{
	my %l = ();
	my @listout;
	foreach my $e (@_) { $l{$e}++; }
	foreach my $e (keys %l) { push(@listout, $e) if($l{$e} > 1); }
	return @listout;	
}

sub unique
{
	my %l = ();
	foreach my $e (@_) { $l{$e}++; }
	return keys %l;
}

sub max
{
	my $max = shift;
	foreach $_ (@_) { $max = $_ if $_ > $max; }
	return $max;
}

sub comb
{
      my ($n, $k) = @_;

      return 0 if( $k < 0 || $k > $n );
      $k = $n - $k if(  $k > $n - $k );

      my $Cnk = 1;

      for( my $i=0; $i<$k; $i++ )
      {
              $Cnk *= $n - $i;
              $Cnk /= $i + 1;
      }

      return( $Cnk );
}

sub inverse_norm
{
  my ($z) = @_;
  my ($cdf) = cdf_norm(abs($z));   
  return (0.5 + $cdf) if ($z >= 0);
  return (0.5 - $cdf);
}


sub cdf_norm
{
      my ($z) = @_;
      my $PREC = 0.00005;
      my $PI = 3.14159265;

      my $a = 1;
      my $b = 1;
      my $c = $z;
      my $sum = $z;
      my $term = $z;

      return( 0.5 * $z / abs ( $z ) ) if( abs( $z ) > 8 );

      for( my $i=1; abs( $term ) > $PREC; $i++ )
      {
              $a += 2;
              $b *= -2 * $i;
              $c *= $z * $z;
              $term = $c/( $a * $b );
              $sum += $term;
      }

      return( $sum/sqrt( 2*$PI ) );
}

sub binomial
{
      my ($p, $n, $s) = @_;

      my $sum = 0;

      if( $n > 30 )
      {
              my $sigma = sqrt( $n*$p*(1.0-$p) );
              my $z = ( ($s+0.5) - $n*$p )/$sigma;
              $sum = 0.5 + cdf_norm( $z );
      }
      else
      {
              for( my $i=0; $i<=$s; $i++ )
              {
                      $sum += comb( $n, $i ) * ( $p ** $i ) * ( (1.0-$p) ** ( $n - $i ) );
              }
      }

      return( 1 - $sum );
}

sub renderDETCompare
{
	my ($self, $confidenceIsoThreshold) = @_;
	
	die "[DetCurveSet::renderDETCompare] Error: Can only compare 2 DET Curves" 
		if(scalar(@{ $self->{DETList} }) != 2);
		
	my ($det1, $det2) = @{ $self->getDETList() };
	
	my $det1name = $det1->{LAST_SERIALIZED_DET};
	$det1name =~ s/\.srl$//;
	my $det2name = $det2->{LAST_SERIALIZED_DET};
	$det2name =~ s/\.srl$//;
	
	my %statsCompare;
	my @listIsoCoeftmp = intersection(@{ $det1->{ISOLINE_COEFFICIENTS} }, @{ $det2->{ISOLINE_COEFFICIENTS} });
	my @listIsoCoef = ();
	
	foreach my $cof ( @listIsoCoeftmp )
	{
		next if(!defined($det1->{ISOPOINTS}{$cof}));
		next if(!defined($det2->{ISOPOINTS}{$cof}));
	
		$statsCompare{$cof}{COMPARE}{PLUS} = 0;
		$statsCompare{$cof}{COMPARE}{MINUS} = 0;
		$statsCompare{$cof}{COMPARE}{ZERO} = 0;
		$statsCompare{$cof}{DET1}{MFA} = $det1->{ISOPOINTS}{$cof}{INTERPOLATED_MFA};
		$statsCompare{$cof}{DET1}{MMISS} = $det1->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS};
		$statsCompare{$cof}{DET2}{MFA} = $det2->{ISOPOINTS}{$cof}{INTERPOLATED_MFA};
		$statsCompare{$cof}{DET2}{MMISS} = $det2->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS};
		
		my @tmpblkkey1 = keys %{ $det1->{ISOPOINTS}{$cof}{BLOCKS} };
		my @tmpblkkey2 = keys %{ $det2->{ISOPOINTS}{$cof}{BLOCKS} };
		
		my @com_blocks = intersection( @tmpblkkey1, @tmpblkkey2 );
	
		foreach my $b ( @com_blocks )
		{
			my $diffdet12 = sprintf("%.4f", $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} - $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} );
		
			push( @{ $statsCompare{$cof}{COMPARE}{DIFF}{ARRAY} }, $diffdet12);
		
			if( abs ( $diffdet12 ) < 0.001 )
			{
				$statsCompare{$cof}{COMPARE}{ZERO}++;
			}
			elsif( $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} > $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} )
			{
				$statsCompare{$cof}{COMPARE}{PLUS}++;
			}
			elsif( $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} < $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} )
			{
				$statsCompare{$cof}{COMPARE}{MINUS}++;
			}			
		}
				
		$statsCompare{$cof}{COMPARE}{BINOMIAL_WITH_ZEROS} = max( 0, binomial( 0.5, $statsCompare{$cof}{COMPARE}{PLUS}+$statsCompare{$cof}{COMPARE}{MINUS}+$statsCompare{$cof}{COMPARE}{ZERO}, $statsCompare{$cof}{COMPARE}{PLUS}+sprintf( "%.0f", $statsCompare{$cof}{COMPARE}{ZERO}/2)) );
		
		push(@listIsoCoef, $cof);	
	}
	
	my $at = new SimpleAutoTable();
	
	my %compare2;
	my @list_isopoints;
	
	$compare2{DET1} = 0;
	$compare2{DET2} = 0;
	$compare2{ZERO} = 0;
	
	foreach my $cof ( sort {$a <=> $b} @listIsoCoef )
	{
		my $bestDET = "-";
		my $isDiff = 0;
		
		if( $statsCompare{$cof}{COMPARE}{BINOMIAL_WITH_ZEROS} < ( 1 - $confidenceIsoThreshold ) )
		{
			$isDiff = 1;
			$bestDET = "DET1";
			$compare2{DET1}++;
		}
		elsif( $statsCompare{$cof}{COMPARE}{BINOMIAL_WITH_ZEROS} > $confidenceIsoThreshold )
		{
			$isDiff = 1;
			$bestDET = "DET2";
			$compare2{DET2}++;
		}
		else
		{
			$compare2{ZERO}++;
		}
		
		$at->addData(sprintf("%.4f", $statsCompare{$cof}{DET1}{MFA}),
		             "DET1|".$det1->{METRIC}->errFALab(), 
		             sprintf("%.4f", $cof) );
		             
		$at->addData(sprintf("%.4f", $statsCompare{$cof}{DET1}{MMISS}),
		             "DET1|".$det1->{METRIC}->errMissLab(), 
		             sprintf("%.4f", $cof) );
		             
		$at->addData(sprintf("%.4f", $statsCompare{$cof}{DET2}{MFA}),
		             "DET2|".$det2->{METRIC}->errFALab(), 
		             sprintf("%.4f", $cof) );
		             
		$at->addData(sprintf("%.4f", $statsCompare{$cof}{DET2}{MMISS}),
		             "DET2|".$det1->{METRIC}->errMissLab(), 
		             sprintf("%.4f", $cof) );
		             
		$at->addData(sprintf("%d", $statsCompare{$cof}{COMPARE}{PLUS}),
		             "+", 
		             sprintf("%.4f", $cof) );
		             
		$at->addData(sprintf("%d", $statsCompare{$cof}{COMPARE}{MINUS}),
		             "-", 
		             sprintf("%.4f", $cof) );
		             
		$at->addData(sprintf("%d", $statsCompare{$cof}{COMPARE}{ZERO}),
		             "0", 
		             sprintf("%.4f", $cof) );
	
		$at->addData(sprintf("%.5f", $statsCompare{$cof}{COMPARE}{BINOMIAL_WITH_ZEROS}),
		             "Sign Test", 
		             sprintf("%.4f", $cof) );
		             
		$at->addData($bestDET,
		             "Comparison", 
		             sprintf("%.4f", $cof) );
		             
		push(@list_isopoints,
		     [( $statsCompare{$cof}{DET1}{MFA}, 
		        $statsCompare{$cof}{DET1}{MMISS},
		        $statsCompare{$cof}{DET2}{MFA},
		        $statsCompare{$cof}{DET2}{MMISS},
		        1 - $isDiff )] );
	}
	
	my $compare2sign = max( 0, binomial( 0.5, $compare2{DET1}+$compare2{DET2}+$compare2{ZERO}, $compare2{DET1}+sprintf( "%.0f", $compare2{ZERO}/2)) );
 
   my $conclusion = sprintf( "Overall sign test:\n  DET# 1 performs %d time%s better than DET# 2\n  DET# 2 performs %d time%s better than DET# 1\n  %d time%s, it is inconclusive\n", $compare2{DET1}, ( $compare2{DET1} > 1 ) ? "s" : "", $compare2{DET2}, ( $compare2{DET2} > 1 ) ? "s" : "", $compare2{ZERO}, ( $compare2{ZERO} > 1 ) ? "s" : "");

   if( $compare2sign < ( 1 - $confidenceIsoThreshold ) )
   {
		   $conclusion .= sprintf(" With %.0f%% of confidence (test=%.5f), DET# 1 overall performs better then DET# 2.\n", $confidenceIsoThreshold*100, $compare2sign );
   }
   elsif( $compare2sign > $confidenceIsoThreshold )
   {
		   $conclusion .= sprintf(" With %.0f%% of confidence (test=%.5f), DET# 2 overall performs better then DET# 1.\n", $confidenceIsoThreshold*100, $compare2sign );
   }
   else
   {
		   $conclusion .= sprintf(" With %.0f%% of confidence (test=%.5f), nothing can be concluded.\n", $confidenceIsoThreshold*100, $compare2sign );
   }
	
	return($at->renderTxtTable(2), $conclusion, \@list_isopoints);
}

sub renderIsoRatioIntersection {
  my $self = shift @_;
  my $mode = MMisc::iuv($_[0], 'text'); 

  my $at = new AutoTable();
  $at->setProperties( { "KeyColumnHTML" => "Remove", "KeyColumnCsv" => "Remove", "KeyColumnTxt" => "Remove"} );
  
  for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    my $det = $self->{DETList}[$d]->{DET};
    my $key = $self->{DETList}[$d]->{KEY};
    
    foreach my $cof ( sort {$a <=> $b} @{ $det->{ISOLINE_COEFFICIENTS} } ) {		
      if(defined($det->{ISOPOINTS}{$cof})) {
        my $rowtitle = "$key|$cof";
        $at->addData($det->{LINETITLE}, "DET Title", $rowtitle);
        $at->addData(sprintf("%.4f", $cof), "Coef", $rowtitle);
        $at->addData(sprintf($det->getMetric()->errFAPrintFormat(), $det->{ISOPOINTS}{$cof}{INTERPOLATED_MFA}), $det->getMetric()->errFALab(),   $rowtitle);
        $at->addData(sprintf($det->getMetric()->errMissPrintFormat(), $det->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS}), $det->getMetric()->errMissLab(), $rowtitle);
        $at->addData(sprintf($det->getMetric()->combPrintFormat(), $det->{ISOPOINTS}{$cof}{INTERPOLATED_COMB}), $det->getMetric()->combLab(), $rowtitle);
        $at->addData(sprintf("%.8f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_DETECTSCORE}), "Detection Threshold", $rowtitle);
      }
    }
  }
 
  return($at->renderCSV())
    if ($mode eq 'csv');
  
  return($at->renderHTMLTable())
    if ($mode eq 'html');

  return $at->renderTxtTable(2);
}

sub renderPerfForFixedMFA {
  my ($self, $MFAFixedValues) = @_;
  my $mode = MMisc::iuv($_[2], 'text');
  
  my $at = new AutoTable();
  $at->setProperties( { "KeyColumnHTML" => "Remove", "KeyColumnCsv" => "Remove", "KeyColumnTxt" => "Remove"} );
  
  for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    my $det = $self->{DETList}[$d]->{DET};
    my $key = $self->{DETList}[$d]->{KEY};
 
    ### Compute the fixed points
    if (@$MFAFixedValues > 0){
      my $MFAFixedValuesResults = $det->{FIXED_MFA_VLAUES};
      for (my $i=0; $i<@$MFAFixedValues; $i++){
        my $rowtitle = "$key|$i";
        $at->addData($det->{LINETITLE}, "DET Title", $rowtitle);
        $at->addData(sprintf("%.4f", $MFAFixedValuesResults->[$i]->{MFA}), $det->getMetric()->errFALab(),   $rowtitle);
        $at->addData(sprintf("%.4f", $MFAFixedValuesResults->[$i]->{InterpMMiss}), $det->getMetric()->errMissLab(), $rowtitle);
      }
    } 
  } 
  
  return($at->renderCSV())
    if ($mode eq 'csv');
  
  return($at->renderHTMLTable())
    if ($mode eq 'html');

  return $at->renderTxtTable(2);
}

sub sort {
    my ($self, $actual) = @_;
    my $maximize;

    if (@{$self->{DETList}} > 0) {
        die "Error: Sort can only be performed on actual or best scores." 
        if ($actual !~ /^(actual|best)$/);
 
        $actual = ($actual eq "actual") ? 1 : 0;    

        #print "Presort\n";
        #foreach my $det (@{$self->{DETList}}) {
        #    my $score;
        #    if ($actual) {
        #        my @tmp = $det->{DET}->getMetric()->getActualDecisionPerformance();
        #        $score = $tmp[0];
        #    } else {
        #        $score = $det->{DET}->getBestCombComb();
        #    }
        #    #print "Final Score: $score\n";
        #}

        if ($actual) {
            my @a = sort DETCurve::compareActual @{$self->{DETList}};
            $self->{DETList} = \@a;
        } else {
            my @a = sort DETCurve::compareBest @{$self->{DETList}};
            $self->{DETList} = \@a;
        }

        #print "\nPostsort\n";
        #foreach my $det (@{$self->{DETList}}) {
        #    my $score;
        #    if ($actual) {
        #        my @tmp = $det->{DET}->getMetric()->getActualDecisionPerformance();
        #        $score = $tmp[0];
        #    } else {
        #        $score = $det->{DET}->getBestCombComb();
        #    }
        #    #print "Final Score: $score\n";
        #}
    }
}

1;
