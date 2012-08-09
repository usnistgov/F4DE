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
use RTTMList;

my $outfilename = "";
my @annotFiles = ();
my @annotScripts = ();
my @rttms = ();
my $inTlist = "";
my $ngram = 0;
my $character = 0;
my $csvOutput = undef;
my $TermList = undef;
my $useSplitChars = 0;
my $ReduceDuplicateInfo = 0;
my $makeTextSplitChars = 0;
my $cleanNonEssentialAttributes = 0;

#Options
#Need flags for adding programmatically generated annots, (i.e. NGram)
GetOptions
(
 'in-term-list=s' => \$inTlist,
 'annot-files=s@' => \@annotFiles,
 'out-file-name=s' => \$outfilename,
 'n-gram' => \$ngram,
 'character' => \$character,
 'rttms=s@' => \@rttms,
 'csvOutput' => \$csvOutput,
 'useSplitChars' => \$useSplitChars,
 'makeTextSplitChars' => \$makeTextSplitChars,
 'ReduceDuplicateInfo' => \$ReduceDuplicateInfo,
 'CleanNonEssentialAttributes' => \$cleanNonEssentialAttributes,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required options
MMisc::error_quit("in-term-list required.") if ($inTlist eq "");
MMisc::error_quit("out-file-name required.") if ($outfilename eq "");
MMisc::error_quit("makeTextSplitChars is mutually exclusive will all other edits.") 
  if ($makeTextSplitChars && ($ngram || (@rttms > 0) || $character || (@annotFiles > 0) || $useSplitChars));


#Load TermList
$TermList = new TermList($inTlist);

if ($makeTextSplitChars){
   foreach my $termid (keys %{ $TermList->{TERMS} }) {
     $TermList->{TERMS}{$termid}{TEXT} = $TermList->{TERMS}{$termid}{CHARSPLITTEXT};
   }
}

my %annotations = ();
#Build file annots
foreach my $file (@annotFiles) {
  open(AFILE, $file) or MMisc::error_quit("Unable to open file '$file'");
  binmode(AFILE, $TermList->getPerlEncodingString()) if ($TermList->{ENCODING} ne "");

  while (<AFILE>) {
    chomp;
    my @data = split(/,/,$_);
    my ($term) = shift(@data);
    $term =~ s/^\s+//; $term =~ s/\s+$//;
    while (@data > 0){
      die "Error: Inconsistent attribute value pairs in '$_'"  if (@data < 2);
      my $attr = shift(@data);
      my $val = shift(@data);
  
      $attr =~ s/^\s+//; $attr =~ s/\s+$//;
      $val =~ s/^\s+//; $val =~ s/\s+$//;
      if (! defined($annotations{$term}{$attr})){
        $annotations{$term}{$attr} = $val;
      } else {
        if (! $ReduceDuplicateInfo){
          $annotations{$term}{$attr} .= "|".$val;
        } else {
          my $re = quotemeta($annotations{$term}{$attr});
          $re =~ s:\\\|:|:g;  ### Activates the pipes!!!!
          if ($val !~ /^($re)$/){
            $annotations{$term}{$attr} .= "|".$val;
          }
        }
      }
    }
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
    if (!defined($TermList->{TERMS}{$termid}->getAttrValue($key))){
      $TermList->{TERMS}{$termid}->setAttrValue($key, $annotations{$TermList->{TERMS}{$termid}{TEXT}}{$key});
    } else {
      $TermList->{TERMS}{$termid}->setAttrValue($key, 
                         $TermList->{TERMS}{$termid}->getAttrValue($key) . "|" .
                         $annotations{$TermList->{TERMS}{$termid}{TEXT}}{$key});
    }
  }
}

## Add the counts from the RTTMs
if (@rttms > 0){
  print "Loading RTTMs for analisys\n";
  foreach my $rttm(@rttms){
    print "   Processing $rttm\n";
    my $key = "RefOccurences:$rttm";
    my $quantKey = "QuantizedRefOccurences:$rttm";
    my $rttm = new RTTMList($rttm, $TermList->getLanguage(),
                            $TermList->getCompareNormalize(), $TermList->getEncoding());  
    my @terms = keys %{ $TermList->{TERMS} };
    my $n = 0;
    foreach my $termid (keys %{ $TermList->{TERMS} }) {
      print "      Processing term $termid ".($n++)." of ".scalar(@terms)." ".$TermList->{TERMS}{$termid}->toPerl()."\n";
      my $text;
      if (! $useSplitChars){
        $text = $TermList->{TERMS}{$termid}{TEXT};
      } else {
        $text = $TermList->{TERMS}{$termid}{CHARSPLITTEXT};
      }
      my $out = RTTMList::findTermHashToArray($rttm->findTermOccurrences($text, 0.5));
      foreach my $dat(@$out){
        print "$termid ".$dat->[0]->{FILE}."\n";
      }
      my $n = scalar(@$out);
      my $quantN = $n;
      if ($n >= 1 && $n <= 1) { $quantN = "0001"; }
      elsif ($n >= 2 && $n <= 4) { $quantN = "0002-4"; }
      elsif ($n >= 5 && $n <= 9) { $quantN = "0005-9"; }
      elsif ($n >= 10 && $n <= 19) { $quantN = "0010-19"; }
      elsif ($n >= 20 && $n <= 49) { $quantN = "0020-49"; }
      elsif ($n >= 50 && $n <= 99) { $quantN = "0050-99"; }
      elsif ($n >= 100 && $n <= 199) { $quantN = "0100-199"; }
      elsif ($n >= 200 && $n <= 499) { $quantN = "0200-499"; }
      elsif ($n >= 500 && $n <= 999) { $quantN = "0500-999"; }
      elsif ($n >= 1000 && $n <= 1999) { $quantN = "1000-1999"; }
      elsif ($n >= 2000 && $n <= 4999) { $quantN = "2000-4999"; }
      elsif ($n >= 5000 && $n <= 9999) { $quantN = "5000-9999"; }
       
      $TermList->{TERMS}{$termid}->setAttrValue($key, $n);
      $TermList->{TERMS}{$termid}->setAttrValue($quantKey, $quantN);
    }
  }
}

if ($cleanNonEssentialAttributes){
  print "Removing All but TEXT attributes\n";
  foreach my $termid (keys %{ $TermList->{TERMS} }) {
    foreach my $attr($TermList->{TERMS}{$termid}->getAttrs()){
      if ($attr !~ /^(TEXT)$/){
        $TermList->{TERMS}{$termid}->deleteAttr($attr);
      }
    }
  }
}

#Dump TermList
if (defined($csvOutput)){
  $TermList->saveFileCSV($outfilename);
} else {
  $TermList->{TERMLIST_FILENAME} = $outfilename;
  $TermList->saveFile();
}
MMisc::ok_quit();

sub charactersOfTerm 
{
  my ($term) = @_;
  $term =~ s/\s+//g;
  
  my @chars = split(//, $term);
  scalar(@chars);
}

sub ngramOfTerm
{
  my ($term) = @_;

  my @words = split(/\s/, $term);
  scalar(@words);
}
