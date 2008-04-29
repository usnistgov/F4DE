#!/usr/bin/env perl

# TrecVid08 Stat Generator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Stat Generator" is an experimental system.
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

my $versionid = "TrecVid08 Stat Generator (Version: $version)";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($tv08pl, $tv08plv, $f4depl, $f4deplv);
BEGIN {
  $tv08pl = "TV08_PERL_LIB";
  $tv08plv = $ENV{$tv08pl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv);

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files (please check your $tv08pl and $f4depl environment variables).";

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1")
  {
    warn_print("\"TrecVid08ViperFile\" is not available in your Perl installation. ", $partofthistool);
    $have_everything = 0;
  }

unless (eval "use TrecVid08Observation; 1")
  {
    warn_print("\"TrecVid08Observation\" is not available in your Perl installation. ", $partofthistool);
    $have_everything = 0;
  }

unless (eval "use ViperFramespan; 1")
  {
    warn_print("\"ViperFramespan\" is not available in your Perl installation. ", $partofthistool);
    $have_everything = 0;
  }

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

# Something missing ? Abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
my @ok_events = $dummy->get_full_events_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

########################################
# Options processing

my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $usage = &set_usage();

# Default values for variables
my $show = 0;
my $xmllint = &_get_env_val($xmllint_env, "");
my $xsdpath = &_get_env_val($xsdpath_env, "../../data");
my $fps = -1;
my $isgtf = 0;
my $docsv = -1;
my $discardErr = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:                    T        cd fgh             v x  

my %opt;
my $dbgftmp = "";
my @leftover;
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => \$isgtf,
   'fps=s'           => \$fps,
   'csv:s'           => \$docsv,
   'discardErrors'   => \$discardErr,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

die("\n$usage\n") if (scalar @ARGV == 0);

die("ERROR: \'fps\' must set in order to do any scoring work") if ($fps == -1);

if ($xmllint ne "") {
  error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

##########
# Main processing
my $tmp;
my %all = ();
my $ntodo = scalar @ARGV;
my $ndone = 0;
my @all_observations;
while ($tmp = shift @ARGV) {
  my ($ok, $object) = &load_file($isgtf, $tmp);
  next if (! $ok);

  my @ao = $object->get_all_events_observations();
  error_quit("Problem obtaining all Observations from $tmp ViperFile (" . $object->get_errormsg() . ")")
    if ($object->error());

  push @all_observations, @ao;

  $all{$tmp} = $object;
  $ndone++;
}
print "All files loaded (ok: $ndone / $ntodo)\n";
error_quit("Can not continue, not all files passed the loading/validation step, aborting\n")
  if (! ($discardErr) && ($ndone != $ntodo));
error_quit("No files ok, can not continue, aborting\n")
  if ($ndone == 0);

# Re-represent all observations into a flat format
my %ohash;
foreach my $obs (@all_observations) {
  my $uid  = $obs->get_unique_id();
  my $et   = $obs->get_eventtype();
  my $id   = $obs->get_id();
  my $gtfs = $obs->get_isgtf();
  my $fn   = $obs->get_filename();
  my $xfn  = $obs->get_xmlfilename();
  my $ds   = (! $gtfs) ? $obs->get_DetectionScore() : undef;
  my $dd   = (! $gtfs) ? $obs->get_DetectionDecision() : undef;
  my $fs_fs = $obs->get_framespan();
  my $fs   = $fs_fs->get_value();
  my $dur  = $obs->Dur();
  my $beg  = $obs->Beg();
  my $end  = $obs->End();
  my $mid  = $obs->Mid();
  
  error_quit("Problem obtaining Observation information (" . $obs->get_errormsg() . ")")
    if ($obs->error());
  error_quit("Problem obtaining Observation's framespan information (" . $fs_fs->get_errormsg() . ")")
    if ($fs_fs->error());

  %{$ohash{$uid}} =
    (
     UID        =>  $uid,
     EventType  => $et,
     ID         => $id,
     isGTF      => $gtfs,
     Filename   => $fn,
     XMLFile    => $xfn,
     DetectionScore => $ds,
     DetectionDecision => $dd,
     Framespan  => $fs,
     Duration   => $dur,
     Beginning  => $beg,
     End        => $end,
     MiddlePoint => $mid,
    );
}

if ($docsv != -1) {
  my @csv_header = 
    ("EventType", "ID", "isGTF", "Framespan", "Duration", "Beginning", "End", "MiddlePoint",
     "DetectionScore", "DetectionDecision", "Filename", "XMLFile");
  my $txt = &do_csv(\@csv_header, %ohash);

  if ($docsv ne "") {
    open CSV, ">$docsv"
      or die("Problem opening csv file ($docsv): $!\n");
    print CSV $txt;
    close CSV;
    print "Wrote CSV file: $docsv\n";
  } else {
    print $txt;
  }
}

die "Done\n";
########## END

########################################

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 --fps fps [--help] [--version] [--xmllint location] [--TrecVid08xsd location] [--discardErrors] [-csv [file.csv]] file.xml [file.xml [...]]

Will Score the XML file(s) provided (Truth vs System)

 Where:
  --gtf           Specify that the files are gtf
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --fps           Set the number of frames per seconds (float value) (also recognined: PAL, NTSC)
  --csv           Generate output representation as CSV (to file if given)
  --discardErrors Continue processing even if not all xml files can be properly loaded
  --version       Print version number and exit
  --help          Print this usage information and exit

Note:
- This prerequisite that the file has already been validated against the 'TrecVid08.xsd' file (using xmllint)
- Program will ignore the <config> section of the XML file.
- List of recognized events: $ro
- 'TrecVid08xsd' files are: $xsdfiles
EOF
;

  return $tmp;
}

####################

sub warn_print {
  print "WARNING: ", @_;

  print "\n";
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

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;

  &valok($fname, "[ERROR] $txt");
}

##########

sub load_file {
  my ($isgtf, $tmp) = @_;

  if (! -e $tmp) {
    &valerr($tmp, $isgtf, "file does not exists, skipping");
    return(0, ());
  }
  if (! -f $tmp) {
    &valerr($tmp, $isgtf, "is not a file, skipping\n");
    return(0, ());
  }
  if (! -r $tmp) {
    &valerr($tmp, $isgtf, "file is not readable, skipping\n");
    return(0, ());
  }
  
  # Prepare the object
  my $object = new TrecVid08ViperFile();
  error_quit("While trying to set \'xmllint\' (" . $object->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $object->set_xmllint($xmllint)) );
  error_quit("While trying to set \'TrecVid08xsd\' (" . $object->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $object->set_xsdpath($xsdpath)) );
  error_quit("While setting \'gtf\' status (" . $object->get_errormsg() . ")")
    if ( ($isgtf) && ( ! $object->set_as_gtf()) );
  error_quit("While setting \'fps\' ($fps) (" . $object->get_errormsg() . ")")
    if ( ! $object->set_fps($fps) );
  error_quit("While setting \'file\' ($tmp) (" . $object->get_errormsg() . ")")
    if ( ! $object->set_file($tmp) );
  
  # Validate (important to confirm that we can have a memory representation)
  if (! $object->validate()) {
    &valerr($tmp, $object->get_errormsg());
    return(0, ());
  }

  &valok($tmp, "Loaded");
  
  return(1, $object);
}

########################################

sub quc { # Quote clean
  my $in = shift @_;

  $in =~ s%\"%\'%g;

  return($in);
}

#####

sub qua { # Quote Array
  my @todo = @_;

  my @out = ();
  foreach my $in (@todo) {
    $in = &quc($in);
    push @out, "\"$in\"";
  }

  return(@out);
}

#####

sub generate_csvline {
  my @in = @_;

  @in = &qua(@in);
  my $txt = join(",", @in), "\n";

  return($txt);
}

#####

sub get_csvline {
  my ($rord, $uid, %ohash) = @_;

  my @keys = @{$rord};

  my @todo;
  foreach my $key (@keys) {
    error_quit("Problem accessing key ($key) from observation hash")
      if (! exists $ohash{$uid}{$key});
    push @todo, $ohash{$uid}{$key};
  }

  return(&generate_csvline(@todo));
}

#####

sub do_csv {
  my ($rord, %ohash) = @_;

  my @header = @{$rord};
  my $txt = "";

  $txt .= &generate_csvline(@header);
  $txt .= "\n";

  foreach my $uid (sort keys %ohash) {
    $txt .= &get_csvline($rord, $uid, %ohash);
    $txt .= "\n";
  }

  return($txt);
}

########################################

sub _get_env_val {
  my $envv = shift @_;
  my $default = shift @_;

  my $var = $default;

  $var = $ENV{$envv} if (exists $ENV{$envv});

  return($var);
}
