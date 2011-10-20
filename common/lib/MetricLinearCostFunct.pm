# F4DE
# MetricLinearCostFunct.pm
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

package MetricLinearCostFunct;

use MetricFuncs;
@ISA = qw(MetricFuncs);

use strict;

use Data::Dumper;
use MMisc;

my @metric_params = ("CostMiss", "CostFA", "Ptarg");

use TrialsNormLinearCostFunct;
my @trials_params = TrialsNormLinearCostFunct::getParamsList();

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
    MMisc::error_quit("\'Ptarg\' parameter must be different than 1.0")
        if ($self->{PARAMS}->{Ptarg} == 1.0);

   #     print Dumper($self);
    $self->{CONST_MISS_FACT} = $self->{PARAMS}->{CostMiss} * $self->{PARAMS}->{Ptarg};
    $self->{CONST_FA_FACT} = $self->{PARAMS}->{CostFA} * (1 - $self->{PARAMS}->{Ptarg});

    bless ($self, $class);

    ### This implements a normalized cost
    $self->setCombLab("DCR??");

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

sub isoCombCoeffForDETCurve(){ (0.1, 0.2, 0.4, 0.5, 0.7, 1.0 ) }


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

sub isoCostRatioCoeffForDETCurve(){ (0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 40, 100, 200, 500, 1000, 2000, 3000, 5000, 10000, 20000, 50000, 100000, 200000, 400000, 600000, 800000, 900000, 950000, 980000) }


sub errMissBlockCalc(){
  my ($self, $nMiss, $block) = @_;
  my $NTarg =  $self->{TRIALS}->getNumTarg($block);
  
  ($NTarg > 0) ? $nMiss / $NTarg : undef;
}

sub errFABlockCalc(){
  my ($self, $nFa, $block) = @_;
  my $NNonTargTrials = (defined($self->{TRIALPARAMS}->{TOTALTRIALS}) ? 
                        $self->{TRIALPARAMS}->{TOTALTRIALS} - $self->{TRIALS}->getNumTarg($block) : 
                        $self->{TRIALS}->getNumNonTarg($block));
  ($NNonTargTrials > 0) ? $nFa / $NNonTargTrials : undef;
}

sub combCalcWeightedMiss(){
  my ($self, $missErr) = @_;
  if (defined($missErr)) {
      ($missErr * $self->{CONST_MISS_FACT});
  } else {
    undef;
  }
}

sub combCalcWeightedFA(){
  my ($self, $faErr) = @_;
  if (defined($faErr)) {
      ($faErr * $self->{CONST_FA_FACT});
  } else {
    undef;
  }
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
### Cost = Pm * Cm * Pt + Pf * Cf * (1 - Pt)
### Cost -  Pf * Cf * (1 - Pt) = (Pm * Cm * Pt)
### (Cost -  Pf * Cf * (1 - Pt)) / (Cm * Pt) = Pm

sub MISSForGivenComb(){
  my ($self, $comb, $faErr) = @_;

  if (defined($comb) && defined($faErr)) {
      (($comb) - ($faErr * $self->{CONST_FA_FACT})) / ($self->{CONST_MISS_FACT})
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

sub FAForGivenComb(){
    my ($self, $comb, $missErr) = @_;
    if (defined($comb) && defined($missErr)) {
    	(($comb) - ($missErr * $self->{CONST_MISS_FACT})) / ($self->{CONST_FA_FACT})
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
  MetricLinearCostFunct::unitTest($dir);  
}

=pod

=item B<unitTest(I<$dir>)>

Run the unit test for the object.  It build a trial structure and test the metric.  If I<$dir> is defined, then a DET Curve 
will be generated.

=cut

sub unitTest {
  my ($dir) = @_;

  print "Test MetricLinearCostFunct...".(defined($dir) ? " Dir=/$dir/" : "(Skipping DET Curve Generation)")."\n";

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


  my @isolinecoef = ( 31 );

  use DETCurve;
  use DETCurveSet;
  use DETCurveGnuplotRenderer;
  my $met = new MetricLinearCostFunct({ ('CostFA' => 1, 'CostMiss' => 10, 'Ptarg' => 0.01 ) }, $trial),
  my $DNmet = new MetricLinearCostFunct({ ('CostFA' => 1, 'CostMiss' => 10, 'Ptarg' => 0.01 ) }, $DNtrial);

  ##############################################################################################
  print "  Testing Calculations .. ";
  my ($exp, $ret);
  $exp = .1; $ret = $met->combCalc(1.0, 0.0); 
  die "\nError: Cost for Pmiss=1.0, Pfa=0.0 was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = .99; $ret = $met->combCalc(0.0, 1.0); 
  die "\nError: Cost for Pmiss=0.0, Pfa=1.0 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  $exp = 0.017425; $ret = $met->combCalc(0.1, 0.0075); 
  die "\nError: Cost for Pmiss=0.1, Pfa=0.0075 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);

  ## Inverse calculations for MISS
  $exp = 0.1; $ret = $met->MISSForGivenComb(0.017425, 0.0075); 
  die "\nError: MISS for Cost=0.8425, Pfa=0.0075 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  $exp = 1.0; $ret = $met->MISSForGivenComb(.1, 0.0); 
  die "\nError: MISS for Cost=1.0, Pfa=0.0 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  
  ## Inverse calculations for FA
  $exp = 0.0075; $ret = $met->FAForGivenComb(0.017425, 0.1); 
  die "\nError: FA for Cost=0.8425, Pmiss=0.1 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  $exp = 1.0; $ret = $met->FAForGivenComb(.99, 0.0); 
  die "\nError: FA for Cost=1.0, Pmiss=0.0 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  
  if (defined($dir)){
    my $det1 = new DETCurve($trial, $met, "Targetted point", \@isolinecoef, undef);
    my $DNdet = new DETCurve($DNtrial, $DNmet, "Do Nothing", \@isolinecoef, undef);

    my $ds = new DETCurveSet("MetricNormLinearFunction Tests");
    die "Error: Failed to add first det" if ("success" ne $ds->addDET("Targetted Point", $det1));
    die "Error: Failed to add second det" if ("success" ne $ds->addDET("Do Nothing", $DNdet));

    my $options = { ("Xmin" => .1,
		   "Xmax" => 95,
		   "Ymin" => .1,
		   "Ymax" => 95,
		   "xScale" => "nd",
		   "yScale" => "nd",
		   "ColorScheme" => "color",
       "DrawIsometriclines" => 1,
       "createDETfiles" => 1,
		   "DrawIsoratiolines" => 1,
                   "serialize" => 1,
                   "Isometriclines" => [ (0.1745) ],
                   "Isoratiolines" => [ (13.333) ],
                   "DETLineAttr" => { ("Name 1" => { label => "New DET1", lineWidth => 9, pointSize => 2, pointTypeSet => "square", color => "rgb \"#0000ff\"" }),
                                    },
                   "PointSet" => [ { MMiss => .8,  MFA => .06, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2011"}, 
                                   { MMiss => .57,  MFA => .045, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2012"}, 
                                   { MMiss => .4,  MFA => .03, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2013"}, 
                                   { MMiss => .29,  MFA => .02, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2014"}, 
                                   { MMiss => .2,  MFA => .015, pointSize => 1,  pointType => 10, color => "rgb \"#00ff00\"", label => "MED2015"}, 
                                   
                                   { MMiss => .565,  MFA => .0424, pointSize => 1,  pointType => 10, color => "rgb \"#ff0000\"", label => "Act  ", justification => "right"}, 
                                   { MMiss => .2828,  MFA => .0212, pointSize => 1,  pointType => 10, color => "rgb \"#ff0000\"", label => "Act  ", justification => "right"}, 
                                   ] ) };
  
    print $ds->renderAsTxt("$dir/MLCF.unitTest.det", 1, 1, $options, "");                                                                     
    ################ HACKED UNIT TEST #################
    # Check to see if the unmarshalling works.
    $det1 = DETCurve::readFromFile("MLCF.unitTest.det.Do_Nothing.srl.gz");    
    ###################################################

  }
  printf "Done\n";
  ###############################################################################################
}

1;
