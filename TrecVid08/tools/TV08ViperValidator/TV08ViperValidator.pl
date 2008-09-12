#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 ViPER XML Validator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 ViPER XML Validator" is an experimental system.
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

my $versionid = "TrecVid08 ViPER XML Validator Version: $version";

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

# TrecVid08Observation (part of this tool)
unless (eval "use TrecVid08Observation; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08Observation\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08HelperFunctions (part of this tool)
unless (eval "use TrecVid08HelperFunctions; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08HelperFunctions\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08ECF (part of this tool)
unless (eval "use TrecVid08ECF; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08ECF\" is not available in your Perl installation. ", $partofthistool, $pe);
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

# Get some values from TrecVid08ECF
my $ecfobj = new TrecVid08ECF();
my @ecf_xsdfilesl = $ecfobj->get_required_xsd_files_list();

my @ok_csv_keys = TrecVid08Observation::get_ok_csv_keys();
my @required_csv_keys = TrecVid08Observation::get_required_csv_keys();

########################################
# Options processing

my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $mancmd = "perldoc -F $0";
my $ok_chars = 'a-zA-Z0-9/.~_-';
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my @ok_remove = ("TrackingComment", "XtraAttributes", "AllEvents", "ALL"); # Order is important ("ALL" must always be last)
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $writeback = -1;
my $xmlbasefile = -1;
my @asked_events = ();
my $autolt = 0;
my $show = 0;
my $remse = 0;
my $crop = "";
my $fps = undef;
my $changetype = undef;
my $MemDump = undef;
my $forceFilename = "";
my $dosummary = undef;
my $ecffile = "";
my @xtra = ();
my $xtra_tc = 0;
my @toremove = ();
my @docsv = ();
my $inscsv = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used: A CD F           R T  WX  a cdefghi   lm  p r   vwx    #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   "XMLbase:s"       => \$xmlbasefile,
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => \$isgtf,
   'write:s'         => \$writeback,
   'limitto=s'       => \@asked_events,
   'pruneEvents'     => \$autolt,
   'removeSubEventtypes' => \$remse,
   'crop=s'          => \$crop,
   'fps=s'           => \$fps,
   'ChangeType:s'    => \$changetype,
   'WriteMemDump:s'  => \$MemDump,
   'ForceFilename=s' => \$forceFilename,
   'displaySummary=i' => \$dosummary,
   'ecf=s'           => \$ecffile,
   'addXtraAttribute=s' => \@xtra,
   'AddXtraTrackingComment' => \$xtra_tc,
   'Remove=s'        => \@toremove,
   'DumpCSV=s'       => \@docsv,
   'insertCSV=s'     => \$inscsv,
   # Hiden Option(s)
   'show_internals'  => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

if (scalar @asked_events == 0) {
  @asked_events = @ok_events;
} else {
  MMisc::error_quit("Can not use \'limitto\' in conjunction with \'pruneEvents\'")
    if ($autolt);
  @asked_events = $dummy->validate_events_list(@asked_events);
  MMisc::error_quit("While checking \'limitto\' events list (" . $dummy->get_errormsg() .")")
    if ($dummy->error());
}

if ($xmlbasefile != -1) {
  my $txt = $dummy->get_base_xml(@asked_events);
  MMisc::error_quit("While trying to obtain the base XML file (" . $dummy->get_errormsg() . ")")
    if ($dummy->error());

  MMisc::writeTo($xmlbasefile, "", 0, 0, $txt);

  MMisc::ok_quit("");
}

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

if (($writeback != -1) && ($writeback ne "")) {
  # Check the directory
  MMisc::error_quit("Provided \'write\' option directory ($writeback) does not exist")
    if (! -e $writeback);
  MMisc::error_quit("Provided \'write\' option ($writeback) is not a directoru")
    if (! -d $writeback);
  MMisc::error_quit("Provided \'write\' option directory ($writeback) is not writable")
    if (! -w $writeback);
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

if ($opt{'ForceFilename'}) {
  MMisc::error_quit("\'ForceFilename\' option selected but no value set\n$usage")
    if ($forceFilename eq "");
  MMisc::error_quit("\'ForceFilename\' option can only be used in conjunction with \'write\'")
    if ($writeback == -1);
}

my ($crop_beg, $crop_end) = (0, 0);
if (! MMisc::is_blank($crop)) {
  MMisc::error_quit("\'crop\' can only be used in conjunction with \'write\'") 
    if ($writeback == -1);

  my @rest = split(m%\:%, $crop);
  MMisc::error_quit("Too many parameters to crop, expected \'beg:end\'")
    if (scalar @rest > 2);
  MMisc::error_quit("Not enough parameters to crop, expected \'beg:end\'") 
    if (scalar @rest < 2);

  ($crop_beg, $crop_end) = @rest;
  MMisc::error_quit("\'crop\' beg must be positive and be at least 1") 
    if ($crop_beg < 1);
  MMisc::error_quit("\'crop\' beg must be less than the end value") 
    if ($crop_beg > $crop_end);

  MMisc::error_quit("\'fps\' must set in order to do any \'crop\'")
    if (! defined $fps);
}

if (defined $dosummary) {
  MMisc::error_quit("\'displaySummary\'\'s \'level\' authorized values are 1 to 6")
    if (($dosummary < 1) || ($dosummary > 6));
} else {
  $dosummary = 0;
}

MMisc::error_quit("\'AddXtraTrackingComment\' can only be used with \'write\'")
  if (($xtra_tc) && ($writeback == -1));

my %hxtra = ();
if (scalar @xtra > 0) {
  MMisc::error_quit("\'addXtraAttribute\' can only be used with \'write\'")
    if ($writeback == -1);

  foreach my $val (@xtra) {
    if ($val =~ m%^([$ok_chars]+)\:([$ok_chars]+)$%) {
      $hxtra{$1} = $2;
    } else {
      MMisc::error_quit("\'addXtraAttribute\' entry ($val) is not composed of \'name\:value\' composed of the following authorized characters \'$ok_chars\' , aborting");
    }
  }
}

if (scalar @toremove > 0) {
  my @tmp = ();
  foreach my $e (@toremove) {
    push @tmp, split(m%\,%, $e);
  }
  @toremove = MMisc::make_array_of_unique_values(@tmp);
  my @tmp = ();
  foreach my $tor (@toremove) {
    push @tmp, $tor if (! grep(m%$tor$%, @ok_remove));
  }
  MMisc::error_quit("Unknown \'Remove\' value: " . join(" ", @tmp))
    if (scalar @tmp > 0);
  # Replace all by "ALL" if in
  my $tmpv = $ok_remove[-1];
  if (grep(m%^$tmpv$%, @toremove)) {
    @toremove = ();
    push @toremove, $tmpv;
  }
  # Replace "ALL" by every other value
  if (grep(m%^$tmpv$%, @toremove)) {
    @toremove = @ok_remove;
    # Remove the last value ("ALL")
    splice(@toremove, -1);
  }
}

if (scalar @docsv > 0) {
  MMisc::error_quit("Can not \'DumpCSV\' unless \'write\' is selected")
    if ($writeback == -1);
  my @tmp = ();
  foreach my $k (@docsv) {
    push @tmp, split(m%\,%, $k);
  }
  @docsv = @tmp;
  my $txt = TrecVid08Observation::CF_check_csv_keys(@docsv);
  MMisc::error_quit("Problem with \'DumpCSV\' keys: $txt")
    if (! MMisc::is_blank($txt));
}

MMisc::error_quit("Can not use \'insertCSV\' unless \'write\' is used")
  if (($writeback == -1) && (! MMisc::is_blank($inscsv)));

my $useECF = (MMisc::is_blank($ecffile)) ? 0 : 1;
MMisc::error_quit("\'fps\' must set in order to use \'ecf\'")
    if (($useECF) && (! defined $fps));

## Loading of the ECF file
if ($useECF) {
  print "\n* Loading the ECF file\n\n";
  my ($errmsg) = TrecVid08HelperFunctions::load_ECF($ecffile, $ecfobj, $xmllint, $xsdpath, $fps);
  MMisc::error_quit("Problem loading the ECF file: $errmsg")
    if (! MMisc::is_blank($errmsg));
}

##########
# Main processing
my $tmp = "";
my $ntodo = scalar @ARGV;
my $ndone = 0;
TrecVid08ViperFile::type_changer_init_randomseed($changetype) if (defined $changetype);
while ($tmp = shift @ARGV) {
  my ($ok, $object) = &load_file($isgtf, $tmp);
  next if (! $ok);

  my $mods = 0; # Those are modification that would influence
  # the Event Observation tracking ID which contains: File, Sourcefile,
  # Type, Event (type not list of), SubType, ID, Framespan, XtrAttributes

  # This is really if you are a debugger
  print("** (Pre) Memory Representation:\n", $object->_display_all()) if ($show);
  # Summary
  if ($dosummary > 3) {
    my $sumtxt = $object->get_summary($dosummary);
    MMisc::error_quit("Problem obtaining summary (" . $object->get_errormsg() . ")") if ($object->error());
    print "[Pre Modifications]\n$sumtxt";
  }

  # 'insertCSV'
  if (! MMisc::is_blank($inscsv)) {
    my $err = TrecVid08HelperFunctions::Add_CSVfile2VFobject($inscsv, $object);
    MMisc::error_quit("Problem while trying to \'insertCSV\': $err")
      if (! MMisc::is_blank($err));
  }

  # 'xtra' Tracking Comment
  if ($xtra_tc) {
    $object->set_xtra_Tracking_Comment(TrecVid08ViperFile::get_xtra_tc_original());
    MMisc::error_quit("Problem while adding \'xtra\' Tracking Comment to ViperFile (" . $object->get_errormsg() .")")
      if ($object->error());
  }

  # ForceFilename
  if ($forceFilename ne "") {
    $object->change_sourcefile_filename($forceFilename);
    MMisc::error_quit("Problem while changing the sourcefile filename (" . $object->get_errormsg() .")")
      if ($object->error());
    $mods++;
  }

  # ChangeType
  if (defined $changetype) {
    my $r = 0;
    if ($isgtf) {
      $r = $object->change_ref_to_sys();
    } else {
      $r = $object->change_sys_to_ref();
    }
    MMisc::error_quit("Could not change type of the file") if ($r == 0);
    MMisc::error_quit("Problem while changing the type of the file: " . $object->get_errormsg()) if ($object->error());
    $mods++;
  }

  # ECF work ?
  if ($useECF) {
    my ($lerr, $obj) =
      TrecVid08HelperFunctions::get_new_ViperFile_from_ViperFile_and_ECF($object, $ecfobj);
    MMisc::error_quit($lerr)
      if (! MMisc::is_blank($lerr));
    $object = $obj;
    $mods++;
  }
  MMisc::error_quit("Problem with ViperFile object")
    if (! defined $object);
  MMisc::error_quit("Problem with ViperFile object (" . $object->get_errormsg() . ")")
    if ($object->error());

  # Crop
  if (! MMisc::is_blank($crop)) {
    (my $err, $object) = TrecVid08HelperFunctions::ViperFile_crop($object, $crop_beg, $crop_end);
    MMisc::error_quit("While cropping: $err\n") if (! MMisc::is_blank($err));
    $mods++;
  }

  # Auto Limit 
  @asked_events = $object->list_used_full_events() 
    if ($autolt);

  # Duplicate the object in memory with only the selected types
  my $nvf = $object->clone_with_selected_events(@asked_events);
  MMisc::error_quit("Problem while \'clone\'-ing the ViperFile (" . $object->get_errormsg() . ")")
      if ($object->error());
  MMisc::error_quit("Problem while \'clone\'-ing the ViperFile")
    if (! defined $nvf);

  # Remove subtype
  if ($remse) {
    $nvf->unset_force_subtype();
    $mods++;
  }

  # Add Xtra Attribute(s)
  if (scalar @xtra > 0) {
    foreach my $key (keys %hxtra) {
      $nvf->set_xtra_attribute($key, $hxtra{$key});
      MMisc::error_quit("Problem while adding \'xtra\' attribute to ViperFile (" . $nvf->get_errormsg() .")")
        if ($nvf->error());
    }
    $mods++;
  }

  # Remove
  if (scalar @toremove > 0) {
    my $tmpv = $ok_remove[0]; # TrackingComment
    if (grep(m%^$tmpv$%, @toremove)) {
      $nvf->unset_xtra_Tracking_Comment();
      MMisc::error_quit("Problem removing the Xtra Tracking Comment (" . $nvf->get_errormsg() .")")
        if ($nvf->error());
    }

    my $tmpv = $ok_remove[1]; # XtraAttributes
    if (grep(m%^$tmpv$%, @toremove)) {
      $nvf->unset_all_xtra_attributes();
      MMisc::error_quit("Problem removing the Xtra Tracking Comment (" . $nvf->get_errormsg() .")")
        if ($nvf->error());
      $mods++;
    }

    my $tmpv = $ok_remove[2]; # AllEvents
    if (grep(m%^$tmpv$%, @toremove)) {
      my $ovf = $nvf->clone_with_no_events();
      MMisc::error_quit("Problem removing all events (" . $nvf->get_errormsg() .")")
        if ($nvf->error());
      $nvf = $ovf;
      $mods++;
    }

  }

  # 'xtra' Tracking Comment
  if (($xtra_tc) && ($mods > 0)) {
    $nvf->set_xtra_Tracking_Comment(TrecVid08ViperFile::get_xtra_tc_modsadd());
    MMisc::error_quit("Problem while adding \'xtra\' Tracking Comment to ViperFile (" . $nvf->get_errormsg() .")")
      if ($nvf->error());
  }

  # Writeback & MemDump
  if ($writeback != -1) {
    # Re-adapt @asked_events for each object if automatic limitto is set
    
    my $txt = $nvf->reformat_xml(@asked_events);
    MMisc::error_quit("While trying to \'write\' (" . $nvf->get_errormsg() . ")")
      if ($nvf->error());
    
    my $fname = "";
    
    if ($writeback ne "") {
      my ($err, $td, $tf, $te) = MMisc::split_dir_file_ext($tmp);
      $fname = MMisc::concat_dir_file_ext($writeback, $tf, $te);
    }
    MMisc::error_quit("Problem while trying to \'write\'")
      if (! MMisc::writeTo($fname, "", 1, 0, $txt, "", "** XML re-Representation:\n"));
    
    if (defined $MemDump) {
      MMisc::error_quit("Problem writing the \'Memory Dump\' representation of the ViperFile object")
        if (! TrecVid08HelperFunctions::save_ViperFile_MemDump($fname, $nvf, $MemDump, 1, 1));
    }
  }
  
  if (scalar @docsv > 0) {
    my $fname = "";

    if ($writeback ne "") {
      my ($err, $td, $tf, $te) = MMisc::split_dir_file_ext($tmp);
      $fname = MMisc::concat_dir_file_ext($writeback, $tf, "csv");
    }

    my ($err, $txt) = TrecVid08HelperFunctions::ViperFile2CSVtxt($nvf, @docsv);
    MMisc::error_quit("Problem while trying to generate the CSV text: $err")
      if (! MMisc::is_blank($err));
    MMisc::error_quit("Problem while trying to \'DumpCSV\'")
      if (! MMisc::writeTo($fname, "", 1, 0, $txt, "", "** CSV representation:\n"));
  }

  # Summary
  if ($dosummary) {
    my $sumtxt = $nvf->get_summary($dosummary);
    MMisc::error_quit("Problem obtaining summary (" . $nvf->get_errormsg() . ")") if ($nvf->error());
    print "[Post Modifications]\n" if ($dosummary > 3);
    print $sumtxt;
  }

  # This is really if you are a debugger
  print("** (Post) Memory Representation:\n", $nvf->_display_all()) if ($show);
  
  $ndone++;
}
print "All files processed (Validated: $ndone | Total: $ntodo)\n\n";

MMisc::error_exit()
  if ($ndone != $ntodo);

MMisc::ok_exit();

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)) { 
    &valok($fname, "[ERROR] $_");
  }
}

##########

sub load_file {
  my ($isgtf, $tmp) = @_;

  my ($retstatus, $object, $msg) = 
    TrecVid08HelperFunctions::load_ViperFile($isgtf, $tmp, 
					     $fps, $xmllint, $xsdpath);

  if ($retstatus) { # OK return
    &valok($tmp, "validates");
  } else {
    &valerr($tmp, $msg);
  }

  return($retstatus, $object);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################ Manual

=pod

=head1 NAME

TV08ViperValidator - TrecVid08 ViPER XML Validator

=head1 SYNOPSIS

B<TV08ViperValidator> S<[ B<--help> | B<--man> | B<--version> ]>
  S<[B<--xmllint> I<location>] [B<--TrecVid08xsd> I<location>]>
  S<[B<--XMLbase> [I<file]>] [B<--gtf>]>
  S<[B<--limitto> I<event1>[,I<event2>[I<...>]]]>
  S<[[B<--write> [I<directory>]]>
  S<[B<--ChangeType> [I<randomseed:find_value>]]>
  S<[B<--crop> I<beg:end>] [B<--WriteMemDump> [I<mode>]]>
  S<[B<--ForceFilename> I<filename>] [B<--pruneEvents>]>
  S<[B<--removeSubEventtypes>]>
  S<[B<--addXtraAttribute> I<name:value>] [B<--AddXtraTrackingComment>]>
  S<[B<--Remove> I<type>]>
  S<[B<--DumpCSV> I<csvkeys>]  [B<--insertCSV> I<file.csv>]]>
  S<[B<--fps> I<fps>] [B<--ecf> I<ecffile>]>
  S<[B<--displaySummary> I<level>]>
  I<viper_source_file.xml> [I<viper_source_file.xml> [I<...>]]
  
=head1 DESCRIPTION

B<TV08ViperValidator> performs a syntactic and semantic validation of the ViPER XML file(s) provided on the command line. It can I<validate> reference files (see B<--gtf>) as well as system files. It can also rewrite validated files into another directory using the same filename as the original (see B<--write>), and only keep a few selected events in the output file (see B<--limitto>). To obtain a list of recognized events, see B<--help>.

=head1 PREREQUISITES

B<TV08ViperValidator> relies on some external software and files.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<TV08_XMLLINT> environment variable.

=item B<FILES>

The syntactic validation requires some XML schema files (full list can be obtained using the B<--help> option).
It is possible to specify their location using the B<--xsdpath> option or the B<TV08_XSDPATH> environment variable.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

B<TV08ViperValidator> relies on some internal and external Perl libraries to function.

Simply running the B<TV08ViperValidator> script should provide you with the list of missing libraries. 
The following environment variables should be set in order for Perl to use the B<F4DE> libraries:

=over

=item B<F4DE_BASE>

The main variable once you have installed the software, it should be sufficient to run this program.

=item B<F4DE_PERL_LIB>

Allows you to specify a different directory for the B<F4DE> libraries.

=item B<TV08_PERL_LIB>

Allows you to specify a different directory for the B<TrecVid08> libraries.

=back

=back

=head1 GENERAL NOTES

B<TV08ViperValidator> expect that the files can be validated using 'xmllint' against the TrecVid08 XSD file(s) (see B<--help> for files list).

B<TV08ViperValidator> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--addXtraAttribute> I<name:value>

Add to each I<Event> I<Observation> an extra attribute to I<write> to the XML file.
More than one B<-addXtraAttribute> command line option can be used to add multiple attributes.
Attributes wil be carried over when performing work on I<Observation>s.

=item B<--AddXtraTrackingComment>

Add to each I<Event> I<Observation> an extra attribute to I<write> to the XML file that will contain information about the I<File>, I<Sourcefile>, I<Type>, I<Event>, I<SubType>, I<ID>, I<Framespan> and I<XtraAttribute> names.

=item B<--ChangeType> [I<randomseed>[:I<find_value>]]

Convert a SYS to REF or a REF to SYS.
The I<randomseed> is useful if you want to reproduce the result in the future.
Be forewarned that it is possible to reproduce a same output if reusing the I<randomseed> value but the process and source files have to be the exact same too.
Also, when trying to reproduce a file, it is possible to ask the program to find the file's first random value (see the XML sourcefile comment) thanks to the I<find_value> argument.

=item B<--crop> beg:end

Will crop all input ViPER files to the specified range. Only valid when used with the 'write' option.
Note that cropping consists of trimming all seen events to the selected range and then shifting the file to start at 1 again.

=item B<--DumpCSV> I<csvkeys>

Will dump into a I<Comma Separated Value> (CSV) file every I<Event> I<Observation> listed in the source xml file(s) in a human readable form.
B<--fps> must be set to use this option.
Multiple B<DumpCSV> entries can be used or I<csvkeys> can be comma separated. 
The list of authorized and required I<csvkeys> can be obtained by using B<--help>.

=item B<--displaySummary> [I<level>]

Display a file information summary.
I<level> is a value from 1 to 6 which will show more information about the I<Event> seen.
Level 1 will just print the list of events seen (post all modifications applied to the file -- if any), level 2 will also print the number of events per event, and level 3 will add to the print the ID list of such events.
Level 4, 5, 6 are repeat of level 1, 2, 3 for pre-modifications comparisons.

=item B<--ecf> I<ecffile>

After validating the file, only keep Event Observation within the file that match the ECF information.

=item B<--ForceFilename> I<fname>

Replace the I<sourcefile>'s I<filename> value by  I<fname>.

=item B<--fps> I<fps>

Specify the default sample rate (in frames per second) of the ViPER files.

=item B<--gtf>

Specify that the file to validate is a Reference file (also known as a Ground Truth File)

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--insertCSV> I<file.csv>

Will insert into the output XML file, every I<Event> I<Observation> listed in the I<file.csv>.
B<--fps> must be set to use this option.
The list of authorized and required I<csvkeys> can be obtained by using B<--help>.

=item B<--limitto> I<event1>[,I<event2>[I<,...>]]

Used with B<--write> or B<--XMLbase>, only add the provided list of events to output files.
Note that B<TV08ViperValidator> will still check the entire ViPER file before it can limit itself to the selected list of events.
B<--limitto> can also use wildcards for sub-Event Types specification such as '*:Mapped' which will request all event types but only I<Mapped> subtype.
To note, if you request a subtype for a file that does not contain any, that subtype will be ignored, ie if you request I<ObjectGet:Mapped> when the file does not contain any subtype, you will get all I<ObjectGet>s.

=item B<--man>

Display this man page.

=item B<--pruneEvents>

For each validated event that is re-written, only add to this file's config section, events for which observations are seen

=item B<--Remove> I<type>

Remove information from output ViPER file.

Note that it removes data just before the file is rewritten to disk, and therefore data added with the such of B<--insertCSV> will be removed if I<AllEvents> is selected.

Removes one of the following:

=over 

=item I<TrackingComment>

removes any tracking comment.

=item I<XtraAttributes>

removes all Xtra Attributes.

=item I<AllEvents>

removes all seen event observations.

=item I<ALL> 

does all the previously listed removes.

=back

=item B<--removeSubEventtypes>

Only useful for specialized Scorer XML files containing subtypes information; option will remove those subtypes

=item B<--TrecVid08xsd> I<location>

Specify the default location of the required XSD files (use B<--help> to get the list of required files).
Can also be set using the B<TV08_XSDPATH> environment variable.

=item B<--version>

Display B<TV08ViperValidator> version information.

=item B<--write> [I<directory>]

Once validation has been completed for a given file, B<TV08ViperValidator> will write a new XML representation of this file to either the standard output (if I<directory> is not set), or will create a file with the same name as the input file in I<directory> (if specified).

=item B<--WriteMemDump> [I<mode>]

Write to disk a memory representation of the validated ViPER File.
This memory representation file can be used as the input of the Scorer, Merger and Validator tools.
The mode is the file representation to disk and its values and its default can be obtained using the B<--help> option.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<TV08_XMLLINT> environment variable.

=item B<--XMLbase> I<file>

Print a XML ViPER file with an empty I<data> section but a populated I<config> section, and exit.
It will write the text content to I<file> if provided.

=back

=head1 USAGE

=item B<TV08ViperValidator --XMLbase TrecVid08_Base.xml>

Will generate a valid TrecVid08 ViPER XML file with an empty I<data> section but with all the events in the I<config> section.

=item B<TV08ViperValidator --XMLbase TrecVid08_ObjectPut_Embrace_only.xml --limitto ObjectPut,Embrace>

Will generate a valid TrecVid08 ViPER XML file with an empty I<data> section but containing only the I<ObjectPut> and I<Embrace> events in its I<config> section.

=item B<TV08ViperValidator --xmllint /local/bin/xmllint --TrecVid08xsd /local/F4DE-CVS/data sys_test1.xml>

Will try to validate the I<system> file I<sys_test1.xml> using the I<xmllint> executable located at I</local/bin/xmllint> and the required XSD files found in the I</local/F4DE/data> directory.

=item B<TV08ViperValidator --gtf ref_test1.xml ref_test2.xml --write /tmp>

Will try to validate the I<reference> files I<ref_test1.xml> and I<ref_test2.xml> and will write into the I</tmp> directory, the files I</tmp/ref_test1.xml> and I</tmp/ref_test2.xml> if they both pass the validation step.

=item B<TV08ViperValidator sys_test1.xml sys_test2.xl --write /tmp --limitto Embrace>

Will try to validate the I<system> files I<sys_test1.xml> and I<sys_test2.xml>, and will write into the I</tmp> directory the files I</tmp/sys_test1.xml> and I</tmp/sys_test2.xml> containing only the I<Embrace> event (if they both pass the validation step).

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=cut

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $ecf_xsdf = join(" ", @ecf_xsdfilesl);
  my $wmd = join(" ", @ok_md);
  my $rem = join(" ", @ok_remove);
  my $ok_csvk = join(" ", @ok_csv_keys);
  my $rq_csvk = join(" ", @required_csv_keys);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --man | --version] [--xmllint location] [--TrecVid08xsd location] [--XMLbase [file]] [--gtf] [--limitto event1[,event2[...]]] [--write [directory] [--ChangeType [randomseed[:find_value]]] [--crop beg:end] [--WriteMemDump [mode]] [--ForceFilename filename] [--pruneEvents] [--removeSubEventtypes] [--addXtraAttributes name:value] [--AddXtrTrackingComment] [--Remove type] [--DumpCSV csvkeys] [--insertCSV file.csv]]  [--fps fps] [--ecf ecffile] [--displaySummary level] viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the ViPER XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --XMLbase       Print a ViPER file with an empty <data> section and a populated <config> section, and exit (to a file if one provided on the command line)
  --gtf           Specify that the file to validate is a Ground Truth File
  --limitto       Only care about provided list of events
  --write         Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)
  --ChangeType    Convert a SYS to REF or a REF to SYS.
  --crop          Will crop file content to only keep content that is found within the beg and end frames
  --WriteMemDump  Write a memory representation of validated ViPER Files that can be used by the Scorer and Merger tools. Two modes possible: $wmd (1st default)
  --ForceFilename Replace the 'sourcefile' file value
  --pruneEvents   Only keep in the new file's config section events for which observations are seen
  --removeSubEventtypes  Useful when working with specialized Scorer outputs to remove specialized sub types
  --addXtraAttribute  Add a new attribute to each event observation in file. Muliple \'--addXtraAttribute\' can be used.
  --AddXtraTrackingComment Add an xtra attribute designed to help understand from where an Event Observation came from when performing an operation on it
  --Remove        Remove from the ViPER file one of the following: $rem
  --DumpCSV       Dump a file containing the list of keys provided
  --insertCSV     Insert the csv file to a re-written XML file. Keys are the same as the one in DumpCSV
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --ecf           Specify the ECF file to load
  --displaySummary  Display a file information summary (level shows information about event type seen, and is a value from 1 to 6)

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'TrecVid08.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will discard any xml comment(s).
- List of recognized events: $ro
- 'TrecVid08xsd' files are: $xsdfiles (and if the 'ecf' option is used, also: $ecf_xsdf)
- Recognized CSV keys: $ok_csvk
- Required CSV keys: $rq_csvk
EOF
    ;

    return $tmp;
}
