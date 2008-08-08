#!/usr/bin/perl -w

# DETUtil
# DETUtil.pl
# Author: Jonathan Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. STDEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use Data::Dumper;
use MetricTV08;
use Trials;

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

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}


Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $VERSION = 0.3;
my $OutPNGfile = "";
my $tmpDir = "/tmp";
my @selectFilters = ();
my @editFilters = ();
my $keepFiles = 0;
my $title = undef;
my $scale = undef;
my $lineTitleModification = "";
my $keyLoc = undef;
my $DetCompare = 0;
my $DrawIsolines = 0;
my $DrawIsopoints = 0;
my $confidenceIsoThreshold = 0.95;
my $ConclusionOverall = 0;
my $gzipPROG = "gzip";
my $gnuplotPROG = "gnuplot";
my $axisScales = undef;

GetOptions
(
	'output-png=s'                       => \$OutPNGfile,
	'tmpdir=s'                           => \$tmpDir,
	'select-filter=s'                    => \@selectFilters,
	'edit-filter=s'                      => \@editFilters,
	'compare'                            => \$DetCompare,
	'isolines'                           => \$DrawIsolines,
	'Isopoints'                          => \$DrawIsopoints,
	'keepFiles'                          => \$keepFiles,
	'Title=s'                            => \$title,
	'lineTitle=s'                        => \$lineTitleModification,
	'Scale=s'                            => \$scale,
	'KeyLoc=s'                           => \$keyLoc,
	'ConclusionOverall'                  => \$ConclusionOverall,
  'ZipPROG=s'                          => \$gzipPROG,
  'GnuplotPROG=s'                      => \$gnuplotPROG,
  'AcisScale=s'                        => \$axisScales,
	'version',                           => sub { print "STDListGenerator version: $VERSION\n"; exit },
	'help'                               => sub { usage (); exit },
);

die "ERROR: An Output file must be set." if($OutPNGfile eq "");
### Check the filter syntax
foreach $_(@selectFilters)
{
	die "Error: Select Filter '$_' does not match a legal expression" if ($_ !~ /^title:.+$/);
}
foreach $_(@editFilters)
{
	die "Error: Edit Filter '$_' does not match a legal expression" if ($_ !~ /^title:s\/[^\/]+\/[^\/]*\/(g|i|gi|ig|)$/);
}

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

### make a temporary dirctory
my $temp = "$tmpDir/DET.$$";

my $ds = new DETCurveSet($title);

die "--compare works only with 2 DET curves" if( ( scalar ( @ARGV ) != 2 ) && $DetCompare );

foreach my $srl( @ARGV )
{
  my $det = DETCurve::readFromFile($srl, $gzipPROG);
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
	
	if ($keep)
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
		
		my $rtn = $ds->addDET($det->getLineTitle(), $det);
    die "Error: Unable to add DET to DETSet.\n$rtn\n"	if ($rtn ne "success");
	}
}

if($DetCompare)
{
	my ($det1, $det2) = $ds->getDETList();
	
	die "'$det1->{LAST_SERIALIZED_DET}' contains no information regarding Isoline" if( !defined( $det1->{ISOPOINTS} ) );
	die "'$det2->{LAST_SERIALIZED_DET}' contains no information regarding Isoline" if( !defined( $det2->{ISOPOINTS} ) );
	
	my @tmpcoefkeys1 = keys %{ $det1->{ISOPOINTS} };
	my @tmpcoefkeys2 = keys %{ $det2->{ISOPOINTS} };
	
	my $det1name = $det1->{LAST_SERIALIZED_DET};
	$det1name =~ s/\.srl$//;
	my $det2name = $det2->{LAST_SERIALIZED_DET};
	$det2name =~ s/\.srl$//;
	
	my @com_coefs = intersection( @tmpcoefkeys1, @tmpcoefkeys2 );
	my %statsCompare;
	
	foreach my $cof ( @com_coefs )
	{
		$statsCompare{$cof}{COMPARE}{PLUS} = 0;
		$statsCompare{$cof}{COMPARE}{MINUS} = 0;
		$statsCompare{$cof}{COMPARE}{ZERO} = 0;
		$statsCompare{$cof}{DET1}{PFA} = $det1->{ISOPOINTS}{$cof}{INTERPOLATED_PFA};
		$statsCompare{$cof}{DET1}{PMISS} = $det1->{ISOPOINTS}{$cof}{INTERPOLATED_PMISS};
		$statsCompare{$cof}{DET2}{PFA} = $det2->{ISOPOINTS}{$cof}{INTERPOLATED_PFA};
		$statsCompare{$cof}{DET2}{PMISS} = $det2->{ISOPOINTS}{$cof}{INTERPOLATED_PMISS};
		
		my @tmpblkkey1 = keys %{ $det1->{ISOPOINTS}{$cof}{BLOCKS} };
		my @tmpblkkey2 = keys %{ $det2->{ISOPOINTS}{$cof}{BLOCKS} };
		
		my @com_blocks = intersection( @tmpblkkey1, @tmpblkkey2 );
	
		foreach my $b ( @com_blocks )
		{
			my $diffdet12 = sprintf( "%.4f", $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{VALUE} - $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{VALUE} );
		
			push( @{ $statsCompare{$cof}{COMPARE}{DIFF}{ARRAY} }, $diffdet12);
		
			if( abs ( $diffdet12 ) < 0.001 )
			{
				$statsCompare{$cof}{COMPARE}{ZERO}++;
			}
			elsif( $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{VALUE} > $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{VALUE} )
			{
				$statsCompare{$cof}{COMPARE}{PLUS}++;
			}
			elsif( $det1->{ISOPOINTS}{$cof}{BLOCKS}{$b}{VALUE} < $det2->{ISOPOINTS}{$cof}{BLOCKS}{$b}{VALUE} )
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
	foreach my $cof ( sort { $a <=> $b } @com_coefs )
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
	
#	$options{Isolines} = \@com_coefs if( $DrawIsolines );
	$options{Isolines} = $DrawIsolines;
	$options{Isopoints} = \@list_isopoints if( $DrawIsopoints );
}

## Setup a cleanup signal
sub cleanup
{
	system "rm -rf $temp";
}

$SIG{INT} = \&cleanup;

system "mkdir $temp";
my $report = $ds->renderAsTxt("$temp/merge", 1, 1, \%options);
# print $report;
system "cp $temp/merge.png $OutPNGfile";
cleanup() if (! $keepFiles);

exit 0;

#############################################  End of the program #########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}


sub usage
{
	print "DETUtil.pl [ [-s|-e] exp ]* [ -t TMPDIR ] [ -c ] -o outputPNG [ searializedDET1, searializedDET2, ...]\n";
	print "\n";
	print "Required file arguments:\n";
	print "  -o, --output-png         Path to write the PNG to\n";
	print "Optional arguments:\n";
	print "  -t, --tmpdir             Path to write temporary files in.\n";
	print "  -k                       Keep the .plt and dat files instead of deleting them\n";
	print "  -s, --select-filter exp  Reduce the combined printout by only including the curves\n";
	print "                           that match the regular expression:\n";
	print "                               title:exp forces the match on the title\n"; 
	print "  -e, --edit-filter exp    Edit the titles to reduce/expand the elements printed in the combined\n";
	print "                           plot with the regular expression:\n";
	print "                              title:exp edits the title\n";
	print "  -c, --compare            Compare 2 DET curves.\n"; 
  print "  -Z, --ZipPROG            Specify the full path name to gzip (Default is to have 'gzip' in your path)\n";
  print "  -G, --GnuplotPROG        Specify the full path name to gnuplot (Default is to have 'gnuplot' in your path)\n";
#	print "  -C, --ConclusionOverall  Make a conclusion on the Sign test analysis.\n"; 
	print "Graph tweaks:\n";
	print "  -i, --isolines           Draw the isolines\n";
	print "  -I, --Isopoints          Draw the isopoints and links\n"; 
	print "  -T, --Title STR          Use STR for the title of the plot\n";    
	print "  -l, --lineTitle STR      Modify the output line title by removing default information. STR\n";
	print "                           can include any number of these characters\n";
	print "                               P -> removes the Maximum Value Point Coordinates\n";
	print "                               T -> removes the DET Curve Type\n";
	print "                               M -> removes the Maximum Value\n";
	print "  -K, --KeyLoc STR         Place the key at one of the locations: \n";
	print "                           STR => left | right | top | bottom | outside | below\n";
	print "  -S, --Scale Xmin:Xmax:Ymin:Ymax   Sets the X and Y axis ranges to the values.  All points must be\n";
	print "                           present\n";
	print "  -A, --AxisScale Xaxis:Yaxis       Sets the X and Y axis scale types for the graph: \n";
	print "                               nd -> Normal Deviate (the default)\n";
	print "                               log -> for logarithmic.\n";
	print "                               linear -> for non-weighted scale.\n";
	print "\n";
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
	
	if( abs( $z ) > 8 )
	{
		return( 0.5 * $z / abs ( $z ) );
	}
	
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


