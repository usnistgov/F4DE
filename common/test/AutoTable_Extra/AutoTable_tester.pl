#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

use AutoTable;

my $mode = shift @ARGV;

my $tsvload = "./tsv_load.pl";
&check_x($tsvload);

my $spload = "./sp_load.pl";
&check_x($spload);

print "** Running AutoTable Extra tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$testr += &do_simple_test($tn, "(Unit Test)", "perl -I../../../common/lib -e 'use AutoTable; AutoTable::unitTest();'", "res-$tn.txt");

##
$tn = "test2";
$testr += &do_simple_test($tn, "(TSV load)", "$tsvload ../common/md.tsv", "res-$tn.txt");

##
$tn = "test3a";
$testr += &do_simple_test($tn, "(Special load)", "$spload ../common/md.csv ../common/md_sp.csv", "res-$tn.txt");

##
$tn = "test3b";
$testr += &do_simple_test($tn, "(Special load with Primary key)", "$spload ../common/md.csv ../common/md_sp.csv TrialID", "res-$tn.txt");

##
$tn = "test3c";
$testr += &do_simple_test($tn, "(Special load with non primary key, removing data)", "$spload ../common/md.csv ../common/md_sp.csv name,color", "res-$tn.txt");

##
$tn = "test3d";
$testr += &do_simple_test($tn, "(Special load with Keep Only)", "$spload ../common/md.csv ../common/md_sp.csv \'\' name,year,color", "res-$tn.txt");

##
$tn = "test3e";
$testr += &do_simple_test($tn, "(Special load with Remove headers)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' name,year", "res-$tn.txt");

##
$tn = "test4a";
$testr += &do_simple_test($tn, "(Reverse Sort Test)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' \'\' reverse", "res-$tn.txt");

##
$tn = "test4b";
$testr += &do_simple_test($tn, "(SHA1 Digest Sort Test)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' \'\' sha1", "res-$tn.txt");

##
$tn = "test4c";
$testr += &do_simple_test($tn, "(SHA224 Digest Sort Test)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' \'\' sha224", "res-$tn.txt");

##
$tn = "test4d";
$testr += &do_simple_test($tn, "(SHA256 Digest Sort Test)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' \'\' sha256", "res-$tn.txt");

##
$tn = "test4e";
$testr += &do_simple_test($tn, "(SHA384 Digest Sort Test)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' \'\' sha384", "res-$tn.txt");

##
$tn = "test4f";
$testr += &do_simple_test($tn, "(SHA512 Digest Sort Test)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' \'\' sha512", "res-$tn.txt");

##
$tn = "test4g";
$testr += &do_simple_test($tn, "(SHA512/224 Digest Sort Test)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' \'\' sha512224", "res-$tn.txt");

##
$tn = "test4h";
$testr += &do_simple_test($tn, "(SHA512/256 Digest Sort Test)", "$spload ../common/md.csv ../common/md_sp.csv \'\' \'\' \'\' sha512256", "res-$tn.txt");

#####

my $elapsed = F4DE_TestCore::get_elapsedtime($t0);
my $add = "";
$add .= " [Elapsed: $elapsed seconds]" if (F4DE_TestCore::is_elapsedtime_on());

MMisc::ok_quit("All test ok$add\n")
  if ($testr == $totest);

MMisc::error_quit("Not all test ok$add\n");

##########

sub do_simple_test {
  my ($testname, $subtype, $command, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", 0, "");

  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev));
}

##

sub check_x {
  my $err = MMisc::check_file_x($_[0]);
  MMisc::error_quit("Problem with executable ($_[0]) : $err")
    if (! MMisc::is_blank($err));
}
