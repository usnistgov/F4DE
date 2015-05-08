#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#

use strict;
use F4DE_TestCore;
use MMisc;

my ($tool, $mode, @rest) = @ARGV;
#$mode = "makecheckfiles";
MMisc::error_quit("ERROR: Tool ($tool) empty or not an executable\n")
  if ((MMisc::is_blank($tool)) || (! MMisc::is_file_x($tool)));
$tool .= " " . join(" ", @rest)
  if (scalar @rest > 0);
my $mmk = F4DE_TestCore::get_magicmode_comp_key();

print "** Running KWSEval tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = ""; # Test name

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$testr += &do_simple_test($tn, "(DataCalculation: Occurrence)", "$tool -e ../common/test2.ecf.xml -r ../common/test2.rttm -s ../common/test2.kwslist.xml -t ../common/test2.kwlist.xml -o -b -f -", "res_$tn.txt");

##
$tn = "test1withAP";
$testr += &do_simple_test($tn, "(DataCalculation: Occurrence)", "$tool -e ../common/test2.ecf.xml -r ../common/test2.rttm -s ../common/test2.kwslist.xml -t ../common/test2.kwlist.xml -o -b -f - -zG MAP -zG MAPpct -zG Optimum -zG Supremum", "res_$tn.txt");

##
$tn = "test2a";
$testr += &do_simple_test($tn, "(DataCalculation: Conditional Occurrence - Source Type)", "$tool -e ../common/test6.ecf.xml -r ../common/test6.rttm -s ../common/test6.kwslist.xml -t ../common/test6.kwlist.xml -Y BN+CTS:BNEWS,CTS -O -B -y TXT -f -", "res_$tn.txt");

##
$tn = "test2b";
$testr += &do_simple_test($tn, "(DataCalculation: Conditional Occurrence - Attribute Query)", "$tool -e ../common/test6.ecf.xml -r ../common/test6.rttm -s ../common/test6.kwslist.xml -t ../common/test6.kwlist.xml -q 'Characters:regex=^[35]\$' -O -B -y TXT -f -", "res_$tn.txt");

##
$tn = "test2c";
$testr += &do_simple_test($tn, "(DataCalculation: Conditional Occurrence - Attribute Query with regular expression filter)", "$tool -e ../common/test6.ecf.xml -r ../common/test6.rttm -s ../common/test6.kwslist.xml -t ../common/test6.kwlist.xml -q 'Characters:regex=^[35]\$' -O -B -y TXT -f -", "res_$tn.txt");

##
$tn = "test3";
$testr += &do_simple_test($tn, "(DataCalculation: Segment)", "$tool -e ../common/test2.ecf.xml -r ../common/test2.rttm -s ../common/test2.kwslist.xml -t ../common/test2.kwlist.xml -o -b -O -B -Y CTS:cts -Y BNEWS:bnews -Y CONFMTG:confmtg -Y ALL:cts,bnews,confmtg -g -f -", "res_$tn.txt");

##
$tn = "test4";
$testr += &do_simple_test($tn, "(DataCalculation: Occurrence)", "$tool -e ../common/test2.ecf.xml -r ../common/test2.rttm -s ../common/test2.kwslist.xml -t ../common/test2.kwlist.xml -o -b -O -B -Y CTS:cts -Y BNEWS:bnews -Y CONFMTG:confmtg -Y ALL:cts,bnews,confmtg -f -", "res_$tn.txt");

##
$tn = "test5a";
$testr += &do_simple_test($tn, "(Handling terms with no targs: Occurrence, with inc)", "$tool -e ../common/test7.ecf.xml -r ../common/test7.rttm -s ../common/test7.kwslist.xml -t ../common/test7.kwlist.xml -o -b -inc -f -", "res_$tn.txt");

##
$tn = "test5b";
$testr += &do_simple_test($tn, "(Handling terms with no targs: Occurrence)", "$tool -e ../common/test7.ecf.xml -r ../common/test7.rttm -s ../common/test7.kwslist.xml -t ../common/test7.kwlist.xml -o -b -f -", "res_$tn.txt");

##
$tn = "test5c";
$testr += &do_simple_test($tn, "(Handling terms with no targs: Segment, with -inc)", "$tool -g -e ../common/test7.ecf.xml -r ../common/test7.rttm -s ../common/test7.kwslist.xml -t ../common/test7.kwlist.xml -o -b -inc -f -", "res_$tn.txt");

##
$tn = "test5d";
$testr += &do_simple_test($tn, "(Handling terms with no targs: Segment)", "$tool -g -e ../common/test7.ecf.xml -r ../common/test7.rttm -s ../common/test7.kwslist.xml -t ../common/test7.kwlist.xml -o -b -f -", "res_$tn.txt");

##
$tn = "test6a";
$testr += &do_simple_test($tn, "(Handle terms outside of ECF Segments: Occurence)", "$tool -e ../common/test5.short.ecf.xml -r ../common/test5.rttm -s ../common/test5.kwslist.xml -t ../common/test5.kwlist.xml -o -b -f -", "res_$tn.txt");

##
$tn = "test6b";
$testr += &do_simple_test($tn, "(Handle terms outside of ECF Segments: Segment)", "$tool -g -e ../common/test5.short.ecf.xml -r ../common/test5.rttm -s ../common/test5.kwslist.xml -t ../common/test5.kwlist.xml -o -b -f -", "res_$tn.txt");

##
$tn = "test7a";
$testr += &do_simple_test($tn, "Cantonese, no special changes", "$tool -e ../common/test8.ecf.xml -r ../common/test8.cantonese.rttm -s ../common/test8.cantonese.kwslist.xml -t ../common/test8.cantonese.kwlist.xml -csv -o -b -f -", "res_$tn.txt");

##
$tn = "test7b";
$testr += &do_simple_test($tn, "Cantonese, Split all characters", "$tool -e ../common/test8.ecf.xml -r ../common/test8.cantonese.rttm -s ../common/test8.cantonese.kwslist.xml -t ../common/test8.cantonese.kwlist.xml -csv -o -b -f - -x charsplit", "res_$tn.txt");

##
$tn = "test7c";
$testr += &do_simple_test($tn, "Cantonese, Split all characters except ASCII", "$tool -e ../common/test8.ecf.xml -r ../common/test8.cantonese.rttm -s ../common/test8.cantonese.kwslist.xml -t ../common/test8.cantonese.kwlist.xml -csv -o -b -f - -x charsplit -x notASCII", "res_$tn.txt");

##
$tn = "test7d";
$testr += &do_simple_test($tn, "Cantonese, Split all characters, delete hyphens", "$tool -e ../common/test8.ecf.xml -r ../common/test8.cantonese.rttm -s ../common/test8.cantonese.kwslist.xml -t ../common/test8.cantonese.kwlist.xml -csv -o -b -f - -x charsplit -x deleteHyphens", "res_$tn.txt");

##
$tn = "test7e";
$testr += &do_simple_test($tn, "Cantonese, Split all characters except ASCII, delete hyphens", "$tool -e ../common/test8.ecf.xml -r ../common/test8.cantonese.rttm -s ../common/test8.cantonese.kwslist.xml -t ../common/test8.cantonese.kwlist.xml -csv -o -b -f - -x charsplit -x deleteHyphens -x notASCII", "res_$tn.txt");

##
$tn = "test8a";
$testr += &do_simple_test($tn, "Just system terms (Occurence)", "$tool -e ../common/test7.ecf.xml -r ../common/test7.rttm -s ../common/test7.missing_term.kwslist.xml -t ../common/test7.kwlist.xml -o -b -inc -f - -j", "res_$tn.txt");

##
$tn = "test8b";
$testr += &do_simple_test($tn, "Just system terms (Segment)", "$tool -e ../common/test7.ecf.xml -r ../common/test7.rttm -s ../common/test7.missing_term.kwslist.xml -t ../common/test7.kwlist.xml -o -b -inc -f - -j -g", "res_$tn.txt");
####

##
$tn = "test9";
$testr += &do_simple_test($tn, "Corner case checks (Segment)", "$tool -e ../common/test9.ecf.xml -r ../common/test9.rttm -s ../common/test9.kwslist.xml -t ../common/test9.kwlist.xml -o -b -g -f -", "res_$tn.txt");
####

my $elapsed = F4DE_TestCore::get_elapsedtime($t0);
my $add = "";
$add .= " [Elapsed: $elapsed seconds]" if (F4DE_TestCore::is_elapsedtime_on());

MMisc::ok_quit("All tests ok$add\n")
  if ($testr == $totest);

MMisc::error_quit("Not all test ok$add\n");

##########

sub do_simple_test {
  my ($testname, $subtype, $command, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", 0);
  
  $totest++;
  my $retval = F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev);

  return($retval);
}
