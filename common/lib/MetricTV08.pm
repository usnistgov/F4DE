# MetricSTD.pm
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

package MetricTV08;
@ISA = qw(MetricFuncs);

use strict;
use MetricFuncs;

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
=item B<new>(I<$%HashOfConstants>, I<$TrailsObject>)  

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

sub new
  {
    my ($class, $parameters, $trial) = @_;

    my $self =
      {
       "PARAMS" => $parameters,
       "TRIALS" => $trial,
       "TRIALPARAMS" => $trial->getMetricParams(),
      };

    #######  customizations
    die "Error: parameter 'CostMiss' not defined"     if (! exists($self->{PARAMS}->{CostMiss}));
    die "Error: parameter 'CostFA' not defined"       if (! exists($self->{PARAMS}->{CostFA}));
    die "Error: parameter 'Rtarget' not defined"      if (! exists($self->{PARAMS}->{Rtarget}));
    die "Error: trials parameter TOTALDURATION does not exist" if (! exists($self->{TRIALPARAMS}->{TOTALDURATION}));
    die "Error: TOTALDURATION must be > 0" if ($self->{TRIALPARAMS}->{TOTALDURATION} <= 0);
    die "Error: CostMiss must be > 0"      if ($self->{PARAMS}->{CostMiss} <= 0);
    die "Error: CostFA must be > 0"        if ($self->{PARAMS}->{CostFA} <= 0);
    die "Error: Rtarget must be > 0"       if ($self->{PARAMS}->{Rtarget} <= 0);

    $self->{PARAMS}->{BETA} = $self->{PARAMS}->{CostFA} / 
      ($self->{PARAMS}->{CostMiss} * $self->{PARAMS}->{Rtarget});
        
    bless $self;
    return $self;
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

=item B<errMissLab>()

Returns a free-form label string for the MissError statistic.  The method is required.

=cut

  sub errMissLab(){ "PMiss"; }

####################################################################################################
=pod

=item B<errMissUnit>()

Returns the units of the miss error metric.  It can be either "B<Prob>" for a probability, or "B<Rate>" for a 
time based rate.

=cut

  sub errMissUnit(){ "Prob" };

####################################################################################################
=pod

=item B<errMissUnitLabel>()

Returns the units lable for the miss error metric.  It can be anything.  The labels is used in the DET curves
to print the units.

=cut

  sub errMissUnitLabel(){ "%" };

####################################################################################################
=pod

=item B<errMissPrintFormat>()

Returns a printf() format string for printing out miss error measurements. 

=cut

  sub errMissPrintFormat(){ "%6.4f" };

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

=item B<errFALab>()

Returns a free-form label string for the FAError statistic.  The method is required.

=cut

  sub errFALab() { "RFA"; }

####################################################################################################
=pod

=item B<errFAUnit>()

Returns the units of the false alarm error metric.  It can be either "B<Prob>" for a probability, or "B<Rate>" for a 
time based rate.

=cut

  sub errFAUnit(){ "Rate" };

####################################################################################################
=pod

=item B<errFAUnitLabel>()

Returns the units lable for the FA error metric.  It can be anything.  The labels is used in the DET curves
to print the units.

=cut

  sub errFAUnitLabel(){ "Events/Hour" };

####################################################################################################
=pod

=item B<errFAPrintFormat>()

Returns a printf() format string for printing out false alarm error measurements. 

=cut

  sub errFAPrintFormat(){ "%6.4f" };

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

=item B<combType>()

Returns a string indicating wether or not the combined metric should be 'maximized' to optimize
performance or 'minimized' to optimize performancs.  

The legal values are /minimizable/ or /maximizable/.

=cut

  sub combType() { "minimizable"; }

####################################################################################################
=pod

=item B<combLab>()

Returns a free-form label string for the combined performance statistic.

=cut

  sub combLab() { "DCR"; }


####################################################################################################
=pod

=item B<combPrintFormat>()

Returns a printf() format string for printing out combined performance statistic. 

=cut
  sub combPrintFormat(){ "%6.4f" };

####################################################################################################
=pod

=item B<combCalc>(I<$missErr, I<$faErr>)

Calculates the combined error metric as a combination of the miss error statistic and the false 
alarm error statistic.  This method uses the constants defined during object creation.  If either C<$missErr> or 
C<$faErr> is undefined, then the combined calculation returns C<undef>,

=cut

  sub combCalc(){
    my ($self, $missErr, $faErr) = @_;
    if (defined($missErr) && defined($faErr)) {
      $missErr + $self->{PARAMS}->{BETA} * $faErr;
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

####################################################################################################
=pod

=item B<combBlockCalc>(I<$nMiss, I<$nFA>, I<$block>)

Computes the combine error metric for a block.  This method takes in the number of misses for the block C<$nMiss>, 
the number of false alarms for the block C<$nFA> and the block id C<$block>.  Then, it calls the sub functions within
the object to calc the error rate.

The method returns C<undef> if either miss or fa error is undefined.

=cut

  sub combBlockCalc(){
    my ($self, $nMiss, $nFa, $block) = @_;
    $self->combCalc($self->errMissBlockCalc($nMiss, $block), $self->errFABlockCalc($nFa, $block));
  }

####################################################################################################
=pod

=item B<combBlockSetCalc>(I<$HashWithMMISSandMFA>)

Calculates the combined statistic over a set of blocks as recorded in the C<%$HashWithMFA> hash table.  The 
method returns an array of the following values: 

=over 4

I<CombStat> is the value of the combined statistic over all blocks.  

I<CombSSD> is the sample standard deviation of the combined statistic.  It can be C<undef> if the combined statistic does not 
have an SSD defined (as in a pooled micro-average), or if fewer than 2 blocks exist.

I<BlockSetMiss> is the missed detection error over all blocks.  If there are 0 blocks, then C<undef> is returned.

I<BlockSetMissSSD> is the missed detection sample standard deviation for the block set.  The value can be C<undef> if the SSD isn't defined OR there are fewer than 2 blocks.

I<BlockSetFA> is the false alarm error over all blocks.  If there are 0 blocks, then C<undef> is returned.

I<BlockSetFASSD> is the false alarm sample standard deviation for the block set.  The value can be C<undef> if the SSD isn't defined OR there are fewer than 2 blocks.

=back 4

The hash TABLE I<$%HashWithMMISSandMFA> is to be organized as follows where 'BLK1'... are block ids 
from the trial structure.  If a block ID is used in the hash table that is not defined in the trial structure, 
the CODE DIES as this should never happen.

    $ht = { { 'BLK1' => { MMISS => <integer>, MFA => <integer>},
              'BLK2' => { MMISS => <integer>, MFA => <integer>} } }



=cut

  sub combBlockSetCalc(){
    my ($self, $data) = @_;
    #### Data is a hash ref with the primary key being a block and for each block there 
    #### MUST be a 2 secondary keys, 'MMISS' and 'MFA'
    
    my ($combSum, $combSumSqr, $combN) = (0, 0, 0);
    my ($missSum, $missSumSqr, $missN) = (0, 0, 0);
    my ($faSum,   $faSumSqr,   $faN) =   (0, 0, 0);
    
    #    my $combAvg = $self->combErrCalc($missAvg, $faAvg);
    #    ($combAvg, undef, $missAvg, $missSSD, $faAvg, $faSSD);

    foreach my $block (keys %$data) {
      my $luFA = $data->{$block}{MFA};
      my $luMiss = $data->{$block}{MMISS};
      die "Error: Can't calculate errCombBlockSetCalc: key 'MFA' for block '$block' missing" if (! defined($luFA));
      die "Error: Can't calculate errCombBlockSetCalc: key 'MMISS' for block '$block' missing" if (! defined($luMiss));

      my $miss = $self->errMissBlockCalc($luMiss, $block); 
      if (defined($miss)) {
        $missSum += $miss;
        $missSumSqr += $miss * $miss;
        $missN++;
      }
      my $fa = $self->errFABlockCalc($luFA, $block); 
      if (defined($fa)) {
        $faSum += $fa;
        $faSumSqr += $fa * $fa;
        $faN ++;
      }        
      ### Try to calculate the SSD of the combined metric IFF the miss and fa errors are allways defined.  If they
      ### are not for one block, then punt!
      if (defined($fa) && defined($miss)) {
        if (defined($combSum)) {
          my $comb = $self->combCalc($miss, $fa);
          $combSum += $comb;
          $combSumSqr += $comb;
          $combN ++;
        }
      } else {
        $combSum = undef;
      }
    }
    
    my ($faBSet, $faBSetSSD) = (undef, undef); 
    $faBSet = $faSum / $faN if ($faN > 0);
    $faBSetSSD = sqrt((($faN * $faSumSqr) - ($faSum * $faSum)) / ($faN * ($faN - 1))) if ($faN >= 2);
  
    my ($missBSet, $missBSetSSD) = (undef, undef); 
    $missBSet = $missSum / $missN if ($missN > 0);
    $missBSetSSD = sqrt((($missN * $missSumSqr) - ($missSum * $missSum)) / ($missN * ($missN - 1))) if ($missN >= 2);

    my ($combBSet, $combBSetSSD) = (undef, undef);
    $combBSet = $self->combCalc($missBSet, $faBSet);
    $combBSetSSD = sqrt((($combN * $combSumSqr) - ($combSum * $combSum)) / ($combN * ($combN - 1))) if (defined($combSum)  && $combN > 1);

    ($combBSet, $combBSetSSD, $missBSet, $missBSetSSD, $faBSet, $faBSetSSD);
  }

#POD# =back 4
#POD# 


1;
