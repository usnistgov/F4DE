#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use MMisc;

my $err = 0;

##########
print "** Checking for Perl Packages:\n";
my $ms = 1;

print "[F4DE Common Packages]\n";
$ms = &_chkpkg
  (
   # common/lib
   "BipartiteMatch",
   "F4DE_TestCore",
   "Levenshtein",
   "MErrorH",
   "MMisc",
   "SimpleAutoTable",
   "TextTools",
   "ViperFramespan",
   "xmllintHelper"
  );
if ($ms > 0) {
  print "  ** ERROR: Not all packages found, you will not be able to run the programs, please install the missing ones\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}

print "[F4DE's CLEAR07 Packages]\n";
$ms = &_chkpkg
  (
   # CLEAR07/lib
   "CLEARDTHelperFunctions",
   "CLEARDTViperFile",
   "CLEARTRHelperFunctions",
   "CLEARTRViperFile",
   "Frame",
   "OBox",
   "Object",
   "Point",
   "Sequence"
  );
if ($ms > 0) {
  print "  ** ERROR: Not all CLEAR07 packages found, you will not be able to run the program, please install the missing ones\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
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
