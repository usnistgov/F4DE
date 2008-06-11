# MetricFuncs.pm
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
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package MetricFuncs;

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

####################################################################################################
=item B<isCompatible>(I<$metric>)

Tests to see if the metrics are compatible, meaning that both metrics have the same
parameters and values for the parameters.

=cut

sub isCompatible(){
    my ($self, $met2) = @_;
    
    return 0 if (ref($self) ne ref($met2));
    
    foreach my $k(keys %{ $self->{PARAMS} }){
        return 0 if (! exists($met2->{PARAMS}->{$k}));
        return 0 if ($self->{PARAMS}->{$k} ne $met2->{PARAMS}->{$k});
    }
    foreach my $k(keys %{ $met2->{PARAMS} }){
        return 0 if (! exists($self->{PARAMS}->{$k}));
        return 0 if ($self->{PARAMS}->{$k} ne $met2->{PARAMS}->{$k});
    }
    return 1;
}

####################################################################################################
=item B<getParamsStr>()

Returns a string with containing the constant parameters of the Metric.  The method is required and must
NOT be changed from the original.

=cut

sub getParamsStr(){
    my($self,$prefix) = @_;
    my $str = "{ (";
    foreach my $k(keys %{ $self->{PARAMS} }){
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

=item B<getActualDecisionPerformance>()

Returns an array of global miss/fa/comb statistics based on the actual decisions.

=cut

sub getActualDecisionPerformance(){
   	my ($self) = @_;
	my $b;
	my %blocks = ();
	
	foreach $b ($self->{TRIALS}->getBlockIDs()){
    	$blocks{$b}{MFA} = $self->{TRIALS}->getNumFalseAlarm($b);
    	$blocks{$b}{MMISS} = $self->{TRIALS}->getNumMiss($b);
    }
	$self->combBlockSetCalc(\%blocks);         
}

1;
