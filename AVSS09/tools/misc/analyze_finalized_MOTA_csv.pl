#!/usr/bin/env perl

# MOTA Component CSV analyzer
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "MOTA Component CSV analyzer" is an experimental system.
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

my $versionid = "MOTA Component CSV analyzer Version: $version";

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
foreach my $pn ("MMisc", "SimpleAutoTable", "CSVHelper", "CLEARMetrics") {
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

my @slok = ("true", "false"); # Order is important
my @hash_order = ("SITE", "EXPID", "TASK", "TTID", "Cam ID"); # order is important
my $slnm = "SelectAdd";
my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:   C         M                  f h      o   s  v     #

my $outdir = "";
my $filebase = "";
my $compMOTE = 0;
my $camseq = "";
my $slf = "";

my @fl = ();
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'outdir=s'      => \$outdir,
   'filebase=s'    => \$filebase,
   'MOTE'          => \$compMOTE,
   'CamSeq=s'      => \$camseq,
   'select=s'      => \$slf,
   '<>'            => sub { my $f = shift @_; my $err = MMisc::check_file_r($f); MMisc::error_quit("Problem with input file ($f) : $err") if (! MMisc::is_blank($err)); push @fl, $f;},
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @fl == 0);

my $ob = "";
if (! MMisc::is_blank($outdir)) {
  my $err = MMisc::check_dir_w($outdir);
  MMisc::error_quit("Problem with \'outdir\' ($outdir): $err")
      if (! MMisc::is_blank($err));
  $outdir =~ s%/$%%;
  MMisc::error_quit("\'\/\' is not an authorized value for \'outdir\'")
      if (MMisc::is_blank($outdir));
  $ob = "$outdir/";
}
if (! MMisc::is_blank($filebase)) {
  my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($filebase);
  MMisc::error_quit("Problem with \'filebase\' ($filebase): $err")
      if (! MMisc::is_blank($err));

  MMisc::error_quit("Problem with \'filebase\' ($filebase): directoryin value")
      if (! MMisc::is_blank($d));
  if (! MMisc::is_blank($e)) {
    MMisc::warn_print("Found a possible extension in file name, replacing \'.\' by \'_\'");
    $filebase = $f . "_" . $e;
  }
  $ob .= $filebase;
  $ob =~ s%\-$%%;
  $ob .= "-";
}

my %cseq = ();
if (! MMisc::is_blank($camseq)) {
  (my $cseq_csvh, %cseq) = &load_CSV2hash($camseq, "TTID", "Cam ID");
}

my $sat = new SimpleAutoTable();
MMisc::error_quit("While creating SAT : " . $sat->get_errormsg())
  if (! $sat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

#####

my $ksplit = "###";

my @mota_h = ();
my $mota_s = 1;
my %motac_mk = ();
my %motac_ttid = ();
my %motac_camid = ();
my %motac_task = ();
my %motac_pricam = ();
my %motac_camseq = ();

my %out = ();

foreach my $file (@fl) {
  %out = ();
  &process_file($file);
}

# Finalize values
&FinalizeResults($sat, \%motac_mk, "${ob}motaF1");
&generateSpecialResults(\%motac_ttid, "TTID", "${ob}TTID-motaF1");
&generateSpecialResults(\%motac_camid, "Cam ID", "${ob}CamID-motaF1");
&generateSpecialResults(\%motac_task, "TASK", "${ob}TASK-motaF1");
if (scalar keys %cseq > 0) {
  &generateSpecialResults(\%motac_pricam, "Cam ID",
                          "${ob}PrimaryCamID-motaF1", "Primary Cam");
  &generateSpecialResults(\%motac_camseq, "Cam ID",
                          "${ob}SequenceCamID-motaF1", "Cam Seq");
}

MMisc::ok_quit("Done\n");

####################

sub process_file {
  my ($in) = @_;

  (my $csvh, %out) = &load_CSV2hash($in, @hash_order);

  foreach my $site (sort keys %out) {
    foreach my $expid (sort keys %{$out{$site}}) {
      foreach my $task (sort keys %{$out{$site}{$expid}}) {
        foreach my $ttid (sort keys %{$out{$site}{$expid}{$task}}) {
          foreach my $camid (sort _num keys %{$out{$site}{$expid}{$task}{$ttid}}) {
      
            ##
            my $cont = 1;
            my $sladd = "";
            if (! MMisc::is_blank($slf)) {
              my ($rc, $so, $se) = 
                MMisc::do_system_call($slf, $site, $expid, $task, $ttid, $camid);
              MMisc::error_quit("Problem calling \'select\' ($slf)")
                  if ($rc != 0);
              $so =~ s%^(\w+)%%;
              my $rv = $1;
              MMisc::error_quit("Did not find a valid select output [$rv]")
                  if ((MMisc::is_blank($rv)) || (! grep(m%^$rv$%i, @slok)));

              $cont = 0 if ($slok[-1] =~ m%^$rv$%i);

              $sladd = MMisc::clean_begend_spaces($so);
            }
            next if (! $cont);

            ##
            my ($mk) = &_get_XXX($site, $expid, $task, $ttid, $camid, "MasterKey");
            
            $sat->addData($site, "SITE", $mk);
            $sat->addData($expid, "EXPID", $mk);
            $sat->addData($task, "TASK", $mk);
            $sat->addData($ttid, "TTID", $mk);
            $sat->addData($camid, "CamID", $mk);
            
            my $cseqv = undef;
            if (scalar keys %cseq > 0) {
              $cseqv = &get_camseq($ttid, $camid);
              $sat->addData($cseqv, "CamSeq", $mk);
            }
            
            ##
            my @motac = &addMOTA2sat($sat, $mk, $site, $expid, $task, $ttid, $camid);
            
            ##
            $mota_s = 0;
            
            ##
            &addMOTAcomps2hash(\%motac_mk, $mk, @motac);
            &addMOTAcomps2hash(\%motac_ttid, $ttid, @motac);
            &addMOTAcomps2hash(\%motac_camid, $camid, @motac);
            &addMOTAcomps2hash(\%motac_task, $task, @motac);
            
            ##
            if (defined $cseqv) {
              my $spkey = &_join_keys($camid, ($cseqv == 1) ? "Y" : "N");
              &addMOTAcomps2hash(\%motac_pricam, $spkey, @motac);
              my $spkey = &_join_keys($camid, $cseqv);
              &addMOTAcomps2hash(\%motac_camseq, $spkey, @motac);
            }
            
            ##
            &addFrameF1plus2sat($sat, $mk, @motac);
            
            # 
            &addMOTE2sat($sat, $mk, @motac);

            ##
            if (! MMisc::is_blank($sladd)) {
              $sat->addData($sladd, $slnm, $mk);
            }
            
          }
        }
      }
    }
  }
}

##########

sub _num { $a <=> $b };

#####

sub _get_XXX {
  my ($site, $expid, $task, $ttid, $camid, $xxx) = @_;

  my $t = "$site / $expid / $task / $ttid / $camid / $xxx";
  MMisc::error_quit("Could not find [$t]")
      if (! exists $out{$site}{$expid}{$task}{$ttid}{$camid}{$xxx});

  my @v = @{$out{$site}{$expid}{$task}{$ttid}{$camid}{$xxx}};

  MMisc::error_quit("More than one value possible for [$t]")
    if (scalar @v > 1);

  return($v[0]);
}

##########

sub get_MOTAc {
  my ($site, $expid, $task, $ttid, $camid) = @_;

  my @needed = ("CostMD","SumMD","CostFA","SumFA","CostIS",
                "SumIDSplit","SumIDMerge","NumberOfEvalGT");

  my @motac = ();
  my @am = ();
  foreach my $x (@needed) {
    my ($v) = &_get_XXX($site, $expid, $task, $ttid, $camid, $x);

    push @motac, $v;

    push @am, $x;
    push @am, $v;
  }

  return(@am);
}

##########

sub get_FrameF1plus {
  my $cordet = CLEARMetrics::get_CorrectDetect_fromMOTAcomp(@_);

  my ($prec, $rec, $ff1) = 
    CLEARMetrics::get_Precision_Recall_FrameF1_fromMOTAcomp(@_);

  return($cordet, $prec, $rec, $ff1);
}

##########

sub get_numSys {
  return(CLEARMetrics::get_NumSys_fromMOTAcomp(@_));
}

####################

sub addMOTA2sat {
  my ($sat, $id, $site, $expid, $task, $ttid, $camid) = @_;

  my @comps = &get_MOTAc($site, $expid, $task, $ttid, $camid);

  my @motac = ();
  while (scalar @comps > 0) {
    my $h = shift @comps;
    my $v = shift @comps;
    push @motac, $v;
    push @mota_h, $h if ($mota_s);
  }

  &addMOTAc2sat($sat, $id, @motac);
  
  return(@motac);
}

##########

sub addMOTAc2sat {
  my ($sat, $id, @motac) = @_;

  for (my $i = 0; $i < scalar @motac; $i++) {
    my $v = $motac[$i];
    my $h = $mota_h[$i];
    $sat->addData($v, $h, $id);
  }
  my $mota = CLEARMetrics::computePrintableMOTA(@motac);
  $sat->addData($mota, "MOTA", $id);
}

##########

sub addFrameF1plus2sat {
  my ($sat, $id, @motac) = @_;

  my ($cordet, $precision, $recall, $framef1) = &get_FrameF1plus(@motac);
          
  $sat->addData($cordet, "CorDet", $id);
          
  $sat->addData($precision, "Precision", $id);
  $sat->addData($recall, "Recall", $id);
  $sat->addData($framef1, "Frame F1", $id);
  
  my $nsys = &get_numSys(@motac, $cordet);
  $sat->addData($nsys, "NumberOfSys", $id);
}

##########

sub addMOTE2sat {
  return() if (! $compMOTE);

  my ($sat, $id, @motac) = @_;

  my ($mote, $mote_md, $mote_fa, $mote_is, $mote_im) = 
    CLEARMetrics::get_MOTE_comp_fromMOTAcomp(@motac);

  $sat->addData($mote_md, "MOTE(miss)", $id);
  $sat->addData($mote_fa, "MOTE(fa)", $id);
  $sat->addData($mote_is, "MOTE(split)", $id);
  $sat->addData($mote_im, "MOTE(merge)", $id);
  
  $sat->addData($mote, "MOTE", $id);
}

####################

sub writeFiles {
  my ($fb, $sat) = @_;

  my $txtfile = "$fb.txt";
  my $tbl = $sat->renderTxtTable(2);
  MMisc::error_quit("Problem rendering SAT: ". $sat->get_errormsg())
      if (! defined($tbl));
  MMisc::error_quit("Problem while trying to write text file ($txtfile)")
      if (! MMisc::writeTo($txtfile, "", 1, 0, $tbl));
  
  my $csvfile = "$fb.csv";
  my $csvtxt = $sat->renderCSV();
  MMisc::error_quit("Generating CSV Report: ". $sat->get_errormsg())
      if (! defined($csvtxt));
  MMisc::error_quit("Problem while trying to write CSV file ($csvfile)")
      if (! MMisc::writeTo($csvfile, "", 1, 0, $csvtxt));
}

#################### 1 key hash

sub addMOTAcomps2hash {
  my ($rhash, $key, @motac) = @_;

  (my $err, @{$$rhash{$key}}) = CLEARMetrics::sumMOTAcomp(@{$$rhash{$key}}, @motac);
  MMisc::error_quit("MOTA Sum: $err") if (! MMisc::is_blank($err));
}

##########

sub finalizeHashMOTAcomps {
  my ($rh) = @_;

  my @tmp = ();
  foreach my $k (keys %{$rh}) {
    (my $err, @tmp) = CLEARMetrics::sumMOTAcomp(@tmp, @{$$rh{$k}});
    MMisc::error_quit("MOTA Sum: $err") if (! MMisc::is_blank($err));
  }

  return(@tmp);
}

#########

sub FinalizeResults {
  my ($sat, $rh, $ofb) = @_;

  my $id = "ZZ -- Finalized Results";
  my @mota_comp_sum = &finalizeHashMOTAcomps($rh);
  &addMOTAc2sat($sat, $id, @mota_comp_sum);
  &addFrameF1plus2sat($sat, $id, @mota_comp_sum);
  &addMOTE2sat($sat, $id, @mota_comp_sum);
  &writeFiles($ofb, $sat);
}

##########

sub generateSpecialResults {
  my ($rh, $ck, $ofb, $key2) = @_;

  my $sat = new SimpleAutoTable();
  MMisc::error_quit("While creating SAT : " . $sat->get_errormsg())
      if (! $sat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

  foreach my $key (sort keys %{$rh}) {
    my $id = $ck;
    $id .= " - $key2" if (! MMisc::is_blank($key2));
    $id .= " - $key";
    if (MMisc::is_blank($key2)) {
      $sat->addData($key, $ck, $id);
    } else {
      my ($k1, $k2) = &_split_keys($key);
      $sat->addData($k1, $ck, $id);
      $sat->addData($k2, $key2, $id);
    }
    my @motac = @{$$rh{$key}};
    &addMOTAc2sat($sat, $id, @motac);
    &addFrameF1plus2sat($sat, $id, @motac);
    &addMOTE2sat($sat, $id, @motac);
  }
  
  &FinalizeResults($sat, $rh, $ofb);
}

####################

sub _join_keys {
  return(join($ksplit, @_));
}

#####

sub _split_keys {
  my $v = shift @_;
  return(split(m%$ksplit%, $v));
}

####################

sub load_CSV2hash {
 my ($file, @h) = @_;

  my $err = MMisc::check_file_r($file);
  MMisc::error_quit("Problem with input file ($file) : $err")
      if (! MMisc::is_blank($err));

  my $csvh = new CSVHelper();
  my %out = $csvh->loadCSV_tohash($file, @h);
  MMisc::error_quit("For CSV file ($file): " . $csvh->get_errormsg())
      if ($csvh->error());

  return($csvh, %out);
}

##########

sub get_camseq {
  my ($ttid, $camid) = @_;
  my $xxx = "Cam Seq";

  my $t = "TTID: $ttid / CAMID: $camid / Key: $xxx";
  if (! exists $cseq{$ttid}{$camid}{$xxx}) {
    MMisc::warn_print("Could not find [$t], returning '0' (not in set)");
    return(0);
  }

  my @v = @{$cseq{$ttid}{$camid}{$xxx}};

  MMisc::error_quit("More than one value possible for [$t]")
    if (scalar @v > 1);

  return($v[0]);
}

####################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

############################################################

sub set_usage {
  my $slansw = join(", ", @slok);
  my $t = $slok[0];
  my $hord = join(", ", @hash_order);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--MOTE] [--CamSeq csvfile] --outdir dir --filebase prefix --select function file-MOTA_Components.csv

Will generate analysises based on data found in the MOTA components files generated by the the finalize EXPID tool

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --MOTE          Compute the MOTE and its components (where: MOTA = 1 - MOTE)
  --CamSeq        Specify the CSV file containing the camera sequence definition (needed headers are: \"TTID\", \"Cam ID\" and \"Cam Seq\")
  --outdir        The output directory in which to generate the results
  --filebase      The prefix of all the files written
  --select        Call a program to check which lines to keep with arguments and expect a specific answer (args: $hord) (answ: $slansw) [for "$t", the word after will be added as the last column of the file named $slnm]
EOF
;
  
  return $tmp;
}
