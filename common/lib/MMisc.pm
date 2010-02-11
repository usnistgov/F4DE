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

use File::Temp qw(tempfile tempdir);
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
    if (&make_dir($name));

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
  my ($envv, $default) = (&iuv($_[0], ''), $_[1]);

  return(undef) if (&is_blank($envv));

  my $var = $default;

  $var = $ENV{$envv} if (exists $ENV{$envv});

  return($var);
}

##########

sub is_blank {
  my $txt = $_[0];

  return(1) if (! defined $txt);
  return(1) if (length($txt) == 0);

  return(($txt =~ m%^\s*$%s));
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
  my $ra = $_[0];
  return(sort { $a <=> $b } @$ra);
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
  my $ra = $_[0];

  my $min = $$ra[0];
  my $max = $min;

  for (my $i = 1; $i < scalar @$ra; $i++) {
    my $v = $$ra[$i];
    $min = $v if ($v < $min);
    $max = $v if ($v > $max);
  }
  
  return($min, $max);
}

#####

sub min { return(&min_r(\@_)); }

##

sub min_r { my $ra = $_[0]; return(List::Util::min(@$ra)); }

#####

sub max { return(&max_r(\@_)); }

##

sub max_r { my $ra = $_[0]; return(List::Util::max(@$ra)); }

##########

sub sum { return(&sum_r(\@_)); }

##

sub sum_r { my $ra = $_[0]; return(List::Util::sum(@$ra)); }

##########

sub writeTo {
  my ($file, $addend, $printfn, $append, $txt,
      $filecomment, $stdoutcomment,
      $fileheader, $filetrailer) 
    = &iuav(\@_, '', '', 0, 0, '', '', '', '', '');

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
  my $ra = $_[0];

  my %ohash = ();
  for (my $i = 0; $i < scalar @$ra; $i++) {
    $ohash{$$ra[$i]}++;
  }

  return(%ohash);
}

#####

sub array1d_to_ordering_hash {
  my $ra = $_[0];

  my %ohash = ();
  for (my $i = $#{@$ra}; $i >= 0; $i--) {
    my $v = $$ra[$i];
    $ohash{$v} = $i;
  }

  return(%ohash);
}

#####

sub make_array_of_unique_values {
  my $ra = $_[0];

  return(@$ra) if (scalar @$ra < 2);

  my %tmp = &array1d_to_ordering_hash($ra);
  my @tosort = keys %tmp;

  my @out = sort {$tmp{$a} <=> $tmp{$b}} @tosort;

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
  if ((! defined $logfile) || (MMisc::is_blank($logfile))) {
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
  $retcode = $?;

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

sub check_file_e { return(&_check_file_dir_XXX('file', 'e', @_)); }
sub check_file_r { return(&_check_file_dir_XXX('file', 'r', @_)); }
sub check_file_w { return(&_check_file_dir_XXX('file', 'w', @_)); }
sub check_file_x { return(&_check_file_dir_XXX('file', 'x', @_)); }

sub check_dir_e { return(&_check_file_dir_XXX('dir', 'e', @_)); }
sub check_dir_r { return(&_check_file_dir_XXX('dir', 'r', @_)); }
sub check_dir_w { return(&_check_file_dir_XXX('dir', 'w', @_)); }
sub check_dir_x { return(&_check_file_dir_XXX('dir', 'x', @_)); }

sub does_file_exists { return( &is_blank( &check_file_e(@_) ) ); }
sub is_file_r { return( &is_blank( &check_file_r(@_) ) ); }
sub is_file_w { return( &is_blank( &check_file_w(@_) ) ); }
sub is_file_x { return( &is_blank( &check_file_x(@_) ) ); }

sub does_dir_exists { return( &is_blank( &check_dir_e(@_) ) ); }
sub is_dir_r { return( &is_blank( &check_dir_r(@_) ) ); }
sub is_dir_w { return( &is_blank( &check_dir_w(@_) ) ); }
sub is_dir_x { return( &is_blank( &check_dir_x(@_) ) ); }

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

  return($rp) if (MMisc::is_blank($rp));

  my $f = $rp;
  $f = "$from/$rp" if ($rp !~ m%^\/%);

  my $o = abs_path($f);

  $o = $f
    if (MMisc::is_blank($o)); # The request PATH does not exist, fake it

  return($o);
}

##########

sub iuav { # Initialize Undefined Array of Values
  my ($ra, @rest) = @_;

  my @out = ();
  for (my $i = 0; $i < scalar @rest; $i++) {
    my $r = $rest[$i];
    my $v = $$ra[$i];
    push @out, &iuv($v, $r);
  }

  return(@out);
}

#####

sub iuv { # Initialize Undefined Values
  my ($v, $r) = @_;

  # Note: '$r' can be 'undef'
  return($r) if (! defined $v);

  return($v);
}

##########

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
  return(0) if (! MMisc::is_blank($err));

  return(1);
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
  
  my $cmd = $exp_ext_cmd{$ext} . " $ff";

  chdir($destdir);
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call($cmd);
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

#####

sub fast_join {
  my ($j, $ra) = @_;

  return('') if (scalar @$ra == 0);

  my $txt = $$ra[0];
  for (my $i = 1; $i < scalar @$ra; $i++) {
    $txt .= $j . $$ra[$i];
  }

  return($txt);
}

############################################################

1;
