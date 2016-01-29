#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#

BEGIN {
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }
}

use strict;
use xmllintHelper;
use DETCurveGnuplotRenderer;
use MMisc;

my $err = 0;

##########
print "** Checking for Perl Packages:\n";
my $ms = 1;

print "[F4DE's TrecVid08 Packages]\n";
$ms = &_chkpkg
  (
   # TrecVid08/lib
   "AdjudicationViPERfile",
   "TrecVid08ECF",
   "TrecVid08EventList", 
   "TrecVid08HelperFunctions",
   "TrecVid08KernelFunctions",
   "TrecVid08Observation",
   "TrecVid08ViperFile",
  );
if ($ms > 0) {
  print "  ** ERROR: Not all TrecVid08 packages found, you will not be able to run the program, please install the missing ones\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}

print "[Optional Perl Packages]\n";
$ms = &_chkpkg("Statistics::Descriptive::Discrete"); # TV08Stats
if ($ms > 0) {
  print "  ** WARNING: Not all TV08Stats packages found, you will not be able to run this program\n";
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

my ($derr, $gnuplot, $gv) = DETCurveGnuplotRenderer::get_gnuplotcmd();
if (MMisc::is_blank($derr)) {
  print "$gnuplot [$gv]\n\n";
} else {
  print "  ** $derr **\n\n";
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
