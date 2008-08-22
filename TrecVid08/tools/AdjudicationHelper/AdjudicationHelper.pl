#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# Adjudication Helper
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Adjudication Helper" is an experimental system.
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

my $versionid = "Adjudication Helper Version: $version";

### TEST Command line: ./AdjudicationHelper.pl -f 25 -D 400 -w 2 ref.xgtf sys_*

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $tv08pl, $tv08plv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = $ENV{$f4b} . "/lib";
  $tv08pl = "TV08_PERL_LIB";
  $tv08plv = $ENV{$tv08pl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib"; # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";
my $warn_msg = "";

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add
    (
     "\"Getopt::Long\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
  $have_everything = 0;
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

my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $margind = 75;
my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $fps = undef;
my $verb = 0;
my $wid = "";
my $validator = "../TV08ViperValidator/TV08ViperValidator.pl";
my $scorer = "../TV08Scorer/TV08Scorer.pl";
my $adjtool = "./Adjudicator.pl";
my $duration = undef;
my $margin = $margind;
my $cREFt = 0;
my $cSYSt = 0;
my $forceFilename = "";
my $adjudicate_only = 0;
# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: A CD              ST V    a c  f h          s  vwx   #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'fps=s'           => \$fps,
   'Validator=s'     => \$validator,
   'Scorer=s'        => \$scorer,
   'Adjudicator=s'   => \$adjtool,
   'work_in_dir=s'   => \$wid,
   'Duration=f'      => \$duration,
   'segmentation_margin=i' => \$margin,
   'changeREFtype'   => \$cREFt,
   'ChangeSYStype'   => \$cSYSt,
   'ForceFilename=s' => \$forceFilename,
   'adjudicate_only' => \$adjudicate_only,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No arguments left on command line\n\n$usage\n")
  if (scalar @ARGV == 0);

my $cmdline_add = "";
my $dummy = new TrecVid08ViperFile();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
  $cmdline_add .= "--xmllint $xmllint ";
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
  $cmdline_add .= "--TrecVid08xsd $xsdpath ";
}

MMisc::error_quit("No \'work_in_dir\' given, aborting")
  if (MMisc::is_blank($wid));
$wid = MMisc::get_file_full_path($wid);
my $err = MMisc::check_dir_w($wid);
MMisc::error_quit("\'work_in_dir\' \'dir\' problem: $err")
  if (! MMisc::is_blank($err));

MMisc::error_quit("\'Duration\' is not set, aborting")
  if (! defined $duration);

MMisc::error_quit("Not doing adjudication work on only on one REF and one SYS file")
  if (scalar @ARGV < 3);

########## Main processing
my $note_key = "NOTE_KEY";

$validator .= " $cmdline_add";
$scorer    .= " $cmdline_add";
$adjtool   .= " $cmdline_add";

my $md_add = ".memdump";
my $log_add = "log";

my $val_md_dir = "00-Validate";
my $ref_val_md_dir = "$val_md_dir/REF";
my $sys_val_md_dir = "$val_md_dir/SYS";
my $first_align    = "01-First_Alignment";
my $first_remove   = "02-Only_Unmapped_Sys";
my $iteration_step = "03-Iteration";
my $UnRef_base     = "04-1-Unmapped_Ref";
my $UnRef_step1    = "$UnRef_base/1-empty_SYS";
my $UnRef_step2    = "$UnRef_base/2-Master_REF_vs_empty_SYS";
my $UnSys_base     = "04-2-Unmapped_Sys";
my $UnSys_step1    = "$UnSys_base/1-empty_REF";
my $UnSys_step2    = "$UnSys_base/2-empty_REF_vs_Final_SYS";
my $AdjDir         = "05-Adjudication_ViPERfiles";

my $stepc = 1;

########## Confirming input files
print "\n\n***** STEP ", $stepc++, ": Confirming input files\n";

my $mf = shift @ARGV;
my $master_ref = MMisc::get_file_full_path($mf);
print "MASTER REF file: $master_ref\n";
&die_check_file_r($master_ref, "REF");

my $annot_count = 1;
my %sys_files = ();
my %sys_short = ();
foreach my $sf (@ARGV) {
  my $f = MMisc::get_file_full_path($sf);
  &die_check_file_r($f, "SYS");
  MMisc::error_quit("The same SYS file ($f) can not be used multiple time")
    if (exists $sys_files{$f});
  my ($dir, $file, $ext) = &die_split_dfe($f);
  MMisc::error_quit("SYS files ought to have different base names ($file)")
    if (exists $sys_short{$file});
  my $xtra = sprintf("${note_key}_%03d", $annot_count++);
  $sys_files{$f} = $xtra;
  $sys_short{$file} = $f;
  print "SYS file: $sf (xtra attribute used: $xtra)\n";
}

########## Validating input files
print "\n\n***** STEP ", $stepc++, ": Validating input files\n";

my $ref_dir = MMisc::get_file_full_path("$wid/$ref_val_md_dir");
&die_mkdir($ref_dir, "REF");
my $sys_dir = MMisc::get_file_full_path("$wid/$sys_val_md_dir");
&die_mkdir($sys_dir, "SYS");

my $val_add = "";
$val_add .= "-F $forceFilename " if (! MMisc::is_blank($forceFilename));

my $ref_switch = "-g";
$ref_switch = "-C" if ($cREFt);
print "Validating REF file\n";
my ($dir, $file, $ext) = &die_split_dfe($master_ref);
my $log = MMisc::concat_dir_file_ext($ref_dir, $file, $log_add);
my $command = "$validator $val_add $master_ref -w $ref_dir -W text $ref_switch";
&die_syscall_logfile($log, "REF validation command", $command);

my $sys_switch = "";
$sys_switch = "-C -g" if ($cSYSt);
print "Validating SYS files\n";
foreach my $sf (sort keys %sys_files) {
  my ($dir, $file, $ext) = &die_split_dfe($sf);
  my $log = MMisc::concat_dir_file_ext($sys_dir, $file, $log_add);
  my $xtra = $sys_files{$sf};
  my $command = "$validator $val_add $sf -w $sys_dir -W text -a $xtra:$sf -A $sys_switch";
  &die_syscall_logfile($log, "SYS validation command", $command);
}

########## Align SYSs to REF
print "\n\n***** STEP ", $stepc++, ": Align SYSs to REF\n";

my ($dir, $file, $ext) = &die_split_dfe($master_ref, "\'master_ref\'");
my $master_ref_md = MMisc::concat_dir_file_ext($ref_dir, $file, $ext . "$md_add");
&die_check_file_r($master_ref_md, "REF");

my %sc1_sys_files = ();
foreach my $sf (sort keys %sys_files) {
  my ($dir, $file, $ext) = &die_split_dfe($sf, "SYS");
  my $sf_md = MMisc::concat_dir_file_ext($sys_dir, $file, $ext . "$md_add");
  &die_check_file_r($sf_md, "SYS");
  
  my $bodir = MMisc::get_file_full_path("$wid/$first_align");
  my $odir = "$bodir/$file";
  &die_mkdir($odir, "SYS");

  my $log = MMisc::concat_dir_file_ext($bodir, $file, $log_add);
  my $command = "$scorer -w $odir -p -f $fps $sf_md -g $master_ref_md -d 0.5 -D $duration -a -s";

  print "* Scoring [$file]\n";
  &die_syscall_logfile($log, "scoring command", $command);

  my ($ofile) = &die_list_X_files(1, $odir, "$file scoring");
  $sc1_sys_files{$file} = "$odir/$ofile";
}

########## Only keeping Unmapped_Sys entries
print "\n\n***** STEP ", $stepc++, ": Only keeping Unmapped_Sys entries\n";

my $usys_dir = MMisc::get_file_full_path("$wid/$first_remove");

my %sc2_sys_files = ();
foreach my $sf (sort keys %sc1_sys_files) {
  my $odir = "$usys_dir/$sf";
  &die_mkdir($odir, "$sf");

  my $rsf = $sc1_sys_files{$sf};
  &die_check_file_r($rsf, "SYS file");

  my $log = MMisc::concat_dir_file_ext($odir, $sf, $log_add);
  my $command = "$validator $rsf -w $odir -W text -l *:Unmapped_Sys -r";

  print "* Only keeping Unmapped_Sys and removing subtypes [$sf]\n";
  &die_syscall_logfile($log, "validating command", $command);

  my (@ofiles) = &die_list_X_files(3, $odir, "$sf validating");
  my @tmp = grep(! m%($md_add|$log_add)$%, @ofiles);
  MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
    if (scalar @tmp != 1);
  my $ofile = $tmp[0];
  $sc2_sys_files{$sf} = "$odir/$ofile";
}

########## Iteration
print "\n\n***** STEP ", $stepc++, ": Iteration\n";

my $inc = 0;
my @todo = sort keys %sc2_sys_files;
my $csf_key = shift @todo;
my $csf = $sc2_sys_files{$csf_key};

my $ftxt = $csf_key;
while (scalar @todo > 0) {
  my $inc_in = 1;
  $inc++;

  my $vs = shift @todo;
  my $vsf = $sc2_sys_files{$vs};

  print "* Working on [$ftxt] vs [$vs]\n";

  # Convert SYS to REF
  my $mode = "SYS2REF";
  my $mode_txt = "Converting SYS to REF";
  my $odir = &die_do_incin_dir($inc, $inc_in++, "$wid/$iteration_step", $mode, $mode_txt);
  my $log = MMisc::concat_dir_file_ext($odir, $mode, $log_add);
  my $command = "$validator $csf -w $odir -W text -C -p";
  print "  -> $mode_txt\n";
  &die_syscall_logfile($log, $mode_txt, $command);

  my (@ofiles) = &die_list_X_files(3, $odir, "$mode");
  my @tmp = grep(m%$md_add$%, @ofiles);
  MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
    if (scalar @tmp != 1);
  my $ofile = $tmp[0];
  $csf = "$odir/$ofile";

  # Score New REF to SYS
  $mode = "Scoring";
  my $mode_txt = "Scoring SYS to new REF";
  my $odir = &die_do_incin_dir($inc, $inc_in++, "$wid/$iteration_step", $mode, $mode_txt);
  my $log = MMisc::concat_dir_file_ext($odir, $mode, $log_add);
  my $command = "$scorer -w $odir -p -f $fps $vsf -g $csf -d 0.5 -D $duration -a -s -X extended";
  print "  -> $mode_txt\n";
  &die_syscall_logfile($log, $mode_txt, $command);

  my (@ofiles) = &die_list_X_files(2, $odir, "$mode");
  my @tmp = grep(! m%$log_add$%, @ofiles);
  MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
    if (scalar @tmp != 1);
  my $ofile = $tmp[0];
  $csf = "$odir/$ofile";
  
  # Removing subtypes
  $mode = "Removing_Subtypes";
  my $mode_txt = "Removing Subtypes";
  my $odir = &die_do_incin_dir($inc, $inc_in++, "$wid/$iteration_step", $mode, $mode_txt);
  my $log = MMisc::concat_dir_file_ext($odir, $mode, $log_add);
  my $command = "$validator $csf -w $odir -r -p";
  print "  -> $mode_txt\n";
  &die_syscall_logfile($log, $mode_txt, $command);

  my (@ofiles) = &die_list_X_files(2, $odir, "$mode");
  my @tmp = grep(! m%$log_add$%, @ofiles);
  MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
    if (scalar @tmp != 1);
  my $ofile = $tmp[0];
  $csf = "$odir/$ofile";

  $ftxt = "Previous Scoring SYS result";
}

########## Aligning Master REF to Empty SYS
print "\n\n***** STEP ", $stepc++, ": Aligning Master REF to Empty SYS\n";
print "Master REF: $master_ref_md\n";

print "* Generating Empty SYS\n";

my $final_sc_dir = MMisc::get_file_full_path("$wid/$UnRef_step1");
&die_mkdir($final_sc_dir, "empty SYS");

my $log_dir = MMisc::get_file_full_path("$wid/$UnRef_base");
my $log = MMisc::concat_dir_file_ext($log_dir, "empty_SYS", $log_add);
my $command = "$validator -R AllEvents -w $final_sc_dir $csf";

&die_syscall_logfile($log, "validating command", $command);

my ($empty_sys) = &die_list_X_files(1, $final_sc_dir, "result");
$empty_sys = MMisc::concat_dir_file_ext($final_sc_dir, $empty_sys, "");

#####
print "* Alignment\n";

my $final_sc_dir = MMisc::get_file_full_path("$wid/$UnRef_step2");
&die_mkdir($final_sc_dir, "REF2SYS");

my $log = MMisc::concat_dir_file_ext($log_dir, "scoring", $log_add);
my $command = "$scorer -w $final_sc_dir -p -f $fps $empty_sys -g $master_ref_md -d 0.5 -D $duration -a -s";

&die_syscall_logfile($log, "scoring command", $command);

my ($UnRef_file) = &die_list_X_files(1, $final_sc_dir, "scoring");
$UnRef_file = MMisc::concat_dir_file_ext($final_sc_dir, $UnRef_file, "");

########## Aligning Empty REF to Final SYS
print "\n\n***** STEP ", $stepc++, ": Aligning Master REF to Empty SYS\n";
print "Final SYS : $csf\n";

print "* Generating Empty REF\n";

my $final_sc_dir = MMisc::get_file_full_path("$wid/$UnSys_step1");
&die_mkdir($final_sc_dir, "empty REF");

my $log_dir = MMisc::get_file_full_path("$wid/$UnSys_base");
my $log = MMisc::concat_dir_file_ext($log_dir, "empty_REF", $log_add);
my $command = "$validator -R AllEvents -w $final_sc_dir -g $master_ref_md";

&die_syscall_logfile($log, "validating command", $command);

my ($empty_ref) = &die_list_X_files(1, $final_sc_dir, "result");
$empty_ref = MMisc::concat_dir_file_ext($final_sc_dir, $empty_ref, "");

#####
print "* Alignment\n";

my $final_sc_dir = MMisc::get_file_full_path("$wid/$UnSys_step2");
&die_mkdir($final_sc_dir, "REF2SYS");

my $log = MMisc::concat_dir_file_ext($log_dir, "scoring", $log_add);
my $command = "$scorer -w $final_sc_dir -p -f $fps $csf -g $empty_ref -d 0.5 -D $duration -a -s";

&die_syscall_logfile($log, "scoring command", $command);

my ($UnSys_file) = &die_list_X_files(1, $final_sc_dir, "scoring");
$UnSys_file = MMisc::concat_dir_file_ext($final_sc_dir, $UnSys_file, "");

########## Creating Adjudication ViPERfiles
print "\n\n***** STEP ", $stepc++, ": Creating Adjudication ViPERfiles\n";
$adjudicate_only = 0; # Turn off

print "Unmapped_REF : $UnRef_file\n";
print "Unmapped_SYS : $UnSys_file\n";

my $ad_add = "-seg_margin_$margin";
my $adj_dir = MMisc::get_file_full_path("$wid/$AdjDir$ad_add");
&die_mkdir($adj_dir, "Adjudication Directory");

my $log = MMisc::concat_dir_file_ext($adj_dir, "Adjudication_Run", $log_add);
my $command = "$adjtool -f $fps -d $adj_dir -a $note_key -s $margin $UnRef_file $UnSys_file";

&die_syscall_logfile($log, "adjudication command", $command);

print "\nAdjudication directory: $adj_dir\n";

my @tfl = &die_list_X_files(0, $adj_dir, "Adjudication results");
my @fl = grep(! m%$log_add$%, @tfl);
MMisc::error_quit("No files in directory")
  if (scalar @fl == 0);

print "\nAdjudication files:\n - ", join("\n - ", sort @fl), "\n";

MMisc::ok_quit("Done\n");

##############################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

##########

sub die_check_file_r {
  my ($file, $text) = @_;

  $err = MMisc::check_file_r($file);
  MMisc::error_quit("Problem with $text file ($file): $err")
    if (! MMisc::is_blank($err));
}

#####

sub die_mkdir {
  my ($dir, $text) = @_;

  MMisc::error_quit("Could not create $text dir ($dir)")
    if (! MMisc::make_dir($dir));
}

#####

sub die_split_dfe {
  my ($filename, $text) = @_;

  my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($filename);
  MMisc::error_quit("Problem splitting $text filename ($filename) into dir/file/ext: $err")
    if (! MMisc::is_blank($err));

  return($dir, $file, $ext);
}

#####

sub die_syscall_logfile {
  my ($file, $txt, @command) = @_;

  if ($adjudicate_only) {
    print "    [## Adjudicate only requested ##] Skipping \'$txt\'\n";
    return();
  }

  my ($ok, $rtxt, $stdout, $stderr, $retcode) =
    MMisc::write_syscall_logfile($file, @command);
  MMisc::error_quit("Problem when running $txt\nSTDOUT:$stdout\nSTDERR:\n$stderr\n")
    if ($retcode != 0);

  print "    (Ran \"$txt\", see log at: $file)\n";
}

#####

sub die_list_X_files {
  my ($x, $dir, $txt) = @_;
  # x = 0 : unlimited

  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($dir);
  MMisc::error_quit("Problem listing $txt directory ($dir): $err")
    if (! MMisc::is_blank($err));

  MMisc::error_quit("Found directories in $txt dir ($dir): " . join(" ", @$rd))
    if (scalar @$rd > 0);

  MMisc::error_quit("Found different than $x files in $txt dir ($dir): " . join(" ", @$rf))
    if (($x) && (scalar @$rf != $x));

  return(@$rf);
}

#####

sub die_do_incin_dir {
  my ($inc, $inc_in, $dirb, $dira, $txt) = @_;

  my $t = sprintf("%03d_%02d-$dira", $inc, $inc_in);

  my $dir = MMisc::get_file_full_path("$dirb/$t");
  &die_mkdir($dir, "SYS2REF");

  return($dir);
}

############################################################

sub set_usage {
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--TrecVid08xsd location] [--Validator location] [--Scorer location] [--Adjudication location] [--changeREFtype] [--ChangeSYStype] [--ForceFilename filename] [--segmentation_margin value] [--adjudication_only] --fps fps --Duration seconds --work_in_dir dir ref_file sys_files

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --Validator     Full path location of the TV08Validator program
  --Scorer        Full path location of the TV08Scorer program
  --Adjudicator   Full path location of the Adjudicator program
  --changeREFtype   Will convert the 'ref_file' from SYS to REF
  --ChangeSYStype   Will convert all 'sys_file's from REF to SYS
  --ForceFilename Replace the 'sourcefile' file value
  --segmentation_margin  Add +/- value frames to each observation when computing its possible candidates for overlap (default: $margind)
  --adjudication_only    Only run the program in the adjudication step
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --Duration      Specify the scoring duration for the Metric (warning: override any ECF file)
  --work_in_dir   Directory where all the output an temporary files will be geneated

Note:
- This prerequisite that the XML files can be been validated using 'xmllint' against the 'TrecVid08.xsd' file
- 'TrecVid08xsd' files are: $xsdfiles
EOF
    ;

    return $tmp;
}
