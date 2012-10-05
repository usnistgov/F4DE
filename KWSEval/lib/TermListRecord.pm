# KWSEval
# TermListRecord.pm
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

package TermListRecord;
use strict;
use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = {};
    
    my $hashattr = shift;
    
    foreach my $attributename (sort keys %{ $hashattr })
    {
        $self->{$attributename} = $hashattr->{$attributename};
    }

    ## Add the character separated term text
#    $self->{CHARSPLITTEXT} = join(" ", split("", $self->{TEXT}));
#    $self->{CHARSPLITTEXT} =~ s/\s+/ /g; 
    
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

sub getAttrValue
{
    my $self = shift;
    my $attr = shift;

    return (exists($self->{$attr}) ? $self->{$attr} : undef);
}

sub deleteAttr
{
    my $self = shift;
    my $attr = shift;

    if (exists($self->{$attr})){
      delete($self->{$attr})
    }
}

sub getAttrs
{
    my $self = shift;

    return (keys %$self);
}

sub toString
{
    my $self = shift;
    my $s = "TermListRecord: ".
    " TERMID=".$self->{TERMID}.
	" TEXT=".$self->{TEXT};
}

sub toPerl
{
    my $self = shift;
    my $save = $Data::Dumper::Indent;
    $Data::Dumper::Indent = 0;
    my $s = Dumper($self);
    $Data::Dumper::Indent = $save;
    return $s;
}

sub toStringFull
{
    my $self = shift;
    my $s = "TermListRecord: ".
    " TERMID=".$self->{TERMID}.
	" TEXT=".$self->{TEXT};

    foreach my $termattrname(sort keys %$self){
      next if( ($termattrname eq "TERMID") || ($termattrname eq "TEXT") );
      $s .= " $termattrname=".$self->{$termattrname};
    }
  return $s;
}

1;
