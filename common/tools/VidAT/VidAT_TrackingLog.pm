# VidAT
# tackinglog.pm
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

package trackinglog;

use strict;
use warnings;
use VideoEdit;
use Data::Dumper;

1;

sub new
{
	my ($class, $inFile, $rmin, $rmax) = @_;
	
	my $self =
	{
		inFile         => $inFile,
		appears        => undef,
		minFrame  => undef,
		maxFrame  => undef,
		frames    => undef,
		polygon   => undef,
		videoClass => undef,
		color_uref => [(251,16,15,0.8)],
		color_usys => [(255,165,0,0.8)],
		color_mref => [(28,6,253,0.8)],
		color_msys => [(54,203,53,0.8)],
		color_dcob => [(255,255,0,0.8)],
		color_clear => [(0, 0, 0, 0)],
		restrictMin => 0,
		restrictMax => 999999,
	};
	
	bless $self;
	
	if(defined($rmin) && defined($rmax))
	{
		$self->{restrictMin} = $rmin;
		$self->{restrictMax} = $rmax;
	}
	
	$self->{videoClass} = new VideoEdit();
	$self->loadFile();
	$self->process();
	
	return $self;
}

sub loadFile
{
	my ($self) = @_;
	
	open(FILE, "<", $self->{inFile}) or die "$!";
	
	my $frame = undef;
	
	while(<FILE>)
	{
		chomp;
		my $line = $_;
			
		if($line =~ /Evaluated Frame: (\d+)/)
		{
			$frame = int($1);
			$self->{minFrame} = $frame if(!defined($self->{minFrame}));
			$self->{maxFrame} = $frame;
			push( @{ $self->{frames} }, $frame);
		}
		
		if(defined($frame))
		{
			next if( ($frame < $self->{restrictMin}) || ($frame > $self->{restrictMax}) );
		}
		
		if($line =~ /REF (\d+) \[x=(\d+) y=(\d+) w=(\d+) h=(\d+) o=(\d+)\]/)
		{
			my $id = int($1);
			my @tl = ($2, $3);
			my @tr = ($2+$4, $3);
			my @bl = ($2, $3+$5);
			my @br = ($2+$4, $3+$5);
			my $deg = $6;
			my @c = (($tl[0]+$br[0])/2, ($tl[1]+$br[1])/2);
			@tl = rotation(@tl, @c, $6);
			@tr = rotation(@tr, @c, $6);
			@bl = rotation(@bl, @c, $6);
			@br = rotation(@br, @c, $6);
			
			my $DCO = 0;
			$DCO = 1 if($line =~ /DCO/);
			
			$self->{polygon}{ref}{$id}{$frame}{DCO} = $DCO;
			$self->{polygon}{ref}{$id}{$frame}{MAPPED} = 0;
			push( @{ $self->{polygon}{ref}{$id}{$frame}{COORD} }, @tl, @tr, @br, @bl);
			
			$self->{appears}{ref}{$id}{$frame}{REAL} = 1;
		}
		
		if($line =~ /SYS (\d+) \[x=(\d+) y=(\d+) w=(\d+) h=(\d+) o=(\d+)\]/)
		{
			my $id = int($1);
			my @tl = ($2, $3);
			my @tr = ($2+$4, $3);
			my @bl = ($2, $3+$5);
			my @br = ($2+$4, $3+$5);
			my $deg = $6;
			my @c = (($tl[0]+$br[0])/2, ($tl[1]+$br[1])/2);
			@tl = rotation(@tl, @c, $6);
			@tr = rotation(@tr, @c, $6);
			@bl = rotation(@bl, @c, $6);
			@br = rotation(@br, @c, $6);
			
			my $DCO = 0;
			$DCO = 1 if($line =~ /DCO/);
			
			$self->{polygon}{sys}{$id}{$frame}{DCO} = $DCO;
			$self->{polygon}{sys}{$id}{$frame}{MAPPED} = 0;
			push( @{ $self->{polygon}{sys}{$id}{$frame}{COORD} }, @tl, @tr, @br, @bl);
			
			$self->{appears}{sys}{$id}{$frame}{REAL} = 1;
		}
		
		if($line =~ /Mapped : SYS (\d+) -> REF (\d+)/)
		{
			my $sysId = int($1);
			my $refId = int($2);
		
			$self->{mapped}{sys}{$sysId}{$frame} = $refId;
			$self->{mapped}{ref}{$refId}{$frame} = $sysId;
			$self->{polygon}{ref}{$refId}{$frame}{MAPPED} = 1;
			$self->{polygon}{sys}{$sysId}{$frame}{MAPPED} = 1;
		}
	}
	
	close(FILE);
	
	$self->buildContiniousFrames();
}

sub rotation
{
	my ($x, $y, $cx, $cy, $deg) = @_;
	
	return( int(($x-$cx)*cos($deg)+($y-$cy)*sin($deg) + $cx), int(-($x-$cx)*sin($deg)+($y-$cy)*cos($deg)+$cy) );
}

sub buildContiniousFrames
{
	my ($self) = @_;
	
	my @listframes = sort {$a <=> $b} @{ $self->{frames} };
	
	foreach my $id (keys %{ $self->{appears}{ref} })
	{
		for(my $i=1; $i<scalar(@listframes); $i++)
		{
			if( (exists($self->{appears}{ref}{$id}{$listframes[$i]})) &&
			    (exists($self->{appears}{ref}{$id}{$listframes[$i-1]})) )
			{
				for(my $j=$listframes[$i-1]+1; $j<=$listframes[$i]-1; $j++)
				{
					$self->{appears}{ref}{$id}{$j}{REAL} = 0;
				}
			}
		}
	}
	
	foreach my $id (keys %{ $self->{appears}{sys} })
	{
		for(my $i=1; $i<scalar(@listframes); $i++)
		{
			if( (exists($self->{appears}{sys}{$id}{$listframes[$i]})) &&
			    (exists($self->{appears}{sys}{$id}{$listframes[$i-1]})) )
			{
				for(my $j=$listframes[$i-1]+1; $j<=$listframes[$i]-1; $j++)
				{
					$self->{appears}{sys}{$id}{$j}{REAL} = 0;
				}
			}
		}
	}
}

sub process
{
	my ($self) = @_;
	
	foreach my $refId (keys %{ $self->{polygon}{ref} })
	{
		$self->processTypeId("ref", $refId);
	}
	
	foreach my $sysId (keys %{ $self->{polygon}{sys} })
	{
		$self->processTypeId("sys", $sysId);
	}	
}

sub processTypeId
{
	my ($self, $type, $id) = @_;
	
	my @listRealFrames = sort {$a <=> $b} keys %{ $self->{polygon}{$type}{$id} };
	my $minFrame = $listRealFrames[0];
	my $maxFrame = $listRealFrames[scalar(@listRealFrames)-1];
	
	# extrapolate polygon
	for(my $i=0; $i<scalar(@listRealFrames)-1; $i++)
	{
		my $currFrame = $listRealFrames[$i];
		my $dco = $self->{polygon}{$type}{$id}{$currFrame}{DCO};
		my $mapped = $self->{polygon}{$type}{$id}{$currFrame}{MAPPED};
		my $mappedId = $self->{mapped}{$type}{$id}{$currFrame};
		my @currCoord = @{ $self->{polygon}{$type}{$id}{$currFrame}{COORD} };
		
		if(exists($self->{appears}{$type}{$id}{$currFrame+1}))
		{
			# a continious frame exists
			# extrapolate the polygon
			my $nextframe = $listRealFrames[$i+1];
			my @nextCoord = @{ $self->{polygon}{$type}{$id}{$nextframe}{COORD} };
			my $length = $nextframe - $currFrame;
			
			for(my $f=$currFrame+1; $f<=$nextframe-1; $f++)
			{
				my $t = ($f-$currFrame)/$length;
				$self->{polygon}{$type}{$id}{$f}{DCO} = $dco;
				$self->{polygon}{$type}{$id}{$f}{MAPPED} = $mapped;
				$self->{mapped}{$type}{$id}{$f} = $mappedId if($mapped);
				
				for(my $c=0; $c<scalar(@currCoord); $c++)
				{
					push( @{ $self->{polygon}{$type}{$id}{$f}{COORD} }, int( (1-$t)*$currCoord[$c] + $t*$nextCoord[$c] ) );
				}
			}
		}
	}
	
	# label
	my @listAppearsFrames = sort {$a <=> $b} keys %{ $self->{polygon}{$type}{$id} };
	
	for(my $i=0; $i<scalar(@listAppearsFrames); $i++)
	{
		my $frm = $listAppearsFrames[$i];
		
		my $label = "";
		
		if($type eq "ref")
		{
			$label .= "R";
		}
		else
		{
			$label .= "S";
		}
		
		$label .= "$id";
		
		if($self->{polygon}{$type}{$id}{$frm}{MAPPED})
		{
			$label .= " > ";
			
			if($type eq "ref")
			{
				$label .= "S";
			}
			else
			{
				$label .= "R";
			}
			
			$label .= "$self->{mapped}{$type}{$id}{$frm}";
		}
		
		$self->{label}{$type}{$id}{$frm}{TEXT} = $label;
		
		push( @{ $self->{label}{$type}{$id}{$frm}{COORD} }, $self->{polygon}{$type}{$id}{$frm}{COORD}[0],
	                                                        $self->{polygon}{$type}{$id}{$frm}{COORD}[1]-5);
	}
	
	# Snail Trail
	
	my $firstFrame = $listAppearsFrames[0];
	my $lastFrame = $listAppearsFrames[scalar(@listAppearsFrames)-1];

	my $prevFrame = $listAppearsFrames[0];
	my $prevDco = $self->{polygon}{$type}{$id}{$prevFrame}{DCO};
	my $prevMapped = $self->{polygon}{$type}{$id}{$prevFrame}{MAPPED};
	
	push( @{ $self->{snail}{$type}{$id}{$prevFrame}{$prevDco}{$prevMapped}{0}{COORD} }, 
	      int( ($self->{polygon}{$type}{$id}{$prevFrame}{COORD}[4]+$self->{polygon}{$type}{$id}{$prevFrame}{COORD}[6])/2 ),
	      int( ($self->{polygon}{$type}{$id}{$prevFrame}{COORD}[5]+$self->{polygon}{$type}{$id}{$prevFrame}{COORD}[7])/2 ) );
	
#	for(my $i=1; $i<scalar(@listAppearsFrames); $i++)
	for(my $frm=$firstFrame+1; $frm<=$lastFrame; $frm++)
	{
#		my $frm = $listAppearsFrames[$i];

		# Add the previous ones
		foreach my $dco (keys %{ $self->{snail}{$type}{$id}{$prevFrame} })
		{
			foreach my $mapped (keys %{ $self->{snail}{$type}{$id}{$prevFrame}{$dco} })
			{
				foreach my $index (keys %{ $self->{snail}{$type}{$id}{$prevFrame}{$dco}{$mapped} })
				{
					push( @{ $self->{snail}{$type}{$id}{$frm}{$dco}{$mapped}{$index}{COORD} },
						  @{ $self->{snail}{$type}{$id}{$prevFrame}{$dco}{$mapped}{$index}{COORD} });
				}
			}
		}
			
		if(exists($self->{polygon}{$type}{$id}{$frm}))
		{
			my @currCoord = @{ $self->{polygon}{$type}{$id}{$frm}{COORD} };
			my $currDco = $self->{polygon}{$type}{$id}{$frm}{DCO};
			my $currMapped = $self->{polygon}{$type}{$id}{$frm}{MAPPED};
			
			my $currIndex = 0;
			
			if(exists($self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped}))
			{
				my @indices = sort {$a <=> $b} keys %{ $self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped} };
				$currIndex = $indices[scalar(@indices)-1];
			}
			
			if( ($currDco == $prevDco) && ($currMapped == $prevMapped) && ($frm-$prevFrame == 1) )
			{
				my @prevCoord = @{ $self->{polygon}{$type}{$id}{$prevFrame}{COORD} };
				
				if( ($currCoord[4] != $prevCoord[4]) ||
					($currCoord[5] != $prevCoord[5]) ||
					($currCoord[6] != $prevCoord[6]) ||
					($currCoord[7] != $prevCoord[7]) )
				{
					push( @{ $self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped}{$currIndex}{COORD} }, 
						  int( ($currCoord[4]+$currCoord[6])/2 ), 
						  int( ($currCoord[5]+$currCoord[7])/2 ) );
				}
			}
			else
			{
				push( @{ $self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped}{$currIndex+1}{COORD} }, 
					  int( ($currCoord[4]+$currCoord[6])/2 ), 
					  int( ($currCoord[5]+$currCoord[7])/2 ) );
			}
			
			$prevDco = $currDco;
			$prevMapped = $currMapped;
			$prevFrame = $frm;
		}
	}
}

sub addRefPolygon
{
	my ($self, $size) = @_;
	
	foreach my $refId (keys %{ $self->{polygon}{ref} })
	{	
		foreach my $frm (keys %{ $self->{polygon}{ref}{$refId} })
		{
			my @coord;
			push(@coord, @{ $self->{polygon}{ref}{$refId}{$frm}{COORD} });
			my $dco = $self->{polygon}{ref}{$refId}{$frm}{DCO};
			my $mapped = $self->{polygon}{ref}{$refId}{$frm}{MAPPED};
			
			my @fill;
			push(@fill, @{ $self->{color_clear} });
			
			if($dco == 1)
			{
				my @border;
				push(@border, @{ $self->{color_dcob} });
				
				$self->{videoClass}->addPolygon($frm, 
							   $frm, 
							   \@coord, 
							   $size,
							   \@fill, 
							   \@border,
							   1);
			}
			else
			{
				my @border;
				push(@border, ($mapped) ? @{ $self->{color_mref} } : @{ $self->{color_uref} });
			
				$self->{videoClass}->addPolygon($frm, 
							   $frm, 
							   \@coord, 
							   $size, 
							   \@fill, 
							   \@border,
							   1);			   
			}
		}
	}
}

sub addSysPolygon
{
	my ($self, $size) = @_;
	
	foreach my $sysId (keys %{ $self->{polygon}{sys} })
	{	
		foreach my $frm (keys %{ $self->{polygon}{sys}{$sysId} })
		{
			my @coord;
			push(@coord, @{ $self->{polygon}{sys}{$sysId}{$frm}{COORD} });
			my $dco = $self->{polygon}{sys}{$sysId}{$frm}{DCO};
			my $mapped = $self->{polygon}{sys}{$sysId}{$frm}{MAPPED};
			
			my @fill;
			push(@fill, @{ $self->{color_clear} });
			
			if($dco == 1)
			{
				my @border;
				push(@border, @{ $self->{color_dcob} });
				
				$self->{videoClass}->addPolygon($frm, 
							   $frm, 
							   \@coord, 
							   $size,
							   \@fill, 
							   \@border,
							   1);
			}
			else
			{
				my @border;
				push(@border, ($mapped) ? @{ $self->{color_msys} } : @{ $self->{color_usys} });
			
				$self->{videoClass}->addPolygon($frm, 
							   $frm, 
							   \@coord, 
							   $size, 
							   \@fill, 
							   \@border,
							   1);			   
			}
		}
	}
}

sub addRefLabel
{
	my ($self) = @_;
	
	foreach my $refId (keys %{ $self->{label}{ref} })
	{	
		foreach my $frm (keys %{ $self->{label}{ref}{$refId} })
		{
			my @coord;
			push(@coord, @{ $self->{label}{ref}{$refId}{$frm}{COORD} });
			
			$self->{videoClass}->addLabel($frm, 
						$frm, 
						$self->{label}{ref}{$refId}{$frm}{TEXT},
						\@coord);
		}
	}
}

sub addSysLabel
{
	my ($self) = @_;
	
	foreach my $sysId (keys %{ $self->{label}{sys} })
	{	
		foreach my $frm (keys %{ $self->{label}{sys}{$sysId} })
		{
			my @coord;
			push(@coord, @{ $self->{label}{sys}{$sysId}{$frm}{COORD} });
			
			$self->{videoClass}->addLabel($frm, 
						$frm, 
						$self->{label}{sys}{$sysId}{$frm}{TEXT},
						\@coord);
		}
	}
}

sub addRefSnailTrail
{
	my ($self, $size) = @_;
		
	foreach my $refId (keys %{ $self->{snail}{ref} })
	{	
		foreach my $frm (keys %{ $self->{snail}{ref}{$refId} })
		{
			foreach my $dco (keys %{ $self->{snail}{ref}{$refId}{$frm} })
			{
				foreach my $mapped (keys %{ $self->{snail}{ref}{$refId}{$frm}{$dco} })
				{
					foreach my $index (keys %{ $self->{snail}{ref}{$refId}{$frm}{$dco}{$mapped} })
					{
						my @coord;
						push(@coord, @{ $self->{snail}{ref}{$refId}{$frm}{$dco}{$mapped}{$index}{COORD} });
			
						my @fill;
						push(@fill, @{ $self->{color_clear} });
			
						if($dco == 1)
						{
							my @border;
							push(@border, @{ $self->{color_dcob} });
							
							$self->{videoClass}->addPolygon($frm, 
										   $frm, 
										   \@coord, 
										   $size,
										   \@fill, 
										   \@border,
										   0);
						}
						else
						{
							my @border;
							push(@border, ($mapped) ? @{ $self->{color_mref} } : @{ $self->{color_uref} });
						
							$self->{videoClass}->addPolygon($frm, 
										   $frm, 
										   \@coord, 
										   $size, 
										   \@fill, 
										   \@border,
										   0);			   
						}
					}
				}
			}
		}
	}
}

sub addSysSnailTrail
{
	my ($self, $size) = @_;
		
	foreach my $sysId (keys %{ $self->{snail}{sys} })
	{	
		foreach my $frm (keys %{ $self->{snail}{sys}{$sysId} })
		{
			foreach my $dco (keys %{ $self->{snail}{sys}{$sysId}{$frm} })
			{
				foreach my $mapped (keys %{ $self->{snail}{sys}{$sysId}{$frm}{$dco} })
				{
					foreach my $index (keys %{ $self->{snail}{sys}{$sysId}{$frm}{$dco}{$mapped} })
					{
						my @coord;
						push(@coord, @{ $self->{snail}{sys}{$sysId}{$frm}{$dco}{$mapped}{$index}{COORD} });
			
						my @fill;
						push(@fill, @{ $self->{color_clear} });
			
						if($dco == 1)
						{
							my @border;
							push(@border, @{ $self->{color_dcob} });
							
							$self->{videoClass}->addPolygon($frm, 
										   $frm, 
										   \@coord, 
										   $size,
										   \@fill, 
										   \@border,
										   0);
						}
						else
						{
							my @border;
							push(@border, ($mapped) ? @{ $self->{color_msys} } : @{ $self->{color_usys} });
						
							$self->{videoClass}->addPolygon($frm, 
										   $frm, 
										   \@coord, 
										   $size, 
										   \@fill, 
										   \@border,
										   0);			   
						}
					}
				}
			}
		}
	}
}

sub addTimer
{
	my ($self) = @_;
	
	my @coord = (0, 11);
	
	for(my $i=$self->{minFrame}; $i<=$self->{maxFrame}; $i++)
	{
		$self->{videoClass}->addLabel($i, $i, "Frame: $i", \@coord);
	}
}

sub addRefFullSnailTrail
{
	my ($self, $size) = @_;
	
	foreach my $refId (keys %{ $self->{snail}{ref} })
	{
		# find the final trail 
		my $lastFrame = 0;
		
		foreach my $frm (keys %{ $self->{snail}{ref}{$refId} })
		{
			$lastFrame = $frm if($lastFrame < $frm);
		}
		
		foreach my $dco (keys %{ $self->{snail}{ref}{$refId}{$lastFrame} })
		{
			foreach my $mapped (keys %{ $self->{snail}{ref}{$refId}{$lastFrame}{$dco} })
			{
				foreach my $index (keys %{ $self->{snail}{ref}{$refId}{$lastFrame}{$dco}{$mapped} })
				{
					my @coord;
					push(@coord, @{ $self->{snail}{ref}{$refId}{$lastFrame}{$dco}{$mapped}{$index}{COORD} });
		
					my @fill;
					push(@fill, @{ $self->{color_clear} });
		
					if($dco == 1)
					{
						my @border;
						push(@border, @{ $self->{color_dcob} });
						
						$self->{videoClass}->addPolygon(0, 
									   999999, 
									   \@coord, 
									   $size,
									   \@fill, 
									   \@border,
									   0);
					}
					else
					{
						my @border;
						push(@border, ($mapped) ? @{ $self->{color_mref} } : @{ $self->{color_uref} });
					
						$self->{videoClass}->addPolygon(0, 
									   999999, 
									   \@coord, 
									   $size, 
									   \@fill, 
									   \@border,
									   0);			   
					}
				}
			}
		}
	}
}

sub addSysFullSnailTrail
{
	my ($self, $size) = @_;
	
	foreach my $sysId (keys %{ $self->{snail}{sys} })
	{
		# find the final trail 
		my $lastFrame = 0;
		
		foreach my $frm (keys %{ $self->{snail}{sys}{$sysId} })
		{
			$lastFrame = $frm if($lastFrame < $frm);
		}
		
		foreach my $dco (keys %{ $self->{snail}{sys}{$sysId}{$lastFrame} })
		{
			foreach my $mapped (keys %{ $self->{snail}{sys}{$sysId}{$lastFrame}{$dco} })
			{
				foreach my $index (keys %{ $self->{snail}{sys}{$sysId}{$lastFrame}{$dco}{$mapped} })
				{
					my @coord;
					push(@coord, @{ $self->{snail}{sys}{$sysId}{$lastFrame}{$dco}{$mapped}{$index}{COORD} });
		
					my @fill;
					push(@fill, @{ $self->{color_clear} });
		
					if($dco == 1)
					{
						my @border;
						push(@border, @{ $self->{color_dcob} });
						
						$self->{videoClass}->addPolygon(0, 
									   999999, 
									   \@coord, 
									   $size,
									   \@fill, 
									   \@border,
									   0);
					}
					else
					{
						my @border;
						push(@border, ($mapped) ? @{ $self->{color_msys} } : @{ $self->{color_usys} });
					
						$self->{videoClass}->addPolygon(0, 
									   999999, 
									   \@coord, 
									   $size, 
									   \@fill, 
									   \@border,
									   0);			   
					}
				}
			}
		}
	}
}

sub XMLFile
{
	my ($self) = @_;
	
	return $self->{videoClass}->saveXMLFile(undef);	
}
