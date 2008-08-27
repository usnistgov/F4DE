#!/usr/bin/perl -w

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

use strict;
use Data::Dumper;

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $tv08pl, $tv08plv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv =  $ENV{$f4b} . "/lib";
  $tv08pl = "TV08_PERL_LIB";
  $tv08plv = $ENV{$tv08pl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib"; # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

use MetricTV08;
use Trials;

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR";              # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# DETCurve (part of this tool)
unless (eval "use DETCurve; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"DETCurve\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# DETCurveSet (part of this tool)
unless (eval "use DETCurveSet; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"DETCurveSet\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add
    (
     "\"Getopt::Long\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
  $have_everything = 0;
}

# Pod::Usage (usualy part of the Perl Core)
unless (eval "use Pod::Usage; 1") {
  &_warn_add
    (
     "\"Pod::Usage\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=pod%3A%3Ausage\" for installation information\n"
    );
  $have_everything = 0;
}

# File::Temp (usualy part of the Perl Core)
unless (eval "use File::Temp qw/ tempdir /; 1") {
  &_warn_add
    (
     "\"File::Temp\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=file%3A%3Atemp\" for installation information\n"
    );
  $have_everything = 0;
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

my $VERSION = 0.4;
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
my $DetCompare = 0;
my $DrawIsoratiolines = 0;
my $Isoratiolineslist = "";
my $DrawIsometriclines = 0;
my $Isometriclineslist = "";
my $DrawIsopoints = 0;
my $confidenceIsoThreshold = 0.95;
my $ConclusionOverall = 0;
my $gzipPROG = "gzip";
my $gnuplotPROG = "gnuplot";
my $axisScales = undef;
my $omitActual = 0;

Getopt::Long::Configure(qw( no_ignore_case ));

GetOptions
(
	'o|output-png=s'                       => \$OutPNGfile,
	
	't|tmpdir=s'                           => \$tmpDir,
	's|select-filter=s'                    => \@selectFilters,
	'e|edit-filter=s'                      => \@editFilters,
	'c|compare'                            => \$DetCompare,
	'C|ConclusionOverall'                  => \$ConclusionOverall,
	'k|keepFiles'                          => \$keepFiles,
	
	'i|iso-costratiolines'                 => \$DrawIsoratiolines,
	'R|set-iso-costratiolines=s'           => \$Isoratiolineslist,
	'I|iso-metriclines'                    => \$DrawIsometriclines,
	'Q|set-iso-metriclines=s'              => \$Isometriclineslist,
	'P|iso-points'                         => \$DrawIsopoints,
	'T|Title=s'                            => \$title,
	'l|lineTitle=s'                        => \$lineTitleModification,
	'S|Scale=s'                            => \$scale,
	'K|KeyLoc=s'                           => \$keyLoc,
	'Z|ZipPROG=s'                          => \$gzipPROG,
	'G|GnuplotPROG=s'                      => \$gnuplotPROG,
	'A|AxisScale=s'                        => \$axisScales,
	'O|OmitActualCalc'                     => \$omitActual, 
	
	'version'                              => sub { my $name = $0; $name =~ s/.*\/(.+)/$1/; print "$name version $VERSION\n"; exit(0); },
	'h|help'                               => \$help,
	'm|man'                                => \$man,
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
		die "ERROR: The coefficient for the iso-costratioline if not a proper floating-point." if( $c !~ /^\d*\.?\d+([eE][-+]?\d+)?$/ );
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
		die "ERROR: The coefficient for the iso-metricline if not a proper floating-point." if( $c !~ /^[-+]?\d*\.?\d+([eE][-+]?\d+)?$/ );
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
	die "Error: Edit Filter '$_' does not match a legal expression" if ($_ !~ /^title:s\/[^\/]+\/[^\/]*\/(g|i|gi|ig|)$/);
}
#
##

my %options = ();
$options{title} = $title if (defined $title);
$options{noSerialize} = 1;

$options{lTitleNoDETType} = 1 if ($lineTitleModification =~ /T/);
$options{lTitleNoPointInfo} = 1 if ($lineTitleModification =~ /P/);
$options{lTitleNoBestComb} = 1 if ($lineTitleModification =~ /M/);

$options{gnuplotPROG} = $gnuplotPROG;
$options{createDETfiles} = 1;
if (defined($axisScales)){
  $axisScales =~ tr/A-Z/a-z/; 
  if ($axisScales !~ /^(nd|log|linear):(nd|log|linear)$/){
    usage();
    die "Error: Axis scales in appropriate" if ($axisScales !~ /^(nd|log|linear):(nd|log|linear)$/);
  }
  $options{xScale} = $1;  
  $options{yScale} = $2;
}

if (defined($scale))
{
	die "Error: Invalid Scale '$scale'. must match N:N:N:N" if ($scale !~ /^(\d+|\d*.\d+):(\d+|\d*.\d+):(\d+|\d*.\d+):(\d+|\d*.\d+)$/);
	$options{Xmin} = $1;
	$options{Xmax} = $2;
	$options{Ymin} = $3;
	$options{Ymax} = $4;
}

if (defined($keyLoc))
{
	die "Error: Invalid key location '$keyLoc'" if ($keyLoc !~ /^(left|right|top|bottom|outside|below)$/);
	$options{KeyLoc} = $keyLoc;
}

if($omitActual)
{
	$options{ReportActual} = 0;
}

my $ds = new DETCurveSet($title);

foreach my $srl ( @ARGV )
{
	my $loadeddet = DETCurve::readFromFile($srl, $gzipPROG);
	@listIsoratiolineCoef = $loadeddet->getMetric()->isoCostRatioCoeffForDETCurve() if(scalar(@listIsoratiolineCoef) == 0);
	@listIsometriclineCoef = $loadeddet->getMetric()->isoCombCoeffForDETCurve() if(scalar(@listIsometriclineCoef) == 0);  
	
	my $det;
	
	if($DrawIsoratiolines)
	{
		$det = new DETCurve($loadeddet->getTrials(), $loadeddet->getMetric(), $loadeddet->getStyle(), $loadeddet->getLineTitle(), \@listIsoratiolineCoef, $loadeddet->{GZIPPROG});
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
		
		my $rtn = $ds->addDET($det->getLineTitle() . "$srl", $det);
    	die "Error: Unable to add DET to DETSet.\n$rtn\n"	if ($rtn ne "success");
	}
}

if($DetCompare)
{
	my ($det1, $det2) = @{ $ds->getDETList() };
	
	my $det1name = $det1->{LAST_SERIALIZED_DET};
	$det1name =~ s/\.srl$//;
	my $det2name = $det2->{LAST_SERIALIZED_DET};
	$det2name =~ s/\.srl$//;
	
	my %statsCompare;
	
	foreach my $cof ( @listIsoratiolineCoef )
	{
		$statsCompare{$cof}{COMPARE}{PLUS} = 0;
		$statsCompare{$cof}{COMPARE}{MINUS} = 0;
		$statsCompare{$cof}{COMPARE}{ZERO} = 0;
		$statsCompare{$cof}{DET1}{PFA} = $det1->{ISOPOINTS}{$cof}{INTERPOLATED_MFA};
		$statsCompare{$cof}{DET1}{PMISS} = $det1->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS};
		$statsCompare{$cof}{DET2}{PFA} = $det2->{ISOPOINTS}{$cof}{INTERPOLATED_MFA};
		$statsCompare{$cof}{DET2}{PMISS} = $det2->{ISOPOINTS}{$cof}{INTERPOLATED_MMISS};
		
		my @tmpblkkey1 = keys %{ $det1->{ISOPOINTS}{$cof}{BLOCKS} };
		my @tmpblkkey2 = keys %{ $det2->{ISOPOINTS}{$cof}{BLOCKS} };
		
		my @com_blocks = intersection( @tmpblkkey1, @tmpblkkey2 );
	
		foreach my $b ( @com_blocks )
		{
			my $diffdet12 = sprintf( "%.4f", $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} - $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} );
		
			push( @{ $statsCompare{$cof}{COMPARE}{DIFF}{ARRAY} }, $diffdet12);
		
			if( abs ( $diffdet12 ) < 0.001 )
			{
				$statsCompare{$cof}{COMPARE}{ZERO}++;
			}
			elsif( $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} > $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} )
			{
				$statsCompare{$cof}{COMPARE}{PLUS}++;
			}
			elsif( $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} < $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{COMB} )
			{
				$statsCompare{$cof}{COMPARE}{MINUS}++;
			}			
		}
				
		$statsCompare{$cof}{COMPARE}{BINOMIAL_WITH_ZEROS} = max( 0, binomial( 0.5, $statsCompare{$cof}{COMPARE}{PLUS}+$statsCompare{$cof}{COMPARE}{MINUS}+$statsCompare{$cof}{COMPARE}{ZERO}, $statsCompare{$cof}{COMPARE}{PLUS}+sprintf( "%.0f", $statsCompare{$cof}{COMPARE}{ZERO}/2)) );
		$statsCompare{$cof}{COMPARE}{BINOMIAL_WITHOUT_ZEROS} = max( 0, binomial( 0.5, $statsCompare{$cof}{COMPARE}{PLUS}+$statsCompare{$cof}{COMPARE}{MINUS}, $statsCompare{$cof}{COMPARE}{PLUS}) );
	}	
	
	print "Comparison between DET# 1:'$det1name' and DET# 2:'$det2name'\n";
	print ".----------------------------------------------------------------------------------------------------------.\n";
	print "|             |       DET# 1     |       DET# 2     |                      |     Sign Test    | Comparison |\n";
	print "|     Coef    |    Pfa    Pmiss  |    Pfa    Pmiss  |     +      -      0  |  w/ 0     w/o 0  |            |\n";
	print "|-------------+------------------+------------------+----------------------+------------------+------------|\n";
	
	my @list_isopoints;
	my %compare2;
	
	$compare2{DET1} = 0;
	$compare2{DET2} = 0;
	$compare2{ZERO} = 0;
	
	# Display the table
	foreach my $cof ( @listIsoratiolineCoef )
	{
		my $bestDET = "    -     ";
		my $isDiff = 0;
		
		if( $statsCompare{$cof}{COMPARE}{BINOMIAL_WITH_ZEROS} < ( 1 - $confidenceIsoThreshold ) )
		{
			$isDiff = 1;
			$bestDET = "  DET# 1  ";
			$compare2{DET1}++;
		}
		elsif( $statsCompare{$cof}{COMPARE}{BINOMIAL_WITH_ZEROS} > $confidenceIsoThreshold )
		{
			$isDiff = 1;
			$bestDET = "  DET# 2  ";
			$compare2{DET2}++;
		}
		else
		{
			$compare2{ZERO}++;
		}
	
		printf( "| %11.4f | %8.6f  %6.4f | %8.6f  %6.4f | %6d %6d %6d | %7.5f  %7.5f | %s |\n", $cof, $statsCompare{$cof}{DET1}{PFA}, $statsCompare{$cof}{DET1}{PMISS},$statsCompare{$cof}{DET2}{PFA}, $statsCompare{$cof}{DET2}{PMISS}, $statsCompare{$cof}{COMPARE}{PLUS}, $statsCompare{$cof}{COMPARE}{MINUS},$statsCompare{$cof}{COMPARE}{ZERO}, $statsCompare{$cof}{COMPARE}{BINOMIAL_WITH_ZEROS}, $statsCompare{$cof}{COMPARE}{BINOMIAL_WITHOUT_ZEROS}, $bestDET );
		
		push( @list_isopoints, [( $statsCompare{$cof}{DET1}{PFA}, $statsCompare{$cof}{DET1}{PMISS},$statsCompare{$cof}{DET2}{PFA}, $statsCompare{$cof}{DET2}{PMISS}, 1 - $isDiff )] ) if( $DrawIsopoints );
	}
	
	print "'----------------------------------------------------------------------------------------------------------'\n";
	
	if( $ConclusionOverall == 1 )
	{
		my $compare2sign = max( 0, binomial( 0.5, $compare2{DET1}+$compare2{DET2}+$compare2{ZERO}, $compare2{DET1}+sprintf( "%.0f", $compare2{ZERO}/2)) );
		
		printf( "Overall sign test:\n  DET# 1 performs %d time%s better than DET# 2\n  DET# 2 performs %d time%s better than DET# 1\n  %d time%s, it is inconclusive\n", $compare2{DET1}, ( $compare2{DET1} > 1 ) ? "s" : "", $compare2{DET2}, ( $compare2{DET2} > 1 ) ? "s" : "", $compare2{ZERO}, ( $compare2{ZERO} > 1 ) ? "s" : "");
		
		if( $compare2sign < ( 1 - $confidenceIsoThreshold ) )
		{
			printf(" With %.0f%% of confidence (test=%.5f), DET# 1 overall performs better then DET# 2.\n", $confidenceIsoThreshold*100, $compare2sign );
		}
		elsif( $compare2sign > $confidenceIsoThreshold )
		{
			printf(" With %.0f%% of confidence (test=%.5f), DET# 2 overall performs better then DET# 1.\n", $confidenceIsoThreshold*100, $compare2sign );
		}
		else
		{
			printf(" With %.0f%% of confidence (test=%.5f), nothing can be concluded.\n", $confidenceIsoThreshold*100, $compare2sign );
		}
	}
	
	$options{Isopoints} = \@list_isopoints if( $DrawIsopoints );
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
	$temp = tempdir( "$tmpDir/DETUtil.XXXXXXXX", CLEANUP => !$keepFiles );
}
else
{
	$temp = tempdir( CLEANUP => !$keepFiles );
}

my $report = $ds->renderAsTxt("$temp/merge", 1, 1, \%options);
system "cp $temp/merge.png $OutPNGfile";

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

sub max
{
	my $max = shift;
	foreach $_ (@_) { $max = $_ if $_ > $max; }
	return $max;
}

sub intersection
{
	my %l = ();
	my @listout;
	foreach my $e (@_) { $l{$e}++; }
	foreach my $e (keys %l) { push(@listout, $e) if($l{$e} > 1); }
	return @listout;	
}

sub comb
{
	my ($n, $k) = @_;
	
	return 0 if( $k < 0 || $k > $n );
	$k = $n - $k if(  $k > $n - $k );
	
	my $Cnk = 1;
	
	for( my $i=0; $i<$k; $i++ )
	{
		$Cnk *= $n - $i;
		$Cnk /= $i + 1;
	}
	
	return( $Cnk );
}

sub cdf_norm
{
	my ($z) = @_;
	my $PREC = 0.00005;
	my $PI = 3.14159265;
	
	my $a = 1;
	my $b = 1;
	my $c = $z;
	my $sum = $z;
	my $term = $z;
	
	return( 0.5 * $z / abs ( $z ) ) if( abs( $z ) > 8 );
	
	for( my $i=1; abs( $term ) > $PREC; $i++ )
	{
		$a += 2;
		$b *= -2 * $i;
		$c *= $z * $z;
		$term = $c/( $a * $b );
		$sum += $term;
	}
	
	return( $sum/sqrt( 2*$PI ) );
}

sub binomial
{
	my ($p, $n, $s) = @_;
	
	my $sum = 0;
	
	if( $n > 30 )
	{
		my $sigma = sqrt( $n*$p*(1.0-$p) );
		my $z = ( ($s+0.5) - $n*$p )/$sigma;
		$sum = 0.5 + cdf_norm( $z );
	}
	else
	{
		for( my $i=0; $i<=$s; $i++ )
		{
			$sum += comb( $n, $i ) * ( $p ** $i ) * ( (1.0-$p) ** ( $n - $i ) );
		}
	}
	
	return( 1 - $sum );
}

__END__

=head1 NAME

DETUtil.pl -- Merge DET Curves and statistical analyses.

=head1 SYNOPSIS

B<DETUtil.pl> [ OPTIONS ] -o F<PNG_FILE>  F<SERIALIZED_DET> [F<SERIALIZED_DET> [...]]

=head1 DESCRIPTION

The script merges multiple DET Curves into a single PNG file and can provide a sign test when comparing two (2) DET Curves.

=head1 OPTIONS

=head2 Required file arguments:

=over 25

=item B<-o>, B<--output-png> F<PNG_FILE>

Output png file.

=head2 Optional arguments:

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

=item B<-C>, B<--ConclusionOverall>

Make a conclusion on the sign test analysis (required -c).

=item B<-Z>, B<--ZipPROG> F<GZIP_PATH>

Specify the full path name to gzip (default: 'gzip').

=item B<-G>, B<--GnuplotPROG> F<GNUPLOT_PATH>

Specify the full path name to gnuplot (default: 'gnuplot').

=head2 Graph tweaks:

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

=item B<-K>, B<--KeyLoc> left | right | top | bottom | outside | below

Place the key at one of the locations.

=item B<-S>, B<--Scale> F<Xmin>:F<Xmax>:F<Ymin>:F<Ymax>

Sets the X and Y axis ranges to the values. All points must be present.

=item B<-A>, B<--AxisScale> F<Xaxis>:F<Yaxis>

Sets the X and Y axis scale types for the graph:
  nd -> Normal Deviate (the default)
  log -> for logarithmic
  linear -> for non-weighted scale

=head2 Others:

=item B<-h>, B<--help>

Print the help.

=item B<-m>, B<--man>

Print the manual.

=item B<--version>

Print the version number.

=back

=head1 BUGS

No known bugs.

=head1 NOTES

The default iso-cost ratio coefficients (-R option) and iso-metric coefficients (-Q option) are defined into the metric.

=head1 AUTHOR

 Jonathan Fiscus <jonathan.fiscus@nist.gov>
 Jerome Ajot <jerome.ajot@nist.gov>
 Martial Michel <martial.michel@nist.gov>

=head1 VERSION

DETUtil.pl version 0.4

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut