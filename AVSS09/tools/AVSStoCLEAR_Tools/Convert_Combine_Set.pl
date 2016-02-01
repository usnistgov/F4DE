#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#
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

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../CLEAR07/lib", "$f4d/../../../common/lib");
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
foreach my $pn ("MMisc", "AVSStoCLEAR") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "AVSS09 ViPER Files to multiple camera view CLEAR ViPER File converter ($versionkey)";

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

########################################

my $usage = "$0 input_dir output_file\n\nConvert all the files within the input_dir directory from AVSS to one multiple camera views CLEAR ViPER file\nRequires a \'Set\' to work: needs 5 camera views that will be placed on 2 lines with cameras 1,2 and 3 on the first line, and camera 4 and 5 on the second.\nNote: video size will be halved during this operation.\n";

my ($in, $out) = @ARGV;

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
  if (scalar @fl == 0);

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

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}
