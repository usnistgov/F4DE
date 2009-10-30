# VidAT
# FFmpegImage.pm
# Authors: Jerome Ajot
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

# $Id $

package FFmpegImage;

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
	
	print "$self->{aspect}\n";
	die;
}

sub extractJpeg
{
	my ($self, $dir) = @_;
	
	my $commandToRun = "ffmpeg -y -i '$self->{inFile}' -an -sameq -f image2 '$dir/%09d.jpeg'";
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

	$self->{nbrJpeg} = scalar(@files);
}

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