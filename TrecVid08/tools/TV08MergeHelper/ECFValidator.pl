#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 ECF XML Validator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 ECF XML Validator" is an experimental system.
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

my $versionid = "TrecVid08 ECF XML Validator Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
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

# Part of this tool
foreach my $pn ("MMisc", "TrecVid08ECF", "TrecVid08ViperFile", "ViperFramespan") {
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
# Get some values from TrecVid08ECF
my $dummy = new TrecVid08ECF();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

# Get some values from TrecVid08ViperFile
my $dummyvf = new TrecVid08ViperFile();
my @ok_events = $dummyvf->get_full_events_list();

########################################
# Options processing

my $xmllint_env = "F4DE_XMLLINT";
my $rsyst_def = "$f4d/../misc/create_random_sys_csv.pl";
my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = "$f4d/../../data";
my $show = 0;
my $fps = 0;
my $show_summary = 0;

my $rsystool = undef;
my $writetodir = "";
my @asked_events = ();
my $entries = undef;
my @limitto = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:   C                T        c ef h   l      s  vwx   #

my %opt = ();
my $dbgftmp = "";
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'fps=i'           => \$fps,
   'content'         => \$show_summary,
   # for 'create_random_sys_csv"
   'CreateRandomSysCSV:s' => \$rsystool,
   'writeToDir=s'       => \$writetodir,
   'limitto=s'       => \@asked_events,
   'entries=i'       => \$entries,
   # Hiden Option(s)
   'show_internals'  => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'fps\' must be set when using this tool\n\n$usage\n")
    if ($fps == 0);

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

if (defined $rsystool) {
    if (MMisc::is_blank($rsystool)) { $rsystool = $rsyst_def; }
    my $err = MMisc::check_file_x($rsystool);
    MMisc::error_quit("Problem with \'CreateRandomSysCSV\' executable ($rsystool): $err\n\n$usage\n")
        if (! MMisc::is_blank($err));
    if (MMisc::is_blank($writetodir)) { $writetodir = MMisc::get_pwd(); }
    $err = MMisc::check_dir_w($writetodir);
    MMisc::error_quit("Problem with \'writeToDir\': $err\n\n$usage\n")
        if (! MMisc::is_blank($err));
    if (scalar @asked_events > 0) {
        @asked_events = $dummyvf->validate_events_list(@asked_events);
        MMisc::error_quit("While checking \'limitto\' events list (" . $dummyvf->get_errormsg() .")")
            if ($dummyvf->error());
    }
    MMisc::error_quit("Problem with \'entries\', must be positive\n\n$usage\n")
        if ((defined $entries) && ($entries < 0));
} else {
    MMisc::error_quit("\'writeToDir\' can only be used with \'CreateRandomSysCSV\'\n\n$usage\n")
        if (! MMisc::is_blank($writetodir));
    MMisc::error_quit("\'limitto\' can only be used with \'CreateRandomSysCSV\'\n\n$usage\n")
        if (scalar @limitto > 0);
    MMisc::error_quit("\'entries\' can only be used with \'CreateRandomSysCSV\'\n\n$usage\n")
        if (defined $entries);
}
    
##########
# Main processing
my $tmp = "";
my %all = ();
my $ntodo = scalar @ARGV;
my $ndone = 0;
while ($tmp = shift @ARGV) {
  my ($ok, $object) = &load_file($tmp);
  next if (! $ok);

  if (defined $rsystool) {
      my @flist = $object->get_files_list();
      MMisc::error_quit("Problem obtaining ECF ($tmp) file list: " . $object->get_errormsg())
          if ($object->error());
      my $btmpfile = MMisc::get_tmpfile();
      foreach my $ufile (sort @flist) {
          my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($ufile);
          MMisc::error_quit("Problem splitting file information ($ufile): $err")
              if (! MMisc::is_blank($err));
          my @res = $object->get_file_ViperFramespans($ufile);
          MMisc::error_quit("Problem obtaining ECF ($tmp) framespan information: " . $object->get_errormsg())
              if ($object->error());
          my ($beg, $end) = (undef, undef);
          # just in case the ECF has more than one framespan for this given file, find its global min/max
          foreach my $vfs (@res) {
              my ($lbeg, $lend) = $vfs->get_beg_end_fs();
              MMisc::error_quit("Problem obtaining framespan direct information: " . $vfs->get_errormsg())
                  if ($vfs->error());
              $beg = (defined $beg) ? (($lbeg < $beg) ? $lbeg : $beg) : $lbeg;
              $end = (defined $end) ? (($lend > $end) ? $lend : $end) : $lend;
          }
          my $ofile = "$writetodir/$file.csv";
          #          print "[$ufile / $ofile / $beg / $end]\n";
          my @cmdl = ($rsystool);
          if (! MMisc::is_blank($writetodir)) { push @cmdl, '--writeTo', $ofile; }
          if (scalar @asked_events > 0) { push @cmdl, '--limitto', join(',', @asked_events); }
          if (defined $entries) { push @cmdl, '--entries', $entries; }
          push @cmdl, $end;
          if ($beg != 1) { push @cmdl, $beg; }

          my ($ok, $otxt, $stdout, $stderr, $retcode, $tmpfile, $signal) =
              MMisc::write_syscall_smart_logfile($btmpfile, @cmdl);
          MMisc::error_quit("Problem running \'CreateRandomSysCSV\' command, for more details, see: $tmpfile")
              if ((! $ok) || ($retcode + $signal != 0));
          $err = MMisc::check_file_r($ofile);
          MMisc::error_quit("Could not find expected output file ($ofile) : $err")
              if (! MMisc::is_blank($err));
          print "     |->  wrote: $ofile\n";
      }
  }
  
  $all{$tmp} = $object;
  $ndone++;
}
MMisc::ok_quit("All files processed (Validated: $ndone | Total: $ntodo)\n");

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
  my ($tmp) = @_;

  my $err = MMisc::check_file_r($tmp);
  if (! MMisc::is_blank($err)) {
    &valerr($tmp, "skipping: $err");
    return(0, ());
  }
  
  # Prepare the object
  my $object = new TrecVid08ECF();
  MMisc::error_quit("While trying to set \'xmllint\' (" . $object->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $object->set_xmllint($xmllint)) );
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $object->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $object->set_xsdpath($xsdpath)) );
  MMisc::error_quit("While setting \'file\' ($tmp) (" . $object->get_errormsg() . ")")
    if ( ! $object->set_file($tmp) );
  MMisc::error_quit("While setting \'fps\' ($fps) (" . $object->get_errormsg() . ")")
    if ( ! $object->set_default_fps($fps) );

  # Validate
  if (! $object->validate()) {
    &valerr($tmp, $object->get_errormsg());
    return(0, ());
  }

  &valok($tmp, "validates");
  print $object->txt_summary() if ($show_summary);

  # This is really if you are a debugger
  $object->_display("** Memory Representation:\n") if ($show);

  return(1, $object);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

############################################################

sub set_usage {
  my $xsdfiles = join(" ", @xsdfilesl);
  my $ro = join(" ", @ok_events);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help] [--version] [--xmllint location] [--TrecVid08xsd location] [--content] --fps fps [--CreateRandomSysCSV [tool_location] --writeToDir dir ] ecf_source_file.xml [ecf_source_file.xml [...]]

Will perform a semantic validation of the ECF XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --fps           Set the default Frame per Second value for files within the ECF
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found
  --content       Show per file summary
  --CreateRandomSysCSV   For each file entry found in any ECF, create a random system CSV file (default tool location: $rsyst_def)
  --writeToDir     Directory to write output CSV files to. Naming of file is shortname.csv
  --limitto       Only care about provided list of events
  --entries       Maximum number of entries per event


Note:
- This prerequisite that the file can be been validated using 'xmllint' against the XSD file
- Program will disard any xml comment(s).
- 'TrecVid08xsd' files are: $xsdfiles
- List of recognized events: $ro
EOF
    ;

    return $tmp;
}
