#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#

use strict;
use xmllintHelper;
use DETCurveGnuplotRenderer;
use MMisc;

my $err = 0;

##########
print "** Checking for Perl Packages:\n";
my $ms = 1;

print "[F4DE's CLEAR07 Packages]\n";
$ms = &_chkpkg
  (
   # CLEAR07/lib
   "CLEARDTHelperFunctions",
   "CLEARDTViperFile",
   "CLEARTRHelperFunctions",
   "CLEARTRViperFile",
   "CLEARFrame",
   "CLEAROBox",
   "CLEARObject",
   "CLEARPoint",
   "CLEARSequence",
   "CLEARMetrics",
  );
if ($ms > 0) {
  print "  ** ERROR: Not all CLEAR07 packages found, you will not be able to run the program, please install the missing ones\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}

##########
print "\n** Checking for \'xmllint\':\n";
my $xmllint_env = "F4DE_XMLLINT";
my $xmllint = MMisc::get_env_val($xmllint_env, "");
if ($xmllint ne "") {
  print "- using the one specified by the $xmllint_env environment variable ($xmllint)\n";
}

my $error = "";
# Confirm xmllint is present and at least 2.6.30
my $xobj = new xmllintHelper();
$xobj->set_xmllint($xmllint);
if ($xobj->error()) {
  print $xobj->get_errormsg();
  print "After installing a suitable version, set the $xmllint_env environment variable to ensure the use of the proper version if it is not the first available in your PATH\n";
  $err++;
} else {
  $xmllint = $xobj->get_xmllint();
  print "  xmllint ($xmllint) is valid and its version is recent enough\n";
}

##########
print "** Checking for gnuplot : ";

my ($err, $gnuplot, $gv) = DETCurveGnuplotRenderer::get_gnuplotcmd();
if (MMisc::is_blank($err)) {
  print "$gnuplot [$gv]\n\n";
} else {
  print "  ** $err **\n\n";
  $err++;
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
