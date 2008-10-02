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
# NIST assumes no responsibility whatsoever for its use by any party.
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
my ($f4b, $f4bv, $tv08pl, $tv08plv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = $ENV{$f4b} . "/lib";
  $tv08pl = "TV08_PERL_LIB";
  $tv08plv = $ENV{$tv08pl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib"; # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add
    (
     "\"Getopt::Long\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
  $have_everything = 0;
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

my $spc = 200; # Fine tuned on BigTest (on my laptop)
# 50=11s 100=9.97s 150=9.5s 200=9.3s 250=9.3s 300=9.55s 500=10.3s
my $chunks = 16034;
my $usage = &set_usage();

my $mrgtool = "../TV08MergeHelper/TV08MergeHelper.pl";
my $valtool = "./TV08ViperValidator.pl";


# Default values for variables
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $writedir = undef;
my $fps = undef;
my $xmllint = "";
my $xsdpath = "";
my $verb = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                    T V         fgh          s uvwx    #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => \$isgtf,
   'writedir=s'      => \$writedir,
   'fps=s'           => \$fps,
   'splitevery=i'    => \$spc,
   'Verbose'         => \$verb,
   'chunks=i'        => \$chunks,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'writedir\' no specified, aborting")
  if (! defined $writedir);

MMisc::error_quit("\'fps\' no specified, aborting")
  if (! defined $fps);

MMisc::error_quit("\"chunks\" ($chunks) is to be 16Kb at minimum")
  if ($chunks < 16034);

MMisc::error_quit("\"splitevery\" ($spc) is to be 50 at minimum")
  if ($spc < 50);

my $err = MMisc::check_dir_w($writedir);
MMisc::error_quit("Problem with \'writedir\': $err")
  if (! MMisc::is_blank($err));

##########
# Main processing

my $ntodo = scalar @ARGV;
my $ndone = 0;
while (my $file = shift @ARGV) {
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

  my ($vf, $md_vf) = ("", "");
  my $mdir = "$bdir/03-Merging";
  if (scalar @vfl > 1) {
    print $stepc++, ") Merging files into output files\n";

    MMisc::error_quit("Problem creating directory [$mdir]")
      if (! MMisc::make_dir($mdir));
    
    (my $err, $vf, $md_vf) = &merge_val_files($file, $mdir, $vdir, @vfl);
    if (! MMisc::is_blank($err)) {
      &valerr($file, $err);
      next;
    }
    print " - Merged files\n";
  } else {
    print "* Skipping merging step for only 1 validated file *\n";
    $vf = MMisc::concat_dir_file_ext("", $fn, $ext);
    $md_vf = $vf . ".memdump";
    $mdir = $vdir;
  }

  ##

  if (scalar @vfl > 1) {
    print $stepc++, ") Copying merged files\n";
  } else {
    print $stepc++, ") Copying validated file\n";
  }

  my $fvf = "$mdir/$vf";
  my $xf = "$writedir/$fn.xml";
  &copy_file($fvf, $xf);

  my $mfvf = "$mdir/$md_vf";
  my $mxf = $xf . ".memdump";
  &copy_file($mfvf, $mxf);

  print "Results:\n - $xf\n - $mxf\n";

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
  my $odir = shift @_;
  my $file = shift @_;
  
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

    if ($slurp =~ s%(\<object\s.+?\<\/object\>)%%s) {
      $txt .= "$1\n";
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

  foreach my $file (@fl) {
    my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($file);
    return($err)
      if (! MMisc::is_blank($err));
    
    my $logfile = "$odir/$fn.log";

    my $cmd = $valtool;
    $cmd .= " -g" if ($isgtf);
    $cmd .= " -w $odir -W text ";
    $cmd .= MMisc::concat_dir_file_ext($sfdir, $fn, $ext);

    my ($rv, $tx, $so, $se, $retcode, $logfile)
      = MMisc::write_syscall_smart_logfile($logfile, $cmd);

    return("Problem validating file [$file] -- see: $logfile")
      if ($retcode != 0);
    &vprint("    -> Validated [$file]\n");
  }

  my @dl = MMisc::get_files_list($odir);
  my @vfl = grep(m%\.memdump$%, @dl);

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
  $cmd .= " -w $odir -W text -k -f $fps -n ";
  $cmd .= $vfl;

  my ($rv, $tx, $so, $se, $retcode, $logfile)
    = MMisc::write_syscall_smart_logfile($logfile, $cmd);

  return("Problem Merging file -- see: $logfile")
    if ($retcode != 0);

  my @dl = MMisc::get_files_list($odir);
  my @mfl = sort grep(! m%\.log$%, @dl);

  return("Found different than two files in directory [$odir]: " . join(" ", @mfl))
    if (scalar @mfl != 2);;

  my $vf = shift @mfl;
  my $md_vf = shift @mfl;

  return("", $vf, $md_vf);
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

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--TrecVid08xsd location] [--gtf] [--splitevery value] [--chunks bytes] [--symlink] [--Verbose] --fps fps --writedir directory viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the ViPER XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable
  --TrecVid08xsd  Path where the XSD files can be found
  --gtf           Specify that the file to validate is a Ground Truth File
  --writedir      Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)

EOF
    ;

    return $tmp;
}
