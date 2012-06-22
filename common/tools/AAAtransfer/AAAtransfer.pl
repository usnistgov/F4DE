#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# AAAsend
# 
# Author: Martial Michel

# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
#
# AAAtransfer.pl is an experimental system.  
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

my $versionid = "AAAsend Version: $version";

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
      : ("$f4d/../../../common/lib");
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
foreach my $pn ("MMisc", "AccellionHelper") {
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

# Default values for variables

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                           abcde  h          stuv      #

my $upload = 0;
my $download = 0;
my $path = "";

my $tool = "";
my @email = ();
my $subject = "";
my $body = "";
my $tversion = 0;
my $continuous = 0;
my $verb = 0;

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'upload=s'   => sub {$upload = 1; $path = $_[1];},
   'download=s' => sub {$download = 1; $path = $_[1];},
   'agent=s'    => \$tool,
   'email=s'    => \@email,
   'subject=s'  => \$subject,
   'body=s'     => \$body,
   'toolVersion'  => \$tversion,
   'continuous=i' => \$continuous,
   'verbose+'   => \$verb,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("Leftover arguments on the command line: " . join(" ", @ARGV))
  if (scalar @ARGV > 0);

MMisc::error_quit("\'--upload\' and \'--download\' can not be used at the same time\n\n$usage")
  if ($upload && $download);

MMisc::error_quit("No \'--tool\' specified, aborting")
  if (MMisc::is_blank($tool));

MMisc::error_quit("Can only download from one sender at a time per agent\n\n$usage")
  if ($download && (scalar @email > 1));

####################

my $aaa = new AccellionHelper($tool);
MMisc::error_quit($aaa->get_errormsg()) if ($aaa->error());

my $tv = $aaa->get_tool_major_version();
MMisc::error_quit("Problem obtaining tool major version: " . $aaa->get_errormsg()) if ($aaa->error());
MMisc::ok_quit("Tool ($tool) Major Version: $tv")
  if ($tversion);

MMisc::error_quit("\'--continuous\' mode is not available with tool ($tool) version 1")
  if ($tv == 1);

$aaa->debug_set_showlogpath(1) if ($verb > 1);
MMisc::error_quit($aaa->get_errormsg()) if ($aaa->error());

if ($upload) {
  &upload();
} else { # download
  if (scalar @email == 1) {
    &download_from(@email);
  } else { # 
    &download();
  }
}
MMisc::error_quit($aaa->get_errormsg()) if ($aaa->error());

MMisc::ok_quit("Done");

####################

sub upload {
  if ($continuous) {
    vprint("-> starting continuous ($continuous seconds interval) upload from \'$path\'\n");
    $aaa->continuous_preferred_upload($path, $subject, $body, $continuous, @email);
    return();
  }

  # non continuous
  vprint("-> starting upload of \'$path\'\n");
  $aaa->preferred_upload($path, $subject, $body, @email);
}

##

sub download_from {
  my ($mail) = @_;

  if ($continuous) {
    vprint("<- starting continuous ($continuous seconds interval) download from \'$mail\' to \'$path\'\n");
    $aaa->continuous_preferred_download_fromEmail($path, $mail, $continuous);
    return();
  }

  # non continuous
  vprint("<- starting download from \'$mail\' to \'$path\'\n");
  $aaa->preferred_download_fromEmail($path, $mail);
}

##

sub download {
  if ($continuous) {
    vprint("<- starting continuous ($continuous seconds interval) download to \'$path\'\n");
    $aaa->continuous_preferred_download($path, $continuous);
    return();
  }

  # non continuous
  vprint("<- starting download to \'$path\'\n");
  $aaa->preferred_download($path);
}

########################################

sub vprint { return() if ($verb == 0); print join("", @_); }

##

sub set_usage {
    my $tmp=<<EOF

$0 [--help] [--verbose] --agent toolLocation [--toolVersion] --upload FileOrDir --email address [--email address [...]] [--subject "email subject"] [--body emailBodyContentFile] [--continous IntervalInSeconds]
$0 [--help] [--verbose] --agent toolLocation [--toolVersion] --download DownloadToDir [--email address] [--continous IntervalInSeconds]

Using AAA agent:
- 'Upload' file or directory content to given email address
- 'Download' files to specific dir

Warning: '--continous' mode can only be used with tool version 1

Where:
  --help         This help message
  --verbose      Be a little more verbose
  --agent        Location of the agent tool (or calling script)
  --toolVersion  Major version number of the agent tool 

--upload         File or Directory to upload from
  --email        Upload to specified recipient
  --subject      Email subject
  --body         File containing email body

--download       Directory to download to
  --email        Only download from specified sender

--continuous     Using this mode, the tool will keep going until manually stopped (Ctrl+C)

EOF
;

  return($tmp);
}
