#!/usr/bin/env perl

use strict;
use TV08TestCore;

my $scorer = shift @ARGV;
error_quit("ERROR: Scorer ($scorer) empty or not an executable\n")
  if (($scorer eq "") || (! -f $scorer) || (! -x $scorer));
my $mode = shift @ARGV;

print "** Running TV08Scorer tests:\n";

my $totest = 0;
my $testr = 0;

$testr += &do_test("Test 1a (same)", "test1-gtf.xml", "test1-same-sys.xml", "-D 1000", "res-test1a.txt");
$totest++;

$testr += &do_test("Test 1b (1x False Alarm)",  "test1-gtf.xml", "test1-1fa-sys.xml", "-D 1000", "res-test1b.txt");
$totest++;

$testr += &do_test("Test 1c (1x Missed Detect)",  "test1-gtf.xml", "test1-1md-sys.xml", "-D 1000", "res-test1c.txt");
$totest++;

$testr += &do_test("Test 2a (same)",  "test2-gtf.xml", "test2-same-sys.xml", "-D 1000", "res-test2a.txt");
$totest++;

$testr += &do_test("Test 2b (1x Missed Detect + 1x False Alarm)",  "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000", "res-test2b.txt");
$totest++;

$testr += &do_test("Test 3a (ECF check 1)",  "test2-gtf.xml", "test2-same-sys.xml", "-D 1000 -e ../common/tests.ecf", "res-test3a.txt");
$totest++;

$testr += &do_test("Test 3b (ECF check 2)",  "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -e ../common/tests.ecf", "res-test3b.txt");
$totest++;

$testr += &do_test("Test 4 (Big Test)",  "test4-BigTest.ref.xml", "test4-BigTest.sys.xml", "-D 90000 --computeDETCurve --noPNG" , "res-test4-BigTest.txt");
$totest++;

if ($testr == $totest) {
  ok_quit("All test ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_test {
  my ($testname, $rf, $sf, $ao, $res) = @_;
  my $frf = "../common/$rf";
  my $fsf = "../common/$sf";

  my $command = "$scorer -a -f 25 -d 1 $fsf -g $frf -s -o $ao";

  return(TV08TestCore::run_simpletest($testname, $command, $res, $mode));
}

#####

sub ok_quit {
  print @_;
  exit(0);
}

#####

sub error_quit {
  print @_;
  exit(1);
}
