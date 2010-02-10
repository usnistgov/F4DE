#!/usr/bin/env perl

# CSV files concatenator
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CSV files concatenator" is an experimental system.
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

my $versionid = "CSV files concatenator Version: $version";

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

my $usage = "$0 outfile.csv [inputfile.csv [inputfile.csv [...]]]\n\nProgram will copy content from multiple CSV files to one output CSV file (it will copy the CSV header of the first file only)\n";

MMisc::error_quit($usage) 
  if (scalar @ARGV < 2);

my $dir = shift @ARGV;
die("[$dir] is not a directory ?")
  if (! -d $dir);
my $out = shift @ARGV;

my @list = `find $dir -name "*.csv"`;
chomp @list;

my $first = 0;
my $lc = 0;
my $inc = 0;
foreach my $file (@list) {
    print "[$file]\n";

    # Copy header
    if (! $first) {
      `head -n 1 $file > $out`;
      $first = 1;
      my $nlc = &get_lc($out);
      my $a = $nlc - $lc;
      die("Header: Diff than one line added ($a)\n")
        if ($a != 1);
      $lc = $nlc;
    }

    `tail -n +2 $file >> $out`;
    my $elc = &get_lc($file) - 1;
    my $nlc = &get_lc($out);
    my $a = $nlc - $lc;
    die("Diff amount of line added ? expected : $elc / seen : $a\n")
      if ($a != $elc);
    print "   -> added $a lines\n";
    $lc = $nlc;
    $inc++;
}

print "Done ($inc files / $lc lines)\n";
exit(0);

#####

sub get_lc {
  my $file = shift @_;

  my $alc = `wc $file`;
  my $lc = 0;

  $lc = $1
    if ($alc =~ m%^\s*(\d+)\s+%);
  
  return ($lc);
}
  
