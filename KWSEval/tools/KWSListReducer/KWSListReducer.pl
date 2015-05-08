#!/usr/bin/env perl
#
# $Id$
#
# KWSListGenerator
# KWSListGenerator.pl
# Author: Jerome Ajot
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
use Encode;
use encoding 'euc-cn';
use encoding 'utf8';

##########
# Check we have every module (perl wise)

my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
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
foreach my $pn ("RTTMList", "TermList", "KWSList", "KWSDetectedList", "MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "KWSListGenerator ($versionkey)";

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long", "Data::Dumper") {
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

########################################

my $inKWSList = "";
my $outKWSList = "";
my $kwlist = "";
my $err;
my $system = "";
my $kwlistName =""; 
GetOptions
(
    'inkwslist=s'                          => \$inKWSList,
    'outkwslist=s'                          => \$outKWSList,
    'kwlist=s'                          => \$kwlist,
    'systemid=s',                            => \$system,
    'KWEntry',                            => \$kwlistName,
    'help'                                => sub { MMisc::ok_quit($usage) },
)  or MMisc::error_quit("Unknown option(s)\n\n$usage\n");

MMisc::error_quit("An input KWSList is needed\n\n$usage\n") if($inKWSList eq "");
MMisc::error_quit("An output KWSList is needed\n\n$usage\n") if($outKWSList eq "");
MMisc::error_quit("A KWList file is needed\n\n$usage\n") if($kwlist eq "");

my $inKWS = new KWSList($inKWSList); #now ready for getNextDetectedKWlist

$err = MMisc::check_file_r($kwlist);
MMisc::error_quit("Problem with TERM File ($kwlist): $err")
  if (! MMisc::is_blank($err));
my $TERM = new TermList($kwlist, 0, 0, 0);

my %termsToKeep = ();
foreach my $termID($TERM->getTermIDs()){
  $termsToKeep{$termID} = 1;
}
#print Dumper(\%termsToKeep);
foreach my $termID($inKWS->getTermIDs()){
  # print "Exists $termID ".(exists($termsToKeep{$termID}) ? "keep" : "delete")."\n";
  $inKWS->deleteTermByID($termID) unless (exists($termsToKeep{$termID}));
}

($inKWS ->{TERMLIST_FILENAME} = $kwlist) =~ s:.*/::;
($inKWS ->{SYSTEM_ID} = $system) if ($system ne "");
$inKWS ->{KWSLIST_FILENAME} = $outKWSList;
$inKWS->saveFile();

MMisc::ok_exit();

############################################################

sub set_usage {
  my $tmp = "";
  $tmp .= "$0 -e ecffile -r rttmfile -o outputfile\n";
  $tmp .= "Desc: This program generates an STDList file based on searching the reference file.\n";
  $tmp .= "\n";
  $tmp .= "Required file arguments:\n";
  $tmp .= "  -t, --termfile           Path to the Term file.\n";
  $tmp .= "  -r, --rttmfile           Path to the RTTM file.\n";
  $tmp .= "  -o, --output-file        Path to the Output file.\n";
  $tmp .= "  -F, --Find-threshold     Threshold.\n";
  $tmp .= "  -m, --missPct <float>    Percentage of Missed Detections\n";
  $tmp .= "  -f, --faPct <float>      Percentage of False Alarms\n";
  $tmp .= "\n";
  
  return($tmp);
}
