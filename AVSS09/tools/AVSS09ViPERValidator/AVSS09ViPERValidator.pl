#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#
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

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../CLEAR07/lib", "$f4d/../../../common/lib");
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

# Part of this tool
foreach my $pn ("MMisc", "AVSS09ViperFile", "AVSS09ECF", "AVSS09HelperFunctions") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "AVSS09 ViPER XML Validator ($versionkey)";

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
my $mancmd = "perldoc -F $0";
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $frameTol = 0;
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = "$f4d/../../../CLEAR07/data";
my $show = 0;
my $forceFilename = "";
my $writeback = -1;
my $MemDump = undef;
my $skipScoringSequenceMemDump = 0;
my $AVxsdpath = "$f4d/../../data";
my $ecf_file = "";
my $ttid = "";
my $tttdir = 0;
my $ovwrt = 1;
my $ttid_quit = 0;
my $ofppid = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used: A C EF        O    T  W        fgh      o q st vwx    #

my %opt;
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'gtf'             => \$isgtf,
   'frameTol=i'      => \$frameTol,
   'ForceFilename=s' => \$forceFilename,
   'write:s'         => \$writeback,
   'WriteMemDump:s'  => \$MemDump,
   'skipScoringSequenceMemDump' => \$skipScoringSequenceMemDump,
   'AVSSxsd=s'       => \$AVxsdpath,
   'ECF=s'           => \$ecf_file,
   'trackingTrial=s' => \$ttid,
   'TrackingTrialsDir' => \$tttdir,
   'overwriteNot'    => sub {$ovwrt = 0},
   'quitTTID'        => \$ttid_quit,
   'OneFilePerPersonID' => \$ofppid,
   # Hiden Option(s)
   'X_show_internals'  => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::error_quit("Not enough arguments\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'ForceFilename\' option selected but no value set\n$usage")   if (($opt{'ForceFilename'}) && (MMisc::is_blank($forceFilename)));

if (($writeback != -1) && ($writeback ne "")) {
  # Check the directory
  my ($err) = MMisc::check_dir_w($writeback);
  MMisc::error_quit("Provided \'write\' option directory ($writeback): $err")
    if (! MMisc::is_blank($err));
  $writeback .= "/" if ($writeback !~ m%\/$%); # Add a trailing slash
}

MMisc::error_quit("Can not use \'trackingTrial\' unless an ECF file is specified")
  if ((MMisc::is_blank($ecf_file)) && (! MMisc::is_blank($ttid)));
MMisc::error_quit("Can not use \'quitTTID\' unless \'trackingTrial\' is selected")
  if ((MMisc::is_blank($ttid)) && ($ttid_quit != 0));

if ($tttdir) {
  MMisc::error_quit("Can not use \'TrackingTrialsDir\' unless an ECF file is specified")
      if (MMisc::is_blank($ecf_file));
  MMisc::error_quit("Can not use \'TrackingTrialsDir\' unless a \"write\" directory is specified")
      if ($writeback eq "");
}

MMisc::error_quit("\'ECF\' needs one of \'TrackingTrialsDir\' or \'trackingTrial\'")
  if ((! MMisc::is_blank($ecf_file)) && (MMisc::is_blank($ttid)) && ($tttdir == 0));

my $sk_wb = 0;
$sk_wb = 1 if ((! MMisc::is_blank($ttid)) || ($tttdir));

if ($sk_wb) {
  my $txt = "*!* Tracking Trial mode selected";
  if (! defined $MemDump) {
    $txt .= " / Forcing " . $ok_md[0] . " MemDump";
    $MemDump = $ok_md[0]
  }
  if ($skipScoringSequenceMemDump) {
    $txt .= " / Forcing ScoringSequenceMemDump";
    $skipScoringSequenceMemDump = 0;
  }
  MMisc::error_quit("No \'write\' option given, needed for this mode\n\n$usage\n")
      if ($writeback == -1);
  MMisc::error_quit("Can not \'write\' to stdout in this mode\n\n$usage\n")
      if ($writeback eq "");
  $txt .= " *!*";
  print "$txt\n";
}

if (defined $MemDump) {
  MMisc::error_quit("\'WriteMemDump\' can only be used in conjunction with \'write\'")
    if ($writeback == -1);
  $MemDump = $ok_md[0]
    if (MMisc::is_blank($MemDump));
  MMisc::error_quit("Unknown \'WriteMemDump\' mode ($MemDump), authorized: " . join(" ", @ok_md))
    if (! grep(m%^$MemDump$%, @ok_md));
}

MMisc::error_quit("\'skipScoringSequenceMemDump\' can only be used if \'MemDump\' is selected")
if (($skipScoringSequenceMemDump) && (! defined $MemDump));

MMisc::error_quit("\'OneFilePerPersonID\' can only be used if a \'write\' directory is provided")
  if (($ofppid) && ($writeback eq ""));

MMisc::error_quit("\'OneFilePerPersonID\' can not be used in conjunction with Tracking Trial mode")
  if (($ofppid) && ($sk_wb));

  
##############################
# Main processing

## Pre
my $ecf = &load_ecf($ecf_file);
my %ttid_lefttodo = ();
if (! MMisc::is_blank($ttid)) {
  my $ok = $ecf->is_ttid_in($ttid);
  MMisc::error_quit("Requested TTID [$ttid] problem: " . $ecf->get_errormsg())
      if ($ecf->error());
  MMisc::error_quit("Requested TTID [$ttid] is not in ECF")
      if (! $ok);
  my @sffn_list = $ecf->get_sffn_list_for_ttid($ttid);
  MMisc::error_quit("Problem obtaining SFFN list for requested TTID [$ttid]: " . $ecf->get_errormsg())
      if ($ecf->error());
  MMisc::error_quit("No SFFN found for requested TTID [$ttid]")
      if (scalar @sffn_list == 0);
  if ($ttid_quit) {
    foreach my $lsffn (@sffn_list) {
      $ttid_lefttodo{$lsffn}++;
    }
  }
}

my $ntodo = scalar @ARGV;
my $ndone = 0;
foreach my $tmp (@ARGV) {
  my ($err, $fname, $fsshift, $idadd, @boxmod) = 
    AVSS09ViperFile::extract_transformations($tmp);
  MMisc::error_quit("While processing filename ($fname): $err")
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

  ## ECF
  my ($msg) = &process_training_trials($object);
  print $msg if (! MMisc::is_blank($msg));
  
  if (($writeback != -1) && (! $sk_wb)) {
    if ($ofppid) {
      my @pid = $object->get_person_id_list();
      print " !! No PERSON IDs in file\n" if (scalar @pid == 0);
      foreach my $id (sort @pid) {
        my $no = $object->clone_selected_ids($id);
        MMisc::error_quit("Problem while cloning selected IDs: " . $object->get_errormsg())
            if ($object->error());
        &write_files($fname, $no, sprintf("-PID_%03d", $id));
      }
    } else {
      &write_files($fname, $object, "");
    }
  }

  $ndone++;
}

print "\n\n" if ($sk_wb);
print("All files processed (Validated: $ndone | Total: $ntodo)\n");

if ($ttid_quit) {
  my $quitxt = "";
  foreach my $sffn (sort keys %ttid_lefttodo) {
    my $v = $ttid_lefttodo{$sffn};
    $quitxt .= "\n - SFFN [$sffn] was not found or validated." 
      if ($v > 0);
  }
  MMisc::error_quit("In \'quitTTID\' mode for TTID [$ttid]:$quitxt\n")
      if (! MMisc::is_blank($quitxt));
  print "Note: In \'quitTTID\' mode for TTID [$ttid], all SFFN seen\n";
}

MMisc::error_quit("Not all files processed succesfuly") if ($ndone != $ntodo);
MMisc::ok_quit("\nDone\n");

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "\n\n[*] " if ($sk_wb);
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

  my ($retstatus, $object, $msg) = 
    AVSS09HelperFunctions::load_ViperFile($isgtf, $tmp, $frameTol, $xmllint, $xsdpath);

  if ($retstatus) { # OK return
    &valok($tmp, $msg . (MMisc::is_blank($msg) ? "validates" : ""));
  } else {
    &valerr($tmp, $msg);
  }

  return($retstatus, $object);
}

##########

sub load_ecf {
  my ($tmp) = @_;

  return(undef) if (MMisc::is_blank($tmp));

  my ($err, $object) = AVSS09HelperFunctions::load_ECF_file($tmp, $xmllint, $AVxsdpath);

  MMisc::error_quit("Problem loading ECF file ($tmp) : $err")
      if (! MMisc::is_blank($err));

  return($object);
}

####################

sub __get_ttid_VF {
  my ($vf, $ttid) = @_;

  my ($err, $nvf) 
    = AVSS09HelperFunctions::clone_VF_apply_ECF_for_ttid($vf, $ecf, $ttid, 1);
  MMisc::error_quit("While trying to obtain a new ViperFile memory representation: $err\n")
      if (! MMisc::is_blank($err));

  return($nvf);
}

#####

sub _get_ttid_dd {
  my ($sffn, $rttid, $isgtf) = @_;

  my $dd = $writeback;
  $dd .= $ecf->get_sffn_ttid_expected_path_base($sffn, $rttid, $isgtf)
    if ($tttdir);

  MMisc::error_quit("Problem creating output dir [$dd]")
      if (! MMisc::make_dir($dd));
  
  return($dd);
}

#####

sub _write_VF_to_ttid_dd {
  my ($vf, $sffn, $rttid, $isgtf, $efn) = @_;

  return(AVSS09HelperFunctions::VF_write_XML_MemDumps($vf, $efn, $isgtf, $MemDump, 0, "", $ovwrt));
}

#####

sub __write_GTF_ttid_VF {
  my ($vf, $rttid, $sffn, $efn) = @_;

  my $nvf = &__get_ttid_VF($vf, $rttid);
  return(&_write_VF_to_ttid_dd($nvf, $sffn, $rttid, 1, $efn));
}

#####

sub __write_SYS_ttid_VF {
  my ($vf, $rttid, $sffn, $efn) = @_;
  return(&_write_VF_to_ttid_dd($vf, $sffn, $rttid, 0, $efn));
}

#####

sub __write_autoselect_ttid_VF {
  my ($vf, $rttid, $sffn, $isgtf) = @_;

  my $dd = &_get_ttid_dd($sffn, $rttid, $isgtf);
  my $df = "$dd/$sffn.xml";
  my $efn = AVSS09ViperFile::get_XML_filename($df);
  MMisc::error_quit("Output ViperFile ($efn) already exists, and overwrite not requested, stopping further processing")
      if ((! $ovwrt) && (MMisc::does_file_exist($efn)));

  return(&__write_GTF_ttid_VF($vf, $rttid, $sffn, $efn))
    if ($isgtf);

  return(&__write_SYS_ttid_VF($vf, $rttid, $sffn, $efn));
}

#####

sub _process_tt_ttid_only {
  my ($vf, $sffn, $isgtf, $rttid) = @_;

  if (! $ecf->is_sffn_in_ttid($rttid, $sffn)) {
    MMisc::error_quit("sffn [$sffn] not part of requested trackingTrial [$ttid], and \'quitTTID\' requested, aborting")
        if ($ttid_quit);
    return("! sffn not part of requested trackingTrial [$ttid], skipping it\n");
  }

  print "++ ttid: $rttid\n";
  my $fn = &__write_autoselect_ttid_VF($vf, $rttid, $sffn, $isgtf);
  if ($ttid_quit) {
    MMisc::error_quit("In \'quitTTID\' mode, can not find SFFN [$sffn] in list of TTID [for $rttid]")
        if (! exists $ttid_lefttodo{$sffn});
    $ttid_lefttodo{$sffn}--;
  }
  return("");
}

#####

sub _process_tt_all {
  my ($vf, $sffn, $isgtf) = @_;

  my @l = $ecf->get_ttid_list_for_sffn($sffn);
  MMisc::error_quit("Problem obtaining list of ttid for sffn: " . $ecf->get_errormsg())
      if ($ecf->error());

  return("  |-> sffn not part of any trackingTrial, skip tt processing\n", undef)
    if (scalar @l == 0);

  foreach my $rttid (@l) {
    my $msg = &_process_tt_ttid_only($vf, $sffn, $isgtf, $rttid);
    print $msg;
  }

  return("--> All ECF ttids done\n");
}

#####

sub process_training_trials {
  my ($vf) = @_;

  return("") if (! $sk_wb);

  my ($sffn) = $vf->get_sourcefile_filename();
  MMisc::error_quit("Problem obtaining sffn: " . $vf->get_errormsg())
      if ($vf->error());

  print "== sffn: $sffn\n";

  my ($isgtf) = $vf->check_if_gtf();
  MMisc::error_quit("Problem obtaining gtf status: " . $vf->get_errormsg())
      if ($vf->error());

  # If we only want one ttid, only do this one
  return(&_process_tt_ttid_only($vf, $sffn, $isgtf, $ttid))
    if (! MMisc::is_blank($ttid));

  # otherwise, do them all
  return(&_process_tt_all($vf, $sffn, $isgtf));
}

#####

sub write_files {
  my ($fname, $object, $lfnadd) = @_;

  my $lfname = "";
  
  if ($writeback ne "") {
    my ($err, $td, $tf, $te) = MMisc::split_dir_file_ext($fname);
    $lfname = MMisc::concat_dir_file_ext($writeback, $tf . $lfnadd, $te);
  }
    
  AVSS09HelperFunctions::VF_write_XML_MemDumps($object, $lfname, $isgtf, $MemDump, $skipScoringSequenceMemDump, "** XML re-Representation:\n", $ovwrt);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

############################################################ Manual

=pod

=head1 NAME

AVSS09ViPERValidator - AVSS09 ViPER XML Validator

=head1 SYNOPSIS

B<AVSS09ViPERValidator> S<[ B<--help> | B<--man> | B<--version> ]>
  S<[B<--xmllint> I<location>] [B<--CLEARxsd> I<location>]>
  S<[B<--gtf>] [B<--frameTol> I<framenbr>]>
  S<[B<--ForceFilename> I<filename>]>
  S<[B<--write> [I<directory>]>
   S<[B<--WriteMemDump> [I<mode>] [B<--skipScoringSequenceMemDump>]]>
   S<[B<--overwriteNot>]]>
  S<[B<--OneFilePerPersonID>]>
  S<[B<--ECF> I<ecffile.xml> [B<--TrackingTrialsDir>]>
   S<[B<--trackingTrial> I<ttid> [B<--quitTTID>]]>
   S<[B<--AVSSxsd> I<location>]]>
  S<I<viper_source_file.xml>[I<transformations>]>
  S<[I<viper_source_file.xml>[I<transformations>] [I<...>]]>
  
=head1 DESCRIPTION

B<AVSS09ViPERValidator> performs a syntactic and semantic validation of the ViPER XML file(s) provided on the command line. It can I<validate> reference files (see B<--gtf>) as well as system files. It can also rewrite validated files into another directory using the same filename as the original (see B<--write>), write a I<memory representation> of the ViPER file post validation (to hasten reload time), as well as a I<Scoring Sequence> I<memory representation> to be used for scoring.

=head1 PREREQUISITES

B<AVSS09ViPERValidator> relies on some external software and files, most of which associated with the B<CLEAR> section of B<F4DE>.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<F4DE_XMLLINT> environment variable to the full path location of the I<xmllint> executable.

=item B<FILES>

The syntactic validation requires some XML schema files (see the B<CLEARDTScorer> help section for a list of the required files).
It is possible to specify their location using the B<--xsdpath> option.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

Once you have installed the software, extending your B<PATH> to include F4DE's B<bin> directory should be sufficient for the tools to find their components.

=back

=head1 GENERAL NOTES

B<AVSS09ViPERValidator> expects that the files can be validated using 'xmllint' against the B<CLEAR> XSD file(s) (see B<--help> for files list).

B<AVSS09ViPERValidator> will use the core validation of the B<CLEAR> code and add some specialized checks associated with the B<AVSS09> evaluation.

=head1 OPTIONS

=over

=item B<--AVSSxsd> I<location>

Specify the default location of the required AVSS XSD files.

=item B<--CLEARxsd> I<location>

Specify the default location of the required CLEAR XSD files.

=item B<--ECF> I<ecffile.xml>

When rewriting XML and MemDump, for a given I<tracking trial ID> apply the rules specified in the ECF to the I<sourcefile filename> corresponding entry.

=item B<--ForceFilename> I<file>

Replace the I<sourcefile>'s I<filename> value by I<file>.

=item B<--frameTol> I<framenbr>

The frame tolerance allowed for attributes to be outside of the object framespan.
Default value can be obtained by using B<--help>.

=item B<--gtf>

Specify that the files to validate are Reference files (also known as a Ground Truth Files)

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--man>

Display this man page.

=item B<--OneFilePerPersonID>

When writing validated files to disk, create one file per PERSON ID seen in the file.

The output filename will be composed of the input file name with S<-PID_XXX>, placed before the file extension, where S<XXX> is the ID written on 3 digits.

=item B<--overwriteNot>

When rewriting XML or MemDumps, the default is to overwrite previously generated files. This option inhibit this feature: it will force files to not be overwritten and the program will exit with an error status.

=item B<--quitTTID>

When checking a specified I<tracking trial ID>, exit with an error message if the files listed on the command line to be validated are not part of this TTID (or if not all the files needed to validate this given TTID are present).

=item B<--skipScoringSequenceMemDump>

Do not generate the I<Scoring Sequence> memory representation when generating the validated ViPER file memory representation.
This representation can be used by the scoring program.

=item B<--TrackingTrialsDir>

When rewriting XML or MemDumps into the B<--write> I<directory>, place those files in a directory structure that match the I<ECF> specifications for a given I<tracking trial ID> that can be reloaded by the B<AVSS09Scorer> program with the I<ECF> information only.

This directory structure is of the form:

I<write directory>/I<tracking trial type>/I<tracking trial ID>/I<sourcefile filename>/I<XML file type>/I<sourcefile filename>S<.xml>

For example, if the I<AVSS09ViPERValidator> was asked to validate a I<GTF> which I<sourcefile filename> (the filename part of the I<file> specified in the XML's I<sourcefile> section) was S<MCTTR0104a.mov>, given an I<ECF> file defining two I<tracking trial ID>s for that I<sourcefile filename> called S<CPSPT_01> and S<SCSPT_02> (respectively of I< tracking trial type>s S<cpspt> and S<scspt>). Given a requested I<write directory> of S<PostECF>, the validation process will generate two XML files:

S<PostECF/cpspt/CPSPT_01/MCTTR0104a.mov/GTF/MCTTR0104a.mov.xml>

S<PostECF/scspt/SCSPT_02/MCTTR0104a.mov/GTF/MCTTR0104a.mov.xml>

=item B<--trackingTrial> I<ttid>

When processing files, only rewrite the ones that are defined in the I<ECF> as part of the specified I<ttid>

=item B<--version>

Display B<AVSS09ViPERValidator> version information.

=item B<--write> [I<directory>]

Once validation has been completed for a given file, B<AVSS09ViPERValidator> will write a new XML representation of this file to either the standard output (if I<directory> is not set), or will create a file with the same name as the input file in I<directory> (if specified).

=item B<--WriteMemDump> [I<mode>]

Write to disk a memory representation of the validated ViPER File.
This memory representation file can be used as the input of other AVSS09 tools.
The mode is the file representation to disk and its values and its default can be obtained using the B<--help> option.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<F4DE_XMLLINT> environment variable.

=back

=head1 TRANSFORMATIONS

Transformations are an easy way to influence the content of the ViPER file.

Syntax: S<[:B<FSshift>][@B<BBmod>][#B<IDadd>]>

=over

=item B<FSshift>

It is the number of frames to add or subtract from every framespan within the specified file.

=item B<BBmod>

It is the I<bounding box> modifications of the form S<I<X>+I<Y>xI<M>>, where I<X> and I<Y> add or subtract and I<M> multiply.
Such that if a I<bounding box> if defined by S<x,y,h,w>, S<new x = (x * M) + X>, S<new y = (y * M) + Y>, S<new h = h * M>, and <new w = w * M>.


=item B<IDadd>

It is the number of ID to add or subtract to every PERSON ID seen within the specified file.
Such that if a I<person ID> is S<ID>, then S<new ID = ID + IDadd>. 

=back

=head1 USAGE

=item B<AVSS09ViPERValidator --xmllint /local/bin/xmllint --TrecVid08xsd /local/F4DE-CVS/data sys_test1.xml>

Will try to validate the I<system> file I<sys_test1.xml> using the I<xmllint> executable located at I</local/bin/xmllint> and the required XSD files found in the I</local/F4DE/data> directory.

=item B<AVSS09ViPERValidator --gtf ref_test1.xml:100@-10+20x0.5#5 ref_test2.xml --frameTol 5 --write /tmp --WriteMemDump text>

Will try to validate the I<reference> files I<ref_test1.xml> and I<ref_test2.xml> using a tolerance of 5 frames for attributes to be ouside of the object framespan.
For I<ref_test1.xml>, it will also add 100 frames to each framespan found within the file, modify the I<bounding box> by substracting 10 from each X coordinate, adding 20 to each Y, and multiplying each resulting coordinate by 0.5, and add 5 to each object ID seen. 
It will then write to the I</tmp> directory a XML rewrite of both files, as well as a ViPER file memory represenation (in text format) and a scoring sequence memory representation.

=item B<AVSS09ViPERValidator sys_test1.xml sys_test2.xml --ForceFilename ff.xml --write /tmp --WriteMemDump gzip --skipScoringSequenceMemDump>

Will try to validate the I<system> files I<sys_test1.xml> and I<sys_test2.xml>, changing for files the I<sourcefile filename> within to I<ff.xml>.
Then write into the I</tmp> directory both files and their ViPER file memory represenation (in compressed format, to save some disk space). 

=item B<AVSS09ViPERValidator --gtf gtf_test1.xml gtf_test2.xml --write /tmp --WriteMemDump gzip --ECF test_ecf.xml --TrackingTrialsDir --trackingTrial CPSPT_01>

Will try to validate the I<reference> files I<gtf_test1.xml> and I<gtf_test2.xml>.
It will then write XML and both XML file and Scoring Sequence MemDumps into the I</tmp> directory the files corresponding to the I<test_ecf.xml> I<ECF> definition of the I<CPSCPT_01> I<tracking trial ID>, following a directory structure that can be used by the I<AVSS09Scorer> tool.

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut

########################################

sub set_usage {
  my $wmd = join(" ", @ok_md);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --man | --version] [--xmllint location] [--CLEARxsd location] [--gtf] [--frameTol framenbr] [--ForceFilename file] [--write [directory] [--WriteMemDump [mode] [--skipScoringSequenceMemDump]] [--overwriteNot]] [--OneFilePerPersonID] [--ECF ecffile.xml [--TrackingTrialsDir] [--trackingTrial ttid [--quitTTID]] [--AVSSxsd location]] viper_source_file.xml[transformations] [viper_source_file.xml[transformations] [...]]

Will perform a semantic validation of the AVSS09 ViPER XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd  Path where the XSD files can be found
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default: $frameTol)
  --ForceFilename  Specify that all files loaded refers to the same 'sourcefile' file
  --write         Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)
  --WriteMemDump  Write a memory representation of validated ViPER Files that can be used by the Scorer and Merger tools. Two modes possible: $wmd (1st default)
  --skipScoringSequenceMemDump  Do not perform the Scoring Sequence MemDump (which can be used for scoring)
  --overwriteNot  Do not overwrite already existing XML or MemDump files
  --OneFilePerPersonID  Generate one output file per PERSON ID seen in input file (\"-PID_XXX\" will be added to the output file name)
  --ECF           Specify the ECF XML file to use when rewritting data
  --TrackingTrialsDir  When rewritting data, create a directory hierarchy than is recongizable by the scoring tool
  --trackingTrial Process only the requested \"tracking trial ID\"
  --quitTTID      Exit with error if not all files requested for given TTID are present (or too many are present)
  --AVSSxsd       Path where the XSD files needed for ECF validation can be found


Transformations syntax: [:FSshift][\@BBmod][#IDadd]
where: 
- FSshift is the number of frames to add or substract from every framespan within this file
- BBmod is the bounding box modifications of the form X+YxM, ie X and Y add or substract and M multiply (example: @-10+20x0.5 will substract 10 from each X coordinate, add 20 to each Y, and multiply each resulting coordinate by 0.5)
- IDadd is the number of ID to add or substract to every PERSON ID seen within this file

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'CLEAR.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will disard any xml comment(s).
- 'CLEARxsd' files are the same as needed by CLEARDTViPERValidator
EOF
;

  return $tmp;
}

######################################## THE END
