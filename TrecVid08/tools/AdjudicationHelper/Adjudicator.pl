#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# Adjudicator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Adjudicator" is an experimental system.
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

my $versionid = "Adjudicator Version: $version";

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

# ViperFramespan (part of this tool)
unless (eval "use ViperFramespan; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"ViperFramespan\" is not available in your Perl installation. ", $partofthistool, $pe);
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
my $se_UnRef  = $dummy->get_UnmappedRef_subeventkey();
my $se_UnSys  = $dummy->get_UnmappedSys_subeventkey();
# We will use the '$dummy' to do checks before processing files

########################################
# Options processing

my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $margind = 75;
my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $fps = undef;
my $odir = "";
my $akey = "";
my $doglobal = 0;
my $margin = $margind;
my $info_path = "";
my $info_g = "";
my $lgwf = "";
my $jpeg_path = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:       G I  L       T      a  d f hij        s  v x   #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'fps=s'           => \$fps,
   'dir=s'           => \$odir,
   'annot_key=s'     => \$akey,
   'Global'          => \$doglobal,
   'segmentation_margin=i' => \$margin,
   'info_path=s'     => \$info_path,
   'InfoGenerator=s' => \$info_g,
   'LGW=s'           => \$lgwf,
   'jpeg_path=s'     => \$jpeg_path,
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

if (! MMisc::is_blank($odir)) {
  my $err = MMisc::check_dir_w($odir);
  MMisc::error_quit("Problem with \'dir\' ($odir): $err")
    if (! MMisc::is_blank($err));
}

MMisc::error_quit("\'segmentation_margin\' must be at least 1")
  if ($margin < 1);

MMisc::error_quit("\'info_path\' can only be used if \'InfoGenerator\' is used")
  if ((MMisc::is_blank($info_g)) && (! MMisc::is_blank($info_path)));
MMisc::error_quit("\'jpeg_path\' can only be used if \'InfoGenerator\' is used")
  if ((MMisc::is_blank($info_g)) && (! MMisc::is_blank($jpeg_path)));
MMisc::error_quit("\'LGW\' can only be used if \'InfoGenerator\' is used")
  if ((MMisc::is_blank($info_g)) && (! MMisc::is_blank($lgwf)));
MMisc::error_quit("\'LGW\' must be set when \'InfoGenerator\' is used")
  if ((! MMisc::is_blank($info_g)) && (MMisc::is_blank($lgwf)));
MMisc::error_quit("\'dir\' must be set when \'InfoGenerator\' is used")
  if ((! MMisc::is_blank($info_g)) && (MMisc::is_blank($odir)));
&die_check_lgwf($lgwf);
if (! MMisc::is_blank($info_path)) {
  $info_path =~ s%\/$%%;
  $info_path .= "/";
}
if (! MMisc::is_blank($jpeg_path)) {
  $jpeg_path =~ s%\/$%%;
  $jpeg_path .= "/";
}

##########
# Main processing

my $log_add  = "log";
my $info_add = "info";

my $stepc = 1;

########## Assimilating SYS files
print "\n\n***** STEP ", $stepc++, ": Assimilating SYS files\n";

my $isgtf = 0; # We only work with SYS files !

my $el= undef;
my %numframes = ();

foreach my $ifile (@ARGV) {
  my $err = MMisc::check_file_r($ifile);
  MMisc::error_quit("Problem with \'xmlfile\': $err")
    if (! MMisc::is_blank($err));
  
  print "** Loading Viper File: $ifile\n";
  my ($retstatus, $vf, $msg) = 
    TrecVid08HelperFunctions::load_ViperFile
    ($isgtf, $ifile, $fps, $xmllint, $xsdpath);
  MMisc::error_quit("File ($ifile) does not validate: $msg")
    if (! $retstatus);
  print " -> File validates\n";
  
  my $sffn = $vf->get_sourcefile_filename();
  MMisc::error_quit("Could not get the sourcefile filename: " . $vf->get_errormsg() )
    if ($vf->error());
  print " -> Sourcefile filename: $sffn\n";

  my $tnf = $vf->get_numframes_value();
  MMisc::error_quit("Could not get the numframes: " . $vf->get_errormsg() )
    if ($vf->error());
  MMisc::error_quit("\'numframes\' differ from previous one ? ($tnf vs " . $numframes{$sffn} . ")")
    if ((exists $numframes{$sffn}) && ($numframes{$sffn} != $tnf));
  $numframes{$sffn} = $tnf;
  
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
print "\n** Seen sourcefile filenames:\n - ", join("\n - ", keys %numframes), "\n";

########## Segmented Adjudication
print "\n\n***** STEP ", $stepc++, ": Segmented Adjudication\n";

my $cnumframes = 0;
my @ev_sffn = $el->get_filenames_list();
MMisc::error_quit("Problem obtaining the EventList sourcefile filename list: " . $el->get_errormsg())
  if ($el->error());
foreach my $sffn (@ev_sffn) {
  MMisc::error_quit("\'numframes\' for selected \'sffn\' does not exist, aborting")
    if (! exists $numframes{$sffn});
  $cnumframes = $numframes{$sffn};
  my @evl = $el->get_events_list($sffn);
  MMisc::error_quit("Problem obtaining the Events list: " . $el->get_errormsg())
    if ($el->error());
  foreach my $event (@evl) {
    my @ol = $el->get_Observations_list($sffn, $event);
    MMisc::error_quit("Problem obtaining the Event Observations: " . $el->get_errormsg())
      if ($el->error());
    
    print "* SFFN: $sffn | Event: $event | Observations: ", scalar(@ol), "\n";
    &write_avf($sffn, $event, undef, @ol) if ($doglobal);
    
    print " -> No Segmentation possible: No \'$se_UnSys\' observations\n"
      if (! &has_UnSys(@ol));

    while (&has_UnSys(@ol)) {
      my $obs = &shift_next_UnSys(\@ol);
      next if (! defined $obs);
      
      my ($fs_fs, @in) = &compute_overlaps($obs, \@ol, $margin);
      
      &write_avf($sffn, $event, $fs_fs, @in);
    }
  }
}

MMisc::ok_quit("Done\n");

########## END

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

##########

sub die_get_subeventtype {
  my ($obs) = shift @_;

  my $est = $obs->get_eventsubtype();
  MMisc::error_quit("Problem obtaining the Observation subtype: " . $obs->get_errormsg())
    if ($obs->error());

  MMisc::error_quit("Found Observation subtype ($est) is not authorized")
    if (($est ne $se_UnRef) && ($est ne $se_UnSys));

  return($est);
}

#####

sub has_UnSys {
  my @ol = @_;

  return(0) if (scalar @ol == 0);

  foreach my $obs (@ol) {
    my $set = &die_get_subeventtype($obs);
    return(1) if ($set eq $se_UnSys);
  }

  return(0);
}

#####

sub shift_next_UnSys {
  my $rol = shift @_;
  
  for (my $i = 0; $i < scalar @$rol; $i++) {
    my $set = die_get_subeventtype($$rol[$i]);
    return(splice(@$rol, $i, 1)) if ($set eq $se_UnSys);
  }

  return(undef);
}

##########

sub die_get_fs_beg_end {
  my ($fs_fs) = @_;

  my ($beg, $end) = $fs_fs->get_beg_end_fs();
 MMisc::error_quit("Error obtaining Framespan's Beg/End: " . $fs_fs->get_errormsg())
   if ($fs_fs->error());

  return($beg, $end);
}

#####

sub die_get_obs_fs_beg_end {
  my ($obs) = @_;

  my $fs_fs = $obs->get_framespan();
  MMisc::error_quit("Error obtaining Observation's framespan: " . $obs->get_errormsg())
    if ($obs->error());

  return(&die_get_fs_beg_end($fs_fs));
}

#####

sub create_fs_from_beg_end {
  my ($beg, $end, $addmargin) = @_;

  $beg -= $addmargin;
  $end += $addmargin;

  $beg = 1 
    if ($beg < 1);
  $end = $cnumframes - 1 
    if ($end >= $cnumframes);

  my $fs_fs = new ViperFramespan();
  $fs_fs->set_value_beg_end($beg, $end);
  MMisc::error_quit("Problem creating ViperFramespan: " . $fs_fs->get_errormsg())
    if ($fs_fs->error());
  
  return($fs_fs);
}

#####

sub get_obs_extended_framespan {
  my ($addmargin, @ol) = @_;

  my @vals = ();
  foreach my $obs (@ol) {
    my @tmp = &die_get_obs_fs_beg_end($obs);
    push @vals, @tmp;
  }

  my ($min, $max) = MMisc::min_max(@vals);
  
  return(&create_fs_from_beg_end($min, $max, $addmargin));
}

#####

sub die_do_fs_obs_ov {
  my ($fs_fs, $obs) = @_;

  my $fs_ov = $obs->get_framespan_overlap_from_fs($fs_fs);
  MMisc::error_quit("Problem obtaining observation framespan and framespan overlap: " . $obs->get_errormsg())
    if ($obs->error());

  return(1) if (defined $fs_ov);

  return(0);
}

#####

sub find_shift_overlapping_obs {
  my ($fs_fs, $rol) = @_;

  my @ol = @$rol;
  my @left = ();
  my @ovobs = ();
  foreach my $obs (@ol) {
    if (&die_do_fs_obs_ov($fs_fs, $obs)) {
      push @ovobs, $obs;
    } else {
      push @left, $obs;
    }
  }

  @$rol = @left;

  return(@ovobs);
}

#####

sub compute_overlaps {
  my ($obs, $rol, $margin) = @_;

  my @in = ();
  push @in, $obs;

  my $fs_fs = undef;
  my $sz = 0;
  do {
    $sz = scalar @in;
    $fs_fs = &get_obs_extended_framespan($margin, @in);
    push @in, &find_shift_overlapping_obs($fs_fs, $rol);
  } until (scalar @in == $sz);

  return($fs_fs, @in);
}

##########

sub write_avf {
  my ($sffn, $event, $fs_fs, @ol) = @_;

  my $nf  = $numframes{$sffn};
  my $osf = 1;
  my $beg = 1;
  my $end = $nf;

  if (defined $fs_fs) {
    ($beg, $end) = &die_get_fs_beg_end($fs_fs);
    $nf = $end - $beg + 1;
    $osf = $beg;
  }

  my $avf = new AdjudicationViPERfile();
  $avf->set_annot_key($akey);
  $avf->set_sffn($sffn);
  $avf->set_numframes($nf);
  $avf->set_origstartframe($osf);
  MMisc::error_quit("Problem creating the Adjudication ViPER file: " . $avf->get_errormsg())
    if ($avf->error());

  foreach my $obs (@ol) {
    $avf->add_tv08obs($obs);
    MMisc::error_quit("Problem adding Observation to AVF: " . $avf->get_errormsg())
      if ($avf->error());
  }

  my $agreeadd = "Agree_" . sprintf("%02d", $avf->get_maxAgree());
  MMisc::error_quit("Problem obtaining AVF's max Agree text: " . $avf->get_errormsg())
    if ($avf->error());

  my $spfnadd = (! defined $fs_fs) ? "-Global" : "-$agreeadd";
  my $fname_b = "$sffn-$event-" . sprintf("%06d", $beg) . "_" . sprintf("%06d", $end) . "$spfnadd";


  my $lsffn = $sffn;
  if (! MMisc::is_blank($info_g)) {
    my $infofile_b = MMisc::concat_dir_file_ext("", $fname_b, $info_add);
    my $infofile = MMisc::concat_dir_file_ext($odir, $fname_b, $info_add);
    my $log = MMisc::concat_dir_file_ext($odir, "InfoGenerator_Run", $log_add);
    my $command = "$info_g $infofile $lgwf $beg $end";
    $command .= " $jpeg_path" if (! MMisc::is_blank($jpeg_path));

    &die_syscall_logfile($log, "InfoGenerator run", $command);

    $lsffn = "$info_path$infofile_b";
  }
 
  if ($lsffn ne $sffn) {
    $avf->set_sffn($lsffn);
    MMisc::error_quit("Problem changing the sffn ($sffn -> $lsffn): " . $avf->get_errormsg())
      if ($avf->error());
  } 

  my $fname = "";
  $fname = MMisc::concat_dir_file_ext($odir, $fname_b, "xml")
    if (! MMisc::is_blank($odir));

  my $txt = $avf->get_xml($event);
  MMisc::error_quit("Problem obtaining the XML representation: " . $avf->get_errormsg())
    if ($avf->error());
    
  MMisc::error_quit("Problem while trying to write")
    if (! MMisc::writeTo($fname, "", 1, 0, $txt, "", "** XML Representation:\n"));
}

##########

sub die_check_lgwf {
  my $lgwf = shift @_;

  return() if (MMisc::is_blank($lgwf));

  MMisc::error_quit("Problem with LGW file: Does not start with LGW")
      unless ($lgwf =~ s%^LGW_%%);

  MMisc::error_quit("Problem with LGW file: Does not contain an 8 digits date")
      unless ($lgwf =~ s%^\d{8}_%%);

  MMisc::error_quit("Problem with LGW file: Does not contain a set id")
      unless ($lgwf =~ s%^E\d_%%);

  MMisc::error_quit("Problem with LGW file: Does not contain a camera id")
      unless ($lgwf =~ s%^CAM\d$%%);
}

##########

sub die_syscall_logfile {
  my ($file, $txt, @command) = @_;

  my ($ok, $rtxt, $stdout, $stderr, $retcode) =
    MMisc::write_syscall_logfile($file, @command);
  MMisc::error_quit("Problem when running $txt\nSTDOUT:$stdout\nSTDERR:\n$stderr\n")
    if ($retcode != 0);

  print "    (Ran \"$txt\", see log at: $file)\n";
}

############################################################

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--TrecVid08xsd location] [--dir dir] [--Global] [--segmentation_margin value] [--InfoGenerator tool --LGW lwg_file [--info_path path]] --annot_key key --fps fps file.xml [file.xml[...]]

Will perform a semantic validation of the ViPER XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --dir           Specify the output path for special ViPER files (stdout otherwise)
  --Global        Generate a global Adjudication File in addition to the segmented ones
  --segmentation_margin  Add +/- value frames to each observation when computing its possible candidates for overlap (default: $margind)
  --InfoGenerator Specify the '.info' generator tool to use (arguments to this tool must be in the following order: info_outfile LGW_info start_frame end_frame [jpeg_path])
  --LGW           Specify the LGW_info passed to the '.info' generator
  --info_path     Path to the final '.info' file (added in the Viper file)
  --jpeg_path     Path to the JPEG files inside the '.info' file
  --annot_key     Specify the annotator key used in the files
  --fps           Specify the fps

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
