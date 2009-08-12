#!/usr/bin/env perl

# Fix Negative X, Y, Width and Height
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Fix Negative X, Y, Width and Height" is an experimental system.
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

my $versionid = "Fix Negative X, Y, Width and Height Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../../common/lib");
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
foreach my $pn ("MMisc") {
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
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

my $doit = 0;
my @fl = ();
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'doit' => \$doit,
   '<>' => sub { my ($f) = @_; my $err = MMisc::check_file_w($f); MMisc::error_quit("Problem with input file ($f): $err") if (! MMisc::is_blank($err)); push @fl, $f; },
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

if ($doit) {
  print "!!!!! REAL run mode !!!!!\n";
  print " Waiting 5 seconds (Ctrl+C to cancel)\n";
  sleep(5);
} else {
  print "********** DRYRUN mode **********\n";
}

foreach my $fn (@fl) {
  my $f = MMisc::slurp_file($fn);
  MMisc::error_quit("Problem slurping file [$fn]") if (! defined $f);

  my $g = $f;

  my $x = 0; while ($g =~ s%(\sx\s*\=\s*\")\-\d+(\")%${1}0${2}%s) { $x++; }
  my $y = 0; while ($g =~ s%(\sy\s*\=\s*\")\-\d+(\")%${1}0${2}%s) { $y++; }
 
  my $nw = 0; while ($g =~ s%(\swidth\s*\=\s*\")\-\d+(\")%${1}1${2}%s) { $nw++; }
  my $nh = 0; while ($g =~ s%(\sheight\s*\=\s*\")\-\d+(\")%${1}1${2}%s) { $nh++; }
 
  my $w = 0; while ($g =~ s%(\swidth\s*\=\s*\")0(\")%${1}1${2}%s) { $w++; }
  my $h = 0; while ($g =~ s%(\sheight\s*\=\s*\")0(\")%${1}1${2}%s) { $h++; }

  if ($g ne $f) {
    print "\n** $fn differs: [$x neg X] [$y neg Y] [$nw neg W / $w 0 W] [$nh neg H / $h 0 H]\n";
    if ($doit) {
      MMisc::error_quit("Problem writing output file [$fn]")
          if (! MMisc::writeTo($fn, "", 1, 0, $g));
    }
  }

}

MMisc::ok_quit("Done\n");

########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--doit] xmlfiles

Try to fix known bad file content:
 if (x < 0) or (y < 0) then replace by 0
 if (height < 1) or (width < 1) then replace by 1

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --doit          Perform modification (safer to do one pass without this option and rerun it with it once it exits wihtout error)

IMPORTANT NOTE: Modify files specified on the command line
EOF
;
  
  return($tmp);
}
