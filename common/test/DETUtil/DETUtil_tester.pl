#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#

use strict;
use F4DE_TestCore;
use MMisc;

my $detutil = shift @ARGV;
my $mode = shift @ARGV;

print "** Running DETUtil/SRL reading tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";

my $t0 = F4DE_TestCore::get_currenttime();

###
###  This code tests reading OLD srl files.  The srls are built by hand by uncommenting the code to save .srl files in DEVA/test/MTests
###  and moving them in place following the version conventions.
###


foreach my $testid("1", "1o", "3", "3d"){
  foreach my $version("2.4.4", "2.4.3.3"){
    $tn = "test$testid.V$version";
    $testr += &do_simple_test($tn, "(Unit Test)", 
                              "perl -I../../../common/lib $detutil -x -X -o foo.png res-$tn.srl.gz ; cat foo.results.txt", "res-$tn.txt");

    
  }
}

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

  my $rtn = F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev);
  system "rm -f foo.results.txt foo.png";
  return($rtn);
}

##

sub check_x {
  my $err = MMisc::check_file_x($_[0]);
  MMisc::error_quit("Problem with executable ($_[0]) : $err")
    if (! MMisc::is_blank($err));
}
