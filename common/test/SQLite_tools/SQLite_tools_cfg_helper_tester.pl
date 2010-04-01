#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use F4DE_TestCore;
use MMisc;

my $tool = shift @ARGV;
MMisc::error_quit("ERROR: Tool ($tool) empty or not an executable\n")
  if ((MMisc::is_blank($tool)) || (! MMisc::is_file_x($tool)));
my $mode = shift @ARGV;

print "** Running SQLite_tools tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = "";

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "cfg_helper1a";
$testr += &do_simple_test($tn, "(ref)", "$tool ../common/ref.csv", "res-$tn.txt");

##
$tn = "cfg_helper1b";
$testr += &do_simple_test($tn, "(sys)", "$tool ../common/sys.csv", "res-$tn.txt");

##
$tn = "cfg_helper1c";
$testr += &do_simple_test($tn, "(md)", "$tool ../common/md.csv", "res-$tn.txt");

##
$tn = "cfg_helper1d";
$testr += &do_simple_test($tn, "(all)", "$tool ../common/ref.csv ../common/sys.csv ../common/md.csv", "res-$tn.txt");

##
$tn = "cfg_helper1e";
$testr += &do_simple_test($tn, "(duplicate table renaming)", "$tool ../common/md.csv ../common/md.csv", "res-$tn.txt");

##
$tn = "cfg_helper2a";
$testr += &do_simple_test($tn, "(columninfo)", "$tool ../common/ref.csv ../common/sys.csv ../common/md.csv -c", "res-$tn.txt");

##
$tn = "cfg_helper2b";
$testr += &do_simple_test($tn, "(tableinfo)", "$tool ../common/ref.csv ../common/sys.csv ../common/md.csv -t", "res-$tn.txt");

##
$tn = "cfg_helper3";
$testr += &do_simple_test($tn, "(Tablename)", "$tool -T SystemOut ../common/sys.csv", "res-$tn.txt");

##
$tn = "cfg_helper4";
$testr += &do_simple_test($tn, "(primarykey)", "$tool -p TrialID ../common/ref.csv ../common/sys.csv ../common/md.csv", "res-$tn.txt");

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
