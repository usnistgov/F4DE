#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my $tool = shift @ARGV;
MMisc::error_quit("ERROR: Tool ($tool) empty or not an executable\n")
  if ((MMisc::is_blank($tool)) || (! MMisc::is_file_x($tool)));
my $mode = shift @ARGV;
$tool .= " " . join(" ", @ARGV)
  if (scalar @ARGV > 0);
my $mmk = F4DE_TestCore::get_magicmode_comp_key();

print "** Running AVSS09Scorer tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = ""; # Test name

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$testr += &do_simple_test($tn, "(Empty SYS vs GTF)", "$tool ../common/test_file2.empty.xml -g ../common/test_file2.clear.xml", "res_$tn.txt");

##
$tn = "test2";
$testr += &do_simple_test($tn, "(Starter SYS vs GTF)", "$tool ../common/test_file2.ss.xml -g ../common/test_file2.clear.xml", "res_$tn.txt");

##
$tn = "test3";
$testr += &do_simple_test($tn, "(Full SYS vs GTF)", "$tool ../common/test_file2.sys.xml -g ../common/test_file2.clear.xml", "res_$tn.txt");

##
$tn = "test4";
$testr += &do_simple_test($tn, "(with ECF)", "$tool ../common/test_file1.sys.xml ../common/test_file2.sys.xml -g ../common/test_file1.clear.xml ../common/test_file2.clear.xml ../common/test_file3.clear.xml -E ../common/test1-ecf.xml", "res_$tn.txt");

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

  my $tdir = "/tmp/AVSS09Scorer_tester-Temp_$testname";
  `rm -rf $tdir` if (-e $tdir);
  MMisc::error_quit("Could not make temporary dir for testing ($tdir)")
    if (! MMisc::make_dir($tdir));
  my $sdir = "$tdir/SYS";
  MMisc::error_quit("Could not make temporary dir for testing ($sdir)")
    if (! MMisc::make_dir($sdir));
  my $gdir = "$tdir/GTF";
  MMisc::error_quit("Could not make temporary dir for testing ($gdir)")
    if (! MMisc::make_dir($gdir));

  $command .= " -w $tdir -D $sdir -d $gdir";

  my $retval = F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev);

  if ($mode eq $mmk) {
    print "  (keeping: $tdir)\n";
  } else {
    `rm -rf $tdir`;
  }

  return($retval);
}
