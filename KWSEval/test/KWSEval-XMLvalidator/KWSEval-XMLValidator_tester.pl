#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my $validator = shift @ARGV;
MMisc::error_quit("ERROR: Validator ($validator) empty or not an executable\n")
  if ((MMisc::is_blank($validator)) || (! MMisc::is_file_x($validator)));
my $mode = shift @ARGV;

print "** Running KWSEval-XMLValidator tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = ""; # Test name

my $t0 = F4DE_TestCore::get_currenttime();

#####
$tn = "test1";
$testr += &do_simple_test($tn, "(KWSList Validation)", "$validator -k ../common/test2.kwslist.xml ../common/test3.kwslist.xml ../common/test5.kwslist.xml ../common/test6.kwslist.xml -w", "res_${tn}.txt");

##
$tn = "test2a";
my $tf = "test5.kwslist.xml";
$testr += &do_simple_test_dir($tn, "(KWSList: Validation -> MemDump 1 save -> MemDump re-load -> MemDump 2 save -> Memdump cmp 1 vs2)", "$validator -k ../common/$tf -w __${tn}_1 -W && $validator -k __${tn}_1/$tf.memdump -w __${tn}_2 -W && diff -s __${tn}_1/$tf.memdump __${tn}_2/$tf.memdump", "res_$tn.txt", ["__${tn}_1", "__${tn}_2"]);

##
$tn = "test2b";
$tf = "test2.kwslist.xml";
$testr += &do_simple_test_dir($tn, "(KWSList: Validation -> MemDump 1 save -> MemDump re-load -> MemDump 2 save -> Memdump cmp 1 vs2)", "$validator -k ../common/$tf -w __${tn}_1 -W && $validator -k __${tn}_1/$tf.memdump -w __${tn}_2 -W && diff -s __${tn}_1/$tf.memdump __${tn}_2/$tf.memdump", "res_$tn.txt", ["__${tn}_1", "__${tn}_2"]);

#####
$tn = "test3";
$testr += &do_simple_test($tn, "(TermList Validation)", "$validator -t ../common/test2.tlist.xml ../common/test3.tlist.xml ../common/test4.cantonese.tlist.xml ../common/test5.tlist.xml ../common/test6.tlist.xml -w", "res_${tn}.txt");

##
$tn = "test4a";
my $tf = "test2.tlist.xml";
$testr += &do_simple_test_dir($tn, "(TermList: Validation -> MemDump 1 save -> MemDump re-load -> MemDump 2 save -> Memdump cmp 1 vs2)", "$validator -t ../common/$tf -w __${tn}_1 -W && $validator -t __${tn}_1/$tf.memdump -w __${tn}_2 -W && diff -s __${tn}_1/$tf.memdump __${tn}_2/$tf.memdump", "res_$tn.txt", ["__${tn}_1", "__${tn}_2"]);

##
$tn = "test4b";
my $tf = "test5.tlist.xml";
$testr += &do_simple_test_dir($tn, "(TermList: Validation -> MemDump 1 save -> MemDump re-load -> MemDump 2 save -> Memdump cmp 1 vs2)", "$validator -t ../common/$tf -w __${tn}_1 -W && $validator -t __${tn}_1/$tf.memdump -w __${tn}_2 -W && diff -s __${tn}_1/$tf.memdump __${tn}_2/$tf.memdump", "res_$tn.txt", ["__${tn}_1", "__${tn}_2"]);

##
$tn = "test4c";
my $tf = "test4.cantonese.tlist.xml";
$testr += &do_simple_test_dir($tn, "(TermList: Validation -> MemDump 1 save -> MemDump re-load -> MemDump 2 save -> Memdump cmp 1 vs2)", "$validator -t ../common/$tf -w __${tn}_1 -W && $validator -t __${tn}_1/$tf.memdump -w __${tn}_2 -W && diff -s __${tn}_1/$tf.memdump __${tn}_2/$tf.memdump", "res_$tn.txt", ["__${tn}_1", "__${tn}_2"]);

#####
$tn = "test5";
$testr += &do_simple_test($tn, "(ECF Validation)", "$validator -e ../common/test1.ecf.xml ../common/test2.ecf.xml ../common/test3.ecf.xml ../common/test3.scoring.ecf.xml ../common/test5.ecf.xml ../common/test6.ecf.xml -w", "res_${tn}.txt");

##
$tn = "test6a";
my $tf = "test1.ecf.xml";
$testr += &do_simple_test_dir($tn, "(ECF: Validation -> MemDump 1 save -> MemDump re-load -> MemDump 2 save -> Memdump cmp 1 vs2)", "$validator -e ../common/$tf -w __${tn}_1 -W && $validator -e __${tn}_1/$tf.memdump -w __${tn}_2 -W && diff -s __${tn}_1/$tf.memdump __${tn}_2/$tf.memdump", "res_$tn.txt", ["__${tn}_1", "__${tn}_2"]);

##
$tn = "test6b";
my $tf = "test2.ecf.xml";
$testr += &do_simple_test_dir($tn, "(ECF: Validation -> MemDump 1 save -> MemDump re-load -> MemDump 2 save -> Memdump cmp 1 vs2)", "$validator -e ../common/$tf -w __${tn}_1 -W && $validator -e __${tn}_1/$tf.memdump -w __${tn}_2 -W && diff -s __${tn}_1/$tf.memdump __${tn}_2/$tf.memdump", "res_$tn.txt", ["__${tn}_1", "__${tn}_2"]);

##
$tn = "test6c";
my $tf = "test3.scoring.ecf.xml";
$testr += &do_simple_test_dir($tn, "(ECF: Validation -> MemDump 1 save -> MemDump re-load -> MemDump 2 save -> Memdump cmp 1 vs2)", "$validator -e ../common/$tf -w __${tn}_1 -W && $validator -e __${tn}_1/$tf.memdump -w __${tn}_2 -W && diff -s __${tn}_1/$tf.memdump __${tn}_2/$tf.memdump", "res_$tn.txt", ["__${tn}_1", "__${tn}_2"]);


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