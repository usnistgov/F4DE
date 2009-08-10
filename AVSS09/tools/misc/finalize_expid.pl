#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# AVSS09 -- for Scoring: EXPID Finalizer
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS09 -- for Scoring: EXPID Finalizer" is an experimental system.
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

my $versionid = "AVSS09 -- for Scoring: EXPID Finalizer Version: $version";

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
foreach my $pn ("MMisc", "SimpleAutoTable", "AVSS09HelperFunctions") {
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

my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                   S              h    m     st v     #

my $scr_dir = "";
my $site = "";
my $expid = "";
my $task = "";
my @metrics = ();
my $outdir = "";

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'scoring_dir=s'      => \$scr_dir,
   'Site=s'             => \$site,
   'expid=s'            => \$expid,
   'task=s'             => \$task,
   'metric=s'           => \@metrics,
   'outdir=s'           => \$outdir,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

MMisc::ok_quit("All options have to be defined, aborting\n\n$usage\n")
  if (MMisc::any_blank($scr_dir, $site, $expid, $task));
MMisc::ok_quit("No metric specified, aborting\n\n$usage\n")
  if (scalar @metrics == 0);

my $mota_sat = undef;
my $mota_sat_file = "";
my $added_mota_data = 0;
if (grep(m%^MOTA$%, @metrics)) {
  $mota_sat = new SimpleAutoTable();
  MMisc::error_quit("While creating MOTA global SAT : " . $mota_sat->get_errormsg())
    if (! $mota_sat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));
}

my @ttidl = @ARGV;

foreach my $metric (@metrics) {
  my $txt = "[$site / $expid / $metric]";
  my ($ok, $warn, $err) = &finalize_expid($scr_dir, $site, $expid, $task, $metric, @ttidl);
  MMisc::warn_print("$txt $warn") if (! MMisc::is_blank($warn));
  MMisc::error_quit("$txt Problem finalizing: $err")
      if (! MMisc::is_blank($err));
  print "$txt $ok\n" if (! MMisc::is_blank($ok));
}

if (defined $mota_sat) {
  if ($added_mota_data) {
    my $txtfile = "$mota_sat_file.txt";
    my $tbl = $mota_sat->renderTxtTable(2);
    MMisc::error_quit("Problem rendering MOTA SAT: ". $mota_sat->get_errormsg())
      if (! defined($tbl));
    MMisc::error_quit("Problem while trying to write MOTA text file ($txtfile)")
      if (! MMisc::writeTo($txtfile, "", 1, 0, $tbl));
    
    my $csvfile = "$mota_sat_file.csv";
    my $csvtxt = $mota_sat->renderCSV();
    MMisc::error_quit("Generating MOTA CSV Report: ". $mota_sat->get_errormsg())
      if (! defined($csvtxt));
    MMisc::error_quit("Problem while trying to write CSV file ($csvfile)")
      if (! MMisc::writeTo($csvfile, "", 1, 0, $csvtxt));
  } else {
    MMisc::warn_print("Never added any data to the MOTA sat, not writting it");
  }
}
  

MMisc::ok_quit("All EXPID [$expid] metrics finalized\n");

########## END

sub finalize_expid {
  my ($scr_dir, $site, $expid, $task, $metric, @ttidl) = @_;

  my @nok = ();
  foreach my $ttid (@ttidl) {
    my $bdd = AVSS09HelperFunctions::get_scoringstep_destdir($scr_dir, "", $site, $expid, $ttid, "");
    return("", "", "Problem obtaining scoringstep destdir") if (! defined($bdd));
    push(@nok, $bdd) if (! MMisc::is_dir_r($bdd));
  }
  return("", "Can not finalize, not all directories are completed (" . join(", ", @nok) .  ")\n", "")
    if (scalar @nok > 0);
  
  my $bofile = AVSS09HelperFunctions::get_scoringstep_destdir($scr_dir, "", $site, $expid, "", "");

  if (! MMisc::is_blank($outdir)) {
    my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($bofile);
    return("", "", $err) if (! MMisc::is_blank($err));
    $bofile = MMisc::concat_dir_file_ext($outdir, $f, $e);
  }

  $mota_sat_file = "$bofile-MOTA_Components"
    if (MMisc::is_blank($mota_sat_file));

  my $eout = "$bofile-ECF-global_results-$metric";
  my $txtfile = "$eout.txt";
  return("", "Skipped, already done", "") if (-e $txtfile);

  # ECF/csv
  my $csvfile = "$eout.csv";
  my $sat = new SimpleAutoTable();
  return("", "", "While preparing print results : " . $sat->get_errormsg() . "\n")
    if (! $sat->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

  my @exp_header = ("Tracking Trial ID","Primary Cam ID","Primary Cam $metric","Cam 1 $metric","Cam 2 $metric","Cam 3 $metric","Cam 4 $metric","Cam 5 $metric","Cam Avg $metric");

  foreach my $ttid (@ttidl) {
    my $bdd = AVSS09HelperFunctions::get_scoringstep_destdir($scr_dir, "", $site, $expid, $ttid, "");
    my $used_csv = "$bdd/ECF-global_results-$metric.csv";
    my $err = MMisc::check_file_r($used_csv);
    return("", "", "Can not finalize, problem with file ($used_csv): $err")
      if (! MMisc::is_blank($err));

    my @added = $sat->add_selected_from_CSV($used_csv, "NA", "$site - $expid - $ttid", @exp_header);
    return("", "", "Can not finalize, problem with file ($used_csv): " . $sat->get_errormsg())
      if ($sat->error());
    MMisc::warn_print("[$site] Added more than one entry from CSV file [$used_csv] (1 expected, found " . scalar @added . ")")
        if (scalar @added > 1);

    if ($metric eq "MOTA") {
      my $csvtl = "$bdd/$task/$ttid/$ttid-Combined_MOTA.csv";
      my ($mota_cv, $err) = &extract_combined_mota_value($csvtl);
      if (! MMisc::is_blank($err)) {
        MMisc::warn_print("[$site] problem obtaining Combined MOTA for $ttid: $err");
      } elsif (! defined $mota_cv) {
        MMisc::warn_print("[$site] problem obtaining Combined MOTA for $ttid");
      } else {
        $sat->addData($mota_cv, "Frame Avg MOTA", $added[0]);
      }
      my $err = &add_to_mota_sat($csvtl, $site, $expid, $task, $ttid);
      MMisc::warn_print("[$site] problem working on global MOTA CSV (at $ttid): $err")
        if (! MMisc::is_blank($err));
    }

  }

  my $tbl = $sat->renderTxtTable(2);
  return("", "", "Problem rendering SAT: ". $sat->get_errormsg())
    if (! defined($tbl));
  return("", "", "Problem while trying to write text file ($txtfile)")
      if (! MMisc::writeTo($txtfile, "", 1, 0, $tbl));

  my $csvtxt = $sat->renderCSV();
  return("", "", "Generating CSV Report: ". $sat->get_errormsg())
      if (! defined($csvtxt));
  return("", "", "Problem while trying to write CSV file ($csvfile)")
      if (! MMisc::writeTo($csvfile, "", 1, 0, $csvtxt));
  
  return("Finalized");
}

##########

sub extract_combined_mota_value {
  my ($file) = @_;

  my $err = MMisc::check_file_r($file);
  return(undef, "file [$file] : $err")
    if (! MMisc::is_blank($err));

  open CMB, "<$file"
    or return(undef, "$file [$file] : $!");

  my $csvh = new CSVHelper();

  while (my $line = <CMB>) {
    my @array = $csvh->csvline2array($line);
    return(undef, "Problem extracting CSV content: " . $csvh->get_errormsg())
      if ($csvh->error());
    return($array[-1], "")
      if ($array[0] eq "Combined MOTA");
  }
  close CMB;

  return(undef);
}

##########

sub add_to_mota_sat {
  return("") if (! defined $mota_sat);

  my ($file, $site, $expid, $task, $ttid) = @_;

  my $err = MMisc::check_file_r($file);
  return("file [$file] : $err")
    if (! MMisc::is_blank($err));

  open CSV, "<$file"
    or return("$file [$file] : $!");

  my @nh = ("Cam ID", "CostMD", "SumMD", "CostFA", "SumFA", "CostIS",
            "SumIDSplit", "SumIDMerge", "NumberOfEvalGT");
  my $idbase = "$site | $expid | $task | $ttid";

  my $csvh = new CSVHelper();

  my $header = <CSV>;
  return("CSV file contains no data ?")
    if (! defined $header);
  my @headers = $csvh->csvline2array($header);
  return("Problem extracting csv line:" . $csvh->get_errormsg())
    if ($csvh->error());
  return("CSV file ($file) contains no usable data")
    if (scalar @headers < 2);

  my %pos = ();
  for (my $i = 0; $i < scalar @headers; $i++) {
    $pos{$headers[$i]} = $i;
  }

  $csvh->set_number_of_columns(scalar @headers);
  return("Problem setting the number of columns for the csv file:" . $csvh->get_errormsg())
    if ($csvh->error());

  my $cont = 1;
  while ($cont) {
    my $line = <CSV>;
    if (MMisc::is_blank($line)) {
      $cont = 0;
      next;
    }
    
    my @array = $csvh->csvline2array($line);
    return("Problem extracting CSV content: " . $csvh->get_errormsg())
      if ($csvh->error());
    if ($array[0] eq "Combined MOTA") {
      $added_mota_data++;
      return("");
    }

    my $id = "$idbase | CSVfile: $file | Line#: $cont";
    $mota_sat->addData($site, "SITE", $id);
    $mota_sat->addData($expid, "EXPID", $id);
    $mota_sat->addData($task, "TASK", $id);
    $mota_sat->addData($ttid, "TTID", $id);
    foreach my $col (@nh) {
      if (! exists $pos{$col}) {
        return("Could not find required value ($col)");
      } else {
        $mota_sat->addData($array[$pos{$col}], $col, $id);
      }
      return($mota_sat->get_errormsg()) if ($mota_sat->error());
    }

    $cont++;
  }
  close CSV;

  return("Could not find expected last CSV line");
}

####################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

############################################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] --scoring_dir dir --Site site --expid expid --task task --metric metric [--metric metric [...]] [--outdir dir ] tiid [ttid [...]]

Will generate the finalized Metric(s) CSV and TXT files for given EXPID's TTID(s)

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --scoring_dir   The base scoring directory (under which should be "site/expid"
  --Site          The submission directory (ex: NIST_1)
  --expid         The experiment ID
  --task          One of the recognized task (ex: MCSPT)
  --metric        One of the CLEAR metric (ex: MOTA)
  --outdir        Specify the output directory (base of the scoring directory otherwise)
EOF
;
  
  return $tmp;
}
