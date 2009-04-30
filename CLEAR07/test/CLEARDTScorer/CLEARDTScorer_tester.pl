#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;

my $scorer = shift @ARGV;
error_quit("ERROR: Scorer ($scorer) empty or not an executable\n")
  if (($scorer eq "") || (! -f $scorer) || (! -x $scorer));
my $mode = shift @ARGV;

print "** Running CLEARDTScorer tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";
my $td = "";

$tn = "test-1a";
$td = "BN_FDT";
$testr += &do_simple_test($tn, $td, "(BN FaceDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D BN -E Area", "res-$tn.txt");

$tn = "test-2a";
$td = "BN_TDT";
$testr += &do_simple_test($tn, $td, "(BN TextDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D BN -E Area -f 15", "res-$tn.txt");

$tn = "test-3a";
$td = "MMR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-MultiSite FaceDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Area", "res-$tn.txt");

# $tn = "test-4a";
# $td = "MMR_PDT";
# $testr += &do_simple_test($tn, $td, "(MRoom-MultiSite PersonDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Area", "res-$tn.txt");

$tn = "test-5a";
$td = "MR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Area", "res-$tn.txt");

$tn = "test-6a";
$td = "MR_HDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST HandDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Point", "res-$tn.txt");

$tn = "test-7a";
$td = "MR_PDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST PersonDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Area", "res-$tn.txt");

$tn = "test-8a";
$td = "SV_PDT";
$testr += &do_simple_test($tn, $td, "(Surv. PersonDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D SV -E Area", "res-$tn.txt");

$tn = "test-9a";
$td = "SV_VDT";
$testr += &do_simple_test($tn, $td, "(Surv. VehicleDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D SV -E Area", "res-$tn.txt");

$tn = "test-10a";
$td = "UV_VDT";
$testr += &do_simple_test($tn, $td, "(UAV VehicleDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D UV -E Area -f 15", "res-$tn.txt");

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

  my $command = "$scorer $fsf -g $frf $params";
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