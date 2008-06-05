#!/usr/bin/env perl

use strict;
use TV08TestCore;

my $cmd = shift @ARGV;
error_quit("ERROR: MergeHelper ($cmd) empty or not an executable\n")
  if (($cmd eq "") || (! -f $cmd) || (! -x $cmd));
my $mode = shift @ARGV;

print "** Running TV08MergeHelper tests:\n";

my $totest = 0;
my $testr = 0;

my $d = "../common";
my $s = "";

$s = "test1a";
$testr += &do_test1("Test 1a (GTF: Basic)", "-g $d/test1-gtf.xml $d/test2-gtf.xml -f PAL -w /tmp", "res_$s.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$s-file.xml");
$totest++;

$s = "test1b";
$testr += &do_test1("Test 1b (SYS: Basic)", "$d/test1-1md-sys.xml $d/test1-same-sys.xml $d/test3-sys.xml $d/test1-1fa-sys.xml $d/test2-1md_1fa-sys.xml $d/test2-same-sys.xml -f PAL -w /tmp", "res_$s.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$s-file1.xml", "/tmp/20061212.mpg.xml:res_$s-file2.xml");
$totest++;

$s = "test2a";
$testr += &do_test1("Test 2a (GTF: Frameshift)", "-g $d/test1-gtf.xml $d/test2-gtf.xml:400 -f PAL -w /tmp", "res_$s.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$s-file.xml");
$totest++;

$s = "test2b";
$testr += &do_test1("Test 2b (SYS: FrameShift)", "$d/test1-1md-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -w /tmp", "res_$s.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$s-file.xml");
$totest++;

$s = "test3a";
$testr += &do_test1("Test 3a (GTF: Frameshift + Overlap check)", "-g $d/test1-gtf.xml $d/test2-gtf.xml:400 -f PAL -w /tmp -s -o", "res_$s.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$s-file.xml");
$totest++;

$s = "test3b";
$testr += &do_test1("Test 3b (SYS: FrameShift + ForceFilename + Overlap Check)", "$d/test1-1md-sys.xml $d/test3-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -w /tmp -s -S -o -F samefile", "res_$s.txt", "/tmp/samefile.xml:res_$s-file.xml");
$totest++;

$s = "test4a";
$testr += &do_test1("Test 4a (GTF: Frameshift + Overlap check + ECF)", "-g $d/test1-gtf.xml $d/test2-gtf.xml:400 -f PAL -w /tmp -s -o -e /tmp/ecf4a.csv", "res_$s.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$s-file1.xml", "/tmp/ecf4a.csv:res_$s-file2.csv");
$totest++;

$s = "test4b";
$testr += &do_test1("Test 4b (SYS: FrameShift + ForceFilename + Overlap Check + ECF)", "$d/test1-1md-sys.xml $d/test3-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -w /tmp -s -S -o -F samefile -e /tmp/ecf4b.csv", "res_$s.txt", "/tmp/samefile.xml:res_$s-file1.xml", "/tmp/ecf4b.csv:res_$s-file2.csv");
$totest++;

if ($testr == $totest) {
  ok_quit("All tests ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_test1 {
  my ($testname, $args, $res, @sfiles) = @_;

  my $command = "$cmd $args";

  return(TV08TestCore::run_complextest($testname, $command, $res, $mode, @sfiles));
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
