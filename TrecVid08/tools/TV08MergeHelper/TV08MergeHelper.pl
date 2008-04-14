#!/usr/bin/env perl

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

my $versionid = "TrecVid08 Viper XML File Merger Version: $version";

##########
# Check we have every module (perl wise)

my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1")
  {
    warn_print
      (
       "\"TrecVid08ViperFile\" is not available in your Perl installation. ",
       "It should have been part of this tools' files."
      );
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

use Data::Dumper;

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

# Default values for variables

my $usage = &set_usage();
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $xmllint = "";
my $xsdpath = ".";
my $writeto = "";
my $fps = -1;
my $show = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:                    T   X        gh   l      s  vwx  

my %opt;
my $dbgftmp = "";
GetOptions
  (
   \%opt,
   'help',
   'version',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => \$isgtf,
   'writeto=s'       => \$writeto,
   'fps=s'           => \$fps,
   # Hidden option
   'show_internals+' => \$show,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

die("\n$usage\n") if (scalar @ARGV == 0);

die("ERROR: \'fps\' must set in order to do be able to use \'observations\' objects\n\n$usage") if ($fps == -1);
die("ERROR: No \'writeto\' set, aborting\n\n$usage\n") if ($writeto =~ m%^\s*$%);

if ($xmllint ne "") {
  error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

##########
# Main processing
my $tmp;
my $mergefile = undef;
my $ntodo = scalar @ARGV;
my $ndone = 0;

while ($tmp = shift @ARGV) {
  if (! -e $tmp) {
    &valerr($tmp, "file does not exists, skipping");
    next;
  }
  if (! -f $tmp) {
    &valerr($tmp, "is not a file, skipping\n");
    next;
  }
  if (! -r $tmp) {
    &valerr($tmp, "file is not readable, skipping\n");
    next;
  }

  # Prepare the object
  my $object = new TrecVid08ViperFile();
  error_quit("While trying to set \'xmllint\' (" . $object->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $object->set_xmllint($xmllint)) );
  error_quit("While trying to set \'TrecVid08xsd\' (" . $object->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $object->set_xsdpath($xsdpath)) );
  error_quit("While setting \'gtf\' status (" . $object->get_errormsg() . ")")
    if ( ($isgtf) && ( ! $object->set_as_gtf()) );
  error_quit("While setting \'file\' (" . $object->get_errormsg() . ")")
    if ( ! $object->set_file($tmp) );
  error_quit("While setting \'fps\' ($fps) (" . $object->get_errormsg() . ")")
    if ( ! $object->set_fps($fps) );

  # Validate
  if (! $object->validate()) {
    &valerr($tmp, $object->get_errormsg());
    next;
  } else {
    &valok($tmp, "loaded");
  }

  if ($show > 1) {
    print "** FILE: $tmp\n";
    print $object->_display();
  }

  # Create the mergefile object if not existant yet
  if (! defined $mergefile) {
    $mergefile = $object->clone_with_no_events();
    error_quit("While duplicating the first object (" . $object->get_errormsg() .")")
      if ($object->error());
  }

  # Now add all observations from the current file to the output file
  foreach my $i (@ok_events) {
    my @bucket = $object->get_event_observations($i);
    error_quit("While \'get_event_observations\' (" . $object->get_errormsg() .")")
      if ($object->error());
    foreach my $obs (@bucket) {
      $mergefile->add_observation($obs);
      error_quit("While \'add_observation\' (" . $mergefile->get_errormsg() .")")
	if ($mergefile->error());
    }
  }

  $ndone++;
}
error_quit("Could not succesfully load all files processed (Loaded: $ndone / $ntodo)\n")
  if ($ndone != $ntodo);

if ($show) {
  print "** MERGED FILE MEMORY REPRESENTATION:\n";
  print $mergefile->_display();
}

my $txt = $mergefile->reformat_xml();
error_quit("While trying to \'write\' (" . $mergefile->get_errormsg() . ")")
  if ($mergefile->error());
open WRITETO, ">$writeto"
  or error_quit("Could not create output file ($writeto): $!\n");
print WRITETO $txt;
close WRITETO;
print "Wrote: $writeto\n";

die("Done.\n");

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;

  &valok($fname, "[ERROR] $txt");
}

########################################

sub set_usage {
  my $ro = join(" ", @ok_events);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help] [--version] [--gtf] [--xmllint location] [--TrecVid08xsd location] viper_source_file.xml [viper_source_file.xml [...]] --writeto file

Will perform a semantic validation of the Viper XML file(s) provided.

 Where:
  --gtf           Specify that the file to validate is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable
  --TrecVid08xsd  Path where the XSD files can be found ($xsdfiles)
  --writeto       Once processed in memory, print a new XML dump of file read
  --fps           Set the number of frames per seconds (float value) (also recognined: PAL, NTSC)
  --version       Print version number and exit
  --help          Print this usage information and exit

Note:
- This prerequisite that the file has already been validated against the 'TrecVid08.xsd' file (using xmllint)
- Program will ignore the <config> section of the XML file.
EOF
;

  return $tmp;
}

####################

sub warn_print {
  print "WARNING: ", @_;
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
