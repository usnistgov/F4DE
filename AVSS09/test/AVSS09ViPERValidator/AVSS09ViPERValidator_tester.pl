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

##
$tn = "test1";
$testr += &do_simple_test($tn, "(GTF files check)", "$tool ../common/MCTTR0201a.clear.xml ../common/MCTTR0202a.clear.xml -g -w", "res_$tn.txt");

##
$tn = "test2";
$testr += &do_simple_test($tn, "(SYS files check)", "$tool ../common/MCTTR0201a.sys.xml ../common/MCTTR0202a.sys.xml -w", "res_$tn.txt");

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

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev));
}
