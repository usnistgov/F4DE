#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# KWSEval XML Validator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "KWSEval XML Validator" is an experimental system.
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
# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "KWSEval XML Validator Version: $version";

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
foreach my $pn ("MMisc", "xmllintHelper") {
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

my $xmllint_env = "F4DE_XMLLINT";
my $toolb = "xsdxmllint";
my @xsdfilesl = ('KWSEval-ecf.xsd', 'KWSEval-kwslist.xsd', 'KWSEval-termlist.xsd'); # order is important
my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Default values for variables

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                    T   X      e  h  k        t vwx   #

my $xmllint = "";
my $xsdpath = "";
my $issome = -1;
my $writeback = -1;
my $tool = "";

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'Tool=s'    => \$tool,
   'xmllint=s' => \$xmllint,
   'Xsdpath=s' => \$xsdpath,
   'ecf'       => sub {$issome = 0;},
   'kwslist'   => sub {$issome = 1;},
   'termlist'  => sub {$issome = 2;},
   'write:s'   => \$writeback,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Did not specify validation type, must be either \'--ecf\', \'--kwslist\' or \'--termlist\'")
  if ($issome == -1);

$tool = (MMisc::is_blank($tool)) ? 
  ((exists $ENV{$f4b}) ? $ENV{$f4b} . "/bin/$toolb" : dirname(abs_path($0)) . "/../../../common/tools/xmllintTools/$toolb.pl")
  : $tool;
my $err = MMisc::check_file_x($tool);
MMisc::error_quit("Problem with tool ($tool): $err")
  if (! MMisc::is_blank($err));

$xmllint = MMisc::get_env_val($xmllint_env, "")
  if (MMisc::is_blank($xmllint));

$xsdpath = (MMisc::is_blank($xsdpath)) ? ((exists $ENV{$f4b}) ? ($ENV{$f4b} . "/lib/data") : (dirname(abs_path($0)) . "/../../data")) : $xsdpath;

print "** Performing initial check\n";
my ($rc, $so, $se) = &run_tool();
MMisc::error_quit("Problem with core tool ($tool):\n[stdout]$so\n[stderr]$se\n")
  if ($rc != 0);

print "** Running all checks (will print result after tool is completed)\n";
($rc, $so, $se) = &run_tool(@ARGV);
MMisc::ok_quit($so)
  if ($rc == 0);

MMisc::error_quit("Problem running core tool ($tool):\n[stdout]$so\n[stderr]$se\n");

########## END

sub run_tool {
  my @cmd = ($tool);
  push @cmd, ('-x', $xmllint) if (! MMisc::is_blank($xmllint));
  push @cmd, ('-p', $xsdpath);
  push @cmd, ('-f', $xsdfilesl[$issome]);
  push @cmd, ('-w') if ($writeback != -1);
  push @cmd, ($writeback) if (($writeback != -1) && ($writeback ne ""));
  push @cmd, (@_) if (scalar @_ > 0);

  return(MMisc::do_system_call(@cmd));
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################ Manual
sub set_usage {
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage:
$0 [--help] [--version] [--Tool location] [--xmllint location] [--Xsdpath dirlocation] [--write [directory]] --ecf ecf_file.xml [ecf_file.xml [...]]
$0 [--help] [--version] [--Tool location] [--xmllint location] [--Xsdpath dirlocation] [--write [directory]] --kwslist kwslist_file.xml [kwslist_file.xml [...]]
$0 [--help] [--version] [--Tool location] [--xmllint location] [--Xsdpath dirlocation] [--write [directory]] --termlist termlist_file.xml [termlist_file.xml [...]]

Will validate KWS Eval's ECF, TermList or KWSlist files using Tool ($toolb)

Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --Tool          Location of global XML validator ($toolb)
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --Xsdpath       Path where the XSD files can be found
  --write         Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)

Note:
- 'Xsdpath' files are: $xsdfiles

EOF
    ;

    return $tmp;
}
