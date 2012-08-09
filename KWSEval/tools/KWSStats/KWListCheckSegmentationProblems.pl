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
use AutoTable;

### Options
my $kwfile = "";
my $outkwfile = "";

GetOptions
(
 'kwlist=s' => \$kwfile,
 'outputkwlist=s' => \$outkwfile,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required arguments
MMisc::error_quit("Specify an input KWList file via -k.") if ($kwfile eq "");
MMisc::error_quit("Specify an output KWList file via -o.") if ($outkwfile eq "");

#Load TermList
my $kwList = new TermList($kwfile);
my %ht = ();
my $n = 0;

print "Computing\n";
foreach my $termid (keys %{ $kwList->{TERMS} }) {
  my $val = $kwList->{TERMS}{$termid}->getAttrValue("CHARSPLITTEXT");
  push @{ $ht{$val} }, $termid;
  $n++;
  ### Set the the attribute of 
  $kwList->{TERMS}{$termid}->setAttrValue("SEGMENTATION_DUPS", $termid);
  $kwList->{TERMS}{$termid}->setAttrValue("UNIQUE_SEGMENTATION", "YES");
}

print "Analisys of terms\n";
print "   Num terms: ".$n."\n";
my @keys = keys %ht;
print "   Num uniq terms: ".scalar(@keys)."\n";
foreach my $key(@keys){
  if (@{ $ht{$key} } > 1){
    print "$key \n";
    my $highestNgramTerm = ""; 
    my $highestNgram = 0;
    foreach my $termid(@{ $ht{$key} }){ 
      print "   ".$kwList->{TERMS}{$termid}->toStringFull()."\n";
      $kwList->{TERMS}{$termid}->setAttrValue("SEGMENTATION_DUPS", join(" ",@{ $ht{$key} }));
      $kwList->{TERMS}{$termid}->setAttrValue("UNIQUE_SEGMENTATION", "NO");
      my $nGram = $kwList->{TERMS}{$termid}->getAttrValue("NGram Order");
      if ($highestNgram < $nGram){
        $highestNgram = $nGram;
        $highestNgramTerm = $termid;
      }        
    }
    die "Error: Failed to find the highest Ngram for clique ".join(" ",@{ $ht{$key} }) if ($highestNgram == 0);
    print "   Selected ID: $highestNgramTerm\n";
    $kwList->{TERMS}{$highestNgramTerm}->setAttrValue("UNIQUE_SEGMENTATION", "YES");
  }
}

$kwList->saveFile($outkwfile);

MMisc::ok_quit();
