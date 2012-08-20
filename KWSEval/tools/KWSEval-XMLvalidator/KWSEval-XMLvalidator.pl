#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# KWSEval XML Validator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "KWSEval XML Validator" is an experimental system.
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
# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "KWSEval XML Validator Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../lib", "$f4d/../../../common/lib");
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
foreach my $pn ("MMisc", "KWSecf", "TermList", "KWSList") {
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

my @ok_md = ("gzip", "text"); # Default is gzip / order is important

my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Default values for variables

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                       W       e  h  k        t vw    #

my $issome = -1;
my $writeback = -1;
my $MemDump = undef;

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'ecf'       => sub {MMisc::error_quit("Can not specify more than one mode") if ($issome != -1); $issome = 0;},
   'kwslist'   => sub {MMisc::error_quit("Can not specify more than one mode") if ($issome != -1); $issome = 1;},
   'termlist'  => sub {MMisc::error_quit("Can not specify more than one mode") if ($issome != -1); $issome = 2;},
   'write:s'   => \$writeback,
   'WriteMemDump:s'  => \$MemDump,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Did not specify validation type, must be either \'--ecf\', \'--kwslist\' or \'--termlist\'")
  if ($issome == -1);

my $ndone = 0;
my $ntodo = 0;
while (my $tmp = shift @ARGV) {
  $ntodo++;

  my ($ok, $object) = &load_file($tmp);
  next if (! $ok);

  if ($writeback != -1) {
    my $fname = "";
    
    if ($writeback ne "") {
      my ($err, $td, $tf, $te) = MMisc::split_dir_file_ext($tmp);
      $fname = MMisc::concat_dir_file_ext($writeback, $tf, $te);
      MMisc::error_quit("Could not rewrite file ($fname)")
        if (! $object->saveFile($fname));
    } else {
      print $object->get_XMLrewrite();
    }

    if (defined $MemDump) {
      (my $err, $fname) = $object->save_MemDump($fname, $MemDump, 1);
      MMisc::error_quit("Problem writing the \'Memory Dump\' representation of the object: $err")
        if (! MMisc::is_blank($err));
    }

  }

  $ndone++;
}
print "All files processed (Validated: $ndone | Total: $ntodo)\n\n";
MMisc::error_exit()
  if ($ndone != $ntodo);

MMisc::ok_exit();

########## END

sub valok { print $_[0] . ": " . $_[1] . "\n"; }

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)) { 
    &valok($fname, "[ERROR] $_");
  }
}


sub load_file {
  my ($err, $object);
 
  if ($issome == 0) {
    ($err, $object) = &load_ECF($_[0]);
  } elsif ($issome == 1) {
    ($err, $object) = &load_KWSList($_[0]);
  } elsif ($issome == 2) {
    ($err, $object) = &load_TermList($_[0]);
  } else {
    MMisc::error_quit("Unknown Mode selected (we should not be here), aborting");
  }

  my $ok = MMisc::is_blank($err);
  if ($ok) {
    &valok($_[0], "validates");
  } else {
    &valerr($_[0], $err);
  }

  return($ok, $object);
}

##

sub load_ECF {
  my $object = new KWSecf();
  my $err = $object->loadFile($_[0]);
  return($err, $object);
}

## 

sub load_KWSList {
  my $object = new KWSList();
  my $err = $object->loadFile($_[0]);
  return($err, $object);
}

## 

sub load_TermList {
  my $object = new TermList();
  my $err = $object->loadFile($_[0]);
  return($err, $object);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################ Manual
sub set_usage {
  my $wmd = join(" ", @ok_md);

  my $tmp=<<EOF
$versionid

Usage:
$0 [--help] [--version] [--write [directory] [--WriteMemDump [mode]]] --ecf ecf_file.xml [ecf_file.xml [...]]
$0 [--help] [--version] [--write [directory] [--WriteMemDump [mode]]] --kwslist kwslist_file.xml [kwslist_file.xml [...]]
$0 [--help] [--version] [--write [directory] [--WriteMemDump [mode]]] --termlist kwlist_file.xml [kwlist_file.xml [...]]

Will validate KWS Eval's ECF, TermList or KWSlist files

Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --write         Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)
  --WriteMemDump  Write a memory representation of validated Files that can be used by the Scorer tools. Two modes possible: $wmd (1st default)

EOF
    ;

    return $tmp;
}
