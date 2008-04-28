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

my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;

# ViperFramespan (part of this tool)
unless (eval "use ViperFramespan; 1")
  {
    warn_print
      (
       "\"TrecVid08ViperFile\" is not available in your Perl installation. ",
       "It should have been part of this tools' files."
      );
    $have_everything = 0;
  }

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1")
  {
    warn_print
      (
       "\"Getopt::Long\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
      );
    $have_everything = 0;
  }

# Something missing ? Abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Options processing

# Default values for variables

my $usage = &set_usage();
my $ecff = "";
my $fps = -1;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:                               ef h             v    

my %opt;
my @leftover;
GetOptions
  (
   \%opt,
   'help',
   'version',
   'fps=s'           => \$fps,
   'ecffile:s'       => \$ecff,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

die("\n$usage\n") if (scalar @ARGV == 0);

die("ERROR: \'fps\' must set in order to do any scoring work") if ($fps == -1);

#################### Main processing

########## Read Input CSV Files
my $step = 1;
print "\n\n** STEP ", $step++, ": Read Input CSV files\n";
my @ecfh = ("SourceFile Filename", "Framespan"); # Order is important

my %all;
foreach my $csv (@ARGV) {
  open FILE, "<$csv"
    or die "ERROR: Could not open input CSV file ($csv): $!\n";

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
my %csvh;
foreach my $fn (sort keys %all) {
  my $fs_fs = $all{$fn};

  my $txt = "";
  my ($beg_ts, $end_ts) = $fs_fs->get_beg_end_ts();
  error_quit("Problem while getting the beginning and end timestamps (" . $fs_fs->get_errormsg() .")")
    if ($fs_fs->error());
  $txt .= "Beginning Timestamp does not start at 0. "
    if ($beg_ts != 0);

  my $v = $fs_fs->get_value();
  error_quit("Problem while getting the framespan's value (" . $fs_fs->get_errormsg() .")")
    if ($fs_fs->error());

  my $c = $fs_fs->count_pairs_in_value();
  error_quit("Problem while getting the framespan's pair count (" . $fs_fs->get_errormsg() .")")
    if ($fs_fs->error());
  $txt .= "Gap Detected (multiple pairs framespan: $v). " if ($c > 1);

  my $key = $fn;
  my $inc = 0;
  $csvh{$key}{$chead[$inc++]} = $fn;
  $csvh{$key}{$chead[$inc++]} = $beg_ts;
  $csvh{$key}{$chead[$inc++]} = $end_ts;
  $csvh{$key}{$chead[$inc++]} = $txt;
}
my $csvtxt = &do_csv(\@chead, %csvh);
if ($ecff ne "") {
  open ECFF, ">$ecff"
    or error_quit("Could not open \'ecffile\' ($ecff): $!");
  print ECFF $csvtxt;
  close ECFF;
} else {
  print $csvtxt;
}

die("Done.\n");


########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 --fps fps [--help] [--version] [--ecffile file.csv] file.csv [file.csv [...]]

Will Score the XML file(s) provided (Truth vs System)

 Where:
  --fps           Set the number of frames per seconds (float value) (also recognined: PAL, NTSC)
  --ecffile       Specify the output CSV file (stdout by default)
  --version       Print version number and exit
  --help          Print this usage information and exit
EOF
;

  return $tmp;
}

####################

sub warn_print {
  print "WARNING: ", @_;
}

##########

sub error_quit {
  print("${ekw}: ", @_);

  print "\n";
  exit(1);
}

##########

sub ok_quit {
  print @_;

  print "\n";
  exit(0);
}

########################################

sub split_csv_line {
  my $line = shift @_;

  my @elts = split(m%,%, $line);
  my @out;
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

  error_quit("There are not enought columns (", scalar @elts . ") in the CSV file to contained the required keys (" . join(",". @ecfh) . ")")
    if (scalar @elts < scalar @ecfh);

  my %pos;
  foreach my $key (@ecfh) {
    my $val = &find_key($key, @elts);
    error_quit("Could not find required CSV key header ($key)")
      if ($val == -1);
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

  if (! exists $all{$fn}) {
    my $fs_fs = new ViperFramespan($fs);
    error_quit("Problem creating a ViperFramespan [$fs] (" . $fs_fs->get_errormsg() . ")")
      if ($fs_fs->error());
    $fs_fs->set_fps($fps);
    error_quit("Problem setting the ViperFramespan's fps (" . $fs_fs->get_errormsg() . ")")
      if ($fs_fs->error());
    $all{$fn} = $fs_fs;
  } else {
    my $fs_fs = $all{$fn};
    $fs_fs->add_fs_to_value($fs);
    error_quit("Problem adding framespan ranges to ViperFramespan (" . $fs_fs->get_errormsg() . ")")
      if ($fs_fs->error());
  }
}

########################################


sub quc { # Quote clean
  my $in = shift @_;

  $in =~ s%\"%\'%g;

  return($in);
}

#####

sub qua { # Quote Array
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

  my @todo;
  foreach my $key (@keys) {
    error_quit("Problem accessing key ($key) from observation hash")
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
