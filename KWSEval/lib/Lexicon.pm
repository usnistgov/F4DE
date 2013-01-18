package Lexicon;

use TranscriptHolder;
@ISA = qw(TranscriptHolder);

use MMisc;

use strict;
use Encode;

sub new {
  my $class = shift;
  my ($lex_fn, $encoding, $language, $compare_normalize) = @_;

  my $self = new TranscriptHolder();
  $self->{terms} => {};
  $self->setEncoding($encoding); #set encoding here?
  $self->setLanguage($language);
  $self->setCompareNormalize($compare_normalize) unless MMisc::is_blank($compare_normalize);

  bless $self;
  #set parser
  $self->{parser} = $self->__default_parser();
  $self->{parser} = $self->__romanized_parser() 
    if $language =~ /^pashto$/i ||
      $language =~ /^Cantonese$/i;

  $self->__build_from_file($lex_fn, $encoding) if $lex_fn;

  return $self;
}

sub __build_from_file {
  my ($self, $lex_fn) = @_;

  open LEXICON, $lex_fn or MMisc::error_quit("Cannot open lexicon '$lex_fn'");
  binmode LEXICON, $self->getPerlEncodingString() if $self->getPerlEncodingString();
  while(<LEXICON>) {
    next if /^;/;
    chomp;
    &{ $self->{parser} }($_);
  }
  close LEXICON;
}

## parsers
sub __default_parser {
  my $self = shift;
  return sub {
    my $row = shift;
    my ($term, $phonemic) = split '\t', $row;
    push @{ $self->{terms}{$term}{phonemics} }, $phonemic;
  }
}

sub __romanized_parser {
  my $self = shift;
  return sub {
    my $row = shift;
    my ($term, $romanized, $phonemic) = split '\t', $row;
    push @{ $self->{terms}{$term}{phonemics} }, $phonemic;
    $self->{terms}{$term}{romanized} = $romanized;
  }
}
##

## accessors
sub get_phonemics {
  my ($self, $kw_text) = @_;
  return $self->{terms}{$kw_text}{phonemics};
}

1;
