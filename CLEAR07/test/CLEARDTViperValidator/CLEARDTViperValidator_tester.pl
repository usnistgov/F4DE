#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#

use strict;
use F4DE_TestCore;
use MMisc;

my ($validator, $mode) = @ARGV;
MMisc::error_quit("ERROR: Validator ($validator) empty or not an executable\n")
  if (($validator eq "") || (! -f $validator) || (! -x $validator));

print "** Running CLEARDTViperValidator tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";
my $td = "";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1a";
$td = "BN_FDT";
$testr += &do_simple_test($tn, $td, "(BN FaceDT: Reference files)", "*.gtf", "", "-D BN -w", "res_$tn.txt", "");

##
$tn = "test1b";
$td = "BN_FDT";
$testr += &do_simple_test($tn, $td, "(BN FaceDT: System submissions)", "", "*.rdf", "-D BN -w", "res_$tn.txt", "");

##
$tn = "test2a";
$td = "BN_TDT";
$testr += &do_simple_test($tn, $td, "(BN TextDT: Reference files)", "*.gtf", "", "-D BN -w -f 15", "res_$tn.txt", "");

##
$tn = "test2b";
$td = "BN_TDT";
$testr += &do_simple_test($tn, $td, "(BN TextDT: System submissions)", "", "*.rdf", "-D BN -w -f 15", "../../../../F4DE-NISTonly/CLEAR07/test/CLEARDTViperValidator/res_$tn.txt", "../../../F4DE-NISTonly/CLEAR07/test/");

##
$tn = "test3a";
$td = "MMR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-MultiSite FaceDT: Reference files)", "*.gtf", "", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test3b";
$td = "MMR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-MultiSite FaceDT: System submissions)", "", "*.rdf", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test4a";
$td = "MMR_PDT";
$testr += &do_simple_test($tn, $td, "(MRoom-MultiSite PersonDT: Reference files)", "*.gtf", "", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test5a";
$td = "MR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: Reference files)", "*.gtf", "", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test5b";
$td = "MR_FDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: System submissions)", "", "*.rdf", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test6a";
$td = "MR_HDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: Reference files)", "*.gtf", "", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test6b";
$td = "MR_HDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST FaceDT: System submissions)", "", "*.rdf", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test7a";
$td = "MR_PDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST PersonDT: Reference files)", "*.gtf", "", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test7b";
$td = "MR_PDT";
$testr += &do_simple_test($tn, $td, "(MRoom-NIST PersonDT: System submissions)", "", "*.rdf", "-D MR -w", "res_$tn.txt", "");

##
$tn = "test8a";
$td = "SV_VDT";
$testr += &do_simple_test($tn, $td, "(Surv. VehicleDT: Reference files)", "*.gtf", "", "-D SV -w", "res_$tn.txt", "");

##
$tn = "test8b";
$td = "SV_VDT";
$testr += &do_simple_test($tn, $td, "(Surv. VehicleDT: System submissions)", "", "*.rdf", "-D SV -w", "res_$tn.txt", "");

##
$tn = "test9a";
$td = "SV_PDT";
$testr += &do_simple_test($tn, $td, "(Surv. PersonDT: Reference files)", "*.gtf", "", "-D SV -w", "res_$tn.txt", "");

##
$tn = "test9b";
$td = "SV_PDT";
$testr += &do_simple_test($tn, $td, "(Surv. PersonDT: System submissions)", "", "*.rdf", "-D SV -w", "res_$tn.txt", "");

##
$tn = "test10a";
$td = "UV_VDT";
$testr += &do_simple_test($tn, $td, "(UAV VehicleDT: Reference files)", "*.gtf", "", "-D UV -w -f 15", "res_$tn.txt", "");

##
$tn = "test10b";
$td = "UV_VDT";
$testr += &do_simple_test($tn, $td, "(UAV VehicleDT: System submissions)", "", "*.rdf", "-D UV -w -f 15", "res_$tn.txt", "");

#####

my $elapsed = F4DE_TestCore::get_elapsedtime($t0);
my $add = "";
$add .= " [Elapsed: $elapsed seconds]" if (F4DE_TestCore::is_elapsedtime_on());

MMisc::ok_quit("All test ok$add\n\n")
  if ($testr == $totest);

MMisc::error_quit("Not all test ok$add\n\n");

##########

sub do_simple_test {
  my ($testname, $testdir, $subtype, $rf, $sf, $params, $res, $xtra) = @_;
  my ($files, $command);

  if ($rf ne "") {
    $files = "../${xtra}common/$testdir/$rf";
    $command = "$validator -g $files $params";
  }
  elsif ($sf ne "") {
    $files = "../${xtra}common/$testdir/$sf";
    $command = "$validator $files $params";
  }
  else {
    MMisc::error_quit("No input files for validator\n\n");
  }

  $totest++;

#  print "[$files / $res]\n";
  return(1) if (! F4DE_TestCore::check_files($testname, $subtype, "intentionally", $files, $res));

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode));
}
