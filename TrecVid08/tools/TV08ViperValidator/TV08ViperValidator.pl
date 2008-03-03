#!/usr/bin/env perl

use strict;

##########
# Version

# $Id$
my $version     = "0.1b";
my $rpm_release = "1";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

print "TrecVid08 Viper XML Validator Version: $version\n";

##########
# Check we have every module (perl wise)

my $have_everything = 1;

# Getopt::Long
unless (eval "use Getopt::Long; 1")
  {
    warn_print
      (
       "\"Getopt::Long\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
      );
    $have_everything = 0;
  }

# XML::Simple
unless (eval "use XML::Simple; 1")
  {
    warn_print
      (
       "\"XML::Simple\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=xml%3A%3Asimple\" for installation information\n"
      );
    $have_everything = 0;
  }

# Data::Dumper
unless (eval "use Data::Dumper; 1")
  {
    warn_print
      (
       "\"Data::Dumper\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=data%3A%3Adumper\" for installation information\n"
      );
    $have_everything = 0;
  }

# Scalar::Util
unless (eval "use Scalar::Util qw(reftype); 1")
  {
    warn_print
      (
       "\"Scalar::Util\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=scalar%3A%3Autil\" for installation information\n"
      );
    $have_everything = 0;
  }

# Something missing, abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Default values for variables

my $usage = &set_usage();
my $ekw = "ERROR"; # Error Key Work
my $verb = 0;
my $show = 0;
my $debug_level = 0;
my $isgtf = 0;

##########
# Authorized Events List
my @ok_events = 
  (
   "DoorOpenClose", "PersonRuns", "ObjectPut", "ObjectGet", "VestAppears",
   "PeopleMeet", "PeopleSplitup", "UseATM", "CellToEar", "OpposingFlow",
   "SitDown", "StandUp", "ObjectTransfer", "Pointing", "ElevatorNoEntry",
  );
##########
# OK XML names per top level
my %ok_names = 
  ( 'sourcefile' => ['file', 'object'] );


########################################
# Options processing

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:    D                            gh          s  v    

GetOptions
  (
   'gtf'             => \$isgtf,
   'show_seen'       => \$show,
   'verbose'         => \$verb,
   'help'            => sub {die "\n$usage\n";},
   'Debug+'          => \$debug_level,
  ) || error_quit("Wrong option on the command line, aborting\n\n$usage\n");

error_quit("Not enough arguments on the command line\n$usage\n")
  if (scalar @ARGV < 1);

##########
# Default values to compare against
my $default_error_value = "get xml name err";

##########
# Main processing
my $tmp;
my %all = ();
while ($tmp = shift @ARGV) {
  $all{$tmp} = &validate_file($tmp);
}

die "All files processed\n";

########## END

########################################

sub valerr {
  my ($fname, $text) = @_;

  print "$fname: [ERROR] $text\n";
}

##########

sub validate_file {
  # Read input file into memory
  my $ifile = shift @_;
  
  open FILE, "<$ifile"
    or ( &valerr($ifile, "Could not open file, skipping: $!") && return );
  my @filec = <FILE>;
  close FILE;
  
  ##########
  # First cleanup & check
  
  # Remove end of lines
  chomp @filec;
  my $line;
  
  # Make content one big string
  my $bigstring = "";
  while  ($line = shift @filec) {
    $bigstring .= "$line ";
  }
  
  # Remove <?xml ...?> header
  if (! ($bigstring =~ s%^\s*\<\?xml.+?\?\>%%i)) {
    valerr($ifile,
	   "Could not find a proper \'<?xml ... ?>\' header, skipping");
    return ();
  }
  
  # Remove <viper ...> header
  if (! ($bigstring =~ s%\s*\<viper[^\>]+\>%%i)) {
    valerr($ifile, "Could not find a proper \'<viper\' header, aborting");
    return ();
  }
  
  # Remove </viper> trailer
  if (! ($bigstring =~ s%\<\/viper\>\s*$%%i)) {
    valerr($ifile, "Could not find a proper \'</viper>\' trailer, aborting");
    return ();
  }
  
  # Remove <config> section
  if (! ($bigstring =~ s%\<config\>.+?\<\/config\>%%i)) {
    valerr($ifile, "Could not find a proper \'<config>\' section, aborting");
    return ();
  }

  # At this point, all we ought to have left is the '<data>' content
  if (! ( ($bigstring =~ m%^\s*\<data>%i) 
	  && ($bigstring =~ m%\<\/data\>\s*$%i) ) ) {
    valerr($ifile,
	   "After initial cleanup, we found more than just viper \'<data>\', aborting");
    return ();
  }
  
  ##########
  # Process the data part
  my ($res, $text, %fdata) = &data_processor($bigstring); 

  if (! $res) {
    valerr($ifile, "$text");
    return ();
  }

  print "$ifile: File validates$text\n";
  return %fdata;
}  

########################################

sub data_processor {
  my $string = shift @_;

  my $res = 1;
  my $text = "";
  my %fdata = ();

  my $ref = XMLin($string);

#  print Dumper($ref);

  ##########
  # At the first level should be a 'sourcefile' and only one for the entire viper file
  my @keys = keys %$ref;

  return (0, "Found multiple main tags in the \'<data>\' section, aborting", ())
    if (scalar @keys > 1);

  return(0, "Main tag found in the \'<data>\' section is not \'sourcefile\', aborting", ())
    if ($keys[0] !~ m%^sourcefile$%i);

  my $sf = $keys[0];
  return(0, "Main \'<data>\' tag contains more than one \'sourcefile\' entry, aborting", ())
    if (&is_array($ref->{$sf}) && (scalar @{$ref->{$sf}} > 1));

  ##########
  # Process each know subkeys one at a time
  @keys = keys %{$ref->{$sf}};

  # Will fill a temporary array with the re-organized data representation
  my %tmp = ();

  #####
  # Check that the 'filename' attribute is set
  my @tmpa = grep(m%^filename$%, @keys);
  
  

  if ($text !~ m%^\s*$%) {
    $text = " (" . &clean_begend_spaces($text) .")";
  }
  %fdata = %tmp;

  return ($res, $text, %fdata);
}

########################################

sub set_usage {
  my $tmp=<<EOF
Usage: $0 [--help] [--verbose] [--gtf] viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the XML file(s) provided.

 Where:
  --gtf           File to validate is a Ground Truth File
  --verbose       Be a little more verbose
  --help          This usage information

Note:
- This prerequisite that the file has already been validated against the 'TrecVid08.xsd' file (using xmllint)
- Program will ignore the <config> section of the XML file.
EOF
;

  return $tmp;
}

####################

sub clean_begend_spaces {
  my $txt = shift @_;

  $txt =~ s%^\s+%%;
  $txt =~ s%\s+$%%;

  return $txt;
}

####################

sub warn_print {
  print "WARNING: ", @_;
}

##########

sub error_quit {
  &ok_quit ("${ekw}:", @_);
}

##########

sub ok_quit {
  print @_;

  die "\n";
}

####################

sub verb_print {
  return if (! $verb);
  
  print @_;
}

##########

sub debug_print {
  my $v = shift @_;
  return if ($v > $debug_level);

  print  @_;
}

####################
# As explained: http://www.perl.com/pub/a/2005/04/14/cpan_guidelines.html?page=2

sub is_array {
  my $data = shift @_;

  my $is_array = reftype( $data ) eq 'ARRAY';

  return $is_array;
}

##########

sub is_hash {
  my $data = shift @_;

  my $is_hash = reftype( $data ) eq 'HASH';

  return $is_hash;
}

##########

sub is_scalar {
  my $data = shift @_;

  my $is_scalar = (! &is_array($data)) && (! &is_hash($data));

  return $is_scalar;
}
