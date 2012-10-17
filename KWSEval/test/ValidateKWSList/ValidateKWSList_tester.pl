#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my $validator = shift @ARGV;
MMisc::error_quit("ERROR: Validator ($validator) empty or not an executable\n")
  if ((MMisc::is_blank($validator)) || (! MMisc::is_file_x($validator)));
my $mode = shift @ARGV;

print "** Running ValidateKWSList tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = ""; # Test name

my $t0 = F4DE_TestCore::get_currenttime();

#####
$tn = "test1a";
$testr += &do_simple_test($tn, "(Validation w/o RTTM #1)", "$validator -t ../../test/common/test2.kwlist.xml -e ../../test/common/test2.ecf.xml -s ../../test/common/test2.kwslist.xml -o /////", "res_${tn}.txt");

#####
$tn = "test1b";
$testr += &do_simple_test($tn, "(Validation w/o RTTM #2)", "$validator -t ../../test/common/test3.kwlist.xml -e ../../test/common/test3.ecf.xml -s ../../test/common/test3.kwslist.xml -o /////", "res_${tn}.txt");

#####
$tn = "test2a";
$testr += &do_simple_test($tn, "(Validation with RTTM #1)", "$validator -t ../../test/common/test2.kwlist.xml -e ../../test/common/test2.ecf.xml -s ../../test/common/test2.kwslist.xml -r ../../test/common/test2.rttm -o /////", "res_${tn}.txt");

#####
$tn = "test2b";
$testr += &do_simple_test($tn, "(Validation with RTTM #2)", "$validator -t ../../test/common/test3.kwlist.xml -e ../../test/common/test3.ecf.xml -s ../../test/common/test3.kwslist.xml -r ../../test/common/test3.rttm -o /////", "res_${tn}.txt");

#####
$tn = "test3";
$testr += &do_simple_test($tn, "(Validation, authorizing missing Term)", "$validator -t ../../test/common/test5.kwlist.xml -e ../../test/common/test5.ecf.xml -s ../../test/common/test5.kwslist.xml -A -o /////", "res_${tn}.txt");

#####

my $elapsed = F4DE_TestCore::get_elapsedtime($t0);
my $add = "";
$add .= " [Elapsed: $elapsed seconds]" if (F4DE_TestCore::is_elapsedtime_on());

MMisc::ok_quit("All tests ok$add\n")
  if ($testr == $totest);

MMisc::error_quit("Not all test ok$add\n");

##########

sub do_simple_test {
  my ($testname, $subtype, $command, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", 0);

  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev));
}

sub do_simple_test_dir {
  my ($testname, $subtype, $command, $res, $ra) =
    MMisc::iuav(\@_, "", "", "", "", []);

  foreach my $d (@$ra) {
    `rm -rf $d`;
    MMisc::error_quit("Problem creating needed dir ($d)")
      if (! MMisc::make_wdir($d));
  }
  my $ok = &do_simple_test($testname, $subtype, $command, $res);
  if ($ok) {
    foreach my $d (@$ra) { `rm -rf $d`; }
    return($ok);
  }

  MMisc::warn_print("Test failed, keeping run directories");
  return($ok);
}
