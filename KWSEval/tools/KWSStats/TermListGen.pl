#!/usr/bin/env perl -w

use strict;

use Encode;
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
use TermList;
use TermListRecord;

my $tlistfile = "";
my $language = "";
my $normalization = "";
my $outfilename = "";
my $encoding = "";
my $inTlist = "";
my $idTextPrefix = "TERM-";
my $fileVersion = "Built by TermListGen";
my $kwKeepPref = "union";   
my $annotKeepPref = "keepOld";

GetOptions
(
 'file=s' => \$tlistfile,
 'in-term-list=s' => \$inTlist,
 'language=s' => \$language,
 'encoding=s' => \$encoding,
 'version=s' => \$fileVersion,
 'kwKeepPreference=s' => \$kwKeepPref,
 'annotKeepPreference=s' => \$annotKeepPref,
 'normalization=s' => \$normalization,
 'out-file-name=s' => \$outfilename,
 'idTextPrefix=s' => \$idTextPrefix,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required arguments
MMisc::error_quit("Specify a term file.") if ($tlistfile eq "");
MMisc::error_quit("Specify the output file.") if ($outfilename eq "");
MMisc::error_quit("Language argument required.") if ($language eq "");
MMisc::error_quit("kwKeepPref = $kwKeepPref but not /(union|old|new)/") if ($kwKeepPref !~ /^(union|old|new)$/);
MMisc::error_quit("annotKeepPref = $annotKeepPref but not /(keepOld|deleteOld)/") if ($annotKeepPref !~ /^(keepOld|deleteOld)$/);

#Get Terms
print "Loading new term csv file '$tlistfile'\n";
my $keywordAT = new AutoTable();
$keywordAT->setEncoding($encoding);
$keywordAT->setCompareNormalize($normalization);
MMisc::error_quit("Problem loading CSV $tlistfile into Auto Table: " . $keywordAT->get_errormsg())
      if (! $keywordAT->loadCSV($tlistfile));
print "   ".scalar($keywordAT->getRowIDs("AsAdded"))." rows loaded \n";

my $inTermList;
#Get Terms from in TermList
if ($inTlist ne "") {
  print "Loading initial termList $inTlist\n";
  $inTermList = new TermList($inTlist, undef, undef);
  MMisc::error_quit("Language on the commandline '$language' does not match input KWList ".
        $inTermList->getLanguage())  if ($inTermList->getLanguage() ne $language);
  MMisc::error_quit("Encoding on the commandline '$encoding' does not match input KWList ".
        $inTermList->getEncoding())  if ($inTermList->getEncoding() ne $encoding);
#  foreach my $termid (keys %{ $inTermList->{TERMS} }) {
#    my $text = $inTermList->normalizeTerm($inTermList->{TERMS}{$termid}{TEXT});
#    $terms{$text} = 1;
#    #Preserve annotations
#    foreach my $key (keys %{ $inTermList->{TERMS}{$termid} }) {
#      next if ($key =~ m/(TERMID|TEXT)/);
#      $preservedAnnots{$text}{$key} = 
#	$inTermList->{TERMS}{$termid}{$key};
#    }
#  }

  ### This will get deleted later
  foreach my $termid (keys %{ $inTermList->{TERMS} }) {
    $inTermList->{TERMS}{$termid}->setAttrValue("__TLG__InitialTermFile__", "1");
  }
} else {
  print "Starting empty termlist\n";
  $inTermList = new TermList(undef, 0, 0, 0);
  $inTermList->setLanguage($language);
  $inTermList->setCompareNormalize($normalization) if ($normalization ne "");
  $encoding = "UTF-8" if ($encoding =~ m/utf-?8/i);
  $inTermList->setEncoding($encoding);
  $inTermList->setVersion($fileVersion);
}
print "  TermLists ready\n";

### Loop over the AutoTable adding keywords
my @cols = $keywordAT->getColIDs("AsAdded");
my $t = 1;
foreach my $lineID($keywordAT->getRowIDs("AsAdded")){
#  print "Processing $lineID\n";
  my $keyword = $keywordAT->getData("KEYWORD", $lineID);
  my $term = $inTermList->getTermFromText($keyword);
  if (!defined($term)){
#    print "  new term needed\n";
    my $newID = $idTextPrefix . sprintf("%04d", $t++);
    while (defined($inTermList->getTermFromID($newID))){
      $newID = $idTextPrefix . sprintf("%04d", $t++);
    }
    ### 
    $term = new TermListRecord({ "TERMID" => $newID, "TEXT" => $keyword});
    $inTermList->addTerm($term, $newID);
  }
  $term->setAttrValue("__TLG__FromNewFile__", "1");
#  print $term->toStringFull();
  foreach my $col(@cols){
    next if ($col eq "KEYWORD");
    my $val = $keywordAT->getData($col, $lineID);
    my $oldVal = $term->getAttrValue($col);
#    print "   $keyword $col $val\n";
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

## Loop through terms keeping the ones for the preference
foreach my $termid (keys %{ $inTermList->{TERMS} }) {
  my $term = $inTermList->{TERMS}{$termid};
  my $fromInit = $term->getAttrValue("__TLG__InitialTermFile__");
  $term->deleteAttr("__TLG__InitialTermFile__");
  
  my $fromNew = $term->getAttrValue("__TLG__FromNewFile__");
  $term->deleteAttr("__TLG__FromNewFile__");
  
  if ($annotKeepPref eq "deleteOld"){
    foreach my $attr($term->getAttrs()){
      $term->deleteAttr($attr) if ($attr !~ /^(TEXT|TERMID)$/);
    }
  }

  #print "$termid $fromInit $fromNew\n";
  if ($kwKeepPref eq "union"){
    ; ## do nothing
  } elsif ($kwKeepPref eq "old") {
    $inTermList->removeTermByID($termid) unless defined($fromInit);
  } elsif ($kwKeepPref eq "new") {
    $inTermList->removeTermByID($termid) unless defined($fromNew);
  }
}

#Output file
#$outfilename = $language . ".kwlist.xml" if ($outfilename eq "");
#$TermList->setLanguage($language);
#$TermList->setCompareNormalize($normalization) if ($normalization ne "");
#$encoding = "UTF-8" if ($encoding =~ m/utf-?8/i);
#$TermList->setEncoding($encoding);
$inTermList->saveFile($outfilename);

MMisc::ok_quit();
