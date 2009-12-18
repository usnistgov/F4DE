# VidAT
# JPEGEdit.pm
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

package JPEGEdit;

use strict;
use warnings;
use File::Temp qw( tempfile );
use POSIX qw(ceil floor);

use Data::Dumper;

sub new
{
	my ($class, $inFile, $tmpBaseDir) = @_;
	my $self =
	{
		MOGRIFY         => 'mogrify',
		CONVERT         => 'convert',
		FONT            => '/Library/Fonts/Arial.ttf',
		workingImage    => undef,
		inFile          => $inFile,
		jpegQuality     => 85,
		jpegProgressive => 1,
		hasChanged      => 0,
		tmpBaseDir => $tmpBaseDir,
	};
	
	bless $self;
	
	return $self;
}

sub clean
{
	my ($self) = @_;
	$self->deleteWorkingImage();
}

sub createWorkingImage
{
	my ($self) = @_;
	
	if(!defined($self->{workingImage}))
	{
		(undef, $self->{workingImage}) = tempfile(OPEN => 0, SUFFIX => ".MIFF", UNLINK => 1, DIR => $self->{tmpBaseDir});
		my $commandToRun = "$self->{CONVERT} '$self->{inFile}' -quality 100 -format MIFF '$self->{workingImage}' 2>&1";
		my $returnCommand = qx($commandToRun);
		my $exitStatus = $? >> 8;
		
		if($exitStatus != 0)
		{
			print STDERR "Cannot create WorkingFile of '$self->{inFile}':\n$commandToRun\n$returnCommand\n";
			return(0);
		}
	}
}

sub deleteWorkingImage
{
	my ($self) = @_;
	unlink($self->{workingImage}) if(defined($self->{workingImage}));
}

sub duplicateInputImage
{
	my ($self, $outFile) = @_;

	my $commandToRun = "/bin/cp '$self->{inFile}' '$outFile' 2>&1";
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;

	if($exitStatus != 0)
	{
		print STDERR "Cannot duplicate image '$self->{inFile}' into '$outFile':\n$returnCommand\n";
		return(0);
	}
}

sub jpeg
{
	my ($self, $outFile) = @_;
	
	if($self->{hasChanged} > 0)
	{
		my $qualityOption = "-quality $self->{jpegQuality}";
		my $progressiveOption = ($self->{jpegProgressive}) ? "-interlace Line" : "";
	
		my $commandToRun = "$self->{CONVERT} '$self->{workingImage}' $qualityOption $progressiveOption -format jpeg '$outFile' 2>&1";
		my $returnCommand = qx($commandToRun);
		my $exitStatus = $? >> 8;
	
		if($exitStatus != 0)
		{
			print STDERR "Cannot convert jpeg image into '$outFile':\n$returnCommand\n";
			return(0);
		}
	}
	else
	{
		$self->duplicateInputImage($outFile);
	}
	
	return 1;
}

sub drawPolygon
# $polygonCorners is an array of x,y,x,y,x,y,x,y,etc...
# $borderColor is [R, G, B, alpha] R,G, and B in 255 alpha in 1.0
{
	my ($self, $polygonCorners, $borderColor, $borderWidth, $fillPolygon, $close) = @_;
	
	if(scalar(@$polygonCorners) % 2 == 1)
	{
		print STDERR "Polygon Corners array must contain even number of coordinates.";
		return(0);
	}
	
	$self->createWorkingImage();
	
	my $corners = "";
	
	for(my $i=0; $i<scalar(@$polygonCorners); $i += 2)
	{
		$corners .= "$polygonCorners->[$i],$polygonCorners->[$i+1] ";
	}
	
	my $borderOption = "-stroke 'rgba($borderColor->[0],$borderColor->[1],$borderColor->[2],$borderColor->[3])' -strokewidth $borderWidth";
	my $fillOption = "-fill ";
	
	if(!defined($fillPolygon))
	{
		$fillOption .= "none";
	}
	else
	{
		$fillOption .= "'rgba($fillPolygon->[0],$fillPolygon->[1],$fillPolygon->[2],$fillPolygon->[3])'";
	}
	
	my $poly = ($close ? "polygon" : "polyline");
	
	my $commandToRun = "$self->{MOGRIFY} $borderOption $fillOption -draw '$poly $corners' '$self->{workingImage}' 2>&1";
	
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;

	if($exitStatus != 0)
	{
		print STDERR "Cannot draw polygon on image '$self->{inFile}':\n$returnCommand\n";
		return(0);
	}	
	
	$self->{hasChanged}++;
	return(1);
}

sub drawPoint
{
	my ($self, $point, $color, $width) = @_;
	
	$self->createWorkingImage();
	
	my $fillOption = "-fill 'rgba($color->[0],$color->[1],$color->[2],$color->[3])'";
	my $commandToRun = "$self->{MOGRIFY} $fillOption -draw ";
	
	my $rad = floor(sqrt(2)*$width/4);
	
	if($rad > 0)
	{
		my $bottomx = $point->[0] + $rad;
		my $bottomy = $point->[1] + $rad;
		
		$commandToRun .= "'circle $point->[0],$point->[1] $bottomx,$bottomy'";
	}
	else
	{
		$commandToRun .= "'point $point->[0],$point->[1]'";
	}
	
	$commandToRun .= " '$self->{workingImage}' 2>&1";
	
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;

	if($exitStatus != 0)
	{
		print STDERR "Cannot draw point on image '$self->{inFile}':\n$returnCommand\n";
		return(0);
	}
	
	$self->{hasChanged}++;
	return(1);
}

sub drawLabel
## Point is the bottom-left point
{
	my ($self, $label, $point) = @_;
	
	$self->createWorkingImage();
	
	my $commandToRun = "$self->{MOGRIFY} -font '$self->{FONT}' -fill white -undercolor '#00000080' -annotate +$point->[0]+$point->[1] ' $label ' '$self->{workingImage}' 2>&1";
	
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;

	if($exitStatus != 0)
	{
		print STDERR "Cannot inprint label on image '$self->{inFile}':\n$returnCommand\n";
		return(0);
	}
	
	$self->{hasChanged}++;
	return(1);
}

sub drawEllipse
# $fillEllipse and $borderColor is [R, G, B, alpha] R,G, and B in 255 alpha in 1.0
{
	my ($self, $centerPoint, $radii, $rotation, $startToEndAngles, $borderColor, $borderWidth, $fillEllipse) = @_;
	
	$self->createWorkingImage();
	
	my $borderOption = "-stroke 'rgba($borderColor->[0],$borderColor->[1],$borderColor->[2],$borderColor->[3])' -strokewidth $borderWidth";
	my $fillOption = "-fill ";
	my $commandToRun = "$self->{MOGRIFY} $fillOption -draw ";
	
	if(!defined($fillEllipse))
	{
		$fillOption .= "none";
	}
	else
	{
		$fillOption .= "'rgba($fillEllipse->[0],$fillEllipse->[1],$fillEllipse->[2],$fillEllipse->[3])'";
	}
	
	$commandToRun .= "'translate $centerPoint->[0],$centerPoint->[1]' rotate $rotation ellipse 0,0 $radii->[0],$radii->[1] $startToEndAngles->[0],$startToEndAngles->[1]'";
	$commandToRun .= " '$self->{workingImage}' 2>&1";
	
	my $returnCommand = qx($commandToRun);
	my $exitStatus = $? >> 8;

	if($exitStatus != 0)
	{
		print STDERR "Cannot draw point on image '$self->{inFile}':\n$returnCommand\n";
		return(0);
	}
	
	$self->{hasChanged}++;
	return(1);
}

1;
