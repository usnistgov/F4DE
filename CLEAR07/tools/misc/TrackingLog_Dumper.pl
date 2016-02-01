#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#
# MOTA Tracking Log CSV Dumper
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "MOTA Tracking Log CSV Dumper" is an experimental system.
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

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
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
foreach my $pn ("MMisc", "SimpleAutoTable") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "MOTA Tracking Log CSV Dumper ($versionkey)";

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
# Used:                                  h      o      v     #

my $outdir = "";

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'outdir=s'      => \$outdir,
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

MMisc::ok_quit("Done\n\n");

########################################

sub doit {
  my ($ifile, $ob) = @_;

  my $err = MMisc::check_file_r($ifile);
  return("Problem with input file ($ifile): $err")
      if (! MMisc::is_blank($err));
  
  open IFILE, "<$ifile"
    or return("Problem with input file ($ifile): $!");
  my @content = <IFILE>;
  close IFILE;
  chomp @content;

  my $csvh = new CSVHelper();

  my @header = 
    (
     "Frame", 
     "frame NumberOfEvalGT", "frame MissedDetect", "frame FalseAlarm", "frame IDSplit", "frame IDMerge", 
     "global NumberOfEvalGT", "global MissedDetect", "global FalseAlarm", "global IDSplit", "global IDMerge",
     "global MOTA"
    );

  my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($ifile);
  return("Problem with filename ($ifile): $err")
    if (! MMisc::is_blank($err));
  
  $ob .= $f;
  $ob =~ s%\-$%%;

  my $of = "${ob}-TL.csv";
  my $otxt = "";

  $csvh->set_number_of_columns(scalar @header);
  my ($ok, $txt) = &generate_csvline($csvh, @header);
  return("Problem generating CSV line: $txt") if (! $ok);
  $otxt .= "$txt\n";

  my @linec = ();
  foreach my $line (@content) {
    next if (! ((substr($line, 0, 2) eq "--") || (substr($line, 0, 5) eq "*****")));

    # "***** Evaluated Frame: 54"
    if ($line =~ m%^\*\*\*\*\* Evaluated\sFrame\:\s+(\d+)\s*$%) {
      my $fn = $1;
      if (scalar @linec > 0) {
        my ($ok, $txt) = &generate_csvline($csvh, @linec);
        return("Problem generating CSV line: $txt") if (! $ok);
        $otxt .= "$txt\n";

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
    
    return("Unknow line [$line], aborting");
  }
  my ($ok, $txt) = &generate_csvline($csvh, @linec) if (scalar @linec > 0);
  return("Problem generating CSV line: $txt") if (! $ok);
  $otxt .= "$txt\n";
  
  return("Problem while trying to write CSV file ($of)")
    if (! MMisc::writeTo($of, "", 1, 0, $otxt));

  return("");
}

##########

sub generate_csvline {
  my ($csvh, @linec) = @_;

  my $cl = $csvh->array2csvline(@linec);
  return(0, "Problem with CSV line: " . $csvh->get_errormsg())
    if ($csvh->error());

  return(1, $cl);
}

########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--outdir dir] file.tracking_log

Will generate CSV files describing the scored frame per scored frame compoment of the MOTA using MOTA tracking logs

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --outdir        The output directory in which to generate the results (by default output in the current directory)
EOF
;
  
  return $tmp;
}
