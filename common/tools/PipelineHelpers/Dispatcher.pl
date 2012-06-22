#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# Dispatcher
# 
# Author: Martial Michel

# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
#
# It is an experimental system.  
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

my $versionid = "Dispatcher Version: $version";

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
      : ("$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "DirTracker") {
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

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

# Default values for variables

my $id = undef;
my $tsmin = 10;
my $tosleep = 60;
my $verb = 0;
my $cmd = "";
my $salttool = "";

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                   S         cde  h             v      #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'verbose+'    => \$verb,
   'scaninterval=i' => \$tosleep,
   'dir=s'      => \$id,
   'command=s'  => \$cmd,
   'SaltTool=s' => \$salttool,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("\'scaninterval\' value under minimum of ${tsmin}s")
  if ($tosleep < $tsmin);

my $err = MMisc::check_dir_r($id);
MMisc::error_quit("Problem with \'dir\' ($id): $err") if (! MMisc::is_blank($err));

$err = MMisc::check_file_x($cmd);
MMisc::error_quit("Problem with \'cmd\' ($cmd): $err") if (! MMisc::is_blank($err));

#####
my $dt = new DirTracker($id, $salttool);
MMisc::error_quit("Problem with DirTracker: " . $dt->get_errormsg()) if ($dt->error());
my $now = MMisc::get_currenttime();
MMisc::vprint(($verb > 0), "!! Performing initial scan of ($id)\n"); 
$dt->init(1);
MMisc::error_quit("Problem with DirTracker initialization: " . $dt->get_errormsg()) if ($dt->error());

my $doit = 1;
my %tocheck = ();
my %tochecksoon = ();
while ($doit) {
  MMisc::vprint(($verb > 0), "  (sleeping ${tosleep}s)\n");
  sleep($tosleep);
  MMisc::vprint(($verb > 0), "[" . sprintf("%.02f", MMisc::get_elapsedtime($now)) . "] Iteration: $doit\n");

  my @newfiles = $dt->scan();
  MMisc::error_quit("Problem with DirTracker scan: " . $dt->get_errormsg()) if ($dt->error());
  MMisc::vprint(($verb > 0), "!! Performing updated scan of ($id)\n"); 
  
  if ($verb > 1) {
    foreach my $file ($dt->just_added()) { MMisc::vprint(($verb > 1), " (justAdded) $file\n"); }
    foreach my $file ($dt->just_deleted()) { MMisc::vprint(($verb > 1), " (justDeleted) $file\n"); }
    foreach my $file ($dt->just_modified()) { MMisc::vprint(($verb > 1), " (justModified) $file\n"); }
  }

  foreach my $file (@newfiles) {
    MMisc::vprint(($verb > 0), "++ new file candidate: $file\n");
    $err = MMisc::check_file_r($file);
    if (! MMisc::is_blank($err)) {
      MMisc::warn_print("Can not use file ($file): $err");
      next;
    }

    my $sha256 = $dt->sha256digest($file);
    if ($dt->error()) {
      MMisc::warn_print("Problem obtaining new file's SHA256 ($file), skipping");
      $dt->clear_error();
      next;
    }

    MMisc::vprint(($verb > 1), "%% SHA256: $sha256\n");
    $tochecksoon{$file} = $sha256;
  }

  foreach my $file (keys %tocheck) {
    # check if file changed since last check
    MMisc::vprint(($verb > 0), "== confirming file ($file) has not changed since last scan\n"); 
    my $sha256 = $dt->sha256digest($file);
    if ($dt->error()) {
      MMisc::warn_print("Problem obtaining old file's SHA256 ($file), skipping");
      $dt->clear_error();
      delete $tocheck{$file};
      next;
    }

    if ($sha256 ne $tocheck{$file}) {
      MMisc::warn_print("File ($file) not finished copying/downloading, will check again next iteration");
      MMisc::vprint(($verb > 1), "%% newSHA256: $sha256\n");
      MMisc::vprint(($verb > 1), "%% oldSHA256: " . $tocheck{$file} . "\n");
      $tocheck{$file} = $sha256;
      next;
    }

    # same file, process it
    &process_file($file);
    delete $tocheck{$file}; # do not process it next time
  }

  # add new files to next check
  foreach my $file (keys %tochecksoon) {
    $tocheck{$file} = $tochecksoon{$file};
    delete $tochecksoon{$file};
  }

  $doit++;
}

MMisc::ok_quit("Done");

####################

sub process_file {
  my ($file) = @_;

  my $command = "$cmd $file";
  MMisc::vprint(($verb > 0), ">> Background command: $command\n");

  # run command in background, as far as WE are concerned we did our job
  system("$command &");
}

####################

sub set_usage {
    my $tmp=<<EOF

$0 [--help] [--verbose] [--scaninterval inseconds] [--SaltTool tool] --dir dirtotrack --command commandtorun

Will track for any new files (*) in \'dirtotrack\' (recursively) and start as a background process: \'commandtorun newfile\' (one new process per new file)

Note: the process never ends and has to be user interuppted (Ctrl+C or kill command)

Note: the tool can only track directories and files it can have access too

*: a "new file" is a file that was added after the tool was started and whose content is not changing anymore (checked at each \'scaninterval\', a file currently being copied/downloaded will continue to change). We rely on the files SHA256 digest to stay the same from the previous scan and the next. 

Where:
  --help          This help message
  --verbose       Be a little more verbose
  --scaninterval  Value in seconds in between recursive directory scans (min: ${tsmin}s, default: ${tosleep}s)
  --SaltTool      Location of a tool which will be given the filename of files for which the SHA256 need to be computed; the one liner standard out string value returned by tool will be used as an extra value prepended to the SHA256 to further differentiate files
  --dir           Directory to track (will also track files in it sub directories)
  --command       Command to run 
EOF
;

  return($tmp);
}
