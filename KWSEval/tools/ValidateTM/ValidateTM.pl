#!/usr/bin/env perl

# ValidateXTM
# Authors: Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# KWSEval is an experimental system.  
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

##########
# Version

# $Id$
my $version     = "0.1b";
if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}
my $versionid = "ValidateXTM Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../lib", "$f4d/../../../common/lib");
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
foreach my $pn ("KWSecf", "KWSEvalSTM", "KWSEvalCTM", "MMisc") {
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

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

####################

my $ECFfile = "";
my $CTMfile = "";
my $STMfile = "";

GetOptions
  (
   'ECF=s'    => \$ECFfile,
   'STM=s'    => \$STMfile,
   'CTM=s'    => \$CTMfile,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::error_quit("$usage")
  if (MMisc::all_blank($ECFfile, $CTMfile, $STMfile));

my $ECF = undef;
if (! MMisc::is_blank($ECFfile)) {
  my $err = MMisc::check_file_r($ECFfile);
  MMisc::error_quit("Problem with \'--ECF\' file ($ECFfile): $err")
      if (! MMisc::is_blank($err));
  $ECF = new KWSecf($ECFfile);
}

my $STM = undef;
if (! MMisc::is_blank($STMfile)) {
  my $err = MMisc::check_file_r($STMfile);
  MMisc::error_quit("Problem with \'--STM\' file ($STMfile): $err")
      if (! MMisc::is_blank($err));
  $STM = new KWSEvalSTM($STMfile);
  MMisc::error_quit("Problem with STM file: " . $STM->get_errormsg())
      if ($STM->error());
}

my $CTM = undef;
if (! MMisc::is_blank($CTMfile)) {
  my $err = MMisc::check_file_r($CTMfile);
  MMisc::error_quit("Problem with \'--CTM\' file ($CTMfile): $err")
      if (! MMisc::is_blank($err));
  $CTM = new KWSEvalCTM($CTMfile);
  MMisc::error_quit("Problem with CTM file: " . $CTM->get_errormsg())
      if ($CTM->error());
}

####################
my %all = ();

my @stm_list = ();
my %stm_hash = ();
if (defined $STM) {
  @stm_list = $STM->get_fulllist();
  MMisc::error_quit("Problem obtaining content list from STM file: " . $STM->get_errormsg())
      if ($STM->error());
  for (my $i = 0; $i < scalar @stm_list; $i++) {
    my ($file, $channel, $bt, $et) = @{$stm_list[$i]};
    @{$stm_hash{$file}{$channel}} = [$bt, $et];
    $all{$file}{$channel}++;
  }
}

my @ctm_list = ();
my %ctm_hash = ();
if (defined $CTM) {
  @ctm_list = $CTM->get_fulllist();
  MMisc::error_quit("Problem obtaining content list from CTM file: " . $CTM->get_errormsg())
      if ($CTM->error());
  for (my $i = 0; $i < scalar @ctm_list; $i++) {
    my ($file, $channel, $bt, $et) = @{$ctm_list[$i]};
    @{$ctm_hash{$file}{$channel}} = [$bt, $et];
    $all{$file}{$channel}++;
  }
}

####################
my $errc = 0;

## CTM vs STM
if (defined $CTM && defined $STM) {
  my %tmp = ();
  foreach my $file (keys %all) {
    foreach my $channel (keys %{$all{$file}}) {
      if (! MMisc::safe_exists(\%ctm_hash, $file, $channel)) {
        MMisc::warn_print("[File: $file / Channel: $channel] does not exist in CTM file");
        $errc++;
      }
      if (! MMisc::safe_exists(\%stm_hash, $file, $channel)) {
        MMisc::warn_print("[File: $file / Channel: $channel] does not exist in STM file");
        $errc++;
      }
    }
  }
}

# CTM vs ECF
if (defined $CTM && defined $ECF) {
  for (my $i = 0; $i < scalar @ctm_list; $i++) {
    my ($file, $channel, $bt, $et) = @{$ctm_list[$i]};
    if ($ECF->FilteringTime($file, $channel, $bt, $et) == 0) {
      MMisc::warn_print("CTM's Entry [File: $file / Channel: $channel / Begtime: $bt / Endtime: $et] is not withing ECF's boundaries");
      $errc++;
    }
  } 
}

# STM vs ECF
if (defined $STM && defined $ECF) {
  for (my $i = 0; $i < scalar @stm_list; $i++) {
    my ($file, $channel, $bt, $et) = @{$stm_list[$i]};
    if ($ECF->FilteringTime($file, $channel, $bt, $et) == 0) {
      MMisc::warn_print("STM's Entry [File: $file / Channel: $channel / Begtime: $bt / Endtime: $et] is not withing ECF's boundaries");
      $errc++;
    }
  } 
}

MMisc::ok_quit("No problems detected, files pass validation") if ($errc == 0);
MMisc::error_quit("Some problems were detected");


############################################################


sub set_usage {
  my $usage = "$0 [--ECF ecfile] [--STM stmfile] [--CTM ctmfile]\n";
  $usage .= "\n";
  $usage .= "Will validate the ECF, STM or CTM by themselves or against one another\n";
  $usage .= "At least one must be specified\n";
  $usage .= "\n";
  $usage .= "  --ECF       Path to the ECF file\n";
  $usage .= "  --STM       Path to the STM file\n";
  $usage .= "  --CTM       Path to the STM file\n";
  $usage .= "\n";
  
  return($usage);
}
