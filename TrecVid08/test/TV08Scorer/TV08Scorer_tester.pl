#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my $scorer = shift @ARGV;
MMisc::error_quit("ERROR: Scorer ($scorer) empty or not an executable\n")
  if ((MMisc::is_blank($scorer)) || (! MMisc::is_file_x($scorer)));
my $mode = shift @ARGV;

print "** Running TV08Scorer tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1a";
$testr += &do_simple_test($tn, "(same)", "test1-gtf.xml", "test1-same-sys.xml", "-D 1000", "res-$tn.txt");

##
$tn = "test1b";
$testr += &do_simple_test($tn, "(1x False Alarm)",  "test1-gtf.xml", "test1-1fa-sys.xml", "-D 1000", "res-$tn.txt");

##
$tn = "test1c";
$testr += &do_simple_test($tn, "(1x Missed Detect)",  "test1-gtf.xml", "test1-1md-sys.xml", "-D 1000", "res-$tn.txt");

##
$tn = "test2a";
$testr += &do_simple_test($tn, "(same)",  "test2-gtf.xml", "test2-same-sys.xml", "-D 1000", "res-$tn.txt");

##
$tn = "test2b";
$testr += &do_simple_test($tn, "(1x Missed Detect + 1x False Alarm)", "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000", "res-$tn.txt");

##
$tn = "test3a";
$testr += &do_simple_test($tn, "(ECF check 1)",  "test2-gtf.xml", "test2-same-sys.xml", "-D 1000 -e ../common/tests.ecf", "res-$tn.txt");

##
$tn = "test3b";
$testr += &do_simple_test($tn, "(ECF check 2)",  "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -e ../common/tests.ecf", "res-$tn.txt");

##
$tn = "test3c";
$testr += &do_simple_test($tn, "(ECF check 3)",  "test2-gtf.xml test3-gtf.xml", "test2-1md_1fa-sys.xml test3-sys.xml", "-D 1000 -e ../common/tests-BAD.ecf", "res-$tn.txt", 1);

##
$tn = "test3d";
$testr += &do_simple_test($tn, "(ECF check 4)",  "test2-gtf.xml test3-gtf.xml", "test2-1md_1fa-sys.xml test3-sys.xml", "-e ../common/tests.ecf", "res-$tn.txt");

##
$tn = "test4";
$testr += &do_simple_test($tn, "(Big Test)", "test4-BigTest.ref.xml", "test4-BigTest.sys.xml", "-D 90000 --computeDETCurve --noPNG -N" , "res-$tn-BigTest.txt");

##
$tn = "test5a";
$testr += &do_simple_test($tn, "(writexml)",  "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -w", "res-$tn.txt");

##
$tn = "test5b";
$testr += &do_simple_test($tn, "(writexml + pruneEvents)", "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -w -p", "res-$tn.txt");

##
$tn = "test6";
$testr += &do_simple_test($tn, "(Limittosysevents)", "test2-gtf.xml", "test2-1md_1fa-sys.xml", "-D 1000 -L", "res-$tn.txt");

##
$tn = "test7a";
$testr += &do_simple_test($tn, "(XtraMappedObservations [copy_sys])", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p -X copy_sys", "res-$tn.txt");

##
$tn = "test7b";
$testr += &do_simple_test($tn, "(XtraMappedObservations [copy_ref])", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p -X copy_ref", "res-$tn.txt");

##
$tn = "test7c";
$testr += &do_simple_test($tn, "(XtraMappedObservations [overlap])", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p -X overlap", "res-$tn.txt");

##
$tn = "test7d";
$testr += &do_simple_test($tn, "(XtraMappedObservations [extended])", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p -X extended", "res-$tn.txt");

##
$tn = "test7e";
$testr += &do_simple_test($tn, "(\'xtra\' files)", "test6-Xtra-gtf.xml", "test6-Xtra-sys.xml", "-D 1000 -s -a -w -p", "res-$tn.txt");

#####

my $elapsed = F4DE_TestCore::get_elapsedtime($t0);
my $add = "";
$add .= " [Elapsed: $elapsed seconds]" if (F4DE_TestCore::is_elapsedtime_on());

MMisc::ok_quit("All test ok$add\n")
  if ($testr == $totest);

MMisc::error_quit("Not all test ok$add\n");

##########

sub do_simple_test {
  my ($testname, $subtype, $rf, $sf, $ao, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", "", "", 0);
  my $frf = "";
  foreach my $i (split(m%\s+%, $rf)) { $frf .= "../common/$i ";}
  my $fsf = "";
  foreach my $i (split(m%\s+%, $sf)) { $fsf .= "../common/$i ";}

  my $command = "$scorer --NoDet --noPNG -a -f 25 -d 1 ${fsf}-g ${frf}-s -o $ao";
  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev));
}
