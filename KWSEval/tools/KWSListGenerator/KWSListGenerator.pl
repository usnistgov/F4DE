#!/usr/bin/env perl

# KWSListGenerator
# KWSListGenerator.pl
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. asclite is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use Encode;
use encoding 'euc-cn';
use encoding 'utf8';

##########
# Version

# $Id$
my $version     = "0.1b";
if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}
my $versionid = "KWSListGenerator Version: $version";

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
foreach my $pn ("RTTMList", "TermList", "KWSList", "KWSDetectedList", "MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

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

my $Termfile = "";
my $RTTMfile = "";
my $Outfile = "";
my $thresholdFind = 0.5;
my $missPct = 0.2;
my $faPct = 0.05;

GetOptions
(
    'termfile=s'                          => \$Termfile,
    'rttmfile=s'                          => \$RTTMfile,
    'output-file=s'                       => \$Outfile,
    'Find-threshold=f'                    => \$thresholdFind,
    'missPct=f'                           => \$missPct,
    'fAPct=f'                             => \$faPct,
    'version',                            => sub { MMisc::ok_quit($versionid) },
    'help'                                => sub { MMisc::ok_quit($usage) },
)  or MMisc::error_quit("Unknown option(s)\n\n$usage\n");

MMisc::error_quit("An RTTM file must be set\n\n$usage\n") if($RTTMfile eq "");
MMisc::error_quit("An Term file must be set\n\n$usage\n") if($Termfile eq "");
MMisc::error_quit("An Output file must be set\n\n$usage\n") if($Outfile eq "");

print "Generate a random system with Pmiss=$missPct and PFa=$faPct\n";

my $TERM = new TermList($Termfile);
my $RTTM = new RTTMList($RTTMfile, $TERM->getLanguage(), $TERM->getCompareNormalize(), $TERM->getEncoding());
my $STDOUT = new_empty KWSList($Outfile);

$STDOUT->{LANGUAGE} = $TERM->{LANGUAGE};
$STDOUT->{ENCODING} = $TERM->{ENCODING};
$STDOUT->{TERMLIST_FILENAME} = $Termfile;

### Build the FA term for this term
my @termidList = sort keys %{ $TERM->{TERMS} };
my %FATermIDList = ();
for (my $f=0; $f<@termidList; $f++){
  $FATermIDList{$termidList[$f]} = $termidList[($f+1)%(@termidList)];
}

for (my $termNum = 0; $termNum < @termidList; $termNum++)
{
    my $termsid = $termidList[$termNum];
    my $terms = $TERM->{TERMS}{$termsid}->{TEXT};
    my $occurrences = RTTMList::findTermHashToArray($RTTM->findTermOccurrences($terms, $thresholdFind));
    #print "Found ".scalar(@$occurrences)." occurrences of ".$terms." ID $termsid in the RTTM\n";
    
    my $detectedterm = new KWSDetectedList($termsid, $termNum * .1 + 1, (($termNum+1) % 7 == 0) ? 1 : 0);
   
    ### The true occurrences 
    my $misses = sprintf("%.0f", @$occurrences * $missPct);
    for(my $i=0; $i<@$occurrences - $misses; $i++)
    {
        my $file = @{ $occurrences->[$i] }[0]->{FILE};
        my $chan = @{ $occurrences->[$i] }[0]->{CHAN};
        my $bt = @{ $occurrences->[$i] }[0]->{BT};
        my $numberoftoken = @{ $occurrences->[$i] };
        my $et = @{ $occurrences->[$i] }[$numberoftoken-1]->{ET};
        my $dur = sprintf("%.4f", $et - $bt);
        my $rttm = \@{ $occurrences->[$i] };
      	my $score = $i / (@$occurrences - $misses );
        my $dec = ($score > 0.5 ? "YES" : "NO");              
        push( @{ $detectedterm->{TERMS} }, new KWSTermRecord($file, $chan, $bt, $dur, $score, $dec));
    }

    ### Add Some False Alarms
    $terms = $TERM->{TERMS}{$FATermIDList{$termsid}}->{TEXT};
    $occurrences = RTTMList::findTermHashToArray($RTTM->findTermOccurrences($terms, $thresholdFind));
    
    ### The true occurrences 
    my $fas = sprintf("%.0f", @$occurrences * $faPct);
    for(my $i=0; $i<$fas; $i++)
    {
        my $file = @{ $occurrences->[$i] }[0]->{FILE};
        my $chan = @{ $occurrences->[$i] }[0]->{CHAN};
        my $numberoftoken = @{ $occurrences->[$i] };
        my $bt = 0.0;
        my $et = $bt + 0.1;

        my $dur = sprintf("%.4f", $et - $bt);
        my $rttm = \@{ $occurrences->[$i] };
      	my $score = $i / ($fas);
        my $dec = ($score > 0.5 ? "YES" : "NO");              
        push( @{ $detectedterm->{TERMS} }, new KWSTermRecord($file, $chan, $bt, $dur, $score, $dec));
    }
    
    
    $STDOUT->{TERMS}{$termsid} = $detectedterm;
}

$STDOUT->saveFile();

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
