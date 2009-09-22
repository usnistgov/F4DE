#!/usr/bin/env perl

# VidAT
# tracklog2xml.pl
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

use strict;
use warnings;
use trackinglog;
use Data::Dumper;
use Pod::Usage;

if(scalar(@ARGV) != 1)
{
	pod2usage(1);
}

my $inFile = "$ARGV[0]";

my $x = new trackinglog($inFile);

$x->addRefPolygon(4);
$x->addSysPolygon(4);
$x->addRefLabel();
$x->addSysLabel();
$x->addRefSnailTrail(3);
$x->addSysSnailTrail(3);
$x->addTimer();

print $x->XMLFile();

=head1 NAME

tracklog2xml.pl -- Tracking log into XML file 

=head1 SYNOPSIS

B<vidat.pl> F<log>

=head1 DESCRIPTION

The software converting tracking log file into XML. And output the XML file in the stdout.

=head1 OPTIONS

=over

=item F<log>

Input log file.

=back

=head1 ADDITIONAL TOOLS

Third part software need to be installed:

 FFmpeg <http://ffmpeg.org/>
 Ghostscript <http://pages.cs.wisc.edu/~ghost/>
 ImageMagick <http://www.imagemagick.org> with JPEG v6b support <ftp://ftp.uu.net/graphics/jpeg/>

=head1 BUGS

No known bugs.

=head1 NOTE

=head1 AUTHORS

 Jerome Ajot <jerome.ajot@nist.gov>

=head1 VERSION

=head1 COPYRIGHT

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to title 17 Section 105 of the United States Code this software is not subject to copyright protection and is in the public domain. VidAT is an experimental system.  NIST assumes no responsibility whatsoever for its use by other parties, and makes no guarantees, expressed or implied, about its quality, reliability, or any other characteristic.  We would appreciate acknowledgement if the software is used.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.