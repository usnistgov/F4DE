#!/usr/bin/env perl

# HTML Status generator
# Author: Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# HTML Status generator is an experimental system.  
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
  (my $cvs_version = '$Revision$') =~ s/[^0-9\.]//g;
  $version = "$version (CVS: $cvs_version)";
}
my $versionid = "HTML Status generator -- Version: $version";

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
foreach my $pn ("MMisc") {
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

my $usage = "$0 [--help] [--version] [--file outfile.html] [--percent value | --Value value --Max Maxvalue [--add addtoValue [--add addtoValue]]] [--message text]";

my $ofile = "";
my $percent = undef;
my $message = "";
my $value = undef;
my $max = undef;
my @adds = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                                f h    m  p     v     #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'file=s'    => \$ofile,
   'percent=f' => \$percent,
   'Value=f' => \$value,
   'Max=f' => \$max,
   'add=f' => \@adds,
   'message=s' => \$message,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Must have at least one of \'percent\' or both \'value\' and \'max\'")
  if ((! defined $percent) && (! defined $max) && (! defined $value));

if (! defined $percent) {
  $percent = $value * 100.0;
  foreach my $val (@adds) {
    $percent += ($val * 100.0);
  }
  $percent /= $max;
}

&doit();

MMisc::ok_exit();

sub doit {
  $percent = ($percent > 100.0) ? 100.0 : $percent;
  my $meta = ($percent == 100.0) ? "" : "<meta http-equiv=\"REFRESH\" content=\"10\">";
  
  # HTML5 Status bar
  my $otxt = "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML//EN\">\n<html>\n<head>\n$meta<title></title>\n</head>\n<body>\n<progress value=\"${percent}\" max=\"100\" height=\"20\" width=\"300\">${percent}\%</progress>$message\n</body>\n</html>\n";

  MMisc::writeTo($ofile, "", 0, 0, $otxt);

}

