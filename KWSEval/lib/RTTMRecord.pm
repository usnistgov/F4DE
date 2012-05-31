# KWSEval
# RTTMRecord.pm
# Author: Jerome Ajot
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

package RTTMRecord;
use strict;

sub new
{
    my $class = shift;
    my $self = {};

    $self->{TYPE} = shift;
    $self->{FILE} = shift;
    $self->{CHAN} = shift;
    $self->{BT} = shift;
    $self->{DUR} = shift;
    $self->{ET} = sprintf("%.4f", $self->{BT} + $self->{DUR});
    $self->{MID} = sprintf("%.4f", $self->{BT} + ($self->{DUR} / 2.0));
    $self->{TOKEN} = shift;
    $self->{STYPE} = shift;
    $self->{SPKR} = shift;
    $self->{CONF} = shift;
    #ref to next record
    $self->{NEXT} = undef;
    
    bless $self;
    return $self;
}

sub toString
{
    my $self = shift;
    my $s = "RTTM: ".
    " TYPE=".$self->{TYPE}.
	" FILE=".$self->{FILE}.
	" CHAN=".$self->{CHAN}.
	" BT=".$self->{BT}.
	" MID=".$self->{MID}.
	" ET=".$self->{ET}.
	" TOKEN=".$self->{TOKEN}.
	" STYPE=".$self->{STYPE}.
	" SPKR=".$self->{SPKR}.
	" CONF=".$self->{CONF};
}

1;
