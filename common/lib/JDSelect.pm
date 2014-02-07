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
  my ($self) = @_;
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


sub dump{
  my    ($self) = @_;
  print "JDS Dump\n";
  print "    totalN=".$self->{TOTALN}."\n";
  print "    DataOutOfMix=".$self->{DATAOUTOFMIX}."\n";
  print "    DataInMix=".$self->{DATAINMIX}."\n";
  print "    Mixtures:\n";
  my $mixAt = new AutoTable();

  foreach my $_fact(@{ $self->{MIXTURENAMES} }){
    foreach my $_lev(sort keys %{ $self->{MIXTURE}{$_fact} }){
	$mixAt->addData($self->{MIXTURE}{$_fact}{$_lev}, "Targ%", "$_fact|$_lev");
	$mixAt->addData($self->{MIXTURE}{$_fact}{$_lev} * $self->{TOTALN}, "Expected", "$_fact|$_lev")
    }
  }
  $mixAt->setRowSort("Alpha");
  $mixAt->setProperties({ "TxtPrefix" => "        "});

  my $at = new AutoTable();
  my %sums = ();
  my $totKey = undef;
  my $rawCountKey = "Raw Count|Total";
  foreach my $_key(sort keys %{ $self->{EXPECTED} }){
    my $_pkey = $_key;
    $_pkey =~ s/_____/|/g;
    if (!defined $totKey){
      ($totKey = $_key) =~ s/_____/|/g;
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
	$mixAt->incrementBy("Selected",$mixFact,$self->{TOSELECT}{$_key})
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
  foreach my $mixFact($mixAt->getRowIDs("AsAdded")){
      $mixAt->addData(sprintf("%.2f",$mixAt->getData("Selected", $mixFact) / $self->{TOTALN}), "Selected%",$mixFact);
      $mixAt->addData(sprintf("%.2f",$mixAt->getData("Targ%", $mixFact) - ($mixAt->getData("Selected", $mixFact) / $self->{TOTALN})), "Deviation%",$mixFact);
  }
  foreach my $totStat(sort keys %sums){
    $at->addData($sums{$totStat}, $totStat, $totKey);
  }
  $at->setProperties({ "SortRowKeyTxt" => "Alpha", "TxtPrefix" => "        "});
  print "    Counts:\n";
  $at->setColSort("Alpha");
  print $at->renderTxtTable(1);
  print "    Univariant Results:\n";
  print $mixAt->renderTxtTable(1);
  
}

sub selectSort{
    return -1 if (exists($a->[2]) && ! exists($b->[2]));
    return 1 if (! exists($a->[2]) && exists($b->[2]));
    if (exists($a->[2]) && exists($b->[2])){
	return ($a->[2] cmp $b->[2]) if ($a->[2] ne $b->[2]);
    }
    return $a->[1] <=> $b->[1];
}

sub getSelection{
  my ($self) = @_;
  my @select = ();
  my $nList = 10;

  ### Build the sorted lists for each key and chop each sorted list into Nlist equal size lists
  my %sortedLists = ();
#  print "Presort\n";
  foreach my $_key(sort keys %{ $self->{TOSELECT} }){
#      print "   $_key\n";
      my $sel = $self->{TOSELECT}{$_key};
      if ($sel > 0){
	  my @list = sort selectSort @{ $self->{COUNT}{$_key} };
	  my $num = @list;
	  for (my $set = 0; $set < $nList; $set ++){
	      my $numToGet = MMisc::max(1,sprintf("%.0f",$num / 10));
#	      print "      Set $set, $numToGet\n";
	      if (@list > 0){
		  if ($set + 1 != $nList){
		      $sortedLists{"set".sprintf("%02d",$set)}{$_key} = [ splice(@list, 0, $numToGet) ];
		  } else {
		      $sortedLists{"set".sprintf("%02d",$set)}{$_key} = [ splice(@list, 0, @list) ];
		  }
	      }
	  }
      }
  }
#  print Dumper(\%sortedLists);

  my $priority = 0; 
  foreach my $_set(sort keys %sortedLists){
      foreach my $_key(sort keys %{ $sortedLists{$_set}}){
	  for (my $i=0; $i<@{ $sortedLists{$_set}{$_key} }; $i++){
	      #print "   Selec $_key $i $sorted[$i][0] $sorted[$i][1] $sorted[$i][2]\n";
	      push @select, [($sortedLists{$_set}{$_key}->[$i][0], $priority++, $_key )];
	  }
      }
  }
#  print Dumper(\@select);

  return \@select;
}


sub unitTest{

  my $jds = new JDSelect();
  $jds->setTotalN(300);
  $jds->setFactorMixtures('Vocab',     { 'InDev-InTrn' => .42, 'InDev-OutOfTrn' => 0.08, 'OutOfDev-OutOfTrn' => .5 });
  $jds->setFactorMixtures('TYPE-BIG3', { 'NAME' => .17,        'NUMBER' => 0.1,          'PHRASE' => .73 });
  $jds->setFactorMixtures('FREQ',      { '0.0-0.5' => .48,     '0.5-1.0' => .48,         '1.0-1.5' => .04});     
  
  my $rnum = 0;
  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NAME',   'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..3)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NAME',   'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
#  foreach (1..1)   { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NAME',   'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand())]); }


  foreach (1..1)   { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..5)   { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
  foreach (1..1)   { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'NUMBER', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand())]); }

  foreach (1..58)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..50)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
  foreach (1..11)  { $jds->addToCount({ 'Vocab' => 'InDev-InTrn',       'TYPE-BIG3' => 'PHRASE', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand())]); }

##########################
  foreach (1..10)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NAME',   'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..50)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NAME',   'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NAME',   'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand())]); }

  foreach (1..3)   { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..1)   { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
  ###foreach (1..1)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn', 'TYPE-BIG3' => 'NUMBER', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand())]); }

  foreach (1..44)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..59)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'InDev-OutOfTrn',    'TYPE-BIG3' => 'PHRASE', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand())]); }

##########################
  foreach (1..158) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NAME',   'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..346) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NAME',   'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
  foreach (1..86)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NAME',   'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand())]); }

  foreach (1..3)   { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..64)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NUMBER', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
  foreach (1..163) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'NUMBER', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand())]); }

  foreach (1..219) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.0-0.5'}, [("REF=".$rnum++, rand())]); }
  foreach (1..10) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand(), "tier1")]); }
  foreach (1..20) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand(), "tier2")]); }
  foreach (1..10) { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '0.5-1.0'}, [("REF=".$rnum++, rand())]); }
  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '1.0-1.5'}, [("REF=".$rnum++, rand(), "tier1")]); }

  foreach (1..13)  { $jds->addToCount({ 'Vocab' => 'OutOfDev-OutOfTrn', 'TYPE-BIG3' => 'PHRASE', 'FREQ' => '1.0'}, [("REF=".$rnum++, rand())], 1); }

  $jds->calculateExpected();

  my @selected = $jds->getSelection();

  $jds->dump();
  print Dumper(\@selected);
}

1;
