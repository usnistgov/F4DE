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

my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../lib", "../../../common/lib");
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
foreach my $pn ("MMisc") {
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

my $mancmd = "perldoc -F $0";
my $spc = 200; # Fine tuned on BigTest (on my laptop)
# 50=11s 100=9.97s 150=9.5s 200=9.3s 250=9.3s 300=9.55s 500=10.3s
my $chunks = 16034;
my $usage = &set_usage();

my $mrgtool = "";
my $valtool = "";
if (exists $ENV{$f4b}) {
  $valtool = $ENV{$f4b} . "/bin/TV08ViperValidator";
  $mrgtool = $ENV{$f4b} . "/bin/TV08MergeHelper";
} else {
  $valtool = "../TV08ViperValidator/TV08ViperValidator.pl";
  $mrgtool = "../TV08MergeHelper/TV08MergeHelper.pl";
}

# Default values for variables
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $writedir = undef;
my $fps = undef;
my $xmllint = "";
my $xsdpath = "";
my $verb = 1;
my $copyxmltoo = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   C         M      T V      c  fgh    m   q s uvwx    #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => \$isgtf,
   'writedir=s'      => \$writedir,
   'fps=s'           => \$fps,
   'splitevery=i'    => \$spc,
   'quiet'           => sub { $verb = 0; },
   'chunks=i'        => \$chunks,
   'ViperValidator=s' => \$valtool,
   'MergerHelper=s'  => \$mrgtool,
   'Copy_xml_too'    => \$copyxmltoo,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

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

  my $addtxt = ($copyxmltoo) ? " (and rewritten XML file)" : "";
  if (scalar @vfl > 1) {
    print $stepc++, ") Copying merged MemDump file$addtxt\n";
  } else {
    print $stepc++, ") Copying validated MemDump file$addtxt\n";
  }

  my $fvf = "$mdir/$vf";
  my $xf = "$writedir/$fn.xml";
  &copy_file($fvf, $xf)
    if ($copyxmltoo);

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

############################################################ Manual

=pod

=head1 NAME

BigXML_ValidatorHelper - TrecVid08 Big XML Files Validator Helper

=head1 SYNOPSIS

B<BigXML_ValidatorHelper> S<[--help | --man | --version]>
  S<[B<--xmllint> I<location>] [B<--TrecVid08xsd> I<location>]>
  S<[B<--ViperValidator> I<location>] [B<--MergeHelper> I<location>]>
  S<[B<--gtf>] [B<--splitevery> I<value>] [B<--chunks> I<bytes>]>
  S<[B<--quiet>] [B<--Copy_xml_too>]>
  B<--fps> I<fps> B<--writedir> I<directory>
  I<viper_source_file.xml> [I<viper_source_file.xml> [I<...>]]

=head1 DESCRIPTION

B<BigXML_ValidatorHelper> performs a syntactic and semantic validation of the ViPER XML file(s) provided on the command line, then write a MemDump version of this file into the B<writedir> directory. It can I<validate> reference files (see B<--gtf>) as well as system files. It does so by splitting large files into plenty of small files, validating those files and merging the resulting files. It does not have all the options of S<TV08ViperValidator> as it is a helper tool designed to obtain a MemDump version of large XML files. Those MemDump files can then be used in other tools reducing considerably the load time (does not have to re-validate the XML file). 

=head1 PREREQUISITES

B<BigXML_ValidatorHelper> relies on some external software and files.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<F4DE_XMLLINT> environment variable.

B<TV08ViperValidator> and B<TV08MergerHelper>, part of F4DE's TrecVid08 section are also needed as they are the core programs used. 

=item B<FILES>

The syntactic validation requires some XML schema files (full list can be obtained using the B<--help> option).
It is possible to specify their location using the B<--xsdpath> option.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

Once you have installed the software, setting B<F4DE_BASE> to the installation location, and extending your B<PATH> to include B<$F4DE_BASE/bin> should be sufficient for the tools to find their components.

=back

=back

=head1 GENERAL NOTES

B<BigXML_ValidatorHelper> expect that the files can be validated using 'xmllint' against the TrecVid08 XSD file(s) (see B<--help> for files list).

B<BigXML_ValidatorHelper> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--Copy_xml_too>

Copy source XML file to B<writedir> directory in addition to generating the I<MemDump> file.

=item B<--chunks> I<value>

Read I<value> bytes of data at a time from the source file when generating the sub files used for validation.
This influence the speed of processing of the validation process.
Default value can be obtained using B<--help>. It is recommended to not go under this value.

=item B<--fps> I<fps>

Specify the default sample rate (in frames per second) of the ViPER files.

=item B<--gtf>

Specify that the file to validate is a Reference file (also known as a Ground Truth File)

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--MergeHelper> I<location>

Specify the location of the S<TV08MergeHelper> program (used by this helper).
Default location used can be obained using B<--help>.

=item B<--man>

Display this man page.

=item B<--quiet>

Do not print processing information (default is to be verbose).

=item B<--splitevery> I<value>

Split the source file every I<value> event observation seen.
This influence the total number of files created in the validation process.
Default value can be obtained using B<--help>

=item B<--TrecVid08xsd> I<location>

Specify the default location of the required XSD files (use B<--help> to get the list of required files).

=item B<--ViperValidator> I<location>

Specify the location of the S<TV08ViperValidator> program (used by this helper).
Default location used can be obained using B<--help>.

=item B<--version>

Display B<BigXML_ValidatorHelper> version information.

=item B<--writedir> [I<directory>]

Once validation has been completed for a given file, B<BigXML_ValidatorHelper> will write the MemDump representation of this file to this directory.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<TV08_XMLLINT> environment variable.

=back

=head1 USAGE


=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut

########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--TrecVid08xsd location] [--ViperValidator location] [--MergerHelper location] [--gtf] [--splitevery value] [--chunks bytes] [--quiet] [--Copy_xml_too] --fps fps --writedir directory viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the ViPER XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable
  --TrecVid08xsd  Path where the XSD files can be found
  --ViperValidator    Location of the TV08ViperValidator tool
  --MergeHelper   Location of the TV08MergeHelper tool
  --gtf           Specify that the file to validate is a Ground Truth File
  --splitevery    Split \'viper_source_file.xml\' every \'value\' events observations (default: $spc)
  --chunks        Specify the size in \'bytes\' of the chunks of the input file being processed at a time (to generate the split version) (default: $chunks)
  --quiet         Print as little information as possible during run
  --Copy_xml_too  By default, only write MemDump to \'writedir\' directory, copy XML file too
  --writedir      Once processed in memory, print a new XML MemDump of file in this directory. Also use this directory to put all steps
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)

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
