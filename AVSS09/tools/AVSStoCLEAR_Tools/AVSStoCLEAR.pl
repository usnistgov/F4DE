#!/usr/bin/env perl

# AVSS ViPER File to CLEAR ViPER File converter
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

my $versionid = "AVSS ViPER File to CLEAR ViPER File converter: $version";

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
foreach my $pn ("MMisc", "AVSStoCLEAR") {
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

my $usage = &set_usage();

my $dosys = 0;
my $doStarterSys = 0;
my $doEmptySys = 0;
my $ifgap = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:     E   I         S              h          s         #

my %opt;
GetOptions
  (
   \%opt,
   'help',
   'sys'          => \$dosys,
   'StarterSys'   => \$doStarterSys,
   'EmptySys'     => \$doEmptySys,
   'IFramesGap=i' => \$ifgap,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("Not enough arguments\n$usage\n") if (scalar @ARGV != 2);

MMisc::error_quit("\'sys\', \'StarterSys\' or \'EmptySys\' can not be used at the same time\n$usage")
  if ($dosys + $doStarterSys + $doEmptySys > 1);

MMisc::error_quit("Invalid \'IFramesGap\' value [$ifgap], must be positive and not equal to zero\n$usage")
  if ($ifgap < 1);

my $avcl = new AVSStoCLEAR();

my ($in, $out) = @ARGV;
MMisc::error_quit("No output_file provided.\n $usage")
  if (MMisc::is_blank($out));
open OUT, ">$out"
  or MMisc::error_quit("Could not create output_file ($out) : $!\n");

my ($ok, $res) = $avcl->load_ViPER_AVSS($in, $ifgap);
MMisc::error_quit("ERROR: " . $avcl->get_errormsg())
  if ($avcl->error());
MMisc::error_quit("ERROR: \'load_ViPER_AVSS\' did not complete succesfully")
  if (! $ok);
print $res;

my $xmlc = "";
my $tag = "";
if ($dosys) {
  $xmlc = $avcl->create_CLEAR_SYS_ViPER($in);
  $tag = "SYS";
} elsif ($doStarterSys) {
  $xmlc = $avcl->create_CLEAR_StarterSYS_ViPER($in);
  $tag = "StarterSYS";
} elsif ($doEmptySys) {
  $xmlc = $avcl->create_CLEAR_EmptySYS_ViPER($in);
  $tag = "EmptySYS";
} else {
  $xmlc = $avcl->create_CLEAR_ViPER($in);
  $tag = "GTF";
}
MMisc::error_quit("ERROR: " . $avcl->get_errormsg())
  if ($avcl->error());
MMisc::error_quit("ERROR: \'create_CLEAR_ViPER\' did not create any XML")
  if (MMisc::is_blank($xmlc));
print OUT $xmlc;
close OUT;

print "\n==> Wrote [$tag] : $out\n";

MMisc::ok_quit("\nDone\n");

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

########################################

sub set_usage {
  my $tmp=<<EOF

$versionid

$0 [--help] --IFramesGap gap [--sys | --StarterSys | --EmptySys] input_file output_file

Convert one AVSS ViPER file to one CLEAR ViPER file (by default, a Ground Truth File)

Where:
  --help          Print this usage information and exit
  --IFramesGap    Specify the gap between I-Frames and Annotated frames
  --sys           Generate a CLEAR ViPER system file
  --StarterSys    Generate a CLEAR ViPER Starter sys file (only contains the first five non occluded bounding boxes)
  --EmptySys      Generate a CLEAR ViPER system file with no person defintion

EOF
;

  return($tmp);
}
