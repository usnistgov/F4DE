#!/usr/bin/env perl

# VidAT_Montage.pl
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by employees of the Federal 
# Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this 
# software is not subject to copyright protection within the United States and is in the public domain. It is an 
# experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY 
# MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use warnings;

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ($f4d);
}
use lib (@f4bv);

use File::Temp qw( tempdir tempfile );
use File::Path qw( rmtree );
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use File::Copy;

use threads; 
use Thread::Queue;

my $FFMPEG_BIN = "ffmpeg";
#my $MONTAGE_BIN = "montage -font '/Library/Fonts/Arial.ttf'";
my $MONTAGE_BIN = "montage";
my $CONVERT_BIN = "convert";
my $threads = 1;
my @thre;
my @thrm;

autoflush STDERR;

my @inputFileStrings;
my $outFile = "";
my $help = 0;
my $man = 0;
my $keep = "";

my $keep1 = 0;
my $keep2 = 9e99;

GetOptions
(
	'i=s@'   => \@inputFileStrings,
	'o=s'    => \$outFile,
	'h|help' => \$help,
	'man'    => \$man,
	'k=s'    => \$keep,
	't=i'    => \$threads,
) or pod2usage(1);

pod2usage(1) if $help;
pod2usage(-exitvalue => 0, -verbose => 2) if $man;
pod2usage("Error: Input video must be specified.\n") if(scalar(@inputFileStrings) == 0);
pod2usage("Error: Output file must be specified.\n") if($outFile eq "");

if($keep =~ /^(\d+),(\d+)$/)
{
	$keep1 = int($1);
	$keep2 = int($2);
}

my %Videos;

my $maxX = 0;
my $maxY = 0;

for(my $i=0; $i<scalar(@inputFileStrings); $i++)
{
	$Videos{$i}{VIDEOFILE} = $inputFileStrings[$i];
	$Videos{$i}{TEMP_DIR} = tempdir( CLEANUP => 1 );
}

my $fps = undef;

my $width = 9e99;
my $height = 9e99;
my $blackJpeg;
my $maxNbFile = 0;

createBlackJpeg();

for(my $i=0; $i<scalar(@inputFileStrings); $i++)
{
	($Videos{$i}{WIDTH_ORIG}, $Videos{$i}{HEIGHT_ORIG}, $Videos{$i}{ASPECT_WIDTH}, $Videos{$i}{ASPECT_HEIGHT}, $Videos{$i}{FPS}) = parseVideoInformation($inputFileStrings[$i]);
	
	if(!defined($fps))
	{
		$fps = $Videos{$i}{FPS};
	}
	elsif($fps != $Videos{$i}{FPS})
	{
		print "$fps consistent across videos.\n";
		exit(1);
	}
	
	$Videos{$i}{WIDTH_FINAL} = closest4( $Videos{$i}{HEIGHT_ORIG}*$Videos{$i}{ASPECT_WIDTH}/$Videos{$i}{ASPECT_HEIGHT} );
	$Videos{$i}{HEIGHT_FINAL} = closest4( $Videos{$i}{HEIGHT_ORIG} );
	
	$width = min($width, $Videos{$i}{WIDTH_FINAL});
	$height = min($height, $Videos{$i}{HEIGHT_FINAL});
}


my $DataExtractQueue = Thread::Queue->new;

for(my $i=0; $i<$threads; $i++)
{
	$thre[$i] = threads->new(\&pextractJpeg);
}

for(my $i=0; $i<scalar(@inputFileStrings); $i++)
{
	$DataExtractQueue->enqueue($i+1);
}

for(my $i=0; $i<$threads; $i++)
{
	$DataExtractQueue->enqueue(undef);
}

for(my $i=0; $i<$threads; $i++)
{
	$thre[$i]->join;
}

for(my $i=0; $i<scalar(@inputFileStrings); $i++)
{	
	opendir(DIR, $Videos{$i}{TEMP_DIR});
	my @files = grep { /^\d+\.jpeg$/ } readdir(DIR);
	closedir(DIR);
	
	$Videos{$i}{NBR_FILES} = scalar(@files);
	$maxNbFile = max($maxNbFile, $Videos{$i}{NBR_FILES});
}

#
my $tempFinalDir = tempdir( CLEANUP => 1 );

print "Temp Dir: $tempFinalDir\n";
my $index = 1;

my $DataMontageQueue = Thread::Queue->new;

for(my $i=0; $i<$threads; $i++)
{
	$thrm[$i] = threads->new(\&pmergeJpegs);
}

for(my $i=1; $i<=$maxNbFile; $i++)
{
	if( ($keep1 <= $i) && ($i <= $keep2) )
	{
		my $nameJpeg = sprintf("%09d.jpeg", $index);
		my $fulllist = "$tempFinalDir/$nameJpeg";
		my $inputJpegName = sprintf("%09d.jpeg", $i);
		
		for(my $j=0; $j<scalar(@inputFileStrings); $j++)
		{
			if($j < $Videos{$j}{NBR_FILES})
			{
				# The jpeg exists
				$fulllist .= "|$Videos{$j}{TEMP_DIR}/$inputJpegName";
			}
			else
			{
				# no more jpeg for you, use the black one
				$fulllist .= "|$blackJpeg";
			}
		}
		
		$DataMontageQueue->enqueue($fulllist);
		$index++;
	}
}

for(my $i=0; $i<$threads; $i++)
{
	$DataMontageQueue->enqueue(undef);
}

for(my $i=0; $i<$threads; $i++)
{
	$thrm[$i]->join;
}

if($keep1 != $keep2)
{
	buildVideo($tempFinalDir, $outFile);
}
else
{
	my $nameJpeg = sprintf("%09d.jpeg", $keep1);
	copy("$tempFinalDir/$nameJpeg", $outFile) or die "Copy failed: $!";
}

# Clean up
cleanup();

exit(0);

## FUNCTIONS
sub pextractJpeg
{
	while(my $DataExtractElement = $DataExtractQueue->dequeue)
	{
		$DataExtractElement--;
		extractJpeg($Videos{$DataExtractElement}{VIDEOFILE}, $Videos{$DataExtractElement}{TEMP_DIR});
	} 
}

sub buildVideo
{
	my ($dir, $outFile) = @_;
	
	my $commandToRun = "$FFMPEG_BIN -r $fps -i '$dir/%9d.jpeg' -sameq -vcodec mpeg4 -f avi -mbd rd -flags +4mv+aic -trellis 2 -cmp 2 -subcmp 2 -g 250 -threads $threads -bf 2 -flags qprd -flags mv0 -y '$outFile'";
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;
	
	if($exitStatus != 0)
	{
		print STDERR "Cannot build movie file '$outFile':\n$returnCommand\n";
		return(0);
	}
}

sub pmergeJpegs
{
	while(my $DataMontageElement = $DataMontageQueue->dequeue)
	{
		mergeJpegs($DataMontageElement);
	}
}

sub mergeJpegs
{
	my ($Jpegs) = @_;
	
	my $commandToRun = "$MONTAGE_BIN -quality 85 -interlace Line -background black -geometry $width"."x"."$height"."! ";
	
	my @jpg = split('\|', $Jpegs);
	
	for(my $i=1; $i<scalar(@jpg); $i++)
	{
		$commandToRun .= " '$jpg[$i]' ";
	}
	
	$commandToRun .= " '$jpg[0]' ";
	
	print "Process Images $jpg[0]\r";
	
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;
	
	if($exitStatus != 0)
	{
		print STDERR "Cannot merge JPEG files to '$jpg[0]':\n$commandToRun\n$returnCommand\n";
		return(0);
	}
}

sub createBlackJpeg
{
	(undef, $blackJpeg) = tempfile(OPEN => 0, SUFFIX => ".jpeg", UNLINK => 1);
	my $commandToRun = "$CONVERT_BIN -size 8x8 xc:black '$blackJpeg'";
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;
	
	if($exitStatus != 0)
	{
		print STDERR "Cannot black JPEG file '$blackJpeg':\n$returnCommand\n";
		return(0);
	}
}

sub cleanup
{
	for(my $i=0; $i<scalar(@inputFileStrings); $i++)
	{
		rmtree($Videos{$i}{TEMP_DIR});
	}
	
	rmtree($tempFinalDir);
	
	unlink($blackJpeg);
}


sub extractJpeg
{
	my ($videoFile, $dir) = @_;
	
	my $commandToRun = "$FFMPEG_BIN -y -i '$videoFile' -an -sameq -f image2 '$dir/%09d.jpeg'";
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;
	
	if($exitStatus != 0)
	{
		print STDERR "Cannot extract JPEGs from file '$videoFile':\n$returnCommand\n";
		return(0);
	}
}

sub closest4
{
	my ($x) = @_;
	
	return( 4*int($x/4 + 0.5) );
}

sub parseVideoInformation
{
	my ($videoFile) = @_;

	my $resolutionW = undef;
	my $resolutionH = undef;
	my $aspectW = undef;
	my $aspectH = undef;
	my $fps = undef;
	
	## Get Information
	my $commandToRun = "$FFMPEG_BIN -i '$videoFile' 2>&1";
	my $ffmpegInfo = qx($commandToRun);

	# Get Resolution
	if($ffmpegInfo =~ /Stream \#0.\d.*?\: Video: .+?, (\d+)x(\d+)/)
	{
		$resolutionW = $1;
		$resolutionH = $2;
	}
	
	# Get DAR
	if($ffmpegInfo =~ /Stream \#0.\d.*?\: Video: .+? DAR (\d+):(\d+)/)
	{
		$aspectW = $1;
		$aspectH = $2;
	}

	# Get FPS
	if($ffmpegInfo =~ /(\d+\.?\d*) tbr/)
	{
		$fps = $1;
	}
	
	return($resolutionW, $resolutionH, $aspectW, $aspectH, $fps);
}

sub min
{
	my $min = shift;
	foreach my $x (@_) {if(defined($x)) { $min = $x if($x < $min); } }	
	return $min;
}

sub max
{
	my $max = shift;
	foreach my $x (@_) {if(defined($x)) { $max = $x if($x > $max); } }	
	return $max;
}

=head1 NAME

VidAT_Montage -- Video Montage Tool 

=head1 SYNOPSIS

B<VidAT_Montage> -i F<VIDEO> [-i F<VIDEO> [...]] [-t F<threads>] -o F<OUTPUT> [-k F<begframe>,F<endframe>] [-man] [-h]

=head1 DESCRIPTION

The software creates a composite video from multiple video inputs into a single video.  The program combines the images on a frame-by-frame basis.

=head1 OPTIONS

=over

=item B<-i> F<VIDEO>

Input video file.

=item B<-t> F<threads>

Set the number of threads.

=item B<-o> F<OUTPUT>

Output video file.

=item B<-k> F<begframe>,F<endframe>

Just create a chunck of the video from begframe to endframe frames.

=item B<-man>

Manual.

=item B<-h>, B<--help>

Help.

=back

=head1 ADDITIONAL TOOLS

Third part software need to be installed:

 FFmpeg <http://ffmpeg.org/>
 Ghostscript <http://pages.cs.wisc.edu/~ghost/>
 ImageMagick <http://www.imagemagick.org> with JPEG v6b support <ftp://ftp.uu.net/graphics/jpeg/>

=head1 BUGS

No known bugs.

=head1 NOTE

To build a montage video, the input video files must have the same duration, especially the same number of frames.
If B<VidATLog> has been used to generate the video, the vidatLog '-k' option has the same value.

=head1 AUTHORS

 Jerome Ajot

=head1 VERSION

=head1 COPYRIGHT

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to title 17 Section 105 of the United States Code this software is not subject to copyright protection and is in the public domain. VidAT is an experimental system.  NIST assumes no responsibility whatsoever for its use by other parties, and makes no guarantees, expressed or implied, about its quality, reliability, or any other characteristic.  We would appreciate acknowledgement if the software is used.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
