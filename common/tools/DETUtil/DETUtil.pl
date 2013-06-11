#!/usr/bin/env perl

# DETUtil
# DETUtil.pl
# Authors: Jonathan Fiscus
#          Jerome Ajot
#          Martial Michel
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

# $Id$

use strict;
use Data::Dumper;
#use Carp ();  local $SIG{__WARN__} = \&Carp::cluck;

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
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
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "DETCurve", "DETCurveSet") {
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

my $VERSION = "0.4";
my @listIsoratiolineCoef = ();
my @listIsometriclineCoef = ();

my $man = 0;
my $help = 0;
my $OutPNGfile = "";
my $tmpDir = "";
my @selectFilters = ();
my @editFilters = ();
my $keepFiles = 0;
my $title = undef;
my $scale = undef;
my $lineTitleModification = undef;
my $keyLoc = undef;
my $keySpacing = undef;
my $keyFontType = undef;
my $keyFontSize = undef;
my @KeyLocDefs = ( "left", "right", "center", "top", "bottom", "outside", "below", "((left|right|center)\\s+(top|bottom|center))" );
my $DetCompare = 0;
my $DrawIsoratiolines = 0;
my $Isoratiolineslist = "";
my $IsoRatioStatisticFile = "";
my $DrawIsometriclines = 0;
my $Isometriclineslist = "";
my $DrawIsopoints = 0;
my $confidenceIsoThreshold = 0.95;
my $gzipPROG = "gzip";
my $gnuplotPROG = "gnuplot";
my $axisScales = undef;
my $docsv = 0;
my $doHTMLTable = 0;
my @plotControls = ();
my $dumpFile = 0;
my $forceRecompute = 0; 
my $doTxtTable = 0;
my $dumptarg = "";
my $HD = 0;
my $AutoAdapt = 0;
my $verbose = 0;
my @perfAtFixedDefs = ();
my ($smooth, $smoothWindowSize, $targExtraDecisions, $nonTargExtraDecisions) = (undef, undef, undef, undef);

# Variables for Brad's hacks.
my $sortBy = undef;
my $firstSetSize = 10;
my $firstSet = "";
my $secondSetSize = 10;
my $secondSet = "";
my $restSet = "";
my $xpng = 0;
my $excludeCounts = 0;

Getopt::Long::Configure(qw( no_ignore_case ));

# Av:   ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: ABCDEFGHIJKL   PQRST V X Za cde ghi klm opqrst v x z #

GetOptions
  (
   'o|output-png=s'              => \$OutPNGfile,
   'r|ratiostats=s'              => \$IsoRatioStatisticFile,
   'g|generateCSV'               => \$docsv,
   'd|dumpFile'                  => \$dumpFile,
   'D|DumpAllTargScr=s'          => \$dumptarg,
   
   't|tmpdir=s'                  => \$tmpDir,
   's|select-filter=s'           => \@selectFilters,
   'e|edit-filter=s'             => \@editFilters,
   'c|compare'                   => \$DetCompare,
   'k|keepFiles'                 => \$keepFiles,
   
   'i|iso-costratiolines'        => \$DrawIsoratiolines,
   'R|set-iso-costratiolines=s'  => \$Isoratiolineslist,
   'I|iso-metriclines'           => \$DrawIsometriclines,
   'Q|set-iso-metriclines=s'     => \$Isometriclineslist,
   'P|iso-points'                => \$DrawIsopoints,
   'T|Title=s'                   => \$title,
   'l|lineTitle=s'               => \$lineTitleModification,
   'S|Scale=s'                   => \$scale,
   'K|KeyLoc=s'                  => \$keyLoc,
   'Z|ZipPROG=s'                 => \$gzipPROG,
   'G|GnuplotPROG=s'             => \$gnuplotPROG,
   'A|AxisScale=s'               => \$axisScales,
   'p|plotControls=s'            => \@plotControls,
   'F|ForceRecompute'            => \$forceRecompute,
   'x|txtTable'                  => \$doTxtTable,  
   'X|ExcludePNGFileFromTxtTable' => \$xpng,
   'q|ExcludeCountsFromReports'    => \$excludeCounts,
   
   'H|HD'                        => \$HD,
   'a|autoAdapt'                 => \$AutoAdapt,

   'V|Verbose'                   => \$verbose,
   'version'                     => sub { my $name = $0; $name =~ s/.*\/(.+)/$1/; 
                                          print "$name version $VERSION\n"; exit(0); },
   'h|help'                      => \$help,
   'm|man'                       => \$man,

   'B|sortBy=s'                  => \$sortBy,
   'C|firstSet=s'                => \$firstSet,
   'D|secondSet=s'               => \$secondSet,
   'E|restSet=s'                 => \$restSet,
   'J|firstSetSize=i'            => \$firstSetSize,
   'L|secondSetSize=i'           => \$secondSetSize,
   'z|perf-at-fixed=s'           => \@perfAtFixedDefs,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n");

## Docs
pod2usage(1) if $help;
pod2usage(-exitvalue => 0, -verbose => 2) if $man;
##

## Checking inputs
pod2usage("Error: At least one DET Curve must be specified.\n") if(scalar ( @ARGV ) == 0);
pod2usage("ERROR: An Output file must be set.\n") if($OutPNGfile eq "");
pod2usage("'-c|--compare' works with 2 and only 2 DET curves.\n") if( ( scalar ( @ARGV ) != 2 ) && $DetCompare );

# Check iso coef
if($Isoratiolineslist ne "")
{
	@listIsoratiolineCoef = ();

	# Use the list given on the command-line
	foreach my $c ( split( /,/ , $Isoratiolineslist ) )
	{
		die "ERROR: The coefficient for the iso-costratioline if not a proper floating-point."
			if( $c !~ /^\d*\.?\d+([eE][-+]?\d+)?$/ );
		
		push( @listIsoratiolineCoef, $c );
	}
	
	@listIsoratiolineCoef = unique(@listIsoratiolineCoef);
	@listIsoratiolineCoef = sort {$a <=> $b} @listIsoratiolineCoef;
}

if($Isometriclineslist ne "")
{
	@listIsometriclineCoef = ();

	# Use the list given on the command-line
	foreach my $c ( split( /,/ , $Isometriclineslist ) )
	{
		die "ERROR: The coefficient for the iso-metricline if not a proper floating-point."
			if( $c !~ /^[-+]?\d*\.?\d+([eE][-+]?\d+)?$/ );
			
		push( @listIsometriclineCoef, $c );
	}
	
	@listIsometriclineCoef = unique(@listIsometriclineCoef);
	@listIsometriclineCoef = sort {$a <=> $b} @listIsometriclineCoef;
}
#

# Check the filter syntax
foreach $_(@selectFilters)
{
	die "Error: Select Filter '$_' does not match a legal expression" if ($_ !~ /^title:.+$/);
}
foreach $_(@editFilters)
{
	die "Error: Edit Filter '$_' does not match a legal expression"
		if ($_ !~ /^title:s\/[^\/]+\/[^\/]*\/(g|i|gi|ig|)$/);
}
#
##

sub vprint {
  return() if (! $verbose);
  print(join("", @_));
}


my %options = ();
$options{title} = $title if (defined $title);
$options{serialize} = 0;

### Parse the line title argument
my %parseHT = ();
$options{DETShowPoint_SupportValues} = [()];
foreach my $code(split("", defined($lineTitleModification) ? $lineTitleModification : "ABCT")){
  if ($code eq "A"){   $options{DETShowPoint_Actual} = 1; }
  elsif ($code eq "B"){   $options{DETShowPoint_Best} = 1; }
  elsif ($code eq "R"){   $options{DETShowPoint_Ratios} = 1; }
  elsif ($code eq "t"){   $options{lTitleNoDETType} = 1;}
  elsif ($code eq "E"){   $options{DETShowEvaluatedBlocks} = 1;}
  elsif ($code =~ /^([TFMC])$/){
    die "Error: --lineTitle code $code used twice" if (exists($parseHT{$code}));
    push (@{ $options{DETShowPoint_SupportValues} }, $code);
    $parseHT{$code} = 1;
  } else {
    die "Error: --lineTitle code $code unrecognized"
  }
}
  
$options{gnuplotPROG} = $gnuplotPROG;
$options{createDETfiles} = 1;

$options{HD} = $HD;
$options{AutoAdapt} = $AutoAdapt;

$options{ExcludePNGFileFromTextTable} = ($xpng == 1);
$options{ExcludeCountsFromReports} = ($excludeCounts == 1);

foreach my $directive (@plotControls){
  my $numRegex = '\d+|\d+\.\d*|\d*\.\d+|\d*\.\d+e-\d\d';
  my $intRegex = '\d*';

  &vprint("[*] Processing directive \'$directive\'\n");
  if ($directive =~ /ColorScheme=(color|colorPresentation|gr[ae]y)$/){
    $options{ColorScheme} = $1;
    $options{ColorScheme} =~ s/gray/grey/;;
  } elsif ($directive =~ /PointSize=(\d+)/){
    $options{PointSize} = $1;
  } elsif ($directive =~ /PointSetAreaDefinition=(Area|Radius)/){
    $options{PointSetAreaDefinition} = $1;
  } elsif ($directive =~ /KeySpacing=($numRegex)/){
    $options{KeySpacing} = $1;
  } elsif ($directive =~ /KeyFontFace=(.*)/){
    $options{KeyFontFace} = $1;
  } elsif ($directive =~ /KeyFontSize=($numRegex)/){
    $options{KeyFontSize} = $1;
  } elsif ($directive =~ /ExtraPoint=(.*)$/){
    my $pointDef = $1;
    my $colorRegex = 'rgb[ _]"#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"';
    my $fullExp = "^([^:]*):($numRegex):($numRegex):($intRegex):($intRegex):(($colorRegex)|):(left|right|center|)(:arrow:($numRegex):($numRegex))?\$";
    die "Error: Point definition /$pointDef/ does not match the pattern /$fullExp/" 
      if ($pointDef !~ /$fullExp/);
    my %ht = ();
    $ht{label}         = $1 if ($1 ne "");
    $ht{MFA}           = $2 if ($2 ne "");
    $ht{MMiss}         = $3 if ($3 ne "");
    $ht{pointSize}     = $4 if ($4 ne "");
    $ht{pointType}     = $5 if ($5 ne "");
    $ht{color}         = $6 if ($6 ne "");
    $ht{justification} = $8 if ($8 ne "");
    if ($9 ne ""){
      $ht{arrow} = "true";
      $ht{length} = $10;
      $ht{angle} = $11;
    }
    push @{ $options{PointSet} }, \%ht;
  } elsif ($directive =~ /PerfBox=(.*)$/){
    my $perfBox = $1;
    my $colorRegex = 'rgb "#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"';
    my $fullExp = "^([^:]*):($numRegex):($numRegex):(($colorRegex)|)\$";
    die "Error: PerfBox definition /$perfBox/ does not match the pattern /$fullExp/" 
      if ($perfBox !~ /$fullExp/);
    my %ht = ();
    $ht{title}         = $1 if ($1 ne "");
    $ht{MFA}           = $2 if ($2 ne "");
    $ht{MMiss}         = $3 if ($3 ne "");
    $ht{color}         = $4 if ($4 ne "");
    push @{ $options{PerfBox} }, \%ht;
  } elsif ($directive =~ /smooth=(\d+),(\d+),(\d+)$/){
    ($smooth, $smoothWindowSize, $targExtraDecisions, $nonTargExtraDecisions) = (1, $1, $2, $3);    
  } elsif ($directive =~ /Font=(.+)$/){
    $options{DETFont} = $1;
  } elsif ($directive =~ /ISORatioLineStyle=([\da-fA-F]{6}|),(\d+|)$/){
    my ($one, $two) = ($1, $2);
    $options{ISORatioLineColor} = $one if ($one ne "");
    $options{ISORatioLineWidth} = $two if ($two ne "");
  } elsif ($directive =~ /ISOMetricLineStyle=([\da-fA-F]{6}|),(\d+|)$/){ 
    my ($one, $two) = ($1, $2);
    $options{ISOCostLineColor} = $one if ($one ne "");
    $options{ISOCostLineWidth} = $two if ($two ne "");
  } elsif ($directive =~ /PlotDETCurves=(true|false)$/){ 
    $options{PlotDETCurves} = $1;
  } elsif ($directive =~ /^PlotMeasureThresholdPlots(=withSE)?$/){ 
    $options{PlotMeasureThresholdPlots} = "true";
    if (defined($1)){
      $options{PlotMeasureThresholdPlots} = "trueWithSE";
    }
  } elsif ($directive =~ /^IncludeRowTotals$/){ 
    $options{ReportRowTotals} = 1;
  } else {
    print "Warning: Unknown plot directive /$directive/\n";
  }
}

if (defined($axisScales))
{
	$axisScales =~ tr/A-Z/a-z/; 
	
	if ($axisScales !~ /^(nd|log|linear):(nd|log|linear)$/)
	{
		die "Error: Axis scales in appropriate" if ($axisScales !~ /^(nd|log|linear):(nd|log|linear)$/);
	}
	
	$options{xScale} = $1;  
	$options{yScale} = $2;
}

if (defined($scale))
{
	die "Error: Invalid Scale '$scale'. must match N:N:N:N"
		if ($scale !~ /^(\d+|\d*.\d+):(\d+|\d*.\d+):(\d+|\d*.\d+):(\d+|\d*.\d+)$/);

	$options{Xmin} = $1;
	$options{Xmax} = $2;
	$options{Ymin} = $3;
	$options{Ymax} = $4;
}

if(defined($keyLoc))
{
  my $expr = "^(".join("|",@KeyLocDefs).")\$";
	die "Error: Invalid key location '$keyLoc' !~ $expr" if ($keyLoc !~ /$expr/);
	$options{KeyLoc} = $keyLoc;
}

my $ds = new DETCurveSet($title);

sub attrValueStringToHT{
  my ($str) = @_;
  my %ht = ();
  
  foreach my $avPair(split(/,/, $str)){
    my ($attr, $val) = split("=>",$avPair);
    print "  attr=$attr val=$val\n";
    $ht{$attr} = $val;
  }
  \%ht;
}

my $firstSetCounter = 0;
my $secondSetCounter = 0;

### Process the option to cumpute performance at fixed points
my @MFAFixedValues = ();
my $MFAFixedValuesReport = "";
if (@perfAtFixedDefs > 0){
  foreach (@perfAtFixedDefs){
    die "Error in value for -perf-at-fixed /$_/, unknown dimension." if ($_ !~ /^FA:(\S+):(\S+)/);
    $MFAFixedValuesReport = $1;
    my $valstr = $2;
    foreach my $val(split(/,/,$valstr)){ 
      die "Error in value for -perf-at-fixed /$_/, illegal value /$val/. not a number." if ($val !~ /^(\d+|\d+\.\d*|\d*\.\d+)$/);
      push @MFAFixedValues, $val;
    }
  }
  print "FA Fixed values: ".join(",",@MFAFixedValues).".  Report to $MFAFixedValuesReport\n";
}


foreach my $srlDef ( @ARGV )
{
  ### The SRL files can now include various plotting attributes.  
  my $pointDef = $1;
  my $numRegex = '\d+|\d+\.\d*|\d*\.\d+';
  my $intRegex = '\d*';
  my $colorRegex = 'rgb "#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"';
  my $MFAFixedValuesResults = undef;

  ### Parse the global srlDef as the default
  my ($srl, $newLabel, $pointSize, $pointTypeSet, $color, $lineWidth, $displayKey) = split(/:/,$srlDef);

  ### If this is set to non-blank, it will get applied
  my ($newSrlDef) = "";
  if ($firstSet ne "" && $firstSetCounter < $firstSetSize) {
    print "first set: $firstSet\n";
    $newSrlDef = $firstSet;
    $firstSetCounter++;
  } elsif ($firstSet ne "" && $secondSet ne "" && $secondSetCounter < $secondSetSize) {
    print "second set: $secondSet\n";
    $newSrlDef = $secondSet;
    $secondSetCounter++;
  } elsif ($firstSet ne "" && $restSet ne "") {
    print "rest set: $restSet\n";
    $newSrlDef = $restSet;
  }

  if ($newSrlDef ne ""){
    my ($_newLabel, $_pointSize, $_pointTypeSet, $_color, $_lineWidth, $_displayKey) = split(/:/,$newSrlDef);
    $newLabel = $_newLabel if ($_newLabel ne "");
    $pointSize = $_pointSize if ($_pointSize ne "");
    $pointTypeSet = $_pointTypeSet if ($_pointTypeSet ne "");
    $color = $_color if ($_color ne "");
    $lineWidth = $_lineWidth if ($_lineWidth ne "");
    $displayKey = $_displayKey if ($_displayKey ne "");
  }
  
  $color =~ s/rgb_/rgb /;
  
  vprint("[*] Loading SRL file ($srl)\n"); 

  my $loadeddet = DETCurve::readFromFile($srl, $gzipPROG);
  if ($smooth){
    $loadeddet = $loadeddet->getSmoothedDET($smoothWindowSize, $targExtraDecisions, $nonTargExtraDecisions);
  }
  
#  print $loadeddet->getTrials()->dump();
  
  my %lineAttr = ();
	if (defined($newLabel)){
    ### then we will control the plot style
    if ($newLabel ne ""){
      # JGF decided to change the way this works....  the line attr still works, but it should be an alternative Way to do it
      #   	  $lineAttr{"label"} = $newLabel;
   	  $loadeddet->setLineTitle($newLabel);
   	}
	  if (defined ($pointSize) && $pointSize ne ""){
 	    die "Error: DET Line Attr control for pointSize [3] /$pointSize/ illegal." if ($pointSize !~ /^($numRegex)$/);
 	    $lineAttr{"pointSize"} = $pointSize;
 	  }
 	  if (defined ($pointTypeSet) && $pointTypeSet ne ""){
  	    die "Error: DET Line Attr control for pointTypeSet [4] /$pointTypeSet/ illegal." if ($pointTypeSet !~ /^(square|circle|triangle|utriangle|diamond)$/);
 	    $lineAttr{"pointTypeSet"} = $pointTypeSet;
 	  }
 	  if (defined ($color) && $color ne ""){
 	    die "Error: DET Line Attr control for color [5] /$color/ illegal." if ($color !~ /^($colorRegex)$/);
 	    $lineAttr{"color"} = $color;
 	  }
 	  if (defined ($lineWidth) && $lineWidth ne ""){
 	    die "Error: DET Line Attr control for LineWidth [6] /$lineWidth/ illegal." if ($lineWidth !~ /^($numRegex)$/);
 	    $lineAttr{"lineWidth"} = $lineWidth;
 	  }
      if (defined ($displayKey) && $displayKey ne "") {
        die "Error: DET Line Attr control for displayKey [7] /$displayKey/ illegal." if ($displayKey !~ /^(true|false)$/);
        $lineAttr{"displayKey"} = $displayKey;
      }
	} 
	
	@listIsoratiolineCoef = $loadeddet->getMetric()->isoCostRatioCoeffForDETCurve()
		if(scalar(@listIsoratiolineCoef) == 0);
	
	@listIsometriclineCoef = $loadeddet->getMetric()->isoCombCoeffForDETCurve() 
		if(scalar(@listIsometriclineCoef) == 0);  
	
	my $det = $loadeddet;
	
  #### Check top see if a RECOMPUTE is really needed
  if ($DrawIsoratiolines || ($IsoRatioStatisticFile ne "")){
    ### Loop thre the needed coefficients.  If the are missing, force a recompute
    foreach my $coeff(@listIsoratiolineCoef){
      if (!defined($loadeddet->getIsolinePointsCombValue($coeff))){
        $forceRecompute = 1;
      }
    }
  }
	if($forceRecompute)
	{
		$det = new DETCurve($loadeddet->getTrials(), $loadeddet->getMetric(),
		                    $loadeddet->getLineTitle(),
		                    \@listIsoratiolineCoef, $loadeddet->{GZIPPROG});
		$det->{LAST_SERIALIZED_DET} = $loadeddet->{LAST_SERIALIZED_DET};

#		print "[Calling 'computePoint']\n";
		$det->computePoints();
	}
    
  if (@MFAFixedValues > 0){
     $det->computeMMissForFixedMFA(\@MFAFixedValues);
  }
  
	my $keep = 0;
	$keep = 1 if (@selectFilters == 0);

	foreach $_(@selectFilters)
	{
		my ($field, $exp) = split(/:/,$_,2);
		
		if ($field eq "title")
		{
			$keep = 1 if ($det->{LINETITLE} =~ /$exp/);
		}
	}
	
	if($keep)
	{
		foreach $_(@editFilters)
		{
			my ($field, $exp) = split(/:/,$_,2);
			my ($op, $op1, $op2, $cond) = split(/\//,$exp,4);
			$cond = "" if (! defined($cond));
			
			if ($field eq "title")
			{
				if ($cond eq "g")
				{
					$det->{LINETITLE} =~ s/$op1/$op2/g;
				}
				elsif ($cond eq "i")
				{
					$det->{LINETITLE} =~ s/$op1/$op2/i;
				}
				elsif (($cond eq "gi") || ($cond eq "ig"))
				{
					$det->{LINETITLE} =~ s/$op1/$op2/gi;
				}
				else
				{
					$det->{LINETITLE} =~ s/$op1/$op2/;
				}
			}
		}
		
		if (scalar(keys %lineAttr) > 0){
		  $options{DETLineAttr}{$det->getLineTitle() . "$srl"} = \%lineAttr;
		}
		my $rtn = $ds->addDET($det->getLineTitle() . "$srl", $det);
    	die "Error: Unable to add DET to DETSet.\n$rtn\n"	if ($rtn ne "success");
	}
}

if ($sortBy) {
    $ds->sort($sortBy);
}

if($IsoRatioStatisticFile ne "") {
  my $lmode = 'text';
  $lmode = 'csv' if ($IsoRatioStatisticFile =~ m%\.csv$%i);
  $lmode = 'html' if ($IsoRatioStatisticFile =~ m%\.html$%i);
  vprint ("[*] Performing 'renderIsoRatioIntersection'\n");
  open(FILESTATS, ">", $IsoRatioStatisticFile) or die "$!";
  print FILESTATS $ds->renderIsoRatioIntersection($lmode);
  close(FILESTATS)
}

if ($MFAFixedValuesReport ne ""){
  my $lmode = 'text';
  $lmode = 'csv' if ($MFAFixedValuesReport =~ m%\.csv$%i);
  $lmode = 'html' if ($MFAFixedValuesReport =~ m%\.html$%i);
  vprint ("[*] Performing 'Fixed MFA Values Report'\n");
  open(FILESTATS, ">", $MFAFixedValuesReport) or die "$!";
  print FILESTATS $ds->renderPerfForFixedMFA(\@MFAFixedValues, $lmode);
  close(FILESTATS)
}

if($DetCompare)
{
  vprint ("[*] Performing 'renderDETCompare'\n");
	my ($str, $conclusion, $list_isopoints) = $ds->renderDETCompare($confidenceIsoThreshold);
	print $str;
	print $conclusion;
	$options{Isopoints} = $list_isopoints if( $DrawIsopoints );
}


if(@listIsoratiolineCoef)
{
	$options{Isoratiolines} = \@listIsoratiolineCoef;
}

if($DrawIsoratiolines)
{
	$options{DrawIsoratiolines} = 1;
}

if($DrawIsometriclines)
{
	$options{Isometriclines} = \@listIsometriclineCoef;
	$options{DrawIsometriclines} = 1;
}

#print Dumper(\%options); exit;

## Reports
my $temp = "";

if($tmpDir ne "" && $tmpDir ne "/tmp")
{
	$temp = File::Temp::tempdir( "$tmpDir/DETUtil.XXXXXXXX", CLEANUP => !$keepFiles );
}
else
{
	$temp = File::Temp::tempdir( CLEANUP => !$keepFiles );
}
&vprint("[*] Temp dir \'$temp\'\n");

### Get the filenames:
my $pngRoot = $OutPNGfile;  $pngRoot =~ s/\.png$//i;

&vprint("[*] Performing 'renderAsTxt'\n");
my $report = $ds->renderReport("$temp/merge", 1, \%options, 
  ($doTxtTable) ? "$pngRoot.results.txt" : undef,
  ($docsv) ? "$pngRoot.results.csv" : undef,
  ($doHTMLTable) ? "$pngRoot.results.html" : undef,
  undef);
  
my $inf = "$temp/merge.png";
&vprint("[*] Copying [$inf] to [$OutPNGfile]\n");
my $err =  MMisc::filecopy($inf, $OutPNGfile);
MMisc::error_quit($err) if (! MMisc::is_blank($err));

my $measureThrHT = $ds->getMeasureThreshPngHT();
if (defined($measureThrHT)){
  foreach my $meas(keys %$measureThrHT){
    my $inf = $measureThrHT->{$meas};
    my $newpng = $OutPNGfile;
    $newpng =~ s/\.png$/.thresh.$meas.png/i;
    &vprint("[*] Copying [$inf] to [$newpng]\n");
    my $err =  MMisc::filecopy($inf, $newpng);
    MMisc::error_quit($err) if (! MMisc::is_blank($err));
  }
}

if ($dumpFile){
  &vprint("[*] Doing 'dumpFile'\n");
  my $dumpf = $OutPNGfile;
  $dumpf =~ s/\.png$//i;
  $dumpf .= ".dump.txt";  
  MMisc::writeTo($dumpf, "", 1, 0, Dumper($ds));

}

MMisc::error_quit("Problem writing All Target Scores")
  if ((! MMisc::is_blank($dumptarg)) && (! $ds->writeAllTargScr($dumptarg)));

exit 0;

#############################################  End of the program #########################################

sub _warn_add
{
	$warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

sub unique
{
	my %l = ();
	foreach my $e (@_) { $l{$e}++; }
	return keys %l;
}

__END__

=head1 NAME

DETUtil.pl -- Merge DET Curves and statistical analyses.

=head1 SYNOPSIS

B<DETUtil.pl> [ OPTIONS ] -o F<PNG_FILE>  F<SRL[:OPTs]> [F<SRL>[:OPTs] [...]]

=head1 DESCRIPTION

The primary purpose of this script is to build a single PNG plot containing multiple DET curve line traces.  The inputs to the program includes options and multiple serialized DET Curves (SRL files).  The primary output is a PNG file.  Secondarily, the pragram can statistically compare two block-averaged DET curves (-c option).

The SRL files are built when a DET curve is produced by a F4DE utility.  The files end with the extension .srl.gz and are located in the scoring output directory.  The SRL command line argument can optionally include a re-specification of the title and plot characteristics of the DET line trace for the SRL file.  The BNF of the specification is below.  All fields can be empty in which case the default value will be used for the attribute. If spaces are used in the title, make sure single or double quotes are used in your shell to make the SRL argument is a single one.

  SRL[:title[:pointSize[:pointType[:color[:lineWidth[:displayKey]]]]]]
  
=over

title -> The title can includes spaces as long as the shell passed the string as a single argument.  This replacement occurs prior to any edit filters specified by the B<-e> option. 

pointSize -> A floating point number for the point size.

pointType -> Must be one of /(square|circle|triangle|utriangle|diamond)/.

color -> The RGB color formatted as /rgb "#hhhhhh"/ where the /h/ characters are hexidecimal RGB colors.

lineWidth -> A floating point number for the line width.

displayKey -> A boolean value for whether or not the SRL will be displayed in the key. Must be formatted as /(true|false)/ where /true/, the default, means the key is printed.

=back

=head1 OPTIONS

=head2 Required file arguments:

=over

=item B<-o>, B<--output-png> F<PNG_FILE>

Output png file.

=item B<-r>, B<--ratiostats> F<FILE>

Output report file containing the intersection coordinates and Combined Cost between the DET Curve and the the Iso-ratio lines.

=back

=head2 Optional arguments:

=over

=item B<-t>, B<--tmpdir> F<DIR>

Speficy the working directory.

=item B<-k>, B<--keepFiles>

Keep the .plt and dat files instead of deleting them.

=item B<-s>, B<--select-filter> F<EXP>

Reduce the combined printout by only including the curves that match the regular expression: title:F<EXP> forces the match on the title.

=item B<-e>, B<--edit-filter> F<EXP>

Edit the titles to reduce/expand the elements printed in the combined plot with the regular expression: title:F<EXP> edits the title.

=item B<-c>, B<--compare>

Compare 2 DET curves with a sign test.

=item B<-Z>, B<--ZipPROG> F<GZIP_PATH>

Specify the full path name to gzip (default: 'gzip').

=item B<-G>, B<--GnuplotPROG> F<GNUPLOT_PATH>

Specify the full path name to gnuplot (default: 'gnuplot').

=back

=head2 Graph tweaks:

=over

=item B<-H>, B<--HD>

Draw higher resolution graph.

=item B<-a>, B<--autoAdapt>

Try to auto adapt height for more readable plot.
Note that this mode relies on I<ImageMagick>'s B<identify> and will fail if it is not available and in your PATH.

=item B<-i>, B<--iso-costratiolines>

Draw the iso-cost ratio lines.

=item B<-R>, B<--set-iso-costratiolines> F<COEF>[,F<COEF>[,...]]

Set the coefficient for the iso-cost ratio lines. The F<COEF> is the ratio of cost of Miss divided by cost of False Alarm. Coeficients can be specified, or the default values defined by the application are used (c.f.: NOTES Section).

=item B<-P>, B<--iso-points>

Draw the isopoints and links (required -c).

=item B<-I>, B<--iso-metriclines>

Draw the iso-metric specific lines.

=item B<-Q>, B<--set-iso-metriclines> F<COEF>[,F<COEF>[,...]]

Set the coefficient for the iso-metric lines. Coeficients can be specified, or the default values defined by the application are used (c.f.: NOTES Section).

=item B<-T>, B<--Title> F<TITLE>

Use  F<TITLE> for the title of the plot.   

=item B<-l>, B<--lineTitle> F<TITLE>

The DET curve lines includes specialized measurement points.  This option modifies the reported measurements.  F<TITLE> can include any number of these characters.

=over 4

=item 

Modifiers to control the type of calculated point to include:

    A -> Include the "Actual" point (used to be -O)
    B -> Include the "Best" combined value
    R -> Include the Iso Ratio points
    E -> Include the number of evalauted blocks

=item 

Modifiers to control the supporting measurements for EACH plotted point.  The order of these is reflected in the DET plots.

    T -> Include the decision score threshold for the point
    F -> Include the false alarm (x-axis value) for the point
    M -> Include the missed detection (y-axis value) for the point
    C -> Include the combined measure for the point

=item 

Modifiers for reporting the type of curve (pooled vs. averaged)

    t -> removes the DET curve type

=back
    
The default value is /ABCT/.

=item B<-K>, B<--KeyLoc> left | right | center | top | bottom | outside | below | "((left|right|center) (top|bottom|center))"

Place the key at one of the locations.

=item B<-S>, B<--Scale> F<Xmin>:F<Xmax>:F<Ymin>:F<Ymax>

Sets the X and Y axis ranges to the values. All points must be present.

=item B<-A>, B<--AxisScale> F<Xaxis>:F<Yaxis>

Sets the X and Y axis scale types for the graph:
  nd -> Normal Deviate (the default)
  log -> for logarithmic
  linear -> for non-weighted scale

=item B<-p>, B<--plotControls> F<Directive>

The B<plotControl> options provides access to fine control the the DET curve display.  The option, which can be used multiple times, specifies one of the following directives via the following BNF definitions:

/KeySpacing=<FLOAT>/ -> Sets the inter-line spaces in the key to the float.  Default is 0.7

/KeyFontFace=<STRING>/ -> Sets font face used in the key of the DET Curve.

/KeyFontSize=<STRING>/ -> Sets font size used in the key of the DET Curve. Default is either via '-p Font=..' or the default font.

/ColorScheme=grey/  ->  Sets the color scheme to either (grey|color|colorPresentatio).

/Font=<GNUPLOT_PNG_FONT_STRING>/  ->  Sets the PNG font to the value.  NOTE: There is no syntax checking.  possibilities are "medium", "font arial 20".

/ISOMetricLineStyle=<RRGGBB>,<D>  -> Sets the color of the ISO Metric lines to the RGB color with width <D>.  Either or both can be omitted to use the default.

/ISOMRatioLineStyle=<RRGGBB>,<D>  -> Sets the color of the ISO Ratio lines to the RGB color with width <D>.  Either or both can be omitted to use the default.

/PointSize=\d+/     -> Overrides to default point size to the specified integer.

/ExtraPoint=text:FA:MISS:pointSize:pointType:color:justification/
                    -> Places a point at location FA,MISS with the label /text/ with the specified point type, color, size, and label justification.  All colons and the FA and MISS values are required.  Point type is an integer. Point color is /rgb "#hhhhhh"/ where the /h/ characters are hexidecimal RGB colors.  Point size is a floating point number.  Justification is either /right|left|center/.

/PerfBox=text:FA:MISS:color/
                    -> Places a transparent box at from the origin to location FA,MISS with the title /text/ with the specified color.  All colons and the FA and MISS values are required.  Color is /rgb "#hhhhhh"/ where the /h/ characters are hexidecimal RGB colors. 


/PointSetAreaDefinition=(Area|Radius)/     -> The value of C<pointSize> is display as either area of  the point or the width.  Def. is radius.

/PlotDETCurves=(true|false)/     -> Include or exclude the DETCurves in the DET plot.  Default is /true/.

/smooth=AdjacentDecisions,extraTargs,extraNonTargs/   -> Build a smoothed DET with the following parameters.     <AdjacentDecisions> use the average decision score +/- the number pf points.  0 means no averaging.  <extraTargs> adds the N targets with linearly interpolated values between each pair of targets.  0 means no targets added.  <extraNonTargs> does the same operation a <extraTargs> except to the non targets.

/PlotMeasureThresholdPlots(=withSE)/  -> Build the threshold plots for two error measures (e.g., miss and false alarm) as a function of the Dectection Score. 

/ReportRowTotals/                     -> Include to totals/Means/SE over all rows on the system report
      
=item B<-F>, B<--ForceRecompute>

Force the DET points to be recomputed.  Some of the other options also re-compute the points.

=item B<-x> B<--txtTable>

Generate a table of statistics.  

=item B<-X> B<--ExcludePNGFileFromTxtTable>
                
Exclude the PNG files location from text tables generated.  

=item B<-q> B<--ExcludeCountsFromReports>

Exclude trial counts from report tables.

=item B<-d> B<--dumpFile>

Dump the SRL files into a file that is readable.

=item B<-D> B<--DumpAllTargScr> fileroot

Dump all the file's Trials Target and Non Target scores into files starting with i<fileroot>.

=item B<-B> B<--sortBy> actual | best

Sorts the SRL files by the actual score or best score.

=item B<-C> B<--firstSet> formatstr 

Applies the given format string to the first set of SRLs. 

=item B<-D> B<--secondSet> formatstr 

Applies the given format string to the second set of SRLs. 

=item B<-E> B<--restSet> formatstr 

Applies the given format string to the rest of the SRLs. 

=item B<-J> B<--firstSetSize> size 

Sets the size of the first set of SRLs. 

=item B<-L> B<--secondSetSize> size 

Sets the size of the second set of SRLs. 

=back

=head2 Others:

=over

=item B<-h>, B<--help>

Print the help.

=item B<-m>, B<--man>

Print the manual.

=item B<--Verbose>

Print a little more verbose information during processing.

=item B<--version>

Print the version number.

=back

=head1 BUGS

No known bugs.

=head1 NOTES

The default iso-cost ratio coefficients (-R option) and iso-metric coefficients (-Q option) are defined into the metric.

The default font face can be changed by setting the environment variable GDFONTPATH to a ttf font like /Library/Fonts/Arial.

=head1 AUTHOR

 Jonathan Fiscus <jonathan.fiscus@nist.gov>
 Jerome Ajot <jerome.ajot@nist.gov>
 Martial Michel <martial.michel@nist.gov>

=head1 VERSION

DETUtil.pl version 0.4 $Revision$

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut
