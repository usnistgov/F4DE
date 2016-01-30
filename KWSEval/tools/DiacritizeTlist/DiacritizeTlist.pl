#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#
# DiacritizeTlist
# DiacritizeTlist.pl
# Author: Jonathan Fiscus
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
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }

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
foreach my $pn ("RTTMList", "TermList", "TermListRecord", "KWSList", "KWSDetectedList", "MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "DiacritizeTlist ($versionkey)";

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

my $Termfile = "";
my $RTTMfile = "";
my $Outfile = "";
my $findTermThreshold = -1;

GetOptions
  (
   'termfile=s'                          => \$Termfile,
   'rttmfile=s'                          => \$RTTMfile,
   'output-file=s'                       => \$Outfile,
   'find-threshhold'                     => \$findTermThreshold,
   'version',                            => sub { MMisc::ok_quit($versionid) },
   'help'                                => sub { MMisc::ok_quit($usage) },
  )  or MMisc::error_quit("Unknown option(s)\n\n$usage\n");

MMisc::error_quit("An RTTM file must be set\n\n$usage\n") if($RTTMfile eq "");
MMisc::error_quit("An Term file must be set\n\n") if($Termfile eq "");
MMisc::error_quit("An Output file must be set") if($Outfile eq "");

my $RTTM = new RTTMList($RTTMfile, "", "", "", 0, 0, 0, 1); # bypassCoreText -> no RTTM text rewrite possible
my $TERM = new TermList($Termfile, 0, 0, 0);
my $TERMOUT = new_empty TermList($Outfile, $TERM->{ECF_FILENAME}, $TERM->{VERSION}, $TERM->{LANGUAGE}, $TERM->getEncoding(), $TERM->getCompareNormalize());

### Loop through the RTTM file, building a mapping table for undiactrized lexemes
my %base2diaLUT = ();
foreach my $file(keys %{ $RTTM->{DATA} }){
    foreach my $chan(keys %{ $RTTM->{DATA}{$file} }){
	foreach my $rttmrec(@{ $RTTM->{DATA}{$file}{$chan} }){
	    my $token = $rttmrec->{TOKEN};
	    $token =~ tr/A-Z/a-z/;
	    ## Remove diacritics
	    my $base = $token;
	    $base =~ s/(\331\216|\331\220|\331\221|\331\222|\331\217)//g;
	    $base2diaLUT{$base}{$token} = 0 if (! exists($base2diaLUT{$base}{token}));
	    $base2diaLUT{$base}{$token}++;
	}
    }
}

### Loop through the terms.  Building ALL the variants
#foreach my $term(sort keys %{ $TERM->{TERMS} }){
#    print "------------------------------------------------------------------\n";
#    print "$term $TERM->{TERMS}{$term}->{TEXT}\n";
#    my @expansions = ();
#    foreach my $base(split(/\s+/,$TERM->{TERMS}{$term}->{TEXT})){
# 	$base =~ tr/A-Z/a-z/;
# 	if (exists($base2diaLUT{$base})){
# 	    push @expansions, [ $base2diaLUT{$base} ];
# 	} else {
# 	    push @expansions, [ ("N/A") ];
# 	}
#    }
# 
#    ### Make the variants
#    #print Dumper(\@expansions);
#}

foreach my $term(sort keys %{ $TERM->{TERMS} })
{
    my @expansions = ();
    
    foreach my $base(split(/\s+/, $TERM->{TERMS}{$term}->{TEXT}))
    {
        $base =~ tr/A-Z/a-z/;
        
        if (exists($base2diaLUT{$base}))
        {
            push @expansions, [ keys %{ $base2diaLUT{$base} } ];
        } 
        else 
        {
            push @expansions, [ ($base) ];
        }
    }
    
    #print Dumper(\@expansions);
    
    my %current;
    my %maxi;
    my $bigmaxi = 1;

    for(my $i=0; $i<@expansions; $i++)
    {
        $current{$i} = 0;
        $maxi{$i} = scalar @{ $expansions[$i] };
        $bigmaxi *= $maxi{$i}; 
    }
    
    my $cur = 0;
    $current{0} = -1;
    my $realTerms = 0;
    my $firstNewTerm = "";
    
    while($cur < $bigmaxi)
    {
        my $curpos = 0;
        my $ok = 0;
        
        while(!$ok)
        {
            $current{$curpos}++;
            
            if($current{$curpos} == $maxi{$curpos})
            {
                $current{$curpos} = 0;
                $curpos++;
            }
            else
            {
                $ok = 1;
            }
        }
     
        my $newterm = "$expansions[0][$current{0}]";
           
        for(my $i=1; $i<@expansions; $i++)
        {
            my $word = $expansions[$i][$current{$i}];
            $newterm .= " $word";
        }
        
        $cur++;
        my $displaycount = sprintf("%04d", $cur);
        my $newtermid = "$term" . "-$displaycount";
        $firstNewTerm = $newterm if ($firstNewTerm eq "");

	if ($findTermThreshold >= 0)
	{
	    my $occ = $RTTM->findTermOccurences($newterm, $findTermThreshold);
	    if (@{ $occ } > 0){
		$TERMOUT->{TERMS}{$newtermid} = new TermListRecord($newtermid, $newterm);
#		print "Add $newtermid\n";
		$realTerms++;
#	    } else {
#		print "Skipping $newtermid\n";
	    }
	} else {
	    $TERMOUT->{TERMS}{$newtermid} = new TermListRecord($newtermid, $newterm);
	    $realTerms++;
#	    print "Add $newtermid\n";
	}        
    }
    if ($realTerms == 0){
#	print "Adding term that already was an OOV $term\n";
	$TERMOUT->{TERMS}{$term} = new TermListRecord($term, $TERM->{TERMS}{$term}->{TEXT});
    }
}

$TERMOUT->saveFile();

MMisc::ok_exit();

############################################################

sub set_usage {
  my $tmp = "";
  $tmp .=  "$0 -t tlist -r rttmfile -o output_tlist [ -f threshhold ]\n";
  $tmp .=  "\n";
  $tmp .=  "Required file arguments:\n";
  $tmp .=  "  -t, --termfile           Path to the Term file.\n";
  $tmp .=  "  -r, --rttmfile           Path to the RTTM file.\n";
  $tmp .=  "  -o, --output-file        Path to the Output Tlist file.\n";
  $tmp .=  "  -f, --find-threshold     Filter the term set to exclude\n";
  $tmp .=  "                           terms not present in the RTTM using\n";
  $tmp .=  "                           the time threshhold\n";
  $tmp .=  "\n";
  
  return($tmp);
}
