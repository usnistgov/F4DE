# KWSEval
# KWSDETSet.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. KWSEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package KWSDETSet;

use strict;
use Data::Dumper;
use MMisc;

sub new {
    my ($class) = @_;
    
    my $self = { COMBINED_DET_PNG => "",
		 DETS => {}
	     };
    bless $self;
    
    return $self;
}

sub addDET(){
    my ($self, $det, $stype) = @_;
    $self->{DETS}{$stype} = $det;
}

sub getDETList(){
    my ($self) = @_;
    
    my @dets = ();
    push @dets, $self->{DETS}{ALL} if (exists($self->{DETS}{ALL}));
    foreach my $stype(keys %{$self->{DETS}}){ 
	push @dets, $self->{DETS}{$stype} if ($stype ne "ALL");
    }
    \@dets;
}

sub hasDETs(){
    my ($self) = @_;
    my @keys = keys %{ $self->{DETS} };
    scalar @keys;
}

sub writeMultiDET(){
    my ($self, $fileRoot) = @_;

    my $info = DETCurve::writeMultiDetGraph($fileRoot, $self->getDETList());
    $self->{COMBINED_DET_PNG} = $info->{COMBINED_DET_PNG};
}

sub serialize(){
    my ($self, $file) = @_;
    open (FILE, ">$file") 
      or MMisc::error_quit("Unable to open file '$file' to serialize KWSDETSet to : $!");
    my $orig = $Data::Dumper::Indent; 
    $Data::Dumper::Indent = 0;
    print FILE Dumper($self); 
    $Data::Dumper::Indent = $orig;
    close FILE;
}

sub readFromFile{
    my ($file) = @_;
    my $str = "";
    open (FILE, "$file")
      or MMisc::error_quit("Failed to open $file for read : $!");
    while (<FILE>) { $str .= $_ ; }
    close FILE;
    my $VAR1;
    eval $str;
    MMisc::error_quit("Problem in \'KWSDETSet::readFromFile()\' eval-ing code: " . join(" | ", $@))
        if $@;
    
    return($VAR1);
}

### This is NOT an instance METHOD!!!!!!!!!!!!!!
sub ndash{
    my ($n) = @_;
    my $s = "";
    foreach (0..$n-1){ $s .= "-" };
    $s;
}

### This is NOT an instance METHOD!!!!!!!!!!!!!!
sub center{
    my ($str, $l) = @_;
    my $slen = length($str);
    my $s = "";
    my $left = sprintf("%.0f",($l - $slen)/2);
    my $right = $l - ($slen + $left) - 1;
    foreach (0..$left-1){ $s .= " " };
    $s .= $str;
    foreach (0..$right-1){ $s .= " " };
    $s;
}

sub writeMultiDETTextSummary(){
    my ($self) = @_;
    my $str = "";
    my @tbl = ();
    my $dets = $self->getDETList();

    push @tbl, [ ("",            "",         "",     "",        "Decision") ];
    push @tbl, [ ("Description", "Max Value","P(Fa)","P(Miss)", "Score")    ];
    for (my $d=0; $d < @$dets; $d++){
	push @tbl, [ ($dets->[$d]->{LINETITLE}, 
		      ($dets->[$d]->getStyle() eq "pooled" ? "Pooled $dets->[$d]->{TRIALS}->{BlockID} $dets->[$d]->{TRIALS}->{DecisionID}" : "$dets->[$d]->{TRIALS}->{BlockID} Weighted")." : " .sprintf("%.4f", $dets->[$d]->getMaxValueValue()),
		      sprintf("%.5f", $dets->[$d]->getMaxValuePFA()),
		      sprintf("%.3f", $dets->[$d]->getMaxValuePMiss()),
		      sprintf("%.4f", $dets->[$d]->getMaxValueDetectionScore())) ];
    } 

    my @c =               (1, 1, 1, 1, 1);
    for (my $d=0; $d < @tbl; $d++){
	for (my $dd=0; $dd < @{$tbl[$d]}; $dd++){
	    $c[$dd] = length($tbl[$d][$dd]) if ($c[$dd] < length($tbl[$d][$dd]));
	}
    }
    my $fmt = "| %$c[0]s | %$c[1]s | %$c[2]s %$c[3]s %$c[4]s |\n";
    my $len = length(sprintf($fmt,"","","","",""));
    $str .= "+-"; foreach (0..4){ $str .= ndash($c[$_]+1) } $str .= "----+\n";
    $str .= "|".center("DET Curve Analysis Summary",$len-2)."|\n";
    $str .= "+-"; foreach (0..4){ $str .= ndash($c[$_]+1) } $str .= "----+\n";
    for (my $d=0; $d < @tbl; $d++){
	if ($d == 2){
	    $str .= "|-".ndash($c[0]+1)."+".ndash($c[1]+2)."+"; foreach (2..4){$str .= ndash($c[$_]+1)} $str .= "-|\n";
	}
	$str .= sprintf($fmt, @{ $tbl[$d] });
    }
    $str .= "+-"; foreach (0..4){ $str .= ndash($c[$_]+1) } $str .= "----+\n";
    $str;
}

sub stripPath{
    my ($file) = @_;
    $file =~ s:.*/::;
    $file;
}

sub writeMultiDETHTMLSummary(){
    my ($self, $dir) = @_;
    my $str = "";
    my @tbl = ();
    
    my $dets = $self->getDETList();
     
    push @tbl, [ ("",            "",         "",     "",        "Decision") ];
    push @tbl, [ ("Description", "Max Value","P(Fa)","P(Miss)", "Score")    ];
    for (my $d=0; $d < @$dets; $d++){
	push @tbl, [ ($dets->[$d]->{LINETITLE}, 
		      ($dets->[$d]->getStyle() eq "pooled" ? "Pooled $dets->[$d]->{TRIALS}->{BlockID} $dets->[$d]->{TRIALS}->{DecisionID}" : "$dets->[$d]->{TRIALS}->{BlockID} Weighted")." : " .sprintf("%.4f", $dets->[$d]->getMaxValueValue()),
		      sprintf("%.5f", $dets->[$d]->getMaxValuePFA()),
		      sprintf("%.3f", $dets->[$d]->getMaxValuePMiss()),
		      sprintf("%.4f", $dets->[$d]->getMaxValueDetectionScore())) ];
    } 
    
    $str .= "<hr>\n";
    $str .= "<table border=0>\n";
    $str .= "<tr bgcolor=#A2C0DF> <th colspan=".(scalar(@{$tbl[0]})+2)." align=center> DET Curve Analysis <br> <img src=\"".stripPath($self->{COMBINED_DET_PNG})."\" alt=\"Combined DET Plot/></th></tr>\n";
    foreach my $row(0..1){
	$str .= " <tr bgcolor=#A2C0DF>\n";
	foreach my $col(0..$#{ $tbl[$row] }){
	    $str .= "  <TH> $tbl[$row][$col] </TH>\n"
	    }
	if ($row == 0){
	    $str .= "  <TH rowspan=2> DET Curve </TH>\n";
	    $str .= "  <TH rowspan=2> Threshold Plot </TH>\n";
	}
	$str .= " </tr>\n";
    }
    foreach my $row(2..$#tbl){
	$str .= " <tr>\n";
	$str .= "  <TH bgcolor=#DADADA> $tbl[$row][0] </TH>\n";
	foreach my $col(1..$#{ $tbl[$row] }){
	    $str .= "  <TD  bgcolor=#EEEEEE> $tbl[$row][$col] </TD>\n"
	    }
	$str .= "  <TD> <A href='".stripPath($dets->[$row-2]->getDETPng())."'>DET</a> </TD>\n";
	$str .= "  <TD> <A href='".stripPath($dets->[$row-2]->getThreshPng())."'>Threshold</a> </TD>\n";
	$str .= " </tr>\n";
    }
    $str .= "</table>\n";
    $str;
}
1;
