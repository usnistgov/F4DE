#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my $tool = shift @ARGV;
MMisc::error_quit("ERROR: Tool ($tool) empty or not an executable\n")
  if ((MMisc::is_blank($tool)) || (! MMisc::is_file_x($tool)));
my $mode = shift @ARGV;

print "** Running SQLite_tables_creator tests:\n";

my $mmk = F4DE_TestCore::get_magicmode_comp_key();

my $totest = 0;
my $testr = 0;
my $tn = "";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "tables_creator1a";
$testr += &do_simple_test($tn, "(no primary key -- ref)", "$tool - ../common/ref1.cfg", "res-$tn.txt");

##
$tn = "tables_creator1b";
$testr += &do_simple_test($tn, "(no primary key -- sys)", "$tool - ../common/sys1.cfg", "res-$tn.txt");

##
$tn = "tables_creator1c";
$testr += &do_simple_test($tn, "(no primary key -- md)", "$tool - ../common/md1.cfg", "res-$tn.txt");

##
$tn = "tables_creator2a";
$testr += &do_simple_test($tn, "(primary key -- ref)", "$tool - ../common/ref2.cfg", "res-$tn.txt");

##
$tn = "tables_creator2b";
$testr += &do_simple_test($tn, "(primary key -- sys)", "$tool - ../common/sys2.cfg", "res-$tn.txt");

##
$tn = "tables_creator2c";
$testr += &do_simple_test($tn, "(primary key -- md)", "$tool - ../common/md2.cfg", "res-$tn.txt");

##
$tn = "tables_creator3a";
$testr += &do_simple_test($tn, "(primary key with multiple tables)", "$tool - ../common/mix2.cfg", "res-$tn.txt");

##
$tn = "tables_creator3b";
$testr += &do_less_simple_test($tn, "(prev + DB creation)", "../common/mix2.cfg", "res-$tn.txt");

##
$tn = "tables_creator3c";
$testr += &do_less_simple_test($tn, "(prev + load CSVs)", "../common/mix2.cfg -l -L ../../../common/tools/SQLite_tools/SQLite_load_csv.pl", "res-$tn.txt");

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

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev));
}

#####

sub do_less_simple_test {
  my ($testname, $subtype, $cadd, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", 0);
  
  my $tdir = "/tmp/SQLite_tools_tester-Temp_$testname";
  `rm -rf $tdir` if (-e $tdir); # Erase the previous one if present
  MMisc::error_quit("Could not make temporary dir for testing ($tdir)")
    if (! MMisc::make_dir($tdir));
  my $db = "$tdir/database.sql";
  
  my $command = "$tool $db $cadd";

  my $retval1 = &do_simple_test($testname, $subtype, $command, $res, $rev);

  my $retval2 = &do_simple_test($testname, "(DB check)", "sqlite3 $db < add_checker_sql.cmd", $res . "-DBcheck", $rev);

  if ($mode eq $mmk) {
    print "  (keeping: $tdir)\n";
  } else {
    `rm -rf $tdir`;
  }

 return($retval1 + $retval2);
}
