# KWSEval
# TermListRecord.pm
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

package TermListRecord;
use strict;

sub new
{
    my $class = shift;
    my $self = {};
    
    my $hashattr = shift;
    
    foreach my $attributename (sort keys %{ $hashattr })
    {
        $self->{$attributename} = $hashattr->{$attributename};
    }

    #$self->{TERMID} = shift;
    #$self->{TEXT} = shift;
    
    bless $self;
    return $self;
}

sub setAttrValue
{
    my $self = shift;
    my $attr = shift;
    my $val = shift;

    $self->{$attr} = $val;
}

sub toString
{
    my $self = shift;
    my $s = "TermListRecord: ".
    " TERMID=".$self->{TERMID}.
	" TEXT=".$self->{TEXT};
}

1;
