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

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../../common/lib");
}
use lib (@f4bv);

use Data::Dumper;
use AutoTable;
use MMisc;

my $Usage = "csv_grep.pl [-v] -i InCSV|- -r row1|row2|... -c column1|column2|... -o outCSV|-\n".
"Desc:  Read in a csv file extracting ONLY the specified columns and writing them to the output file.\n";

my $in = undef;
my $out = undef;
my $col = undef;
my $row = undef;
my $reverse = 0;

use Getopt::Long;
my $result = GetOptions ("i=s" => \$in,
			 "o=s" => \$out,
			 "c=s" => \$col,
			 "r=s" => \$row,
			 "-v"  => \$reverse);
die "Aborting:\n$Usage\n:" if (!$result);

die("Error: Argument -i req'd\n" . $Usage) if (!defined($in));
die("Error: Argument -c and/or -r req'd\n" . $Usage) if (!defined($col) && !defined($row));
die("Error: Argument -o req'd\n" . $Usage) if (!defined($out));

my $at = new AutoTable(); 
if (! $at->loadCSV($in)) {
  die("Error: Failed to load CSV file '$in'");
}

$at->setProperties({ "KeepColumnsInOutput" => $col }) if (defined($col)); 
$at->setProperties({ "KeepRowsInOutput" => $row }) if (defined($row)); 

if ($out eq "-"){
  print $at->renderCSV(); 
} else {
  MMisc::writeTo($out, "", 1, 0, $at->renderCSV());
}

exit(0);




