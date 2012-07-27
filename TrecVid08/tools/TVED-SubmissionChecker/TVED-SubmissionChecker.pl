#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid Event Detection Submission Checker
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid Event Detection Submission Checker" is an experimental system.
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
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid Event Detection Submission Checker Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../lib", "$f4d/../../../common/lib");
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
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "TrecVid08ViperFile", "TrecVid08HelperFunctions", "TrecVid08ECF", "TrecVid08EventList", "CSVHelper") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

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
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
my @ok_events = $dummy->get_full_events_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

# Get some values from TrecVid08ECF
my $ecfobj = new TrecVid08ECF();
my @ecf_xsdfilesl = $ecfobj->get_required_xsd_files_list();

########################################
# Options processing

my @expected_ext = MMisc::get_unarchived_ext_list();
my $epmdfile = "Events_Processed.md";

my $md_add = TrecVid08HelperFunctions::get_MemDump_Suffix();

my $BigXMLtool = (exists $ENV{$f4b})
  ? $ENV{$f4b} . "/bin/TV08_BigXML_ValidatorHelper"
  : dirname(abs_path($0)) . "/../TV08ViperValidator/TV08_BigXML_ValidatorHelper.pl";

my $xmllint_env = "F4DE_XMLLINT";
my $mancmd = "perldoc -F $0";
my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : (dirname(abs_path($0)) . "/../../data");
my $fps = undef;
my $ecffile = "";
my $verb = 0;
my $rtmpdir = undef;
my $wid = undef;
my $skipval = 0;
my $memdump = undef;
my $dryrun = 0;
my $gdoepmd = 0;
my $qins = 0;
my $cont_md = 0;
my $use_bigxml = 0;
my $specfile = "";
my $pc_check = 0;
my %pc_check_h = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:  BC               ST VW    bcdef h        q s uvwx   #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'fps=s'           => \$fps,
   'ecf=s'           => \$ecffile,
   'Verbose'         => \$verb,
   'uncompress_dir=s' => \$rtmpdir,
   'work_in_dir=s'   => \$wid,
   'skip_validation' => \$skipval,
   'WriteMemDump=s'  => \$memdump,
   'dryrun_mode'     => \$dryrun,
   'create_Events_Processed_file' => \$gdoepmd,
   'quit_if_non_scorable' => \$qins,
   'Continue_MemDump' => \$cont_md,
   'bigXML'           => \$use_bigxml,
   'BigXML=s'         => \$BigXMLtool,
   'Specfile=s'       => \$specfile,
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

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

if (defined $rtmpdir) {
  my $de = MMisc::check_dir_w($rtmpdir);
  MMisc::error_quit("Problem with \'uncompress_dir\' ($rtmpdir): $de")
    if (! MMisc::is_blank($de));
  MMisc::error_quit("\'uncompress_dir\' can not be used at the same time as \'work_in_dir\'")
    if (defined $wid);
}

if (defined $wid) {
  MMisc::error_quit("\'work_in_dir\' argument is \'dir\'")
    if (MMisc::is_blank($wid));
 MMisc::error_quit("When using \'work_in_dir\', only one information (<SITE>) should be left on the command line")
   if (scalar @ARGV > 1);
}

MMisc::error_quit("Can only use \'create_Events_Processed_file\' when \'WriteMemDump\' is used too")
  if (($gdoepmd) && (! defined $memdump));

if (defined $memdump) {
  my $derr = MMisc::check_dir_w($memdump);
  MMisc::error_quit("Problem with \'WriteMemDump\' 's directory ($memdump) : $derr")
    if (! MMisc::is_blank($derr));
} else {
  MMisc::error_quit("\'Continue_MemDump\' can only be used if \'WriteMemDump\' is selected")
    if ($cont_md);
  MMisc::error_quit("\'bigXML\' can only be used if \'WriteMemDump\' is selected")
    if ($use_bigxml);
}

########################################

# Expected values
my @expected_year;
my @expected_task;
my @expected_data;
my @expected_lang;
my @expected_input;
my @expected_sysid_beg;
my @expected_dir_output;
my %expected_sffn;
my $check_minMax = 0;
my $default_fps = undef;
my @forceUseEcf_remove = ();
my $subname_params = 2;
my $subname_param1 = "";

my $tmpstr = MMisc::slurp_file($specfile);
MMisc::error_quit("Problem loading \'Specfile\' ($specfile)")
  if (! defined $tmpstr);
eval $tmpstr;
MMisc::error_quit("Problem during \'Specfile\' ($specfile) use : " . join(" | ", $@))
  if $@;

sub __cfgcheck {
  my ($t, $v, $c) = @_;
  return if ($c == 0);
  MMisc::error_quit("Missing or improper datum [$t] in \'SpecFile\' ($specfile)")
    if ($v);
}

&__cfgcheck("\@expected_year", (scalar @expected_year == 0), 1);
&__cfgcheck("\@expected_task", (scalar @expected_task == 0), 1);
&__cfgcheck("\@expected_data", (scalar @expected_data == 0), 1);
&__cfgcheck("\@expected_lang", (scalar @expected_lang == 0), 1);
&__cfgcheck("\@expected_input", (scalar @expected_input == 0), 1);
&__cfgcheck("\@expected_sysid_beg", (scalar @expected_sysid_beg == 0), 1);
&__cfgcheck("\@expected_dir_output", (scalar @expected_dir_output == 0), 1);
my $forceUseEcf = (scalar @forceUseEcf_remove > 0) ? 1 : 0;
&__cfgcheck("\%expected_sffn", (scalar keys %expected_sffn == 0), ($forceUseEcf ? 0 : 1));

$fps = $default_fps
  if ((defined $default_fps) && (! defined $fps));

#####
## Post config check
MMisc::error_quit("An \'ECF\' file is required for this tool to work")
  if (($forceUseEcf) && MMisc::is_blank($ecffile));

my $useECF = (MMisc::is_blank($ecffile)) ? 0 : 1;
MMisc::error_quit("\'fps\' must set in order to use \'ecf\'")
    if (($useECF) && (! defined $fps));

if ($skipval) {
  MMisc::error_quit("Can not use \'WriteMemDump\' or \'bigXML\' when \'skip_validation\' is selected")
    if ((defined $memdump) || ($use_bigxml) );
  MMisc::error_quit("Can not use \'ecf\' when \'skip_validation\' is selected")
    if ((! $forceUseEcf) && (! MMisc::is_blank($ecffile)));
}

## Loading of the ECF file
if ($useECF) {
  print "\n* Loading the ECF file\n\n";
  my ($errmsg) = TrecVid08HelperFunctions::load_ECF($ecffile, $ecfobj, $xmllint, $xsdpath, $fps);
  MMisc::error_quit("Problem loading the ECF file: $errmsg")
    if (! MMisc::is_blank($errmsg));
}

#####
## Fill 'expected_sffn' from ECFs
if ($forceUseEcf) {
  my @fl = $ecfobj->get_files_list();
  my %expt = ();
  foreach my $file (@fl) {
    my $out = $file;
    foreach my $rem (@forceUseEcf_remove) {
      $out =~ s%$rem%%;
    }
    $expt{$out} = $file;
  }
  foreach my $k (@expected_data) {
    $expected_sffn{$k} = \%expt;
  }
}

##########

my $doepmd = 0;

my @needed_csv_keys = ("EventType", "DetectionDecision", "DetectionScore", "Framespan"); # order is important
my %expEv_maxFalse = ();
my %expEv_minTrue  = ();

my $todo = scalar @ARGV;
my $done = 0;
my %warnings = ();
my %notes = ();
my $wn_key = "";
my $admd = 0; # Already Dumper MemDump ?
foreach my $sf (@ARGV) {
  %warnings = ();
  %notes = ();

  print "\n---------- [$sf]\n";

  my $ok = 1;
  my $tmpdir = "";
  my $site = "";
  my $err = "";
  my $p1task = "";
  my $p1data = "";
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
    
    vprint(1, "Get the SITE and SUB-NUM information");
    ($err, $site, $subnum, $p1task, $p1data) = &check_archive_name($file);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
    
    vprint(1, "Uncompressing archive");
    ($err, $tmpdir) = &uncompress_archive($dir, $file, $ext, $rtmpdir);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
  } else {
    my @split = split(m%\_%, $sf);
    if ($subname_params == 5) {
      MMisc::error_quit("We should have had 3x parameters: <SITE>_<TASK>_<DATA> ($sf)")
        if (scalar @split != 3);
      ($site, $p1task, $p1data) = @split;
    } else {
      MMisc::error_quit("We should have had only 1 parameter: <SITE> ($sf)")
        if (scalar @split != 1);
      ($site) = @split;
    }
    $tmpdir = $wid;
    my $de = MMisc::check_dir_r($tmpdir);
    MMisc::error_quit("Problem with \'work_in_dir\' directory ($tmpdir): $de")
      if (! MMisc::is_blank($de));
    vprint(1, "\'work_in_dir\' path");
  }

  if ($subname_params == 5) {
    vprint(2, "<SITE> = $site | <DATA> = $p1data | <TASK> = $p1task | <SUB-NUM> = $subnum");
  } else {
    vprint(2, "<SITE> = $site | <SUB-NUM> = $subnum");
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
    foreach my $sdir (sort @$rd) {
      vprint(2, "Checking Submission Directory ($sdir)");
      $wn_key = $sdir;
      my @errs = &check_submission_dir("$tmpdir/$odir", $sdir, $site, $p1data, $p1task);
      if (scalar @errs > 0) {
        my $err = &format_list("While checking submission dir [$sdir]", "  ", @errs);
        &valerr($sf, $err);
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
push @lin, "the \'skip_validation\' option was used, therefore the XML files were not checked for accuracy. Submitted archive files must have been XML validated to be accepted."
  if ($skipval);
push @lin, "the \'ecf\' option was not used, therefore your XML files were not matched against it. Submitted archive files must run this process to avoid missed elements in submission."
  if (! $useECF);
push @lin, "the \'dryrun_mode\' option was used, therefore the \'Events_Processed:\' was not looked for in your submission text file.  Submitted EVAL archive files must run this process to obtain the list of Events scored against."
  if ($dryrun);
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
  &valok($fname, "[ERROR] ** Please refer to the \'Submission Instructions\' (Appendix B) of the \'TRECVid Event Detection Evaluation Plan\' for more information");

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
  
  return(&check_archive_name5($file))
    if ($subname_params == 5);

  my $et = "Archive name not of the form \'<SITE>_<SUB-NUM>\'";

  my ($lsite, $lsubnum, @left) = split(m%\_%, $file);

  return($et . " (leftover entries: " . join(" ", @left) . ")")
    if (scalar @left > 0);
  
  return($et . " (<SUB-NUM> ($lsubnum) not of the expected form: integer value starting at 1)")
    if ( ($lsubnum !~ m%^\d+$%) || ($lsubnum =~ m%^0%) );

  return("", $lsite, $lsubnum);
}

###

sub check_archive_name5 {
  my $file = MMisc::iuv(shift @_, "");
  
  my $et = "Archive name not of the form \'" . $subname_param1 . "_<SITE>_<TASK>_<DATA>_<SUB-NUM>\'";
  my ($sn1, $lsite, $ltask, $ldata, $lsubnum, @left) = split(m%\_%, $file);
  
  return($et . " (leftover entries: " . join(" ", @left) . ")")
    if (scalar @left > 0);

  my $lerr = "";
  $lerr .= &cmp_exp("First parameter", $sn1, $subname_param1);
  $lerr .= &cmp_exp("<TASK>", $ltask, @expected_task);
  $lerr .= &cmp_exp("<DATA>", $ldata, @expected_data);
  $lerr .= ( ($lsubnum !~ m%^\d+$%) || ($lsubnum =~ m%^0%) ) 
    ? " (<SUB-NUM> ($lsubnum) not of the expected form: integer value starting at 1)" : "";

  return("$et $lerr")
    if (! MMisc::is_blank($lerr));

  return("", $lsite, $lsubnum, $ltask, $ldata);
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
  my ($bd, $dir, $site, $p1data, $p1task) = @_;

  vprint(3, "Checking name");
  my ($lerr, my $data) = &check_name($dir, $site, $p1data, $p1task);
  return($lerr) if (! MMisc::is_blank($lerr));

  vprint(3, "Checking expected directory files");
  (my $rep, my @errs) = &check_exp_dirfiles($bd, $dir, $data);
  return(@errs) if (scalar @errs > 0);
  push @{$notes{$wn_key}}, "Expected_Events: " . join(" ", @$rep)
    if (scalar @$rep > 0);

  return(@errs);
}

##########

sub check_name {
  my ($name, $site, $p1data, $p1task) = @_;

  my $et = "\'EXP-ID\' not of the form \'<SITE>_<YEAR>_<TASK>_<DATA>_<LANG>_<INPUT>_<SYSID>_<VERSION>\' : ";
  
  my ($lsite, $lyear, $ltask, $ldata, $llang, $linput, $lsysid, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters ($name). ", "")
    if (MMisc::any_blank($lsite, $lyear, $ltask, $ldata, $llang, $linput, $lsysid, $lversion));
  
  my $err = "";
  
  $err .= " <SITE> ($lsite) is different from submission file <SITE> ($site)."
    if ($site ne $lsite);
  
  $err .= " <TASK> ($ltask) is different from submission file <TASK> ($p1task)."
    if ((! MMisc::is_blank($p1task)) && ($ltask ne $p1task));

  $err .= " <DATA> ($ldata) is different from submission file <DATA> ($p1data)."
    if ((! MMisc::is_blank($p1data)) && ($ldata ne $p1data));

  $err .= &cmp_exp("<YEAR>", $lyear, @expected_year);
  $err .= &cmp_exp("<TASK>", $ltask, @expected_task);
  $err .= &cmp_exp("<DATA>", $ldata, @expected_data);
  $err .= &cmp_exp("<LANG>", $llang, @expected_lang);
  $err .= &cmp_exp("<INPUT>", $linput, @expected_input);
  
  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expected_sysid_beg) . "). "
    if (! grep(m%^$b$%, @expected_sysid_beg));
  
  if ($b eq $expected_sysid_beg[0]) {
    $err .= "<SYSID> ($lsysid) can only have one primary \'EXP-ID\'"
      if (($pc_check) && (exists $pc_check_h{$site}));
    $pc_check_h{$site}++;
  }

  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) || ($lversion > 19) );
  # More than 19 submissions would make anybody suspicious ;)
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  vprint(4, "<SITE> = $lsite | <YEAR> = $lyear | <TASK> = $ltask | <DATA> = $ldata | <LANG> = $llang | <INPUT> = $linput | <SYSID> = $lsysid | <VERSION> = $lversion");
  
  return("", $ldata);
}

##########

sub check_exp_dirfiles {
  my ($bd, $exp, $data) = @_;
  
  my @ep = ();
  
  my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files("$bd/$exp");
  return(\@ep, $derr)
    if (! MMisc::is_blank($derr));
  
  my @left = @$rd;
  push @left, @$ru;
  return(\@ep, "Found more than just files (" . join(" ", @left) . ")")
    if (scalar @left > 0);
  
  return(\@ep, "Found no files")
    if (scalar @$rf == 0);
  
  my %leftf = MMisc::array1d_to_count_hash($rf);
  vprint(4, "Checking for expected text file");
  my $expected_exp = "$exp.txt";
  my @txtf = grep(m%\.txt$%, @$rf);
  return(\@ep, "Found no \'.txt\' file")
    if (scalar @txtf == 0);
  return(\@ep, "Found more than the one expected \'.txt\' file :" . join(" ", @txtf) . ")")
    if (scalar @txtf > 1);
  return(\@ep, "Could not find the expected \'.txt\' file ($expected_exp) (seen: " . join(" ", @txtf) . ")")
    if (! grep(m%$expected_exp$%, @txtf));
  vprint(5, "Found: $expected_exp" . (($dryrun) ? " (dryrun_mode: skipping content check)" : "") );
  
  my @events_processed = ();
  if (! $dryrun) {
    ($derr, @events_processed) = &get_events_processed("$bd/$exp", $expected_exp);
    return(\@ep, $derr)
      if (! MMisc::is_blank($derr));
    return(\@ep, "No event found in \'Events_Processed:\' line ?")
      if (scalar @events_processed == 0);
  }
  delete $leftf{$expected_exp};
  
  vprint(4, "Checking for XML files");
  my @xmlf = grep(m%\.xml$%, @$rf);
  return(\@ep, "Found no \'.xml\' file. ")
    if (scalar @xmlf == 0);
  foreach my $xf (@xmlf) { delete $leftf{$xf}; }
  return(\@ep, "More than just \'.txt\' and \'.xml\' files in directory (" . join(" ", keys %leftf) . ")")
    if (scalar keys %leftf > 0);
  vprint(5, "Found: " . join(" ", @xmlf));
  
  # Try to validate the XML file
  my @errsl = ();
  my @sffnl = ();
  $doepmd = 1 if ($gdoepmd);
  if (! $skipval) {
    foreach my $xf (@xmlf) {
      vprint(4, "Trying to validate XML file ($xf)");
      my ($e, $sffn) = &validate_xml("$bd/$exp", $xf, $data, $exp, @events_processed);
      if (! MMisc::is_blank($e)) {
        vprint(5, "ERROR: $e");
        push @errsl, "$xf : $e";
        return(\@ep, @errsl)
          if ($qins);
      }
      push @sffnl, $sffn;
    }
  }
  return(\@ep, @errsl)
    if (scalar @errsl > 0);
  
  if ($useECF) {
    my ($err, $rmiss, $rnotin) = TrecVid08HelperFunctions::confirm_all_ECF_sffn_are_listed($ecfobj, @sffnl);
    return(\@ep, "Problem obtaining file list from ECF ($err)")
      if (! MMisc::is_blank($err));
    if (scalar @$rmiss > 0) {
      my $tmp_txt = "Will not be able to perform soring (comparing ECF to common list"
        . (($skipval && $forceUseEcf) ? " -- this is due to the use \'--skip_validation\', please rerun without this option before submitting)" : "")
        . "); the following referred to files are present in the ECF but where not found in the submission: " . join(" ", sort @$rmiss);
      push @{$warnings{$wn_key}}, $tmp_txt;
      MMisc::error_quit($tmp_txt)
        if ($qins);
    }
    push @{$warnings{$wn_key}}, "FYI: the following referred to files are not listed in the ECF, and therefore will not be scored against: " . join(" ", sort @$rnotin)
      if (scalar @$rnotin > 0);
  }
  
  return(\@events_processed, @errsl);
}

##########

sub get_events_processed {
  my $dir = shift @_;
  my $file = shift @_;
  
  my $fn = "$dir/$file";
  
  vprint(4, "Checking for \'Events_Processed:\' line in txt file");
  
  my @ep = ();
  
  my $err = MMisc::check_file_r($fn);
  return("Problem with file ($file): $err", @ep)
    if (! MMisc::is_blank($err));
  
  my $fc = MMisc::slurp_file($fn);
  return("Problem reading txt file ($file)", @ep)
    if (! defined $fc);

  if ($fc =~ m%^Events_Processed:(.+)$%m) {
    my $el = MMisc::clean_begend_spaces($1);
    $fc =~ s%^Events_Processed:(.+)$%%m;
    return("Multiple \'Events_Processed:\' lines found in txt file", @ep) 
      if ($fc =~ m%^Events_Processed:.*$%m);
    my @tep = split(m%\s+%, $el);
    $dummy->clear_error(); # if there was an error in a previous iteration
    @tep = $dummy->validate_events_list(@tep);
    return("Problem validating file's event list (" . $dummy->get_errormsg() . ")", @ep)
      if ($dummy->error());
    @ep = @tep;
  } else {
    return("Could not find the \'Events_Processed:\' line in file ($file)", @ep);
  }
  
  vprint(5, "Events Processed: " . join(" ", @ep));
  return("", @ep);
}

##########

sub validate_xml {
  my ($dir, $xf, $data, $exp, @events_processed) = @_;

  my $sffn = "";

  my ($derr, $tdir, $exp_key, $ext) = MMisc::split_dir_file_ext($xf);
  return("Problem splitting file and extension for ($xf)", $sffn)
    if (! MMisc::is_blank($derr));
  return("Expected filename extension is \".xml\", found \".$ext\"")
    if ($ext ne "xml");

  return("Could not find matching sourcefile filename for <DATA> ($data) and xml file ($xf)", $sffn)
    if (! exists $expected_sffn{$data}{$exp_key});
  
  my $exp_sffn = $expected_sffn{$data}{$exp_key};
 
  if ($cont_md) {
    my $md_file = "$memdump/$exp/$xf$md_add";
    if (-e $md_file) {
      vprint(5, "MemDump file already exists and \'Continue_MemDump\' requested, skipping");
      # Return the expected sffn (passed validation, so it is ok)
      return("", $exp_sffn)
    }
  }
 
  my $md_dd = "";
  if (defined $memdump) {
    $md_dd = "$memdump/$exp";
    
    return("In \'WriteMemDump\' problem creating output directory ($md_dd)", "")
      if (! MMisc::make_dir($md_dd));

    my $derr = MMisc::check_dir_w($md_dd);
    return("In \'WriteMemDump\', output directory ($md_dd) problem: $derr", "")
      if (! MMisc::is_blank($derr));

    $admd = 0;
  }

  my $tmp = "$dir/$xf";
  if ($use_bigxml) {
    vprint(5, "Using BigXML tool to generate MemDump version");
    return("No directory given for BigXML", "")
      if (MMisc::is_blank($md_dd));
    my $cmd = $BigXMLtool;
    $cmd .= " -f $fps -w $md_dd $dir/$xf";
    my $logfile = "$md_dd/$exp_key-BigXML.log";
    
    my ($rv, $tx, $so, $se, $retcode, $logfile)
      = MMisc::write_syscall_smart_logfile($logfile, $cmd);
    
    return("Problem during BigXML, see logfile ($logfile)", "")
      if ($retcode != 0);
    
    $tmp = MMisc::concat_dir_file_ext($md_dd, $xf, $md_add);

    $admd = 1;
  }
   
  vprint(5, "Loading ViperFile ($tmp)");
  my ($retstatus, $object, $msg) = 
    TrecVid08HelperFunctions::load_ViperFile
    (0, $tmp, $fps, $xmllint, $xsdpath);
  
  return($msg, "")
    if (! $retstatus);

  vprint(5, "Confirming sourcefile filename is proper");
  $sffn = $object->get_sourcefile_filename();
  return("Problem obtaining the sourcefile's filename (" . $object->get_errormsg() . ")", "")
    if ($object->error());
  
  return("Sourcefile's filename is wrong (is: $sffn) (expected: $exp_sffn)", $sffn)
    if ($sffn !~ m%$exp_sffn$%);
  
  my ($bettxt, $bte, $btot) = $object->get_txt_and_number_of_events(2);
  return("Problem obtaining the number of events (" . $object->get_errormsg() . ")", $sffn)
    if ($object->error());
  
  push @{$warnings{$wn_key}}, "$xf: Found no events in file. "
    if ($btot == 0);
  
  if (defined $memdump) {
    my $txt = &write_memdump_file($object, $exp, $xf, @events_processed);
    return("$xf: $txt", $sffn) if (! MMisc::is_blank($txt));
  }

  if ($check_minMax) {
    vprint(5, "Confirming: max 'false' DetectionScore > min 'true' DetectionScore (per Event, and per Event/EXPID)");
    my ($err, $csvtext) = TrecVid08HelperFunctions::ViperFile2CSVtxt($object, @needed_csv_keys);
    return("Problem extracting data : $err", $sffn)
      if (! MMisc::is_blank($err));

    my @lines = split(m%\n%, $csvtext);

    my $ch = new CSVHelper();
    return("Internal error -- Problem creating the CSV object :" . $ch->get_errormsg(), $sffn)
      if ($ch->error());

    my (%EvTmin, %EvFmax, %evn);
    for (my $i = 1; $i < scalar @lines; $i++) { # skip header
      my ($eid, $dec, $scr, @xrest) = $ch->csvline2array($lines[$i]);
      return("Internal error -- Problem extracting data from CSV : " . $ch->get_errormsg(), $sffn)
        if ($ch->error());
      return("Internal error -- Leftover data from CSV extraction", $sffn)
        if (scalar @xrest > 1);
#      print "[$i] $eid / $dec / $scr\n";
      $evn{$eid}++;
      $EvFmax{$eid} = $scr
        if (($dec == 0) && ((! exists $EvFmax{$eid}) || ($EvFmax{$eid} < $scr)));
      $EvTmin{$eid} = $scr
        if (($dec == 1) && ((! exists $EvTmin{$eid}) || ($EvTmin{$eid} > $scr)));
    }

    my $errtxt = "";
    foreach my $ev (keys %evn) {
      $errtxt .= sprintf("For \'$ev\' : max 'false' > min 'true' [current values: %.03f > %.03f]. ", $EvFmax{$ev}, $EvTmin{$ev})
        if ((exists $EvTmin{$ev}) && (exists $EvFmax{$ev}) && ($EvFmax{$ev} > $EvTmin{$ev}));
      if (exists $EvFmax{$ev}) {
        $expEv_maxFalse{$exp}{$ev} = $EvFmax{$ev}
        if (((! MMisc::safe_exists(\%expEv_maxFalse, $exp, $ev)) || ($expEv_maxFalse{$exp}{$ev} < $EvFmax{$ev})));
      }
      if (exists $EvTmin{$ev}) {
        $expEv_minTrue{$exp}{$ev} = $EvTmin{$ev}
        if (((! MMisc::safe_exists(\%expEv_minTrue, $exp, $ev)) || ($expEv_minTrue{$exp}{$ev} > $EvTmin{$ev})));
      }
      $errtxt .= sprintf("For EXPID ($exp) \'$ev\' : max 'false' > min 'true' [%.03f > %.03f].  ", 
                         $expEv_maxFalse{$exp}{$ev}, $expEv_minTrue{$exp}{$ev})
        if ((MMisc::safe_exists(\%expEv_minTrue, $exp, $ev)) && (MMisc::safe_exists(\%expEv_maxFalse, $exp, $ev)) 
            && ($expEv_maxFalse{$exp}{$ev} > $expEv_minTrue{$exp}{$ev}));
    }
    return($errtxt, $sffn)
      if (! MMisc::is_blank($errtxt));
  }

  return("", $sffn)
    if (! $useECF);
  
  vprint(5, "Applying ECF file ($ecffile) to ViperFile");
  my ($lerr, $nobject) =
    TrecVid08HelperFunctions::get_new_ViperFile_from_ViperFile_and_ECF($object, $ecfobj);
  return($lerr, $sffn)
    if (! MMisc::is_blank($lerr));
  return("Problem with ViperFile object", $sffn)
    if (! defined $nobject);
  
  my ($aettxt, $ate, $atot) = $nobject->get_txt_and_number_of_events(2);
  return("Problem obtaining the number of events (after ECF) (" . $nobject->get_errormsg() . ")", $sffn)
    if ($nobject->error());

  push @{$warnings{$wn_key}}, "$xf: Total number of events changed from before ($btot / Events: $bettxt) to after applying the ECF ($atot / Events: $aettxt). "
    if ($atot != $btot);

  if (scalar @events_processed > 0) {
    my @ue = $nobject->list_used_events();
    my ($ri, $ro) = MMisc::confirm_first_array_values(\@ue, \@events_processed);
    return("Some events found in file that were not in the \'Events_Processed:\' list: " . join(" ", @$ro) . ".", $sffn)
      if (scalar @$ro > 0);
  }

  return("", $sffn);
}

##########

sub write_memdump_file {
  return("") if (! defined $memdump);

  my ($vf, $diradd, $fname, @ep) = @_;

  my $dd = "$memdump/$diradd";

  return("In \'WriteMemDump\' problem creating output directory ($dd)")
    if (! MMisc::make_dir($dd));

  my $derr = MMisc::check_dir_w($dd);
  return("In \'WriteMemDump\', output directory problem: $derr")
    if (! MMisc::is_blank($derr));

  if ($doepmd) { # First, do the Processed Event list dump
    my $str = MMisc::get_sorted_MemDump(\@ep);
    my $fn = "$dd/$epmdfile";
    MMisc::error_quit("Could not write expected events files ($fn), aborting")
      if (! MMisc::writeTo($fn, "", 0, 0, $str));
    $doepmd = 0;
  }

  # Then worry about the regular memdump
  my $of = "$dd/$fname";
  if ($admd) {
    $of .= $md_add;
    my $err = MMisc::check_file_r($of);
    return("\'WriteMemDump\' file [$of] problem: $err")
      if (! MMisc::is_blank($err));
  } else {
    (my $ok, $of) = TrecVid08HelperFunctions::save_ViperFile_MemDump($of, $vf, "gzip", 0);
    return("In \'WriteMemDump\', a problem occurred while writing the output file ($of): $ok")
      if (! MMisc::is_blank($ok));
  }

  return("");
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

TVED-Submission Checker - TrecVid Event Detection Submission Checker

=head1 SYNOPSIS

B<TVED-SubmissionChecker> S<[B<--help> | B<--version> | B<--man>]>
  S<B<--Specfile> I<perlEvalfile>> 
  S<[B<--xmllint> I<location>] [B<--TrecVid08xsd> I<location>]>
  S<[B<--ecf> I<ecffile> B<--fps> I<fps>]>
  S<[B<--skip_validation>]>
  S<[B<--WriteMemDump> I<dir> [B<--create_Events_Processed_file>]>
  S<[B<--Continue_MemDump>]]>
  S<[B<--dryrun_mode>] [B<--Verbose>]>
  S<[B<--uncompress_dir> I<dir> | B<--work_in_dir> I<dir>]>
  S<[B<--quit_if_non_scorable>]>
  S<[B<--bigXML> [B<--BigXML> I<location>]]>
  S<last_parameter>

=head1 DESCRIPTION

B<TVED-SubmissionChecker> is a I<TrecVid Event Detection Sumbission Checker> program designed to confirm that a submission archive follows the guidelines posted in the I<Submission Instructions> of the I<TRECVid Event Detection Evaluation Plan>.
 
The software will confirm that an archive's files and directory structure conforms with the I<Submission Instructions>, and will validate the SYS XML files.

It is written to be functional with both TRECVid08 and TRECVid09 but using a B<Specfile> that contains needed definitions (distributed as part of the F4DE archive).

In the case of B<--work_in_dir>, S<last_parameter> is the E<lt>SITEE<gt>.
In all other cases, S<last_parameter> is the archive file to process in the E<lt>I<SITE>E<gt>_E<lt>I<SUB-NUM>E<gt>.I<extension> form (recognized extensions are available using the B<--help> option).

Supported archive formats list can be obtained using B<--help>.

=head1 PREREQUISITES

B<TVED-SubmissionChecker> ViPER files need to pass the B<TV08ViperValidator> validation process. The program relies on the following software and files.
 
=over

=item B<SOFTWARE>

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<F4DE_XMLLINT> environment variable to the full path location of the I<xmllint> executable.

The program relies on I<gnu tar> and I<unzip> to process the archive files.

=item B<FILES>

The syntactic validation requires some XML schema files (full list can be obtained using the B<--help> option).
It is possible to specify their location using the B<--xsdpath> option.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

Once you have installed the software, setting B<F4DE_BASE> to the installation location, and extending your B<PATH> to include B<$F4DE_BASE/bin> should be sufficient for the tools to find their components.

=back

=head1 GENERAL NOTES

B<TVED-SubmissionChecker> expects that the system and reference ViPER files can be been validated using 'xmllint' against the TrecVid08 XSD file(s) (see B<--help> for files list).

B<TVED-SubmissionChecker> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--BigXML> I<location>

Specify the I<location> of the S<TV08_BigXML_ValidatorHelper> tool.

=item B<--bigXML>

Use the S<TV08_BigXML_ValidatorHelper> tool to validate and perform a MemDump of the XML files contained within the submission.

=item B<--Continue_MemDump>

When re-running a previously started process (using B<--WriteMemDump>), skip previously created MemDump files.

=item B<--create_Events_Processed_file>

Will create an S<Events_Processed.md> I<MemDump> file in B<WriteMemDump>'s I<dir>.

=item B<--dryrun_mode>

Perform all regular tasks related with checking a submission, except for checking the content of the txt file for the S<Events_Processed:> entry.

=item B<--ecf> I<ecffile>

Specify the I<ECF> to load. The ECF provides the duration of the test set for the error calculations and the list of sourcefile filename expected to be seen in the submission. 

=item B<--fps> I<fps>

Specify the default sample rate (in frames per second) of the ViPER files.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--quit_if_non_scorable>

If for any reason, any submission file or step is non scorable, quit when an error is encounted, instead of continuing the check process and adding information to a report printed when all submissions have been checked.

=item B<--man>

Display this man page.

=item B<--Specfile> I<perlEvalfile>

Specify the I<perlEvalfile> that contains definitions specific to the evaluation checked against.

=item B<--skip_validation>

Do not perform XML validation on the ViPER files within the archive.

=item B<--TrecVid08xsd> I<location>

Specify the default location of the required XSD files (use B<--help> to get the list of required files).

=item B<--uncompress_dir> I<dir>

Specify the location of the directory in which to uncompress the archive content (by default a temporary directory is created).

=item B<--Verbose>

Print a verbose log of every task being performed before performing it, and in some case, its results.

=item B<--version>

Display B<TVED-SubmissionChecker> version information.

=item B<--WriteMemDump> I<dir>

Write a memory dump of validated XML files into I<dir>.
Useful to avoid having to re-run the entire validation process on the XML file when using another one F4DE's program that accept such files.

=item B<--work_in_dir> I<dir>

Specify the location of the uncompressed files to check.
This step is designed to help confirm that a directory structure is proper before generating the archive.
When using this mode, the S<last_parameter> becomes E<lt>SITEE<gt>.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<F4DE_XMLLINT> environment variable.

=back

=head1 USAGE

=item B<TVED-SubmissionChecker --Specfile TV08ED-SubmissionChecker_conf.perl SITE_3.tgz>

Will perform a submission check on archive file I<SITE_3.tgz> in a temporarily created directory, following the evaluation configuration information specified in I<TV08ED-SubmissionChecker_conf.perl>.

=item B<TVED-SubmissionChecker --Specfile TV08ED-SubmissionChecker_conf.perl SITE_3.tgz --uncompress_dir testdir --skip_validation --dryrun>

Will perform a submission check on archive file I<SITE_3.tgz>, uncompressing its content in the I<testdir> directory. This will also not try to validate the XML files, it will simply confirm that the directory structure, and that all the files are present. It will not check the content of the E<lt>EXP-IDE<gt> txt file for the S<Events_Processed:> entry. 

=item B<TVED-SubmissionChecker --Specfile TV08ED-SubmissionChecker_conf.perl SITE --work_in_dir testdir -ecf ecfile.xml --fps 25>

Will check that the files and directories in I<testdir> are the expected ones. It will check the txt file for the S<Events_Processed:> entry. It will also confirm that the XML files validate against the XML strucutre. It will confirm that the content of the XML files be matched against the ECF file (using a frame per second rate of 25) to permit scoring (the scorer will refuse to process those XML files if one or more of the file listed in the ECF is missing).

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
  my $xsdfiles = join(" ", @xsdfilesl);
  my $ecf_xsdf = join(" ", @ecf_xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version | --man] --Specfile perlEvalfile [--xmllint location] [--TrecVid08xsd location] [--ecf ecffile --fps fps] [--skip_validation] [--WriteMemDump dir [--create_Events_Processed_file] [--Continue_MemDump]] [--dryrun_mode] [--Verbose] [--uncompress_dir dir | --work_in_dir dir] [--quit_if_non_scorable] [--bigXML [--BigXML location]] last_parameter

Will confirm that a submission file conforms to the 'Submission Instructions' (Appendix B) of the 'TRECVid Event Detection Evaluation Plan'. The program needs a 'Specfile' to load some of its eval specific definitions.

'last_parameter' is usually the archive file(s) to process (of the form <SITE>_<SUB-NUM>.extension, example: NIST_2.tgz)
Only in the '--work_in_dir' case does it become an expected value (<SITE> or <SITE>_<TASK>_<DATA>, depending on your evaluation, please refer to the eval plan for additional details).

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --Specfile      Specify the \'perlEvalfile\' that contains definitions specific to the evaluation run
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found
  --ecf           Specify the ECF file to load
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --skip_validation  Bypass the XML files validation process
  --WriteMemDump  Write a memory dump of each validated XML file into \'dir\'. Note that this option will recreate the <EXP-ID> directory.
  --create_Events_Processed_file   Will create an \'$epmdfile\' MemDump file in \'WriteMemDump\' \'s dir
  --Continue_MemDump    If a MemDump file already exist, skip re-creation of the same file
  --dryrun_mode   Do not check for content of txt file
  --Verbose       Explain step by step what is being checked
  --uncompress_dir  Specify the directory in which the archive file will be uncompressed
  --work_in_dir   Bypass all steps up to and including uncompression and work with files in the directory specified (useful to confirm a submission before generating its archive)
  --quit_if_non_scorable  If for any reason, any submission is non scorable, quit without continuing the check process, instead of adding information to a report printed at the end
  --bigXML        Use the \"TV08_BigXML_ValidatorHelper\" tool to perform validation of XML files
  --BigXML        Specify the location of the \"TV08_BigXML_ValidatorHelper\" tool (default: $BigXMLtool)

Note:
- Recognized archive extensions: $ok_exts
- This prerequisite that the XML files can be been validated using 'xmllint' against the 'TrecVid08.xsd' file
- 'TrecVid08xsd' files are: $xsdfiles (and if the 'ecf' option is used, also: $ecf_xsdf)
EOF
    ;

    return $tmp;
}
