#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
    if 0;

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
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
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }

  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../CLEAR07/lib", "$f4d/../../../common/lib");
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
foreach my $pn ("MMisc", "AVSS09ECF", "AVSS09HelperFunctions", "SimpleAutoTable", "CSVHelper", "CLEARMetrics") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "AVSS09 Scorer ($versionkey)";

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
my @ok_needed = ("Video", "MOTA", "MOTP", "SFDA", "ATA", "MODA", "MODP"); # Order is crucial: "Video" <=> "sffn" has to be first

my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = "$f4d/../../../CLEAR07/data";
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
my $AVxsdpath = "$f4d/../../data";
my $docsv = 0;
my $trackmota = 0;
my $fullresults = 0;
my $ovnotreq    = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: A CDEF        O   ST V      cd fgh    m o q st vwx   #

my %opt = ();
my @sys = ();
my @ref = ();
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
   'gtf'             => sub {$gtfs++},
   'frameTol=i'      => \$frameTol,
   'Validator=s'     => \$valtool,
   'Scorer=s'        => \$scrtool,
   'AVSSxsd=s'       => \$AVxsdpath,
   'ECF=s'           => \$ecf_file,
   'Overwrite'       => \$ovwrt,
   'skipValidation'  => \$skval,
   'dirGTF=s'        => \$gtfvaldir,
   'DirSYS=s'        => \$sysvaldir,
   'trackingTrial=s' => \$ttid,
   'csv'             => \$docsv,
   'TrackMOTA'       => \$trackmota,
   'FullResults'     => \$fullresults,
   'overlapNotRequired' => \$ovnotreq,
   # Non options (SYS + REF)
   '<>' => sub { if ($gtfs) { push @ref, @_; } else { push @sys, @_; } },
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::error_quit("Leftover arguments on the command line: " . join(", ", @ARGV))
  if (scalar @ARGV > 0);

# Check option set
&check_opt_is_blank("writedir", $destdir);
&check_opt_is_blank("dirGTF", $gtfvaldir);
&check_opt_is_blank("DirSYS", $sysvaldir);
# And directories exists
&check_opt_dir_w("writedir", $destdir);
if ($skval) {
  &check_opt_dir_r("dirGTF", $gtfvaldir);
  &check_opt_dir_r("DirSYS", $sysvaldir);
} else {
  &check_opt_dir_w("dirGTF", $gtfvaldir);
  &check_opt_dir_w("DirSYS", $sysvaldir);
}

MMisc::error_quit("Can not use \'FullResults\' unless \'csv\' is selected too")
  if (($fullresults) && (! $docsv));

MMisc::error_quit("\'dirGTF\' and \'DirSYS\' should not be the same")
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
  push @ok_tools, "$f4d/bin/${valtool_bt}.pl";
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
  push @ok_tools, "$f4d/bin/${scrtool_bt}.pl";
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
my @needed = ();
if (! $fullresults) {
  push @needed, @ok_needed[0..1];
} else {
  push @needed, @ok_needed;
}
my $ok = &do_scoring($ecf);

print "\n\n";

MMisc::error_quit("***** Not all scoring ok *****")
  if (! $ok);

my $ocsvf = ($docsv) ? "$destdir/ECF-global_results.csv" : "";
&print_global_results($ecf, $ocsvf, $needed[1]);
if ($fullresults) {
  for (my $i = 1; $i < scalar @needed; $i++) {
    my $key = $needed[$i];
    my $ocsvf = ($docsv) ? "$destdir/ECF-global_results-$key.csv" : "";
    &print_global_results($ecf, $ocsvf, $key);
  }
}    

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
  for (my $fi = 0; $fi < scalar @filelist; $fi++) {
    my $tmp = $filelist[$fi];
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
      $command .= " --trackingTrial $ttid" if (! MMisc::is_blank($ttid));
      $command .= " --overwriteNot" if (! $ovwrt);
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
  my ($logfile, $rsysf, $rgtff, $csvfile) = @_;

  my $cmd = $scrtool;
  $cmd .= " --xmllint $xmllint" if ($opt{'xmllint'});
  $cmd .= " --CLEARxsd $xsdpath" 
      if (($opt{'xsdpath'}) || (! MMisc::is_blank($xsdpath)));
  $cmd .= " --frameTol $frameTol" if ($opt{'frameTol'});
  $cmd .= " --Domain SV";
  $cmd .= " --Eval Area";
  my $spmode = "AVSS09";
  $spmode .= ":full" if ($fullresults);
  $cmd .= " --SpecialMode $spmode";
  $cmd .= " --overlapNotRequired" if ($ovnotreq);
  $cmd .= " --csv $csvfile" if (! MMisc::is_blank($csvfile));
  $cmd .= " --quitOnMissingFiles";
  if ($trackmota) {
    my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($logfile);
    MMisc::error_quit("Problem splitting \'logfile\' into dir/file/ext: $err")
      if (! MMisc::is_blank($err));
    $cmd .= " --motaLogDir $d";
  }

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

sub do_validation {
  if (($skval) && (! MMisc::is_blank($ecf_file))) {
    print("Note: \'ECF\' provided and \'skipValidation\' selected; will check ECF needed MemDump files from information comtained within ECF file in scoring step\n");
      return();
  }
  
  print("Note: no \'ECF\' provided, but \'skipValidation\' selected, will at least confirm required files are present\n")
    if ($skval);

  MMisc::error_quit("Only one \'gtf\' separator allowed per command line, aborting\n\n$usage\n")
    if ($gtfs > 1);
  
  MMisc::error_quit("No SYS file(s) provided, can not perform scoring\n\n$usage\n")
    if (scalar @sys == 0);
  MMisc::error_quit("No REF file(s) provided, can not perform scoring\n\n$usage\n")
    if (scalar @ref == 0);
  MMisc::error_quit("Unequal number of REF and SYS files, can not perform scoring\n\n$usage\n")
    if ((MMisc::is_blank($ecf_file)) && (scalar @ref != scalar @sys));
  
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
  my $logfile = "$destdir/scoring.log";
  my $csvfile = ($docsv) ? "$destdir/DTScorer_Results.csv" : "";
  my ($scores, $logfile) = &do_single_scoring($logfile, \@sysscrf, \@refscrf, $csvfile);
  
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

  my $csvfile = "$td/$rttid-DTScorer_Results.csv";
  my $logfile = "$td/$rttid-DTScoring.log";

  my ($scores, $logfile) = &do_single_scoring($logfile, \@sfl, \@gfl, $csvfile);

  &prepare_results($ecf, $rttid, $csvfile);
  my $ocsvfile = ($docsv) ? "$td/$rttid-Results.csv" : "";

  my $ref_res = &reformat_results($ecf, $rttid, $ocsvfile, $needed[1]);
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

  my $type = $ecf->get_ttid_type($rttid);
  MMisc::error_quit("Problem obtaining \'ttid\' type : " . $ecf->get_errormsg())
    if ($ecf->error());

  my @sffnl = $ecf->get_sffn_list_for_ttid($rttid);
  MMisc::error_quit("Problem obtaining \'sffn\' list : " . $ecf->get_errormsg())
    if ($ecf->error());
  MMisc::error_quit("Empty \'sffn\' list for \'ttid\' ($rttid)")
    if (scalar @sffnl == 0);

  my %cid = ();
  foreach my $sffn (@sffnl) {
    my $camid = $ecf->get_camid_from_ttid_sffn($rttid, $sffn);
    MMisc::error_quit("Problem obtaining \'camid\' : " . $ecf->get_errormsg())
      if ($ecf->error());
    $cid{$sffn} = $camid;
  }

  my $pc = $ecf->get_ttid_primary_camid($rttid);
  MMisc::error_quit("Problem obtaining primary \'camid\' : " . $ecf->get_errormsg())
    if ($ecf->error());

  my ($err, %oh) = AVSS09HelperFunctions::load_DTScorer_ResultsCSV($csvfile, \@sffnl, \%cid, @needed);
  MMisc::error_quit("Problem with DTScorer Results CSV for \'ttid\' ($rttid): $err")
    if (! MMisc::is_blank($err));

  my %calc_sum = ();
  my %calc_entries = ();
  foreach my $camid (keys %oh) {
    for (my $i = 1; $i < scalar @needed; $i++) {
      my $key = $needed[$i];
      my $val = $oh{$camid}{$key};

      $calc_sum{$key} = 0 if (! exists $calc_sum{$key});
      $calc_entries{$key} = 0 if (! exists $calc_entries{$key});

      $global_scores{$type}{$rttid}{$gs_spk[0]}{$camid}{$key} = $val;

      $calc_sum{$key} += $val;
      $calc_entries{$key}++;
    }
    $global_camid{$camid}++;
  }

  $global_scores{$type}{$rttid}{$gs_spk[1]} = $pc;

  for (my $i = 1; $i < scalar @needed; $i++) {
    my $key = $needed[$i];
    $global_scores{$type}{$rttid}{$gs_spk[2]}{$key} 
    = $calc_sum{$key} / $calc_entries{$key};
  }

  if (($trackmota) && ($docsv)) {
    my ($err, $bd, $dummy, $dummy) = MMisc::split_dir_file_ext($csvfile);
    MMisc::error_quit("Problem extracting dir/file/ext [$csvfile]: $err")
      if (! MMisc::is_blank($err));
    &mota_comp_csv($bd, $rttid, %cid);
  }
}

##########

sub print_global_results {
  my ($ecf, $csvfile, $key) = @_;

  return("") if (! defined $ecf);

  print"\n\n########## ECF result table:\n";

  my $sat = new SimpleAutoTable();
  MMisc::error_quit("While preparing print results : " . $sat->get_errormsg() . "\n")
    if (! $sat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

  my @gcamid = sort {$a <=> $b} keys %global_camid;

  foreach my $type (keys %global_scores) {
    foreach my $rttid (keys %{$global_scores{$type}}) {
      my $id = "$type - $rttid";
      &sat_add_results($sat, $id, 0, $type, $rttid, $key, @gcamid);
      MMisc::error_quit("Problem with SAT: " . $sat->get_errormsg())
        if ($sat->error());
    }
  }

  if (! MMisc::is_blank($csvfile)) {
    my $csvtxt = $sat->renderCSV();
    MMisc::error_quit("Generating CSV Report: ". $sat->get_errormsg())
      if (! defined($csvtxt));
    MMisc::error_quit("Problem while trying to write CSV file ($csvfile)")
      if (! MMisc::writeTo($csvfile, "", 1, 0, $csvtxt));
  }

  my $tbl = $sat->renderTxtTable(2);
  MMisc::error_quit("Problem rendering SAT: ". $sat->get_errormsg())
    if (! defined($tbl));

  print "$tbl\n\n";
}

#####

sub reformat_results {
  my ($ecf, $rttid, $csvfile, $key) = @_;

  return("") if (! defined $ecf);

  my $type = $ecf->get_ttid_type($rttid);
  MMisc::error_quit("Problem obtaining \'ttid\' type : " . $ecf->get_errormsg())
    if ($ecf->error());

  my $sat = new SimpleAutoTable();
  MMisc::error_quit("While preparing print results : " . $sat->get_errormsg() . "\n")
    if (! $sat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

  my $id = "$type - $rttid";

  my $hf = ($type eq "scspt") ? 1 : 0;

  &sat_add_results($sat, $id, $hf, $type, $rttid, $key);
  MMisc::error_quit("Problem with SAT: " . $sat->get_errormsg())
    if ($sat->error());

  my $tbl = $sat->renderTxtTable(2);
  MMisc::error_quit("Problem rendering SAT: ". $sat->get_errormsg())
    if (! defined($tbl));

  if (! MMisc::is_blank($csvfile)) {
    my $csvtxt = $sat->renderCSV();
    MMisc::error_quit("Generating CSV Report: ". $sat->get_errormsg())
      if (! defined($csvtxt));
    MMisc::error_quit("Problem while trying to write CSV file ($csvfile)")
      if (! MMisc::writeTo($csvfile, "", 1, 0, $csvtxt));
  }

  return($tbl);
}

#####

sub sat_add_results {
  my ($sat, $id, $half_fill, $type, $rttid, $key, @gcamids) = @_;

  MMisc::error_quit("Can not find results for \'ttid\' ($rttid)")
    if (! exists $global_scores{$type}{$rttid});

  my @camids = keys %{$global_scores{$type}{$rttid}{$gs_spk[0]}};
  my $pc = $global_scores{$type}{$rttid}{$gs_spk[1]};
  my $avg = $global_scores{$type}{$rttid}{$gs_spk[2]}{$key};

  $sat->addData($type, "Type", $id);
  $sat->addData($rttid, "Tracking Trial ID", $id);
  $sat->addData($pc, "Primary Cam ID", $id);
  $sat->addData($global_scores{$type}{$rttid}{$gs_spk[0]}{$pc}{$key}, 
                "Primary Cam $key", $id);

  return() if ($half_fill);

  @gcamids = @camids if (scalar @gcamids == 0);
  foreach my $cid (@gcamids) {
    my $v = ($cid == $pc) ? "--" 
      : (! exists $global_scores{$type}{$rttid}{$gs_spk[0]}{$cid}{$key}) ? "NA"
      : $global_scores{$type}{$rttid}{$gs_spk[0]}{$cid}{$key};
    $sat->addData($v, "Cam $cid $key", $id);
  }    

  $sat->addData($global_scores{$type}{$rttid}{$gs_spk[2]}{$key}, "Avg $key", $id);}

####################

sub mota_comp_csv {
  my ($bd, $rttid, %cid) = @_;

  my @mota_comps = ();

  my $sat = new SimpleAutoTable();
  MMisc::error_quit("While preparing print results : " . $sat->get_errormsg() . "\n")
    if (! $sat->setProperties({ "KeyColumnTxt" => "Remove" }));

  my @sat_headers = ();

  my @sffnl = sort { $cid{$a} <=> $cid{$b} } keys %cid;

  foreach my $sffn (@sffnl) {
    my $lcid = $cid{$sffn};

    my $tf = "$bd/$sffn-MOTA_Components.csv";
    if (! MMisc::does_file_exist($tf)) {
      MMisc::warn_print("Could not find CAM $lcid MOTA Components CSV file ($tf), most likely no content");
      next;
    }
    my $err = MMisc::check_file_r($tf);
    MMisc::error_quit("Problem with CAM $lcid MOTA Components CSV file ($tf): $err")
      if (! MMisc::is_blank($err));
    
    open LOCAL_CSV, "<$tf"
      or MMisc::error_quit("Problem opening CSV file ($tf): $!");
    
    my $csvh = new CSVHelper();
    
    # header
    my $hl = <LOCAL_CSV>;
    my @array = $csvh->csvline2array($hl);
    MMisc::error_quit("Problem extracting CSV header [file: $tf]: " . $csvh->get_errormsg())
      if ($csvh->error());
    
    if (scalar @sat_headers == 0) {
      push @sat_headers, @array;
    } else {
      MMisc::error_quit("Not the same number of element in CSV ($tf) [" . scalar @array . "] than in Table [" . scalar @sat_headers . "]")
        if (scalar @array != scalar @sat_headers);
      for (my $i = 0; $i < scalar @array; $i++) {
        MMisc::error_quit("Not the same order for elements in CSV header")
          if ($sat_headers[$i] ne $array[$i]);
      }
    }
    $csvh->set_number_of_columns(scalar @array);
    
    my $line = <LOCAL_CSV>;
    my @larray = $csvh->csvline2array($line);
    MMisc::error_quit("Problem extracting CSV line: " . $csvh->get_errormsg())
      if ($csvh->error());
    
    my $id = "CID: $lcid / SFFN: $sffn";
    $sat->addData($lcid, "Cam ID", $id);
    my @mota_comps_tmp = ();
    my $proc_done = 0;
    for (my $i = 0; (($proc_done == 0) && ($i < scalar @array)); $i++) {
      my $v = $larray[$i];
      my $cc = $sat_headers[$i];
      $sat->addData($v, $array[$i], $id);
      if ($cc eq "MOTA") {
        $proc_done = 1;
        next;
      }
      if (! MMisc::is_integer($v)) {
        MMisc::error_quit("Column ($cc) value ($v) is not an integrer (for CAM ID $lcid)");
        next;
      }
      $mota_comps_tmp[$i] = $v;
    }
    my $lmota = CLEARMetrics::computePrintableMOTA(@larray);
    $sat->addData($lmota, "Computed MOTA", $id);
    (my $err, @mota_comps) = CLEARMetrics::sumMOTAcomp(@mota_comps, @mota_comps_tmp);
    MMisc::error_quit("While summing MOTA components: $err") 
      if (! MMisc::is_blank($err));
  }
  close LOCAL_CSV;

  if (scalar @mota_comps == 0) {
    MMisc::warn_print("Can not compute combined MOTA: no element in Sum array");
    return("");
  }
  if (scalar @mota_comps != 8) {
    MMisc::error_quit("Can not compute combined MOTA: not 8 elements (" . scalar @mota_comps .")");
    return("");
  }

  my $id = "Combined MOTA";
  $sat->addData($id, "Cam ID", $id);
  $sat->addData("", "MOTA", $id);
  for (my $i = 0; $i < scalar @mota_comps; $i++) {
    my $v = $mota_comps[$i];
    my $cc = $sat_headers[$i];

    $sat->addData($v, $sat_headers[$i], $id);
  }
  my $lmota = CLEARMetrics::computePrintableMOTA(@mota_comps);
  $sat->addData($lmota, "Computed MOTA", $id);

  my $csvfile = "$bd/$rttid-Combined_MOTA.csv";
  my $csvtxt = $sat->renderCSV();
  MMisc::error_quit("Generating CSV Report: ". $sat->get_errormsg())
    if (! defined($csvtxt));
  MMisc::error_quit("Problem while trying to write CSV file ($csvfile)")
    if (! MMisc::writeTo($csvfile, "", 1, 0, $csvtxt));

  my $tbl = $sat->renderTxtTable(2);
  MMisc::error_quit("Problem rendering SAT: ". $sat->get_errormsg())
    if (! defined($tbl));
  
  print "$tbl\n\n";  

  return("");
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

#####

sub check_opt_dir_r {
  my ($opt, $dir) = @_;

  my $err = MMisc::check_dir_r($dir);
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
  S<[B<--ECF> I<ecffile.xml> [B<--trackingTrial> I<ttid>] [B<--AVSSxsd> I<location>]]>
  S<B<--writedir> I<directory> B<--dirGTF> I<directory> B<--DirSYS> I<directory>>
  S<[B<--frameTol> I<framenbr>]>
  S<[B<--Validator> I<tool>] [B<--Overwrite>] [B<--skipValidation>]>
  S<[B<--Scorer> I<tool>] [B<--overlapNotRequired>] [B<--csv>]>
  S<[B<--TrackMOTA>] [B<--FullResults>]>
  S<[I<sys_file.xml> [I<...>] B<--gtf> I<ref_file.xml> [I<...>]]>
  
=head1 DESCRIPTION

B<AVSS09Scorer> is a scorer program able to specialize its processing based on an optional I<Experiment Control File> (ECF).

It is a wrapper program for the I<AVSS09ViPERValidator> and I<CLEARDTScorer> tools:

=over

=item I<AVSS09ViPERValidator> performs a syntactic and semantic validation of the ViPER XML file(s) provided on the command line.

=item I<CLEARDTScorer> performs the actual scoring on the I<Scoring Sequence memory representation> of the I<system> and I<reference> XML files obtained from the validation step.

=back

B<AVSS09Scorer> can be run in multiple ways:

=over

=item Validate files and perform scoring (no ECF)

S<AVSS09Scorer --writedir ResultsDir --dirGTF GTFdir --DirSYS SYSdir sys_files/*.xml --gtf ref_files/*.xml>

The validation tool will create the files required for scoring, the most important ones being the I<Scoring Sequence MemDump> files. The scoring process will try to score each I<Scoring Sequence MemDump> against one following the rule that for each one I<system> I<sourcefile's filename> there must be one I<reference> I<sourcefile's filename>.

=item Skip validation, and only do the scoring step (no ECF)

S<AVSS09Scorer --writedir newResultsDir --dirGTF GTFdir --DirSYS SYSdir --skipValidation sys_files/* --gtf ref_files/*>

This will not perform the validation step; it will still confirm that the S<Scoring Sequence MemDump> files needed for scoring are present.

This relies on both the I<GTFdir> and I<SYSdir> directories to have been filled by a previous validation process,

=item Using an ECF, validate files and perform scoring.

S<AVSS09Scorer --ECF ecf.xml --writedir ResultsDir --dirGTF GTFdir --DirSYS SYSdir sys_files/* --gtf ref_files/*>

The ECF will force the validation of only the files whose sourcefile's filename is listed as part of a I<tracking trial ID> (ttid), and will be specifically adapted following the rules needed for that specific ttid in a directory that follow the structure defined by the I<TrackingTrialsDir> option of I<AVSS09ViPERValidator>.

Then, I<AVSS09Scorer> will look for each files needed for scoring each ttid listed in the ECF file (that should be available in the I<GTFdir> and <SYSdir> directories following the special directory structure), and will run I<CLEARDTScorer> on them.

=item Using an ECF, skip validation and only do the scoring step

S<AVSS09Scorer --ECF ecf.xml --writedir ResultsDir --dirGTF GTFdir --DirSYS SYSdir --ECF ecf.xml --skipValidation>

This relies on both the I<GTFdir> and I<SYSdir> directories to have been filled by a previous validation process using the ECF file.

Note that in this case, it is not necessary to specify the source XML files as only the file generated by the I<validation with ECF> process are needed and should be in the I<GTFdir> and <SYSdir> directories following the special directory structure.

=back

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

Once you have installed the software, extending your B<PATH> to include F4DE's B<bin> directory should be sufficient for the tools to find their components.

=back

=head1 GENERAL NOTES

B<AVSS09ViPERValidator> expects that the files can be validated using 'xmllint' against the B<CLEAR> XSD file(s) (see B<--help> for files list).

B<AVSS09ViPERValidator> will use the core validation of the B<CLEAR> code and add some specialized checks associated with the B<AVSS09> evaluation.

The B<CLEARDTScorer> will load I<Scoring Sequence memory representations> generated by the validation process.

=head1 OPTIONS

=over

=item B<--AVSSxsd> I<location>

Specify the default location of the required AVSS XSD files.

=item B<--CLEARxsd> I<location>

Specify the default location of the required XSD files.

=item B<--csv>

Generate a CSV file (or multiple one with the B<--ECF> option) containing the scoring results.

=item B<--DirSYS> I<directory>

Specify the I<system> I<directory>  (or directory structure base, with the B<--ECF> option) in which the I<validation> tool will write files, and the I<scorer> tool will find them.

=item B<--dirGTF> I<directory>

Specify the I<system> I<directory> (or directory structure base, with the B<--ECF> option) in which the I<validation> tool will write files, and the I<scorer> tool will find them.

=item B<--ECF> I<ecffile.xml>

Specify the I<ECF> file from which, defining the list of I<tracking trial ID>s available to be scored and the specific controls they provide over XML files.

=item B<--FullResults>

Compute and display all the CLEARDRScorer tool's metrics.
The default is to only work with the MOTA.

=item B<--frameTol> I<framenbr>

The frame tolerance allowed for attributes to be outside of the object framespan

=item B<--gtf>

Specify that the files past this marker are reference files.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--man>

Display this man page.

=item B<--Overwrite>

For the I<validation> step run from this tool, when rewriting XML or MemDumps, the default is to not overwrite previously generated files. This option inhibit this feature and will force files to be overwritten.

=item B<--overlapNotRequired>

When running the scoring tool, do not refuse to score SYS files whose framespan does not fully contains the GTF framespan

=item B<--Scorer> I<tool>

Specify the full path location of the B<CLEARDTScorer> program

=item B<--skipValidation>

Do not perform the I<validation> step.

=item B<--TrackMOTA>

Create a MOTA computation tracking log in the directory where the scorer log is written.

=item B<--trackingTrial> I<ttid>

Only process validation and scoring for entries that are defined in the I<ECF> as part of the specified I<ttid>.

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

=over

=item B<AVSS09Scorer --xmllint /local/bin/xmllint --CLEARxsd /local/F4DE-CVS/data --writedir /tmp/results --dirGTF /tmp/GTF --DirSYS /tmp/SYS --frameTol 5 sys_test1.xml sys_test2.xml --gtf ref_test1.xml ref_test2.xml>

Using the I<xmllint> executable located at I</local/bin/xmllint>, with the required XSD files found in the I</local/F4DE/data> directory, putting all the generated SYS / GTF files in I</tmp/SYS> / I</tmp/GTF>, the results in I</tmp/results>, and using a frame tolerance of 5 frames, it will use:

=over

=item B<AVSS09ViPERValidator> to validate and generate the I<Scoring Sequence MemDump> files for the I<sys_test1.xml> and I<sys_test2.xml> I<system> files, as well as the I<ref_test1.xml> and I<ref_test2.xml> I<reference> files.

=item B<CLEARDTScorer> to perform scoring on those I<Scoring Sequence MemDump> files generated by the validation step.

=back

=item B<AVSS09Scorer --ECF test1-ecf.xml --writedir test1_results --dirGTF ValGTF --DirSYS ValSYS --cvs sys1.xml sys2.xml sys3.xml --gtf ref1.xml ref2.xml ref3.xml>

Where I<sysX.xml> and I<refX.xml> specify the I<SYS> and I<REF> files defining the I<testX.mov> I<sourcefile's filename>.

With the I<test1-ecf.xml> file definning the:

=over 

=item I<CPSPT01> task (of I<Camera Pair Single Person Tracking> (cpspt) type) for I<sourcefile's filename> S<test1.mov> and S<test2.mov>, with a specialized I<evaluation framespan>, adding a I<Don't Care Region> (DCR) and a I<Don't Care Frame> (DCF), and

=item I<SCSPT05b> task (of I<Single Camera Single Person Tracking> (scspt) type) for I<sourcefile's filename> S<test2.mov>, with a specialized I<evaluation framespan>.

=back

The B<AVSS09Scorer> wrapper will:

=over

=item use B<AVSS09ViPERValidator> using the ECF, to validate and generate the following I<Scoring Sequence MemDump> files:

For the I<CPSPT01> I<tracking trial ID> (ttid):
S<ValSYS/cpspt/CPSPT01/test1.mov/SYS/test1.mov.SSMemDump>, 
S<ValSYS/cpspt/CPSPT01/test2.mov/SYS/test2.mov.SSMemDump>
and
S<ValGTF/cpspt/CPSPT01/test1.mov/GTF/test1.mov.SSMemDump>,
S<ValGTF/cpspt/CPSPT01/test2.mov/GTF/test2.mov.SSMemDump>
onto which it will have applied the I<evaluation framespan>, DCR and DCF specific to this ttid.

For the I<SCSPT05b> ttid:
S<ValSYS/scspt/SCSPT05b/test2.mov/SYS/test2.mov.SSMemDump>
and 
S<ValGTF/scspt/SCSPT05b/test2.mov/GTF/test2.mov.SSMemDump>
onto which it will have applied the I<evaluation framespan> specific to this ttid.

It will discard I<ref3.xml> and I<sys3.xml> as their sourcefile's filename is not listed in the ECF.

=item post running the external validation tool, the wrapper will confirm that for the I<CPSTP01> and I<SCSPT05b> ttid, the I<Scoring Sequence MemDump> files are available in the I<ValSYS> and I<ValGTF> directories (following the special directory structure)

=item use B<CLEARDTScorer> for scoring in turn each I<tracking trial ID> using only the I<Scoring Sequence MemDump> needed for it.

=item post running the external scoring tool, the wrapper will find the expected CSV file, extract CLEAR result information and generate AVSS results in a text and CSV form. 

=back

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
  my $metrics = join(" ", @ok_needed[1..$#ok_needed]);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --man | --version] [--xmllint location] [--CLEARxsd location] [--ECF ecffile.xml [--trackingTrial ttid] [--AVSSxsd location]] --writedir directory --dirGTF directory --DirSYS directory [--frameTol framenbr] [--Validator tool] [--Overwrite] [--skipValidation] [--Scorer tool] [--overlapNotRequired] [--csv] [--TrackMOTA] [--FullResults] [sys_file.xml [sys_file.xml [...]] --gtf ref_file.xml [ref_file.xml [...]]]

Will call the AVSS09 Validation and CLEAR Scorer tools on the XML file(s) provided (System vs Reference).

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd      Path where the XSD files can be found
  --ECF           Specify the ECF XML file to load and score against
  --trackingTrial  Process only the requested \"tracking trial ID\"
  --AVSSxsd       Path where the XSD files needed for ECF validation can be found
  --writedir      Directory in which scoring will be performed
  --dirGFT        Directory in which validated GTF files are/will be 
  --DirSYS        Directory in which validated SYS files are/will be
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default: $frameTol)
  --Validator     Specify the full path location of the $valtool_bt tool (if not in your path)
  --Overwrite     Overwrite previously validated XML and MemDump files
  --skipValidation  Skip the validation process (will still check files needed for scoring)
  --Scorer        Specify the full path location of the $scrtool_bt tool (if not in your path)
  --overlapNotRequired  Do not refuse to score SYS vs REF in case a full overlap of the GTF framespan by the SYS is not true
  --csv           Request results to be put into a CSV file
  --TrackMOTA     Create a MOTA computation tracking log in the directory where the scorer log is written
  --FullResults   Print all metrics results ($metrics)

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'CLEAR.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will disard any xml comment(s).
- 'CLEARxsd' files are the same as needed by $valtool_bt
EOF
;

  return $tmp;
}
