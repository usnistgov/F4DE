package MMisc;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# M's Misc Functions
#
# Author(s): Martial Michel
#

# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "MMisc.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

##### Warning: only use packages that are part of the 'Core Modules'
# see: http://perldoc.perl.org/index-modules-A.html
use Cwd qw(cwd abs_path);
use File::Basename 'dirname';
use Data::Dumper;
use File::Find;
use File::Temp qw(tempdir tempfile);
use File::Copy;
use List::Util qw(reduce);
use Time::HiRes qw(gettimeofday tv_interval);

##### For non 'Core Modules' you will need to load them from within the specific function
# (recommended to set a variable to avoid having to reload it)
my $DigestSHA_module = undef;
my $StatisticsDistributions_module = undef;
my $YAML_module = undef;
my $DataDump_module = undef;
my $AutoTable_module = undef;


########## No 'new' ... only functions to be useful

sub get_tmpdir {
  my $name = (defined $_[0]) ? tempdir($_[0] . '.XXXXXX', TMPDIR => 1) : tempdir();
  
  return($name) 
    if (-d $name);

  return($name)
    if (&make_wdir($name));

  # Directory does not exist and could not be created
  return(undef);
}

#####

# Request a temporary file (file is created)
sub get_tmpfile {
  my ($fh, $file) = (defined $_[0]) ? tempfile($_[0] . '.XXXXXX', TMPDIR => 1) : tempfile();
  return($file);
}

#####

sub slurp_file {
  my ($fname, $mode) = &iuav(\@_, '', 'text');

  return(undef) if (&is_blank($fname));

  my $out = '';
  open FILE, "<$fname"
    or return(undef);
  if ($mode eq 'bin') {
    binmode FILE;
    my $buffer = '';
    while ( read(FILE, $buffer, 65536) ) {
      $out .= $buffer;
    }
  } else {
    my @all = <FILE>;
    chomp @all;

    $out = fast_join("\n", \@all);
  }
  close FILE;

  return($out);
}

##########

sub check_package {
  my $package = &iuv($_[0], '');

  return(0) if (&is_blank($package));

  unless (eval "use $package; 1") {
    return(0);
  }

  return(1);
}

##########

sub get_env_val {
  # arg 0: env variable
  # arg 1: default returned value (if not set)
  my $envv = &iuv($_[0], '');

  return(undef) if (&is_blank($envv));

  return($_[1]) if (! exists $ENV{$envv});

  return($ENV{$envv});
}

##########

sub is_blank {
  # arg 0: variable to check
  return(1) if (! defined($_[0]));
  return(1) if (length($_[0]) == 0);

  return(1) if ($_[0] =~ m%^\s*$%s);

  return(0);
}

#####

sub any_blank {
  for (my $i = 0; $i < scalar @_; $i++) {
    my $v = $_[$i];
    return(1) if (&is_blank($v));
  }

  return(0);
}

#####

sub all_blank {
  for (my $i = 0; $i < scalar @_; $i++) {
    my $v = $_[$i];
    return(0) if (! &is_blank($v));
  }

  return(1);
}

##########

sub clean_beg_spaces {
  my $rstr = $_[0];

  my $cont = 1;
  while ((length($$rstr) > 1024) && ($cont)) {
    my $txt = substr($$rstr, 0, 1024, '');
    $txt =~ s%^\s+%%s;
    if (length($txt) > 0) {
      substr($$rstr, 0, 0, $txt);
      $cont = 0;
    }
  }
  $$rstr =~ s%^\s+%%s if ($cont == 1);
}

#####

sub clean_end_spaces {
  my $rstr = $_[0];

  my $cont = 1;
  while ((length($$rstr) > 1024) && ($cont)) {
    my $txt = substr($$rstr, -1024, 1024, '');
    $txt =~ s%\s+$%%s;
    if (length($txt) > 0) {
      $$rstr .= $txt;
      $cont = 0;
    }
  }
  $$rstr =~ s%\s+$%%s if ($cont == 1);
}

#####

sub clean_begend_spaces {
  my $txt = $_[0];

  return('') if (&is_blank($txt));

  &clean_beg_spaces(\$txt);
  &clean_end_spaces(\$txt);

  return($txt);
}

##########

sub reorder_array_numerically {
  # arg 0: ref to array of values
  return(sort { $a <=> $b } @{$_[0]});
}

####

sub get_msize {
  my $str = $_[0];
  my $x = `/bin/ps -aux | grep $$ | grep -v "grep" | awk '{print \$5}'`;
  $x =~ s/\s//g;
  return("$x $str");
}

#####

sub min_max { return(&min_max_r(\@_)); }

##

sub min_max_r {
  # arg 0: ref to array of values

  my $min = ${$_[0]}[0];
  my $max = $min;

  for (my $i = 1; $i < scalar @{$_[0]}; $i++) {
    my $v = ${$_[0]}[$i];
    $min = $v if ($v < $min);
    $max = $v if ($v > $max);
  }
  
  return($min, $max);
}

#####

sub min { return(List::Util::min(@_)); }

##

sub min_r {
  # arg 0: ref to array of values
  return(List::Util::max(@{$_[0]})); 
}

#####

sub max { return(List::Util::max(@_)); }

##

sub max_r {
  # arg 0: ref to array of values
  return(List::Util::max(@{$_[0]}));
}

##########

sub sum { return(List::Util::sum(\@_)); }

##

sub sum_r {
  # arg 0: ref to array of values
  return(List::Util::sum(@{$_[0]}));
}

##########

sub writeTo {
  my ($file, $addend, $printfn, $append, $txt,
      $filecomment, $stdoutcomment,
      $fileheader, $filetrailer, $makexec, $binmode)
    = &iuav(\@_, '', '', 0, 0, '', '', '', '', '', 0, '');

  my $rv = 1;

  my $ofile = '';
  if (! &is_blank($file)) {
    if (-d $file) {
      &warn_print("Provided file ($file) is a directory, will write to STDOUT\n");
      $rv = 0;
    } else {
      $ofile = $file;
      $ofile .= $addend if (! &is_blank($addend));
    }
  }

  my $da = 0;
  if (! &is_blank($ofile)) {
    my $tofile = $ofile;
    if ($append) {
      $da = 1 if (-f $ofile);
      open FILE, ">>$ofile" or ($ofile = '');
    } else {
      open FILE, ">$ofile" or ($ofile = '');
    }
    if (&is_blank($ofile)) {
      &warn_print("Could not create \'$tofile\' (will write to STDOUT): $!\n");
      $rv = 0;
    } else {
      binmode(FILE, $binmode) if (! MMisc::is_blank($binmode));
    }        
  }

  if (! &is_blank($ofile)) {
    print FILE $fileheader if (! &is_blank($fileheader));
    print FILE $txt;
    print FILE $filetrailer if (! &is_blank($filetrailer));
    close FILE;
    # Note: do not print action when writing to STDOUT (even when requested)
    print((($da) ? 'Appended to file:' : 'Wrote:') . " $ofile$filecomment\n") 
      if (($ofile ne '-') && ($printfn));
    if ($ofile ne '-') {
      if ($makexec) { # Make it executable (if requested)
        chmod(0755, $ofile);
      } else { # otherwise at least try to make it world readable
        chmod(0644, $ofile);
      }
    }
    return(1); # Always return ok: we requested to write to a file and could
  }

  # Default: write to STDOUT
  print $stdoutcomment;
  print $txt;
  return($rv); # Return 0 only if we requested a file write and could not, 1 otherwise
}

##########

sub clone {
  # Clone hash, arrays and scalars, but no specialized types
  map { ! ref() ? $_ : ref eq 'HASH' ? {clone(%$_)} : ref eq 'ARRAY' ? [clone(@$_)] : &error_quit("Cloning ($_) not supported") } @_;
}

##########

sub array1d_to_count_hash {
  # arg 0: ref to array of values
  my %ohash = ();
  for (my $i = 0; $i < scalar @{$_[0]}; $i++) {
    $ohash{${$_[0]}[$i]}++;
  }

  return(%ohash);
}

#####

sub array1d_to_ordering_hash {
  # arg 0: ref to array of values
  my %ohash = ();
  for (my $i = scalar(@{$_[0]}) - 1; $i >= 0; $i--) {
    $ohash{${$_[0]}[$i]} = $i;
  }

  return(%ohash);
}

#####

sub make_array_of_unique_values {
  # arg 0: ref to array of values

  return(@{$_[0]}) if (scalar @{$_[0]} < 2);

  my %tmp = &array1d_to_ordering_hash($_[0]);

  my @out = sort {$tmp{$a} <=> $tmp{$b}} keys %tmp;

  return(@out);
}

##########

sub compare_arrays {
  my ($rexp, $ra) = @_;

  my @in  = ();
  my @out = ();

  return(\@in, \@out) if (! defined $rexp);

  for (my $i = 0; $i < scalar @$rexp; $i++) {
    my $elt = $$rexp[$i];
    if (grep(m%^$elt$%i, @$ra)) {
      push @in, $elt;
    }
  }

  for (my $i = 0; $i < scalar @$ra; $i++) {
    my $elt = $$ra[$i];
    if (! grep(m%^$elt$%i, @$rexp)) {
      push @out, $elt;
    }
  }

  return(\@in, \@out);
}

#####

sub confirm_first_array_values {
  my ($rexp, $ra) = @_;

  my @in = ();
  my @out = ();

  return(\@in, \@out) if (! defined $rexp);

  for (my $i = 0; $i < scalar @$rexp; $i++) {
    my $elt = $$rexp[$i];
    if (grep(m%^$elt$%, @$ra)) {
      push @in, $elt;
    } else {
      push @out, $elt;
    }
  }

  return(\@in, \@out);
}

##########

sub get_array1posinarray2 {
  my ($ra1, $ra2) = @_;

  my @a1 = &make_array_of_unique_values($ra1);
  return("Array1 does not contain unique values")
    if (scalar @a1 != scalar @$ra1);

  my @a2 = &make_array_of_unique_values($ra2);
  return("Array2 does not contain unique values")
    if (scalar @a2 != scalar @$ra2);

  my %h2 = &array1d_to_ordering_hash(\@a2);

  my %match = ();
  my @bad = ();
  for (my $i = 0; $i < scalar @a1; $i++) {
    if (exists $h2{$a1[$i]}) {
      $match{$a1[$i]} = $h2{$a1[$i]};
    } else {
      push @bad, $a1[$i];
    }
  }

  return("Some values not in array comp: " . join(" ", @bad))
    if (scalar @bad > 0);

  return("", %match);
}

##########
# % perl -e 'use MMisc; print join(" *** ", MMisc::get_regexp_array1posinarray2(["m%af%i", "m%cr%i"], ["after", "before", "Crust"]));'
# *** m%cr%i *** 2 *** m%af%i *** 0
# <=> "" error message, match for 'm%cr%i' is '2' (ie 'Crust') and match for 'm%af%i' is '0' (ie 'after') 
sub get_regexp_array1posinarray2 {
  my ($ra1, $ra2) = @_;

  my @a1 = &make_array_of_unique_values($ra1);
  return("Array1 does not contain unique values")
    if (scalar @a1 != scalar @$ra1);

  my @a2 = &make_array_of_unique_values($ra2);
  return("Array2 does not contain unique values")
    if (scalar @a2 != scalar @$ra2);

  my %h2 = &array1d_to_ordering_hash(\@a2);

  my %match = ();
  my @bad = ();
  my @keys = keys %h2;
  for (my $i = 0; $i < scalar @a1; $i++) {
    my $v = $a1[$i];
    my $regexp = "grep {$v} \@keys";
    my @found = eval $regexp;
    if (scalar @found == 1) {
      $match{$a1[$i]} = $h2{$found[0]};
    } else {
      return("Found multiple possible match to $v (" . scalar @found . "): " . join(" | ", @found))
        if (scalar @found > 1);
      push @bad, $a1[$i];
    }
  }

  return("Some values not in array comp: " . join(" ", @bad))
    if (scalar @bad > 0);
  
  return("", %match);
}

##########

sub _uc_lc_array_values {
  my ($mode, $ra) = @_; 

  my @out = ();
  for (my $i = 0; $i < scalar @$ra; $i++) {
    my $value = $$ra[$i];
    my $v = ($mode == 1) ? uc($value) :
      ($mode == 2) ? lc($value) :
        ($mode == 3) ? ucfirst($value) :
          ($mode == 4) ? lcfirst($value) :
            $value;
    push @out, $v;
  }

  return(@out);
}

#####

sub uppercase_array_values {
  return(&_uc_lc_array_values(1, @_));
}

#####

sub lowercase_array_values {
  return(&_uc_lc_array_values(2, @_));
}

#####

sub ucfirst_array_values {
  return(&_uc_lc_array_values(3, @_));
}

#####

sub lcfirst_array_values {
  return(&_uc_lc_array_values(4, @_));
}

##########

sub arrays_unique_union {
  # arg 0: 1 keep first / otherwise keep last
  # args : reference to arrays
  my %tmp = ();
  my $inc = 0;
  
  my $v;
  for (my $i = 1; $i < scalar @_; $i++) {
    &error_quit("Using \'MMisc::arrays_unique_union\', argument \#$i: Not a reference to array")
      if (! ref($_[$i]));
    for (my $j = 0; $j < scalar @{$_[$i]}; $j++) {
      $v = ${$_[$i]}[$j];
      next if ((exists $tmp{$v}) && ($_[0]));
      $tmp{$v} = $inc++;
    }
  }

  return(sort {$tmp{$a} <=> $tmp{$b}} keys %tmp);
}

#####

sub arrays_intersection {
  # arg 0: 1 keep first / otherwise keep last
  # args 1 and 2 : reference to arrays to intersect (only two)

  &error_quit("Using \'MMisc::arrays_intersection\', not enough arguments (need: keep first + two reference to array)")
    if (scalar @_ != 3);

  for (my $i = 1; $i < scalar @_; $i++) {
    &error_quit("Using \'MMisc::arrays_intersection\', argument \#$i: Not a reference to array")
      if (! ref($_[$i]));
  }

  my %tmp = ();
  my $v;
  for (my $i = 0; $i < scalar @{$_[0]}; $i++) {
    $v = ${$_[0]}[$i];
    next if ((exists $tmp{$v}) && ($_[0]));
    $tmp{$v} = $i;
  }
  for (my $i = 0; $i < scalar @{$_[1]}; $i++) {
    $v = ${$_[1]}[$i];
    delete $tmp{$v};
  }

  return(sort {$tmp{$a} <=> $tmp{$b}} keys %tmp);
}

##########

sub get_decimal_length {
  my $v = &iuv($_[0], '');

  return(0) if (&is_blank($v));

  my $l = 0;

  $l = length($v)
    if ($v =~ s%^\d+\.%%);

  return($l);
}

#####

sub compute_precision {
  my ($v1, $v2) = &iuav(\@_, 0, 0);

  my $l1 = &get_decimal_length($v1);
  my $l2 = &get_decimal_length($v2);

  my $p = 0;
  if (($l1 == 0) && ($l2 == 0)) { # both ints
    $p = 0.5;
  } else {
    my $v = min($l1, $l2); # if l1 or l2 are not equal to 0
    $v = max($l1, $l2) if ($v == 0); # otherwise take the non 0 one
    $p = ($v > 1) 
      ? (1.0 / (10 ** ($v - 1) ) ) # and go to the 1 depth up
	: 1.0; # expected for case that are only 1 digit deep
  }

  return($p);
}

#####

sub are_float_equal {
  my ($v1, $v2, $p) = &iuav(\@_, 0, 0, 0.000001);

  $p = &compute_precision($v1, $v2) if ($p == 0);

  return(1) if (abs($v1 - $v2) < $p);

  return(0);
}

##########

sub __get_sorted_MemDump_YAML {
  my ($obj, $indent) = @_;

  ## Try to use YAML
  if (! defined $YAML_module) {
    &error_quit("Can not use the YAML module")
      if (! &check_package("YAML"));
    $YAML_module = "YAML";
  }

  # Save the default sort key
  my $s_dso = $YAML::Sortkeys;
  # Save the default indent
  my $s_din = $YAML::Indent;

  # sort
  $YAML::Sortkeys = 1;
  # request indent level
  $YAML::Indent = $indent;

  # Obtaing string
  my $str = YAML::Dump($obj);

  # Return original indent value
  $YAML::Indent = $s_din;
  # Return original sort keys values
  $YAML::Sortkeys = $s_dso;

  return($str);
}

##

sub __get_sorted_MemDump_Dump {
  my ($obj, $indent) = @_;

  ## Warning: output might not be sorted

  ## Try to use Data::Dump
  if (! defined $DataDump_module) {
    &error_quit("Can not use the Data::Dump module")
      if (! &check_package("Data::Dump"));
    $DataDump_module = "Data::Dump";
  }

  # Save the default indent
  my $s_din = $Data::Dump::INDENT;

  # Set requested indent level
  my $tmp = "";
  for (my $i = 0; $i < $indent; $i++) { $tmp .= ' '; }
  $Data::Dump::INDENT = $tmp;

  # Obtaing string
  my $str = Data::Dump::dump($obj);

  # Return orignal indent value
  $Data::Dump::INDENT = $indent;

  return($str);
}

##

sub get_sorted_MemDump {
  my ($obj, $indent, $method, $split) = 
    ($_[0], &iuv($_[1], 2), &iuv($_[2], 'dumper'), &iuv($_[3], 0));

  return(&__get_sorted_MemDump_YAML($obj, $indent))
    if (lc($method) eq 'yaml');

 return(&__get_sorted_MemDump_Dump($obj, $indent))
    if (lc($method) eq 'dump');

  MMisc::error_quit("Unknow \'get_sorted_MemDump\' Method ($method)")
      if (lc($method) ne 'dumper');

  # Save the default sort key
  my $s_dso = $Data::Dumper::Sortkeys;
  # Save the default indent
  my $s_din = $Data::Dumper::Indent;
  # Save the default Purity
  my $s_dpu = $Data::Dumper::Purity;

  # Force dumper to sort
  $Data::Dumper::Sortkeys = 1;
  # Force dumper to use requested indent level
  $Data::Dumper::Indent = $indent;
  # Purity controls how self referential objects are written
  $Data::Dumper::Purity = ($split) ? 0 : 1;

  # Get the Dumper dump
  my $str = Dumper($obj);

  # Reset the keys to their previous values
  $Data::Dumper::Sortkeys = $s_dso;
  $Data::Dumper::Indent   = $s_din;
  $Data::Dumper::Purity   = $s_dpu;

  return($str);
}

#####

sub dump_memory_object {
  my ($file, $ext, $obj, $txt_fileheader, $gzip_fileheader, $printfn, $method, $split) =
    &iuav(\@_, '', '', undef, undef, undef, 1, 'dumper', 0);

  return(0) if (! defined $obj);
  
  # The default is to write the basic text version
  my $fileheader = $txt_fileheader;
  my $str = &get_sorted_MemDump($obj, undef, $method, $split);

  # But if we provide a gzip fileheader, try it
  if (defined $gzip_fileheader) {
    my $tmp = &mem_gzip($str);
    if (defined $tmp) {
      # If gzip worked, we will write this version
      $str = $tmp;
      $fileheader = $gzip_fileheader;
    }
    # Otherwise, we will write the text version
  }

  my $headeradd = ($method ne 'dumper') ? "# MMisc::get_sorted_MemDump used method: [$method]\n\n" : "";
  return( &writeTo($file, $ext, $printfn, 0, $str, '', '', $fileheader . $headeradd, '') );
}

#####

sub __extract_method {
  my ($str) = @_;

  # Get only the first 4K to work with
  my $sv = substr($str, 0, 4096);

  # can we extract the method string identifier ?
  if ($sv =~ s%\#\sMMisc\:\:get\_sorted\_MemDump\sused\smethod\:\s\[(\w+)\]\n\n%%) {
    substr($str, 0, 4096, $sv); # fill removed header string
    return($str, $1);
  }

  return($str, 'dumper');
}

##

sub load_memory_object {
  my ($file, $gzhdsk) = &iuav(\@_, '', undef);

  return(undef) if (&is_blank($file));

  my $str = &slurp_file($file, 'bin');
  return(undef) if (! defined $str);

  ($str, my $method) = &__extract_method($str);

  if (defined $gzhdsk) {
    # It is possibly a gzip file => Remove the header ?
    my $tstr = &strip_header($gzhdsk, $str);
    if ($tstr ne $str) {
      # If we could remove the header, it means it is a gzip file: try to un-gzip
      my $tmp = &mem_gunzip($tstr);
      return(undef) if (! defined $tmp);
      # it is un-gzipped -> work with it
      $str = $tmp;
    }
  }

  return(&__load_Dump_memory_object($str))
    if (lc($method) eq 'dump');

  return(&__load_YAML_memory_object($str))
    if (lc($method) eq 'yaml');

  my $VAR1;
  eval $str;
  &error_quit("Problem in \'MMisc::load_memory_object()\' eval-ing code: " . join(" | ", $@))
    if $@;

  return($VAR1);
}

##

sub __load_YAML_memory_object {
  ## Try to use YAML
  if (! defined $YAML_module) {
    &error_quit("Can not use the YAML module")
      if (! &check_package("YAML"));
    $YAML_module = "YAML";
  }
  return(YAML::Load($_[0]));
 
}

##

sub __load_Dump_memory_object {
  my $val = eval $_[0];
  &error_quit("Problem in \'MMisc::load_memory_object()\' eval-ing code: " . join(" | ", $@))
    if $@;
  return($val);
}

##########

sub mem_gzip {
  my $tozip = &iuv($_[0], '');

  return(undef) if (&is_blank($tozip));

  my $filename = &get_tmpfile();
  open(FH, " | gzip > $filename")
    or return(undef);
  print FH $tozip;
  close FH;

  return(&slurp_file($filename, 'bin'));
}

#####

sub mem_gunzip {
  my $tounzip = &iuv($_[0], '');

  return(undef) if (&is_blank($tounzip));

  my $filename = &get_tmpfile();
  open FILE, ">$filename"
    or return(undef);
  print FILE $tounzip;
  close FILE;

  return(&file_gunzip($filename));
}

#####

sub file_gunzip {
  my $in = &iuv($_[0], '');

  return(undef) if (&is_blank($in));
  return(undef) if (! &is_file_r($in));

  my $unzip = '';
  open(FH, "gzip -dc $in |")
    or return(undef);
  while (my $line = <FH>) { 
    $unzip .= $line;
  }
  close FH;

  return(undef) if (&is_blank($unzip));

  return($unzip);
}

##########

sub strip_header {
  my ($header, $str) = &iuav(\@_, '', '');

  return($str) if (&is_blank($header));
  return('') if (&is_blank($str));
  
  my $lh = length($header);
  
  my $sh = substr($str, 0, $lh);

  return(substr($str, $lh))
    if ($sh eq $header);
  
  return($str);
}

##########

sub _system_call_logfile {
  my ($logfile, @rest) = @_;
  
  return(-1, '', '') if (scalar @rest == 0);

  my $cmdline = '(' . join(' ', @rest) . ')'; 

  my $retcode = -1;
  my $signal = 0;
  my $stdoutfile = '';
  my $stderrfile = '';
  if ((! defined $logfile) || (&is_blank($logfile))) {
    # Get temporary filenames (created by the command line call)
    $stdoutfile = &get_tmpfile();
    $stderrfile = &get_tmpfile();
  } else {
    $stdoutfile = $logfile . '.stdout';
    $stderrfile = $logfile . '.stderr';
    # Create a place holder for the final logfile
    open TMP, ">$logfile"
      or return(-1, '', '');
    print TMP "Placedholder for final combined log\n\nCommandline: [$cmdline]\n\nSee \"$stdoutfile\" and \"$stderrfile\" files until the process is concluded\n";
    close TMP
  }

  my $ov = $|;
  $| = 1;

  open (CMD, "$cmdline 1> $stdoutfile 2> $stderrfile |");
  close CMD;
  $retcode = $? >> 8;
  $signal = $? & 127;

  $| = $ov;

  # Get the content of those temporary files
  my $stdout = &slurp_file($stdoutfile);
  my $stderr = &slurp_file($stderrfile);

  # Erase the temporary files
  unlink($stdoutfile);
  unlink($stderrfile);

  return($retcode, $stdout, $stderr, $signal);
}

#####

sub do_system_call {
  return(&_system_call_logfile(undef, @_));
}

#####

sub write_syscall_logfile {
  my $ofile = &iuv(shift @_, '');

  return(0, '', '', '', '') 
    if ( (&is_blank($ofile)) || (scalar @_ == 0) );

  my ($retcode, $stdout, $stderr, $signal) = &_system_call_logfile($ofile, @_);

  my $otxt = '[[COMMANDLINE]] ' . join(' ', @_) . "\n"
    . "[[RETURN CODE]] $retcode\n"
    . ( ($signal > 0) ? "[[SIGNAL]] $signal\n" : "" )
    . "[[STDOUT]]\n$stdout\n\n"
    . "[[STDERR]]\n$stderr\n";

  return(0, $otxt, $stdout, $stderr, $retcode, $ofile, $signal)
    if (! &writeTo($ofile, '', 0, 0, $otxt));

  return(1, $otxt, $stdout, $stderr, $retcode, $ofile, $signal);
}

#####

sub write_syscall_smart_logfile {
  my $ofile = &iuv(shift @_, '');

  return(0, '', '', '', '') 
    if ( (&is_blank($ofile)) || (scalar @_ == 0) );

  if (-e $ofile) {
    my $date = `date "+20%y%m%d-%H%M%S"`;
    chomp($date);
    $ofile .= "-$date";
  }

  return(&write_syscall_logfile($ofile, @_));
}

##########
# vprint(Yes, ToPrint)
## Print "ToPrint" only if "Yes" is true
sub vprint {
  my $yes = shift @_;
  return() if (! $yes);
  print join("", @_);
}

##########
# miniJobRunner(verbose, rerunIfBad, baseLockDirectory, baseJobID, commandtorun)
#### bare component of the full JobRunner tool, designed to simply run a JobID
# if it was not run in the past or currently in progress
## input: (verbose, rerunIfBad, baseLockDirectory, baseJobID, commandtorun)
# verbose=0,1,2: print run status information
# rerunIfBad=0,1: rerun a job if it was in the past but failed to succesfully complete
# baseLockDirectory=path: location of base lock directory
# baseJobID=string: name given by user to job, is used to create uniqueness
# commandtorun=array: command to run (full path recommended)
## return: (errstring, wasJobRun, ...)
# errstring=string: if non blank, contains an error message from miniJobRunner
# wasJobRun=0,1: only set to 1 if the job was run
# "..." are the usual return values from 'write_syscall_logfile'; will only be present if 'wasJobRun' is true(=1)
sub miniJobRunner {
  my ($verb, $redobad, $blockdir, $toprint, @cmd) = @_;

  my $err = "";
  # clean up jobid
  my $name = $toprint;
  $name =~ s%^\s+%%;
  $name =~ s%\s+$%%;
  $name =~ s%[^a-z0-9-_]%_%ig;
  return("No \'jobid\' specified, aborting", 0)
    if (&is_blank($name));

  # check lock dir
  $blockdir =~ s%\/$%%; # remove trailing /
  $blockdir = &get_file_full_path($blockdir);
  return("No \'lockdir\' specified, aborting", 0)
    if (&is_blank($blockdir));
  $err = &check_dir_w($blockdir);
  return("Problem with \'lockdir\' : $err", 0)
    if (! &is_blank($err));
  my $lockdir = "$blockdir/$name";
  return("The lockdir directory ($lockdir) must not exist", 0)
    if (&does_dir_exist($lockdir));

  # check for badly formed lockdir
  my @dir_end = ("done", "skip", "bad", "inprogress");
  my $ds_sep  = "_____";
  my @all = ();
  foreach my $end (@dir_end) {
    my $tmp = "${ds_sep}$end";
    return("Requested lockdir can not end in \'$tmp\' ($lockdir)", 0)
      if ($lockdir =~ m%$tmp$%i);
    push @all, "$lockdir$tmp";
  }
  my ($dsDone, $dsSkip, $dsBad, $dsRun) = @all;

  my $blogfile = "logfile";
  my $toprint2 = (! &is_blank($toprint)) ? "$toprint -- " : ""; 
  
  # check for multiple state lock directory
  my @mulcheck = ();
  foreach my $tmpld (@all) {
    push(@mulcheck, $tmpld) if (&does_dir_exist($tmpld));
  }
  return("Can not run program, lockdir already exists in multiple states:\n - " . join("\n - ", @mulcheck), 0)
    if (scalar @mulcheck > 1);
  
  ## Skip ?
  if (&does_dir_exist($dsSkip)) {
    &vprint($verb, "[miniJobRunner] ${toprint2}Skip requested\n");
    return("", 0);
  }

  ## Previously bad ?
  if (&does_dir_exist($dsBad)) {
      if (! $redobad) {
        &vprint($verb, "[miniJobRunner] ${toprint2}Previous bad run present, skipping\n");
        return("", 0);
      }
      
      &vprint($verb, "[miniJobRunner] ${toprint2}Deleting previous run lockdir [$dsBad]\n");
      `rm -rf $dsBad`;
      return("Problem deleting \'bad\' lockdir [$dsBad], still present ?", 0)
        if (&does_dir_exist($dsBad));
    }

  ## Previously done ?
  if (&does_dir_exist($dsDone)) {
    my $flf = "$dsDone/$blogfile";
    if (&does_file_exist($flf)) {
      vprint($verb, "[miniJobRunner] ${toprint2}Previously succesfully completed\n");
      return("", 0);
    } else {
      vprint($verb, "[miniJobRunner] ${toprint2}Previously succesfully completed, but logfile absent => considering as new run, Deleting previous run lockdir [$dsDone]\n");
      `rm -rf $dsDone`;
      return("Problem deleting lockdir [$dsDone], still present ?", 0)
        if (&does_dir_exist($dsDone));
    }
  }

  ## Already in progress ?
  if (&does_dir_exist($dsRun)) {
    &vprint($verb, "[miniJobRunner] ${toprint2}Job already in progress, Skipping\n");
    return("", 0);
  }

  # Actual run
  &vprint($verb, "[miniJobRunner] ${toprint2}In progress\n");
  &vprint(($verb > 1), "[miniJobRunner] ${toprint2}Creating \"In Progress\" lock dir\n");
  return("Could not create writable dir ($dsRun)", 0)
    if (! &make_wdir($dsRun));
  my $flf = "$dsRun/$blogfile";

  my ($rv, $tx, $so, $se, $retcode, $flogfile, $signal)
    = &write_syscall_logfile($flf, @cmd);
  vprint(($verb > 1), "[miniJobRunner] ${toprint2}Final Logfile different from expected one: $flogfile\n")
    if ($flogfile ne $flf);

  if (($retcode == 0) && ($signal == 0)) {
    return("Could not rename [$dsRun] to [$dsDone]: $!", 1, $rv, $tx, $so, $se, $retcode, $flogfile)
      if (! rename($dsRun, $dsDone));
    $flogfile =~ s%$dsRun%$dsDone%;
    vprint($verb, "[miniJobRunner] ${toprint2}Job succesfully completed\n");
    return("", 1, $rv, $tx, $so, $se, $retcode, $flogfile, $signal);
  }

  ## If we are here, it means it was a BAD run
  return("Could not rename [$dsRun] to [$dsBad]: $!", 1, $rv, $tx, $so, $se, $retcode, $flogfile, $signal)
    if (! rename($dsRun, $dsBad));
  $flogfile =~ s%$dsRun%$dsBad%;
  return("Error during run, see logfile ($flogfile)", 1, $rv, $tx, $so, $se, $retcode, $flogfile);
}

####################
# Get SHA capabilities

sub __check_SHAxxx {
  my $digest = eval { $DigestSHA_module->new($_[0])->add("string") };
  return(0) if ($@);
  return(1);
}

my @expSHAs = (1, 224, 256, 384, 512, 512224, 512256);
my @okSHAs = ();

sub __get_SHAmodule {
  return("") if (defined $DigestSHA_module);
  
  ## Try to use Digest::SHA.  If not installed, use the slower
  ## but functionally equivalent Digest::SHA::PurePerl instead.

  if (&check_package("Digest::SHA")) {
    $DigestSHA_module = "Digest::SHA";
  } elsif (&check_package("Digest::SHA::PurePerl")) {
    $DigestSHA_module = "Digest::SHA::PurePerl";
  } else {
    return("Unable to find Digest::SHA or Digest::SHA::PurePerl");
  }
  
  foreach my $sha (@expSHAs) {
    push(@okSHAs, $sha)
      if (&__check_SHAxxx($sha));
  }

  return("");
}


sub Available_SHAdigest {
  my $err = &__get_SHAmodule();
  &error_quit("Problem obtaining SHA list: $err")
    if (! MMisc::is_blank($err));

  return(@okSHAs);
} 

##########
# file_shaXXXdigest(FileName)
## return(errstring, hexdigest)
# ie an error message if any as well as the hex digest of the given file
# (adapted from 'shasum' 's 'sumfile')
sub file_shaXXXdigest {
  my ($xxx, $file) = @_;

  my $err = &check_file_r($file);
  return("Problem with input file ($file): $err")
    if (! &is_blank($err));

  $err = &__get_SHAmodule();
  return($err) if (! MMisc::is_blank($err));

  return("Can not do requested SHA Digest ($xxx), capability: " . join(" ", @okSHAs))
    if (! grep(m%^$xxx$%, @okSHAs));

  my $digest = eval { $DigestSHA_module->new(256)->addfile($file, 'b') };
  if ($@) { return("Problem reading file ($file): $!"); }
  return("", $digest->hexdigest);
}

# Valid XXX values: 1 224 256 384 512 512/224 512/256
sub file_sha1digest   { return(&file_shaXXXdigest(1,   $_[0])); }
sub file_sha224digest { return(&file_shaXXXdigest(224, $_[0])); }
sub file_sha256digest { return(&file_shaXXXdigest(256, $_[0])); }
sub file_sha384digest { return(&file_shaXXXdigest(384, $_[0])); }
sub file_sha512digest { return(&file_shaXXXdigest(512, $_[0])); }
sub file_sha512224digest { return(&file_shaXXXdigest(512224, $_[0])); }
sub file_sha512256digest { return(&file_shaXXXdigest(512256, $_[0])); }


#####
# string_shaXXXdigest(string)
## return(errstring, hexdigest)
# ie an error message if any as well as the hex digest of the given string
# (adapted from 'shasum' 's 'sumfile')
sub string_shaXXXdigest {
  my ($xxx, $string) = @_;

  return("Empty string")
    if (&is_blank($string));

  my $err = &__get_SHAmodule();
  return($err) if (! MMisc::is_blank($err));

  return("Can not do requested SHA Digest ($xxx), capability: " . join(" ", @okSHAs))
    if (! grep(m%^$xxx$%, @okSHAs));

  my $digest = eval { $DigestSHA_module->new($xxx)->add($string) };
  if ($@) { return("Problem analyzing string: $!"); }
  return("", $digest->hexdigest);
}

# Valid XXX values: 1 224 256 384 512 512/224 512/256
sub string_sha1digest   { return(&string_shaXXXdigest(1,   $_[0])); }
sub string_sha224digest { return(&string_shaXXXdigest(224, $_[0])); }
sub string_sha256digest { return(&string_shaXXXdigest(256, $_[0])); }
sub string_sha384digest { return(&string_shaXXXdigest(384, $_[0])); }
sub string_sha512digest { return(&string_shaXXXdigest(512, $_[0])); }
sub string_sha512224digest { return(&string_shaXXXdigest(512224, $_[0])); }
sub string_sha512256digest { return(&string_shaXXXdigest(512256, $_[0])); }

#####

sub unitTest_stringSHAdigest {
  # Lorem Ipsum: http://www.lipsum.com/
  my $teststring = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur eleifend erat et magna molestie tincidunt sagittis nulla consequat. Morbi vitae dui leo. Nullam sagittis ultricies orci quis sodales. Praesent varius dictum massa id eleifend. Maecenas condimentum, elit a scelerisque pellentesque, ante mauris varius turpis, nec commodo risus velit ut augue. Aliquam erat volutpat. Fusce in ligula nisi, vitae lacinia sem. Phasellus posuere urna scelerisque est ultrices imperdiet ornare nisi tempor. In et neque nunc. Praesent scelerisque consectetur neque, at sollicitudin dolor luctus at. Aliquam dolor dui, suscipit eget dignissim vitae, aliquet at elit. Proin eget ante massa.\nSuspendisse molestie euismod lacus vitae tempus. Praesent sodales convallis diam, in aliquam tellus lobortis nec. Nullam et sem ante. Aliquam libero turpis, blandit ac sollicitudin non, faucibus nec ligula. Suspendisse sed quam orci. Proin sit amet enim purus, ac commodo odio. Vivamus vitae ultricies nibh. Cras venenatis justo non felis tempus blandit.\nSed aliquam mauris accumsan tortor bibendum cursus mollis urna volutpat. Donec at neque id massa rutrum accumsan id a libero. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis vel nibh justo. Donec ultrices erat rhoncus justo mollis eu ultrices metus tincidunt. Sed tincidunt, nisl nec pretium volutpat, augue eros venenatis ante, ac aliquam urna ipsum ac augue. Pellentesque aliquam, dolor sit amet suscipit sagittis, ante libero malesuada tortor, ut dapibus quam urna non sapien. Maecenas vestibulum tincidunt tempor. Integer congue mi a erat congue vestibulum. Aliquam erat volutpat. Morbi euismod dictum eros non luctus. Curabitur tristique ornare nisl, et sagittis tortor fermentum vel. Sed ornare dictum magna, at semper enim convallis ac. Phasellus erat est, bibendum et volutpat vel, pellentesque non leo.\nUt eleifend malesuada dolor eu sodales. Nunc nisi enim, tempus scelerisque malesuada ut, elementum sit amet urna. Vivamus velit libero, consequat at porttitor vitae, posuere ut magna. Praesent eu arcu et leo fringilla cursus. Fusce ultrices aliquet risus, eget congue ipsum porttitor eget. Fusce in nunc leo. Curabitur luctus felis sed ligula scelerisque bibendum. Aliquam vel libero dui, non tristique dolor. Nunc ut gravida dui. Etiam vitae quam odio. Nunc semper turpis nec libero volutpat pellentesque. Aenean convallis, nisl luctus volutpat sollicitudin, diam magna mollis eros, eget blandit dolor lectus vel enim. Fusce erat nulla, posuere id pulvinar ac, condimentum in tellus. Nulla facilisi. Cras quam purus, ultrices vel aliquam eget, condimentum vel lacus. Sed porta, arcu id consequat laoreet, turpis arcu ornare odio, at vestibulum elit lorem vitae ante.\nCurabitur faucibus, tellus consectetur facilisis porta, tortor risus interdum erat, in scelerisque leo enim vitae leo. Integer dignissim, justo quis pellentesque porttitor, diam turpis vehicula purus, sed congue massa odio sed nunc. Aenean condimentum pharetra ornare. Quisque vehicula varius eros sit amet congue. Nulla venenatis vehicula cursus. Proin vel metus quam, et vestibulum nibh. Vestibulum egestas dictum quam luctus bibendum. Etiam quis volutpat nibh. Etiam ornare purus vitae lectus rutrum vestibulum. Aenean scelerisque sagittis dui sollicitudin porta. Curabitur cursus tincidunt convallis. Integer eu urna mauris. Cras sagittis neque vel nisi tempus at dictum nisl mattis. Curabitur a lacus malesuada risus feugiat rhoncus vitae in sapien. Proin placerat consequat porttitor.\n";

  my @todo = @expSHAs;
  my @capable = &Available_SHAdigest();
  my %comps = 
    (
     $todo[0] => '64fba7a0aef72094c65b09264f33c54408af90aa', # 1
     $todo[1] => 'c1fff0ef3ecbf6792a89df3bffe4d69b1055d0d78a0c0bb7245080c5', # 224
     $todo[2] => 'bedb5c5274a6ea58929c9fd03b8fa8efb48fe3e88613e8ecd1b5248fd4e27049', # 256
     $todo[3] => 'dee0c37e92be73ef83df176bef3add5e813bb70aa7cb8d69cc5088fb68281c11b751125bc9b7e8ae127bd9aa2ce424a4', # 384
     $todo[4] => '66e6bc053d3baaa76eed667af8b2c01b7c1fc3d1a1c8a2c5e8b2b8f6ca91bb4f74b91c95dfa3f1ea440ee101aa64e01d3281a69096b5c747206379ba37af4266', # 512
     $todo[5] => '5c16d5a9015051438705118852401cfb365cba090025f88f029fdc2c', # 512224
     $todo[6] => '8fef1afd622530170acbcda890cc1c7d3639b3febe6969b8d88b56fe9ba2a1eb', # 512256
    );
  print " Testing SHA digest string computation:\n";
  my $fail = 0;
  foreach my $check (@todo) {
    print "  SHA $check ... ";
    if (! grep(m%^$check$%, @capable)) {
      print "skipping (not available for this version of Perl)\n";
    } else {
      my $comp = $comps{$check};
      my $res = &string_shaXXXdigest($check, $teststring);
      if ($comp eq $res) {
        print "ok\n";
      } else {
        print "failed\n";
#      print "[$res]\{$comp\}\n";
        $fail++;
      }
    }
  }

  return($fail)
}

##########

sub __find_pre {
  my $v = &get_file_full_path($_[0]);
  return(MMisc::check_dir_r($v), $v);
 }
 
sub find_all {
  my ($err, $v) = &__find_pre($_[0]);
  return("Problem with dir ($v): $err") if (! MMisc::is_blank($err));
  my @out = ();
  find({ wanted => sub { push @out, $_; }, no_chdir => 1 }, $v);
  return("", @out);
}

sub find_all_files {
  my ($err, $v) = &__find_pre($_[0]);
  return("Problem with dir ($v): $err") if (! MMisc::is_blank($err));
  my @out = ();
  find({ wanted => sub { if (-f $_) {push @out, $_;} }, no_chdir => 1 }, $v);
  return("", @out);
}

sub find_all_dirs {
  my ($err, $v) = &__find_pre($_[0]);
  return("Problem with dir ($v): $err") if (! MMisc::is_blank($err));
  my @out = ();
  find({ wanted => sub { if (-d $_) {push @out, $_;} }, no_chdir => 1 }, $v);
  return("", @out);
}

##########

sub find_Module_location {
  my $m = $_[0];
  return(undef) if (! &check_package($m));

  $m =~ s%::%\/%g;
  $m =~ s/$/.pm/;
  return(&get_file_full_path($INC{$m})) 
    if ((require $m) && (exists $INC{$m}));

  return(undef); # returns undef if it could not found
}

##

sub find_Module_path {
  my $m = $_[0];
  my $v = &find_Module_location($m);
  return(undef) if (! defined $v);

  $m =~ s%::%\/%g;
  $m =~ s/$/.pm/;
  $v =~ s%$m$%%;
  $v =~ s%\/$%%;
  # Warning will return the base path in which A::B (ie A/B.pm) can be found
  return($v);
}

##########

sub get_txt_last_Xlines {
  my ($txt, $X) = &iuav(\@_, '', 0);

  my @out = ();

  return(@out) if ( (&is_blank($txt)) || ($X == 0) );

  my @toshowa = ();
  my @a = split(m%\n%, $txt);
  my $e = scalar @a;
  my $b = (($e - $X) > 0) ? ($e - $X) : 0;
  for (my $i = $b; $i < $e; $i++) {
    push @toshowa, $a[$i];
  }

  return(@toshowa);
}

##########

sub cmd_which {
  my $cmd = $_[0];
  
  my ($retcode, $stdout, $stderr) = &do_system_call('which', $cmd);
  
  return(undef) if ($retcode != 0);

  return($stdout);
}

## 

sub smart_cmd_which {
  my ($cmd, @rest) = split(m%\s+%, $_[0]);
  
  my $ret = &cmd_which($cmd);
  return(undef) if (! defined $ret);
  
  return(join(" ", $ret, @rest));
}

####################

sub __printto_core { if (shift @_ == 2) { print STDERR join("", @_) } else { print join("", @_) } }

##########

sub __warn_print_core { &__printto_core(shift @_, '[Warning] ' . join(' ', @_) . "\n"); }
sub warn_print { &__warn_print_core(1, @_); }
sub stderr_warn_print { &__warn_print_core(2, @_); } 

##########

#  $Carp::Verbose = 1;  carp(1);
sub error_exit { exit(1); }

sub __error_quit_core { &__printto_core(shift @_, '[ERROR] ' . join(' ', @_) . "\n"); }
sub error_quit { &__error_quit_core(1, @_); &error_exit(); }
sub stderr_error_quit { &__error_quit_core(2, @_); &error_exit(); }

##########

sub ok_exit { exit(0); }

sub __ok_quit_core { &__printto_core(shift @_, join(' ', @_) . "\n"); }
sub ok_quit { &__ok_quit_core(1, @_); &ok_exit(); }
sub stderr_ok_quit { &__ok_quit_core(2, @_); &ok_exit(); }


####################

sub _check_file_dir_core {
  my ($entity, $mode) = &iuav(\@_, '', '');

  return('empty mode')
    if (&is_blank($mode));

  return("empty $mode name")
    if (&is_blank($entity));
  return("$mode does not exist")
    if (! -e $entity);
  if ($mode eq 'dir') {
    return("is not a $mode")
      if (! -d $entity);
  } elsif ($mode eq 'file') {
    return("is not a $mode")
      if (! -f $entity);
  }

  return('');
}  

#####

sub _check_file_dir_XXX {
  my ($mode, $totest, $x) = &iuav(\@_, '', '', '');

  return('empty mode')
    if (&is_blank($mode));
  return('empty test')
    if (&is_blank($totest));

  my $txt = &_check_file_dir_core($x, $mode);
  return($txt) if (! &is_blank($txt));

  return('') if ($totest eq 'e');

  if ($totest eq 'r') {
    return("$mode is not readable")
      if (! -r $x);
  } elsif ($totest eq 'w') {
    return("$mode is not writable")
      if (! -w $x);
  } elsif ($totest eq 'x') {
    return("$mode is not executable")
      if (! -x $x);
  } else {
    return('unknown mode');
  }

  return('');
}

#####

sub check_file_e { return(&_check_file_dir_XXX('file', 'e', $_[0])); }
sub check_file_r { return(&_check_file_dir_XXX('file', 'r', $_[0])); }
sub check_file_w { return(&_check_file_dir_XXX('file', 'w', $_[0])); }
sub check_file_x { return(&_check_file_dir_XXX('file', 'x', $_[0])); }

sub check_dir_e { return(&_check_file_dir_XXX('dir', 'e', $_[0])); }
sub check_dir_r { return(&_check_file_dir_XXX('dir', 'r', $_[0])); }
sub check_dir_w { return(&_check_file_dir_XXX('dir', 'w', $_[0])); }
sub check_dir_x { return(&_check_file_dir_XXX('dir', 'x', $_[0])); }

sub does_file_exist { return( &is_blank( &check_file_e($_[0]) ) ); }
sub is_file_r { return( &is_blank( &check_file_r($_[0]) ) ); }
sub is_file_w { return( &is_blank( &check_file_w($_[0]) ) ); }
sub is_file_x { return( &is_blank( &check_file_x($_[0]) ) ); }

sub does_dir_exist { return( &is_blank( &check_dir_e($_[0]) ) ); }
sub is_dir_r { return( &is_blank( &check_dir_r($_[0]) ) ); }
sub is_dir_w { return( &is_blank( &check_dir_w($_[0]) ) ); }
sub is_dir_x { return( &is_blank( &check_dir_x($_[0]) ) ); }

#####

sub get_file_stat {
  my $file = &iuv($_[0], '');

  my $err = &check_file_e($file);
  return($err, undef) if (! &is_blank($err));

  my @a = stat($file);

  return("No stat obtained ($file)", undef)
    if (scalar @a == 0);

  return('', @a);
}

#####

sub _get_file_info_core {
  my ($pos, $file) = &iuav(\@_, -1, '');

  return(undef, 'Problem with function arguments')
    if ( ($pos == -1) || (&is_blank($file)) );

  my ($err, @a) = &get_file_stat($file);

  return(undef, $err)
    if (! &is_blank($err));

  return($a[$pos], '');
}

#####

sub get_file_uid   {return(&_get_file_info_core(4, @_));} 
sub get_file_gid   {return(&_get_file_info_core(5, @_));} 
sub get_file_size  {return(&_get_file_info_core(7, @_));} 
sub get_file_atime {return(&_get_file_info_core(8, @_));} 
sub get_file_mtime {return(&_get_file_info_core(9, @_));} 
sub get_file_ctime {return(&_get_file_info_core(10, @_));} 

#####  

# Note: will only keep "ok" files in the output list
sub sort_files {
  my $criteria = &iuv($_[0], '');

  my $func = undef;
  if ($criteria eq 'size') {
    $func = \&get_file_size;
  } elsif ($criteria eq 'atime') {
    $func = \&get_file_atime;
  } elsif ($criteria eq 'mtime') {
    $func = \&get_file_mtime;
  } elsif ($criteria eq 'ctime') {
    $func = \&get_file_ctime;
  } else {
    return('Unknown criteria', undef);
  }

  my %tmp = ();
  my @errs = ();
  for (my $i = 1; $i < scalar @_; $i++) {
    my $file = $_[$i];
    my ($v, $err) = &$func($file);
    if (! &is_blank($err)) {
      push @errs, $err;
      next;
    }
    if (! defined $v) {
      push @errs, "Undefined value for \'$file\''s \'$criteria\'";
      next;
    }
    $tmp{$file} = $v;
  }

  my @out = sort { $tmp{$a} <=> $tmp{$b} } keys %tmp;

  my $errmsg = join('. ', @errs);

  return($errmsg, @out);
}

#####

# Note: will return undef if any file in the list is not "ok"
sub _XXXest_core {
  my $mode = &iuv(shift @_, '');

  my @out = ();

  return(@out) if (&is_blank($mode));

  my ($err, @or) = &sort_files($mode, @_);

  return(@out)
    if (scalar @or != scalar @_);

  return(@or);
}

#####

sub newest {
  my @or = &_XXXest_core('mtime', @_);

  return(undef) if (scalar @or == 0);

  return($or[-1]);
}

#####

sub oldest {
  my @or = &_XXXest_core('mtime', @_);

  return(undef) if (scalar @or == 0);

  return($or[0]);
}

#####

sub biggest {
  my @or = &_XXXest_core('size', @_);

  return(undef) if (scalar @or == 0);

  return($or[-1]);
}

#####

sub smallest {
  my @or = &_XXXest_core('size', @_);

  return(undef) if (scalar @or == 0);

  return($or[0]);
}

####################

# Will create directories up to requested depth
sub make_dir {
  my ($dest, $perm) = &iuav(\@_, '', 0755);

  return(0) if (&is_blank($dest));

  return(1) if (-d $dest);

  $perm = 0755 if (&is_blank($perm)); # default permissions

  my $t = '';
  my @todo = split(m%/%, $dest);
  for (my $i = 0; $i < scalar @todo; $i++) {
    my $d = $todo[$i];
    $t .= "$d/";
    next if (-d $t);

    mkdir($t, $perm);
    last if (! -d $t);
  }

  return(0) if (! -d $dest);

  return(1);
}

sub make_wdir {
  my $ok = &make_dir(@_);
  return($ok) if (! $ok);
  return(&is_dir_w($_[0]));
}

##########

sub follow_link {
  if (-l $_[0]) { return(readlink($_[0])); }
  return($_[0]);
}

#####

sub list_dirs_files {
  my $dir = &iuv($_[0], '');
  my $fullpath = &iuv($_[1], 0);
  # when requesting the full file path, does not just return the list of files or directory contained, return the full path filename
    
  return('Empty dir name', undef, undef, undef)
    if (&is_blank($dir));

  opendir DIR, "$dir"
    or return("Problem opening directory ($dir) : $!", undef, undef, undef);
  my @fl = grep(! m%^\.\.?%, readdir(DIR));
  close DIR;

  my @d = ();
  my @f = ();
  my @u = ();
  for (my $i = 0; $i < scalar @fl; $i++) {
    my $entry = $fl[$i];
    my $ff = "";
    if ($fullpath) {
      my $fd = &get_dir_actual_dir($dir);
      $ff = "$fd/$entry";
      $entry = $ff;
    } else {
      $ff = &follow_link("$dir/$entry", $dir);
      $ff = "$dir/$ff" if ($ff ne "$dir/$entry");
    }

    if (-d $ff) {
#      print "[D] $entry -> $ff\n";
      push @d, $entry;
      next;
    }
    if (-f $ff) {
#      print "[F] $entry -> $ff\n";
      push @f, $entry;
      next;
    }
    
#    print "[?] $entry -> $ff\n";
    push @u, $entry;
  }

  return('', \@d, \@f, \@u);
}

#####

sub get_dirs_list { return(&_get_files_dir_list_core($_[0], 0)); }

sub get_files_list { return(&_get_files_dir_list_core($_[0], 1)); }

sub _get_files_dir_list_core {
  # 0: dir | 1: 0=dir/1=file
  my $dir = &iuv($_[0], '');
  my @out = ();
  return(@out) if (&is_blank($dir));
  my ($err, $rd, $rf, $ru) = &list_dirs_files("$dir/.");
  if (! &is_blank($err)) {
    &warn_print("While checking dir ($dir): $err");
    return(@out);
  }
  return(@{$rf}) if ($_[1] == 1);
  return(@{$rd});
}

##########

sub split_dir_file_ext {
  my $ff = &iuv($_[0], '');

  return ('empty filename', '', '', '')
    if (&is_blank($ff));

  my $dir = '';
  my $file = '';
  my $ext = '';

  my $tkf = '';

  $dir = $1 if ($ff =~ s%^(\/)%%);

  while ($ff =~ s%^(.*?\/)%%) {
    $dir .= $1;
  }

  $tkf = $1 if ($ff =~ s%^([\.]+)([^\.])%$2%);

  $ext = $2 if ($ff =~ s%^([^\.]+?)\.(.+)$%$1%);

  # Note that 'file' can be a '.cshrc' file 
  $file = $tkf . $ff;

  return('', $dir, $file, $ext);
}

##########

sub concat_dir_file_ext {
  my ($dir, $file, $ext) = &iuav(\@_, '', '', '');

  my $out = '';

  if (! &is_blank($dir)) {
    $dir =~ s%/$%%;
    $out .= "$dir/";
  }

  $out .= $file;

  $ext =~ s%^\.%%;
  $out .= ".$ext" if (! &is_blank($ext));

  return($out);
}

##########

sub get_pwd { return(cwd()); }

#####

sub get_file_full_path {
  my ($rp, $from) = &iuav(\@_, '', &get_pwd());

  return($rp) if (&is_blank($rp));

  my $f = $rp;
  $f = "$from/$rp" if ($rp !~ m%^\/%);

  my $o = abs_path($f);

  $o = $f
    if (&is_blank($o)); # The request PATH does not exist, fake it

  return($o);
}

#####

# careful, these functions follow symlinks
sub get_file_actual_dir { return(dirname(abs_path($_[0]))); }
sub get_dir_actual_dir  { return(abs_path($_[0])); }
sub get_file_actual_file { return(&get_dir_actual_dir($_[0])); }

#####


## compute_actual_dir_relative_path(from, to [, force_relative])
#   tells how to cd from 'from' dir to get to 'to' dir
# warning: use 'get_file_actual_dir'
# notes:
# - if a relative path is not possible (ie dirs differ from / forward), return dir1
#   unless 'force_relative' is true, in which case a relative path will be computed
# - only for directories AND directories need to exist already
# - return 'undef' in case of problem
sub compute_actual_dir_relative_path {
  my ($d1, $d2, $force_relative) = &iuav(\@_, undef, undef, 0);
  return(undef) if (! &does_dir_exist($d1));
  return(undef) if (! &does_dir_exist($d2));

  my $from = &get_dir_actual_dir($d1);
  my $to   = &get_dir_actual_dir($d2);

  return('.') if ($from eq $to);

  my $dbg = 0;
  vprint($dbg, "[$from]\n[$to]\n");

  my @a1 = grep (! m%^$%, split(m%/%, $to));
  my @a2 = grep (! m%^$%, split(m%/%, $from));

  my $mod = 0;
  my @out_b = ();
  my @out_e = ();
  for (my $i = 0; $i < max(scalar @a1, scalar @a2); $i++) {
    vprint($dbg, "?? $a1[$i] | $a2[$i]\n");

    # same path and no change yet, nothing to do
    if (($mod == 0) && ($a1[$i] eq $a2[$i])) {
      vprint($dbg, "== $a2[$i]\n");
      next;
    }

    # no common PATH possible from /
    return($to)
      if (($i == 0) && ($force_relative == 0));
     
    # at this point whatever is next means change
    $mod++; 

    # ie we created the entry in the to go to path split by checking its existence ?
    if ($a1[$i] eq '') { 
      vprint($dbg, "..\n");
      push @out_b, '..';
      next;
    } 

    # ie we created the entry in the coming from path split by checking its existence ?
    if ($a2[$i] eq '') {
      vprint($dbg, "++ $a1[$i]\n");
      push @out_e, $a1[$i];
      next;
    }

    vprint($dbg, "** .. $a1[$i]\n");
    push @out_b, '..';
    push @out_e, $a1[$i];
  }
  
  my $res = join('/', @out_b, @out_e);
  if ($dbg) {
    my $check = &get_dir_actual_dir("$from/$res");
    vprint($dbg, "[$check]" . (($check ne $to) ? "   !!!!!!!!!!! different from: $to" : "") . "\n");
  }
  vprint($dbg, " => $res\n");

  return($res);
}

##########

sub iuav { # Initialize Undefined Array of Values
  my ($ra, @rest) = @_;
  # 0: reference to array
  # 1+: replacement values

  my @out = ();
  for (my $i = 0; $i < scalar @rest; $i++) {
    push @out, &iuv($$ra[$i], $rest[$i]);
  }

  return(@out);
}

#####

sub iuv { # Initialize Undefined Values
  # arg 0: value to check
  # arg 1: replacement if undefined (can be 'undef')
  return(defined $_[0] ? $_[0] : $_[1]);
}

##########

sub dive_hash {
  my ($rh, @keys) = @_;

  return('Not a HASH', undef)
    if (ref($rh) ne 'HASH');

  my $key = shift @keys;

  return("Key [$key] not in HASH", undef)
    if (! exists $$rh{$key});

  return('', $$rh{$key})
    if (scalar @keys == 0);

  my $nrh = $$rh{$key};
  return('Not a HASH', undef)
    if (ref($nrh) ne 'HASH');

  return &dive_hash($nrh, @keys);
}

#####

sub dive_structure {
  my $r = $_[0];

  return('', $r) if (! ref($r));

  return('', $$r[0]) 
    if (ref($r) eq 'ARRAY');

  return('Not a HASH (' . ref($r) . ')', undef)
    if (ref($r) ne 'HASH');
  
  my @keys = keys %$r;
  return('Found multiple keys (' . join(' ', @keys) . ')', undef) 
    if (scalar @keys > 1);

  $r = $$r{$keys[0]};

  return(&dive_structure($r));
}

##########

sub __extract_float {
  my $str = $_[0];

  $str = &clean_begend_spaces($str);
  return($1, undef)
    if ($str =~ m%^(\-?\d+(e[-+]?\d+)?)$%i);
 
  return($1, $str)
    if ($str =~ m%^(\-?\d+)\.\d+(e[-+]?\d+)?$%i);

  return(undef, undef);
}

#####

sub is_get_float {
  my ($a, $b) = &__extract_float($_[0]);
  return(0, undef) if (! defined $a);
  return(1, $a) if (! defined $b);
  return(1, $b);
}

##

sub is_float {
  my ($ok, $val) = &is_get_float($_[0]);
  return($ok);
}

##

sub get_float {
  my ($ok, $val) = &is_get_float($_[0]);
  return($val);
}

#####

sub is_get_integer {
  my ($a, $b) = &__extract_float($_[0]);
  return(0, undef) if ((! defined $a) || (defined $b));
  return(1, $a);
}

#####

sub is_integer {
  my ($ok, $val) = &is_get_integer($_[0]);
  return($ok);
}

#####

sub get_integer {
  my ($ok, $val) = &is_get_integer($_[0]);
  return($val);
}

##########

sub human_int {
  my $v = $_[0];

  return($v)
    if (length($v) < 4);

  my @rord = ();
  while (length($v) > 0) {
    push @rord, substr($v, -3, 3, '');
  }

  return(join(',', reverse(@rord)));
}

####################

sub do_ls {
  return('Empty \"ls\" argument', undef) if (scalar @_ == 0);

  my $cmd = 'ls ' . join(' ', @_);

  my ($rc, $stdout, $stderr) = &do_system_call($cmd);

  return($stderr, undef) if ($rc);

  return('', $stdout);
} 

#####

sub ls_ok {
  my ($err, $val) = &do_ls(@_);

  return(0) if (! defined $val);
  return(0) if (! &is_blank($err));

  return(1);
}

#### 

sub randomize {
  my @d = ();
  while (@_) { push @d, splice(@_, rand @_, 1); }
  return @d;
}

####################

sub get_currenttime { return([gettimeofday()]); }
sub get_scalar_currenttime { return(scalar gettimeofday()); }

#####

sub get_elapsedtime { return(tv_interval($_[0])); }

##########
### Added by Jon Fiscus
### This routine returns 0 if the value to take the sqrt of is essentially zero, but negative
### due to floating point problems
sub safe_sqrt {
  my $v = $_[0];

  $v = 0.0 if (defined $v && $v > -0.00000000001 && $v < 0.00000000000);
  
  return(sqrt($v));
}

####################
# MM: for submission checkers: unarchive archives

my %exp_ext_cmd = ();

#####

sub __set_unarchived_ext_list {
  return() if (scalar keys %exp_ext_cmd > 0);

  my $tar      = 'tar xf';
  my $targzip  = 'tar xfz';
  my $tarbzip2 = 'tar xfj';
  my $zip      = 'unzip';

  %exp_ext_cmd = 
    (
     # TAR
     'tar'     => $tar,
     # TAR + GZIP
     'tar.gz'  => $targzip,
     'tgz'     => $targzip,
     # TAR + BZIP2
     'tar.bz2' => $tarbzip2,
     'tbz2'    => $tarbzip2,
     'tbz'     => $tarbzip2,
     'tb2'     => $tarbzip2,
     # ZIP
     'zip'     => $zip,
    );
}

#####

sub get_unarchived_ext_list {
  &__set_unarchived_ext_list();
  return(sort keys %exp_ext_cmd);
}

#####

sub unarchive_archive {
  my ($arc, $destdir) = @_;

  &__set_unarchived_ext_list();

  my ($err, $dir, $file, $ext) = &split_dir_file_ext($arc);
  return("Problem with archive filename: $err") if (! &is_blank($err));
  
  $ext = lc($ext);
  return("Problem with archive extension ($ext), is not in the list of recognized extensions (" . join(' ', &get_unarchived_ext_list()) . ')')
    if (! exists $exp_ext_cmd{$ext});

  my $pwd = &get_pwd();
  my $ff = &get_file_full_path($arc);

  $err = &check_file_r($ff);
  return("Problem with archive file ($arc): $err") if (! &is_blank($err));

  $err = &check_dir_w($destdir);
  return("Problem with destination directory ($destdir): $err") if (! &is_blank($err));
  
  my @cmd = ($exp_ext_cmd{$ext},  $ff);

  chdir($destdir);
  my ($retcode, $stdout, $stderr) = &do_system_call(@cmd);
  chdir($pwd);
  
  return('', $retcode, $stdout, $stderr);
}

##########

sub safe_exists {
  # when doing exists $hash{$k1}{$k2}{$k3}
  # avoid creating $hash{$k1}{$k2}

  my ($ra, $k, @ks) = @_;

  return(0) if (! exists $$ra{$k});

  return(1) if (scalar @ks == 0);

  return(&safe_exists($$ra{$k}, @ks));
}

######

sub push_tohash {
  # with: ($rh, $v, $d0, @d) = @_
  # eq to: push @{$$rh{$d0}{$d[0]}...{$d[x]}}, $v
  my ($rh, $v, $d0) = splice(@_,0,3);

  if (scalar @_ == 0) {
    push @{$$rh{$d0}}, $v;
    return(1);
  } elsif (scalar @_ > 2) {
    my ($d1, $d2) = splice(@_,0,2);
    return(&push_tohash(\%{$$rh{$d0}{$d1}{$d2}}, $v, @_));
  }

  return(&push_tohash(\%{$$rh{$d0}}, $v, @_));
}

#####

sub set_tohash {
  # with: ($rh, $v, $d0, @d) = @_
  # eq to: $$rh{$d0}{$d[0]}...{$d[x]} = $v
  my ($rh, $v, $d0) = splice(@_,0,3);

  if (scalar @_ == 0) {
    $$rh{$d0} = $v;
    return(1);
  } elsif (scalar @_ > 2) {
    my ($d1, $d2) = splice(@_,0,2);
    return(&set_tohash(\%{$$rh{$d0}{$d1}{$d2}}, $v, @_));
  }

  return(&set_tohash(\%{$$rh{$d0}}, $v, @_));
}

#####

sub inc_tohash {
  # with: ($rh, $d0, @d) = @_
  # eq to: $$rh{$d0}{$d[0]}...{$d[x]}}++
  my ($rh, $d0) = splice(@_,0,2);

  if (scalar @_ == 0) {
    $$rh{$d0}++;
    return(1);
  } elsif (scalar @_ > 2) {
    my ($d1, $d2) = splice(@_,0,2);
    return(&inc_tohash(\%{$$rh{$d0}{$d1}{$d2}}, @_));
  }

  return(&inc_tohash(\%{$$rh{$d0}}, @_));
}

#####

sub fast_join {
  # arg 0: join separator
  # arg 1: reference to array of entries to be joined

  return('') if (scalar @{$_[1]} == 0);

  my $txt = ${$_[1]}[0];
  for (my $i = 1; $i < scalar @{$_[1]}; $i++) {
    $txt .= $_[0] . ${$_[1]}[$i];
  }

  return($txt);
}

##########

sub get_version_comp {
  my ($value, $comps, $mul) = @_;

  return("Version number does not contain only digits or dots [$value]")
    if (! ($value =~ m%^[0-9\.]+$%));

  my @c = split(m%\.%, $value);
  
  my $ret = 0;
  for (my $i = 0; $i < $comps; $i++) {
    my $x = 1; for (my $j = 1 + $i; $j < $comps; $j++) { $x *= $mul; } 
    $ret += ((defined $c[$i] ? $c[$i] : 0) * $x);
  }

  return("", $ret);
}

##########

sub filecopy {
  my ($if, $of) = @_;

  my $err = &check_file_r($if);
  return("Problem with copy input file ($if) : $err")
    if (! &is_blank($err));

  copy($if, $of)
    or return("Problem copying file [$if] -> [$of] : $!");
  
  $err = "";
  $err = &check_file_r($of);
  return("Problem with copy output file ($of) : $err")
      if (! &is_blank($err));

  return("");
}

##

sub filecopytodir {
  my ($if, $od) = @_;

  my $of = $if;
  $of =~ s%^.+/%%;
  return(&filecopy($if, "$od/$of"));
}

##########

sub is_email {
  return("No email provided")
    if (MMisc::is_blank($_[0]));

  return("") 
    if ($_[0] =~ m%^[\w\.\-\_]+\@[\w\.\-\_]+\.[a-z]{2,}$%i);

  return("Invalid email address");
}

##########

# % perl -e 'use MMisc; @a=qw(1 2 3 4 5 6 7); print join(" ", MMisc::shiftX(3,\@a)) . "|" . join(" ", @a) . "\n";'
# 1 2 3|4 5 6 7
sub shiftX {
  # 0: number of items
  # 1: reference to array to shift elements from
  return(splice(@{$_[1]}, 0, $_[0]));
}

##

# % perl -e 'use MMisc; @a=qw(1 2 3 4 5 6 7); print join(" ", MMisc::popX(3,\@a)) . "|" . join(" ", @a) . "\n";'
# 5 6 7|1 2 3 4
sub popX {
  # 0: number of items
  # 1: reference to array to shift elements from
  return(splice(@{$_[1]}, -$_[0]));
}


##########
sub mode2perms {
  my ($mode) = @_;

 # thanks: http://bytes.com/topic/perl/answers/50411-access-mode-int-string
  my @rwx = qw(--- --x -w- -wx r-- r-x rw- rwx);
  my $perms = $rwx[$mode & 7];
  $mode >>= 3;
  $perms = $rwx[$mode & 7] . $perms;
  $mode >>= 3;
  $perms = $rwx[$mode & 7] . $perms;
  substr($perms, 2, 1) =~ tr/-x/Ss/ if -u _;
  substr($perms, 5, 1) =~ tr/-x/Ss/ if -g _;
  substr($perms, 8, 1) =~ tr/-x/Tt/ if -k _;

  return($perms);
}



############################################################

sub marshal_matrix { 
    # Parse arguments.
    my (@arr) = @_;

    # Initalize some variables including the header string.
    my $cols = @{$arr[0]};
    my $rows = @arr;
    my $str = "begin $rows $cols\n";

    # Generate the format string.
    my $format = "";
    for my $x (1 .. $cols) {
        $format .= "d";
    }

    # Loop through each row and pack it into a string and 
    # append it to the header string. 
    foreach my $row (@arr) {
        my $val = pack($format, @$row);
        $str .= "$val";
    }

    # Return the packed string.
    $str;
}

sub unmarshal_matrix {
    # Parse arguments.
    my ($str) = @_;

    # Initialize output array
    my @arr = ();

    # Initialize the columns and rows
    # Note: Rows are not used at the moment.
    my $rows = undef;
    my $cols = undef;
    if ($str =~ /begin (\d+) (\d+)/) {
        $rows = $1;
        $cols = $2;
    }

    # Generate the format string. 
    # Note: when the pattern contains an asterisk
    #       perl will repeat the pattern until there
    #       are no bytes left. The () just denote
    #       what to repeat.
    my $format = "(";
    for my $x (1 .. $cols) {
        $format .= "d";
    }
    $format .= ")*";

    
    # Where all the magic happens.
    #   1) Strip the header off of the binary data.
    #   2) Initialize the counter and the temporary row.
    #   Loop:
    #       1) Push the new value of x onto the temporary row.
    #       2) If the temporary row is full, make a new 
    #           reference to it and throw it into the array.
    #       3) Increment our friendly counter.
    $str =~ s/^begin \d+ \d+\n//;
    my $ctr = 1;
    my @tmp = ();
    for my $x ( unpack($format, $str) ){
        push @tmp, $x;
        if ($ctr % $cols == 0) {
            my @retmp = @tmp;
            push @arr, \@retmp;
            @tmp = ();
        }
        $ctr++;
    }
    
    # Return the array. 
    @arr;
}
############################################################

###  Removes elements from an array that match the expression
sub filterArray {
  my ($array_ref, $expr) = @_;
  
  for (my $i=0; $i<@$array_ref; $i++){
    if ($array_ref->[$i] =~ /$expr/){
      splice (@$array_ref, $i, 1);
      $i--;  ## The splice reduces the size of the array so redo this index
    } 
  }
  $array_ref;
}

############################################################

sub __floor { return (int($_[0])); }
sub __ceil  { return (int($_[0]+0.99)); }


sub unitTest {
  print "Test MMisc\n";
  my $errc = 0;

  $errc += marshalTest();
  $errc += filterArrayUnitTest();
  $errc += interpolateYDimUnitTest();
  $errc += compareDataUnitTest();
  $errc += unitTest_stringSHAdigest();

  MMisc::error_quit("Problem with some MMisc unitTest")
      if ($errc != 0);
  
  MMisc::ok_exit();
}

sub runFilterArrayCase{
  my ($arr, $expr, $expected) = @_;
  my $msg = "Input: arr=".join("-",@$arr)." expr=$expr expected=".join("-",@$expected);
  filterArray($arr, $expr);
  $msg .= "  Output: ".join("-",@$arr)."\n";
  my $fail = 0;
  if (@$arr != @$expected){
    $fail = 1;
  } else {
    for (my $i; $i<@$arr; $i++){
      $fail = 1 if ($arr->[$i] ne $expected->[$i]) 
    }
  } 
  error_quit("filterArray Test Failed: $msg") 
    if ($fail);
}

sub filterArrayUnitTest{
  print " Testing filterArray ... ";
  runFilterArrayCase([ () ], "b", [ () ]);
  runFilterArrayCase([ ("b") ], "b", [ () ]);
  runFilterArrayCase([ ("b", "b") ], "b", [ () ]);
  runFilterArrayCase([ ("b", "c") ], "b", [ ("c") ]);
  runFilterArrayCase([ ("c", "b") ], "b", [ ("c") ]);
  runFilterArrayCase([ ("b", "c", "b") ], "b", [ ("c") ]);
  runFilterArrayCase([ ("b", "c", "b", "c", "b", "c") ], "b", [ ("c", "c", "c") ]);
  ### Regex stuff
  runFilterArrayCase([ ("aba", "b", "c") ], "b", [ ("c") ]);
  runFilterArrayCase([ ("aba", "b", "c") ], "^b\$", [ ("aba", "c") ]);
  runFilterArrayCase([ ("aba", "b", "c") ], "ba\$", [ ("b", "c") ]);
  runFilterArrayCase([ ("443", "|", "3") ], "\\|", [ ("443", "3") ]);
  print "OK\n";
  return(0);
}

sub marshalTest {
  print " Testing marshaling and unmarshaling of matricies\n";
  print "  Simple matrix test ... ";
  my @testarr = ([1, 2, 3], [4, 5, 6], [7, 8, 9]);
  my $teststr = marshal_matrix(@testarr);
  my @resultarr = unmarshal_matrix($teststr);
  
  my $cols = @{$resultarr[0]};
  my $rows = @resultarr;
  my $j = 0;
  for (my $i=0; $i < $rows; $i++) {
    for (my $j=0; $j < $cols; $j++) {
      error_quit("unmarshaling the matrix")
        if ($testarr[$i]->[$j] != $resultarr[$i]->[$j]);
    }
  }
  print "OK\n";
  
  print "  Floating point matrix test ... ";
  @testarr = ([0.1, 0.2, 0.3], [0.44, 0.55, 0.66], [0.777, 0.888, 0.999]);
  $teststr = marshal_matrix(@testarr);
  @resultarr = unmarshal_matrix($teststr);
  
  $cols = @{$resultarr[0]};
  $rows = @resultarr;
  $j = 0;
  for (my $i=0; $i < $rows; $i++) {
    for (my $j=0; $j < $cols; $j++) {
      error_quit("unmarshaling the matrix")
        if ($testarr[$i]->[$j] != $resultarr[$i]->[$j]);
    }
  }
  print "OK\n";

  return(0);
}

### based on points (x1, y1) and (x2, y2), compute the line function and the Y value for $newX
sub interpolateYDim{
  my ($x1, $y1, $x2, $y2, $newX) = @_;
#  print "Interpolate: ($x1,$y1) ($x2,$y2) = newX=$newX\n";
  my ($newY) = ($x2-$x1 == 0) ? (($y2+$y1)/2) : ($y2 + ( ($y1-$y2) * (($x2-$newX) / ($x2-$x1))));  
#  print ("  newY=$newY\n");
  return $newY;
}

sub interpolateYDimUnitTest(){
### unit tests
  print " Testing interpolateYDim...";
  error_exit() if (abs(interpolateYDim(1,1,3,3,2.5) - 2.5) >= 0.0001);
  error_exit() if (abs(interpolateYDim(3,3,1,1,2.5) - 2.5) >= 0.0001);
  error_exit() if (abs(interpolateYDim(1,2,4,5,2.5) - 3.5) >= 0.0001);
  ## extrapolation
  error_exit() if (abs(interpolateYDim(1,2,4,5,7.5) - 8.5) >= 0.0001);
  ## horizontal line
  error_exit() if (abs(interpolateYDim(1,2,2,2,7.5) - 2) >= 0.0001);
  ## vertical line
  error_exit() if (abs(interpolateYDim(1,2,1,8,1) - 5) >= 0.0001);
  print "OK\n";
  return(0);
}

sub compareData{
  my ($a1, $a2, $includePaired) = @_;

  ## Try to use Statistics::Distributions
  if (! defined $StatisticsDistributions_module) {
    &error_quit("Can not use the Statistics::Distributions module")
      if (! &check_package("Statistics::Distributions"));
    $StatisticsDistributions_module = "Statistics::Distributions";
  }

  my ($sum1, $sum2, $sum1x2, $sumSqr1, $sumSqr2, $diff, $sumSqrDiff) = (0, 0, 0, 0, 0, 0, 0);

  my %ht = ();
  error_quit("compareData needs data in array1") if (@$a1 <= 1);
  error_quit("compareData needs data in array2") if (@$a2 <= 1);

  $ht{N1} = @$a1;
  $ht{N2} = @$a2;
  ##### Non-Paired Measures
  for (my $n=0; $n<$ht{N1}; $n++){
    $sum1 += $a1->[$n];
    $sumSqr1 += $a1->[$n] * $a1->[$n];
  }
  for (my $n=0; $n<$ht{N2}; $n++){
    $sum2    += $a2->[$n];
    $sumSqr2 += $a2->[$n] * $a2->[$n];
  }
  $ht{mean1} = $sum1 / $ht{N1};
  $ht{mean2} = $sum2 / $ht{N2};
  $ht{var1} = ($ht{N1} <= 1 ? undef : (($ht{N1} * $sumSqr1) - ($sum1 * $sum1)) / ($ht{N1} * ($ht{N1} - 1)));
  $ht{var2} = ($ht{N2} <= 1 ? undef : (($ht{N2} * $sumSqr2) - ($sum2 * $sum2)) / ($ht{N2} * ($ht{N2} - 1)));
  $ht{stddev1} = (defined($ht{var1}) ? MMisc::safe_sqrt($ht{var1}) : undef);
  $ht{stddev2} = (defined($ht{var2}) ? MMisc::safe_sqrt($ht{var2}) : undef);
 
  ### Unpaired T Test Equal Variances - Assumes normal distribution
  my $s = 0;
  for (my $n=0; $n<$ht{N1}; $n++){    $s += ($a1->[$n] - $ht{mean1}) * ($a1->[$n] - $ht{mean1});    }
  for (my $n=0; $n<$ht{N2}; $n++){    $s += ($a2->[$n] - $ht{mean2}) * ($a2->[$n] - $ht{mean2});    }
#  print "$s\n";
  my %hth = ();
  $hth{df} = ($ht{N1} + $ht{N2} - 2);
  $hth{pooledSampleVar} = ($s / $hth{df});
  $hth{pooledSampleStddev} = MMisc::safe_sqrt($s / $hth{pooledSampleVar});
  $hth{testStat} = ($ht{mean1} - $ht{mean2}) / MMisc::safe_sqrt($hth{pooledSampleVar}  * (1/$ht{N1} + 1/$ht{N2}));
  $hth{POneTail} = Statistics::Distributions::tprob($hth{df}, $hth{testStat} * ($hth{testStat} < 0 ? -1 : 1));
  $hth{PTwoTail} = $hth{POneTail} * 2;
  $ht{stats}{unpaired}{TTest}{equalVariance} = \%hth;
  ### End of computation

  ### Unpaired T Test UNEqual Variances
  my %uht = ();
  $uht{df} = &__floor(((($ht{var1}/$ht{N1}) + ($ht{var2} / $ht{N2}) * ($ht{var1}/$ht{N1}) + ($ht{var2} / $ht{N2}))) /
                   ( ((($ht{var1}/$ht{N1}) *($ht{var1}/$ht{N1})) / ($ht{N1} - 1)) + ((($ht{var2}/$ht{N2}) *($ht{var2}/$ht{N2})) / ($ht{N2} - 1))));
  $uht{testStat} = ($ht{mean1} - $ht{mean2}) / MMisc::safe_sqrt(($ht{var1}/$ht{N1}) + ($ht{var2} / $ht{N2}));
  $uht{POneTail} = Statistics::Distributions::tprob($uht{df}, $uht{testStat} * ($uht{testStat} < 0 ? -1 : 1));
  $uht{PTwoTail} = $uht{POneTail} * 2;
  $ht{stats}{unpaired}{TTest}{unequalVariance} = \%uht;
  ### End of computation

  
  
  error_quit("compareData(): Paired test requested but lengths non-equal")
    if ($ht{N1} != $ht{N2} && $includePaired);
  if ($includePaired){
    error_quit("Correllation Coeff requires at least 2 values") if ($ht{N1} <= 1);
    ### Paired Tests
    $ht{stats}{paired}{N} = $ht{N1};
    my $N = $ht{stats}{paired}{N};
    
    for (my $n=0; $n<$N; $n++){
      $diff += $a1->[$n] - $a2->[$n];
      $sumSqrDiff += ($a1->[$n] - $a2->[$n]) * ($a1->[$n] - $a2->[$n]);
      $sum1x2  += $a1->[$n] * $a2->[$n];
    } 
    $ht{stats}{paired}{meanDiff} = $diff / $N;
    $ht{stats}{paired}{varDiff} = ($N <= 1 ? undef : (($N * $sumSqrDiff) - ($diff * $diff)) / ($N * ($N - 1)));
    $ht{stats}{paired}{stddevDiff} = ($N <= 1 ? undef : MMisc::safe_sqrt($ht{stats}{paired}{varDiff}));

    $ht{stats}{paired}{r} = ($N * $sum1x2 - $sum1*$sum2) /
                      MMisc::safe_sqrt(($N * $sumSqr1 - ($sum1 * $sum1)) * ($N * $sumSqr2 - ($sum2 * $sum2)));

    #### Paired TTest test case Based on http://www.statsdirect.com/help/parametric_methods/ptt.htm
    my %xht = ();
    $xht{df} = $N - 1;
    $xht{testStat} = $ht{stats}{paired}{meanDiff} / MMisc::safe_sqrt($ht{stats}{paired}{stddevDiff} * $ht{stats}{paired}{stddevDiff} / $N);
    $xht{POneTail} = Statistics::Distributions::tprob($xht{df}, $xht{testStat} * ($xht{testStat} < 0 ? -1 : 1));
    $xht{PTwoTail} = 2 * $xht{POneTail};
    $ht{stats}{paired}{pairedTTest} = \%xht;
    ### End of computation
  }
  
  return (\%ht);
}

sub compareDataUnitTest{
  print " Testing compareData...";  
  #my ($r, $avg1, $avg2, $avgDiff, $stddev1, $stddev2, $stddevDiff) = 
  my $ht = compareData([ (60, 61, 62, 63, 65) ], [ (3.1, 3.6, 3.8, 4, 4.1) ], 1);
  #print Dumper($ht);
  error_quit("compareDataUnitTest failed to calculate R")
    if (abs($ht->{stats}{paired}{r} - 0.911872) > 0.0001);
  error_quit("compareDataUnitTest failed to calculate StdDev1")
    if (abs($ht->{stddev1} - 1.923538) > 0.0001);
  error_quit("compareDataUnitTest failed to calculate Avg1")
    if (abs($ht->{mean1} - 62.20000) > 0.0001);
  error_quit("compareDataUnitTest failed to calculate StdDev2")
    if (abs($ht->{stddev2} - 0.396232) > 0.0001);
  error_quit("compareDataUnitTest failed to calculate Avg2")
    if (abs($ht->{mean2} - 3.720000) > 0.0001);
  error_quit("compareDataUnitTest failed to calculate AvgDiff")
    if (abs($ht->{stats}{paired}{meanDiff} - 58.48000) > 0.0001);
  error_quit("compareDataUnitTest failed to calculate StdDevDiff")
    if (abs($ht->{stats}{paired}{stddevDiff} - 1.570668) > 0.0001);
  print "OK\n";
  #print Dumper(compareData([ (134, 146, 104, 119, 124, 161, 107, 83, 113, 129, 97, 123) ], [ (70, 118, 101, 85, 107, 132, 94) ], 0));

#  print Dumper(compareData([ (312, 242, 340, 388, 296, 254, 391, 402, 290) ], [ (300, 201, 232, 312, 220, 256, 328, 330, 231) ], 1));
  return(0);
}


sub charHistFromStdin{
  my ($encoding, $norm) = @_;
  
  ## Try to use AutoTable
  if (! defined $AutoTable_module) {
    &error_quit("Can not use the AutoTable module")
      if (! &check_package("AutoTable"));
    $AutoTable_module = "AutoTable";
  }

  my $at = new AutoTable();
  $at->setEncoding($encoding) if ($encoding ne "");
  $at->setCompareNormalize($norm);# if ($norm ne "");
  binmode STDIN, $at->getPerlEncodingString();
  while (<STDIN>){
    foreach my $c(split(//, $_)){
      $c = "<NL>" if ($c eq "\n");
      $c = "<SPACE>" if ($c eq " ");
      $c = "<TAB>" if ($c eq "\t");
      $c = "<CR>" if ($c eq "\r");
      
      ### 
      $c = $at->normalizeTerm($c)."|".$c;
      $at->increment("Count",$c);
    }
  }
  
  $at->setProperties({"SortRowKeyTxt", "Alpha"});
  print $at->renderTxtTable(1);
}
  



1;
