#!/usr/bin/env perl

# AVSS09 XML Merger
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS09 XML Merger" is an experimental system.
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

my $versionid = "AVSS09 XML Merger Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../lib", "../../../CLEAR07/lib", "../../../common/lib");
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
foreach my $pn ("MMisc", "AVSS09ViperFile") {
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

my $xmllint_env = "F4DE_XMLLINT";
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $frameTol = 0;
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = (exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : "../../../CLEAR07/data";
my $show = 0;
my $forceFilename = "";
my $writedir = -1;
my $MemDump = undef;
my $skipSequenceMemDump = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   C  F                W        fgh          s  vwx    #

my %opt;
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'gtf'             => \$isgtf,
   'frameTol=i'      => \$frameTol,
   'ForceFilename=s' => \$forceFilename,
   'writedir=s'      => \$writedir,
   'WriteMemDump:s'  => \$MemDump,
   'skipSequenceMemDump' => \$skipSequenceMemDump,
   # Hiden Option(s)
   'X_show_internals'  => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\nNot enough arguments\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'ForceFilename\' option selected but no value set\n$usage")   if (($opt{'ForceFilename'}) && (MMisc::is_blank($forceFilename)));

if (($writedir != -1) && ($writedir ne "")) {
  # Check the directory
  my ($err) = MMisc::check_dir_w($writedir);
  MMisc::error_quit("Provided \'write\' option directory ($writedir): $err")
    if (! MMisc::is_blank($err));
  $writedir .= "/" if ($writedir !~ m%\/$%); # Add a trailing slash
}

if (defined $MemDump) {
  MMisc::error_quit("\'WriteMemDump\' can only be used in conjunction with \'write\'")
    if ($writedir == -1);
  $MemDump = $ok_md[0]
    if (MMisc::is_blank($MemDump));
  MMisc::error_quit("Unknown \'WriteMemDump\' mode ($MemDump), authorized: " . join(" ", @ok_md))
    if (! grep(m%^$MemDump$%, @ok_md));
}
  
##############################
# Main processing

my $step = 1;
##########
print "\n\n** STEP ", $step++, ": Load all files to be merged\n";

my $ntodo = scalar @ARGV;
my $ndone = 0;
my %all_vf = ();
my %merged = ();
foreach my $tmp (@ARGV) {
  my ($err, $fname, $fsshift, $idadd, @boxmod) = 
    AVSS09ViperFile::extract_transformations($tmp);
  MMisc::error_quit("While processing filename ($tmp): $err")
      if (! MMisc::is_blank($err));

  my ($key) = AVSS09ViperFile::get_key_from_transformations($fname, $fsshift, $idadd, @boxmod);
  MMisc::error_quit("File key ($key) seems to have already been loaded; can not load same file key multiple times, aborting")
    if (exists $all_vf{$key});

  my ($ok, $object) = &load_file($isgtf, $fname);
  next if (! $ok);

  # Do the transformations here
  my ($mods) = $object->Transformation_Helper($forceFilename, $fsshift, $idadd, @boxmod);
  MMisc::error_quit("Problem during \"transformations\": " . $object->get_errormsg())
      if ($object->error());

  # Get the sourcefile filename information to check if we already
  # have a merge candidate or it is the first file
  my ($sffn) = $object->get_sourcefile_filename();
  MMisc::error_quit("Problem obtaining sourcefile's filename: " . $object->get_errormsg())
      if ($object->error());

  $ndone++;

  if (! exists $merged{$sffn}) { # 1st of its kind: store in hash, wait for next
    $merged{$sffn} = $object;
    next;
  }

  # At this point, there is already an object to merge to, do it
  my $tmp = $merged{$sffn};
  $tmp->merge($object);
  MMisc::error_quit("Problem merging ViPER Files together: " . $tmp->get_errormsg())
      if ($tmp->error());
}

##########
print "\n\n** STEP ", $step++, ": Write all merged files\n";

my $fdone = 0;
foreach my $fname (keys %merged) {
  my $object = $merged{$fname};

  my ($txt) = $object->reformat_xml($isgtf);
  MMisc::error_quit("While trying to \'write\' (" . $object->get_errormsg() . ")")
      if ($object->error());
  my $tmp2 = $fname;
  $tmp2 =~ s%^.+\/([^\/]+)$%$1%;
  my $lfname = "$writedir$tmp2";
  MMisc::error_quit("Problem while trying to \'write\'")
      if (! MMisc::writeTo($lfname, "", 1, 0, $txt, "", "** XML re-Representation:\n"));

  if (defined $MemDump) {
    $object->write_MemDumps($lfname, $isgtf, $MemDump, $skipSequenceMemDump);
    MMisc::error_quit("Problem while trying to perform \'MemDump\'")
        if ($object->error());
  }

  $fdone++;
}

MMisc::ok_quit("All files processed (Read $ndone files / Wrote $fdone files)\n");

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
    &valok($tmp, $msg . (MMisc::is_blank($msg) ? "validates" : ""));
  } else {
    &valerr($tmp, $msg);
  }

  return($retstatus, $object);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

########################################

sub set_usage {
  my $wmd = join(" ", @ok_md);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help] [--version] [--gtf] [--xmllint location] [--CLEARxsd location] [--frameTol framenbr] [--writedir [directory] [--WriteMemDump [mode] [--skipSequenceMemDump]] [--ForceFilename file] viper_source_file.xml[transformations] [viper_source_file.xml[transformations] [...]]

Will merge AVSS09 Viper XML file whose sourcefile's filename is identical.

 Where:
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd  Path where the XSD files can be found
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default: $frameTol)
  --ForceFilename  Specify that all files loaded refers to the same 'sourcefile' file
  --writedir      Once processed in memory, print the new XML dump files to this directory (the output filename will the sourcefile's filename with the xml extension)
  --WriteMemDump  Write a memory representation of validated ViPER Files that can be used by the Scorer and Merger tools. Two modes possible: $wmd (1st default)
  --skipSequenceMemDump  Do not perform the sequence MemDump (useful for scoring) 
  --version       Print version number and exit
  --help          Print this usage information and exit

Transformations syntax: [:FSshift][\@BBmod][#IDadd]
where: 
- FSshift is the number of frames to add or substract from every framespan within this file
- BBmod is the bounding box modifications of the form X+YxM, ie X and Y add or substract and M multiply (example: @-10+20x0.5 will substract 10 from each X coordinate, add 20 to each Y, and multiply each resulting coordinate by 0.5)
- IDadd is the number of ID to add or substract to every PERSON ID sen within this file

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'CLEAR.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will disard any xml comment(s).
- 'CLEARxsd' files are the same as needed by CLEARDTViperValidator
- The merging process does not check/interpret/modify lower level data and will simply extent the framespan of the first file matching the sourcefile's filename found

EOF
;

  return $tmp;
}
