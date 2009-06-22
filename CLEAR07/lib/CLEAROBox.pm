package CLEAROBox;

# CLEAROBox
#
# Author(s): Vasant Manohar
# Additions: Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAROBox.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CLEAROBox.pm Version: $version";

use CLEARPoint;
use MErrorH;
use MMisc;

# Constructor 
# Using double-argument form of bless() for an inheritable constructor
# Rather than being uniquely a class method, we'll set it up so that 
# it can be called as either a class method or an object method.

#######################

sub new {
    my ( $proto, $x, $y, $height, $width, $orientation ) = @_;
    my $class = ref($proto) || $proto;
   
    my $_errormsg = MErrorH->new("CLEAROBox");
    my $errortxt  = "";
    $_errormsg->set_errormsg($errortxt);

    my $self =
        {
        _x              => $x,
        _y              => $y,
        _width          => $width,
        _height         => $height,
        _orientation    => $orientation,
        #ErrorHandler
        _errormsg       =>$_errormsg,
        };

    return "'x' not defined" if (! defined $x);
    return "'y' not defined" if (! defined $y);
    return "'width' not defined" if (! defined $width);
    return "'width' should be a positive number" if ($width <= 0);
    return "'height' not defined" if (! defined $height);
    return "'height' should be a positive number" if ($height <= 0);
    return "'orientation' not defined" if (! defined $orientation);

    bless ( $self, $class );
    return $self;
}

######################

sub unitTest {
    print "Test CLEAROBox\n";
    
    my ( $ob1, $ob2, $ret );

    $ob1 = CLEAROBox->new(284, 149, 86, 103, 1);
    $ob2 = CLEAROBox->new(281, 149, 95, 102, 0);
    $ret = $ob1->computeIntersectionArea($ob2);
    MMisc::error_quit("  Computing Intersection Area Error: Expected 8365.20954518059 got $ret\n")
        if ($ret ne 8365.20954518059);

    $ob1 = CLEAROBox->new(119, 146, 37, 27, 3);
    $ob2 = CLEAROBox->new(109, 146, 43, 46, 0);
    $ret = $ob1->computeIntersectionArea($ob2);
    MMisc::error_quit("  Computing Intersection Area Error: Expected 979.897364451338 got $ret\n")
        if ($ret ne 979.897364451338);

    print "  Computing Intersection Area... OK\n";
    return 1;
}

#######################

sub _setX {
    my ( $self, $x ) = @_;
    $self->{_x} = $x;
}

sub getX {
    my ( $self ) = @_;
    return $self->{_x};
}

sub _setY {
    my ( $self, $y ) = @_;
    $self->{_y} = $y;
}

sub getY {
    my ( $self ) = @_;
    return $self->{_y}; 
}

sub _setWidth {
    my ( $self, $width ) = @_;
    $self->{_width} = $width;
}

sub getWidth {
    my ( $self ) = @_;
    return $self->{_width}; 
}

sub _setHeight {
    my ( $self, $height ) = @_;
    $self->{_height} = $height;
}

sub getHeight {
    my ( $self ) = @_;
    return $self->{_height};
}

sub _setOrientation {
    my ( $self, $orientation ) = @_;
    $self->{_orientation} = $orientation;
}

sub getOrientation {
    my ( $self ) = @_;
    return $self->{_orientation};
}

#######################

sub computeArea {
    my ( $self ) = @_;
    return $self->getWidth()*$self->getHeight();
}

#######################

sub computeCentroid {
  my ( $self ) = @_;
  my $orads = $self->getOrientation()/180.0*3.1415926535897932384626433;
  my $xhat = $self->getWidth()/2;
  my $yhat = $self->getHeight()/2;
  my $r = sqrt($xhat*$xhat + $yhat*$yhat);
  my $theta = atan2($yhat,$xhat);
  $theta -= $orads;
  
  my $centx = $r*cos($theta)+$self->getX();
  my $centy = $r*sin($theta)+$self->getY();
  my $centroid = CLEARPoint->new( $centx, $centy );
  
  MMisc::error_quit("Failed to create new 'CLEARPoint' instance in 'computeCentroid'\n")
      if (ref($centroid) ne "CLEARPoint");
  
  return $centroid;
}

#######################

sub computeIntersectionArea {
    my ( $self, $other ) = @_;

    my $PI = 3.1415926535897932384626433;
    my $MACHINE_LOW = 0.0001;

    my $gtBox = { 
                 x => $self->getX(), 
                 y => $self->getY(), 
                 width => $self->getWidth(), 
                 height => $self->getHeight(), 
                 orientation => $self->getOrientation()/180.0*$PI,
                };
    my $soBox = { 
                 x => $other->getX(), 
                 y => $other->getY(), 
                 width => $other->getWidth(), 
                 height => $other->getHeight(), 
                 orientation => $other->getOrientation()/180.0*$PI,
                };

    # Check for the trivial case
    if ( ($gtBox->{x} == $soBox->{x}) && ($gtBox->{y} == $soBox->{y}) && ($gtBox->{width} == $soBox->{width}) && 
         ($gtBox->{height} == $soBox->{height}) && ($gtBox->{orientation} == $soBox->{orientation}) ) {
        return ($gtBox->{width}*$gtBox->{height});
    }

    # Build vertex set for both gtBox and soBox
    my $gtVertexSet = {
                        topLeft  => [ $gtBox->{x}, $gtBox->{y} ],
                        botLeft  => [ $gtBox->{x}+$gtBox->{height}*sin($gtBox->{orientation}), 
                                      $gtBox->{y}+$gtBox->{height}*cos($gtBox->{orientation}) ],
                        botRight => [ $gtBox->{x}+$gtBox->{height}*sin($gtBox->{orientation})+$gtBox->{width}*cos($gtBox->{orientation}), 
                                      $gtBox->{y}+$gtBox->{height}*cos($gtBox->{orientation})-$gtBox->{width}*sin($gtBox->{orientation}) ],
                        topRight => [ $gtBox->{x}+$gtBox->{width}*cos($gtBox->{orientation}), 
                                      $gtBox->{y}-$gtBox->{width}*sin($gtBox->{orientation}) ],
                      };
    my $soVertexSet = {
                        topLeft  => [ $soBox->{x}, $soBox->{y} ],
                        botLeft  => [ $soBox->{x}+$soBox->{height}*sin($soBox->{orientation}), 
                                      $soBox->{y}+$soBox->{height}*cos($soBox->{orientation}) ],
                        botRight => [ $soBox->{x}+$soBox->{height}*sin($soBox->{orientation})+$soBox->{width}*cos($soBox->{orientation}), 
                                      $soBox->{y}+$soBox->{height}*cos($soBox->{orientation})-$soBox->{width}*sin($soBox->{orientation}) ],
                        topRight => [ $soBox->{x}+$soBox->{width}*cos($soBox->{orientation}), 
                                      $soBox->{y}-$soBox->{width}*sin($soBox->{orientation}) ],
                      };
    
    my @vertexOrder = ('topLeft', 'botLeft', 'botRight', 'topRight');

    # Check first for the simple case, when the orientation of both OBoxes is zero
    if ( ($gtBox->{orientation} == 0) && ($soBox->{orientation} == 0) ) {
        my $intLeft   = MMisc::max( $gtVertexSet->{topLeft}[0], $soVertexSet->{topLeft}[0] );
        my $intTop    = MMisc::max( $gtVertexSet->{topLeft}[1], $soVertexSet->{topLeft}[1] );
        my $intRight  = MMisc::min( $gtVertexSet->{botRight}[0], $soVertexSet->{botRight}[0] );
        my $intBottom = MMisc::min( $gtVertexSet->{botRight}[1], $soVertexSet->{botRight}[1] );

        my $intWidth  = $intRight > $intLeft ? ($intRight - $intLeft) : 0;
        my $intHeight = $intBottom > $intTop ? ($intBottom - $intTop) : 0;

        return ($intWidth*$intHeight);
    }

    # Proceed to do the generic case.
    my $countComposed = 0;
    my $intVertices = [ ];
    my ( $intTopLeftX, $intTopLeftY );

    # Find gtBox vertices contained in soOBox
    foreach my $gtKey (@vertexOrder) {
        my $vertSlope1 = ($gtVertexSet->{$gtKey}[1] - $soVertexSet->{topRight}[1])*($soVertexSet->{botLeft}[0] - $soVertexSet->{topLeft}[0]) - 
                         ($gtVertexSet->{$gtKey}[0] - $soVertexSet->{topRight}[0])*($soVertexSet->{botLeft}[1] - $soVertexSet->{topLeft}[1]);
        my $vertSlope2 = ($gtVertexSet->{$gtKey}[1] - $soVertexSet->{topLeft}[1])*($soVertexSet->{botLeft}[0] - $soVertexSet->{topLeft}[0]) - 
                         ($gtVertexSet->{$gtKey}[0] - $soVertexSet->{topLeft}[0])*($soVertexSet->{botLeft}[1] - $soVertexSet->{topLeft}[1]);
        my $horzSlope1 = ($gtVertexSet->{$gtKey}[1] - $soVertexSet->{topLeft}[1])*($soVertexSet->{topRight}[0] - $soVertexSet->{topLeft}[0]) - 
                         ($gtVertexSet->{$gtKey}[0] - $soVertexSet->{topLeft}[0])*($soVertexSet->{topRight}[1] - $soVertexSet->{topLeft}[1]);
        my $horzSlope2 = ($gtVertexSet->{$gtKey}[1] - $soVertexSet->{botLeft}[1])*($soVertexSet->{topRight}[0] - $soVertexSet->{topLeft}[0]) - 
                         ($gtVertexSet->{$gtKey}[0] - $soVertexSet->{botLeft}[0])*($soVertexSet->{topRight}[1] - $soVertexSet->{topLeft}[1]);
        my $chkVal1 = abs($vertSlope1*$vertSlope2) <= $MACHINE_LOW ? 0 : $vertSlope1*$vertSlope2;
        my $chkVal2 = abs($horzSlope1*$horzSlope2) <= $MACHINE_LOW ? 0 : $horzSlope1*$horzSlope2;

        if (($chkVal1 < 0) && ($chkVal2 < 0)) {
            push( @{$intVertices->[$countComposed]}, @{ $gtVertexSet->{$gtKey} } );
            $countComposed++;
            if (! defined $intTopLeftX) { ( $intTopLeftX, $intTopLeftY ) = @{ $gtVertexSet->{$gtKey} }; }
            elsif ( ($intTopLeftX > $gtVertexSet->{$gtKey}[0]) || 
                    ((abs($intTopLeftX - $gtVertexSet->{$gtKey}[0]) <= $MACHINE_LOW) && ($intTopLeftY < $gtVertexSet->{$gtKey}[1])) ) {
                ( $intTopLeftX, $intTopLeftY ) = @{ $gtVertexSet->{$gtKey} };
            }
        }
    }

    # Find soBox vertices contained in gtOBox
    foreach my $soKey (@vertexOrder) {
        my $vertSlope1 = ($soVertexSet->{$soKey}[1] - $gtVertexSet->{topRight}[1])*($gtVertexSet->{botLeft}[0] - $gtVertexSet->{topLeft}[0]) - 
                         ($soVertexSet->{$soKey}[0] - $gtVertexSet->{topRight}[0])*($gtVertexSet->{botLeft}[1] - $gtVertexSet->{topLeft}[1]);
        my $vertSlope2 = ($soVertexSet->{$soKey}[1] - $gtVertexSet->{topLeft}[1])*($gtVertexSet->{botLeft}[0] - $gtVertexSet->{topLeft}[0]) - 
                         ($soVertexSet->{$soKey}[0] - $gtVertexSet->{topLeft}[0])*($gtVertexSet->{botLeft}[1] - $gtVertexSet->{topLeft}[1]);
        my $horzSlope1 = ($soVertexSet->{$soKey}[1] - $gtVertexSet->{topLeft}[1])*($gtVertexSet->{topRight}[0] - $gtVertexSet->{topLeft}[0]) - 
                         ($soVertexSet->{$soKey}[0] - $gtVertexSet->{topLeft}[0])*($gtVertexSet->{topRight}[1] - $gtVertexSet->{topLeft}[1]);
        my $horzSlope2 = ($soVertexSet->{$soKey}[1] - $gtVertexSet->{botLeft}[1])*($gtVertexSet->{topRight}[0] - $gtVertexSet->{topLeft}[0]) - 
                         ($soVertexSet->{$soKey}[0] - $gtVertexSet->{botLeft}[0])*($gtVertexSet->{topRight}[1] - $gtVertexSet->{topLeft}[1]);
        my $chkVal1 = abs($vertSlope1*$vertSlope2) <= $MACHINE_LOW ? 0 : $vertSlope1*$vertSlope2;
        my $chkVal2 = abs($horzSlope1*$horzSlope2) <= $MACHINE_LOW ? 0 : $horzSlope1*$horzSlope2;

        if (($chkVal1 < 0) && ($chkVal2 < 0)) {
            push( @{$intVertices->[$countComposed]}, @{ $soVertexSet->{$soKey} } );
            $countComposed++;
            if (! defined $intTopLeftX) { ( $intTopLeftX, $intTopLeftY ) = @{ $soVertexSet->{$soKey} }; }
            elsif ( ($intTopLeftX > $soVertexSet->{$soKey}[0]) || 
                    ((abs($intTopLeftX - $soVertexSet->{$soKey}[0]) <= $MACHINE_LOW) && ($intTopLeftY < $soVertexSet->{$soKey}[1])) ) {
                ( $intTopLeftX, $intTopLeftY ) = @{ $soVertexSet->{$soKey} };
            }
        }
    }

    # Find the intersection points of the two OBoxes
    for (my $outloop = 0; $outloop <= $#vertexOrder; $outloop++) {
        for (my $inloop = 0; $inloop <= $#vertexOrder; $inloop++) {
            my @gtVertex1 = ( $gtVertexSet->{$vertexOrder[$outloop]}[0], $gtVertexSet->{$vertexOrder[$outloop]}[1] );
            my @gtVertex2 = ( $gtVertexSet->{$vertexOrder[($outloop+1)%4]}[0], $gtVertexSet->{$vertexOrder[($outloop+1)%4]}[1] );
            my @soVertex1 = ( $soVertexSet->{$vertexOrder[$inloop]}[0], $soVertexSet->{$vertexOrder[$inloop]}[1] );
            my @soVertex2 = ( $soVertexSet->{$vertexOrder[($inloop+1)%4]}[0], $soVertexSet->{$vertexOrder[($inloop+1)%4]}[1] );
            my ( $xCross, $yCross ) = ( 0,0 );

            if ((abs($gtVertex1[0] - $gtVertex2[0]) <= $MACHINE_LOW) && (abs($soVertex1[0] - $soVertex2[0]) <= $MACHINE_LOW)) {next;}
            elsif ((abs($gtVertex1[0] - $gtVertex2[0]) <= $MACHINE_LOW) && (abs($soVertex1[0] - $soVertex2[0]) > $MACHINE_LOW)) {
                $xCross = $gtVertex1[0];
                my $slope = ($soVertex2[1] - $soVertex1[1])/($soVertex2[0] - $soVertex1[0]);
                $yCross = $slope*($xCross - $soVertex1[0]) + $soVertex1[1];
            }
            elsif ((abs($gtVertex1[0] - $gtVertex2[0]) > $MACHINE_LOW) && (abs($soVertex1[0] - $soVertex2[0]) <= $MACHINE_LOW)) {
                $xCross = $soVertex1[0];
                my $slope = ($gtVertex2[1] - $gtVertex1[1])/($gtVertex2[0] - $gtVertex1[0]);
                $yCross = $slope*($xCross - $gtVertex1[0]) + $gtVertex1[1];
            }
            else {
                my $slope1 = ($gtVertex2[1] - $gtVertex1[1])/($gtVertex2[0] - $gtVertex1[0]);
                my $slope2 = ($soVertex2[1] - $soVertex1[1])/($soVertex2[0] - $soVertex1[0]);

                if (abs($slope1 - $slope2) <= $MACHINE_LOW) {next;}
                else {
                    $xCross = ($slope1*$gtVertex1[0] - $gtVertex1[1] - $slope2*$soVertex1[0] + $soVertex1[1])/($slope1-$slope2);
                    $yCross = $slope1*($xCross - $gtVertex1[0]) + $gtVertex1[1];
                }
            }

            if ( ((MMisc::max(MMisc::min($gtVertex1[0], $gtVertex2[0]), MMisc::min($soVertex1[0], $soVertex2[0])) - $xCross) <= $MACHINE_LOW) && 
                 (($xCross - MMisc::min(MMisc::max($gtVertex1[0], $gtVertex2[0]), MMisc::max($soVertex1[0], $soVertex2[0]))) <= $MACHINE_LOW) &&
                 ((MMisc::max(MMisc::min($gtVertex1[1], $gtVertex2[1]), MMisc::min($soVertex1[1], $soVertex2[1])) - $yCross) <= $MACHINE_LOW) && 
                 (($yCross - MMisc::min(MMisc::max($gtVertex1[1], $gtVertex2[1]), MMisc::max($soVertex1[1], $soVertex2[1]))) <= $MACHINE_LOW) ) {
                push( @{$intVertices->[$countComposed]}, ( $xCross, $yCross ) );
                $countComposed++;
                if (! defined $intTopLeftX) { ( $intTopLeftX, $intTopLeftY ) = ( $xCross, $yCross ); }
                elsif ( ($intTopLeftX > $xCross) || 
                        ((abs($intTopLeftX - $xCross) <= $MACHINE_LOW) && ($intTopLeftY < $yCross)) ) {
                    ( $intTopLeftX, $intTopLeftY ) = ( $xCross, $yCross );
                }
            }
        }
    }
    
    # Least number of non-collinear points needed for a closed area (3). If # of intersection points is less than 3, return 0.
    if ($countComposed < 3) { return 0; }

    # print Dumper($intVertices);

    # Create a cyclic order of vertex traversal based on the angle made with pivot vertex (topLeft).
    my $convHull = {};
    for (my $loop = 0; $loop < scalar @{$intVertices}; $loop++) {
        if (abs($$intVertices[$loop][0] - $intTopLeftX) <= $MACHINE_LOW) {
            if (abs($$intVertices[$loop][1] - $intTopLeftY) <= $MACHINE_LOW) { next; }
            elsif ($$intVertices[$loop][1] > $intTopLeftY) { 
                if (exists $convHull->{$PI/2}) {
                    my @currVertex = @{$convHull->{$PI/2}};
                    if ((abs($currVertex[0] - $$intVertices[$loop][0]) > $MACHINE_LOW) || (abs($currVertex[1] - $$intVertices[$loop][1]) > $MACHINE_LOW)) {
                        if ((abs($currVertex[0] - $intTopLeftX) <= $MACHINE_LOW) && (abs($currVertex[1] - $intTopLeftY) <= $MACHINE_LOW)) {
                            $convHull->{$PI/2} = [@{ $intVertices->[$loop] }];
                        }
                        elsif ((abs($intTopLeftX - $$intVertices[$loop][0]) > $MACHINE_LOW) || (abs($intTopLeftY - $$intVertices[$loop][1]) > $MACHINE_LOW)) {
                            $self->_set_errormsg("WEIRD: There are 3 unique collinear points forming an area");
                            return -1;
                        }
                    }
                }
                else { $convHull->{$PI/2} = [@{ $intVertices->[$loop] }]; }
            } 
            else { 
                if (exists $convHull->{-$PI/2}) {
                    my @currVertex = @{$convHull->{-$PI/2}};
                    if ((abs($currVertex[0] - $$intVertices[$loop][0]) > $MACHINE_LOW) || (abs($currVertex[1] - $$intVertices[$loop][1]) > $MACHINE_LOW)) {
                        if ((abs($currVertex[0] - $intTopLeftX) <= $MACHINE_LOW) && (abs($currVertex[1] - $intTopLeftY) <= $MACHINE_LOW)) {
                            $convHull->{-$PI/2} = [@{ $intVertices->[$loop] }];
                        }
                        elsif ((abs($intTopLeftX - $$intVertices[$loop][0]) > $MACHINE_LOW) || (abs($intTopLeftY - $$intVertices[$loop][1]) > $MACHINE_LOW)) {
                            $self->_set_errormsg("WEIRD: There are 3 unique collinear points forming an area");
                            return -1;
                        }
                    }
                }
                else { $convHull->{-$PI/2} = [@{ $intVertices->[$loop] }]; }
            }
        }
        else { 
            my $angle = atan2( $$intVertices[$loop][1] - $intTopLeftY, $$intVertices[$loop][0] - $intTopLeftX );
            if (exists $convHull->{$angle}) {
                    my @currVertex = @{$convHull->{$angle}};
                    if ((abs($currVertex[0] - $$intVertices[$loop][0]) > $MACHINE_LOW) || (abs($currVertex[1] - $$intVertices[$loop][1]) > $MACHINE_LOW)) {
                        if ((abs($currVertex[0] - $intTopLeftX) <= $MACHINE_LOW) && (abs($currVertex[1] - $intTopLeftY) <= $MACHINE_LOW)) {
                            $convHull->{angle} = [@{ $intVertices->[$loop] }];
                        }
                        elsif ((abs($intTopLeftX - $$intVertices[$loop][0]) > $MACHINE_LOW) || (abs($intTopLeftY - $$intVertices[$loop][1]) > $MACHINE_LOW)) {
                            $self->_set_errormsg("WEIRD: There are 3 unique collinear points forming an area");
                            return -1;
                        }
                    }
            }
            else { $convHull->{$angle} = [@{ $intVertices->[$loop] }]; }
        }
    }

    # Compute individual triangle areas and add them up
    my @hullOrder = MMisc::reorder_array_numerically(keys %$convHull);
    my $intersectionArea = 0;
    for (my $loop = 0; $loop < $#hullOrder; $loop++ ) {
        # print "$convHull->{$hullOrder[$loop]}[0] $convHull->{$hullOrder[$loop]}[1]\n";
        my ( $vertex1X, $vertex1Y ) = @{ $convHull->{$hullOrder[$loop]} };
        my ( $vertex2X, $vertex2Y ) = @{ $convHull->{$hullOrder[$loop+1]} };
        my ( $height, $base ) = ( 0, 0 );

        # Compute height for each triangle
        if ( abs($intTopLeftX - $vertex1X) <= $MACHINE_LOW ) { $height = abs($vertex2X - $intTopLeftX); }
        else {
            my $slope = ($vertex1Y - $intTopLeftY)/($vertex1X - $intTopLeftX); 
            $height = abs(($vertex2X - $intTopLeftX)*$slope + $intTopLeftY - $vertex2Y)/sqrt(1+$slope*$slope);
        }

        # Compute base for each triangle
        $base = sqrt(($intTopLeftX - $vertex1X)*($intTopLeftX - $vertex1X) + ($intTopLeftY - $vertex1Y)*($intTopLeftY - $vertex1Y));
        $intersectionArea += $base*$height/2;
    }
    # print "$convHull->{$hullOrder[$#hullOrder]}[0] $convHull->{$hullOrder[$#hullOrder]}[1]\n";

    return $intersectionArea;
    
}

#######################

sub computeBigBox {
    my ( $self, $other ) = @_;

    my $newX = $self->getX();
    my $newY = $other->getY();
    my $newWidth = $self->getWidth();
    my $newHeight = $other->getHeight()*2;
    my $newOrientation = $self->getOrientation();

    $self->_setX($newX);
    $self->_setY($newY);
    $self->_setWidth($newWidth);
    $self->_setHeight($newHeight);
    $self->_setOrientation($newOrientation);
}

#######################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{_errormsg}->set_errormsg($txt);
}

sub get_errormsg {
  my ($self) = @_;
  return($self->{_errormsg}->errormsg());
}

sub error {
  my ($self) = @_;
  return($self->{_errormsg}->error());
}

########################################

1;
