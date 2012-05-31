#!/usr/bin/perl -w

# TListAddNGram.pl
# Author: Jonathan Fiscus, Jerome Ajot
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
foreach my $pn ("MMisc", "TermList", "TermListRecord") {
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

my $VERSION = 0.1;

sub usage
{
    print "TListAddNGram.pl -t inTList -o outputTList \n";
    print "\n";
    print "Required file arguments:\n";
    print "  -t, --termfile           Path to the Term file.\n";
    print "  -o, --output-file        Path to the Output Tlist file.\n";
    print "\n";
}


my $Termfile = "";
my $Outfile = "";

GetOptions
(
    'termfile=s'                          => \$Termfile,
    'output-file=s'                       => \$Outfile,
    'version',                            => sub { print "TListAddNGram.pl version: $VERSION\n"; exit },
    'help'                                => sub { usage (); exit },
);

die "ERROR: An Term file must be set." if($Termfile eq "");
die "ERROR: An Output file must be set." if($Outfile eq "");

my $TERM = new TermList($Termfile);

foreach my $term(sort keys %{ $TERM->{TERMS} }){
    
    my @a = split(/\s/, $TERM->{TERMS}{$term}->{TEXT});
    my $o = scalar(@a);
    $o = "3-4" if ($o == 3 || $o == 4);
        
    $TERM->{TERMS}{$term}->setAttrValue("NGram Order", "$o-grams")
}

$TERM->saveFile($Outfile);

