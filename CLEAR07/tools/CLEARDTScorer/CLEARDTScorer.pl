#!/usr/bin/env perl

# CLEAR Detection and Tracking Scorer
#
# Author(s): Vasant Manohar
# Additions: Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAR Detection and Tracking Scorer" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
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

my $versionid = "CLEAR Detection and Tracking Scorer Version: $version";

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
foreach my $pn ("CLEARDTViperFile", "CLEARDTHelperFunctions", "CLEARSequence", "SimpleAutoTable") {
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
MMisc::error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Get some values from CLEARDTViperFile
my $dummy = new CLEARDTViperFile();
my @ok_objects = $dummy->get_full_objects_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
my @spmode_list = $dummy->get_spmode_list();
# We will use the '$dummy' to do checks before processing files

########################################
# Options processing

my $xmllint_env = "F4DE_XMLLINT";
my $det_thres   = 1.0;
my $trk_thres   = 1.0;
my $CostMiss    = 1.0;
my $CostFA      = 1.0;
my $CostIS      = 1.0;
my $frameTol    = 0;

my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Default values for variables
my $gtfs = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../data";
my $evaldomain  = undef;
my $eval_type   = undef;
my $bin         = 0;
my $writeres    = "";
my $spmode      = "";
my $spmode_run  = "";
my $csvfile     = "";
my $motalogdir  = undef;
my $ovnotreq    = 0;
my $qomf        = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   CDEF  I   M     S        bcd fgh    m      t vwx    #

my %opt;
my $dbgftmp = "";

my $commandline = $0 . " " . join(" ", @ARGV) . "\n\n";
my @sys = ();
my @ref = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'Domain=s'        => \$evaldomain,
   'Eval=s'          => \$eval_type,
   'detthres=f'      => \$det_thres,
   'trkthres=f'      => \$trk_thres,
   'MissCost=f'      => \$CostMiss,
   'FACost=f'        => \$CostFA,
   'ISCost=f'        => \$CostIS,
   'bin'             => \$bin,
   'frameTol=i'      => \$frameTol,
   'writeResults=s'  => \$writeres,   
   'gtf'             => sub {$gtfs++},
   'SpecialMode=s'   => \$spmode,
   'csv=s'           => \$csvfile,
   'motaLogDir:s'    => \$motalogdir,
   'overlapNotRequired' => \$ovnotreq,
   'quitOnMissingFiles' => \$qomf,
   # Non options (SYS + REF)
   '<>' => sub { if ($gtfs) { push @ref, @_; } else { push @sys, @_; } },
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Leftover arguments on the command line: " . join(", ", @ARGV))
  if (scalar @ARGV > 0);

if (defined $evaldomain) { 
  $evaldomain = uc($evaldomain);
  MMisc::error_quit("Unknown 'Domain'. Has to be (BN, MR, SV, UV), aborting\n\n$usage\n") if ( ($evaldomain ne "BN") && ($evaldomain ne "MR") && ($evaldomain ne "SV") && ($evaldomain ne "UV") );
  $dummy->set_required_hashes($evaldomain); 
}
else { MMisc::error_quit("'Domain' is a required argument (BN, MR, SV, UV), aborting\n\n$usage\n"); }

if (defined $eval_type) {
  if (lc($eval_type) eq "area") {
    $eval_type = "Area"; 
  } elsif (lc($eval_type) eq "point") {
    $eval_type = "Point";
  } else {
    MMisc::error_quit("Unknown 'EvalType'. Has to be (area, point), aborting\n\n$usage\n"); 
  }
} else {
  MMisc::error_quit("'EvalType' is a required argument (area, point), aborting\n\n$usage\n");
}

MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
  if ((! MMisc::is_blank($xmllint)) && (! $dummy->set_xmllint($xmllint)));

MMisc::error_quit("While trying to set \'CLEARxsd\' (" . $dummy->get_errormsg() . ")")
  if ((! MMisc::is_blank($xsdpath)) && (! $dummy->set_xsdpath($xsdpath)));

MMisc::error_quit("\'overlapNotRequired\' only authorized with \'SpecialMode\'")
  if (($ovnotreq) && (MMisc::is_blank($spmode)));

my $avss_full = "full"; # Authorized "AVSS" special mode modification
if (! MMisc::is_blank($spmode)) {
  if ($spmode =~ m%^(.+)\:(.+)$%) {
    $spmode = $1;
    $spmode_run = $2;
  }
  MMisc::error_quit("Problem with \'SpecialMode\' (" . $dummy->get_errormsg() . ")")
      if (! $dummy->is_spmode_ok($spmode));
  my $err = &check_spmode_run();
  MMisc::error_quit($err) if (! MMisc::is_blank($err));
}

if (! MMisc::is_blank($motalogdir)) {
  my $err = MMisc::check_dir_w($motalogdir);
  MMisc::error_quit("Problem with \'motaLogDir\' ($motalogdir): $err")
      if (! MMisc::is_blank($err));
}

MMisc::error_quit("Only one \'gtf\' separator allowed per command line, aborting")
  if ($gtfs > 1);

MMisc::error_quit("No SYS file(s) provided, can not perform scoring")
  if (scalar @sys == 0);
MMisc::error_quit("No REF file(s) provided, can not perform scoring")
  if (scalar @ref == 0);
MMisc::error_quit("Unequal number of REF and SYS files, can not perform scoring")
  if (scalar @ref != scalar @sys);

##########
# Main processing
my $ntodo = scalar @ref;

my $results = new SimpleAutoTable();
MMisc::error_quit("Error final results table: ".$results->get_errormsg()."\n")
   if (! $results->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

my (@ref_seqs, @sys_seqs);

for (my $loop = 0; $loop < $ntodo; $loop++) {
  my ($ref_ok, $gtSequence) = &load_file(1, $ref[$loop]);
  MMisc::error_quit("Could not load ground truth scoring sequence: $ref[$loop]\n") if (! $ref_ok);

  my %ref_seq = ( 'sequence'    => $gtSequence,
                  'filename'    => $gtSequence->getSeqFileName(),
                  'video_file'  => $gtSequence->getSourceFileName(),
                  'beg_fr'      => $gtSequence->getSeqBegFr(),
                  'end_fr'      => $gtSequence->getSeqEndFr(),
                );
  push @ref_seqs, \%ref_seq;

  my ($sys_ok, $sysSequence) = &load_file(0, $sys[$loop]);
  MMisc::error_quit("Could not load system output scoring seqeunce: $sys[$loop]\n") if (! $sys_ok);
  my %sys_seq = ( 'sequence'    => $sysSequence,
                  'filename'    => $sysSequence->getSeqFileName(),
                  'video_file'  => $sysSequence->getSourceFileName(),
                  'beg_fr'      => $sysSequence->getSeqBegFr(),
                  'end_fr'      => $sysSequence->getSeqEndFr(),
                );
  push @sys_seqs, \%sys_seq;
}

# Prepare for batch processing
my @files_to_be_processed;
foreach my $ref_file (@ref_seqs) {
  my $checkFlag = 0; # To check if we matched a reference file
  my ($ref_video_filename, $ref_start_frame, $ref_end_frame) = ($ref_file->{'video_file'}, $ref_file->{'beg_fr'}, $ref_file->{'end_fr'});
  foreach my $sys_file (@sys_seqs) {
    my ($sys_video_filename, $sys_start_frame, $sys_end_frame) = ($sys_file->{'video_file'}, $sys_file->{'beg_fr'}, $sys_file->{'end_fr'});
    # Systems can report outside of the evaluation framespan
    if ($ref_video_filename eq $sys_video_filename) {
      if ($ovnotreq) {
        push @files_to_be_processed, [$ref_file->{'sequence'}, $sys_file->{'sequence'}];
        $checkFlag = 1;
        last;
      }
      if (($sys_start_frame <= $ref_start_frame) && ($sys_end_frame >= $ref_end_frame)) {
        push @files_to_be_processed, [$ref_file->{'sequence'}, $sys_file->{'sequence'}];
        $checkFlag = 1;
        last;
      }
    }
    
  }
  MMisc::error_quit("Could not find matching system output file for " . $ref_file->{'filename'} . " (possibly no SYS file covering REF framespan range)")
      if (($qomf) && (! $checkFlag));
  print "Could not find matching system output file for " . $ref_file->{'filename'} . ". Skipping file\n" if (! $checkFlag);
}

my ($sfda_add, $ata_add, $moda_add, $modp_add, $mota_add, $motp_add) 
  = (1, 1, 1, 1, 1, 1);
# Note: For 'AVSS09' we are only interested in the MOTA, so if 'spmode'
#       is set to AVSS09, skip the scoring and set all values to NA
# Unless we requested "AVSS09:full"
($sfda_add, $ata_add, $moda_add, $modp_add, $motp_add) = (0, 0, 0, 0, 0)
  if (($spmode eq $spmode_list[0]) && ($spmode_run ne $avss_full));

# Start processing
my $ndone = 0;
my ($gtSequence, $sysSequence, $ref_eval_obj, $sys_eval_obj);
foreach my $ref_sys_pair (@files_to_be_processed){
  my ($sfda, $ata, $moda, $modp, $mota, $motp);
  $gtSequence = $ref_sys_pair->[0];
  $sysSequence = $ref_sys_pair->[1];

  $ref_eval_obj = $gtSequence->getEvalObj();
  $sys_eval_obj = $sysSequence->getEvalObj();

  if (MMisc::is_blank($ref_eval_obj) && MMisc::is_blank($sys_eval_obj)) { 
    &add_data2sat($results, $ndone+1, $gtSequence->getSeqFileName, $sysSequence->getSeqFileName, $gtSequence->getSourceFileName, $ref_eval_obj, $eval_type, $sfda, $ata, $moda, $modp, $mota, $motp);
    $ndone++;
    next;
  } elsif (MMisc::is_blank($ref_eval_obj)) {
    $ref_eval_obj = $sys_eval_obj; 
  } elsif (MMisc::is_blank($sys_eval_obj)) {
    $sys_eval_obj = $ref_eval_obj; 
  }
  
  MMisc::error_quit("Not possible to evaluate two different evaluation objects. Ground truth object: $ref_eval_obj\t System output object: $sys_eval_obj\n")
      if ($ref_eval_obj ne $sys_eval_obj);

  # SFDA & ATA
  if ($sfda_add) {
    $sfda = $gtSequence->computeSFDA($sysSequence, $eval_type, $det_thres, $bin);
    MMisc::error_quit("Error computing 'SFDA' (" . $gtSequence->get_errormsg() . ")")
        if ($gtSequence->error());
  }
  if ($ata_add) {
    $ata = $gtSequence->computeATA($sysSequence, $eval_type, $trk_thres, $bin);
    MMisc::error_quit("Error computing 'ATA' (" . $gtSequence->get_errormsg() . ")")
        if ($gtSequence->error());
  }
  
  # MODA & MODP
  if ($moda_add) {
    $moda = $gtSequence->computeMODA($sysSequence, $CostMiss, $CostFA, $eval_type, $det_thres, $bin);
    MMisc::error_quit("Error computing 'MODA' (" . $gtSequence->get_errormsg() . ")")
        if ($gtSequence->error());
  }
  if ($modp_add) {
    $modp = $gtSequence->computeMODP($sysSequence, $eval_type, $det_thres, $bin);
    MMisc::error_quit("Error computing 'MODP' (" . $gtSequence->get_errormsg() . ")")
        if ($gtSequence->error());
  }

  # MOTA & MOTP
  if ($mota_add) {
    my $mota_logfile = undef;
    my $mota_csvfile = undef;
    my $lsffn = $gtSequence->getSourceFileName();
    if (! MMisc::is_blank($motalogdir)) {
      $mota_logfile = "$motalogdir/$lsffn";
      $mota_csvfile = $mota_logfile
        if (! MMisc::is_blank($csvfile));
    } elsif (defined $motalogdir) {
      print "---------- [$lsffn] Tracking Log ----------\n";
      $mota_logfile = "";
    }
    $mota = $gtSequence->computeMOTA($sysSequence, $CostMiss, $CostFA, $CostIS, $eval_type, $trk_thres, $bin, $mota_logfile, $mota_csvfile);
    MMisc::error_quit("Error computing 'MOTA' (" . $gtSequence->get_errormsg() . ")")
        if ($gtSequence->error());
  }
  if ($motp_add) {
    $motp = $gtSequence->computeMOTP($sysSequence, $eval_type, $trk_thres, $bin);
    MMisc::error_quit("Error computing 'MOTP' (" . $gtSequence->get_errormsg() . ")")
        if ($gtSequence->error());
  }

  &add_data2sat($results, $ndone+1, $gtSequence->getSeqFileName, $sysSequence->getSeqFileName, $gtSequence->getSourceFileName, $ref_eval_obj, $eval_type, $sfda, $ata, $moda, $modp, $mota, $motp);

  $ndone++;
}

my $tbl = $results->renderTxtTable(2);
MMisc::error_quit("Generating Final Report (". $results->get_errormsg() . ")")
  if (! defined($tbl));

if (! MMisc::is_blank($csvfile)) {
  my $csvtxt = $results->renderCSV();
  MMisc::error_quit("Generating CSV Report (". $results->get_errormsg() . ")")
  if (! defined($csvtxt));
  MMisc::error_quit("Problem while trying to write CSV file ($csvfile)")
  if (! MMisc::writeTo($csvfile, "", 1, 0, $csvtxt));
}

my $param_setting = &get_param_settings();

my $output = $commandline . $param_setting . $tbl;
MMisc::error_quit("Problem while trying to \'write\'")
  if (! MMisc::writeTo($writeres, "", 1, 0, $output, "", "** Detection and Tracking Results:\n"));

MMisc::ok_quit("\n\n***** DONE *****\n");

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)){ 
    &valok($fname, "[ERROR] $_");
  }
}

##########

sub load_file {
  my ($isgtf, $tmp) = @_;

  my ($retstatus, $object, $msg) = 
    CLEARDTHelperFunctions::load_ScoringSequence($isgtf, $tmp, $evaldomain, $frameTol, $xmllint, $xsdpath, $spmode);

  if (! $retstatus) {
    &valerr($tmp, $msg);
  }

  return($retstatus, $object);
}

########################################

sub get_param_settings {
  my $str;

  if ($eval_type eq "Area") { $str = "Area Based Evaluation parameters: "; }
  else { $str = "Distance Based Evaluation parameters: "; }

  $str .= "Detection-Threshold = $det_thres (";
  if ($bin) { $str .= "Binary = True"; }
  else { $str .= "Binary = False"; }
  $str .= "); ";

  $str .= "Tracking-Threshold = $trk_thres (";
  if ($bin) { $str .= "Binary = True"; }
  else { $str .= "Binary = False"; }
  $str .= "); ";

  $str .= "Miss-Detect-Cost = $CostMiss; ";
  $str .= "False-Alarm-Cost = $CostFA; ";
  $str .= "ID-Switch-Cost = $CostIS.\n\n";

  return($str);
}

########################################

sub add_data2sat {
  my ($sat, $runid, $reffilename, $sysfilename, $videofilename, 
      $evalobj, $evaltype, $sfda, $ata, $moda, $modp, $mota, $motp) = @_;
  
  $sfda = sprintf("%.6f", $sfda);
  $ata = sprintf("%.6f", $ata);
  $moda = sprintf("%.6f", $moda);
  $modp = sprintf("%.6f", $modp);
  $mota = sprintf("%.6f", $mota);
  $motp = sprintf("%.6f", $motp);
  
  $sat->addData($reffilename, "Reference File", $runid);
  $sat->addData($sysfilename, "System Output File", $runid);
  $sat->addData($videofilename, "Video", $runid);
  $sat->addData($evalobj, "Object", $runid);

  if ($evaltype eq "Area") {
    $sat->addData($sfda, "SFDA", $runid) if ($sfda_add);
    $sat->addData($ata, "ATA", $runid)   if ($ata_add);
    $sat->addData($moda, "MODA", $runid) if ($moda_add);
    $sat->addData($modp, "MODP", $runid) if ($modp_add);
    $sat->addData($mota, "MOTA", $runid) if ($mota_add);
    $sat->addData($motp, "MOTP", $runid) if ($motp_add);
  } else {
    $sat->addData($sfda, "SFDA-D", $runid) if ($sfda_add);
    $sat->addData($ata, "ATA-D", $runid)   if ($ata_add);
    $sat->addData($moda, "MODA", $runid)   if ($moda_add);
    $sat->addData($modp, "MODP-D", $runid) if ($modp_add);
    $sat->addData($mota, "MOTA", $runid)   if ($mota_add);
    $sat->addData($motp, "MOTP-D", $runid) if ($motp_add);
  }
}

##########

sub check_spmode_run {
  my $err = "";

  return("") if (MMisc::is_blank($spmode_run));

  return("")
    if (($spmode eq $spmode_list[0]) && ($spmode_run eq $avss_full));

  return("Unknown \'special mode\' [$spmode] condition ($spmode_run)");
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

########################################

sub set_usage {
  my $ro = join(" ", @ok_objects);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $spml = join(" ", @spmode_list);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help] [--version] [--xmllint location] [--CLEARxsd location] --Domain name --Eval type [--frameTol framenbr] [--writeResult file] [--csv file] [--detthres value] [--trkthres value] [--bin] [--MissCost value] [--FACost value] [--ISCost value] [--SpecialMode mode[:trigger] [--overlapNotRequired]] [--motaLogDir [dir]] [--quitOnMissingFiles] sys_file.xml [sys_file.xml [...]] --gtf ref_file.xml [ref_file.xml [...]]

Will Score the XML file(s) provided (System vs Truth)

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd      Path where the XSD files can be found
  --Domain        Specify the evaluation domain for the set of files (BN, MR, SV, UV)
  --Eval          Specify the type of measures that you want to compute (Area, Point)
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default value: $frameTol)
  --writeResult   Specify the file into which the scoring result will be written
  --csv           Specify the file into which the CSV formatted scoring result will be written
  --detthres      Set the threshold for spatial overlap between reference and system objects when computing detection measures (default: $det_thres)
  --trkthres      Set the threshold for spatial overlap between reference and system objects when computing tracking measures (default: $trk_thres)
  --bin           Specify if the thresholding should be 'binary' ( >= thres = 1.0, < thres = 0.0) or 'regular' ( >=thres = 1.0, < thres = actual overlap ratio) (default: 'regular')
  --MissCost      Set the Metric's Cost for a Miss (default: $CostMiss)
  --FACost        Set the Metric's Cost for a False Alarm (default: $CostFA)
  --ISCost        Set the Metric's Cost for an ID Switch (default: $CostIS)
  --SpecialMode   Specify that the scorer is run using the CLEAR metric with a different evaluation rules (authorized modes: $spml)
  --overlapNotRequired  Do not refuse to score SYS vs REF in case a full overlap of the GTF framespan by the SYS is not true
  --motaLogDir    Specify the directory in which one log file per sourcefile filename is written, containing an evaluated-frame per evaluated-frame decomposition of the tracking analysis. If no directory is provided, print to stdout
  --quitOnMissingFiles  Quit if any of the input file is not scorable at pre-scoring check
  --gtf           Specify that the files past this marker on the command line are Ground Truth Files  

Note:
- Program will ignore the <config> section of the XML file.
- List of recognized objects: $ro
- 'CLEARxsd' files are: $xsdfiles
EOF
;

  return $tmp;
}
