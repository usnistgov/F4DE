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
my @oneFact = ();
my @twoFact = ();
my $listAttr = undef;
my @rttms = ();

GetOptions
(
 'kwlist=s' => \$kwfile,
  '1Fact=s@' => \@oneFact,
  '2Fact=s@' => \@twoFact,
  'list' => \$listAttr,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required arguments
MMisc::error_quit("Specify a KWList file via -k.") if ($kwfile eq "");


#Load TermList
my $kwList = new TermList($kwfile);

# Listing the potential attributes
if (defined($listAttr)){
  print "The following is a list of potential attributes\n";
  my $at = new AutoTable();
  
  foreach my $termid (keys %{ $kwList->{TERMS} }) {
    $at->increment("#Terms", "TotalTerms");
    foreach my $attr($kwList->{TERMS}{$termid}->getAttrs()){
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
  foreach my $termid (keys %{ $kwList->{TERMS} }) {
    #  my $text = $kwList->{TERMS}{$termid}{TEXT};
    $val = $kwList->{TERMS}{$termid}->getAttrValue($attr);
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
  foreach my $termid (keys %{ $kwList->{TERMS} }) {
    #  my $text = $kwList->{TERMS}{$termid}{TEXT};
    $val1 = $kwList->{TERMS}{$termid}->getAttrValue($attr1);
    $val2 = $kwList->{TERMS}{$termid}->getAttrValue($attr2);
    $at->increment($attr2."|".((defined $val2) ? $val2 : "UNDEF"),
                   $attr1."|".((defined $val1) ? $val1 : "UNDEF"));
  }
  print "Two Factor Analsis of $attr1attr2\n";
  $at->{Properties}->setValue("SortColKeyTxt", "Alpha");
  $at->{Properties}->setValue("SortRowKeyTxt", "Alpha");
  print $at->renderTxtTable(1);
  print "\n";
}



MMisc::ok_quit();
