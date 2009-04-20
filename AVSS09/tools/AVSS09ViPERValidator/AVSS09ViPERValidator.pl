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
# "AVSS09 ViPER XML Validator" is an experimental system.
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

my $versionid = "AVSS09 ViPER XML Validator Version: $version";

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
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $avpl, $clearpl and $f4depl environment variables).";
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
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../../CLEAR07/data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../../CLEAR07/data"));
my $frameTol = 0;
my $show = 0;
my $forceFilename = "";
my $writeback = -1;
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
   'write:s'         => \$writeback,
   'WriteMemDump:s'  => \$MemDump,
   'skipSequenceMemDump' => \$skipSequenceMemDump,
   # Hiden Option(s)
   'X_show_internals'  => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Not enough arguments\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'ForceFilename\' option selected but no value set\n$usage")   if (($opt{'ForceFilename'}) && (MMisc::is_blank($forceFilename)));

if (($writeback != -1) && ($writeback ne "")) {
  # Check the directory
  my ($err) = MMisc::check_dir_w($writeback);
  MMisc::error_quit("Provided \'write\' option directory ($writeback): $err")
    if (! MMisc::is_blank($err));
  $writeback .= "/" if ($writeback !~ m%\/$%); # Add a trailing slash
}

if (defined $MemDump) {
  MMisc::error_quit("\'WriteMemDump\' can only be used in conjunction with \'write\'")
    if ($writeback == -1);
  $MemDump = $ok_md[0]
    if (MMisc::is_blank($MemDump));
  MMisc::error_quit("Unknown \'WriteMemDump\' mode ($MemDump), authorized: " . join(" ", @ok_md))
    if (! grep(m%^$MemDump$%, @ok_md));
}

MMisc::error_quit("\'skipSequenceMemDump\' can only be used if \'MemDump\' is selected")
if (($skipSequenceMemDump) && (! defined $MemDump));
  
##############################
# Main processing
my $ntodo = scalar @ARGV;
my $ndone = 0;
foreach my $tmp (@ARGV) {
  my ($err, $fname, $fsshift, $idadd, @boxmod) = 
    AVSS09ViperFile::extract_transformations($tmp);
  MMisc::error_quit("While processing filename ($tmp): $err")
      if (! MMisc::is_blank($err));

  my ($ok, $object) = &load_file($isgtf, $fname);
  next if (! $ok);

  if ($show) {
    print "** [Before mods]\n";
    print $object->_display_all();
  }

  # Do the transformations here
  my $mods = $object->Transformation_Helper($forceFilename, $fsshift, $idadd, @boxmod);
  MMisc::error_quit("Problem during \"transformations\": " . $object->get_errormsg())
      if ($object->error());

  if ($mods && $show) {
    print "** [After Mods]\n";
    print $object->_display_all();
  }

  if ($writeback != -1) {
    my ($txt) = $object->reformat_xml($isgtf);
    MMisc::error_quit("While trying to \'write\' (" . $object->get_errormsg() . ")")
      if ($object->error());
    my $lfname = "";
    if ($writeback ne "") {
      my $tmp2 = $fname;
      $tmp2 =~ s%^.+\/([^\/]+)$%$1%;
      $lfname = "$writeback$tmp2";
    } 
    MMisc::error_quit("Problem while trying to \'write\'")
      if (! MMisc::writeTo($lfname, "", 1, 0, $txt, "", "** XML re-Representation:\n"));

    if (defined $MemDump) {
      $object->write_MemDumps($lfname, $isgtf, $MemDump, $skipSequenceMemDump);
      MMisc::error_quit("Problem while trying to perform \'MemDump\'")
          if ($object->error());
    }
  }

  $ndone++;
}

print("All files processed (Validated: $ndone | Total: $ntodo)\n");

MMisc::error_quit("Not all files processed succesfuly") if ($ndone != $ntodo);
MMisc::ok_quit("\nDone\n");

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

Usage: $0 [--help] [--version] [--gtf] [--xmllint location] [--CLEARxsd location] [--frameTol framenbr] [--write [directory] [--WriteMemDump [mode] [--skipSequenceMemDump]] [--ForceFilename file] viper_source_file.xml[transformations] [viper_source_file.xml[transformations] [...]]

Will perform a semantic validation of the AVSS09 Viper XML file(s) provided.

 Where:
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan
  --ForceFilename  Specify that all files loaded refers to the same 'sourcefile' file
  --write         Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)
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
EOF
;

  return $tmp;
}
