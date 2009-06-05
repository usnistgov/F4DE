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
foreach my $pn ("CLEARDTViperFile", "CLEARDTHelperFunctions", "Sequence", "SimpleAutoTable") {
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

# Default values for variables
my $gtfs = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../data";
my $evaldomain  = undef;
my $eval_type   = undef;
my $bin         = 0;
my $writeres    = "";
my $spmode      = "";
my $csvfile     = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   CDEF  I   M     S        bcd fgh           t vwx    #

my %opt;
my $dbgftmp = "";

my $commandline = $0 . " " . join(" ", @ARGV) . "\n\n";
my @leftover;
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
   'gtf'             => sub {$gtfs++; @leftover = @ARGV},
   'SpecialMode=s'   => \$spmode,
   'csv=s'           => \$csvfile,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

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

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
  if ((! MMisc::is_blank($xmllint)) && (! $dummy->set_xmllint($xmllint)));

MMisc::error_quit("While trying to set \'CLEARxsd\' (" . $dummy->get_errormsg() . ")")
  if ((! MMisc::is_blank($xsdpath)) && (! $dummy->set_xsdpath($xsdpath)));

MMisc::error_quit("Problem with \'SpecialMode\' (" . $dummy->get_errormsg() . ")")
  if ((! MMisc::is_blank($spmode)) && (! $dummy->is_spmode_ok($spmode)));

MMisc::error_quit("Only one \'gtf\' separator allowed per command line, aborting")
  if ($gtfs > 1);

my ($rref, $rsys) = &get_sys_ref_filelist(\@leftover, @ARGV);
my @ref = @{$rref};
my @sys = @{$rsys};
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
        if (($ref_video_filename eq $sys_video_filename) && ($sys_start_frame <= $ref_start_frame) && ($sys_end_frame >= $ref_end_frame)) {
            push @files_to_be_processed, [$ref_file->{'sequence'}, $sys_file->{'sequence'}];
            $checkFlag = 1;
            last;
        }
    }
    print "Could not find matching system output file for " . $ref_file->{'filename'} . ". Skipping file\n" if (! $checkFlag);
}

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
  
  $sfda = $gtSequence->computeSFDA($sysSequence, $eval_type, $det_thres, $bin);
  MMisc::error_quit("Error computing 'SFDA' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());
  $ata = $gtSequence->computeATA($sysSequence, $eval_type, $trk_thres, $bin);
  MMisc::error_quit("Error computing 'ATA' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());

  $moda = $gtSequence->computeMODA($sysSequence, $CostMiss, $CostFA, $eval_type, $det_thres, $bin);
  MMisc::error_quit("Error computing 'MODA' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());
  $modp = $gtSequence->computeMODP($sysSequence, $eval_type, $det_thres, $bin);
  MMisc::error_quit("Error computing 'MODP' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());

  $mota = $gtSequence->computeMOTA($sysSequence, $CostMiss, $CostFA, $CostIS, $eval_type, $trk_thres, $bin);
  MMisc::error_quit("Error computing 'MOTA' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());
  $motp = $gtSequence->computeMOTP($sysSequence, $eval_type, $trk_thres, $bin);
  MMisc::error_quit("Error computing 'MOTP' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());

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

sub get_sys_ref_filelist {
  my $rlo = shift @_;
  my @args = @_;

  my @lo = @{$rlo};

  @args = reverse @args;
  @lo = reverse @lo;

  my @ref;
  my @sys;
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
     $sat->addData($sfda, "SFDA", $runid);
     $sat->addData($ata, "ATA", $runid);
     $sat->addData($moda, "MODA", $runid);
     $sat->addData($modp, "MODP", $runid);
     $sat->addData($mota, "MOTA", $runid);
     $sat->addData($motp, "MOTP", $runid);
 }
 else {
     $sat->addData($sfda, "SFDA-D", $runid);
     $sat->addData($ata, "ATA-D", $runid);
     $sat->addData($moda, "MODA", $runid);
     $sat->addData($modp, "MODP-D", $runid);
     $sat->addData($mota, "MOTA", $runid);
     $sat->addData($motp, "MOTP-D", $runid);
 }

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

Usage: $0 [--help] [--version] [--xmllint location] [--CLEARxsd location] --Domain name --Eval type [--frameTol framenbr] [--writeResult file] [--csv file] [--detthres value] [--trkthres value] [--bin] [--MissCost value] [--FACost value] [--ISCost value] [--SpecialMode mode] sys_file.xml [sys_file.xml [...]] --gtf ref_file.xml [ref_file.xml [...]]

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
  --gtf           Specify that the files past this marker on the command line are Ground Truth Files  

Note:
- Program will ignore the <config> section of the XML file.
- List of recognized objects: $ro
- 'CLEARxsd' files are: $xsdfiles
EOF
;

  return $tmp;
}
