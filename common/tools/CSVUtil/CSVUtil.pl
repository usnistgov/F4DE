#!/usr/bin/perl -w

use strict;

use strict;
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




