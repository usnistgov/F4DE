#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# AVSS Submission Checker
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS Submission Checker" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
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

my $versionid = "AVSS Checker Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../lib", "../../../CLEAR07/lib", "../../../common/lib");
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
foreach my $pn ("MMisc", "AVSS09ViperFile", "AVSS09ECF", "AVSS09HelperFunctions") {
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
# Options processing

my @expected_ext = MMisc::get_unarchived_ext_list();
my $xml_md_add = AVSS09ViperFile::get_VFMemDump_filename();
my $ss_md_add = AVSS09ViperFile::get_SSMemDump_filename();

my $xmllint_env = "F4DE_XMLLINT";
my $mancmd = "perldoc -F $0";

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../../CLEAR07/data";
my $AVxsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../data";
my $verb = 0;
my $rtmpdir = undef;
my $wid = undef;
my $skipval = 0;
my $memdump = "/tmp";
my $ecfdir = "";
my $qoe = 0;
my $specfile = "";
my $valtool = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/bin/AVSS09ViPERValidator") : "../AVSS09ViPERValidator/AVSS09ViPERValidator.pl";
my $frameTol = 0;
my $logdir = ".";
my $usage = &set_usage();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: A C               S  VW     c efh    lm   q stuvwx   #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'AVSSxsd=s'       => \$AVxsdpath,
   'Verbose'         => \$verb,
   'uncompress_dir=s' => \$rtmpdir,
   'work_in_dir=s'   => \$wid,
   'skip_validation' => \$skipval,
   'WriteMemDump=s'  => \$memdump,
   'ecfdir=s'        => \$ecfdir,
   'quit_on_error'   => \$qoe,
   'Specfile=s'      => \$specfile,
   'tool=s'          => \$valtool,
   'frameTol=i'      => \$frameTol,
   'logdir=s'        => \$logdir,
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

MMisc::error_quit("No \'ecfdir\' given, will not continue processing\n\n$usage\n")
  if (MMisc::is_blank($ecfdir));

MMisc::error_quit("No \'tool\' given, will not continue processing\n\n$usage\n")
  if ((MMisc::is_blank($valtool)) && (! $skipval));

if (! $skipval) {
  my $err = MMisc::check_file_x($valtool);
  MMisc::error_quit("\'tool\' ($valtool) problem: $err")
    if (! MMisc::is_blank($err));
}

if (defined $rtmpdir) {
  my $de = MMisc::check_dir_w($rtmpdir);
  MMisc::error_quit("Problem with \'temdir\' ($rtmpdir): $de")
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

{
  my $err = MMisc::check_dir_w($logdir);
  MMisc::error_quit("\'logdir\' ($logdir) problem: $err")
    if (! MMisc::is_blank($err));
}

if ($skipval) {
  MMisc::error_quit("Can not use \'WriteMemDump\' when \'skip_validation\' is selected")
    if (defined $memdump);
}

if (defined $memdump) {
  my $derr = MMisc::check_dir_w($memdump);
  MMisc::error_quit("Problem with \'WriteMemDump\' 's directory ($memdump) : $derr")
    if (! MMisc::is_blank($derr));
}

########################################

# Expected values
my @expected_year;
my @expected_task;
my @expected_data;
my @expected_lang;
my @expected_sysid_beg;
my @expected_dir_output;
my %expected_ecf_files;

my $tmpstr = MMisc::slurp_file($specfile);
MMisc::error_quit("Problem loading \'Specfile\' ($specfile)")
  if (! defined $tmpstr);
eval $tmpstr;

MMisc::error_quit("Missing data in \'Specfile\' ($specfile)")
  if (
    (scalar @expected_year == 0)
    || (scalar @expected_task == 0)
    || (scalar @expected_data == 0)
    || (scalar @expected_lang == 0)
    || (scalar @expected_sysid_beg == 0)
    || (scalar @expected_dir_output == 0)
    || (scalar keys %expected_ecf_files == 0)
  );

my $doepmd = 0;

my $todo = scalar @ARGV;
my $done = 0;
my %errors = ();
my %warnings = ();
my %notes = ();
my $wn_key = "";
my $admd = 0; # Already Dumped MemDump ?
my $logbase = "$logdir/";
my %ttid_left = ();
my @ttid_modes = ("TODO", "DONE", "ERROR"); # Order is important
foreach my $sf (@ARGV) {
  %warnings = ();
  %notes = ();
  %errors = ();

  print "\n---------- [$sf]\n";

  my $ok = 1;
  my $tmpdir = "";
  my $site = "";
  my $err = "";
  $logbase = "";
  %ttid_left = ();

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
    ($err, $site, my $subnum) = &check_archive_name($file);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
    vprint(2, "<SITE> = $site | <SUB-NUM> = $subnum");
    $logbase = "$logdir/${site}_${subnum}_____";
    vprint(1, "Uncompressing archive");
    ($err, $tmpdir) = &uncompress_archive($dir, $file, $ext, $rtmpdir);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
  } else {
    $site = $sf;
    $tmpdir = $wid;
    my $de = MMisc::check_dir_r($tmpdir);
    MMisc::error_quit("Problem with \'work_in_dir\' directory ($tmpdir): $de")
      if (! MMisc::is_blank($de));
    vprint(1, "\'work_in_dir\' path");
    vprint(2, "<SITE> = $site");
    $logbase = "$logdir/${site}_X_____";
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
      &valerr($sf, "Found no <EXP-ID> directory");
      $ok = 0;
      next;
    }
    foreach my $sdir (sort @$rd) {
      vprint(2, "Checking <EXP-ID> Directory ($sdir)");
      $wn_key = $sdir;
      my $err = &check_expid_dir("$tmpdir/$odir", $sdir, $site);
      if (! MMisc::is_blank($err)) {
        if ($qoe) {
          &__extend_error_notes_warnings();
          my ($okadd, $erradd) = &format_warnings_notes_errors();
          &valerr($sf, "While checking submission's EXPID [$sdir]: $erradd");
        }
        $ok = 0;
      }
    }
  }
  
  &__extend_error_notes_warnings();
  my ($okadd, $erradd) = &format_warnings_notes_errors();

  $ok = 0 if (! MMisc::is_blank($erradd));
     
  if ($ok) {
    &valok($sf, "ok$okadd");
    $done ++;
  } else {
    &valerr($sf, "The following errors were seen: $erradd", $okadd);
  }

}

my @lin = ();
push @lin, "the \'skip_validation\' option was used, therefore the XML files were not checked for accuracy. Submitted archive files must have been XML validated to be accepted."
  if ($skipval);
push @lin, "the \'work_in_dir\' option was used, please rerun the program against the final archive file to confirm it is a valid submission file." 
  if (defined $wid);
print(
  "\n\n==========\nAll submission processed (OK: $done / Total: $todo)\n" 
  . ((scalar @lin == 0) ? "" :
     ($done ? "\nIMPORTANT NOTES:\n - " . join("\n - ", @lin) . "\n" : ""))
  );

MMisc::error_quit("Not all submission processed succesfuly") if ($done != $todo);
MMisc::ok_quit("\nDone\n");


########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt, $extra) = @_;

  print "\n\n\n";
  &valok($fname, "[ERROR] $txt");
  &valok($fname, "[ERROR] ** Please refer to the \'Submission Instructions\' of the \'AVSS Multiple Camera Person Tracking Evaluation Plan\' for more information");

  &valok($fname, "Also to note: $extra") if (! MMisc::is_blank($extra));

  MMisc::error_quit("\'quit_on_error\' selected, quitting")
    if ($qoe);
}

##########

sub __add_to_errors {
  my ($exp, $print, $v) = @_;

  push @{$errors{$exp}}, $v;
  print "!! [$exp] ERROR: $v\n" if ($print);
}

#####

sub __add_to_warnings {
  my ($exp, $print, $v) = @_;

  push @{$warnings{$exp}}, $v;
  print "++ [$exp] Warning: $v\n" if ($print);
}

#####

sub __add_to_notes {
  my ($exp, $print, $v) = @_;

  push @{$notes{$exp}}, $v;
  print "%% [$exp] Note: $v\n" if ($print);
}

#####

sub __extend_error_notes_warnings {
  foreach my $lexpid (sort keys %ttid_left) {
    my %ltmp = ();
    foreach my $lttid (sort keys %{$ttid_left{$lexpid}}) {
      my $v = $ttid_left{$lexpid}{$lttid};
      push @{$ltmp{$v}}, $lttid; 
    }
    if ((! exists $ltmp{$ttid_modes[2]}) && (! exists $ltmp{$ttid_modes[0]})) {
      &__add_to_notes($lexpid, 0, "For EXPID [$lexpid]: Found all expected TTID");
    } else {
      if (exists $ltmp{$ttid_modes[0]}) {
        &__add_to_warnings($lexpid, 0, "Some TTID not found: " . join(", ", sort @{$ltmp{$ttid_modes[0]}}));
      }
      if (exists $ltmp{$ttid_modes[2]}) {
        &__add_to_errors($lexpid, 0, "Some TTID had errors: " . join(", ", sort @{$ltmp{$ttid_modes[2]}}));
      }
      if (exists $ltmp{$ttid_modes[1]}) {
        &__add_to_notes($lexpid, 0, "Found some TTIDs: " . join(", ", sort @{$ltmp{$ttid_modes[1]}}));
      }
    }
  }
}

#####

sub format_list {
  my ($txt, $skipbl, @list) = @_;

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

sub format_warnings_notes_errors {
  my $txt = "";
  my $err = "";

  my @todo = keys %notes;
  push @todo, keys %warnings;
  push @todo, keys %errors;
  @todo = MMisc::make_array_of_unique_values(\@todo);

  foreach my $key (@todo) {
    my $tmp = "";
    my $header = "  -- EXPID: $key\n";
    if (exists $warnings{$key}) {
      my @list = @{$warnings{$key}};
      $tmp .= &format_list("    - WARNINGS:", "      ", @list);
    }
    if (exists $notes{$key}) {
      my @list = @{$notes{$key}};
      $tmp .= &format_list("    - NOTES:", "      ", @list);
    }
    if (exists $errors{$key}) {
      $err = "\n$header";
      my @list = @{$errors{$key}};
      $err .= &format_list("    - ERRORS:", "      ", @list);
    }

    $txt .= "$header$tmp"
      if (! MMisc::is_blank($tmp));
  }

  $txt = "\n$txt"
    if (! MMisc::is_blank($txt));

  return($txt, $err);
}

##########

sub check_archive_extension {
  my $ext = MMisc::iuv($_[0], "");

  return(&cmp_exp("file extension", lc($ext), @expected_ext));
}

##########

sub check_archive_name {
  my $file = MMisc::iuv($_[0], "");

  my $et = "Archive name not of the form \'<SITE>_<SUB-NUM>\'";

  my ($lsite, $lsubnum, @left) = split(m%\_%, $file);
  
  return($et . " (leftover entries: " . join(" ", @left) . ")")
    if (scalar @left > 0);

  return($et . " (<SUB-NUM> ($lsubnum) not of the expected form: integer value starting at 1)")
    if ( ($lsubnum !~ m%^\d+$%) || ($lsubnum =~ m%^0%) );

  return("", $lsite, $lsubnum);
}

##########

sub uncompress_archive {
  my ($dir, $file, $ext, $rtmpdir) = 
    ($_[0], $_[1], $_[2], MMisc::iuv($_[3], undef));

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
  my $tmpdir = MMisc::iuv($_[0], "");

  return("Empty directory ?")
    if (MMisc::is_blank($tmpdir));

  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($tmpdir);
  return("Problem checking directory ($tmpdir) : $err")
    if (! MMisc::is_blank($err));

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

sub check_expid_dir {
  my ($bd, $dir, $site) = @_;

  vprint(3, "Checking name");
  my ($lerr, my $data, my $task) = &check_name($dir, $site);
  if (! MMisc::is_blank($lerr)) {
    &__add_to_errors($dir, 1, $lerr);
    return($lerr);
  }

  vprint(3, "Checking expected directory files");
  my ($lerr) = &check_exp_dirfiles($bd, $dir, $data, $task);
  if (! MMisc::is_blank($lerr)) {
    &__add_to_errors($dir, 1, $lerr);
    return($lerr);
  }

  return("");
}

##########

sub check_name {
  my ($name, $site) = @_;

  my $et = "\'EXP-ID\' not of the form \'<SITE>_<YEAR>_<TASK>_<DATA>_<LANG>_<SYSID>_<VERSION>\' : ";
  
  my ($lsite, $lyear, $ltask, $ldata, $llang, $lsysid, $lversion, 
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters ($name). ", "")
    if (MMisc::any_blank($lsite, $lyear, $ltask, $ldata, $llang,, $lsysid, $lversion));
  
  my $err = "";
  
  $err .= " <SITE> ($lsite) is different from submission file <SITE> ($site)."
    if ($site ne $lsite);
  
  $err .= &cmp_exp("<YEAR>", $lyear, @expected_year);
  $err .= &cmp_exp("<TASK>", $ltask, @expected_task);
  $err .= &cmp_exp("<DATA>", $ldata, @expected_data);
  $err .= &cmp_exp("<LANG>", $llang, @expected_lang);
  
  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expected_sysid_beg) . "). "
    if (! grep(m%^$b$%, @expected_sysid_beg));
  
  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) );
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  vprint(4, "<SITE> = $lsite | <YEAR> = $lyear | <TASK> = $ltask | <DATA> = $ldata | <LANG> = $llang | <SYSID> = $lsysid | <VERSION> = $lversion");
  
  return("", $ldata, $ltask);
}

##########

sub __check_exp_txt_file {
  my ($exp, @lf) = @_;

  vprint(4, "Checking for $exp.txt file");
  my $ef = "$exp.txt";

  return("Did not find 1 expected file [$ef], found " 
         . ((scalar @lf == 0) ? "none" : (scalar @lf . " (" . join(" ", @lf) . ")")) )
    if (scalar @lf != 1);

  return("Did not find expected file ($ef), found (" . $lf[0] . ")")
    if ($lf[0] ne $ef);

  return("");
}  

#####

sub __check_task_dir {
  my ($task, @ld) = @_;

  vprint(4, "Checking for <TASK> directory");

  return("Did not find 1 expected directory [$task], found " 
         . ((scalar @ld == 0) ? "none" : (scalar @ld . " (" . join(" ", @ld) . ")")) )
    if (scalar @ld != 1);

  return("Did not find expected directory ($task), found (" . $ld[0] . ")")
    if (lc($ld[0]) ne lc($task));

  return("", $ld[0]);
}

#####

sub check_exp_dirfiles {
  my ($bd, $exp, $data, $task) = @_;
  
  my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files("$bd/$exp");
  return($derr) if (! MMisc::is_blank($derr));

  # <EXPID>.txt file
  my $err = &__check_exp_txt_file($exp, @$rf);
  if (! MMisc::is_blank($err)) {
    &__add_to_errors($exp, 1, $err);
    return($err) if ($qoe);
  }

  # <TASK> dir
  my ($err, $lt) = &__check_task_dir($task, @$rd);
  if (! MMisc::is_blank($err)) {
    &__add_to_errors($exp, 1, $err);
    return($err) if ($qoe);
    return(""); # Non lethal, but do no check its content
  }

  my ($err, $aa) = &check_task_dir("$bd/$exp/$lt", $data, $task, $exp);
  if (! MMisc::is_blank($err)) {
    if ($aa != 1) { # Not already added to errors hash ?
      &__add_to_errors($exp, 1, $err);
    }
    return($err) if ($qoe);
  }

  return("");
}

##########

sub check_task_dir {
  my ($bd, $data, $task, $exp) = @_;

  vprint(5, "Checking $task directory");
  vprint(6, "Confirming ECF file");
  return("No ECF file available for [$data / $task]")
    if (! exists $expected_ecf_files{$task}{$data});
  my $ecffile = "$ecfdir/" . $expected_ecf_files{$task}{$data};
  vprint(7, "Using: $ecffile");

  my $err = MMisc::check_file_r($ecffile);
  return("Problem with expected ECF file for [$data / $task] ($ecffile): $err")
    if (! MMisc::is_blank($err));

  my ($err, $ecfobj) = AVSS09HelperFunctions::load_ECF_file($ecffile, $xmllint, $AVxsdpath);
  return("Problem loading ECF file for [$data / $task] ($ecffile) : $err")
    if (! MMisc::is_blank($err));
  
  my @ttl = $ecfobj->get_ttid_list();
  return("Problem extracting TTID list from ECF [$ecffile]:" . $ecfobj->get_errormsg())
    if ($ecfobj->error());
  return("Found no TTID in ECF [$ecffile]")
    if (scalar @ttl == 0);
  foreach my $tt (@ttl) {
    $ttid_left{$exp}{$tt} = $ttid_modes[0];
  }

  vprint(6, "Checking TTID directories");
  # Check each ttid dir
  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($bd);
  return("Problem checking directory ($bd) : $err")
    if (! MMisc::is_blank($err));
  my @left = @$rf;
  push @left, @$ru;
  return("Found files where only directories expected (seen: " . join(" ", @left) .")")
    if (scalar @left > 0);
  return("Found no TTID directory")
    if (scalar @$rd == 0);

  # <ttid>
  my $err = "";
  foreach my $ttid (@$rd) {
    return("Could not find TTID [$ttid] in expected TTID list")
      if (! exists $ttid_left{$exp}{$ttid});
    my $lerr = &check_ttid_dir("$bd/$ttid", $data, $task, $ttid, $ecfobj, $ecffile, $exp);
    if (! MMisc::is_blank($lerr)) {
      &__add_to_errors($exp, 1, $lerr);
      $ttid_left{$exp}{$ttid} = $ttid_modes[2];
      $err .= $lerr;
      return($err, 1) if ($qoe);
      next;
    }
    
    $ttid_left{$exp}{$ttid} = $ttid_modes[1];
  }
  return($err, 1) if (! MMisc::is_blank($err));

  return("");
}

##########

sub check_ttid_dir {
  my ($bd, $data, $task, $ttid, $ecfobj, $ecffile, $exp) = @_;

  vprint(7, "Checking TTID ($ttid)");
  my $ok = $ecfobj->is_ttid_of_type($ttid, $task);
  if ($ecfobj->error()) {
    my $err = $ecfobj->get_errormsg();
    $ecfobj->clear_error(); # for next run
    return($err);
  }
  return("Requested TTID ($ttid) is not of type ($task). ") if (! $ok);

  vprint(7, "Checking TTID directory for XML files ($ttid)");
  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($bd);
  return("Problem checking directory ($bd) : $err. ")
    if (! MMisc::is_blank($err));
  return("Found no files in directory ($bd). ")
    if (scalar @$rf == 0);
  return("Found unexpected directories in ($bd): " . join(" ", @$rd) . ". ")
    if (scalar @$rd > 0);
  my @l = grep(! m%\.xml$%i, @$rf);
  return("Found non XML files in TTID directory ($bd): " . join(" ", @l) . ". ")
    if (scalar @l > 0);

  vprint(7, "Confirming XML files are matching the expected naming");
  my @list = $ecfobj->get_sffn_list_for_ttid($ttid);
  if ($ecfobj->error()) {
    my $err = $ecfobj->get_errormsg();
    $ecfobj->clear_error(); # for next run
    return($err);
  }
  return("Found no entry for ttid. ") if (scalar @list == 0);
  
  my %h = ();
  my $err = "";
  foreach my $f (@list) {
    $f =~ s%^.+/%%;
    $f =~ s%\..+$%%;
    $h{$f}++;
  }
  foreach my $f (keys %h) {
    $err .= "$f entry appears more than once in ECF for \"$ttid\" TTID. "
      if ($h{$f} > 1);
  }
  return($err) if (! MMisc::is_blank($err));

  $err = "";
  foreach my $g (@$rf) {
    my $f = $g;
    $f =~ s%\.[^\.]+$%%;
    if (! exists $h{$f}) {
      $err .= "Found unknown file ($g). ";
    } else {
      $h{$f}--;
    }
  }
  return("For TTID [$ttid] (dir: $bd): $err. ") if (! MMisc::is_blank($err));
    
  foreach my $f (keys %h) {
    $err .= "$f entry appears in ECF for \"$ttid\" TTID but was not found in directory ($bd). "
      if ($h{$f} > 0);
  }
  return($err) if (! MMisc::is_blank($err));

  return("") if ($skipval);

  my $logfile = "$logbase${exp}_____${task}_____${ttid}.log";
  return(&validate_ttid_dir($bd, $ttid, $ecffile, $logfile, $exp, @$rf));
}  

##########

sub validate_ttid_dir {
  my ($bd, $ttid, $ecffile, $logfile, $exp, @fl) = @_;
  
  vprint(8, "Validating TTID content ($ttid)");
  
  my $lmemdump = "$memdump/$exp";
  return("Problem creating directory [$lmemdump]")
    if (! MMisc::make_dir($lmemdump));

  my $cmd = "$valtool";
  $cmd .= " --xmllint $xmllint" if (! MMisc::is_blank($xmllint));
  $cmd .= " --CLEARxsd $xsdpath" if (! MMisc::is_blank($xsdpath));
  $cmd .= " --AVSSxsd $AVxsdpath" if (! MMisc::is_blank($AVxsdpath));
  $cmd .= " --frameTol $frameTol";
  $cmd .= " --write $lmemdump --WriteMemDump gzip";
  $cmd .= " --ECF $ecffile --TrackingTrialsDir --trackingTrial $ttid --quitTTID";
  foreach my $f (@fl) {
    $cmd .= " $bd/$f";
  }

  vprint(9, "Running Validation step");
  my ($ok, $rtxt, $stdout, $stderr, $retcode) =
    MMisc::write_syscall_logfile($logfile, $cmd);
  return("Problem while running validation on TTID [$ttid], see log file [$logfile]")
    if ($retcode != 0);
  vprint(10, "Succesful validation [log: $logfile]");

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
  my ($h, @rest) = @_;

  my $s = "********************";


  print substr($s, 0, $h), " ", join("", @rest), "\n";
}

############################################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################ Manual

=pod

=head1 NAME

AVSS-Submission Checker - AVSS Submission Checker

=head1 SYNOPSIS

B<AVSS-SubmissionChecker> S<[B<--help> | B<--version> | B<--man>]>
  S<B<--Specfile> I<perlEvalfile> B<--ecfdir> I<directory>>
  S<[B<--xmllint> I<location>] [B<--CLEARxsd> I<location>] [B<--AVSSxsd> I<location>]>
  S<[B<--skip_validation>] [B<--WriteMemDump> I<dir>] [B<--Verbose>]>
  S<[B<--uncompress_dir> I<dir> | B<--work_in_dir> I<dir>]>
  S<[B<--quit_on_error>] [B<--logdir> I<directory>]>
  S<[B<--tool> I<toolpath>] [B<--frameTol> I<nbrframe>]>
  S<last_parameter>

=head1 DESCRIPTION

B<AVSS-SubmissionChecker> is an I<AVSS Sumbission Checker> program designed to confirm that a submission archive follows the guidelines posted in the I<Submission Instructions> of the I<AVSS Multiple Camera Person Tracking Evaluation Plan>.
 
The software will confirm that an archive's files and directory structure conforms with the I<Submission Instructions>, and will validate the SYS XML files.

It is written to be functional with AVSS09 by using a B<Specfile> that contains needed definitions (distributed as part of the F4DE archive).

In the case of B<--work_in_dir>, S<last_parameter> is the E<lt>SITEE<gt>.
In all other cases, S<last_parameter> is the archive file to process in the E<lt>I<SITE>E<gt>_E<lt>I<SUB-NUM>E<gt>.I<extension> form (recognized extensions are available using the B<--help> option).

=head1 PREREQUISITES

B<AVSS-SubmissionChecker> ViPER files need to pass the B<AVSS09ViPERValidator> validation process. The program relies on the following software and files.
 
=over

=item B<SOFTWARE>

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<F4DE_XMLLINT> environment variable to the full path location of the I<xmllint> executable.

The program needs I<AVSS09ViPERValidator> to perform ViPER validation and additional check on submission files.

The program relies on I<gnu tar> and I<unzip> to process the archive files.

=item B<FILES>

The syntactic validation requires some XML schema files.
It is possible to specify their location using the B<CLEARxsd> and B<AVSSxsd> options.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

The program also requires a B<Specfile> that defines some parameters related to the eval being checked as well as list the expected ECF files depending on the task specified by the E<lt>I<EXPID>E<gt>. It then requires a directory location (B<ecfdir>) for those needed ECF files. Note that the ECFs are not part of the B<F4DE> distribution, rather they are contained in the training/testing annotation releases.

=item B<GLOBAL ENVIRONMENT VARIABLES>

Once you have installed the software, setting B<F4DE_BASE> to the installation location, and extending your B<PATH> to include B<$F4DE_BASE/bin> should be sufficient for the tools to find their components.

=back

=head1 GENERAL NOTES

B<AVSS-SubmissionChecker> expects that the system and reference ViPER files can be been validated using 'xmllint' against the AVSS09 specifications.

B<AVSS-SubmissionChecker> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--AVSSxsd> I<location>

Specify the default location of the required AVSS XSD files.

=item B<--CLEARxsd> I<location>

Specify the default location of the required CLEAR XSD files.

=item B<--ecfdir> I<directory>

Specify the I<directory> in which the ECF XML files specified using the B<Specfile> option can be found. The ECF provides information such as the list of sourcefile filenames expected to be seen in the submission. 

=item B<--frameTol> I<nbrframe>

The frame tolerance allowed for attributes to be outside of the object framespan.
Default value can be obtained by using B<--help>.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--logdir> I<directory>

Specify the directory in which ViPER validation logs are placed.

=item B<--man>

Display this man page.

=item B<--quit_on_error>

If for any reason, any submission file or step is returning an error, quit when this error is encounted, instead of continuing the check process and adding information to a report printed when all submissions have been checked.

=item B<--Specfile> I<perlEvalfile>

Specify the I<perlEvalfile> that contains definitions specific to the evaluation checked against.

=item B<--skip_validation>

Do not perform XML validation on the ViPER files within the archive.

=item B<--tool> I<toolpath>

Specify the full path location of the S<AVSS09ViPERValidator> tool.

=item B<--uncompress_dir> I<dir>

Specify the location of the directory in which to uncompress the archive content (by default a temporary directory is created).

=item B<--Verbose>

Print a verbose log of every task being performed before performing it, and in some case, its results.

=item B<--version>

Display B<AVSS-SubmissionChecker> version information.

=item B<--WriteMemDump> I<dir>

Write a memory dump of validated XML files into I<dir>, placing those files in a directory structure that match the I<ECF> specifications for a given I<tracking trial ID> that can be reloaded by the B<AVSS09Scorer> program with the I<ECF> information only.

=item B<--work_in_dir> I<dir>

Specify the location of the uncompressed files to check.
This step is designed to help confirm that a directory structure is proper before generating the archive.
When using this mode, the S<last_parameter> becomes E<lt>SITEE<gt>.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<F4DE_XMLLINT> environment variable.

=back

=head1 USAGE

=item B<AVSS-SubmissionChecker --Specfile AVSS09-SubmissionChecker_conf.perl --ecfdir ECFs SITE_3.tgz>

Will perform a submission check on archive file I<SITE_3.tgz> in a temporarily created directory, following the evaluation specifications defined in I<AVSS09-SubmissionChecker_conf.perl> and looking for the ECF XMLs defined in this specfile in the I<ECFs> directory.

=item B<AVSS-SubmissionChecker --Specfile AVSS09-SubmissionChecker_conf.perl --ecfdir ECFs SITE_3.tgz --uncompress_dir testdir --skip_validation>

Will perform a submission check on archive file I<SITE_3.tgz>, uncompressing its content in the I<testdir> directory. This will also not try to validate the XML files, it will simply confirm that the directory structure, and that all the files are present.

=item B<AVSS-SubmissionChecker --Specfile AVSS09-SubmissionChecker_conf.perl --ecfdir ECFs SITE --work_in_dir testdir --Verbose --quit_on_errors>

Will check that the files and directories in I<testdir> are the expected ones. It will also confirm that the XML files validate against the XML strucutre, and that the content of the XML files can be matched against the ECF rules. While checking each I<EXPID> and I<TTID>, print verbose information on step performed, and will exit after the first error encountered (instead of processing all the files/directory in I<testdir>).

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

  my $txt=<<EOF
$versionid

Usage: $0 [--help | --version | --man] --Specfile perlEvalfile --ecfdir directory [--xmllint location] [--CLEARxsd location] [--AVSSxsd location] [--skip_validation] [--WriteMemDump dir] [--Verbose] [--uncompress_dir dir | --work_in_dir dir] [--quit_on_error] [--logdir directory] [--tool toolpath] [--frameTol nbrframe] last_parameter

Will confirm that a submission file conforms to the 'Submission Instructions' of the 'AVSS Multiple Camera Person Tracking Evaluation Plan'. The program needs a 'Specfile' to load some of its eval specific definitions, as well as an 'ecfdir' in which are all the XML ECF files specified in the Specfile.

'last_parameter' is usually the archive file(s) to process (of the form <SITE>_<SUB-NUM>.extension, example: NIST_2.tgz)
Only in the '--work_in_dir' case does it become <SITE>.

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailed manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --Specfile      Specify the \'perlEvalfile\' that contains definitions specific to the evaluation run
  --ecfdir        Specify the \'directory\' in which the ECF XML files defined in the \'perlEvalfile\' can be found 
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd      Path where the XSD files related to CLEAR can be found
  --AVSSxsd       Path where the XSD files needed for AVSS ECF validation can be found
  --skip_validation  Bypass the XML files validation process
  --WriteMemDump  Base directory in which the scoring ready directory hierarchy will be created 
  --Verbose       Explain step by step what is being checked
  --uncompress_dir  Specify the directory in which the archive file will be uncompressed
  --work_in_dir   Bypass all steps up to and including uncompression and work with files in the directory specified (useful to confirm a submission before generating its archive)
  --quit_on_error Exit as soon as an error is found in submission. Default is to try to process the entire submission and give a summary of all encountered errors at the end of the check
  --logdir        Specify the \'directory\' in which all validation steps log files are written (default: $logdir)
  --tool          Specify the full path location of the AVSS09ViPERValidator tool (default: $valtool)
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default: $frameTol)

Note:
- Recognized archive extensions: $ok_exts
EOF
;

  return($txt);
}
