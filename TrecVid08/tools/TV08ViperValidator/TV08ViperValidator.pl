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

# File::Temp (usualy part of the Perl Core)
unless (eval "use File::Temp qw / tempfile /; 1")
  {
    warn_print
      (
       "\"File::Temp\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=file%3A%3temp\" for installation information\n"
      );
    $have_everything = 0;
  }

# For debugging purposes
# Data::Dumper (usualy part of the Perl Core)
unless (eval "use Data::Dumper; 1")
  {
    warn_print
      (
       "\"Data::Dumper\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=data%3A%3Adumper\" for installation information\n"
      );
    $have_everything = 0;
  }

# Something missing ? Abort
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
   # Required events
   "PersonRuns", "CellToEar", "ObjectPut", "PeopleMeet", "PeopleSplitup", 
   "Embrace", "Pointing", "ElevatorNoEntry", "OpposingFlow", "TakePicture", 
   # Optional events
   "DoorOpenClose", "UseATM", "ObjectGet", "VestAppears", "SitDown", 
   "StandUp", "ObjectTransfer", 
   # Removed events
   ##
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
my $default_error_value = "default_error_value";
my $framespan_max_default = "all";
my $framespan_max = $framespan_max_default;

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
  my ($text, %current) = &validate_file($tmp);
  next if ($text !~ m%^\s*$%);

  print("Memory Representation:\n", Dumper(\%current)) if ($show);
  %{$all{$tmp}} = %current;
  $ndone++;
}
die("All files processed", ($verb) ? (" (Todo: ", scalar @ntodo, " | Done:  $ndone)") : "", "\n");

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
    return ($default_error_value, ());
  }
#  debug_savefile(0, "", $bigstring);

  # Initial Cleanups & Check
  ($res, $bigstring) = &data_cleanup($bigstring);
  if ($res !~ m%^\s*$%) {
    valerr($ifile, $res, $bigstring);
    return ($default_error_value, ());
  }

  # Process the data part
  my %fdata;
  ($res, %fdata) = &data_processor($bigstring); 
  if ($res !~ m%^\s*$%) {
    valerr($ifile, $res);
    return ($default_error_value, ());
  }

  print "$ifile: File validates$res\n";
  return ("", %fdata);
}

########################################

sub run_xmllint {
  verb_print("Running xmllint\n");

  my $file = shift @_;
  $file =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  my ($retcode, $stdout, $stderr) =
    &system_call($xmllint, "--path", "\"$xsdpath\"", "--schema", $xsdpath . "/" . $xsdfilesl[0], $file);

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
  
  # Remove <viper ...> and </viper> header and trailer
  return("Could not find a proper \'viper\' tag, aborting", $bigstring)
    if (! &remove_xml_tags("viper", \$bigstring));
  
  # Remove <config> section
  return("Could not find a proper \'config\' section, aborting", $bigstring)
    if (! &remove_xml_section("config", \$bigstring));

  # At this point, all we ought to have left is the '<data>' content
  return("After initial cleanup, we found more than just viper \'data\', aborting", $bigstring)
    if (! ( ($bigstring =~ m%^\s*\<data>%is) && ($bigstring =~ m%\<\/data\>\s*$%is) ) );

  return ("", $bigstring);
}

####################

sub remove_xml_tags {
  my $name = shift @_;
  my $rstr = shift @_;

  if ($$rstr =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    return (1 == 1);
  } elsif ($$rstr =~ s%\s*\<${name}(\>|\s+[^\>]+\>)(.+?)\<\/${name}\>%$2%s) {
    return (1 == 1);
  }

  return (1 == 0);
}

#####

sub remove_xml_section {
  my $name = shift @_;
  my $rstr = shift @_;

  if ($$rstr =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    return (1 == 1);
  } elsif ($$rstr =~ s%\s*\<${name}(\>|\s+[^\>]+\>).+?\<\/${name}\>%%s) {
    return (1 == 1);
  }

  return (1 == 0);
}


########################################

sub data_processor {
  verb_print("Running Data Processor (Internal)\n");

  my $string = shift @_;

  my $res = "";
  my %fdata = ();
  
  #####
  # First off, confirm the first section is 'data' and remove it
  my $name = &get_next_xml_name($string);
  return("Problem obtaining a valid XML name, aborting", $string)
    if ($name eq $default_error_value);
  return("\'data\' section not present (instead: $name), aborting", $string)
    if ($name !~ m%^data$%i);
  return("Problem cleaning \'data\' tags", $string)
    if (! &remove_xml_tags($name, \$string));
  
  #####
  # Now, the next --and only-- section is to be a 'sourcefile'
  my $name = &get_next_xml_name($string);
  return("Problem obtaining a valid XML name, aborting", $string)
    if ($name eq $default_error_value);
  return("\'sourcefile\' section not present (instead: $name), aborting", $string)
    if ($name !~ m%^sourcefile$%i);
  my $tmp = $string;
  my $section = &get_named_xml_section($name, \$string);
  return("Problem obtaining the \'sourcefile\' XML section, aborting", $tmp)
    if ($name eq $default_error_value);
  # And nothing else should be left in the file
  return("Data left in addition to the \'sourcefile\' XML section, aborting", $string)
    if ($string !~ m%\s*$%);
  # Parse it
  ($res, %fdata) = &parse_sourcefile_section($name, $section);
  return("Problem while processing the \'sourcefile\' XML section (" . &clean_begend_spaces($res) .")", $section)
    if ($res !~ m%^\s*$%);

  return ($res, %fdata);
}

#################### 

sub keep_dp_doit {
  my $string = shift @_;
  
  return ($string !~ m%^\s*$%s);
}

##########

sub get_next_xml_name {
  my $str = shift @_;
  my $txt = $default_error_value;

  if ($str =~ m%^\s*\<\s*([^\>]+)%s) {
    my $tmp = $1;
    my @a = split(m%\s+%, $tmp);
    $txt = $a[0];
  }

  return $txt;
}

##########

sub get_named_xml_section {
  my $name = shift @_;
  my $rstr = shift @_;

  my $txt = $default_error_value;
  
  if ($$rstr =~ s%\s*(\<${name}(\/\>|\s+[^\>]+\/\>))%%s) {
    $txt = $1;
  } elsif ($$rstr =~ s%\s*(\<${name}(\>|\s+[^\>]+\>).+?\<\/${name}\>)%%s) {
    $txt = $1;
  }

  return $txt;
}

##########

sub get_next_xml_section {
  my $rstr = shift @_;
  
  my $name = $default_error_value;
  my $section = $default_error_value;

  $name = get_next_xml_name($$rstr);
  if ($name eq $default_error_value) {
    return ($name,  "");
  }

  $section = get_named_xml_section($name, $rstr);

  return ($name, $section);
}

##########

sub split_xml_tag {
  my $tag = shift @_;

  my @split = split(m%\=%, $tag);
  return ("", "")
    if (scalar @split != 2);

  my ($name, $value) = @split;
  $value =~ s%^\s*\"%%;
  $value =~ s%\"\s*$%%;

  return ($name, $value);
}

#####

sub split_xml_tag_list_to_hash {
  my @list = @_;

  my %hash;
  foreach my $tag (@list) {
    my ($name, $value) = split_xml_tag($tag);
    return("Problem splitting inlined attribute ($tag)", ())
      if ($name =~ m%^\s*$%);

    return("Inlined attribute ($name) appears to be present multiple times")
      if (exists $hash{$name});
    
    $hash{$name} = $value;
  }

  return ("", %hash);
}

#####

sub get_inline_xml_attributes {
  my $name = shift @_;
  my $str = shift @_;

  my $txt = "";
  if ($str =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    $txt = $1;
  } elsif ($str =~ s%\s*\<${name}(\>|\s+[^\>]+\>)%%s) {
    $txt = $1;
  }
  $txt =~ s%^\s+%%;
  $txt =~ s%\/?\>$%%;

  my @all = split(m%\s+%, $txt);
  return ("", ()) if (scalar @all == 0); # None found
#  debug_print(0, "[$txt] (" . join("|", @all) . ")\n");

  my ($res, %hash) = split_xml_tag_list_to_hash(@all);
  return($res, ()) if ($res !~ m%^\s*$%);

  return ("", %hash);
}
  
##########

sub find_hash_key {
  my $name = shift @_;
  my %hash = @_;

  my @keys = keys %hash;

  my @list = grep(m%^${name}$%i, @keys);
  return("key ($name) does not seem to be present", "")
    if (scalar @list == 0);
  return("key ($name) seems to be present multiple time (" . join(", ", @list) .")", "")
    if (scalar @list > 1);
  
  return ("", $list[0]);
}

####################

sub parse_sourcefile_section {
  my $name = shift @_;
  my $str = shift @_;

  my %it;
  
  #####
  # First, get the inline attributes from the 'sourcefile' inline attribute itself
  my ($text, %iattr) = &get_inline_xml_attributes($name, $str);
  return($text, ()) if ($text !~ m%^\s*$%);

  # We should only have a \'filename\'
  my @keys = keys %iattr;
  return ("Found multiple keys in the \'sourcefile\' inlined attributes", ())
    if (scalar @keys > 1);
  ($text, my $found) = &find_hash_key("filename", %iattr);
  return($text, ()) if ($text !~ m%^\s*$%);

  my $filename = $iattr{$found};

  #####
  # We can now remove the \'sourcefile\' header and trailer tags
  return("WEIRD: could not remove the \'$name\' header and trailer tags", ())
    if (! &remove_xml_tags($name, \$str));

  #####
  # Get the 'file' section
  my $sec = get_named_xml_section("file", \$str);
  return("No \'file\' section found in the \'sourcefile\'", ())
    if ($sec eq $default_error_value);
  ($text, my %fattr) = &parse_file_section($sec);
  return($text, ()) if ($text !~ m%^\s*$%);
  
  # Complete %fattr and start filling %it
  $fattr{"filename"} = $filename;
  %{$it{"file"}} = %fattr;

  ##########
  # Process all that is left in the string (should only be objects)
  $str = clean_begend_spaces($str);
  while ($str !~ m%^\s*$%s) {
    debug_print(2, "[$str]\n");
    my $sec = get_named_xml_section("object", \$str);
    return("No \'object\' section left in the \'sourcefile\'", ())
      if ($sec eq $default_error_value);
    ($text, my $object_type, my $object_id, my $object_framespan, my %oattr)
      = &parse_object_section($sec);
    return($text, ()) if ($text !~ m%^\s*$%);
    debug_print(2, "[*] $object_type | $object_id | $object_framespan\n", Dumper(\%oattr));

    ##### Sanity
    
    # Check that the object name is an authorized event name
    return("Found unknown event type ($object_type) in \'object\'", ())
      if (! grep(/^$object_type$/, @ok_events));
    # Check that the object type/id key does not already exist
    return("Only one unique (event type, id) key authorized ($object_type, $object_id)", ())
      if (exists $it{$object_type}{$object_id});
    
    ##### Add to %it
    %{$it{$object_type}{$object_id}} = %oattr;
    $it{$object_type}{$object_id}{"framespan"} = $object_framespan;

    # Prepare string for the next run
    $str = clean_begend_spaces($str);
  }

  ##### Final Sanity Checks
  
  # Check that for each event type, there is no id gap
  foreach my $event (@ok_events) {
    next if (! exists $it{$event});
    my @list = sort numerically keys %{$it{$event}};

    return ("Event ID list must always start at 0 (for event \'$event\', start at " . $list[0] . ")", ())
      if ($list[0] != 0);

    return ("Event ID list must always start at 0 and have not gap (for event \'$event\', seen "
	    . scalar @list . " elements, while last one listed is " .  $list[-1] . " (starting from 0))", ())
      if (scalar @list != $list[-1] + 1); 
  }

  return ("", %it);
}

####################

sub compare_arrays {
  my $rexp = shift @_;
  my @list = @_;

  my @in;
  my @out;
  foreach my $elt (@$rexp) {
    if (grep(m%^$elt$%, @list)) {
      push @in, $elt;
    } else {
      push @out, $elt;
    }
  }

  return (\@in, \@out);
}

#####

sub parse_file_section {
  my $str = shift @_;

  my $wtag = "file";
  my %file_hash;

  my ($text, %attr) = &get_inline_xml_attributes($wtag, $str);
  return ($text, ()) if ($text !~ m%^\s*$%);

  my @expected = ("id", "name"); # 'id' is to be first
  my ($in, $out) = &compare_arrays(\@expected, keys %attr);
  return("Could not find all the expected inline \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected inline \'$wtag\' attributes", ())
    if (scalar @$out > 0);

  # Get the file id
  return("WEIRD: Could not find the \'id\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[0]});
  my $fid = $attr{$expected[0]};
  return("Only one authorized $wtag id [0, here $fid]", ())
    if ($fid != 0);
  $file_hash{"file_id"} = $fid;

  # Remove the \'file\' header and trailer tags
  return("WEIRD: could not remove the \'$wtag\' header and trailer tags", ())
    if (! &remove_xml_tags($wtag, \$str));

  #####
  # Process each "attribute" left now
  ($text, %attr) = parse_attributes(\$str);
  return("While parsing the \'$wtag\' \'attribute\'s : $text", ())
    if ($text !~ m%^\s*$%);

  # Confirm they are the ones we want
  my %expected_hash = 
    (
     "NUMFRAMES" => "dvalue",
     "SOURCETYPE" => undef,
     "H-FRAME-SIZE" => "dvalue",
     "V-FRAME-SIZE" => "dvalue",
     "FRAMERATE" => "fvalue",
    );
  @expected = keys %expected_hash;
  ($in, $out) = &compare_arrays(\@expected, keys %attr);
  return("Could not find all the expected \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'$wtag\' attributes", ())
    if (scalar @$out > 0);

  # Check they are of valid type & reformat them for the output file hash
  foreach my $key (@expected) {
    $file_hash{$key} = undef;
    my $val = $expected_hash{$key};
    next if (! defined $val);
    my @comp = keys %{$attr{$key}};
    next if (scalar @comp == 0);
    my @expected2;
    push @expected2, $val;
    ($in, $out) = &compare_arrays(\@expected2, @comp);
   return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type", ())
      if (scalar @$out > 0);

    return("WEIRD: Could not find the value associated with the \'$key\' \'$wtag\' attribute", ())
      if (! exists $attr{$key}{$val}{$framespan_max});
    $file_hash{$key} = ${$attr{$key}{$val}{$framespan_max}}[0];
  }

  # Set the "framespan_max" from the NUMFRAMES entry
  my $key = "NUMFRAMES";
  return("No \'$key\' \'$wtag\' attribute defined", ())
    if (! defined $file_hash{$key});
  my $val = $file_hash{$key};
  return("Invalid value for \'$key\' \'$wtag\' attribute", ())
    if ($val < 0);

  $framespan_max = "1:$val";

  return ("", %file_hash);
}

##########

sub parse_object_section {
  my $str = shift @_;

  my $wtag = "object";

  my $object_name;
  my $object_id;
  my $object_framespan;
  my %object_hash;

  my ($text, %attr) = &get_inline_xml_attributes($wtag, $str);
  return ($text, ()) if ($text !~ m%^\s*$%);

  my @expected = ("name", "id", "framespan"); # order is important
  my ($in, $out) = &compare_arrays(\@expected, keys %attr);
  return("Could not find all the expected inline \'file\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected inline \'file\' attributes", ())
    if (scalar @$out > 0);

  # Get the object name
  return("WEIRD: Could not obtain the \'name\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[0]});
  $object_name = $attr{$expected[0]};

  # Get the object id
  return("WEIRD: Could not obtain the \'id\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[1]});
  $object_id = $attr{$expected[1]};

  # Get the object framespan
  return("WEIRD: Could not obtain the \'framespan\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[2]});
  my $tmp = $attr{$expected[2]};
  ($text, $tmp) = &fix_framespan($tmp);
  return($text, ()) if ($text !~ m%^\s*$%);
  $text = &framespan_is_within($tmp, $framespan_max);
  return($text, ()) if ($text !~ m%^\s*$%);
  $object_framespan = $tmp;

  # Remove the \'object\' header and trailer tags
  return("WEIRD: could not remove the \'$wtag\' header and trailer tags", ())
    if (! &remove_xml_tags($wtag, \$str));

  #####
  # Process each "attribute" left now
  ($text, %attr) = parse_attributes(\$str, $object_framespan);
  return("While parsing the \'$wtag\' \'attribute\'s : $text", ())
    if ($text !~ m%^\s*$%);
  
  # Confirm they are the ones we want
  my %expected_hash = 
    (
     "Point" => "point",
     "BoundingBox" => "bbox",
     "DetectionScore" => "fvalue",
     "DetectionDecision" => "bvalue",
    );
  @expected = keys %expected_hash;
  ($in, $out) = &compare_arrays(\@expected, keys %attr);
  return("Could not find all the expected \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'$wtag\' attributes", ())
    if (scalar @$out > 0);

  # Check they are of valid type & reformat them for the output object hash
  foreach my $key (@expected) {
    my $val = $expected_hash{$key};
    next if (! defined $val);
    my @comp = keys %{$attr{$key}};
    next if (scalar @comp == 0);
    my @expected2;
    push @expected2, $val;
    ($in, $out) = &compare_arrays(\@expected2, @comp);
   return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type", ())
      if (scalar @$out > 0);

    foreach my $fs (keys %{$attr{$key}{$val}}) {
      @{$object_hash{$key}{$fs}} = @{$attr{$key}{$val}{$fs}};
    }
  }

  return ("", $object_name, $object_id, $object_framespan, %object_hash);
}

####################

sub framespan_sort {
  my ($e1) = ($a =~ m%^(\d+)\:%);
  my ($e2) = ($b =~ m%^(\d+)\:%);

  return ($e1 <=> $e2);
}

#####

sub framespan_reorder {
  my $fs = shift @_;

  my @ftodo = split(/[\s|\t]+/, $fs);

  my @o = sort framespan_sort @ftodo;

  return("While shifting frames, not the same number of elements between the original array and the result array", "")
    if (scalar @ftodo != scalar @o);

  my $res = join(" ", @o);

  return("", $res);
}

##########

sub framespan_shorten_check {
  my ($b, $e, $txt) = @_;

  return("badly formed range pair")
    if (($b =~ m%^\s*$%) || ($e =~ m%^\s*$%));
  
  return("framespan range pair values can not be negative")
    if (($b < 0) || ($e < 0));

  return("framespan range pair is not ordered")
    if ($e < $b);

  return("");
}

#####

sub framespan_shorten {
  my $fs = shift @_;

  my @ftodo = split(/[\s|\t]+/, $fs);

  my $ftc = scalar @ftodo;

  # no elements ?
  return("No values in framespan range", "")
    if ($ftc == 0);

  my $entry = shift @ftodo;
  my ($b, $e) = ($entry =~ m%^(\d+)\:(\d+)$%);
  my $text = &framespan_shorten_check($b, $e, $entry);
  return ($text, "") if ($text !~ m%^\s*$%);

  # Only 1 element ?
  return ("", $fs) if ($ftc == 1);

  # More than one element: compute
  my @o = ();

  foreach $entry (@ftodo) {
    my ($nb, $ne) = ($entry =~ m%^(\d+)\:(\d+)$%);
    $text = &framespan_shorten_check($b, $e, $entry);
    return ($text, "") if ($text !~ m%^\s*$%);

    if ($nb == $e) { # ex: 1:2 2:6 -> 1:6
      $e = $ne;
    } elsif ($nb == 1 + $e) { # ex: 1:1 2:3 -> 1:3
      $e = $ne;
    } else { # ex: 1:2 12:24 -> 1:2 12:24
      push @o, "$b:$e";
      ($b, $e) = ($nb, $ne);
    }
  }
  push @o, "$b:$e";
  
  my $res = join(" ", @o);
  
  return ("", $res);
}

#####

sub fix_framespan {
  my $fs = shift @_;

  return ("", $fs) if ($fs eq $framespan_max);

  my $text;

  # Reorder (just in case)
  ($text, $fs) = &framespan_reorder($fs);
  return ($text, "") if ($text !~ m%^\s*$%);

  # Shorten range of framespan entries (Also performs a check on pair ordering)
  # NOTE: must be done after full reorder since it relies on entries to be ordered to work
  ($text, $fs) = &framespan_shorten($fs);
  return ($text, "") if ($text !~ m%^\s*$%);

  my ($bf, $ef) = &framespan_get_begend($fs);
  return("framespan start at frame \#1", "") if ($bf < 1);

  return ("", $fs);
}

##########

sub framespan_get_begend {
  my $fs = shift @_;

  my ($bf) = ($fs =~ m%^(\d+)\:%);
  my ($ef) = ($fs =~ m%\:(\d+)$%);

  return ($bf, $ef);
}

#####

sub framespan_check_no_overlap {
  my $ifs = shift @_;
  my @afs = shift @_;

  return ("") if (scalar @afs == 0);

  my ($i_beg, $i_end) = framespan_get_begend($ifs);

  foreach my $cfs (@afs) {
    my ($c_beg, $c_end) = framespan_get_begend($cfs);

    # No overlap possible
    next if (($c_end < $i_beg) || ($i_end < $c_beg));

    # Overlap
    return("framespan overlap detected");
  }

  return("");
}

#####

sub framespan_is_within {
  my $v = shift @_;
  my $range = shift @_;

  my ($v_beg, $v_end) = framespan_get_begend($v);
  my ($r_beg, $r_end) = framespan_get_begend($range);

  return("") if (($v_beg >= $r_beg) && ($v_end <= $r_end));

  return("framespan is not within the given range");
}

##########

sub data_process_array_core {
  my $name = shift @_;
  my $rattr = shift @_;
  my @expected = @_;

  my ($in, $out) = &compare_arrays(\@expected, keys %$rattr);
  return("Could not find all the expected \'data\:$name\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'data\:$name\' attributes", ())
    if (scalar @$out > 0);

  my @res;
  foreach my $key (@expected) {
    push @res, $$rattr{$key};
  }

  return ("", @res);
}

#####

sub data_process_bbox {
  my %attr = @_;
  my @expected = ("x", "y", "height", "width");
  
  return &data_process_array_core("bbox", \%attr, @expected);
}

#####

sub data_process_point {
  my %attr = @_;
  my @expected = ("x", "y");
  
  return &data_process_array_core("point", \%attr, @expected);
}

#####

sub data_process_fvalue {
  my %attr = @_;
  my @expected = ("value");
  
  return &data_process_array_core("fvalue", \%attr, @expected);
}

#####

sub data_process_dvalue {
  my %attr = @_;
  my @expected = ("value");
  
  return &data_process_array_core("dvalue", \%attr, @expected);
}

#####

sub extract_data {
  my $str = shift @_;
  my $fspan = shift @_;
  my %attr;
  my @afspan;

  while ($str !~ m%^\s*$%) {
    my $name = &get_next_xml_name($str);
    return("Problem obtaining a valid XML name, aborting", $str)
      if ($name eq $default_error_value);
    return("\'data\' extraction process does not seem to have found one, aborting", $str)
      if ($name !~ m%^data\:%i);
    my $section = &get_named_xml_section($name, \$str);
    return("Problem obtaining the \'data\:\' XML section, aborting", "")
      if ($name eq $default_error_value);

    # All within a data: entry is inlined, so get the inlined content
    my ($text, %iattr) = &get_inline_xml_attributes($name, $section);
    return($text, ()) if ($text !~ m%^\s*$%);

    # Check the framespan (if any)
    my $lfspan;
    my $key = "framespan";
    if (exists $iattr{$key}) {
      $lfspan = $iattr{$key};
      ($text, $lfspan) = &fix_framespan($lfspan);
      return($text, ()) if ($text !~ m%^\s*$%);
      
      $text = &framespan_is_within($lfspan, $fspan);
      return($text, ()) if ($text !~ m%^\s*$%);

      $text = &framespan_check_no_overlap($lfspan, @afspan);
      return($text, ()) if ($text !~ m%^\s*$%);

      push @afspan, $lfspan;

      delete $iattr{$key};
    } else {
      # if none was specified, it means that it is valid for the entire provided framespan
      $lfspan = $fspan;
    }

    # From here we work per 'data:' type
    $name =~ s%^data\:%%;
  SWITCH: {
      if ($name =~ m%^bbox$%) {
	($text, @{$attr{$name}{$lfspan}}) = &data_process_bbox(%iattr);
	last SWITCH;
      }
      if ($name =~ m%^point$%) {
	($text, @{$attr{$name}{$lfspan}}) = &data_process_point(%iattr);
	last SWITCH;
      }
      if ($name =~ m%^fvalue$%) {
	($text, @{$attr{$name}{$lfspan}}) = &data_process_fvalue(%iattr);
	last SWITCH;
      }
      if ($name =~ m%^dvalue$%) {
	($text, @{$attr{$name}{$lfspan}}) = &data_process_dvalue(%iattr);
	last SWITCH;
      }
      return("Unknown \'data\;\' type ($name)", ());
    }
    return($text, ()) if ($text !~ m%^\s*$%);
    
    debug_print(2, "[$name | $lfspan | " . join(" , ", @{$attr{$name}{$lfspan}}), "]\n");
  }

  return ("", %attr);

}

#####

sub parse_attributes {
  my $rstr = shift @_;
  my $fspan = shift @_;
  my %attrs;

  if ($fspan =~ m%^\s*$%) {
    if ($framespan_max eq $framespan_max_default) {
      $fspan = $framespan_max;
    } else {
      return("WEIRD: At this point the framespan range should be defined", ());
    }
  }
  
  # We process all the "attributes"
  while ($$rstr !~ m%^\s*$%) {
    my $sec = get_named_xml_section("attribute", $rstr);
    return ("Could not find an \'attribute\'", ()) if ($sec eq $default_error_value);

    # Get its name
    my ($text, %iattr) = &get_inline_xml_attributes("attribute", $sec);
    return($text, ()) if ($text !~ m%^\s*$%);

    return("Found more than one inline attribute for \'attribute\'", ())
      if (scalar %iattr != 1);
    return("Could not find the \'name\' of the \'attribute\'", ())
      if (! exists $iattr{"name"});

    my $name = $iattr{"name"};

    # Now get its content
    return("WEIRD: could not remove the \'attribute\' header and trailer tags", ())
      if (! &remove_xml_tags("attribute", \$sec));

    # Process the content
    $sec = &clean_begend_spaces($sec);
    
    if ($sec =~ m%^\s*$%) {
      $attrs{$name} = undef;
    } else {
      ($text, my %tmp) = &extract_data($sec, $fspan);
      return("Error while processing the \'data\:\' content of the \'$name\' \'attribute\' ($text)", ())
	if ($text !~ m%^\s*$%);
      %{$attrs{$name}} = %tmp;
    }
    
  } # while

  return ("", %attrs);
}

########################################
# xmllint check

sub get_tmpfilename {
  my ($fh, $name) = tempfile( UNLINK => 1 );

  return $name;
}

#####

sub slurp_file {
  my $fname = shift @_;

  open FILE, "<$fname"
    or error_quit("Can not open file to slurp ($fname): $!\n");
  my @all = <FILE>;
  close FILE;

  my $tmp = join(" ", @all);
  chomp $tmp;

  return $tmp;
}

#####

sub system_call {
  my @args = @_;
  
  my $cmdline = join(" ", @args);
  debug_print(1, "system_call [$cmdline]\n");

  my $retcode = -1;
  my $stdoutfile = &get_tmpfilename();
  my $stderrfile = &get_tmpfilename();

  open (CMD, "$cmdline 1> $stdoutfile 2> $stderrfile |");
  close CMD;
  $retcode = $?;

  my $stdout = slurp_file($stdoutfile);
  my $stderr = slurp_file($stderrfile);

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

  $txt =~ s%^\s+%%s;
  $txt =~ s%\s+$%%s;

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

##########

sub numerically {
  return ($a <=> $b);
}
