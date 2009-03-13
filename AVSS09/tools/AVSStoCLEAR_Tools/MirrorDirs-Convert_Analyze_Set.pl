#!/usr/bin/env perl

# Mirror XML directory structure (specialized for use with Convert_Analyze_Set)
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAR Detection and Tracking Viper XML Validator" is an experimental system.
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

my $versionid = "Mirror XML directory structure (uses Convert_Analyze_Set): $version";

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
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

use strict;

########################################
my $toolsb = "Convert_Analyze_Set";

my $usage = "$0 source_dir output_dir [full_path_to_tool]\n\nConvert all the XML files found parsing the source_dir directory from AVSS ViPER to CLEAR ViPER files\nRelies on the $toolsb tool for this process\n";

my $in = shift @ARGV;
my $out = shift @ARGV;

MMisc::error_quit("No input_dir provided.\n $usage")
  if (MMisc::is_blank($out));
MMisc::error_quit("No output_dir provided.\n $usage")
  if (MMisc::is_blank($out));

my $err = MMisc::check_dir_r($in);
MMisc::error_quit("input_dir [$in] problem: $err")
  if (! MMisc::is_blank($err));

my $err = MMisc::check_dir_w($out);
MMisc::error_quit("output_dir [$out] problem: $err")
  if (! MMisc::is_blank($err));

my $tool = MMisc::iuv(shift @ARGV, MMisc::get_pwd() . "/${toolsb}.pl");
my $err = MMisc::check_file_x($tool);
MMisc::error_quit("tool [$tool] problem: $err")
  if (! MMisc::is_blank($err));

&do_xmls($in, $out);

MMisc::ok_quit("\nDone\n");

############################################################

sub do_xmls {
  my $in = shift @_;
  my $out = shift @_;

  my $cwd = MMisc::get_pwd();

  chdir($in);
  my $cmd = 'find . -name "*.xml"';
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call($cmd);
  MMisc::error_quit("Problem finding XML files: $stderr")
      if ($retcode != 0);
  chdir($cwd);

  my @files = split(m%\n%, $stdout);
  chomp @files;

  my %sets = &split_into_sets(@files);
  my @sl = keys %sets;

  print "Found: ", scalar @sl, " sets\n";

  my $inc = 0;
  foreach my $set (sort @sl) {
    print "|-> Processing Set ", ++$inc, " / ", scalar @sl, " [$set]\n";
    &process_set($set, $in, $out, @{$sets{$set}});
  }

}

####################

sub split_into_sets {
  my @fl = @_;

  my %res = ();
  foreach my $f (@fl) {
    my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($f);
    MMisc::error_quit("Problem splitting file name: $err")
        if (! MMisc::is_blank($err));
    # remove heading './', '/' and trailing '/'
    $dir =~ s%^\.\/%%;
    $dir =~ s%^\/%%;
    $dir =~ s%\/$%%;
    # Get just the filename
    my $fn = MMisc::concat_dir_file_ext("", $file, $ext);
    push @{$res{$dir}}, $fn;
  }
  
  return(%res);
}

####################

sub process_set {
  my $set_dir = shift @_;
  my $set_indir = shift @_;
  my $set_outdir = shift @_;
  my @set_files = @_;

  MMisc::error_quit("No XML files expected ?")
      if (scalar @set_files == 0);

  my $id = "$set_indir/$set_dir";
  my $err = MMisc::check_dir_r($id);
  MMisc::error_quit("Problem with input directory [$id]: $err")
      if (! MMisc::is_blank($err));
      
  my $od = "$set_outdir/$set_dir";
  MMisc::error_quit("Problem creating output directory [$od]")
      if (! MMisc::make_dir($od));

  my $logfile = "$od/set_run.log";
  my ($ok, $otxt, $stdout, $stderr, $retcode, $ofile) =
    MMisc::write_syscall_logfile($logfile, $tool, $id, $od);

  MMisc::error_quit("Problem while set processing, see logfile [$ofile]")
      if (! $ok);
  MMisc::error_quit("Problem processing set command, see logfile [$ofile]")
      if ($retcode != 0);

  print "|   |-> See run logfile [$ofile]\n";

  foreach my $file (@set_files) {
    my $of = "$od/$file";
    my ($size, $err) = MMisc::get_file_size($of);
    MMisc::error_quit("Problem while checking output file size [$of]: $err")
        if (! MMisc::is_blank($err));
    MMisc::error_quit("Output file is 0 [$of]")
        if ($size == 0);
  }

  print "|   |-> Set output files (", scalar @set_files, ") generated\n";
  print "|\n";
}
