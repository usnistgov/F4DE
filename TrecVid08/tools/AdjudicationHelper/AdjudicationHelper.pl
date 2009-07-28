#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 Adjudication Helper
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Adjudication Helper" is an experimental system.
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

my $versionid = "TrecVid08 Adjudication Helper Version: $version";

### TEST Command line: ./AdjudicationHelper.pl -f 25 -D 400 -w 2 ref.xgtf sys_*

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../lib", "../../../common/lib");
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
foreach my $pn ("TrecVid08ViperFile", "TrecVid08HelperFunctions", "MMisc") {
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

my $xmllint_env = "F4DE_XMLLINT";
my $margin_d = 75;
my $validator_d = "../TV08ViperValidator/TV08ViperValidator.pl";
my $scorer_d = "../TV08Scorer/TV08Scorer.pl";
my $adjtool_d = "./Adjudicator.pl";

my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../data";
my $fps = undef;
my $verb = 0;
my $wid = "";
my $duration = undef;
my $margin = $margin_d;
my $cREFt = 0;
my $cSYSt = undef;
my $forceFilename = "";
my $adjudicate_only = 0;
my $deltat = undef;
my $validator = "";
my $scorer = "";
my $adjtool = "";
my $info_path = "";
my $info_g = "";
my $jpeg_path = "";
my $pds = 0;
my $warn_nf = 0;
my $nonglob = 0;
my $minAgree = 0;
my $mad = 0;
my $smartglob = undef;
my $rmREFfromSYS = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: A CD    I   M     ST VW   a cd f hij  mn p rs  vwx   #

my $fcmdline = "$0 " . join(" ", @ARGV);

my %opt = ();
my @args = ();
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
   'ChangeSYStype:s' => \$cSYSt,
   'ForceFilename=s' => \$forceFilename,
   'adjudicate_only' => \$adjudicate_only,
   'delta_t=f'       => \$deltat,
   'info_path=s'     => \$info_path,
   'InfoGenerator=s' => \$info_g,
   'jpeg_path=s'     => \$jpeg_path,
   'percentDS'       => \$pds,
   'Warn_numframes'  => \$warn_nf,
   'nonGlobing'      => \$nonglob,
   'minAgree=i'      => \$minAgree,
   'MakeAgreeDir'    => \$mad,
   'globSmart=i'     => \$smartglob,
   'rerunMasterREFvsSYS' => \$rmREFfromSYS,
   '<>'              => sub { push @args, @_ },
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Not doing adjudication work on only on one REF and one SYS file")
  if (scalar @args < 3);

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

MMisc::error_quit("\'delta_t\' is not set, aborting")
  if (! defined $deltat);

if (defined $smartglob) {
  MMisc::error_quit("Not doing both \'nonGlobing\' and \'globSmart\' at the same time")
      if ($nonglob);
  MMisc::error("\"globSmart\" value must be 1 or more")
      if ($smartglob < 1);
}

MMisc::error_quit("\'info_path\' can only be used if \'InfoGenerator\' is used")
  if ((MMisc::is_blank($info_g)) && (! MMisc::is_blank($info_path)));
MMisc::error_quit("\'jpeg_path\' can only be used if \'InfoGenerator\' is used")
  if ((MMisc::is_blank($info_g)) && (! MMisc::is_blank($jpeg_path)));

print "[COMMANDLINE] [$fcmdline]\n";

########## Main processing
my $note_key = "NOTE_KEY";

$validator = "$validator_d $validator"
  if ($validator =~ m%^\-%);
$scorer = "$scorer_d $scorer"
  if ($scorer =~ m%^\-%);
$adjtool = "$adjtool_d $adjtool"
  if ($adjtool =~ m%^\-%);

$validator = $validator_d 
  if (MMisc::is_blank($validator));
$scorer = $scorer_d 
  if (MMisc::is_blank($scorer));
$adjtool = $adjtool_d 
  if (MMisc::is_blank($adjtool));

$validator .= " $cmdline_add";
$scorer    .= " $cmdline_add";
$adjtool   .= " $cmdline_add";

my $adjtool_spadd = "";
if (scalar @ARGV > 0) {
  $adjtool_spadd = "-- " . join(" ", @ARGV);
  print "(Will add [$adjtool_spadd] to [$adjtool] command line)\n";
}

my $md_add = TrecVid08HelperFunctions::get_MemDump_Suffix();

my $log_add  = "log";
my $info_add = "info";

my $dtadd = "-deltat_$deltat";

my $empty_ref_dir  = "00-empty_REF";
my $val_md_dir     = "01-Validate";
my $ref_val_md_dir = "$val_md_dir/REF";
my $sys_val_md_dir = "$val_md_dir/SYS";
my $GTFvsSYS_dir   = "02-MasterREF_vs_SYS";
sub get_first_align {my($v)=@_;return(sprintf("$GTFvsSYS_dir/%02d-1-First_Alignment", $v));}
sub get_first_remove {my($v)=@_;return(sprintf("$GTFvsSYS_dir/%02d-2-Only_Unmapped_Sys", $v));}
my $iteration_step = "03-Iterations";
my $UnRef_base     = "04-Unmapped_Ref";
my $UnRef_step1    = "$UnRef_base/1-empty_SYS";
my $UnRef_step2    = "$UnRef_base/2-Master_REF_vs_empty_SYS";
my $UnSys_base     = "05-Unmapped_Sys";
my $UnSys_step1    = "$UnSys_base/1-empty_REF";
my $UnSys_step2    = "$UnSys_base/2-empty_REF_vs_Final_SYS";
my $AdjDir         = "06-Adjudication_ViPERfiles";
my $NGAdjDir       = "06-Non_Globing-Adjudication_ViPERfiles";
my $SGAdjDir       = "06-Smart_Globing-Adjudication_ViPERfiles";

my $stepc = 1;

########## Generating Empty Master REF file
my $mf = shift @args;

if ($mf eq "_blank_") {
  print "\n\n***** STEP ", $stepc++, ": Generating Empty Master REF file\n";

  # Use the first SYS file
  my $sf = $args[0];
  my $f = MMisc::get_file_full_path($sf);
  &die_check_file_r($f, "SYS file used to make Empty Master REF");

  my $mrd = MMisc::get_file_full_path("$wid/$empty_ref_dir");
  &die_mkdir($mrd, "empty Master REF");

  my $log = MMisc::concat_dir_file_ext($mrd, "empty_Master_REF", $log_add);
  my $command = "$validator -R AllEvents -w $mrd -W text $f -p";
  if (defined $cSYSt) { # if the SYS are really a GTF
    $command .= " -g";
  } else { # otherwise, we need to change its type
    $command .= " -C";
  }

  &die_syscall_logfile($log, "validating command", $command);

  my @ofiles = &die_list_X_files(3, $mrd, "result");
  my @tmp = grep(m%$md_add$%, @ofiles);
  MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
    if (scalar @tmp != 1);

  $mf = "$mrd/" . $tmp[0];
}


########## Confirming input files
print "\n\n***** STEP ", $stepc++, ": Confirming input files\n";

my $master_ref = MMisc::get_file_full_path($mf);
print "MASTER REF file: $master_ref\n";
&die_check_file_r($master_ref, "REF");

my $annot_count = 1;
my %sys_files = ();
my %sys_short = ();
my @order_of_things = ();
foreach my $sf (@args) {
  my $f = MMisc::get_file_full_path($sf);
  &die_check_file_r($f, "SYS");
  MMisc::error_quit("The same SYS file ($f) can not be used multiple time")
    if (exists $sys_files{$f});
  my ($dir, $onfile, $ext) = &die_split_dfe($f, "SYS file");
  my $file = MMisc::concat_dir_file_ext("", $onfile, $ext);
  MMisc::error_quit("SYS files ought to have different names ($file)")
    if (exists $sys_short{$file});
  my $xtra = sprintf("${note_key}_%03d", $annot_count++);
  $sys_files{$f} = $xtra;
  $sys_short{$file} = $f;
  print "SYS file: $sf (xtra attribute used: $xtra)\n";
  push @order_of_things, $f;
}

########## Validating input files
print "\n\n***** STEP ", $stepc++, ": Validating input files\n";

## REF

my $ref_dir = MMisc::get_file_full_path("$wid/$ref_val_md_dir");
&die_mkdir($ref_dir, "REF");

my $val_add = "";
$val_add .= "-F $forceFilename " 
  if (! MMisc::is_blank($forceFilename));

my $ref_switch = "-g";
$ref_switch = "-C" if ($cREFt);
print "Validating REF file\n";
my ($dir, $onfile, $ext) = &die_split_dfe($master_ref, "Master REF file");
my $file = MMisc::concat_dir_file_ext("", $onfile, $ext);
my $log = MMisc::concat_dir_file_ext($ref_dir, $file, $log_add);
my $command = "$validator $val_add $master_ref -w $ref_dir -W text $ref_switch";
&die_syscall_logfile($log, "REF validation command", $command);
my @ofiles = &die_list_X_files(3, $ref_dir, "REF Validation result");
my @tmp = grep(m%$md_add$%, @ofiles);
MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
  if (scalar @tmp != 1);
my $master_ref_md = "$ref_dir/" . $tmp[0];

## SYS

my $sys_dir_base = MMisc::get_file_full_path("$wid/$sys_val_md_dir");
my $sys_dir = ($pds) ? "$sys_dir_base/00-Before_percentDS" : $sys_dir_base;
&die_mkdir($sys_dir, "SYS");

my $sys_switch = "";
if (defined $cSYSt) {
  my $v = (MMisc::is_blank($cSYSt)) ? "" : " $cSYSt";
  $sys_switch = "-C$v -g" 
}
print "Validating SYS files\n";
foreach my $sf (@order_of_things) {
  my ($dir, $onfile, $ext) = &die_split_dfe($sf ,"SYS file");
  my $file = MMisc::concat_dir_file_ext("", $onfile, $ext);
  my $log = MMisc::concat_dir_file_ext($sys_dir, $file, $log_add);
  my $xtratxt = "";
  if (! $pds) { # Do not add the xtraTrackingComment just yet if 'percentDS'
    my $xtra = $sys_files{$sf};
    $xtratxt = "-a $xtra:$sf -A";
  }
  my $command = "$validator $val_add $sf -w $sys_dir -W text $xtratxt $sys_switch";
  &die_syscall_logfile($log, "SYS validation command", $command);
}

if ($pds) {
  print "Adjusting Detection Score to 100 % max [0 -> 1]\n";

  # First, get the values to work with
  my @xf = ();
  foreach my $sf (@order_of_things) {
    my ($dir, $onfile, $ext) = &die_split_dfe($sf ,"SYS file");
    my $file = MMisc::concat_dir_file_ext($sys_dir, $onfile, $ext . (($ext =~ m%$md_add$%) ? "" : $md_add));
    push @xf, $file;
  }
  my $log = MMisc::concat_dir_file_ext($sys_dir_base, "find_global", $log_add);
  my $command = "$validator -G -f $fps " . join(" ", @xf);
  &die_syscall_logfile($log, "Obtaining Global Range and Global Min Values", $command);

  my ($gmin, $grange) = &extract_gmin_grange_from_log($log);
  print "Found: Global min = $gmin / Global range = $grange\n";

  if ($grange == 0) {
    MMisc::warn_print("          @@@@@@@@@@ Global range is 0 / Forcing \'1\' @@@@@@@@@@");
    $grange = 1;
  }

  # Then apply those values
  my $sys_dir_pds = "$sys_dir_base/01-After_percentDS";
  &die_mkdir($sys_dir_pds, "percent DS SYS");
  my $log = MMisc::concat_dir_file_ext($sys_dir_pds, "apply_global", $log_add);
  my $command = "$validator -G -V $grange:$gmin -f $fps -w $sys_dir_pds -W text " . join(" ", @xf);
  &die_syscall_logfile($log, "Applying Global Range and Global Min Values", $command);

  my ($gmin, $grange) = &extract_gmin_grange_from_log($log);
  print "FINAL: Global min = $gmin / Global range = $grange\n";
  
  # Finaly, get the final Validated MemDump _WITH_ the xtraTrackingComment
  $sys_dir = $sys_dir_base;
  foreach my $sf (@order_of_things) {
    my ($dir, $onfile, $ext) = &die_split_dfe($sf ,"SYS file");
    my $file = MMisc::concat_dir_file_ext("", $onfile, $ext);
    my $infile = MMisc::concat_dir_file_ext($sys_dir_pds, $onfile, $ext . (($ext =~ m%$md_add$%) ? "" : $md_add));
    my $log = MMisc::concat_dir_file_ext($sys_dir, $file, $log_add);
    my $xtra = $sys_files{$sf};
    my $command = "$validator $val_add $infile -w $sys_dir -W text -a $xtra:$sf -A";
    &die_syscall_logfile($log, "Post \'percentDS\' SYS MemDump + Xtra adds", $command);
  }
}

########## Align SYSs to Master REF
print "\n\n***** STEP ", $stepc++, ": Align SYSs to Master REF\n";

&die_check_file_r($master_ref_md, "Validated REF");

my @lsysf = ();
my @lfilel = ();
my %score_sf = ();
foreach my $sf (@order_of_things) {
  my ($dir, $onfile, $ext) = &die_split_dfe($sf, "SYS");
  my $file = MMisc::concat_dir_file_ext("", $onfile, $ext);
  my $sf_md = MMisc::concat_dir_file_ext($sys_dir, $file, (($file =~ m%$md_add$%) ? "" : "$md_add"));
  &die_check_file_r($sf_md, "SYS");
  push @lsysf, $sf_md;
  push @lfilel, $file;
  $score_sf{$sf} = 1;
}

my %sc1_sys_files = ();
my %sc1_mapt = ();

my %sc2_sys_files = ();
my %sc2_mapt = ();

my $mrscit = 0;
my $redo_mrscit = ($rmREFfromSYS) ? 1 : 0;
my %prev_csv = ();
do {
  print "*** SYSs vs Master REF (Iteration: $mrscit)\n";
  my @nlsysf = ();
  for (my $i = 0; $i < scalar @order_of_things; $i++) {
    my $sf = $order_of_things[$i];
    next if ($score_sf{$sf} == 0);
    my $sf_md = $lsysf[$i];
    my $file = $lfilel[$i];
    my $bodir = MMisc::get_file_full_path("$wid/" . &get_first_align($mrscit));
    my $odir = "$bodir/$file$dtadd";
    &die_mkdir($odir, "SYS");
    
    my $log = MMisc::concat_dir_file_ext($bodir, "$file$dtadd", $log_add);
    my $command = "$scorer -w $odir -W text -p -f $fps $sf_md -g $master_ref_md -d $deltat -D $duration -a -s";
    
    print "* Scoring [$file]\n";
    &die_syscall_logfile($log, "scoring command", $command);
    
    my @ofiles = &die_list_X_files(2, $odir, "$file scoring");
    my ($ofile) = grep(m%$md_add$%, @ofiles);
    $sc1_mapt{$sf} = $file;
    $sc1_sys_files{$file} = "$odir/$ofile";
  }
  
  ## Only keeping Unmapped_Sys entries
  print "*** Only keeping Unmapped_Sys entries (Iteration: $mrscit)\n";
  
  my $usys_dir = MMisc::get_file_full_path("$wid/" . &get_first_remove($mrscit));
  
  foreach my $tsf (@order_of_things) {
    if ($score_sf{$tsf} == 0) {
      push @nlsysf, "NO FILE THERE";
      next;
    }
    MMisc::error_quit("KEY NOT FOUND [$tsf]")
      if (! exists $sc1_mapt{$tsf});
    my $sf = $sc1_mapt{$tsf};
    MMisc::error_quit("KEY2 NOT FOUND [$sf]")
      if (! exists $sc1_sys_files{$sf});
    
    my $odir = "$usys_dir/$sf$dtadd";
    &die_mkdir($odir, "$sf");
    
    my $rsf = $sc1_sys_files{$sf};
    &die_check_file_r($rsf, "SYS file");
    
    my $log = MMisc::concat_dir_file_ext($odir, $sf, $log_add);
    my $command = "$validator $rsf -w $odir -W text -l *:Unmapped_Sys -r";
    
    my $efn = 2;
    if ($rmREFfromSYS) {
      $command .= " --DumpCSV EventType,Framespan -f $fps";
      $efn = 3;
    }

    print "* Only keeping Unmapped_Sys and removing subtypes [$sf]\n";
    &die_syscall_logfile($log, "validating command", $command);
    
    my (@ofiles) = &die_list_X_files($efn + 1, $odir, "$sf validating");
    my @tmp = grep(! m%$log_add$%, @ofiles);
    MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected ($efn) : " . join(" ", @tmp))
      if (scalar @tmp != $efn);
    my ($ofile) = grep(m%$md_add$%, @tmp);
    $sc2_mapt{$tsf} = $sf;
    my $nsysf = "$odir/$ofile";
    my $err = MMisc::check_file_r($nsysf);
    MMisc::error_quit("Problem with new SYS file ($nsysf): $err")
      if (! MMisc::is_blank($err));
    $sc2_sys_files{$sf} = $nsysf;
    push @nlsysf, $nsysf;

    if ($rmREFfromSYS) {
      my ($lcsvf) = grep(m%\.csv$%i, @tmp);
      my $csvf = "$odir/$lcsvf";
      MMisc::error_quit("Could not find expected CSV file ($csvf)")
        if (! MMisc::is_file_r($csvf));
      
      if (exists $prev_csv{$tsf}) {
        my $lcont = &are_csv_content_different($prev_csv{$tsf}, $csvf);
        if ($lcont == 0) {
          print "  -> [$sf] converged in $mrscit iteration(s)\n";
          $score_sf{$tsf} = 0;
        }
      }
      $prev_csv{$tsf} = $csvf;
    }

  }
  @lsysf = @nlsysf;

  if ($redo_mrscit) {
    my $tmpc = 0;
    foreach my $key (keys %score_sf) {
      $tmpc += $score_sf{$key};
    }
    $redo_mrscit = $tmpc;
    print "*** All files have converged\n"
      if ($redo_mrscit == 0);
  }

  $mrscit++;
} until ($redo_mrscit == 0);

########## Iteration
print "\n\n***** STEP ", $stepc++, ": Iteration\n";

my $inc = 0;
my @todo = ();
foreach my $k (@order_of_things) {
  push @todo, $sc2_mapt{$k};
}
MMisc::error_quit("No elements in SYS list, aborting")
  if (scalar @todo == 0);
my $csf_key = shift @todo;
my $csf = $sc2_sys_files{$csf_key};

MMisc::error_quit("No elements left in SYS list, aborting")
  if (scalar @todo == 0);

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
  my $odir = &die_do_incin_dir($inc, $inc_in++, "$wid/$iteration_step", $mode, $mode_txt, $dtadd);
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
  my $odir = &die_do_incin_dir($inc, $inc_in++, "$wid/$iteration_step", $mode, $mode_txt, $dtadd);
  my $log = MMisc::concat_dir_file_ext($odir, $mode, $log_add);
  my $command = "$scorer -w $odir -W text -p -f $fps $vsf -g $csf -d $deltat -D $duration -a -s -X extended";
  print "  -> $mode_txt\n";
  &die_syscall_logfile($log, $mode_txt, $command);

  my (@ofiles) = &die_list_X_files(3, $odir, "$mode");
  my @tmp = grep(m%$md_add$%, @ofiles);
  MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
    if (scalar @tmp != 1);
  my $ofile = $tmp[0];
  $csf = "$odir/$ofile";

  # Removing subtypes
  $mode = "Removing_Subtypes";
  my $mode_txt = "Removing Subtypes";
  my $odir = &die_do_incin_dir($inc, $inc_in++, "$wid/$iteration_step", $mode, $mode_txt, $dtadd);
  my $log = MMisc::concat_dir_file_ext($odir, $mode, $log_add);
  my $command = "$validator $csf -w $odir -W text -r -p";
  print "  -> $mode_txt\n";
  &die_syscall_logfile($log, $mode_txt, $command);

  my (@ofiles) = &die_list_X_files(3, $odir, "$mode");
  my @tmp = grep(m%$md_add$%, @ofiles);
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

my $final_sc_dir = MMisc::get_file_full_path("$wid/$UnRef_step1$dtadd");
&die_mkdir($final_sc_dir, "empty SYS");

my $log_dir = MMisc::get_file_full_path("$wid/$UnRef_base");
my $log = MMisc::concat_dir_file_ext($log_dir, "empty_SYS$dtadd", $log_add);
my $command = "$validator -R AllEvents -w $final_sc_dir -W text $csf";

&die_syscall_logfile($log, "validating command", $command);

my @ofiles = &die_list_X_files(2, $final_sc_dir, "result");
my @tmp = grep(m%$md_add$%, @ofiles);
MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
  if (scalar @tmp != 1);
my $empty_sys = $tmp[0];
$empty_sys = MMisc::concat_dir_file_ext($final_sc_dir, $empty_sys, "");

#####
print "* Alignment\n";

my $final_sc_dir = MMisc::get_file_full_path("$wid/$UnRef_step2$dtadd");
&die_mkdir($final_sc_dir, "REF2SYS");

my $log = MMisc::concat_dir_file_ext($log_dir, "scoring$dtadd", $log_add);
my $command = "$scorer -w $final_sc_dir -W text -p -f $fps $empty_sys -g $master_ref_md -d $deltat -D $duration -a -s";

&die_syscall_logfile($log, "scoring command", $command);

my @files = &die_list_X_files(2, $final_sc_dir, "scoring");
my @tmp = grep(m%$md_add$%, @ofiles);
MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
  if (scalar @tmp != 1);
my $UnRef_file = $tmp[0];
$UnRef_file = MMisc::concat_dir_file_ext($final_sc_dir, $UnRef_file, "");

########## Aligning Empty REF to Final SYS
print "\n\n***** STEP ", $stepc++, ": Aligning Empty REF to Final SYS\n";
print "Final SYS : $csf\n";

print "* Generating Empty REF\n";

my $final_sc_dir = MMisc::get_file_full_path("$wid/$UnSys_step1$dtadd");
&die_mkdir($final_sc_dir, "empty REF");

my $log_dir = MMisc::get_file_full_path("$wid/$UnSys_base");
my $log = MMisc::concat_dir_file_ext($log_dir, "empty_REF$dtadd", $log_add);
my $command = "$validator -R AllEvents -w $final_sc_dir -W text -g $master_ref_md";

&die_syscall_logfile($log, "validating command", $command);

my @ofiles = &die_list_X_files(2, $final_sc_dir, "result");
my @tmp = grep(m%$md_add$%, @ofiles);
MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
  if (scalar @tmp != 1);
my $empty_ref = $tmp[0];
$empty_ref = MMisc::concat_dir_file_ext($final_sc_dir, $empty_ref, "");

#####
print "* Alignment\n";

my $final_sc_dir = MMisc::get_file_full_path("$wid/$UnSys_step2$dtadd");
&die_mkdir($final_sc_dir, "REF2SYS");

my $log = MMisc::concat_dir_file_ext($log_dir, "scoring$dtadd", $log_add);
my $command = "$scorer -w $final_sc_dir -W text -p -f $fps $csf -g $empty_ref -d $deltat -D $duration -a -s";

&die_syscall_logfile($log, "scoring command", $command);

my @ofiles = &die_list_X_files(2, $final_sc_dir, "scoring");
my @tmp = grep(m%$md_add$%, @ofiles);
MMisc::error_quit("Found different amount of files (" . scalar @tmp . ") than expected (1) : " . join(" ", @tmp))
  if (scalar @tmp != 1);
my $UnSys_file = $tmp[0];
$UnSys_file = MMisc::concat_dir_file_ext($final_sc_dir, $UnSys_file, "");

########## Creating Adjudication ViPERfile
print "\n\n***** STEP ", $stepc++, ": Creating Adjudication ViPERfile\n";
$adjudicate_only = 0; # Turn off

print "Unmapped_REF : $UnRef_file\n";
print "Unmapped_SYS : $UnSys_file\n";

my $adadd = "-seg_margin_$margin";
my $tadjdir = ($nonglob) ? $NGAdjDir : ((defined $smartglob) ? $SGAdjDir : $AdjDir);
my $adj_dir = MMisc::get_file_full_path("$wid/$tadjdir$dtadd$adadd");
&die_mkdir($adj_dir, "Adjudication Directory");

my $log = MMisc::concat_dir_file_ext($adj_dir, "Adjudication_Run", $log_add);
my $command = "$adjtool -f $fps -d $adj_dir -a $note_key -s $margin $UnRef_file $UnSys_file";
$command .= " -I $info_g" if (! MMisc::is_blank($info_g));
$command .= " -i $info_path" if (! MMisc::is_blank($info_path));
$command .= " -j $jpeg_path" if (! MMisc::is_blank($jpeg_path));
$command .= " -W" if ($warn_nf);
$command .= " -c" if ($mad);
$command .= " -m $minAgree" if ($minAgree > 0);
$command .= " -o -r" if ($nonglob);
$command .= " -S $smartglob -r" if (defined $smartglob);
$command .= " $adjtool_spadd" if (! MMisc::is_blank($adjtool_spadd));

&die_syscall_logfile($log, "adjudication command", $command);

print "\nAdjudication directory: $adj_dir\n";

my @fl = ();
if ($mad) {
  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($adj_dir);
  MMisc::error_quit("Problem listing directory ($adj_dir): $err")
      if (! MMisc::is_blank($err));
  foreach my $tdir (@{$rd}) {
    my @tfl = &die_list_X_files(0, "$adj_dir/$tdir", "Adjudication results for [$tdir]");
    push @fl, grep(! m%($log_add|$info_add)$%, @tfl);
  }
} else {
  my @tfl = &die_list_X_files(0, $adj_dir, "Adjudication results");
  @fl = grep(! m%($log_add|$info_add)$%, @tfl);
}
if (scalar @fl == 0) {
  print("\nNo Adjudication files found\n");
} else {
  print "\nAdjudication files (", scalar @fl, "):\n - ", join("\n - ", sort @fl), "\n";
}

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
    if (($x > 0) && (scalar @$rf != $x));

  return(@$rf);
}

#####

sub die_do_incin_dir {
  my ($inc, $inc_in, $dirb, $dira, $txt, $diradd) = @_;

  my $t = sprintf("%03d_%02d-$dira", $inc, $inc_in);

  my $dir = MMisc::get_file_full_path("$dirb/$t$diradd");
  &die_mkdir($dir, $txt);

  return($dir);
}

##########

sub extract_gmin_grange_from_log {
  my $log = shift @_;

  my $txt = MMisc::slurp_file($log);
  MMisc::error_quit("Problem reading log file ($txt), aborting")
    if (! defined $txt);

  my ($gmin, $grange) = (undef, undef);
  ($gmin, $grange) = ($1, $2)
    if ($txt =~ m%^Global\s+min\:\s+([^\s]+?)\s.+?\[Range\:\s+([^\s]+)\]%m);
  MMisc::error_quit("Could not find Global min and Global Range values")
    if ((! defined $gmin) || (! defined $grange));
  MMisc::error_quit("Some problem with Global min and Global Range values (Not a number ? [$gmin / $grange]")
    if ((! MMisc::is_float($gmin)) || (! MMisc::is_float($grange)));

  return($gmin, $grange);
}

##########

sub are_csv_content_different {
  my ($csv1, $csv2) = @_;

  foreach my $f (@_) {
    my $err = MMisc::check_file_r($f);
    MMisc::error_quit("Problem with CSV file ($f): $err")
      if (! MMisc::is_blank($err));
  }

  open FILE, "<$csv1"
    or MMisc::error_quit("Problem reading CSV file ($csv1): $!");
  my @a1 = <FILE>;
  close FILE;
  open FILE, "<$csv2"
    or MMisc::error_quit("Problem reading CSV file ($csv2): $!");
  my @a2 = <FILE>;
  close FILE;

  return(1)
    if (scalar @a1 != scalar @a2);

  @a1 = sort @a1;
  @a2 = sort @a2;

  for (my $i = 0; $i < scalar @a1; $i++) {
    return(1) if ($a1[$i] ne $a2[$i]);
  }

  return(0);
}

############################################################

sub set_usage {
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--TrecVid08xsd location] [--Validator location] [--Scorer location] [--Adjudication location] [--InfoGenerator tool [--info_path path] [--jpeg_path path]] [--changeREFtype] [--ChangeSYStype [randomseed[:find_value]]] [--percentDS] [--ForceFilename filename] [--segmentation_margin value] [--adjudication_only] [--Warn_numframes] [--minAgree level] [--MakeAgreeDir] [--nonGlobing | --globSmart tokeep] [--rerunMasterREFvsSYS] --fps fps --Duration seconds --delta_t value --work_in_dir dir ref_file sys_files

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found
  --Validator     Full path location of the TV08Validator program (default: $validator_d)
  --Scorer        Full path location of the TV08Scorer program (default: $scorer_d)
  --Adjudicator   Full path location of the Adjudicator program (default: $adjtool_d)
  --InfoGenerator Specify the '.info' generator tool to use (arguments to this tool must be in the following order: info_outfile file_name start_frame end_frame [jpeg_path])
  --info_path     Path to the final '.info' file (added in the Viper file)
  --jpeg_path     Path to the JPEG files inside the '.info' file
  --changeREFtype   Will convert the 'ref_file' from SYS to REF
  --ChangeSYStype   Will convert all 'sys_file's from REF to SYS. The \'randomseed\' and \'find_value\' are the same as in the TV08ViperValidator\'s \'ChangeType\' options.
  --percentDS     For the SYS files, obtain the global min and global range and recompute them so that each DetectionScore value will be between 0 and 1
  --ForceFilename Replace the 'sourcefile' file value
  --segmentation_margin  Add +/- value frames to each observation when computing its possible candidates for overlap (default: $margin_d)
  --adjudication_only    Only run the program in the adjudication step
  --Warn_numframes    Print a warning (instead of quitting), in case the XML files NUMFRAMES differs
  --minAgree      Do not write files XML Adjudication files for entries under the minAgree level value
  --MakeAgreeDir  Create an output directory per Agree level
  --nonGlobing    Will create Adjudication XML files using the \"non Globing\" algorithm (default is to use the Globing algorithm)
  --globSmart     Will create Adjudication XML files using the \"smart Globing\" algorithm (default is to use the Globing algorithm), working on the top \'tokeep\' Unmapped Sys observations
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --Duration      Specify the scorer's duration
  --delta_t       Specify the scorer's delta_t value
  --work_in_dir   Directory where all the output an temporary files will be geneated
  --rerunMasterREFvsSYS  Will rerun the "Align SYSs to Master REF" step as many time as needed until a convergence is reached in order to remove multiple SYS entries that are matched by the same REF entry

The tool will create Adjudication XML files by working step by step with the REF and SYS files using other TrecVid08 F4DE tools, and using the Adjudicator script on the final result.

A note on algorithms for the final Adjudication XML files:
- \"Globing\" (default mode) will add to the XML file any event observation overlapping the extended range (global min and global max of all ovservations that are within).
- \"non Globing\" will only add to the XML file Unmapped Ref observations, not other Unmapped Sys ones.
- \"smart Globing\" will add to the XML file all event observations that overlap the extended range from a list of observations that contains both all the Unmapped Ref and the top \'tokeep\' Unmapped Sys (highest Agree level and highest mean DetectionScore)

Note:
- This prerequisite that the XML files can be been validated using 'xmllint' against the 'TrecVid08.xsd' file
- 'TrecVid08xsd' files are: $xsdfiles
- dash preceded options for the different programs can be used by simply entering them when specifying the programs.
- Using '_blank_' as the REF file will force the creation of an empty REF file from the first SYS file listed
EOF
    ;

    return $tmp;
}
