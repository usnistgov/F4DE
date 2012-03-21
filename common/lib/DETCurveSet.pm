# F4DE
# DETCurveSet.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. F4DE is
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
        if ($score1 < $score2 || $score2 < $score3);

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
        if ($score1 < $score2 || $score2 < $score3);

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
  my ($self, $buildCurves, $includeCounts, $reportActual, $includeIsoRatios, $includeFixedMFA) = @_;
    
  my $useAT = 1;
  
  my $at = ($useAT ? new AutoTable() : new SimpleAutoTable());
	$at->setProperties( { "KeyColumnCsv" => "Remove", "KeyColumnTxt" => "Remove", 
                              "SortRowKeyTxt" => "Alpha", "SortRowKeyCsv" => "Alpha" } );

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
    if ($buildCurves) {
      my $opt = ($metric->combType() eq "maximizable" ? "Max " : "Min ");
      my $optFull = ($metric->combType() eq "maximizable" ? "Maximum" : "Minimum");
      $at->addData(&_PN($metric->errFAPrintFormat(), $det->getBestCombMFA()),              ($useAT ? "$optFull $comblab Analysis|" : "" ) . $metric->errFALab(),   $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getBestCombMMiss()),          ($useAT ? "$optFull $comblab Analysis|" : "" ) . $metric->errMissLab(), $key);
      $at->addData(&_PN($metric->combPrintFormat(), $det->getBestCombComb()),              ($useAT ? "$optFull $comblab Analysis|" : "" ) . $metric->combLab(),    $key);
      $at->addData(&_PN($metric->errMissPrintFormat(), $det->getBestCombDetectionScore()), ($useAT ? "$optFull $comblab Analysis|" : "" ) ."Dec. Thresh", $key);

      if ($det->getDETPng() ne "") {
        $at->addData($det->getDETPng(), ($useAT ? "DET Curve Graphs|" : "" ) . "DET Curve", $key);
      }
      if ($det->getThreshPng() ne "") {
        $at->addData($det->getThreshPng(), ($useAT ? "DET Curve Graphs|" : "" ) . "Threshold Curve", $key);
      }
    }
    if ($includeIsoRatios){
   		foreach my $cof ( sort {$a <=> $b} @{ $det->{ISOLINE_COEFFICIENTS} } ) {		
  			if(defined($det->{ISOPOINTS}{$cof}))	{
  				$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_DETECTSCORE}),   
  				  ($useAT ? "Iso Ratios|" : "" ) . sprintf("%.4f-Dec. Thresh", $cof),   $key);
  				$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_MFA}),   
  				  ($useAT ? "Iso Ratios|" : "" ) . sprintf("%.4f-%s", $cof, $det->getMetric()->errFALab()),   $key);
	   			$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS}), 
	   			  ($useAT ? "Iso Ratios|" : "" ) . sprintf("%.4f-%s", $cof, $det->getMetric()->errMissLab()), $key);
		  		$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_COMB}),  
		  		  ($useAT ? "Iso Ratios|" : "" ) . sprintf("%.4f-%s", $cof, $det->getMetric()->combLab()),    $key);
			  }
		  }  
    }
  
    if ($includeFixedMFA && defined($det->{FIXED_MFA_VALUES})){
      my $MFAFixedResults = $det->{FIXED_MFA_VALUES};
      for (my $i=0; $i<@$MFAFixedResults; $i++){
        my $MFA = $MFAFixedResults->[$i]->{MFA};
        my $MMISS = $MFAFixedResults->[$i]->{InterpMMiss};
        my $THR = $MFAFixedResults->[$i]->{InterpScore};
				$at->addData(sprintf("%.4f", $MFA),    
  				  ($useAT ? "FixedFA|" : "" ) . sprintf("%.4f-".$det->getMetric()->errFALab(), $MFA),   $key);
  			$at->addData(sprintf("%.4f", $MMISS),    
     		  ($useAT ? "FixedFA|" : "" ) . sprintf("%.4f-".$det->getMetric()->errMissLab(), $MFA),   $key);
  			$at->addData(sprintf("%.4f", $THR),    
     		  ($useAT ? "FixedFA|" : "" ) . sprintf("%.4f-Dec. Thresh", $MFA),   $key);
			 
		  }  
    }
  }
  $at;
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
  
sub renderAsTxt(){
  my ($self, $fileRoot, $buildCurves, $includeCounts, $DETOptions, $csvfn) = @_;
    
  if (@{ $self->{DETList} } == 0) {
    return "Error: No DETs provided to produce a report from";
  }
  
  my $reportActual = 1;
  $reportActual = $DETOptions->{DETShowPoint_Actual} 
    if (exists($DETOptions->{DETShowPoint_Actual}));

  ### Build the combined and separate DET PNGs
  my $multiInfo = {()};
  if ($buildCurves && $DETOptions->{createDETfiles}) {
    my $dcRend = new DETCurveGnuplotRenderer($DETOptions);
    $multiInfo = $dcRend->writeMultiDetGraph($fileRoot,  $self);
  }

  my $variableParams = $self->_findVariableParams();
  
  my $at = $self->_buildAutoTable($buildCurves, $includeCounts, $reportActual, $DETOptions->{DETShowPoint_Ratios});
    
  my $trial = $self->{DETList}[0]->{DET}->getTrials();
  my $metric = $self->{DETList}[0]->{DET}->getMetric();

  ### Add all the parameters:
  my $info = "Performance Summary Over and Ensemble of Subsets\n\n";
  $info .= "System Title: ".(defined($self->{Title}) ? $self->{Title} : 'N/A')."\n\n"; 
  $info .= "Constant parameters:\n";
  foreach my $key ($trial->getTrialParamKeys()) {
    next if ($key =~ m%^__%); # Skip hidden keys  
    next if (exists($variableParams->{$key}));
    $info .= "   $key = ".$trial->getTrialParamValue($key)."\n";
  }
  foreach my $key ($metric->getParamKeys()) {
    next if ($key =~ m%^__%); # Skip hidden keys
    next if (exists($variableParams->{$key}));
    $info .= "   $key = ".$metric->getParamValue($key)."\n";
  }
  $info .= "\n";
  if ($buildCurves) {
    if (exists($multiInfo->{COMBINED_DET_PNG})) {
      $info .= "Combined DET Plot: $multiInfo->{COMBINED_DET_PNG}\n\n";
    }
  }

  MMisc::writeTo($csvfn, "", 1, 0, $at->renderCSV()) if (! MMisc::is_blank($csvfn));

  return($info . $at->renderTxtTable(2));
}

sub renderCSV {
    my ($self, $fileRoot, $includeCounts, $DETOptions, $fixedMFAValues) = @_;

  if (@{ $self->{DETList} } == 0) {
    return "Error: No DETs provided to produce a report from";
  }
  
  my $reportActual = 1;
  $reportActual = $DETOptions->{DETShowPoint_Actual} if (exists($DETOptions->{DETShowPoint_Actual}));

  my $multiInfo = {()};
  if ($DETOptions->{createDETfiles}) {
      my $dcRend = new DETCurveGnuplotRenderer($DETOptions);
      $multiInfo = $dcRend->writeMultiDetGraph($fileRoot, $self);
  }

  my $at = $self->_buildAutoTable(1, $includeCounts, $reportActual, $DETOptions->{DETShowPoint_Ratios}, 1);
    
  return($at->renderCSV());
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

sub renderIsoRatioIntersection
{
	my ($self) = @_;
	
	my $at = new AutoTable();
	$at->setProperties( { "KeyColumnCsv" => "Remove", "KeyColumnTxt" => "Remove"} );

  for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    my $det = $self->{DETList}[$d]->{DET};
    my $key = $self->{DETList}[$d]->{KEY};
 
		foreach my $cof ( sort {$a <=> $b} @{ $det->{ISOLINE_COEFFICIENTS} } )
		{		
			if(defined($det->{ISOPOINTS}{$cof}))
			{
				my $rowtitle = "$key|$cof";
				$at->addData($det->{LINETITLE},                                            "DET Title",                     $rowtitle);
				$at->addData(sprintf("%.4f", $cof),                                        "Coef",                          $rowtitle);
				$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_MFA}),   $det->getMetric()->errFALab(),   $rowtitle);
				$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS}), $det->getMetric()->errMissLab(), $rowtitle);
				$at->addData(sprintf("%.4f", $det->{ISOPOINTS}{$cof}{INTERPOLATED_COMB}),  $det->getMetric()->combLab(),    $rowtitle);
			}
		}
	}
	
	return $at->renderTxtTable(2);
}

sub renderPerfForFixedMFA
{
	my ($self, $MFAFixedValues) = @_;
	
	my $at = new AutoTable();
	$at->setProperties( { "KeyColumnCsv" => "Remove", "KeyColumnTxt" => "Remove"} );

  for (my $d=0; $d<@{ $self->{DETList} }; $d++) {
    my $det = $self->{DETList}[$d]->{DET};
    my $key = $self->{DETList}[$d]->{KEY};
 
    ### Compute the fixed points
    if (@$MFAFixedValues > 0){
      my $MFAFixedValuesResults = $det->{FIXED_MFA_VLAUES};
      for (my $i=0; $i<@$MFAFixedValues; $i++){
        my $rowtitle = "$key|$i";
        $at->addData($det->{LINETITLE},                                        "DET Title",                     $rowtitle);
  			$at->addData(sprintf("%.4f", $MFAFixedValuesResults->[$i]->{MFA}),   $det->getMetric()->errFALab(),   $rowtitle);
    		$at->addData(sprintf("%.4f", $MFAFixedValuesResults->[$i]->{InterpMMiss}), $det->getMetric()->errMissLab(), $rowtitle);
      }
    } 
  } 

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
