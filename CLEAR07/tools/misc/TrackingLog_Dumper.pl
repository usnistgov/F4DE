#!/usr/bin/env perl

# Tracking Log MOTA CSV Dumper
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Tracking Log MOTA CSV Dumper" is an experimental system.
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

my $versionid = "Tracking Log MOTA CSV Dumper Version: $version";

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
foreach my $pn ("MMisc", "SimpleAutoTable") {
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


##########

my $ifile = shift @ARGV;
my $err = MMisc::check_file_r($ifile);
MMisc::error_quit("Problem with input file ($ifile): $err")
  if (! MMisc::is_blank($err));

my $ofile = shift @ARGV;
MMisc::error_quit("No output file provided, aborting")
  if (MMisc::is_blank($ofile));

open IFILE, "<$ifile"
  or MMisc::error_quit("Problem with input file ($ifile): $!");
my @content = <IFILE>;
close IFILE;
chomp @content;

open OFILE, ">$ofile"
  or MMisc::error_quit("Problem with output file ($ofile): $!");

my $csvh = new CSVHelper();

my @header = 
  (
   "Frame", 
   "frame NumberOfEvalGT", "frame MissedDetect", "frame FalseAlarm", "frame IDSplit", "frame IDMerge", 
   "global NumberOfEvalGT", "global MissedDetect", "global FalseAlarm", "global IDSplit", "global IDMerge",
   "global MOTA"
  );
$csvh->set_number_of_columns(scalar @header);
&write_csvline(@header);

my @linec = ();
foreach my $line (@content) {
  next if (! ((substr($line, 0, 2) eq "--") || (substr($line, 0, 5) eq "*****")));

    # "***** Evaluated Frame: 54"
    if ($line =~ m%^\*\*\*\*\* Evaluated\sFrame\:\s+(\d+)\s*$%) {
      my $fn = $1;
      if (scalar @linec > 0) {
        &write_csvline(@linec);
        @linec = ();
      }
      push @linec, $fn;

      next;
    }

  # "-- MOTA frame summary : [NumberOfEvalGT: 0] [MissedDetect: 0] [FalseAlarm: 0] [IDSplit: 0] [IDMerge: 0]"
  if ($line =~ m%^\-\-\sMOTA\sframe\ssummary\s*\:\s+\[NumberOfEvalGT\:\s*(\d+)\]\s+\[MissedDetect\:\s*(\d+)\]\s+\[FalseAlarm\:\s*(\d+)\]\s+\[IDSplit\:\s*(\d+)\]\s+\[IDMerge\:\s*(\d+)\]\s*$%) {
    push @linec, ($1, $2, $3, $4, $5);

    next;
  }

  # "-- MOTA global summary: [NumberOfEvalGT: 0] [MissedDetect: 0] [FalseAlarm: 0] [IDSplit: 0] [IDMerge: 0] => [MOTA = NaN]"
  if ($line =~ m%^\-\-\sMOTA\sglobal\ssummary\s*\:\s+\[NumberOfEvalGT\:\s*(\d+)\]\s+\[MissedDetect\:\s*(\d+)\]\s+\[FalseAlarm\:\s*(\d+)\]\s+\[IDSplit\:\s*(\d+)\]\s+\[IDMerge\:\s*(\d+)\]\s+\=\>\s+\[MOTA\s+\=\s+(\-?[\w\.]+)\]\s*$%) {
    push @linec, ($1, $2, $3, $4, $5, $6);

    next;
  }

  MMisc::error_quit("Unknow line [$line], aborting");
}
&write_csvline(@linec) if (scalar @linec > 0);

close OFILE;
MMisc::ok_quit("Done\n\n");

########################################

sub write_csvline {
  my @linec = @_;
  my $cl = $csvh->array2csvline(@linec);
  MMisc::error_quit("Problem with CSV line: " . $csvh->get_errormsg())
      if ($csvh->error());

  print OFILE "$cl\n";
}

sub set_usage {
  return("TBD");
}
