#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#
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

# Part of this tool
foreach my $pn ("MMisc", "ViperFramespan") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "Fix Englobing FrameSpans ($versionkey)";

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
my $verb = 0;
my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'doit' => \$doit,
   'Verb' => \$verb,
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

my %replc = ();
my %tmp_fsh = ();
foreach my $fn (@fl) {
  print "\n[*] Processing [$fn]\n" if ($verb);
  my $f = MMisc::slurp_file($fn);
  MMisc::error_quit("Problem slurping file [$fn]") if (! defined $f);

  my $g = $f;

  %replc = ();
  $g = &processit($g);
  
  if ($g ne $f) {
    print "\n** $fn changes: \n";
    if (scalar(keys %replc) == 0) {
      MMisc::writeTo("/tmp/bad.xml", "", 1, 0, $g);
      MMisc::error_quit("Unknown replacement");
    } else {
      foreach my $type (keys %replc) {
        foreach my $id (keys %{$replc{$type}}) {
          print " - [TYPE: $type] [ID $id] " . $replc{$type}{$id} . "\n";
        }
      }
    }

    if ($doit) {
      MMisc::error_quit("Problem writing output file [$fn]")
          if (! MMisc::writeTo($fn, "", 1, 0, $g));
    }
  }

}

MMisc::ok_quit("Done\n");

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
  my ($beg, $end) = $fs_gfs->get_beg_end_fs();

  $v =~ s%(<attribute\s*([^\>]*?\/>|.+?<\/attribute>))%&process_attribute($id, $type, $beg, $end, $1)%sge;

  return($v);
}

##########

sub _fs_sort {
  MMisc::error_quit("Could not extract framespan beg [$a]")
      if (! ($a =~ m%^\s*(\d+)\:%s));
  my $b1 = $1;
 
 MMisc::error_quit("Could not extract framespan beg [$b]")
      if (! ($b =~ m%^\s*(\d+)\:%s));
  my $b2 = $1;

  MMisc::error_quit("Could not extract framespan end [$a]")
      if (! ($a =~ m%\:(\d+)\s*$%s));
  my $e1 = $1;

 MMisc::error_quit("Could not extract framespan end [$b]")
      if (! ($b =~ m%\:(\d+)\s*$%s));
  my $e2 = $1;

  return($e1 <=> $e2) if ($b1 == $b2);

  return($b1 <=> $b2);
}

#####

sub process_attribute {
  my ($id, $type, $beg, $end, $v) = @_;

  my $t = $v;

  %tmp_fsh = ();

  $t =~ s%(<data\:\w+\s+.+?\/\>)%&hash_fsinfo($1)%sge;

  return($v) if (scalar keys %tmp_fsh == 0);

  my @k = sort _fs_sort keys %tmp_fsh;
  
  # We only care about the first and last values
  
  my $b = $k[0];
  my $fs_fs = new ViperFramespan($b);
  MMisc::error_quit("Problem creating VFS ($b): " . $fs_fs->get_errormsg())
      if ($fs_fs->error());
  my ($lbeg, $lend) = $fs_fs->get_beg_end_fs();
  if ($beg < $lbeg) {
    my $add = "$beg:$lbeg";
    $fs_fs->add_fs_to_value($add);
    MMisc::error_quit("Problem adding [$add] to [$b]: " . $fs_fs->get_errormsg())
        if ($fs_fs->error());
    $tmp_fsh{$b} = $fs_fs->get_value();
    $replc{$type}{$id} .= "Shifted beg from $lbeg to $beg.";
  } elsif ($lbeg < $beg) {
    MMisc::warn_print("[TYPE: $type] [ID $id] framespan beg [$lbeg] is before <attribute> beg [$beg]");
  } # else (equal), do nothing
    
  my $e = $k[-1];
  my $fs_fs = new ViperFramespan($e);
  MMisc::error_quit("Problem creating VFS ($e): " . $fs_fs->get_errormsg())
      if ($fs_fs->error());
  my ($lbeg, $lend) = $fs_fs->get_beg_end_fs();
  if ($end > $lend) {
    my $add = "$lend:$end";
    $fs_fs->add_fs_to_value($add);
    MMisc::error_quit("Problem adding [$add] to [$e]: " . $fs_fs->get_errormsg())
        if ($fs_fs->error());
    $tmp_fsh{$e} = $fs_fs->get_value();
    $replc{$type}{$id} .= "Shifted end from $lend to $end.";
  } elsif ($end < $lend) {
    MMisc::warn_print("[TYPE: $type] [ID $id] framespan end [$lend] is after <attribute> end [$lend]");
  } # else (equal), do nothing

   $t =~ s%(<data\:\w+\s+.+?\/\>)%&replace_fsinfo($1)%sge;
 
  return($t);
}

#####

sub hash_fsinfo {
  my ($x) = @_;

  if (! ($x =~ m%^<data\:\w+\s+.*framespan\s*\=\s*\"([^\"]+?)\"%s)) {
    MMisc::error_quit("Can not extract framespan from line [$x], but we could for the same attribute before")
        if (scalar keys %tmp_fsh > 0);
    MMisc::warn_print("Could not extract framespan from line [$x]");
    return($x);
  }

  my $f = $1;
  $tmp_fsh{$f} = $f;

  return($x);
}

#####

sub replace_fsinfo {
  my ($x) = @_;

  MMisc::error_quit("Can not extract framespan from line [$x]")
      if (! ($x =~ m%^<data\:\w+\s+.*framespan\s*\=\s*\"([^\"]+?)\"%s));

  my $f = $1;
  MMisc::error_quit("Can not find framespan [$f]")
      if (! exists $tmp_fsh{$f});

  my $o = $tmp_fsh{$f};
  $x =~ s%^(<data\:\w+\s+.*framespan\s*\=\s*\")[^\"]+?(\")%$1$o$2%s;

  return($x);
}

########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--Verbose] [--doit] xmlfiles

Try to extend every <object>'s <attribute> <data> \"framespan\" to go the the <object>'s <attribute> framespan.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --Verbose       Print name of current file being processed
  --doit          Perform modification (safer to do one pass without this option and rerun it with it once it exits wihtout error)

IMPORTANT NOTE: Modify files specified on the command line
EOF
;
  
  return($tmp);
}
