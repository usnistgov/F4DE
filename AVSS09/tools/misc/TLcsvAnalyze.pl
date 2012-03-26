#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# Tracking Log CSV Analyzer
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TLcsvAnalyze" is an experimental system.
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

my $versionid = "Tracking Log CSV Analyze Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "CSVHelper", "ViperFramespan") {
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
MMisc::error_quit("$usage") if (scalar @ARGV == 0);

my $outfile = "";
my $dostdout = 0;
my $stdoutheaders = 0;
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'outfile=s'     => \$outfile,
   'stdout'        => \$dostdout,
   'HeadersOnly'   => \$stdoutheaders,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("\'headersOnly\' requested but \'stdout\' not requested\n$usage")
  if (($stdoutheaders) && (! $dostdout));

if (($stdoutheaders) && ($dostdout)) {
  &prep_file_header();
  MMisc::ok_quit("");
}

MMisc::error_quit("$usage") if (scalar @ARGV < 1);

if ($dostdout) {
  MMisc::error_quit("When using \'stdout\' mode only one file is authorized")
    if (scalar @ARGV > 1);
} else {
  MMisc::error_quit("\'outfile\' not set")
    if (MMisc::is_blank($outfile));

  open OFILE, ">$outfile"
    or MMisc::error_quit("Problem with \'outfile\' ($outfile) : $!");
}
my %all = ();
foreach my $if (@ARGV) {
  &process_file($if);
}

my $csvh = &prep_file_header();
foreach my $if (@ARGV) {
  &write_file_details($csvh, $if);
}
if (! $dostdout) {
  close OFILE;
  print "[*****] Wrote \'$outfile\'\n";
}

MMisc::ok_quit($dostdout ? "" : "Done");

##########

sub vprint {
  return if ($dostdout);

  print @_;
}

#####

sub csverr {
  MMisc::error_quit("No CSV handler ?") if (! defined $_[0]);
  MMisc::error_quit("CSV handler problem: " . $_[0]->get_errormsg())
      if ($_[0]->error());
}

#####

sub check_fs {
  my ($fs) = @_;
  MMisc::error_quit("Undefined ViperFramespan")
    if (! defined $fs);
  MMisc::error_quit("ViperFramespan error: " . $fs->get_errormsg())
    if ($fs->error());
}

##

sub add2fs {
  my ($fs, $beg, $end) = @_;

  return(0) if (($beg == 0) || ($end == 0));

  &check_fs($fs);
  my $c = $fs->is_value_set($fs);
  &check_fs($fs);

  if ($c) {
    $fs->add_fs_to_value("$beg:$end");
  } else {
    $fs->set_value_beg_end($beg, $end);
  }
  &check_fs($fs);

  return(1);
}

##

sub get_fs_value {
  my ($fs) = @_;

  &check_fs($fs);
  my $c = $fs->is_value_set($fs);
  &check_fs($fs);

  if ($c) {
    my $v = $fs->get_value();
    &check_fs($fs);
    return($v);
  }

  return("");
}

##

sub get_fs_duration {
  my ($fs) = @_;

  &check_fs($fs);
  my $c = $fs->is_value_set($fs);
  &check_fs($fs);

  if ($c) {
    my $v = $fs->duration();
    &check_fs($fs);
    return($v);
  }

  return(0);
}


#####

sub process_file {
  my ($file) = @_;

  &vprint("[*] Loading \'$file\'\n");
  
  open FILE, "<$file"
    or MMisc::error_quit("Problem opening file ($file) : $!");
  
  my $csvh = new CSVHelper(); &csverr($csvh);
  my $line = <FILE>; chomp $line;
  my @header = $csvh->csvline2array($line); &csverr($csvh);

  my ($beg, $end) = (0, 0);
  my $pfr = 0;
  my $length_frc = 0;
  my $mp_frc = 0;
  my $md_frc = 0;
  my $fa_frc = 0;
  my $dco_frc = 0;
  my $fs_length = new ViperFramespan(); &check_fs($fs_length);
  my $fs_mp = new ViperFramespan(); &check_fs($fs_mp);
  my $fs_md = new ViperFramespan(); &check_fs($fs_md);
  my $fs_fa = new ViperFramespan(); &check_fs($fs_fa);
  my $fs_dco = new ViperFramespan(); &check_fs($fs_dco);
  while ($line = <FILE>) {
    chomp $line;
    my ($fr, $mp, $md, $fa, $dco) = $csvh->csvline2array($line);
    &csverr($csvh);

    $pfr = $fr if ($pfr == 0);

    $beg = $fr if ($beg == 0);
    $end = $fr;

    if (! MMisc::is_blank($mp)) {
      &add2fs($fs_mp, $pfr, $fr);
      $mp_frc++;
    }
    if (! MMisc::is_blank($md)) {
      &add2fs($fs_md, $pfr, $fr);
      $md_frc++;
    }
    if (! MMisc::is_blank($fa)) {
      &add2fs($fs_fa, $pfr, $fr);
      $fa_frc++;
    }
    if (! MMisc::is_blank($dco)) {
      &add2fs($fs_dco, $pfr, $fr);
      $dco_frc++;
    }
    $length_frc++;

    $pfr = $fr;
  }
  close FILE;
  
 MMisc::error_quit("Could not set main length, this is bad")
   if (! &add2fs($fs_length, $beg, $end));

  $all{$file} = [
    $length_frc, &get_fs_value($fs_length), &get_fs_duration($fs_length),
    $mp_frc, &get_fs_value($fs_mp), &get_fs_duration($fs_mp),
    $md_frc, &get_fs_value($fs_md), &get_fs_duration($fs_md),
    $fa_frc, &get_fs_value($fs_fa), &get_fs_duration($fs_fa),
    $dco_frc, &get_fs_value($fs_dco), &get_fs_duration($fs_dco)
    ];
}

##########

sub prep_file_header {
  my $csvh = new CSVHelper(); &csverr($csvh);
  return($csvh) if (($dostdout) && (! $stdoutheaders));

  my @h = ();
  push (@h, "FileName") if (! $stdoutheaders);
  push @h, (
    "FileFrameCount", "FileFramespan", "FileDuration",
    "MappedFrameCount", "MappedFramespan", "MappedDuration",
    "MDFrameCount", "MDFramespan", "MDDuration",
    "FAFrameCount", "FAFramespan", "FADuration",
    "DCOFrameCount", "DCOFramespan", "DCODuration"
  );
  $csvh->set_number_of_columns(scalar @h); &csverr($csvh);
  my $txt = $csvh->array2csvline(@h);
  if ($stdoutheaders) {
    print "$txt\n";
  } else {
    print OFILE "$txt\n"; &csverr($csvh);
  }
  return($csvh);
}

#####

sub write_file_details {
  my ($csvh, $file) = @_;

  my @tmp = @{$all{$file}};

  my @a = ();
  push(@a, $file) if (! $dostdout);
  push @a, @tmp;
  
  my $str = $csvh->array2csvline(@a); &csverr($csvh);
  if ($dostdout) {
    print "$str\n";
  } else {
    print OFILE  "$str\n"; 
  }
}

####################

sub set_usage {
  my $tmp=<<EOF
$versionid

$0 [--help] [--outfile file | --stdout [--HeadersOnly]] trackinglogfile [trackinglogfile [...]]

Will generate a Framespan Details CSV from a Tracking Log CSV.

Where:
  --help     This help message
  --outfile  Specify the output file
  --stdout   Print the CSV line to stdout. In this mode, only one trackinglogfile can be specified, and the line will not contain the FileName field (1st field in the normal CSV file)
  --HeadersOnly  Print the CSV headers only to stdout (does not need a trackinglogfile)

Information made available in the CSV file are:
  FileName       The filename as given on the command line (omitted when using --stdout)
  FileFrameCount  The number of evaluated frames seen in the File
  FileFramespan  The Framespan of the frames seen in the File
  FileDuration   The duration (in frames) of the frames seen in the File
  MappedFrameCount  The Mapped evaluated frames count 
  MappedFramespan  The Mapped frames 
  MappedDuration   The Mapped frames duration
  MDFrameCount    The Missed Detect evaluated frames count
  MDFramespan     The Missed Detect frames
  MDDuration      The Missed Detect frames duration
  FAFrameCount    The False Alarm evaluated frames count
  FAFramespan     The False Alarm frames
  FADuration      The False Alarm frames duration
  DCOFrameCount   The Do Not Care evaluated frames count
  DCOFramespan    The Do Not Care frames
  DCODuration     The Do Not Care frames duration

EOF
;

  return($tmp);
}
