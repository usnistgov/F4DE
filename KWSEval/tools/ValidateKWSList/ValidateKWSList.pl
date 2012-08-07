#!/usr/bin/env perl

# ValidateKWSList
# ValidateKWSList.pl
# Authors: Jerome Ajot
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
my $versionid = "ValidateKWSList Version: $version";

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
foreach my $pn ("KWSecf", "TermList", "KWSList", "RTTMList", "MMisc") {
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

my $TERMfile = "";
my $ECFfile = "";
my $KWSfile = "";
my $RTTMfile = "";
my $outputfile = "";
my $mddir = "";

GetOptions
  (
   'termfile=s'   => \$TERMfile,
   'ecffile=s'    => \$ECFfile,
   'sysfile=s'    => \$KWSfile,
   'rttmfile=s'   => \$RTTMfile,
   'output=s'     => \$outputfile,
   'memdumpDir=s' => \$mddir,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::error_quit("$usage")
  if (MMisc::any_blank($TERMfile, $ECFfile, $KWSfile));

my $err = MMisc::check_file_r($TERMfile);
MMisc::error_quit("Problem with \'--termfile\' file ($TERMfile): $err")
  if (! MMisc::is_blank($err));
$err = MMisc::check_file_r($ECFfile);
MMisc::error_quit("Problem with \'--ecffile\' file ($ECFfile): $err")
  if (! MMisc::is_blank($err));
$err = MMisc::check_file_r($KWSfile);
MMisc::error_quit("Problem with \'--kwsfile\' file ($KWSfile): $err")
  if (! MMisc::is_blank($err));

if (! MMisc::is_blank($RTTMfile)) {
  $err = MMisc::check_file_r($RTTMfile);
  MMisc::error_quit("Problem with \'--rttmfile\' file ($RTTMfile): $err")
      if (! MMisc::is_blank($err));
}

if (! MMisc::is_blank($mddir)) {
  $err = MMisc::check_dir_w($mddir);
  MMisc::error_quit("Problem with \'--memdumpDir\' ($mddir): $err")
      if (! MMisc::is_blank($err));
}

my $TERM = new TermList($TERMfile);
my $ECF = new KWSecf($ECFfile);
my $KWS = new KWSList($KWSfile);
my $RTTM = (! MMisc::is_blank($RTTMfile)) ? 
  new RTTMList($RTTMfile, $TERM->getLanguage(), 
               $TERM->getCompareNormalize(), $TERM->getEncoding()) 
  : undef;

my %ListTerms;
foreach my $termid (keys %{ $TERM->{TERMS} }) { $ListTerms{$termid} = 1; }

my $errors = 0;
my $warnings = 0;
foreach my $termid (sort keys %{ $KWS->{TERMS} }) {
  if (exists($TERM->{TERMS}{$termid})) {
    delete $ListTerms{$termid};
    
    ### No need to check if there are no occurrences for the term
    next if (! defined($KWS->{TERMS}{$termid}->{TERMS}));
    
    for (my $i=0; $i<@{ $KWS->{TERMS}{$termid}->{TERMS} }; $i++) {
      if (0 == $ECF->FilteringTime
          ($KWS->{TERMS}{$termid}->{TERMS}[$i]->{FILE}, 
           $KWS->{TERMS}{$termid}->{TERMS}[$i]->{CHAN},
           $KWS->{TERMS}{$termid}->{TERMS}[$i]->{BT},
           $KWS->{TERMS}{$termid}->{TERMS}[$i]->{ET}) ) {
        print "ERROR - KWS detected term ID '$termid' (File '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{FILE}', Channel '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{CHAN}', Begin time '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{BT}', duration '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{DUR}') not defined in the ECF.\n";
        $errors++;
        delete $KWS->{TERMS}{$termid}->{TERMS}[$i];
      }
    }
		
    my %uniqueDetected = ();
    for (my $i=0; $i<@{ $KWS->{TERMS}{$termid}->{TERMS} }; $i++) {
      if (! exists( $uniqueDetected{"$KWS->{TERMS}{$termid}->{TERMS}[$i]->{FILE}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{CHAN}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{BT}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{DUR}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{SCORE}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{DECISION}"} )) {
        $uniqueDetected{"$KWS->{TERMS}{$termid}->{TERMS}[$i]->{FILE}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{CHAN}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{BT}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{DUR}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{SCORE}"."|"."$KWS->{TERMS}{$termid}->{TERMS}[$i]->{DECISION}"} = 1;
      } else {
        print "WARNING - KWS detected term ID '$termid' (File '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{FILE}', Channel '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{CHAN}', Begin time '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{BT}', duration '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{DUR}', duration '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{SCORE}', duration '$KWS->{TERMS}{$termid}->{TERMS}[$i]->{DECISION}') is a duplicate.\n";
        $warnings++;
        delete $KWS->{TERMS}{$termid}->{TERMS}[$i];
      }
    }
  } else {
    print "ERROR - ID '$termid' present in KWS file but not defined in the Term List.\n";
    $errors++;
    delete $KWS->{TERMS}{$termid};
  }
}

foreach my $termid (sort keys %ListTerms) {
  print "ERROR - ID '$termid' defined in the Term List but absent in KWS file.\n";
  $errors++;
}

if ($errors + $warnings > 0) {
  print "'$KWSfile' does not validate due to $errors error(s) and $warnings warning(s)!\nCheck above for details!";
} else {
  print "'$KWSfile' validates!\n";
}

if($outputfile ne "") {
  $KWS->{KWSLIST_FILENAME} = $outputfile;
  $KWS->saveFile();

  print "The new KWS file '$outputfile' will not be proper because some terms have not been detected in the original KWS file!\n" 
    if (keys( %ListTerms ) != 0);
}

if (! MMisc::is_blank($mddir)) {
  &saveObject($mddir, $TERMfile, $TERM);
  &saveObject($mddir, $ECFfile, $ECF);
  &saveObject($mddir, $KWSfile, $KWS);
  &saveObject($mddir, $RTTMfile, $RTTM);
}

MMisc::ok_exit() if ($errors + $warnings == 0);
# exit with the number of errors summed to the number of warning if any
exit($errors + $warnings);

############################################################

sub saveObject {
  my ($od, $if, $object) = @_;
  return() if (! defined $object);
  
  my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($if);
  my $of = MMisc::concat_dir_file_ext($od, $f, $e);
  
  $object->saveFile($of);
  $object->save_MemDump($of);
}

#####

sub set_usage {
  my $usage = "$0 --termfile termfile --ecf ecfile --sysfile kwsfile [--rttmfile rttmfile] [--output purged_KWSlist] [--memdumpDir dir]\n";
  $usage .= "\n";
  $usage .= "Required file arguments:\n";
  $usage .= "  --termfile        Path to the TermList file\n";
  $usage .= "  --ecffile         Path to the ECF file\n";
  $usage .= "  --sysfile         Path to the KWSList file\n";
  $usage .= "  --rttmfile        Path to the RTTM file\n";
  $usage .= "  --output          Path to the output new purged KWS file\n";
  $usage .= "  --memdumpDir      Path to the directory where to put all processed input files\n";
  $usage .= "\n";
  
  return($usage);
}
