#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# Big XML Files Validator Helper
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Big XML Files Validator Helper" is an experimental system.
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
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "Big XML Files Validator Helper Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../lib", "$f4d/../../../CLEAR07/lib", "$f4d/../../../common/lib");
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
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "MtXML") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

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

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################

my $spc = 5; 
my $chunks = 128272;
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $frameTol = 0;
my $mrgtool = "";
my $valtool = "";
if (exists $ENV{$f4b}) {
  $valtool = $ENV{$f4b} . "/bin/AVSS09ViperValidator";
  $mrgtool = $ENV{$f4b} . "/bin/AVSS09Merger";
} else {
  $valtool = dirname(abs_path($0)) . "/../AVSS09ViperValidator/AVSS09ViperValidator.pl";
  $mrgtool = dirname(abs_path($0)) . "/../AVSS09Merger/AVSS09Merger.pl";
}
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $writedir = undef;
my $xmllint = "";
my $xsdpath = "";
my $verb = 1;
my $copyxmltoo = 0;
my $doseq = 0;
my $MemDump = $ok_md[0];

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   C         M     ST VWX    c  fgh    m   q s uvwx    #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'gtf'             => \$isgtf,
   'frameTol=i'      => \$frameTol,
   'writedir=s'      => \$writedir,
   'WriteMemDumpMode=s'  => \$MemDump,
   'splitevery=i'    => \$spc,
   'quiet'           => sub { $verb = 0; },
   'chunks=i'        => \$chunks,
   'ViperValidator=s' => \$valtool,
   'MergerHelper=s'  => \$mrgtool,
   'Xml_copy_too'    => \$copyxmltoo,
   'SequenceMemDump' => \$doseq,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'writedir\' no specified, aborting")
  if (! defined $writedir);

MMisc::error_quit("Unknown \'WriteMemDumpMode\' value ($MemDump), authorized: " . join(" ", @ok_md))
  if (! grep(m%^$MemDump$%, @ok_md));

MMisc::error_quit("\"chunks\" ($chunks) is to be 16Kb at minimum")
  if ($chunks < 16034);

MMisc::error_quit("\"splitevery\" ($spc) is to be 2 at minimum")
  if ($spc < 2);

my $err = MMisc::check_dir_w($writedir);
MMisc::error_quit("Problem with \'writedir\': $err")
  if (! MMisc::is_blank($err));

##########
# Main processing

my $vmd_ext = "VFmemdump";
my $smd_ext = "SSmemdump";

my $ntodo = scalar @ARGV;
my $ndone = 0;
for (my $fi = 0; $fi < scalar @ARGV; $fi++) {
  my $file = $ARGV[$fi];
  print "\n** $file\n";

  my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($file);
  &valerr($file, $err)
    if (! MMisc::is_blank($err));

  my $bdir = "$writedir/$fn.ValidatorHelper";
  `rm -rf $bdir`
    if (-d $bdir);

  my $stepc = 1;
  
  ##

  print $stepc++, ") Creating one XML file per $spc events\n";

  my $sfdir = "$bdir/01-Split_files";
  MMisc::error_quit("Problem creating directory [$sfdir]")
      if (! MMisc::make_dir($sfdir));

  my ($err, @fl) = &prep_sub_files($sfdir, $file);
  if (! MMisc::is_blank($err)) {
    &valerr($file, $err);
    next;
  }
  print " - Created ", scalar @fl, " files\n";
  MMisc::error_quit("No file created ?")
    if (scalar @fl == 0);

  ##

  my $vdir = "$bdir/02-Validation";
  MMisc::error_quit("Problem creating directory [$vdir]")
      if (! MMisc::make_dir($vdir));

  if (scalar @fl == 1) {
    print $stepc++, ") Only one file created, validating source file\n";
    $sfdir = $dir;
    @fl = ();
    push @fl, MMisc::concat_dir_file_ext("", $fn, $ext);
  } else {
    print $stepc++, ") Validating each file\n";
  }

  my ($err, @vfl) = &validate_sub_files($vdir, $sfdir, @fl);
  if (! MMisc::is_blank($err)) {
    &valerr($file, $err);
    next;
  }
  MMisc::error_quit("No Validated file ?")
    if (scalar @vfl == 0);
  print " - Validated ", scalar @vfl, " files\n"
    if (scalar @vfl > 1);

  ##

  my ($vf, $md_vf, $md_ss) = ("", "");
  my $mdir = "$bdir/03-Merging";
  if (scalar @vfl > 1) {
    print $stepc++, ") Merging files into output files\n";

    MMisc::error_quit("Problem creating directory [$mdir]")
      if (! MMisc::make_dir($mdir));
    
    (my $err, $vf, $md_vf, $md_ss) 
      = &merge_val_files($file, $mdir, $vdir, @vfl);
    if (! MMisc::is_blank($err)) {
      &valerr($file, $err);
      next;
    }
    print " - Merged files\n";
  } else {
    print "* Skipping merging step for only 1 validated file *\n";
    $vf = MMisc::concat_dir_file_ext("", $fn, $ext);
    $md_vf = $vf . ".$vmd_ext";
    $md_ss = $vf . ".$smd_ext";
    $mdir = $vdir;
  }

  ##

  my $addtxt = ($copyxmltoo) ? " (and rewritten XML file)" : "";
  if (scalar @vfl > 1) {
    print $stepc++, ") Copying merged MemDump file(s)$addtxt\n";
  } else {
    print $stepc++, ") Copying validated MemDump file(s)$addtxt\n";
  }

  my $fvf = "$mdir/$vf";
  my $xf = "$writedir/$fn.xml";
  &copy_file($fvf, $xf)
    if ($copyxmltoo);

  my $mfvf = "$mdir/$md_vf";
  my $mxf = $xf . ".$vmd_ext";
  &copy_file($mfvf, $mxf);

  my $mfss = "$mdir/$md_ss";
  my $sxf = $xf . ".$smd_ext";
  &copy_file($mfss, $sxf) if ($doseq);

  print "Results:\n - $xf\n - $mxf\n";
  print " - $sxf\n" if ($doseq);

  $ndone++;
}
print "All files processed (Done: $ndone | Total: $ntodo)\n\n";
MMisc::error_exit()
  if ($ndone != $ntodo);

MMisc::ok_exit();

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)) { 
    &valok($fname, "[ERROR] $_");
  }
}

####################

sub prep_sub_files {
  my ($odir, $file) = @_;
  
  my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($file);
  return($err)
    if (! MMisc::is_blank($err));

  my $slurped = MMisc::slurp_file($file);
  if (! defined $slurped) {
    return("Problem loading file, skipping");
    next;
  }

  my $trailer = "";
  my $slurp = substr($slurped, -$chunks, $chunks, "");
  $trailer = $1 if ($slurp =~ s%(\<\/sourcefile\>.+$)%%s);
  return("Could not get file trailer")
    if (MMisc::is_blank($trailer));
  $slurped .= $slurp;

  my $header = "";
  my $slurp = substr($slurped, 0, $chunks, "");
  $header = $1 if ($slurp =~ s%^(.+?\<\/file\>)%%s);
  return("Could not get file header")
    if (MMisc::is_blank($header));

  my $k_obj = "object";
  my $k_err = "MtXML_ERROR";

  # Also need the I-FRAMES and FRAMES
  # slower: we need to find it in the entire 'slurped'
  # but we only have to do it once for each "object"
  my $inf = "";

  $inf = MtXML::get_named_xml_section_with_inline_content($k_obj, "I-FRAMES", \$slurped, $k_err);
  return("Could not find \"I-FRAMES\"")
    if ($inf eq $k_err);
  $header .= $inf;

  $inf = MtXML::get_named_xml_section_with_inline_content($k_obj, "FRAME", \$slurped, $k_err);
  return("Could not find \"FRAME\"")
    if ($inf eq $k_err);
  $header .= $inf;

  # Process the rest of the objects
  my $inc = 0;
  my $count = 0;
  my $txt = "\n";
  my @fl = ();
  my $doit = 1;
  while ($doit) {
    if ((length($slurp) < $chunks) && (length($slurped) > 0)) {
      # A little cleanup before loading more data
      $slurp =~ s%^[\s\t\n\r]+%%s;
      $slurp .= substr($slurped, 0, $chunks, "");
    }

    if (MMisc::is_blank($slurp)) {
      $doit = 0;
      next;
    }

    my $inf = MtXML::get_named_xml_section($k_obj, \$slurp, $k_err);
    if ($inf ne $k_err) {
      $txt .= "$inf\n";
      $count++;
    } else {
      my $tf = "$odir/$fn.bad";
      MMisc::writeTo($tf, "", 0, 0, "[$slurp]");
      return("Could not find an \"object\" section, but file is not empty. See \"$tf\" for leftover content (content encapsulated within [])");
    }

    if ($count >= $spc) {
      my $tf = MMisc::concat_dir_file_ext($odir, sprintf("${fn}_%06d", ++$inc), $ext);
      MMisc::writeTo($tf, "", $verb, 0, $header . $txt . $trailer);
      push @fl, $tf;
      $txt = "\n";
      $count = 0;
    }

  }

  if ($count > 0) {
    my $tf = MMisc::concat_dir_file_ext($odir, sprintf("${fn}_%06d", ++$inc), $ext);
    MMisc::writeTo($tf, "", $verb, 0, $header . $txt . $trailer);
    push @fl, $tf;
    $txt = "";
    $count = 0;
  }
    
  return("", @fl);
}

####################

sub validate_sub_files {
  my ($odir, $sfdir, @fl) = @_;

  my $forceSeq = 0;
  $forceSeq = 1 if ((scalar @fl == 1) && ($doseq));

  foreach my $file (@fl) {
    my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($file);
    return($err)
      if (! MMisc::is_blank($err));
    
    my $logfile = "$odir/$fn.log";

    my $cmd = $valtool;
    $cmd .= " -g" if ($isgtf);
    $cmd .= " -f $frameTol" if ($frameTol);
    $cmd .= " -w $odir -W $MemDump";
    $cmd .= " -s " if (! $forceSeq);
    $cmd .= MMisc::concat_dir_file_ext($sfdir, $fn, $ext);

    my ($rv, $tx, $so, $se, $retcode, $logfile)
      = MMisc::write_syscall_smart_logfile($logfile, $cmd);

    return("Problem validating file [$file] -- see: $logfile")
      if ($retcode != 0);
    &vprint("    -> Validated [$file]\n");
  }

  my @dl = MMisc::get_files_list($odir);
  my @vfl = grep(m%\.$vmd_ext$%, @dl);

  return("Found a different amount of output files (" . scalar @vfl . ") from the number of input file (" . scalar @fl . ")")
    if (scalar @vfl != scalar @fl);

  return("", @vfl);
}

####################

sub merge_val_files {
  my ($ffnb, $odir, $vdir, @fl) = @_;

  my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($ffnb);
  return($err)
    if (! MMisc::is_blank($err));

  my $vfl = "";
  foreach my $file (@fl) {
    $vfl .= "$vdir/$file ";
  }    
  
  my $logfile = "$odir/$fn.log";

  my $cmd = $mrgtool;
  $cmd .= " -g" if ($isgtf);
  $cmd .= " -f $frameTol " if ($frameTol);
  $cmd .= " -w $odir -W $MemDump ";
  $cmd .= " -s " if (! $doseq);
  $cmd .= $vfl;

  my ($rv, $tx, $so, $se, $retcode, $logfile)
    = MMisc::write_syscall_smart_logfile($logfile, $cmd);

  return("Problem Merging file -- see: $logfile")
    if ($retcode != 0);

  my @dl = MMisc::get_files_list($odir);
  my @mfl = sort grep(! m%\.log$%, @dl);

  my $efn = ($doseq) ? 3 : 2;
  return("Found different than $efn files in directory [$odir]: " . join(" ", @mfl))
    if (scalar @mfl != $efn);;

  my $vf = shift @mfl;
  my $md_ss = "";
  $md_ss = shift @mfl if ($doseq);
  my $md_vf = shift @mfl;

  return("", $vf, $md_vf, $md_ss);
}

##########

sub vprint {
  return() if (! $verb);

  print @_;
}

##########

sub copy_file {
  my ($a, $b) = @_;

  my $cmd = "cp $a $b";
  my ($rc, $so, $se) = MMisc::do_system_call($cmd);
  MMisc::error_quit("Could not copy [$a] to [$b]: $se")
    if ($rc != 0);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

########################################

sub set_usage {
  my $wmd = join(" ", @ok_md);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--CLEARxsd location] [--ViperValidator location] [--MergerHelper location] [--gtf] [--splitevery value] [--chunks bytes] [--quiet] [--Xml_copy_too] [--WriteMemDumpMode mode] [--SequenceMemDump] [--frameTol framenbr] --writedir directory viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the ViPER XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable
  --CLEARxsd      Path where the XSD files can be found
  --ViperValidator    Location of the AVSS09ViperValidator tool
  --MergeHelper   Location of the AVSS09Merger tool
  --gtf           Specify that the file to validate is a Ground Truth File
  --splitevery    Split \'viper_source_file.xml\' every \'value\' events observations (default: $spc)
  --chunks        Specify the size in \'bytes\' of the chunks of the input file being processed at a time (to generate the split version) (default: $chunks)
  --quiet         Print as little information as possible during run
  --Xml_copy_too  By default, only write MemDump to \'writedir\' directory, copy XML file too
  --WriteMemDumpMode  Select MemDump mode. Two modes possible: $wmd (1st default)
  --SequenceMemDump  Generate MemDump of Sequence files (useful for scoring)
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default: $frameTol)
  --writedir      Once processed in memory, print a new XML MemDump of file in this directory. Also use this directory to put all steps

Note:
- Program will ignore the <config> section of the XML file.
- Program will discard any xml comment(s).
- By default will try to use:
$valtool
$mrgtool
EOF
    ;

    return $tmp;
}
