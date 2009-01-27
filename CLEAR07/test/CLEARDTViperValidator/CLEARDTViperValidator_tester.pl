#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;

my $validator = shift @ARGV;
error_quit("ERROR: Validator ($validator) empty or not an executable\n")
  if (($validator eq "") || (! -f $validator) || (! -x $validator));
my $mode = shift @ARGV;

print "** Running CLEARDTViperValidator tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";
my $td = "";

$tn = "test-1a";
$td = "BN_FDT";
$testr += &do_simple_test($tn, $td, "(BN FaceDT: Reference files)", "*.gtf", "", "-D BN -w", "res-$tn.txt");

$tn = "test-1b";
$td = "BN_FDT";
$testr += &do_simple_test($tn, $td, "(BN FaceDT: System submissions)", "", "PPATT_F0904_P_2005_Test_BNews_FDT_02_01.rdf", "-D BN -w", "res-$tn.txt");

$tn = "test-2a";
$td = "BN_TDT";
$testr += &do_simple_test($tn, $td, "(BN TextDT: Reference files)", "*.gtf", "", "-D BN -w -f 15", "res-$tn.txt");

$tn = "test-2b";
$td = "BN_TDT";
$testr += &do_simple_test($tn, $td, "(BN TextDT: System submissions)", "", "*.rdf", "-D BN -w -f 15", "res-$tn.txt");

$tn = "test-3a";
$td = "MMR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-MultiSite FaceDT: Reference files)", "*.gtf", "", "-D MR -w", "res-$tn.txt");

$tn = "test-3b";
$td = "MMR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-MultiSite FaceDT: System submissions)", "", "PPATT_F0206_P_2006_Test_Meetings_FDT_10_01.rdf", "-D MR -w", "res-$tn.txt");

$tn = "test-4a";
$td = "MMR_PDT";
$testr += &do_simple_test($tn, $td, "(MRoom-MultiSite PersonDT: Reference files)", "*.gtf", "", "-D MR -w", "res-$tn.txt");

$tn = "test-5a";
$td = "MR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: Reference files)", "*.gtf", "", "-D MR -w", "res-$tn.txt");

$tn = "test-5b";
$td = "MR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: System submissions)", "", "PPATT_F0904_P_2005_Test_Meetings_FDT_01_01.rdf", "-D MR -w", "res-$tn.txt");

$tn = "test-6a";
$td = "MR_HDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: Reference files)", "*.gtf", "", "-D MR -w", "res-$tn.txt");

$tn = "test-6b";
$td = "MR_HDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: System submissions)", "", "*.rdf", "-D MR -w", "res-$tn.txt");

$tn = "test-7a";
$td = "MR_PDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST PersonDT: Reference files)", "*.gtf", "", "-D MR -w", "res-$tn.txt");

$tn = "test-7b";
$td = "MR_PDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST PersonDT: System submissions)", "", "*.rdf", "-D MR -w", "res-$tn.txt");

$tn = "test-8a";
$td = "SV_VDT";
$testr += &do_simple_test($tn, $td, "(Surv. VehicleDT: Reference files)", "*.gtf", "", "-D SV -w", "res-$tn.txt");

$tn = "test-8b";
$td = "SV_VDT";
$testr += &do_simple_test($tn, $td, "(Surv. VehicleDT: System submissions)", "", "*.rdf", "-D SV -w", "res-$tn.txt");

$tn = "test-9a";
$td = "SV_PDT";
$testr += &do_simple_test($tn, $td, "(Surv. PersonDT: Reference files)", "*.gtf", "", "-D SV -w", "res-$tn.txt");

$tn = "test-9b";
$td = "SV_PDT";
$testr += &do_simple_test($tn, $td, "(Surv. PersonDT: System submissions)", "", "XXUSC_PDTSYS01_P_2006_Test_Surveillance_PDT_20_01.rdf", "-D SV -w", "res-$tn.txt");

$tn = "test-10a";
$td = "UV_VDT";
$testr += &do_simple_test($tn, $td, "(UAV VehicleDT: Reference files)", "*.gtf", "", "-D UV -w -f 15", "res-$tn.txt");

$tn = "test-10b";
$td = "UV_VDT";
$testr += &do_simple_test($tn, $td, "(UAV VehicleDT: System submissions)", "", "XXUSC_Track_P_2005_UAV_VDT_14_01.rdf", "-D UV -w -f 15", "res-$tn.txt");

if ($testr == $totest) {
  ok_quit("All test ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_simple_test {
  my ($testname, $testdir, $subtype, $rf, $sf, $params, $res) = @_;
  my ($files, $command);

  if ($rf ne "") {
    $files = "../common/$testdir/$rf";
    $command = "$validator -g $files $params";
  }
  elsif ($sf ne "") {
    $files = "../common/$testdir/$sf";
    $command = "$validator $files $params";
  }
  else {
    error_quit("No input files for validator\n\n");
  }

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
