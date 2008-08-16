#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;

my $scorer = shift @ARGV;
error_quit("ERROR: Scorer ($scorer) empty or not an executable\n")
  if (($scorer eq "") || (! -f $scorer) || (! -x $scorer));
my $mode = shift @ARGV;

print "** Running TV08Scorer tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";

$tn = "test1a";
$testr += &do_simple_test($tn, "(same)", "test1-gtf.xml", "test1-same-sys.xml", "-D 1000", "res-$tn.txt");

$tn = "test1b";
$testr += &do_simple_test($tn, "(1x False Alarm)",  "test1-gtf.xml", "test1-1fa-sys.xml", "-D 1000", "res-$tn.txt");

$tn = "test1c";
$testr += &do_simple_test($tn, "(1x Missed Detect)",  "test1-gtf.xml", "test1-1md-sys.xml", "-D 1000", "res-$tn.txt");

$tn = "test2a";
$testr += &do_simple_test($tn, "(same)",  "test2-gtf.xml", "test2-same-sys.xml", "-D 1000", "res-$tn.txt");

$tn = "test2b";
$testr += &do_simple_test($tn, "(1x Missed Detect + 1x False Alarm)", "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000", "res-$tn.txt");

$tn = "test3a";
$testr += &do_simple_test($tn, "(ECF check 1)",  "test2-gtf.xml", "test2-same-sys.xml", "-D 1000 -e ../common/tests.ecf", "res-$tn.txt");

$tn = "test3b";
$testr += &do_simple_test($tn, "(ECF check 2)",  "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -e ../common/tests.ecf", "res-$tn.txt");

$tn = "test4";
$testr += &do_simple_test($tn, "(Big Test)", "test4-BigTest.ref.xml", "test4-BigTest.sys.xml", "-D 90000 --computeDETCurve --noPNG -N" , "res-$tn-BigTest.txt");

$tn = "test5a";
$testr += &do_simple_test($tn, "(writexml)",  "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -w", "res-$tn.txt");

$tn = "test5b";
$testr += &do_simple_test($tn, "(writexml + pruneEvents)", "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -w -p", "res-$tn.txt");

$tn = "test6";
$testr += &do_simple_test($tn, "(Limittosysevents)", "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -L", "res-$tn.txt");

$tn = "test7a";
$testr += &do_simple_test($tn, "(XtraMappedObservations [copy_sys])", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p -X copy_sys", "res-$tn.txt");

$tn = "test7b";
$testr += &do_simple_test($tn, "(XtraMappedObservations [copy_ref])", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p -X copy_ref", "res-$tn.txt");

$tn = "test7c";
$testr += &do_simple_test($tn, "(XtraMappedObservations [overlap])", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p -X overlap", "res-$tn.txt");

$tn = "test7d";
$testr += &do_simple_test($tn, "(XtraMappedObservations [extended])", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p -X extended", "res-$tn.txt");

$tn = "test7e";
$testr += &do_simple_test($tn, "(\'xtra\' files)", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p", "res-$tn.txt");

if ($testr == $totest) {
  ok_quit("All test ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_simple_test {
  my ($testname, $subtype, $rf, $sf, $ao, $res) = @_;
  my $frf = "../common/$rf";
  my $fsf = "../common/$sf";

  my $command = "$scorer -a -f 25 -d 1 $fsf -g $frf -s -o $ao";
  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode));
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
