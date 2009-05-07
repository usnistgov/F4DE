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

##
$tn = "test1";
$testr += &do_simple_test($tn, "(Empty SYS vs GTF)", "$tool ../common/MCTTR0202a.empty.xml -g ../common/MCTTR0202a.clear.xml", "res_$tn.txt");

##
$tn = "test2";
$testr += &do_simple_test($tn, "(Starter SYS vs GTF)", "$tool ../common/MCTTR0202a.ss.xml -g ../common/MCTTR0202a.clear.xml", "res_$tn.txt");

##
$tn = "test3";
$testr += &do_simple_test($tn, "(Full SYS vs GTF)", "$tool ../common/MCTTR0202a.sys.xml -g ../common/MCTTR0202a.clear.xml", "res_$tn.txt");

#####

if ($testr == $totest) {
  MMisc::ok_quit("All tests ok\n");
}

MMisc::error_quit("Not all test ok\n");

##########

sub do_simple_test {
  my ($testname, $subtype, $command, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", 0);
  
  $totest++;

  my $tdir = "/tmp/AVSS09Scorer_tester-Temp_$testname";
  `rm -rf $tdir` if (-e $tdir);
  MMisc::error_quit("Could not make temporary dir for testing ($tdir)")
    if (! MMisc::make_dir($tdir));

  $command .= " -w $tdir";

  my $add = F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev);

  if ($mode eq $mmk) {
    print "  (keeping: $tdir)\n";
  } else {
    `rm -rf $tdir`;
  }

  return($add);
}
