#!/usr/bin/env perl

# TrecVid08 Viper XML Validator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Viper XML Validator" is an experimental system.
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

my $versionid = "TrecVid08 Viper XML Validator Version: $version";

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
my $ekw = "ERROR";              # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";

# MMisc (part of this tool)
unless (eval "use MMisc; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"TrecVid08ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# TrecVid08HelperFunctions (part of this tool)
unless (eval "use TrecVid08HelperFunctions; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"TrecVid08HelperFunctions\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1")
  {
    warn_print
      (
       "\"Getopt::Long\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
      );
    $have_everything = 0;
  }

# Something missing ? Abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
my @ok_events = $dummy->get_full_events_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

########################################
# Options processing

my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $mancmd = "perldoc -F $0";
my $usage = &set_usage();

# Default values for variables
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $writeback = -1;
my $xmlbasefile = -1;
my @asked_events = ();
my $autolt = 0;
my $show = 0;
my $remse = 0;
my $crop = "";
my $fps = undef;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:                    T   X    c   gh   lm  p r   vwx  

my %opt = ();
my $dbgftmp = "";
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   "XMLbase:s"       => \$xmlbasefile,
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => \$isgtf,
   'write:s'         => \$writeback,
   'limitto=s'       => \@asked_events,
   'pruneEvents'     => \$autolt,
   'removeSubEventtypes' => \$remse,
   'crop=s'          => \$crop,
   'fps=s'           => \$fps,
   # Hiden Option(s)
   'show_internals'  => \$show,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

ok_quit("\n$usage\n") if ($opt{'help'});
ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  error_quit("Could not run \'$mancmd\'") if ($r);
  ok_quit($o);
}

if (scalar @asked_events == 0) {
  @asked_events = @ok_events;
} else {
  error_quit("Can not use \'limitto\' in conjunction with \'pruneEvents\'")
    if ($autolt);
  @asked_events = $dummy->validate_events_list(@asked_events);
  error_quit("While checking \'limitto\' events list (" . $dummy->get_errormsg() .")")
    if ($dummy->error());
}

if ($xmlbasefile != -1) {
  my $txt = $dummy->get_base_xml(@asked_events);
  error_quit("While trying to obtain the base XML file (" . $dummy->get_errormsg() . ")")
    if ($dummy->error());

  MMisc::writeTo($xmlbasefile, "", 0, 0, $txt);

  ok_quit("");
}

ok_quit("\n$usage\n") if (scalar @ARGV == 0);

if ($xmllint ne "") {
  error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

if (($writeback != -1) && ($writeback ne "")) {
  # Check the directory
  error_quit("Provided \'write\' option directory ($writeback) does not exist")
    if (! -e $writeback);
  error_quit("Provided \'write\' option ($writeback) is not a directoru")
    if (! -d $writeback);
  error_quit("Provided \'write\' option directory ($writeback) is not writable")
    if (! -w $writeback);
  $writeback .= "/" if ($writeback !~ m%\/$%); # Add a trailing slash
}

my ($crop_beg, $crop_end) = (0, 0);
if (! MMisc::is_blank($crop)) {
  error_quit("\'crop\' can only be used in conjunction with \'write\'") if ($writeback == -1);

  my @rest = split(m%\:%, $crop);
  error_quit("Too many parameters to crop, expected \'beg:end\'") if (scalar @rest > 2);
  error_quit("Not enough parameters to crop, expected \'beg:end\'") if (scalar @rest < 2);

  ($crop_beg, $crop_end) = @rest;
  error_quit("\'crop\' beg must be positive and be at least 1") if ($crop_beg < 1);
  error_quit("\'crop\' beg must be less than the end value") if ($crop_beg > $crop_end);

  error_quit("\'fps\' must set in order to do any \'crop\'") if (! defined $fps);

}

##########
# Main processing
my $tmp = "";
my %all = ();
my $ntodo = scalar @ARGV;
my $ndone = 0;
while ($tmp = shift @ARGV) {
  my ($ok, $object) = &load_file($isgtf, $tmp);
  next if (! $ok);

  if (! MMisc::is_blank($crop)) {
    (my $err, $object) = TrecVid08HelperFunctions::ViperFile_crop($object, $crop_beg, $crop_end);
    error_quit("While cropping: $err\n") if (! MMisc::is_blank($err));
  }

  if ($writeback != -1) {
    # Re-adapt @asked_events for each object if automatic limitto is set
    $object->unset_force_subtype() if ($remse);
    @asked_events = $object->list_used_full_events() if ($autolt);
    my $txt = $object->reformat_xml(@asked_events);
    error_quit("While trying to \'write\' (" . $object->get_errormsg() . ")")
      if ($object->error());
    my $fname = "";
    if ($writeback ne "") {
      my $tmp2 = $tmp;
      $tmp2 =~ s%^.+\/([^\/]+)$%$1%;
      $fname = "$writeback$tmp2";
    }
    error_quit("Problem while trying to \'write\'")
      if (! MMisc::writeTo($fname, "", 1, 0, $txt, "", "** XML re-Representation:\n"));
  }

  $all{$tmp} = $object;
  $ndone++;
}
ok_quit("All files processed (Validated: $ndone | Total: $ntodo)\n");

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

##########

sub load_file {
  my ($isgtf, $tmp) = @_;

  if (! -e $tmp) {
    &valerr($tmp, "file does not exists, skipping");
    return(0, ());
  }
  if (! -f $tmp) {
    &valerr($tmp, "is not a file, skipping\n");
    return(0, ());
  }
  if (! -r $tmp) {
    &valerr($tmp, "file is not readable, skipping\n");
    return(0, ());
  }
  
  # Prepare the object
  my $object = new TrecVid08ViperFile();
  error_quit("While trying to set \'xmllint\' (" . $object->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $object->set_xmllint($xmllint)) );
  error_quit("While trying to set \'TrecVid08xsd\' (" . $object->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $object->set_xsdpath($xsdpath)) );
  error_quit("While setting \'gtf\' status (" . $object->get_errormsg() . ")")
    if ( ($isgtf) && ( ! $object->set_as_gtf()) );
  error_quit("While setting \'file\' ($tmp) (" . $object->get_errormsg() . ")")
    if ( ! $object->set_file($tmp) );
  error_quit("While setting \'fps\' ($fps) (" . $object->get_errormsg() . ")")
    if ( (defined $fps) &&  ( ! $object->set_fps($fps) ) );

  # Validate
  if (! $object->validate()) {
    &valerr($tmp, $object->get_errormsg());
    return(0, ());
  }

  &valok($tmp, "validates");

  # This is really if you are a debugger
  print("** Memory Representation:\n", $object->_display_all()) if ($show);

  return(1, $object);
}

########################################

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --man | --version] [--XMLbase [file]] [--gtf] [--xmllint location] [--TrecVid08xsd location] [--pruneEvents]  [--limitto event1[,event2[...]]] [--removeSubEventtypes] [--write [directory] [--crop beg:end]] [--fps fps] viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the Viper XML file(s) provided.

 Where:
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --pruneEvents   Only keep in the new file's config section events for which observations are seen
  --limitto       Only care about provided list of events
  --removeSubEventtypes  Useful when working with specialized Scorer outputs to remove specialized sub types
  --write         Once processed in memory, print a new XML dump of file read (or to the same filename within the command line provided directory if given)
  --crop          Will crop file content to only keep content that is found within the beg and end frames
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --XMLbase       Print a Viper file with an empty <data> section and a populated <config> section, and exit (to a file if one provided on the command line)
  --version       Print version number and exit
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'TrecVid08.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will discard any xml comment(s).
- List of recognized events: $ro
- 'TrecVid08xsd' files are: $xsdfiles
EOF
    ;

    return $tmp;
}

####################

sub warn_print {
  print "WARNING: ", @_;

  print "\n";
}

##########

sub error_quit {
  print("${ekw}: ", @_);

  print "\n";
  exit(1);
}

##########

sub ok_quit {
  print @_;

  print "\n";
  exit(0);
}

############################################################ Manual

=pod

=head1 NAME

TV08ViperValidator - TrecVid08 Viper XML Validator

=head1 SYNOPSIS

B<TV08ViperValidator> S<[ B<--help> | B<--man> | B<--version> ]>
        S<[B<--XMLbase> [I<file]>]>
        S<[B<--xmllint> I<location>] [B<--TrecVid08xsd> I<location>]>
        S<[B<--gtf>] [B<--limitto> I<event1>[,I<event2>[I<...>]]]>
        S<[B<--write> [I<directory>]]>
        I<viper_source_file.xml> [I<viper_source_file.xml> [I<...>]]

=head1 DESCRIPTION

B<TV08ViperValidator> performs a syntactic and semantic validation of the Viper XML file(s) provided on the command line. It can I<validate> reference files (see B<--gtf>) as well as system files. It can also rewrite validated files into another directory using the same filename as the original (see B<--write>), and only keep a few selected events into the output file (see B<--limitto>). To obtain a list of recognized events, see B<--help>.

=head1 PREREQUISITES

B<TV08ViperValidator> relies on some external software and files.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<TV08_XMLLINT> environment variable.

=item B<FILES>

The syntactic validation requires some XML schema files (full list can be obtained using the B<--help> option).
It is possible to specify their location using the B<--xsdpath> option or the B<TV08_XSDPATH> environment variable.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

B<TV08ViperValidator> relies on some internal and external Perl libraries to function.

Simply running the B<TV08ViperValidator> script should provide you with the list of missing libraries. 
The following environment variables should be set in order for Perl to use the B<F4DE> libraries:

=over

=item B<F4DE_BASE>

The main variable once you have installed the software, it should be sufficient to run this program.

=item B<F4DE_PERL_LIB>

Allows you to specify a different directory for the B<F4DE> libraries.

=item B<TV08_PERL_LIB>

Allows you to specify a different directory for the B<TrecVid08> libraries.

=back

=back

=head1 GENERAL NOTES

B<TV08ViperValidator> expect that the file can be been validated using 'xmllint' against the TrecVid08 XSD file(s) (see B<--help> for files list).

B<TV08ViperValidator> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--crop> beg:end

Will crop all input ViperFiles to the specified range. Only valid when used with the 'write' option.
Note that cropping consist of trimming all seen events to the selected range and then shifting the file to start at 1 again.

=item B<--fps> I<fps>

Specify the default sample rate (in frames per second) of the Viper files.

=item B<--gtf>

Specify that the file to validate is a Reference file (also known as a Ground Truth File)

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--limito> I<event1>[,I<event2>[I<,...>]]

Used with B<--write> or B<--XMLbase>, only add provided list of events to output files.
Note that B<TV08ViperValidator> will still check the entire viper file before it can limit itself to the selected list of events.
B<--limitto> can also use wildcards for sub-Event Types specification such as '*:Mapped' which will request all event types but only I<Mapped> subtype.
To note, if you request a subtype for a file that does not contain any, that subtype will be ignored, ie if you request I<ObjectGet:Mapped> when the file does not contain any subtype, you will get all I<ObjectGet>s.

=item B<--man>

Display this man page.

=item B<--pruneEvents>

For each validated that is re-written, only add to this file's config section, events for which observations are seen

=item B<--removeSubEventtypes>

Only useful for specialized Scorer XML files containing subtypes information; option will remove those subtypes

=item B<--TrecVid08xsd> I<location>

Specify the default location of the required XSD files (use B<--help> to get the list of required files).
Can also be set using the B<TV08_XSDPATH> environment variable.

=item B<--version>

Display B<TV08ViperValidator> version information.

=item B<--write> I<directory>

Once validation has been completed for a given file, B<TV08ViperValidator> will write a new XML representation of this file to either the standard output (if I<directory> is not set), or will create a file with the same name as the input file in I<directory> (if specified).

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<TV08_XMLLINT> environment variable.

=item B<--XMLbase> I<file>

Print a XML Viper file with an empty I<data> section but a populated I<config> section, and exit.
It will write the text content to I<file> if provided.

=back

=head1 USAGE

=item B<TV08ViperValidator --XMLbase TrecVid08_Base.xml>

Will generate an I<data> empty valid TrecVid08 Viper XML file, containing all the events in the <config> section.

=item B<TV08ViperValidator --XMLbase TrecVid08_ObjectPut_Embrace_only.xml --limitto ObjectPut,Embrace>

Will generate an I<data> empty valid TrecVid08 Viper XML file, containing only the I<ObjectPut> and I<Embrace> events in its <config> section.

=item B<TV08ViperValidator --xmllint /local/bin/xmllint --TrecVid08xsd /local/F4DE-CVS/data sys_test1.xml>

Will try to validate the I<system> file I<sys_test1.xml> using the I<xmllint> executable located at I</local/bin/xmllint> and the required XSD files found in the I</local/F4DE/data> directory.

=item B<TV08ViperValidator --gtf ref_test1.xml ref_test2.xml --write /tmp>

Will try to validate the I<reference> files I<ref_test1.xml> and I<ref_test2.xml> and will write into the I</tmp> directory, the files I</tmp/ref_test1.xml> and I</tmp/ref_test2.xml> if they both pass the validation step.

=item B<TV08ViperValidator sys_test1.xml sys_test2.xl --write /tmp --limitto Embrace>

Will try to validate the I<system> files I<sys_test1.xml> and I<sys_test2.xml>, and will write into the I</tmp> directory the files I</tmp/sys_test1.xml> and I</tmp/sys_test2.xml> containing only the I<Embrace> event (if they both pass the validation step).

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=cut
