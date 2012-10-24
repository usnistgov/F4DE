# F4DE
# RTTMSegment.pm
# Author: David Joy
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# F4DE is an experimental system.  
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

package RTTMSegment;
use strict;

sub new
{
  my $class = shift;
  my $self = {};

  $self->{TYPE} = shift; #Should be 'SPEECH' or 'NONSPEECH'
  $self->{FILE} = shift;
  $self->{CHAN} = shift;
  $self->{ECFSRCTYPE} = undef;  #Added to ease filtering and alignments
  $self->{BT} = shift;
  $self->{DUR} = shift;
  $self->{ET} = sprintf("%.4f", $self->{BT} + $self->{DUR});
  $self->{SPKRRECS} = shift; #Hash of Speaker => Token => @Records

  bless $self;
  return $self;
}

sub recalc_dur {
  my $self = shift;
  $self->{DUR} = $self->{ET} - $self->{BT};
}

sub findTermsInSegment
{
  my ($self, $term, $threshold, $rttm) = @_;
  MMisc::warn_print "Using deprecated function 'findTermsInSegment' in RTTMSegment.pm!!";
  my @outList;
  $term =~ s/^\s*//;
  $term =~ s/\s*$//;
  #Need rttm for normalization
  if (defined $rttm) { $term = $rttm->normalizeTerm($term); }
  else { $term = lc $term;}

  my @terms = split(/\s+/, $term);
  #Currently no order to returned matches
  foreach my $spkr (sort keys %{ $self->{SPKRRECS} })
  {
    foreach my $record (@{ $self->{SPKRRECS}{$spkr}{$terms[0]} })
    {
      my @tmpList = ();
      push (@tmpList, $record);
      my $pattern1 = $terms[0];
      my $pattern2 = $record->{TOKEN};
      next if ($pattern2 !~ /^\Q$pattern1\E$/i);
      my $termpos = 1;
      my $currecord = $record;
      my $hoprecord = $record;
      while ($termpos < @terms)
      {
	if (defined $hoprecord->{NEXT} &&
	    sprintf("%.4f", ($hoprecord->{NEXT}{BT} - $hoprecord->{ET})) <= $threshold)
	{
	  if ($hoprecord->{NEXT}{STYPE} eq "frag" ||
	      $hoprecord->{NEXT}{STYPE} eq "fp")
	  {
	    $hoprecord = $hoprecord->{NEXT};
	    next;
	  }

	  $pattern1 = $terms[$termpos];
	  $pattern2 = $hoprecord->{NEXT}{TOKEN};
	  
	  if ($pattern2 =~ /^\Q$pattern1\E$/i)
	  {
	    $currecord = $hoprecord->{NEXT};
	    $hoprecord = $currecord;
	    push (@tmpList, $currecord);
	  }
	  else
	  {
	    #Next record wasn't a match
	    @tmpList = ();
	    last;
	  }
	}
	else
	{
	  #Reached the end of records for that speaker or threshold not met
	  @tmpList = ();
	  last;
	}

	$termpos++;
      }
      push (@outList, \@tmpList) if (@tmpList > 0);
    }
  }
  return (\@outList);
}

sub hasTerm
{
  my ($self, $term, $threshold, $rttm) = @_;
  MMisc::warn_print "Using deprecated function 'hasTerm' in RTTMSegment.pm!!";
  $term =~ s/^\s*//;
  $term =~ s/\s*$//;
  #Need rttm for normalization
  if (defined $rttm) { $term = $rttm->normalizeTerm($term); }
  else { $term = lc $term; }
  my @terms = split(/\s+/, $term);
  foreach my $spkr (sort keys %{ $self->{SPKRRECS} })
  {
    return 0 if (not defined $self->{SPKRRECS}{$spkr}{$terms[0]});
    foreach my $record (@{ $self->{SPKRRECS}{$spkr}{$terms[0]} })
    {
      #fragments aren't put into a segment's record
      #next if ($record->{STYPE} eq "frag" || $record->{STYPE} eq "fp");
      my $termpos = 1;
      my $currecord = $record;
      my $hoprecord = $currecord;

      while ($termpos < @terms) {
	if (defined $hoprecord->{NEXT} &&
	    sprintf("%.4f", ($hoprecord->{NEXT}{BT} - $hoprecord->{ET})) <= $threshold) {

	  if ($hoprecord->{NEXT}{STYPE} eq "frag" ||
	      $hoprecord->{NEXT}{STYPE} eq "fp") {
	    $hoprecord = $hoprecord->{NEXT};
	  }

	  my $pattern1 = $terms[$termpos];
	  if ($hoprecord->{NEXT}{TOKEN} =~ /^\Q$pattern1\E$/i) {
	    $currecord = $hoprecord->{NEXT};
	    $hoprecord = $currecord;
	  }
	  else { last; }
	}
	else { last; }

	$termpos++;
      }
      return 1 if ($termpos >= @terms);
    }
  }
  return 0;
}

1;
