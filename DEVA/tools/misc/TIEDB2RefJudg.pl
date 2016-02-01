#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
    if 0;

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# TrecVid Multimedia Event Detection Trial Index and EventDB to REF and Judgment
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid Event Detection EventDB to Threshold" is an experimental system.
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
foreach my $pn ("MMisc", "CSVHelper") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "TrecVid Event Detection Trial Index and EventDB to REF and Judgment ($versionkey)";

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

my $usage = &set_usage();
MMisc::error_quit("Usage:\n$usage\n") if (scalar @ARGV == 0);

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                                  h                   #

my $seed = undef;

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No arguments left on command line\n\n$usage\n")
  if (scalar @ARGV == 0);
MMisc::error_quit("Wrong argument count\n\n$usage\n")
  if (scalar @ARGV != 4);

my $eid = 'EventID';
my $null = 'NULL';

my $tid = 'TrialID';

my ($if1, $if2, $of1, $of2, $of3, $of4) = @ARGV;

##
my $randi = 0; # default random array increment
my $rands = 0;
my @randa = ();
srand($seed);
set_randa(10000);

##
my $icsvh1 = new CSVHelper();
MMisc::error_quit("Problem with input CSV1: " . $icsvh1->get_errormsg()) if ($icsvh1->error());
my %eventids = $icsvh1->loadCSV_tohash($if1, $eid);
MMisc::error_quit("Problem with input CSV1 ($if1): " . $icsvh1->get_errormsg()) if ($icsvh1->error());

##
my $icsvh2 = new CSVHelper();
MMisc::error_quit("Problem with input CSV2: " . $icsvh2->get_errormsg()) if ($icsvh2->error());
my %tids = $icsvh2->loadCSV_tohash($if2, $tid);
MMisc::error_quit("Problem with input CSV2 ($if2): " . $icsvh2->get_errormsg()) if ($icsvh2->error());

## REF
my $ocsvh1 = new CSVHelper();
my @ocsv1 = ($tid, 'Targ');
my $otxt1 = "";
my $randi1 = 1111;
MMisc::error_quit("Problem with output CSV1: " . $ocsvh1->get_errormsg()) if ($ocsvh1->error());
$ocsvh1->set_number_of_columns(scalar @ocsv1);
MMisc::error_quit("Problem with output CSV1 ($of1): " . $ocsvh1->get_errormsg()) if ($ocsvh1->error());
$otxt1 .= $ocsvh1->array2csvline(@ocsv1) . "\n";
MMisc::error_quit("Problem with output CSV1 ($of1): " . $ocsvh1->get_errormsg()) if ($ocsvh1->error());


## Judgement
my $ocsvh2 = new CSVHelper();
my @ocsv2 = ("ClipID",$eid,"INSTANCE_TYPE","SYNOPSIS","GENRE","TOPIC","SCENE","OBJECTS","ACTIVITIES","INSTANCE_VARIETY","INSTANCE_COMPLEXITY","VISUAL_EVIDENCE","AUDIO_EVIDENCE","TEXT_EVIDENCE","NON_ENG_SPEECH","NON_ENG_TEXT","NARRATIVE_AUDIO","NARRATIVE_TEXT","INSTANCE_COMMENT","PEOPLE","OTHER_VISUAL","SPEECH","NOISE","OTHER_AUDIO","EDITED_TEXT","EMBEDDED_TEXT","OTHER_TEXT");
my $otxt2 = "";
my $randi2 = 2222;
MMisc::error_quit("Problem with output CSV2: " . $ocsvh2->get_errormsg()) if ($ocsvh2->error());
$ocsvh2->set_number_of_columns(scalar @ocsv2);
MMisc::error_quit("Problem with output CSV2 ($of2): " . $ocsvh2->get_errormsg()) if ($ocsvh2->error());
$otxt2 .= $ocsvh2->array2csvline(@ocsv2) . "\n";
MMisc::error_quit("Problem with output CSV2 ($of2): " . $ocsvh2->get_errormsg()) if ($ocsvh2->error());

## Threshold
my $ocsvh3 = undef;
my @ocsv3 = ($eid, 'DetectionThreshold', 'DetectionTPT', 'EAGTPT');
my $otxt3 = "";
my $randi3 = 3333;
if (! MMisc::is_blank($of3)) {
  $ocsvh3 = new CSVHelper();
  MMisc::error_quit("Problem with output CSV3: " . $ocsvh3->get_errormsg()) if ($ocsvh3->error());
  $ocsvh3->set_number_of_columns(scalar @ocsv3);
  MMisc::error_quit("Problem with output CSV3 ($of3): " . $ocsvh3->get_errormsg()) if ($ocsvh3->error());
  $otxt3 .= $ocsvh3->array2csvline(@ocsv3) . "\n";
  MMisc::error_quit("Problem with output CSV3 ($of3): " . $ocsvh3->get_errormsg()) if ($ocsvh3->error());
}

## Decision
my $ocsvh4 = undef;
my @ocsv4 = ($tid, 'Score');
my $otxt4 = "";
my $randi4 = 4444;
if (! MMisc::is_blank($of4)) {
  $ocsvh4 = new CSVHelper();
  MMisc::error_quit("Problem with output CSV4: " . $ocsvh4->get_errormsg()) if ($ocsvh4->error());
  $ocsvh4->set_number_of_columns(scalar @ocsv4);
  MMisc::error_quit("Problem with output CSV4 ($of4): " . $ocsvh4->get_errormsg()) if ($ocsvh4->error());
  $otxt4 .= $ocsvh4->array2csvline(@ocsv4) . "\n";
  MMisc::error_quit("Problem with output CSV4 ($of4): " . $ocsvh4->get_errormsg()) if ($ocsvh4->error());
}

####################

my %clipids = ();
foreach my $tid (sort keys %tids) {
  my ($clipid, $eventid, @rest) = split(m%\.%, $tid);
  MMisc::error_quit("ClipID / EventID empty ?") if ((MMisc::is_blank($clipid)) || (MMisc::is_blank($eventid)));
  MMisc::error_quit("Extra info in TrialID: " . join(" | ", @rest)) if (scalar @rest > 0);
 
  my $val = &get_rand(1.0, \$randi1);
  @ocsv1 = ($tid, ($val > 0.9) ? 'y' : 'n');
  $otxt1 .= $ocsvh1->array2csvline(@ocsv1) . "\n";
  MMisc::error_quit("Problem with output CSV1: " . $ocsvh1->get_errormsg()) if ($ocsvh1->error());

  $clipids{$clipid}{$eventid} = $val;

  if (defined $ocsvh4) {
    @ocsv4 = ($tid, sprintf("%.03f", &get_rand(1.0, \$randi4)));
    $otxt4 .= $ocsvh4->array2csvline(@ocsv4) . "\n";
    MMisc::error_quit("Problem with output CSV4: " . $ocsvh4->get_errormsg()) if ($ocsvh4->error());
  }
}

if (defined $ocsvh3) {
  foreach my $event (sort keys %eventids) {
    next if ($event eq $null);
    @ocsv3 = ($event, sprintf("%.03f", 0.4 + &get_rand(0.6, \$randi3)), sprintf("%.02f", 10.0 + &get_rand(40, \$randi3)), sprintf("%.02f", &get_rand(20, \$randi3)));
    $otxt3 .= $ocsvh3->array2csvline(@ocsv3) . "\n";
    MMisc::error_quit("Problem with output CSV3: " . $ocsvh3->get_errormsg()) if ($ocsvh3->error());
  }
}

my @filler = (); for (my $i = 3; $i < scalar @ocsv2; $i++) { push @filler, ""; }
foreach my $clipid (sort keys %clipids) {
  my $used = 0;
  foreach my $eventid (sort keys %{$clipids{$clipid}}) {
    my $val = $clipids{$clipid}{$eventid};
    my $it = ($val > 0.9) ? 'positive' : ($val > 0.85) ? 'near_miss' : ($val > 0.8) ? 'related' : ($val > 0.75) ? 'not_sure' : $null;
#    print "$clipid / $val / $it\n";
    next if ($it eq $null);
    $used++;
    @ocsv2 = ($clipid, $eventid, $it, @filler);
    $otxt2 .= $ocsvh2->array2csvline(@ocsv2) . "\n";
    MMisc::error_quit("Problem with output CSV2: " . $ocsvh2->get_errormsg()) if ($ocsvh2->error());
  }
  if ($used == 0) {
    @ocsv2 = ($clipid, $null, $null, @filler);
    $otxt2 .= $ocsvh2->array2csvline(@ocsv2) . "\n";
    MMisc::error_quit("Problem with output CSV2: " . $ocsvh2->get_errormsg()) if ($ocsvh2->error());
  }
}

MMisc::error_quit("Problem writing file ($of1)")
  if (! MMisc::writeTo($of1, "", 1, 0, $otxt1));

MMisc::error_quit("Problem writing file ($of2)")
  if (! MMisc::writeTo($of2, "", 1, 0, $otxt2));

if (defined $ocsvh3) {
  MMisc::error_quit("Problem writing file ($of3)")
      if (! MMisc::writeTo($of3, "", 1, 0, $otxt3));
}

if (defined $ocsvh4) {
  MMisc::error_quit("Problem writing file ($of4)")
      if (! MMisc::writeTo($of4, "", 1, 0, $otxt4));
}

MMisc::ok_quit();

########## END

sub set_randa {
  for (my $i = 0; $i < $_[0]; $i++) {
    push @randa, rand();
  }
  $rands = scalar @randa;
}

#####

sub get_rand {
  MMisc::error_quit("Can not get pre computed rand() value from array (no content)")
    if ($rands == 0);
  my $mul = (defined $_[0]) ? $_[0] : 1;
  my $rs = (defined $_[1]) ? $_[1] : \$randi;
  my $v = $mul * $randa[$$rs];
  $$rs++;
  $$rs = 0 if ($$rs >= $rands);
  return($v);
}

#####



#####

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] EventDB.csv TrialIndex.csv Ref.csv Judgement.csv [threshold.csv detection.csv]

Input: EventDB.csv TrialIndex.csv
Output: Ref.csv Judgement.csv [threshold.csv detection.csv]

EOF
    ;

    return $tmp;
}

