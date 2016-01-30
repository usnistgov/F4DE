#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#

use strict;

use Encode;
use if $^V lt 5.18.0, "encoding", 'euc-cn';
use if $^V ge 5.18.0, "Encode::CN";
use if $^V lt 5.18.0, "encoding", 'utf8';
use if $^V ge 5.18.0, "utf8";

# Check we have every module (perl wise)

my (@f4bv, $f4d);
BEGIN {
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }

  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
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
use BabelLex;

my $outfilename = "";
my @annotFiles = ();
my @csvAnnotFiles = ();
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
my $warnFailedLookup = 0; 
my $addInferredCharaterDuration = 0;

my $charSplitText = 0;
my $charSplitTextNotASCII = 0;
my $charSplitTextDeleteHyphens = 0;
my $charTextRegex = undef;

my @textPrefilters = ();
my @deleteAttr = ();
my $mduration = "";
my $normalizeTermTexts = undef;   ### applies the text normalization to the term texts
my $bypassxmllint = 0;

my $newVersion = undef;
my @oovLexicons = ();

#Options
#Need flags for adding programmatically generated annots, (i.e. NGram)
GetOptions
(
 'in-term-list=s' => \$inTlist,
 'annot-files=s@' => \@annotFiles,
 'csv-annot-files=s@' => \@csvAnnotFiles,
 'out-file-name=s' => \$outfilename,
 'n-gram' => \$ngram,
 'character' => \$character,
 'rttms=s@' => \@rttms,
 'csvOutput' => \$csvOutput,
 'useSplitChars' => \$useSplitChars,
 'makeTextSplitChars' => \$makeTextSplitChars,
 'ReduceDuplicateInfo' => \$ReduceDuplicateInfo,
 'addInferredCharaterDuration' => \$addInferredCharaterDuration,
 'CleanNonEssentialAttributes' => \$cleanNonEssentialAttributes,
 'warnFailedTermLookup' => \$warnFailedLookup,
 'selectAttrValue=s' => \$selectAttrValueStr,
 'attrValue=s' => \$attrValueStr,
 'xprefilterText=s@'                   => \@textPrefilters,
 'deleteAttr=s@'                       => \@deleteAttr,
 "mediatedDuration=s" => \$mduration,
 'setVersion=s'                        => \$newVersion,
 'normalizeTermTexts'                  => \$normalizeTermTexts,
 'XmllintBypass'                       => \$bypassxmllint,
 'addOOVCount=s@'                  => \@oovLexicons,
) or MMisc::error_quit("Unknown option(s)\n");


#Check required options
MMisc::error_quit("in-term-list required.") if ($inTlist eq "");
MMisc::error_quit("out-file-name required.") if ($outfilename eq "");
MMisc::error_quit("makeTextSplitChars is mutually exclusive will all other edits.") 
  if ($makeTextSplitChars && ($ngram || (@rttms > 0) || $character || $mduration || (@annotFiles > 0) || $useSplitChars));


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
    MMisc::error_quit("Error: -xprefilterText option /$filt/ not defined.  Aborting.");
  }
}


print "Warning: -zprefilterText notASCII ignored because -z charsplit not used\n" if (!$charSplitText && $charSplitTextNotASCII);
print "Warning: -zprefilterText deleteHyphens ignored because -z charsplit not used\n" if (!$charSplitText && $charSplitTextDeleteHyphens);
print "Warning: -addInferredCharaterDuration ingnored because no RTTMs are present\n" if ($addInferredCharaterDuration && @rttms <= 0);
############  READY TO BEGIN ######################

#Load TermList
#$TermList = new TermList($inTlist, $charSplitText, $charSplitTextNotASCII, $charSplitTextDeleteHyphens);
$TermList = new TermList($inTlist, 0, 0, 0, $bypassxmllint);
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


foreach my $csvfile (@csvAnnotFiles) {
  print "Loading annotation csv file '$csvfile'\n";
  my $at = new AutoTable();
  $at->setEncoding($TermList->getEncoding());
  $at->setCompareNormalize($TermList->getCompareNormalize());
  MMisc::error_quit("Problem loading CSV $csvfile into Auto Table: " . $at->get_errormsg() )
      if (! $at->loadCSV($csvfile, undef, undef, undef, undef, "\t"));
  print "   CSV Error message ".$at->get_errormsg() ."\n";
  print "   ".scalar($at->getRowIDs("AsAdded"))." rows loaded \n";  

  my @cols = $at->getColIDs("AsAdded");
  my $t = 1;
  my %warnings = ();
  foreach my $lineID($at->getRowIDs("AsAdded")){
#    print "Processing $lineID\n";
    my $keyword = $at->getData("KEYWORD", $lineID);
    my $term = $TermList->getTermFromText($keyword);
    if (!defined($term)){
      die "Failed to find term for keyword $keyword" if (! $warnFailedLookup);
      print "Warning: term lookup fpr /$keyword/ failed.  Skipping\n";
      next
    }
    
    foreach my $col(@cols){
      next if ($col eq "KEYWORD");
      if ($col eq ""){
        if (!exists($warnings{$col})){ 
          print "Warning: There is a blank column header in $csvfile which was ignored\n";
          $warnings{$col} = 1;
        }
        next;
      }
      my $val = $at->getData($col, $lineID);
      my $oldVal = $term->getAttrValue($col);
      if (!defined $oldVal){
        $term->setAttrValue($col,$val);
      } else {
        my $new = 1;
        foreach my $ov(split(/,/,$oldVal)){ $new = 0 if ($val eq $ov);  }
        if ($new){
          $term->setAttrValue($col,"$oldVal,$val");
          print "Info: term ".$term->getAttrValue("TERMID")." /$keyword/ $col has multiple values ($oldVal,$val)\n";
        }
      }
    }
  }
#    print "  new term needed\n";
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


# Process Mediated Duration request:
# expected argument and options:
# --mediatedDuration lexicon_filename,romanized_flag,phone_duration_filename
# where romanized flag must either be 1 or 0.
# When the option is used, the argument string is split on comma, and the
# results are passed to the BabelLex module. The module loads the files and
# prepares the duration tables. This script then continues to query the module
# for its terms durations. The new attribute name "Mediated Duration" and the 
# received value are stored in the output file.
if ($mduration ne "") {

  my @args = split(/,/, join(',', $mduration));

  my $mdur_lex_file = $args[0];
  my $romanized     = $args[1];
  my $mdur_dur_file = $args[2];
  my $mdur_map_file = $args[3];

  MMisc::error_quit ("Arg 1 lex file [$mdur_lex_file] not found\n")
  unless (-e $mdur_lex_file);

  MMisc::error_quit ("Arg 2 romanized flag [$romanized] must be 0 or 1\n")
    unless ($romanized == 0 || $romanized == 1);

  MMisc::error_quit ("Arg 4 dur file [$mdur_dur_file] not found\n")
    unless (-e $mdur_dur_file);

  MMisc::error_quit ("Arg 5 map file [$mdur_map_file] not found\n")
    unless (-e $mdur_map_file);

  print "\n                             ***\n";
  print "Computing term mediated durations using:\n";
  print "$mdur_map_file,\n$mdur_lex_file,\n$romanized,\n$mdur_dur_file\n";
  print "***\n";

  my $bl = new BabelLex ($mdur_lex_file,
                         $romanized,
                         $TermList->getEncoding(),
                         $mdur_dur_file,
                         $mdur_map_file);

  foreach my $termid (keys %{ $TermList->{TERMS} }) {

    my $term = $TermList->{TERMS}{$termid};
    my %data = %{$bl->getDurationHash($term->getAttrValue("TEXT"))};

    $term->setAttrValue("Phone_Length_i", $data{NUMPHONES});
    $term->setAttrValue("Phone_Length_Med_Status_n", $data{SIZESTATUS});
    $term->setAttrValue("Phone_Mediated_Duration", $data{DURAVERAGE});
    $term->setAttrValue("Phone_Mediated_Status", $data{DURSTATUS});
  }
}

# Process oovCount request:
# expected argument is a set of lexicons:
if (@oovLexicons > 0){
  for my $lexdef(@oovLexicons){
    print "$lexdef\n";
    my ($lex, $romanized) = split(/,/, $lexdef);

    unless (-e $lex){ die "Error: Arg 1 lexicon /$lex/ does not exist for OOV computation"; }
    unless ($romanized == 0 || $romanized == 1){ die "Error: Arg 2 /$romanized/ must be 0 or 1 for OOV computation\n";}
    print "Computing OOVs for lexicon $lex, romanzied=$romanized\n";

    my $bl = new BabelLex ($lex, $romanized, $TermList->getEncoding(), undef, undef);
    foreach my $termid (keys %{ $TermList->{TERMS} }) {
      my $term = $TermList->{TERMS}{$termid};
      my $oov = $bl->getOOVCount($term->getAttrValue("TEXT"));

      $term->setAttrValue("OOVCount:$lex", $oov);
    }
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
      #print "      Processing term $termid ".($n++)." of ".scalar(@terms)." ".$TermList->{TERMS}{$termid}->toPerl()."\n";
      my $text = $TermList->{TERMS}{$termid}{TEXT};

      if ($charSplitText){
        $text = $TermList->charSplitText($text, $charSplitTextNotASCII, $charSplitTextDeleteHyphens);
      }
      my $out = RTTMList::findTermHashToArray($rttm->findTermOccurrences($text, 0.5));
      my $total_dur = 0.0;
      foreach my $dat(@$out){
#        print "$termid ".$dat->[0]->{FILE}."\n";
	$total_dur += ($dat->[-1]->{ET} - $dat->[0]->{BT});
      }
      my $n = scalar(@$out);
      my $quantN = $n;
      if ($n == 0) { $quantN = "0000x0"; }
      elsif ($n >= 1 && $n <= 1) { $quantN = "0001x1"; }
      elsif ($n >= 2 && $n <= 4) { $quantN = "0002x4"; }
      elsif ($n >= 5 && $n <= 9) { $quantN = "0005x9"; }
      elsif ($n >= 10 && $n <= 19) { $quantN = "0010x19"; }
      elsif ($n >= 20 && $n <= 49) { $quantN = "0020x49"; }
      elsif ($n >= 50 && $n <= 99) { $quantN = "0050x99"; }
      elsif ($n >= 100 && $n <= 199) { $quantN = "0100x199"; }
      elsif ($n >= 200 && $n <= 499) { $quantN = "0200x499"; }
      elsif ($n >= 500 && $n <= 999) { $quantN = "0500x999"; }
      elsif ($n >= 1000 && $n <= 1999) { $quantN = "1000x1999"; }
      elsif ($n >= 2000 && $n <= 4999) { $quantN = "2000x4999"; }
      elsif ($n >= 5000 && $n <= 9999) { $quantN = "5000x9999"; }
       
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
if ($addInferredCharaterDuration){
  if ($num_sampled_terms > 0) {
    my $dur_per_char = ($total_per_char_dur / $num_sampled_terms);
    #build mean character duration
    foreach my $termid (keys %{ $TermList->{TERMS} }) {
      my $nchars = &charactersOfTerm($TermList->{TERMS}{$termid}{TEXT});
      my $inferred_dur = $dur_per_char * $nchars;
      my $quant_inf_dur = "";
      my $quant_inf_dur_per_char = "";
    
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
  } else {
    warn "Could not compute Inferred Character Duration (Number of sampled terms = 0)\n";
  }
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

### Update the version
if (defined($newVersion)){
    $TermList->setVersion($newVersion);
}

if (defined($normalizeTermTexts)){
    print "Applying normalization to the term texts\n";
    foreach my $termid (keys %{ $TermList->{TERMS} }) {
	$TermList->{TERMS}{$termid}{TEXT} = $TermList->normalizeTerm($TermList->{TERMS}{$termid}{TEXT});
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
  sprintf("%02d",scalar(@chars));
}

sub ngramOfTerm
{
  my ($term) = @_;

  my @words = split(/\s/, $term);
  sprintf("%02d",scalar(@words));
}
