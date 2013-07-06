#!/usr/bin/env perl

# DETEdit
# DETEdit.pl
# Authors: Jonathan Fiscus
#          Jerome Ajot
#          Martial Michel
# 
# This software was developed at the National Institute of Standards and
# Technology by employees of the Federal Government in the course of
# their official duties.  Pursuant to Title 17 Section 105 of the United
# States Code this software is not subject to copyright protection within
# the United States and is in the public domain. 
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
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST
# MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER,
# INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use Data::Dumper;

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "DETCurve", "DETCurveSet") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long", "Pod::Usage", "File::Temp") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

my $VERSION = 0.1;
my $man = 0;
my $help = 0;
my $inPlace = 0;
my $title = undef;
my $titleRegex = undef;
my $inputSrl = undef;
my $outputSrl = undef;
my $gzipPROG = "gzip";

my @plotControls = ();
my ($smooth, $smoothWindowSize, $targExtraDecisions, $nonTargExtraDecisions) = (undef, undef, undef, undef);

Getopt::Long::Configure(qw( no_ignore_case ));

GetOptions
  (
   'o|output-srl=s' => \$outputSrl,
   'i|input-srl=s'  => \$inputSrl,
   'I|Inplace'      => \$inPlace,
   
   't|title=s'      => \$title,
   'titleRegex=s'   => \$titleRegex,
   
   'Z|ZipPROG=s'    => \$gzipPROG,
   
   'p|plotControls=s'            => \@plotControls,

   'version'      => sub { my $name = $0; $name =~ s/.*\/(.+)/$1/; print "$name version $VERSION\n"; exit(0); },
   'h|help'         => \$help,
   'm|man'          => \$man,
  );

## Docs
pod2usage(1) if $help;
pod2usage(-exitvalue => 0, -verbose => 2) if $man;
##

## Checking inputs
pod2usage("ERROR: An input file must be set.\n") unless defined($inputSrl);
pod2usage("ERROR: The output must be specified as either 'inPlace' or as a file via -o\n")
  if (!defined($outputSrl) && $inPlace == 0);
pod2usage("ERROR: The output must be specified as either 'inPlace' or as a file via -o, but NOT both!\n")
  if (defined($outputSrl) && $inPlace == 1);


foreach my $directive (@plotControls){
  if ($directive =~ /smooth=(\d+),(\d+),(\d+)$/){
    ($smooth, $smoothWindowSize, $targExtraDecisions, $nonTargExtraDecisions) = (1, $1, $2, $3);    
  } else {
    print "Warning: Unknown plot directive /$directive/\n";
  }
}

my $inDet = DETCurve::readFromFile($inputSrl, $gzipPROG);
if ($smooth){
  $inDet = $inDet->getSmoothedDET($smoothWindowSize, $targExtraDecisions, $nonTargExtraDecisions);
}


##Make the edits
if (defined($title)){
  $inDet->setLineTitle($title);
}
if (defined($titleRegex)){
	my $retitle = $inDet->getLineTitle();
  my ($op, $op1, $op2, $cond) = split(/\//,$titleRegex,4);
  $cond = "" if (! defined($cond)); 
			
  if ($cond eq "g"){
		$retitle =~ s/$op1/$op2/g;
  } elsif ($cond eq "i") {
		$retitle =~ s/$op1/$op2/i;
  } elsif (($cond eq "gi") || ($cond eq "ig")) {
  	$retitle =~ s/$op1/$op2/gi;
  }	else {
  	$retitle =~ s/$op1/$op2/;
	}
  $inDet->setLineTitle($retitle);
}

### Output the new  file
if ($inPlace){
  $inputSrl =~ s/\.gz$//;
  $inDet->serialize($inputSrl);  
} else {
  ### delete the .gz if it's there
  $outputSrl =~ s/\.gz$//;
  $inDet->serialize($outputSrl);
}
exit 0;

#############################################  End of the program #########################################

sub _warn_add
{
	$warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

__END__

=head1 NAME

DETEdit.pl -- Edit properties in a serialized DET Curve.

=head1 SYNOPSIS

S<B<DETEdit.pl> [--help | --man | --version] -input-srl F<IN_SRL_FILE>  [--Inplace] --output-srl F<OUT_SRL_FILE> [--title I<"title">] [--titleRegex I<regexp>] [--ZipPROG I<prog>] [--plotControls> F<Directive>]>

=head1 DESCRIPTION

The script modifies fields in a serialized DET Curve generated by the F4DE package.

=head1 OPTIONS

=over

=item B<--input-srl> F<SRL>

Input serialized DET Curve .

=item B<--Inplace> 

Overwrite the input file with the updated file.

=item B<--output-srl> 

Specifiy the output file.

=item B<--title> S<"title">

Specify a new title.

=item B<--titleRegex>

Modify the title with the regular expression.  If both B<title> and B<titleRegex> are used on the commandline, the title is changed, then the Regex is applied.

=item B<-Z>, B<--ZipPROG> F<GZIP_PATH>

Specify the full path name to gzip (default: 'gzip').

=item B<-p>, B<--plotControls> F<Directive>

The B<plotControl> options provides access to fine control the the DET curve display.

/smooth=AdjacentDecisions,extraTargs,extraNonTargs/   -> Build a smoothed DET with the following parameters.     <AdjacentDecisions> use the average decision score +/- the number pf points.  0 means no averaging.  <extraTargs> adds the N targets with linearly interpolated values between each pair of targets.  0 means no targets added.  <extraNonTargs> does the same operation a <extraTargs> except to the non targets.

=item B<-h>, B<--help>

Print the help.

=item B<-m>, B<--man>

Print the manual.

=item B<--version>

Print the version number.

=back

=head1 BUGS

No known bugs.

=head1 NOTES

The default iso-cost ratio coefficients (-R option) and iso-metric coefficients (-Q option) are defined into the metric.

=head1 AUTHOR

 Jonathan Fiscus <jonathan.fiscus@nist.gov>
 Jerome Ajot <jerome.ajot@nist.gov>
 Martial Michel <martial.michel@nist.gov>

=head1 VERSION

DETUtil.pl version 0.4

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut
