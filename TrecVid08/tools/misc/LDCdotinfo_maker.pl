#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 -- for LDC: .info maker
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 -- for LDC: .info maker" is an experimental system.
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

my $versionid = "TrecVid08 -- for LDC: .info maker Version: $version";

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

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                                  h    m     s  v     #

my $jpeg_path = "";
my $split_v = 7750;
my $margin_v = 125;

my $path_add = "data/";
my $frame_pre = "frm_";

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'split_every=i'  => \$split_v,
   'margin_value=i' => \$margin_v,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);
MMisc::error_quit("Need at least 4 file arguments to work\n$usage\n") 
  if (scalar @ARGV < 4);

MMisc::error_quit("split_value < 1")
  if ($split_v < 1);
MMisc::error_quit("margin_value < 0")
  if ($margin_v < 0);
MMisc::error_quit("split_value <= margin_value")
  if ($split_v <= $margin_v);

my ($infofile, $file_name, $sf, $ef, $jpeg_path) 
  = MMisc::iuav(\@ARGV, "", "", -1, -1, "");

MMisc::error_quit("End Frame < Beg Frame")
  if ($ef < $sf);
MMisc::error_quit("Beginning frame must be at least 1")
  if ($sf < 1);

if (! MMisc::is_blank($jpeg_path)) {
  $jpeg_path =~ s%\/$%%;
  $jpeg_path .= "/";
}

my @ranges = &die_ranges_generator($ef, $split_v, $margin_v);

my $otxt = "";
$otxt .= "#VIPER_VERSION_3.0\n1\n";
for (my $f = $sf; $f < $ef; $f++) {
  $otxt .= &die_get_file_loc($f, $jpeg_path, $file_name, @ranges) . "\n";
}
MMisc::error_quit("Problem while trying to write")
  if (! MMisc::writeTo($infofile, "", 1, 0, $otxt, "", "** Info file:\n"));

MMisc::ok_quit("Done\n");

########## END

sub die_ranges_generator {
  my ($ef, $split_v, $margin_v) = @_;

  my ($bv, $ev) = (0, $split_v);
  my @pair = ($bv, $ev);
  my @list = ();
  push @list, \@pair;

  while ($ev < $ef) {
    $bv = $ev - $margin_v;
    $ev = $bv + $split_v;

    my @pair = ($bv, $ev);
    push @list, \@pair;
  }

  return(reverse(@list));
}

##########

sub get_range {
  my ($f, @list) = @_;

  my ($bv, $ev) = (0, 0);
  foreach my $ra (@list) {
    ($bv, $ev) = @{$ra};
    return ($bv, $ev) 
      if (($f >= $bv) && ($f <= $ev)); # exaclty from bv to ev
  }

  return(-1,-1);
}

#####

sub die_get_file_loc {
  my ($f, $jpeg_path, $file_name, @list) = @_;

  $f--; # Remove 1 from the frame value

  my ($bv, $ev) = &get_range($f, @list);
  MMisc::error_quit("Could not find proper range for requested frame ($f)")
    if ($bv == $ev);

  my $txt = "";

  $txt .= (MMisc::is_blank($jpeg_path)) ? "." : $jpeg_path;
  $txt =~ s%\/$%%;
  $txt .= "/$path_add$file_name/";
  $txt .= sprintf("%06d", $bv) . "_" . sprintf("%06d", $ev);
  $txt .= "/$frame_pre" . sprintf("%06d", $f) . ".jpg";

  return($txt);
}

##########

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--split_every value] [--margin_value value] outfile.info file_name start_frame end_frame [jpeg_path]

Will generate 

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --split_every   For LDC sub jpeg directories, number of jpegs in one directory
  --margin_value  Amount to remove from last end frame to compute new beginning frame for LDC sub jpeg directories
EOF
;
  
  return $tmp;
}
