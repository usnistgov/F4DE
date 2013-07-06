#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# CSVUtil
#
# Author(s): Martial Michel
#

# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CSVUtil.pl" is an experimental system.
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


# $Id$

use strict;
use Statistics::Descriptive;

my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../../common/lib");
}
use lib (@f4bv);

use Data::Dumper;
use AutoTable;
use MMisc;

my $Usage = 
"CSVUtil.pl [-v | [-n colName=val] ] -i InCSV|- -o outCSV|- -r row1|row2|... -c column1|column2|... \n".
"    --or-- [-v | [-n colName=val] ] -i InCSV|- -a outAutoTable -R column1|column2|... -C column1|column2|... -V column1 \n".
"    --or-- [-v | [-n colName=val] ] -i InCSV|- -q setOfValues -C column1|column2|... -V column1 \n".
"    --or-- [-v | [-n colName=val] ] -i InCSV|- -Info\n".
"Desc:  Read in a csv file extracting ONLY the specified columns and writing them to the output file.\n".
"       -n colName=val adds a column header as 'colName' with the value 'val' for all rows.  -n may be used many times.\n".
"       -q returns a table for values for the columns.\n".
"       -QuoteChar <char> sets the quote charater\n".
"       -SepChar <char> sets the column separator.  The special value <TAB> will bv converted to a 'tab' character.\n";

my $in = undef;
my $outCSV = undef;
my $outAT = undef;
my $col = undef;
my $row = undef;
my @ATcol = ();
my @ATrow = ();
my $ATval = undef;
my $reverse = 0;
my @outputTypes = ();
my $quiet = 0;
my $statForRow = "";
my $statForCol = "";
my $printInfo = undef;
my $outUniqQuery = undef;
my $encoding = "UTF-8";
my $quoteChar = undef;
my $sepChar = undef;
my @extraCol = ();

use Getopt::Long;
Getopt::Long::Configure ("bundling", "no_ignore_case");
my $result = GetOptions ("i=s" => \$in,
			 "o=s" => \$outCSV,
			 "a=s" => \$outAT,
			 "q=s" => \$outUniqQuery,
			 "c=s" => \$col,
			 "r=s" => \$row,
			 "R=s@" => \@ATrow,
			 "V=s" => \$ATval,
			 "C=s@" => \@ATcol,
			 "OutputType=s@" => \@outputTypes,
			 "quiet" => \$quiet,
			 "statForRow=s" => \$statForRow,
			 "statForCol=s" => \$statForCol,
			 "encoding=s" => \$encoding,
			 "Info" => \$printInfo,
			 "QuoteChars=s" => \$quoteChar,
			 "SepChar=s" => \$sepChar,
			 "-v"  => \$reverse,
       "n=s@" => \@extraCol,
			 );
MMisc::error_quit("Aborting:\n$Usage\n:") if (!$result);

push(@outputTypes, "csv") if (@outputTypes == 0);

MMisc::error_quit("Argument -i req'd\n" . $Usage) if (!defined($in));
MMisc::error_quit("An argument for output is req'd either -I, -o, -n, or -a req'd\n" . $Usage) if (!defined($outCSV) && !defined($outAT) && !defined($printInfo) && !defined($outUniqQuery) && @extraCol == 0);
foreach my $otype(@outputTypes){
  MMisc::error_quit("OutputType $otype not (csv|txt|html|tgrid)\n" . $Usage) if ($otype !~ /^(csv|txt|html|tgrid)$/);
}
MMisc::error_quit("statForRow not (continuous|discrete)\n" . $Usage) if ($statForRow !~ /^(continuous|discrete|)$/);
MMisc::error_quit("statForCol not (continuous|discrete)\n" . $Usage) if ($statForCol !~ /^(continuous|discrete|)$/);

### Handle the tab character
$sepChar = "\t" if ($sepChar eq "\\t" || $sepChar eq "<TAB>");

### Check the extra column data transforming it into a usable hash
if (@extraCol > 0){
  for (my $d=0; $d<@extraCol; $d++){
    die "Error: Can't process extra column data /$extraCol[$d]/ !~ /^(\S+)=(.+)\$/" if ($extraCol[$d] !~ /^(\S+)=(.+)$/);
    $extraCol[$d] = {header => $1, val => $2};
    $col .= "|$1" if ($col ne "");
  }
}

if ($outAT ne "-" && $outCSV ne "-" && $outUniqQuery ne "-"){
  print "Info: KeepColumns = $col\n" if (!$quiet);
  print "Info: KeepRows = $row\n" if (!$quiet);
  print "Info: outputTypes = (".join(", ",@outputTypes).")\n" if (!$quiet);
  print "Info: statForRow = $statForRow\n" if (!$quiet);
  print "Info: statForCol = $statForCol\n" if (!$quiet);
  print "Info: quoteChar = ".(!defined($quoteChar) ? "UNDEF" : (($quoteChar eq "") ? "EMPTY" : $quoteChar))."\n" if (!$quiet);
  print "Info: sepChar = ".(!defined($sepChar) ? "UNDEF" : (($sepChar eq "\t") ? "<TAB>" : $sepChar))."\n" if (!$quiet);
}


my $at = new AutoTable(); 
$at->setEncoding($encoding);
if (! $at->loadCSV($in, undef, undef, undef, $quoteChar, $sepChar)) {
  die("Error: Failed to load CSV file '$in' ".$at->get_errormsg());
}

### Add the extra columns  
for (my $d=0; $d<@extraCol; $d++){
  foreach my $row($at->getRowIDs("AsAdded")){ 
    my $val = $extraCol[$d]->{val};
    my $newVal = "";
    if ($val =~ /^{ (\$val{(.+)}) \=\~ (s\/(.*)\/(.*)\/(.*)) }$/){
      my $seedField = $2;
      my $seedOp1 = $4;
      my $seedOp2 = $5;
      my $seedOp3 = $6;
      my $seedValue = $at->getData($seedField, $row);       $seedValue = "" if (! defined($seedValue));
      my $exp = $3;
      eval "(\$newVal = \$seedValue) =~ s/$seedOp1/$seedOp2/$seedOp3;\n";
    } elsif ($val =~ /^{ (\$val{(.+)}) \=\~ (.*) \? (.*) \: (.*) }$/){
      ## { ($val{Event} =~ /E1/) ? "New" : "Old") }
      my $seedField = $2;
      my $seedOp1 = $3;
      my $seedOp2 = $4;
      my $seedOp3 = $5;
      my $seedValue = $at->getData($seedField, $row);       $seedValue = "" if (! defined($seedValue));

      eval "\$newVal = \$seedValue =~ $seedOp1 ? $seedOp2 : $seedOp3\n";
    } else {
      $newVal = $val;
    }
    $at->addData($newVal,$extraCol[$d]->{header},$row);
  }
}


if (defined($printInfo)){
  use Statistics::Descriptive;
  print "Information about $in\n";
  print scalar($at->getRowIDs("AsAdded"))." Rows:\n";
  print scalar($at->getColIDs("AsAdded"))." Columns: \n";
  my $colNum = 1;
  foreach my $col($at->getColIDs("AsAdded")){
      my $type = $col; 
      $type =~ s/^(.*)(_d|_c|_t|_b|ID)$/$2/;
      $type = "text" if ($type eq $col);
      print "  ".$colNum++.": $type $col -> ";
      if ($type =~ /^(_b|_d)$/){
          my %ht = ();
          foreach my $row($at->getRowIDs("AsAdded")){ 
              my $val = $at->getData($col, $row);
              $ht{$val}++;
          }
          foreach my $val(sort keys %ht){ print " $val->".$ht{$val}}
      } elsif ($type =~ /^(_c)$/){
          my $stat = Statistics::Descriptive::Full->new();
          my $unk = 0;
          my $invalid = 0;
          foreach my $row($at->getRowIDs("AsAdded")){ 
              my $val = $at->getData($col, $row);
              if (! defined($val)){
                  $unk++;
              } elsif ($val !~ /^-?\d+\.?\d*$/){
                  $invalid++;
              } else {
                  $stat->add_data($val);
              }
          }
          print "#unk=$unk, #invalid=$invalid, #val=".$stat->count().", min=".$stat->min().", mean=".$stat->mean().", median=".$stat->median().", max=".$stat->max();
      } else {
          ;
      }
      print "\n";
  }
  
  
}

if (defined($outCSV)){
  MMisc::error_quit("Error: Argument -c, -n, and/or -r req'd\n" . $Usage) if (!defined($col) && !defined($row) && (@extraCol == 0));

  $at->setProperties({ "KeepColumnsInOutput" => $col }) if (defined($col)); 
  $at->setProperties({ "KeepRowsInOutput" => $row }) if (defined($row)); 

  foreach my $otype(@outputTypes){
    MMisc::writeTo("$outCSV"  . ($outCSV eq "-" ? "" : ".$otype"), "", 1, 0, $at->renderByType($otype));
  }
} 

if (defined($outUniqQuery)){
  MMisc::error_quit("Error: -C, and -V req'd\n" . $Usage) if (@ATcol == 0 || !defined($ATval));

  ### Go through the Keys for matching expressions
  my @outColIDs = (); my %uniqOutColIDs = ();
  my @outRowColIDs = (); my %uniqRowOutColIDs = ();
  my @outValueColIDs = (); my %uniqValueOutColIDs = ();
  foreach my $colDef(@ATcol){
    foreach my $colID($at->getColIDs("AsAdded")){
      if ($colID =~ /$colDef/){
        push @outColIDs, $colID if (! exists($uniqOutColIDs{$colID}));
        $uniqOutColIDs{$colID} = 1;
      }
    }
  }
#  print "Query columns: ".join(" ", @outColIDs)."\n";
  my %ht = ();
  foreach my $rowIDStr ($at->getRowIDs("AsAdded")) {
    my $key = "";
    foreach my $colID(@outColIDs){
      $key .= "_$colID=".$at->getData($colID, $rowIDStr);
    }
    $key =~ s/^_//;
#    print "$key\n";
    push (@{ $ht{$key} }, $at->getData($ATval, $rowIDStr));
  
  }

  foreach my $key(sort keys %ht){
    MMisc::writeTo("$outUniqQuery" , "", 1, 1, "$key -> ".join(" ",@{ $ht{$key} })."\n");
  }
  
  
} elsif (defined($outAT)){
  MMisc::error_quit("Error: -C, -V, and -R req'd\n" . $Usage) if (@ATcol == 0 || @ATrow == 0 || !defined($ATval));

  ### Go through the Keys for matching expressions
  my @outColIDs = (); my %uniqOutColIDs = ();
  my @outRowColIDs = (); my %uniqRowOutColIDs = ();
  my @outValueColIDs = (); my %uniqValueOutColIDs = ();
  foreach my $colDef(@ATcol){
    foreach my $colID($at->getColIDs("AsAdded")){
      if ($colID =~ /$colDef/){
        push @outColIDs, $colID if (! exists($uniqOutColIDs{$colID}));
        $uniqOutColIDs{$colID} = 1;
      }
    }
  }
  print "Info: Column colIds (".join(",",@ATcol).") - ".join(", ",@outColIDs)."\n" if (!$quiet);
  MMisc::error_quit("-C resulted in no columns") if (@outColIDs == 0);
  ###
  foreach my $colDef(@ATrow){
    foreach my $colID($at->getColIDs("AsAdded")){
      if ($colID =~ /$colDef/){
        push @outRowColIDs, $colID if (! exists($uniqRowOutColIDs{$colID}));
        $uniqRowOutColIDs{$colID} = 1;
      }
    }
  }
  print "Info: Row colIds (".join(",",@ATrow).")  - ".join(", ",@outRowColIDs)."\n" if (!$quiet);
  MMisc::error_quit("-R resulted in no columns for rows") if (@outRowColIDs == 0);
  ###
  foreach my $colDef($ATval){
    foreach my $colID($at->getColIDs("AsAdded")){
      if ($colID =~ /$colDef/){
        push @outValueColIDs, $colID if (! exists($uniqValueOutColIDs{$colID}));
        $uniqValueOutColIDs{$colID} = 1;
      }
    }
  }
  print "Info: Value colIds ($ATval) - ".join(", ",@outValueColIDs)."\n" if (!$quiet);
  MMisc::error_quit("-V resulted in no columns for cel values") if (@outValueColIDs == 0);

  my $newAt = new AutoTable(); 
  $newAt->setEncoding($encoding);
  foreach my $rowIDStr ($at->getRowIDs("AsAdded")) {
    ### Build the column label
    my ($colLab, $rowLab, $val) = ("", "", "");
    my $stat = Statistics::Descriptive::Full->new();
   
    for (my $i=0; $i<@outRowColIDs; $i++){
      $rowLab .= ($i != 0 ? "|" : "") . $at->getData($outRowColIDs[$i], $rowIDStr);
    }
    for (my $i=0; $i<@outColIDs; $i++){
      $colLab .= ($i != 0 ? "|" : "") . $at->getData($outColIDs[$i], $rowIDStr);
      for (my $j=0; $j<@outValueColIDs; $j++){
        $val .= ($j != 0 ? " " : "") . $at->getData($outValueColIDs[$j], $rowIDStr);
      }
      $newAt->addData($val, $outValueColIDs[$i]."|".$colLab, $rowLab);
    }
  }

  my @rowIDS = $newAt->getRowIDs("AsAdded");
  my @colIDS = $newAt->getColIDs("AsAdded");
  my $statColIDStr = undef;
  my %statRowValues = ();
  my %allDiscreteKeys = ();
  my $colStatLab = undef;

  if ($statForRow ne ""){
    foreach my $rowIDStr (@rowIDS) {
      next if ($row ne "" && $rowIDStr !~ /^($row)$/);
      
      my $stat = Statistics::Descriptive::Full->new();
      my %statDiscrete = ();
      foreach my $colIDStr (@colIDS) {
        if (! defined($statColIDStr)){
          ($statColIDStr = $colIDStr) =~ s/[^|]+\|/ |/g;
          $statColIDStr =~ s/\|[^\|]+$/| /g;
        }
        my $val = $newAt->getData($colIDStr, $rowIDStr);
        if ($statForRow eq "continuous"){
          $val =~ s/\s+//g;
          $stat->add_data($val);
        } elsif ($statForRow eq "discrete") {
          $statDiscrete{$val} = 0 if (!exists($statDiscrete{$val}));
          $statDiscrete{$val} ++;        
        }
      }
      if (! defined($colStatLab)){
        $colStatLab = $statColIDStr;
        $colStatLab =~ s/\|\s*$//;
      }
      if ($statForRow eq "continuous"){
        $newAt->addData($stat->count(), $colStatLab."Stat|Count", $rowIDStr); 
        $newAt->addData(sprintf("%.4f",$stat->min()), $colStatLab."Stat|Min", $rowIDStr); 
        $newAt->addData(sprintf("%.4f",$stat->mean()), $colStatLab."Stat|Mean", $rowIDStr);
        $newAt->addData(sprintf("%.4f",$stat->median()), $colStatLab."Stat|Median", $rowIDStr);
        $newAt->addData(sprintf("%.4f",$stat->max()), $colStatLab."Stat|Max", $rowIDStr);
        $newAt->addData(sprintf("%.4f",$stat->standard_deviation()), $colStatLab."Stat|StdDev", $rowIDStr);
        $statRowValues{Mean}{$rowIDStr} = sprintf("%.4f",$stat->mean());
        $statRowValues{Median}{$rowIDStr} = sprintf("%.4f",$stat->median());      
      } elsif ($statForRow eq "discrete") {
        ### If I have for room in the colums for lab so use it
        foreach my $key(keys %statDiscrete){
          my $skey = ($key eq "" ? " " : $key);
          $newAt->addData($statDiscrete{$key}, $colStatLab."Value|$skey", $rowIDStr);
          $allDiscreteKeys{$skey} = 1;
        }
#        $newAt->addData($count, $colStatLab."Summary|Count", $rowIDStr);
      } 
    }
  }
  ### Add zero values for discrete
  if ($statForRow eq "discrete") {
    foreach my $rowIDStr (@rowIDS) {
      foreach my $discKey(keys %allDiscreteKeys){
        my $val = $newAt->getData($colStatLab."Value|$discKey", $rowIDStr);
        $newAt->addData(0, $colStatLab."Value|$discKey", $rowIDStr) if (!defined($val));
      }
    }
  }

  ### Compute the ordinals
  if ($statForRow eq "continuous"){
    foreach my $stat("Mean", "Median"){
      my $ranks = getRanks($statRowValues{$stat}, 0.01);
      foreach my $rowid(keys %$ranks){
        $newAt->addData($ranks->{$rowid}, $colStatLab."Rank|$stat", $rowid); 
      }
    }
  }

  my %statColValues = ();
  my $statRowIDStr = undef;
  if ($statForCol ne ""){
    my $rowStatLab = undef;
    my %statDiscrete = ();
    foreach my $colIDStr (@colIDS) {
      my $stat = Statistics::Descriptive::Full->new();
      foreach my $rowIDStr (@rowIDS) {
        next if ($row ne "" && $rowIDStr  !~ /^($row)$/);
        if (! defined($statRowIDStr)){
          ($statRowIDStr = $rowIDStr) =~ s/[^|]+\|/ |/g;
          $statRowIDStr =~ s/\|[^\|]+$/| /g;
        }
        my $val = $newAt->getData($colIDStr, $rowIDStr);
        if ($statForCol eq "continuous"){
          $val =~ s/\s+//g;
          $stat->add_data($val);
        } elsif ($statForCol eq "discrete") {
          $val = " " if ($val eq "");
          $statDiscrete{$val} = 0 if (!exists($statDiscrete{$val}));
          $statDiscrete{$val} ++;        
        }
      }
      if (! defined($rowStatLab)){
        $rowStatLab = $statRowIDStr;
        $rowStatLab =~ s/\|\s*$//;
      }
      if ($statForCol eq "continuous"){
        $newAt->addData($stat->count(), $colIDStr, $rowStatLab."Stat|Count"); 
        $newAt->addData(sprintf("%.4f",$stat->min()), $colIDStr, $rowStatLab."Stat|Min"); 
        $newAt->addData(sprintf("%.4f",$stat->mean()), $colIDStr, $rowStatLab."Stat|Mean"); 
        $newAt->addData(sprintf("%.4f",$stat->median()), $colIDStr, $rowStatLab."Stat|Median"); 
        $newAt->addData(sprintf("%.4f",$stat->max()), $colIDStr, $rowStatLab."Stat|Max"); 
        $newAt->addData(sprintf("%.4f",$stat->standard_deviation()), $colIDStr, $rowStatLab."Stat|StdDEv"); 
        $statColValues{Mean}{$colIDStr} = sprintf("%.4f",$stat->mean());
        $statColValues{Median}{$colIDStr} = sprintf("%.4f",$stat->median());      
      } elsif ($statForCol eq "discrete") {
        my $count = 0;
        ### If I have for room in the colums for lab so use it
        foreach my $key(keys %statDiscrete){
          $newAt->addData($statDiscrete{$key}, $colIDStr, $rowStatLab."Value|$key");
          $count += $statDiscrete{$key};
          $statDiscrete{$key} = 1;
        }
      } 
    }
    ### Add zero values for discrete
    if ($statForRow eq "discrete") {
      foreach my $colIDStr (@colIDS) {
        foreach my $discKey(keys %allDiscreteKeys){
          my $val = $newAt->getData($colIDStr, $rowStatLab."Value|$discKey");
          $newAt->addData(0, $colIDStr, $rowStatLab."Value|$discKey") if (!defined($val));
        }
      }
    }
    ### Compute the ordinals
    if ($statForCol eq "continuous"){
      foreach my $stat("Mean", "Median"){
        my $ranks = getRanks($statColValues{$stat}, 0.01);
        foreach my $col(keys %$ranks){
          $newAt->addData($ranks->{$col}, $col, $rowStatLab."Rank|$stat"); 
        }
      }
    }
  }

  $newAt->setProperties({ "KeepColumnsInOutput" => $col }) if (defined($col)); 
  $newAt->setProperties({ "KeepRowsInOutput" => "$row|.*Stat.*|.*Value.*|.*Rank.*" }) if (defined($row)); 
  
  foreach my $otype(@outputTypes){    
    MMisc::writeTo("$outAT" . ($outAT eq "-" ? "" : ".$otype"), "", 1, 0, $newAt->renderByType($otype));
  }
}

sub getRanks(){
  my ($hash, $tieThresh) = @_;

  my $rank=1;
  my %ranks = ();

  my @keys = sort { $hash->{$a} <=> $hash->{$b} } keys %$hash;
  foreach my $col(@keys){
#    print "$hash->{$col}\n";
    $ranks{$col} = $rank++;
  }
  ### Adjust for ties
  my $i = 0;
  while ($i < @keys){
    my $end = $i;
    my $min = $hash->{$keys[$i]};
    my $sum = 0;
    while ($end < @keys && abs($hash->{$keys[$end]} - $hash->{$keys[$i]}) < $tieThresh){
      $sum += $ranks{$keys[$end]};
      $end++;
    }
    if ($i+1 != $end){
      for (my $j=$i; $j<$end; $j++){
#        $ranks{$keys[$j]} .= " $hash->{$keys[$j]} | $sum / ($end - $i) = ".($sum / ($end - $i));
         $ranks{$keys[$j]} = sprintf("%.1f", ($sum / ($end - $i)));
      }
      $i = $end;
    } else {
      $i++;
    }
  }
#  print Dumper(\%ranks);
  return (\%ranks);
}


exit(0);




