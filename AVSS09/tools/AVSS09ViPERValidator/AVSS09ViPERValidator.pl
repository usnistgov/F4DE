#!/usr/bin/env perl

# AVSS09 ViPER File Validator
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

my $versionid = "AVSS09 Viper XML Validator Version: $version";

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
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $clearpl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"AVSS09ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# AVSS09ViperFile (part of this tool)
unless (eval "use AVSS09ViperFile; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"AVSS09ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
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

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Options processing

my $xmllint_env = "CLEAR_XMLLINT";
my $xsdpath_env = "CLEAR_XSDPATH";
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $usage = "USAGE TODO";

# Default values for variables
my $isgtf = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../../CLEAR07/data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../../CLEAR07/data"));
my $frameTol = 0;
my $show = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   CD               T  WX       fgh   l         vwx    #

my %opt;
my $dbgftmp = "";

GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'gtf'             => \$isgtf,
   'frameTol=i'      => \$frameTol,
   # Hiden Option(s)
   'show_internals'  => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);


##########
# Main processing
my $tmp;
my $ntodo = scalar @ARGV;
my $ndone = 0;
while ($tmp = shift @ARGV) {
  my ($ok, $object) = &load_file($isgtf, $tmp);
  next if (! $ok);

#  print "**[", $object->get_xmllint(""), "]**\n";
#  MMisc::error_quit($object->get_errormsg())
#      if ($object->error());

  print "** Object:\n", $object->_display_all()
    if ($show);

  $ndone++;
}

MMisc::ok_quit("All files processed (Validated: $ndone | Total: $ntodo)\n");

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)){ 
    &valok($fname, "[ERROR] $_");
  }
}

##########

sub load_file {
  my ($isgtf, $tmp) = @_;

  my ($retstatus, $object, $msg) = 
    AVSS09ViperFile::load_ViperFile($isgtf, $tmp, $frameTol, $xmllint, $xsdpath);

  if ($retstatus) { # OK return
    &valok($tmp, "validates");
  } else {
    &valerr($tmp, $msg);
  }

  return($retstatus, $object);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}
