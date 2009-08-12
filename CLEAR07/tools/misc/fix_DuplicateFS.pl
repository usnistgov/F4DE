#!/usr/bin/env perl

# Fix Duplicate FrameSpans
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Fix Duplicate FrameSpans" is an experimental system.
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

my $versionid = "Fix Duplicate FrameSpans Version: $version";

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
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

if ($doit) {
  print "!!!!! REAL run mode !!!!!\n";
  print " Waiting 5 seconds (Ctrl+C to cancel)\n";
  sleep(5);
} else {
  print "********** DRYRUN mode **********\n";
}

my %replc = ();
foreach my $fn (@fl) {
  my $f = MMisc::slurp_file($fn);
  MMisc::error_quit("Problem slurping file [$fn]") if (! defined $f);

  %replc = ();
  my $g = $f;

  $g = &processit($g);

  if ($g ne $f) {
    print "\n** $fn differs: \n";
    if (scalar(keys %replc) == 0) {
      MMisc::error_quit("Unknown replacement");
    } else {
      foreach my $id (keys %replc) {
        my @fs = @{$replc{$id}};
        MMisc::error_quit("Empty content [ID:$id]") if (scalar @fs == 0);
        print " - [ID $id] Duplicates: " . join(" ", @fs) . "\n";
      }
    }

    if ($doit) {
      MMisc::error_quit("Problem writing output file [$fn]")
          if (! MMisc::writeTo($fn, "", 1, 0, $g));
    }
  }

}

MMisc::ok_quit("Done\n");

####################

sub processit {
  my ($fc) = @_;

  $fc =~ s%(<object\s.+?</object>)%&process_content($1)%sge;

  return($fc);
}

#####

sub process_content {
  my ($v) = @_;

  if ($v !~ m%<object\s+.*?name\s*\=\s*\"PERSON\"%s) {
    print "Not a person ?\n";
    return ($v);
  }

  my $out = "";
  my %fs = ();
  my $t = $v;

  MMisc::error_quit("Could not extract object header")
      if (! ($t =~ s%^(<object\s+.*?id\s*\=\s*\"(\d+)\".*?\>)%%s));
  my $id = $2;
  my $out .= $1;
  
  while ($t =~ s%^(.*?\<data\:bbox\s+.+?\/\>)%%s) {
    my $x = $1;

    MMisc::error_quit("Could not extract framespan from line [$x]")
        if (! ($x =~ m%framespan\s*\=\s*\"([^\"]+?)\"%));
    my $f = $1;

    if (exists $fs{$f}) {
      push @{$replc{$id}}, $f;
      next;
    }

    $out .= $x;
    $fs{$f}++;
  }

  $out .= $t;

  return($out);
}

########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--doit] xmlfiles

Try to fix known duplicate framespan definition for a given object by only keeping the first one found.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --doit          Perform modification (safer to do one pass without this option and rerun it with it once it exits wihtout error)

IMPORTANT NOTE: Modify files specified on the command line
EOF
;
  
  return($tmp);
}
