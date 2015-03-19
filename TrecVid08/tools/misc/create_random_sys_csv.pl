#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 random CSV generator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 random CSV generator" is an experimental system.
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

my $versionid = "TrecVid08 random CSV Generator Version: $version";

##########
# Check we have every module (perl wise)

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
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "TrecVid08ViperFile", "TrecVid08Observation", "CSVHelper") {
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
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
my @ok_events = $dummy->get_full_events_list();
# We will use the '$dummy' to do checks before processing files

my @ok_csv_keys = TrecVid08Observation::get_ok_csv_keys();

########################################
# Options processing

my $entries = 100;
my $beg_def = 1;
my $th = 0.75;
my $usage = &set_usage();

# Default values for variables
my $writeto = "";
my @asked_events = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                               e  h   l       t vw     #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'writeTo=s'       => \$writeto,
   'limitto=s'       => \@asked_events,
   'entries=i'       => \$entries,
   'threshold=f'     => \$th,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("\'writeTo\' must be specified\n\n$usage\n")
  if (MMisc::is_blank($writeto));

MMisc::error_quit("\'threshold\' must be within 0 and 1 to be valid\n\n$usage\n")
    if (($th < 0) || ($th > 1));

my %eth = ();
if (scalar @asked_events == 0) {
  @asked_events = @ok_events;
} else {
    my @tmp_el = ();
    foreach my $entry (@asked_events) {
        if ($entry =~ m%^(\w+)\:(.+)$%) {
            MMisc::error_quit("Event ($1) \'threshold\' ($2) must be within 0 and 1 to be valid\n\n$usage\n")
                if (($2 < 0) || ($2 > 1));
            push @tmp_el, $1;
            $eth{$1} = $2;
#            print "[$1 / $2]\n";
        } else {
            push @tmp_el, $entry;
        }
    }
    @asked_events = @tmp_el;
    
  @asked_events = $dummy->validate_events_list(@asked_events);
  MMisc::error_quit("While checking \'limitto\' events list (" . $dummy->get_errormsg() .")")
    if ($dummy->error());
}

MMisc::ok_quit("Not enough arguments leftover, awaiting number of frames\n$usage\n") if (scalar @ARGV < 1);

MMisc::ok_quit("Too many arguments leftover, awaiting number of frames\n$usage\n") if (scalar @ARGV > 2);

my ($beg, $end) = ($beg_def, shift @ARGV);
if (scalar @ARGV == 1) { $beg = shift @ARGV; }

MMisc::error_quit("For \'end\'\'s \'beg:end\' values must follow: beg < end\n\n$usage\n")
  if ($end <= $beg);


# initialize random number
srand();

my $ocsvh = new CSVHelper();
my @oh = ($ok_csv_keys[9], $ok_csv_keys[0], $ok_csv_keys[1], $ok_csv_keys[2], $ok_csv_keys[3]);
$ocsvh->set_number_of_columns(scalar @oh);
my $ocsvtxt = "";
$ocsvtxt .= $ocsvh->array2csvline(@oh) . "\n";
MMisc::error_quit("Problem with output CSV : " . $ocsvh->get_errormsg())
  if ($ocsvh->error());

foreach my $event (@asked_events) {
  my $ne = int(rand($entries));
  my $lth = (exists $eth{$event}) ? 100.0*$eth{$event} : $th;
#  print "[$lth]\n";
  my @bl = ();
  for (my $i = 0; $i < $ne; $i++) { push @bl, $beg + int(rand($end-$beg)); }
  @bl = sort { $a <=> $b } @bl;
  my $inc = 0;
  foreach my $bv (@bl) {
    $inc++;
    $bv = ($bv >= $end) ? $bv - 100 : $bv;
    $bv = ($bv < $beg) ? $beg : $bv;
    my $ev = $bv + int(rand((2*$end) / $ne));
    $ev = ($ev >= $end) ? $end : $ev;
    my $ds = int(rand(100));
    my $dt = ($ds > $lth) ? 'true' : 'false';
    my @csvl = ($inc, $event, "$bv:$ev", sprintf("%0.03f", $ds / 100), $dt);
#    print join(" | ", @csvl) . "\n";
    $ocsvtxt .= $ocsvh->array2csvline(@csvl) . "\n";
    MMisc::error_quit("Problem with output CSV : " . $ocsvh->get_errormsg())
      if ($ocsvh->error());
  }
  print " - $event : " . scalar @bl . " entries\n";
}
MMisc::writeTo($writeto, "", 1, 0, $ocsvtxt);

MMisc::ok_exit();

########## END

sub set_usage {
  my $ro = join(" ", @ok_events);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--writeTo file.csv] [--limitto event1[:threshold1][,event2[:threshold2][,...]]] [--entries number] [--threshold float] end_framenumber [beg_framenumber]

Create a CSV file filled with random system entries.
Up to "number" random entries (default: $entries), potentially going from "beg_framenumber" (default: $beg_def) to "end_framenumber"

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --writeTo       File to write CSV values to
  --limitto       Only care about provided list of events. Also allow setting of per event threshold
  --entries       Maximum number of entries per event
  --threshold     Any 'DetectionScore' about this value will have a 'DetectionDecision' value of 'true' (default: $th)

Note:
 - List of recognized events: $ro
EOF
    ;

  return $tmp;
}
