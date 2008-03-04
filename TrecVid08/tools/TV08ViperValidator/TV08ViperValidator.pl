#!/usr/bin/env perl

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";
my $rpm_release = "1";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08 Viper XML Validator Version: $version";

##########
# Check we have every module (perl wise)

my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;

my @xsdfilesl = ( "TrecVid08.xsd", "TrecVid08-viper.xsd", "TrecVid08-viperdata.xsd" ); # Important that the main file be first
my $xsdfiles = join(", ", @xsdfilesl);

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

# IO::CaptureOutput
unless (eval "use IO::CaptureOutput qw(capture_exec); 1")
  {
    warn_print
      (
       "\"IO::CaptureOutput\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=io%3A%3AcaptureOutput\" for installation information\n"
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
my $verb = 0;
my $show = 0;
my $debug_level = 0;
my $debug_file = "/tmp/validator-$$";
my $debug_counter = 0;
my $isgtf = 0;
my $xmllint = "";
my $xsdpath = ".";

##########
# Authorized Events List
my @ok_events = 
  (
   "DoorOpenClose", "PersonRuns", "ObjectPut", "ObjectGet", "VestAppears",
   "PeopleMeet", "PeopleSplitup", "UseATM", "CellToEar", "OpposingFlow",
   "SitDown", "StandUp", "ObjectTransfer", "Pointing", "ElevatorNoEntry",
  );

########################################
# Options processing

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
# USed:    D                 V       d  gh          s  v    

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
   'show_seen'       => \$show,
   'Verbose'         => \$verb,
   # Hidden otpions
   'debug+'          => \$debug_level,
   'Debugfile=s'     => \$dbgftmp,
  ) or error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

die("\n$usage\n") if ($opt{'help'});
die("$versionid\n") if ($opt{'version'});

error_quit("Not enough arguments on the command line\n$usage\n")
  if (scalar @ARGV < 1);

if ($dbgftmp ne "") {
  $debug_file = $dbgftmp;
  $debug_level++ if ($debug_level == 0);
}

##########

# Confirm xmllint is present and at least 2.6.30
$xmllint = &check_xmllint($xmllint);
# Confirm that the required xsdfiles are available
$xsdpath = &check_xsdfiles($xsdpath, @xsdfilesl);


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
  my ($fname, $text, $string) = @_;

  print "$fname: [ERROR] $text\n";
  debug_savefile(0, "", $string);
}

##########

sub validate_file {
  my $ifile = shift @_;

  # Load the XML through xmllint
  my ($res, $bigstring) = &run_xmllint($ifile);
  if ($res !~ m%^\s*$%) {
    valerr($ifile,$res);
    return ();
  }

  # Initial Cleanups & Check
  ($res, $bigstring) = &data_cleanup($bigstring);
  if ($res !~ m%^\s*$%) {
    valerr($ifile, $res, $bigstring);
    return ();
  }

  # Process the data part
  my %fdata;
  ($res, %fdata) = &data_processor($bigstring); 
  if ($res !~ m%^\s*$%) {
    valerr($ifile, $res);
    return ();
  }

  print "$ifile: File validates$res\n";
  return %fdata;
}

########################################

sub run_xmllint {
  verb_print("Running xmllint\n");

  my $file = shift @_;
  $file =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  my ($retcode, $stdout, $stderr) = &system_call($xmllint, "--path", "\"$xsdpath\"", "--schema", $xsdpath . "/" . $xsdfilesl[0], $file);

  return("Problem validating file with \'xmllint\' ($stderr), aborting", "")
    if ($retcode != 0);

  return ("", $stdout);
}

########################################

sub data_cleanup {
  verb_print("Running Data Cleanup\n");

  my $bigstring = shift @_;

  # Remove <?xml ...?> header
  return("Could not find a proper \'<?xml ... ?>\' header, skipping", $bigstring)
    if (! ($bigstring =~ s%^\s*\<\?xml.+?\?\>%%is));
  
  # Remove <viper ...> header
  return("Could not find a proper \'<viper\' header, aborting", $bigstring)
    if (! ($bigstring =~ s%\s*\<viper[^\>]+\>%%is));
  
  # Remove </viper> trailer
  return("Could not find a proper \'</viper>\' trailer, aborting", $bigstring)
    if (! ($bigstring =~ s%\<\/viper\>\s*$%%is));
  
  # Remove <config> section
  return("Could not find a proper \'<config>\' section, aborting", $bigstring)
    if (! ($bigstring =~ s%\<config\>.+?\<\/config\>%%is));

  # At this point, all we ought to have left is the '<data>' content
  return("After initial cleanup, we found more than just viper \'<data>\', aborting", $bigstring)
    if (! ( ($bigstring =~ m%^\s*\<data>%is) && ($bigstring =~ m%\<\/data\>\s*$%is) ) );

  return ("", $bigstring);
}

########################################

sub data_processor {
  verb_print("Running Data Processor\n");

  my $string = shift @_;

  my $text = "";
  my %fdata = ();

  my @keys;
  my @tmpa;
  my %tmph;

  my $ref = XMLin($string);

#  print Dumper($ref);

  ##########
  # At the first level should be a 'sourcefile' and only one for the entire viper file
  @keys = keys %$ref;

  return ("Found no main tags in the \'<data>\' section, aborting", ())
    if (scalar @keys == 0);

  return ("Found multiple main tags in the \'<data>\' section, aborting", ())
    if (scalar @keys > 1);

  return("Main tag found in the \'<data>\' section is not \'sourcefile\', aborting", ())
    if ($keys[0] !~ m%^sourcefile$%i);

  my $sf = $keys[0];
  return("Main \'<data>\' tag contains more than one \'sourcefile\' entry, aborting", ())
    if (&is_array($ref->{$sf}) && (scalar @{$ref->{$sf}} > 1));

  ##########
  # Process each know subkeys one at a time

  #####
  # Check that the 'filename' attribute is set
  @keys = keys %{$ref->{$sf}};
  @tmpa = &find_key_occurrence("filename", @keys);
  
  return("Found no \'filename\' \'sourcefile\' attribute, aborting", ())
    if (scalar @tmpa > 1);

  return("Found multiple \'filename\' \'sourcefile\' attribute, aborting", ())
    if (scalar @tmpa > 1);

  my $kfn = $tmpa[0];
  return("\'filename\' \'sourcefile\' attribute contains multiple values, aborting", ())
    if (&is_array($ref->{$sf}->{$kfn}) && (scalar @{$ref->{$sf}->{$kfn}} > 1));

  my $fn = $ref->{$sf}->{$kfn};

  # Remove it from the left to process list
  delete $ref->{$sf}->{$kfn};

  #####
  # 'file' attribute
  @keys = keys %{$ref->{$sf}};
  @tmpa = &find_key_occurrence("file", @keys);
  
  return("Found no \'file\' \'sourcefile\' attribute, aborting", ())
    if (scalar @tmpa > 1);

  return("Found multiple \'file\' \'sourcefile\' attribute, aborting", ())
    if (scalar @tmpa > 1);

  my $kfl = $tmpa[0];
  return("\'file\' \'sourcefile\' attribute does not seem to contains multiple attributes, aborting", ())
    if (! &is_hash($ref->{$sf}->{$kfl}));

  %tmph = %{$ref->{$sf}->{$kfl}};
#  print Dumper(\%tmph);

  my ($toto) = &check_file(%tmph);

  my $fn = $ref->{$sf}->{$kfl};



  #####
  # Objects

  # Will fill a temporary array with the re-organized data representation
  my %tmp = ();


  if ($text !~ m%^\s*$%) {
    $text = " (" . &clean_begend_spaces($text) .")";
  }
  %fdata = %tmp;

  return ($text, %fdata);
}


##########

sub find_key_occurrence {
  my $name = shift @_;
  my @keys = @_;

  my @res = grep(m%^${name}$%i, @keys);

  return @res;
}

#####

sub check_file {
  my %tmp = @_;

  # for a file, all we really care about are the content of the 'attribute's
  my @keys = keys %tmp;
  my @tmpa = &find_key_occurrence("attribute", @keys);
 
  my %attr = &consolidate_attributes(\@tmpa, \%tmp);
 
  

}

#####

sub consolidate_attributes {
  my $rarray = shift @_;
  my $rhash = shift @_;

  my $ret = 1;

  my %res;
  foreach my $key1 (@{$rarray}) {
    my %hash = %{$rhash->{$key1}};
    foreach my $key2 (keys %hash) {
      my $tk2 = lc $key2;
      
      $res{$tk2} = $hash{$key2};
    }
  }

  return %res;
}

########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help] [--version] [--Verbose] [--gtf] [--xmllint location] [--TrecVid08xsd location] viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the XML file(s) provided.

 Where:
  --xmllint       Full location of the \'xmllint\' executable
  --TrecVid08xsd  Path where the XSD files can be found ($xsdfiles)
  --gtf           File to validate is a Ground Truth File
  --version       Print version number and exit
  --Verbose       Be a little more verbose
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
  &ok_quit ("${ekw}: ", @_);
}

##########

sub ok_quit {
  print @_;

  die "\n";
}

####################

sub verb_print {
  return if (! $verb);
  
  print STDERR @_;
}

##########

sub debug_print {
  my $v = shift @_;

  return if ($v > $debug_level);

  print  STDERR "DEBUG: ", @_;
}

#####

sub debug_savefile {
  my $v = shift @_;
  my $file = shift @_;
  my $string = shift @_;

  return if ($v > $debug_level);

  return if ($string =~ m%^\s*$%);

  $file = sprintf("$debug_file.%03d", ++$debug_counter)
    if ($file eq "");
  my $ok = 1;

  open FILE, ">$file"
      or {$ok = 0};
  
  if ($ok == 0) {
    debug_print(0, "Could not create debug file ($file): $!\n");
  } else {
    print FILE $string;
    close FILE;
    debug_print(0, "Created debug file: $file\n");
  }
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

####################
# xmllint check

sub system_call {
  my @args = @_;

  debug_print(1, "system_call [", join(" ", @args), "]\n");

  my ($stdout, $stderr) = capture_exec(@args);
  my $ retcode = $?;

  chomp $stdout;
  chomp $stderr;

  return ($retcode, $stdout, $stderr);
}

#####

sub check_xmllint {
  verb_print("Checking that xmllint is available...\n");

  my $xmllint = shift @_;

  # If none provided, check if it is available in the path
  if ($xmllint eq "") {
    my ($retcode, $stdout, $stderr) = &system_call('which', 'xmllint');
    error_quit("Could not find a valid \'xmllint\' command in the PATH, aborting\n")
      if ($retcode != 0);
    $xmllint = $stdout;
  }

  $xmllint =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  # Check that the file for xmllint exists and is an executable file
  error_quit("\'xmllint\' ($xmllint) does not exist, aborting\n")
    if (! -e $xmllint);

  error_quit("\'xmllint\' ($xmllint) is not a file, aborting\n")
    if (! -f $xmllint);

  error_quit("\'xmllint\' ($xmllint) is not executable, aborting\n")
    if (! -x $xmllint);

  # Now check that it actually is xmllint
  my ($retcode, $stdout, $stderr) = &system_call($xmllint, '--version');
  error_quit("\'xmllint\' ($xmllint) does not seem to be a valid \'xmllint\' command, aborting\n")
    if ($retcode != 0);
  
  if ($stderr =~ m%using\s+libxml\s+version\s+(\d+)%) {
    # xmllint print the command name followed by the version number
    my $version = $1;
    error_quit("\'xmllint\' ($xmllint) version too old: requires at least 2.6.30 (ie 20630, installed $version), aborting\n")
      if ($version <= 20630);
  } else {
    error_quit("Could not confirm that \'xmllint\' is valid, aborting\n");
  }

  return $xmllint;
}

#####

sub check_xsdfiles {
  verb_print("Checking that the required XSD files are available...\n");
  my $xsdpath = shift @_;
  my @xsdfiles = @_;

  $xsdpath =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;
  $xsdpath =~ s%(.)\/$%$1%;

  foreach my $fname (@xsdfiles) {
    my $file = "$xsdpath/$fname";
    debug_print(1, "Checking [$file]\n");
    error_quit("Could not find required XSD file ($fname) at selected path ($xsdpath), aborting\n")
      if (! -e $file);
  }

  return $xsdpath;
}
  
