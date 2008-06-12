#!/usr/bin/env perl

use strict;
use TV08TestCore;
use TrecVid08xmllint;

my $err = 0;

##########
print "** Checking for Perl Packages:\n";
my $ms;
print "[F4DE Provided Packages]\n";
$ms = &_chkpkg("BipartiteMatch", "DETCurve", "MMisc", "MtXML", "SimpleAutoTable", "Trials", "MErrorH", "MetricTestStub", "PropList", "TrialSummaryTable", "ViperFramespan", "MetricFuncs", "MetricTV08", "TrecVid08ECF", "TrecVid08EventList", "TrecVid08Observation", "TrecVid08ViperFile", "TrecVid08xmllint");
if ($ms > 0) {
  print "  ** ERROR: Not all packages found, you will not be able to run the program, please install the missing ones\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}
print "[Required Packages]\n";
$ms = &_chkpkg("Getopt::Long", "Data::Dumper", "File::Temp");
if ($ms > 0) {
  print "  ** ERROR: Not all packages found, you will not be able to run the program, please install the missing ones\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}

print "[Optional Packages]\n";
$ms = &_chkpkg("Statistics::Descriptive::Discrete"); # TV08Scorer
if ($ms > 0) {
  print "  ** WARNING: Not all TV08Scorer packages found, you will not be able to run this program\n";
} else {
  print "  Found all packages\n\n";
}

##########
print "** Checking for xmllint:\n";
my $xmllint_env = "TV08_XMLLINT";
my $xmllint = MMisc::get_env_val($xmllint_env, "");
if ($xmllint ne "") {
  print "- using the one specified by the $xmllint_env environment variable ($xmllint)\n";
}

my $error = "";
# Confirm xmllint is present and at least 2.6.30
my $xobj = new TrecVid08xmllint();
$xobj->set_xmllint($xmllint);
if ($xobj->error()) {
  print $xobj->get_errormsg();
  print "After installing a suitable version, set the $xmllint_env environment variable to ensure the use of the proper version if it is not in your PATH\n";
  $err++;
} else {
  $xmllint = $xobj->get_xmllint();
  print "  xmllint ($xmllint) is ok and recent enough\n";
}

####################

error_quit("\nSome issues, fix before attempting to run make check again\n") if ($err);

ok_quit("\n** Pre-requisite testing done\n\n");

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


####################

sub ok_quit {
  print @_;
  exit(0);
}

#####

sub error_quit {
  print @_;
  exit(1);
}
