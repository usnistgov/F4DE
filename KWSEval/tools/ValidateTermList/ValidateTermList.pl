#!/usr/bin/perl -w

# ValidateTermList
# ValidateTermList.pl
# Authors: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. KWSEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
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
my $versionid = "ValidateTermList Version: $version";

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

####################


my $TERMfile = "";

GetOptions
(
    'termfile=s'                          => \$TERMfile,
) or MMisc::error_quit("Unknown option(s)");

MMisc::error_quit("$usage") if($TERMfile eq "");

open(TERMLIST, $TERMfile) or MMisc::error_quit("Unable to open for read TermList file '$TERMfile' : $!");

my $tlistfilestring = "";
my %TERMList;

while (<TERMLIST>)
{
	chomp;
	$tlistfilestring .= $_;
}

close(TERMLIST);

#clean unwanted spaces
$tlistfilestring =~ s/\s+/ /g;
$tlistfilestring =~ s/> </></g;
$tlistfilestring =~ s/^\s*//;
$tlistfilestring =~ s/\s*$//;

my $termlisttag;
my $allterms;
my %TermsbyID;
my %TermsbyTEXT;

if($tlistfilestring =~ /(<termlist .*?[^>]*>)([[^<]*<.*[^>]*>]*)<\/termlist>/)
{
	$termlisttag = $1;
	$allterms = $2;
}
else
{
	MMisc::error_quit("Invalid TermList file");
}

while( $allterms =~ /(<term termid=\"(.*?[^\"]*)\"[^>]*><termtext>(.*?)<\/termtext>(.*?)<\/term>)/ )
{
	my $previouslength = length($allterms);
	my $x = quotemeta($1);
	
	if(!exists($TermsbyID{$2}))
	{
		$TermsbyID{$2} = $3;
	}
	else
	{
		print "[DUPLICATE] [ ID ] - ID ('$2') - Text ('$3') - Previous ID ('$2') - Text ('$TermsbyID{$2}')\n";
	}
	
	if(!exists($TermsbyTEXT{$3}))
	{
		$TermsbyTEXT{$3} = $2;
	}
	else
	{
		print "[DUPLICATE] [TEXT] - ID ('$2') - Text ('$3') - Previous ID ('$TermsbyTEXT{$3}') - Text ('$3')\n";
	}
	
	$allterms =~ s/$x//;
	
	if( ($previouslength == length($allterms)) && (length($allterms) != 0) )
	{
		print "Error: Infinite Loop in 'TermList' parsing!\n";
		exit(0);
	}
}

MMisc::ok_exit();

############################################################

sub set_usage {
  my $usage = "$0 -t termfile [ OPTIONS ]\n";
  $usage .= "\n";
  $usage .= "Required file arguments:\n";
  $usage .= "  -t, --termfile           Path to the TermList file.\n";
  $usage .= "\n";
  
  return($usage);
}
