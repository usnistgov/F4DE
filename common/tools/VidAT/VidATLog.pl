#!/usr/bin/env perl

# vidatLog.pl
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

B<vidatLog.pl> overlays bounding boxes,
points, and labels on a video regarding the annotation provided by
the tracking log file created by the B<CLEARDTScorer.pl>.  The default
behavior of vidatLog.pl is the following:

=over 4 

=item * the video is generated with the boxes and points defined in the tracking log.  The boxes are color coded indicating how the bounding boxes were scored.

=item * bounding boxes for frames NOT referenced in the tracking log are added by the tool by computing a linearly interpolated transformation between successive evaluated frames. The interpolation ends when there is an evaluated frame not containing the object.

=item * Object IDs are added as labels to the bounding boxes. 

=item * A "snail trail" is added to the video indicating the object's bounding box frame history.  The trail remains visible while the object continues to have successive evaluated frames. '-notrails' disables this option. 

=back


The CLEARDTScorer tracking log information is represented as follows:

=over 4 

=item * The obox elements SYS <ID> obox[...] or REF <ID> obox[...]
    are represented by a rectangle defined by its coordinates in [...] with the 
    text label "SYS: <ID>" or "REF: <ID>".

=item * The point elements SYS <ID> point[...] or REF <ID> point[...]
    are represented by a point defined by its coordinates in [...] with the 
    label "SYS: <ID>" or "REF: <ID>".

=back

The colors used for the drawn elements indicate how the bounding boxes were scored by parsing the 
"Mapped : SYS <ID> -> REF <ID>" lines in the tracking log.  The default colors are: 

=over 4

=item * The un-mapped reference elements are in red.

=item * The un-mapped system elements are in orange.

=item * The mapped reference elements are in blue.

=item * The mapped system elements are in green.

=item * The Don't Care Objects (DCO) are in yellow.

=back



=head1 EXAMPLE EXECUTION

perl -I <VIDAT_DIRECTORY> <VIDAT_DIRECTORY>/vidatLog.pl \
 -i video_file \
 -l CLEARDTScorer_trackinglog \
 -o output_video_file
 

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

Create the output video by including only the frames between the 
boundary defined by <begframe> and <endframe>.

=item B<-k> F<auto>

Create the output video by including only the frames included in the tracking log.

=item B<-notrails>

Deactivate the snail trails. This option is useful when lots
of elements are tracked.

=item B<-nointerpolation>

This option deactivates the interpolation between evaluated frames as 
defined in the tracking log. See the DESCRIPTION in the manual page 'vidatLog.pl -man' for a description of the
interpolation algorithm. Using this option, the elements (points and boxes) will
only appear for the frames they have been defined in the tracking log.
 
The timer remains shown.

=item B<-onlyframes>

Generate output images only for the frames defined in the tracking log
without the snail trails and in a JPEG format. Images will be stored
in the directory F<OUTPUT>. This is the only option that changes the
output format from video to still images.


=item B<-man>

Manual.

=item B<-h>, B<--help>

Help.

=back

=head1 ADDITIONAL TOOLS

Third part software need to be installed:

 FFmpeg <http://ffmpeg.org/>
 Ghostscript <http://pages.cs.wisc.edu/~ghost/>
 ImageMagick <http://www.imagemagick.org> with JPEG v6b support <http://www.ijg.org/>

=head1 BUGS

No known bugs.

=head1 NOTE

=head1 AUTHORS

 Jerome Ajot <jerome.ajot@nist.gov>

=head1 VERSION

=head1 COPYRIGHT

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to title 17 Section 105 of the United States Code this software is not subject to copyright protection and is in the public domain. VidAT is an experimental system.  NIST assumes no responsibility whatsoever for its use by other parties, and makes no guarantees, expressed or implied, about its quality, reliability, or any other characteristic.  We would appreciate acknowledgement if the software is used.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
