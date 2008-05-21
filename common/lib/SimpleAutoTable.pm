package SimpleAutoTable;

use PropList;
use Data::Dumper;

use strict;

my $key_KeyColumn = "KeyColumn";
my @av_KeyColumn = ("Keep", "Remove"); # Order is Important
my $key_SortRowKey = "SortRowKey";
my @av_SortRowKey = ("AsAdded", "Num", "Alpha"); # Order is Important

sub new {
  my ($class) = shift @_;

  my $prop = new PropList();
  $prop->addProp($key_KeyColumn, $av_KeyColumn[0], @av_KeyColumn);
  $prop->addProp($key_SortRowKey, $av_SortRowKey[0], @av_SortRowKey);

  my $errormsg = &_set_errormsg_txt("", $prop->get_errormsg());

  my $self =
    {
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
     Properties  => $prop,
     errormsg    => $errormsg,
    };

  bless $self;
  return($self);
}

##########

sub error {
  my ($self) = @_;

  return(1) if (! &_is_blank($self->get_errormsg()));

  return(0);
}

#####

sub get_errormsg {
  my ($self) = @_;

  return($self->{errormsg});
}

#####

sub _set_errormsg_txt {
  my ($oh, $add) = @_;

  my $txt = "$oh$add";

  $txt =~ s%\[SimpleAutoTable\]\s+%%g;

  return("") if (&_is_blank($txt));

  $txt = "[SimpleAutoTable] $txt";

  return($txt);
}

#####

sub _set_errormsg {
  my ($self, $txt) = @_;

  $self->{errormsg} = &_set_errormsg_txt($self->{errormsg}, $txt);
}

##########

sub getProp_KeyColumn {
  my ($self) = @_;

  my $prop = $self->{Properties};

  my $v = $prop->getValue($key_KeyColumn);
  if ($prop->error()) {
    $self->_set_erromsg("Could not get the KeyColumn Property (" . $prop->get_errormsg() . ")");
    return(0);
  }
  
  return($v);
}

#####

sub _setProp_KeyColumn {
  my ($self, $val) = @_;

  my $prop = $self->{Properties};

  if ((! $prop->setValue($key_KeyColumn, $val)) || ($prop->error())) {
    $self->_set_erromsg("Could not set the KeyColumn Property (" . $prop->get_errormsg() . ")");
    return(0);
  }

  return(1);
}

#####

sub setProp_KeepKeyColumn {
  my ($self) = @_;
  return($self->_setProp_KeyColumn($av_KeyColumn[0]));
}

#####

sub setProp_RemoveKeyColumn {
  my ($self) = @_;
  return($self->_setProp_KeyColumn($av_KeyColumn[1]));
}

##########

sub getProp_SortRowKey {
  my ($self) = @_;

  my $prop = $self->{Properties};

  my $v = $prop->getValue($key_SortRowKey);
  if ($prop->error()) {
    $self->_set_erromsg("Could not get the SortRowKey Property (" . $prop->get_errormsg() . ")");
    return(0);
  }
  
  return($v);
}

#####

sub _setProp_SortRowKey {
  my ($self, $val) = @_;

  my $prop = $self->{Properties};

  if ((! $prop->setValue($key_SortRowKey, $val)) || ($prop->error())) {
    $self->_set_erromsg("Could not set the SortRowKey Property (" . $prop->get_errormsg() . ")");
    return(0);
  }

  return(1);
}

#####

sub setProp_SortRowKeyAsAdded {
  my ($self) = @_;
  return($self->_setProp_SortRowKey($av_SortRowKey[0]));
}

#####

sub setProp_SortRowKeyNum {
  my ($self) = @_;
  return($self->_setProp_SortRowKey($av_SortRowKey[1]));
}

#####

sub setProp_SortRowKeyAlpha {
  my ($self) = @_;
  return($self->_setProp_SortRowKey($av_SortRowKey[2]));
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
    
    if (! exists($ht->{SubID}{$id}{SubIDCount})){
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
    foreach my $sid(keys %{ $ht->{SubID} }){
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
    if ($lev == 1){
        ### Loop through the IDS at this level
        foreach my $sid(keys %{ $ht->{SubID} }){
            $len = length($sid) if ($len < length($sid));
        }
        return $len
    } else {
        ### recur at the next level
        foreach my $sid(keys %{ $ht->{SubID} }){
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
    my ($self, $ht) = @_;
    my @ids = ();
        
    my @sortedKeys = sort { $ht->{SubID}{$a}->{thisIDNum} <=> $ht->{SubID}{$b}->{thisIDNum}} keys %{ $ht->{SubID} };
    
    foreach my $sid(@sortedKeys){
        if ($ht->{SubID}->{$sid}->{SubIDCount} > 0){
            foreach my $labelID ($self->_getOrderedLabelIDs($ht->{SubID}->{$sid})){
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
    
    if (defined($self->{data}{$colid."-".$rowid})){
        print "Warning Datam for '$rowid $colid' has multiple instances.\n"; 
        return 1;
    }
    $self->{data}{$rowid."-".$colid} = $val;
    1;    
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

  my $r1c = (($self->getProp_KeyColumn()) eq $av_KeyColumn[1]) ? 1 : 0;
  my $sm = $self->getProp_SortRowKey();
    
  ### Compute the max width of the row labels for each level
  my $maxRowLabWidth = $interColGap;
  my @rowLabWidth = ();
  for (my $rl= ($r1c ? 2 : 1); $rl <= $numRowLev; $rl++){
    my $w = $self->_getRowLabelWidth($self->{rowLabOrder}, $rl);
    push @rowLabWidth, $w; 
    $maxRowLabWidth += $w + ($rl > 1 ? $interColGap : 0);    
  }
#    print "MaxRowWidth    $maxRowLabWidth = ".join(" ",@rowLabWidth)."\n";

  #######################################################
  my ($r, $c, $fmt, $str, $rowIDStr, $colIDStr);

#    print "The Report\n";
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"});
  my @colIDs = $self->_getOrderedLabelIDs($self->{"colLabOrder"});
#    print "ColIDs ".join(" ",@colIDs)."\n";

  ### Header output
  $out .= ((! $r1c) 
	   ? ($self->_nChrStr($maxRowLabWidth, " ") . "|" . $gapStr)
	   : $gapStr);

  my $data_len = 0;            
  for ($c= 0; $c<@colIDs; $c++){
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
  
  ### The data
  my @srowIDs 
    = ($sm eq $av_SortRowKey[0]) # As Added
      ? @rowIDs 
	: (($sm eq $av_SortRowKey[1]) # Num
	   ? sort _num @rowIDs
	   : sort @rowIDs); # Alpha

  foreach $rowIDStr (@srowIDs){
    if (! $r1c) {
      for ($c=1; $c<=$numRowLev; $c++){
	$out .= $self->_leftJust($rowIDStr, $maxRowLabWidth);
      }
      $out .= "|";
    }

    foreach $colIDStr (@colIDs){
      $out .= "$gapStr" 
	. $self->_rightJust($self->{data}{$rowIDStr."-".$colIDStr}, 
			    $self->_getColLabelWidth($colIDStr));
    }
      
    $out .= "\n";
  }   
    
  print($out);
}

############################################################

sub _is_blank {
  my $txt = shift @_;
  return(($txt =~ m%^\s*$%));
}

################################################################################

1;
