# F4DE
# MetricTV08.pm
# Author: Jon Fiscus
# Additions: Martial Michel
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

package MetricTV08;

use MetricFuncs;
@ISA = qw(MetricFuncs);

use strict;

use Data::Dumper;
use MMisc;

=pod
=head1 NAME

TrecVid08/lib/MetricTV08 - Compiled 2-class detection metrics for TRECViD '08 Event Detection

=head1 SYNOPSIS

This object computes Type I (False alarms) and Type II (Missed detection) errors for a 2-class
detection problem with a combined error metric.  The object implements a standard interface for
this class of evaluation.  All methods in this class are required.

=head1 DESCRIPTION

=head2 METHODS

=over 4

####################################################################################################
=item B<new>(I<$%HashOfConstants>, I<$TrialsObject>)  

Returns a new metrics object.  On failure to validate the arguements, returns NULL.  For this object, the costants hash
must contain 'CostMiss', 'CostFA', and 'RateFA'.   The Trials object must also contain the constant 'TOTALDURATION' which 
is the duration of the test material.  Note that 'RateFA' and 'TOTALDURATION' must be in the same units, (seconds, hours, etc.)

On error, the object returns a string indication the error.  The calling program should implement the following to check 
whether or not the object was created.

    my $met = new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $emptyTrial);
    if (ref($met) ne "MetricTestStub"){
        die "Error: Unable to create a MetricTestStub object with message '$met'\n";
    }

=cut

my @metric_params = ("CostMiss", "CostFA", "Rtarget");

sub getParamsList { return(@metric_params); }

my @trials_params = ("TOTALDURATION");

sub getTrialsNeededParamsList { return(@trials_params); }

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
    MMisc::error_quit("TOTALDURATION must be > 0")
        if ($self->{TRIALPARAMS}->{TOTALDURATION} <= 0);

    $self->{PARAMS}->{BETA} = $self->{PARAMS}->{CostFA} / 
      ($self->{PARAMS}->{CostMiss} * $self->{PARAMS}->{Rtarget});
        
    bless($self, $class);

    $self->setErrFALab("RFA");
    $self->setErrFAUnit("Rate");
    $self->setErrFAUnitLabel("Events/Hour");
    $self->setCombLab("DCR");

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

  if ($param eq "TOTALDURATION"){
    if ($mergeType eq "pooled"){
      ### if pooled, totalduration added
      return (defined($mergedValue) ? $mergedValue : 0) + $toMergeValue;
    } elsif ($mergeType eq "blocked") {
      ### if blocked, the totalduration MUST be constant 
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

  sub isoCombCoeffForDETCurve(){ (0.1, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0 ) }


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



####################################################################################################
=pod

=item B<errMissBlockCalc>(I<$nMiss>, I<$block>)

Calculates the miss error statistic for block '$block' if the number of misses is '$nMiss'.  This functions uses the 
reference to the trials data structure to find the denominator.   If the denominator is 0, then the statistic is undefined
and it returns C<undef>.

=cut

  sub errMissBlockCalc(){
    my ($self, $nMiss, $block) = @_;
    my $NTarg =  $self->{TRIALS}->getNumTarg($block);
  
    ($NTarg > 0) ? $nMiss / $NTarg : undef;
  }

####################################################################################################
=pod

=item B<errFABlockCalc>(I<$nFA>, I<$block>)

Calculates the false alarm error statistic for block '$block' if the number of false alarms is '$nFA'.  This functions uses the 
reference to the trials data structure to find the denominator.   If the denominator is 0, then the statistic is undefined
and it returns C<undef>.

=cut

  sub errFABlockCalc(){
    my ($self, $nFa, $block) = @_;
    ### The denominator is already checked so no need to return undef.  TotalDuration is in seconds!!!!
    $nFa / ($self->{TRIALPARAMS}->{TOTALDURATION} / 3600);
  }


####################################################################################################
=pod

=item B<combCalcWeightedMiss>()

Returns the wieghted MISS value for the combined calculation 

=cut

  sub combCalcWeightedMiss(){
    my ($self, $missErr) = @_;
    if (defined($missErr)) {
      $missErr;
    } else {
      undef;
    }
  }

####################################################################################################
=pod

=item B<combCalcWeightedFA>()

Returns the wieghted FA value for the combined calculation 

=cut
  sub combCalcWeightedFA(){
    my ($self, $faErr) = @_;
    if (defined($faErr)) {
      $self->{PARAMS}->{BETA} * $faErr;
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

  sub MISSForGivenComb(){
    my ($self, $comb, $faErr) = @_;
    if (defined($comb) && defined($faErr)) {
      $comb - $self->{PARAMS}->{BETA} * $faErr;
    } else {
      undef;
    }
  }

####################################################################################################
=pod

=item B<FAForGivenComb>(I<$comb, I<$missErr>)

Calculates the value of the Fa statistic for a given combined measure and the Miss value.  This is 
a permutation of the combined formula to solve for the Fa value. This method uses the constants 
defined during object creation.  If either C<$comb> or 
C<$missErr> is undefined, then the combined calculation returns C<undef>,

=cut

  sub FAForGivenComb(){
    my ($self, $comb, $missErr) = @_;
    if (defined($comb) && defined($missErr)) {
      ($comb - $missErr)/$self->{PARAMS}->{BETA};
    } else {
      undef;
    }
  }



#POD# =back 4
#POD# 


1;
