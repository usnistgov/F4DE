#!/usr/bin/env perl

use strict;
use Getopt::Long;
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
  ) || equit("Wrong option on the command line, aborting\n\n$usage\n");

equit("Not enough arguments on the command line\n$usage\n")
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
  if (! ( ($bigstring =~ s%^\s*\<data>%%i) 
	  && ($bigstring =~ s%\<\/data\>\s*$%%i) ) ) {
    valerr($ifile,
	   "After initial cleanup, we found more than just viper \'<data>\', aborting");
    return ();
  }
  
  ##########
  # Process the data part
  my ($res, $text, %fdata) = &data_processor($bigstring); 
  if (! $res) {
    valerr(&ifile, "$text");
    return ();
  }

  print "$ifile: File validates$text\n";
  return %fdata;
}  

########################################

sub keep_dp_doit {
  my $string = shift @_;
  
  return ($string !~ m%^\s*$%);
}

##########

sub get_xml_name {
  my $str = shift @_;
  my $txt = $default_error_value;

  if ($str =~ m%^\s*\<([^\s]+)\s+%) {
    $txt = $1;
  }

  return $txt;
}

##########

sub get_xml_section {
  my $name = shift @_;
  my $rstr = shift @_;

  my $txt = $default_error_value;
  
  if ($$rstr =~ s%^\s*(\<${name}(\/\>|\s+[^\>]+\/\>))%%) {
    $txt = $1;
  } elsif ($$rstr =~ s%^\s*(\<${name}(\>|\s+[^\>]+\>).+?\<\/${name}\>)%%) {
    $txt = $1;
  }

  return $txt;
}

##########

sub get_xml_name_section {
  my $rstr = shift @_;
  
  my $name = $default_error_value;
  my $section = $default_error_value;

  $name = get_xml_name($$rstr);
  if ($name eq $default_error_value) {
    return ($name,  "");
  }

  $section = get_xml_section($name, $rstr);

  return ($name, $section);
}

##########

sub data_processor {
  my $string = shift @_;

  my $res = 1;
  my $text = "NOTE: ALL SUB LEVELS NOT CHECKED YET. ";
  my %fdata = ();

  my $kd = 1;
  while ($kd && &keep_dp_doit($string)) {
    # Get the first found XML section name and its entire text
    my ($name, $section) = get_xml_name_section(\$string);
    if ($name eq $default_error_value) {
      $text .= "Problem obtaining a valid xml name. ";
      $res = 0;
      $kd = 0;
      next;
    }
    if ($section eq $default_error_value) {
      $text .= "Problem obtaining XML section for name ($name).";
      $res = 0;
      $kd = 0;
      next;
    }

    dprint(2, "$name [left: ", length($string), "]\n");

  }

  if ($text !~ m%^\s*$%) {
    $text = " (" . &clean_begend_spaces($text) .")";
  }

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

sub vprint {
  return if (! $verb);

  print @_;
}

##########

sub equit {
  &oquit ("${ekw}:", @_);
}

##########

sub oquit {
  print @_;

  die "\n";
}

####################

sub vprint {
  return if (! $verb);
  
  print @_;
}

##########

sub dprint {
  my $v = shift @_;
  return if ($v > $debug_level);

  print  @_;
}
