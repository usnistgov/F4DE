package MMisc;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

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
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;
##use Carp;

use File::Temp qw(tempfile tempdir);
use File::Copy;
use Data::Dumper;
use Cwd qw(cwd abs_path);
use Time::HiRes qw(gettimeofday tv_interval);
use List::Util qw(reduce);

my $version     = '0.1b';

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "MMisc.pm Version: $version";

########## No 'new' ... only functions to be useful

sub get_tmpdir {
  my $name = tempdir();
  
  return($name) 
    if (-d $name);

  return($name)
    if (&make_wdir($name));

  # Directory does not exist and could not be created
  return(undef);
}

#####

sub get_tmpfilename {
  my (undef, $name) = tempfile( OPEN => 0 );

  return($name);
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
      $fileheader, $filetrailer, $makexec)
    = &iuav(\@_, '', '', 0, 0, '', '', '', '', '', 0);

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

sub get_sorted_MemDump {
  my ($obj, $indent) = ($_[0], &iuv($_[1], 2));

  # Save the default sort key
  my $s_dso = $Data::Dumper::Sortkeys;
  # Save the default indent
  my $s_din = $Data::Dumper::Indent;
  # Save the deault Purity
  my $s_dpu = $Data::Dumper::Purity;

  # Force dumper to sort
  $Data::Dumper::Sortkeys = 1;
  # Force dumper to use requested indent level
  $Data::Dumper::Indent = $indent;
  #  Purity controls how self referential objects are written
  $Data::Dumper::Purity = 1;

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
  my ($file, $ext, $obj, $txt_fileheader, $gzip_fileheader, $printfn) =
    &iuav(\@_, '', '', undef, undef, undef, 1);

  return(0) if (! defined $obj);
  
  # The default is to write the basic text version
  my $fileheader = $txt_fileheader;
  my $str = &get_sorted_MemDump($obj);

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

  return( &writeTo($file, $ext, $printfn, 0, $str, '', '', $fileheader, '') );
}

#####

sub load_memory_object {
  my ($file, $gzhdsk) = &iuav(\@_, '', undef);

  return(undef) if (&is_blank($file));

  my $str = &slurp_file($file, 'bin');
  return(undef) if (! defined $str);

  if (defined $gzhdsk) {
    # It is possibly a gzip file => Remove the header ?
    my $tstr = &strip_header($gzhdsk, $str);
    if ($tstr ne $str) {
      # If we could it means it is a gzip file: try to un-gzip
      my $tmp = &mem_gunzip($tstr);
      return(undef) if (! defined $tmp);
      # it is un-gzipped -> work with it
      $str = $tmp;
    }
  }

  my $VAR1;
  eval $str;
  &error_quit("Problem in \'MMisc::load_memory_object()\' eval-ing code: " . join(" | ", $@))
    if $@;

  return($VAR1);
}

##########

sub mem_gzip {
  my $tozip = &iuv($_[0], '');

  return(undef) if (&is_blank($tozip));

  my $filename = &get_tmpfilename();
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

  my $filename = &get_tmpfilename();
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
  my $stdoutfile = '';
  my $stderrfile = '';
  if ((! defined $logfile) || (&is_blank($logfile))) {
    # Get temporary filenames (created by the command line call)
    $stdoutfile = &get_tmpfilename();
    $stderrfile = &get_tmpfilename();
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

  $| = $ov;

  # Get the content of those temporary files
  my $stdout = &slurp_file($stdoutfile);
  my $stderr = &slurp_file($stderrfile);

  # Erase the temporary files
  unlink($stdoutfile);
  unlink($stderrfile);

  return($retcode, $stdout, $stderr);
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

  my ($retcode, $stdout, $stderr) = &_system_call_logfile($ofile, @_);

  my $otxt = '[[COMMANDLINE]] ' . join(' ', @_) . "\n"
    . "[[RETURN CODE]] $retcode\n"
      . "[[STDOUT]]\n$stdout\n\n"
        . "[[STDERR]]\n$stderr\n";

  return(0, $otxt, $stdout, $stderr, $retcode, $ofile)
    if (! &writeTo($ofile, '', 0, 0, $otxt));

  return(1, $otxt, $stdout, $stderr, $retcode, $ofile);
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

#####

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

####################

sub warn_print {
  print('[Warning] ', join(' ', @_), "\n");
}

##########

sub error_exit {
#  $Carp::Verbose = 1;  carp(1);
  exit(1);
}

#####

sub error_quit {
  print('[ERROR] ', join(' ', @_), "\n");
  &error_exit();
}

##########

sub ok_exit {
  exit(0);
}

#####

sub ok_quit {
  print(join(' ', @_), "\n");
  &ok_exit();
}

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

sub list_dirs_files {
  my $dir = &iuv($_[0], '');

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
    my $ff = "$dir/$entry";
    if (-d $ff) {
      push @d, $entry;
      next;
    }
    if (-f $ff) {
      push @f, $entry;
      next;
    }
    push @u, $entry;
  }

  return('', \@d, \@f, \@u);
}

#####

sub get_dirs_list {
  my $dir = &iuv($_[0], '');

  my @out = ();

  return(@out) if (&is_blank($dir));

  my ($err, $rd, $rf, $ru) = &list_dirs_files($dir);

  return(@out) if (! &is_blank($err));

  return(@{$rd});
}

#####

sub get_files_list {
  my $dir = &iuv($_[0], '');

  my @out = ();

  return(@out) if (&is_blank($dir));

  my ($err, $rd, $rf, $ru) = &list_dirs_files($dir);

  return(@out) if (! &is_blank($err));

  return(@{$rf});
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

##########

sub iuav { # Initialize Undefined Array of Values
  my ($ra, @rest) = @_;

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
  while (@_) {                                                                                                                                                                                                                            
    push @d, splice(@_, rand @_, 1);                                                                                                                                                                                                
  }     
  return @d;
}

####################

sub get_currenttime { return([gettimeofday()]); }

#####

sub get_elapsedtime { return(tv_interval($_[0])); }

##########
### Added by Jon Fiscus
### This routine returns 0 if the value to take the sqrt of is essentially zero, but negative do
### to floating point problems
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
  # eq to: push @{$$rh{$d0}{$d[0]}...{$d[x]}}, $v
  my ($rh, $v, $d0, @d) = @_;

  if (scalar @d == 0) {
    push @{$$rh{$d0}}, $v;
    return(1);
  }

  return(&push_tohash(\%{$$rh{$d0}}, $v, @d));
}

#####

sub set_tohash {
  # eq to: $$rh{$d0}{$d[0]}...{$d[x]} = $v
  my ($rh, $v, $d0, @d) = @_;

  if (scalar @d == 0) {
    $$rh{$d0} = $v;
    return(1);
  }

  return(&set_tohash(\%{$$rh{$d0}}, $v, @d));
}

#####

sub inc_tohash {
  # eq to: $$rh{$d0}{$d[0]}...{$d[x]}}++
  my ($rh, $d0, @d) = @_;

  if (scalar @d == 0) {
    $$rh{$d0}++;
    return(1);
  }

  return(&push_toinc(\%{$$rh{$d0}}, @d));
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


sub unitTest {
	print "Test MMisc\n";
	marshalTest();
  filterArrayUnitTest();
	return 1;
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
  if ($fail) {
    die "\nfilterArray Test Failed: $msg";
  }
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
			die "Error: unmarshaling the matrix." if ($testarr[$i]->[$j] != $resultarr[$i]->[$j]);
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
			die "Error: unmarshaling the matrix." if ($testarr[$i]->[$j] != $resultarr[$i]->[$j]);
		}
	}
	print "OK\n";
}

1;
