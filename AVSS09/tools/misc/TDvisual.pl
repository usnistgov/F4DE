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

my $versionid = "Tracking Details to Visuals Version: $version";

##########
# Check we have every module (perl wise)

my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
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
my $shape = $ok_shapes[0];

my $usage = &set_usage();
MMisc::error_quit($usage) if (scalar @ARGV == 0);

my $ofile = "";
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'container=s' => \$mode,
   'shape=s' => \$shape,
   'output=s' => \$ofile,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("Too many arguments on hte command line\n$usage")
  if (scalar @ARGV > 2);

MMisc::error_quit("No TrackingDetails File specified\n$usage")
  if (scalar @ARGV == 0);

MMisc::error_quit("No \'output\' specified, aborting\n$usage")
  if (MMisc::is_blank($ofile));

MMisc::error_quit("Wrong option for \'container\' ($mode), authorized values: " . join(" ", @ok_modes))
  if ((MMisc::is_blank($mode)) || (! (grep(m%^$mode$%, @ok_modes))));

MMisc::error_quit("Wrong option for \'shape\' ($shape), authorized values: " . join(" ", @ok_shapes))
  if ((MMisc::is_blank($shape)) || (! (grep(m%^$shape$%, @ok_shapes))));

my $if = shift @ARGV;
open FILE, "<$if"
  or MMisc::error_quit("Problem with input file ($if) : $!");

my @all = ();
while (my $entry =<FILE>) {
  chomp $entry;

  my @colors = &process_text($entry);
  push @all, \@colors;
}

&do_plot($ofile, @all);

MMisc::ok_quit("Done");

##########

sub do_plot {
  my ($fn, @entries) = @_;
  $fn .= ".png" if (! ($fn =~ m%\.png$%));

  my $image = Image::Magick->new;

  my ($max_x, $max_y) = 0;
  foreach my $entry (@entries) {
    $max_y++;
    my $v = scalar @{$entry};
    $max_x = $v if ($v > $max_x);
  }
  
  if ($mode eq 'rect') {
    &do_inrect($image, $max_x, $max_y, @entries);
  } else {
    &do_incircle($image, $max_x, $max_y, @entries);
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
  my ($image, $max_x, $max_y, @entries) = @_;
  
  my $side = 1000 + ($max_y*20);
  my $txt = sprintf('%dx%d', $side, $side);
  my $center = sprintf("%d", $side / 2);
  &prep_image($image, $txt);
  
  my $div = &pi2 / (5.0 * $max_x);
    
  for (my $inc = 0; $inc < scalar @entries; $inc++) {
    my @colors = @{$entries[$inc]};
    
    for (my $i = 0; $i < scalar @colors; $i++) {
      my $c = $colors[$i];
      
      if ($shape eq $ok_shapes[1]) {
        my $c1 = cos($div*(5*$i));
        my $c2 = cos($div*((5*$i)+3));
        my $s1 = sin($div*(5*$i));
        my $s2 = sin($div*((5*$i)+3));
        
        $txt = sprintf(
          "%d,%d %d,%d %d,%d %d,%d", 
          $center + (($center - 10)-(20*$inc))*$c1,
          $center + (($center - 10)-(20*$inc))*$s1,
          $center + (($center - 10)-(20*$inc))*$c2,
          $center + (($center - 10)-(20*$inc))*$s2,
          $center + (($center - 27)-(20*$inc))*$c2,
          $center + (($center - 27)-(20*$inc))*$s2,
          $center + (($center - 27)-(20*$inc))*$c1,
          $center + (($center - 27)-(20*$inc))*$s1
          );
      } else { # circles
        my $c1 = cos($div*(5*$i+2));
        my $s1 = sin($div*(5*$i+2));
        
        my $x = $center+((($center - 10)-(20*$inc))*$c1);
        my $y = $center+((($center - 10)-(20*$inc))*$s1);
        $txt = sprintf("%d,%d %d,%d", $x, $y, $x+2, $y+2);
      }

      my $err = $image->Draw('primitive'=>$shape, 'fill' => $c, 'points' => $txt);
      MMisc::error_quit("Problem during \'$shape\' plot : $err")
        if (! MMisc::is_blank($err));
    }
  }
}

#####

sub do_inrect {
  my ($image, $max_x, $max_y, @entries) = @_;

  my $txt = sprintf("%dx%d", 5*$max_x, 20*$max_y);
  &prep_image($image, $txt);

  for (my $inc = 0; $inc < scalar @entries; $inc++) {
    my @colors = @{$entries[$inc]};
    
    for (my $i = 0; $i < scalar @colors; $i++) {
      my $c = $colors[$i];
      
      if ($shape eq $ok_shapes[1]) {
        $txt = sprintf(
          "%d,%d %d,%d %d,%d %d,%d", 
          5*$i, 20*$inc,
          5*$i + 3, 20*$inc,
          5*$i + 3, (20*$inc)+17,
          5*$i, (20*$inc) + 17
          );
      } else { # circles
        my $v = (5*$i)+2;
        $txt = sprintf("%d,%d,%d,%d", $v, 10 + (20 * $inc), $v + 2, 12 + (20 * $inc));
      }

      my $err = $image->Draw('primitive' => $shape, 'fill' => $c, 'points' => $txt);
      MMisc::error_quit("Problem during \'$shape\' plot : $err")
        if (! MMisc::is_blank($err));
    }
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

$0 [--help] [--container mode] [--shape shape] --output file.png TrackingDetailsFile

Will generate a Tracking Details visual representation. Each new line from the TrackingDetailsFile is considered as a new entry to process

Where:
  --help     This help message
  --container  Specify the shape of the plot detail (valid modes are: $tokm) [default: $mode]
  --shape    Specify the shape of the individual entry occurrences (valid modes are: $toks) [default: $shape]
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
