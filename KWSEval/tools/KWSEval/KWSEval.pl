#!/usr/bin/env perl -w
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# KWSEval
# 
# Original Authors: Jerome Ajot, Jon Fiscus
# Additions: Martial Michel

# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. KWSEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

### Die on any warning and give a stack trace
#use Carp qw(cluck);
#$SIG{__WARN__} = sub { cluck "Warning:\n", @_, "\n";  die; };

# Test: perl KWSEval.pl -e ../test_suite/test2.ecf.xml -r ../test_suite/test2.rttm -s ../test_suite/test2.stdlist.xml -t ../test_suite/test2.tlist.xml -o -A

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.8b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "KWSEval Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../lib", "../../../common/lib");
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
foreach my $pn ("MMisc", "RTTMList", "KWSecf", "TermList", "KWSList", "KWSTools", "KWSMappedRecord", 'BipartiteMatch',
                "KWSAlignment", "CacheOccurrences", "KWSDETSet") {
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

my $ECFfile = "";
my $RTTMfile = "";
my $STDfile = "";
my $TERMfile = "";

my $thresholdFind = 0.5;
my $thresholdAlign = 0.5;
my $epsilonTime = 1e-8; #this weights time congruence in the joint mapping table
my $epsilonScore = 1e-6; #this weights score congruence in the joint mapping table

my $KoefV = 1;
my $KoefC = sprintf("%.4f", $KoefV/10);

my $trialsPerSec = 1;
my $probOfTerm = 0.0001;

my @isoPMISS = (0.0001, 0.001, 0.004, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 40, 60, 80, 90, 95, 98);
my @isoPFA = (0.0001);
#my @isoPFA = (0.0001, 0.001, 0.004, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 40);

my $displayall = 0;

my $requestreportAlign = 0;
my $requestreportOccur = 0;
my $requestconditionalreportOccur = 0;
my $requestDETCurve = 0;
my $requestDETConditionalCurve = 0;
my $PooledTermDETs = 0;
my $requestCSV = 0;

my $outputreportAlign = "-1";
my $outputreportOccur = "-1";
my $outputconditionalreportOccur = "-1";
my $outputreportDETCurve = "";
my $outputreportDETConditionalCurve = "";
my $outputCSV = "-1";

my $RTTMOcurencesCacheFile = "";
my $flagRTTMOcurencesCacheFile = "";

my $filterecf = 0;

my $haveReports = 0;

sub checksumSystemV
{
    my($filename) = @_;
    my $stringf = "";
    
    open(FILE, $filename) 
      or MMisc::error_quit("cannot open file '$filename' for checksum");
    
    while (<FILE>)
    {
        chomp;
        $stringf .= $_;
    }
    
    close(FILE);
    
    #clean unwanted spaces
    $stringf =~ s/\s+/ /g;
    $stringf =~ s/> </></g;
    $stringf =~ s/^\s+//;
    $stringf =~ s/\s+$//;
    
    return(unpack("%32b*", $stringf));
}

sub usage
{
	print "KWSEval.pl -e ecffile -r rttmfile -s stdfile -t termfile [ OPTIONS ]\n";
	print "\n";
	print "Required file arguments:\n";
	print "  -e, --ecffile            Path to the ECF file.\n";
	print "  -r, --rttmfile           Path to the RTTM file.\n";
	print "  -s, --stdfile            Path to the STDList file.\n";
	print "  -t, --termfile           Path to the TermList file.\n";
	print "\n";
	print "Find options:\n";
	print "  -F, --Find-threshold <thresh>\n";
	print "                           The <thresh> value represents the maximum time gap in\n";
	print "                           seconds between two words in order to consider the two words\n";
	print "                           to be part of a term when searching the RTTM file for reference\n";
	print "                           term occurrences. (default: 0.5).\n";
	print "  -S, --Similarity-threshold <thresh>\n";
	print "                           The <thresh> value represents the maximum time distance\n";
	print "                           between the temporal extent of the reference term and the\n";
	print "                           mid point of system's detected term for the two to be\n";
	print "                           considered a pair of potentially aligned terms. (default: 0.5).\n";
	print "\n";
	print "Filter options:\n";
	print "  -E, --ECF-filtering      System and reference terms must be in the ECF segments.\n";
	print "                           (default: off).\n";
	print "  -T, --Term [<set_name>:]<termid>[,<termid>[, ...]]\n";
	print "                           Only the <termid> or the list of <termid> (separated by ',')\n";
	print "                           will be displayed in the Conditional Occurrence Report and Con-\n";
	print "                           ditional DET Curve. An name can be given to the set by specify-\n";
	print "                           ing <set_name> (<termid> can be a regular expression).\n";
	print "  -Y, --YSourcetype [<set_name>:]<type>[,<type>[, ...]]\n";
	print "                           Only the <type> or the list of <type> (separated by ',') will\n";
	print "                           be displayed in the Conditional Occurrence Report and Condi-\n";
	print "                           tional DET Curve. An name can be given to the set by specifying\n";
	print "                           <set_name> (<type> can be a regular expression).\n";
	print "  -N, --Namefile <file/channel>[,<file/channel>[, ...]]\n";
	print "                           Only the <file> and <channel> or the list of <file> and <chan-\n";
	print "                           nel> (separated by ',') will be displayed in the Occurrence\n";
	print "                           Report and DET Curve (<file> and <channel> can be regular\n";
	print "                           expressions).\n";
	print "  -q, --query <name_attribute>\n";
	print "                           Populate the Conditional Reports with set of terms identified by\n";
	print "                           <name_attribute> in the the term list's 'terminfo' tags.\n";
	print "  -w, --words-oov          Generate a Conditional Report sorted by terms that are \n";
	print "                           Out-Of-Vocabulary (OOV) for the system.\n";
	print "\n";
	print "Report options:\n";
	print "  -a, --align-report [<file>] Output the Alignment Report.\n";
	print "  -o, --occurrence-report [<file>] Output the Occurrence Report.\n";
	print "  -O, --Occurrence-conditionalreport [<file>] Output the Conditional Occurrence Report.\n";
	print "  -d, --det-curve <file>    Output the DET Curve.\n";
	print "  -i, --iso-lines [<coef>[,<coef>[, ...]]]\n";
	print "                            Include the iso line information inside the serialized det curve.\n";
	print "                            Every <coef> can be specified, or it uses those by default.\n";
	print "                            The <coef> is the ratio Pmiss/Pfa.\n";
	print "  -D, --DET-conditional-curve <file> Output the Conditional DET Curve.\n";
	print "  -P, --Pooled-DETs        Produce term occurrence DET Curves instead of 'Term Weighted' DETs.\n";
	print "  -C, --CSV [<file>]       Output the CSV Report.\n";
	print "  -H, --HTML <folder>      Output the Occurrence HTML Report.\n";
	print "  -Q, --QHTML <folder>     Output the Conditional Occurrence HTML Report.\n";
	print "  -A, --All-display        Add an additional column in the Occurrence report containing\n";
	print "                           the overall statistics for every terms (default: off).\n";
	print "  -k, --koefcorrect <value> Value for correct (C).\n";
	print "  -K, --Koefincorrect <value> Value for incorrect (V).\n";
	print "  -n, --number-trials-per-sec <value>  The number of trials per second. (default: 1)\n";
	print "  -p, --prob-of-term <value>  The probability of a term. (default: 0.0001)\n";
	print "  -I, --ID-System <name>   Overwrites the name of the STD system.\n";
	print "\n";
	print "Other options:\n";
	print "  -c, --cache-find <file>  Use the caching file for finding occurrences. If the file\n";
	print "                           does not exist, it creates the cache during the search.\n";
	print "\n";
}

my @arrayparseterm;
my $numberFiltersTermArray = 0;
my %filterTermArray;

my @arraycmdline;
my @arrayparsefile;

my @arrayparsetype;
my $numberFiltersTypeArray = 0;
my %filterTypeArray;

my $htmlfolder = "";
my $requestHtml = 0;

my $conditionalhtmlfolder = "";
my $requestConditionalHtml = 0;

my $threshchecktrans = -1.0;
my $resquestchecktrans = 0;

my $requestwordsoov = 0;
my $IDSystem = "";

my $OptionIsoline = "";
my @listIsolineCoef = ();

my @Queries;

GetOptions
(
    'ecffile=s'                           => \$ECFfile,
    'rttmfile=s'                          => \$RTTMfile,
    'stdfile=s'                           => \$STDfile,
    'termfile=s'                          => \$TERMfile,
    'Find-threshold=f'                    => \$thresholdFind,
    'Similarity-threshold=f'              => \$thresholdAlign,
    'All-display'                         => \$displayall,
    'align-report:s'                      => \$outputreportAlign,
    'occurrence-report:s'                 => \$outputreportOccur,
    'Occurrence-conditionalreport:s'      => \$outputconditionalreportOccur,
    'Term=s@'                             => \@arrayparseterm,
    'query=s@'                            => \@Queries,
    'Namefile=s@'                         => \@arraycmdline,
    'YSourcetype=s@'                      => \@arrayparsetype,
    'ECF-filtering'                       => \$filterecf,
    'det-curve=s'                         => \$outputreportDETCurve,
    'iso-lines:s'                         => \$OptionIsoline,
    'DET-conditional-curve=s'             => \$outputreportDETConditionalCurve,
    'cache-find=s'                        => \$RTTMOcurencesCacheFile,
    'CSV:s'                               => \$outputCSV,
    'HTML=s'                              => \$htmlfolder,
    'QHTML=s'                             => \$conditionalhtmlfolder,
    'koefcorrect=f'                       => \$KoefC,
    'Koefincorrect=f'                     => \$KoefV,
    'number-trials-per-sec=f'             => \$trialsPerSec,
    'prob-of-term=f'                      => \$probOfTerm,
    'Pooled-DETs'                         => \$PooledTermDETs,
    'version'                             => sub { print "STDEval version: $version\n"; exit },
    'help'                                => sub { usage (); exit },
    'x=f'                                 => \$threshchecktrans,
    'words-oov'                           => \$requestwordsoov,
    'ID-System=s'                         => \$IDSystem,
);

#checking transcript
$resquestchecktrans = 1 if($threshchecktrans != -1.0);

#parsing TermIDs
$numberFiltersTermArray = @arrayparseterm;

for(my $i=0; $i<$numberFiltersTermArray; $i++)
{
    my @tmp = split(/:/, join(':', $arrayparseterm[$i]));
    @{ $filterTermArray{$tmp[0]} } = split(/,/, join(',', $tmp[(@tmp==1)?0:1]));
}

#parsing Filenames and channels
my @tmpfile = split(/,/, join(',', @arraycmdline));

for(my $j=0; $j<@tmpfile; $j++)
{
    push(@arrayparsefile, [ split("\/", $tmpfile[$j]) ]);
}

#parsing Sourcetypes
$numberFiltersTypeArray = @arrayparsetype;

for(my $i=0; $i<$numberFiltersTypeArray; $i++)
{
    my @tmp = split(/:/, join(':', $arrayparsetype[$i]));
    @{ $filterTypeArray{$tmp[0]} } = split(/,/, join(',', $tmp[(@tmp==1)?0:1]));
}

if($numberFiltersTypeArray == 0)
{
    $numberFiltersTypeArray = 1;
    $filterTypeArray{''} = [()];
}

$requestreportAlign = 1 if($outputreportAlign ne "-1");
$requestreportOccur = 1 if($outputreportOccur ne "-1");
$requestconditionalreportOccur = 1 if($outputconditionalreportOccur ne "-1");
$requestDETCurve = 1 if($outputreportDETCurve ne "");
$requestDETConditionalCurve = 1 if($outputreportDETConditionalCurve ne "");
$requestCSV = 1 if($outputCSV ne "-1");
$requestHtml = 1 if($htmlfolder ne "");
$requestConditionalHtml = 1 if($conditionalhtmlfolder ne "");

# Isoline Option
my @tmplistiso1 = ();
my @tmplistiso2 = ();

if( $OptionIsoline eq "" )
{
	# Create the default list of coefficients
	foreach my $PFAi ( @isoPFA )
	{
		foreach my $PMISSi ( @isoPMISS )
		{
			push( @tmplistiso1, $PMISSi/$PFAi );
		}
	}
}
else
{
	# Use the list given on the command-line
	foreach my $coefi ( split( /,/ , $OptionIsoline ) )
	{
		MMisc::error_quit("The coefficient for the iso-line if not a proper floating-point")
      if( $coefi !~ /^\d+(\.\d+)?$/ );
		push( @tmplistiso1, $coefi );
	}
}

@tmplistiso2 = KWSTools::unique(@tmplistiso1);
@listIsolineCoef = sort {$a <=> $b} @tmplistiso2;

$haveReports = $requestreportAlign || $requestreportOccur || $requestDETCurve || $requestCSV || $requestHtml || $requestconditionalreportOccur || $requestDETConditionalCurve || $resquestchecktrans || $requestConditionalHtml;

#check if the options are valid to run
MMisc::error_quit("An RTTM file must be set")
  if($RTTMfile eq "");
MMisc::error_quit("A TermList file must be set")
  if($TERMfile eq "");

if($haveReports)
{
    MMisc::error_quit("An ECF file must be set")
      if($ECFfile eq "");
    MMisc::error_quit("An STDList file must be set")
      if($STDfile eq "");
}

#loading the files
my $ECF;
my $RTTM = new RTTMList($RTTMfile);
my $STD;
my $TERM = new TermList($TERMfile);

if($haveReports)
{
    $ECF = new KWSecf($ECFfile);
    $STD = new KWSList($STDfile);
    $STD->SetSystemID($IDSystem) if($IDSystem ne "");
}

#Queries for Termlist
if(@Queries)
{
    $TERM->QueriesToTermSet(\@Queries, \%filterTermArray);
}

if( ($requestconditionalreportOccur || $requestConditionalHtml) && $requestwordsoov)
{
    my @arraytermsoov = ();
    my @arraytermsiv = ();
    $STD->listOOV(\@arraytermsoov);
    $STD->listIV(\@arraytermsiv);
    @{ $filterTermArray{'Out-of-Vocabulary'} } = @arraytermsoov;
    @{ $filterTermArray{'In-Vocabulary'} } = @arraytermsiv;
}

# clean the filter for terms
$numberFiltersTermArray = keys %filterTermArray;

if($numberFiltersTermArray == 0)
{
    $numberFiltersTermArray = 1;
    $filterTermArray{''} = [()];
}

my $RefList = {};
my $HypList = {};

$flagRTTMOcurencesCacheFile = ((-e $RTTMOcurencesCacheFile) ? "r" : "w") if($RTTMOcurencesCacheFile ne "");

if($flagRTTMOcurencesCacheFile eq "r")
{
	print STDERR "Cache file found - Using '$RTTMOcurencesCacheFile' for RTTM occurrences.\n";
	
    my $checksum = 0;
    my $cachingOcc = new CacheOccurrences($RTTMOcurencesCacheFile, $checksum, $thresholdFind, $RefList);
    $cachingOcc->loadFile($TERM);
    
    if($cachingOcc->{SYSTEMVRTTM} != checksumSystemV($RTTMfile))
    {
        print STDERR "WARNING: RTTM Checksum missmatch: ignoring cache information!\n";
        $flagRTTMOcurencesCacheFile = "";
    }
    
    if($cachingOcc->{THRESHOLD} != $thresholdFind)
    {
        print STDERR "WARNING: Threshold in caching ($cachingOcc->{THRESHOLD}) missmatch the current threshold ($thresholdFind): ignoring cache information!\n";
        $flagRTTMOcurencesCacheFile = "";
    }
}
elsif($flagRTTMOcurencesCacheFile eq "w")
{
	print STDERR "Cache file not found - Will generate the cache file '$RTTMOcurencesCacheFile'.\n";
}

print STDERR "Processing Alignment.\n";

my %mappings;

foreach my $termsid(sort keys %{ $TERM->{TERMS} })
{
    my $terms = $TERM->{TERMS}{$termsid}->{TEXT};

    if($flagRTTMOcurencesCacheFile ne "r")
    {
        #find occurrences for ref
        my $roccurrences = $RTTM->findTermOccurrences($terms, $thresholdFind);
        
        for(my $i=0; $i<@$roccurrences; $i++)
        {
            my $file = @{ $roccurrences->[$i] }[0]->{FILE};
            my $chan = @{ $roccurrences->[$i] }[0]->{CHAN};
            my $bt = @{ $roccurrences->[$i] }[0]->{BT};
            my $numberoftoken = @{ $roccurrences->[$i] };
            my $et = @{ $roccurrences->[$i] }[$numberoftoken-1]->{ET};
            my $dur = sprintf("%.4f", $et - $bt);
            #my $rttm = \@{ $roccurrences->[$i] };
                        
            push( @{ $RefList->{$termsid}{$terms} }, new KWSTermRecord($file, $chan, $bt, $dur, undef, undef));
        }
    }
    
    if($haveReports)
    {
        $mappings{$termsid} = new KWSMappedRecord();
        $mappings{$termsid}->{UNMAPPED_SYS} = [()];
        $mappings{$termsid}->{UNMAPPED_REF} = [()];
        $mappings{$termsid}->{MAPPED} = [()];
        
        my %ref_occs;
        my %miss_values;
        
        if($RefList->{$termsid}{$terms})
        {
            #terms in the Ref
            for(my $i=0; $i<@{ $RefList->{$termsid}{$terms} }; $i++)
            {
                next if $filterecf and not $ECF->FilteringTime($RefList->{$termsid}{$terms}[$i]->{FILE}, $RefList->{$termsid}{$terms}[$i]->{CHAN}, $RefList->{$termsid}{$terms}[$i]->{BT}, $RefList->{$termsid}{$terms}[$i]->{ET});
                $ref_occs{$i+1} = $RefList->{$termsid}{$terms}[$i];
                $miss_values{$i+1} = 0;
           }
        }
        
        #find occurrences for sys
        $HypList->{$termsid}{$terms} = $STD->{TERMS}{$termsid};
        
        my %sys_occs;
        my %fa_values;
        
        if($HypList->{$termsid}{$terms}->{TERMS})
        {
            #terms in the Hyp      
            for(my $j=0; $j<@{ $HypList->{$termsid}{$terms}->{TERMS} }; $j++)
            {
                next if $filterecf and not $ECF->FilteringTime($HypList->{$termsid}{$terms}->{TERMS}[$j]->{FILE}, $HypList->{$termsid}{$terms}->{TERMS}[$j]->{CHAN}, $HypList->{$termsid}{$terms}->{TERMS}[$j]->{BT}, $HypList->{$termsid}{$terms}->{TERMS}[$j]->{ET});
                $sys_occs{$j+1} = $HypList->{$termsid}{$terms}->{TERMS}[$j];
                $fa_values{$j+1} = -1;
            }
        }
        
        # compute joint values
        my %joint_values;
        
        while (my($ref_id, $ref_occ) = each %ref_occs)
        {
            while (my($sys_id, $sys_occ) = each %sys_occs)
            {
                next if ( $sys_occ->{FILE} ne $ref_occ->{FILE} or
                          $sys_occ->{CHAN} ne $ref_occ->{CHAN} or
                          $sys_occ->{MID} > $ref_occ->{ET}+$thresholdAlign or
                          $sys_occ->{MID} < $ref_occ->{BT}-$thresholdAlign );
        
                my $time_congruence = (min($ref_occ->{ET}, $sys_occ->{ET}) - max($ref_occ->{BT}, $sys_occ->{BT}))/max(0.00001,$ref_occ->{DUR});
                my $score_congruence = 0;
                
                if($STD->{DIFF_SCORE} != 0)
                {
                    $score_congruence = ($sys_occ->{SCORE} - $STD->{MIN_SCORE}) / ($STD->{DIFF_SCORE});
                }
                                
                $joint_values{$ref_id}{$sys_id} = 1 + $epsilonTime * $time_congruence + $epsilonScore * $score_congruence;
            }
        }
        
        #compute mapping
        my ($err, %Rmap) = BipartiteMatch::_map_ref_to_sys(\%joint_values, \%fa_values, \%miss_values, 0);
        my $map = \%Rmap;

        while (my($ref_id, $sys_id) = each %$map)
        {
            push(@{ $mappings{$termsid}->{MAPPED} }, [ ($sys_occs{$sys_id}, $ref_occs{$ref_id}) ]);
            delete $ref_occs{$ref_id};
            delete $sys_occs{$sys_id};
        }
            
        foreach my $ref_occ (values %ref_occs)
        {
            push(@{ $mappings{$termsid}->{UNMAPPED_REF} }, $ref_occ);
        }
        
        foreach my $sys_occ (values %sys_occs)
        {
            push(@{ $mappings{$termsid}->{UNMAPPED_SYS} }, $sys_occ);
        }
    }
}

if($flagRTTMOcurencesCacheFile eq "w")
{
    my $cachingOcc = new CacheOccurrences($RTTMOcurencesCacheFile, checksumSystemV($RTTMfile), $thresholdFind, $RefList);
    $cachingOcc->saveFile($TERM);
}

# STD Alignment structure for reports
if($haveReports)
{
    my $stdAlign = new KWSAlignment($STD, $TERM, $ECF, \%mappings, $KoefC, $KoefV);
    
    # Align report
    $stdAlign->ReportAlign($outputreportAlign) if($requestreportAlign);
    
    #Check Transcript
    if($resquestchecktrans)
    {
        $stdAlign->transcriptCheckReport("", $threshchecktrans);
    }
    
    # Conditional Occurrence Report
    if($requestconditionalreportOccur || $requestDETConditionalCurve || $requestConditionalHtml)
    {
        my $allresults_Occ;
        my $allresults_DET;
        my %results_Occ;
        my %results_DET;
        my $dset = new KWSDETSet();
        
        foreach my $titleTerm(sort keys %filterTermArray)
        {
            foreach my $titleType(sort keys %filterTypeArray)
            {                    
                $results_Occ{$titleTerm}{$titleType} = $stdAlign->GenerateOccurrenceReport(\@{ $filterTermArray{$titleTerm} }, \@arrayparsefile, \@{ $filterTypeArray{$titleType} }, $trialsPerSec, $probOfTerm, $KoefV, $KoefC);
                
                my $lineTitle = "Terms:".($titleTerm eq "" ? "All" : $titleTerm)." Sources:".($titleType eq "" ? "All" : $titleType);
                
                if($requestDETConditionalCurve)
                {
                    $results_DET{$titleTerm}{$titleType} = $stdAlign->GenerateDETReport(\@{ $filterTermArray{$titleTerm} }, \@arrayparsefile, \@{ $filterTypeArray{$titleType} }, $lineTitle, $KoefV, $KoefC, $trialsPerSec, $probOfTerm, $PooledTermDETs);

                    if (! $results_DET{$titleTerm}{$titleType}->successful())
                    {
                        print STDERR "Warning: Failed to produce DET plot for Termset '$titleTerm' and '$titleType'\n";
                    }
                    else
                    {
                        $dset->addDET($results_DET{$titleTerm}{$titleType}, "$titleTerm $titleType");
                    }
                }
            }
        }
        
        $allresults_Occ = $stdAlign->CopyConditionalOccurrenceReports(\%results_Occ);
        $stdAlign->ReportConditionalOccurrence($outputconditionalreportOccur, $allresults_Occ, $dset) if($requestconditionalreportOccur);   

        if($requestDETConditionalCurve)
        {
            $dset->writeMultiDET($outputreportDETConditionalCurve);
        }
        
        # html
        if($requestConditionalHtml)
        {
            $stdAlign->ReportConditionalHTML($conditionalhtmlfolder, $allresults_Occ, $dset);
        }
    }
    
    # Occurrence Report
    if($requestDETCurve || $requestreportOccur || $requestHtml)
    {
        my $allresults_Occ = $stdAlign->GenerateOccurrenceReport(\@{ $filterTermArray{''} }, \@arrayparsefile, \@{ $filterTypeArray{''} }, $trialsPerSec, $probOfTerm, $KoefV, $KoefC);
        my $dset = new KWSDETSet();
        
        if ($displayall && $requestDETCurve)
        {
            my $det = $stdAlign->GenerateDETReport(\@{ $filterTermArray{''} }, \@arrayparsefile, \@{ $filterTypeArray{''} }, $stdAlign->{STD}->{SYSTEM_ID}." : ALL Data", $KoefV, $KoefC, $trialsPerSec, $probOfTerm, $PooledTermDETs);

            if (! $det->successful())
            {
                print STDERR "Warning: Failed to produce DET plot for ALL data\n";
            }

            $dset->addDET($det, "ALL");
        }
        
        if ($requestDETCurve)
        {
            ###Compute a DET Curve for each source type present
            my %occFiltTypeArr = ();

            for (my $i=0; $i<@{ $stdAlign->{ECF}->{EXCERPT} }; $i++)
            {
                $occFiltTypeArr{uc($stdAlign->{ECF}->{EXCERPT}[$i]->{SOURCE_TYPE})} = [ ( uc($stdAlign->{ECF}->{EXCERPT}[$i]->{SOURCE_TYPE}) )];
            }

            foreach my $stype(keys %occFiltTypeArr)
            {
                my $det = $stdAlign->GenerateDETReport(\@{ $filterTermArray{''} }, \@arrayparsefile, \@{ $occFiltTypeArr{$stype} }, "$stdAlign->{STD}->{SYSTEM_ID}: $stype Subset", $KoefV, $KoefC, $trialsPerSec, $probOfTerm, $PooledTermDETs, \@listIsolineCoef);

                if (! $det->successful())
                {
                    print STDERR "Warning: Failed to produce DET plot for $stype subset data\n";
                }
                
                $dset->addDET($det, $stype);
            }
        }
        
        $stdAlign->ReportOccurrence($outputreportOccur, $displayall, $allresults_Occ, $dset) if($requestreportOccur); 

        if ($requestDETCurve)
        {
            $dset->writeMultiDET($outputreportDETCurve);
        }
    
        # html
        if($requestHtml)
        {
            $stdAlign->ReportHTML($htmlfolder, $displayall, $allresults_Occ, $dset);
        }
    }
    
    # csv
    $stdAlign->csvReport($outputCSV) if($requestCSV);
}

exit 0;
