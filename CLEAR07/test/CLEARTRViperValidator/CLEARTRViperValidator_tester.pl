#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my $validator = shift @ARGV;
MMisc::error_quit("ERROR: Validator ($validator) empty or not an executable\n")
  if (($validator eq "") || (! -f $validator) || (! -x $validator));
my $mode = shift @ARGV;

print "** Running CLEARTRViperValidator tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";
my $td = "";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1a";
$td = "BN_TR";
$testr += &do_simple_test($tn, $td, "(BN TextRec: Reference files)", "*.gtf", "", "-D BN -w -f 15", "res_$tn.txt");

##
$tn = "test1b";
$td = "BN_TR";
$testr += &do_simple_test($tn, $td, "(BN TextRec: System Submissions)", "", "*.rdf", "-D BN -w -f 15", "res_$tn.txt");

#####

my $elapsed = F4DE_TestCore::get_elapsedtime($t0);
my $add = "";
$add .= " [Elapsed: $elapsed seconds]" if (F4DE_TestCore::is_elapsedtime_on());

MMisc::ok_quit("All test ok$add\n\n")
  if ($testr == $totest);

MMisc::error_quit("Not all test ok$add\n\n");

##########

sub do_simple_test {
  my ($testname, $testdir, $subtype, $rf, $sf, $params, $res) = @_;
  my ($files, $command);

  if ($rf ne "") {
    $files = "../common/$testdir/$rf";
    $command = "$validator -g $files $params";
  }
  elsif ($sf ne "") {
    $files = "../common/$testdir/$sf";
    $command = "$validator $files $params";
  }
  else {
    MMisc::error_quit("No input files for validator\n\n");
  }

  $totest++;

  return(1) if (! F4DE_TestCore::check_files($testname, $subtype, "intentionally", $files, $res));

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode));
}
