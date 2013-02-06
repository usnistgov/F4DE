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
use Statistics::Descriptive;
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
my $splitChar = '\|';
my @attrPreConds = ();
my $plot_root = "";
my $plot_count = 1;

GetOptions
(
  'kwlist=s' => \$kwfile1,
  'comparekwlist=s' => \$kwfile2,
  '1Fact=s@' => \@oneFact,
  '2Fact=s@' => \@twoFact,
  'list' => \$listAttr,
  'splitChar=s' => \$splitChar,
  'attrPreConditions=s@' => \@attrPreConds,  ## To include a KW, all conditions must be met  '<attr>:regex=<val>'
  'plotroot=s' => \$plot_root,
) or MMisc::error_quit("Unknown option(s)\n");

#Check required arguments
MMisc::error_quit("Specify a KWList file via -k.") if ($kwfile1 eq "");

# Parse the preconditions
my @kwConds = ();
foreach my $pc(@attrPreConds){
  print "Parsing Precondition $pc\n";
  die "Error: Failed to parse precondition /$pc/" unless($pc =~ /^(.+):regex=(.+)$/);
  push @kwConds, { attr => $1, valRegex => $2 };
}
#print Dumper(\@kwConds);
sub kwMeetsPreCondition{
 my ($kw) = @_;
 for (my $i=0; $i<@kwConds; $i++){
   my $val = $kw->getAttrValue($kwConds[$i]{"attr"});
   return 0 unless(defined($val));
   return 0 if ($val !~ /$kwConds[$i]{"valRegex"}/);
 }
 return 1;
}

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

foreach my $attr(@oneFact) {
  die "Error: Can't parse 1-factor string /$attr/ !~ /^([^:]):(.+)\$/" unless ($attr =~ /^([^:]):(.+)$/);
  my $type = $1;
  $attr = $2;
  my ($fact_recorder, $fact_renderer) = &__1_fact_gen_for_type($type, $attr) or next;

  foreach my $termid (keys %{ $kwList1->{TERMS} }) {
    next unless (kwMeetsPreCondition($kwList1->{TERMS}{$termid}));
    my $val = $kwList1->{TERMS}{$termid}->getAttrValue($attr);
    &{ $fact_recorder }($val) if $val;
  }
  print "One Factor Analysis of $attr\n";
  &{ $fact_renderer }();
}

###1 factor report generators
sub __1_fact_gen_for_type {
  my ($type, $attr) = @_;
  if ($type =~ /d/i) { return &__discrete_1_fact($attr); }
  elsif ($type =~ /c/i) { return &__continuous_1_fact($attr); }
  else { warn("Unrecognized type '$type' for $attr.\n") and return; }
}
sub __discrete_1_fact {
  my $attr = shift;
  my $at = new AutoTable();
  return (sub { #recorder
	    my $val = shift;
	    $at->increment("Count", $val ? $val : "UNDEF");
	  },
	  sub { #renderer
	    $at->setProperties({"SortRowKeyTxt" => "Alpha"});
	    print $at->renderTxtTable(1);
	  });
} #?
sub __continuous_1_fact {
  my $attr = shift;
  my $stats = new Statistics::Descriptive::Full;
  return (sub { #recorder
	    my $val = shift;
	    $stats->add_data($val) if $val;
	  },
	  sub { #renderer
	      my $at = new AutoTable();
	      my %plot_data = ();
	      $at->addData($stats->count(), "Count", "Data");
	      $at->addData(sprintf("%.4f", $stats->min()), "Min", "Data");
	      $at->addData(sprintf("%.4f", $stats->quantile(1)), "Lower Quartile", "Data");
	      $at->addData(sprintf("%.4f", $stats->median()), "Median", "Data");
	      $at->addData(sprintf("%.4f", $stats->mean()), "Mean", "Data");
	      $at->addData(sprintf("%.4f", $stats->quantile(3)), "Upper Quartile", "Data");
	      $at->addData(sprintf("%.4f", $stats->max()), "Max", "Data");
	      print $at->renderTxtTable(1);
	      $plot_data{"Data"} = [$stats->min(),
				  $stats->quantile(1),
				  $stats->median(),
				  $stats->quantile(3),
				  $stats->max(),
				  $stats->mean()];
	      unless (MMisc::is_blank($plot_root)) { 
		render_box_plot(\%plot_data, "$plot_root$plot_count", undef, $attr);
		$plot_count++;
	      }
	  });
} #?
###

#two factor
foreach my $attr1attr2(@twoFact) {
  my ($attr1, $attr2) = split(/\|/, $attr1attr2);

  die "Error: Can't parse first 2-factor string /$attr1/ !~ /^([^:]):(.+)\$/" unless ($attr1 =~ /^([^:]):(.+)$/);
  my $type1 = $1;
  $attr1 = $2;
  die "Error: Can't parse second 2-factor string /$attr2/ !~ /^([^:]):(.+)\$/" unless ($attr2 =~ /^([^:]):(.+)$/);
  my $type2 = $1;
  $attr2 = $2;
   
  my ($fact_recorder, $fact_renderer) = &__2_fact_gen_for_type($type1, $attr1, $type2, $attr2) or next;
  foreach my $termid (keys %{ $kwList1->{TERMS} }) {
###<<<<<<< KWListStat.pl
###    #  my $text = $kwList1->{TERMS}{$termid}{TEXT};
###
###    $val = $kwList1->{TERMS}{$termid}->getAttrValue($attr);
###    if (defined($val)){
###      $val =~ s/\|/_/g;
###      $at->increment("Count", $val);
###    } else {
###      $at->increment("Count", "UNDEF");
###    }
###=======
    next unless (kwMeetsPreCondition($kwList1->{TERMS}{$termid}));

    my $val1 = $kwList1->{TERMS}{$termid}->getAttrValue($attr1);
    my $val2 = $kwList1->{TERMS}{$termid}->getAttrValue($attr2);
    &{ $fact_recorder }($val1, $val2) if $val1 and $val2;
###>>>>>>> 1.4
  }
  print "Two Factor Analysis of $attr1|$attr2\n";
  &{ $fact_renderer }();
}

###2 factor report generators
sub __2_fact_gen_for_type {
  my ($type1, $attr1, $type2, $attr2) = @_; #attr taken only for axis labels on plots
  if ("$type1$type2" =~ /dd/i) { return &__dd_2_fact($attr1, $attr2); }
  elsif ("$type1$type2" =~ /cd/i) { return &__cd_2_fact($attr1, $attr2); }
  elsif ("$type1$type2" =~ /cc/i) { return &__cc_2_fact($attr1, $attr2); }
  else { warn("Unrecognized type '$type1$type2'.\n") and return; }
}
sub __dd_2_fact {
  my ($attr1, $attr2) = @_;
  my $at = new AutoTable();
  return (sub { #recorder
	    my ($val1, $val2) = @_;
	    $at->increment($val1 ? $val1 : "UNDEF", $val2 ? $val2 : "UNDEF");
	  },
	  sub { #renderer
	    print $at->renderTxtTable(1);
	  });
}
sub __cd_2_fact {
  my ($attr1, $attr2) = @_;
  my %results = ();
  $results{"Grand"} = new Statistics::Descriptive::Full;
  return (sub { #recorder
	    my ($val1, $val2) = @_;
	    $results{$val2} ||= new Statistics::Descriptive::Full;
	    $results{$val2}->add_data($val1);
	    $results{"Grand"}->add_data($val1);
	  },
	  sub { #renderer
	    my $at = new AutoTable();
	    $at->setProperties({"SortRowKeyTxt" => "Alpha"});
	    my %plot_data = ();
	    foreach my $key(keys %results) {
	      $at->addData($results{$key}->count(), "Count", $key);
	      $at->addData(sprintf("%.4f", $results{$key}->min()), "Min", $key);
	      $at->addData(sprintf("%.4f", $results{$key}->quantile(1)), "Lower Quartile", $key);
	      $at->addData(sprintf("%.4f", $results{$key}->median()), "Median", $key);
	      $at->addData(sprintf("%.4f", $results{$key}->mean()), "Mean", $key);
	      $at->addData(sprintf("%.4f", $results{$key}->quantile(3)), "Upper Quartile", $key);
	      $at->addData(sprintf("%.4f", $results{$key}->max()), "Max", $key);
	      $plot_data{$key} = [$results{$key}->min(),
				  $results{$key}->quantile(1),
				  $results{$key}->median(),
				  $results{$key}->quantile(3),
				  $results{$key}->max(),
				  $results{$key}->mean()];
	    }
	    unless (MMisc::is_blank($plot_root)) {
	      render_box_plot(\%plot_data, "$plot_root$plot_count", $attr2, $attr1);
	      $plot_count++;
	    }
	    print $at->renderTxtTable(1);
	  });
}
sub __cc_2_fact {
  my ($attr1, $attr2) = @_;
  my @results = ();
  my ($grand_v1, $grand_v2) = (0.0, 0.0);
  return (sub { #recorder
	    my ($val1, $val2) = @_;
	    $grand_v1 += $val1; $grand_v2 += $val2;
	    push @results, "$val2, $val1"; # reverse these?
	  },
	  sub { #renderer
	    if (scalar(@results) > 0) {
	      $grand_v1 /= scalar(@results);
	      $grand_v2 /= scalar(@results);
	      push @results, sprintf("%.4f", $grand_v2)." ".sprintf("%.4f", $grand_v1);
	    }
	    unless (MMisc::is_blank($plot_root)) {
	      render_scatter_plot(\@results, "$plot_root$plot_count", $attr2, $attr1);
	      $plot_count++;
	    }
	  });
}

###


###foreach my $attr1attr2(@twoFact){
###  my ($attr1, $attr2) = split(/$splitChar/, $attr1attr2);
###  my @attr1Labs = split(/\|/,$attr1);
###  my @attr2Labs = split(/\|/,$attr2);
###  print "   attr1=".join(",",@attr1Labs)." attr2=".join(",",@attr2Labs)."\n";
###  my $at = new AutoTable();
###  my $val1;
###  my $val2;
###  foreach my $termid (keys %{ $kwList1->{TERMS} }) {
###    next unless(kwMeetsPreCondition($kwList1->{TERMS}{$termid}));
###    
###    #  my $text = $kwList->{TERMS}{$termid}{TEXT};
###    foreach my $subAttr1(@attr1Labs){
###      foreach my $subAttr2(@attr2Labs){
###       $val1 = $kwList1->{TERMS}{$termid}->getAttrValue($subAttr1);
###       $val2 = $kwList1->{TERMS}{$termid}->getAttrValue($subAttr2);
###       $at->increment($subAttr2."|".((defined $val2) ? $val2 : "UNDEF"),
###                      $subAttr1."|".((defined $val1) ? $val1 : "UNDEF"));
###      }
###    }
###  }
###  print "Two Factor Analsis of $attr1attr2\n";
###  $at->{Properties}->setValue("SortColKeyTxt", "Alpha");
###  $at->{Properties}->setValue("SortRowKeyTxt", "Alpha");
###  print $at->renderTxtTable(1);
###  print "\n";
###}

### Box plot
sub render_box_plot {
  my $data = shift; #should be { xtic => (min, 1stQ, median, 3rdQ, max, mean) }
  my $plot_name = shift;
  my $xlabel = shift;
  my $ylabel = shift;
  
  my @keys = sort( keys %{ $data } );
  my $plt = "";
  $plt.="set terminal png font arial 10\n";
  $plt.="set bars 2\n";
#  $plt.="set logscale y\n";
  $plt.="set xlabel \\\"$xlabel\\\"\n" if $xlabel;
  $plt.="set ylabel \\\"$ylabel\\\"\n" if $ylabel;
  my $count = 1;
  my $data_str = "";
  my @xtics = ();
  foreach my $xtic (@keys) {
    push @xtics, "\\\"$xtic\\\" $count";
    $data_str.="$count ".join(" ", @{ $data->{$xtic} })."\n";
    $count++;
  }
  $data_str.="e\n";

  $plt.="set xtics (".join(",", @xtics).")\n";
  $plt.="set xtics nomirror rotate by -45\n";
  $plt.="set title \\\"Distribution of $ylabel as a function of $xlabel\\\"\n";
  
  $plt.="plot [0:".(scalar @keys + 1)."] '-' using 1:3:2:6:5 with candlesticks whiskerbars 0.5 lw 2, \\\n";
  $plt.=" '-' using 1:4:4:4:4 with candlesticks lt -4 lc rgbcolor \\\"#0000ff\\\" notitle\n";
  $plt.=$data_str;
  $plt.=$data_str;
  print "Writing box plot: $plot_name.png\n";
  system "echo \"$plt\" | tee $plot_name.plt | gnuplot > $plot_name.png";
}
###

### Scatter plot

sub render_scatter_plot {
  my $data = shift; #should be @ of points
  my $plot_name = shift;
  my $xlabel = shift;
  my $ylabel = shift;

  my $plt = "";
  $plt.="set terminal png large\n";
  $plt.="set style function dots\n";
  $plt.="set xlabel \\\"$xlabel\\\"\n" if $xlabel;
  $plt.="set ylabel \\\"$ylabel\\\"\n" if $ylabel;
  $plt.="plot '-'\n";
  my $data_str = "";
  foreach my $points (@{ $data }) {
    $data_str.="$points\n";
  }
  $data_str.="e\n";
  $plt.=$data_str;

  system "echo \"$plt\" | gnuplot > $plot_name.png";
}

###

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
  print "   Uniq to Set2: ".join(", ",@{ applySetOperations(\@kw1KW_nonorm, \@kw2KW_nonorm, "B - A") })."\n\n";
  foreach my $t(@{ applySetOperations(\@kw1KW_nonorm, \@kw2KW_nonorm, "B - A")}){
    my $term = $kwList2->getTermFromText($t);
    print "      Uniq in Set2: $t ".$term->getAttrValue("TERMID")."\n";
  }
  
  print "Compare the keyword texts WITH Normalization\n";
  my @kw1KW_norm = ();
  my @kw2KW_norm = ();
  foreach my $id(@kw1ids){ my $t = $kwList1->getTermFromID($id); push @kw1KW_norm, $kwList1->normalizeTerm($t->getAttrValue("TEXT")); }
  foreach my $id(@kw2ids){ my $t = $kwList2->getTermFromID($id); push @kw2KW_norm, $kwList2->normalizeTerm($t->getAttrValue("TEXT")); }
  print arrayComparisonReport(\@kw1KW_norm, \@kw2KW_norm, "Set1", "Set2", "   ");
  print "\n";

  print "Compare the keyword texts WITH Normalization AND KWIDs\n";
  @kw1KW_norm = ();
  @kw2KW_norm = ();
  foreach my $id(@kw1ids){ my $t = $kwList1->getTermFromID($id); push @kw1KW_norm, $t->getAttrValue("TERMID")." ".$kwList1->normalizeTerm($t->getAttrValue("TEXT")); }
  foreach my $id(@kw2ids){ my $t = $kwList2->getTermFromID($id); push @kw2KW_norm, $t->getAttrValue("TERMID")." ".$kwList2->normalizeTerm($t->getAttrValue("TEXT")); }
  print arrayComparisonReport(\@kw1KW_norm, \@kw2KW_norm, "Set1", "Set2", "   ");
  print "\n";
  
}

MMisc::ok_quit();
