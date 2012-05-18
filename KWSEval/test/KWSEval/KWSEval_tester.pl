#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my ($tool, $mode, @rest) = @ARGV;
#$mode = "makecheckfiles";
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
$tn = "test7";
$testr += &do_simple_test($tn, "(DataCalculation: Occurence)", "$tool -e ../common/test2.ecf.xml -r ../common/test2.rttm -s ../common/test2.stdlist.xml -t ../common/test2.tlist.xml -o -b -f -", "res_$tn.txt");

##
$tn = "test8";
$testr += &do_simple_test($tn, "(DataCalculation: Conditional Occurrences)", "$tool -e ../common/test6.ecf.xml -r ../common/test6.rttm -s ../common/test6.stdlist.xml -t ../common/test6.tlist.xml -Y BN+CTS:BNEWS,CTS -Y MTG:CONFMTG -O -B -y TXT -f -", "res_$tn.txt");

##
$tn = "test9";
$testr += &do_simple_test($tn, "(DataCalculation: Segment Occurence)", "$tool -e ../common/test2.ecf.xml -r ../common/test2.rttm -s ../common/test2.stdlist.xml -t ../common/test2.tlist.xml -o -b -O -B -Y CTS:cts -Y BNEWS:bnews -Y CONFMTG:confmtg -Y ALL:cts,bnews,confmtg -g -f -", "res_$tn.txt");

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
