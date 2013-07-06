#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# sorter.pl
#
# Author(s): Martial Michel
#

# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "sorter.pl" is an experimental system.
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


# $Id$

use strict;
#use Data::Dumper;

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../../common/lib");
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
foreach my $pn ("MMisc", "CSVHelper") {
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
# Options processing

my $splitsize = 4;
my $splitdim  = 4;
my $usage = &set_usage();
MMisc::error_quit($usage) if (scalar @ARGV == 0);

# Default values for variables
my @sortCol = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                                  h          s         #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'sortColumns=s'  => \@sortCol,
   'indexSplitSize=i'    => \$splitsize,
   'IndexSplitCount=i'   => \$splitdim,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if (($opt{'help'}) || (scalar @ARGV == 0));

MMisc::error_quit($usage) 
  if (scalar @ARGV != 2);

my ($in, $out) = @ARGV;

open IFILE, "<$in"
  or MMisc::error_quit("Problem opening input file ($in) : $!");
open OFILE, ">$out"
  or MMisc::error_quit("Problem opening output file ($out) : $!");

my $icsvh = new CSVHelper();
my $ocsvh = new CSVHelper();


########## Read file
print "** Reading input file\n";
my $now = MMisc::get_currenttime();
my $ish = 0;
my $inlc = 0;
my %colm = ();
my %name = ();
my %content = ();
my @split = ();
my $tmp;

# Read first line (header)
my $line = <IFILE>;
my @inh = $icsvh->csvline2array($line);
MMisc::error_quit("Problem with input CSV : " . $icsvh->get_errormsg() . "\n[Line $ish : $line]")
  if ($icsvh->error());
$ish++;

&get_colm(@inh);
$icsvh->set_number_of_columns(scalar @inh);
foreach my $k (@sortCol) {
  next if (exists $colm{$k});
  MMisc::error_quit("Required \'sortColumns\' not found ($k)");
}

my @rest = ();
while ($line = <IFILE>) {
  print "  Line: $ish    \r" if (++$ish % 1000 == 0);
  @inh = ();
  @inh = $icsvh->csvline2array($line);
  MMisc::error_quit("Problem with input CSV : " . $icsvh->get_errormsg() . "\n[Line $ish : $line]")
      if ($icsvh->error());

  my $val = $inh[$colm{$sortCol[0]}];
#  print "  [$val]  \r";
  &get_split($val);
#  print join("|", @split) . " = $val\n";
  MMisc::push_tohash(\%name, $val, @split)
    if (! exists $content{$val});
  @rest = ();
  for (my $i = 1; $i < scalar @sortCol; $i++) { push @rest, $inh[$colm{$sortCol[$i]}]; }
  push @{$content{$val}}, \@rest;

  $line = "";
}
close IFILE;
my $elapsed = MMisc::get_elapsedtime($now);
print "  (elapsed: $elapsed)   \n";

########## Write file
print "** Writing output file\n";
my $now = MMisc::get_currenttime();
my $gosh = 0;
my $osh = 0;
$ocsvh->set_number_of_columns(scalar @sortCol);
my $otxt = $ocsvh->array2csvline(@sortCol);
$otxt .= "\n";
MMisc::error_quit("Problem with output CSV [at header]: " . $ocsvh->get_errormsg())
  if ($ocsvh->error());
$osh++;

sub write_file {
  my ($dim, $rh) = @_;

  if ($dim == 1) {
    foreach my $key (sort keys %{$rh}) {
      foreach my $lname (sort @{$$rh{$key}}) {
        for (my $i = 0; $i < scalar @{$content{$lname}}; $i++) {
          $otxt .= $ocsvh->array2csvline($lname, @{${$content{$lname}}[$i]});
          $otxt .= "\n";
          MMisc::error_quit("Problem with output CSV [at $lname]: " . $ocsvh->get_errormsg())
            if ($ocsvh->error());
          $osh++;
        }
      }
    }
    if ($osh > 1000) {
      $gosh += $osh;
      print "  Line: $gosh  \r";
      print OFILE "$otxt";
      $otxt = "";
      $osh = 0;
    }
    return();
  }
  
  foreach my $key (sort keys %{$rh}) {
    &write_file($dim - 1, \%{$$rh{$key}});
  }
}

&write_file($splitdim, \%name);
print OFILE "$otxt";
$gosh += $osh;
close OFILE;
my $elapsed = MMisc::get_elapsedtime($now);
print "  (elapsed: $elapsed)   \n";

MMisc::ok_quit("Done (processed $ish lines in / $gosh lines out)\n");

####################

sub get_colm {
  for (my $i = 0; $i < scalar @_; $i++) {
    my $v = $_[$i];
    $colm{$v} = $i;
  }
}

#####

sub get_split {
  for (my $i = 0; $i < $splitdim; $i++) {
    $tmp = substr($_[0], $splitsize * $i, $splitsize);
    $split[$i] =  ((! defined $tmp) || ($tmp eq '')) ? "\0" : $tmp;
  }
}

####################

sub set_usage{
  my $tmp=<<EOF

$0 [--help] --sortColumns colname [--sortColumnes colname [...]] [--indexSplitSize charactercount] [--IndexSplitCount dimension] infile.csv outfile.csv

Copy ONLY columns provided using \'sortColumns\' (in the order given) fron infile.csv to outfile.csv, sorting each line read in alphabetical order (based on first column)

Where:
  --help        This help message
  --sortColumns  Order in which columns listed in outfile
  --indexSplitSize    For large number of lines a quick sort index is created, this value contains the size of the number of characters to split at (default: $splitsize)
  --IndexSplitCount   Number of dimensions of index (default: $splitdim)

EOF
;

  return($tmp);
}
