#!/usr/bin/env perl

# ConditionalQueryTList
# ConditionalQueryTList.pl
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
# Version

# $Id$
my $version     = "0.1b";
if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}
my $versionid = "ConditionalQueryTList Version: $version";

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
foreach my $pn ("TermList", "MMisc") {
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

####################

sub union_intersection
{
    my($list1, $list2, $out_union, $out_intersection) = @_;
    
    my %union;
    my %isect;    
    foreach my $e (@{ $list1 }, @{ $list2 }) { $union{$e}++ && $isect{$e}++ }

    @{ $out_union } = keys %union;
    @{ $out_intersection } = keys %isect;
}

sub multiarray
{
    my($list1, $list2, $multi) = @_;
    
    foreach my $e1 (@{ $list1 })
    {
        foreach my $e2 (@{ $list2 })
        {
            push(@{$multi}, ($e1 ne "")?"$e1|$e2":"$e2");
        }
    }
}

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

my $Termfile = "";
my @Queries;


GetOptions
(
    'termfile=s' => \$Termfile,
    'query=s@'   => \@Queries,
    'help'       => sub { MMisc::ok_quit($usage) },
) or MMisc::error_quit("Unknown option(s)\n\n$usage\n");

MMisc::error_quit("A TermList file must be set\n\n$usage\n") if($Termfile eq "");
MMisc::error_quit("At least Query file must be set\n\n$usage\n") if(scalar(@Queries) == 0);

my $TERM = new TermList($Termfile, 0, 0, 0);

my %attributes;

foreach my $termid(keys %{ $TERM->{TERMS} } )
{
    foreach my $attrib_name(keys %{ $TERM->{TERMS}{$termid} })
    {
        if( ($attrib_name ne "TERMID") && ($attrib_name ne "TEXT") )
        {
            $attributes{$attrib_name} = 1;
        }
    }
}

foreach my $quer(@Queries)
{
    MMisc::error_quit("$quer is not a valid attribute") if(!$attributes{$quer});
}

my %hashterm;

foreach my $termid(keys %{ $TERM->{TERMS} } )
{
    foreach my $attrib_name(keys %{ $TERM->{TERMS}{$termid} })
    {
        if( ($attrib_name ne "TERMID") && ($attrib_name ne "TEXT") )
        {
            my $attribute_value = $TERM->{TERMS}{$termid}->{$attrib_name};
            push(@{ $hashterm{$attrib_name}{$attribute_value} }, $termid);
        }
    }
}

my @multivalues = ("");
my @sorted_queries = sort @Queries;

foreach my $quer(@sorted_queries)
{
    my @values = sort keys %{ $hashterm{$quer} };
    my @finalmulti;
    multiarray(\@multivalues, \@values, \@finalmulti);
    @multivalues = @finalmulti;
}

my %hashlistterms;

foreach my $multivalue(@multivalues)
{
    my @values = split(/\|/, $multivalue);

    my @listterm = @{ $hashterm{$sorted_queries[0]}{$values[0]} };
    my $title = "$sorted_queries[0] $values[0]";
    
    for(my $i=1; $i<@sorted_queries; $i++)
    {
        my @outtmp;
        my @out_inter;
        union_intersection(\@listterm, \@{ $hashterm{$sorted_queries[$i]}{$values[$i]} }, \@outtmp, \@out_inter);
        @listterm = @out_inter;
        $title .= "|$sorted_queries[$i] $values[$i]";
    }
    
    $title =~ s/ /_/g;

    push(@{ $hashlistterms{$title} }, @listterm);
}

foreach my $finalkey(sort keys %hashlistterms)
{
    my $tmp = join(',', @{ $hashlistterms{$finalkey} });
    print "$finalkey:$tmp\n";
}

MMisc::ok_exit();

############################################################

sub set_usage {
  my $tmp = "";
  $tmp .= "$0 -t termfile -q query -q query\n";
  $tmp .= "Desc: This script reads a termfile and reports the values for the -q <ATTRNAME> and the terms matching the value.\n";
  $tmp .= "\n";
  $tmp .= "Required file arguments:\n";
  $tmp .= "  -t, --termfile           Path to the Term file.\n";
  $tmp .= "  -q, --query              Query.\n";
  $tmp .= "\n";
  
  return($tmp);
}
