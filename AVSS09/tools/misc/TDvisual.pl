#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrackingDetails to Visuals
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TDvisual" is an experimental system.
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

my $versionid = "Tracking Details to Visuals Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Image::Magick", "Math::Trig \':pi\'", "Getopt::Long") {
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

my @ok_modes = ('rect', 'circle');
my @ok_shapes = ('circle', 'polygon');
my $mode = $ok_modes[0];
my $poly = $ok_shapes[0];

my $usage = &set_usage();

my $ofile = "";
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'container=s' => \$mode,
   'shape=s' => \$poly,
   'output=s' => \$ofile,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("No TrackingDetails on the command line ?")
  if (scalar @ARGV == 0);

MMisc::error_quit("Too many arguments left on the command line, on \'TrackingDetails\' should be left ?")
  if (scalar @ARGV != 1);

my $test = shift @ARGV;

MMisc::error_quit("No \'output\' specified, aborting")
  if (MMisc::is_blank($ofile));

MMisc::error_quit("Wrong option for \'container\' ($mode), authorized values: " . join(" ", @ok_modes))
  if ((MMisc::is_blank($mode)) || (! (grep(m%^$mode$%, @ok_modes))));

MMisc::error_quit("Wrong option for \'shape\' ($poly), authorized values: " . join(" ", @ok_shapes))
  if ((MMisc::is_blank($poly)) || (! (grep(m%^$poly$%, @ok_shapes))));

my @colors = &process_text($test);

&do_plot($ofile);

MMisc::ok_quit("Done");

##########

sub do_plot {
  my ($fn) = @_;
  $fn .= ".png" if (! ($fn =~ m%\.png$%));

  my $image = Image::Magick->new;
  
  if ($mode eq 'rect') {
    &do_inrect($image);
  } else {
    &do_incircle($image);
  }
  my $err = $image->Write(filename => $fn, compression => 'None');
  MMisc::error_quit("Problem during file write : $err")
      if (! MMisc::is_blank($err));

  $err = MMisc::check_file_r($fn);
  MMisc::error_quit("Problem with output file ($fn) : $err")
      if (! MMisc::is_blank($err));

  print "Output file: $fn\n";
}

#####

sub prep_image {
  my ($image, $txt) = @_;
  $image->Set(size=>$txt);
  $image->ReadImage('xc:white');
}

#####

sub do_incircle {
  my ($image) = @_;

  my $txt = '1000x1000';
  &prep_image($image, $txt);
  my $div = &pi2 / (5.0 * (scalar @colors));

  my $prim = ($poly eq 'poly') ? 'polygon' : 'circle';
  for (my $i = 0; $i < scalar @colors; $i++) {
    my $c = $colors[$i];

    if ($poly eq 'poly') {
      my $c1 = cos($div*(5*$i));
      my $c2 = cos($div*((5*$i)+3));
      my $s1 = sin($div*(5*$i));
      my $s2 = sin($div*((5*$i)+3));
      
      $txt = sprintf("%d,%d %d,%d %d,%d %d,%d", 
                     500 + 490*$c1, 500 + 490*$s1,
                     500 + 490*$c2, 500 + 490*$s2,
                     500 + 460*$c2, 500 + 460*$s2,
                     500 + 460*$c1, 500 + 460*$s1);
    } else { # circles
      my $c1 = cos($div*(5*$i+2));
      my $s1 = sin($div*(5*$i+2));

      my $x = 500+(490*$c1);
      my $y = 500+(490*$s1);
      $txt = sprintf("%d,%d %d,%d", $x, $y, $x+2, $y+2);
    }

    my $err = $image->Draw('primitive'=>$prim, 'fill' => $c, 'points' => $txt);
    MMisc::error_quit("Problem during \'$prim\' plot : $err")
        if (! MMisc::is_blank($err));
  }
}

#####

sub do_inrect {
  my ($image) = @_;

  my $txt = sprintf("%dx20", 5*scalar(@colors));
  &prep_image($image, $txt);

  my $prim = ($poly eq 'poly') ? 'polygon' : 'circle';
  for (my $i = 0; $i < scalar @colors; $i++) {
    my $c = $colors[$i];
    
    if ($poly eq 'poly') {
      $txt = sprintf("%d,%d %d,%d %d,%d %d,%d", 
                     5*$i, 0,
                     5*$i + 3, 0,
                     5*$i + 3, 19,
                     5*$i, 19);
    } else { # circles
      my $v = 5*$i+2;
      $txt = sprintf("%d,%d,%d,%d", $v, 10, $v + 2, 12);
    }

    my $err = $image->Draw('primitive' => $prim, 'fill' => $c, 'points' => $txt);
    MMisc::error_quit("Problem during \'$prim\' plot : $err")
        if (! MMisc::is_blank($err));
  }
}

#################### 

sub process_text {
  my $text = shift @_;

  my $sp = '!';

  # Yellow for DCO
  # Green for Mapped
  # Red for MD
  # Orange for FA
  # Black for MD & FA
  my %vals = 
    ( 
     '.' => '#CCCCCC', # nothing
     ':' => '#FFFF00', # DCO
     '-' => '#FF0000', # MD
     '|' => '#FFA500', # FA
     '+' => '#000000', # MD & FA
     '@' => '#00FF00', # Mapped
     $sp => '#FF00FF',
    );


  my @res = ();
  while (my $c = substr($text, 0, 1, '')) {
    if (! exists $vals{$c}) {
#      print "Unknown entry [$c]\n";
      next;
    }

    if ($c eq $sp) {
      $res[-1] = $vals{$c};
      next;
    }

    push @res, $vals{$c};
  }

  return(@res);
}

########################################

sub set_usage {
  my $tokm = join(" ", @ok_modes);
  my $toks = join(" ", @ok_shapes);

  my $tmp=<<EOF
$versionid

$0 [--help] [--container mode] [--shape shape] --output file.png 'TrackingDetails'

Will generate a Tracking Details visual representation.

Where:
  --help     This help message
  --container  Specify the shape of the plot detail (valid modes are: $tokm)
  --shape    Specify the shape of the individual entry occurrences (valid modes are: $toks)
  --output   Specify the output PNG file

TrackingDetails code and corresponding Colors on the plot are:
  .    GREY       No Objects
  :    YELLOW     Don't Care REF
  -    RED        Missed Detect
  |    ORANGE     False Alarm
  +    BLACK      Missed Detect and False Alarm
  @    GREEN      Mapped REF to SYS
  !    PURPLE     Max Miss Detect rule was triggered

EOF
;

  return($tmp);
}
