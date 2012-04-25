#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use MMisc;

my $err = 0;

my $mode = shift @ARGV;

sub __not4ohc { ($mode ne "OpenHaRT_minirelease_check") ? $_[0] : '' }

##########
print "** Checking that the temporary location can be used:\n";
my $tmp = MMisc::get_tmpfilename();
print "  - obtained temp file name: \"$tmp\"\n";
print "  - trying to create it: ";
if (open FILE, ">$tmp") {
  close FILE;
  print "ok\n";
} else {
  $err++;
  print " ERROR during file creation : $!\n";
}
print "\n";

##########
print "** Checking for Perl Required Packages:\n";
my $ms = 0;

$ms = &_chkpkg
  (
   "Getopt::Long",
   "Data::Dumper",
   "File::Copy",
   "File::Temp",
   "Cwd", 
   "Text::CSV",
   "Time::HiRes", 
   &__not4ohc("Math::Random::OO::Uniform"),
   &__not4ohc("Math::Random::OO::Normal"),
   &__not4ohc("Statistics::Descriptive"),
   &__not4ohc("Statistics::Descriptive::Discrete"),
   "DBI",
   "DBD::SQLite",
   "File::Find",
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
   &__not4ohc("BipartiteMatch"),
   "CSVHelper",
   &__not4ohc("DETCurve"),
   &__not4ohc("DETCurveGnuplotRenderer"),
   &__not4ohc("DETCurveSet"),
   "F4DE_TestCore",
   &__not4ohc("Levenshtein"),
   "MErrorH",
   "MMisc",
   &__not4ohc("MetricFuncs"),
   &__not4ohc("MetricNormLinearCostFunct"),
   &__not4ohc("MetricTestStub"),
   &__not4ohc("MetricTV08"),
#   "MetricCCD10",
   "MtSQLite",
   &__not4ohc("MtXML"),
   "PropList",
   &__not4ohc("SimpleAutoTable"),
   &__not4ohc("TextTools"),
   &__not4ohc("TrialSummaryTable"),
   &__not4ohc("TrialsFuncs"),
   &__not4ohc("TrialsTestStub"),
   &__not4ohc("TrialsTV08"),
#   "TrialsCCD10",
   &__not4ohc("TrialsNormLinearCostFunct"),
   &__not4ohc("ViperFramespan"),
   &__not4ohc("xmllintHelper")
  );
if ($ms > 0) {
  print "  ** ERROR: Not all packages found, you will not be able to run the programs, please install the missing ones\n";
  $err++;
} else {
  print "  Found all packages\n";
}

##########
print "\n** Recommended Perl Packages:\n";
$ms = &_chkpkg("Text::CSV_XS");
if ($ms > 0) {
  print "  ** WARNING: The optional yet recommended \"Text::CSV_XS\" package is not available in your perl installation. It can greatly improve the speed of CSV handling.\n";
}

##########
print "\n** Package with acceptable variation:\n";
$ms = &_chkpkg("Digest::SHA", "Digest::SHA::PurePerl");
if ($ms > 1) {
  print "  ** ERROR: At least of the two package must be present, or you will not be able to run some programs\n\n";
  $err++;
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

  my $ms = 0;
  foreach my $i (@tocheck) {
    next if (MMisc::is_blank($i));
    print "- $i : ";
    my $v = MMisc::check_package($i);
    my $t = $v ? "ok" : "**missing**";
    print "$t\n";
    $ms++ if (! $v);
  }

  return($ms);
}
