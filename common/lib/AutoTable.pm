package AutoTable;

#  Auto Table
#
# Original Author: Jonathan Fiscus 
# Adds: Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AutoTable.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

# $Id$

use strict;

use MErrorH;
use PropList;
#use CSVHelper;

use Data::Dumper;


my $key_KeyColumnTxt = "KeyColumnTxt";
my $key_KeyColumnCsv = "KeyColumnCsv";
my $key_SortRowKeyTxt = "SortRowKeyTxt";
my $key_SortRowKeyCsv = "SortRowKeyCsv";
my $key_SortColKeyTxt = "SortColKeyTxt";
my $key_SortColKeyCsv = "SortColKeyCsv";

sub new {
  my ($class) = shift @_;

  my $errormsg = new MErrorH("AutoTable");

  my $self =
    {
     hasData => 0,
     data => { },
     rowLabOrder => 
     {
      ThisIDNum    => 0,
      SubIDCount   => 0,
      SubID        => {},
      width        => { charLen => 0 },
     },
     colLabOrder => 
     {
      ThisIDNum    => 0,
      SubIDCount   => 0,
      SubID        => {},
      width        => { charLen => 0 },
     },
     Properties  => new PropList(),
     errormsg    => $errormsg,
    };

  bless $self;

  $self->{Properties}->addProp($key_KeyColumnCsv, "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_KeyColumnTxt, "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_SortRowKeyTxt, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortRowKeyCsv, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortColKeyTxt, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortColKeyCsv, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->_set_errormsg($self->{Properties}->get_errormsg());

  return($self);
}

##########

sub setProperties(){
  my ($self, $propHT) = @_;
    
  if (! $self->{Properties}->setValueFromHash($propHT)) {
    $self->_set_erromsg("Could not set Properties: ",$self->{Properties}->get_errormsg());
    return (0);
  }
  return (1);
}
    
##########

sub unitTest {
  my $makecall = shift @_;

  print "Testing AutoTable ..." if ($makecall);

  my $sg = new AutoTable();
  $sg->addData("1",  "abcdefghijabcdefghijabcdefghijabcdefghij|A|col1", "Sub|PartZ|ObjectPut");
  $sg->addData("2",  "abcdefghijabcdefghijabcdefghijabcdefghij|A|col2", "Sub|PartZ|ObjectPut");
  $sg->addData("5",  "abcdefghijabcdefghijabcdefghijabcdefghij|A|col1", "Sub|PartYY|PeopleSplitUp");
  $sg->addData("6",  "abcdefghijabcdefghijabcdefghijabcdefghij|A|col2", "Sub|PartYY|PeopleSplitUp");
  $sg->addData("9",  "PartA|012345678901234567890123456789012345|col1", "Sub|PartZ|PersonRuns");
  $sg->addData("10", "PartA|012345678901234567890123456789012345|col2", "Sub|PartZ|PersonRuns");
  $sg->addData("13", "PartA|012345678901234567890123456789012345|col1", "Sub|PartYY|Pointing");
  $sg->addData("12", "PartA|012345678901234567890123456789012345|col2", "Sub|PartYY|Pointing");

  $sg->addData("3",  "PartB|Aletsmakethisbiggg|col3", "Sub|PartZ|ObjectPut");
  $sg->addData("4",  "PartB|Aletsmakethisbiggg|col4", "Sub|PartZ|ObjectPut");
  $sg->addData("7",  "PartB|Aletsmakethisbiggg|col3", "Sub|PartYY|PeopleSplitUp");
  $sg->addData("8",                 "PartB|B|col4", "Sub|PartYY|PeopleSplitUp");
  $sg->addData("11",                "PartB|B|col3", "Sub|PartZ|PersonRuns");
  $sg->addData("12",                "PartB|B|col4", "Sub|PartZ|PersonRuns");
  $sg->addData("15",                "PartB|B|col3", "Sub|PartYY|Pointing");
  $sg->addData("16454433333333334", "PartB|B|col4", "Sub|PartYY|Pointing");
  $sg->addData("16454433333333334", "PartB|ThisIsBig|col4", "Sub|PartYY|Pointing");

  if (1){
      $sg->addData("5",  "abcdefghijabcdefghijabcdefghijabcdefghij|A|col1", "Bus|PartYY|PeopleSplitUp");
      $sg->addData("6",  "abcdefghijabcdefghijabcdefghijabcdefghij|A|col2", "Bus|PartYY|PeopleSplitUp");
      $sg->addData("13", "PartA|012345678901234567890123456789012345|col1", "Bus|PartYY|Pointing");
      $sg->addData("12", "PartA|012345678901234567890123456789012345|col2", "Bus|PartYY|Pointing");
      
      $sg->addData("7",  "PartB|Aletsmakethisbiggg|col3", "Bus|PartYY|PeopleSplitUp");
      $sg->addData("8",                 "PartB|B|col4", "Bus|PartYY|PeopleSplitUp");
      $sg->addData("15",                "PartB|B|col3", "Bus|PartYY|Pointing");
      $sg->addData("16454433333333334", "PartB|B|col4", "Bus|PartYY|Pointing");
      $sg->addData("16454433333333334", "PartB|ThisIsBig|col4", "Bus|PartYY|Pointing");
      
      $sg->{Properties}->setValue($key_SortColKeyTxt, "Alpha");
      $sg->{Properties}->setValue($key_SortRowKeyTxt, "Alpha");
  }
  ### Get the order of column

#  my $colLabTree = $sg->_buildLabelHeir("col", "Alpha");
  
  if (! $makecall) {
#      $sg->dump();
      print($sg->renderTxtTable(2));
  }

  MMisc::ok_quit(" OK");

}

sub _buildHeir(){
    my ($self, $gap) = @_;

    $self->_buildLabelHeir("col", $gap);
    $self->_buildLabelHeir("row", $gap);
}

sub renderTxtTable(){
    my ($self, $gap) = @_;

    my $out = "";
    $self->_buildHeir($gap);

#    print Dumper($self);
    my @IDs = $self->{render}{colIDs};
    my $levels = $self->{render}{colLabelLevels};
    my @nodeSet;
    die "Internal Error: No levels defined" if ($levels < 1);
    for (my $level=0; $level < $levels; $level++){
	### Render the row data
	for (my $rowLevel=0; $rowLevel < @{ $self->{render}{rowLabelWidth} }; $rowLevel++){
	    $out .= $self->_centerJust("", $self->{render}{rowLabelWidth}->[$rowLevel]);    
	    $out .= $self->_centerJust("", $gap); 
	}
	$out .= "|";

	### Render the col data
	my $tree = $self->{render}{colLabelHeir}; 
	@nodeSet = @{ $tree->{nodes} };
	
	my $searchLevel = $level;
	while ($searchLevel > 0){
	    my @stack = @nodeSet;
	    @nodeSet = ();
	    foreach my $nd(@stack){ 
		push @nodeSet, @{ $nd->{nodes} };
	    }
	    $searchLevel --;
	}
	
	for (my $node=0; $node < @nodeSet; $node ++){
	    $out .= $self->_centerJust($nodeSet[$node]{id}, $nodeSet[$node]{width});
	    $out .= "|" if ($node < @nodeSet - 1);	    
	}
	$out .= "|\n";
    }
    ### The separator
    for (my $rowLevel=0; $rowLevel < @{ $self->{render}{rowLabelWidth} }; $rowLevel++){
	$out .= $self->_nChrStr($self->{render}{rowLabelWidth}->[$rowLevel] + $gap, "-");
    }
    $out .= "+";
    for (my $node=0; $node<@nodeSet; $node++) {
	$out .= "" . $self->_nChrStr($nodeSet[$node]{width},"-") . "+";
    }    
    $out .= "\n";

    #### NOW: @nodeSet is the formatting informatlion for the columns!!!
    my @colIDs = ();  ####$self->_getOrderedLabelIDs($self->{"colLabOrder"}, "AsAdded");
    foreach my $nd(@nodeSet){ 
	push @colIDs, $nd->{subs}[0];
    }
    #    print "ColIDs ".join(" ",@colIDs)."\n";
#    print join(" ",@colIDs)."\n";
    my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, "Alpha"); #$rowSort);
#    print join(" ",@rowIDs)."\n";
    my @lastRowLabel = ();
    foreach my $rowIDStr (@rowIDs) {
#	if (! $r1c) {
#	    for (my $c=1; $c<=$numRowLev; $c++) {
#	    for (my $c=1; $c<=1; $c++) {
#		$out .= $self->_leftJust($rowIDStr, $maxRowLabWidth);
#	    }
#	    $out .= "|";
#	}
	### Render the row header column 
	if (1){
	    my @ids = split(/\|/, $rowIDStr);
	    my $print = 1;
	    for (my $rowLevel=0; $rowLevel < @{ $self->{render}{rowLabelWidth} }; $rowLevel++){
		$lastRowLabel[$rowLevel] = "" if (! defined($lastRowLabel[$rowLevel]));

		$print = 1;
		if ($lastRowLabel[$rowLevel] eq $ids[$rowLevel]){
		    $print = 0;
		} else {
		    ### if we print a level, then print all levels below
		    for (my $trl=$rowLevel+1; $trl < @{ $self->{render}{rowLabelWidth} }; $trl++){
			$lastRowLabel[$trl] = "";
		    }
		}

		$out .= $self->_leftJust($print ? $ids[$rowLevel] : "", $self->{render}{rowLabelWidth}->[$rowLevel]);    
#		$out .= $self->_leftJust("", $gap) if ($rowLevel != 0);
		$out .= $self->_leftJust("", $gap);

		$lastRowLabel[$rowLevel] = $ids[$rowLevel];
	    }
	    $out .= "|";
	}
	for (my $node=0; $node<@nodeSet; $node++) {
	    $out .= " " . $self->_rightJust($self->{data}{$rowIDStr."-".$nodeSet[$node]{subs}[0]}, $nodeSet[$node]{width} - 2) . " |";
	}
      
	$out .= "\n";
    }   
    $out;
}

sub _buildLabelHeir(){
    my ($self, $colVrow, $gap) = @_;

    my ($labHT, @IDs, $levels);
    if ($colVrow eq "col") {
	$labHT = $self->{"colLabOrder"};
	@IDs = $self->_getOrderedLabelIDs($labHT, $self->{Properties}->getValue($key_SortColKeyTxt));
    } else {
	$labHT = $self->{"rowLabOrder"};
	@IDs = $self->_getOrderedLabelIDs($labHT, $self->{Properties}->getValue($key_SortRowKeyTxt));
    }

    my $levels = scalar( @{ $labHT->{SubID}{$IDs[0]}{labels} } );
    foreach my $id(@IDs){
	die "[AutoTable] Error: Inconsistent number of $colVrow sublevels for id '$id' not $levels\n"
	    if ($levels != scalar( @{ $labHT->{SubID}{$id}{labels} } ));
    } 
#    print Dumper($self);
#    print "Num of levels $levels \n";
    
    if ($colVrow eq "col") {
	my ($tree, $subWidth) = $self->_buildTree(\@IDs, $labHT, 0, $levels, 0, $gap);
	
	$self->{render}{colIDs} = \@IDs;
	$self->{render}{colLabelHeir} = $tree;
	$self->{render}{colLabelLevels} = $levels;
    } else {
	$self->{render}{rowIDs} = \@IDs;
	$self->{render}{rowLabelLevels} = $levels;
	$self->{render}{rowLabelWidth} = [()];
	for (my $level = 0; $level < $levels; $level++){
	    $self->{render}{rowLabelWidth}->[$level] = 0;
	}
	### Row widths are simpler!!!
	foreach my $id(@IDs){
	    for (my $level = 0; $level < $levels; $level++){
		my $len = length($labHT->{SubID}{$id}{labels}[$level]);
		$self->{render}{rowLabelWidth}->[$level] = $len if ($len > $self->{render}{rowLabelWidth}->[$level]);
#		print "$id $level $len ".$self->{render}{rowLabelWidth}->[$level]."\n";
	    }
	}
    }

#    print "Total Width = $subWidth\n";
}

sub _buildTree(){
    my ($self, $ids, $labHT, $level, $maxLevel, $minWidth, $gap) = @_;
    my ($Vb) = 0;
    my $pre = sprintf("%".(($level+1)*3)."s","");
    print $pre.join(",",@$ids)." $level, $maxLevel  minWidth=$minWidth\n" if ($Vb);
    my %tree = ();
    ### begin the tree with all root nodes
    my $lastLab = "";
    my $nodeCnt = 0;
    foreach my $id(@$ids){
	my $sLab = $labHT->{SubID}{$id}{labels}[$level];
	print $pre."sLab $sLab\n" if ($Vb);
	if ($lastLab ne $sLab){
	    push @{ $tree{nodes} }, { subs => [()], level => $level, id => $sLab, width => -1};
	}
	$lastLab = $sLab;
	push (@{ $tree{nodes}[$#{ $tree{nodes} } ]{subs}  }, $id);
    }
    
    ### Start the recursions on independent columns

    if ($level+1 < $maxLevel){
	my $thisWidth = 0;
	my @computedWidth = ();
	for (my $node=0; $node<@{ $tree{nodes} }; $node ++){
	    print $pre."Recursing node $node ".$tree{nodes}[$node]{id}."\n" if ($Vb);

	    my ($data, $subWidth) = $self->_buildTree($tree{nodes}[$node]{subs} , $labHT, $level+1, $maxLevel, length($tree{nodes}[$node]{id}) + $gap*2, $gap);
	    $tree{nodes}[$node]{nodes} = $data->{nodes};
	    $tree{nodes}[$node]{width} = $subWidth;
	    $thisWidth += $tree{nodes}[$node]{width};
	    $thisWidth += 1 if ($node != 0);  #  Separator
	    $computedWidth[$node] = $tree{nodes}[$node]{width};
	    print $pre."  subwidth = $subWidth    thisWidth = $thisWidth  minWidth=$minWidth\n" if ($Vb);
	}
	if ($minWidth > $thisWidth){
	    print $pre."   minWidth $minWidth > thisWidth $thisWidth... recommputing\n" if ($Vb);
	    my $totResid = $minWidth - $thisWidth;
	    my $perNode = sprintf("%d",$totResid/@{ $tree{nodes} });
	    print $pre."   Redistribute $totResid spaces, $perNode per node\n" if ($Vb);
	    $thisWidth = 0;
	    for (my $node=0; $node<@{ $tree{nodes} }; $node ++){
		my $thisNode = ($node < @{ $tree{nodes} } - 1) ? $perNode : ($totResid - ((@{ $tree{nodes} }-1) * $perNode));
		print $pre."   --re-- Recursing node $node ".$tree{nodes}[$node]{id}." $thisNode more space to the computed $computedWidth[$node]\n" if ($Vb);

		my ($data, $subWidth) = $self->_buildTree($tree{nodes}[$node]{subs} , $labHT, $level+1, $maxLevel, $computedWidth[$node] + $thisNode, $gap);
		$tree{nodes}[$node]{nodes} = $data->{nodes};
		$tree{nodes}[$node]{width} = $subWidth;
		$thisWidth += $tree{nodes}[$node]{width};
		$thisWidth += 1 if ($node != 0);
		print $pre."  --re-- subwidth = $subWidth    thisWidth = $thisWidth  minWidth=$minWidth\n" if ($Vb);
	    }

	}
	die "Internal Error on recursion " if ($minWidth > $thisWidth);
	print $pre."Returning $thisWidth\n" if ($Vb);
	(\%tree, $thisWidth);    
    }  else {
	### We're @ the data so this is when we can calc the value of the individual value
	my $thisWidth = 0;
	for (my $node=0; $node<@{ $tree{nodes} }; $node ++){
	    print $pre."terminating ".$tree{nodes}[$node]{id}."\n" if ($Vb);
	    $tree{nodes}[$node]{nodes} = [()];
	    my $dataLen = $labHT->{SubID}{$tree{nodes}[$node]{subs}[0]}{width}{charLen};
	    my $labLen = length($tree{nodes}[$node]{id});
	    $tree{nodes}[$node]{width} = $gap*2 + (($labLen < $dataLen) ? $dataLen : $labLen);
	    $thisWidth += $tree{nodes}[$node]{width};
	    $thisWidth += 1 if ($node != 0);  # Plus 1 for |
	    print $pre."   subWidth = ".$tree{nodes}[$node]{width}."  thisWidth = $thisWidth\n" if ($Vb);
	}
	print $pre."Total Width = $thisWidth minWidth=$minWidth\n" if ($Vb);
	if ($minWidth > $thisWidth){
	    my $totResid = $minWidth - $thisWidth;
	    my $perNode = sprintf("%d",$totResid/@{ $tree{nodes} });
	    print $pre."   Redistribute $totResid spaces, $perNode per node\n" if ($Vb);
	    for (my $node=0; $node<@{ $tree{nodes} }; $node ++){
		my $thisNode = ($node < @{ $tree{nodes} } - 1) ? $perNode : ($totResid - ((@{ $tree{nodes} }-1) * $perNode));
		print $pre."   Redistrubuting extra space for node $node: $tree{nodes}[$node]{width} + $thisNode for this node\n" if ($Vb);
		$tree{nodes}[$node]{width} += $thisNode;
		$thisWidth += $thisNode;
                ## No need to add 1 for the separator  ###		$thisWidth += 1 if ($node != 0);  # Plus 1 for |
	    }	    
	    die $pre."Internal Error: ($minWidth < $thisWidth)" if ($minWidth < $thisWidth);
	}
	(\%tree, $thisWidth);
    }

}

sub _addLab(){
  my ($self, $type, $id, $val) = @_;
  my $ht = $self->{$type."LabOrder"};
    
  if (! exists($ht->{SubID}{$id}{SubIDCount})) {
    $ht->{SubID}{$id} = { thisIDNum => $ht->{SubIDCount} ++,
                          SubIDCount => 0,
                          SubID => {},
			  labels => [ split(/\|/,$id) ], 
                          width => { charLen => 0 } };
  }

  $ht = $ht->{SubID}{$id};
    
  ### HT is now the lowest level so we can save of the length for later
  $ht->{width}{charLen} = length($val) if ($ht->{width}{charLen} < length($val));
    
}

sub _getNumLev(){
  my ($self, $ht) = @_;
  my $numLev = 0;
  foreach my $sid (keys %{ $ht->{SubID} }) {
    my $nsl = $self->_getNumLev($ht->{SubID}->{$sid});
    $numLev = (1 + $nsl) if ($numLev < (1 + $nsl));
  }
  $numLev;
}

sub _getNumColLev(){
  my ($self) = @_;
  $self->_getNumLev($self->{"colLabOrder"});
}

sub _getNumRowLev(){
  my ($self) = @_;
  $self->_getNumLev($self->{"rowLabOrder"});
}

sub _getRowLabelWidth(){
  my ($self, $ht, $lev) = @_;
    
  my $len = 0;
  if ($lev == 1) {
    ### Loop through the IDS at this level
    foreach my $sid (keys %{ $ht->{SubID} }) {
      $len = length($sid) if ($len < length($sid));
    }
    return $len
  } else {
    ### recur at the next level
    foreach my $sid (keys %{ $ht->{SubID} }) {
      my $slen = $self->_getRowLabelWidth($ht->{SubID}{$sid}, $lev - 1);
      $len = $slen if ($len < $slen);
    }
    return $len           
  }
  MMisc::error_quit("[AutoTable] Internal Error");
}

sub _getColLabelWidth(){
  my ($self, $idStr) = @_;
  my $dl = $self->{"colLabOrder"}->{SubID}{$idStr}->{width}{charLen};
  (length($idStr) > $dl) ? length($idStr) : $dl;
    
}

sub _getOrderedLabelIDs(){
  my ($self, $ht, $order) = @_;
  my @ids = ();
            
  my @sortedKeys = ();
  if ($order eq "AsAdded") {
    @sortedKeys = sort { $ht->{SubID}{$a}->{thisIDNum} <=> $ht->{SubID}{$b}->{thisIDNum}} keys %{ $ht->{SubID} };
  } elsif ($order eq "Num") {
    @sortedKeys = sort { $a <=> $b} keys %{ $ht->{SubID} };
  } elsif ($order eq "Alpha") {
    @sortedKeys = sort keys %{ $ht->{SubID} };
  } else {
    MMisc::error_quit("Internal Error AutoTable: Sort order '$order' not defined");
  }  

  foreach my $sid (@sortedKeys) {
    if ($ht->{SubID}->{$sid}->{SubIDCount} > 0) {
      foreach my $labelID ($self->_getOrderedLabelIDs($ht->{SubID}->{$sid}), $order) {
        push @ids, "$sid|$labelID";
      }
    } else {
      push @ids, $sid;
    }
  }

  @ids;
}

sub _getStrForLevel(){
  my ($self, $str, $lev) = @_;
  my @a = split(/\|/, $str);    
  $a[$lev-1];
}

sub addData{
  my ($self,$val, $colid, $rowid) = @_;
    
  $self->_addLab("col", $colid, $val);
  $self->_addLab("row", $rowid, $val);
    
  if (defined($self->{data}{$colid."-".$rowid})) {
    print "Warning Datam for '$rowid $colid' has multiple instances.\n"; 
    return 1;
  }
  $self->{data}{$rowid."-".$colid} = $val;
  $self->{hasData}++;

  return(1);    
}

sub dump(){
  my ($self) = @_;
  print Dumper($self);
}

sub _nChrStr(){
  my ($self, $n, $chr) = @_;
  my $fmt = "%${n}s";
  my $str = sprintf($fmt, "");
  $str =~ s/ /$chr/g;
  $str;
}

sub _leftJust(){
  my ($self, $str, $len) = @_;
  $str . $self->_nChrStr($len - length($str), " ");
}

sub _rightJust(){
  my ($self, $str, $len) = @_;
  $self->_nChrStr($len - (defined($str) ? length($str) : 0), " ") . (defined($str) ? $str : "");
}

sub _centerJust(){
  my ($self, $str, $len) = @_;
  my $left = sprintf("%d", ($len - length($str)) / 2);
  my $right = $len - (length($str) + $left);
  $self->_nChrStr($left, " ") . $str . $self->_nChrStr($right, " ");
}


##########

sub loadCSV {
  my ($self, $file) = @_;

  return($self->_set_error_and_return("Can not load a CSV to a AutoTable which already has data", 0))
    if ($self->{hasData});
  
  open FILE, "<$file"
    or return($self->_set_error_and_return("Could not open CSV file ($file): $!\n", 0));
  my @filec = <FILE>;
  close FILE;
  chomp @filec;

  my $csvh = new CSVHelper();
  return($self->_set_error_and_return("Problem creating CSV handler", 0))
    if (! defined $csvh);
  return($self->_set_error_and_return("Problem with CSV handler: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());
  
  my %csv = ();
  my %elt1 = ();
  my $inc = 0;
  foreach my $line (@filec) {
    next if ($line =~ m%^\s*$%);

    my $key = sprintf("File: $file | Line: %012d", $inc);
    my @cols = $csvh->csvline2array($line);
    return($self->_set_error_and_return("Problem with CSV line: " . $csvh->get_errormsg(), 0))
      if ($csvh->error());
    
    if ($inc > 0) {
      $elt1{$cols[0]}++;
    } else {
      $csvh->set_number_of_columns(scalar @cols);
    }

    push @{$csv{$key}}, @cols;

    $inc++;
  }

  my $cu1cak = 1; # Can use 1st column as (master) key
  foreach my $key (keys %elt1) {
    $cu1cak = 0 if ($elt1{$key} > 1);
  }
  $self->setProperties({ "$key_KeyColumnCsv" => "Remove", "$key_KeyColumnTxt" => "Remove"}) if (! $cu1cak);

  my @colIDs = ();
  foreach my $key (sort keys %csv) {
    my @a = @{$csv{$key}};

    if (scalar @colIDs == 0) {
      @colIDs = @a;
      my $discard = shift @colIDs if ($cu1cak);
      next;
    }

    my $ID = "";
    if ($cu1cak) {
      $ID = shift @a;
    } else {
      $ID = $key;
    }

    for (my $i = 0; $i < scalar @a; $i++) {
      $self->addData($a[$i], $colIDs[$i], $ID);
    }
  }
  
  return(1);
}

##########

sub renderCSV {
  my ($self) = @_;
  
  my $out = "";
  
  my $keyCol = $self->{Properties}->getValue($key_KeyColumnCsv);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_KeyColumnCsv property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my $k1c = ($keyCol eq "Keep") ? 1 : 0;

  my $rowSort = $self->{Properties}->getValue($key_SortRowKeyCsv);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to to return get the $key_SortRowKeyCsv property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $rowSort);
  my @colIDs = $self->_getOrderedLabelIDs($self->{"colLabOrder"}, "AsAdded");

  my $csvh = new CSVHelper();
  return($self->_set_error_and_return("Problem creating CSV handler", 0))
    if (! defined $csvh);
  return($self->_set_error_and_return("Problem with CSV handler: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());

  ### Header output
  my @line = ();
  push @line, "MasterKey" if ($k1c);
  push @line, @colIDs;
  my $txt = $csvh->array2csvline(@line);
  return($self->_set_error_and_return("Problem with CSV array: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());
  $out .= "$txt\n";
  $csvh->set_number_of_columns(scalar @line);

  # line per line
  foreach my $rowIDStr (@rowIDs) {
    my @line = ();
    push @line, $rowIDStr if ($k1c);
    foreach my $colIDStr (@colIDs) {
      push @line, $self->{data}{$rowIDStr."-".$colIDStr};
    }
    my $txt = $csvh->array2csvline(@line);
    return($self->_set_error_and_return("Problem with CSV array: " . $csvh->get_errormsg(), 0))
      if ($csvh->error());
    $out .= "$txt\n";
  }
    
  return($out);
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errormsg}->set_errormsg($txt);
}

#####

sub get_errormsg {
  my ($self) = @_;
  return($self->{errormsg}->errormsg());
}

#####

sub error {
  my ($self) = @_;
  return($self->{errormsg}->error());
}

#####

sub clear_error {
  my ($self) = @_;
  return($self->{errormsg}->clear());
}

#####

sub _set_error_and_return {
  my $self = shift @_;
  my $errormsg = shift @_;

  $self->_set_errormsg($errormsg);

  return(@_);
}

############################################################

1;
