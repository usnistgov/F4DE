# Levenshtein.pm
# Author: Jerome Ajot <jerome.ajot@nist.gov>
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 

# Levenshtein.pm is an experimental system.  
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
# revision 0.1:
# - Initial version (Jerome)

# Levenshtein(txt1, txt2, insdelcost, subcost, corrcost, recur, splitspace)
#  Generic function to calculate the Levenshtein distance.
#   txt1, txt2 => string o be compared
#   insdelcost => cost of insertion and deletion
#   subcost    => cost of substitution
#   corrcost   => cost of correct
#   recur      => The comparation function is another Levenshtein or the string compare
#   splitspace => split the strings by spaces or characters
#
# LevenshteinDiff(txt1, txt2)
#  Calculate the Levenshtein distance with the costs of 1 for errors and by charater split.
#  Commun use to compare words.
#
# LevenshteinPhrase(txt1, txt2)
#  Calculate the Levenshtein distance with the costs of 4/3 for errors and by space split.
#  Commun use to compare sentences.
#
# LevenshteinEx(txt1, txt2)
#  Calculate the Levenshtein distance with the costs of 4/3 for errors and by space split.
#  It also compare the text elements/words using the levenshteinDiff.
#  Commun use to compare sentences and add information on the word comparison.
#
# LevenshteinExAlign(txt1, txt2)
#  Calculate the Levenshtein distance using LevenshteinEx.
#  It outputs the cost and a pointer to an array which contains an ordered list of the alignment.

use strict;
use TextTools;
use MMisc;

sub Levenshtein1
{
	my ($txt1, $txt2, $insdelcost, $subcost, $corrcost, $recur, $splitspace) = @_;
	
	my @arr1;
	my @arr2;
	
	if($splitspace)
	{
		# Split by spaces
		@arr1 = split(/\s+/, NormalizeText($txt1));
		@arr2 = split(/\s+/, NormalizeText($txt2));
	}
	else
	{
		# Split by characters
		@arr1 = split(//, $txt1);
		@arr2 = split(//, $txt2);
	}
	
	my ($len1, $len2) = (scalar @arr1, scalar @arr2);
	
	# If one string is empty return the cost
	return $len1*$insdelcost if($len2 == 0);
	return $len2*$insdelcost if($len1 == 0);
	
	# Initiate the Levenshtein Matrix
	my %mat;
	
	for (my $i=0; $i<=$len1; ++$i)
	{
		for (my $j=0; $j<=$len2; ++$j)
		{
			$mat{$i}{$j} = $corrcost;
			$mat{0}{$j} = $j*$insdelcost;
		}
	
		$mat{$i}{0} = $i*$insdelcost;
	}
	
	# Fill up the Matrix
	for (my $i=1; $i<=$len1; ++$i)
	{
		for (my $j=1; $j<=$len2; ++$j)
		{
			my $cost = undef;
			
			if($recur)
			{
				# Adaptive cost based on the difference and the length of the strings
				$cost = LevenshteinDiff($arr1[$i-1], $arr2[$j-1])*$subcost/MMisc::max(length($arr1[$i-1]), length($arr2[$j-1]));
			}
			else
			{
				$cost = ($arr1[$i-1] eq $arr2[$j-1]) ? $corrcost : $subcost;
			}
			
			$mat{$i}{$j} = MMisc::min($mat{$i-1}{$j} + $insdelcost, $mat{$i}{$j-1} + $insdelcost, $mat{$i-1}{$j-1} + $cost);
		}
	}

    return ($mat{$len1}{$len2}, \%mat, \@arr1, \@arr2);
}

sub LevenshteinAlign1
{
	my ($txt1, $txt2, $insdelcost, $subcost, $corrcost, $recur, $splitspace) = @_;
	my ($val, $mat, $arr1, $arr2) = Levenshtein1($txt1, $txt2, $insdelcost, $subcost, $corrcost, $recur, $splitspace);
	
	my @alignment;
	
	my $curri = scalar @$arr1;
	my $currj = scalar @$arr2;
	
	# Go through the matrix to find the shortest path
	while($curri || $currj)
	{
		my ($inscost, $delcost, $transcost) = (9e99, 9e99, 9e99);
		
		# Calculate the costs
		$inscost = $mat->{$curri-1}{$currj} + $insdelcost if($curri);
		$delcost = $mat->{$curri}{$currj-1} + $insdelcost if($currj);
		
		if($curri && $currj)
		{
			$transcost = $mat->{$curri-1}{$currj-1};
			if($recur) { $transcost += LevenshteinDiff($arr1->[$curri-1], $arr2->[$currj-1])*$subcost/MMisc::max(length($arr1->[$curri-1]), length($arr2->[$currj-1])); }
			else       { $transcost += ($arr1->[$curri-1] eq $arr2->[$currj-1]) ? $corrcost : $subcost; }
		}
		
		# 
		my $deci = 0;
		my $decj = 0;
		my $min;
		
		if($inscost <= $delcost) { $deci = 1; $min = $inscost; }
		else                     { $decj = 1; $min = $delcost; }
		
		if($transcost <= $min) { $deci = 1; $decj = 1; }
		
		push(@alignment, [($arr1->[$curri-1], $arr2->[$currj-1])]) if($deci && $decj);
		push(@alignment, [("", $arr2->[$currj-1])]) if(!$deci && $decj);
		push(@alignment, [($arr1->[$curri-1], "")]) if($deci && !$decj);
		
		$curri -= $deci;
		$currj -= $decj;
	}
	
	@alignment = reverse @alignment;
	
	return($val, \@alignment);
}

sub LevenshteinExAlign
{
	my ($txt1, $txt2) = @_;
	return LevenshteinAlign1($txt1, $txt2, 3, 4, 0, 1, 1);
}

sub Levenshtein
{
	my ($txt1, $txt2, $insdelcost, $subcost, $corrcost, $recur, $splitspace) = @_;
	my ($val, undef, undef, undef) = Levenshtein1($txt1, $txt2, $insdelcost, $subcost, $corrcost, $recur, $splitspace);
	return($val);
}

sub LevenshteinDiff
{
	my ($txt1, $txt2) = @_;
	return Levenshtein($txt1, $txt2, 1, 1, 0, 0, 0);
}

sub LevenshteinPhrase
{
	my ($txt1, $txt2) = @_;
	return Levenshtein($txt1, $txt2, 3, 4, 0, 0, 1);
}

sub LevenshteinEx
{
	my ($txt1, $txt2) = @_;
	return Levenshtein($txt1, $txt2, 3, 4, 0, 1, 1);
}

sub LevenshteinPhraseErrorReport
{
	my ($ref, $hyp) = @_;
	my ($val, $alignment) = LevenshteinAlign1($ref, $hyp, 3, 4, 0, 0, 1);
	
	my $ins = 0;
	my $del = 0;
	my $sub = 0;
	my $corr = 0;
	my $nbref = 0;
	my $nbhyp = 0;
	
	for(my $i=0; $i<@$alignment; ++$i)
	{
		$ins++ if($alignment->[$i][0] eq "");
		$del++ if($alignment->[$i][1] eq "");
		$nbref++ if($alignment->[$i][0] ne "");
		$nbhyp++ if($alignment->[$i][1] ne "");
		
		if( ($alignment->[$i][1] ne "") && ($alignment->[$i][0] ne "") )
		{
			if($alignment->[$i][0] ne $alignment->[$i][1])
			{
				$sub++;
			}
			else
			{
				$corr++;
			}
		}
	}
	
	return($val, $nbref, $nbhyp, $corr, $sub, $ins, $del);
}

sub DisplayAlignment
{
	my ($alignment) = @_;
	
	my $str1 = "";
	my $str2 = "";
	
	for(my $i=0; $i<@$alignment; ++$i)
	{
		my $len1 = length($alignment->[$i][0]);
		my $len2 = length($alignment->[$i][1]);
		my $upcase = ($alignment->[$i][0] ne $alignment->[$i][1]);
		
		$str1 .= ($upcase) ? uc($alignment->[$i][0]) : $alignment->[$i][0];
		$str2 .= ($upcase) ? uc($alignment->[$i][1]) : $alignment->[$i][1];
		
		if(!$len1)
		{
			$len1 = $len2;
			$str1 .= "*" x $len2;
		}
		
		if(!$len2)
		{
			$len2 = $len1;
			$str2 .= "*" x $len1;
		}
		
		$str1 .= " " x ($len2 - $len1) if($len2 > $len1);
		$str2 .= " " x ($len1 - $len2) if($len1 > $len2);
		
		$str1 .= " ";
		$str2 .= " ";
	}
	
	print "$str1\n$str2\n";
}

1;
