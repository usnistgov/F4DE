# VidAT_FFmpegImage.pm
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by employees of the Federal 
# Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this 
# software is not subject to copyright protection within the United States and is in the public domain. It is an 
# experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY 
# MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

package VidAT_FFmpegImage;

use strict;
use warnings;
use File::Basename;

sub new
{
	my ($class, $inFile) = @_;
	my $self =
	{
		FFMPEG         => 'ffmpeg',
		inFile         => $inFile,
		fps            => undef,
		codec          => undef,
		container      => undef,
		nbrJpeg        => undef,
		aspect         => undef,
		resolution     => 
		{
			w => undef,
			h => undef,
		},
	};
	
	bless $self;
	
	$self->parseVideoInformation();
	
	return $self;
}

=pod

=item B<parseVideoInformation>()

Parse the the video information (FPS, Duration, DAR, Codec) from the video file provided at the the creation of the 
object.

=cut

sub parseVideoInformation
{
	my ($self) = @_;
	
	## Get Information
	my $commandToRun = "ffmpeg -i '$self->{inFile}' 2>&1";
	my $ffmpegInfo = qx($commandToRun);

	# Get Container
	my $filename = basename($self->{inFile});
	my $extension = "";
	$extension = $1 if($filename =~ /^.*?\.([^\.]*)$/);

	if($ffmpegInfo =~ /Input \#\d, (.+?), /)
	{
		my @a = split(/,/, $1);
		$self->{container} = $a[0];
		
		for(my $i=0; $i<scalar(@a); $i++)
		{
			$self->{container} = $extension if($a[$i] eq $extension);
		}
	}
	else
	{
		$self->{container} = "avi";
	}
	
	# Get Codec
	if($ffmpegInfo =~ /Stream \#0.\d.*?\: Video: (.+?),/)
	{
		$self->{codec} = $1;
	}
	else
	{
		$self->{codec} = "mpeg4";
	}
	
	# Get Resolution
	if($ffmpegInfo =~ /Stream \#0.\d.*?\: Video: .+?, (\d+)x(\d+)/)
	{
		$self->{resolution}{w} = $1;
		$self->{resolution}{h} = $2;
	}
	
	# Get DAR
	if($ffmpegInfo =~ /Stream \#0.\d.*?\: Video: .+? DAR (\d+:\d+)/)
	{
		$self->{aspect} = $1;
	}

	# Get FPS
	if($ffmpegInfo =~ /(\d+\.?\d*) tbr/)
	{
		$self->{fps} = $1;
	}
	else
	{
		$self->{fps} = 25;
	}
	
	# Get Duration
	if($ffmpegInfo =~ /Duration: (\d+):(\d+):(\d+)/)
	{
		$self->{duration} = 3600*$1 + 60*$2 + $3 + 1;
		$self->{expectedframes} = int($self->{duration}*($self->{fps} + 0.01));
	}
}

=pod

=item B<extractJpeg>(I<$dir>, I<$firstFrame>, I<$lastFrame>)

Extract all the frames defined between I<$firstFrame> and I<$lastFrame> into the directory I<$dir>. Frames will be a 
JPEG is the name will be the frame number.

=cut

sub extractJpeg
{
	my ($self, $dir, $firstFrame, $lastFrame) = @_;
	
	my $beginSecondTime = $firstFrame/$self->{fps};
	my $hours = int($beginSecondTime/3600);
	my $mins = int( ($beginSecondTime - 3600*$hours)/60 );
	my $secs = int($beginSecondTime - 3600*$hours - $mins*60 );
	my $msecs = int( 1000*($beginSecondTime - 3600*$hours - $mins*60 - $secs) + 0.5);

	my $nbrFrames = $lastFrame - $firstFrame + 1;

	my $strBegTime = sprintf("%02d:%02d:%02d.%03d", $hours, $mins, $secs, $msecs);
	
	my $commandToRun = "ffmpeg -y -i '$self->{inFile}' -ss $strBegTime -vframes $nbrFrames -an -sameq -f image2 '$dir/%09d.jpeg'";
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;
	
	if($exitStatus != 0)
	{
		print STDERR "Cannot extract JPEGs from file '$self->{inFile}':\n$returnCommand\n";
		return(0);
	}
	
	opendir(DIR, $dir);
	my @files = grep { /^\d+\.jpeg$/ } readdir(DIR);
	closedir(DIR);
	
	for(my $i = 0; $i<scalar(@files); $i++)
	{
		my $currentFileName = sprintf("$dir/%09d.jpeg", $i+1);
		my $newFileName = sprintf("$dir/0%09d.jpeg", $i+$firstFrame);
		
		rename("$currentFileName", "$newFileName");
	}

	$self->{nbrJpeg} = scalar(@files);
}

=pod

=item B<buildVideo>(I<$dir>, I<$outFile>)

Recontruct the video I<$outFile> from the JPEG files in the directory I<$dir>.

=cut

sub buildVideo
{
	my ($self, $dir, $outFile) = @_;
	
	my $outFilename = $outFile;
	
	my $filename = basename($outFile);
	my $extension = "";
	$extension = $1 if($filename =~ /^.*?\.([^\.]*)$/);
	
	$outFilename .= ".$self->{container}" if($extension ne $self->{container});
	
	my $aspect = "";
	
	$aspect = "-aspect $self->{aspect}" if(defined($self->{aspect}));
	
	my $commandToRun = "ffmpeg -y -r $self->{fps} -i '$dir/%9d.jpeg' -sameq -f $self->{container} $aspect -vcodec $self->{codec} -y '$outFilename'";
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;
	
	if($exitStatus != 0)
	{
		print STDERR "Cannot build movie file '$outFile':\n$returnCommand\n";
		return(0);
	}
}

1;
