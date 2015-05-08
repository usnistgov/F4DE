# F4DE 
#
# $Id$
#
# OFunct.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
#
# KWSEval is an experimental system.  
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

package OFunct;
use strict;
use MMisc;
use Data::Dumper;
use Math::Trig;

# This object evaluates a weighted object function returning the Pvalue of the test
sub new
{
  my ($class, $expectedDistribution) = @_;
  
  my $self = {
    EXPECTED => $expectedDistribution,
    };
	
  bless($self);
  return $self;
}

sub unitTest{
  my $ofunc = new OFunct([(12.267, 11.223, 13.659, 13.920, 12.180, 15.660, 8.091)]);
  die "Error:" if (abs($ofunc->compare([(12, 10, 12, 18, 10, 20, 5)], 0, "chi") - 4.310) > 0.001);
  die "Error:" if (abs($ofunc->compare([(12, 10, 12, 18, 10, 20, 5)], 1, "chi") - 0.049) > 0.001);

exit;
    
  $ofunc = new OFunct([(1, 0)]);
  print Dumper($ofunc);
  $ofunc->compare([(1, 0)], 0);
  $ofunc->compare([(0, 1)], 0);
  $ofunc->compare([(1, 1)], 0);
}


sub compare{
  my ($self, $observedDist, $asUnity, $metric) = @_;
  my $vb = 0;
    
  die "Error: Expected count () != test count ()" if (@{ $self->{EXPECTED} } != @$observedDist);

  my $exp = ($asUnity ? _toUnity($self->{EXPECTED}) : $self->{EXPECTED} );
  my $obs = ($asUnity ? _toUnity($observedDist) : $observedDist);
  print "asUnity=$asUnity\n" if ($vb);
  print "  Exp=(".join(",",@$exp).")\n" if ($vb);
  print "  Obs=(".join(",",@$obs).")\n" if ($vb);
  if (0){
    ### Cosine similarity
    my $sumExO = 0;
    my $sumE = 0;
    my $sumO = 0;
    for (my $i=0; $i<@$exp; $i++){
      $sumExO += $obs->[$i] * $exp->[$i];
      $sumE   += $exp->[$i] * $exp->[$i];
      $sumO   += $obs->[$i] * $obs->[$i];
    }
    print "  sumExO = $sumExO\n";
    print "  sumE = $sumE\n";
    print "  sumO = $sumO\n";
    my $theta = $sumExO / (sqrt($sumE) * sqrt($sumO));
    my $sim = cos($theta);
    my $simAngle = 1 - (acos($sim) / 3.14159);
    print "  Theta=$theta sim=$sim simAngle=$simAngle\n";
  }
  if ($metric eq "chi"){
   ### Chi squared test
    my $sum = 0;
    for (my $i=0; $i<@$exp; $i++){
      $sum += (($obs->[$i] - $exp->[$i]) * ($obs->[$i] - $exp->[$i])) / $exp->[$i]
    }
    print "Chi^2 = $sum\n" if ($vb);
    return($sum);
  } else {
    die;
  }
 }

### A class method
sub _toUnity{
  my ($data) = @_;
  my @out = ();
  
  my $sum = 0;
  foreach $_(@$data){ $sum += $_; }
  foreach $_(@$data){ push @out, $_ / $sum}
  \@out;  
}


1;

