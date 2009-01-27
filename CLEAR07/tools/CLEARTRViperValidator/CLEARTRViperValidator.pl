#!/usr/bin/env perl

# CLEAR Text Recognition Viper XML Validator
#
# Original Author(s): Martial Michel
# Modified to suit VACE/CLEAR purposes by: Vasant Manohar
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAR Text Recognition Viper XML Validator" is an experimental system.
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

my $versionid = "CLEAR Text Recognition Viper XML Validator Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $clearpl, $clearplv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "DATE_BASE";
  $f4bv = (defined $ENV{$f4b}) ? $ENV{$f4b} . "/lib": "/lib";
  $clearpl = "CLEAR_PERL_LIB";
  $clearplv = $ENV{$clearpl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "DATE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($clearplv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $clearpl and $f4depl environment variables).";
my $warn_msg = "";

# CLEARTRViperFile (part of this tool)
unless (eval "use CLEARTRViperFile; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"CLEARTRViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
  }

# CLEARTRHelperFunctions (part of this tool)
unless (eval "use CLEARTRHelperFunctions; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"CLEARTRHelperFunctions\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Sequence (part of this tool)
unless (eval "use Sequence; 1")
  {
    my $pe = &eo2pe($@);
    &_warn_add("\"Sequence\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1")
  {
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

########################################
# Get some values from CLEARTRViperFile
my $dummy = new CLEARTRViperFile();
my @ok_objects = $dummy->get_full_objects_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

########################################
# Options processing

my $xmllint_env = "CLEAR_XMLLINT";
my $xsdpath_env = "CLEAR_XSDPATH";
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0;
my $xmllint = &_get_env_val($xmllint_env, "");
my $xsdpath = &_get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $writeback = -1;
my $xmlbasefile = -1;
my $evaldomain = undef;
my $frameTol = 0;
my $MemDump = undef;
my $show = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:                    T   X        gh   l         vwx  

my %opt;
my $dbgftmp = "";
GetOptions
  (
   \%opt,
   'help',
   'version',
   "XMLbase:s"       => \$xmlbasefile,
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'gtf'             => \$isgtf,
   'Domain:s'        => \$evaldomain,
   'frameTol=i'      => \$frameTol,
   'write:s'         => \$writeback,
   'WriteMemDump:s'  => \$MemDump,
   # Hiden Option(s)
   'show_internals'  => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

if (defined $evaldomain) { 
  $evaldomain = uc($evaldomain);
  MMisc::error_quit("Unknown 'Domain'. Has to be (BN, MR, SV, UV)") if ( ($evaldomain ne "BN") && ($evaldomain ne "MR") && ($evaldomain ne "SV") && ($evaldomain ne "UV") );
  $dummy->set_required_hashes($evaldomain); 
}
else { MMisc::error_quit("'Domain' is a required argument (BN, MR, SV, UV)"); }

if ($xmlbasefile != -1) {
  my $txt = $dummy->get_base_xml($isgtf, @ok_objects);
  MMisc::error_quit("While trying to obtain the base XML file (" . $dummy->get_errormsg() . ")")
    if ($dummy->error());

  MMisc::writeTo($xmlbasefile, "", 0, 0, $txt);  

  MMisc::ok_quit($txt);
}

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'CLEARxsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

if (($writeback != -1) && ($writeback ne "")) {
  # Check the directory
  MMisc::error_quit("Provided \'write\' option directory ($writeback) does not exist")
    if (! -e $writeback);
  MMisc::error_quit("Provided \'write\' option ($writeback) is not a directory")
    if (! -d $writeback);
  MMisc::error_quit("Provided \'write\' option directory ($writeback) is not writable")
    if (! -w $writeback);
  $writeback .= "/" if ($writeback !~ m%\/$%); # Add a trailing slash
}

if (defined $MemDump) {
  MMisc::error_quit("\'WriteMemDump\' can only be used in conjunction with \'write\'")
    if ($writeback == -1);
  $MemDump = $ok_md[0]
    if (MMisc::is_blank($MemDump));
  MMisc::error_quit("Unknown \'WriteMemDump\' mode ($MemDump), authorized: " . join(" ", @ok_md))
    if (! grep(m%^$MemDump$%, @ok_md));
}

##########
# Main processing
my $tmp;
my %all = ();
my $ntodo = scalar @ARGV;
my $ndone = 0;
while ($tmp = shift @ARGV) {
  my ($ok, $object) = &load_file($isgtf, $tmp);
  next if (! $ok);

  if ($writeback != -1) {
    my $txt = $object->reformat_xml($isgtf, @ok_objects);
    MMisc::error_quit("While trying to \'write\' (" . $object->get_errormsg() . ")")
      if ($object->error());
    my $fname = "";
    if ($writeback ne "") {
      my $tmp2 = $tmp;
      $tmp2 =~ s%^.+\/([^\/]+)$%$1%;
      $fname = "$writeback$tmp2";
    } 
    MMisc::error_quit("Problem while trying to \'write\'")
      if (! MMisc::writeTo($fname, "", 1, 0, $txt, "", "** XML re-Representation:\n"));

    if (defined $MemDump) {
      MMisc::error_quit("Problem writing the \'Memory Dump\' representation of the ViperFile object")
	if (! CLEARTRHelperFunctions::save_ViperFile_MemDump($fname, $object, $MemDump));    
   
      my $eval_sequence = Sequence->new($fname);
      die "Failed scoring 'Sequence' instance creation. $eval_sequence\n"
        if (ref($eval_sequence) ne "Sequence");

      $object->reformat_ds($eval_sequence, $isgtf, @ok_objects);
      die "Could not reformat Viper File: $fname. " . $object->get_errormsg() . "\n" if ($object->error());

      MMisc::error_quit("Problem writing the 'Memory Dump' representation of the Scoring Sequence object")
	if (! CLEARTRHelperFunctions::save_ScoringSequence_MemDump($fname, $eval_sequence, $MemDump));    
    }
  }

  $all{$tmp} = $object;
  $ndone++;
}

MMisc::ok_quit("All files processed (Validated: $ndone | Total: $ntodo)\n");

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)){ 
    &valok($fname, "[ERROR] $_");
  }
}

##########

sub load_file {
  my ($isgtf, $tmp) = @_;

  my ($retstatus, $object, $msg) = 
    CLEARTRHelperFunctions::load_ViperFile($isgtf, $tmp, $evaldomain, $frameTol, $xmllint, $xsdpath);

  if ($retstatus) { # OK return
    &valok($tmp, "validates");
  } else {
    &valerr($tmp, $msg);
  }

  return($retstatus, $object);
}

########################################

sub set_usage {
  my $ro = join(" ", @ok_objects);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help] [--version] [--XMLbase [file]] [--gtf] [--xmllint location] [--CLEARxsd location] [--limitto object1[,object2[...]]] [--write [directory]] viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the Viper XML file(s) provided.

 Where:
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --limitto       Only care about provided list of objects
  --write         Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)
  --XMLbase       Print a Viper file with an empty <data> section and a populated <config> section, and exit (to a file if one provided on the command line)
  --version       Print version number and exit
  --help          Print this usage information and exit

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'CLEAR.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will disard any xml comment(s).
- List of recognized objects: $ro
- 'CLEARxsd' files are: $xsdfiles
EOF
;

  return $tmp;
}

####################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

########################################

sub _get_env_val {
  my $envv = shift @_;
  my $default = shift @_;

  my $var = $default;

  $var = $ENV{$envv} if (exists $ENV{$envv});

  return($var);
}
