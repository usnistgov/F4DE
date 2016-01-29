#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
    if 0;

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# TrecVid08 Merge Helper Caller
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Merge Helper Caller" is an experimental system.
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

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "TrecVid08 Merge Helper Caller ($versionkey)";

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
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case permute));

########################################
# Options processing

my $merger = "TV08MergeHelper";
$merger ="$f4d/$merger.pl";

my $logdir = ".";
my $usage = &set_usage();

# Default values for variables
my $show = 0;
my $ovdir = "";
my $ecfdir = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# USed:                               e  h   lm o   s  v     #

my @fileslist = ();
sub setfileslist {
  push @fileslist, @_;
}
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'mergehelper=s'=> \$merger,
   'show_cmdline' => \$show,
   'logdir=s'     => \$logdir,
   'overlaplistdir=s' => \$ovdir,
   'ecfhelperdir=s'   => \$ecfdir,
   '<>'   => \&setfileslist,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No XML files seen on the command line\n\n$usage\n") if (scalar @fileslist == 0);
MMisc::error_quit("No \'mergehelper\' parameters on the command line\n\n$usage\n") if (scalar @ARGV == 0);
my @merger_cmds = @ARGV;


#################### Main processing
my $step = 1;

########## Generated XML files list (per site / camera / date / site / excerpt)
print "\n\n** STEP ", $step++, ": Generate XML files list (per camera)\n";

my %tomerge = ();
my $camkey = "_CAM";
my $ntodo = scalar @fileslist;
my $ndone = 0;
foreach my $fn (@fileslist) {
  my $dir = ".";
  my $file = $fn;

  if ($fn =~ m%^(.+)/([^\/]+)$%) {
    $dir = $1;
    $file = $2;
  }

  if ($file !~ m%^(.+?${camkey}\d+)\_(\d+)\_(\d+)\_.+\.\w+%) {
    &valerr($file, "Filename does not follow the expected pattern, skipping");
    next;
  }

  my $file_key = $1;
  my $beg_fs = $2;
  my $end_fs = $3;

  my $shift_fs = sprintf("%d", $beg_fs); # convert it into a number

  # Add ".mpeg" to the filekey
  $file_key .= ".mpeg";

  # Create the hash that contains the 'to merge' list 
  push @{$tomerge{$file_key}}, "$fn:$shift_fs";

  &valok($file, "ok" . (($shift_fs) ? " (will request a frameshift of $shift_fs)" : ""));
  $ndone++;
}

print "*-> All files loaded ( $ndone ok / $ntodo)\n";
MMisc::error_quit("Can not continue, not all files patterns were recognized\n")
  if ($ndone != $ntodo);

########## Call the merger

print "\n\n** STEP ", $step++, ": Calling the merger script\n";
my @atomerge = sort keys %tomerge;
my $ntodo = scalar @atomerge;
my $ndone = 0;
foreach my $key (@atomerge) {
  my @files = @{$tomerge{$key}};

  print "|--> $key\n";

  next if (! &call_merger($key, @files));

  $ndone++;
}
print "\n*-> All files merged ( $ndone ok / $ntodo)\n";
MMisc::error_quit("Not all files merged, aborting\n")
  if ($ndone != $ntodo);

MMisc::ok_quit("Done.\n");


########################################

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;

  &valok($fname, "[ERROR] $txt");
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

########################################

sub _cm_wf {
  my $header = shift @_;
  my $fname = shift @_;
  my $txt = shift @_;

  # Do not write empty files
  return if ($txt =~ m%^\s*$%);

  MMisc::writeTo($fname, "", 0, 0, $txt);

  print "| |--> Wrote \"$header\" to \'$fname\'\n";
}

#####

sub call_merger {
  my $key = shift @_;
  my @files = @_;

  my @addcmdline = ();
  push @addcmdline, ("--ForceFilename", "$key");
  push @addcmdline, ("--overlaplistfile" , "$ovdir/$key.overlap.log") if ($ovdir ne "");
  push @addcmdline, ("--ecfhelperfile", "$ecfdir/$key.ecf.csv") if ($ecfdir ne "");

  my @itcl = ($merger, @merger_cmds, @addcmdline, @files);
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call(@itcl);
  my $cmdline = join(" ", @itcl);

  print "| |--> Command line: $cmdline\n" if ($show);
  &_cm_wf("commandline", "$logdir/${key}.cmdline", $cmdline);
  &_cm_wf("run log", "$logdir/${key}.run.log", $stdout);
  &_cm_wf("error output", "$logdir/${key}.run.error", $stderr);
  print "| |--> Return code: ", ($retcode == 0) ? "OK" : "ERROR", "\n";
  print "|\n";

  if ($retcode == 0) {
    return(1);
  } else {
    return(0);
  }
}

############################################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--mergehelper fullcommandpath] [--show_cmdline] [--logdir dir] [--overlaplistdir dir] [--ecfhelperdir dir] file.xml [file.xml [...]] -- merger_parameters

Will Score the XML file(s) provided (Truth vs System)

 Where:
  --mergehelper   Provide the mergehelper command location (Default: $merger)
  --show_cmdline  Display the merger command line that will be used
  --logdir        Specify the log directory (Default: $logdir)
  --overlaplistdir Specify the directory in which to ask the merger to generate the overlaplistfile
  --ecfhelperdir  Specify the directory in which to ask the merger to generate the ecfhelperfile
  --version       Print version number and exit
  --help          Print this usage information and exit
EOF
    ;

    return $tmp;
}
