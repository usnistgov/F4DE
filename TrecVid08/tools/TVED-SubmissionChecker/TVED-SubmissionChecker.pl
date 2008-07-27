#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 Event Detection Submission Checker
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Event Detection Submission Checker" is an experimental system.
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

my $versionid = "TrecVid08 Event Detection Submission Checker Version: $version";

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

# Cwd (usualy part of the Perl Core)
unless (eval "use Cwd; 1") {
  &_warn_add
    (
     "\"Cwd\" is not available on your Perl installation. ",
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


########################################
# Options processing

my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $mancmd = "perldoc -F $0";
my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $vfv = "";


# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:   C  F             T  WX    cdefgh   lm  p r   vwx  

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'ViperValidator=s'      => \$vfv,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}



########################################

# Expected values
my @expected_ext = ( "tgz" );
my @expected_year = ( "2008" );
my @expected_task = ( "retroED" );
my @expected_data = ( "DEV08", "EVAL08" );
my @expected_lang = ( "ENG" );
my @expected_input = ( "s-camera" );
my @expected_sysid_beg = ( "p-", "c-" );

my @expected_dir_output = ( "output" );

my $todo = scalar @ARGV;
my $done = 0;
foreach my $sf (@ARGV) {
  my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($sf);
  if (! MMisc::is_blank($err)) {
    &valerr($sf, $err);
    next;
  }

#  print "[$dir | $file | $ext]\n";

  if (MMisc::is_blank($file)) {
    &valerr($sf, "No filename detected ?");
    next;
  }

  # Check the file extension
  $err = &check_archive_extension($ext);
  if (! MMisc::is_blank($err)) {
    &valerr($sf, $err);
    next;
  }

  # Get the SITE and SUB-NUM information
  ($err, my $site, my $subnum) = &check_archive_name($file);
  if (! MMisc::is_blank($err)) {
    &valerr($sf, $err);
    next;
  }
  
  # Uncompress archive
  ($err, my $tmpdir) = &uncompress_archive($dir, $file, $ext);
 if (! MMisc::is_blank($err)) {
   &valerr($sf, $err);
   next;
 }

  # Check for the output directories
  $err = &check_for_output_dir($tmpdir);
  if (! MMisc::is_blank($err)) {
    &valerr($sf, $err);
    next;
  }

  # Process each output directory
  foreach my $odir (@expected_dir_output) {
    my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files("$tmpdir/$odir");
    if (! MMisc::is_blank($derr)) {
      &valerr($sf, $derr);
      next;
    }
    if ( (scalar @$rf > 0) || (scalar @$ru > 0) ) {
      &valerr($sf, "Found more than just directories");
      next;
    }
    if (scalar @$rd == 0) {
      &valerr($sf, "Found no submission directory");
      next;
    }
    foreach my $sdir (sort @$rd) {
      ($err, my $warn) = &check_submission_dir("$tmpdir/$odir", $sdir, $site);
      if (! MMisc::is_blank($err)) {
        &valerr($sf, $err);
      }
    }
  }

  &valok($sf, "ok");
  $done++;
}

MMisc::ok_quit("All submission processed (OK: $done / Total: $todo)\n");

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
  &valok($fname, "[ERROR] ** Please refer to the \'Submission Instructions\' (Appendix B) of the \'TRECVid Event Detection Evaluation Plan\' for more information");
}


##########

sub check_archive_extension {
  my $ext = MMisc::iuv(shift @_, "");

  return(&cmp_exp("file extension", $ext, @expected_ext));
}

##########

sub check_archive_name {
  my $file = MMisc::iuv(shift @_, "");

  my $et = "Archive name not of the form \'<SITE>_<SUB-NUM>\'";

  my ($lsite, $lsubnum, @left) = split(m%\_%, $file);
  
  return($et . " (leftover entries: " . join(" ", @left) . ")")
    if (scalar @left > 0);

  return($et . " (<SUB-NUM> ($lsubnum) not of the expected form: integer value starting at 1)")
    if ( ($lsubnum !~ m%^\d+$%) || ($lsubnum =~ m%^0%) );

  return("", $lsite, $lsubnum);
}

##########

sub uncompress_archive {
  my ($dir, $file, $ext) = MMisc::iuav(\@_, "", "", "");

  my $tmpdir = MMisc::get_tmpdir();
  return("Problem creating temporary directory", undef)
    if (! defined $tmpdir);

  my $pwd = Cwd::getcwd();

  my $f = ( (MMisc::is_blank($dir)) ? $pwd : $dir) . "/$file.$ext";
  
  my $cmdline = "tar xfz $f";

  chdir($tmpdir);
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call($cmdline);
  chdir($pwd);

  return("Problem while uncompressing archive ($stderr)", undef)
    if (! MMisc::is_blank($stderr));

  return("", $tmpdir);
}

##########

sub check_for_output_dir {
  my $tmpdir = MMisc::iuv(shift @_, "");

  return("Empty directory ?")
    if (MMisc::is_blank($tmpdir));

  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($tmpdir);

  return("Found files where only directories expected")
    if ( (scalar @$rf > 0) || (scalar @$ru > 0) );
  
  my @d = @$rd;

  return("Found a different amount of directories in the base directory than expected (expected: " . join(" ", @expected_dir_output) . ") (seen: " . join(" ", @d) . ")")
  if (scalar @d != scalar @expected_dir_output);

  my ($ri, $ro) = MMisc::confirm_first_array_values(\@expected_dir_output, @d);
  return("Not all expected directories (" . join(" ", @expected_dir_output) . ") found")
    if (scalar @$ri != scalar @expected_dir_output);

  return("");
}


##########

sub check_submission_dir {
  my ($bd, $dir, $site) = @_;

  my $err = "";
  my $warn = "";

  my ($lerr) = &check_name($dir, $site);
  return($lerr) if (! MMisc::is_blank($lerr));

  ($lerr, my $lw) = &check_exp_dirfiles($bd, $dir, $site);
  return($lerr) if (! MMisc::is_blank($lerr));


}

##########

sub check_name {
  my ($name, $site) = @_;

  my $et = "\'EXP-ID\' not of the form \'<SITE>_<YEAR>_<TASK>_<DATA>_<LANG>_<INPUT>_<SYSID>_<VERSION>\'";

  my ($lsite, $lyear, $ltask, $ldata, $llang, $linput, $lsysid, $lversion,
      @left) = split(m%\_%, $name);

  return($et . " (leftover entries: " . join(" ", @left) . ")")
    if (scalar @left > 0);

  return($et . " (<SITE> ($lsite) is different from submission file <SITE> ($site))")
    if ($site ne $lsite);

  my $err = "";
  $err .= &cmp_exp("<YEAR>", $lyear, @expected_year);
  $err .= &cmp_exp("<TASK>", $ltask, @expected_task);
  $err .= &cmp_exp("<DATA>", $ldata, @expected_data);
  $err .= &cmp_exp("<LANG>", $llang, @expected_lang);
  $err .= &cmp_exp("<INPUT>", $linput, @expected_input);

  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expected_sysid_beg) . "). "
      if (! grep(m%^$b$%, @expected_sysid_beg));
  
  return($et . $err)
    if (! MMisc::is_blank($err));

}

##########

sub check_exp_dirfiles {
  my ($bd, $exp) = @_;

  my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files("$bd/$exp");
  return($derr) 
    if (! MMisc::is_blank($derr));

  return("Found more than just files")
    if ( (scalar @$rd > 0) || (scalar @$ru > 0) );

  return("Found no submission files")
    if (scalar @$rf == 0);

  my $expected_exp = "$exp.txt";
  my @txtf = grep(m%\.txt$%, @$rf);
  return("Found no \'.txt\' file. ")
    if (scalar @txtf == 0);
  return("Found more than the one expected \'.txt\' file :" . join(" ", @txtf) . ")")
    if (scalar @txtf > 1);
  return("Could not find the expected \'.txt\' file ($expected_exp) (seen: " . join(" ", @txtf) . ")")
    if (! grep(m%$expected_exp$%, @txtf));

  my @xmlf = grep(m%\.xml$%, @$rf);
  return("Found no \'.xml\' file. ")
    if (scalar @xmlf == 0);
  return("More than just \'.txt\' and \'.xml\' files in directory. ")
    if ((scalar @xmlf + scalar @txtf) != (scalar @$rf));

  

  return("");
}

##########

sub cmp_exp {
  my ($t, $v, @e) = @_;

  return("$t ($v) does not compare to expected value (" . join(" ", @e) ."). ")
    if (! grep(m%$v$%, @e));

  return("");
}


############################################################

sub set_usage {
  my $xsdfiles = join(" ", @xsdfilesl);
  my $ecf_xsdf = join(" ", @ecf_xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--TrecVid08xsd location] [--ViperValidator prog] file.tgz [file.tgz [...]]

Will confirm that a submission file conform to the 'Submission Instructions'

 Where:
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --ViperValidator  Location of the TV08ViperValidator program
  --version       Print version number and exit
  --help          Print this usage information and exit

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'TrecVid08.xsd' file
- 'TrecVid08xsd' files are: $xsdfiles (and if the 'ecf' option is used, also: $ecf_xsdf)
EOF
    ;

    return $tmp;
}
