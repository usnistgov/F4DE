#!/usr/bin/env perl

# VidAT
# vidatLog.pl
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
use Getopt::Long;
use Pod::Usage;
use List::Util qw( min max );
use File::Path qw( rmtree );
use VideoEdit;
use trackinglog;
use FFmpegImage;
use Data::Dumper;

my $man = 0;
my $help = 0;

my $inVideoFile = "";
my $logFile = "";
my $outFile = "";
my $keep = "";
my $tmpBaseDir = "/tmp/Vidat.$$";
my $notrails = 0;
my $nointerpolation = 0;
my $onlyframes = 0;

my $keep1 = 0;
my $keep2 = 9e99;

GetOptions
(
	'i=s'    => \$inVideoFile,
	'l=s'    => \$logFile,
	'o=s'    => \$outFile,
	'h|help' => \$help,
	'man'    => \$man,
	'k=s'    => \$keep,
	'tmp=s'  => \$tmpBaseDir,
	'notrails' => \$notrails,
	'nointerpolation' => \$nointerpolation,
	'onlyframes' => \$onlyframes, # Display only key Frames
) or pod2usage(1);

pod2usage(1) if $help;
pod2usage(-exitvalue => 0, -verbose => 2) if $man;
pod2usage("Error: Input video must be specified.\n") if($inVideoFile eq "");
pod2usage("Error: log file must be specified.\n") if($logFile eq "");
pod2usage("Error: Output file must be specified.\n") if($outFile eq "");

mkdir("$tmpBaseDir");

$nointerpolation = 1 if($onlyframes);
$notrails = 1 if($nointerpolation);

my $v = new FFmpegImage($inVideoFile);

my $keepMin = 0;
my $keepMax = $v->{expectedframes};

if($keep =~ /^(\d+),(\d+)$/)
{
	$keepMin = max($keepMin, int($1));
	$keepMax = min($keepMax, int($2));
}

my $x = new trackinglog($logFile, $keepMin, $keepMax, $tmpBaseDir, 1-$nointerpolation);
$x->{videoClass}->addKeepRange($keepMin, $keepMax);

$x->keepOnlyKeyFramesRange() if($keep eq "auto");
$x->keepOnlyKeyFrames() if($onlyframes);

$x->addRefPolygon(4);
$x->addSysPolygon(4);
$x->addRefPoint(4);
$x->addSysPoint(4);
$x->addRefLabel();
$x->addSysLabel();

if($notrails != 1)
{
	$x->addRefSnailTrail(3);
	$x->addSysSnailTrail(3);
}

$x->addTimer();

$x->{videoClass}->loadVideoFile($inVideoFile);

if(!$onlyframes)
{
	# Build a video
	print "Build video file '$outFile'\n";
	$x->{videoClass}->buildVideo($outFile);
}
else
{
	# Just images
	print "Build JPEG files in '$outFile'\n";
	mkdir($outFile);
	$x->{videoClass}->buildJpegs($outFile);
}

rmtree("$tmpBaseDir");

=head1 NAME

vidatLog.pl -- Video Annotation Tool 

=head1 SYNOPSIS

B<vidatLog.pl> -i F<VIDEO> -l F<LOG> -o F<OUTPUT> [-tmp F<DIR>] [-k [F<begframe>,F<endframe>|auto]] [-notrails] [-nointerpolation] [-onlyframes] [-man] [-h]

=head1 DESCRIPTION

The software is adding filter information such as polygon masking, point and labels into the video. It is frame accurate.

=head1 OPTIONS

=over

=item B<-i> F<VIDEO>

Input video file..

=item B<-l> F<LOG>

Input log file.

=item B<-o> F<OUTPUT>

Output video file or directory.

=item B<-tmp> F<DIR>

Specify a temporary directory.

=item B<-k> F<begframe>,F<endframe>

Ignore the frames outside the defined range.

=item B<-k> F<auto>

Ignore the frames outside the defined range in the trackinglog.

=item B<-notrails>

Do not generate the snail trails.

=item B<-nointerpolation>

Do not generate the interpolated boxes and points. It will display only the timer and the elements defined in the tracking log.

=item B<-onlyframes>

Generate only images for the frames defined in the tracking log, without the snail trails and it will store them in the directory F<OUTPUT>.

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

=head1 AUTHORS

 Jerome Ajot <jerome.ajot@nist.gov>

=head1 VERSION

=head1 COPYRIGHT

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to title 17 Section 105 of the United States Code this software is not subject to copyright protection and is in the public domain. VidAT is an experimental system.  NIST assumes no responsibility whatsoever for its use by other parties, and makes no guarantees, expressed or implied, about its quality, reliability, or any other characteristic.  We would appreciate acknowledgement if the software is used.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.