#!/usr/bin/env perl

use strict;
use TV08TestCore;

my $validator = shift @ARGV;
error_quit("ERROR: Validator ($validator) empty or not an executable\n")
  if (($validator eq "") || (! -f $validator) || (! -x $validator));
my $mode = shift @ARGV;

print "** Running TV08ViperValidator tests:\n";

my $totest = 0;
my $testr = 0;

$testr += &do_test1("Test 0 (Base XML Generation)", "-X", "res_test0.txt");

$testr += &do_test1("Test 1 (Not a Viper File)", "TV08ViperValidator_tester.pl", "res_test1.txt");

$testr += &do_test1("Test 2 (GTF files check)", "../../test/common/test1-gtf.xml ../../test/common/test2-gtf.xml -g -w", "res_test2.txt");

$testr += &do_test1("Test 3 (SYS file check)", "../../test/common/test1-1fa-sys.xml ../../test/common/test1-1md-sys.xml ../../test/common/test1-same-sys.xml ../../test/common/test2-1md_1fa-sys.xml ../../test/common/test2-same-sys.xml -w", "res_test3.txt");

$testr += &do_test1("Test 4 (limitto check)", "../../test/common/test1-gtf.xml ../../test/common/test2-gtf.xml -g -w -l ObjectPut", "res_test4.txt");

$testr += &do_test1("Test 5a (subEventtypes)", "../../test/common/test5-subEventtypes-sys.xml -w", "res_test5a.txt");

$testr += &do_test1("Test 5b (subEventtypes + pruneEvents)", "../../test/common/test5-subEventtypes-sys.xml -w -p", "res_test5b.txt");

$testr += &do_test1("Test 5c (subEventtypes + pruneEvents + removeSubEventtypes)", "../../test/common/test5-subEventtypes-sys.xml -w -p -r", "res_test5c.txt");


if ($testr == $totest) {
  ok_quit("All tests ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_test1 {
  my ($testname, $args, $res) = @_;

  my $command = "$validator $args";
  $totest++;

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
