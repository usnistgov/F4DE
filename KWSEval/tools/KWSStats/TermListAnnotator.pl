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
my $attrValueStr = undef;  ### must be a HASH structure that can be eval'd
my $attrValue = undef;  ### must be a HASH structure that can be eval'd
my $selectAttrValueStr = undef;
my $selectAttrValue = undef;

my $charSplitText = 0;
my $charSplitTextNotASCII = 0;
my $charSplitTextDeleteHyphens = 0;
my $charTextRegex = undef;

my @textPrefilters = ();
my @deleteAttr = ();

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
 'selectAttrValue=s' => \$selectAttrValueStr,
 'attrValue=s' => \$attrValueStr,
 'xprefilterText=s@'                   => \@textPrefilters,
 'deleteAttr=s@'                       => \@deleteAttr,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required options
MMisc::error_quit("in-term-list required.") if ($inTlist eq "");
MMisc::error_quit("out-file-name required.") if ($outfilename eq "");
MMisc::error_quit("makeTextSplitChars is mutually exclusive will all other edits.") 
  if ($makeTextSplitChars && ($ngram || (@rttms > 0) || $character || (@annotFiles > 0) || $useSplitChars));
if (defined($attrValueStr)){
  eval("\$attrValue = ".$attrValueStr);
#  print "Adding annotations:\n".Dumper($attrValue);
#  exit;
  MMisc::error_quit("Unable to parse attribute value String '$attrValueStr'") if (! defined($attrValue)); 
  MMisc::error_quit("parse attribute value String '$attrValueStr' is not a hash") if (ref($attrValue) ne "HASH"); 
}
if (defined($selectAttrValueStr)){
  eval("\$selectAttrValue = ".$selectAttrValueStr);
#  print "Select Terms annotations $selectAttrValueStr:\n".Dumper($selectAttrValue);
#  exit;
  MMisc::error_quit("Unable to parse attribute value String '$attrValueStr'") if (! defined($selectAttrValue)); 
  MMisc::error_quit("parse attribute value String '$attrValueStr' is not a hash") if (ref($selectAttrValue) ne "HASH"); 
}
foreach my $filt(@textPrefilters){
  if ($filt =~ /^charsplit$/i){
    $charSplitText = 1;
  } elsif ($filt =~ /^notascii$/i){
    $charSplitTextNotASCII = 1;
  } elsif ($filt =~ /^deletehyphens$/i){
    $charSplitTextDeleteHyphens = 1;
  } elsif ($filt =~ /^regex=(.+)$/i){
    $charTextRegex = $1
  } else {
    MMisc::error_quit("Error: -zprefilterText option /$filt/ not defined.  Aborting.");
  }
}
print "Warning: -zprefilterText notASCII ignored because -z charsplit not used\n" if (!$charSplitText && $charSplitTextNotASCII);
print "Warning: -zprefilterText deleteHyphens ignored because -z charsplit not used\n" if (!$charSplitText && $charSplitTextDeleteHyphens);

############  READY TO BEGIN ######################

#Load TermList
#$TermList = new TermList($inTlist, $charSplitText, $charSplitTextNotASCII, $charSplitTextDeleteHyphens);
$TermList = new TermList($inTlist, 0, 0, 0);
### Apply the attrValue
if (defined($attrValueStr)){
 foreach my $termid (keys %{ $TermList->{TERMS} }) {
    foreach my $key(keys %$attrValue){
      $TermList->{TERMS}{$termid}->setAttrValue($key, $attrValue->{$key});
    }
  }
}

if ($makeTextSplitChars){
   foreach my $termid (keys %{ $TermList->{TERMS} }) {
     $TermList->{TERMS}{$termid}{TEXT} = $TermList->{TERMS}{$termid}{CHARSPLITTEXT};
   }
}

if (defined $charTextRegex){
   print "Applying text filter $charTextRegex\n";
   die "Unable to parse regex $charTextRegex" unless ($charTextRegex =~ /s\/(.+)\/(.*)\/$/);
   my ($p1, $p2, $p3) = ($1, $2, $3);
   foreach my $termid (keys %{ $TermList->{TERMS} }) {
     $TermList->{TERMS}{$termid}{TEXT} =~ s/$p1/$p2/g;
   }
}

my %annotations = ();
#Build file annots
foreach my $file (@annotFiles) {
  open(AFILE, $file) or MMisc::error_quit("Unable to open file '$file'");
  binmode(AFILE, $TermList->getPerlEncodingString()) if ($TermList->{ENCODING} ne "");

  my $nonFoundTerms = 0;
  while (<AFILE>) {
    chomp;
    my @data = split(/,/,$_);
    my ($term) = shift(@data);
    $term =~ s/^\s+//; $term =~ s/\s+$//;
    my $termRec = undef;
    if (! $charSplitText){
      $termRec = $TermList->getTermFromText($term);
    } else {
      my $normTerm = $TermList->charSplitText($term, $charSplitTextNotASCII, $charSplitTextDeleteHyphens);
      $termRec = $TermList->getTermFromTextAfterCharSplit($normTerm, $charSplitTextNotASCII, $charSplitTextDeleteHyphens);
    }
    if (defined($termRec)){
      while (@data > 0){
        die "Error: Inconsistent attribute value pairs in '$_'"  if (@data < 2);
        my $attr = shift(@data);
        my $val = shift(@data);
  
        $attr =~ s/^\s+//; $attr =~ s/\s+$//;
        $val =~ s/^\s+//; $val =~ s/\s+$//;
        my $existingVal = $termRec->getAttrValue($attr);
        if (!defined($existingVal)){
          $termRec->setAttrValue($attr, $val);
        } else {
          $termRec->setAttrValue($attr, $existingVal . "|" . $val);
        }
      } 
    } else {
      print "Warning: Term record not found for line /$_/\n";
      $nonFoundTerms ++;
    }
  }
  print "Warning: $nonFoundTerms terms not found by text\n" if ($nonFoundTerms > 0);
  close AFILE;
}

#Run annotation functions
if ($character != 0) {
  print "Computing character counts\n";
  foreach my $termid (keys %{ $TermList->{TERMS} }) {
    my $term = $TermList->{TERMS}{$termid};
    $term->setAttrValue("Characters", &charactersOfTerm($term->getAttrValue("TEXT")));
  }
}
if ($ngram != 0) {
  print "Computing N-gram counts\n";
  foreach my $termid (keys %{ $TermList->{TERMS} }) {
    my $term = $TermList->{TERMS}{$termid};
    $term->setAttrValue("NGram Order", &ngramOfTerm($term->getAttrValue("TEXT")));
  }
}

### Replace original texts and Removing the ORIGTEXT attribute
#foreach my $termid (keys %{ $TermList->{TERMS} }) {
#  my $term = $TermList->getTermFromID($termid);
#  my $origText = $term->getAttrValue("ORIGTEXT");
#  my $text = $term->getAttrValue("TEXT");
#  if (defined($origText) && $origText ne $text){
#    $term->setAttrValue("TEXT", $origText);
#  }
#  $term->deleteAttr("ORIGTEXT");  
#}

#for inferred duration model
my $num_sampled_terms = 0;
my $total_per_char_dur = 0;

## Add the counts from the RTTMs
if (@rttms > 0){
  print "Loading RTTMs for analisys\n";
  foreach my $rttm(@rttms){
    print "   Processing $rttm\n";
    my $key = "RefOccurences:$rttm";
    my $quantKey = "QuantizedRefOccurences:$rttm";
    my $meanDurationKey = "MeanDuration:$rttm";
    my $meanDurPerCharKey = "MeanDurPerChar:$rttm";
    my $quantizedDurationKey = "QuantizedDuration:$rttm";
    my $rttm = new RTTMList($rttm, $TermList->getLanguage(),
                            $TermList->getCompareNormalize(), $TermList->getEncoding(), 
                            $charSplitText, $charSplitTextNotASCII, $charSplitTextDeleteHyphens, 1); # bypassCoreText -> no RTTM text rewrite possible  
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
      my $total_dur = 0.0;
      foreach my $dat(@$out){
        print "$termid ".$dat->[0]->{FILE}."\n";
	$total_dur += ($dat->[-1]->{ET} - $dat->[0]->{BT});
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
      if ($n > 0) {
	#Mean term duration annotations
	my $mean_term_dur = ($total_dur / $n);
	my $quant_dur = "";
	$TermList->{TERMS}{$termid}->setAttrValue($meanDurationKey, sprintf("%.4f", $mean_term_dur));

	#quantize duration
	for (my $i = 1; $i <= 10; $i++) {
	  my $upper = $i * 0.5;
	  if ($mean_term_dur < $upper) {
	    $quant_dur = sprintf("%.1f", $upper - 0.5)."-".sprintf("%.1f", $upper);
	    last;
	  }
	}
	$TermList->{TERMS}{$termid}->setAttrValue($quantizedDurationKey, $quant_dur);

	#Calculate mean char duration
	my $nchars = &charactersOfTerm($TermList->{TERMS}{$termid}{TEXT});
	$total_per_char_dur += ($mean_term_dur / $nchars);
	$num_sampled_terms += 1;

	#Add mean duration per character
	$TermList->{TERMS}{$termid}->setAttrValue($meanDurPerCharKey, sprintf("%.4f", $mean_term_dur / $nchars));
      }
    }
  }
}

#Inferred Term Duration
my $dur_per_char = ($total_per_char_dur / $num_sampled_terms) if $num_sampled_terms > 0;
#build mean character duration
foreach my $termid (keys %{ $TermList->{TERMS} }) {
  my $nchars = &charactersOfTerm($TermList->{TERMS}{$termid}{TEXT});
  my $inferred_dur = $dur_per_char * $nchars;
  my $quant_inf_dur = "";
  $TermList->{TERMS}{$termid}->setAttrValue("InferredDuration", sprintf("%.4f", $inferred_dur));
  #quantize inferred duration
  for (my $i = 1; $i <= 10; $i++) {
    my $upper = $i * 0.5;
    if ($inferred_dur < $upper) {
      $quant_inf_dur = sprintf("%.1f", $upper - 0.5)."-".sprintf("%.1f", $upper);
      last;
    }
  }
  $TermList->{TERMS}{$termid}->setAttrValue("QuantizedInferredDuration", $quant_inf_dur);
}

### Filter unselected terms
if (defined($selectAttrValueStr)){
  my $numDel = 0;
  print "Removing un-selected terms \n";
#  print join(" ",keys %$selectAttrValue)."\n";
  foreach my $termid (keys %{ $TermList->{TERMS} }) {
    my $keep = 0;
#    print "$termid\n";
    foreach my $keepAttr(keys %$selectAttrValue){
      my $val = $TermList->{TERMS}{$termid}->getAttrValue($keepAttr);
#      print Dumper($TermList->{TERMS}{$termid});
      my $pat = $selectAttrValue->{$keepAttr};
#      print " $termid $keepAttr val=$val pat=$pat\n";
      $keep = 1 if (defined($val) && $val =~ /^($pat)$/);
    }
    if (! $keep){
      $TermList->removeTermByID($termid) ;
      $numDel ++;
    }
  }      
  print "  $numDel keywords deleted\n";
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

### Delete the requested attributes
foreach my $attr(@deleteAttr){
  print "Removing Attribute $attr\n";
  foreach my $termid (keys %{ $TermList->{TERMS} }) {
     $TermList->{TERMS}{$termid}->deleteAttr($attr);
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
