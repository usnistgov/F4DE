# F4DE
# MetricSTD.pm
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

package MetricTestStub;
use MetricFuncs;
@ISA = qw(MetricFuncs);

use strict;

use Data::Dumper;
use MMisc;
 
my @metric_params = ("ValueV", "ValueC", "ProbOfTerm");

use TrialsTestStub;
my @trials_params = TrialsTestStub::getParamsList();

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
    }
    foreach my $p (@trials_params) {
      MMisc::error_quit("Trials parameter \'$p\' does not exist")
          if (! exists($self->{TRIALPARAMS}->{$p}));
    }

    #    print Dumper($self->{TRIALPARAMS});

    $self->{PARAMS}->{BETA} = $self->{PARAMS}->{ValueC} / $self->{PARAMS}->{ValueV} * 
      ((1 / $self->{PARAMS}->{ProbOfTerm}) - 1);

    bless ($self, $class);
    $self->setCombTypToMaximizable();
    $self->setCombLab("Value");

    if (0){
      $self->setErrMissLab("setErrMissLab");
      #$self->setErrMissUnit("setErrMissUnit");
      $self->setErrMissUnitLabel("setErrMissUnitLabel");
      ##sub setErrMissPrintFormat(){ my $self = shift; $self->{"errMissPrintFormat"} = shift; }
      $self->setErrFALab("setErrFALab");
      #$self->setErrFAUnit("setErrFAUnit");
      $self->setErrFAUnitLabel("setErrFAUnitLabel");
      #sub setErrFAPrintFormat(){ my $self = shift; $self->{"errFAPrintFormat"} = shift; }
      $self->setCombLab("setCombLab");
      #sub setCombPrintFormat(){ my $self = shift; $self->{"combPrintFormat"} = shift; }
    }

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

####################################################################################################
=pod

=item B<errMissPrintFormat>()

Returns a printf() format string for printing out miss error measurements. 

=cut

sub errFABlockCalc(){
  my ($self, $nFa, $block) = @_;
  my $NNonTargTrials = (defined($self->{TRIALPARAMS}->{TOTALTRIALS}) ? 
                        $self->{TRIALPARAMS}->{TOTALTRIALS} - $self->{TRIALS}->getNumTarg($block) : 
                        $self->{TRIALS}->getNumNonTarg($block));
  $nFa / $NNonTargTrials;
}


####################################################################################################
=pod

=item B<combCalcWeightedMiss>()

Returns the wieghted MISS value for the combined calculation 

=cut

sub combCalcWeightedMiss(){
  my ($self, $missErr) = @_;
  undef;
}


####################################################################################################
=pod

=item B<combCalcWeightedFA>()

Returns the wieghted FA value for the combined calculation 

=cut
sub combCalcWeightedFA(){
  my ($self, $faErr) = @_;
  undef;
}

### Either 'maximizable' or 'minimizable'
sub combCalc(){
  my ($self, $missErr, $faErr) = @_;
  if (defined($missErr)) {
    1  - ($missErr + $self->{PARAMS}->{BETA} * $faErr);
  } else {
    undef;
  }
}

####################################################################################################
=pod

=item B<combPrintFormat>()

Returns a printf() format string for printing out combined performance statistic. 

=cut
  sub combPrintFormat(){ "%6.4f" };

####################################################################################################
=pod

=item B<MISSForGivenComb>(I<$comb, I<$faErr>)

Calculates the value of the Miss statistic for a given combined measure and the FA value.  This is 
a permutation of the combined formula to solve for the Miss value. This method uses the constants 
defined during object creation.  If either C<$comb> or 
C<$faErr> is undefined, then the combined calculation returns C<undef>,

=cut

sub MISSForGivenComb(){
  my ($self, $comb, $faErr) = @_;
  if (defined($comb) && defined($faErr)) {
    - ($comb - 1 + $self->{PARAMS}->{BETA} * $faErr);
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
	  (1 - $comb - $missErr)/$self->{PARAMS}->{BETA};
	} else {
	  undef;
	}
}

1;
