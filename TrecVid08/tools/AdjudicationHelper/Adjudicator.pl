#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# ViPER Converter
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "ViPER Converter" is an experimental system.
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

my $versionid = "ViPER Converter Version: $version";

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
  $f4deplv = $ENV{$f4depl} || "../../../common/lib"; # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08HelperFunctions (part of this tool)
unless (eval "use TrecVid08HelperFunctions; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08HelperFunctions\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08EventList (part of this tool)
unless (eval "use TrecVid08EventList; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08EventList\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08Observation (part of this tool)
unless (eval "use TrecVid08Observation; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08Observation\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# AdjudicationViPERfile (part of this tool)
unless (eval "use AdjudicationViPERfile; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"AdjudicationViPERfile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add
    (
     "\"Getopt::Long\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
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
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $fps = undef;
my $odir = "";
my $akey = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                    T      a  d f h    m        v x   #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'fps=s'           => \$fps,
   'dir=s'           => \$odir,
   'annot_key=s'     => \$akey,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);
MMisc::error_quit("Need at least 1 file arguments to work\n$usage\n") 
  if (scalar @ARGV < 1);

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

MMisc::error_quit("\'fps\' must be set to continue")
  if (! defined $fps);
MMisc::error_quit("\'annot_key\' must be set to continue")
  if (MMisc::is_blank($akey));

##########

my $err = MMisc::check_dir_w($odir);
MMisc::error_quit("Problem with \'outdir\': $err")
  if (! MMisc::is_blank($err));


##########
# Main processing
my $stepc = 1;

########## Assimilating SYS files
print "\n\n***** STEP ", $stepc++, ": Assimilating SYS files\n";

my $isgtf = 0; # We only work with SYS files !

my $el  = undef;
my $sffn = "";
my $numframes = 0;
foreach my $ifile (@ARGV) {
  $err = MMisc::check_file_r($ifile);
  MMisc::error_quit("Problem with \'xmlfile\': $err")
      if (! MMisc::is_blank($err));
  
  print "** Loading Viper File: $ifile\n";
  my ($retstatus, $vf, $msg) = 
    TrecVid08HelperFunctions::load_ViperFile
        ($isgtf, $ifile, $fps, $xmllint, $xsdpath);
  MMisc::error_quit("File ($ifile) does not validate: $msg")
      if (! $retstatus);

  print " -> File validates\n";
  #print "**MemDump: ", MMisc::get_sorted_MemDump($vf), "\n";

  my $tsffn = $vf->get_sourcefile_filename();
  MMisc::error_quit("Could not get the sourcefile filename: " . $vf->get_errormsg() )
      if ($vf->error());
  MMisc::error_quit("Only one \'sourcefile filanme\' authorized for this work")
      if ((! MMisc::is_blank($sffn)) && ($sffn ne $tsffn));
  $sffn = $tsffn;

  my $tnf = $vf->get_numframes_value();
  MMisc::error_quit("Could not get the numframes: " . $vf->get_errormsg() )
      if ($vf->error());
  MMisc::error_quit("\'numframes\' differ from previous one ? ($tnf vs $numframes)")
      if (($numframes != 0) && ($ numframes != $tnf));
  $numframes = $tnf;
  
  print " -> Converting to an EventList\n";
  if (! defined $el) {
    $el = new TrecVid08EventList();
    MMisc::error_quit("Problem creating the EventList :" . $el->get_errormsg())
        if ($el->error());
  }
  my ($terr, $tobs, $added, $rejected) = 
    TrecVid08HelperFunctions::add_ViperFileObservations2EventList($vf, $el, 1);
  MMisc::error_quit("Problem adding ViperFile Observations to EventList: $terr")
      if (! MMisc::is_blank($terr));
  print "   -> Added: $tobs Observations ($added Added / $rejected Rejected)\n";
}

########## Adding observations to AdjudicationViPERfile
print "\n\n***** STEP ", $stepc++, ": Adding observations to AdjudicationViPERfile\n";

my $avf = new AdjudicationViPERfile();
$avf->set_annot_key($akey);
$avf->set_sffn($sffn);
$avf->set_numframes($numframes);
MMisc::error_quit("Problem creating the Adjudication ViPER file: " . $avf->get_errormsg())
  if ($avf->error());

my @evl = $el->get_events_list($sffn);
MMisc::error_quit("Problem obtaining the Events list: " . $el->get_errormsg())
  if ($el->error());
foreach my $event (@evl) {
  my @ol = $el->get_Observations_list($sffn, $event);
  MMisc::error_quit("Problem obtaining the Events Observations: " . $el->get_errormsg())
      if ($el->error());
  MMisc::error_quit("Problem adjusting the Adjudication ViPER file for event ($event): " . $avf->get_errormsg())
      if ($avf->error());
  
  print "* Event: $event | Observations: ", scalar(@ol), "\n";
  foreach my $obs (@ol) {
    $avf->add_tv08obs($obs);
    MMisc::error_quit("Problem adding Observation to AVF: " . $avf->get_errormsg())
        if ($avf->error());
  }
  
  my $fname = (! MMisc::is_blank($odir)) ? MMisc::concat_dir_file_ext($odir, "Adjudication-$event", "xml") : "";
  my $txt = $avf->get_xml($event);
  MMisc::error_quit("Problem obtaining the XML representation: " . $avf->get_errormsg())
      if ($avf->error());

  MMisc::error_quit("Problem while trying to write")
      if (! MMisc::writeTo($fname, "", 1, 0, $txt, "", "** XML re-Representation:\n"));
}


MMisc::ok_quit("OK SO FAR -- MORE TODO\n");


MMisc::ok_quit("Done\n");

########## END

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--TrecVid08xsd location] [--dir dir] --annot_key key --fps fps file.xml [file.xml[...]]

Will perform a semantic validation of the ViPER XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --dir           Specify the output path for special ViPER files (stdout otherwise)
  --annot_key     Specify the annotator key used in the files

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'TrecVid08.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will discard any xml comment(s).
- List of recognized events: $ro
- 'TrecVid08xsd' files are: $xsdfiles
EOF
    ;

    return $tmp;
}
