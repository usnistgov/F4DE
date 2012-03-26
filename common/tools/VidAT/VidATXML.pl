#!/usr/bin/env perl

# VidATXML.pl
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

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ($f4d);
}
use lib (@f4bv);

use Getopt::Long;
use Pod::Usage;

use VidAT_VideoEdit;

use Data::Dumper;

my $man = 0;
my $help = 0;

my $inVideoFile = "";
my $xmlFile = "";
my $outFile = "";
my $keep = "";
my $tmpBaseDir = "/tmp/Vidat.$$";

my $keep1 = 0;
my $keep2 = 9e99;

GetOptions
(
	'i=s'    => \$inVideoFile,
	'x=s'    => \$xmlFile,
	'o=s'    => \$outFile,
	'h|help' => \$help,
	'man'    => \$man,
	'k=s'    => \$keep,
) or pod2usage(1);

pod2usage(1) if $help;
pod2usage(-exitvalue => 0, -verbose => 2) if $man;
pod2usage("Error: Input video must be specified.\n") if($inVideoFile eq "");
pod2usage("Error: XML file must be specified.\n") if($xmlFile eq "");
pod2usage("Error: Output file must be specified.\n") if($outFile eq "");

my $x = new VidAT_VideoEdit();

if($keep =~ /^(\d+),(\d+)$/)
{
	$keep1 = int($1);
	$keep2 = int($2);
	$x->addKeepRange($keep1, $keep2);
}

$x->loadXMLFile($xmlFile);
$x->loadVideoFile($inVideoFile);

if($keep1 != $keep2)
{
	# Build a video
	print "Build video file '$outFile'\n";
	$x->buildVideo($outFile);
}
else
{
	# just one image
	print "Just one jpeg file '$outFile'\n";
	$x->buildJpegSingle($keep1, $outFile);
}

$x->clean();

exit(0);

=head1 NAME

VidATXML -- Video Annotation Tool 

=head1 SYNOPSIS

B<VidATXML> -i F<VIDEO> -x F<XML> -o F<OUTPUT> [-man] [-h]

=head1 DESCRIPTION

The software is adding filter information such as polygon masking, point and labels into the video. It is frame accurate.

=head1 OPTIONS

=over

=item B<-i> F<VIDEO>

Input video file..

=item B<-x> F<XML>

Input XML configuration file.

=item B<-o> F<OUTPUT>

Output video file.

=item B<-k> F<begframe>,F<endframe>

Just create a chunck of the video from begframe to endframe frames.

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

 Jerome Ajot

=head1 VERSION

=head1 COPYRIGHT

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to title 17 Section 105 of the United States Code this software is not subject to copyright protection and is in the public domain. VidAT is an experimental system.  NIST assumes no responsibility whatsoever for its use by other parties, and makes no guarantees, expressed or implied, about its quality, reliability, or any other characteristic.  We would appreciate acknowledgement if the software is used.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
