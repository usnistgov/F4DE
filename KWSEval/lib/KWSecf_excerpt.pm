# KWSEval
# KWSecf_excerpt.pm
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. KWSEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

package KWSecf_excerpt;
use strict;

sub new
{
    my $class = shift;
    my $self = {};

    $self->{AUDIO_FILENAME} = shift;
    $self->{CHANNEL} = shift;
    $self->{TBEG} = shift;
    $self->{DUR} = shift;
    $self->{TEND} = sprintf("%.4f", $self->{TBEG} + $self->{DUR});
    $self->{LANGUAGE} = shift;
    $self->{SOURCE_TYPE} = shift;    
    $self->{FILE} = "";
    
    if($self->{AUDIO_FILENAME} =~ /.*\/(.*?[^\/]*)\.([^\.]+)$/)
    {
        $self->{FILE} = $1;
    } elsif($self->{AUDIO_FILENAME} =~ /(.*)\.([^\.]+)$/) {
        $self->{FILE} = $1;
    }
    
    bless $self;
    return $self;
}

sub toString
{
    my $self = shift;
    my $s = "excerpt: ".
    " AUDIO_FILENAME=".$self->{AUDIO_FILENAME}.
    " FILE=".$self->{FILE}.
	" CHANNEL=".$self->{CHANNEL}.
	" TBEG=".$self->{TBEG}.
	" TEND=".$self->{TEND}.
	" DUR=".$self->{DUR}.
	" LANGUAGE=".$self->{LANGUAGE}.
	" SOURCE_TYPE=".$self->{SOURCE_TYPE};
}

1;
