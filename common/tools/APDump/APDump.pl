#!/usr/bin/env perl
#
# $Id$
#
# APDump
# APDump.pl
# Authors: Jonathan Fiscus
# 
# This software was developed at the National Institute of Standards and
# Technology by employees of the Federal Government in the course of
# their official duties.  Pursuant to Title 17 Section 105 of the United
# States Code this software is not subject to copyright protection within
# the United States and is in the public domain. 
# It is an experimental system.  
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST
# MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER,
# INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use Data::Dumper;
#use Carp ();  local $SIG{__WARN__} = \&Carp::cluck;

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

# Part of this tool
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";

foreach my $pn ("MMisc", "DETCurve", "DETCurveSet", "AutoTable") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long", "Pod::Usage", "File::Temp") {
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

my @columnDefs = ();
my $outFile = undef;
my $gzipPROG = "gzip";

my $VERSION = "0.1";
# Av:   ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: 

GetOptions
  (
   'c|columns=s'              => \@columnDefs,
   'o|output=s'               => \$outFile,
   'Z|ZipPROG=s'              => \$gzipPROG,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n");

MMisc::error_quit("Error: At least one SRL.\n") if(scalar ( @ARGV ) == 0);
MMisc::error_quit("Error: An Output file must be set.\n") if($outFile eq "");
### PreCheck the SRLs
foreach my $srl(@ARGV){  MMisc::error_quit("Error: SRL '$srl' not found", $srl) if (! -f $srl) }
### Parse and Check the column DEFs
my @infoCols = ();
foreach my $col(@columnDefs){
  my $regex = "([^=]+)=([^=]+)";
  MMisc::error_quit("Error: Column def /$col/ does not match the pattern /$regex/") if ($col !~ /^($regex)/);
  push @infoCols, { name => $2 , val => $3};
}

### Let's proceed
my $at = new AutoTable();
my $nsrl = 0;
foreach my $srl(@ARGV){
  my $id = sprintf("SRL-%03d",$nsrl++);
  print "Loading $srl id=$id\n";
  my $det = DETCurve::readFromFile($srl, $gzipPROG);
  
  my @blkIDs = $det->getTrials()->getBlockIDs();
  if (@blkIDs != 1){
    print "   Warning: Skipping $id.  ".scalar(@blkIDs)." blocks but this report is only valid for a single block DET\n";
  }
  my $blk = @blkIDs[0];

  for (my $cd=0; $cd<@infoCols; $cd++){
    $at->addData($infoCols[$cd]->{val}, $infoCols[$cd]->{name}, $id);
  }
  $at->addData($blk, "Event", $id);
  $at->addData($det->getGlobalMeasure("APpct"), "AP", $id);
  $at->addData($det->getGlobalMeasure("APPpct"), "APP", $id);
  my ($BScombAvg, $BScombSSD, $BSmissAvg, $BSmissSSD, $BSfaAvg, $BSfaSSD) = $det->getMetric()->getActualDecisionPerformance();
  $at->addData($BScombAvg, "Act. ".$det->getMetric()->combLab(), $id);
  $at->addData($BSmissAvg, "Act. ".$det->getMetric()->errMissLab(), $id);
  $at->addData($BSfaAvg, "Act. ".$det->getMetric()->errFALab(), $id);

  my ($actBlocks) = $det->getMetric()->getActualDecisionRawCountBlocks("includeAllCounts");
  foreach my $statDef("MMISS:FN @ SysThresh", "MFA:FP @ SysThresh", "MCORRDET:TP @ SysThresh", "MCORRNOTDET:TN @ SysThresh"){
  	my ($key, $name) = split(/:/, $statDef);
  	my $sum = 0;
	foreach my $blk(keys %{ $actBlocks }){  $sum += $actBlocks->{$blk}{$key} };
	$at->addData($sum, $name, $id);
  }  
  $at->addData($at->getData("TP @ SysThresh", $id) + $at->getData("FP @ SysThresh", $id), "Retr @ SysThresh", $id);

  $at->addData($det->getTrials()->getNumTrials($blk), "Search Videos", $id);
  $at->addData($det->getTrials()->getNumTarg($blk), "Event Videos", $id);
  my $thresh = $det->getTrials()->getTrialActualDecisionThreshold();  
  $at->addData($thresh, "SysThresh", $id);

  ### (rank, score, targ|nontarg, id)
  my $ranks = $det->getGlobalMeasureStructure("APpct")->{MEASURE}{POSRANKS};
  my $numPos = 1;
  #set the threshold state
  for (my $r=0; $r<@$ranks; $r++){
    #print "$r $numPos $thresh $ranks->[$r][0] $ranks->[$r][1] $ranks->[$r][2] $ranks->[$r][3]\n";
    my $useIt = 0;
  
    if ($ranks->[$r][2] == 1){ ### Target
      $at->addData($ranks->[$r][0], "<<FOOTER>>".$numPos++, $id);
    }
  }
  ### Error Check
  MMisc::error_quit("Error: for Event $blk, $numPos positives found but expected ".$det->getTrials()->getNumTarg($blk))
    if ($numPos-1 != $det->getTrials()->getNumTarg($blk));
  
}
$at->setProperties({ "KeyColumnCsv" => "Remove" });
MMisc::writeTo($outFile, "", 0, 0, $at->renderCSV());






