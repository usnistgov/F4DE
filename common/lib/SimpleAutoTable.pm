package SimpleAutoTable;

# Simple Auto Table
#
# Original Author: Jonathan Fiscus 
# Adds: Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "SimplAutoTable.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

# $Id$

use strict;

use MErrorH;
use PropList;
use Data::Dumper;


my $key_KeyColumnTxt = "KeyColumnTxt";
my $key_KeyColumnCsv = "KeyColumnCsv";
my $key_SortRowKeyTxt = "SortRowKeyTxt";
my $key_SortRowKeyCsv = "SortRowKeyCsv";

sub new {
  my ($class) = shift @_;

  my $errormsg = new MErrorH("SimpleAutoTable");

  my $self =
    {
     hasData => 0,
     data => { },
     rowLabOrder => 
     {
      ThisIDNum    => 0,
      SubIDCount   => 0,
      SubID        => {},
      width        => { icgMult => 0, icgSepMult => 0, charLen => 0 },
     },
     colLabOrder => 
     {
      ThisIDNum    => 0,
      SubIDCount   => 0,
      SubID        => {},
      width        => { icgMult => 0, icgSepMult => 0, charLen => 0 },
     },
     Properties  => new PropList(),
     errormsg    => $errormsg,
    };

  bless $self;

  $self->{Properties}->addProp($key_KeyColumnCsv, "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_KeyColumnTxt, "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_SortRowKeyTxt, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortRowKeyCsv, "AsAdded", ("AsAdded", "Num", "Alpha"));
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

sub unitTest(){
  my $sg = new SimpleAutoTable();
  $sg->addData("1",  "PartA|A|col1", "PartZ|ObjectPut");
  $sg->addData("2",  "PartA|A|col2", "PartZ|ObjectPut");
  $sg->addData("3",  "PartB|A|col3", "PartZ|ObjectPut");
  $sg->addData("4",  "PartB|A|col4", "PartZ|ObjectPut");
  $sg->addData("5",  "PartA|A|col1", "PartYY|PeopleSplitUp");
  $sg->addData("6",  "PartA|A|col2", "PartYY|PeopleSplitUp");
  $sg->addData("7",  "PartB|A|col3", "PartYY|PeopleSplitUp");
  $sg->addData("8",  "PartB|B|col4", "PartYY|PeopleSplitUp");
  $sg->addData("9",  "PartA|B|col1", "PartZ|PersonRuns");
  $sg->addData("10", "PartA|B|col2", "PartZ|PersonRuns");
  $sg->addData("11", "PartB|B|col3", "PartZ|PersonRuns");
  $sg->addData("12", "PartB|B|col4", "PartZ|PersonRuns");
  $sg->addData("13", "PartA|B|col1", "PartYY|Pointing");
  $sg->addData("14", "PartA|B|col2", "PartYY|Pointing");
  $sg->addData("15", "PartB|B|col3", "PartYY|Pointing");
  $sg->addData("16454433333333334", "PartB|B|col4", "PartYY|Pointing");

  #    $sg->dump();
  $sg->renderTxtTable(2);

}

sub _addLab(){
  my ($self, $type, $id, $val) = @_;
  my $ht = $self->{$type."LabOrder"};
    
  if (! exists($ht->{SubID}{$id}{SubIDCount})) {
    $ht->{SubID}{$id} = { thisIDNum => $ht->{SubIDCount} ++,
                          SubIDCount => 0,
                          SubID => {},
                          width => { icgMult => 0, icgSepMult => 0, charLen => 0 } };
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
  die "Internal Error";
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
    die "Internal Error SimpleAutoTable: Sort order '$order' not defined";
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
  @a[$lev-1];
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
  $self->_nChrStr($len - length($str), " ") . $str;
}

sub _centerJust(){
  my ($self, $str, $len) = @_;
  my $left = sprintf("%d", ($len - length($str)) / 2);
  my $right = $len - (length($str) + $left);
  $self->_nChrStr($left, " ") . $str . $self->_nChrStr($right, " ");
}

sub renderTxtTable(){
  my ($self, $interColGap) = @_;
  
  my $fmt_x;
  my $gapStr = sprintf("%${interColGap}s","");
  
  my $numColLev = $self->_getNumColLev();
  my $numRowLev = $self->_getNumRowLev();
  
  my $out = "";
  
  #    print Dumper($self);
  
  #    print "Col num lev = $numColLev\n";
  #    print "Row num lev = $numRowLev\n";

  my $keyCol = $self->{Properties}->getValue($key_KeyColumnTxt);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the ".$key_KeyColumnTxt." property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my $r1c = ($keyCol eq "Remove") ? 1 : 0;
    
  ### Compute the max width of the row labels for each level
  my $maxRowLabWidth = $interColGap;
  my @rowLabWidth = ();
  for (my $rl=1; $rl <= $numRowLev; $rl++) {
    my $w = $self->_getRowLabelWidth($self->{rowLabOrder}, $rl);
    push @rowLabWidth, $w; 
    $maxRowLabWidth += $w + ($rl > 1 ? $interColGap : 0);    
  }
  #    print "MaxRowWidth    $maxRowLabWidth = ".join(" ",@rowLabWidth)."\n";

  #######################################################
  my ($r, $c, $fmt, $str, $rowIDStr, $colIDStr);

  #    print "The Report\n";
  my $rowSort = $self->{Properties}->getValue($key_SortRowKeyTxt);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to to return get RowSort property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $rowSort);
  my @colIDs = $self->_getOrderedLabelIDs($self->{"colLabOrder"}, "AsAdded");
  #    print "ColIDs ".join(" ",@colIDs)."\n";

  ### Header output
  $out .= ((! $r1c) 
           ? ($self->_nChrStr($maxRowLabWidth, " ") . "|" . $gapStr)
           : $gapStr);

  my $data_len = 0;            
  for ($c= 0; $c<@colIDs; $c++) {
    $out .= $self->_centerJust($colIDs[$c],
                               $self->_getColLabelWidth($colIDs[$c]));
    $out .= $gapStr;
    $data_len += $self->_getColLabelWidth($colIDs[$c]) + $interColGap;
  }
  $out .= "\n";
        
  ### Header separator
  $out .= ((! $r1c) 
           ? ($self->_nChrStr($maxRowLabWidth, "-") . "+")
           : "") . $self->_nChrStr($data_len, "-");
  $out .= "\n";
  
  foreach $rowIDStr (@rowIDs) {
    if (! $r1c) {
      for ($c=1; $c<=$numRowLev; $c++) {
        $out .= $self->_leftJust($rowIDStr, $maxRowLabWidth);
      }
      $out .= "|";
    }

    foreach $colIDStr (@colIDs) {
      $out .= "$gapStr" 
        . $self->_rightJust($self->{data}{$rowIDStr."-".$colIDStr}, 
                            $self->_getColLabelWidth($colIDStr));
    }
      
    $out .= "\n";
  }   
    
  return($out);
}

##########

sub _badfile {
  my ($self, $txt) = @_;

  $self->_seterrormsg($txt);
  return(0);
}

#####

sub extract_csv_line {
  my $line = shift @_;

  my @split = split(m%\"\s*\,\s*\"%, $line);
  my @out;
  foreach my $elt (@split) {
    $elt =~ s%^\"%%;
    $elt =~ s%\"$%%;
    push @out, $elt;
  }

  return(@out);
}

#####

sub loadCSV {
  my ($self, $file) = @_;

  if ($self->{hasData}) {
    $self->_set_errormsg("Can not load a CSV to a SimpleAutoTable which already has data");
    return(0);
  }
  
  open FILE, "<$file"
    or return(&_badfile("Could not open CSV file ($file): $!\n"));
  my @filec = <FILE>;
  close FILE;

  chomp @filec;
  my %csv;
  my %elt1;
  my $inc = 0;
  my $nc = -1;
  foreach my $line (@filec) {
    next if ($line =~ m%^\s*$%);
    my $key = sprintf("File: $file | Line: %012d", $inc++);
    my @cols = &extract_csv_line($line);
    if ($nc != -1) {
      if ($nc != scalar @cols) {
        $self->_set_errormsg("File ($file) is not a CSV, not all lines contains the same amount of information");
        return(0);
      }
      $elt1{$cols[0]}++;
    } 
    push @{$csv{$key}}, @cols;

    $nc = scalar @cols;
  }

  my $cu1cak = 1;               # Can use 1st column as key
  foreach my $key (keys %elt1) {
    $cu1cak = 0 if ($elt1{$key} > 1);
  }
  $self->setProperties({ "$key_KeyColumnCsv" => "Remove", "$key_KeyColumnTxt" => "Remove"}) if (! $cu1cak);

  my @colIDs;
  foreach my $key (sort keys %csv) {
    my @a = @{$csv{$key}};

    if (scalar @colIDs == 0) {
      @colIDs = @a;
      my $discard = shift @colIDs if ($cu1cak);
      next;
    }

    my $ID;
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

  ### Header output
  my @line;
  push @line, "MasterKey" if ($k1c);
  push @line, @colIDs;
  $out .= &generate_csvline(@line);
  
  # line per line
  foreach my $rowIDStr (@rowIDs) {
    my @line;
    push @line, $rowIDStr if ($k1c);
    foreach my $colIDStr (@colIDs) {
      push @line, $self->{data}{$rowIDStr."-".$colIDStr};
    }
    $out .= &generate_csvline(@line);
  }   
    
  return($out);
}

sub quc {                       # Quote clean
  my $in = shift @_;

  $in =~ s%\"%\'%g;

  return($in);
}

#####

sub qua {                       # Quote Array
  my @todo = @_;

  my @out = ();
  foreach my $in (@todo) {
    $in = &quc($in);
    push @out, "\"$in\"";
  }

  return(@out);
}

#####

sub generate_csvline {
  my @in = @_;

  @in = &qua(@in);
  my $txt = join(",", @in);
  
  return("$txt\n");
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errormsg}->set_errormsg($txt);
}

##########

sub get_errormsg {
  my ($self) = @_;
  return($self->{errormsg}->errormsg());
}

##########

sub error {
  my ($self) = @_;
  return($self->{errormsg}->error());
}

############################################################

1;
