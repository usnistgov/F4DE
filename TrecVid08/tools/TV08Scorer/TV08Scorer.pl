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

my $versionid = "TrecVid08 Scorer (Version: $version)";

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

# Something missing ? Abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
$versionid .= "\nusing:\n" . $dummy->get_version();
my @ok_events = $dummy->get_full_events_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

########################################
# Options processing

# Default values for variables

my $usage = &set_usage();
my $show = 0;
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision information set
my $xmllint = "";
my $xsdpath = ".";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:                    T            gh          s  v x  

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
   # Hidden option
   'show_internals+' => \$show,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

die("\n$usage\n") if (scalar @ARGV == 0);

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
my %all = ();
my @ntodo = scalar @ARGV;
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

  # Validate (important to confirm that we can have a memory representation)
  if (! $object->validate()) {
    &valerr($tmp, $object->get_errormsg());
    next;
  } else {
    &valok($tmp, "Loaded");
  }

  # This is really if you are a debugger
  print("** Memory Representation:\n", $object->_display()) if ($show);

  # This is really if you are a debugger 
  if ($show > 1) {
    print("** Observation representation:\n");
    foreach my $i (@ok_events) {
      print("-- EVENT: $i\n");
      my @bucket = $object->get_event_observations($i);
      error_quit("While \'get_event\'observations\' (" . $object->get_errormsg() .")")
	if ($object->error());
      foreach my $obs (@bucket) {
	print $obs->_display();
      }
    }
  }
  $ndone++;
}
print "All files processed: $ndone ok / ", scalar @ntodo, "\n";
die("Can not continue, not all files passed the loading/validation step, aborting\n") if ($ndone != scalar @ntodo);




die("Done\n");

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

Usage: $0 [--help] [--version] [--gtf] [--xmllint location] [--TrecVid08xsd location] viper_source_file.xml [viper_source_file.xml [...]]

Will Score the XML file(s) provided (Truth vs System)

 Where:
  --gtf           Specify that the file to score is a Ground Truth File
  --xmllint       Full location of the \'xmllint\' executable
  --TrecVid08xsd  Path where the XSD files can be found ($xsdfiles)
  --version       Print version number and exit
  --help          Print this usage information and exit

Note:
- This prerequisite that the file has already been validated against the 'TrecVid08.xsd' file (using xmllint)
- Program will ignore the <config> section of the XML file.
- List of recognized events: $ro
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
