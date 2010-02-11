#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my ($scorer, $mode) = @ARGV;
MMisc::error_quit("ERROR: Scorer ($scorer) empty or not an executable\n")
  if (($scorer eq "") || (! -f $scorer) || (! -x $scorer));

print "** Running CLEARDTScorer tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";
my $td = "";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$td = "BN_FDT";
$testr += &do_simple_test($tn, $td, "(BN FaceDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D BN -E Area", "res_$tn.txt");

##
$tn = "test2";
$td = "BN_TDT";
$testr += &do_simple_test($tn, $td, "(BN TextDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D BN -E Area -f 15", "res_$tn.txt");

##
$tn = "test3";
$td = "MMR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-MultiSite FaceDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Area", "res_$tn.txt");

##
$tn = "test4";
$td = "MR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Area", "res_$tn.txt");

##
$tn = "test5";
$td = "MR_HDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST HandDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Point", "res_$tn.txt");

##
$tn = "test6";
$td = "MR_PDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST PersonDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D MR -E Area", "res_$tn.txt");

##
$tn = "test7";
$td = "SV_PDT";
$testr += &do_simple_test($tn, $td, "(Surv. PersonDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D SV -E Area", "res_$tn.txt");

##
$tn = "test8";
$td = "SV_VDT";
$testr += &do_simple_test($tn, $td, "(Surv. VehicleDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D SV -E Area", "res_$tn.txt");

##
$tn = "test9";
$td = "UV_VDT";
$testr += &do_simple_test($tn, $td, "(UAV VehicleDT: regular non-binary thresholding)", "*.gtf", "*.rdf", "-D UV -E Area -f 15", "res_$tn.txt");

#####

my $elapsed = F4DE_TestCore::get_elapsedtime($t0);
my $add = "";
$add .= " [Elapsed: $elapsed seconds]" if (F4DE_TestCore::is_elapsedtime_on());

MMisc::ok_quit("All test ok$add\n\n")
  if ($testr == $totest);

MMisc::error_quit("Not all test ok$add\n\n");

##########

sub do_simple_test {
  my ($testname, $testdir, $subtype, $rf, $sf, $params, $res) = @_;
  my $frf = "../common/$testdir/$rf";
  my $fsf = "../common/$testdir/$sf";

  my $command = "$scorer $fsf -g $frf $params";
  $totest++;

  return(1) if (! F4DE_TestCore::check_files($testname, $subtype, "intentionally", $frf, $fsf, $res));

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode));
}
