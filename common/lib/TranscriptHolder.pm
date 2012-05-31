# F4DE
# TranscriptHolder.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
#
# F4DE is an experimental system.  
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
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package TranscriptHolder;

use MErrorH;
@ISA = qw(MErrorH);

use strict;
use Data::Dumper;
use Encode;
use encoding 'euc-cn';
use encoding 'utf8';
use MMisc;

=pod

=head1 NAME

common/lib/TranscriptHolder - a set of methods to handle transcript strigns

=head1 SYNOPSIS

This object contains inherited methods for any object that contains transcript objects that can be 
in a specific encoding.
=pod

=head1 DESCRIPTION

=head2 METHODS

=over 4

=cut

sub new {
    my ($class) = @_;

    my $self = new MErrorH('TranscriptHolder');

    $self->{"COMPARENORMALIZE"} = "";
    $self->{"ENCODING"} = "";
    $self->{"LANGUAGE"} = "";
 
    bless ($self, $class);
    return($self);
}

sub setCompareNormalize{
    my ($self, $type) = @_;

    if (!defined($type) || $type !~ /^(lowercase|)$/){
       $self->set_errormsg( "Error: setCompareNormalize failed because of unknown normalization /$type/");
       return 0;
    }

    $self->{COMPARENORMALIZE} = $type;

    return 1;
}

sub getCompareNormalize{
    my ($self, $type) = @_;

    return($self->{COMPARENORMALIZE});
}

sub setLanguage{
    my ($self, $type) = @_;

    $self->{LANGUAGE} = $type;
    return 1;
}

sub getLanguage
{
  my ($self) = @_;
  
  return ($self->{LANGUAGE});
}

sub setEncoding{
    my ($self, $type) = @_;

    if (!defined($type) || $type !~ /^(UTF-8|)$/){
       $self->set_errormsg("Error: setCompareNormalize failed because of unknown encoding /$type/");
       return 0;
    }
    $self->{ENCODING} = $type;
    return 1;
}

sub getEncoding
{
  my ($self) = @_;
  
  return ($self->{ENCODING});
}

sub getPerlEncodingString
{
  my ($self) = @_;
  
  return ("utf8") if ($self->{ENCODING} eq "UTF-8");
  return ($self->{ENCODING});
}

sub normalizeTerm 
{
  my ($self, $term) = @_;
  $term = lc $term if ($self->{COMPARENORMALIZE} eq "lowercase");
  return $term;
}

1;
