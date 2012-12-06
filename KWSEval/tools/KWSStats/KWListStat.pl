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
my $kwfile1 = "";
my $kwfile2 = "";
my @oneFact = ();
my @twoFact = ();
my $listAttr = undef;
my @rttms = ();

GetOptions
(
  'kwlist=s' => \$kwfile1,
  'comparekwlist=s' => \$kwfile2,
  '1Fact=s@' => \@oneFact,
  '2Fact=s@' => \@twoFact,
  'list' => \$listAttr,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required arguments
MMisc::error_quit("Specify a KWList file via -k.") if ($kwfile1 eq "");


#Load TermList
my $kwList1 = new TermList($kwfile1, 1, 1, 1);

# Listing the potential attributes
if (defined($listAttr)){
  print "The following is a list of potential attributes\n";
  my $at = new AutoTable();
  
  foreach my $termid (keys %{ $kwList1->{TERMS} }) {
    $at->increment("#Terms", "TotalTerms");
    foreach my $attr($kwList1->{TERMS}{$termid}->getAttrs()){
      $at->increment("#Terms", $attr);
    }
  }
  print $at->renderTxtTable(1);
  print "\n";
}

# One Factor Analsys
print "Conducting one Factor Analysis for attributes: ".join(", ",@oneFact)."\n";

foreach my $attr(@oneFact){
  my $at = new AutoTable();
  my $val;
  foreach my $termid (keys %{ $kwList1->{TERMS} }) {
    #  my $text = $kwList1->{TERMS}{$termid}{TEXT};
    $val = $kwList1->{TERMS}{$termid}->getAttrValuee($attr);
    if (defined($val)){
      $val =~ s/\|/_/g;
      $at->increment("Count", $val);
    } else {
      $at->increment("Count", "UNDEF");
    }
  }
  print "One Factor Analsis of $attr\n";
  $at->{Properties}->setValue("SortColKeyTxt", "Alpha");
  $at->{Properties}->setValue("SortRowKeyTxt", "Alpha");
  print $at->renderTxtTable(1);
  print "\n";
}


# Two Factor Analsys
print "Conducting Two Factor Analysis for attributes: ".join(", ",@twoFact)."\n";

foreach my $attr1attr2(@twoFact){
  my ($attr1, $attr2) = split(/\|/, $attr1attr2);

  my $at = new AutoTable();
  my $val1;
  my $val2;
  foreach my $termid (keys %{ $kwList1->{TERMS} }) {
    #  my $text = $kwList->{TERMS}{$termid}{TEXT};
    $val1 = $kwList1->{TERMS}{$termid}->getAttrValue($attr1);
    $val2 = $kwList1->{TERMS}{$termid}->getAttrValue($attr2);
    $at->increment($attr2."|".((defined $val2) ? $val2 : "UNDEF"),
                   $attr1."|".((defined $val1) ? $val1 : "UNDEF"));
  }
  print "Two Factor Analsis of $attr1attr2\n";
  $at->{Properties}->setValue("SortColKeyTxt", "Alpha");
  $at->{Properties}->setValue("SortRowKeyTxt", "Alpha");
  print $at->renderTxtTable(1);
  print "\n";
}

sub applySetOperations{
  my ($a1, $a2, $op) = @_;
  my %ht = ();
  my @res = ();
  my %a1ht = ();
  my %a2ht = ();
  
  foreach my $v(@$a1){   if (! exists($a1ht{$v})){  $ht{$v}  =  1; } $a1ht{$v} ++;  }
  ### report dups in a1
  my $dup = 0;
  foreach my $v(keys %a1ht){  $dup ++ if ($a1ht{$v} > 1); }
  print "Warning: $dup duplicate entries in array1\n" if ($dup > 0);
    
  foreach my $v(@$a2){   if (! exists($a2ht{$v})){  $ht{$v}  += 10; } $a2ht{$v} ++;  }
  $dup = 0;
  foreach my $v(keys %a2ht){  $dup ++ if ($a2ht{$v} > 1); }
  print "Warning: $dup duplicate entries in array2\n" if ($dup > 0);

  if ($op eq "intersect"){
    foreach my $k(keys %ht){
      push @res, $k if ($ht{$k} == 11);
    }
  } elsif ($op eq "A - B"){
    foreach my $k(keys %ht){
      push @res, $k if ($ht{$k} == 1);
    }
  } elsif ($op eq "B - A"){
    foreach my $k(keys %ht){
      push @res, $k if ($ht{$k} == 10);
    }
  }
  
  return \@res;
}

sub arrayComparisonReport{
  my ($a1, $a2, $a1ID, $a2ID, $prefix) = @_;
  
  my $intersect = applySetOperations($a1, $a2, "intersect");
  my $at = new AutoTable();
  
  $at->addData(scalar(@$a1),        "In $a1ID", "In $a1ID");
  $at->addData(scalar(@$intersect), "In $a1ID", "In $a2ID");
  $at->addData(scalar(@$a2),        "In $a2ID", "In $a2ID");
  $at->addData(scalar(@$intersect), "In $a2ID", "In $a1ID");

  $at->{Properties}->setValue("TxtPrefix", "   ");
  return $at->renderTxtTable(); 
}

### Compare KWList
if ($kwfile2 ne ""){
  print "Comparing keyword lists\n";
  print "  Set1 -> $kwfile1\n";
  print "  Set2 -> $kwfile2\n\n";

  my $kwList2 = new TermList($kwfile2, 1, 1, 1);
  
  print "Compare the keyword IDS\n";
  my @kw1ids = $kwList1->getTermIDs();
  my @kw2ids = $kwList2->getTermIDs();
  print arrayComparisonReport(\@kw1ids, \@kw2ids, "Set1", "Set2", "   ");
  print "\n";

  print "Compare the keyword texts WITHOUT Normalization\n";
  my @kw1KW_nonorm = ();
  my @kw2KW_nonorm = ();
  foreach my $id(@kw1ids){ my $t = $kwList1->getTermFromID($id); push @kw1KW_nonorm, $t->getAttrValue("TEXT"); }
  foreach my $id(@kw2ids){ my $t = $kwList2->getTermFromID($id); push @kw2KW_nonorm, $t->getAttrValue("TEXT"); }
  print arrayComparisonReport(\@kw1KW_nonorm, \@kw2KW_nonorm, "Set1", "Set2", "   ");
  print "\n";
  print "   Uniq to Set1: ".join(", ",@{ applySetOperations(\@kw1KW_nonorm, \@kw2KW_nonorm, "A - B") })."\n\n";
  
  print "Compare the keyword texts WITH Normalization\n";
  my @kw1KW_norm = ();
  my @kw2KW_norm = ();
  foreach my $id(@kw1ids){ my $t = $kwList1->getTermFromID($id); push @kw1KW_norm, $kwList1->normalizeTerm($t->getAttrValue("TEXT")); }
  foreach my $id(@kw2ids){ my $t = $kwList2->getTermFromID($id); push @kw2KW_norm, $kwList2->normalizeTerm($t->getAttrValue("TEXT")); }
  print arrayComparisonReport(\@kw1KW_norm, \@kw2KW_norm, "Set1", "Set2", "   ");
  print "\n";
  
}

MMisc::ok_quit();
