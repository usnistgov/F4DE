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

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add("\"Getopt::Long\" is not available on your Perl installation. ",
             "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n");
  $have_everything = 0;
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

use strict;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################

my $usage = "$0 [--help] --IFramesGap gap [--sys | --StarterSys] input_file output_file\n\nConvert one AVSS ViPER file to one CLEAR ViPER file\n";

my $dosys = 0;
my $doStarterSys = 0;
my $ifgap = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:         I         S              h          s         #

my %opt;
GetOptions
  (
   \%opt,
   'help',
   'sys'          => \$dosys,
   'StarterSys'   => \$doStarterSys,
   'IFramesGap=i' => \$ifgap,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});

MMisc::ok_quit("\nNot enough arguments\n$usage\n") if (scalar @ARGV != 2);

MMisc::error_quit("\'sys\' and \'StarterSys\' can not be used at the same time\n$usage")
  if (($opt{'sys'}) && ($opt{'StarterSys'}));
MMisc::error_quit("Invalid \'IFramesGap\' value [$ifgap], must be positive and not equal to zero\n$usage")
  if ($ifgap < 1);

my $avcl = new AVSStoCLEAR();

my $in = shift @ARGV;
my $out = shift @ARGV;
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
if ($dosys) {
  $xmlc = $avcl->create_CLEAR_SYS_ViPER($in);
} elsif ($doStarterSys) {
  $xmlc = $avcl->create_CLEAR_StarterSYS_ViPER($in);
} else {
  $xmlc = $avcl->create_CLEAR_ViPER($in);
}
MMisc::error_quit("ERROR: " . $avcl->get_errormsg())
  if ($avcl->error());
MMisc::error_quit("ERROR: \'create_CLEAR_ViPER\' did not create any XML")
  if (MMisc::is_blank($xmlc));
print OUT $xmlc;
close OUT;

print "\n==> Wrote", ($dosys ? "[SYS]" : ($doStarterSys ? "[StarterSYS]" : "[GTF]")), ": $out\n";

MMisc::ok_quit("\nDone\n");

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}
