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
# the United States and is in the public domain. It is an experimental
# system.  NIST assumes no responsibility whatsoever for its use by any
# party.
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
my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../lib", "../../../common/lib");
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
my $lineTitleModification = "";
my $keyLoc = undef;
my $keySpacing = undef;
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
my $omitActual = 0;
my $docsv = 0;
my @plotControls = ();
my $dumpFile = 0;
my $forceRecompute = 0; 
my $doTxtTable = 0;
my $dumptarg = "";
my $HD = 0;
my $AutoAdapt = 0;
my $verbose = 0;

Getopt::Long::Configure(qw( no_ignore_case ));

# Av:   ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: A    FGHI K   OPQRST V   Za cde ghi klm op rst v x   #

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
   'O|OmitActualCalc'            => \$omitActual, 
   'p|plotControls=s'            => \@plotControls,
   'F|ForceRecompute'            => \$forceRecompute,
   'x|txtTable'                  => \$doTxtTable,  
    
   'H|HD'                        => \$HD,
   'a|autoAdapt'                 => \$AutoAdapt,

   'V|Verbose'                   => \$verbose,
   'version'                     => sub { my $name = $0; $name =~ s/.*\/(.+)/$1/; 
                                          print "$name version $VERSION\n"; exit(0); },
   'h|help'                      => \$help,
   'm|man'                       => \$man,
  );

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

$options{lTitleNoDETType} = 1 if ($lineTitleModification =~ /T/);
$options{lTitleNoPointInfo} = 1 if ($lineTitleModification =~ /P/);
$options{lTitleNoBestComb} = 1 if ($lineTitleModification =~ /M/);

$options{gnuplotPROG} = $gnuplotPROG;
$options{createDETfiles} = 1;

$options{HD} = $HD;
$options{AutoAdapt} = $AutoAdapt;

foreach my $directive(@plotControls){
  my $numRegex = '\d+|\d+\.\d*|\d*\.\d+';
  my $intRegex = '\d*';

  &vprint("[*] Processing directive \'$directive\'\n");
  if ($directive =~ /ColorScheme=gr[ae]y/){
    $options{ColorScheme} = "grey";
  } elsif ($directive =~ /PointSize=(\d+)/){
    $options{PointSize} = $1;
  } elsif ($directive =~ /PointSetAreaDefinition=(Area|Radius)/){
    $options{PointSetAreaDefinition} = $1;
  } elsif ($directive =~ /KeySpacing=($numRegex)/){
    $options{KeySpacing} = $1;
  } elsif ($directive =~ /ExtraPoint=(.*)$/){
    my $pointDef = $1;
    my $colorRegex = 'rgb "#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"';
    my $fullExp = "^([^:]*):($numRegex):($numRegex):($intRegex):($intRegex):(($colorRegex)|):(left|right|center|)\$";
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
    push @{ $options{PointSet} }, \%ht;
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

if($omitActual)
{
	$options{ReportActual} = 0;
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

foreach my $srlDef ( @ARGV )
{
  ### The SRL files can now include various plotting attributes.  
  my $pointDef = $1;
  my $numRegex = '\d+|\d+\.\d*|\d*\.\d+';
  my $intRegex = '\d*';
  my $colorRegex = 'rgb "#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"';

  my ($srl, $newLabel, $pointSize, $pointTypeSet, $color, $lineWidth) = split(/:/,$srlDef);
  
  vprint("[*] Loading SRL file ($srl)\n"); 
  my $loadeddet = DETCurve::readFromFile($srl, $gzipPROG);
  my %lineAttr = ();
	if (defined($newLabel)){
    ### then we will control the plot style
 	  $lineAttr{"label"} = $newLabel if ($newLabel ne "");
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
	} 
	
	@listIsoratiolineCoef = $loadeddet->getMetric()->isoCostRatioCoeffForDETCurve()
		if(scalar(@listIsoratiolineCoef) == 0);
	
	@listIsometriclineCoef = $loadeddet->getMetric()->isoCombCoeffForDETCurve() 
		if(scalar(@listIsometriclineCoef) == 0);  
	
	my $det;
	
	if( $DrawIsoratiolines || ($IsoRatioStatisticFile ne "") || $forceRecompute)
	{
		$det = new DETCurve($loadeddet->getTrials(), $loadeddet->getMetric(),
		                    $loadeddet->getLineTitle(),
		                    \@listIsoratiolineCoef, $loadeddet->{GZIPPROG});
		$det->{LAST_SERIALIZED_DET} = $loadeddet->{LAST_SERIALIZED_DET};

		$det->computePoints();
	}
	else
	{
		$det = $loadeddet;
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

if($IsoRatioStatisticFile ne "")
{
  vprint ("[*] Performing 'renderIsoRatioIntersection'\n");
	open(FILESTATS, ">", $IsoRatioStatisticFile) or die "$!";
	print FILESTATS $ds->renderIsoRatioIntersection();
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

if($DrawIsoratiolines)
{
	$options{Isoratiolines} = \@listIsoratiolineCoef;
	$options{DrawIsoratiolines} = 1;
}

if($DrawIsometriclines)
{
	$options{Isometriclines} = \@listIsometriclineCoef;
	$options{DrawIsometriclines} = 1;
}

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

&vprint("[*] Performing 'renderAsTxt'\n");
my $report = $ds->renderAsTxt("$temp/merge", 1, 1, \%options);
my $inf = "$temp/merge.png";
&vprint("[*] Copying [$inf] to [$OutPNGfile]\n");
my $err =  MMisc::filecopy($inf, $OutPNGfile);
MMisc::error_quit($err) if (! MMisc::is_blank($err));

if ($docsv) {
  &vprint("[*] Doing 'generateCSV'\n");
  my $csvf = $OutPNGfile;
  $csvf =~ s/\.png$//i;
  $csvf .= ".csv";
  my $csv = $ds->renderCSV("$temp/merge", 1, \%options);
  MMisc::writeTo($csvf, "", 1, 0, $csv);
}

if ($doTxtTable) {
  &vprint("[*] Doing \'txtTable\'\n");
  my $txtf = $OutPNGfile;
  $txtf =~ s/\.png$//i;
  $txtf .= ".results.txt";
  my $txt = $ds->renderAsTxt("$temp/merge", 1, \%options);
  MMisc::writeTo($txtf, "", 1, 0, $txt);
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

B<DETUtil.pl> [ OPTIONS ] -o F<PNG_FILE>  F<SERIALIZED_DET[:OPTs]> [F<SERIALIZED_DET>[:OPTs] [...]]

=head1 DESCRIPTION

The script merges multiple serialized DET Curves into a single PNG file and can provide a sign test when comparing two (2) DET Curves.  

The specification of the serialized DET Curves can optionally include a re-specification of the title and plot characteristics on the DET curve.  The BNF of the specification is below.  All fields can be empty in which case the default value will be used for the attribute

  SRL[:title[:pointSize[:pointType[:color[:lineWidth]]]]]
  
=over

title -> The title can includes spaces as long as the shell passed the string as a single argument.  This replacement occurs prior to any edit filters specified by the B<-e> option. 

pointSize -> A floating point number for the point size.

pointType -> Must be one of /(square|circle|triangle|utriangle|diamond)/.

color -> The RGB color formatted as /rgb "#hhhhhh"/ where the /h/ characters are hexidecimal RGB colors.

lineWidth -> A floating point number for the line width.

=back

=head1 OPTIONS

=head2 Requiredd file arguments:

=over

=item B<-o>, B<--output-png> F<PNG_FILE>

Output png file.

=item B<-r>, B<--output-ratiostats> F<FILE>

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

=item B<-O>, B<--OmitActualCalc>

Omit outputting actual Miss/FA/Costs.

=item B<-T>, B<--Title> F<TITLE>

Use  F<TITLE> for the title of the plot.   

=item B<-l>, B<--lineTitle> F<TITLE>

Modify the output line title by removing default information. F<TITLE> can include any number of these characters.
  P -> removes the Maximum Value Point Coordinates
  T -> removes the DET Curve Type
  M -> removes the Maximum Value

=item B<-K>, B<--KeyLoc> left | right | center | top | bottom | outside | below | ((left|right|center) (top|bottom|center))

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

/ColorScheme=grey/  ->  Sets the color scheme to greyscale.

/PointSize=\d+/     -> Overrides to default point size to the specified integer.

/ExtraPoint=text:FA:MISS:pointSize:pointType:color:justification/
                    -> Places a point at localtion FA,MISS with the label /text/ with the specified point type, color, size, and label justification.  All colons and the FA and MISS values are required.  Point type is an integer. Point color is /rgb "#hhhhhh"/ where the /h/ characters are hexidecimal RGB colors.  Point size is a floating point number.  Justification is either /right|left|center/.

/PointSetAreaDefinition=(Area|Radius)/     -> The value of C<pointSize> is display as either area of  the point or the width.  Def. is radius.

=item B<-F>, B<--ForceRecompute>

Force the DET points to be recomputed.  Some of the other options also re-compute the points.

=item B<-x> B<--txtTable>

Generate a table of statistics.  

=item B<-d> B<--dumpFile>

Dump the SRL files into a file that is readable.

=item B<-D> B<--DumpAllTargScr> fileroot

Dump all the file's Trials Target and Non Target scores into files starting with i<fileroot>.

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

The default font face can be changed by setting the environment variable GNUPLOT_DEFAULT_GDFONT to a ttf font like /Library/Fonts/Arial.

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
