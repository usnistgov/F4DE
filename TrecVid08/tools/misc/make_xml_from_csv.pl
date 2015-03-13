#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 Make XML(s) from CSV(s)
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 random CSV generator" is an experimental system.
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

my $versionid = "TrecVid08 Make XML(s) from CSV(s) Version: $version";

##########
# Check we have every module (perl wise)

my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
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
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "TrecVid08ViperFile", "TrecVid08Observation", "CSVHelper") {
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
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
my @ok_events = $dummy->get_full_events_list();
# We will use the '$dummy' to do checks before processing files

my @ok_csv_keys = TrecVid08Observation::get_ok_csv_keys();

########################################
# Options processing

my $tool = "$f4d/../TV08ViperValidator/TV08ViperValidator.pl";
my $fps = 25;
my $usage = &set_usage();

# Default values for variables
my @asked_events = ();
my $isgtf = 0;
my $changetype = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   C                             gh   l       t v      #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   # TV08ViperValidator options
   'limitto=s'       => \@asked_events,
   'tool=s'          => \$tool,
   'gtf'             => \$isgtf,
   'ChangeType'      => \$changetype,
   'fps=s'           => \$fps,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Not enough arguments left on command line\n\n$usage\n")
    if (scalar @ARGV < 3);

MMisc::error_quit("Too many arguments left on command line\n\n$usage\n")
    if (scalar @ARGV > 4);

my ($CSVinDir, $XMLinDir, $outDir, $stagingDir) = @ARGV;

$CSVinDir = MMisc::get_dir_actual_dir($CSVinDir);
my $err = MMisc::check_dir_r($CSVinDir);
MMisc::error_quit("Problem with \'CSVinDir\': $err\n\n$usage\n")
  if (! MMisc::is_blank($err));

$XMLinDir = MMisc::get_dir_actual_dir($XMLinDir);
$err = MMisc::check_dir_r($XMLinDir);
MMisc::error_quit("Problem with \'XMLinDir\': $err\n\n$usage\n")
  if (! MMisc::is_blank($err));

$outDir = MMisc::get_dir_actual_dir($outDir);
$err = MMisc::check_dir_w($outDir);
MMisc::error_quit("Problem with \'outDir\': $err\n\n$usage\n")
  if (! MMisc::is_blank($err));

if (MMisc::is_blank($stagingDir)) { $stagingDir = MMisc::get_tmpdir(); }
$stagingDir = MMisc::get_dir_actual_dir($stagingDir);
$err = MMisc::check_dir_w($stagingDir);
MMisc::error_quit("Problem with \'stagingDir\': $err\n\n$usage\n")
  if (! MMisc::is_blank($err));

if (scalar @asked_events == 0) {
  @asked_events = @ok_events;
} else {
  @asked_events = $dummy->validate_events_list(@asked_events);
  MMisc::error_quit("While checking \'limitto\' events list (" . $dummy->get_errormsg() .")")
    if ($dummy->error());
}

$err = MMisc::check_file_x($tool);
MMisc::error_quit("Problem with \'tool\' executable ($tool): $err\n\n$usage\n")
    if (! MMisc::is_blank($err));

## Pre checks

my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($CSVinDir, 1);
MMisc::error_quit("Problem checking input \'CSVinDir\': $err")
    if (! MMisc::is_blank($err));
#print "---", join(" ", @{$rf}), "\n";
my @CSVfiles = grep(m%\.csv$%i, @{$rf});
MMisc::error_quit("Found no CSV files in \'CVSinDir\' ($CSVinDir)")
    if (scalar @CSVfiles == 0);
my %CSVhash = &file_hash(@CSVfiles);

($err, $rd, $rf, $ru) = MMisc::list_dirs_files($XMLinDir, 1);
MMisc::error_quit("Problem checking input \'XMLinDir\': $err")
    if (! MMisc::is_blank($err));
my @XMLfiles = grep(m%\.xml$%i, @{$rf});
MMisc::error_quit("Found no XML files in \'XMLinDir\' ($XMLinDir)")
    if (scalar @XMLfiles == 0);
my %XMLhash = &file_hash(@XMLfiles);

# Need to match all CSV before proceeding
my $etxt = "";
foreach my $ifile (sort keys %CSVhash) {
    my $fifile = $CSVhash{$ifile};
    $err = MMisc::check_file_r($fifile);
    if (! MMisc::is_blank($err)) {
        $etxt .= " - problem with CSV input file ($fifile): $err";
    }

    if (! exists $XMLhash{$ifile}) {
        $etxt .= " - could not find matching XML file for $ifile CSV\n";
    } else {
        my $fifile2 = $XMLhash{$ifile};
        $err = MMisc::check_file_r($fifile2);
        if (! MMisc::is_blank($err)) {
            $etxt .= " - problem with XML input file ($fifile2): $err";
        }
    }        
}
MMisc::error_quit("Can not continue, found some issues:\n$etxt")
    if (! MMisc::is_blank($etxt));

## core processing
my $btmpfile = MMisc::get_tmpfile();
foreach my $ifile (sort keys %CSVhash) {
    print "[*] $ifile\n";
    
    my $csvf = $CSVhash{$ifile};
    my $xmlf = $XMLhash{$ifile};

    # 1) remove + type conversion
    my @cmdl1 = ($tool);
    push @cmdl1, '--write', $stagingDir;
    if (scalar @asked_events > 0) { push @cmdl1, '--limitto', join(',', @asked_events); }
    if ($isgtf) { push @cmdl1, '--gtf'; }
    if ($changetype) {push @cmdl1, '--ChangeType'; }   
    push @cmdl1, '--Remove', 'ALL';
    push @cmdl1, $xmlf;

    my ($ok, $otxt, $stdout, $stderr, $retcode, $tmpfile, $signal) =
        MMisc::write_syscall_smart_logfile($btmpfile, @cmdl1);
          MMisc::error_quit("Problem running \'tool\' command (stage1), for more details, see: $tmpfile")
              if ((! $ok) || ($retcode + $signal != 0));

    my $sxmlf = "$stagingDir/$ifile.xml";
    $err = MMisc::check_file_r($sxmlf);
    MMisc::error_quit("Problem with expected staging file ($sxmlf): $err")
        if (! MMisc::is_blank($err));
    
    # 2) CSV insertion
    my @cmdl2 = ($tool);
    push @cmdl2, '--write', $outDir;
    if (scalar @asked_events > 0) { push @cmdl2, '--limitto', join(',', @asked_events); }
    # if 'changetype' and previous was NOT GTF, stageing file is GTF
    # if NOT 'changetype', previous was and still is GTF
    if ((($changetype) && (! $isgtf)) || ((! $changetype) && ($isgtf))) { push @cmdl2, '--gtf'; }
    push @cmdl2, '--fps', $fps;
    push @cmdl2, '--insertCSV', $csvf;
    push @cmdl2, $sxmlf;

    ($ok, $otxt, $stdout, $stderr, $retcode, $tmpfile, $signal) =
        MMisc::write_syscall_smart_logfile($btmpfile, @cmdl2);
    MMisc::error_quit("Problem running \'tool\' command (stage2), for more details, see: $tmpfile")
        if ((! $ok) || ($retcode + $signal != 0));

    my $oxmlf = "$outDir/$ifile.xml";
    $err = MMisc::check_file_r($oxmlf);
    MMisc::error_quit("Problem with expected final XML file ($oxmlf): $err\n  (maybe $tmpfile contains some answer as to why)\n")
        if (! MMisc::is_blank($err));

    print "  |-> wrote: $oxmlf\n";
}



MMisc::ok_exit();

##########

sub file_hash {
    my %tmp = ();
    foreach my $ifile (@_) {
        my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($ifile);
        MMisc::error_quit("While obtaining file name information: $err")
            if (! MMisc::is_blank($err));
        $tmp{$file} = $ifile;
#        print "[$file / $ifile]\n";
    }

    return(%tmp);
}

########## END

sub set_usage {
  my $ro = join(" ", @ok_events);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--limitto event1[,event2[...]]] [--tool TV08ViperValidator_location] [--gtf] [--ChangeType] [--fps fps] CSVinDir XMLinDir outDir [stagingDir]

Will find XML files (in XMLinDir) matching the CVS files (in CSVinDir, only matching on file name), emtpy the XMLs and fill them with values found in the CSVs, writing the result in outDir
Note that the conversion process requires a staging dir (remove has to be done before the insert); if none is provided, one will be created 

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --limitto       Only care about provided list of events
  --tool          Location of the TV08ViperValidator tool (default: $tool)
  --gtf           Specify that the original XML file to read is a Ground Truth File
  --ChangeType    Convert a SYS to REF or a REF to SYS
  --fps           Specify the fps to provide the tool (default value if none provided: $fps)

  
Note:
 - the process will not convert a   
 - List of recognized events: $ro
EOF
    ;

  return $tmp;
}
