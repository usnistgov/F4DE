# F4DE
#
# $Id$
#
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

    if (!defined($type) || ($type !~ /^(UTF-8|)$/ && $type !~ /^gb2312$/i)){
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
  
  return (":utf8") if ($self->{ENCODING} eq "UTF-8");
  return (":gb2312-raw") if ($self->{ENCODING} =~ /^gb2312$/i);
  return ($self->{ENCODING});
}

sub normalizeTerm 
{
  my ($self, $term) = @_;
  $term = lc $term if ($self->{COMPARENORMALIZE} eq "lowercase");
  return $term;
}

sub charSplitText
{
  my ($self, $text, $notASCII, $deleteHyphens) = @_;
  
  my $modText = $text;
  ## Do the split
  $modText = join(" ", split("",$modText));
  ## Handle the ASCII
  if ($notASCII){
#    $modText =~ s/([a-z])\s+([a-z])/$1$2/g;
#    $modText =~ s/([a-z])\s+([a-z])/$1$2/g;
    $modText =~ s/([\001-\177])\s+([\001-\177])/$1$2/g;
    $modText =~ s/([\001-\177])\s+([\001-\177])/$1$2/g;
  }
  ## Handle hyphens
  $modText =~ s/-/ /g if ($deleteHyphens);
  ### Cleanup spaces
  $modText =~ s/\s+/ /g;
  $modText =~ s/^\s+//;
  $modText =~ s/\s+$//;
  return $modText;
}

sub unitTestCharSplitText
{
  my ($th, $orig, $exp, $notAscii, $deleteHyphen) = @_;
  
  my $res = $th->charSplitText($orig, $notAscii, $deleteHyphen);
  
  if ($res ne $exp){
    print "\nError: charSplitText($orig, $notAscii, $deleteHyphen) = $res but expected $exp\n";
    return 1;
  }
  return ;
}

sub unitTest
{
  my $th = new TranscriptHolder();
  $th->setEncoding("UTF-8");
  my $err = 0;
  
  print "Testing Transcript Holder\n";
  
  ### NO OPTIONS
  print "  No options...   ";
  $err += unitTestCharSplitText($th, "a", "a", 0, 0);
  $err += unitTestCharSplitText($th, "a ", "a", 0, 0);
  $err += unitTestCharSplitText($th, " a", "a", 0, 0);
  $err += unitTestCharSplitText($th, "ab", "a b", 0, 0);
  $err += unitTestCharSplitText($th, "a b", "a b", 0, 0);
  $err += unitTestCharSplitText($th, "abc", "a b c", 0, 0);

  $err += unitTestCharSplitText($th, "对", "对", 0, 0);
  $err += unitTestCharSplitText($th, "对 ", "对", 0, 0);
  $err += unitTestCharSplitText($th, " 对", "对", 0, 0);
  $err += unitTestCharSplitText($th, "对症", "对 症", 0, 0);
  $err += unitTestCharSplitText($th, "对 症", "对 症", 0, 0);
  $err += unitTestCharSplitText($th, "对症下", "对 症 下", 0, 0);

  $err += unitTestCharSplitText($th, "a对b症c下d", "a 对 b 症 c 下 d", 0, 0);
  $err += unitTestCharSplitText($th, "a对症c下d", "a 对 症 c 下 d", 0, 0);
  $err += unitTestCharSplitText($th, "a对症下d", "a 对 症 下 d", 0, 0);

  $err += unitTestCharSplitText($th, "ab症c下d", "a b 症 c 下 d", 0, 0);
  $err += unitTestCharSplitText($th, "abc下d", "a b c 下 d", 0, 0);

  $err += unitTestCharSplitText($th, "a-b", "a - b", 0, 0);
  $err += unitTestCharSplitText($th, "a-b-", "a - b -", 0, 0);
  $err += unitTestCharSplitText($th, "-a-b-", "- a - b -", 0, 0);

  $err += unitTestCharSplitText($th, "对-症", "对 - 症", 0, 0);
  $err += unitTestCharSplitText($th, "对-症-", "对 - 症 -", 0, 0);
  $err += unitTestCharSplitText($th, "-对-症-", "- 对 - 症 -", 0, 0);
  print "\n";
  
  print "  Deleting hyphens...   ";
  ### Testing Delete hypehd
  $err += unitTestCharSplitText($th, "a-b", "a b", 0, 1);
  $err += unitTestCharSplitText($th, "a-b-", "a b", 0, 1);
  $err += unitTestCharSplitText($th, "-a-b-", "a b", 0, 1);

  $err += unitTestCharSplitText($th, "对-症", "对 症", 0, 1);
  $err += unitTestCharSplitText($th, "对-症-", "对 症", 0, 1);
  $err += unitTestCharSplitText($th, "-对-症-", "对 症", 0, 1);
  print "\n";
  
  print "  Not ASCII...   ";
  $err += unitTestCharSplitText($th, "a", "a", 1, 0);
  $err += unitTestCharSplitText($th, "a ", "a", 1, 0);
  $err += unitTestCharSplitText($th, " a", "a", 1, 0);
  $err += unitTestCharSplitText($th, "ab", "ab", 1, 0);
  $err += unitTestCharSplitText($th, "abc", "abc", 1, 0);
  $err += unitTestCharSplitText($th, "abcd", "abcd", 1, 0);

  $err += unitTestCharSplitText($th, "对", "对", 1, 0);
  $err += unitTestCharSplitText($th, "对 ", "对", 1, 0);
  $err += unitTestCharSplitText($th, " 对", "对", 1, 0);
  $err += unitTestCharSplitText($th, "对症", "对 症", 1, 0);
  $err += unitTestCharSplitText($th, "对 症", "对 症", 1, 0);
  $err += unitTestCharSplitText($th, "对症下", "对 症 下", 1, 0);

  $err += unitTestCharSplitText($th, "ab对", "ab 对", 1, 0);
  $err += unitTestCharSplitText($th, "对ab", "对 ab", 1, 0);
  $err += unitTestCharSplitText($th, "a对b", "a 对 b", 1, 0);
  $err += unitTestCharSplitText($th, "ab对ab", "ab 对 ab", 1, 0);
  $err += unitTestCharSplitText($th, "abc对abc", "abc 对 abc", 1, 0);
  $err += unitTestCharSplitText($th, "abcd对abcd", "abcd 对 abcd", 1, 0);
  $err += unitTestCharSplitText($th, "abcd对症abcd", "abcd 对 症 abcd", 1, 0);
    
  print "\n";
  
  print "  Deleting hypehns and Not ASCII...   ";
  $err += unitTestCharSplitText($th, "a", "a", 1, 1);
  $err += unitTestCharSplitText($th, "ab", "ab", 1, 1);
  $err += unitTestCharSplitText($th, "abc", "abc", 1, 1);
  $err += unitTestCharSplitText($th, "abcd", "abcd", 1, 1);
  $err += unitTestCharSplitText($th, "a-b", "a b", 1, 1);
  $err += unitTestCharSplitText($th, "a-b-", "a b", 1, 1);
  $err += unitTestCharSplitText($th, "-a-b-", "a b", 1, 1);
  
  return 1 if ($err > 0);
  print "\nOK\n";
  return 0    
}

1;
