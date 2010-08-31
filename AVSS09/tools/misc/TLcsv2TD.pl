#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# Tracking Log CSV to Tracking Details
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TLcsv2TD" is an experimental system.
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

my $versionid = "Tracking Log CSV to Tracking Details Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../../common/lib");
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
foreach my $pn ("MMisc", "CSVHelper") {
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

my $mddrop = 0;
my $outfile = "";
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'MDthreshold=i' => \$mddrop,
   'outfile=s'     => \$outfile
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("$usage") if (scalar @ARGV < 1);

MMisc::error_quit("Problem with \'mddrop\' must be at least 1")
  if ($mddrop <= 1);

MMisc::error_quit("\'outfile\' not set")
  if (MMisc::is_blank($outfile));

open OFILE, ">$outfile"
  or MMisc::error_quit("Problem with \'outfile\' ($outfile) : $!");

my %all = ();
foreach my $if (@ARGV) {
  &process_file($if);
}

my $csvh = &prep_file_header();
foreach my $if (@ARGV) {
  &write_file_details($csvh, $if);
}
close OFILE;
print "[*****] Wrote \'$outfile\'\n";

MMisc::ok_quit("Done");

##########

sub csverr {
  MMisc::error_quit("No CSV handler ?") if (! defined $_[0]);
  MMisc::error_quit("CSV handler problem: " . $_[0]->get_errormsg())
      if ($_[0]->error());
}

#####

sub process_file {
  my ($file) = @_;

  print "[*] Loading \'$file\'\n";
  
  open FILE, "<$file"
    or MMisc::error_quit("Problem opening file ($file) : $!");
  
  my $csvh = new CSVHelper(); &csverr($csvh);
  my $line = <FILE>; chomp $line;
  my @header = $csvh->csvline2array($line); &csverr($csvh);

  print "  ";

  my $c_mp = '@';
  my $c_md = '-';
  my $c_fa = '|';
  my $c_mdfa = '+';
  my $c_none = '.';
  my $c_dco = ':';


  my $frc = 0;
  my $mdc = 0;
  my $max = 0;
  my $fmx = 0;
  my $beg = 0;
  my $kbeg = 0;
  my $fbeg = 0;
  my $end = 0;
  my $kend = 0;
  my $fend = 0;
  my $ftbeg = 0;
  my $ftend = 0;
  my $ftl = 0;
  my $ftt = -1;
  my $track = "";
  my $str = 0;
  my $cont = 1;
  my $frd = 0;
  my $pfr = 0;
  while (($cont) && ($line = <FILE>)) {
    chomp $line;
    my ($fr, $mp, $md, $fa, $dco) = $csvh->csvline2array($line);
    &csverr($csvh);

    $frd = $fr - $pfr;
    $pfr = $fr;

    if ( (MMisc::is_blank($fa))
        && (MMisc::is_blank($md)) 
        && (MMisc::is_blank($mp))
         && (MMisc::is_blank($dco)) ) {
      $track .= ($str) ? $c_none : "";
      print $c_none;
      next;
    }

    if (! MMisc::is_blank($mp)) {
      print $c_mp;
      $track .= $c_mp;
      $str++;
      $beg = ($beg == 0) ? $fr : $beg;
      $end = $fr;
      $ftbeg = ($ftbeg == 0) ? $fr : $ftbeg;
      $ftend = $fr;
      $mdc = 0;
      $ftt = ($ftt == -1) ? 1 : $ftt;
      next; 
    }

    if (! MMisc::is_blank($md)) {
      $ftbeg = ($ftbeg == 0) ? $fr : $ftbeg;
      $ftend = $fr;
#      $ftt = ($ftt == -1) ? 1 : $ftt;

      if (MMisc::is_blank($fa)) {
        print $c_md;
        $track .= $c_md;
      } else {
        print $c_mdfa;
        $track .= $c_mdfa;
        $str++;
      }
      $str++;
      $mdc++;
      if ($mdc >= $mddrop) {
        $frc = $end - $beg;
        $frc = ($frc == 0) ? (($beg == 0) ? 0 : 1) : 1 + $frc;
        if ($frc > $max) {
          $max = $frc;
          $kbeg = $beg;
          $kend = $end;
          if ($fmx == 0) {
            $fmx = $frc;
            $fbeg = $beg;
            $fend = $end;
          }
        }
        if ($beg != 0) {
#          $cont = 0;
          $track .= "![$frc/$max]";
          $ftt = 0;
        }
        $frc = 0;
        $mdc = 0;
        if ($cont) {
          $beg = 0;
          $end = 0;
        }
      }
      next;
    }

    if (! MMisc::is_blank($fa)) {
      print $c_fa;
      $track .= $c_fa;
      $str++;
      next;
    }

    if (! MMisc::is_blank($dco)) {
      $track .= ($str) ? $c_dco : "";
      print $c_dco;
      next;
    }

    MMisc::error_quit("We should not be here");
  }
  close FILE;
  $frc = $end - $beg;
  $frc = ($frc == 0) ? (($beg == 0) ? 0 : 1) : 1 + $frc;
  if ($frc > $max) {
    $max = $frc;
    $kbeg = $beg;
    $kend = $end;
    if ($fmx == 0) {
      $fmx = $frc;
      $fbeg = $beg;
      $fend = $end;
    }
  }
  $track .= "\$[$frc/$max]";

  $ftt = ($ftt == -1) ? 0: $ftt;
  $ftl = $ftend - $ftbeg;
  $ftl = ($ftl == 0) ? (($ftbeg == 0) ? 0 : 1) : 1 + $ftl;


  $all{$file} = [$max, $track, $kbeg, $kend, $mddrop,
                 $fmx, $fbeg, $fend, 
                 $ftt, $ftl, $ftbeg, $ftend];

  print "\n   (max: $max)\n";
}

##########

sub prep_file_header {
  my $csvh = new CSVHelper(); &csverr($csvh);
  my @h = ("FileName", 
           "FirstTrackedLife", "FirstBegFr", "FirstEndFr",
           "MaxTrackedLife", "MaxBegFr", "MaxEndFr",
           "CompleteTrackBool", "CompeteTrackLife", 
           "CompleteBegFr", "CompleteEndFr",
           "MDThresold", "TrackDetail");
  $csvh->set_number_of_columns(scalar @h); &csverr($csvh);
  print OFILE $csvh->array2csvline(@h) . "\n"; &csverr($csvh);
  
  return($csvh);
}

#####

sub write_file_details {
  my ($csvh, $file) = @_;

  my ($max, $track, $beg, $end, $mt, $fmx, $fbeg, $fend, $ctt, $ctl, $ctbeg, $ctend) 
    = @{$all{$file}};

  my @a = ($file, $fmx, $fbeg, $fend, $max, $beg, $end, $ctt, $ctl, $ctbeg, $ctend, $mt, $track);
  print OFILE $csvh->array2csvline(@a) . "\n"; &csverr($csvh);
}

####################

sub set_usage {
  my $tmp=<<EOF
$versionid

$0 [--help] --outfile file trackinglogfile [trackinglogfile [...]]

Will generate a Tracking Details CSV from a Tracking Log CSV.

Where:
  --help     This help message
  --outfile  Specify the output file


TrackingDetails code are:
  .    No Objects
  :    Don't Care REF
  -    Missed Detect
  |    False Alarm
  +    Missed Detect and False Alarm
  @    Mapped REF to SYS
  !    Max Miss Detect rule was triggered

EOF
;

  return($tmp);
}
