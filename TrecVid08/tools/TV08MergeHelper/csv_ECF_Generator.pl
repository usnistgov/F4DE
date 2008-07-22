#!/usr/bin/env perl

# ECF Generator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "ECF Generator" is an experimental system.
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

my $versionid = "ECF Generator (Version: $version)";

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

# ViperFramespan (part of this tool)
unless (eval "use ViperFramespan; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
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
# Options processing

my $usage = &set_usage();

# Default values for variables
my $csvf = -1;
my $ecff = "";
my $fps = -1;
my $ecfVersionAttr = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# USed:     E                       c ef h             v     #

my %opt = ();
my @leftover = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'fps=s'           => \$fps,
   'csv:s'           => \$csvf,
   'ecffile=s'       => \$ecff,
   'EcfVersion=s'    => \$ecfVersionAttr,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'fps\' must set in order to do any scoring work") if ($fps == -1);
MMisc::error_quit("No mode selected, must at least do one of csv or ecf output") if (($csvf == -1) && ($ecff eq ""));
MMisc::error_quit("\'EcfVersion\' must be set if \'ecffile\' selected") if (($ecff ne "") && ($ecfVersionAttr eq ""));

#################### Main processing

########## Read Input CSV Files
my $step = 1;
print "\n\n** STEP ", $step++, ": Read Input CSV files\n";
my @ecfh = ("SourceFile Filename", "Framespan", "FPS"); # Order is important

my %all = ();
foreach my $csv (@ARGV) {
  open FILE, "<$csv"
    or MMisc::error_quit("ERROR: Could not open input CSV file ($csv): $!\n");

  # Check the CVS header is fine and get the position of the keys
  my $header = <FILE>;
  my %pos = &check_csv_header($header);

  # Now process line per line
  while (my $line = <FILE>) {
    &process_csv_line($line, %pos)
  }

  print "$csv: read\n";
}

########## Generating Report
print "\n\n** STEP ", $step++, ": Geneating report\n";

my @chead = ("Sourcefile Filename", "Beg ts", "End ts", "Comment"); # Order is important
my %csvh = ();
foreach my $fn (sort keys %all) {
  my $fs_fs = $all{$fn};

  my $txt = "";
  my ($beg_ts, $end_ts) = $fs_fs->get_beg_end_ts();
  MMisc::error_quit("Problem while getting the beginning and end timestamps (" . $fs_fs->get_errormsg() .")")
    if ($fs_fs->error());
  $txt .= "Beginning Timestamp does not start at 0. "
    if ($beg_ts != 0);

  my $v = $fs_fs->get_value();
  MMisc::error_quit("Problem while getting the framespan's value (" . $fs_fs->get_errormsg() .")")
    if ($fs_fs->error());

  my $c = $fs_fs->count_pairs_in_value();
  MMisc::error_quit("Problem while getting the framespan's pair count (" . $fs_fs->get_errormsg() .")")
    if ($fs_fs->error());
  $txt .= "Gap Detected (multiple pairs framespan: $v). " if ($c > 1);

  my $key = $fn;
  my $inc = 0;
  $csvh{$key}{$chead[$inc++]} = $fn;
  $csvh{$key}{$chead[$inc++]} = $beg_ts;
  $csvh{$key}{$chead[$inc++]} = $end_ts;
  $csvh{$key}{$chead[$inc++]} = $txt;
}

if ($csvf != -1) {
  my $csvtxt = &do_csv(\@chead, %csvh);
  MMisc::writeTo($csvf, "", 1, 0, $csvtxt);
}

########## Generating ECF
if ($ecff ne "") {
  print "\n\n** STEP ", $step++, ": Geneating ECF in '$ecff'\n";

  my $ssd = 0;
  foreach my $fn (sort keys %all) {
    my $fs_fs = $all{$fn};
    $ssd += $fs_fs->duration_ts();
  }

  my $ecftxt = "";
  $ecftxt .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  $ecftxt .= "<ecf>\n";
  $ecftxt .= "   <source_signal_duration>" . sprintf("%.3f",$ssd) . "</source_signal_duration>\n";
  $ecftxt .= "   <version>$ecfVersionAttr</version>\n";
  $ecftxt .= "   <excerpt_list>\n";
  foreach my $fn (sort keys %all) {
    my $fs_fs = $all{$fn};
    my $sub_fs_list = $fs_fs->get_list_of_framespans();
    MMisc::error_quit("Failed to get sub framespans " . $fs_fs->get_errormsg())
      if (! defined($sub_fs_list));
    foreach my $fs (@$sub_fs_list) {
      $ecftxt .= "       <excerpt>\n";
      $ecftxt .= "           <!--  Framespan " . $fs->get_value() . " -->\n";
      $ecftxt .= "           <filename>$fn</filename>\n";
      $ecftxt .= "           <begin>" . $fs->get_beg_ts() . "</begin>\n";
      $ecftxt .= "           <duration>" . $fs->duration_ts() . "</duration>\n";
      $ecftxt .= "           <sample_rate>" . $fs->get_fps() . "<sample_rate>\n";
      $ecftxt .= "           <language>english</language>\n";
      $ecftxt .= "           <source_type>surveillance</source_type>\n";
      $ecftxt .= "       </excerpt>\n";
    }
  }
  $ecftxt .= "   </excerpt_list>\n";
  $ecftxt .= "</ecf>\n";

  MMisc::error_quit("Error: Unable to do the ECF file")
    if (! MMisc::writeTo($ecff, "", 1, 0, $ecftxt));
}

MMisc::ok_quit("Done.\n");


########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 --fps fps [--help] [--version] [[--csv [file.csv]] | [--ecffile file --EcfVersion versionid]] file.csv [file.csv [...]]

Will Score the XML file(s) provided (Truth vs System)

 Where:
  --fps           Set the number of frames per seconds (float value) (also recognined: PAL, NTSC)
  --ecffile       Specify the output ECF file
  --EcfVersion    Specify the version ID to add in the ECF file
  --csv           Specify the output CSV file (stdout by default)
  --version       Print version number and exit
  --help          Print this usage information and exit
EOF
    ;

    return $tmp;
}

####################

sub _warn_add {
  $warn_msg .= sprint("[Warning] ", join(" ", @_), "\n");
}

########################################

sub split_csv_line {
  my $line = shift @_;

  my @elts = split(m%,%, $line);
  my @out = ();
  foreach my $elt (@elts) {
    $elt =~ s%^\s+%%;
    $elt =~ s%\s+$%%;
    $elt =~ s%^\"%%;
    $elt =~ s%\"$%%;
    push @out, $elt;
  }

  return(@out);
}

########################################

sub find_key {
  my $key = shift @_;
  my @elts = @_;

  for (my $i = 0; $i < scalar @elts; $i++) {
    return($i) if ($elts[$i] =~ m%^$key$%);
  }

  return(-1);
}

#####

sub check_csv_header {
  my $header = shift @_;

  my @elts = &split_csv_line($header);

  MMisc::error_quit("There are not enought columns (", scalar @elts . ") in the CSV file to contained the required keys (" . join(",". @ecfh) . ")")
    if (scalar @elts < scalar @ecfh);

  my %pos = ();
  foreach my $key (@ecfh) {
    my $val = &find_key($key, @elts);
    if ($val == -1) {
      MMisc::error_quit("Could not find required CSV key header ($key)")
        if ($key ne $ecfh[-1]);
      # FPS was optional for a while, so skip if not found
      next;
    }
    $pos{$key} = $val;
  }

  return(%pos);
}

########################################

sub process_csv_line {
  my $line = shift @_;
  my %pos = @_;

  my @elts = &split_csv_line($line);

  my $fn = $elts[$pos{$ecfh[0]}];
  my $fs = $elts[$pos{$ecfh[1]}];
  my $ffps = $fps;              # Set a default value
  # and override if it was given
  $ffps = $elts[$pos{$ecfh[2]}]
    if (exists $pos{$ecfh[2]});

  if (! exists $all{$fn}) {
    my $fs_fs = new ViperFramespan($fs);
    MMisc::error_quit("Problem creating a ViperFramespan [$fs] (" . $fs_fs->get_errormsg() . ")")
      if ($fs_fs->error());
    $fs_fs->set_fps($ffps);
    MMisc::error_quit("Problem setting the ViperFramespan's fps (" . $fs_fs->get_errormsg() . ")")
      if ($fs_fs->error());
    $all{$fn} = $fs_fs;
  } else {
    my $fs_fs = $all{$fn};
    my $tfps = $fs_fs->get_fps();
    MMisc::error_quit("Problem obtaining framespan's fps (" . $fs_fs->get_errormsg() . ")")
      if ($fs_fs->error());
    MMisc::error_quit("New entry's fps ($tfps) is different from the previously given value ($ffps)")
      if ($tfps != $ffps);

    $fs_fs->add_fs_to_value($fs);
    MMisc::error_quit("Problem adding framespan ranges to ViperFramespan (" . $fs_fs->get_errormsg() . ")")
      if ($fs_fs->error());
  }
}

########################################


sub quc {                       # Quote clean
  my $in = shift @_;

  $in =~ s%\"%\'%g;

  return($in);
}

#####

sub qua {                       # Quote Array
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

  my @todo = ();
  foreach my $key (@keys) {
    MMisc::error_quit("Problem accessing key ($key) from observation hash")
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
