#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# KWSEval
# 
# Original Authors: Jerome Ajot, Jon Fiscus
# Additions: Martial Michel, David Joy

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

### Die on any warning and give a stack trace
#use Carp qw(cluck);
#$SIG{__WARN__} = sub { cluck "Warning:\n", @_, "\n";  die; };

# Test: perl KWSEval.pl -e ../test_suite/test2.ecf.xml -r ../test_suite/test2.rttm -s ../test_suite/test2.stdlist.xml -t ../test_suite/test2.tlist.xml -o -A

use strict;
use Encode;
use encoding 'euc-cn';
use encoding 'utf8';

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

#foreach my $f4dedir (@f4bv) { print $f4dedir . "\n"; }

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
                "KWSAlignment", "KWSSegAlign", "CacheOccurrences", "DETCurveSet", "DETCurve", "MetricTWV", "TrialsTWV") {
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

# something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

####################

my $ECFfile = "";
my $RTTMfile = "";
my $STDfile = "";
my $TERMfile = "";

my $thresholdFind = 0.5;
my $thresholdAlign = 0.5;
#my $epsilonTime = 1e-8; #this weights time congruence in the joint mapping table
#my $epsilonScore = 1e-6; #this weights score congruence in the joint mapping table

my $KoefV = 1;
my $KoefC = sprintf("%.4f", $KoefV/10);

my $trialsPerSec = 1;
my $probOfTerm = 0.0001;

my @isoPMISS = (0.0001, 0.001, 0.004, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 40, 60, 80, 90, 95, 98);
my @isoPFA = (0.0001);

my $displayall = 0;

my $segmentbased = 0;
my $requestSumReport = 0;
my $requestBlockSumReport = 0;
my $requestCondSumReport = 0;
my $requestCondBlockSumReport = 0;
my $requestDETCurve = 0;
my $requestDETConditionalCurve = 0;
my $PooledTermDETs = 0;
my $cleanDETsFolder = 0;
my $requestalignCSV = 0;
my $includeNoTargBlocks = 0;

my $reportOutTypes = [ "TXT" ];

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

my @arrayparseterm;
my $numberFiltersTermArray = 0;
my %filterTermArray;

my @arraycmdline;
my @arrayparsefile;

my @arrayparsetype;
my $numberFiltersTypeArray = 0;
my %filterTypeArray;

my $fileRoot = "";

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
    'file-root=s'                         => \$fileRoot,
    'osummary-report'                     => \$requestSumReport,
    'block-summary-report'                => \$requestBlockSumReport,
    'Osummary-conditional-report'         => \$requestCondSumReport,
    'Block-summary-conditional-report'    => \$requestCondBlockSumReport,
    'Term=s@'                             => \@arrayparseterm,
    'query=s@'                            => \@Queries,
    'Namefile=s@'                         => \@arraycmdline,
    'YSourcetype=s@'                      => \@arrayparsetype,
    "gsegment-based-alignment"            => \$segmentbased,
    'iso-lines:s'                         => \$OptionIsoline,
    'det-curve'                           => \$requestDETCurve,
    'DET-conditional-curve'               => \$requestDETConditionalCurve,
    'Clean-DETs-folder'                   => \$cleanDETsFolder,
    'csv-of-alignment'                    => \$requestalignCSV,
    'ytypes-of-report-output=s@'          => \$reportOutTypes,
    'koefcorrect=f'                       => \$KoefC,
    'Koefincorrect=f'                     => \$KoefV,
    'number-trials-per-sec=f'             => \$trialsPerSec,
    'prob-of-term=f'                      => \$probOfTerm,
    'Pooled-DETs'                         => \$PooledTermDETs,
    'version'                             => sub { MMisc::ok_quit($versionid); },
    'help'                                => sub { MMisc::ok_quit($usage); },
    'words-oov'                           => \$requestwordsoov,
    'include-blocks-w-notargs'            => \$includeNoTargBlocks,
    'ID-System=s'                         => \$IDSystem,
) or MMisc::error_quit("Unknown option(s)\n\n$usage\n");

#parsing TermIDs
$numberFiltersTermArray = @arrayparseterm;
for(my $i=0; $i<$numberFiltersTermArray; $i++) {
    my @tmp = split(/:/, join(':', $arrayparseterm[$i]));
    @{ $filterTermArray{$tmp[0]} } = split(/,/, join(',', $tmp[(@tmp==1)?0:1]));
}

#parsing Filenames and channels
my @tmpfile = split(/,/, join(',', @arraycmdline));
for(my $i=0; $i<@tmpfile; $i++) {
    push(@arrayparsefile, [ split("\/", $tmpfile[$i]) ]);
}

#parsing Sourcetypes
$numberFiltersTypeArray = @arrayparsetype;
for(my $i=0; $i<$numberFiltersTypeArray; $i++) {
    my @tmp = split(/:/, join(':', $arrayparsetype[$i]));
    @{ $filterTypeArray{$tmp[0]} } = split(/,/, join(',', $tmp[(@tmp==1)?0:1]));
}

$requestalignCSV = 1 if(defined $requestalignCSV);

# Isoline Option
my @tmplistiso1 = ();
my @tmplistiso2 = ();

if( $OptionIsoline eq "" ) {
	# Create the default list of coefficients
	foreach my $PFAi ( @isoPFA ) {
		foreach my $PMISSi ( @isoPMISS ) {
			push( @tmplistiso1, $PMISSi/$PFAi );
		}
	}
}
else {
	# Use the list given on the command-line
	foreach my $coefi ( split( /,/ , $OptionIsoline ) ) {
		MMisc::error_quit("The coefficient for the iso-line if not a proper floating-point")
      if( $coefi !~ /^\d+(\.\d+)?$/ );
		push( @tmplistiso1, $coefi );
	}
}

@tmplistiso2 = KWSTools::unique(@tmplistiso1);
@listIsolineCoef = sort {$a <=> $b} @tmplistiso2;

$haveReports = $requestSumReport || $requestBlockSumReport || $requestCondSumReport || $requestCondBlockSumReport || $requestalignCSV || $requestDETConditionalCurve;
MMisc::error_quit("Must include a file root") if ($fileRoot eq "");

if ($fileRoot =~ m:/[^/]+$:) { $fileRoot .= "."; } #if the fileroot has a prepend string add a '.'
###Error breakouts before loading
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

my $groupBySrcType = 0; $groupBySrcType = 1 if (keys %filterTypeArray > 0);
my $groupByTerm = 0; $groupByTerm = 1 if (keys %filterTermArray > 0);
my $groupByAttr = 0; $groupByAttr = 1 if (@Queries > 0);
if ($groupBySrcType + $groupByTerm + $groupByAttr + $requestwordsoov > 1) {
  MMisc::error_quit("Cannot specify more than one condition (-Y, -q, -T) for the conditional report");
} #Perhaps a more descriptive error

###loading the files
my $ECF;
my $STD;

if($haveReports) {
    $ECF = new KWSecf($ECFfile);
    $STD = new KWSList($STDfile);
    $STD->SetSystemID($IDSystem) if($IDSystem ne "");
}
my $TERM = new TermList($TERMfile);
my $RTTM = new RTTMList($RTTMfile, $TERM->getLanguage(), $TERM->getCompareNormalize(), $TERM->getEncoding());  

# clean the filter for terms
$numberFiltersTermArray = keys %filterTermArray;

####Alignments
my @alignResults;
my ($dset, $qdset);
my @filters = ();
my $groupBySubroutine = undef;
my $alignmentCSV = "";
if ($requestalignCSV == 1) {
  if ($fileRoot ne "-") { $alignmentCSV = $fileRoot . "alignment.csv"; }
  else { $alignmentCSV = "alignment.csv"; }
}
if ($segmentbased != 0)
{
###Segment based Alignment
  my $segAlignment = new KWSSegAlign($RTTM, $STD, $ECF, $TERM);
  $segAlignment->setFilterData(\%filterTypeArray, \%filterTermArray, \@arraycmdline, \@Queries);

#Setup segment filters
  push (@filters, \&KWSSegAlign::filterByFileChan) if (@arraycmdline > 0);

  $groupBySubroutine = \&KWSSegAlign::groupByECFSourceType if ($groupBySrcType == 1);
  $groupBySubroutine = \&KWSSegAlign::groupByTerms if ($groupByTerm == 1);
  $groupBySubroutine = \&KWSSegAlign::groupByAttributes if ($groupByAttr == 1);
  $groupBySubroutine = \&KWSSegAlign::groupByOOV if ($requestwordsoov == 1);

  #Align
  @alignResults = @{ $segAlignment->alignSegments($alignmentCSV, \@filters, $groupBySubroutine, $thresholdFind, $KoefC, $KoefV, $probOfTerm, \@listIsolineCoef, $PooledTermDETs, $includeNoTargBlocks) };
}
else
{
###Occurence based Alignment
  my $alignment = new KWSAlignment($RTTM, $STD, $ECF, $TERM);
  $alignment->setFilterData(\%filterTypeArray, \%filterTermArray, \@arraycmdline, \@Queries);

#Setup filters
  push (@filters, \&KWSAlignment::filterByFileChan) if (@arraycmdline > 0);

  $groupBySubroutine = \&KWSAlignment::groupByECFSourceType if ($groupBySrcType == 1);
  $groupBySubroutine = \&KWSAlignment::groupByTerms if ($groupByTerm == 1);
  $groupBySubroutine = \&KWSAlignment::groupByAttributes if ($groupByAttr == 1);
  $groupBySubroutine = \&KWSAlignment::groupByOOV if ($requestwordsoov == 1);

  #Align
  @alignResults = @{ $alignment->alignTerms($alignmentCSV, \@filters, $groupBySubroutine, $thresholdFind, $thresholdAlign, $KoefC, $KoefV, \@listIsolineCoef, $trialsPerSec, $probOfTerm, $PooledTermDETs, $includeNoTargBlocks) };
}

#Set dets
my $detoptions = { ("Xmin" => .0001,
                    "Xmax" => 40,
                    "Ymin" => 5,
                    "Ymax" => 98,
                    "DETShowPoint_Actual" => 1,
                    "DETShowPoint_Best" => 1,
                    "xScale" => "nd",
                    "yScare" => "nd",
                    "ColorScheme" => "color",
                    "createDETfiles" => 1,
                    "serialize" => 1 ) };

$dset = $alignResults[0];
$qdset = $alignResults[1];

##Render reports
my $detsPath = "";
if ($fileRoot ne "-") { $detsPath = $fileRoot . "dets/"; }
else { $detsPath = "dets/"; }
if ($requestDETCurve || $requestDETConditionalCurve) {
  if ((not mkdir ($detsPath)) && $cleanDETsFolder == 1) {
    MMisc::error_quit($detsPath ." already exists, cleaning it may lead to unwanted results"); }
}

my $file;
foreach my $reportOutType (@{ $reportOutTypes }) {
  next if (! $reportOutType =~ /(TXT|CSV|HTML)/i);
#Render summary reports
  if ($requestSumReport) {
    if ($fileRoot eq "-") { $file = "-"; }
    else { $file = $fileRoot . "sum." . lc $reportOutType; }

    print "Summary Report: " . $file . "\n";
    open (SUMREPORT, ">$file");
    #set binmode
    if ($RTTM->{ENCODING} ne ""){
      binmode(SUMREPORT, $RTTM->getPerlEncodingString());
    }
    my $detsPath = "";
    if ($fileRoot ne "-") { $detsPath = $fileRoot . "dets/sum" }
    else { $detsPath = "dets/sum"; }
    print SUMREPORT $dset->renderReport($detsPath, $requestDETCurve, 1, $detoptions, $reportOutType);
    close (SUMREPORT);
  }
  if ($requestBlockSumReport) {
    if ($fileRoot eq "-") { $file = "-"; }
    else { $file = $fileRoot . "bsum." . lc $reportOutType; }
    
    print "Block Summary Report: " . $file . "\n";
    open (BSUMREPORT, ">$file");
    #set binmode
    if ($RTTM->{ENCODING} ne ""){
      binmode(BSUMREPORT, $RTTM->getPerlEncodingString());
    }
    print BSUMREPORT $dset->renderBlockedReport($reportOutType, $segmentbased); #shows Corr!Det if segment based
    close (BSUMREPORT);
  }
  
#Render conditional summary reports
  if ($requestCondSumReport) {
    if ($fileRoot eq "-") { $file = "-"; }
    else { $file = $fileRoot . "cond.sum." . lc $reportOutType; }
    
    print "Conditional Summary Report: " . $file . "\n";
    open (QSUMREPORT, ">$file");
    #set binmode
    if ($RTTM->{ENCODING} ne ""){
      binmode(QSUMREPORT, $RTTM->getPerlEncodingString());
    }
    my $detsPath = "";
    if ($fileRoot ne "-") { $detsPath = $fileRoot . "dets/cond.sum" }
    else { $detsPath = "dets/cond.sum"; }
    print QSUMREPORT $qdset->renderReport($detsPath, $requestDETConditionalCurve, 1, $detoptions, $reportOutType);
    close (QSUMREPORT);
  }
  if ($requestCondBlockSumReport) {
    if ($fileRoot eq "-") { $file = "-"; }
    else { $file = $fileRoot . "cond.bsum." . lc $reportOutType; }
    
    print "Conditional Block Summary Report: " . $file . "\n";
    open (QBSUMREPORT, ">$file");
    #set binmode
    if ($RTTM->{ENCODING} ne ""){
      binmode(QBSUMREPORT, $RTTM->getPerlEncodingString());
    }
    print QBSUMREPORT $qdset->renderBlockedReport($reportOutType, $segmentbased); #shows Corr!Det if segment based
    close (QBSUMREPORT);
  }
}
###

##Clean DETS folder
if ($cleanDETsFolder) {
  my $dir2clean = $fileRoot . $detsPath;
  opendir (DIR, $dir2clean) or MMisc::error_quit("Cannot locate DETs directory to clean.");
#  print "About to remove ..\n";
  my @files2rm = ();
  while (my $file = readdir(DIR)) {
    next if ($file =~ /^\.{1,2}/ || $file =~ /\.png$/i || $file =~ /\.srl\.gz$/i);
    push (@files2rm, $dir2clean . $file);
#    print $dir2clean . $file . "\n";
  }
  unlink @files2rm;
}
##

MMisc::ok_exit();

############################################################

sub set_usage {
  my $tmp = "";

	$tmp .= "KWSEval.pl -e ecffile -r rttmfile -s stdfile -t termfile -f fileroot [ OPTIONS ]\n";
	$tmp .= "\n";
	$tmp .= "Required file arguments:\n";
	$tmp .= "  -e, --ecffile            Path to the ECF file.\n";
	$tmp .= "  -r, --rttmfile           Path to the RTTM file.\n";
	$tmp .= "  -s, --stdfile            Path to the STDList file.\n";
	$tmp .= "  -t, --termfile           Path to the TermList file.\n";
	$tmp .= "\n";
	$tmp .= "Find options:\n";
	$tmp .= "  -F, --Find-threshold <thresh>\n";
	$tmp .= "                           The <thresh> value represents the maximum time gap in\n";
	$tmp .= "                           seconds between two words in order to consider the two words\n";
	$tmp .= "                           to be part of a term when searching the RTTM file for reference\n";
	$tmp .= "                           term occurrences. (default: 0.5).\n";
	$tmp .= "  -S, --Similarity-threshold <thresh>\n";
	$tmp .= "                           The <thresh> value represents the maximum time distance\n";
	$tmp .= "                           between the temporal extent of the reference term and the\n";
	$tmp .= "                           mid point of system's detected term for the two to be\n";
	$tmp .= "                           considered a pair of potentially aligned terms. (default: 0.5).\n";
	$tmp .= "\n";
	$tmp .= "Filter options:\n";
	$tmp .= "  -T, --Term [<set_name>:]<termid>[,<termid>[, ...]]\n";
	$tmp .= "                           Only the <termid> or the list of <termid> (separated by ',')\n";
	$tmp .= "                           will be displayed in the Conditional Occurrence Report and Con-\n";
	$tmp .= "                           ditional DET Curve. An name can be given to the set by specify-\n";
	$tmp .= "                           ing <set_name> (<termid> can be a regular expression).\n";
	$tmp .= "  -Y, --YSourcetype [<set_name>:]<type>[,<type>[, ...]]\n";
	$tmp .= "                           Only the <type> or the list of <type> (separated by ',') will\n";
	$tmp .= "                           be displayed in the Conditional Occurrence Report and Condi-\n";
	$tmp .= "                           tional DET Curve. An name can be given to the set by specifying\n";
	$tmp .= "                           <set_name> (<type> can be a regular expression).\n";
	$tmp .= "  -N, --Namefile <file/channel>[,<file/channel>[, ...]]\n";
	$tmp .= "                           Only the <file> and <channel> or the list of <file> and <chan-\n";
	$tmp .= "                           nel> (separated by ',') will be displayed in the Occurrence\n";
	$tmp .= "                           Report and DET Curve (<file> and <channel> can be regular\n";
	$tmp .= "                           expressions).\n";
	$tmp .= "  -q, --query <name_attribute>\n";
	$tmp .= "                           Populate the Conditional Reports with set of terms identified by\n";
	$tmp .= "                           <name_attribute> in the the term list's 'terminfo' tags.\n";
	$tmp .= "  -w, --words-oov          Generate a Conditional Report sorted by terms that are \n";
	$tmp .= "                           Out-Of-Vocabulary (OOV) for the system.\n";
	$tmp .= "\n";
  $tmp .= "Alignment options:\n";
  $tmp .= "  -g, --gsegment-based-alignment\n";
  $tmp .= "                           Produces a segment alignment rather than occurence based alignment\n";
  $tmp .= "                           (default: off)\n";
	$tmp .= "Report options:\n";
  $tmp .= "  -path <path>             Output directory for generated reports.\n";
  $tmp .= "  -f  --file-root          File root for the generated reports.\n";
	$tmp .= "  -o, --osummary-report                    Output the Summary Report.\n";
  $tmp .= "  -b, --block-summary-report               Output the Block Summary Report.\n";
	$tmp .= "  -O, --Osummary-conditional-report        Output the Conditional Occurrence Report.\n";
  $tmp .= "  -B, --Block-summary-conditional-report   Output the Conditional Block Summary Report.\n";
	$tmp .= "  -i, --iso-lines [<coef>[,<coef>[, ...]]]\n";
	$tmp .= "                            Include the iso line information inside the serialized det curve.\n";
	$tmp .= "                            Every <coef> can be specified, or it uses those by default.\n";
	$tmp .= "                            The <coef> is the ratio Pmiss/Pfa.\n";
	$tmp .= "  -d, --det-curve                          Output the DET Curve.\n";
	$tmp .= "  -D, --DET-conditional-curve              Output the Conditional DET Curve.\n";
	$tmp .= "  -P, --Pooled-DETs        Produce term occurrence DET Curves instead of 'Term Weighted' DETs.\n";
  $tmp .= "  -C, --Clean-DETs-folder  Removes all non-png files from the generated dets folder.\n";
  $tmp .= "  -c, --csv-of-alignment         Output the alignment CSV.";
  $tmp .= "  -y, --ytype-of-report-output   Output types of the reports. (TXT,CSV,HTML) (Default is Text)\n";
	$tmp .= "  -k, --koefcorrect <value>     Value for correct (C).\n";
	$tmp .= "  -K, --Koefincorrect <value>   Value for incorrect (V).\n";
	$tmp .= "  -n, --number-trials-per-sec <value>  The number of trials per second. (default: 1)\n";
	$tmp .= "  -p, --prob-of-term <value>  The probability of a term. (default: 0.0001)\n";
  $tmp .= "  -inc, --include-blocks-w-notargs  Include blocks with no targets in block reports.\n";
	$tmp .= "  -I, --ID-System <name>   Overwrites the name of the STD system.\n";
	$tmp .= "\n";
	$tmp .= "Other options:\n";
	$tmp .= "\n";

  return($tmp);
}
