# TextTools.pm
#
# $Id$
#
# Author: Jerome Ajot <jerome.ajot@nist.gov>
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
#
# TextTools.pm is an experimental system.  
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

use strict;

sub NormalizeText 
{
	my ($norm_text) = @_;
	
	# language-independent part:
	$norm_text =~ s/-\n//g;      # strip end-of-line hyphenation and join lines
	$norm_text =~ s/\n/ /g;      # join lines
	$norm_text =~ s/&apos;/'/g;  # convert SGML tag for apostrophe to '
	$norm_text =~ s/&quot;/"/g;  # convert SGML tag for quote to "
	$norm_text =~ s/&amp;/&/g;   # convert SGML tag for ampersand to &
	$norm_text =~ s/&lt;/</g;    # convert SGML tag for less-than to >
	$norm_text =~ s/&gt;/>/g;    # convert SGML tag for greater-than to <
	
	# language-dependent part (assuming Western languages):
	$norm_text = " $norm_text ";
	$norm_text =~ s/([\{-\~\[-\` -\&\(-\+\:-\@\/])/ $1 /g; # tokenize punctuation
	$norm_text =~ s/([^0-9])([\.,])/$1 $2 /g;              # tokenize period and comma unless preceded by a digit
	$norm_text =~ s/([\.,])([^0-9])/ $1 $2/g;              # tokenize period and comma unless followed by a digit
	$norm_text =~ s/([0-9])(-)/$1 $2 /g;                   # tokenize dash when preceded by a digit
	$norm_text =~ s/\s+/ /g;                               # one space only between words
	$norm_text =~ s/^\s+//;                                # no leading space
	$norm_text =~ s/\s+$//;                                # no trailing space
	
	return($norm_text);
}

# Split a string into an array of string.
sub PunctuationSplit
{
	my ($str) = @_;
	
	my @spltarr = split(/(\s[\.\!\?\;\:])/, NormalizeText($str));

	my $pnct = 0;
	my @output;
	my $strout;
	my $add;
	
        for (my $i = 0; $i < scalar @spltarr; $i++) {
          my $str = $spltarr[$i];
          $add = 0;
          
          if(!($pnct%2))
            {
              $strout = $str;
              $add = 1 if(scalar(@spltarr) == ($pnct + 1));
            }
          else
            {
              $strout .= $str;
              $add = 1;
            }
          
          if($add)
            {
              $strout =~ s/\s+/ /g;
              $strout =~ s/^\s+//; 
              $strout =~ s/\s+$//;
              $strout =~ s/(\s+)([\.\!\?\;\:])/$2/;
              $strout =~ s/(\s+)([\)\"])/$2/;
              $strout =~ s/([\(\"])(\s+)/$1/;
              push(@output, $strout);
            }
          
          $pnct++;
	}
	
	return(@output);
}

# Split a string into an array of string.
sub WordSplit
{
	my ($str) = @_;

	return(split(/\s+/, NormalizeText($str)));
}

1;
