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

package MetricTestStub;
use strict;
use Data::Dumper;
 
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

    return "Error: parameter 'ValueV' not defined"     if (! exists($self->{PARAMS}->{ValueV}));
    return "Error: parameter 'ValueC' not defined"     if (! exists($self->{PARAMS}->{ValueC}));
    return "Error: parameter 'ProbOfTerm' not defined" if (! exists($self->{PARAMS}->{ProbOfTerm}));

    #    print Dumper($self->{TRIALPARAMS});
    return "Error: trials parameter 'TOTALTRIALS' does not exist" if (! exists($self->{TRIALPARAMS}->{TOTALTRIALS}));

    $self->{PARAMS}->{BETA} = $self->{PARAMS}->{ValueC} / $self->{PARAMS}->{ValueV} * 
      ((1 / $self->{PARAMS}->{ProbOfTerm}) - 1);

    bless $self;
    return $self;
  }

sub getParamsStr(){
  my($self) = @_;
  my $str = "{ (";
  foreach my $k (keys %{ $self->{PARAMS} }) {
    $str .= "'$k' => '$self->{PARAMS}->{$k}', ";
  }
  $str .= ') }';
  $str;   
}


sub errMissLab(){ "PMiss"; }
sub errMissUnit(){ "Prob" };
sub errMissUnitLabel(){ "%" };
sub errMissBlockCalc(){
  my ($self, $nMiss, $block) = @_;
  my $NTarg =  $self->{TRIALS}->getNumTarg($block);
  
  ($NTarg > 0) ? $nMiss / $NTarg : undef;
}
sub errMissBlockSetCalc(){
  my ($self, $data) = @_;
  #### Data is a hass ref with the primary key being a block and for each block there t
  #### MUST be a key 'MMISS' as a secondary key 

  my ($sum, $sumsqr, $n) = (0, 0);
  foreach my $block (keys %$data) {
    my $lu = $data->{$block}{MMISS};
    die "Error: Can't calculate errMissBlockSetCalc: key 'MMISS' for block '$block' missing" if (! defined($lu));

    if ($self->{TRIALS}->getNumTarg($block) > 0) {
      my $miss = $self->errMissBlockCalc($lu, $block);
      $sum += $miss;
      $sumsqr += $miss * $miss;
      $n ++;
    }
  }
  die "Error: Can't calculate errMissBlockSetCalc: zero blocks" if ($n == 0);
  ($sum / $n, sqrt((($n * $sumsqr) - ($sum * $sum)) / ($n * ($n - 1))));
}

sub errFALab() { "PFA"; }
sub errFAUnit(){ "Prob" };
sub errFAUnitLabel(){ "%" };
sub errFABlockCalc(){
  my ($self, $nFa, $block) = @_;
  my $NNonTargTrials = (defined($self->{TRIALPARAMS}->{TOTALTRIALS}) ? 
                        $self->{TRIALPARAMS}->{TOTALTRIALS} - $self->{TRIALS}->getNumTarg($block) : 
                        $self->{TRIALS}->getNumNonTarg($block));
  $nFa / $NNonTargTrials;
}
sub errFABlockSetCalc(){
  my ($self, $data) = @_;
  #### Data is a hass ref with the primary key being a block and for each block there t
  #### MUST be a key 'MFA' as a secondary key }
  my ($sum, $sumsqr, $n) = (0, 0, 0);
  foreach my $block (keys %$data) {
    my $lu = $data->{$block}{MFA};
    my $Ntarg =  $self->{TRIALS}->getNumTarg($block);
    die "Error: Can't calculate errFABlockSetCalc: key '".$self->errFALab()."' for block '$block' missing" if (! defined($lu));
            
    next if ($self->{TRIALS}->getNumTarg($block) == 0);
    my $fa = $self->errFABlockCalc($lu, $block);
    $sum += $fa;
    $sumsqr += $fa * $fa;
    $n ++;
  }
  die "Error: Can't calculate errFABlockSetCalc: zero blocks" if ($n == 0);
  ($sum / $n, sqrt((($n * $sumsqr) - ($sum * $sum)) / ($n * ($n - 1))));
}

### Either 'maximizable' or 'minimizable'
sub combType() { "maximizable"; }
sub combLab() { "Value"; }
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

=item B<MISSForGivenComb>(I<$comb, I<$faErr>)

Calculates the value of the Miss statistic for a given combined measure and the FA value.  This is 
a permutation of the combined formula to solve for the Miss value. This method uses the constants 
defined during object creation.  If either C<$comb> or 
C<$faErr> is undefined, then the combined calculation returns C<undef>,

=cut

sub combPmissForGivenCost(){
  my ($self, $comb, $faErr) = @_;
  if (defined($comb) && defined($faErr)) {
    - ($comb - 1 + $self->{PARAMS}->{BETA} * $faErr);
  } else {
    undef;
  }
}

sub combBlockCalc(){
  my ($self, $nMiss, $nFa, $block) = @_;
  $self->combErrCalc($self->errMissCalc($nMiss, $block), $self->errFACalc($nFa, $block));
}
sub combBlockSetCalc(){
  my ($self, $data) = @_;
  #### Data is a hass ref with the primary key being a block and for each block there 
  #### MUST be a 2 secondary keys, 'MMISS' and 'MFA'
  my ($missAvg, $missSSD) = $self->errMissBlockSetCalc($data);
  my ($faAvg,   $faSSD)   = $self->errFABlockSetCalc($data);    
  #    my $combAvg = $self->combErrCalc($missAvg, $faAvg);
  #    ($combAvg, undef, $missAvg, $missSSD, $faAvg, $faSSD);

  my ($sum, $sumsqr, $n) = (0, 0, 0);
  foreach my $block (keys %$data) {
    my $luFA = $data->{$block}{MFA};
    my $luMiss = $data->{$block}{MMISS};
    die "Error: Can't calculate errCombBlockSetCalc: key 'MFA' for block '$block' missing" if (! defined($luFA));
    die "Error: Can't calculate errCombBlockSetCalc: key 'MMISS' for block '$block' missing" if (! defined($luMiss));

    next if ($self->{TRIALS}->getNumTarg($block) == 0);

    my $miss = $self->errMissBlockCalc($luMiss, $block); 
    my $fa = $self->errFABlockCalc($luFA, $block); 

    $sum += $self->combCalc($miss, $fa);
    $sumsqr += $self->combCalc($miss, $fa) * $self->combCalc($miss, $fa);
    $n ++;
  }
  die "Error: Can't calculate errFABlockSetCalc: zero blocks" if ($n == 0);
  ($sum / $n,
   sqrt((($n * $sumsqr) - ($sum * $sum)) / ($n * ($n - 1))),
   $missAvg, $missSSD, $faAvg, $faSSD);
}

sub isCompatible(){
  1;
}

1;
