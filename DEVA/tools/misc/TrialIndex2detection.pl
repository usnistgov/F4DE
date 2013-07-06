#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid Multimedia Event Detection TrialIndex to detection
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid Event Detection TrialIndex to detection" is an experimental system.
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
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid Event Detection TrialIndex to detection Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
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

my $usage = &set_usage();
MMisc::error_quit("Usage:\n$usage\n") if (scalar @ARGV == 0);

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                   ST V           h    m   q s uvw    #

my $seed = undef;

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No arguments left on command line\n\n$usage\n")
  if (scalar @ARGV == 0);
MMisc::error_quit("Wrong argument count\n\n$usage\n")
  if (scalar @ARGV != 2);

my $tid = 'TrialID';

my ($if, $of) = @ARGV;

##
my $randi = 0; # default random array increment
my $rands = 0;
my @randa = ();
srand($seed);
set_randa(10000);

##
my $icsvh = new CSVHelper();
MMisc::error_quit("Problem with input CSV: " . $icsvh->get_errormsg()) if ($icsvh->error());

my %tids = $icsvh->loadCSV_tohash($if, $tid);
MMisc::error_quit("Problem with input CSV: " . $icsvh->get_errormsg()) if ($icsvh->error());

##
my $ocsvh = new CSVHelper();
MMisc::error_quit("Problem with output CSV: " . $ocsvh->get_errormsg()) if ($ocsvh->error());

my @ocsv = ($tid, 'Score');
$ocsvh->set_number_of_columns(scalar @ocsv);
MMisc::error_quit("Problem with output CSV: " . $ocsvh->get_errormsg()) if ($ocsvh->error());

my $otxt = "";
$otxt .= $ocsvh->array2csvline(@ocsv) . "\n";
MMisc::error_quit("Problem with output CSV: " . $ocsvh->get_errormsg()) if ($ocsvh->error());

foreach my $tid (sort keys %tids) {
  @ocsv = ($tid, sprintf("%.03f", &get_rand()));
  $otxt .= $ocsvh->array2csvline(@ocsv) . "\n";
  MMisc::error_quit("Problem with output CSV: " . $ocsvh->get_errormsg()) if ($ocsvh->error());
}

MMisc::error_quit("Problem writing file ($of)")
  if (! MMisc::writeTo($of, "", 1, 0, $otxt));

MMisc::ok_quit();

########## END

sub set_randa {
  for (my $i = 0; $i < $_[0]; $i++) {
    push @randa, rand();
  }
  $rands = scalar @randa;
}

#####

sub get_rand {
  MMisc::error_quit("Can not get pre computed rand() value from array (no content)")
    if ($rands == 0);
  my $mul = (defined $_[0]) ? $_[0] : 1;
  my $rs = (defined $_[1]) ? $_[1] : \$randi;
  my $v = $mul * $randa[$$rs];
  $$rs++;
  $$rs = 0 if ($$rs >= $rands);
  return($v);
}

#####

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] TrialIndex.csv detection.csv


EOF
    ;

    return $tmp;
}

