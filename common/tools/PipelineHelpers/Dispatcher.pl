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
foreach my $pn ("MMisc", "DispatcherHelper") {
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
my $tsmin = 15;
my $tosleep = 60;
my $verb = 0;
my $cmd = "";
my $salttool = "";
my @ignore = ();
my $resumefile = "";
my $doresume = 0;
my $SHAhist = 0;

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                  RS         cd f hi        rs  v      #

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
   'ignoreFile=s' => \@ignore,
   'resumeFile=s' => \$resumefile,
   'Resume' => \$doresume,
   'fullHistory' => \$SHAhist,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("\'Resume\' can only be used if \'resumeFile\' is used")
  if (($doresume != 0) && (MMisc::is_blank($resumefile)));

MMisc::error_quit("\'scaninterval\' value under minimum of ${tsmin}s")
  if ($tosleep < $tsmin);

my $err = MMisc::check_dir_r($id);
MMisc::error_quit("Problem with \'dir\' ($id): $err") if (! MMisc::is_blank($err));

$err = MMisc::check_file_x($cmd);
MMisc::error_quit("Problem with \'cmd\' ($cmd): $err") if (! MMisc::is_blank($err));

##
my $dh = new DispatcherHelper();
MMisc::error_quit($dh->get_errormsg()) if ($dh->error());

my $resumed = 0;
if (! MMisc::is_blank($resumefile)) {
  $dh->set_saveStateFile($resumefile);
  MMisc::error_quit($dh->get_errormsg()) if ($dh->error());

  if ($doresume != 0) {
    $resumed = $dh->load_saveStateFile();
    MMisc::error_quit($dh->get_errormsg()) if ($dh->error());
  }
}

if ($resumed == 0) {
  $dh->set_dir($id);
  MMisc::error_quit($dh->get_errormsg()) if ($dh->error());

  if (! MMisc::is_blank($salttool)) {
    $dh->set_salttool($salttool);
    MMisc::error_quit($dh->get_errormsg()) if ($dh->error());
  }
}

$dh->set_SHAhist($SHAhist);
MMisc::error_quit($dh->get_errormsg()) if ($dh->error());

$dh->set_scaninterval($tosleep);
MMisc::error_quit($dh->get_errormsg()) if ($dh->error());
  
$dh->set_command($cmd);
MMisc::error_quit($dh->get_errormsg()) if ($dh->error());

$dh->set_verbosity_level($verb);
MMisc::error_quit($dh->get_errormsg()) if ($dh->error());

foreach my $ie (@ignore) {
  $dh->addto_ignore($ie);
  MMisc::error_quit($dh->get_errormsg()) if ($dh->error());
}

if ($resumed == 0) {
  $dh->init();
  MMisc::error_quit($dh->get_errormsg()) if ($dh->error());
}

$dh->loop(); # we should never come out of here, unless an error occured
MMisc::error_quit($dh->get_errormsg()) if ($dh->error());

MMisc::ok_quit("Done");

####################

sub set_usage {
    my $tmp=<<EOF

$0 [--help] [--verbose] [--fullHistory] [--scaninterval inseconds] [--SaltTool tool] [--ignoreFile string [--ignoreFile string [...]]] [--resumeFile [--Resume]] --dir dirtotrack --command commandtorun

Will track for any new files (*) in \'dirtotrack\' (recursively) and start as a background process: \'commandtorun newfile\' (one new process per new file)

Note: the process never ends and has to be user interuppted (Ctrl+C or kill command)

Note: the tool can only track directories and files it can have access too

*: a "new file" is a file that was added after the tool was started and whose content is not changing anymore (checked at each \'scaninterval\', a file currently being copied/downloaded will continue to change). We rely on the files SHA256 digest to stay the same from the previous scan and the next. 

Where:
  --help          This help message
  --verbose       Be a little more verbose
  --fullHistory   Keep an internal history of every SHA256 seen (including deleted files whose SHA were authorized to be forgotten)
  --scaninterval  Value in seconds in between recursive directory scans (min: ${tsmin}s, default: ${tosleep}s)
  --SaltTool      Location of a tool which will be given the filename of files for which the SHA256 need to be computed; the one liner standard out string value returned by tool will be used as an extra value prepended to the SHA256 to further differentiate files
  --ignoreFile    If a new file found contain the provided string, do not run the command on it
  --resumeFile    Store last iteration into a memory dump file that can be used at a later time to restart exactly as if nothing had happened
  --Resume        if the \'resumeFile\' is present, try to load it and \"resume\" from it (\'dir\' and \'salttool\' are then ignored, but other values can be added. \'ignoreFile\' entries can be added to the one loaded from the resume file)
  --dir           Directory to track (will also track files in it sub directories)
  --command       Command to run
EOF
;

  return($tmp);
}
