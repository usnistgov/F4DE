#!/usr/bin/env perl -w

use strict;

use encoding 'euc-cn';
use encoding 'utf8';

# Check we have every module (perl wise)

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);
#

use Getopt::Long;
use Data::Dumper;
use MMisc;
use Encode;
use TermList;
use TermListRecord;

my $outfilename = "";
my @annotFiles = ();
my @annotScripts = ();
my $inTlist = "";
my $ngram = 0;
my $character = 0;

my $TermList = undef;

#Options
#Need flags for adding programmatically generated annots, (i.e. NGram)
GetOptions
(
 'in-term-list=s' => \$inTlist,
 'annot-files=s@' => \@annotFiles,
 'out-file-name=s' => \$outfilename,
 'n-gram' => \$ngram,
 'character' => \$character,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required options
MMisc::error_quit("in-term-list required.") if ($inTlist eq "");
MMisc::error_quit("out-file-name required.") if ($outfilename eq "");

#Load TermList
$TermList = new TermList($inTlist);

my %annotations = ();
#Build file annots
foreach my $file (@annotFiles) {
  open(AFILE, $file) or MMisc::error_quit("Unable to open file '$file'");
  binmode(AFILE, $TermList->getPerlEncodingString()) if ($TermList->{ENCODING} ne "");

  while (<AFILE>) {
    chomp;
    my ($term, $attr, $val) = split(/,/, $_);
    $term =~ s/^\s+//; $term =~ s/\s+$//;
    $attr =~ s/^\s+//; $attr =~ s/\s+$//;
    $val =~ s/^\s+//; $val =~ s/\s+$//;
    $annotations{$term}{$attr} = $val;
  }
  close AFILE;
}

#Run annotation functions
foreach my $termid (keys %{ $TermList->{TERMS} }) {
  my $text = $TermList->{TERMS}{$termid}{TEXT};
  if ($character != 0) {
    $annotations{$text}{"Characters"} = &charactersOfTerm($text);
  }
  if ($ngram != 0) {
    $annotations{$text}{"NGram Order"} = &ngramOfTerm($text);
  }
}

#Add Annotations
foreach my $termid (keys %{ $TermList->{TERMS} }) {
  foreach my $key (keys %{ $annotations{$TermList->{TERMS}{$termid}{TEXT}} }) {
    $TermList->{TERMS}{$termid}->setAttrValue($key, $annotations{$TermList->{TERMS}{$termid}{TEXT}}{$key})
  }
}

#Dump TermList
$TermList->{TERMLIST_FILENAME} = $outfilename;
$TermList->saveFile();

MMisc::ok_quit();

sub charactersOfTerm 
{
  my ($term) = @_;
  
  my @chars = split(//, $term);
  scalar(@chars);
}

sub ngramOfTerm
{
  my ($term) = @_;

  my @words = split(/\s/, $term);
  scalar(@words);
}
