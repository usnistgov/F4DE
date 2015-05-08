#!/usr/bin/env perl
#
# $Id$
#
# AVSS ViPER Files to CLEAR ViPER Files converter and analyzer
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAR Detection and Tracking Viper XML Validator" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../CLEAR07/lib", "$f4d/../../../common/lib");
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
foreach my $pn ("MMisc", "AVSStoCLEAR", "CSVHelper") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "AVSS09 ViPER Files to CLEAR ViPER Files converter and analyzer ($versionkey)";

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long") {
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

use strict;

########################################

my $usage = &set_usage();

my $dosys = 0;
my $doStarterSys = 0;
my $doEmptySys = 0;
my $ifgap = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:     E   I         S              h          s         #

my %opt;
GetOptions
  (
   \%opt,
   'help',
   'sys'          => \$dosys,
   'StarterSys'   => \$doStarterSys,
   'EmptySys'     => \$doEmptySys,
   'IFramesGap=i' => \$ifgap,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("Not enough arguments\n$usage\n") if (scalar @ARGV != 2);

MMisc::error_quit("\'sys\', \'StarterSys\' or \'EmptySys\' can not be used at the same time\n$usage")
  if ($dosys + $doStarterSys + $doEmptySys > 1);

MMisc::error_quit("Invalid \'IFramesGap\' value [$ifgap], must be positive and not equal to zero\n$usage")
  if ($ifgap < 1);

my ($in, $out) = @ARGV;

MMisc::error_quit("No input_dir provided.\n $usage")
  if (MMisc::is_blank($out));
MMisc::error_quit("No output_dir provided.\n $usage")
  if (MMisc::is_blank($out));

my $err = MMisc::check_dir_r($in);
MMisc::error_quit("input_dir problem: $err")
  if (! MMisc::is_blank($err));

my $err = MMisc::check_dir_w($out);
MMisc::error_quit("output_dir problem: $err")
  if (! MMisc::is_blank($err));

my @fl = MMisc::get_files_list($in);
MMisc::error_quit("No files in input_dir\n")
  if (scalar @fl == 0);

my $avcl = new AVSStoCLEAR();
my @keys = ();

foreach my $file (sort @fl) {
  my $ff = "$in/$file";
  print "\n--------------------\n### FILE: $ff\n";
  my $off = "$out/$file";
  open OUT, ">$off"
    or MMisc::error_quit("Problem creating output file [$off]: $!");

  my ($ok, $res) = $avcl->load_ViPER_AVSS($ff, $ifgap);
  MMisc::error_quit($avcl->get_errormsg())
      if ($avcl->error());
  MMisc::error_quit("\'load_ViPER_AVSS\' did not complete succesfully")
      if (! $ok);
  print $res;

  my $xmlc = "";
  my $tag = "";
  if ($dosys) {
    $xmlc = $avcl->create_CLEAR_SYS_ViPER($ff);
    $tag = "SYS";
  } elsif ($doStarterSys) {
    $xmlc = $avcl->create_CLEAR_StarterSYS_ViPER($ff);
    $tag = "StarterSYS";
  } elsif ($doEmptySys) {
    $xmlc = $avcl->create_CLEAR_EmptySYS_ViPER($ff);
    $tag = "EmptySYS";
  } else {
    $xmlc = $avcl->create_CLEAR_ViPER($ff);
    $tag = "GTF";
  }
  MMisc::error_quit($avcl->get_errormsg())
      if ($avcl->error());
  MMisc::error_quit("\'create_CLEAR_ViPER\' did not create any XML")
      if (MMisc::is_blank($xmlc));
  print OUT $xmlc;
  close OUT;
  print "\n==> Wrote [$tag] : $off\n";

  push @keys, $ff;
}

MMisc::ok_quit("SYS or StarterSys requested, not performing additional analysis\n")
  if (($dosys) || ($doStarterSys));

####################

print "\nCamera list:\n";
foreach my $key (@keys) {
  my $cid = $avcl->get_cam_id($key);
  MMisc::error_quit("Problem getting camera ID information: " . $avcl->get_errormsg())
      if ($avcl->error());
  print "|-> Camera $cid -- Associated file: $key\n";
}

#####

print "\nUsable pairs:\n";
foreach my $key1 (@keys) {
  my $cid1 = $avcl->get_cam_id($key1);
  MMisc::error_quit("Problem getting camera ID information: " . $avcl->get_errormsg())
      if ($avcl->error());
  print "* Camera $cid1\n";
  foreach my $key2 (@keys) {
    next if ($key1 eq $key2);

    my $cid2 = $avcl->get_cam_id($key2);
    MMisc::error_quit("Problem getting camera ID information: " . $avcl->get_errormsg())
        if ($avcl->error());
    
    my $rcomp = $avcl->get_comparables($key1, $key2);
    MMisc::error_quit("Problem while obtaining comparables: " . $avcl->get_errormsg())
        if ($avcl->error());

    if (! defined $rcomp) {
      print "|-> Camera $cid2 : NONE\n";
      next;
    }

    print "|-> Camera $cid2 : YES\n";
    foreach my $id (sort _num keys %$rcomp) {
      my $ov = $$rcomp{$id};
      print "|   |-> ID: $id / Overlap (short form): $ov\n"; 
    }
  }
  print "|\n";
}

####################

print "\nOrder of appearance:\n";
my ($rresk, $rresbf) = $avcl->get_appear_order(@keys);
MMisc::error_quit("Problem while obtaining order of appearance: " . $avcl->get_errormsg())
  if ($avcl->error());

my %cam_seqstr = ();
foreach my $id (sort _num keys %$rresk) {
  print "* ID: $id\n";
  $cam_seqstr{$id} .= "";

  my $inc = 0;
  for (my $i = 0; $i < scalar @{$$rresk{$id}}; $i++) {
    my $key = ${$$rresk{$id}}[$i];
    my $cid = $avcl->get_cam_id($key);
    MMisc::error_quit("Problem getting camera ID information: " . $avcl->get_errormsg())
        if ($avcl->error());
    printf("  %02d ) Camera %d [beginning frame: %d]\n",
           1 + $i, $cid , ${$$rresbf{$id}}[$i]);
    $cam_seqstr{$id} .= "$cid ";
  }

  $cam_seqstr{$id} =~ s%\s$%%;
}

####################

print "\nGenerate CSV\n";

my $of = "$out/setdetails.csv";
open OFILE, ">$of"
  or MMisc::error_quit("Could not create CSV file [$of] : $!");

my @header = ();
push @header, "Directory", "File ID", "Excerpt Set", "Camera ID";

my $csvh = new CSVHelper();
MMisc::error_quit($csvh->get_errormsg())
  if ($csvh->error());

my @idl = sort _num keys %$rresk;

my @clip_headers = ();
my @obj_headers  = ();
my @ooa = ();
my $wrote_header = 0;
foreach my $key (sort @keys) {
  my @content_hd = ();

  {
    my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($key);
    MMisc::error_quit("Problem splitting file into dir/file/ext [$key] : $err")
        if (! MMisc::is_blank($err));
    $dir =~ s%\/$%%;
    my $set = $dir;
    $set =~ s%^.+/%%;
    push @content_hd, $dir, MMisc::concat_dir_file_ext("", $file, $ext), $set;
  }

  my $cid = $avcl->get_cam_id($key);
  MMisc::error_quit("Problem obtaining camera ID :" . $avcl->get_errormsg())
      if ($avcl->error());
  push @content_hd, $cid;

  if (scalar @clip_headers == 0) {
    @clip_headers = $avcl->get_clip_csv_data_headers($key);
    MMisc::error_quit("Problem getting clip CSV data headers :" . $avcl->get_errormsg())
        if ($avcl->error());
    push @header, @clip_headers;
  }

  my @values = $avcl->get_clip_csv_data($key);
  MMisc::error_quit("Problem getting clip CSV data headers :" . $avcl->get_errormsg())
      if ($avcl->error());
  push @content_hd, @values;

  foreach my $id (@idl) {
    my @content_id = ();

    if (scalar @obj_headers == 0) {
      @obj_headers = $avcl->get_obj_csv_data_headers($key);
      MMisc::error_quit("Problem getting object CSV data headers :" . $avcl->get_errormsg())
          if ($avcl->error());
      push @header, @obj_headers;
    }

    my @values = $avcl->get_obj_csv_data($key, $id);
    MMisc::error_quit("Problem getting object CSV data headers :" . $avcl->get_errormsg())
        if ($avcl->error());
    push @content_id, @values;
    
    # Order of appearance
    if (scalar @ooa == 0) {
      push @ooa, "Order of Appearance", "Camera Sequence";
      push @header, @ooa;
    }
    my $res = "Never";
    for (my $i = 0; $i < scalar @{$$rresk{$id}}; $i++) {
      my $in = ${$$rresk{$id}}[$i];
      $res = 1 + $i if ($key eq $in);
    }
    push @content_id, $res;
    push @content_id, $cam_seqstr{$id};

    if (! $wrote_header) {
      $csvh->set_number_of_columns(scalar @header);
      MMisc::error_quit($csvh->get_errormsg())
          if ($csvh->error());
      my $line = $csvh->array2csvline(@header);
      MMisc::error_quit($csvh->get_errormsg())
          if ($csvh->error());
      MMisc::error_quit("Problem creating CSV header")
          if (! defined $line);
      print OFILE $line . "\n";
      $wrote_header = 1;
    }

    my @content = ();
    push @content, @content_hd;
    push @content, @content_id;

    MMisc::error_quit("Different number of columns in data (" . scalar @content . ") than in header (" . scalar @header . "), refusing to write")
        if (scalar @header != scalar @content);

    my $line = $csvh->array2csvline(@content);
    MMisc::error_quit($csvh->get_errormsg())
        if ($csvh->error());
    MMisc::error_quit("Problem creating CSV content")
        if (! defined $line);
    print OFILE $line . "\n";
  }
}
close OFILE;
print " => Wrote set CSV file: $of\n";

MMisc::ok_quit("\nDone\n");

############################################################

sub _num { $a <=> $b; }

#####

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

########################################

sub set_usage {
  my $tmp=<<EOF

$versionid

$0 [--help] --IFramesGap gap [--sys | --StarterSys | --EmptySys] input_dir output_dir

Convert all the files within the input_dir directory from AVSS to CLEAR ViPER files (by default, a Ground Truth File).

For GTF, also print some details on files seen within this fileset such as camera information, associated file, PERSON (target) information, order of appearance of target in cameras, and will also generate a CSV file with these data.

Where:
  --help          Print this usage information and exit
  --IFramesGap    Specify the gap between I-Frames and Annotated frames
  --sys           Generate a CLEAR ViPER system file
  --StarterSys    Generate a CLEAR ViPER Starter sys file (only contains the first five non occluded bounding boxes)
  --EmptySys      Generate a CLEAR ViPER system file with no person defintion

EOF
;

  return($tmp);
}
