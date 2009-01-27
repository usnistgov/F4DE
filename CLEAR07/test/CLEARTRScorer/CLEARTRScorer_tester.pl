#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;

my $scorer = shift @ARGV;
error_quit("ERROR: Scorer ($scorer) empty or not an executable\n")
  if (($scorer eq "") || (! -f $scorer) || (! -x $scorer));
my $mode = shift @ARGV;

print "** Running CLEARTRScorer tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";
my $td = "";

$tn = "test-1a";
$td = "BN_TR";
$testr += &do_simple_test($tn, $td, "(BN TextRec: regular non-binary area thresholding)", "*.gtf", "*.rdf", "-D BN -E Area", "res-$tn.txt");

$tn = "test-1b";
$td = "BN_TR";
$testr += &do_simple_test($tn, $td, "(BN TextRec: regular non-binary point thresholding)", "*.gtf", "*.rdf", "-D BN -E Point", "res-$tn.txt");

if ($testr == $totest) {
  ok_quit("All test ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_simple_test {
  my ($testname, $testdir, $subtype, $rf, $sf, $params, $res) = @_;
  my $frf = "../common/$testdir/$rf";
  my $fsf = "../common/$testdir/$sf";

  my $command = "$scorer $fsf -g $frf $params -f 15";
  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode));
}

#####

sub ok_quit {
  print @_;
  exit(0);
}

#####

sub error_quit {
  print @_;
  exit(1);
}
