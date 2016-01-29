#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#

BEGIN {
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
            || ($ENV{PERL_HASH_SEED} != 0)
            || (! exists $ENV{PERL_PERTURB_KEYS} )
            || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }
}

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

my $trial_metric_add = "-u MetricTestStub -U ValueC=0.1 -U ValueV=1 -U ProbOfTerm=0.0001 -T TOTALTRIALS=10";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$testr += &do_less_simple_test($tn, "(filter1)", "-r ../../../common/test/common/ref.csv -s ../../../common/test/common/sys.csv ../../../common/test/common/md.csv -F ../common/filter1.sql", "res-$tn.txt");

##
$tn = "test2";
$testr += &do_less_simple_test($tn, "(filter2)", "-r ../../../common/test/common/ref.csv -s ../../../common/test/common/sys.csv ../../../common/test/common/md.csv -F ../common/filter2.sql", "res-$tn.txt");

##
$tn = "test3";
$testr += &do_skip_test($tn, "(filter1, skip DB recreation, filter2)", "-r ../../../common/test/common/ref.csv -s ../../../common/test/common/sys.csv ../../../common/test/common/md.csv -F ../common/filter1.sql", "res-$tn.txt", "-F ../common/filter2.sql");

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
    if (! MMisc::make_wdir($tdir));
  
  my $command = "$tool -o $tdir $cadd $trial_metric_add ; cat $tdir/scoreDB.scores.txt";

  my $retval = &do_simple_test($testname, $subtype, $command, $res, $rev);

  my $db = "$tdir/scoreDB.db";
  $retval += &do_simple_test($testname, "(DB check)", "sqlite3 $db < add_checker.sql", $res . "-DBcheck", $rev);

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
    if (! MMisc::make_wdir($tdir));
  
  my $tdir1 = "$tdir/step1";
  MMisc::error_quit("Could not make temporary dir for testing ($tdir1)")
    if (! MMisc::make_wdir($tdir1));

  my $tdir2 = "$tdir/step2";
  MMisc::error_quit("Could not make temporary dir for testing ($tdir2)")
    if (! MMisc::make_wdir($tdir2));

  my $command = "$tool -o $tdir1 $cadd1 $trial_metric_add";

  my $retval = &do_simple_test($testname, "$subtype [step1]", $command, $res . "-step1", $rev);

  my $db = "$tdir1/scoreDB.db";
  $retval += &do_simple_test($testname, "$subtype [step1 DBcheck]", "sqlite3 $db < add_checker.sql", $res . "-step1_DBcheck", $rev);

  $command = "$tool -c -C -R $tdir1/referenceDB.db -S $tdir1/systemDB.db -M $tdir1/metadataDB.db -o $tdir2 $cadd2 $trial_metric_add";

  $retval += &do_simple_test($testname, "$subtype [step2]", $command, $res . "-step2", $rev);

  $db = "$tdir2/scoreDB.db";
  $retval += &do_simple_test($testname, "$subtype [step2 DBcheck]", "sqlite3 $db < add_checker.sql", $res . "-step2_DBcheck", $rev);

  if ($mode eq $mmk) {
    print "  (keeping: $tdir)\n";
  } else {
    `rm -rf $tdir`;
  }

  return($retval);
}
