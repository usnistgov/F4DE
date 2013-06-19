# F4DE
# MetrticFuncs.pm
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
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package MetricFuncs;

use TrialsFuncs;
use strict;
use Data::Dumper;

=pod

=head1 NAME

common/lib/MetricFuncs - a set of inhereited functions for Metrics objects

=head1 SYNOPSIS

This object contains inherited methods for the metrics objects.  This is to keep 
the specialized functions separate from the default functions.
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

=cut

sub new {
    my ($class, $parameters, $trial) = @_;

    my $self =
      {
       "PARAMS" => $parameters,
       "TRIALS" => $trial,
       "TRIALPARAMS" => $trial->getTrialParams(),
       "errMissLab" => "PMiss",
       "errMissUnit" => "Prob",
       "errMissUnitLabel" => "",
       "errMissPrintFormat" => "%6.3f",
       "errFALab" => "PFA",
       "errFAUnit" => "Prob",
       "errFAUnitLabel" => "",
       "errFAPrintFormat" => "%6.5f",
       "combLab" => "Cost",
       "combPrintFormat" => "%6.4f",
       "optimizationStyle" => "minimizable",
       "definedGlobalMeasures" => [("AP", "APP", "APpct", "APPpct")],
       "globalMeasures" => [()],
       "defaultPlotOptions" => {},
      };

    bless ($self, $class);
    ####### Optional parameters for Global Measures
    foreach my $p (@{ $self->{"definedGlobalMeasures"} }) {
      if (exists($parameters->{$p})) {
        $self->setPerformGlobalMeasure($p, $parameters->{$p});
      }
    }
    return $self;
}

####################################################################################################
=item B<isCompatible>(I<$metric>)

Tests to see if the metrics are compatible, meaning that both metrics have the same
parameters and values for the parameters EXCLUDING Global parameters.

=cut

sub isCompatible(){
  my ($self, $met2) = @_;
    
  return 0 if (ref($self) ne ref($met2));
    
  my @tmp = keys %{ $self->{PARAMS} };
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $k = $tmp[$i];

    ## Avoig globalMeasure checks
    my @mlist = grep { $_ eq $k} @{ $self->{definedGlobalMeasures} };
    next if (@mlist > 0);

    return 0 if (! exists($met2->{PARAMS}->{$k}));
    return 0 if ($self->{PARAMS}->{$k} ne $met2->{PARAMS}->{$k});
  }

  @tmp = keys %{ $met2->{PARAMS} };
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $k = $tmp[$i];

    ## Avoig globalMeasure checks
    my @mlist = grep { $_ eq $k} @{ $self->{definedGlobalMeasures} };
    next if (@mlist > 0);

    return 0 if (! exists($self->{PARAMS}->{$k}));
    return 0 if ($self->{PARAMS}->{$k} ne $met2->{PARAMS}->{$k});
  }

  return 1;
}

####################################################################################################
=pod

=item B<errMissLab>()

Returns a free-form label string for the MissError statistic.  The method is required.

=cut

sub errMissLab(){ my $self = shift; $self->{"errMissLab"}; }

####################################################################################################
=pod

=item B<errMissUnit>()

Returns the units of the miss error metric.  It can be either "B<Prob>" for a probability, or "B<Rate>" for a 
time based rate.

=cut

sub errMissUnit(){ my $self = shift; $self->{"errMissUnit"} };

####################################################################################################
=pod

=item B<errMissUnitLabel>()

Returns the units lable for the miss error metric.  It can be anything.  The labels is used in the DET curves
to print the units.

=cut

sub errMissUnitLabel(){ my $self = shift; $self->{"errMissUnitLabel"};  };

####################################################################################################
=pod

=item B<errMissPrintFormat>()

Returns a printf() format string for printing out miss error measurements. 

=cut

sub errMissPrintFormat(){ my $self = shift; $self->{"errMissPrintFormat"} };

####################################################################################################
=pod

=item B<errFALab>()

Returns a free-form label string for the FAError statistic.  The method is required.

=cut

sub errFALab() { my $self = shift; $self->{"errFALab"} }

####################################################################################################
=pod

=item B<errFAUnit>()

Returns the units of the false alarm error metric.  It can be either "B<Prob>" for a probability, or "B<Rate>" for a 
time based rate.

=cut

sub errFAUnit(){ my $self = shift;  $self->{"errFAUnit"} };

####################################################################################################
=pod

=item B<errFAUnitLabel>()

Returns the units lable for the FA error metric.  It can be anything.  The labels is used in the DET curves
to print the units.

=cut

sub errFAUnitLabel(){  my $self = shift; $self->{"errFAUnitLabel"} };

####################################################################################################
=pod

=item B<errFAPrintFormat>()

Returns a printf() format string for printing out false alarm error measurements. 

=cut

sub errFAPrintFormat(){ my $self = shift;  $self->{"errFAPrintFormat"} };


####################################################################################################
=pod

=item B<combLab>()

Returns a free-form label string for the combined performance statistic.

=cut

sub combLab() { my $self = shift; $self->{"combLab"}; }


####################################################################################################
=pod

=item B<combPrintFormat>()

Returns a printf() format string for printing out combined performance statistic. 

=cut
sub combPrintFormat(){ my $self = shift; $self->{"combPrintFormat"} };

####################################################################################################
=pod

=item B<combType>()

Returns a printf() format string for printing out combined type. 

=cut
sub combType(){ my $self = shift; $self->{"optimizationStyle"} };

###################################################################################################
=pod

=item B<errMissLab>($val)

Sets the parameter I<errMissLab> to $val. 

=cut

sub setErrMissLab(){ my $self = shift; $self->{"errMissLab"} = shift; }

#################################################################################################
=pod

=item B<setErrMissUnit>($val)

Sets the parameter I<errMissUnit> to $val

=cut

sub setErrMissUnit(){ my $self = shift; $self->{"errMissUnit"} = shift; }

#################################################################################################
=pod

=item B<setErrMissUnitLabel>($val)

Sets the parameter I<errMissUnitLabel> to $val

=cut

sub setErrMissUnitLabel(){ my $self = shift; $self->{"errMissUnitLabel"} = shift; }

#################################################################################################
=pod

=item B<setErrMissPrintFormat>($val)

Sets the parameter I<errMissPrintFormat> to $val

=cut

sub setErrMissPrintFormat(){ my $self = shift; $self->{"errMissPrintFormat"} = shift; }

#################################################################################################
=pod

=item B<setErrFALab>($val)

Sets the parameter I<errFALab> to $val

=cut

sub setErrFALab(){ my $self = shift; $self->{"errFALab"} = shift; }

#################################################################################################
=pod

=item B<setErrFAUnit>($val)

Sets the parameter I<errFAUnit> to $val

=cut

sub setErrFAUnit(){ my $self = shift; $self->{"errFAUnit"} = shift; }

#################################################################################################
=pod

=item B<setErrFAUnitLabel>($val)

Sets the parameter I<errFAUnitLabel> to $val

=cut

sub setErrFAUnitLabel(){ my $self = shift; $self->{"errFAUnitLabel"} = shift; }

#################################################################################################
=pod

=item B<setErrFAPrintFormat>($val)

Sets the parameter I<errFAPrintFormat> to $val

=cut

sub setErrFAPrintFormat(){ my $self = shift; $self->{"errFAPrintFormat"} = shift; }

#################################################################################################
=pod

=item B<setCombLab>($val)

Sets the parameter I<combLab> to $val

=cut

sub setCombLab(){ my $self = shift; $self->{"combLab"} = shift; }

#################################################################################################
=pod

=item B<setCombPrintFormat>($val)

Sets the parameter I<combPrintFormat> to $val

=cut

sub setCombPrintFormat(){ my $self = shift; $self->{"combPrintFormat"} = shift; }

#################################################################################################
=pod

=item B<setCombTypeToMinimizable>()

Sets the type of the combined function to be minimizable.

=cut

sub setCombTypToMinimizable(){ my $self = shift; $self->{"optimizationStyle"} = "minimizable" }

#################################################################################################
=pod

=item B<setCombTypeToMaximizable>()

Sets the type of the combined function to be maximizable.

=cut

sub setCombTypToMaximizable(){ my $self = shift; $self->{"optimizationStyle"} = "maximizable" }


####################################################################################################
=item B<getParamsStr>()

  Returns a string with containing the constant parameters of the Metric.  The method is required and must
  NOT be changed from the original.

=cut

  sub getParamsStr(){
    my($self,$prefix) = @_;
    my $str = "{ (";
    my @tmp = keys %{ $self->{PARAMS} };
    for (my $i = 0; $i < scalar @tmp; $i++) {
      my $k = $tmp[$i];
      $str .= "$prefix$k => '$self->{PARAMS}->{$k}', ";
    }
    $str .= ") }";
    $str;   
  }

####################################################################################################
=pod

=item B<getParamsKeys>()

Returns an array of parameter keys.

=cut

  sub getParamKeys(){
    my($self) = @_;
    keys %{ $self->{PARAMS} };
  }

####################################################################################################
=pod

=item B<setParamValue>()

Sets the a parameter value for a key.

=cut

  sub setParamValue(){
    my($self, $key, $val) = @_;
    $self->{PARAMS}->{$key} = $val;
  }

####################################################################################################
=pod

=item B<getParamValueExists>()

Returns true if a parameter value exists.

=cut

  sub getParamValueExists(){
    my($self, $key) = @_;
    exists($self->{PARAMS}->{$key});
  }

####################################################################################################
=pod

=item B<getParamValue>()

Returns the value stored in the parameter value.

=cut

  sub getParamValue(){
    my($self, $key) = @_;
    $self->{PARAMS}->{$key};
  }

####################################################################################################
=pod

=item B<getParams>()

Returns the value stored in the parameter value.

=cut

  sub getParams(){
    my($self, $key) = @_;
    $self->{PARAMS};
  }

####################################################################################################
=pod

=item B<cloneForTrial>(I<$trial>)

Returns a new metric object using the parameters in the existing metric object ($self) and the
trial structure.

=cut

sub cloneForTrial(){
  my($self, $trial) = @_;

  ### Make a metric clone
  my $metType = ref($self);
  my $VAR1;
  eval (Dumper($self->getParams()));
  return($metType->new($VAR1, $trial));
}

####################################################################################################
=pod

=item B<getActualDecisionPerformance>()

Returns an array of global miss/fa/comb statistics based on the actual decisions. The contents of the array are:

(MeanActComb, SampleStdDevActComb, MeanMiss, SampleStdDevMiss, MeanFA, SampleStdDevFA)

=cut

  sub getActualDecisionPerformance(){
    my ($self) = @_;
    my $b = "";
    my %blocks = ();

    my @tmp = $self->{TRIALS}->getBlockIDs();
    for (my $i = 0; $i < scalar @tmp; $i++) {
      next if (! $self->{TRIALS}->isBlockEvaluated($tmp[$i]));
      my $b = $tmp[$i];
      $blocks{$b}{MFA} = $self->{TRIALS}->getNumFalseAlarm($b);
      $blocks{$b}{MMISS} = $self->{TRIALS}->getNumMiss($b);
    }
    $self->combBlockSetCalc(\%blocks);         
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
    $self->combCalc($self->errMissBlockCalc($nMiss, $nFa, $block), $self->errFABlockCalc($nMiss, $nFa, $block));
  }

####################################################################################################
=pod

=item B<combCalcWeightedMiss>()

Returns the wieghted MISS value for the combined calculation 

=cut

sub combCalcWeightedMiss(){
  my ($self, $missErr) = @_;
  $missErr;
}


####################################################################################################
=pod

=item B<combCalcWeightedFA>()

Returns the wieghted FA value for the combined calculation 

=cut

sub combCalcWeightedFA(){
  my ($self, $faErr) = @_;
  $faErr;
}

####################################################################################################
=pod

=item B<dumpBlocksStruct>()

PRints the structure used by the Compute functions.

=cut

sub dumpBlocksStruct{
  my ($bs) = @_;
  print getBlocksStructSummary($bs);
}

####################################################################################################
=pod

=item B<getBlocksStructSummary>()

PRints the structure used by the Compute functions.

=cut

sub getBlocksStructSummary{
  my ($bs) = @_;
  my $str = "Block Str:";
  foreach my $blk(keys %$bs){
    $str .= " $blk:[TARGi=$bs->{$blk}->{TARGi}, NONTARGi=$bs->{$blk}->{NONTARGi}]";
  }
  return $str;
}

####################################################################################################
=pod

=item B<getBlocksStructNumRetrieved>()

Returns the number of trials consumed

=cut

sub getBlocksStructNumRetrieved{
  my ($bs) = @_;
  my $numRet = 0;
  foreach my $blk(keys %$bs){
    $numRet += ($bs->{$blk}->{TARGi} + $bs->{$blk}->{NONTARGi}) ;
  }
  return($numRet);
}

#####################################################################################################
#=pod
#
#=item B<getBlocksStructNumRetrievedOfBlock>()
#
#Returns the number of trials consumed for a block
#
#=cut
#
#sub getBlocksStructNumRetrieved{
#  my ($bs, $blk) = @_;
#  return ($bs->{$blk}->{TARGi} + $bs->{$blk}->{NONTARGi}) ;
#}

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
    my ($miss, $fa);
    
    #    my $combAvg = $self->combErrCalc($missAvg, $faAvg);
    #    ($combAvg, undef, $missAvg, $missSSD, $faAvg, $faSSD);
    my @ktmp = keys %$data;
    for (my $ik = 0; $ik < scalar @ktmp; $ik++) {
      my $block = $ktmp[$ik];

      my $luFA = $data->{$block}{MFA};
      my $luMiss = $data->{$block}{MMISS};
      die "Error: Can't calculate errCombBlockSetCalc: key 'MFA' for block '$block' missing" if (! defined($luFA));
      die "Error: Can't calculate errCombBlockSetCalc: key 'MMISS' for block '$block' missing" if (! defined($luMiss));

      
      $miss = $data->{$block}{CACHEDMMISS};
      if (!defined($miss)){       
        $miss = $self->errMissBlockCalc($luMiss, $luFA, $block); 
        $data->{$block}{CACHEDMMISS} = $miss;
      }
      if (defined($miss)) {
        $missSum += $miss;
        $missSumSqr += $miss * $miss;
        $missN++;
      }
      $fa = $data->{$block}{CACHEDMFA};
      if (!defined($fa)){
        $fa = $self->errFABlockCalc($luMiss, $luFA, $block); 
        $data->{$block}{CACHEDMFA} = $fa;
      }
      if (defined($fa)) {
        $faSum += $fa;
        $faSumSqr += $fa * $fa;
        $faN ++;
      }     
      
#      print "   ($block, $miss, $fa)\n";
      ### Try to calculate the SSD of the combined metric IFF the miss and fa errors are allways defined.  If they
      ### are not for one block, then punt!
      if (defined($fa) && defined($miss)) {
        if (defined($combSum)) {
          my $comb = $self->combCalc($miss, $fa);
          $combSum += $comb;
          $combSumSqr += $comb * $comb;
          $combN ++;
        }
      } else {
        $combSum = undef;
      }
    }
#    print "miss=".($missSum/$missN).",$missSum,$missSumSqr,$missN ";
#    print "FA=".(($faN > 0) ? sprintf("%.7f",$faSum/$faN) : "NaN").",$faSum,$faSumSqr,$faN ";
#    print "comb=".(($combN > 0 && defined($combSum)) ? ($combSum/$combN) : "NaN").",".(defined($combSum)?$combSum:"NaN").",$combSumSqr,$combN\n";
    my ($faBSet, $faBSetSSD) = (undef, undef); 
    $faBSet = $faSum / $faN if ($faN > 0);
    $faBSetSSD = MMisc::safe_sqrt((($faN * $faSumSqr) - ($faSum * $faSum)) / ($faN * ($faN - 1))) if ($faN > 1);
  
    my ($missBSet, $missBSetSSD) = (undef, undef); 
    $missBSet = $missSum / $missN if ($missN > 0);
    $missBSetSSD = MMisc::safe_sqrt((($missN * $missSumSqr) - ($missSum * $missSum)) / ($missN * ($missN - 1))) if ($missN > 1);

    my ($combBSet, $combBSetSSD) = (undef, undef);
    $combBSet = $self->combCalc($missBSet, $faBSet);
#  print "sqrt((($combN * $combSumSqr) - ($combSum * $combSum)) / ($combN * ($combN - 1))) if (defined($combSum)  && $combN > 1);\n"
#    if ( (defined($combSum)  && $combN > 1) && ((($combN * $combSumSqr) - ($combSum * $combSum)) / ($combN * ($combN - 1)) < 0));
    $combBSetSSD = MMisc::safe_sqrt((($combN * $combSumSqr) - ($combSum * $combSum)) / ($combN * ($combN - 1))) if (defined($combSum)  && $combN > 1);

    ($combBSet, $combBSetSSD, $missBSet, $missBSetSSD, $faBSet, $faBSetSSD);
  }

####################################################################################################
=pod

=item B<computeCurveArea>(I<$missErr>, I<$faErr>)

Calculates the area for the curve.  The type can be ABOVE the curve (for a Pmiss, PFA curve) or BELOW the curve (for am ROC curve).  
The measure is always called AreaUnderTheCurve: the type determines how the MMFA value is used. The value returned has a range from 
0 to 1.

=cut

sub computeCurveArea(){

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
  if (defined($missErr) && defined($faErr)) {
      ($self->combCalcWeightedMiss($missErr) + $self->combCalcWeightedFA($faErr));
  } else {
    undef;
  }
}


####################################################################################################
=pod

=item B<setPerformGlobalMeasure>(I<$measureName>, I<$boolSet>)

Sets the flag to calculate and report the global measure I<$MeasureName>.

=cut

sub setPerformGlobalMeasure(){
  my ($self, $measureName, $bool) = @_;
  my $regex = "(AP|APP|APpct|APPpct)";
  
  if ($measureName !~ /^${regex}$/){
    MMisc::warn_print("Global Measure '$measureName' not defined, only '$regex'.  Skipping") ;
    return;
  }
    
  if ($bool =~ /^true$/i){
    my @mlist = grep { $_ eq $measureName} @{ $self->{globalMeasures} };
    push (@{ $self->{globalMeasures} }, $measureName)  if (@mlist == 0);
  } elsif ($bool =~ /^false$/i){
    my @mlist = grep { $_ eq $measureName} @{ $self->{globalMeasures} };
    if (@mlist != 0){
      $self->{globalMeasures} = grep { $_ ne $measureName} @{ $self->{globalMeasures} };
    }
  } else {
    MMisc::warn_print("Global Measure '$measureName' value $bool does not match (true|false).  Skipping.") 
  }
}

####################################################################################################
=pod

=item B<getGlobalMeasures>()

Returns the list of global measures.

=cut

sub getGlobalMeasures{
  my ($self) = @_;
  
  return(exists($self->{globalMeasures}) ? $self->{globalMeasures} : [()]);
}


####################################################################################################
=pod

=item B<getDefaultPlotOptions>()

Returns a pointer to a hash of default plot options.

=cut

sub getDefaultPlotOptions{
  my ($self) = @_;
  
  return(exists($self->{defaultPlotOptions}) ? $self->{defaultPlotOptions} : undef)
}

####################################################################################################
=pod

=item B<testActualDecisionPerformance>(I<$expArr, I<$printPrefix>)

Compares the expected actual decision performance to the computed
version C<@$expArr>.  C<$printPrefix> is prepended to any printouts.

=cut
 
sub testActualDecisionPerformance{
  my ($self, $act, $pre) = @_;
  my (@compAct) = $self->getActualDecisionPerformance();

  print "${pre}Checking calculation of the Actual Decision Performance points...";
  return "\nError: Number of Actual point valuesnot correct.  Expected ".scalar(@$act)." != ".scalar(@compAct)."\n" 
    if (@$act != @compAct);
  print "  Ok\n";
  print "${pre}  Checking points...";
  for (my $value=0; $value < @$act; $value++){
    if (! defined($act->[$value])){
      return "\nError: Actual point $value computed to not be undefined but should be" if (defined($compAct[$value]));
    } else {
      #print "if (abs($act->[$value] - ".sprintf("%.5f",$compAct[$value])." > 0.00001);\n";
      return "\nError: Actual point $value expected $act->[$value] but was ".sprintf("%.4f",$compAct[$value])
	if (abs($act->[$value] - sprintf("%.5f",$compAct[$value])) > 0.00001);
    }
  }    
  print "  Ok\n";
  return "ok";
}


1;
