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

use MMisc;
use MErrorH;
use PropList;
use CSVHelper;

use Data::Dumper;


my $key_KeyColumnTxt = "KeyColumnTxt";
my $key_KeyColumnCsv = "KeyColumnCsv";
my $key_KeyColumnHTML = "KeyColumnHTML";
my $key_SortRowKeyTxt = "SortRowKeyTxt";
my $key_SortRowKeyCsv = "SortRowKeyCsv";
my $key_SortColKeyTxt = "SortColKeyTxt";
my $key_SortColKeyCsv = "SortColKeyCsv";
my $key_KeepColumnsInOutput = "KeepColumnsInOutput";
my $key_KeepRowsInOutput = "KeepRowsInOutput";

my $key_htmlColHeadBGColor = "html.colhead.bgcolor";
my $key_htmlRowHeadBGColor = "html.rowhead.bgcolor";
my $key_htmlCellBGColor = "html.cell.bgcolor";
my $key_htmlCellJust = "html.cell.justification";

my @ok_specials = ("HTML", "CSV", "TEXT");

sub new {
  my ($class) = shift @_;
  
  my $errormsg = new MErrorH("AutoTable");
  
  my $self =
  {
    hasData => 0,
    data => { },
    special => { },
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
  $self->{Properties}->addProp($key_KeyColumnHTML, "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_SortRowKeyTxt, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortRowKeyCsv, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortColKeyTxt, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortColKeyCsv, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_KeepColumnsInOutput, "", ());
  $self->{Properties}->addProp($key_KeepRowsInOutput, "", ());
  
  $self->{Properties}->addProp($key_htmlColHeadBGColor, "", ());
  $self->{Properties}->addProp($key_htmlRowHeadBGColor, "", ());
  $self->{Properties}->addProp($key_htmlCellBGColor, "", ());
  $self->{Properties}->addProp($key_htmlCellJust, "right", ("left", "center", "right"));
  
  $self->_set_errormsg($self->{Properties}->get_errormsg());
  
  return($self);
}

##########

sub setProperties(){
  my ($self, $propHT) = @_;
  
  if (! $self->{Properties}->setValueFromHash($propHT)) {
    $self->_set_errormsg("Could not set Properties: ",$self->{Properties}->get_errormsg());
    return (0);
  }
  return (1);
}

##########

sub unitTest {
  my $makecall = shift @_;
  
  print "Testing AutoTable ..." if ($makecall);
  
  my $at = new AutoTable();
  print "Testing behavior on an empty table\n";
  die "Error: Empty table not rendered correctly for TXT" if ($at->renderTxtTable() !~ /Warning: Empty table./);
  die "Error: Empty table not rendered correctly for HTML" if ($at->renderHTMLTable() !~ /Warning: Empty table./);
  die "Error: Empty table not rendered correctly for CSV" if ($at->renderCSV() !~ /Warning: Empty table./);

#  $at->addData({value => "1x1", link => "/etc/hosts"},  "CCC|col1|A", "srow1|row1");
#  $at->addData({value => "1x1", link => "/etc/hosts", linkText => "foo"},  "CCC|col1|A", "srow1|row1");
  $at->addData("1x1",  "CCC|col1|A", "srow1|row1");
  $at->addData("1x1",  "CCC|col1|B", "srow1|row1");
  $at->addData("1x2",  "CCC|col1|C", "srow1|row1");
  $at->addData("1x1",  "CCC|col2|A", "srow1|row1");
  $at->addData("1x1",  "CCC|col2|B", "srow1|row1");
  $at->addData("1x2",  "CCC|col2|C", "srow1|row1");
  $at->addData("1x1",  "CCC|col1|A", "srow1|row2");
  $at->addData("1x1",  "CCC|col1|B", "srow1|row2");
  $at->addData("1x2",  "CCC|col1|C", "srow1|row2");
  $at->addData("1x1",  "CCC|col2|A", "srow1|row2");
  $at->addData("1x1",  "CCC|col2|B", "srow1|row2");
  $at->addData("1x2",  "CCC|col2|C", "srow1|row2");
  $at->addData("1x1",  "CCC|col1|A", "srow2|row1");
  $at->addData("1x1",  "CCC|col1|B", "srow2|row1");
  $at->addData("1x2",  "CCC|col1|C", "srow2|row1");
  $at->addData("1x1",  "CCC|col2|A", "srow2|row1", "url={http://www.nist.gov/}");
  $at->addData("1x1",  "CCC|col2|B", "srow2|row1");
  $at->addData("1x2",  "CCC|col2|C", "srow2|row1");
  $at->addData("1x1",  "CCC|col1|A", "srow2|row2");
  $at->addData("1x1",  "CCC|col1|B", "srow2|row2");
  $at->addData("1x2",  "CCC|col1|C", "srow2|row2");
  $at->addData("1x1",  "CCC|col2|A", "srow2|row2");
  $at->addData("1x1",  "CCC|col2|B", "srow2|row2");
  $at->addData("1x2",  "CCC|col2|C", "srow2|row2");
#  $at->addData("1x1",  "||", "srow2|row2");
#  $at->addData("1x1",  "||", "srow2|row2");
#  $at->addData("1x2",  "||", "srow2|row2"); 
 
 print "<html>\n";
  print "Simple Table\n";
  print "<pre>\n";
  print($at->renderTxtTable(1));
  print($at->renderCSV(2));
  print "</pre>\n";
  print($at->renderHTMLTable());
  
##=======
##  
##>>>>>>> 1.3
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
#<<<<<<< AutoTable.pm
  
  print "Complex Table\n";
  print "<pre>\n";
  print($sg->renderTxtTable(2));
  print($sg->renderCSV());
  print "</pre>\n";
  print($sg->renderHTMLTable());
  
##=======
##  
###  my $colLabTree = $sg->_buildLabelHeir("col", "Alpha");
##  
##  if (! $makecall) {
###      $sg->dump();
##    print($sg->renderTxtTable(2));
##  }
##  
##>>>>>>> 1.3
  $sg->setProperties({ $key_KeepColumnsInOutput => ".*PartA.*|PartB.*col4" });
  print "Complex table = keepColumns .*PartA.*|PartB.*col4\n";
  print "<pre>\n";
  print($sg->renderTxtTable(2));
  print($sg->renderCSV());
  print "</pre>\n";
  print($sg->renderHTMLTable());
  
  $sg->setProperties({ $key_KeepRowsInOutput => ".*PartZ.*" });
  $sg->setProperties({ $key_htmlColHeadBGColor => "pink" });
  $sg->setProperties({ $key_htmlRowHeadBGColor => "orange" });
  $sg->setProperties({ $key_htmlCellBGColor => "read" });
  $sg->setProperties({ $key_htmlCellJust => "center" });
  print "Complex table = keepRows *PartZ.*, HTML props\n";
  print "<pre>\n";
  print($sg->renderTxtTable(2));
#<<<<<<< AutoTable.pm
  print($sg->renderCSV());
  print "</pre>\n";
  print($sg->renderHTMLTable());
  
  $sg->setProperties({ $key_KeyColumnHTML => "Remove" });
  $sg->setProperties({ $key_KeyColumnTxt => "Remove" });
  $sg->setProperties({ $key_KeyColumnCsv => "Remove" });
  print "Complex table = remnove key column\n";
  print "<pre>\n";
  print($sg->renderTxtTable(2));
  print($sg->renderCSV());
  print "</pre>\n";
  print($sg->renderHTMLTable());
  
  print "</html>\n";
##=======
##  
##  print($sg->renderCSV(2));
##  
##>>>>>>> 1.3
  MMisc::ok_quit(" OK");
  
}

sub _buildHeir(){
  my ($self, $gap) = @_;
  
  $self->_buildLabelHeir("col", $gap);
  $self->_buildLabelHeir("row", $gap);
}


sub __HTML_proc_sp {
  my ($str) = @_;

  my (@h1, @h2);

#  print "#####[$str]#####\n";
  if ($str =~ s%url\=\{([^\}]+?)\}%%) {
    push @h1, "<a href=\"$1\">";
    unshift @h2, "</a>";
  }

  return(join("", @h1), join("", @h2));
}

sub __process_special {
  my ($mode, $str) = @_;
  MMisc::error_quit("Unknown special mode ($mode)")
      if (! grep(m%^$mode$%, @ok_specials));

  return(&__HTML_proc_sp($str))
    if ($mode eq $ok_specials[0]);

  # only HTML for now
  return("", "");
}


sub renderHTMLTable(){
  my ($self, $tha) = @_;
  my $out = "";

  ### Make sure there is data.   If there isn't report nothing exists
  my @_da = keys %{ $self->{data} };
  return "Warning: Empty table.  Nothing to produce.\n" if (@_da == 0);
  
  ##########
  my $keyCol = $self->{Properties}->getValue($key_KeyColumnHTML);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_KeyColumnHTML property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my $k1c = ($keyCol eq "Keep") ? 1 : 0;
  
  ########## HTML options
  my $colHeadBGColor = $self->{Properties}->getValue($key_htmlColHeadBGColor);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_htmlColHeadBGColor property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  $colHeadBGColor = " bgcolor=\"$colHeadBGColor\""if ($colHeadBGColor ne "");
  
  ########## HTML options
  my $rowHeadBGColor = $self->{Properties}->getValue($key_htmlRowHeadBGColor);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_htmlRowHeadBGColor property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  $rowHeadBGColor = " bgcolor=\"$rowHeadBGColor\""if ($rowHeadBGColor ne "");
  ####
  my $cellBGColor = $self->{Properties}->getValue($key_htmlCellBGColor);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_htmlCellBGColor property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  $cellBGColor = " bgcolor=\"$cellBGColor\""if ($cellBGColor ne "");
  ####
  my $cellJust = $self->{Properties}->getValue($key_htmlCellJust);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_htmlCellJust property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  $cellJust = " align=\"$cellJust\""if ($cellJust ne "");
  
  $self->_buildHeir(1);
  
#    print Dumper($self);
  my @IDs = $self->{render}{colIDs};
  my $levels = $self->{render}{colLabelLevels};
  
  my @nodeSet;
  die "Internal Error: No levels defined" if ($levels < 1);
  $out .= "<table border=1 $tha>\n";
  for (my $level=0; $level < $levels; $level++){
    $out .= "<tr>\n";
    ### Render the row data 
    my $numRowHead = scalar(@{ $self->{render}{rowLabelWidth} });
    $out .= "  <th rowspan=$levels colspan=$numRowHead> &nbsp; </th>\n" if ($k1c && $level == 0);
    
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
      my $ncol = scalar( @{ $nodeSet[$node]{subs} });
      $out .= "  <th".($ncol > 1 ? " colspan=$ncol" : "")." $colHeadBGColor> $nodeSet[$node]{id}  </th>\n";
    }
    $out .= "</tr>\n";
  }
  
  #### NOW: @nodeSet is the formatting informatlion for the columns!!!
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, "Alpha",
					  $self->{Properties}->getValue($key_KeepRowsInOutput));
  #print join(" ",@rowIDs)."\n";
  #### compute the rowspans for each 
  my @lastRowLabel = ();
  #### make a 2D table of ids
  my @idlist = ();
  foreach (@rowIDs) {
    push @idlist, [ _safeSplit("|", $_) ];
  }
  for (my $row=0; $row<@rowIDs; $row++) {
    $out .= "<tr>\n";
    
    if ($k1c){
      my @ids = @{ $idlist[$row] };
      for (my $rowLevel=0; $rowLevel < @{ $self->{render}{rowLabelWidth} }; $rowLevel++){
	$lastRowLabel[$rowLevel] = "" if (! defined($lastRowLabel[$rowLevel]));
	
	my $print = 1;
	if ($lastRowLabel[$rowLevel] eq $ids[$rowLevel]){
	  $print = 0;
	} else {
	  ### if we print a level, then print all levels below
	  for (my $trl=$rowLevel+1; $trl < @{ $self->{render}{rowLabelWidth} }; $trl++){
	    $lastRowLabel[$trl] = "";
	  }
	}
	if ($print){
	  ### look forward to see when to stop
	  my $span = 0;
	  my $stop = 0;
	  for (my $larow=$row; $larow<@rowIDs && $stop == 0; $larow++){
	    ### is this value the same
	    $stop = 1 if ($ids[$rowLevel] ne $idlist[$larow][$rowLevel]);
	    ### do any of the left label values change
	    for (my $leftlev=0; $leftlev < $rowLevel; $leftlev ++){
	      $stop = 1 if ($ids[$leftlev] ne $idlist[$larow][$leftlev]);
	    }
	    $span ++ if (! $stop);
	  }
	  $out .= "  <th".($span > 1 ? " rowspan=$span" : "")." $rowHeadBGColor> $ids[$rowLevel] </th>\n";
	} else {
	  $out .= "  <!-- <th> ".($print ? $ids[$rowLevel] : "&nbsp;")." </th> -->\n";
	}
	
	$lastRowLabel[$rowLevel] = $ids[$rowLevel];
      }
    }
    for (my $node=0; $node<@nodeSet; $node++) {
      my $lid = $rowIDs[$row]."-".$nodeSet[$node]{subs}[0];
      my $str = defined($self->{data}{$lid}) ? $self->{data}{$lid} : "&nbsp;";
      my ($h1, $h2) = ("", "");
#      print "[$lid]\n";
      ($h1, $h2) = &__process_special($ok_specials[0], $self->{special}{$lid}) 
        if (exists $self->{special}{$lid});
      $out .= "  <td $cellJust $cellBGColor> $h1".$str."$h2 </td>".
	"  <!-- $rowIDs[$row] $nodeSet[$node]{subs}[0]  --> \n";
    }
    $out .= "</tr>\n";
  }   
  $out .= "</table>\n";
  $out;
}

sub renderTxtTable(){
#<<<<<<< AutoTable.pm
  my ($self, $gap) = @_;
  
  ### Make sure there is data.   If there isn't report nothing exists
  my @_da = keys %{ $self->{data} };
  return "Warning: Empty table.  Nothing to produce.\n" if (@_da == 0);

  $gap = 1 if ((!defined($gap)) || ($gap < 1));
  
  my $keyCol = $self->{Properties}->getValue($key_KeyColumnTxt);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_KeyColumnTxt property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my $k1c = ($keyCol eq "Keep") ? 1 : 0;
  
  my $out = "";
  $self->_buildHeir($gap);
  
##=======
##  my ($self, $gap) = @_;
##  
##  my $out = "";
##  $self->_buildHeir($gap);
##  
##>>>>>>> 1.3
#    print Dumper($self);
#<<<<<<< AutoTable.pm
  my @IDs = $self->{render}{colIDs};
  my $levels = $self->{render}{colLabelLevels};
  my @nodeSet;
  die "Internal Error: No levels defined" if ($levels < 1);
  for (my $level=0; $level < $levels; $level++){
    ### Render the row data
    if ($k1c){
      for (my $rowLevel=0; $rowLevel < @{ $self->{render}{rowLabelWidth} }; $rowLevel++){
	$out .= $self->_centerJust("", $self->{render}{rowLabelWidth}->[$rowLevel]);    
	$out .= $self->_centerJust("", $gap); 
      }
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
##=======
##  my @IDs = $self->{render}{colIDs};
##  my $levels = $self->{render}{colLabelLevels};
##  my @nodeSet;
##  die "Internal Error: No levels defined" if ($levels < 1);
##  for (my $level=0; $level < $levels; $level++){
##    ### Render the row data
##    for (my $rowLevel=0; $rowLevel < @{ $self->{render}{rowLabelWidth} }; $rowLevel++){
##      $out .= $self->_centerJust("", $self->{render}{rowLabelWidth}->[$rowLevel]);    
##      $out .= $self->_centerJust("", $gap); 
##>>>>>>> 1.3
  }
#<<<<<<< AutoTable.pm
  ### The separator
  if ($k1c){
    for (my $rowLevel=0; $rowLevel < @{ $self->{render}{rowLabelWidth} }; $rowLevel++){
      $out .= $self->_nChrStr($self->{render}{rowLabelWidth}->[$rowLevel] + $gap, "-");
    }
    $out .= "+";
  } else {
    $out .= "|";
##=======
##    $out .= "|";
##    
##    ### Render the col data
##    my $tree = $self->{render}{colLabelHeir}; 
##    @nodeSet = @{ $tree->{nodes} };
##    
##    my $searchLevel = $level;
##    while ($searchLevel > 0){
##      my @stack = @nodeSet;
##      @nodeSet = ();
##      foreach my $nd(@stack){ 
##	push @nodeSet, @{ $nd->{nodes} };
##      }
##      $searchLevel --;
##>>>>>>> 1.3
  }
#<<<<<<< AutoTable.pm
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
  my $rowSort = $self->{Properties}->getValue($key_SortRowKeyCsv);
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $rowSort,
					  $self->{Properties}->getValue($key_KeepRowsInOutput));
#    print join(" ",@rowIDs)."\n";
#<<<<<<< AutoTable.pm
  my @lastRowLabel = ();
  foreach my $rowIDStr (@rowIDs) {
    ### Render the row header column 
    if ($k1c){
      my @ids = _safeSplit("|", $rowIDStr);
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
##=======
##  my @lastRowLabel = ();
##  foreach my $rowIDStr (@rowIDs) {
###	if (! $r1c) {
###	    for (my $c=1; $c<=$numRowLev; $c++) {
###	    for (my $c=1; $c<=1; $c++) {
###		$out .= $self->_leftJust($rowIDStr, $maxRowLabWidth);
###	    }
###	    $out .= "|";
###	}
##    ### Render the row header column 
##    if (1){
##      my @ids = split(/\|/, $rowIDStr);
##      my $print = 1;
##      for (my $rowLevel=0; $rowLevel < @{ $self->{render}{rowLabelWidth} }; $rowLevel++){
##	$lastRowLabel[$rowLevel] = "" if (! defined($lastRowLabel[$rowLevel]));
##	
##	$print = 1;
##	if ($lastRowLabel[$rowLevel] eq $ids[$rowLevel]){
##	  $print = 0;
##	} else {
##	  ### if we print a level, then print all levels below
##	  for (my $trl=$rowLevel+1; $trl < @{ $self->{render}{rowLabelWidth} }; $trl++){
##	    $lastRowLabel[$trl] = "";
##	  }
##	}
##	
##	$out .= $self->_leftJust($print ? $ids[$rowLevel] : "", $self->{render}{rowLabelWidth}->[$rowLevel]);    
##>>>>>>> 1.3
#		$out .= $self->_leftJust("", $gap) if ($rowLevel != 0);
#<<<<<<< AutoTable.pm
	$out .= $self->_leftJust("", $gap);
	
	$lastRowLabel[$rowLevel] = $ids[$rowLevel];
      }
    }
    $out .= "|";
    for (my $node=0; $node<@nodeSet; $node++) {
      $out .= " " . $self->_rightJust($self->{data}{$rowIDStr."-".$nodeSet[$node]{subs}[0]}, $nodeSet[$node]{width} - 2) . " |";
    }
    
    $out .= "\n";
  }   
  
  $out;
###=======
###	$out .= $self->_leftJust("", $gap);
###	
###	$lastRowLabel[$rowLevel] = $ids[$rowLevel];
###      }
###      $out .= "|";
###    }
###    for (my $node=0; $node<@nodeSet; $node++) {
###      $out .= " " . $self->_rightJust($self->{data}{$rowIDStr."-".$nodeSet[$node]{subs}[0]}, $nodeSet[$node]{width} - 2) . " |";
###    }
###    
###    $out .= "\n";
###  }   
###  $out;
###>>>>>>> 1.3
}

sub _buildLabelHeir(){
  my ($self, $colVrow, $gap) = @_;
  
  my ($labHT, @IDs);
  if ($colVrow eq "col") {
    $labHT = $self->{"colLabOrder"};
    @IDs = $self->_getOrderedLabelIDs($labHT, $self->{Properties}->getValue($key_SortColKeyTxt),  
                                      $self->{Properties}->getValue($key_KeepColumnsInOutput));
  } else {
    $labHT = $self->{"rowLabOrder"};
    @IDs = $self->_getOrderedLabelIDs($labHT, $self->{Properties}->getValue($key_SortRowKeyTxt), 
				      $self->{Properties}->getValue($key_KeepRowsInOutput));
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
			  labels => [ _safeSplit("|",$id) ], 
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
  my ($self, $ht, $order, $IDsToKeep) = @_;
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

  my @keepIDs = ();
  my $filterIDs = 0;
  if (defined($IDsToKeep) && $IDsToKeep ne ""){
    $filterIDs = 1;
    @keepIDs = _safeSplit("|", $IDsToKeep);
  }
#  print "Checking $order\n";
  foreach my $sid (@sortedKeys) {
    if ($ht->{SubID}->{$sid}->{SubIDCount} > 0) {
      foreach my $labelID ($self->_getOrderedLabelIDs($ht->{SubID}->{$sid}), $order,  $IDsToKeep) {
        push @ids, "$sid|$labelID";
      }
      die;
    } else {
      if ($filterIDs == 0){
	push @ids, $sid
      } else {
	my $keep = 0;
	foreach my $exp(@keepIDs){
	  $keep = 1 if (grep(m%^$exp$%, $sid));
#          print "Check $exp $sid $keep\n";
	}
	push @ids, $sid if ($keep);
      }
    }
  }
#  print join (" ", @ids)."\n";
  MMisc::error_quit("No IDs in the output") if (@ids < 1);
  @ids;
}

sub _safeSplit{
  my ($matchStr, $text) = @_; 
#  return split(/$matchStr/, $text);
  my @arr = split(/(\|)/, $text);
  ### If the final item is a /|/, then there is no final empty element.  MAKE ONE NOW.
  push (@arr, "") if ($arr[$#arr] eq "|");
  ### Remove the /|/ symbols
  MMisc::filterArray(\@arr, "\\|");
#  print "Call $matchStr $text    (".join(",",@arr).")\n";
  ### Check to make sure there are NO empty elements.  If there are, then die
  foreach (@arr){
    die "Error: Column/row header \"$text\" contains empty items which is illegal." if ($_ eq "");
  } 
  @arr;
}

sub _getStrForLevel(){
  my ($self, $str, $lev) = @_;
  my @a = _safeSplit("|", $str);    
  $a[$lev-1];
}

sub setSpecial {
  my ($self, $colid, $rowid, $special) = @_;

  my $lid = $rowid."-".$colid;
  MMisc::error_quit("Datum for '$rowid $colid' does not exist, can not set \'special\'")
      if (! defined($self->{data}{$lid}));

  $self->{special}{$lid} = $special;
  return(1);
}

sub addData{
  my ($self, $val, $colid, $rowid, $special) = @_;
  
  $self->_addLab("col", $colid, $val);
  $self->_addLab("row", $rowid, $val);
  
  my $lid = $rowid."-".$colid;
  if (defined($self->{data}{$lid})) {
    print "Warning Datum for '$rowid $colid' has multiple instances.\n"; 
    return 1;
  }
  $self->{data}{$lid} = $val;
  if (defined $special) {
    $self->{special}{$lid} = $special;
#    print "[#####] {$lid} $special\n";
  }
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
  my $self = shift @_;
  my $file = shift @_;
  my ($qc, $sc) = MMisc::iuav(\@_, undef, undef);
  
  return($self->_set_error_and_return("Can not load a CSV to a AutoTable which already has data", 0))
    if ($self->{hasData});
  
  open FILE, "<$file"
    or return($self->_set_error_and_return("Could not open CSV file ($file): $!\n", 0));
  my @filec = <FILE>;
  close FILE;
  chomp @filec;
  
  my $csvh = new CSVHelper($qc, $sc);
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
  
  ### Make sure there is data.   If there isn't report nothing exists
  my @_da = keys %{ $self->{data} };
  return "Warning: Empty table.  Nothing to produce.\n" if (@_da == 0);

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
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $rowSort, $self->{Properties}->getValue($key_KeepRowsInOutput));
  my @colIDs = $self->_getOrderedLabelIDs($self->{"colLabOrder"}, "AsAdded", $self->{Properties}->getValue($key_KeepColumnsInOutput));
  
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

################## Access functions #########################################

sub getData{
  my ($self, $rowid, $colid) = @_;
  
  if (defined($self->{data}{$rowid."-".$colid})) {
    return $self->{data}{$rowid."-".$colid};
  }
  return("oiops");    
}

sub getColIDs{
  my ($self, $order) = @_;
  return $self->_getOrderedLabelIDs($self->{"colLabOrder"}, $order, $self->{Properties}->getValue($key_KeepColumnsInOutput));
}

sub getRowIDs{
  my ($self, $order) = @_;
  return $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $order, $self->{Properties}->getValue($key_KeepRowsInOutput));
}

sub hasColID{
  my ($self, $id) = @_;
  return exists($self->{"colLabOrder"}->{SubID}{$id});
}

sub hasRowID{
  my ($self, $id) = @_;
  return exists($self->{"rowLabOrder"}->{SubID}{$id});
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
