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

use TrialsCBCD09;
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

1;
