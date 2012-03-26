#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid Multimedia Event Detection Submission Checker
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid Event Detection Submission Checker" is an experimental system.
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
foreach my $pn ("MMisc", "MtSQLite") {
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

my @data_search_path = ('.', (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : (dirname(abs_path($0)) . "/../../data"));

my ($err, $sqlitecmd) = MtSQLite::get_sqlitecmd();
MMisc::error_quit($err)
  if (MMisc::is_blank($sqlitecmd));

my $DEVAtool = (exists $ENV{$f4b})
  ? $ENV{$f4b} . "/bin/DEVA_cli"
  : dirname(abs_path($0)) . "/../DEVA_cli/DEVA_cli.pl";
my $err = MMisc::check_file_x($DEVAtool);
MMisc::error_quit("Problem with required tool ($DEVAtool) : $err")
  if (! MMisc::is_blank($err));

my $mancmd = "perldoc -F $0";
my $usage = &set_usage();

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

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                   ST V           h    m   q s uvw    #

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
my @expid_tag;
my @expid_data;
my @expid_MEDtype;
my @expid_EAG;
my @expid_sysid_beg;
my @expected_dir_output;
my $expected_csv_per_expid = -1;
my @expected_csv_names;
my $db_check_sql = undef;
my $medtype_fullcount = -1;
my @db_eventidlist;
my @db_missingTID;
my @db_unknownTID;
my @db_detectionTID;
my @db_thresholdEID;
my $max_expid = 0;
my $max_expid_error = 1;

my $tmpstr = MMisc::slurp_file($specfile);
MMisc::error_quit("Problem loading \'Specfile\' ($specfile)")
  if (! defined $tmpstr);
eval $tmpstr;
MMisc::error_quit("Problem during \'SpecFile\' use ($specfile) : " . join(" | ", $@))
  if $@;

sub __cfgcheck {
  my ($t, $v) = @_;
  MMisc::error_quit("Missing or improper datum [$t] in \'SpecFile\' ($specfile)")
    if ($v);
}

&__cfgcheck("\@expid_tag", (scalar @expid_tag == 0));
&__cfgcheck("\@expid_data", (scalar @expid_data == 0));
&__cfgcheck("\@expid_MEDtype", (scalar @expid_MEDtype == 0));
&__cfgcheck("\@expid_EAG", (scalar @expid_EAG == 0));
&__cfgcheck("\@expid_sysid_beg", (scalar @expid_sysid_beg == 0));
&__cfgcheck("\@expected_dir_output", (scalar @expected_dir_output == 0));
&__cfgcheck("\$expected_csv_per_expid", ($expected_csv_per_expid < 0));
&__cfgcheck("\@expected_csv_names", (scalar @expected_csv_names == 0));
&__cfgcheck("\$db_check_sql", (! defined $db_check_sql));
&__cfgcheck("\$medtype_fullcount", ($medtype_fullcount < 0));
&__cfgcheck("\@db_eventidlist", (scalar @db_eventidlist == 0));
&__cfgcheck("\@db_missingTID", (scalar @db_missingTID == 0));
&__cfgcheck("\@db_unknownTID", (scalar @db_unknownTID == 0));
&__cfgcheck("\@db_detectionTID", (scalar @db_detectionTID == 0));
&__cfgcheck("\@db_thresholdEID", (scalar @db_thresholdEID == 0));

&extend_file_location(\$db_check_sql, 'SQL DB check file', @data_search_path);

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
  my $err = "";

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
    
    vprint(1, "Get the TEAM, DATA and SUB-NUM information");
    ($err, $team, $data, my $subnum) = &check_archive_name($file);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
    vprint(2, "<TEAM> = $team | <DATA> = $data | <SUB-NUM> = $subnum");
    
    vprint(1, "Uncompressing archive");
    ($err, $tmpdir) = &uncompress_archive($dir, $file, $ext, $rtmpdir);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
  } else {
    $team = $sf;
    $tmpdir = $wid;
    my $de = MMisc::check_dir_r($tmpdir);
    MMisc::error_quit("Problem with \'work_in_dir\' directory ($tmpdir): $de")
      if (! MMisc::is_blank($de));
    vprint(1, "\'work_in_dir\' path");
    vprint(2, "<TEAM> = $team");
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
      my ($err) = &check_submission_dir("$tmpdir/$odir", $sdir, $team);
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

  my $et = "Archive name not of the form \'MED11_<TEAM>_<DATA>_<SUB-NUM>\' : ";

  my ($ltag, $lteam, $ldata, $lsubnum, @left) = split(m%\_%, $file);
  
  return($et . "leftover entries: " . join(" ", @left))
    if (scalar @left > 0);

  my $err = "";

  $err .= &cmp_exp("MED11", $ltag, @expid_tag);
  $err .= &cmp_exp("<DATA>",  $ldata, @expid_data);
  
  $err .= " (<SUB-NUM> ($lsubnum) not of the expected form: integer value starting at 1)"
    if ( ($lsubnum !~ m%^\d+$%) || ($lsubnum =~ m%^0%) );

  return($et . $err, "")
    if (! MMisc::is_blank($err));

  return("", $lteam, $ldata, $lsubnum);
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
  my ($bd, $dir, $team) = @_;

  vprint(3, "Checking name");
  my ($lerr, $data, $medtype) = &check_name($dir, $team);
  return($lerr) if (! MMisc::is_blank($lerr));

  vprint(3, "Checking expected directory files");
  return(&check_exp_dirfiles($bd, $dir, $data, $medtype));
}

##########

sub check_name {
  my ($name, $team, $data) = @_;

  my $et = "\'EXP-ID\' not of the form \'<TEAM>_MED11_<DATA>_<MEDTYPE>_<EAG>_<SYSID>_<VERSION>\' : ";
  
  my ($lteam, $ltag, $ldata, $lmedtype, $leag, $lsysid, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters ($name). ", "")
    if (MMisc::any_blank($lteam, $ltag, $ldata, $lmedtype, $leag, $lsysid, $lversion));
  
  my $err = "";
  
  $err .= " <TEAM> ($lteam) is different from submission file <TEAM> ($team)."
    if ($team ne $lteam);

  $err .= " <DATA> ($ldata) is different ftom submission file <DATA> ($data)."
    if ((! MMisc::is_blank($data)) && ($data ne $ldata));
  
  $err .= &cmp_exp("_MED11_", $ltag, @expid_tag);
  $err .= &cmp_exp("<DATA>",  $ldata, @expid_data);
  $err .= &cmp_exp("<MEDTYPE>", $lmedtype, @expid_MEDtype);
  $err .= &cmp_exp("<EAG>", $leag, @expid_EAG);
  
  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expid_sysid_beg) . "). "
    if (! grep(m%^$b$%, @expid_sysid_beg));
  
  if ($b eq $expid_sysid_beg[0]) {
    $err .= "<SYSID> ($lsysid) can only have one primary \'EXP-ID\'"
      if (($pc_check) && (exists $pc_check_h{$team}));
    $pc_check_h{$team}++;
  }

  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) || ($lversion > 19) );
  # More than 19 submissions would make anybody suspicious ;)
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  vprint(4, "<TEAM> = $lteam | <TAG> = $ltag | <DATA> = $ldata | <MEDTYPE> = $lmedtype | <EAG> = $leag | <SYSID> = $lsysid | <VERSION> = $lversion");
  
  return("", $ldata, $lmedtype);
}

##########

sub check_exp_dirfiles {
  my ($bd, $exp, $data, $medtype) = @_;

  my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files("$bd/$exp");
  return($derr) if (! MMisc::is_blank($derr));
  
  my @left = @$rd;
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
  
  return(&run_DEVAcli($exp, $data, $medtype, %match));
}

#####

sub run_DEVAcli {
  my ($exp, $data, $medtype, %match) = @_;

  vprint(4, "Creating the Database (ie validating System)");

  my $od = "$outdir/$exp";
  return("Problem creating output dir ($od)")
    if (! MMisc::make_wdir($od));
  vprint(5, "Output dir: $od");
    
  my @cmd = ();
  push @cmd, '-p', 'MED11', '-o', "$od";
  foreach my $k (keys %match) {
    push @cmd , '-s', $match{$k} . ":$k";
  }
  push @cmd, "$trialindex:TrialIndex";
  push @cmd, '-f', '-D';

  my $lf = "$od/DEVAcli_run.log";
  vprint(5, "Running tool ($DEVAtool), log: $lf");
  my ($err) = &run_tool($lf, $DEVAtool, @cmd);

  return($err) if (! MMisc::is_blank($err));

  return(&check_TrialIDs($od, $exp, $data, $medtype));
}

#####

sub run_tool {
  my ($lf, $tool, @cmds) = @_;

  $lf = MMisc::get_tmpfilename() if (MMisc::is_blank($lf));

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    MMisc::write_syscall_smart_logfile($lf, $tool, @cmds); 
  if ((! $ok) || ($rc != 0)) {
    my $lfc = MMisc::slurp_file($of);
    return("There was a problem running the tool ($tool) command\n  Run log (located at: $of) content: $lfc\n\n");
  }

  return("", $ok, $otxt, $so, $se, $rc, $of);
}

#####

sub check_TrialIDs {
  my ($od, $expid, $data, $medtype) = @_;

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
  vprint(5, "Found $tidc EventID : " . ajoin(" ", @el));
  return("Found no recognized EventID") if ($tidc == 0);

  if (($medtype_fullcount > 0) && ($medtype eq $expid_MEDtype[0]) && ($tidc < $medtype_fullcount)) {
    my $txt = "EXPID ($expid) designs this submission as a \'$medtype\', but it contains $tidc EventIDs, when $medtype_fullcount are expected to consider it so";
    return($txt) if ($data ne $expid_data[0]);
    MMisc::warn_print("$txt. Since this is a $data submission, only this warning is shown. Otherwise, an error message would have been shown");
  }

  my $err = &id_check($dbfile, "Missing TrialID", $db_missingTID[0], $db_missingTID[1]);
  return($err) if (! MMisc::is_blank($err));

  my $err = &id_check($dbfile, "Unknown TrialID", $db_unknownTID[0], $db_unknownTID[1]);
  return($err) if (! MMisc::is_blank($err));

  my $err = &id_check($dbfile, "Unknown \'detection\' TrialID", $db_detectionTID[0], $db_detectionTID[1]);
  return($err) if (! MMisc::is_blank($err));

  my $err = &id_check($dbfile, "Unknown \'threshold\' EventID", $db_thresholdEID[0], $db_thresholdEID[1]);
  return($err) if (! MMisc::is_blank($err));

  return("");
}

#####

sub id_check {
  my ($dbfile, $txt, $tn, $cn) = @_;

  my @lid = ();
  my ($err, $tidc) = MtSQLite::select_helper__to_array($dbfile, \@lid, $tn, "", $cn);
  return("Problem obtaining the $txt list : $err") if (! MMisc::is_blank($err));
  vprint(5, "Found $tidc $txt");
  return("$tidc $txt: " . ajoin(" ", @lid)) if ($tidc > 0);

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

Usage: $0 [--help | --version | --man] --Specfile perlEvalfile --TrialIndex index.csv [--Verbose] [--uncompress_dir dir | --work_in_dir dir] [--quit_if_non_scorable] last_parameter

Will confirm that a submission file conforms to the 'Submission Instructions' (Appendix B) of the 'TRECVid Multimedia Event Detection Evaluation Plan'. The program needs a 'Specfile' to load some of its eval specific definitions.

'last_parameter' is usually the archive file(s) to process (of the form MED11_<TEAM>_<DATA>_<SUB-NUM>.extension, example: MED11_testTEAM_DRYRUN_1.tar.bz2)
Only in the '--work_in_dir' case does it become <TEAM>.

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --Specfile      Specify the \'perlEvalfile\' that contains definitions specific to the evaluation run
  --TrialIndex    Specify the location of the \'TrialIndex.csv\' file used
  --Verbose       Explain step by step what is being checked
  --uncompress_dir  Specify the directory in which the archive file will be uncompressed
  --work_in_dir   Bypass all steps up to and including uncompression and work with files in the directory specified (useful to confirm a submission before generating its archive)
  --quit_if_non_scorable  If for any reason, any submission is non scorable, quit without continuing the check process, instead of adding information to a report printed at the end

Note:
- Recognized archive extensions: $ok_exts

EOF
    ;

    return $tmp;
}
