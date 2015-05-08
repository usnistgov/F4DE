# F4DE
#
# $Id$
#
# MetricRo.pm
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

package MetricDemo;

use DETCurve;
use DETCurveSet;
use DETCurveGnuplotRenderer;
use Math::Random::OO::Uniform;
use strict;
use AutoTable;

### Tada!! The metrics!
use MetricRo;
use TrialsRo;

use Data::Dumper;
use MMisc;


sub runDemo{
  my ($dir) = @_;

  my @isolinecoef = (.1, 1, 3);
  
  ### Build the data for the trials  
  my $decisionScoreRand = Math::Random::OO::Normal->new(0,1); $decisionScoreRand->seed(3324);
  my $targetRand = Math::Random::OO::Uniform->new(0,1);       $targetRand->seed(35213);
  my %trials = ();

  my $numEpoch = 3;
  for (my $epoch = 0; $epoch<$numEpoch; $epoch ++){
    for (my $nt = 0; $nt<1000; $nt ++){
      push(@{ $trials{"epoch $epoch"}{TARG}},    $decisionScoreRand->next());
      push(@{ $trials{"epoch $epoch"}{NONTARG}}, $decisionScoreRand->next());
    }
  } 

  my $options = { 
      ("Xmin" => 0,
		   "Xmax" => 100,
		   "Ymin" => 0,
		   "Ymax" => 100,
		   "xScale" => "linear",
		   "yScale" => "linear",
		   "ColorScheme" => "colorPresentation",
       "DrawIsometriclines" => 1,
       "createDETfiles" => 1,
		   "DrawIsoratiolines" => 1,
       "serialize" => 1,
       "Isoratiolines" => [ (12.5) ],
       "Isometriclines" => \@isolinecoef,
       "PointSet" => [] ) };
  my $dsRo = makeDET(\%trials, "MetricRo");
  print $dsRo->renderAsTxt("$dir/MD.Ro.randomTest.det", 1, $options, "");       

  my ($med2011MI, $med2011FA) = (0.75, 0.06);
  my ($med2012MI, $med2012FA) = (0.50, 0.04);
  my ($med2013MI, $med2013FA) = (0.35, 0.028);
  my ($med2014MI, $med2014FA) = (0.25, 0.02);
  my ($med2015MI, $med2015FA) = (0.18, 0.0144);
  
  my $tr = new TrialsNormLinearCostFunct({ ( ) }, "Detection", "Block", "Trial");
  my $met = new MetricNormLinearCostFunct({ ('CostFA' => 1, 'CostMiss' => 10 , 'Ptarg' => 0.01 ) }, $tr);
  my $med2011Cost = $met->combCalc($med2011MI, $med2011FA);
  my $med2012Cost = $met->combCalc($med2012MI, $med2012FA);
  my $med2013Cost = $met->combCalc($med2013MI, $med2013FA);
  my $med2014Cost = $met->combCalc($med2014MI, $med2014FA);
  my $med2015Cost = $met->combCalc($med2015MI, $med2015FA);

  my $med2011Ratio = $med2011MI /  $med2011FA;
  my $med2012Ratio = $med2012MI /  $med2012FA;
  my $med2013Ratio = $med2013MI /  $med2013FA;
  my $med2014Ratio = $med2014MI /  $med2014FA;
  my $med2015Ratio = $med2015MI /  $med2015FA;

 $options = { 
      ("Xmin" => 0.1,
		   "Xmax" => 99,
		   "Ymin" => 0.1,
		   "Ymax" => 99,
		   "xScale" => "nd",
		   "yScale" => "nd",
		   "ColorScheme" => "color",
       "createDETfiles" => 1,
       "ReportActual" => 1,
		   "ReportMinumum" => 0,
       "serialize" => 1,
		   "DrawIsoratiolines" => 0,
       "Isoratiolines" => [ (12.5) ],
       "DrawIsometriclines" => 1,
       "PointSet" => [ { MMiss => $med2011MI,  MFA => $med2011FA, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2011"}, 
                       { MMiss => $med2012MI,  MFA => $med2012FA, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2012"}, 
                       { MMiss => $med2013MI,  MFA => $med2013FA, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2013"}, 
                       { MMiss => $med2014MI,  MFA => $med2014FA, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2014"}, 
                       { MMiss => $med2015MI,  MFA => $med2015FA, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2015"}, 
                       ] ) };

  my $dsNLCF = makeDET(\%trials, "MetricNormLinearCostFunct");
  print $dsNLCF->renderAsTxt("$dir/MD.NLCF.randomTest.det", 1, $options, "");       

  
}

sub getNewTrials{
  my ($name) = @_;
  if ($name eq "MetricRo"){
    return new TrialsRo({ () }, "Detection", "Block", "Trial");
  } elsif ($name eq "MetricNormLinearCostFunct"){
    return new TrialsNormLinearCostFunct({ ( ) }, "Detection", "Block", "Trial");
  } else {
    die;
  }
}

sub getNewMetric{
  my ($name, $tr) = @_;
  if ($name eq "MetricRo"){
    return new MetricRo({ ('m' => 12.5) }, $tr);
  } elsif ($name eq "MetricNormLinearCostFunct"){
    return new MetricNormLinearCostFunct({ ('CostFA' => 1, 'CostMiss' => 10, 'Ptarg' => 0.01 ) }, $tr);
  } else {
    die;
  }
}

sub makeDET{
  my ($trials, $metName) = @_;

  my $ds = new DETCurveSet("MetricDemo");
  my @isolinecoef = ();
  
  print "  Building Setting up MetricRo\n";
  my $tr1 = getNewTrials($metName);
  my $tr2 = getNewTrials($metName);
  my $tr3 = getNewTrials($metName);
  my $tr4 = getNewTrials($metName);
  my $tr5 = getNewTrials($metName);
  my $tr6 = getNewTrials($metName);
  
  my @epochs = keys %$trials;
  for (my $epoch = 0; $epoch<@epochs; $epoch ++){
    my $blk = "epoch $epoch";
    foreach my $scr (@{ $trials->{$blk}{TARG} }){    
      my $ns = $scr;                       $tr1->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 1); 
      $ns += (0.40 + $epoch * 0.02);       $tr2->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 1); 
      $ns += (0.45 + $epoch * 0.02);       $tr3->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 1); 
      $ns += (0.25 + $epoch * 0.02);       $tr4->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 1); 
      $ns += (0.20 + $epoch * 0.02);       $tr5->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 1); 
      $ns += (0.25 + $epoch * 0.02);       $tr6->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 1); 
    }
    foreach my $scr (@{ $trials->{$blk}{NONTARG} }){ 
      my $ns = $scr;                      $tr1->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 0); 
      $ns -= (0.40 + $epoch * 0.02);      $tr2->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 0); 
      $ns -= (0.45 + $epoch * 0.02);      $tr3->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 0); 
      $ns -= (0.25+ $epoch * 0.02);      $tr4->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 0); 
      $ns -= (0.20 + $epoch * 0.02);      $tr5->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 0); 
      $ns -= (0.25 + $epoch * 0.02);      $tr6->addTrial($blk, $ns, ($ns <= 0.5 ? "NO" : "YES" ), 0); 
    }
  }
  
  my $met1 = getNewMetric($metName, $tr1);   my $det1 = new DETCurve($tr1, $met1, "$metName Random", \@isolinecoef, undef);
  my $met2 = getNewMetric($metName, $tr2);   my $det2 = new DETCurve($tr2, $met2, "$metName - Lev1", \@isolinecoef, undef);
  my $met3 = getNewMetric($metName, $tr3);   my $det3 = new DETCurve($tr3, $met3, "$metName - Lev2", \@isolinecoef, undef);
  my $met4 = getNewMetric($metName, $tr4);   my $det4 = new DETCurve($tr4, $met4, "$metName - Lev3", \@isolinecoef, undef);
  my $met5 = getNewMetric($metName, $tr5);   my $det5 = new DETCurve($tr5, $met5, "$metName - Lev4", \@isolinecoef, undef);
  my $met6 = getNewMetric($metName, $tr6);   my $det6 = new DETCurve($tr6, $met6, "$metName - Lev5", \@isolinecoef, undef);
   
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("$metName - Random", $det1));
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("$metName - Lev1", $det2));
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("$metName - Lev2", $det3));
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("$metName - Lev3", $det4));
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("$metName - Lev4", $det5));
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("$metName - Lev5", $det6));

  return $ds;
}



### This fills each trial with the exact same Data
##sub blockAverageUnitTest{
##  my ($dir, @trials) = @_;
##
##
##  my @isolinecoef = (.1, 1, 3);
##
##  print "Build a block averaged random DET curve for Dir=/$dir/\n";
##  my $decisionScoreRand = Math::Random::OO::Normal->new(0,1);
##  my $targetRand = Math::Random::OO::Uniform->new(0,1);
##      
##  for (my $epoch = 0; $epoch<10; $epoch ++){
##    print "    Epoch $epoch\n";
##    my $epochTrial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
##    for (my $nt = 0; $nt<1000; $nt ++){
##      # TArgets
##      my $scr = $decisionScoreRand->next() + (0.25 + $epoch * 0.02);
##      $trial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), 1);
##      $epochTrial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), 1);
##      # NonTargets
##      $scr = $decisionScoreRand->next() - (0.25 + $epoch * 0.02);
##      $trial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), 0);
##      $epochTrial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), 0);
##    }
##    my $epochMet = new MetricRo({ ('m' => 12.5) }, $trial);
##    my $epochDet = new DETCurve($epochTrial, $epochMet, "Epoch $epoch", \@isolinecoef, undef);
##    die "Error: Failed to add first det" if ("success" ne $ds->addDET("Epoch $epoch", $epochDet));
##  } 
##}

1;
