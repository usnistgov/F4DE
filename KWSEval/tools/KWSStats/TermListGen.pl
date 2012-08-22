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

my @tlistfiles = ();
my $language = "";
my $normalization = "";
my $outfilename = "";
my $encoding = "";
my $inTlist = "";

GetOptions
(
 'files=s@' => \@tlistfiles,
 'in-term-list=s' => \$inTlist,
 'language=s' => \$language,
 'encoding=s' => \$encoding,
 'normalization=s' => \$normalization,
 'out-file-name=s' => \$outfilename,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required arguments
MMisc::error_quit("Specify at least one file.") if (@tlistfiles == 0);
MMisc::error_quit("Language argument required.") if ($language eq "");

#Get Terms
my %terms = ();
foreach my $tfile (@tlistfiles) {
  open (TFILE, $tfile)
    or MMisc::error_quit("Cannot open file '$tfile'.");
  while (<TFILE>) {
    chomp;
    #Trim
    s/^\s*//;
    s/\s*$//;
    
    next if ($_ =~ /^$/);

    $_ = lc $_ if ($normalization =~ m/lowercase/i);
    $terms{$_} = 1;
  }
  close TFILE;
}
my %preservedAnnots = ();
#Get Terms from in TermList
if ($inTlist ne "") {
  my $inTermList = new TermList($inTlist);
  foreach my $termid (keys %{ $inTermList->{TERMS} }) {
    my $text = $inTermList->normalizeTerm($inTermList->{TERMS}{$termid}{TEXT});
    $terms{$text} = 1;
    #Preserve annotations
    foreach my $key (keys %{ $inTermList->{TERMS}{$termid} }) {
      next if ($key =~ m/(TERMID|TEXT)/);
      $preservedAnnots{$text}{$key} = 
	$inTermList->{TERMS}{$termid}{$key};
    }
  }
}

#Build TermList
my $TermList = new TermList();
my @aterms = keys %terms;
for (my $t=0; $t<@aterms; $t++) {
  my $termid = "TERM-" . sprintf("%04d", $t);
  $TermList->{TERMS}{$termid} = new TermListRecord({ TERMID => $termid, TEXT => $aterms[$t]});
#  $TermList->{TERMS}{$termid}{TERMID} = $termid;
#  $TermList->{TERMS}{$termid}{TEXT} = $aterms[$t];
  if ($preservedAnnots{$aterms[$t]}) {
    #Add preserved annotations
    foreach my $key (keys %{ $preservedAnnots{$aterms[$t]} }) {
      $TermList->{TERMS}{$termid}{$key} = $preservedAnnots{$aterms[$t]}{$key};
    }
  }
}

#Output file
$outfilename = $language . ".kwlist.xml" if ($outfilename eq "");
$TermList->setLanguage($language);
$TermList->setCompareNormalize($normalization) if ($normalization ne "");
my $version = 1; #??
$TermList->{VERSION} = $version;
$encoding = "UTF-8" if ($encoding =~ m/utf-?8/i);
$TermList->setEncoding($encoding);
$TermList->saveFile($outfilename);

MMisc::ok_quit();
