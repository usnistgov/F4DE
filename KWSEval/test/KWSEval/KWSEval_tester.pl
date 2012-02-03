#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my ($tool, $mode, @rest) = @ARGV;
MMisc::error_quit("ERROR: Tool ($tool) empty or not an executable\n")
  if ((MMisc::is_blank($tool)) || (! MMisc::is_file_x($tool)));
$tool .= " " . join(" ", @rest)
  if (scalar @rest > 0);
my $mmk = F4DE_TestCore::get_magicmode_comp_key();

print "** Running KWSEval tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = ""; # Test name

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$testr += &do_simple_test($tn, "(DataCalculation: Alignments)", "$tool -e ../common/test3.ecf.xml -r ../common/test3.rttm -s ../common/test3.stdlist.xml -t ../common/test3.tlist.xml -a", "res_$tn.txt");

##
$tn = "test2";
$testr += &do_simple_test($tn, "(DataCalculation: Occurrences)", "$tool -e ../common/test3.ecf.xml -r ../common/test3.rttm -s ../common/test3.stdlist.xml -t ../common/test3.tlist.xml -o -A", "res_$tn.txt");

##
$tn = "test3";
$testr += &do_simple_test($tn, "(DataCalculation: Conditional Occurrences)", "$tool -e ../common/test3.ecf.xml -r ../common/test3.rttm -s ../common/test3.stdlist.xml -t ../common/test3.tlist.xml -Y BN+CTS:BNEWS,CTS -Y MTG:CONFMTG -O -A", "res_$tn.txt");

##
$tn = "test4";
$testr += &do_simple_test($tn, "(DataCalculation: Alignments with ECF Filtering)", "$tool -e ../common/test3.ecf.xml -r ../common/test3.rttm -s ../common/test3.stdlist.xml -t ../common/test3.tlist.xml -a -E", "res_$tn.txt");

##
$tn = "test5";
$testr += &do_simple_test($tn, "(DataCalculation: Alignments with Scoring ECF Filtering)", "$tool -e ../common/test3.scoring.ecf.xml -r ../common/test3.rttm -s ../common/test3.stdlist.xml -t ../common/test3.tlist.xml -a -E", "res_$tn.txt");

##
$tn = "test6";
my $cachefile = "$tn.cache";
unlink($cachefile) 
  if (MMisc::does_file_exist($cachefile));
$tn .= "a";
$testr += &do_simple_test($tn, "(Caching: Generate Cache)", "$tool -e ../common/test2.ecf.xml -r ../common/test2.rttm -s ../common/test2.stdlist.xml -t ../common/test2.tlist.xml -o -A -c $cachefile", "res_$tn.txt");

##
$tn = "test6b";
$testr += &do_simple_test($tn, "(Caching: Cached Report)", "$tool -e ../common/test2.ecf.xml -r ../common/test2.rttm -s ../common/test2.stdlist.xml -t ../common/test2.tlist.xml -o -A -c $cachefile", "res_$tn.txt");
unlink($cachefile) 
  if (MMisc::does_file_exist($cachefile));

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

  my $retval = F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev);

  return($retval);
}
