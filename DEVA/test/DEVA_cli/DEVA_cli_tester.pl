#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my $tool = shift @ARGV;
MMisc::error_quit("ERROR: Tool ($tool) empty or not an executable\n")
  if ((MMisc::is_blank($tool)) || (! MMisc::is_file_x($tool)));
my $mode = shift @ARGV;

print "** Running DEVA_cli tests:\n";

my $mmk = F4DE_TestCore::get_magicmode_comp_key();

my $totest = 0;
my $testr = 0;
my $tn = "";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$testr += &do_less_simple_test($tn, "(filter1)", "-r ../../../common/test/common/ref.csv -s ../../../common/test/common/sys.csv ../../../common/test/common/md.csv -F ../common/filter1.cmd", "res-$tn.txt");

##
$tn = "test2";
$testr += &do_less_simple_test($tn, "(filter2)", "-r ../../../common/test/common/ref.csv -s ../../../common/test/common/sys.csv ../../../common/test/common/md.csv -F ../common/filter2.cmd", "res-$tn.txt");

##
$tn = "test3";
$testr += &do_skip_test($tn, "(filter1, skip DB recreation, filter2)", "-r ../../../common/test/common/ref.csv -s ../../../common/test/common/sys.csv ../../../common/test/common/md.csv -F ../common/filter1.cmd", "res-$tn.txt", "-F ../common/filter2.cmd");

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
    MMisc::iuav(\@_, "", "", "", "", 0);

  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev));
}

#####

sub do_less_simple_test {
  my ($testname, $subtype, $cadd, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", 0);
  
  my $tdir = "/tmp/DEVA_cli_tester-Temp_$testname";
  `rm -rf $tdir` if (-e $tdir); # Erase the previous one if present
  MMisc::error_quit("Could not make temporary dir for testing ($tdir)")
    if (! MMisc::make_dir($tdir));
  
  my $command = "$tool -o $tdir $cadd";

  my $retval = &do_simple_test($testname, $subtype, $command, $res, $rev);

  my $db = "$tdir/scoreDB.sql";
  $retval += &do_simple_test($testname, "(DB check)", "sqlite3 $db < add_checker_sql.cmd", $res . "-DBcheck", $rev);

  if ($mode eq $mmk) {
    print "  (keeping: $tdir)\n";
  } else {
    `rm -rf $tdir`;
  }

  return($retval);
}

##########

sub do_skip_test {
  my ($testname, $subtype, $cadd1, $res, $cadd2, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", "", 0);
  
  my $tdir = "/tmp/DEVA_cli_tester-Temp_$testname";
  `rm -rf $tdir` if (-e $tdir); # Erase the previous one if present
  MMisc::error_quit("Could not make temporary dir for testing ($tdir)")
    if (! MMisc::make_dir($tdir));
  
  my $tdir1 = "$tdir/step1";
  MMisc::error_quit("Could not make temporary dir for testing ($tdir1)")
    if (! MMisc::make_dir($tdir1));

  my $tdir2 = "$tdir/step2";
  MMisc::error_quit("Could not make temporary dir for testing ($tdir2)")
    if (! MMisc::make_dir($tdir2));

  my $command = "$tool -o $tdir1 $cadd1";

  my $retval = &do_simple_test($testname, "$subtype [step1]", $command, $res . "-step1", $rev);

  my $db = "$tdir1/scoreDB.sql";
  $retval += &do_simple_test($testname, "$subtype [step1 DBcheck]", "sqlite3 $db < add_checker_sql.cmd", $res . "-step1_DBcheck", $rev);

  $command = "$tool -c -C -R $tdir1/referenceDB.sql -S $tdir1/systemDB.sql -m $tdir1/metadataDB.sql -o $tdir2 $cadd2";

  $retval += &do_simple_test($testname, "$subtype [step2]", $command, $res . "-step2", $rev);

  $db = "$tdir2/scoreDB.sql";
  $retval += &do_simple_test($testname, "$subtype [step2 DBcheck]", "sqlite3 $db < add_checker_sql.cmd", $res . "-step2_DBcheck", $rev);

  if ($mode eq $mmk) {
    print "  (keeping: $tdir)\n";
  } else {
    `rm -rf $tdir`;
  }

  return($retval);
}
