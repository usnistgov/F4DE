#!/usr/bin/env perl

# Fix Englobing FrameSpans
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Fix Englobing FrameSpans" is an experimental system.
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

my $versionid = "Fix Englobing FrameSpans Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../../common/lib");
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
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "ViperFramespan") {
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

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

my $doit = 0;
my @fl = ();
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'doit' => \$doit,
   '<>' => sub { my ($f) = @_; my $err = MMisc::check_file_w($f); MMisc::error_quit("Problem with input file ($f): $err") if (! MMisc::is_blank($err)); push @fl, $f; },
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @fl == 0);

if ($doit) {
  print "!!!!! REAL run mode !!!!!\n";
  print " Waiting 5 seconds (Ctrl+C to cancel)\n";
  sleep(5);
} else {
  print "********** DRYRUN mode **********\n";
}

my $maxv = 0;
my %replc = ();
foreach my $fn (@fl) {
  my $f = MMisc::slurp_file($fn);
  MMisc::error_quit("Problem slurping file [$fn]") if (! defined $f);

  my $g = $f;

  %replc = ();
  $maxv = 0;
  $g = &processit($g);
  $g = &numframes($g, \$maxv);
  
  if ($g ne $f) {
    print "\n** $fn changes: \n";
    if ((scalar(keys %replc) == 0) && (MMisc::is_blank($maxv))) {
      MMisc::writeTo("/tmp/bad.xml", "", 1, 0, $g);
      MMisc::error_quit("Unknown replacement");
    }

    if (scalar keys %replc != 0) {
      foreach my $type (keys %replc) {
        foreach my $id (keys %{$replc{$type}}) {
          print " - [TYPE: $type] [ID $id] " . $replc{$type}{$id} . "\n";
        }
      }
    }

    print " - $maxv\n"
      if (! MMisc::is_blank($maxv));

    if ($doit) {
      MMisc::error_quit("Problem writing output file [$fn]")
          if (! MMisc::writeTo($fn, "", 1, 0, $g));
    }
  }

}

MMisc::ok_quit("Done\n");

####################

sub numframes {
  my ($fc, $rmaxv) = @_;

  $fc =~ s%(<attribute\s+name\s*=\s*\"NUMFRAMES\">.*?<data:dvalue\s+value\s*=\s*\"\d+\"\/>.*?</attribute>)%&process_numframes($1, $rmaxv)%sge;
  MMisc::error_quit("Could not modify NUMFRAMES [$1]")
      if (MMisc::is_integer($$rmaxv));

  return($fc);
}

#####

sub process_numframes {
  my ($x, $rmaxv) = @_;

  MMisc::error_quit("Could not extract NUMFRAMES value")
      if (! ($x =~ m%<data:dvalue\s+value\s*=\s*\"\d+\"\/>%));
  my $v = $1;

  if ($v < $$rmaxv) {
    $$rmaxv = "";
    return($x);
  }

  # else
  my $t = $$rmaxv;
  $$rmaxv = "Extended NUMFRAMES from $v to $t";

  MMisc::error_quit("Could not change NUMFRAMES' value")
      if (! ($x =~ s%(<data:dvalue\s+value\s*=\s*\")\d+(\"\/>)%$1$t$2%));

  return($x);
}

####################

sub processit {
  my ($fc) = @_;

  $fc =~ s%(<object\s.+?</object>)%&process_content($1)%sge;

  return($fc);
}

#####

sub process_content {
  my ($v) = @_;

  MMisc::error_quit("Could not extract object header (ID)")
      if (! ($v =~ m%^<object\s+.*?id\s*\=\s*\"(\d+)\".*?\>%s));
  my $id = $1;
 
  MMisc::error_quit("Could not extract object header (object type)")
      if (! ($v =~ m%^<object\s+.*?name\s*\=\s*\"([^\"]+?)\".*?\>%s));
  my $type = $1;

  MMisc::error_quit("Could not extract object header (framespan)")
      if (! ($v =~ m%^<object\s+.*?framespan\s*\=\s*\"([^\"]+?)\".*?\>%s));
  my $gfs = $1;

  my $fs_gfs= new ViperFramespan($gfs);
  MMisc::error_quit("Problem with ViperFramespan: " . $fs_gfs->get_errormsg())
      if ($fs_gfs->error());
  $gfs = $fs_gfs->get_value(); # optimized version
  my ($b1, $e1) = $fs_gfs->get_beg_end_fs();
  $maxv = MMisc::max($maxv, $e1);

  $v =~ s%(<attribute\s*([^\>]*?\/>|.+?<\/attribute>))%&process_attribute($id, $type, $fs_gfs, $1)%sge;

  my $new_gfs = $fs_gfs->get_value();

  if ($new_gfs ne $gfs) {
    MMisc::error_quit("Could not replace object header (framespan)")
      if (! ($v =~ s%^(<object\s+.*?framespan\s*\=\s*\")([^\"]+?)(\".*?\>)%$1$new_gfs$3%s));
    my ($b2, $e2) = $fs_gfs->get_beg_end_fs();
    $maxv = MMisc::max($maxv, $e2);

    my $txt = "Extended from [$b1;$e1] to [$b2;$e2]";
    $replc{$type}{$id} = $txt;
    print "[$txt]\n";
  }
  
  return($v);
}

##########

sub process_attribute {
  my ($id, $type, $fs_gfs, $v) = @_;

  $v =~ s%(<data\:\w+\s+.+?\/\>)%&process_datablock($id, $type, $fs_gfs, $1)%sge;

  return($v);
}

##########

sub process_datablock {
  my ($id, $type, $fs_gfs, $v) = @_;

  if (! ($v =~ m%framespan\s*\=\s*\"([^\"]+?)\"%)) {
    MMisc::warn_print("Could not extract framespan from line [$v]");
    return($v);
  }
  my $fs = $1;

  my $fs_fs = new ViperFramespan($fs);
  MMisc::error_quit("Problem with ViperFramespan: " . $fs_fs->get_errormsg())
      if ($fs_fs->error());

  my $iw = $fs_fs->is_within($fs_gfs);
  MMisc::error_quit("Problem while \"is_within\" ViperFramespan: " . $fs_fs->get_errormsg())
      if ($fs_fs->error());
  if (! $iw) {
    $fs_gfs->add_fs_to_value($$fs);
    MMisc::error_quit("Problem adding framespan ($fs) to global framespan: " . $fs_gfs->get_errormsg())
        if ($fs_gfs->error());
  }

  # We did not really replace anything, but used the 'sed' to call this function
  return($v);
}

########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--doit] xmlfiles

Try to extend every <object>'s \"framespan\" to add entries from its <attributes> that are outside its boundaries. Also extend NUMFRAMES if needed.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --doit          Perform modification (safer to do one pass without this option and rerun it with it once it exits wihtout error)

IMPORTANT NOTE: Modify files specified on the command line
EOF
;
  
  return($tmp);
}
