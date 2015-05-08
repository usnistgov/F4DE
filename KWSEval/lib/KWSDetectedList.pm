# KWSEval
#
# $Id$
#
# KWSDetectedList.pm
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

package KWSDetectedList;
use strict;
use KWSTermRecord;
 
sub new
{
    my $class = shift;
    my $self = {};

    $self->{TERMID} = shift;
    $self->{SEARCH_TIME} = shift;
    $self->{OOV_TERM_COUNT} = shift;
    $self->{TERMS} = ();
	
    bless $self;    
    return $self;
}

sub toString
{
    my ($self) = @_;

    print "Dump of KWSDetectedList\n";
    print "   TermID: " . $self->{TERMID} . "\n";
    print "   Term search time: " . $self->{SEARCH_TIME} . "\n";
    print "   oov term count: " . $self->{OOV_TERM_COUNT} . "\n";
    print "   Terms:\n";
    
    if($self->{TERMS})
    {
        for (my $i=0; $i<@{ $self->{TERMS} }; $i++)
        {
            print "    ".$self->{TERMS}[$i]->toString()."\n";
        }
    }
}

1;

