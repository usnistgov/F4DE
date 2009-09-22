# VidAT
# VideoEdit.pm
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

package VideoEdit;

use strict;
use warnings;
use File::Temp qw( tempdir );
use File::Path qw( rmtree );
use JPEGEdit;
use FFmpegImage;

sub new
{
	my ($class) = @_;
	my $self =
	{
		videoFile    => undef,
		filterFile   => undef,
		filterLoaded => 0,
		tempDir1     => undef,
		tempDir2     => undef,
		filter       => {},
		outputFrames => undef,
		minFrame     => 9e99,
		maxFrame     => 0,
	};
	
	bless $self;
	
	return $self;
}

sub loadVideoFile
{
	my ($self, $videoFile) = @_;
	
	$self->{videoFile} = $videoFile;
	$self->extractJpegs();
}

sub clean
{
	my ($self) = @_;
	rmtree($self->{tempDir1}) if(defined($self->{tempDir1}));
	rmtree($self->{tempDir2}) if(defined($self->{tempDir2}));
}

sub extractJpegs
{
	my ($self) = @_;
	
	$self->{tempDir1} = tempdir( CLEANUP => 1 );
	$self->{images} = new FFmpegImage($self->{videoFile});
	$self->{images}->extractJpeg($self->{tempDir1});
}

sub buildVideo
{
	my ($self, $outFile) = @_;
	
	# at the end, check if the outframes created something
	if(!defined($self->{outputFrames}{keep}))
	{
		push( @{ $self->{outputFrames}{keep} }, [(1, 9e99)] );
		$self->{minFrame} = 1;
		$self->{maxFrame} = 9e99;
	}
	
	if(defined($self->{videoFile}) && $self->{filterLoaded})
	{
		# Create tempdir
		$self->{tempDir2} = tempdir( CLEANUP => 1 );
		$self->processImages();
		$self->{images}->buildVideo($self->{tempDir2}, $outFile);
	}
	else
	{
		$self->{images}->buildVideo($self->{tempDir1}, $outFile);
	}
}

sub buildJpegSingle
{
	my ($self, $frameId, $outFile) = @_;
	
	$self->processSingleImage($frameId, $outFile);
}

sub doKeep
{
	my ($self, $id) = @_;
	
	my $keep = 0;
	
	#  check in the list of keep if we keep it
	for(my $i=0; ($i<scalar(@{ $self->{outputFrames}{keep} }) && !$keep); $i++)
	{
		$keep = 1 if( ($self->{outputFrames}{keep}[$i][0] <= $id) && ($id <= $self->{outputFrames}{keep}[$i][1]) );
	}
	
	# if we keep it, check the list of unkeep
	if($keep && defined($self->{outputFrames}{notkeep}))
	{
		for(my $i=0; ($i<scalar(@{ $self->{outputFrames}{notkeep} }) && $keep); $i++)
		{
			$keep = 0 if( ($self->{outputFrames}{notkeep}[$i][0] <= $id) && ($id <= $self->{outputFrames}{notkeep}[$i][1]) );
		}
	}
	
	return $keep;
}

sub doDuplicate
{
	my ($self, $id) = @_;
	
	my $c = 0;
	
	if(defined($self->{outputFrames}{duplicate}))
	{
		if(defined($self->{outputFrames}{duplicate}{$id}))
		{
			$c = $self->{outputFrames}{duplicate}{$id};
		}
	}
	
	return $c;
}

sub hasFilters
{
	my ($self, $id) = @_;
	
	my @outPolygon;
	my @outPoint;
	my @outLabel;
	my @outEllipses;
	
	foreach my $bt (keys %{ $self->{filter} })
	{
		if($bt <= $id)
		{
			foreach my $et (keys %{ $self->{filter}{$bt} })
			{
				if($id <= $et)
				{
					foreach my $elt (@{ $self->{filter}{$bt}{$et} })
					{
						push(@outPolygon, $elt) if($elt->{TYPE} eq "polygon");
						push(@outEllipses, $elt) if($elt->{TYPE} eq "ellipse");
						push(@outPoint, $elt) if($elt->{TYPE} eq "point");
						push(@outLabel, $elt) if($elt->{TYPE} eq "label");
					}
				}
			}
		}
	}
	
	my $nbPoly = scalar(@outPolygon);
	my $nbEllip = scalar(@outEllipses);
	my $nbPt = scalar(@outPoint);
	my $nbLbl = scalar(@outLabel);
	print "Frame '$id' - POLY:$nbPoly ELLIP:$nbEllip PTS:$nbPt LBL:$nbLbl\r";
	
	return(\@outPolygon, \@outEllipses, \@outPoint, \@outLabel);
}

sub processSingleImage
{
	my ($self, $index, $outJpeg) = @_;
	
	opendir(DIR, $self->{tempDir1});
	my @files = grep { /^\d+\.jpeg$/ } readdir(DIR);
	closedir(DIR);
	
	if( ($index >= $self->{minFrame}) &&
		($index <= $self->{maxFrame}) &&
		($self->doKeep($index)) )
	{
		my $jpeg = new JPEGEdit("$self->{tempDir1}/$files[$index]");
		
		# Apply all the filters
		my ($polygons, $ellipses, $points, $labels) = $self->hasFilters($index);
		
		# polygons
		for(my $j=0; $j<scalar(@$polygons); $j++)
		{	
			$jpeg->drawPolygon($polygons->[$j]->{COORD}, 
			                   $polygons->[$j]->{BORDERCOLOR}, 
			                   $polygons->[$j]->{WIDTH}, 
			                   $polygons->[$j]->{FILLCOLOR},
			                   $polygons->[$j]->{CLOSE});
		}
		
		# ellipses
		for(my $j=0; $j<scalar(@$ellipses); $j++)
		{
		   my @center = ($points->[$j]->{X}, $points->[$j]->{Y});	
		   $jpeg->drawEllipse(\@center, 
		   					  $ellipses->[$j]->{RADII}, 
		   					  $ellipses->[$j]->{ROTATION}, 
		   					  $ellipses->[$j]->{ANGLES}, 
		   					  $ellipses->[$j]->{BORDERCOLOR}, 
			                  $ellipses->[$j]->{WIDTH}, 
			                  $ellipses->[$j]->{FILLCOLOR});
		}
		
		# points
		for(my $j=0; $j<scalar(@$points); $j++)
		{
		   my @coord = ($points->[$j]->{X}, $points->[$j]->{Y});	
		   $jpeg->drawPoint(\@coord, $points->[$j]->{COLOR}, $points->[$j]->{WIDTH});
		}
		
		# labels
		for(my $j=0; $j<scalar(@$labels); $j++)
		{
			my @coord = ($labels->[$j]->{X}, $labels->[$j]->{Y});
			$jpeg->drawLabel($labels->[$j]->{TEXT}, \@coord);
		}
		
		$jpeg->jpeg($outJpeg);
		$jpeg->clean();
	}
}

sub processImages
{
	my ($self) = @_;
	
	my $ind = 1;
	opendir(DIR, $self->{tempDir1});
	my @files = grep { /^\d+\.jpeg$/ } readdir(DIR);
	closedir(DIR);
	
	for(my $i=1; $i<=scalar(@files); $i++)
	{
		next if($i < $self->{minFrame});
		next if($i > $self->{maxFrame});
		next if(! $self->doKeep($i));

		my $jpeg = new JPEGEdit("$self->{tempDir1}/$files[$i]");
		
		# Apply all the filters
		my ($polygons, $ellipses, $points, $labels) = $self->hasFilters($i);
		
		# polygons
		for(my $j=0; $j<scalar(@$polygons); $j++)
		{	
			$jpeg->drawPolygon($polygons->[$j]->{COORD}, 
			                   $polygons->[$j]->{BORDERCOLOR}, 
			                   $polygons->[$j]->{WIDTH}, 
			                   $polygons->[$j]->{FILLCOLOR},
			                   $polygons->[$j]->{CLOSE});
		}
		
		# ellipses
		for(my $j=0; $j<scalar(@$ellipses); $j++)
		{
		   my @center = ($points->[$j]->{X}, $points->[$j]->{Y});	
		   $jpeg->drawEllipse(\@center, 
		   					  $ellipses->[$j]->{RADII}, 
		   					  $ellipses->[$j]->{ROTATION}, 
		   					  $ellipses->[$j]->{ANGLES}, 
		   					  $ellipses->[$j]->{BORDERCOLOR}, 
			                  $ellipses->[$j]->{WIDTH}, 
			                  $ellipses->[$j]->{FILLCOLOR});
		}
		
		# points
		for(my $j=0; $j<scalar(@$points); $j++)
		{
		   my @coord = ($points->[$j]->{X}, $points->[$j]->{Y});	
		   $jpeg->drawPoint(\@coord, $points->[$j]->{COLOR}, $points->[$j]->{WIDTH});
		}
		
		# labels
		for(my $j=0; $j<scalar(@$labels); $j++)
		{
			my @coord = ($labels->[$j]->{X}, $labels->[$j]->{Y});
			$jpeg->drawLabel($labels->[$j]->{TEXT}, \@coord);
		}
	
		# Duplicates
		my $nbrcopy = 1 + $self->doDuplicate($i);
	
		for(my $k=0; $k<$nbrcopy; $k++)
		{
			my $strout = sprintf("%s/%09d.jpeg", $self->{tempDir2}, $ind);
			$jpeg->jpeg($strout);
			$ind++;
		}
	
		$jpeg->clean();
	}
}

sub addKeepRange
{
	my ($self, $begf, $endf) = @_;
	
	push( @{ $self->{outputFrames}{keep} }, [($begf, $endf)] );				
	$self->{minFrame} = min($self->{minFrame}, $begf);
	$self->{maxFrame} = max($self->{maxFrame}, $endf);
	$self->{filterLoaded} = 1;
}

sub addNotKeepRange
{
	my ($self, $begf, $endf) = @_;
	
	push( @{ $self->{outputFrames}{notkeep} }, [($begf, $endf)] );
	$self->{filterLoaded} = 1;
}

sub addDuplicate
{
	my ($self, $frm, $count) = @_;
	
	$self->{outputFrames}{duplicate}{$frm} = $count;
	$self->{filterLoaded} = 1;
}

sub loadXMLFile
{
	my ($self, $filterFile) = @_;
	
	autoflush STDOUT;
	print "Loading XML file '$filterFile'...\n";
	
	my $nbLoaded = 0;
	
	$self->{filterFile} = $filterFile;
	
	open(INFILE, "<", $self->{filterFile}) or die "$!";
	
	my $str = "";
	
	while(<INFILE>)
	{
		chomp;
		s/^\s+//;
		s/\s+$//;
		$str .= "$_";
	}
	
	close(INFILE);
	
	$str =~ s/<\?.+?\?>//;
	$str =~ s/<\!--.+?-->//;
	
	# if output_frames keep not specified, then the full lengh is used
	# if the output_frames is given, then it will keep only what it is asked
	# for.
	if($str =~ s/<output_frames>(.+?)<\/output_frames>//)
	{
		my $frameList = $1;
		
		while($frameList =~ s/<frames (.+?)\/>//)
		{
			my $f = parseAttributes($1);
			
			if(defined($f->{keep}))
			{
				if($f->{keep})
				{
					$self->addKeepRange($f->{begin}, $f->{end});
					$nbLoaded++;
					print "  Ranges loaded: $nbLoaded\r" ;
				}
				else
				{
					$self->addNotKeepRange($f->{begin}, $f->{end});
					$nbLoaded++;
					print "  Ranges loaded: $nbLoaded\r" ;
				}
			}
			
			if(defined($f->{duplicate}))
			{
				if($f->{duplicate} > 0)
				{
					for(my $i=$f->{begin}; $i<=$f->{end}; $i++)
					{
						$self->addDuplicate($i, $f->{duplicate});
						$nbLoaded++;
						print "  Ranges loaded: $nbLoaded\r" ;
					}
				}
			}
		}
	}
	
	print "  Ranges loaded: $nbLoaded\n";
	$nbLoaded = 0;
	
	# Points
	while($str =~ s/<point>(.+?)<\/point>//)
	{
		$self->parsePoint($1);
		$nbLoaded++;
		print "  Points loaded: $nbLoaded\r" ;
	}
	
	print "  Points loaded: $nbLoaded\n";
	$nbLoaded = 0;
	
	# Labels
	while($str =~ s/<label>(.+?)<\/label>//)
	{
		$self->parseLabel($1);
		$nbLoaded++;
		print "  Labels loaded: $nbLoaded\r" ;
	}
	
	print "  Labels loaded: $nbLoaded\n";
	$nbLoaded = 0;
	
	# Polygons
	while($str =~ s/<polygon>(.+?)<\/polygon>//)
	{
		$self->parsePolygon($1);
		$nbLoaded++;
		print "  Polygons loaded: $nbLoaded\r" ;
	}
	
	print "  Polygons loaded: $nbLoaded\n";
	
	# at the end, check if the outframes created something
	if(!defined($self->{outputFrames}{keep}))
	{
		push( @{ $self->{outputFrames}{keep} }, [(1, 9e99)] );
		$self->{minFrame} = 1;
		$self->{maxFrame} = 9e99;
	}
}

sub parseAttributes
{
	my ($string) = @_;
	
	my $tmpstr = $string;
	my %out;
	
	while($tmpstr =~ s/([a-zA-Z0-9_]+)=[\'\"]([a-zA-Z0-9_,\.]+)[\'\"]//)
	{
		$out{$1} = $2;
	}
	
	return \%out;
}

sub saveXMLFile
{
	my ($self, $filterFile) = @_;
	
	my $strFile = "";
	
	$strFile = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\n";
	
	## Keep, unkeep and duplicate
	if(defined($self->{outputFrames}))
	{
		$strFile .= "<output_frames>\n";
		
		if(defined($self->{outputFrames}{keep}))
		{
			for(my $i=0; $i<scalar(@{ $self->{outputFrames}{keep} }); $i++)
			{
				$strFile .= "\t<frames begin=\"$self->{outputFrames}{keep}->[$i][0]\" end=\"$self->{outputFrames}{keep}->[$i][1]\" keep=\"1\" />\n";
			}
		}
				
		if(defined($self->{outputFrames}{notkeep}))
		{
			for(my $i=0; $i<scalar(@{ $self->{outputFrames}{notkeep} }); $i++)
			{
				$strFile .= "\t<frames begin=\"$self->{outputFrames}{notkeep}->[$i][0]\" end=\"$self->{outputFrames}{notkeep}->[$i][1]\" keep=\"0\" />\n";
			}
		}
		
		if(defined($self->{outputFrames}{duplicate}))
		{
			if(defined($self->{outputFrames}{duplicate}))
			{
				foreach my $frm (keys %{ $self->{outputFrames}{duplicate} })
				{
					$strFile .= "\t<frames begin=\"$frm\" end=\"$frm\" keep=\"1\" duplicate=\"$self->{outputFrames}{duplicate}{$frm}\" />\n";
				}
			}
		}
		
		$strFile .= "</output_frames>\n";
	}
	##
	
	foreach my $begf (keys %{ $self->{filter} })
	{
		foreach my $endf (keys %{ $self->{filter}{$begf} })
		{
			for(my $i=0; $i<scalar(@{ $self->{filter}{$begf}{$endf} }); $i++)
			{
				my $type = $self->{filter}{$begf}{$endf}[$i]->{TYPE};
				
				if($type eq "point")
				{
					$strFile .= "<point>\n";
					$strFile .= "\t<frames begin=\"$begf\" end=\"$endf\" />\n";
					$strFile .= "\t<coordinate x=\"$self->{filter}{$begf}{$endf}[$i]->{X}\" y=\"$self->{filter}{$begf}{$endf}[$i]->{Y}\" />\n";
					$strFile .= "\t<border width=\"$self->{filter}{$begf}{$endf}[$i]->{WIDTH}\" color=\"". join(',', @{ $self->{filter}{$begf}{$endf}[$i]->{COLOR} }) . "\" />\n";
					$strFile .= "</point>\n";
				}
				elsif($type eq "label")
				{
					$strFile .= "<label>\n";
					$strFile .= "\t<frames begin=\"$begf\" end=\"$endf\" />\n";
					$strFile .= "\t<coordinate x=\"$self->{filter}{$begf}{$endf}[$i]->{X}\" y=\"$self->{filter}{$begf}{$endf}[$i]->{Y}\" />\n";
					
					my $text = $self->{filter}{$begf}{$endf}[$i]->{TEXT};
					$text =~ s/\</&lt;/g;
					$text =~ s/\>/&gt;/g;
					$text =~ s/\&/&amp;/g;
					$text =~ s/\'/&apos;/g;
					$text =~ s/\"/&quot;/g; 					
					
					$strFile .= "\t<text>$text</text>\n";
					$strFile .= "</label>\n";
				}
				elsif($type eq "polygon")
				{
					$strFile .= "<polygon>\n";
					$strFile .= "\t<frames begin=\"$begf\" end=\"$endf\" />\n";
					$strFile .= "\t<corners close=\"$self->{filter}{$begf}{$endf}[$i]->{CLOSE}\">\n";
					
					for(my $j=0; $j<scalar( @{ $self->{filter}{$begf}{$endf}[$i]->{COORD} } ); $j += 2)
					{
					
						$strFile .= "\t\t<coordinate x=\"$self->{filter}{$begf}{$endf}[$i]->{COORD}[$j]\" y=\"$self->{filter}{$begf}{$endf}[$i]->{COORD}[$j+1]\" />\n";
					}
					
					$strFile .= "\t</corners>\n";
					$strFile .= "\t<border width=\"$self->{filter}{$begf}{$endf}[$i]->{WIDTH}\" color=\"". join(',', @{ $self->{filter}{$begf}{$endf}[$i]->{BORDERCOLOR} }) . "\" />\n";
					$strFile .= "\t<fill color=\"". join(',', @{ $self->{filter}{$begf}{$endf}[$i]->{FILLCOLOR} }) . "\" />\n";
					$strFile .= "</polygon>\n";
				}
				else
				{
					print STDERR "unknown type: '$type'\n";
				}
			}
		}
	}
	
	if(defined($filterFile))
	{
		open(OUT, ">", $filterFile) or die "$!";
		print OUT "$strFile";
		close(OUT);
	}
	else
	{
		return($strFile);
	}
}

sub addLabel
{
	my ($self, $bf, $ef, $text, $coord) = @_;
	
	my %object;
	$object{TYPE} = "label";
	$object{BEGT} = $bf;
	$object{ENDT} = $ef;
	$object{X} = $coord->[0];
	$object{Y} = $coord->[1];
	$object{TEXT} = $text;
	push(@{ $self->{filter}{$object{BEGT}}{$object{ENDT}} }, \%object);
	$self->{filterLoaded} = 1;
}

sub parseLabel
{
	my ($self, $str) = @_;
	
	my %object;
	
	my $s = $str;
	my ($b, $e) = (1, 9e99);
	my @coord = (0, 0);
	my $text = "";
	
	if($s =~ s/<frames (.+?)\/>//)
	{
		my $f = parseAttributes($1);		
		$b = $f->{begin};
		$e = $f->{end};
	}

	if($s =~ s/<coordinate (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		$coord[0] = $f->{x};
		$coord[1] = $f->{y};
	}
	
	if($s =~ s/<text>(.+?)<\/text>//)
	{
		$text = $1;
		$text =~ s/&lt;/</g;
		$text =~ s/&gt;/>/g;
		$text =~ s/&amp;/&/g;
		$text =~ s/&apos;/'/g;
		$text =~ s/&quot;/"/g;
	}
	
	$self->addLabel($b, $e, $text, \@coord);
}

sub addPoint
{
	my ($self, $bf, $ef, $coord, $width, $color) = @_;
	
	my %object;
	$object{TYPE} = "point";
	$object{BEGT} = $bf;
	$object{ENDT} = $ef;
	$object{X} = $coord->[0];
	$object{Y} = $coord->[1];
	$object{WIDTH} = $width;
	$object{COLOR} = [($color->[0],$color->[1],$color->[2],$color->[3])];
	push(@{ $self->{filter}{$object{BEGT}}{$object{ENDT}} }, \%object);
	$self->{filterLoaded} = 1;
}

sub parsePoint
{
	my ($self, $str) = @_;
	
	my %object;
	
	my $s = $str;
	my ($b, $e) = (1, 9e99);
	my @coord = (0, 0);
	my $width = 1;
	my @color = (0,0,0,1);
	
	if($s =~ s/<frames (.+?)\/>//)
	{
		my $f = parseAttributes($1);		
		$b = $f->{begin};
		$e = $f->{end};
	}

	if($s =~ s/<coordinate (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		$coord[0] = $f->{x};
		$coord[1] = $f->{y};
	}
	
	if($s =~ s/<border (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		$width = $f->{width};
		@color = ();
		push(@color, split(/,/, $f->{color}) );
	}
	
	$self->addPoint($b, $e, \@coord, $width, \@color);
}

sub addPolygon
{
	my ($self, $bf, $ef, $coord, $width, $colorfill, $colorborder, $close) = @_;
	
	my %object;
	$object{TYPE} = "polygon";
	$object{BEGT} = $bf;
	$object{ENDT} = $ef;
	$object{WIDTH} = $width;
	$object{BORDERCOLOR} = [($colorborder->[0],$colorborder->[1],$colorborder->[2],$colorborder->[3])];
	$object{FILLCOLOR} = [($colorfill->[0],$colorfill->[1],$colorfill->[2],$colorfill->[3])];
	$object{CLOSE} = $close;
	
	for(my $i=0; $i<scalar(@$coord); $i++)
	{
		push(@{$object{COORD}}, $coord->[$i]);
	}
	
	if(scalar(@$coord) == 2)
	{
		for(my $i=0; $i<scalar(@$coord); $i++)
		{
			push(@{$object{COORD}}, $coord->[$i]);
		}
	}
	
	push(@{ $self->{filter}{$object{BEGT}}{$object{ENDT}} }, \%object);
	$self->{filterLoaded} = 1;
}

sub parsePolygon
{
	my ($self, $str) = @_;
	
	my $s = $str;
	my ($b, $e) = (1, 9e99);
	my @coord;
	my $width = 1;
	my @fillcolor = (0,0,0,0);
	my @bordercolor = (0,0,0,1);
	my $close = 1;
	
	if($s =~ s/<frames (.+?)\/>//)
	{
		my $f = parseAttributes($1);		
		$b = $f->{begin};
		$e = $f->{end};
	}
	
	if($s =~ s/<corners(.+?)>(.+?)<\/corners>//)
	{
		my $f = parseAttributes($1);
		
		if(defined($f->{close}))
		{
			$close = $f->{close};
		}
		
		my $t = $2;
		
		while($t =~ s/<coordinate (.+?)\/>//)
		{
			my $f = parseAttributes($1);
			push(@coord, $f->{x});
			push(@coord, $f->{y});
		}
	}
	
	if($s =~ s/<border (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		$width = $f->{width};
		@bordercolor = ();
		push(@bordercolor, split(/,/, $f->{color}) );
	}
	
	if($s =~ s/<fill (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		@fillcolor = ();
		push(@fillcolor, split(/,/, $f->{color}) );
	}
	
	$self->addPolygon($b, $e, \@coord, $width, \@fillcolor, \@bordercolor, $close);
}

sub parseEllipse
{
	my ($self, $str) = @_;
	
	my $s = $str;
	my ($b, $e) = (1, 9e99);
	my @center;
	my @radii;
	my @angles = (0, 360);
	my $rotation = 0;
	my $width = 1;
	my @fillcolor = (0,0,0,0);
	my @bordercolor = (0,0,0,1);

	if($s =~ s/<frames (.+?)\/>//)
	{
		my $f = parseAttributes($1);		
		$b = $f->{begin};
		$e = $f->{end};
	}

	if($s =~ s/<center (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		$center[0] = $f->{x};
		$center[1] = $f->{y};
	}
	
	if($s =~ s/<radii (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		$radii[0] = $f->{a};
		$radii[1] = $f->{b};
	}

	if($s =~ s/<rotation (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		$rotation = $f->{angle};
	}
	
	if($s =~ s/<border (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		$width = $f->{width};
		@bordercolor = ();
		push(@bordercolor, split(/,/, $f->{color}) );
	}
	
	if($s =~ s/<fill (.+?)\/>//)
	{
		my $f = parseAttributes($1);
		@fillcolor = ();
		push(@fillcolor, split(/,/, $f->{color}) );
	}
	
	if($s =~ s/<angles (.+?)\/>//)
	{
		my $f = parseAttributes($1);		
		$angles[0] = $f->{begin};
		$angles[1] = $f->{end};
	}
	
	$self->addEllipse($b, $e, \@center, \@radii, $rotation, $width, \@fillcolor, \@bordercolor, \@angles);
}

sub addEllipse
{
	my ($self, $bf, $ef, $center, $radii, $rotation, $width, $colorfill, $colorborder, $angles) = @_;
	
	my %object;
	$object{TYPE} = "ellipse";
	$object{BEGT} = $bf;
	$object{ENDT} = $ef;
	$object{X} = $center->[0];
	$object{Y} = $center->[1];
	$object{RADII} = [($radii->[0],$radii->[1])];
	$object{ANGLES} = [($angles->[0],$angles->[1])];
	$object{WIDTH} = $width;
	$object{ROTATION} = $rotation;
	$object{BORDERCOLOR} = [($colorborder->[0],$colorborder->[1],$colorborder->[2],$colorborder->[3])];
	$object{FILLCOLOR} = [($colorfill->[0],$colorfill->[1],$colorfill->[2],$colorfill->[3])];
	push(@{ $self->{filter}{$object{BEGT}}{$object{ENDT}} }, \%object);
	$self->{filterLoaded} = 1;
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

1;
