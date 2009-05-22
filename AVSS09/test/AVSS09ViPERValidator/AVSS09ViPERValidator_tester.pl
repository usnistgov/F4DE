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


print "** Running AVSS09ViPERValidator tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = ""; # Test name

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$testr += &do_simple_test($tn, "(GTF files check)", "$tool ../common/test_file?.clear.xml -g -w", "res_$tn.txt");

##
$tn = "test2";
$testr += &do_simple_test($tn, "(SYS files check)", "$tool ../common/test_file?.sys.xml ../common/test_file?.ss.xml -w", "res_$tn.txt");

##
$tn = "test3";
$testr += &do_simple_test($tn, "(DCR, DCF, Evaluate checks)", "./_special_test1.pl", "res_$tn.txt");

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
