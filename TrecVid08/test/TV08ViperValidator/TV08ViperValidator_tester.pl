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
$totest++;

$testr += &do_test1("Test 1 (Not a Viper File)", "TV08ViperValidator_tester.pl", "res_test1.txt");
$totest++;


if ($testr == $totest) {
  ok_quit("All test ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_test1 {
  my ($testname, $args, $res) = @_;

  my $command = "$validator $args";

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
