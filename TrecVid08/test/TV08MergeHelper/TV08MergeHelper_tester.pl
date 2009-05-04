#!/usr/bin/env perl

use strict;
use F4DE_TestCore;
use MMisc;

my $cmd = shift @ARGV;
MMisc::error_quit("ERROR: MergeHelper ($cmd) empty or not an executable\n")
  if ((MMisc::is_blank($cmd)) || (! MMisc::is_file_x($cmd)));
my $mode = shift @ARGV;

print "** Running TV08MergeHelper tests:\n";

my $totest = 0;
my $testr = 0;

my $d = "../common";
my $tn = "";

##
$tn = "test1a";
$testr += &do_complex_test($tn, "(GTF: Basic)", "-g $d/test1-gtf.xml $d/test2-gtf.xml -f PAL -w /tmp", "res_$tn.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$tn-file.xml");

##
$tn = "test1b";
$testr += &do_complex_test($tn, "(SYS: Basic)", "$d/test1-1md-sys.xml $d/test1-same-sys.xml $d/test3-sys.xml $d/test1-1fa-sys.xml $d/test2-1md_1fa-sys.xml $d/test2-same-sys.xml -f PAL -w /tmp", "res_$tn.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$tn-file1.xml", "/tmp/20061212.mpg.xml:res_$tn-file2.xml");

##
$tn = "test2a";
$testr += &do_complex_test($tn, "(GTF: Frameshift)", "-g $d/test1-gtf.xml $d/test2-gtf.xml:400 -f PAL -w /tmp", "res_$tn.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$tn-file.xml");

##
$tn = "test2b";
$testr += &do_complex_test($tn, "(SYS: FrameShift)", "$d/test1-1md-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -w /tmp", "res_$tn.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$tn-file.xml");

##
$tn = "test3a";
$testr += &do_complex_test($tn, "(GTF: Frameshift + Overlap check)", "-g $d/test1-gtf.xml $d/test2-gtf.xml:400 -f PAL -w /tmp -s -o", "res_$tn.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$tn-file.xml");

##
$tn = "test3b";
$testr += &do_complex_test($tn, "(SYS: FrameShift + ForceFilename + Overlap Check)", "$d/test1-1md-sys.xml $d/test3-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -w /tmp -s -S -o -F samefile", "res_$tn.txt", "/tmp/samefile.xml:res_$tn-file.xml");

##
$tn = "test4a";
$testr += &do_complex_test($tn, "(GTF: Frameshift + Overlap check + ECF)", "-g $d/test1-gtf.xml $d/test2-gtf.xml:400 -f PAL -w /tmp -s -o -e /tmp/ecf4a.csv", "res_$tn.txt", "/tmp/20050519-1503-Excerpt.mpg.xml:res_$tn-file1.xml", "/tmp/ecf4a.csv:res_$tn-file2.csv");

##
$tn = "test4b";
$testr += &do_complex_test($tn, "(SYS: FrameShift + ForceFilename + Overlap Check + ECF)", "$d/test1-1md-sys.xml $d/test3-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -w /tmp -s -S -o -F samefile -e /tmp/ecf4b.csv", "res_$tn.txt", "/tmp/samefile.xml:res_$tn-file1.xml", "/tmp/ecf4b.csv:res_$tn-file2.csv");

##
$tn = "test5a";
$testr += &do_simple_test($tn, "(SYS: FrameShift + ForceFilename + Overlap Check / on stdout)", "$d/test1-1md-sys.xml $d/test3-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -s -S -o -F samefile", "res_$tn.txt");

##
$tn = "test5b";
$testr += &do_simple_test($tn, "(SYS: FrameShift + ForceFilename + Overlap Check / on stdout + pruneEvents)", "$d/test1-1md-sys.xml $d/test3-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -s -S -o -F samefile -p", "res_$tn.txt");

##
$tn = "test5c";
$testr += &do_simple_test($tn, "(SYS: FrameShift + ForceFilename + Overlap Check / on stdout + pruneEvents + OverlapOnlyXML)", "$d/test1-1md-sys.xml $d/test3-sys.xml $d/test1-same-sys.xml:40 $d/test1-1fa-sys.xml:10000 $d/test2-1md_1fa-sys.xml:5000 $d/test2-same-sys.xml:1500 -f PAL -s -S -o -F samefile -p -O", "res_$tn.txt");

#####

if ($testr == $totest) {
  MMisc::ok_quit("All tests ok\n");
}

MMisc::error_quit("Not all test ok\n");

##########

sub do_complex_test {
  my ($testname, $subtype, $args, $res, @sfiles) = @_;

  my $command = "$cmd $args";
  $totest++;

  return(F4DE_TestCore::run_complextest($testname, $subtype, $command, $res, $mode, @sfiles));
}

#####

sub do_simple_test {
  my ($testname, $subtype, $args, $res) = @_;

  my $command = "$cmd $args";
  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode));
}
