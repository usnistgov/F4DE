#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use MMisc;

my $err = 0;

##########
print "** Checking for Perl Required Packages:\n";
my $ms = 1;

$ms = &_chkpkg
  (
   "Getopt::Long",
   "Data::Dumper",
   "File::Copy",
   "File::Temp",
   "Cwd", "Text::CSV",
   "Time::HiRes", 
   "Math::Random::OO::Uniform",
   "Math::Random::OO::Normal",
   "Statistics::Descriptive",
   "DBI",
   "DBD::SQLite"
  );
if ($ms > 0) {
  print "  ** ERROR: Not all packages found, you will not be able to run the program (and some F4DE package will most likely fail this step), install the missing packages and re-run the checks\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}

print "[F4DE Common Packages]\n";
$ms = &_chkpkg
  (
   # common/lib
   "AutoTable",
#   "BarPlot",
   "BipartiteMatch",
   "CSVHelper",
   "DETCurve",
   "DETCurveGnuplotRenderer",
   "DETCurveSet",
   "F4DE_TestCore",
   "Levenshtein",
   "MErrorH",
   "MMisc",
   "MetricFuncs",
   "MetricNormLinearCostFunct",
   "MetricTestStub",
   "MetricTV08",
#   "MetricCCD10",
   "MtSQLite",
   "MtXML",
   "PropList",
   "SimpleAutoTable",
   "TextTools",
   "TrialSummaryTable",
   "TrialsFuncs",
   "TrialsTestStub",
   "TrialsTV08",
#   "TrialsCCD10",
   "TrialsNormLinearCostFunct",
   "ViperFramespan",
   "xmllintHelper"
  );
if ($ms > 0) {
  print "  ** ERROR: Not all packages found, you will not be able to run the programs, please install the missing ones\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}

##########
print "** Recommended Perl Packages:\n";
$ms = &_chkpkg("Text::CSV_XS");
if ($ms > 0) {
  print "  ** WARNING: The optional yet recommended \"Text::CSV_XS\" package is not available in your perl installation. It can greatly improve the speed of CSV handling.\n";
}

##########
print "\n** Checking for \'rsync\' (needed by installer): ";
my $rsync = MMisc::cmd_which("rsync");
if (! defined $rsync) {
  print " NOT found\n";
  $err++;
} else {
  print " found ($rsync)\n";
}


####################

MMisc::error_quit("\nSome issues, fix before attempting to run make check again\n") if ($err);

MMisc::ok_quit("\n** Pre-requisite testing done\n\n");

####################

sub _chkpkg {
  my @tocheck = @_;

  my $ms = scalar @tocheck;
  foreach my $i (@tocheck) {
    print "- $i : ";
    my $v = MMisc::check_package($i);
    my $t = $v ? "ok" : "**missing**";
    print "$t\n";
    $ms -= $v;
  }

  return($ms);
}
