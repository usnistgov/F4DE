#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
    if 0;

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# TrecVid08 -- for LDC: .info copier
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 -- for LDC: .info copier" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
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
foreach my $pn ("MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "TrecVid08 LDC .info copier ($versionkey)";

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

my $fbase = "";
my $suffix = "";
my $odir = "";
my $infile = "";
my $cfn = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                                  hi            v     #


my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'input_file=s' => \$infile,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);
MMisc::error_quit("Need at least 4 file arguments to work\n$usage\n") 
  if (scalar @ARGV < 4);

my ($outfile, $linfile, $sf, $ef) 
  = MMisc::iuav(\@ARGV, "", "", -1, -1, "");

MMisc::error_quit("End Frame < Beg Frame")
  if ($ef < $sf);
MMisc::error_quit("Beginning frame must be at least 1")
  if ($sf < 1);

$infile = (MMisc::is_blank($infile)) ? $linfile : $infile;

open INFILE, "<$infile"
  or MMisc::error_quit("Problem opening input file ($infile) : $!");
my @infilec = <INFILE>;
close INFILE;

MMisc::error_quit("Not enough lines in input file [", scalar @infilec - 2, "to get requested number [$ef]")
  if (scalar @infilec - 2 < $ef);

open OUTFILE, ">$outfile"
  or MMisc::error_quit("Problem creating output file ($outfile): $!");
# Copy the header
print OUTFILE shift @infilec;
print OUTFILE shift @infilec;

for (my $i = $sf - 1; $i < $ef; $i++) {
  print OUTFILE $infilec[$i];
}

close OUTFILE;

MMisc::ok_quit("Done\n");

########## END

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] outfile.info infile.info start_frame end_frame

Will generate 

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --input_file    Specify the info file to load data from
EOF
;
  
  return $tmp;
}
