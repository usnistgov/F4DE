#!/usr/bin/env perl

# AVSS ViPER Files to multiple camera view CLEAR ViPER File converter
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAR Detection and Tracking Viper XML Validator" is an experimental system.
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

my $versionid = "AVSS ViPER Files to multiple camera view CLEAR ViPER File converter: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $avpl, $avplv, $clearpl, $clearplv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = (defined $ENV{$f4b}) ? $ENV{$f4b} . "/lib": "/lib";
  $avpl = "AVSS09_PERL_LIB";
  $avplv = $ENV{$avpl} || "../../lib";
  $clearpl = "CLEAR_PERL_LIB";
  $clearplv = $ENV{$clearpl} || "../../../CLEAR07/lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($avplv, $clearplv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $avpl, $clearpl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# AVSStoCLEAR (part of this tool)
unless (eval "use AVSStoCLEAR; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"AVSStoCLEAR\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

use strict;

########################################

my $usage = "$0 input_dir output_file\n\nConvert all the files within the input_dir directory from AVSS to one multiple camera views CLEAR ViPER file\nRequires a \'Set\' to work: needs 5 camera views that will be placed on 2 lines with cameras 1,2 and 3 on the first line, and camera 4 and 5 on the second.\nNote: video size will be halved during this operation.\n";

my $in = shift @ARGV;
my $out = shift @ARGV;

MMisc::error_quit("No input_dir provided.\n $usage")
  if (MMisc::is_blank($out));
MMisc::error_quit("No output_file provided.\n $usage")
  if (MMisc::is_blank($out));

my $err = MMisc::check_dir_r($in);
MMisc::error_quit("input_dir problem: $err")
  if (! MMisc::is_blank($err));

open OUT, ">$out"
  or MMisc::error_quit("Problem creating output_file: $!");

my @fl = MMisc::get_files_list($in);
MMisc::error_quit("No files in input_dir\n")
  if (! defined @fl);

my %order = 
  (
   # ID => (ID add, X add, Y add, XYdiv)

# Full resolution
#  '1' => [1000, 0, 0, 1],
#  '2' => [2000, 723, 0, 1],
#  '3' => [3000, 1446, 0, 1],
#  '4' => [4000, 0, 580, 1],
#  '5' => [5000, 723, 580, 1],

# Half resolution
  '1' => [1000, 0, 0, 2],
  '2' => [2000, 362, 0, 2],
  '3' => [3000, 723, 0, 2],
  '4' => [4000, 0, 290, 2],
  '5' => [5000, 362, 290, 2],
  );

my $avcl = new AVVStoCLEAR();
my @keys = ();

foreach my $file (sort @fl) {
  my $ff = "$in/$file";
  print "\n--------------------\n### FILE: $ff\n";

  my ($ok, $res) = $avcl->load_ViPER_AVSS($ff);
  MMisc::error_quit($avcl->get_errormsg())
      if ($avcl->error());
  MMisc::error_quit("\'load_ViPER_AVSS\' did not complete succesfully")
      if (! $ok);
  print $res;

  my $cid = $avcl->get_cam_id($ff);
  MMisc::error_quit($avcl->get_errormsg())
      if ($avcl->error());

  push @keys, $ff;
}

my $xmlc = $avcl->create_composite_CLEAR_ViPER("composite.mov", \@keys, \%order);
MMisc::error_quit($avcl->get_errormsg())
  if ($avcl->error());
MMisc::error_quit("\'create_composite_CLEAR_ViPER\' did not create any XML")
  if (MMisc::is_blank($xmlc));
print OUT $xmlc;

close OUT;
print "\n==> Wrote: $out\n";

MMisc::ok_quit("\nDone\n");

############################################################



