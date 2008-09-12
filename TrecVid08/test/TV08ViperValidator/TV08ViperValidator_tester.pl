#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;

my $validator = shift @ARGV;
error_quit("ERROR: Validator ($validator) empty or not an executable\n")
  if (($validator eq "") || (! -f $validator) || (! -x $validator));
my $mode = shift @ARGV;

print "** Running TV08ViperValidator tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = ""; # Test name

##
$tn = "test0";
$testr += &do_simple_test($tn, "(Base XML Generation)", "$validator -X", "res_$tn.txt");

##
$tn = "test1";
$testr += &do_simple_test($tn, "(Not a Viper File)", "$validator TV08ViperValidator_tester.pl", "res_${tn}.txt", 1);

##
$tn = "test2";
$testr += &do_simple_test($tn, "(GTF files check)", "$validator ../common/test1-gtf.xml ../common/test2-gtf.xml -g -w", "res_$tn.txt");

##
$tn = "test3";
$testr += &do_simple_test($tn, "(SYS files check)", "$validator ../common/test1-1fa-sys.xml ../common/test1-1md-sys.xml ../common/test1-same-sys.xml ../common/test2-1md_1fa-sys.xml ../common/test2-same-sys.xml -w", "res_$tn.txt");

##
$tn = "test4";
$testr += &do_simple_test($tn, "(limitto check)", "$validator ../common/test1-gtf.xml ../common/test2-gtf.xml -g -w -l ObjectPut", "res_$tn.txt");

##
$tn = "test5a";
$testr += &do_simple_test($tn, "(subEventtypes)", "$validator ../common/test5-subEventtypes-sys.xml -w", "res_$tn.txt");

$tn = "test5b";
$testr += &do_simple_test($tn, "(subEventtypes + pruneEvents)", "$validator ../common/test5-subEventtypes-sys.xml -w -p", "res_$tn.txt");

$tn = "test5c";
$testr += &do_simple_test($tn, "(subEventtypes + pruneEvents + removeSubEventtypes)", "$validator ../common/test5-subEventtypes-sys.xml -w -p -r", "res_$tn.txt");

$tn = "test5d";
$testr += &do_simple_test($tn, "(subEventtypes + limitto)", "$validator ../common/test5-subEventtypes-sys.xml -w -l *:Unmapped_Sys", "res_$tn.txt");

##
$tn = "test6";
$testr += &do_simple_test($tn, "(crop)", "$validator ../common/test1-1fa-sys.xml -w -p -c 1118:2000 -f 25", "res_$tn.txt");

##
$tn = "test7a";
$testr += &do_simple_test($tn, "(ChangeType SYS -> REF)", "$validator ../common/test1-1fa-sys.xml ../common/test2-1md_1fa-sys.xml -w -C 256 -p", "res_$tn.txt");

$tn = "test7b";
$testr += &do_simple_test($tn, "(ChangeType REF -> SYS w/ randomseed)", "$validator ../common/test1-gtf.xml ../common/test2-gtf.xml -g -w -C 256 -p", "res_$tn.txt");

$tn = "test7c";
$testr += &do_simple_test($tn, "(ChangeType REF -> SYS w/ randomseed + find_value)", "$validator ../common/test2-gtf.xml -g -w -C 256:0.120257329 -p", "res_$tn.txt");

##
$tn = "test8a";
$testr += &do_simple_test($tn, "(MemDump)", "$validator ../common/test1-1fa-sys.xml ../common/test2-1md_1fa-sys.xml -w -W text -p", "res_$tn.txt");

$tn = "test8b";
$testr += &do_simple_test($tn, "(MemDump Load)", "$validator ../common/test1-1fa-sys.xml.memdump ../common/test2-1md_1fa-sys.xml.memdump -w -p", "res_$tn.txt");

$tn = "test8c";
$testr += &do_simple_test($tn, "(MemDump gzip save -> load)", "$validator ../common/test1-1fa-sys.xml -w . -W gzip && $validator test1-1fa-sys.xml.memdump -w -p; rm -f test1-1fa-sys.xml*", "res_$tn.txt");

##
$tn = "test9";
$testr += &do_simple_test($tn, "(ForceFilename)", "$validator ../common/test1-1fa-sys.xml ../common/test2-1md_1fa-sys.xml -w -p -F newfilename", "res_$tn.txt");

##
$tn = "test10a";
$testr += &do_simple_test($tn, "(displaySummary [SYS])", "$validator ../common/test1-1fa-sys.xml ../common/test2-1md_1fa-sys.xml ../common/test5-subEventtypes-sys.xml -d 3", "res_$tn.txt");

$tn = "test10b";
$testr += &do_simple_test($tn, "(displaySummary [REF])", "$validator -g ../common/test1-gtf.xml ../common/test2-gtf.xml -d 3", "res_$tn.txt");

##
$tn = "test11a";
$testr += &do_simple_test($tn, "(ECF [REF])", "$validator -g ../common/test1-gtf.xml ../common/test2-gtf.xml -e ../common/tests.ecf -f NTSC -d 6", "res_$tn.txt");

$tn = "test11b";
$testr += &do_simple_test($tn, "(ECF + ChangeType + Crop [REF])", "$validator -g ../common/test1-gtf.xml ../common/test2-gtf.xml -e ../common/tests.ecf -f NTSC -d 6 -C word -w -p -c 20:1080", "res_$tn.txt");

##
$tn = "test12a";
$testr += &do_simple_test($tn, "(addXtraAttribute)", "$validator ../common/test1-1md-sys.xml -a addedattr:testvalue -a another_addedattr:value11 -w -p", "res_$tn.txt");

$tn = "test12b";
$testr += &do_simple_test($tn, "(addXtraAttribute + crop)", "$validator ../common/test1-1md-sys.xml -a attr_name:person_11 -c 1450:1750 -f PAL -w -p", "res_$tn.txt");

$tn = "test12c";
$testr += &do_simple_test($tn, "(addXtraAttribute + AddXtraTrackingComment + crop)", "$validator ../common/test1-1md-sys.xml -a attr_name:person_11 -c 1450:1750 -f PAL -w -p -A", "res_$tn.txt");

##
$tn = "test13a";
$testr += &do_simple_test($tn, "(Remove TrackingComment)", "$validator ../common/test6-Xtra-sys.xml -w -p -R TrackingComment", "res_$tn.txt");

$tn = "test13b";
$testr += &do_simple_test($tn, "(Remove XtraAttributes)", "$validator ../common/test6-Xtra-sys.xml -w -p -R XtraAttributes", "res_$tn.txt");

$tn = "test13c";
$testr += &do_simple_test($tn, "(Remove AllEvents)", "$validator ../common/test6-Xtra-sys.xml -w -p -R AllEvents", "res_$tn.txt");

##
$tn = "test14a";
$testr += &do_simple_test($tn, "(DumpCSV)", "$validator ../common/test6-Xtra-sys.xml -w -p -f NTSC -D EventType,Filename,XMLFile,EventSubType,ID,isGTF,DetectionScore,DetectionDecision,Framespan,FileFramespan,Xtra,Comment,BoundingBox,Point,OtherFileInformation,Duration,Beginning,End,MiddlePoint", "res_$tn.txt");

$tn = "test14b";
$testr += &do_simple_test($tn, "(insertCSV)", "$validator ../common/test7-empty_gtf.xml -w -p -f NTSC -i ../common/test7-population.csv", "res_$tn.txt");

##########

if ($testr == $totest) {
  ok_quit("All tests ok\n\n");
} else {
  error_quit("Not all test ok\n\n");
}

die("You should never see this :)");

##########

sub do_simple_test {
  my ($testname, $subtype, $command, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", 0);

  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev));
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
