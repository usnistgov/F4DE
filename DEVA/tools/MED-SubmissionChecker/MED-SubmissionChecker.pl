#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# TrecVid Multimedia Event Detection Submission Checker
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid Multimedia Event Detection Submission Checker" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "MtSQLite") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "TrecVid Event Detection Submission Checker ($versionkey)";

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));


########################################
# Options processing

my @expected_ext = MMisc::get_unarchived_ext_list();

my @data_search_path = ('.', "$f4d/../../data");

my ($err, $sqlitecmd) = MtSQLite::get_sqlitecmd();
MMisc::error_quit($err)
  if (MMisc::is_blank($sqlitecmd));

my $DEVAtool = "$f4d/../DEVA_cli/DEVA_cli.pl";
my $err = MMisc::check_file_x($DEVAtool);
MMisc::error_quit("Problem with required tool ($DEVAtool) : $err")
  if (! MMisc::is_blank($err));

my $mancmd = "perldoc -F $0";
my $usage = &set_usage();
MMisc::error_quit("Usage:\n$usage\n") if (scalar @ARGV == 0);

# Default values for variables
my $verb = 0;
my $rtmpdir = undef;
my $wid = undef;
my $qins = 0;
my $specfile = "";
my $pc_check = 0;
my %pc_check_h = ();
my $outdir = undef;
my $trialindex = undef;
my $audtid = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: A                 ST V           h    m   q s uvw    #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'Verbose'        => \$verb,
   'uncompress_dir=s' => \$rtmpdir,
   'work_in_dir=s'  => \$wid,
   'quit_if_non_scorable' => \$qins,
   'Specfile=s'     => \$specfile,
   'outdir=s'       => \$outdir,
   'TrialIndex=s'   => \$trialindex,
   'AllowUnknowDetectionTrialID' => \$audtid,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::error_quit("No arguments left on command line\n\n$usage\n")
  if (scalar @ARGV == 0);

MMisc::error_quit("No \'Specfile\' given, will not continue processing\n\n$usage\n")
  if (MMisc::is_blank($specfile));
my $err = MMisc::check_file_r($specfile);
MMisc::error_quit("Problem with \'Specfile\' ($specfile) : $err")
  if (! MMisc::is_blank($err));

MMisc::error_quit("Mandatory \'TrialIndex\' CSV was not specified, aborting")
  if (! defined $trialindex);
my $err = MMisc::check_file_r($trialindex);
MMisc::error_quit("Problem with \'TrialIndex\' CSV file ($trialindex) : $err")
  if (! MMisc::is_blank($err));

if (defined $rtmpdir) {
  my $de = MMisc::check_dir_w($rtmpdir);
  MMisc::error_quit("Problem with \'uncompress_dir\' ($rtmpdir): $de")
    if (! MMisc::is_blank($de));
  MMisc::error_quit("\'uncompress_dir\' can not be used at the same time as \'work_in_dir\'")
    if (defined $wid);
}

if (defined $outdir) {
  my $de = MMisc::check_dir_w($outdir);
  MMisc::error_quit("Problem with \'outdir\' ($outdir): $de")
    if (! MMisc::is_blank($de));
} else {
  $outdir = MMisc::get_tmpdir();
  MMisc::error_quit("Problem creating temporary directory for \'--outdir\'")
    if (! defined $outdir);
}

if (defined $wid) {
  MMisc::error_quit("\'work_in_dir\' argument is \'dir\'")
    if (MMisc::is_blank($wid));
 MMisc::error_quit("When using \'work_in_dir\', only one information (<TEAM>) should be left on the command line")
   if (scalar @ARGV > 1);
}

########################################

# Expected values
my $expid_count = 7;
my @expid_tag;
my @expid_data;
my @expid_task;
my @expid_MEDtype;
my @expid_traintype;
my @expid_hardwaretype;
my @expid_EAG;
my @expid_sysid_beg;
my @expid_sys;


my @expected_dir_output;
my $expected_csv_per_expid = -1;
my @expected_csv_names;
my $db_check_sql = undef;
my $medtype_fullcount = -1; # setting to a value, this value will be used / 0: use the 'perTask' entry instead
my %medtype_fullcount_perTask;
my @db_eventidlist;
my @db_missingTID;
my @db_unknownTID;
my @db_detectionTID;
my @db_thresholdEID;
my $max_expid = 0;
my $max_expid_error = 1;
my @db_checkSEARCHMDTPT;

my @db_checkRanksdup = ();

my $mer_subcheck = "";
my %mer_ok_expid = ();

my $tmpstr = MMisc::slurp_file($specfile);
MMisc::error_quit("Problem loading \'Specfile\' ($specfile)")
  if (! defined $tmpstr);
eval $tmpstr;
MMisc::error_quit("Problem during \'SpecFile\' use ($specfile) : " . join(" | ", $@))
  if $@;

sub __cfgcheck {
  my ($t, $v, $c) = @_;
  return if ($c == 0);
  MMisc::error_quit("Missing or improper datum [$t] in \'SpecFile\' ($specfile)")
    if ($v);
}

# EXPID side
&__cfgcheck("\@expid_tag", (scalar @expid_tag == 0), 1);
my $medyear = $expid_tag[0];
&__cfgcheck("\@expid_data", (scalar @expid_data == 0), 1);
&__cfgcheck("\@expid_task", (scalar @expid_task == 0), (($expid_count == 9) || ($medyear eq 'MED13')));
&__cfgcheck("\@expid_MEDtype", (scalar @expid_MEDtype == 0), ($medyear ne 'MED13' && $medyear ne 'MED15'));
&__cfgcheck("\@expid_traintype", (scalar @expid_traintype == 0), (($expid_count == 9) || ($medyear eq 'MED13')));
&__cfgcheck("\@expid_EAG", (scalar @expid_EAG == 0), ($medyear ne 'MED13' && $medyear ne 'MED15'));
&__cfgcheck("\@expid_sysid_beg", (scalar @expid_sysid_beg == 0), ($medyear ne 'MED13' && $medyear ne 'MED15'));

&__cfgcheck("\@expected_dir_output", (scalar @expected_dir_output == 0), 1);
&__cfgcheck("\$expected_csv_per_expid", ($expected_csv_per_expid < 0), 1);
&__cfgcheck("\@expected_csv_names", (scalar @expected_csv_names == 0), 1);
&__cfgcheck("\$db_check_sql", (! defined $db_check_sql), 1);
&__cfgcheck("\$medtype_fullcount", ($medtype_fullcount < 0), 1);
&__cfgcheck("\%medtype_fullcount_perTask", (scalar(keys %medtype_fullcount_perTask) == 0), ($medtype_fullcount == 0));
&__cfgcheck("\@db_eventidlist", (scalar @db_eventidlist == 0), 1);
&__cfgcheck("\@db_missingTID", (scalar @db_missingTID == 0), 1);
&__cfgcheck("\@db_unknownTID", (scalar @db_unknownTID == 0), 1);
&__cfgcheck("\@db_detectionTID", (scalar @db_detectionTID == 0), 1);
&__cfgcheck("\@db_thresholdEID", (scalar @db_thresholdEID == 0), 1);
&__cfgcheck("\@db_checkSEARCHMDTPT", (scalar @db_checkSEARCHMDTPT == 0), ($medyear eq 'MED13'));

&extend_file_location(\$db_check_sql, 'SQL DB check file', @data_search_path);

my $xtratool = MMisc::get_file_actual_dir($0) . "/../../../common/tools/SQLite_tools/SQLite_dump_csv.pl";
if (! MMisc::is_blank($mer_subcheck)) {
    $err = MMisc::check_file_x($xtratool);
    MMisc::error_quit("Problem with extra tool needed for MER ($xtratool): $err")
        if (! MMisc::is_blank($err));
}

my $doepmd = 0;

my $todo = scalar @ARGV;
my $done = 0;
my %warnings = ();
my %notes = ();
my $wn_key = "";
foreach my $sf (@ARGV) {
  %warnings = ();
  %notes = ();

  print "\n---------- [$sf]\n";

  my $ok = 1;
  my $tmpdir = "";
  my $team = "";
  my $data = "";
  my $eset = "";
  my $err = "";
  my $subnum = "";

  if (! defined $wid) {
    vprint(1, "Checking \'$sf\'");
    
    my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($sf);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
    
    if (MMisc::is_blank($file)) {
      &valerr($sf, "No filename detected ?");
      next;
    }
    
    vprint(1, "Checking the file extension");
    $err = &check_archive_extension($ext);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }

    if ($medyear eq 'MED13' || $medyear eq 'MED15') {
      vprint(1, "Get the TEAM, SEARCH, EVENTSET and SUB-NUM information");
    } else {
      vprint(1, "Get the TEAM, DATA and SUB-NUM information");
    }
    ($err, $team, $data, $subnum, $eset) = &check_archive_name($file);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
    if ($medyear eq 'MED13' || $medyear eq 'MED15') {
      vprint(2, "<TEAM> = $team | <SEARCH> = $data | <EVENTSET> = $eset | <SUB-NUM> = $subnum");
    } else {
      vprint(2, "<TEAM> = $team | <DATA> = $data | <SUB-NUM> = $subnum");
    }

    vprint(1, "Uncompressing archive");
    ($err, $tmpdir) = &uncompress_archive($dir, $file, $ext, $rtmpdir);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
  } else {
    if ($medyear eq 'MED13' || $medyear eq 'MED15') {
      ($err, $team, $data, $subnum, $eset) = &check_archive_name($sf);
      if (! MMisc::is_blank($err)) {
        &valerr($sf, $err);
        next;
      }
    } else {
      $team = $sf;
    }
    $tmpdir = $wid;
    my $de = MMisc::check_dir_r($tmpdir);
    MMisc::error_quit("Problem with \'work_in_dir\' directory ($tmpdir): $de")
      if (! MMisc::is_blank($de));
    vprint(1, "\'work_in_dir\' selected");
    if ($medyear eq 'MED13' || $medyear eq 'MED15') {
      vprint(2, "<TEAM> = $team | <SEARCH> = $data | <EVENTSET> = $eset");
    } else {
      vprint(2, "<TEAM> = $team");
    }
  }
  vprint(2, "Temporary directory: $tmpdir");

  vprint(1, "Check for the output directories");
  $err = &check_for_output_dir($tmpdir);
  if (! MMisc::is_blank($err)) {
    &valerr($sf, $err);
    next;
  }

  vprint(1, "Process each output directory");
  foreach my $odir (@expected_dir_output) {
    my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files("$tmpdir/$odir");
    if (! MMisc::is_blank($derr)) {
      &valerr($sf, $derr);
      $ok = 0;
      next;
    }
    my @left = @$rf;
    push @left, @$ru;
    if (scalar @left > 0) {
      &valerr($sf, "Found more than just directories (" . join(" ", @left) . ")");
      $ok = 0;
      next;
    }
    if (scalar @$rd == 0) {
      &valerr($sf, "Found no submission directory");
      $ok = 0;
      next;
    }
    if (($max_expid) && (scalar @$rd > $max_expid)) {
        if ($max_expid_error) {
          &valerr($sf, "Found more than the $max_expid authorized directory/EXPID (found: " . scalar @$rd . ")");
          $ok = 0;
          next;
        }
        MMisc::warn_print("Found more than the $max_expid authorized directory/EXPID (found: " . scalar @$rd . "). Currently, only this warning is shown. In the future, an error message might appear in this case.");
    }
    foreach my $sdir (sort @$rd) {
      vprint(2, "Checking Submission Directory ($sdir)");
      $wn_key = $sdir;
      my ($err) = &check_submission_dir("$tmpdir/$odir", $sdir, $team, $data, $eset);
      if (! MMisc::is_blank($err)) {
        &valerr($sf, "While checking submission dir [$sdir] : " . $err);
        $ok = 0;
        next;
      }
    }
  }

  if ($ok) {
    &valok($sf, "ok" . &format_warnings_notes());
    $done ++;
  }
}

my @lin = ();
push @lin, "the \'work_in_dir\' option was used, please rerun the program against the final archive file to confirm it is a valid submission file." 
  if (defined $wid);

print "\n\n==========\nAll submission processed (OK: $done / Total: $todo)\n" 
  . ((scalar @lin == 0) ? "" : ($done ? "\nIMPORTANT NOTES:\n - " . join("\n - ", @lin) . "\n" : "")) . "\n";

MMisc::error_quit("Not all submission processed succesfully")
  if ($done != $todo);
MMisc::ok_quit();

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  &valok($fname, "[ERROR] $txt");
  &valok($fname, "[ERROR] ** Please refer to the \'Submission Instructions\', in the Appendices of the \'TRECVid Event Detection Evaluation Plan\' for more information");

  MMisc::error_quit("\'quit_if_non_scorable\' selected, quitting")
    if ($qins);
}

#####

sub format_list {
  my $txt = shift @_;
  my $skipbl = shift @_;
  my @list = @_;

  return("$txt None\n")
    if (scalar @list == 0);

  return("$txt " . $list[0] . "\n")
    if (scalar @list == 1);

  my $inc = 1;
  my $out = "$txt (" . scalar @list . ")\n";
  foreach my $entry (@list) {
    $out .= "$skipbl$inc) $entry\n";
    $inc++;
  }

  return($out);
}

#####

sub format_warnings_notes {
  my $txt = "";

  my @todo = keys %notes;
  push @todo, keys %warnings;
  @todo = MMisc::make_array_of_unique_values(\@todo);
  foreach my $key (@todo) {
    $txt .= "  -- $key\n";
    if (exists $warnings{$key}) {
      my @list = @{$warnings{$key}};
      $txt .= &format_list("    - WARNINGS:", "      ", @list);
    }
    if (exists $notes{$key}) {
      my @list = @{$notes{$key}};
      $txt .= &format_list("    - NOTES:", "      ", @list);
    }
  }

  $txt = "\n$txt"
    if (! MMisc::is_blank($txt));

  return($txt);
}

##########

sub check_archive_extension {
  my $ext = MMisc::iuv(shift @_, "");

  return(&cmp_exp("file extension", lc($ext), @expected_ext));
}

##########

sub check_archive_name {
  my $file = MMisc::iuv(shift @_, "");

  return(check_archive_name13p($file)) if ($medyear eq 'MED13' || $medyear eq 'MED15');

  my $et = "Archive name not of the form \'${medyear}_<TEAM>_<DATA>_<SUB-NUM>\' : ";

  my ($ltag, $lteam, $ldata, $lsubnum, @left) = split(m%\_%, $file);
  
  return($et . "leftover entries: " . join(" ", @left))
    if (scalar @left > 0);

  my $err = "";

  $err .= &cmp_exp($medyear, $ltag, @expid_tag);
  $err .= &cmp_exp("<DATA>",  $ldata, @expid_data);
  
  $err .= " (<SUB-NUM> ($lsubnum) not of the expected form: integer value starting at 1)"
    if ( ($lsubnum !~ m%^\d+$%) || ($lsubnum =~ m%^0%) );

  return($et . $err, "")
    if (! MMisc::is_blank($err));

  return("", $lteam, $ldata, $lsubnum);
}

##

sub check_archive_name13p {
  my $file = MMisc::iuv(shift @_, "");

  my $et = "Archive name not of the form \'${medyear}_<TEAM>_<SEARCH>_<EVENTSET>_<SUB-NUM>\' : ";

  my ($ltag, $lteam, $ldata, $leset, $lsubnum, @left) = split(m%\_%, $file);
  
  return($et . "leftover entries: " . join(" ", @left))
    if (scalar @left > 0);

  my $err = "";

  $err .= &cmp_exp($medyear, $ltag, @expid_tag);
  $err .= &cmp_exp("<SEARCH>",  $ldata, @expid_data);
  $err .= &cmp_exp("<EVENTSET>",  $leset, @expid_task);
  
  $err .= "<SUB-NUM> ($lsubnum) not of the expected form: integer value starting at 1. "
    if ( ($lsubnum !~ m%^\d+$%) || ($lsubnum =~ m%^0%) );

  return($et . $err, "")
    if (! MMisc::is_blank($err));

  return("", $lteam, $ldata, $lsubnum, $leset);
}

##########

sub uncompress_archive {
  my ($dir, $file, $ext, $rtmpdir) = MMisc::iuav(\@_, "", "", "", undef);

  my $tmpdir = "";
  if (! defined $rtmpdir) {
    $tmpdir = MMisc::get_tmpdir();
    return("Problem creating temporary directory", undef)
      if (! defined $tmpdir);
  } else {
    $tmpdir = $rtmpdir;
  }

  my $lf = MMisc::concat_dir_file_ext($dir, $file, $ext);

  my ($err, $retcode, $stdout, $stderr) = MMisc::unarchive_archive($lf, $tmpdir);

  return("Problem before uncompressing archive ($err)", undef)
    if (! MMisc::is_blank($err));

  return("Problem while uncompressing archive ($stderr)", undef)
    if (! MMisc::is_blank($stderr));

  return("", $tmpdir);
}

##########

sub check_for_output_dir {
  my $tmpdir = MMisc::iuv(shift @_, "");

  return("Empty directory ?")
    if (MMisc::is_blank($tmpdir));

  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($tmpdir);

  my @left = @$rf;
  push @left, @$ru;
  return("Found files where only directories expected (seen: " . join(" ", @left) .")")
    if (scalar @left > 0);
  
  my @d = @$rd;

  return("Found a different amount of directories in the base directory than expected (expected: " . join(" ", @expected_dir_output) . ") (seen: " . join(" ", @d) . ")")
  if (scalar @d != scalar @expected_dir_output);

  my ($ri, $ro) = MMisc::confirm_first_array_values(\@expected_dir_output, \@d);
  return("Not all expected directories (" . join(" ", @expected_dir_output) . ") found")
    if (scalar @$ri != scalar @expected_dir_output);

  return("");
}


##########

sub check_submission_dir {
  my ($bd, $dir, $team, $data, $eset) = @_;

  vprint(3, "Checking name");
  my ($lerr, $ldata, $medtype, $task, $sys, $traintype) = &check_name($dir, $team, $data, $eset);
  return($lerr) if (! MMisc::is_blank($lerr));

  vprint(3, "Checking expected directory files");
  return(&check_exp_dirfiles($bd, $dir, $data, $medtype, $task, $sys, $traintype));
}

##########

sub check_name {
  return(&check_name_med15p(@_))
    if ($medyear eq 'MED15');
  return(&check_name_med13p(@_))
    if ($medyear eq 'MED13'); # pre-empt the check for 7 elements here
  return(&check_name_med12p(@_))
    if ($medyear eq 'MED12');
  return(&check_name_med11(@_))
    if ($expid_count == 7);
  MMisc::error_quit("Unknown EXPID name handler for \'$medyear\'");
}

#####

sub check_name_med11 {
  my ($name, $team, $data) = @_;

  my $et = "\'EXP-ID\' not of the form \'<TEAM>_${medyear}_<DATA>_<MEDTYPE>_<EAG>_<SYSID>_<VERSION>\' : ";
  
  my ($lteam, $ltag, $ldata, $lmedtype, $leag, $lsysid, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters ($name). ", "")
    if (MMisc::any_blank($lteam, $ltag, $ldata, $lmedtype, $leag, $lsysid, $lversion));
  
  my $err = "";
  
  $err .= " <TEAM> ($lteam) is different from submission file <TEAM> ($team). "
    if ($team ne $lteam);

  $err .= " <DATA> ($ldata) is different from submission file <DATA> ($data). "
    if ((! MMisc::is_blank($data)) && ($data ne $ldata));
  
  $err .= &cmp_exp($medyear, $ltag, @expid_tag);
  $err .= &cmp_exp("<DATA>",  $ldata, @expid_data);
  $err .= &cmp_exp("<MEDTYPE>", $lmedtype, @expid_MEDtype);
  $err .= &cmp_exp("<EAG>", $leag, @expid_EAG);
  
  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expid_sysid_beg) . "). "
    if (! grep(m%^$b$%, @expid_sysid_beg));
  
  if ($b eq $expid_sysid_beg[0]) {
    if ($pc_check) {
      if (exists $pc_check_h{$team}) {
        $err .= "<SYSID> ($lsysid) can only have one primary \'EXP-ID\' (was: " . $pc_check_h{$team} . "). ";
      } else {
        $pc_check_h{$team} = $name;
      }
    }
  }

  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) || ($lversion > 19) );
  # More than 19 submissions would make anybody suspicious ;)
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  vprint(4, "<TEAM> = $lteam | <TAG> = $ltag | <DATA> = $ldata | <MEDTYPE> = $lmedtype | <EAG> = $leag | <SYSID> = $lsysid | <VERSION> = $lversion");
  
  return("", $ldata, $lmedtype);
}

#####

sub check_name_med12p {
  my ($name, $team, $data) = @_;

  my $et = "\'EXP-ID\' not of the form \'<TEAM>_${medyear}_<DATA>_<TASK>_<MEDTYPE>_<TRAINTYPE>_<EAG>_<SYSID>_<VERSION>\' : ";
  
  my ($lteam, $ltag, $ldata, $ltask, $lmedtype, $ltraintype, $leag, $lsysid, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters ($name). ", "")
    if (MMisc::any_blank($lteam, $ltag, $ldata, $lmedtype, $ltraintype, $leag, $lsysid, $lversion));
  
  my $err = "";
  
  $err .= " <TEAM> ($lteam) is different from submission file <TEAM> ($team)."
    if ($team ne $lteam);

  $err .= " <DATA> ($ldata) is different from submission file <DATA> ($data)."
    if ((! MMisc::is_blank($data)) && ($data ne $ldata));
  
  $err .= &cmp_exp($medyear, $ltag, @expid_tag);
  $err .= &cmp_exp("<DATA>",  $ldata, @expid_data);
  $err .= &cmp_exp("<TASK>",  $ltask, @expid_task);
  $err .= &cmp_exp("<MEDTYPE>", $lmedtype, @expid_MEDtype);
  $err .= &cmp_exp("<TRAINTYPE>",  $ltraintype, @expid_traintype);
  $err .= &cmp_exp("<EAG>", $leag, @expid_EAG);

  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expid_sysid_beg) . "). "
    if (! grep(m%^$b$%, @expid_sysid_beg));
  
  if ($b eq $expid_sysid_beg[0]) {
    $err . "primary submission must be <TRAINTYPE> = " . $expid_traintype[0] . " (is: $ltraintype)"
      if ($ltraintype ne $expid_traintype[0]);
    $err .= "<SYSID> ($lsysid) can only have one primary \'EXP-ID\'"
      if (($pc_check) && (exists $pc_check_h{$team}));
    $pc_check_h{$team}++;
  }

  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) || ($lversion > 19) );
  # More than 19 submissions would make anybody suspicious ;)
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  vprint(4, "<TEAM> = $lteam | <TAG> = $ltag | <DATA> = $ldata | <TASK> = $ltask | <MEDTYPE> = $lmedtype | <TRAINTYPE> = $ltraintype | <EAG> = $leag | <SYSID> = $lsysid | <VERSION> = $lversion");
  
  return("", $ldata, $lmedtype, $ltask);
}

#####

sub check_name_med13p {
  my ($name, $team, $data, $eset) = @_;

  my $et = "\'EXP-ID\' not of the form \'<TEAM>_${medyear}_<SYS>_<SEARCH>_<EVENTSET>_<EKTYPE>_<VERSION>\' : ";
  
  my ($lteam, $ltag, $lsys, $lsearch, $leset, $lektype, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters ($name). ", "")
    if (MMisc::any_blank($lteam, $ltag, $lsys, $lsearch, $leset, $lversion));
  
  my $err = "";
  
  $err .= " <TEAM> ($lteam) is different from submission file <TEAM> ($team)."
    if ($team ne $lteam);
  $err .= " <SEARCH> ($lsearch) is different from submission file <SEARCH> ($data)."
    if ($data ne $lsearch);
  $err .= " <EVENTSET> ($leset) is different from submission file <EVENTSET> ($eset)."
    if ($eset ne $leset);

  $err .= &cmp_exp($medyear, $ltag, @expid_tag);
  $err .= &cmp_exp("<SYS>",  $lsys, @expid_sys);
  $err .= &cmp_exp("<SEARCH>",  $lsearch, @expid_data);
  $err .= &cmp_exp("<EVENTSET>", $leset, @expid_task);
  $err .= &cmp_exp("<EKTYPE>", $lektype, @expid_traintype);

  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) );
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  vprint(4, "<TEAM> = $lteam | <TAG> = $ltag | <SYS> = $lsys | <SEARCH> = $lsearch | <EVENTSET> = $leset | <EKTYPE> = $lektype | <VERSION> = $lversion");
  
  return("", $lsearch, $lsearch, $leset, $lsys, $lektype);
}

#####

sub check_name_med15p {
  my ($name, $team, $data, $eset) = @_;

  my $et = "\'EXP-ID\' not of the form \'<TEAM>_${medyear}_<SEARCH>_<EVENTSET>_<EKTYPE>_<SMGHW>_<SYS>_<VERSION>\' : ";
  
  my ($lteam, $ltag, $lsearch, $leset, $lektype, $lsmghw, $lsys, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters ($name). ", "")
    if (MMisc::any_blank($lteam, $ltag, $lsearch, $leset, $lektype, $lsmghw, $lsys, $lversion));
  
  my $err = "";
  
  $err .= " <TEAM> ($lteam) is different from submission file <TEAM> ($team)."
    if ($team ne $lteam);
  $err .= " <SEARCH> ($lsearch) is different from submission file <SEARCH> ($data)."
    if ($data ne $lsearch);
  $err .= " <EVENTSET> ($leset) is different from submission file <EVENTSET> ($eset)."
    if ($eset ne $leset);

  $err .= &cmp_exp($medyear, $ltag, @expid_tag);
  $err .= &cmp_exp("<SEARCH>",  $lsearch, @expid_data);
  $err .= &cmp_exp("<EVENTSET>", $leset, @expid_task);
  $err .= &cmp_exp("<EKTYPE>", $lektype, @expid_traintype);
  $err .= &cmp_exp("<SMGHW>", $lsmghw, @expid_hardwaretype);

  $err .= "<SYS> ($lsys) not of the expected form: beginning with (p-, or c-), only alphanumeric characters. "
    if ($lsys !~ /^[pc]\-[a-zA-Z\d]+/);

  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) );
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  vprint(4, "<TEAM> = $lteam | <TAG> = $ltag | <SEARCH> = $lsearch | <EVENTSET> = $leset | <EKTYPE> = $lektype | <SMGHW> = $lsmghw | <SYS> = $lsys | <VERSION> = $lversion");
  
  return("", $lsearch, $lsearch, $leset, $lsys, $lektype);
}

##########

sub check_exp_dirfiles {
  my ($bd, $exp, $data, $medtype, $task, $sys, $traintype) = @_;

  my $expdir = "$bd/$exp";
  my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files($expdir);
  return($derr) if (! MMisc::is_blank($derr));

  my $merdir = "";
  my @left = @$rd;
  if (scalar @left == 1) {
      if ($left[0] eq 'MER') {
          return("Found a MER directory in EXPID ($exp) but MER's Submission Checker is not set") 
              if (MMisc::is_blank($mer_subcheck));

          return("Some of the data needed for checking that the MER data is authorized is missing (have: $sys / $data / $task / $traintype)")
              if (MMisc::any_blank($data, $sys, $task, $traintype));

          return("Found a MER directory, but the following case is not authorized: $sys / $data / $task / $traintype")
              if (! MMisc::safe_exists(\%mer_ok_expid, $data, $sys, $task, $traintype));

          $merdir = "$expdir/" . shift @left; # also remove problem from list for later check
          vprint(4, "Found a MER directory, will check it after the MED checks");
      }
  }
  push @left, @$ru;
  return("Found more than just files (" . join(" ", @left) . ")")
    if (scalar @left > 0);
  
  return("Found no files")
    if (scalar @$rf == 0);
  
  my %leftf = MMisc::array1d_to_count_hash($rf);
  vprint(4, "Checking for expected text file");
  my $expected_exp = "$exp.txt";
  my @txtf = grep(m%\.txt$%, @$rf);
  return("Found no \'.txt\' file")
    if (scalar @txtf == 0);
  return("Found more than the one expected \'.txt\' file :" . join(" ", @txtf) . ")")
    if (scalar @txtf > 1);
  return("Could not find the expected \'.txt\' file ($expected_exp) (seen: " . join(" ", @txtf) . ")")
    if (! grep(m%$expected_exp$%, @txtf));
  delete $leftf{$expected_exp};
  
  vprint(4, "Checking for CSV files");
  my @csvf = grep(m%\.csv$%, @$rf);
  return("Found no \'.csv\' file. ")
    if (scalar @csvf == 0);
  foreach my $xf (@csvf) { delete $leftf{$xf}; }
  return("More than just \'.txt\' and \'.csv\' files in directory (" . join(" ", keys %leftf) . ")")
    if (scalar keys %leftf > 0);
  vprint(5, "Found: " . join(" ", @csvf));
  
  return("Did not find the expected $expected_csv_per_expid CSV files, found " . scalar @csvf . " : " . join(" ", @csvf))
    if (scalar @csvf != $expected_csv_per_expid);

  my %match = ();
  foreach my $k (@expected_csv_names) {
    my $fn = "$exp.$k.csv";
    return("Could not find the expected \'$k\' CSV file ($fn)")
      if (! grep(m%^$fn$%, @csvf));
    $match{$k} = "$bd/$exp/$fn";
    vprint(5, "Matched \'$k\' CSV file: $fn");
  }
  
  return(&run_DEVAcli($exp, $data, $medtype, $task, \%match, $merdir));
}

#####

sub run_DEVAcli {
  my ($exp, $data, $medtype, $task, $rmatch, $merdir) = @_;

  vprint(4, "Creating the Database (ie validating System)");

  my $od = "$outdir/$exp";
  return("Problem creating output dir ($od)")
    if (! MMisc::make_wdir($od));
  vprint(5, "Output dir: $od");
    
  my @cmd_args = ();
  push @cmd_args, '-p', $medyear, '-o', "$od";
  foreach my $k (keys %$rmatch) {
    push @cmd_args, '-s', $$rmatch{$k} . ":$k";
  }
  push @cmd_args, "$trialindex:TrialIndex";
  push @cmd_args, '-f', '-D';

  my $lf = "$od/DEVAcli_run.log";
  vprint(5, "Running tool ($DEVAtool), log: $lf");
  my ($err) = &run_tool($lf, $DEVAtool, @cmd_args);

  return($err) if (! MMisc::is_blank($err));

  return(&check_TrialIDs($od, $exp, $data, $medtype, $task, $merdir));
}

#####

sub run_tool {
  my ($lf, $tool, @cmds) = @_;

  $lf = MMisc::get_tmpfile() if (MMisc::is_blank($lf));

  my ($ok, $otxt, $so, $se, $rc, $of, $sig) = 
    MMisc::write_syscall_smart_logfile($lf, $tool, @cmds); 
  if ((! $ok) || ($rc + $sig != 0)) {
    my $lfc = MMisc::slurp_file($of);
    return("There was a problem running the tool ($tool) command\n  Run log (located at: $of) content: $lfc\n\n");
  }

  return("", $ok, $otxt, $so, $se, $rc, $of);
}

#####

sub check_TrialIDs {
  my ($od, $expid, $data, $medtype, $task, $merdir) = @_;

  vprint(4, "Checking Database's EventID and TrialID");

  my $sysdb = "$od/systemDB.db";
  my $err = MMisc::check_file_r($sysdb);
  return("Problem with system DB ($sysdb) : $err")
    if (! MMisc::is_blank($err));
  my $mddb  = "$od/metadataDB.db";
  my $err = MMisc::check_file_r($mddb);
  return("Problem with metadata DB ($mddb) : $err")
    if (! MMisc::is_blank($err));

  my $dbf = "checkDB.db";
  my $dbfile = "$od/$dbf";

  my $cmd = "";
  $cmd .= "ATTACH DATABASE \"$mddb\" AS metadataDB;\n";
  $cmd .= "ATTACH DATABASE \"$sysdb\" AS systemDB;\n";

  $cmd .= MMisc::slurp_file($db_check_sql);

  my ($err, $log) = &__runDB_cmd($dbfile, $cmd);
  return("Problem while checking the System Database's EventID and TrialID : $err\n\nLog file ($log) text:\n" . MMisc::slurp_file($log))
    if (! MMisc::is_blank($err));
  vprint(5, "Generated \'$dbf\' [log: $log]");

  my @el = ();
  my ($err, $tidc) = MtSQLite::select_helper__to_array($dbfile, \@el, $db_eventidlist[0], "", $db_eventidlist[1]);
  return("Problem obtaining the EventID list : $err") if (! MMisc::is_blank($err));
  my @fel = (); for (my $i = 0; $i < scalar @el; $i++) { push @fel, @{$el[$i]}; }
  vprint(5, "Found $tidc EventID : " . join(" ", sort @fel));
  return("Found no recognized EventID") if ($tidc == 0);

  if ($medtype_fullcount != -1) {
    my $mtfc = $medtype_fullcount;
    if ($medtype_fullcount == 0) {
      return("We do not have a valid definition for the expected number of events for <DATA>=$data and <TASK>=$task. ")
        if (! MMisc::safe_exists(\%medtype_fullcount_perTask, $data, $task));
      $mtfc = $medtype_fullcount_perTask{$data}{$task};
      return("For <DATA>=$data there can NOT be a <TASK>=$task")
        if ($mtfc == -1);
    }
    if ((defined $medtype) && ($medtype eq $expid_MEDtype[0]) && ($tidc < $mtfc)) {
      my $txt = "EXPID ($expid) designs this submission as a \'$medtype\', but it contains $tidc EventIDs, when $mtfc are expected to consider it so";
      return($txt) if ($data ne $expid_data[0]);
      MMisc::warn_print("$txt. Since this is a $data submission, only this warning is shown. Otherwise, an error message would have been shown");
    }
  }

  if (scalar @db_missingTID > 0) {
    my $err = &id_check($dbfile, "Missing TrialID", $db_missingTID[0], $db_missingTID[1], 0);
    return($err) if (! MMisc::is_blank($err));
  }

  if (scalar @db_unknownTID > 0) {
    my $err = &id_check($dbfile, "Unknown TrialID", $db_unknownTID[0], $db_unknownTID[1], 0);
    return($err) if (! MMisc::is_blank($err));
  }

  if (($audtid == 0) && (scalar @db_detectionTID > 0)) {
    my $err = &id_check($dbfile, "Unknown \'detection\' TrialID", $db_detectionTID[0], $db_detectionTID[1], 0);
    return($err) if (! MMisc::is_blank($err));
  }

  if (scalar @db_thresholdEID > 0) {
    my $err = &id_check($dbfile, "Unknown \'threshold\' EventID", $db_thresholdEID[0], $db_thresholdEID[1], 0);
    return($err) if (! MMisc::is_blank($err));
  }

  if (scalar @db_checkSEARCHMDTPT > 0) {
    my $err = &id_check($dbfile, "unique \'SEARCHMDTPT\' value", $db_checkSEARCHMDTPT[0], $db_checkSEARCHMDTPT[1], 1);
    return($err) if (! MMisc::is_blank($err));
  }

  if (scalar @db_checkRanksdup > 0) {
      my @lid = ();
      my ($err, $tidc) = MtSQLite::select_helper__to_array($dbfile, \@lid, $db_checkRanksdup[0], "", '*');
      return("Problem obtaining the ". $db_checkRanksdup[0] . " table : $err") if (! MMisc::is_blank($err));
      vprint(5, "Found $tidc duplicate Rank for individual EventIDs");
      if ($tidc > 0) {
          my $rtxt = "$tidc duplicate Ranks found:\n";
          foreach my $rax (@lid) {
              my ($l_eid, $l_rnk, $l_cnt) = @{$rax};
              $rtxt .= "  EventID: $l_eid  / Rank: $l_rnk / Count: $l_cnt\n";
          }
          return($rtxt);
      }
  }

  if (! MMisc::is_blank($merdir)) {
      my $mof = "$od/MER_completeness.csv";
      my $mol = "$mof.log";
      vprint(5, "Generating MER Completeness file [log: $mol]");
      my @cmd_args = ($dbfile, 'yesTrialID', $mof, 'TrialID');
      ($err, my $ok) = &run_tool($mol, $xtratool, @cmd_args);
      return("While running MER completeness file generation: $err (log:$mol")
          if (! MMisc::is_blank($err));
      $mol = "$od/MER_subcheck.log";
      vprint(5, "Running MER submission checker [log: $mol]");
      my @cmd_args = ($merdir, $mof);
      ($err, $ok) = &run_tool($mol, $mer_subcheck, @cmd_args);
      return("While running MER submission checks: $err (log:$mol)")
          if (! MMisc::is_blank($err));
  }
     
  return("");
}

#####

sub id_check {
  my ($dbfile, $txt, $tn, $cn, $mt) = @_;

  my @lid = ();
  my ($err, $tidc) = MtSQLite::select_helper__to_array($dbfile, \@lid, $tn, "", $cn);
  return("Problem obtaining the $txt list : $err") if (! MMisc::is_blank($err));
  vprint(5, "Found $tidc $txt");
  return("$tidc $txt: " . ajoin(" ", @lid)) if ($tidc > $mt);

  return("");
}

#####

sub ajoin {
  my $sep = shift @_;

  my @txt = "";
  for (my $i = 0; $i < scalar @_; $i++) {
    push @txt, join($sep, @{$_[$i]});
  }
  return(join($sep, @txt));
}

#####

sub __runDB_cmd {
  my ($dbfile, $cmd) = @_;
  
## SQLite usage
  my ($err, $log, $stdout, $stderr) = 
    MtSQLite::sqliteCommands($sqlitecmd, $dbfile, $cmd);
  return($err, $log);
}

#####

sub extend_file_location {
  my ($rf, $t, @pt) = @_;

  return if (MMisc::is_blank($$rf));
  return if (MMisc::does_file_exist($$rf));

  foreach my $p (@pt) {
    my $v = "$p/$$rf";
    if (MMisc::does_file_exist($v)) {
#      &note_print("Using \'$t\' file: $v");
      $$rf = $v;
      return();
    }
  }

  MMisc::error_quit("Could not find \'$t\' file ($$rf) in any of the expected paths: " . join(" ", @pt));
}  

##########

sub cmp_exp {
  my ($t, $v, @e) = @_;

  return("$t ($v) does not compare to expected value (" . join(" ", @e) ."). ")
    if (! grep(m%^$v$%, @e));

  return("");
}

##########

sub vprint {
  return if (! $verb);

  my $s = "********************";


  print substr($s, 0, shift @_), " ", join("", @_), "\n";
}

############################################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################ Manual

=pod

=head1 NAME

MED-Submission Checker - TrecVid Multimedia Event Detection Submission Checker

=head1 SYNOPSIS


=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut

############################################################

sub set_usage {
  my $ok_exts = join(" ", @expected_ext);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version | --man] --Specfile perlEvalfile --TrialIndex index.csv [--Verbose] [--uncompress_dir dir | --work_in_dir dir] [--outdir dir] [--AllowUnknowDetectionTrialID] [--quit_if_non_scorable] last_parameter

Will confirm that a submission file conforms to the 'Submission Instructions', in the Appendices of the 'TRECVid Multimedia Event Detection Evaluation Plan'. The program needs a 'Specfile' to load some of its eval specific definitions.

'last_parameter' is usually the archive file(s) to process (see evaluation plan for details).
Only in the '--work_in_dir' case does it become <TEAM>, and from MED13 forward: the expected archive filename (without its extension).

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --Specfile      Specify the \'perlEvalfile\' that contains definitions specific to the evaluation run
  --TrialIndex    Specify the location of the \'TrialIndex.csv\' file used
  --Verbose       Explain step by step what is being checked
  --uncompress_dir  Specify the directory in which the archive file will be uncompressed
  --work_in_dir   Bypass all steps up to and including uncompression and work with files in the directory specified (useful to confirm a submission before generating its archive)
  --outdir        When validating DB content, output generated DB in this directory
  --AllowUnknowDetectionTrialID  This is only to be used in case the final Reference TrialIndex has less elements than the original given to participants, as it skip the verification for unknown TrialIDs present in submissions
  --quit_if_non_scorable  If for any reason, any submission is non scorable, quit without continuing the check process, instead of adding information to a report printed at the end

Note:
- Recognized archive extensions: $ok_exts

EOF
    ;

    return $tmp;
}
