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

$testr += &do_test("Test 1a (same)", "test1-gtf.xml", "test1-same-sys.xml", "TV08res-test1-same.txt");
$totest++;

$testr += &do_test("Test 1b (1x False Alarm)",  "test1-gtf.xml", "test1-1fa-sys.xml", "TV08res-test1-1fa.txt");
$totest++;

$testr += &do_test("Test 1c (1x Missed Detect)",  "test1-gtf.xml", "test1-1md-sys.xml", "TV08res-test1-1md.txt");
$totest++;

$testr += &do_test("Test 2a (same)",  "test2-gtf.xml", "test2-same-sys.xml", "TV08res-test2-same.txt");
$totest++;

$testr += &do_test("Test 2b (1x Missed Detect + 1x False Alarm)",  "test2-gtf.xml", "test2-1md_1fa-sys.xml", "TV08res-test2-1md_1fa.txt");
$totest++;

if ($testr == $totest) {
  ok_quit("All test ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_test {
  my ($testname, $rf, $sf, $res) = @_;
  my $frf = "../common/$rf";
  my $fsf = "../common/$sf";

  my $command = "$scorer -f 25 -d 1 $fsf -g $frf -s -p";

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
