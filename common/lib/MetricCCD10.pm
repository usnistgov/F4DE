# F4DE
# MetricCBCD10.pm
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

package MetricCBCD10;

use MetricFuncs;
use MetricTV08;
@ISA = qw(MetricFuncs MetricTV08);

use strict;

use Data::Dumper;
use MMisc;

my @metric_params = ("CostMiss", "CostFA", "Rtarget");

use TrialsCBCD10;
my @trials_params = TrialsCBCD09::getParamsList();

sub getParamsList { return(@metric_params); }
sub getTrialsParamsList { return(@trials_params); }

=pod
=head1 NAME

common/lib/MetricCBCD10 - Compiled 2-class detection metrics for TRECVID Content Based Copy Detection Event Detection

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

sub new
  {
    my ($class, $parameters, $trial) = @_;

    my $self = MetricTV08->new($parameters, $trial);

    bless($self, $class);

    $self->setErrFAUnitLabel("Events/(Hour*Hour)");

    return $self;
  }

sub unitTest(){
  my ($dir) = ".";

  print "Test MetricCBCD10...".(defined($dir) ? " Dir=/$dir/" : "(Skipping DET Curve Generation)")."\n";

  my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );

################################### A do nothing system
### Pmiss == 1  - 10 misses
### PFa == 0    - 0  FA  
### Cost == 1

  my $DNtrial = new TrialsCBCD10("Term Detection", "Term", "Occurrence", { () });
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
     
  my $trial = new TrialsFuncs("Term Detection", "Term", "Occurrence", { () });
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
  my $met = new MetricNormLinearCostFunct({ ('CostFA' => 1, 'CostMiss' => 10, 'Ptarg' => 0.01 ) }, $trial),
  my $DNmet = new MetricNormLinearCostFunct({ ('CostFA' => 1, 'CostMiss' => 10, 'Ptarg' => 0.01 ) }, $DNtrial);

  ##############################################################################################
  print "  Testing Calculations .. ";
  my ($exp, $ret);
  $exp = 1; $ret = $met->combCalc(1.0, 0.0); 
  die "\nError: Cost for Pmiss=1.0, Pfa=0.0 was = $ret NOT $exp\n " if (abs($ret - $exp) > 0.0001);
  $exp = 9.9; $ret = $met->combCalc(0.0, 1.0); 
  die "\nError: Cost for Pmiss=0.0, Pfa=1.0 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  $exp = 0.17425; $ret = $met->combCalc(0.1, 0.0075); 
  die "\nError: Cost for Pmiss=0.1, Pfa=0.0075 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);

  ## Inverse calculations for MISS
  $exp = 0.1; $ret = $met->MISSForGivenComb(0.17425, 0.0075); 
  die "\nError: MISS for Cost=0.8425, Pfa=0.0075 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  $exp = 1.0; $ret = $met->MISSForGivenComb(1.0, 0.0); 
  die "\nError: MISS for Cost=1.0, Pfa=0.0 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  
  ## Inverse calculations for FA
  $exp = 0.0075; $ret = $met->FAForGivenComb(0.17425, 0.1); 
  die "\nError: FA for Cost=0.8425, Pmiss=0.1 was = $ret NOT $exp\n" if (abs($ret - $exp) > 0.0001);
  $exp = 1.0; $ret = $met->FAForGivenComb(9.9, 0.0); 
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
  
    print $ds->renderAsTxt("$dir/MNLCF.unitTest.det", 1, 1, $options, "");                                                                     
  }
  printf "Done\n";
  ###############################################################################################
}

1;
