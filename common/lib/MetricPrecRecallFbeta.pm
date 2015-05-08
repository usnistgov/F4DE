# F4DE
#
# $Id$
#
# MetricPrecRecallFbeta.pm
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

package MetricPrecRecallFbeta;

use MetricFuncs;
@ISA = qw(MetricFuncs);

use strict;

use Data::Dumper;
use MMisc;

my @metric_params = ("Beta");

use TrialsPrecRecallFbeta;
my @trials_params = TrialsPrecRecallFbeta::getParamsList();

sub getParamsList { return(@metric_params); }
sub getTrialsParamsList { return(@trials_params); }
 
sub new
  {
    my ($class, $parameters, $trial) = @_;

    my $self = MetricFuncs->new($parameters, $trial);

    #######  customizations
    foreach my $p (@metric_params) {
      MMisc::error_quit("parameter \'$p\' not defined")
          if (! exists($self->{PARAMS}->{$p}));
      MMisc::error_quit("parameter \'$p\' must > 0")
          if ($self->{PARAMS}->{$p} <= 0);
    }
    foreach my $p (@trials_params) {
      MMisc::error_quit("Trials parameter \'$p\' does not exist")
          if (! exists($self->{TRIALPARAMS}->{$p}));
    }

    ## Add normalization constants so they don't need recomputed

   #     print Dumper($self);

    bless ($self, $class);

    ### This implements a normalized cost
    $self->setCombLab("Fbeta(".$self->{PARAMS}->{Beta}.")");
    $self->setErrMissLab("Precision");
    $self->setErrFALab("Recall");
    $self->setCombTypToMaximizable();

    return $self;
  }

####################################################################################################
=pod

=item B<trialParamMerge>(I<$Param>, I<$baseValue>, I<$valueToMerge>, I<$mergeType>)

When Trial structures are merged, the parameters in the Trial structure need to be merged appropriately
based on whether or not the C<mergeType> is /pooled/ or /blocked/.  One way to think of a C<pooled> merge
is to concatenate the data into a single list.  One way to think of a C<blocked> merge is keep the individual 
Trial structures as blocks in the new structures. 

This code is executed parameter, by C<$Param> from the data structure.  Since the interpretation of how to
merge a parameter,  the specifics of the merge are encoded in the Metric object.

C<baseValue> is the existing value in the trial structure.  If this is the first merge, (i.e., the 
trial structure is empty), then this value must be C<undef>.  C<valueToMerge> is the value to merge.

=cut

sub trialParamMerge(){
  my ($self, $param, $mergedValue, $toMergeValue, $mergeType) = @_;

  die "What's this for???";
  
  if ($param eq "TOTALTRIALS"){
    if ($mergeType eq "pooled"){
      ### if pooled, totaltrials ios added
      return (defined($mergedValue) ? $mergedValue : 0) + $toMergeValue;
    } elsif ($mergeType eq "blocked") {
      ### if blocked, the totaltrials MUST be constant 
      return undef if (!defined($mergedValue) && !defined($toMergeValue));
      die "Error: Trial Merge of incompatable /$param/.  New value undefined" if (!defined($toMergeValue));
      return $toMergeValue if (!defined($mergedValue));
      die "Error: Trial Merge only supported for equal /$param/ ($mergedValue != $toMergeValue)" 
        if ($mergedValue != $toMergeValue);
      return $mergedValue;
    } else {
      die "Error: Unknown merge type /$mergeType/\n";
    }
  }
  die "Error: Trial parameter merge for /$param/ Failed.  $param not defined in the metric";
}


####################################################################################################
=pod

=item B<isoCombCoeffForDETCurve>()

Returns an array of coefficients to define what iso lines to draw on a DET Curve for the defined 
combiner metric. These are the defaults for the Metric, but can be overridden by DETUtil and the actual scoring
application.

=cut

sub isoCombCoeffForDETCurve(){ ( ) }


####################################################################################################
=pod

=item B<isoCostRatioCoeffForDETCurve>()

Returns an array of coefficients to define what iso lines to draw on a DET Curve.  For instance, if the
combined metric model is:

  Combined = C_m * Miss + C_f * FA
  
Then the coefficients represent various values of C_m / C_f.  

These are the defaults for the Metric, but can be overridden by DETUtil and the actual scoring
application.

=cut

sub isoCostRatioCoeffForDETCurve(){ ( ) }


sub errMissBlockCalc(){
  my ($self, $nMiss, $nFA, $block) = @_;
  my $NTarg =  $self->{TRIALS}->getNumTarg($block);
  my $NRet = ( ($NTarg - $nMiss) + $nFA);
  
  ($NRet > 0) ? ($NTarg - $nMiss) / $NRet : undef; 
}

sub errFABlockCalc(){
  my ($self, $nMiss, $nFa, $block) = @_;

  my $NTarg =  $self->{TRIALS}->getNumTarg($block);
  ($NTarg > 0) ? ($NTarg - $nMiss) / $NTarg : undef;
}

sub combCalcWeightedMiss(){
  my ($self, $missErr) = @_;
  die "This function combCalcWeightedMiss() for the MetricPrecRecallFbeta metric";
}

sub combCalcWeightedFA(){
  my ($self, $faErr) = @_;
  die "This function combCalcWeightedFA() for the MetricPrecRecallFbeta metric";
}

####################################################################################################
=pod

=item B<combCalc>(I<$missErr, I<$faErr>)

Calculates the combined error metric as a combination of the miss error statistic and the false 
alarm error statistic.  This method uses the constants defined during object creation.  If either C<$missErr> or 
C<$faErr> is undefined, then the combined calculation returns C<undef>,

=cut

sub combCalc(){
  my ($self, $missErr, $faErr) = @_;
  my $beta = $self->{PARAMS}->{'Beta'};
  return undef if ( (($beta * $beta * $missErr) + $faErr) == 0);
  return (1 + ($beta * $beta)) * ($missErr * $faErr) / (($beta * $beta * $missErr) + $faErr);
}

####################################################################################################
=pod

=item B<MISSForGivenComb>(I<$comb, I<$faErr>)

Calculates the value of the Miss statistic for a given combined measure and the FA value.  This is 
a permutation of the combined formula to solve for the Miss value. This method uses the constants 
defined during object creation.  If either C<$comb> or 
C<$faErr> is undefined, then the combined calculation returns C<undef>,

=cut

### The derivation
# F = (1 + B^2) * (prec * recall) / ((B^2 * prec) + recall)
## Separate the weights
#p = - ( r * F ) / (B^2 * F - r * B^2 - r)

sub MISSForGivenComb(){
  my ($self, $comb, $faErr) = @_;
  
  if (defined($comb) && defined($faErr)) {
    my $beta = $self->{PARAMS}->{'Beta'};
    my $denom = ( $beta * $beta * $comb - $faErr * $beta * $beta - $faErr);
    if ($denom == 0){
      undef;
    } else {
      - ($faErr * $comb) / $denom
    }
  } else {
    undef;
  }
}

=pod

=item B<FAForGivenComb>(I<$comb>, I<$missErr>)

Calculates the value of the Fa statistic for a given combined measure and the Miss value.  This is 
a permutation of the combined formula to solve for the Fa value. This method uses the constants 
defined during object creation.  If either C<$comb> or 
C<$missErr> is undefined, then the combined calculation returns C<undef>,

=cut

# r = - (p * B^2 * F) / (F - p*B^2 - p)
sub FAForGivenComb(){
  my ($self, $comb, $missErr) = @_;
  
  if (defined($comb) && defined($missErr)) {
    my $beta = $self->{PARAMS}->{'Beta'};
    my $denom = ($comb - $missErr * $beta * $beta - $missErr);
    if ($denom == 0){
      undef;
    } else {
      - ($missErr * $beta * $beta * $comb) / $denom
    }
  } else {
    undef;
  }
}

=pod

=item B<allUnitTest(I<$dir>)>

Run all the unit tests.

=cut

sub allUnitTest(){
  my ($dir) = ".";
  die "Error: allUnitTest(\$dir) requires a defined $dir" if (! defined($dir));
  MetricPrecRecallFbeta::unitTest($dir);  
}

sub unitTest {
  my ($dir) = @_;

  print "Test MetricPrecRecallFbeta...".(defined($dir) ? " Dir=/$dir/" : "(Skipping DET Curve Generation)")."\n";

  my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );

################################### A do nothing system
### Pmiss == 1  - 10 misses
### PFa == 0    - 0  FA  
### Cost == 1

  my $DNtrial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
  $DNtrial->addTrial("she", 0.03, "NO", 0);
  $DNtrial->addTrial("she", 0.04, "NO", 1);
  $DNtrial->addTrial("she", 0.05, "NO",  1);
  $DNtrial->addTrial("she", 0.10, "NO", 0);
  $DNtrial->addTrial("she", 0.15, "NO", 0);
  foreach (1..259){
    $DNtrial->addTrial("she", 0.17, "NO", 0);
  }
  $DNtrial->addTrial("she", 0.17, "NO", 0);
  $DNtrial->addTrial("she", 0.20, "NO", 1);
  $DNtrial->addTrial("she", 0.25, "NO", 1);
  $DNtrial->addTrial("she", 0.65, "NO", 1);
  $DNtrial->addTrial("she", 0.70, "NO", 1);
  $DNtrial->addTrial("she", 0.70, "NO", 1);
  $DNtrial->addTrial("she", 0.75, "NO", 0);
  $DNtrial->addTrial("she", 0.75, "NO", 1);
  $DNtrial->addTrial("she", 0.85, "NO", 0);
  $DNtrial->addTrial("she", 0.85, "NO", 1);
  $DNtrial->addTrial("she", 0.98, "NO", 0);
  $DNtrial->addTrial("she", 0.98, "NO", 0);
  $DNtrial->addTrial("she", 1.00, "NO", 1);

################################### A target point
### Pmiss == 0.1  - 1 misses
### PFa == 0.0075  - 3 FA  
### Cost == 0.8425
     
  my $trial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
  $trial->addTrial("she", 0.03, "NO", 0);
  $trial->addTrial("she", 0.04, "NO", 0);
  $trial->addTrial("she", 0.05, "NO",  0);
  $trial->addTrial("she", 0.10, "NO", 0);
  $trial->addTrial("she", 0.15, "NO", 1);
  foreach (1..391){
    $trial->addTrial("she", 0.17, "NO", 0);
  }
  $trial->addTrial("she", 0.17, "NO", 0);
  $trial->addTrial("she", 0.20, "NO", 0);
  $trial->addTrial("she", 0.25, "YES", 1);
  $trial->addTrial("she", 0.65, "YES", 1);
  $trial->addTrial("she", 0.70, "YES", 0);
  $trial->addTrial("she", 0.70, "YES", 0);
  $trial->addTrial("she", 0.70, "YES", 0);
  $trial->addTrial("she", 0.75, "YES", 1);
  $trial->addTrial("she", 0.75, "YES", 1);
  $trial->addTrial("she", 0.85, "YES", 1);
  $trial->addTrial("she", 0.85, "YES", 1);
  $trial->addTrial("she", 0.98, "YES", 1);
  $trial->addTrial("she", 0.98, "YES", 1);
  $trial->addTrial("she", 1.0, "YES", 1);

  print $trial->dump();

  @isolinecoef = ( );

  use DETCurve;
  use DETCurveSet;
  use DETCurveGnuplotRenderer;

  #  my $t = new MetricPrecRecallFbeta({ ('CostFA' => 1, 'CostMiss' => 80, 'Ptarg' => 0.001 ) }, $trial);
  #  print " nom ".$t->combCalc(0.75, 0.06)."\n";
  #  print " nom ".$t->combCalc(0.5, 0.04)."\n";

  my $met = new MetricPrecRecallFbeta({ ('Beta' => 1) }, $trial);
  my $DNmet = new MetricPrecRecallFbeta({ ('Beta' => 1) }, $DNtrial);

  ##############################################################################################
  print "  Testing Calculations .. ";
  my ($exp, $ret, $prec, $recall, $comb);
  
  ## Precsion and recall checks
  $exp = ((10 - 5) / (10 - 5 + 20)); $ret = $met->errMissBlockCalc(5, 20, "she"); 
  die "\nError: errMissBlockCalc(#Miss=5, #FA=20, block=she) was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = ((10 - 5) / (10)); $ret = $met->errFABlockCalc(5, 20, "she"); 
  die "\nError: errFABlockCalc(#Miss=5, #FA=20, block=she) was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  
  $exp = 1; $prec = 1; $recall = 1; $ret = $met->combCalc($prec, $recall); 
  die "\nError: Fbeta for Prec=$prec, Recall=$recall was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = 0; $prec = 0; $recall = 1; $ret = $met->combCalc($prec, $recall); 
  die "\nError: Fbeta for Prec=$prec, Recall=$recall was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = 0; $prec = 1; $recall = 0; $ret = $met->combCalc($prec, $recall); 
  die "\nError: Fbeta for Prec=$prec, Recall=$recall was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = 0.66666667; $prec = 1; $recall = 0.5; $ret = $met->combCalc($prec, $recall); 
  die "\nError: Fbeta for Prec=$prec, Recall=$recall was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);


  $exp = 0.75; $ret = $met->errMissBlockCalc(1, 3, "she"); 
  die "\nError: errMissBlockCalc(#Miss=1, #FA=3, block=she) was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = 0.9; $ret = $met->errFABlockCalc(1, 3, "she"); 
  die "\nError: errFABlockCalc(#Miss=1, #FA=3, block=she) was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001); 

  ## Inverse calculations for MISS

  $exp = 0.5; $prec = 1; $comb = 0.666667; $ret = $met->FAForGivenComb($comb, $prec); 
  die "\nError: FAForGivenComb(comb=$comb, recall=$recall) was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);

  $exp = 1; $recall = 0.5; $comb = 0.666667; $ret = $met->MISSForGivenComb($comb, $recall); 
  die "\nError: MISSForGivenComb(comb=$comb, recall=$recall) was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  

  $ret = $met->testActualDecisionPerformance([ ('0.8181818', undef, '0.75', undef, '0.9', undef) ], "  ");
  die $ret if ($ret ne "ok");
  
  if (defined($dir)){
    my $det1 = new DETCurve($trial, $met, "Targetted point", \@isolinecoef, undef);
    my $DNdet = new DETCurve($DNtrial, $DNmet, "Do Nothing", \@isolinecoef, undef);
  

    my $ds = new DETCurveSet("MetricNormLinearFunction Tests");
    die "Error: Failed to add first det" if ("success" ne $ds->addDET("Targetted Point", $det1));
    die "Error: Failed to add second det" if ("success" ne $ds->addDET("Do Nothing", $DNdet));

    my $options = { ("Xmin" => 0,
		   "Xmax" => 100,
		   "Ymin" => 0,
		   "Ymax" => 100,
		   "xScale" => "linear",
		   "yScale" => "linear",
		   "ColorScheme" => "colorPresentation",
       "DrawIsometriclines" => 1,
       "DrawIsoratiolines" => 1,
       "Isoratiolines" =>  [ (0.5, 1, 2) ],
       "Isometriclines" => [ (.8, .4) ], 
#       "Isometriclines" => [ (.5) ], 
       "createDETfiles" => 1,
       "serialize" => 1,
     ) };
  
    print $ds->renderAsTxt("$dir/PRFbeta.unitTest.det", 1, 1, $options, "");                                                                     
    ################ HACKED UNIT TEST #################
    # Check to see if the unmarshalling works.
    $det1 = DETCurve::readFromFile("PRFbeta.unitTest.det.Do_Nothing.srl.gz");    
    ###################################################

  }
  printf "Done\n";
  ###############################################################################################
}

sub randomCurveUnitTest{
  my ($dir) = @_;

  die "Error: randomCurveUnitTest(\$dir) requires a defined $dir" if (! defined($dir));

  use DETCurve;
  use DETCurveSet;
  use DETCurveGnuplotRenderer;
  use Math::Random::OO::Uniform;

  my @Ptargs = (0.02);
  my @TargNonTargSep = (1);
  my @isoRatioCoeff = ();

  print "Build a random DET curve for Ptarg=(".join(",",@Ptargs).") Dir=/$dir/\n";
  my $decisionScoreRand = Math::Random::OO::Normal->new(0,1);
  my $targetRand = Math::Random::OO::Uniform->new(0,1);
  my $ds = new DETCurveSet("MetricNormLinearFunction Tests");
      
  foreach my $Ptarg (@Ptargs){
    foreach my $sep (@TargNonTargSep){
      print "  Working on Ptarg=$Ptarg Targ/NonTargSep=(+/-)$sep\n";
      my $trial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    
      for (my $epoch = 0; $epoch<1; $epoch ++){
        print "    Epoch $epoch\n";
        for (my $nt = 0; $nt<10000; $nt ++){
          my $scr = $decisionScoreRand->next();
          my $targ = ($targetRand->next() <= $Ptarg ? 1 : 0);
          $scr += ($targ ? $sep : -$sep);
        
          $trial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), $targ);
        }
      }
     my $met = new MetricPrecRecallFbeta({ ('Beta' => .1) }, $trial);
#    $trial->exportForDEVA("DEVA.rand");
#    die "Stop";
      my $det1 = new DETCurve($trial, $met, "Ptarg = $Ptarg", [(1)], undef);
      die "Error: Failed to add first det" if ("success" ne $ds->addDET("Ptarg = $Ptarg, Sep +/- $sep", $det1));
    } 
 
  }
  my $options = { ("Xmin" => 0,
		   "Xmax" => 1,
		   "Ymin" => 0,
		   "Ymax" => 1,
		   
		   "xScale" => "linear",
		   "yScale" => "linear",
		   "DETShowPoint_Actual" => 1,
		   "DETShowPoint_Best" => 1,
		   "DETShowPoint_Ratios" => 1,
		   "DETShowPoint_SupportValues" => [ ( 'C', 'M', 'F', 'T' ) ],
       "DrawIsometriclines" => 1,
       "DrawIsoratiolines" => 1,
       "Isoratiolines" =>  [ (1) ],
       "Isometriclines" => [ (.9, .8, .7, .6, .4, .2, .1 ) ], 
       "ColorScheme" => "colorPresentation",
       "createDETfiles" => 1,
       "serialize" => 1 ) };
       
#  DB::enable_profile("$dir/MNLCF.randomTest.profile");
  print $ds->renderAsTxt("$dir/PRFbeta.randomTest.det", 1, 1, $options, "");                                                                     
#  DB::finish_profile();
}

sub blockAverageUnitTest{
  my ($dir) = @_;

  die "Error: blockAverageUnitTest(\$dir) requires a defined $dir" if (! defined($dir));

  use DETCurve;
  use DETCurveSet;
  use DETCurveGnuplotRenderer;
  use Math::Random::OO::Uniform;

  my @isolinecoef = (.1, 1, 3);

  print "Build a block averaged random DET curve for Dir=/$dir/\n";
  my $decisionScoreRand = Math::Random::OO::Normal->new(0,1);
  my $targetRand = Math::Random::OO::Uniform->new(0,1);
  my $ds = new DETCurveSet("MetricNormLinearFunction Tests");
      
  print "  Building DETS\n";
  my $trial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");

  for (my $epoch = 0; $epoch<10; $epoch ++){
    print "    Epoch $epoch\n";
    my $epochTrial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    for (my $nt = 0; $nt<1000; $nt ++){
      # TArgets
      my $scr = $decisionScoreRand->next() + (0.25 + $epoch * 0.02);
      $trial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), 1);
      $epochTrial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), 1);
      # NonTargets
      $scr = $decisionScoreRand->next() - (0.25 + $epoch * 0.02);
      $trial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), 0);
      $epochTrial->addTrial("epoch $epoch", $scr, ($scr <= 0.5 ? "NO" : "YES" ), 0);
    }
    my $epochMet = new MetricPrecRecallFbeta({ ('CostFA' => 1, 'CostMiss' => 1 , 'Ptarg' => 0.1 ) }, $trial);
    my $epochDet = new DETCurve($epochTrial, $epochMet, "Epoch $epoch", \@isolinecoef, undef);
    die "Error: Failed to add first det" if ("success" ne $ds->addDET("Epoch $epoch", $epochDet));
  } 
  my $met = new MetricPrecRecallFbeta({ ('CostFA' => 1, 'CostMiss' => 1 , 'Ptarg' => 0.1 ) }, $trial);
  my $det1 = new DETCurve($trial, $met, "Block Averaged", \@isolinecoef, undef);

  die "Error: Failed to add first det" if ("success" ne $ds->addDET("Block Averaged", $det1));

  my $options = { 
      ("Xmin" => 0.1,
		   "Xmax" => 99.9,
		   "Ymin" => .1,
		   "Ymax" => 99.9,
		   "xScale" => "nd",
		   "yScale" => "nd",
		   "ColorScheme" => "color",
       "DrawIsometriclines" => 1,
       "createDETfiles" => 1,
		   "DrawIsoratiolines" => 1,
       "serialize" => 1,
       "Isoratiolines" => [ (100.0, 10.0, 1.0) ],
       "Isometriclines" => \@isolinecoef,
       "PointSet" => [] ) };
  print $ds->renderAsTxt("$dir/BA.randomTest.det", 1, 1, $options, "");                                                                     
}

1;
