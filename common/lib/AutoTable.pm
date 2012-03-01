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

## Text
my $key_KeyColumnTxt   = "KeyColumnTxt";
my $key_SortRowKeyTxt   = "SortRowKeyTxt";
my $key_SortColKeyTxt   = "SortColKeyTxt";

## CSV
my $key_KeyColumnCsv   = "KeyColumnCsv";
my $key_SortRowKeyCsv   = "SortRowKeyCsv";
my $key_SortColKeyCsv   = "SortColKeyCsv";

## HTML
my $key_KeyColumnHTML  = "KeyColumnHTML";
my $key_SortRowKeyHTML  = "SortRowKeyHTML";
my $key_SortColKeyHTML  = "SortColKeyHTML";
my $key_htmlColHeadBGColor = "html.colhead.bgcolor";
my $key_htmlRowHeadBGColor = "html.rowhead.bgcolor";
my $key_htmlCellBGColor    = "html.cell.bgcolor";
my $key_htmlCellJust       = "html.cell.justification";

## LaTeX
my $key_KeyColumnLaTeX = "KeyColumnLaTeX";
my $key_SortRowKeyLaTeX = "SortRowKeyLaTeX";
my $key_SortColKeyLaTeX = "SortColKeyLaTeX";

##
my $key_KeepColumnsInOutput = "KeepColumnsInOutput";
my $key_KeepRowsInOutput    = "KeepRowsInOutput";

my @ok_specials = ("HTML", "CSV", "TEXT", "LaTeX");

#####

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

  ## Text
  $self->{Properties}->addProp($key_KeyColumnTxt,   "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_SortRowKeyTxt,   "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortColKeyTxt,   "AsAdded", ("AsAdded", "Num", "Alpha"));

  ## CSV
  $self->{Properties}->addProp($key_KeyColumnCsv,   "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_SortRowKeyCsv,   "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortColKeyCsv,   "AsAdded", ("AsAdded", "Num", "Alpha"));

  ## HTML
  $self->{Properties}->addProp($key_KeyColumnHTML,  "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_SortRowKeyHTML,  "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortColKeyHTML,  "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_htmlColHeadBGColor, "", ());
  $self->{Properties}->addProp($key_htmlRowHeadBGColor, "", ());
  $self->{Properties}->addProp($key_htmlCellBGColor, "", ());
  $self->{Properties}->addProp($key_htmlCellJust, "right", ("left", "center", "right"));

  ## LaTeX
  $self->{Properties}->addProp($key_KeyColumnLaTeX, "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_SortRowKeyLaTeX, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortColKeyLaTeX, "AsAdded", ("AsAdded", "Num", "Alpha"));

  ##
  $self->{Properties}->addProp($key_KeepColumnsInOutput, "", ());
  $self->{Properties}->addProp($key_KeepRowsInOutput, "", ());
    
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

sub __UT_showAllModes {
  my ($txt, $sg) = @_;

  print "<hr><h1>$txt</h1>\n";
  print "<h2>Text Rendering</h2>\n" . "<pre>\n" . $sg->renderTxtTable(2) . "</pre>\n";
  print "<h2>CSV Rendering</h2>\n" . "<pre>\n" . $sg->renderCSV() . "</pre>\n";
  print "<h2>LaTeX Rendering</h2>\n" . "<pre>\n" . $sg->renderLaTeXTable() . "</pre>\n";
  print "<h2>HTML Rendering</h2>\n" . $sg->renderHTMLTable() . "\n";
}

##

sub unitTest {
  my $makecall = shift @_;

  print "<html>\n<head><title>AutoTable UnitTest</title></head><body>";
  
  print "Testing AutoTable ..." if ($makecall);
  
  my $at = new AutoTable();
  print "Testing behavior on an empty table\n";
  MMisc::error_quit("Empty table not rendered correctly for TXT")
      if ($at->renderTxtTable() !~ /Warning: Empty table./);
  MMisc::error_quit("Empty table not rendered correctly for HTML")
      if ($at->renderHTMLTable() !~ /Warning: Empty table./);
  MMisc::error_quit("Empty table not rendered correctly for CSV")
      if ($at->renderCSV() !~ /Warning: Empty table./);
  MMisc::error_quit("Empty table not rendered correctly for LaTeX")
      if ($at->renderLaTeXTable() !~ /Warning: Empty table./);

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
 
  & __UT_showAllModes("Simple Table", $at);
  
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
  
  & __UT_showAllModes("Complex Table", $sg);

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
  & __UT_showAllModes("Complex Table = keepColumns .*PartA.*|PartB.*col4", $sg);
  
  $sg->setProperties({ $key_KeepRowsInOutput => ".*PartZ.*" });
  $sg->setProperties({ $key_htmlColHeadBGColor => "pink" });
  $sg->setProperties({ $key_htmlRowHeadBGColor => "orange" });
  $sg->setProperties({ $key_htmlCellBGColor => "read" });
  $sg->setProperties({ $key_htmlCellJust => "center" });
  & __UT_showAllModes("Complex Table = keepRows *PartZ.*, HTML props", $sg);
  
  $sg->setProperties({ $key_KeyColumnHTML => "Remove" });
  $sg->setProperties({ $key_KeyColumnTxt => "Remove" });
  $sg->setProperties({ $key_KeyColumnCsv => "Remove" });
  & __UT_showAllModes("Complex Table = remove key column", $sg);
  
  print "<hr>OK EXIT\n";

  print "</body></html>\n";
##=======
##  
##  print($sg->renderCSV());
##  
##>>>>>>> 1.3
  MMisc::ok_exit();
  
}

sub __getLID {
  # arg 0: Row ID
  # arg 1: Col ID
  return($_[0] . "-" . $_[1]);
}


sub _buildHeir(){
  my ($self, $gap) = @_;
  
  $self->_buildLabelHeir("col", $gap);
  $self->_buildLabelHeir("row", $gap);
}


sub __HTML_proc_sp {
  my ($str) = @_;

  my (@h1, @h2);

  if ($str =~ s%before\=\{([^\}]+?)\}%%) {
    push @h1, "$1";
  }

  if ($str =~ s%after\=\{([^\}]+?)\}%%) {
    unshift @h2, "$1";
  }

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
  # 'tha' = "table header adds" = HTML code added after <table
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
  MMisc::error_quit("Internal Error: No levels defined") if ($levels < 1);
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
  my $rowSort = $self->{Properties}->getValue($key_SortRowKeyHTML);
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $rowSort,
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
      my $lid = &__getLID($rowIDs[$row], $nodeSet[$node]{subs}[0]);
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
  MMisc::error_quit("Internal Error: No levels defined") if ($levels < 1);
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
##  MMisc::error_quit("Internal Error: No levels defined") if ($levels < 1);
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
  my $rowSort = $self->{Properties}->getValue($key_SortRowKeyTxt);
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
      $out .= " " . $self->_rightJust($self->{data}{&__getLID($rowIDStr, $nodeSet[$node]{subs}[0])}, $nodeSet[$node]{width} - 2) . " |";
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
###      $out .= " " . $self->_rightJust($self->{data}{&__getLID($rowIDStr, $nodeSet[$node]{subs}[0])}, $nodeSet[$node]{width} - 2) . " |";
###    }
###    
###    $out .= "\n";
###  }   
###  $out;
###>>>>>>> 1.3
}

##########

sub __latex_escape {
  my ($txt) = @_;

  my $out = "";
  while ($txt =~ s%^(.*?)([\\\{\}\&\#\%\_\^\~\$])%%) {
    $out .= "$1\\$2";
  }
  $out .= $txt;

  return($out);
}

sub __latexit {
  my ($text, $ncols, $nrows, $x, $y, $rs) = @_;

  if ($$rs{$x}{$y} > 0) {
    return("") if ($ncols < 2);
    $nrows = 1;
  }
  
  for (my $px = $x; $px < $x + $ncols; $px++) {
    for (my $py = $y; $py < $y + $nrows; $py++) {
      $$rs{$px}{$py}++;
    }
  }

  my $out = "";

  # columns before lines
  $out .= "\\multicolumn\{$ncols\}\{\|c\|\}\{" if ($ncols > 1);
  $out .= "\\multirow\{$nrows\}\{*\}\{" if ($nrows > 1);
  $out .= &__latex_escape($text);
  $out .= "\}" if ($nrows > 1);
  $out .= "\}" if ($ncols > 1);

  return($out);
}

##

sub renderLaTeXTable(){
  my ($self) = @_;
  my $out = "";

  ### Make sure there is data.   If there isn't report nothing exists
  my @_da = keys %{ $self->{data} };
  return "Warning: Empty table.  Nothing to produce.\n" if (@_da == 0);
  
  ##########
  my $keyCol = $self->{Properties}->getValue($key_KeyColumnLaTeX);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_KeyColumnHTML property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my $k1c = ($keyCol eq "Keep") ? 1 : 0;
  
  $self->_buildHeir(1);
  
#    print Dumper($self);
  my @IDs = $self->{render}{colIDs};
  my $levels = $self->{render}{colLabelLevels};
  
  my @nodeSet;
  my $headers = "";
  my $ncols = 0;
  MMisc::error_quit("Internal Error: No levels defined") if ($levels < 1);
  my %skip = ();
  my ($x, $y) = (0, 0);
  for (my $level=0; $level < $levels; $level++){
    my @line = ();
    ### Render the row data 
    my $numRowHead = scalar(@{ $self->{render}{rowLabelWidth} });
    push @line, &__latexit(" ", $numRowHead, $levels, $x, $y, \%skip); $x += $numRowHead;
    $ncols += $numRowHead;

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
      push @line, &__latexit($nodeSet[$node]{id}, $ncol, 1); $x += $ncol;
      $ncols += $ncol;
    }
    $headers .= join(" & ", @line) . "\\\\" . "\n"; $y++; $x = 0;
    if (MMisc::is_blank($out)) {
      $out .= "\%\% add to document header: \\usepackage\{multirow\}\n";
      $out .= "\\begin{tabular}{";
      for (my $i = 0; $i < $ncols; $i++) { $out .= '|c'; }
      $out .= "|}\n";
      $out .= "\\hline\n";
    }
  }
  $out .= $headers;
  $out .= "\\hline\n";
  
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
    my @line = ();
    
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
          push @line, &__latexit($ids[$rowLevel], 1, $span, $x, $y, \%skip); $x++;
	} else {
          push @line, &__latexit($ids[$rowLevel], 1, 1, $x, $y, \%skip); $x++;
	}
	
	$lastRowLabel[$rowLevel] = $ids[$rowLevel];
      }
    }
    for (my $node=0; $node<@nodeSet; $node++) {
      my $lid = &__getLID($rowIDs[$row], $nodeSet[$node]{subs}[0]);
      my $str = defined($self->{data}{$lid}) ? $self->{data}{$lid} : "&nbsp;";
      my ($h1, $h2) = ("", "");
#      print "[$lid]\n";
      ($h1, $h2) = &__process_special($ok_specials[0], $self->{special}{$lid}) 
        if (exists $self->{special}{$lid});
      push @line, &__latexit($str, 1, 1, $x, $y, \%skip); $x++;
    }
    $out .= join(" & ", @line) . '\\\\' . "\n"; $y++; $x = 0;
  }   
  $out .= "\\hline\n";
  $out .= "\\end\{tabular\}\n";

#  print "[$x][$y]\n";
#  foreach my $x (sort {$a <=> $b} keys %skip) {
#    foreach my $y (sort {$a <=> $b} keys %{$skip{$x}}) {
#      my $v = $skip{$x}{$y};
#      $v = ($v > 0) ? $v : 0;
#      print "$v ";
#    }
#    print "\n";
#  }

  return($out);
}

##########

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
    MMisc::error_quit("[AutoTable] Inconsistent number of $colVrow sublevels for id '$id' not $levels\n")
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
    MMisc::error_quit("Internal Error on recursion") if ($minWidth > $thisWidth);
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
      MMisc::error_quit($pre."Internal Error: ($minWidth < $thisWidth)") if ($minWidth < $thisWidth);
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
    MMisc::error_quit("Column/row header \"$text\" contains empty items which is illegal") if ($_ eq "");
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

  my $lid = &__getLID($rowid, $colid);
  MMisc::error_quit("Datum for '$rowid $colid' does not exist, can not set \'special\'")
      if (! defined($self->{data}{$lid}));

  $self->{special}{$lid} = $special;
  return(1);
}

##########

sub addData__core {
  my ($self, $val, $colid, $rowid, $special, $unique) = @_;
  
  $self->_addLab("col", $colid, $val);
  $self->_addLab("row", $rowid, $val);
  
  my $lid = &__getLID($rowid, $colid);
  if (defined($self->{data}{$lid})) {
    if ($unique) {
      print "Warning Datum for '$rowid $colid' has multiple instances (not replacing)\n"; 
      return 1;
    }
    $unique = -1; # replacement (no add)
  }
  $self->{data}{$lid} = $val;
  if (! MMisc::is_blank($special)) {
    $self->{special}{$lid} = $special;
  }
  $self->{hasData}++ if ($unique != -1); 
  
  return(1);
}

#####

sub addData {
  my ($self, $val, $colid, $rowid, $special) = @_;
  return($self->addData__core($val, $colid, $rowid, $special, 1));
}

#####

sub setData {
  my ($self, $val, $colid, $rowid, $special) = @_;
  return($self->addData__core($val, $colid, $rowid, $special, 0));
}

##########

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

sub create_MasterKey {
  # arg 0: self
  # args : column components in order
  my $self = shift @_;
  return(join("_____", @_));
}

#####

sub __check_zero_array_ref {
  return("", undef) if (! defined $_[0]);
  return("Not a REF to ARRAY", undef)
    if (ref($_[0]) ne 'ARRAY');
  return("", undef)
    if (scalar @{$_[0]} == 0);
  return("", $_[0]);
}

##

sub __loadCSVcore {
  my $self = shift @_;
  my $file = shift @_; # CSV file to load
  my $sp_file = shift @_; # Special CSV to load
  my ($rmkc, $rk, $rr, $qc, $sc, $sp_qc, $sp_sc) = MMisc::iuav(\@_, undef, undef, undef, undef, undef, undef, undef);
  ## $rmkc: ref to @ "master key columns" (if not given, use builtin)
  # $rk : ref to @ "to keep headers"
  # $rr : ref to @ "to remove headers"
  # will not stop for columns not found
  ## 'qc' & 'sc': Quote character (quote_char) and Separator character (sep_char)
  # if not modifying a value make sure to set to 'undef' so that defaults are used
  # refer to Text::CSV's perldoc for more details

  return($self->_set_error_and_return("Can not load a CSV to a AutoTable which already has data", 0))
    if ($self->{hasData});
  
  my $err;

  ($err, $rmkc) = &__check_zero_array_ref($rmkc);
  return($self->_set_error_and_return("Issue with AutoTable's reference to master key columns: $err", 0))
    if (! MMisc::is_blank($err));

  ($err, $rk) = &__check_zero_array_ref($rk);
  return($self->_set_error_and_return("Issue with AutoTable's reference to keep header: $err", 0))
    if (! MMisc::is_blank($err));

  ($err, $rr) = &__check_zero_array_ref($rr);
  return($self->_set_error_and_return("Issue with AutoTable's reference to \"to remove headers\": $err", 0))
    if (! MMisc::is_blank($err));

  return($self->_set_error_and_return("Can not both remove and keep headers at the same time", 0))
    if ((defined $rk) && (defined $rr));

  my $withSpecial = (MMisc::is_blank($sp_file)) ? 0 : 1;

  open FILE, "<$file"
    or return($self->_set_error_and_return("Could not open CSV file ($file): $!\n", 0));
  my @filec = <FILE>;
  close FILE;
  chomp @filec;
  
  my @sp_filec = ();
  if ($withSpecial) {
    open FILE, "<$sp_file"
      or return($self->_set_error_and_return("Could not open Special CSV file ($sp_file): $!\n", 0));
    @sp_filec = <FILE>;
    close FILE;
    chomp @sp_filec;
    return($self->_set_error_and_return("Not the same number of lines between CSV file and Special CSV file (" . scalar @filec . " vs " . scalar @sp_filec . ")", 0))
      if (scalar @filec != scalar @sp_filec);
  } 

  return($self->_set_error_and_return("Not content in CSV file or header only ? (\# lines: " . scalar @filec . ")", 0))
    if (scalar @filec < 2);

  my $csvh = new CSVHelper($qc, $sc);
  return($self->_set_error_and_return("Problem creating CSV handler", 0))
    if (! defined $csvh);
  return($self->_set_error_and_return("Problem with CSV handler: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());

  my $sp_csvh = undef;
  if ($withSpecial) {
    $sp_csvh = new CSVHelper($sp_qc, $sp_sc);
    return($self->_set_error_and_return("Problem creating Special CSV handler", 0))
      if (! defined $sp_csvh);
    return($self->_set_error_and_return("Problem with Special CSV handler: " . $sp_csvh->get_errormsg(), 0))
      if ($sp_csvh->error());
  }
  
  my %csv = ();
  my %sp_csv = ();
  my %elt1 = ();
  my @order = ();
  my $inc = 0;
  for (my $i = 0; $i < scalar @filec; $i++) {
    my $line = $filec[$i];
    my $sp_line = ($withSpecial) ? $sp_filec[$i] : "";
    
    my $key = sprintf("File: $file | Line: %012d", $inc);
    my @cols = $csvh->csvline2array($line);
    return($self->_set_error_and_return("Problem with CSV line: " . $csvh->get_errormsg(), 0))
      if ($csvh->error());

    my @sp_cols = ();
    if ($withSpecial) {
      @sp_cols = $sp_csvh->csvline2array($sp_line);
      return($self->_set_error_and_return("Problem with Special CSV line: " . $sp_csvh->get_errormsg(), 0))
        if ($sp_csvh->error());
      return($self->_set_error_and_return("Problem with Special CSV line: no the same number of columns between main CSV and Special CSV (" . scalar @cols . " vs " . scalar @sp_cols . ")", 0))
        if (scalar @cols  != scalar @sp_cols);
    }


    if ($inc > 0) {
      $elt1{$cols[0]}++;
    } else {
      $csvh->set_number_of_columns(scalar @cols);
      $sp_csvh->set_number_of_columns(scalar @cols) if ($withSpecial);
    }
    
    push @order, $key;
    push @{$csv{$key}}, @cols;
    if ($withSpecial) {
      push @{$sp_csv{$key}}, @sp_cols;
    }

    $inc++;
  }
  
  $self->setProperties({ "$key_KeyColumnCsv" => "Remove", "$key_KeyColumnTxt" => "Remove", "$key_KeyColumnHTML" => "Remove"});

  my @colIDs = @{$csv{$order[0]}};

  my %match = MMisc::array1d_to_ordering_hash(\@colIDs);
  if (defined $rmkc) {
    my @nf = ();
    for (my $i = 0; $i < scalar @$rmkc; $i++) {
      push(@nf, $$rmkc[$i]) if (! exists $match{$$rmkc[$i]});
    }
    return($self->_set_error_and_return("Can not load a CSV to a AutoTable: missing required MasterKey columns:" . join(", ", @nf), 0))
      if (scalar @nf > 0);
  }

  my %rem = ();
  if (defined $rr) {
    for (my $i = 0; $i < scalar @$rr; $i++) {
      $rem{$$rr[$i]}++;
    }
  }
  if (defined $rk) {
    my %t = MMisc::array1d_to_count_hash($rk);
    for (my $i = 0; $i < scalar @colIDs; $i++) {
      $rem{$colIDs[$i]}++ if (! exists $t{$colIDs[$i]});
    }
  }

  for (my $i = 1; $i < scalar @order; $i++) {
    my $key = $order[$i];
    my @a = @{$csv{$key}};
    my @sp_a = ($withSpecial) ? @{$sp_csv{$key}} : ();
    my $ID = $key;
    if (defined $rmkc) {
      my @t = ();
      for (my $k = 0; $k < scalar @$rmkc; $k++) {
        push @t, $a[$match{$$rmkc[$k]}];
      }
      $ID = $self->create_MasterKey(@t);
    }
    
    for (my $j = 0; $j < scalar @a; $j++) {
      next if (exists $rem{$colIDs[$j]});
      $self->setData($a[$j], $colIDs[$j], $ID);
      $self->setSpecial($colIDs[$j], $ID, $sp_a[$j]) if (! MMisc::is_blank($sp_a[$j]));
    }
  }
  
  return(1);
}

#####

sub loadCSV {
  # arg 0: self
  # arg 1: CSV file to load
  # arg 2: reference to header columns used to make table's line masterkey
  #   useful to do manipulations later, can create line key using $self->create_MasterKey(@columns)
  #   warning: duplicate data will be replaced
  #   if 'undef' is used a default unique key per line will be used
  #   will fail if any column is not found in the CSV file
  # arg 3: header columns to keep (remove all else)
  # arg 4: header columns to remove (keep all else)
  # arg 5 Text::CSV's quote_char
  # arg 6: Text::CSV's sep_char (use 'undef' is not changed, will cause issues otherwise)
  ## arg 2 to 6 are optional
  ## WARNING: for args 2 to 6 , use 'undef' instead of <empty> if not using functionality (will cause issues otherwise)
  # ex: do not use loadCSV($f, , , , , "\t")
  #     but use loadCSV($f1, undef, undef, undef, undef, "\t")
  #     to load a Tab separated file

  my $self = shift @_;
  my $file = shift @_;
  my ($rmkc, $rk, $rr, $qc, $sc) = MMisc::iuav(\@_, undef, undef, undef, undef, undef);
  return($self->__loadCSVcore($file, undef, $rmkc, $rk, $rr, $qc, $sc));
}

#####

sub loadCSVandSpecial {
  # arg 0: self
  # arg 1: CSV file to load
  # arg 2: Special CSV file to load
  # arg 3: reference to header columns used to make table's line masterkey (see 'loadCSV' for notes)
  # arg 4: header columns to keep (remove all else) (see 'loadCSV' for notes)
  # arg 5: header columns to remove (keep all else) (see 'loadCSV' for notes)
  # arg 6: Text::CSV's quote_char
  # arg 7: Text::CSV's sep_char
  # arg 8: Text::CSV's quote_char for Special
  # arg 9: Text::CSV's sep_char for Special
  ## WARNING: args 3 to 9 are optional and follow the warning detailed in 'loadCSV'

  my $self = shift @_;
  my $file = shift @_;
  my $sp_file = shift @_;
  my ($rmkc, $rk, $rr, $qc, $sc, $sp_qc, $sp_sc) = MMisc::iuav(\@_, undef, undef, undef, undef, undef, undef, undef);
  return($self->_set_error_and_return("No Special CSV file specified ?", 0))
    if (MMisc::is_blank($sp_file));
  return($self->__loadCSVcore($file, $sp_file, $rmkc, $rk, $rr, $qc, $sc, $sp_qc, $sp_sc));
}

##########

sub __renderCSVcore {
  my $self = shift @_;
  my ($withSpecial, $qc, $sc) = MMisc::iuav(\@_, undef, undef, undef);
  # $qc: Text::CSV's quote_char
  # $sc: Text::CSV's sep_char
  
  ### Make sure there is data.   If there isn't report nothing exists
  my @_da = keys %{ $self->{data} };
  return "Warning: Empty table.  Nothing to produce.\n" if (@_da == 0);

  my $out = "";
  my $sp_out = "";

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
  my $colSort = $self->{Properties}->getValue($key_SortColKeyCsv);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to to return get the $key_SortColKeyCsv property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }

  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $rowSort, $self->{Properties}->getValue($key_KeepRowsInOutput));
  my @colIDs = $self->_getOrderedLabelIDs($self->{"colLabOrder"}, $colSort, $self->{Properties}->getValue($key_KeepColumnsInOutput));
  
  my $csvh = new CSVHelper($qc, $sc);
  return($self->_set_error_and_return("Problem creating CSV handler", 0))
    if (! defined $csvh);
  return($self->_set_error_and_return("Problem with CSV handler: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());

  my $sp_csvh = new CSVHelper($qc, $sc);
  return($self->_set_error_and_return("Problem creating CSV handler", 0))
    if (! defined $sp_csvh);
  return($self->_set_error_and_return("Problem with CSV handler: " . $sp_csvh->get_errormsg(), 0))
    if ($sp_csvh->error());
  
  ### Header output
  my @line = ();
  push @line, "MasterKey" if ($k1c);
  push @line, @colIDs;
  my $txt = $csvh->array2csvline(@line);
  return($self->_set_error_and_return("Problem with CSV array: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());
  $out .= "$txt\n";
  $csvh->set_number_of_columns(scalar @line);
  if ($withSpecial) {
    $sp_csvh->set_number_of_columns(scalar @line);
    $sp_out .= "$txt\n";
  }

  # line per line
  foreach my $rowIDStr (@rowIDs) {
    my @line = ();
    my @sp_line = ();
    push @line, $rowIDStr if ($k1c);
    push @sp_line, $rowIDStr if ($k1c);
    foreach my $colIDStr (@colIDs) {
      my $lid = &__getLID($rowIDStr, $colIDStr);
      push @line, $self->{data}{$lid};
      if ($withSpecial) {
        if (exists $self->{special}{$lid}) {
          push @sp_line, $self->{special}{$lid};
        } else {
          push @sp_line, "";
        }
      }
    }
    my $txt = $csvh->array2csvline(@line);
    return($self->_set_error_and_return("Problem with CSV array: " . $csvh->get_errormsg(), 0))
      if ($csvh->error());
    $out .= "$txt\n";
    if ($withSpecial) {
      my $txt = $sp_csvh->array2csvline(@sp_line);
      return($self->_set_error_and_return("Problem with CSV array: " . $sp_csvh->get_errormsg(), 0))
        if ($sp_csvh->error());
      $sp_out .= "$txt\n";
    }
  }
  
  return($out) if (! $withSpecial);
  return($out, $sp_out);
}

#####

sub renderCSV { return($_[0]->__renderCSVcore(0, $_[1], $_[2])); }

sub renderCSVandSpecial { return($_[0]->__renderCSVcore(1, $_[1], $_[2])); }


################## Access functions #########################################

sub getData{
  my ($self, $rowid, $colid) = @_;
  
  if (defined($self->{data}{&__getLID($rowid, $colid)})) {
    return $self->{data}{&__getLID($rowid, $colid)};
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
