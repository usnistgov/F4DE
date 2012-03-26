#!/usr/bin/env perl

# Tracking Log Dump Analyzer
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Tracking Log Dump Analyzer" is an experimental system.
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

my $versionid = "Tracking Log Dump Analyzer Version: $version";

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
foreach my $pn ("MMisc", "CSVHelper", "CLEARMetrics") {
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

my $costMD = 1;
my $costFA = 1;
my $costIS = 1;
my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:      F  I   M     S             gh      o   s  v     #

my $outdir = "";
my $gpmode = 0;
my $shiftf = 0;
my $skbg = 0;

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'outdir=s'      => \$outdir,
   'gnuplot_mode'  => \$gpmode,
   'FAcost=i'      => \$costFA,
   'MDcost=i'      => \$costMD,
   'IScost=i'      => \$costIS,
   'shift_frames'  => \$shiftf,
   'SkipBeforeFirstGTF' => \$skbg,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

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

my $done = 0;
my $todo = 0;
foreach my $file (@ARGV) {
  $todo++;

  my $err = &doit($file, $ob);
  print "$file: ";
  if (MMisc::is_blank($err)) {
    print "OK\n";
    $done++;

    next;
  } 

  print "ERROR [$err]\n";
}

MMisc::error_quit("Not all files completed ($done/$todo)\n")
  if ($done != $todo);

MMisc::ok_quit("Done\n");

####################

sub doit {
  my ($in, $ob) = @_;

  my $err = MMisc::check_file_r($in);
  return("Problem with input file ($in) : $err")
    if (! MMisc::is_blank($err));

  my $tcsvh = new CSVHelper();
  my @h = ("Frame");
  my %out = $tcsvh->loadCSV_tohash($in, @h);
  return("CSV: " . $tcsvh->get_errormsg())
    if ($tcsvh->error());

  my $csvh = undef;

  if ($gpmode) { 
    $csvh = new CSVHelper(" ", "\t");
  } else {
    $csvh = new CSVHelper();
  }
  
  my @header = 
    (
     "Frame",
     "CostMD","SumMD","CostFA","SumFA","CostIS",
     "SumIDSplit","SumIDMerge","NumberOfEvalGT",
     "MOTA", "CorDet", "NumSys",
     "Precision", "Recall", "FrameF1",
    );
  
  my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($in);
  return("Problem with filename ($in): $err")
      if (! MMisc::is_blank($err));
    
  $ob .= $f;
  $ob =~ s%\-$%%;
  
  my $of = "${ob}-TLD_motaF1." . (($gpmode) ? "gp_" : "") . "csv";
  my $otxt = "";

  $csvh->set_number_of_columns(scalar @header);

  my $wroteheader = 0;
  my $sf = undef;
  foreach my $f (sort _num keys %out) {
    if (! defined $sf) {
      if ($shiftf) {
        $sf = $f - 1;
      } else {
        $sf = 0;
      }
    }
 
    my $cf = $f - $sf;

    my @linec = ();
    
    push @linec, $cf;
    
    my @motac = &get_MOTAc($f, \%out);
    return("Problem extracting the 8 components of the MOTA for frame ($f), seen " . scalar @motac)
      if (scalar @motac != 8);
    push @linec, @motac;

    # In 'SkipBeforeFirstGTF' mode, do not process unless # GTF > 0
    if (($skbg) && ($motac[7] == 0)) {
      $sf = undef; # Reset 'shift_frames' computation

      next;
    }

    my $motav = &_get_XXX($f, "global MOTA", \%out);
    push @linec, $motav;
    
    my ($cordet, @prff1) = &get_FrameF1plus(@motac);
    my $nsys = &get_numSys(@motac);
    push @linec, $cordet;
    push @linec, $nsys;
    push @linec, @prff1;
    
    if ($wroteheader == 0) {
      my ($ok, $txt) = &generate_csvline($csvh, @header);
      return("Problem genreating CSV line: $txt") if (! $ok);
      $otxt .= "$txt\n";
      $wroteheader = 1;
    }
 
    my ($ok, $txt) = &generate_csvline($csvh, @linec);
    return("Problem generating CSV line: $txt") if (! $ok);
    $otxt .= "$txt\n";
  }
  
  if (MMisc::is_blank($otxt)) {
    MMisc::warn_print("Skipping file write step ($of), no data to write");
    return("");
  }

  return("Problem while trying to write CSV file ($of)")
    if (! MMisc::writeTo($of, "", 1, 0, $otxt));
  
  return("");
}

####################

sub _num { $a <=> $b };

#####

sub _get_XXX {
  my ($f, $xxx, $rout) = @_;

  MMisc::error_quit("Could not find [$f]")
      if (! exists $$rout{$f}{$xxx});

  my @v = @{$$rout{$f}{$xxx}};

  MMisc::error_quit("More than one value possible for [$f]")
    if (scalar @v > 1);

  return($v[0]);
}

##########

sub get_MOTAc {
  my ($f, $rout) = @_;

  my @needed = ($costMD, "global MissedDetect", $costFA, "global FalseAlarm",
                $costIS, "global IDSplit", "global IDMerge", 
                "global NumberOfEvalGT");

  my @motac = ();
  for (my $i = 0; $i < scalar @needed; $i++) {
    my $n = $needed[$i];
    my $v = $n;

    ($v) = &_get_XXX($f, $n, $rout) if (! MMisc::is_float($n));

    push @motac, $v;
  }

  return(@motac);
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

sub generate_csvline {
  my ($csvh, @linec) = @_;

  my $cl = $csvh->array2csvline(@linec);
  return(0, "Problem with CSV line: " . $csvh->get_errormsg())
    if ($csvh->error());

  return(1, $cl);
}

############################################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--outdir dir] [--shift_frames] [--SkipBeforeFirstGTF] [--gnuplot_mode] [--FAcost cost] [--MDcost cost] [--IScost cost] TrackingLog_Dumper_output.csv

Will generate CSV files with MOTA and FrameF1 information from the CSV generated by using the TrackingLog_Dumper tool

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --outdir        The output directory in which to generate the results
  --shift_frames  Shift all the frames seen so that the first rewritten one start at 1 (copy seen value otherwise)
  --SkipBeforeFirstGTF  Skip generation of output until the first GTF object is seen
  --gnuplot_mode  Allow the CSV files to be gnuplot usable
  --FAcost        Specify the cost of False Alarms for MOTA computation (default: $costFA)
  --MDcost        Specify the cost of Missed Detects for MOTA computation (default: $costMD)
  --IScost        Specify the cost of ID Switch for MOTA computation (default: $costIS)
EOF
;
  
  return $tmp;
}
