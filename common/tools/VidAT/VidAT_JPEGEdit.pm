# VidAT_JPEGEdit.pm
#
# $Id$
#
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by employees of the Federal 
# Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this 
# software is not subject to copyright protection within the United States and is in the public domain. 
# 
# It is an experimental system.  
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY 
# MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

package VidAT_JPEGEdit;

use strict;
use warnings;
use File::Temp qw( tempfile );
use POSIX qw( ceil floor );

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

=pod

=item B<clean>()

Cleanup all the remaining temporary files.

=cut

sub clean
{
	my ($self) = @_;
	$self->deleteWorkingImage();
}

=pod

=item B<createWorkingImage>()

Create the file that will be used for frame editing. Using the ImageMagick format.

=cut

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

=pod

=item B<deleteWorkingImage>()

Delete the working image.

=cut

sub deleteWorkingImage
{
	my ($self) = @_;
	unlink($self->{workingImage}) if(defined($self->{workingImage}));
}

=pod

=item B<duplicateInputImage>(I<$outFile>)

Duplicate the image into I<$outFile> file.

=cut

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

=pod

=item B<jpeg>(I<$outFile>)

Convert the working image into I<$outFile> as JPEG.

=cut

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

=pod

=item B<drawPolygon>(I<$polygonCorners>, I<$borderColor>, I<$borderWidth>, I<$fillPolygon>, I<$close>)

Draw a polygon in the working image using the I<$polygonCorners> as corner points, I<$borderColor> the color for the 
border, I<$borderWidth> as a pixel size of the border, I<$fillPolygon> as the color to fill the polygon, and I<$close> 
as a boolean to define is the polygon is closed or not.

I<$polygonCorners> is a list of corner coordinates
[ x1, y1, x2, y2, x3, y3, ... ] where the corners are (x1, y1) , (x2, y2), (x3, y3). The number of elements if 
I<$polygonCorners> must be even.

I<$borderColor> is a array of RGB, alpha. RGB codes must be between 0 and 255 and alpha transparency is a floating point
value between 0 and 1.

I<$borderWidth> is a integer for the size of the border.

I<$fillPolygon> is a array RGB, alpha following the same convension than I<$borderColor>.

A closed polygon, link the last corner to the first one.

=cut

sub drawPolygon
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

=pod

=item B<drawPoint>(I<$point>, I<$color>, I<$width>)

Draw a point at the coordinates defined in I<$point> with the color I<$color> and the size I<$width>.

I<$point> is a pair of coordinates [ x, y ] .

I<$color> is a array of RGB, alpha. RGB codes must be between 0 and 255 and alpha transparency is a floating point
value between 0 and 1.

I<$width> is a integer for the size of the point.

=cut

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

=pod

=item B<drawLabel>(I<$label>, I<$point>)

Draw a test I<$label> at the coordinates defined in I<$point>.

I<$point> is a pair of coordinates [ x, y ].

I<$label> is the text to be displayed.

=cut

sub drawLabel
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

=pod

=item B<drawEllipse>(I<$centerPoint>, I<$radii>, I<$rotation>, I<$startToEndAngles>, I<$borderColor>, I<$borderWidth>, I<$fillEllipse>)

Draw an ellipse at the center point I<$centerPoint> with the two radii I<$radii>, following a main axe rotation of 
I<$rotation>, with the border color of I<$borderColor>, a border size of I<$borderWidth> and filling up the ellipse
with the color I<$fillEllipse>. Only a portion of the ellipse can be drawed be providing the begin and end angle 
I<$startToEndAngles>.

I<$centerPoint> is a pair of coordinates [ x, y ] to the center of the ellipse.

I<$radii> are the two radii of the ellipse.

I<$startToEndAngles> are the two angles in degree.

I<$borderColor> is a array of RGB, alpha. RGB codes must be between 0 and 255 and alpha transparency is a floating point
value between 0 and 1.

I<$borderWidth> is a integer for the size of the border.

I<$fillEllipse> is a array RGB, alpha following the same convension than I<$borderColor>.

I<$rotation> is the angle in degree of the ellipse rotation based on its center point.

=cut

sub drawEllipse
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
