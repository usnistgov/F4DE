package SimpleAutoTable;

use Data::Dumper;
use strict;

sub new {
    my ($class) = shift @_;
    my $self = {
	   data => { },
       rowLabOrder => { ThisIDNum => 0, SubIDCount => 0, SubID => {}, width => { icgMult => 0, icgSepMult => 0, charLen => 0 } },
       colLabOrder => { ThisIDNum => 0, SubIDCount => 0, SubID => {}, width => { icgMult => 0, icgSepMult => 0, charLen => 0 } },
       
    };
    bless $self;
    return $self;
}

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

sub renderTxtTable {
  my ($self, $interColGap) = @_;

  print $self->renderTxtTable_core($interColGap);
}

sub _rem1col {
  my ($length, $text) = @_;

  $text =~ s%^.{$length}%%;

  return($text);
}

sub sorted_renderTxtTable {
  my ($self, $interColGap, $rem1col) = @_;
  my $rl = 0;

  my $txt = $self->renderTxtTable_core($interColGap);

  my @all = split(m%\n%, $txt);
  my $header = shift @all;
  my $separator = shift @all;

  # Remove initial column ?
  if ($rem1col) {
    if ($separator =~ m%^(.+\+)%) {
      $rl = length($1);
      $rl += $interColGap;
    } else {
      die "Could not find separator ?";
    }
  }

  my @sorted = sort @all;

  my $out = "";
  $out .= &_rem1col($rl, $header) . "\n";
  $out .= &_rem1col($rl, $separator) . "\n";
  foreach my $line (@sorted) {
    $out .= &_rem1col($rl, $line) . "\n";
  }

  print $out;
}

sub renderTxtTable_core(){
    my ($self, $interColGap) = @_;

    my $fmt_x;
    my $gapStr = sprintf("%${interColGap}s","");

    my $numColLev = $self->_getNumColLev();
    my $numRowLev = $self->_getNumRowLev();

    my $out = "";
    
#    print Dumper($self);
    
#    print "Col num lev = $numColLev\n";
#    print "Row num lev = $numRowLev\n";
    
    ### Compute the max width of the row labels for each level
    my $maxRowLabWidth = $interColGap;
    my @rowLabWidth = ();
    for (my $rl=1; $rl <= $numRowLev; $rl++){
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
    $out .= $self->_nChrStr($maxRowLabWidth, " ") . "|" . $gapStr;
    
    my $data_len = 0;            
    for ($c=0; $c<@colIDs; $c++){
        $out .= $self->_centerJust($colIDs[$c], $self->_getColLabelWidth($colIDs[$c]));
        $out .= $gapStr;
        $data_len += $self->_getColLabelWidth($colIDs[$c]) + $interColGap;
    }
    $out .= "\n";
        
    ### Header separator
    $out .= $self->_nChrStr($maxRowLabWidth, "-") . "+" . $self->_nChrStr($data_len, "-");
    $out .= "\n";
    
    
    ### The data
    foreach $rowIDStr(@rowIDs){
        for ($c=1; $c<=$numRowLev; $c++){
            $out .= $self->_leftJust($rowIDStr, $maxRowLabWidth);
        }
        $out .= "|";
        
        foreach $colIDStr(@colIDs){
            $out .= "$gapStr" . $self->_rightJust($self->{data}{$rowIDStr."-".$colIDStr}, 
                                              $self->_getColLabelWidth($colIDStr));
        }
        
        $out .= "\n";
    }   

    return($out);
}

1;
