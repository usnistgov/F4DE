#!/usr/bin/env perl
#
# $Id$
#
# ECFSegmentor
# ECFSegmentor.pl
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
foreach my $pn ("MMisc", "RTTMList", "KWSecf", "KWSecf_excerpt") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "ECFSegmentor ($versionkey)";

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

####################

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

sub diffsegment
{
    my($beg1, $end1, $beg2, $end2) = @_;
    my @out =();
    
    my $beg2in = ($beg2 > $beg1 && $beg2 < $end1);
    my $end2in = ($end2 > $beg1 && $end2 < $end1);
    
    if($beg2 > $beg1 || $end2 < $end1)
    {
        if(!$beg2in && !$end2in)
        {
            push(@out, [ ($beg1, $end1) ]);
        }
        elsif(!$beg2in && $end2in)
        {
            push(@out, [ ($end2, $end1) ]);
        }
        elsif($beg2in && !$end2in)
        {
            push(@out, [ ($beg1, $beg2) ]);
        }
        elsif($beg2in && $end2in)
        {
            push(@out, [ ($beg1, $beg2) ]);
            push(@out, [ ($end2, $end1) ]);
        }
    }
    
    return @out;
}

sub multidiffsegment
{
    my($beg, $end, @segments) = @_;
    my @out;
            
    if(@segments)
    {
        for(my $i=0; $i<@segments; $i++)
        {
            push(@out, diffsegment($segments[$i][0], $segments[$i][1], $beg, $end));
        }
    }
    
    return @out;
}

my $ECFfile = "";
my $RTTMfile = "";
my $Outfile = "";
my $Versionnumber = "";
my $updateDur = undef;

GetOptions
(
    'ecffile=s'                           => \$ECFfile,
    'rttmfile=s'                          => \$RTTMfile,
    'output-file=s'                       => \$Outfile,
    'updateDur'                           => \$updateDur,
    'Version-number=s'                    => \$Versionnumber,
    'version',                            => sub { MMisc::ok_quit($versionid) },
    'help'                                => sub { MMisc::ok_quit($usage) },
);

MMisc::error_quit("An RTTM file must be set\n\n$usage\n") if ($RTTMfile eq "");
MMisc::error_quit("An ECF file must be set\n\n$usage\n") if ($ECFfile eq "");
MMisc::error_quit("An Output file must be set\n\n$usage\n") if ($Outfile eq "");
MMisc::error_quit("A Version must be set\n\n$usage\n") if ($Versionnumber eq "");

my $ECF = new KWSecf($ECFfile);
my $RTTM = new RTTMList($RTTMfile, "", "", "", 0, 0, 0, 1); # bypassCoreText -> no RTTM text rewrite possible
my $ECFOUT = new_empty KWSecf($Outfile);

$ECFOUT->{SIGN_DUR} = $ECF->{SIGN_DUR};
$ECFOUT->{VER} = $Versionnumber;

if($ECF->{EXCERPT})
{
    for(my $i=0; $i<@{ $ECF->{EXCERPT} }; $i++)
    {
        my $file = $ECF->{EXCERPT}[$i]->{AUDIO_FILENAME};
        my $purged_file = $ECF->{EXCERPT}[$i]->{FILE};;
        my $channel = $ECF->{EXCERPT}[$i]->{CHANNEL};
        my $begt = $ECF->{EXCERPT}[$i]->{TBEG};
        my $endt = $ECF->{EXCERPT}[$i]->{TEND};
        my $dur = $ECF->{EXCERPT}[$i]->{DUR};
        my $language = $ECF->{EXCERPT}[$i]->{LANGUAGE};
        my $source_type = $ECF->{EXCERPT}[$i]->{SOURCE_TYPE};
        
        my @segments = [($begt, $endt)];

        if($RTTM->{NOSCORE}{$purged_file}{$channel})
        {
            for(my $j=0; $j<@{ $RTTM->{NOSCORE}{$purged_file}{$channel} }; $j++)
            {
                @segments = multidiffsegment($RTTM->{NOSCORE}{$purged_file}{$channel}[$j]->{BT}, $RTTM->{NOSCORE}{$purged_file}{$channel}[$j]->{ET}, @segments);
            }
            
            if(@segments)
            {
                for(my $j=0; $j<@segments; $j++)
                {
                    push(@{ $ECFOUT->{EXCERPT} }, new KWSecf_excerpt($file, $channel, $segments[$j][0], sprintf("%.4f", $segments[$j][1]-$segments[$j][0]), $language, $source_type) );
                }
            }
        }
        else
        {
            push(@{ $ECFOUT->{EXCERPT} }, new KWSecf_excerpt($file, $channel, $begt, $dur, $language, $source_type) );
        }
    }
}

if (defined($updateDur)) { 
  $ECFOUT->{SIGN_DUR} = 0;

  foreach my $excerpt (@{ $ECFOUT->{EXCERPT} }) {
    $ECFOUT->{SIGN_DUR} += $excerpt->{DUR};
  }
}

$ECFOUT->saveFile($ECFOUT->getFile());

MMisc::ok_exit();

############################################################

sub set_usage {
  my $tmp = "";
  $tmp .= "$0 -e ecffile -r rttmfile -o outputfile\n";
  $tmp .= "Desc: This script applies the NOSCORE regions in a RTTM file to the ECF file to make a scoring ECF file.\n";
  $tmp .= "\n";
  $tmp .= "Required file arguments:\n";
  $tmp .= "  -e, --ecffile            Path to the ECF file.\n";
  $tmp .= "  -r, --rttmfile           Path to the RTTM file.\n";
  $tmp .= "  -o, --output-file        Path to the Output file.\n";
  $tmp .= "  -V, --Version-number     ECF version.\n";
  $tmp .= "  -u, --updateDur          Update the ECF's duration field.\n";
  $tmp .= "\n";
  
  return($tmp);
}
