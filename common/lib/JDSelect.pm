# F4DE Package
#
# $Id$
#
# JDSelect.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
#
# F4DE is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  


# Description:
#  

# JDSelect is a tool to control the random selection of elements ensuring
# the outcome closely matches the specified profile described by a joint
# distribtion derived from a set of factors each with univariate densities.  

# 1. The selection percentage:

# Each factor has a set of discrete "levels" each with a target proportion of
# data to select. For instance, the factor /duration/ could have three
# levels with the corresponding proportions:

#    '0.0-0.5' => .48,     '0.5-1.0' => .48,         '1.0-1.5' => .04

# The proportions of a given factor must sum to 1.

# Using the set of factors, JDSelect enumerates all combinations of
# factor levels and computes the combination proportion for the combined
# factor levels by multiplying the univariate porportions together.

# 2. The selection elements:

# The elements to select are added to the object specifying through the
# addToCount() method.  The method takes two arguements:
#   ARG1: a hash table specifying the levels of each factor for the element.  
#   ARG2: an array reference where:
#       ARG2[0] = the label of the element
#       ARG2[1] = the ordering number.  The ordering number can be build by
#                 any means: random, stratified random, etc.
#       ARG2[2] = the optional strata id for the element.  The sorting order 
#                 uses the strata id as the major sort, and the ordering nunmbers
#                 as the minor sort key.  Elements without a strata are selected
#                 last.

# 3. The selection:

# Using the supplied total number of elements to select, N, the
# elements to select for a given factor level combination, K, is N *
# the combination proportion.  JDSelect selects the K elements for the
# factor level combination by sorting the element ordering numbers in
# assending order.







package JDSelect;

use strict;

use Data::Dumper;
use AutoTable;
use MMisc;
use Statistics::Descriptive;
use Statistics::Descriptive::Discrete;


sub new {
  my ($class) = @_;
  
  my $errormsg = new MErrorH("PropList");
  my $at = new AutoTable();

  my $self =
  {
    TOTALN      => undef,
    COUNT       => {},
    UNIVARIATECOUNT => {},
    MIXTURE     => {},
    DATAOUTOFMIX   => 0,
    DATAINMIX   => 0,
  };
  
  bless $self;
  return $self;
}

sub setTotalN{
  my ($self, $totalN) = @_;
  $self->{TOTALN} = $totalN
  
}

sub setFactorMixtures{
  my ($self, $factName, $factHT) = @_;

  push @{ $self->{MIXTURENAMES} }, $factName;
  $self->{MIXTURE}{$factName} = $factHT;
  ### Check to make sure sum to 1
  my $sum = 0;
  foreach my $_key(sort keys %$factHT){
    $sum += $factHT->{$_key};
  }
  MMisc::error_quit("Factor mixture for $factName does not sum to 1 (it is $sum)") 
   if (abs(1 - $sum) > 0.001);

}

sub addToCount{
  my ($self, $coordHT, $dataArr, $skipIfFactorNotDefined) = @_;
  ### dataArr = (id, order, tier)  
  ###           tier = undef -> "tier1"

  my $key = "";
  my $outOfMix = 0;
  foreach my $_fact(@{ $self->{MIXTURENAMES} }){
    MMisc::error_quit("Factor $_fact not found in coordinateHT\n".Dumper($coordHT)) 
	if (! exists($coordHT->{$_fact}));
    if (! exists($self->{MIXTURE}{$_fact}{$coordHT->{$_fact}})){
	if ( $skipIfFactorNotDefined == 1){
	    $outOfMix = 1;
	} else {
	    MMisc::error_quit("Value ($coordHT->{$_fact}) for Factor $_fact not found in MIXTURE\n".Dumper($self->{MIXTURE}{$_fact}));
	}
    }
    $key .= "_____" if ($key ne "");
    $key .= $coordHT->{$_fact};    
  }
  if ($outOfMix){
      $self->{DATAOUTOFMIX} ++;
      push @{ $self->{OUTOFMIXCOUNT}{$key} }, $dataArr;
  } else {
      $self->{DATAINMIX} ++;
      push @{ $self->{COUNT}{$key} }, $dataArr;
      if (defined($dataArr->[2])){
	  $self->{SELECTTIERS}{$dataArr->[2]} = 1;
      }
  }
  
  # Record the univariatn stats including in vs. out distinction
  foreach my $_fact(@{ $self->{MIXTURENAMES} }){
      my $out = ($outOfMix ? "OUT" : "IN");
      my $val = "UNK";
      if (exists($coordHT->{$_fact}) && $coordHT->{$_fact} ne ""){ # && exists($self->{MIXTURE}{$_fact}{$coordHT->{$_fact}})){
	  $val = $coordHT->{$_fact};					  
      }
      $self->{UNIVARIATECOUNT}{$_fact}{VAL}{$val}{$out} ++;
  }
}

sub combinations{
  my($arrs) = @_;
  my @combs = ();

  ### Setup the pointers
  my @_ptr = ();
  foreach (@$arrs){ push @_ptr, 0 };
  my $done = 0;
  do {
    my @_a = ();
    foreach (0..$#$arrs){ push @_a, "$arrs->[$_][$_ptr[$_]]" };
#    print "  comb=".join(", ",@_a)."\n";
    push @combs, \@_a;

    ## Increment
    my $change = 1;
    $_ptr[$#$arrs] ++;
    while ($change){
      $change = 0;
      for ($_ = $#$arrs; $_ >= 0; $_--){
	if ($_ptr[$_] > $#{ $arrs->[$_] }){
	  $change = 1;
	  $_ptr[$_] = 0;
	  if ($_ == 0){
	    $done = 1;	    
	  } else {
	    $_ptr[$_-1] ++;
	  }
	}	  
      }
      
    }
  } while (! $done);
  return \@combs;
}

sub getMixtureForValue{
  my ($self, $fact, $value) = @_;
  return $self->{MIXTURE}{$fact}{$value};
}

sub calculateExpected{
  my ($self, $doPass2) = @_;
  my $vb = 0;

  my @factArrs = ();
  my @factIDs = ();

  foreach my $_fact(@{ $self->{MIXTURENAMES} }){
    push @factArrs, [ sort keys %{ $self->{MIXTURE}{$_fact} } ];
    push @factIDs, $_fact;
  }
  print Dumper(\@factArrs) if ($vb);
  foreach my $combArr(@{ combinations(\@factArrs) }){
    my $key = join("_____",@$combArr);
#    print "exp $key\n";
    my $exp = $self->{TOTALN};
    for (my $fid=0; $fid < @$combArr; $fid++){
      my $mix = $self->getMixtureForValue($factIDs[$fid], $combArr->[$fid]);
#      print "   mix[$factIDs[$fid]][val=$combArr->[$fid]] = $mix\n";
      $exp *= $mix;
      $self->{MIXTUREKEYLUT}{$key}{$factIDs[$fid]."|".$combArr->[$fid]} = 1;
    }
#    print "      exp = $exp\n";
    $self->{EXPECTED}{$key} = $exp;
    if ($exp < 0.01){
      $self->{EXPECTEDINT}{$key} = 0;
    } else {
      $self->{EXPECTEDINT}{$key} = sprintf("%.0d",$exp+0.5);
      $self->{EXPECTEDINT}{$key} = 1 if ($self->{EXPECTEDINT}{$key} =~ /^(|0)$/);
    } 
    my $avail  = (exists($self->{COUNT}{$key})       ? scalar(@{ $self->{COUNT}{$key} }) : 0);
    $self->{TOSELECTINIT}{$key} = MMisc::min($self->{EXPECTEDINT}{$key}, $avail);
    $self->{TOSELECTUNDERAGE}{$key} = ($avail < $self->{EXPECTEDINT}{$key} ? ($avail - $self->{EXPECTEDINT}{$key}) : "");
    $self->{TOSELECTADD}{$key} = 0;
    $self->{TOSELECT}{$key}  =  $self->{TOSELECTADD}{$key} + $self->{TOSELECTINIT}{$key};
  }

  print "###Start to redistribute\n" if ($vb);
  
  if ($doPass2){
    my $redist = @factArrs-1;
    while ($redist > 0){
      my @topFactArrs = ();
      my @botFactArrs = ();
      for ($_ = 0; $_<$redist; $_++) {          push @topFactArrs, $factArrs[$_] }
      for ($_ = $redist; $_<@factArrs; $_++) { push @botFactArrs, $factArrs[$_] }
      # Compute the shortfall
      my $leftovers = 0;
      foreach my $topComb(@{ combinations(\@topFactArrs) }){
	print "   ".join(", ",@$topComb)."\n" if ($vb);
	my ($expInt, $toSelInit, $toSelAdd, $avail, $short) = (0, 0, 0, 0, 0);
	my $cntBot = 0;
	foreach my $botComb(@{ combinations(\@botFactArrs) }){
	  $cntBot ++;
	  print "       ".join(", ",@$botComb)."\n" if ($vb);
	  my $key = join("_____",@$topComb, @$botComb);
	  $expInt += $self->{EXPECTEDINT}{$key};
	  $toSelInit  += $self->{TOSELECTINIT}{$key};
	  $toSelAdd  += $self->{TOSELECTADD}{$key};
	  my $realAvail   = (exists($self->{COUNT}{$key})       ? scalar(@{ $self->{COUNT}{$key} }) : 0);
	  if ($realAvail > ($self->{TOSELECTINIT}{$key}) + $self->{TOSELECTADD}{$key} ){
	    $avail ++;  ### There's some to select somewhere
	  }
	}
	$short = $expInt - ($toSelInit + $toSelAdd);
	print "           Short = $short for $cntBot divisions\n" if ($vb);
	my $resid = $short;
	while ($avail > 0 && $resid > 0){
	  $avail = 0;
	  foreach my $botComb(@{ combinations(\@botFactArrs) }){
	    my $key = join("_____",@$topComb, @$botComb);
	    my $realAvail   = (exists($self->{COUNT}{$key})       ? scalar(@{ $self->{COUNT}{$key} }) : 0);
	    my $selected    = $self->{TOSELECTINIT}{$key} + $self->{TOSELECTADD}{$key};
	    if ($selected < $realAvail){
	      ### Add one
	      $self->{TOSELECTADD}{$key} ++;
	      $self->{TOSELECT}{$key}  =  $self->{TOSELECTADD}{$key} + $self->{TOSELECTINIT}{$key};
	      $resid--;
	      $avail = 1 if ($selected + 1 < $realAvail);  ### Is there more
	      print "               Adding one to ".$key."\n" if ($vb);
	    }
	  }
	}
	if ($resid > 0){
	  print "Warning: Resid is $resid for ".join("_____",@$topComb)."[*].  Redistributing to a higher factor \n" if ($vb);
	  $leftovers = 1;	
	}
      }
      if ($leftovers) {
	$redist --;
      } else {
	$redist = -1;
      }
    }
  }
}


sub dump{
  my  ($self, $rootOutput, $setID) = @_;
  print "JDS Dump\n";
  print "    totalN=".$self->{TOTALN}."\n";
  print "    DataOutOfMix=".$self->{DATAOUTOFMIX}."\n";
  print "    DataInMix=".$self->{DATAINMIX}."\n";
  print "    RootOutput=$rootOutput\n";
  print "    Mixtures:\n";
  my $mixAt = new AutoTable();

  foreach my $_fact(@{ $self->{MIXTURENAMES} }){
    foreach my $_lev(sort keys %{ $self->{MIXTURE}{$_fact} }){
	$mixAt->addData($self->{MIXTURE}{$_fact}{$_lev}, "Results|Targ%", "$setID|$_fact|$_lev");
	$mixAt->addData($self->{MIXTURE}{$_fact}{$_lev} * $self->{TOTALN}, "Results|Expected", "$setID|$_fact|$_lev")
    }
  }
  $mixAt->setRowSort("Alpha");
  $mixAt->setProperties({ "TxtPrefix" => "        "});

  my $at = new AutoTable();
  my %sums = ();
  my $totKey = undef;
  my $rawCountKey = "Raw Count|Total";
  foreach my $_key(sort keys %{ $self->{EXPECTED} }){
    my $_pkey = "$setID|".$_key;
    $_pkey =~ s/_____/|/g;
    if (!defined $totKey){
      ($totKey = "$setID|".$_key) =~ s/_____/|/g;
      $totKey =~ s/[^\|]+/__SUM__/g;      
    }
    if (exists($self->{COUNT}{$_key})){
      $at->addData(scalar(@{ $self->{COUNT}{$_key}}), $rawCountKey, $_pkey);
      if (!exists($sums{$rawCountKey})){
	  $sums{$rawCountKey} = 0;
	  foreach my $tier(sort keys %{ $self->{SELECTTIERS} }){
	      $sums{"Raw Count|$tier"} = 0;
	  }
      }
      foreach my $dat(@{ $self->{COUNT}{$_key}}){
	  $sums{$rawCountKey} ++;
	  if (defined($dat->[2])){
	      $at->increment("Raw Count|$dat->[2]", $_pkey);
	      $sums{"Raw Count|$dat->[2]"} ++;
	  }
      }
    }
    foreach my $mixFact(keys %{ $self->{MIXTUREKEYLUT}{$_key} }){
	$mixAt->incrementBy("Results|Selected","$setID|".$mixFact,$self->{TOSELECT}{$_key})
    }

    foreach my $stat("EXPECTED", "EXPECTEDINT", "TOSELECTINIT", "TOSELECTUNDERAGE", "TOSELECTADD", "TOSELECT"){
      my $statID = "Expected|$stat";
      $statID = "Select|$stat" if ($stat =~ /TOSELEC/);
      if (exists($self->{$stat}{$_key})){
	$at->addData($self->{$stat}{$_key}, $statID, $_pkey);
	$sums{$statID} = 0 if (!exists($sums{$statID}));
	$sums{$statID} += ($self->{$stat}{$_key} ne "" ? $self->{$stat}{$_key} : 0);
      }     
      if ($stat eq "TOSELECT"){
	  $statID = "Select|TOSELECT-deviation";
	  $at->incrementBy($statID, $_pkey, $self->{$stat}{$_key});
	  $sums{$statID} = 0 if (!exists($sums{$statID}));
	  $sums{$statID} += ($self->{$stat}{$_key} ne "" ? $self->{$stat}{$_key} : 0);
      }
      if ($stat eq "EXPECTEDINT"){
	  $statID = "Select|TOSELECT-deviation";
	  $at->incrementBy($statID, $_pkey, -$self->{$stat}{$_key});
	  $sums{$statID} = 0 if (!exists($sums{$statID}));
	  $sums{$statID} += ($self->{$stat}{$_key} ne "" ? -$self->{$stat}{$_key} : 0);
      }
    }
  }
  ### Calc the selected for a factor
  my %factCount = ();
  foreach my $mixFact($mixAt->getRowIDs("AsAdded")){
    my ($set, $fact, $lev) = split(/\|/, $mixFact);
    $factCount{$fact} += $mixAt->getData("Results|Selected", $mixFact);
    #  $mixAt->addData(sprintf("%.2f",$mixAt->getData("Results|Selected", $mixFact) / $self->{TOTALN}), "Results|Selected%",$mixFact);
    #  $mixAt->addData(sprintf("%.2f",($mixAt->getData("Results|Selected%", $mixFact) - $mixAt->getData("Results|Targ%", $mixFact)) ), "Results|DeviationFromExp%",$mixFact);
  }
  foreach my $mixFact($mixAt->getRowIDs("AsAdded")){
    my ($set, $fact, $lev) = split(/\|/, $mixFact);
    $mixAt->addData(sprintf("%.2f",($mixAt->getData("Results|Selected", $mixFact) / $factCount{$fact}) ), "Results|Selected%",$mixFact);
    $mixAt->addData(sprintf("%.2f",($mixAt->getData("Results|Selected%", $mixFact) - $mixAt->getData("Results|Targ%", $mixFact)) ), "Results|DeviationFromExp%",$mixFact);
  }
#  print Dumper(\%factCount); exit;  
  ## add the input univariate counts
  foreach my $fact(keys %{ $self->{UNIVARIATECOUNT} }){
      foreach my $k(keys %{ $self->{UNIVARIATECOUNT}{$fact}{VAL} }){
	  my $mixFact = "$setID|$fact|$k";
	  foreach my $o(keys %{ $self->{UNIVARIATECOUNT}{$fact}{VAL}{$k} }){
	      $mixAt->addData($self->{UNIVARIATECOUNT}{$fact}{VAL}{$k}{$o}, "Inputs|$o Mixture", $mixFact);
	      if ($o eq "IN"){
		  my $res = $self->{UNIVARIATECOUNT}{$fact}{VAL}{$k}{$o} - $mixAt->getData("Results|Selected", $mixFact);
		  $mixAt->addData($res, "Inputs|$o Mixture Not Selected", $mixFact);
		  $mixAt->addData(sprintf("%.1f",$self->{UNIVARIATECOUNT}{$fact}{VAL}{$k}{$o} / $mixAt->getData("Results|Targ%", $mixFact)), "Capacity|Maximum N", $mixFact);
	      }
	  }
       }
   }

  foreach my $totStat(sort keys %sums){
    $at->addData($sums{$totStat}, $totStat, $totKey);
  }
  $at->setProperties({ "SortRowKeyTxt" => "Alpha", "TxtPrefix" => "        "});
  print "    Univariate Results:\n";
  print $mixAt->renderTxtTable(1);
  MMisc::writeTo($rootOutput, ".Univariate.tgrid", 1, 0, $mixAt->renderByType("tgrid")) if (defined($rootOutput));

  print "\n    Multivariate Counts:\n";
  $at->setColSort("Alpha");
  print $at->renderTxtTable(1);
  MMisc::writeTo($rootOutput, ".MultiVariate.tgrid", 1, 0, $at->renderByType("tgrid")) if (defined($rootOutput));
#  print Dumper($self->{UNIVARIATECOUNT});  

}

sub selectSort{
    return -1 if (exists($a->[2]) && ! exists($b->[2]));
    return 1 if (! exists($a->[2]) && exists($b->[2]));
    if (exists($a->[2]) && exists($b->[2])){
	return ($a->[2] cmp $b->[2]) if ($a->[2] ne $b->[2]);
    }
    return $a->[1] <=> $b->[1];
}

### $nList is the number of element sets to output in the selection array.  This stratifies the 
### selection so that IF a process needs to prioritize usage of the selected elements, sequentially 
### processing the selection list maintains a balanced usage accross all factor level combinations.
sub getSelection{
  my ($self, $nList) = @_;
  my @select = ();

  ### Build the sorted lists for each key and chop each sorted list into Nlist equal size lists
  my %sortedLists = ();
#  print "Presort\n";
  foreach my $_key(sort keys %{ $self->{TOSELECT} }){
      my $sel = $self->{TOSELECT}{$_key};
      my $selPerSet = $sel / $nList;
#      print "   $_key -> $sel to select\n";
      if ($sel > 0){
	  my @list = sort selectSort @{ $self->{COUNT}{$_key} };
	  my $num = @list;
	  my $numConsumed = 0;
	  for (my $set = 0; $set < $nList; $set ++){
	      my $numToGet = MMisc::max(1,sprintf("%.0f",($selPerSet * ($set + 1)) - $numConsumed ));
#	      print "      Set $_key, set$set, numConsumed=$numConsumed, $numToGet of $num (".scalar(@list)." really)\n";
	      if (@list > 0){
		  if ($set + 1 != $nList){
		      $sortedLists{"set".sprintf("%02d",$set)}{$_key} = [ splice(@list, 0, $numToGet) ];
		  } else {
		      $sortedLists{"set".sprintf("%02d",$set)}{$_key} = [ splice(@list, 0, @list) ];
		  }
		  $numConsumed += scalar(@{ $sortedLists{"set".sprintf("%02d",$set)}{$_key} });
	      }
	  }
      }
  }
#  print Dumper(\%sortedLists);

  my $priority = 0; 
  my %needed = ();
  my %neededInit = ();
  foreach my $_key(sort keys %{ $self->{TOSELECT} }){
    $needed{$_key} = $self->{TOSELECT}{$_key};
    $neededInit{$_key} = $self->{TOSELECTINIT}{$_key};
  }

  foreach my $_set(sort keys %sortedLists){
      foreach my $_key(sort keys %{ $sortedLists{$_set}}){
	  for (my $i=0; $i<@{ $sortedLists{$_set}{$_key} }; $i++){
	      #print "   Selec $_key $i $sorted[$i][0] $sorted[$i][1] $sorted[$i][2]\n";
	    if ($needed{$_key} > 0){
	      my $selectPhase = ($neededInit{$_key} > 0) ? "Phase1Init" : "Phase2Add";
	      push @select, [($sortedLists{$_set}{$_key}->[$i][0], $priority++, $_key, $selectPhase, $_set )];
	      $needed{$_key} --;
	      $neededInit{$_key} --;
	    }
	  }
      }
  }
#  print Dumper(\@select);

  return \@select;
}


sub unitTest{
  my $jds = new JDSelect();
  $jds->setTotalN(100);
  $jds->setFactorMixtures('Vocab',     { 'InDev-InTrn' => .42, 'InDev-OutOfTrn' => 0.08, 'OutOfDev-OutOfTrn' => .5 });
  $jds->setFactorMixtures('TYPE-BIG3', { 'NAME' => .17,        'NUMBER' => 0.1,          'PHRASE' => .73 });
  $jds->setFactorMixtures('FREQ',      { '0.0-0.5' => .48,     '0.5-1.0' => .48,         '1.0-1.5' => .04});     
  
  my $rnum = 0;
  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NAME',   'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..3)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NAME',   'FREQ' => '0.5-1.0'}, [("REF=".$rnum, $rnum++)]); }
#  foreach (1..1)   { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NAME',   'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }


  foreach (1..1)   { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..5)   { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..1)   { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NUMBER', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }

  foreach (1..58)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..50)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..11)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'PHRASE', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }

##########################
  foreach (1..10)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NAME',   'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..50)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NAME',   'FREQ' => '0.5-1.0'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NAME',   'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }

  foreach (1..3)   { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..1)   { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum, $rnum++)]); }
  ###foreach (1..1)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn', 'TYPE-BIG3' => 'NUMBER', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }

  foreach (1..44)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..59)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'PHRASE', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }

##########################
  foreach (1..158) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NAME',   'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..346) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NAME',   'FREQ' => '0.5-1.0'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..86)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NAME',   'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }

  foreach (1..3)   { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..64)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..163) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NUMBER', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }

  foreach (1..219) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum, $rnum++)]); }
  foreach (1..10)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum.".notier", $rnum++)]); }
  foreach (1..10)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum.".tier1", $rnum++, "tier1")]); }
  foreach (1..5)   { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum.".tier2", $rnum++, "tier2")]); }
  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum, $rnum++)]); }

  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '1.0'}, [("REF=".$rnum, $rnum++)], 1); }

  print "Calculating the expected sizes\n";
  $jds->calculateExpected(0);

  my $selected = $jds->getSelection(10);

  $jds->dump(undef, "test");
  print scalar(@$selected)." elements selected\n";
  for (my $s=0; $s < @$selected; $s++){
    print join(",", @{ $selected->[$s] })."\n";
  }
#  print Dumper($jds);
}

1;
