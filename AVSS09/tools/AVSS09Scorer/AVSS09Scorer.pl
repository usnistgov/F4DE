#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# AVSS09 Scorer
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS09 Submission Checker" is an experimental system.
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

my $versionid = "AVSS09 Scorer Version: $version";

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
foreach my $pn ("MMisc", "AVSS09ECF", "AVSS09HelperFunctions", "SimpleAutoTable", "CSVHelper") {
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
my $mancmd = "perldoc -F $0";
my $frameTol = 0;
my $valtool_bt = "AVSS09ViPERValidator";
my $scrtool_bt = "CLEARDTScorer";
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../../CLEAR07/data";
my $gtfs = 0;
my $verb = 1;
my $valtool = "";
my $scrtool = "";
my $destdir = "";
my $sysvaldir = "";
my $gtfvaldir = "";
my $ttid = "";
my $skval = 0;
my $ecf_file = "";
my $ovwrt = 0;
my $AVxsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../data";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:   CDE         O   S  V       d f          q s  vwx   #

my %opt = ();
my @leftover = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'quiet'           => sub {$verb = 0},
   'writedir=s'      => \$destdir,
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'gtf'             => sub {$gtfs++; @leftover = @ARGV},
   'frameTol=i'      => \$frameTol,
   'Validator=s'     => \$valtool,
   'Scorer=s'        => \$scrtool,
   'AVSSxsd=s'       => \$AVxsdpath,
   'ECF=s'           => \$ecf_file,
   'Overwrite'       => \$ovwrt,
   'skipValidation'  => \$skval,
   'dir_for_GTF=s'   => \$gtfvaldir,
   'Dir_for_SYS=s'   => \$sysvaldir,
   'ttid=s'          => \$ttid,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

# Check option set
&check_opt_is_blank("writedir", $destdir);
&check_opt_is_blank("dir_for_GTF", $gtfvaldir);
&check_opt_is_blank("Dir_for_SYS", $sysvaldir);
# And directories exists
&check_opt_dir_w("writedir", $destdir);
&check_opt_dir_w("dir_for_GTF", $gtfvaldir);
&check_opt_dir_w("Dir_for_SYS", $sysvaldir);

MMisc::error_quit("\'dir_for_GTF\' and \'Dir_for_SYS\' can not be the same")
  if ($gtfvaldir eq $sysvaldir);

# ECF
if (! MMisc::is_blank($ecf_file)) {
  my $err = MMisc::check_file_r($ecf_file);
  MMisc::error_quit("Problem with \'ECF\' file ($ecf_file): $err")
    if (! MMisc::is_blank($err));
}

# Val tool
if (MMisc::is_blank($valtool)) {
  my @ok_tools = ();
  if (defined $ENV{$f4b}) {
    push @ok_tools, $ENV{$f4b} . "/bin/$valtool_bt";
  }
  push @ok_tools, "./$valtool_bt";
  push @ok_tools, "./$valtool_bt.pl";
  push @ok_tools, "../$valtool_bt/$valtool_bt.pl";
  foreach my $t (@ok_tools) {
    next if (! MMisc::is_blank($valtool));
    next if (! MMisc::is_file_x($t));
    $valtool = $t;
  }
}
if (! $skval) {
  MMisc::error_quit("No \'$valtool_bt\' provided/found\n\n$usage\n")
    if (MMisc::is_blank($valtool));
  my $err = MMisc::check_file_x($valtool);
  MMisc::error_quit("Problem with \'$valtool_bt\' [$valtool]: $err\n\n$usage\n")
    if (! MMisc::is_blank($err));
}

# Scr tool
if (MMisc::is_blank($scrtool)) {
  my @ok_tools = ();
  if (defined $ENV{$f4b}) {
    push @ok_tools, $ENV{$f4b} . "/bin/$scrtool_bt";
  }
  push @ok_tools, "./$scrtool_bt";
  push @ok_tools, "./$scrtool_bt.pl";
  push @ok_tools, "../../../CLEAR07/tools/$scrtool_bt/$scrtool_bt.pl";
  foreach my $t (@ok_tools) {
    next if (! MMisc::is_blank($scrtool));
    next if (! MMisc::is_file_x($t));
    $scrtool = $t;
  }
}
MMisc::error_quit("No \'$scrtool_bt\' provided/found\n\n$usage\n")
  if (MMisc::is_blank($scrtool));
my $err = MMisc::check_file_x($scrtool);
MMisc::error_quit("Problem with \'$scrtool_bt\' [$scrtool]: $err\n\n$usage\n")
  if (! MMisc::is_blank($err));

my $svfmd = "VFmemdump";
my $sssmd = "SSmemdump";
########## Main processing
my $stepc = 1;

#### Pre
my $ecf = &load_ecf($ecf_file);

##### Validation
my ($rsys_hash, $rref_hash) = &do_validation();

##### Scoring
my %global_scores = ();
my %global_camid = ();
my @gs_spk = ("camid", "primcam", "motavg"); # special keys / order is important
my $ok = &do_scoring($ecf);

print "\n\n";

MMisc::error_quit("***** Not all scoring ok *****")
  if (! $ok);

my $grtxt = &get_global_results($ecf);
print"\n\n########## ECF result table:\n\n$grtxt\n\n"
  if (! MMisc::is_blank($grtxt));

MMisc::ok_quit("***** Done *****\n");

########## END
########################################

sub load_preprocessing {
  my ($isgtf, $ddir, @filelist) = @_;

  if (! $skval) {
    print "** Validating and Generating ", ($isgtf) ? "GTF" : "SYS", " Sequence MemDump\n";
  } else {
    print "** Confirming that ", ($isgtf) ? "GTF" : "SYS", " Sequence MemDump exist\n";
  }

  my %all = ();
  while (my $tmp = shift @filelist) {
    print "- Working on ",  ($isgtf) ? "GTF" : "SYS", " file: $tmp\n";

    my $err = MMisc::check_file_r($tmp);
    MMisc::error_quit("Problem with file ($tmp): $err")
        if (! MMisc::is_blank($err));

    my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($tmp);
    MMisc::error_quit("Problem spliting filename ($tmp): $err")
        if (! MMisc::is_blank($err));

    my $td = $ddir;
    $td = "$ddir/$file" if (MMisc::is_blank($ecf_file));

    if ((! $skval) && (MMisc::is_blank($ecf_file))) {
      MMisc::error_quit("Output directory already exists ($td)")
        if (-d $td);
      MMisc::error_quit("Problem creating output directory ($td)")
        if (! MMisc::make_dir($td));
    }

    my $logfile = "$td/$file.log";

    my $command = $valtool;
    $command .= " --gtf" if ($isgtf);
    $command .= " --xmllint $xmllint" if ($opt{'xmllint'});
    $command .= " --CLEARxsd $xsdpath" if ($opt{'xsdpath'});
    $command .= " --frameTol $frameTol" if ($opt{'frameTol'});
    $command .= " --write $td --WriteMemDump gzip";

    if (! MMisc::is_blank($ecf_file)) {
      $command .= " --ECF $ecf_file";
      $command .= " --TrackingTrialsDir"; # Always with ECF (safer & easier)
      $command .= " --tracking_trial $ttid" if (! MMisc::is_blank($ttid));
      $command .= " --overwrite_not" if (! $ovwrt);
    }

    $command .= " \"$tmp\"";

    if (! $skval) {
      my ($ok, $otxt, $stdout, $stderr, $retcode, $ofile) = 
        MMisc::write_syscall_smart_logfile($logfile, $command);
      
      MMisc::error_quit("Problem during validation:\n" . $stderr . "\nFor details, see $ofile\n")
        if ($retcode != 0);
      
      print "   -> OK [logfile: $ofile]\n";
    }

    if (MMisc::is_blank($ecf_file)) {
      my $file = "$td/$file.$ext";
      my $err = MMisc::check_file_r($file);
      MMisc::error_quit("Can not find output ViperFile [$file]")
        if (! MMisc::is_blank($err));
      
      my $vfmd = "$file.$svfmd";
      my $err = MMisc::check_file_r($vfmd);
      MMisc::error_quit("Can not find ViperFile MemDump file [$vfmd]")
        if (! MMisc::is_blank($err));
      $all{$svfmd}{$vfmd} = $tmp;
      
      my $ssmd = "$file.$sssmd";
      my $err = MMisc::check_file_r($ssmd);
      MMisc::error_quit("Can not find Scoring Sequence MemDump file [$ssmd]")
        if (! MMisc::is_blank($err));
      $all{$sssmd}{$ssmd} = $tmp;
    }
  }
    
  return(%all);
}

##########

sub do_single_scoring {
  my ($td, $rsysf, $rgtff, $csvfile) = @_;

  my $logfile = "$td/scoring.log";
  
  my $cmd = "";
  if (! defined $ENV{$f4b}) { 
    $cmd .= "perl ";
    foreach my $j ("../../../CLEAR07/lib", "../../../common/lib") {
      my $err = MMisc::check_dir_r($j);
      MMisc::error_quit("Problem with expected INC directory [$j]: $err")
        if (! MMisc::is_blank($err));
      $cmd .= " -I$j";
    }
    $cmd .= " ";
  }

  $cmd .= $scrtool;
  $cmd .= " --xmllint $xmllint" if ($opt{'xmllint'});
  $cmd .= " --CLEARxsd $xsdpath" if (($opt{'xsdpath'}) || (! defined $ENV{$f4b}));
  $cmd .= " --frameTol $frameTol" if ($opt{'frameTol'});
  $cmd .= " --Domain SV";
  $cmd .= " --Eval Area";
  $cmd .= " --SpecialMode AVSS09";
  $cmd .= " --csv $csvfile" if (! MMisc::is_blank($csvfile));

  my @command = ();
  push @command, $cmd;
  push @command, @$rsysf;
  push @command, "--gtf";
  push @command, @$rgtff;

  my ($ok, $otxt, $stdout, $stderr, $retcode, $ofile) = 
    MMisc::write_syscall_smart_logfile($logfile, @command);

  MMisc::error_quit("Problem during scoring:\n" . $stderr . "\nFor details, see $ofile\n")
      if ($retcode != 0);

  if (! MMisc::is_blank($csvfile)) {
    my $err = MMisc::check_file_r($csvfile);
    MMisc::error_quit("Problem with expected CSV file ($csvfile): $err")
      if (! MMisc::is_blank($err));
  }

  return($stdout, $ofile);
}

##########

sub get_sys_ref_filelist {
  my $rlo = shift @_;
  my @args = @_;

  my @lo = @{$rlo};

  @args = reverse @args;
  @lo = reverse @lo;

  my @ref = ();
  my @sys = ();
  while (my $l = shift @lo) {
    if ($l eq $args[0]) {
      push @ref, $l;
      shift @args;
    }
  }
  @ref = reverse @ref;
  @sys = reverse @args;

  return(\@ref, \@sys);
}

####################

sub do_validation {
  if (($skval) && (! MMisc::is_blank($ecf_file))) {
    print("Note: \'ECF\' provided and \'skipValidation\' selected; will check ECF file presence from ECF in scoring step\n");
      return();
  }
  
  print("Note: no \'ECF\' provided, but \'skipValidation\' selected, will at least confirm required files are present\n")
    if ($skval);

  MMisc::error_quit("Only one \'gtf\' separator allowed per command line, aborting\n\n$usage\n")
    if ($gtfs > 1);
  
  my ($rref, $rsys) = &get_sys_ref_filelist(\@leftover, @ARGV);
  my @ref = @{$rref};
  my @sys = @{$rsys};
  MMisc::error_quit("No SYS file(s) provided, can not perform scoring\n\n$usage\n")
    if (scalar @sys == 0);
  MMisc::error_quit("No REF file(s) provided, can not perform scoring\n\n$usage\n")
    if (scalar @ref == 0);
  MMisc::error_quit("Unequal number of REF and SYS files, can not perform scoring\n\n$usage\n")
    if (scalar @ref != scalar @sys);
  
  #####
  print "\n\n***** STEP ", $stepc++, ": Validation\n";
  
  my (%sys_hash) = &load_preprocessing(0, $sysvaldir, @sys);
  my (%ref_hash) = &load_preprocessing(1, $gtfvaldir, @ref);
  
  return(\%sys_hash, \%ref_hash);
}

#####

sub load_ecf {
  my ($tmp) = @_;

  return(undef) if (MMisc::is_blank($tmp));

  #####
  print "\n\n***** STEP ", $stepc++, ": Validating ECF file\n";

  my ($err, $object) = AVSS09HelperFunctions::load_ECF_file($tmp, $xmllint, $AVxsdpath);

  MMisc::error_quit("Problem loading ECF file ($tmp) : $err")
      if (! MMisc::is_blank($err));

  MMisc::error_quit("Requested \'ttid\' ($ttid) is not part of provided \'ECF\' (ok ttids: " . join("|", $object->get_ttid_list()) . ")")
    if ((! MMisc::is_blank($ttid)) && (! $object->is_ttid_in($ttid)));

  MMisc::error_quit("Problem with \'ECF\' ($tmp): " . $object->get_errormsg())
    if ($object->error());

  return($object);
}

####################

sub do_scoring_noECF {
  my @sysscrf = keys %{$$rsys_hash{$sssmd}};
  my @refscrf = keys %{$$rref_hash{$sssmd}};
  my ($scores, $logfile) = &do_single_scoring($destdir, \@sysscrf, \@refscrf);
  
  print "\n\n**** Scoring results:\n-- Beg ----------\n$scores\n-- End ----------\n";
  print "For more details, see: $logfile\n";

  return(1);
}

##########

sub do_ECF_ttid_scoring {
  my ($ecf, $rttid) = @_;

  print "- Scoring \"$rttid\" ttid\n";

  MMisc::error_quit("Problem with \'ECF\' : " . $ecf->get_errormsg())
    if ($ecf->error());

 MMisc::error_quit("Can not score specified \'ttid\' ($rttid), not part of \'ECF\'")
   if (! $ecf->is_ttid_in($rttid));

  my @sffnl = $ecf->get_sffn_list_for_ttid($rttid);
  MMisc::error_quit("Problem obtaining SFFN list: " . $ecf->get_errormsg())
    if ($ecf->error());
  MMisc::error_quit("Empty SFFN list for ttid [$rttid]")
    if (scalar @sffnl == 0);
  
  my %dirs =
    (
     0 => $sysvaldir,
     1 => $gtfvaldir,
    );

  my %fl = ();
  foreach my $isgtf (keys %dirs) {
    foreach my $sffn (@sffnl) {
      my $df = $ecf->get_sffn_ttid_expected_XML_filename($sffn, $rttid, $isgtf, $dirs{$isgtf});
      MMisc::error_quit("Problem obtaining destination file [$sffn / $rttid / $isgtf]")
        if (! defined $df);
      my ($ssf) = AVSS09ViperFile::get_SSMemDump_filename($df);
      my $err = MMisc::check_file_r($ssf);
      MMisc::error_quit("Problem with finding Scoring Sequence MemDump for \'ttid\' [$rttid] / \'sffn\' [$sffn] " . (($isgtf) ? "GFT" : "SYS") . " (looking for: " . $df .") : $err")
        if (! MMisc::is_blank($err));
      push @{$fl{$isgtf}}, $ssf;
    }
  }

  my $dd = $ecf->get_ttid_expected_path_base($rttid);
  MMisc::error_quit("Problem obtaining scoring destination path [$rttid]")
    if (! defined $dd);
  my $td = "$destdir/$dd";
  MMisc::error_quit("Problem creating scoring output directory ($td)")
        if (! MMisc::make_dir($td));

  my @sfl = @{$fl{0}};
  my @gfl = @{$fl{1}};

  my $csvfile = "$td/$rttid.csv";

  my ($scores, $logfile) = &do_single_scoring($td, \@sfl, \@gfl, $csvfile);

  &prepare_results($ecf, $rttid, $csvfile);

  my $ref_res = &reformat_results($ecf, $rttid);
  print "$ref_res\n";

  return(1);
}

#####

sub do_ECF_scoring {
  my ($ecf) = @_;

  my @ttidl = $ecf->get_ttid_list();
  MMisc::error_quit("Problem obtaing \'ttid\' list : " . $ecf->get_errormsg())
    if ($ecf->error());
  MMisc::error_quit("Found no \'ttid\' in ECF")
    if (scalar @ttidl == 0);

  my $ok = 0;
  foreach my $rttid (sort @ttidl) {
    $ok += &do_ECF_ttid_scoring($ecf, $rttid);
  }

  return(1) if ($ok == scalar @ttidl);

  return(0);
}

#####

sub do_scoring {
  my ($ecf) = @_;
  print "\n\n***** STEP ", $stepc++, ": Scoring\n";

  return(&do_scoring_noECF())
    if (! defined $ecf);

  return(&do_ECF_ttid_scoring($ecf, $ttid))
    if (! MMisc::is_blank($ttid));

  return(&do_ECF_scoring($ecf));
}

####################

sub prepare_results {
  my ($ecf, $rttid, $csvfile) = @_;

  my $err = MMisc::check_file_r($csvfile);
  MMisc::error_quit("Can not find CSV file ($csvfile): $err")
    if (! MMisc::is_blank($err));

  open CSV, "<$csvfile"
    or MMisc::error_quit("Problem opening CSV file ($csvfile): $!");

  my $csvh = new CSVHelper();
  MMisc::error_quit("Problem creating the CSV object: " . $csvh->get_errormsg())
    if ($csvh->error());

  my $header = <CSV>;
  MMisc::error_quit("CSV file contains no data ?")
    if (! defined $header);
  my @headers = $csvh->csvline2array($header);
  MMisc::error_quit("Problem extracting csv line:" . $csvh->get_errormsg())
    if ($csvh->error());
  MMisc::error_quit("CSV file ($csvfile) contains no usable data")
    if (scalar @headers < 2);

  my %pos = ();
  for (my $i = 0; $i < scalar @headers; $i++) {
    $pos{$headers[$i]} = $i;
  }

  my @needed = ("Video", "MOTA");
  foreach my $key (@needed) {
    MMisc::error_quit("Could not find needed key ($key) in results")
      if (! exists $pos{$key});
  }

  $csvh->set_number_of_columns(scalar @headers);
  MMisc::error_quit("Problem setting the number of columns for the csv file:" . $csvh->get_errormsg())
    if ($csvh->error());

  my $type = $ecf->get_ttid_type($rttid);
  MMisc::error_quit("Problem obtaining \'ttid\' type : " . $ecf->get_errormsg())
    if ($ecf->error());

  my @sffnl = $ecf->get_sffn_list_for_ttid($rttid);
  MMisc::error_quit("Problem obtaining \'sffn\' list : " . $ecf->get_errormsg())
    if ($ecf->error());
  MMisc::error_quit("Empty \'sffn\' list for \'ttid\' ($rttid)")
    if (scalar @sffnl == 0);
  my %sffnh = ();
  # There is a strange tendency to uppercase the entire output scoring array
  # but we need the exact sffn value, so lowercase everything
  foreach my $sffn (@sffnl) {
    my $lcsffn = lc $sffn;
    MMisc::error_quit("Problem with lowercasing \'sffn\' keys ($sffn), an entry with the same name already exists")
      if (exists $sffnh{$lcsffn});
    $sffnh{$lcsffn} = $sffn;
  }

  my $pc = $ecf->get_ttid_primary_camid($rttid);
  MMisc::error_quit("Problem obtaining primary \'camid\' : " . $ecf->get_errormsg())
    if ($ecf->error());

  my %oh = ();
  my $cont = 1;
  my $mota_avg = 0;
  my $mota_entries = 0;
  while ($cont) {
    my $line = <CSV>;
    if (MMisc::is_blank($line)) {
      $cont = 0;
      next;
    }

    my @linec = $csvh->csvline2array($line);
    MMisc::error_quit("Problem extracting csv line:" . $csvh->get_errormsg())
      if ($csvh->error());
    my $sffn = $linec[$pos{$needed[0]}];
    my $mota = $linec[$pos{$needed[1]}];

    my $sffnk = lc $sffn;
    MMisc::error_quit("Could not find \'sffn\' ($sffn) in list of expected ones [or already processed ?]")
      if (! exists $sffnh{$sffnk});
    $sffn = $sffnh{$sffnk};
    delete $sffnh{$sffnk};

    MMisc::error_quit("\'sffn\' ($sffn) not in \'ttid\' ($rttid) [in: " . join(",", @sffnl) . "]")
      if (! $ecf->is_sffn_in_ttid($rttid, $sffn));

    my $camid = $ecf->get_camid_from_ttid_sffn($rttid, $sffn);
    MMisc::error_quit("Problem obtaining \'camid\' : " . $ecf->get_errormsg())
      if ($ecf->error());
    
    $global_scores{$type}{$rttid}{$gs_spk[0]}{$camid} = $mota;
    $mota_avg += $mota;
    $mota_entries++;
    $global_camid{$camid}++;
  }
  MMisc::error_quit("Missing some \'sffn\' results for \'ttid\' ($rttid): " . join(",", keys %sffnh))
    if (scalar keys %sffnh > 0);
  close(CSV);

  $global_scores{$type}{$rttid}{$gs_spk[1]} = $pc;
  $global_scores{$type}{$rttid}{$gs_spk[2]} = $mota_avg / $mota_entries;
}

##########

sub get_global_results {
  my ($ecf) = @_;

  return("") if (! defined $ecf);

  my $sat = new SimpleAutoTable();
  MMisc::error_quit("While preparing print results : " . $sat->get_errormsg() . "\n")
    if (! $sat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

  my @gcamid = sort {$a <=> $b} keys %global_camid;

  foreach my $type (keys %global_scores) {
    foreach my $rttid (keys %{$global_scores{$type}}) {
      my $id = "$type - $rttid";
      &sat_add_results($sat, $id, 0, $type, $rttid, @gcamid);
      MMisc::error_quit("Problem with SAT: " . $sat->get_errormsg())
        if ($sat->error());
    }
  }

  my $tbl = $sat->renderTxtTable(2);
  MMisc::error_quit("Problem rendering SAT: ". $sat->get_errormsg())
    if (! defined($tbl));

  return($tbl);
}

#####

sub reformat_results {
  my ($ecf, $rttid) = @_;

  return("") if (! defined $ecf);

  my $type = $ecf->get_ttid_type($rttid);
  MMisc::error_quit("Problem obtaining \'ttid\' type : " . $ecf->get_errormsg())
    if ($ecf->error());

  my $sat = new SimpleAutoTable();
  MMisc::error_quit("While preparing print results : " . $sat->get_errormsg() . "\n")
    if (! $sat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

  my $id = "$type - $rttid";

  my $hf = ($type eq "scspt") ? 1 : 0;

  &sat_add_results($sat, $id, $hf, $type, $rttid);
  MMisc::error_quit("Problem with SAT: " . $sat->get_errormsg())
    if ($sat->error());

  my $tbl = $sat->renderTxtTable(2);
  MMisc::error_quit("Problem rendering SAT: ". $sat->get_errormsg())
    if (! defined($tbl));

  return($tbl);
}

#####

sub sat_add_results {
  my ($sat, $id, $half_fill, $type, $rttid, @gcamids) = @_;

  MMisc::error_quit("Can not find results for \'ttid\' ($rttid)")
    if (! exists $global_scores{$type}{$rttid});

  my @camids = keys %{$global_scores{$type}{$rttid}{$gs_spk[0]}};
  my $pc = $global_scores{$type}{$rttid}{$gs_spk[1]};
  my $avg = $global_scores{$type}{$rttid}{$gs_spk[2]};

  $sat->addData($type, "Type", $id);
  $sat->addData($rttid, "Tracking Trial ID", $id);
  $sat->addData($pc, "Primary Camera ID", $id);
  $sat->addData($global_scores{$type}{$rttid}{$gs_spk[0]}{$pc}, 
                "Primary Camera MOTA", $id);

  return() if ($half_fill);

  @gcamids = @camids if (scalar @gcamids == 0);
  foreach my $cid (@gcamids) {
    my $v = ($cid == $pc) ? "--" 
      : (! exists $global_scores{$type}{$rttid}{$gs_spk[0]}{$cid}) ? "NA"
      : $global_scores{$type}{$rttid}{$gs_spk[0]}{$cid};
    $sat->addData($v, "Cam $cid MOTA", $id);
  }    

  $sat->addData($global_scores{$type}{$rttid}{$gs_spk[2]}, "Average MOTA", $id);
}

####################

sub check_opt_is_blank {
  my ($opt, $val) = @_;

  MMisc::error_quit("No \'$opt\' given, aborting\n\n$usage\n")
    if (MMisc::is_blank($val));
}

#####

sub check_opt_dir_w {
  my ($opt, $dir) = @_;

  my $err = MMisc::check_dir_w($dir);
  MMisc::error_quit("Problem with \'$opt\' directory [$dir]: $err\n\n$usage\n")
    if (! MMisc::is_blank($err));
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

############################################################ Manual

=pod

=head1 NAME

AVSS09Scorer - AVSS09 ViPER XML System to Reference Scoring Tool

=head1 SYNOPSIS

B<AVSS09Scorer> S<[ B<--help> | B<--man> | B<--version> ]>
  S<[B<--xmllint> I<location>] [B<--CLEARxsd> I<location>]>
  S<B<--writedir> directory [B<--frameTol> I<framenbr>]>
  S<[B<--Validator> I<tool>] [B<--Scorer> I<tool>]>
  S<I<sys_file.xml> [I<...>] B<--gtf> I<ref_file.xml> [I<...>]>
  
=head1 DESCRIPTION

B<AVSS09Scorer> is a wrapper tool for the I<AVSS09ViPERValidator> and I<CLEARDTScorer> tools.
The first one performs a syntactic and semantic validation of the ViPER XML file(s) provided on the command line.
The second perform the actual scoring on the I<Scoring Sequence memory representation> of the I<system> and I<reference> XML files.

=head1 PREREQUISITES

B<AVSS09scorer>'s tools relies on some external software and files, most of which associated with the B<CLEAR> section of B<F4DE>.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<F4DE_XMLLINT> environment variable to the full path location of the I<xmllint> executable.

=item B<FILES>

The syntactic validation requires some XML schema files (see the B<CLEARDTScorer> help section for file list).
It is possible to specify their location using the B<--xsdpath> option.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

Once you have installed the software, setting B<F4DE_BASE> to the installation location, and extending your B<PATH> to include B<$F4DE_BASE/bin> should be sufficient for the tools to find their components.

=back

=head1 GENERAL NOTES

B<AVSS09ViPERValidator> expects that the files can be validated using 'xmllint' against the B<CLEAR> XSD file(s) (see B<--help> for files list).

B<AVSS09ViPERValidator> will use the core validation of the B<CLEAR> code and add some specialized checks associated with the B<AVSS09> evaluation.

The B<CLEARDTScorer> will load I<Scoring Sequence memory represenations> generated by the validation process.

=head1 OPTIONS

=over

=item B<--CLEARxsd> I<location>

Specify the default location of the required XSD files.

=item B<--frameTol> I<framenbr>

The frame tolerance allowed for attributes to be outside of the object framespan

=item B<--gtf>

Specify that the files past this marker are reference files.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--man>

Display this man page.

=item B<--Scorer> I<tool>

Specify the full path location of the B<CLEARDTScorer> program

=item B<--Validator> I<tool>

Specify the full path location of the B<AVSS09ViPERValidator> program

=item B<--version>

Display B<AVSS09ViPERValidator> version information.

=item B<--writedir> I<directory>

Specify the I<directory> in which all files required for the validation and scoring process will be generated.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<F4DE_XMLLINT> environment variable.

=back

=head1 USAGE

=item B<AVSS09Scorer --xmllint /local/bin/xmllint --CLEARxsd /local/F4DE-CVS/data --writedir /tmp --frameTol 5 sys_test1.xml sys_test2.xml --gtf ref_test1.xml ref_test2.xml>

Using the I<xmllint> executable located at I</local/bin/xmllint>, with the required XSD files found in the I</local/F4DE/data> directory, putting all generated files in I</tmp>, and using a frame tolerance of 5 frames, it will use:

=over

=item B<AVSS09ViPERValidator> to validate the I<system> files I<sys_test1.xml> and I<sys_test2.xml> as well as the I<reference> files I<ref_test1.xml> and I<ref_test2.xml>.
The validator will also generate a I<Scoring Sequence memory represenation> of all those files.

=item B<CLEARDTScorer> to perform scoring on the I<Scoring Sequence memory represenation> files present.

=back

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut

########################################

sub set_usage {
  my $wmd = join(" ", @ok_md);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --man | --version] [--xmllint location] [--CLEARxsd location] --writedir directory [--frameTol framenbr] [--Validator tool] [--Scorer tool] sys_file.xml [sys_file.xml [...]] --gtf ref_file.xml [ref_file.xml [...]]

Will call the AVSS09 Validation and CLEAR Scorer tools on the XML file(s) provided (System vs Reference)

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd  Path where the XSD files can be found
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default: $frameTol)
  --writedir      Directory in which validation and scoring will be performed
  --Validator     Specify the full path location of the $valtool_bt tool (if not in your path)
  --Scorer        Specify the full path location of the $scrtool_bt tool (if not in your path)

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'CLEAR.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will disard any xml comment(s).
- 'CLEARxsd' files are the same as needed by $valtool_bt
EOF
;

  return $tmp;
}
