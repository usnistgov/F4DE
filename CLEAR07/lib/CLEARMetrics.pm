package CLEARMetrics;

# CLEARMetrics
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEARMetrics.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

my $version = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CLEARMetrics.pm Version: $version";


########################################

sub computeMOTA {
  my ($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng) = @_;

  return(undef) if ($cng == 0);
  
  return(1 - ( $costMD*$sumMD + $costFA*$sumFA + $costIS*($sumIDsplit + $sumIDmerge)) / $cng);
}

##########

sub computePrintableMOTA {
  my $v = &computeMOTA(@_);
  
  return("NA") if (! defined $v);
  
  return(sprintf("%.06f", $v));
}

##########

sub __check_sameMOTAcomp {
  my ($col1, $col2, $name, @array) = @_;

  my $v1 = $array[$col1];
  my $v2 = $array[$col2];
  
  return("Different $name [$v1 / $v2]")
    if ($v1 != $v2);

  return("");
}

#####

sub sumMOTAcomp {
  my @all = @_;

  # Special case, adding to an empty, return the input as the result
  return("", @all[0..7]) if (scalar @all == 8);

  return("Strange number of elements (expected 16, got " . scalar @all . ")")
    if (scalar @all != 16);
  
  foreach my $v (@all) {
    return("Not all values given are integer value [$v]")
      if (! MMisc::is_integer($v));
  }

  my $err = "";
  $err .= &__check_sameMOTAcomp(0, 8, "CostMD", @all);
  $err .= &__check_sameMOTAcomp(2, 10, "CostFA", @all);
  $err .= &__check_sameMOTAcomp(4, 12, "CostIS", @all);
  return($err) if (! MMisc::is_blank($err));

  my @out = ();
  # Sum all
  for (my $i = 0; $i < 8; $i++) {
    $out[$i] = $all[$i] + $all[8 + $i];
  }
  # but 3 special cases
  $out[0] = $all[0];
  $out[2] = $all[2];
  $out[4] = $all[4];

  return("", @out);
}

########################################

1;
