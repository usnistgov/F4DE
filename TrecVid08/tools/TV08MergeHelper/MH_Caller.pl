#!/usr/bin/env perl

# Merge Helper Caller
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Merge Helper Caller" is an experimental system.
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

my $versionid = "Merge Helper Caller (Version: $version)";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $tv08pl, $tv08plv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = $ENV{$f4b} . "/lib";
  $tv08pl = "TV08_PERL_LIB";
  $tv08plv = $ENV{$tv08pl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1")
  {
    warn_print
      (
       "\"Getopt::Long\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
      );
    $have_everything = 0;
  }

# File::Temp (usualy part of the Perl Core)
unless (eval "use File::Temp qw / tempfile /; 1")
  {
    warn_print
      (
       "\"File::Temp\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=file%3A%3Atemp\" for installation information\n"
      );
    $have_everything = 0;
  }

# Something missing ? Abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case permute));

########################################
# Options processing

my $merger = "TV08MergeHelper";
if ($f4bv ne "/lib") {
  my $t = $f4bv;
  $t =~ s%/lib%/bin%;
  $merger = "$t/$merger";
} else {
  $merger = "./$merger.pl";
}
my $logdir = ".";
my $usage = &set_usage();

# Default values for variables
my $show = 0;
my $ovdir = "";
my $ecfdir = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# USed:                               e  h   lm o   s  v     #

my @fileslist;
sub setfileslist {
  push @fileslist, @_;
}
my %opt;
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
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

ok_quit("\n$usage\n") if ($opt{'help'});
ok_quit("$versionid\n") if ($opt{'version'});

error_quit("No XML files seen on the command line\n\n$usage\n") if (scalar @fileslist == 0);
error_quit("No \'mergehelper\' parameters on the command line\n\n$usage\n") if (scalar @ARGV == 0);
my @merger_cmds = @ARGV;


#################### Main processing
my $step = 1;

########## Generated XML files list (per site / camera / date / site / excerpt)
print "\n\n** STEP ", $step++, ": Generate XML files list (per camera)\n";

my %tomerge;
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

  my $shift_fs = 0 + $beg_fs; # convert it into a number

  # Add ".mpeg" to the filekey
  $file_key .= ".mpeg";

  # Create the hash that contains the 'to merge' list 
  push @{$tomerge{$file_key}}, "$fn:$shift_fs";

  &valok($file, "ok" . (($shift_fs) ? " (will request a frameshift of $shift_fs)" : ""));
  $ndone++;
}

print "*-> All files loaded ( $ndone ok / $ntodo)\n";
error_quit("Can not continue, not all files patterns were recognized\n")
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
error_quit("Not all files merged, aborting\n")
  if ($ndone != $ntodo);

ok_quit("Done.\n");


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

####################

sub warn_print {
  print "WARNING: ", @_;
}

##########

sub error_quit {
  print("${ekw}: ", @_);

  print "\n";
  exit(1);
}

##########

sub ok_quit {
  print @_;

  print "\n";
  exit(0);
}

########################################

sub _get_tmpfilename {
  my (undef, $name) = tempfile( OPEN => 0 );

  return($name);
}

#####

sub _slurp_file {
  my $fname = shift @_;

  open FILE, "<$fname"
    or error_quit("[TrecVid08ViperFile] Internal error: Can not open file to slurp ($fname): $!\n");
  my @all = <FILE>;
  close FILE;

  my $tmp = join(" ", @all);
  chomp $tmp;

  return($tmp);
}

#####

sub _do_system_call {
  my @args = @_;
  
  my $cmdline = join(" ", @args);

  print "| |--> cmdline: [$cmdline]\n"
    if ($show);

  my $retcode = -1;
  # Get temporary filenames (created by the command line call)
  my $stdoutfile = &_get_tmpfilename();
  my $stderrfile = &_get_tmpfilename();

  open (CMD, "$cmdline 1> $stdoutfile 2> $stderrfile |");
  close CMD;
  $retcode = $?;

  # Get the content of those temporary files
  my $stdout = &_slurp_file($stdoutfile);
  my $stderr = &_slurp_file($stderrfile);

  # Erase the temporary files
  unlink($stdoutfile);
  unlink($stderrfile);

  return($retcode, $stdout, $stderr, $cmdline);
}

########################################

sub write_file {
  my $fname = shift @_;
  my $txt = shift @_;

  open FILE, ">$fname"
    or error_quit("Could not create output file ($fname): $!");
  print FILE $txt;
  close FILE;
}

#####

sub _cm_wf {
  my $header = shift @_;
  my $fname = shift @_;
  my $txt = shift @_;

  # Do not write empty files
  return if ($txt =~ m%^\s*$%);

  &write_file($fname, $txt);

  print "| |--> Wrote \"$header\" to \'$fname\'\n";
}

#####

sub call_merger {
  my $key = shift @_;
  my @files = @_;

  my @addcmdline;
  push @addcmdline, ("--ForceFilename", "$key");
  push @addcmdline, ("--overlaplistfile" , "$ovdir/$key.overlap.log") if ($ovdir ne "");
  push @addcmdline, ("--ecfhelperfile", "$ecfdir/$key.ecf.csv") if ($ecfdir ne "");

  my ($retcode, $stdout, $stderr, $cmdline) = &_do_system_call($merger, @merger_cmds, @addcmdline, @files);

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
