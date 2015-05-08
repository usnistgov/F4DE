#!/usr/bin/env perl
#
# $Id$
#

use strict;
use Getopt::Long;
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

my $usage  = &set_usage();
my $outdir = "";

my %opt;
GetOptions
  (
   \%opt,
   'help',
   "outdir:s"       => \$outdir,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("No \'outdir\' set\n$usage\n") if ($outdir =~ m%^\s*$%);

die("Problem with \'outdir\' ($outdir): $!\n")
  if ((! -e $outdir) || (! -d $outdir)); 

die("No input file provided, aborting") if (scalar @ARGV == 0);

my @todo = @ARGV;
my $done = 0;
foreach my $ifile (@todo) {
  my ($ds, $txt) =  &fixit($ifile, $outdir);
  $done += $ds;
  print "$txt";
}
my $ntodo = scalar @todo;

die("All done (ok:$done/$ntodo)\n");

########################################

sub fixit {
  my $ifile = shift @_;
  my $outdir = shift @_;

  my $short = $ifile;
  $short =~ s%^.*\/([^\/]+)$%$1%;

  open IFILE, "<$ifile"
    or return(0, "$short: Problem opening input file: $!\n");
  my @content = <IFILE>;
  close FILE;
  chomp @content;

  my $ofile = "$outdir/$short";
  $ofile =~ s%\/(\/)%$1%g;

  open OFILE, ">$ofile"
    or return(0, "$short: Problem creating output file ($ofile): $!\n");

  my $mods = 0;
  foreach my $line (@content) {
    my $out = &fixline($line);
    if ($out ne $line) {
      $mods++;
#      print("WAS: [$line]\nNOW: [$out]\n");
    }
    print OFILE "$out";
  }

  close OFILE;

  return(1, "$short: wrote $ofile [$mods line modified]\n");
}

##########

sub fixline {
  my $line = shift @_;
  my $out;

  if ($line =~ m%^(\s*?)\<attribute\s.*?name\=\"Time\"%) {
    my $spacer = $1;
    if ($line =~ m%dynamic\=%) { # we are in the config section
      $out =<<EOF
$spacer<attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
$spacer<attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
$spacer<attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
$spacer<attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
EOF
;
    } else { # in the data section
      $out =<<EOF;
$spacer<attribute name="Point"/>
$spacer<attribute name="BoundingBox"/>
$spacer<attribute name="DetectionScore"/>
$spacer<attribute name="DetectionDecision"/>
EOF
;
    }
  } elsif ($line =~ m%\"PersonRun\"%) { # PersonRun -> PersonRuns
    $out = "$line\n";
    $out =~ s%(\"PersonRun)(\")%$1s$2%g;
  } else {
    $out = "$line\n";
  }
  
  return($out);
}

####################

sub set_usage {
  my $tmp=<<EOF
Usage: $0 [--help] --outdir dir xmlfile [xmlfile[...]]

Fix bad LDC files.

 Where:
  --outdir    Specify output dir (must exists)
EOF
;

  return($tmp);
}
