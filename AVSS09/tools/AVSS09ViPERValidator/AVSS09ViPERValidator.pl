#!/usr/bin/env perl

# AVSS09 ViPER File Validator
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS09 ViPER XML Validator" is an experimental system.
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

my $versionid = "AVSS09 ViPER XML Validator Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $avpl, $avplv, $clearpl, $clearplv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = (defined $ENV{$f4b}) ? $ENV{$f4b} . "/lib": "/lib";
  $avpl = "AVSS09_PERL_LIB";
  $avplv = $ENV{$avpl} || "../../lib";
  $clearpl = "CLEAR_PERL_LIB";
  $clearplv = $ENV{$clearpl} || "../../../CLEAR07/lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($avplv, $clearplv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $avpl, $clearpl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"AVSS09ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# AVSS09ViperFile (part of this tool)
unless (eval "use AVSS09ViperFile; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"AVSS09ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add("\"Getopt::Long\" is not available on your Perl installation. ",
             "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n");
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
# Options processing

my $xmllint_env = "CLEAR_XMLLINT";
my $xsdpath_env = "CLEAR_XSDPATH";
my $mancmd = "perldoc -F $0";
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $frameTol = 0;
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0;
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../../CLEAR07/data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../../CLEAR07/data"));
my $show = 0;
my $forceFilename = "";
my $writeback = -1;
my $MemDump = undef;
my $skipScoringSequenceMemDump = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   C  F                W        fgh          s  vwx    #

my %opt;
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
   'ForceFilename=s' => \$forceFilename,
   'write:s'         => \$writeback,
   'WriteMemDump:s'  => \$MemDump,
   'skipScoringSequenceMemDump' => \$skipScoringSequenceMemDump,
   # Hiden Option(s)
   'X_show_internals'  => \$show,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::error_quit("Not enough arguments\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'ForceFilename\' option selected but no value set\n$usage")   if (($opt{'ForceFilename'}) && (MMisc::is_blank($forceFilename)));

if (($writeback != -1) && ($writeback ne "")) {
  # Check the directory
  my ($err) = MMisc::check_dir_w($writeback);
  MMisc::error_quit("Provided \'write\' option directory ($writeback): $err")
    if (! MMisc::is_blank($err));
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

MMisc::error_quit("\'skipScoringSequenceMemDump\' can only be used if \'MemDump\' is selected")
if (($skipScoringSequenceMemDump) && (! defined $MemDump));
  
##############################
# Main processing
my $ntodo = scalar @ARGV;
my $ndone = 0;
foreach my $tmp (@ARGV) {
  my ($err, $fname, $fsshift, $idadd, @boxmod) = 
    AVSS09ViperFile::extract_transformations($tmp);
  MMisc::error_quit("While processing filename ($tmp): $err")
      if (! MMisc::is_blank($err));

  my ($ok, $object) = &load_file($isgtf, $fname);
  next if (! $ok);

  if ($show) {
    print "** [Before mods]\n";
    print $object->_display_all();
  }

  # Do the transformations here
  my $mods = $object->Transformation_Helper($forceFilename, $fsshift, $idadd, @boxmod);
  MMisc::error_quit("Problem during \"transformations\": " . $object->get_errormsg())
      if ($object->error());

  ## DCx test code would go here...

  if ($mods && $show) {
    print "** [After Mods]\n";
    print $object->_display_all();
  }

  if ($writeback != -1) {
    my ($txt) = $object->reformat_xml($isgtf);
    MMisc::error_quit("While trying to \'write\' (" . $object->get_errormsg() . ")")
      if ($object->error());
    my $lfname = "";
    if ($writeback ne "") {
      my $tmp2 = $fname;
      $tmp2 =~ s%^.+\/([^\/]+)$%$1%;
      $lfname = "$writeback$tmp2";
    } 
    MMisc::error_quit("Problem while trying to \'write\'")
      if (! MMisc::writeTo($lfname, "", 1, 0, $txt, "", "** XML re-Representation:\n"));

    if (defined $MemDump) {
      $object->write_MemDumps($lfname, $isgtf, $MemDump, $skipScoringSequenceMemDump);
      MMisc::error_quit("Problem while trying to perform \'MemDump\'")
          if ($object->error());
    }
  }

  $ndone++;
}

print("All files processed (Validated: $ndone | Total: $ntodo)\n");

MMisc::error_quit("Not all files processed succesfuly") if ($ndone != $ntodo);
MMisc::ok_quit("\nDone\n");

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
    AVSS09ViperFile::load_ViperFile($isgtf, $tmp, $frameTol, $xmllint, $xsdpath);

  if ($retstatus) { # OK return
    &valok($tmp, $msg . (MMisc::is_blank($msg) ? "validates" : ""));
  } else {
    &valerr($tmp, $msg);
  }

  return($retstatus, $object);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

############################################################ Manual

=pod

=head1 NAME

AVSS09ViperValidator - AVSS09 ViPER XML Validator

=head1 SYNOPSIS

B<AVSS09ViperValidator> S<[ B<--help> | B<--man> | B<--version> ]>
  S<[B<--xmllint> I<location>] [B<--CLEARxsd> I<location>]>
  S<[B<--gtf>] [B<--frameTol> I<framenbr>]>
  S<[[B<--write> [I<directory>]]>
  S<[B<--WriteMemDump> [I<mode>] [B<--skipScoringSequenceMemDump>]]]>
  S<[B<--ForceFilename> I<filename>]>
  S<I<viper_source_file.xml>[I<transformations>]>
  S<[I<viper_source_file.xml>[I<transformations>] [I<...>]>
  
=head1 DESCRIPTION

B<AVSS09ViperValidator> performs a syntactic and semantic validation of the ViPER XML file(s) provided on the command line. It can I<validate> reference files (see B<--gtf>) as well as system files. It can also rewrite validated files into another directory using the same filename as the original (see B<--write>), write a I<memory representation> of the ViPER file post validation (to fasten reload time), as well as a I<Scoring Sequence> I<memory representation> to be used for scoring.

=head1 PREREQUISITES


B<AVSS09ViperValidator> relies on some external software and files, most of which associated with the B<CLEAR> section of B<F4DE>.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<CLEAR_XMLLINT> environment variable.

=item B<FILES>

The syntactic validation requires some XML schema files (see the B<CLEARDTScorer> help section for a list of the required files).
It is possible to specify their location using the B<--xsdpath> option or the B<CLEAR_XSDPATH> environment variable.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

B<AVSS09ViperValidator> relies on some internal and external Perl libraries to function.

Simply running the B<AVSS09ViperValidator> script should provide you with the list of missing libraries. 
The following environment variables should be set in order for Perl to use the B<F4DE> libraries:

=over

=item B<F4DE_BASE>

The main variable once you have installed the software, it should be sufficient to run this program.

=item B<F4DE_PERL_LIB>

Allows you to specify a different directory for the B<F4DE> libraries.

=item B<AVSS09_PERL_LIB>

Allows you to specify a different directory for the B<AVSS09> libraries.

=item B<CLEAR_PERL_LIB>

Allows you to specify a different directory for the B<CLEAR> libraries.

=back

=back

=head1 GENERAL NOTES

B<AVSS09ViperValidator> expects that the files can be validated using 'xmllint' against the B<CLEAR> XSD file(s) (see B<--help> for files list).

B<AVSS09ViperValidator> will use the core validation of the B<CLEAR> code and add some specialized checks associated with the B<AVSS09> evaluation.

=head1 OPTIONS

=over

=item B<--CLEARxsd> I<location>

Specify the default location of the required XSD files.
Can also be set using the B<CLEAR_XSDPATH> environment variable.

=item B<--ForceFilename> I<file>

Replace the I<sourcefile>'s I<filename> value by I<file>.

=item B<--frameTol> I<framenbr>

The frame tolerance allowed for attributes to be outside of the object framespan

=item B<--gtf>

Specify that the files to validate are Reference files (also known as a Ground Truth Files)

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--man>

Display this man page.

=item B<--skipScoringSequenceMemDump>

Do not generate the I<Scoring Sequence> memory representation when generating the validated ViPER file memory representation.
This representation can be used by the scoring program.

=item B<--version>

Display B<AVSS09ViperValidator> version information.

=item B<--write> [I<directory>]

Once validation has been completed for a given file, B<AVSS09ViperValidator> will write a new XML representation of this file to either the standard output (if I<directory> is not set), or will create a file with the same name as the input file in I<directory> (if specified).

=item B<--WriteMemDump> [I<mode>]

Write to disk a memory representation of the validated ViPER File.
This memory representation file can be used as the input of other AVSS09 tools.
The mode is the file representation to disk and its values and its default can be obtained using the B<--help> option.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<CLEAR_XMLLINT> environment variable.

=back

=head1 TRANSFORMATIONS

Transformations are an easy way to influence the content of the ViPER file.

Syntax: S<[:B<FSshift>][@B<BBmod>][#B<IDadd>]>

=over

=item B<FSshift>

It is the number of frames to add or substract from every framespan within the specified file.

=item B<BBmod>

It is the I<bounding box> modifications of the form S<I<X>+I<Y>xI<M>>, where I<X> and I<Y> add or substract and I<M> multiply.

=item B<IDadd>

It is the number of ID to add or substract to every PERSON ID seen within the specified file.

=back

=head1 USAGE

=item B<AVSS09ViperValidator --xmllint /local/bin/xmllint --TrecVid08xsd /local/F4DE-CVS/data sys_test1.xml>

Will try to validate the I<system> file I<sys_test1.xml> using the I<xmllint> executable located at I</local/bin/xmllint> and the required XSD files found in the I</local/F4DE/data> directory.

=item B<AVSS09ViperValidator --gtf ref_test1.xml:100@-10+20x0.5#5 ref_test2.xml --frameTol 5 --write /tmp --WriteMemDump text>

Will try to validate the I<reference> files I<ref_test1.xml> and I<ref_test2.xml> using a tolerance of 5 frames for attributes to be ouside of the object framespan.
For I<ref_test1.xml>, it will also add 100 frames to each framespan found within the file, modify the I<bounding box> by substracting 10 from each X coordinate, adding 20 to each Y, and multiplying each resulting coordinate by 0.5, and add 5 to each object ID seen. 
It will then write to the I</tmp> directory a XML rewrite of both files, as well as a ViPER file memory represenation (in text format) and a scoring sequence memory representation.

=item B<AVSS09ViperValidator sys_test1.xml sys_test2.xl --ForceFilename ff.xml --write /tmp --WriteMemDump gzip --skipScoringSequenceMemDump>

Will try to validate the I<system> files I<sys_test1.xml> and I<sys_test2.xml>, changing for files the I<sourcefile filename> within to I<ff.xml>.
Then write into the I</tmp> directory both files and their ViPER file memory represenation (in compressed format, to save some disk space). 

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=cut

########################################

sub set_usage {
  my $wmd = join(" ", @ok_md);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --man | --version] [--xmllint location] [--CLEARxsd location] [--gtf] [--frameTol framenbr] [--write [directory] [--WriteMemDump [mode] [--skipScoringSequenceMemDump]] [--ForceFilename file] viper_source_file.xml[transformations] [viper_source_file.xml[transformations] [...]]

Will perform a semantic validation of the AVSS09 Viper XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default: $frameTol)
  --ForceFilename  Specify that all files loaded refers to the same 'sourcefile' file
  --write         Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)
  --WriteMemDump  Write a memory representation of validated ViPER Files that can be used by the Scorer and Merger tools. Two modes possible: $wmd (1st default)
  --skipScoringSequenceMemDump  Do not perform the Scoring Sequence MemDump (which can be used for scoring) 

Transformations syntax: [:FSshift][\@BBmod][#IDadd]
where: 
- FSshift is the number of frames to add or substract from every framespan within this file
- BBmod is the bounding box modifications of the form X+YxM, ie X and Y add or substract and M multiply (example: @-10+20x0.5 will substract 10 from each X coordinate, add 20 to each Y, and multiply each resulting coordinate by 0.5)
- IDadd is the number of ID to add or substract to every PERSON ID seen within this file

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'CLEAR.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will disard any xml comment(s).
- 'CLEARxsd' files are the same as needed by CLEARDTViperValidator
EOF
;

  return $tmp;
}

######################################## THE END
