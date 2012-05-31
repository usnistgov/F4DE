#!/usr/bin/env perl

# CSV files concatenator
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CSV files concatenator" is an experimental system.
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

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CSV files concatenator Version: $version";

use strict;

########################################

my $usage = "$0 indir outfile.csv\n\nProgram will copy content from multiple CSV files (required to have the .csv extension) from a given directory to one output CSV file (it will copy the CSV header of the first file only)\nNote: the script will not try to do any check on the number of columns in the input files\n";

die($usage) 
  if (scalar @ARGV != 2);

my ($dir, $out) = @ARGV;
die("[$dir] is not a directory ?")
  if (! -d $dir);

my @list = `find $dir -name "*.csv"`;
chomp @list;

my $first = 0;
my $lc = 0;
my $inc = 0;
foreach my $file (@list) {
    print "[$file]\n";

    # Copy header
    if (! $first) {
      `head -n 1 $file > $out`;
      $first = 1;
      my $nlc = &get_lc($out);
      my $a = $nlc - $lc;
      die("Header: Diff than one line added ($a)\n")
        if ($a != 1);
      $lc = $nlc;
    }

    `tail -n +2 $file >> $out`;
    my $elc = &get_lc($file) - 1;
    my $nlc = &get_lc($out);
    my $a = $nlc - $lc;
    die("Diff amount of line added ? expected : $elc / seen : $a\n")
      if ($a != $elc);
    print "   -> added $a lines\n";
    $lc = $nlc;
    $inc++;
}

print "Done ($inc files / $lc lines)\n";
exit(0);

#####

sub get_lc {
  my ($file) = @_;

  my $alc = `wc $file`;
  my $lc = 0;

  $lc = $1
    if ($alc =~ m%^\s*(\d+)\s+%);
  
  return ($lc);
}
  
