# F4DE
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

package MetricRo;

use MetricFuncs;
@ISA = qw(MetricFuncs);

use strict;

use Data::Dumper;
use MMisc;

my @metric_params = ("m");

use TrialsRo;
my @trials_params = TrialsRo::getParamsList();

sub getParamsList { return(@metric_params); }
sub getTrialsParamsList { return(@trials_params); }
 
sub new
  {
    my ($class, $parameters, $trial) = @_;

    my $self = MetricFuncs->new($parameters, $trial);
    bless ($self, $class);

    #######  customizations - Required parameters
    foreach my $p ("m") {
      MMisc::error_quit("parameter \'$p\' not defined")   if (! exists($self->{PARAMS}->{$p}));
      MMisc::error_quit("parameter \'$p\' must > 0")      if ($self->{PARAMS}->{$p} <= 0);      
    }
    foreach my $p (@trials_params) {
      MMisc::error_quit("Trials parameter \'$p\' does not exist")
          if (! exists($self->{TRIALPARAMS}->{$p}));
    }

    ### This implements a normalized cost
    $self->setCombLab("Ro");
    $self->setErrFAUnit("Pct");
    $self->setErrMissUnit("Pct");
    $self->setErrMissLab("Recall");
    $self->setErrFALab("Percent Rank");
    $self->setCombTypToMaximizable();
    $self->setErrMissPrintFormat("%.1f");
    $self->setErrFAPrintFormat("%.1f");
    $self->setCombPrintFormat("%.1f");

    $self->{defaultPlotOptions}{ReportGlobal} = 1;
    $self->{defaultPlotOptions}{Xmin} = 0;
    $self->{defaultPlotOptions}{Xmax} = 5;
    $self->{defaultPlotOptions}{Ymin} = 0;
    $self->{defaultPlotOptions}{Ymax} = 100;
#    $self->{defaultPlotOptions}{DrawIsometriclines} = 1;
#    $self->{defaultPlotOptions}{Isometriclines} = [(25, 50, 65, 75, 85)];
    $self->{defaultPlotOptions}{xScale} = "linear";
    $self->{defaultPlotOptions}{yScale} = "linear";
    $self->{defaultPlotOptions}{ColorScheme} = "colorPresentation";
    $self->{defaultPlotOptions}{ReportRowTotals} = 1;
    $self->{defaultPlotOptions}{IncludeRandomCurve} = "false";
#    $self->{defaultPlotOptions}{DETShowMeasurementsAsLegend} = 1;
    $self->{defaultPlotOptions}{DETShowPoint_Actual} = 1;
#    $self->{defaultPlotOptions}{DETShowPoint_Best} = 1;
    $self->{defaultPlotOptions}{DETShowPoint_SupportValues} = [("C", "G")];
    $self->{defaultPlotOptions}{KeyLoc} = "right bottom";
    $self->{defaultPlotOptions}{PlotThresh} = "false";
    $self->{defaultPlotOptions}{"XticFormat"} = "%.3f";
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

#### Recall
sub errMissBlockCalc(){
  my ($self, $nMiss, $nFA, $block) = @_;
  my $NTarg =  $self->{TRIALS}->getNumTarg($block);
  
  ($NTarg > 0) ? ($NTarg - $nMiss) / $NTarg * 100: undef; 
}

#### Percent Recall
sub errFABlockCalc(){
  my ($self, $nMiss, $nFa, $block) = @_;
  my $NTarg =  $self->{TRIALS}->getNumTarg($block);
  my $NRet = ( ($NTarg - $nMiss) + $nFa);
  my $NNTarg = $self->{TRIALS}->getNumNonTarg($block);
  ($NNTarg + $NTarg > 0) ? ($NRet) / ($NNTarg + $NTarg) * 100: undef;
}

sub combCalcWeightedMiss(){
  my ($self, $missErr) = @_;
  die "This function combCalcWeightedMiss() for the MetricRo metric";
}

sub combCalcWeightedFA(){
  my ($self, $faErr) = @_;
  die "This function combCalcWeightedFA() for the MetricRo metric";
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
  my $m = $self->{PARAMS}->{'m'};
  return ($missErr - $m * $faErr);
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
#  Ro = RT - m * Rho(t)
#
#  Ro = miss - m * fa
#  miss = Ro + m *fa

sub MISSForGivenComb(){
  my ($self, $comb, $faErr) = @_;
  
  if (defined($comb) && defined($faErr)) {
    my $m = $self->{PARAMS}->{'m'};
    return($comb + $m * $faErr);
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

#
#  Ro = miss - m * fa
#  Ro - miss = m * fa  
#  fa = (Ro - miss) / m

sub FAForGivenComb(){
  my ($self, $comb, $missErr) = @_;
  
  if (defined($comb) && defined($missErr)) {
    my $m = $self->{PARAMS}->{'m'};
    return(($comb - $missErr) / $m);
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
  MetricRo::unitTest($dir);  
}

sub unitTest {
  my ($dir) = @_;

  print "Test MetricRo...".(defined($dir) ? " Dir=/$dir/" : "(Skipping DET Curve Generation)")."\n";

  my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );

################################### A do nothing system
### Pmiss == 1  - 10 misses
### PFa == 0    - 0  FA  
### Cost == 1

  my $DNtrial = new TrialsRo({ () }, "Term Detection", "Term", "Occurrence");
  $DNtrial->addTrial("she", 0.03, "NO", 0);
  $DNtrial->addTrial("she", 0.04, "NO", 1);  #276
  $DNtrial->addTrial("she", 0.05, "NO", 1); #275
  $DNtrial->addTrial("she", 0.10, "NO", 0);
  $DNtrial->addTrial("she", 0.15, "NO", 0);
  foreach (1..259){
  $DNtrial->addTrial("she", 0.17, "NO", 0);
  }
  $DNtrial->addTrial("she", 0.17, "NO", 0);
  $DNtrial->addTrial("she", 0.20, "NO", 1);  #12
  $DNtrial->addTrial("she", 0.25, "NO", 1);  #11
  $DNtrial->addTrial("she", 0.65, "NO", 1);  #10
  $DNtrial->addTrial("she", 0.70, "NO", 1);  #9
  $DNtrial->addTrial("she", 0.70, "NO", 1);  #8
  $DNtrial->addTrial("she", 0.75, "NO", 0);
  $DNtrial->addTrial("she", 0.75, "NO", 1);  #7
  $DNtrial->addTrial("she", 0.85, "NO", 0);
  $DNtrial->addTrial("she", 0.85, "NO", 1);  #5
  $DNtrial->addTrial("she", 0.98, "NO", 0);
  $DNtrial->addTrial("she", 0.98, "NO", 0);
  $DNtrial->addTrial("she", 1.00, "NO", 1);  #1

  my $IDs = new TrialsRo({ () }, "Term Detection", "Term", "Occurrence");
  $IDs->addTrial("she", 0.03, "NO", 0, undef, "id300");
  $IDs->addTrial("she", 0.04, "NO", 1, undef, "id276");  #276
  $IDs->addTrial("she", 0.05, "NO", 1, undef, "id275"); #275
  $IDs->addTrial("she", 0.10, "NO", 0, undef, "id100");
  $IDs->addTrial("she", 0.15, "NO", 0, undef, "id100");
  foreach (1..259){
    $IDs->addTrial("she", 0.17, "NO", 0, undef, "id100");
  }
  $IDs->addTrial("she", 0.17, "NO", 0, undef, "id012");
  $IDs->addTrial("she", 0.20, "NO", 1, undef, "id012");  #12
  $IDs->addTrial("she", 0.25, "NO", 1, undef, "id011");  #11
  $IDs->addTrial("she", 0.65, "NO", 1, undef, "id010");  #10
  $IDs->addTrial("she", 0.70, "NO", 1, undef, "id009");  #9
  $IDs->addTrial("she", 0.70, "NO", 1, undef, "id008");  #8
  $IDs->addTrial("she", 0.75, "NO", 0, undef, "id007");
  $IDs->addTrial("she", 0.75, "NO", 1, undef, "id006");  #6
  $IDs->addTrial("she", 0.85, "NO", 0, undef, "id005");
  $IDs->addTrial("she", 0.85, "NO", 1, undef, "id004");  #4
  $IDs->addTrial("she", 0.98, "NO", 0, undef, "id003");
  $IDs->addTrial("she", 0.98, "NO", 0, undef, "id001");
  $IDs->addTrial("she", 1.00, "NO", 1, undef, "id001");  #1

################################### A target point
### Pmiss == 0.1  - 1 misses
### PFa == 0.0075  - 3 FA  
### Cost == 0.8425
     
  my $trial = new TrialsRo({ () }, "Term Detection", "Term", "Occurrence");
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

  @isolinecoef = ( );

  use DETCurve;
  use DETCurveSet;
  use DETCurveGnuplotRenderer;

  my $met = new MetricRo({ ('m' => 2, 'APPpct' => "true", 'APpct' => "true") }, $trial);
  my $DNmet = new MetricRo({ ('m' => 2, 'APPpct' => "true", 'APpct' => "true") }, $DNtrial);

  ##############################################################################################
  print "  Testing Calculations .. ";
  my ($exp, $ret, $pret, $recall, $comb);
  
  ## PercentReturned and recall checks
  $exp = 50.0; $ret = $met->errMissBlockCalc(5, 20, "she"); 
  die "\nError: errMissBlockCalc(#Miss=5, #FA=20, block=she) was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = 6.09756097560976; $ret = $met->errFABlockCalc(5, 20, "she");
  die "\nError: errFABlockCalc(#Miss=5, #FA=20, block=she) was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  
  $exp = -100; $pret = 100; $recall = 100; $ret = $met->combCalc($pret, $recall); 
  die "\nError: Ro for PRet=$pret, Recall=$recall was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = -200; $pret = 0; $recall = 100; $ret = $met->combCalc($pret, $recall); 
  die "\nError: Ro for PRet=$pret, Recall=$recall was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = 1; $pret = 1; $recall = 0; $ret = $met->combCalc($pret, $recall); 
  die "\nError: Ro for PRet=$pret, Recall=$recall was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = -0.5; $pret = 0.5; $recall = 0.5; $ret = $met->combCalc($pret, $recall); 
  die "\nError: Ro for PRet=$pret, Recall=$recall was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);


  $exp = 90; $ret = $met->errMissBlockCalc(1, 3, "she"); 
  die "\nError: errMissBlockCalc(#Miss=1, #FA=3, block=she) was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = 2.9268; $ret = $met->errFABlockCalc(1, 3, "she"); 
  die "\nError: errFABlockCalc(#Miss=1, #FA=3, block=she) was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001); 

  ## Inverse calculations for MISS

  $exp = -0.5; $pret = 0.5; $comb = -0.5; $ret = $met->FAForGivenComb($comb, $pret); 
  die "\nError: FAForGivenComb(comb=$comb, recall=$recall) was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);

  $exp = 0.5; $recall = 0.5; $comb = -0.5; $ret = $met->MISSForGivenComb($comb, $recall); 
  die "\nError: MISSForGivenComb(comb=$comb, recall=$recall) was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  print "Ok\n";

  $ret = $met->testActualDecisionPerformance([ (84.14634, undef, 90, undef, 2.92683, undef) ], "  ");  die $ret if ($ret ne "ok");
  
  my $det1 = new DETCurve($trial, $met, "Targetted point", \@isolinecoef, undef);
  $det1->computePoints();

  my $DNdet = new DETCurve($DNtrial, $DNmet, "Do Nothing", \@isolinecoef, undef);
  $DNdet->computePoints();

  my $IDsDet = new DETCurve($IDs, $DNmet, "Do Nothing", \@isolinecoef, undef);
  $IDsDet->computePoints();
  
  my $ds = new DETCurveSet("MetricRo Tests");
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("Targetted Point", $det1));
  die "Error: Failed to add second det" if ("success" ne $ds->addDET("Do Nothing", $DNdet));

  $exp = 85.0190;
  die "\nError: Ave Prec for \$det1 is ".$det1->getGlobalMeasure("APpct")." not $exp\n" 
    if (abs($det1->getGlobalMeasure("APpct") - $exp) > 0.0001);
  $exp = 48.5611;
  die "\nError: Ave Prec for \$DNdet is ".$DNdet->getGlobalMeasure("APpct")." not $exp\n" 
    if (abs($DNdet->getGlobalMeasure("APpct") - $exp) > 0.0001);
  $exp = 50.27545;
  die "\nError: Ave Prec for \$DNdet is ".$IDsDet->getGlobalMeasure("APpct")." not $exp\n" 
    if (abs($IDsDet->getGlobalMeasure("APpct") - $exp) > 0.0001);

  $exp = 72.0472;
  die "\nError: Ave Prec' for \$det1 is ".$det1->getGlobalMeasure("APPpct")." not $exp\n" 
    if (abs($det1->getGlobalMeasure("APPpct") - $exp) > 0.0001);
  

  if (defined($dir)){
    my $options = { (
		   "ColorScheme" => "colorPresentation",
#       "DrawIsometriclines" => 1,
#       "Isometriclines" => [ (.5, .1) ], 
       "createDETfiles" => 1,
       "serialize" => 1,
        ExcludePNGFileFromTextTable => 1
     ) };
  
    print $ds->renderAsTxt("$dir/Ro.unitTest.det", 1, $options, "");                                                                     
    ################ HACKED UNIT TEST #################
    # Check to see if the unmarshalling works.
    $det1 = DETCurve::readFromFile("$dir/Ro.unitTest.det.Do_Nothing.srl.gz");    
    ###################################################

  }
  ###############################################################################################
  exit(0);
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
  my $ds = new DETCurveSet("MetricRo Tests");
      
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
     my $met = new MetricRo({ ('m' => 12.5, 'AP' => "true") }, $trial);
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
       "Isometriclines" => [ (.9, .8, .7, .6, .4, .2, .1 ) ], 
#       "DrawIsoratiolines" => 1,
#       "Isoratiolines" =>  [ (1) ],
       "ColorScheme" => "colorPresentation",
       "createDETfiles" => 1,
       "serialize" => 1 ) };
       
#  DB::enable_profile("$dir/MNLCF.randomTest.profile");
  print $ds->renderAsTxt("$dir/Ro.randomTest.det", 1, $options, "");                                                                     
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
    my $epochMet = new MetricRo({ ('m' => 12.5, 'AP' => "true") }, $trial);
    my $epochDet = new DETCurve($epochTrial, $epochMet, "Epoch $epoch", \@isolinecoef, undef);
    die "Error: Failed to add first det" if ("success" ne $ds->addDET("Epoch $epoch", $epochDet));
  } 
  my $met = new MetricRo({ (m => 12.5, 'AP' => "true") }, $trial);
  my $det1 = new DETCurve($trial, $met, "Block Averaged", \@isolinecoef, undef);

  die "Error: Failed to add first det" if ("success" ne $ds->addDET("Block Averaged", $det1));

  my $options = { 
      ("Xmin" => 0.1,
		   "Xmax" => 99.9,
		   "Ymin" => .1,
		   "Ymax" => 99.9,
		   "xScale" => "linear",
		   "yScale" => "linear",
		   "ColorScheme" => "colorPresentation",
       "DrawIsometriclines" => 1,
       "createDETfiles" => 1,
#		   "DrawIsoratiolines" => 1,
       "serialize" => 1,
#       "Isoratiolines" => [ (100.0, 10.0, 1.0) ],
       "Isometriclines" => \@isolinecoef,
       "PointSet" => [] ) };
  print $ds->renderAsTxt("$dir/BA.randomTest.det", 1, $options, "");                                                                     
}

1;
