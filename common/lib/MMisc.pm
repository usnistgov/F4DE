package MMisc;

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

# File::Temp (usualy part of the Perl Core)
use File::Temp qw / tempfile /;
# Data::Dumper
use Data::Dumper;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "MMisc.pm Version: $version";

########## No 'new' ... only functions to be useful

sub get_tmpfilename {
  my (undef, $name) = tempfile( OPEN => 0 );

  return($name);
}

#####

sub slurp_file {
  my $fname = shift @_;
  my $mode = shift @_; # Default is text

  open FILE, "<$fname"
    or return(undef);
  my @all = <FILE>;
  close FILE;
  chomp @all if (defined($mode) && $mode ne "bin");

  my $jc = (defined($mode) && $mode ne "bin") ? "\n" : "";
  my $tmp = join($jc, @all);

  return($tmp);
}

#####

sub do_system_call {
  my @args = @_;
  
  my $cmdline = join(" ", @args);

  my $retcode = -1;
  # Get temporary filenames (created by the command line call)
  my $stdoutfile = &get_tmpfilename();
  my $stderrfile = &get_tmpfilename();

  open (CMD, "$cmdline 1> $stdoutfile 2> $stderrfile |");
  close CMD;
  $retcode = $?;

  # Get the content of those temporary files
  my $stdout = &slurp_file($stdoutfile);
  my $stderr = &slurp_file($stderrfile);

  # Erase the temporary files
  unlink($stdoutfile);
  unlink($stderrfile);

  return($retcode, $stdout, $stderr);
}

##########

sub check_package {
  my ($package) = @_;
  unless (eval "use $package; 1")
    {
      return(0);
    }
  return(1);
}

##########

sub get_env_val {
  my $envv = shift @_;
  my $default = shift @_;

  my $var = $default;

  $var = $ENV{$envv} if (exists $ENV{$envv});

  return($var);
}

##########

sub is_blank {
  my $txt = shift @_;
  return(($txt =~ m%^\s*$%));
}

##########

sub clean_begend_spaces {
  my $txt = shift @_;

  $txt =~ s%^\s+%%s;
  $txt =~ s%\s+$%%s;

  return($txt);
}

##########

sub _numerically {
  return ($a <=> $b);
}

#####

sub reorder_array_numerically {
  my @ts = @_;

  @ts = sort _numerically @ts;

  return(@ts);
}

#####

sub min_max {
  my @v = &reorder_array_numerically(@_);

  return($v[0], $v[-1]);
}

#####

sub min {
  my @v = &min_max(@_);

  return($v[0]);
}

#####

sub max {
  my @v = &min_max(@_);

  return($v[-1]);
}

##########

sub sum {
  my $out = 0;
  foreach my $v (@_) {
    $out += $v;
  }
  return($out);
}

##########

sub writeTo {
  my ($file, $addend, $printfn, $append, $txt, $filecomment, $stdoutcomment,
     $fileheader, $filetrailer) = @_;

  my $rv = 1;

  my $ofile = "";
  if ((defined $file) && (! &is_blank($file))) {
    if (-d $file) {
      print "WARNING: Provided file ($file) is a directory, will write to STDOUT\n";
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
      open FILE, ">>$ofile" or ($ofile = "");
    } else {
      open FILE, ">$ofile" or ($ofile = "");
    }
    if (&is_blank($ofile)) {
      print "WARNING: Could not create \'$tofile\' (will write to STDOUT): $!\n";
      $rv = 0;
    }
  }

  if (! &is_blank($ofile)) {
    print FILE $fileheader if (! &is_blank($fileheader));
    print FILE $txt;
    print FILE $filetrailer if (! &is_blank($filetrailer));
    close FILE;
    print((($da) ? "Appended to file:" : "Wrote:") . " $ofile$filecomment\n") 
      if ($printfn);
    return(1); # Always return ok: we requested to write to a file and could
  }

  # Default: write to STDOUT
  print $stdoutcomment;
  print $txt;
  return($rv); # Return 0 only if we requested a file write and could not, 1 otherwise
}

##########

sub clone {
  # Clone hash and arrays
  map { ! ref() ? $_ : ref eq 'HASH' ? {clone(%$_)} : ref eq 'ARRAY' ? [clone(@$_)] : die "Cloning ($_) not supported" } @_;
}

##########

sub array1d_to_count_hash {
  my @all = @_;

  my %ohash = ();
  foreach my $o (@all) {
    $ohash{$o}++;
  }

  return(%ohash);
}

#####

sub array1d_to_ordering_hash {
  my @all = @_;

  my %ohash = ();
  for (my $i = 0; $i < scalar @all; $i++) {
    my $v = $all[$i];
    next if (exists $ohash{$v});
    $ohash{$v} = $i;
  }

  return(%ohash);
}

#####

sub make_array_of_unique_values {
  my @order = @_;

  return(@order) if (scalar @order <= 1);

  my %tmp = &array1d_to_ordering_hash(@order);
  my @tosort = keys %tmp;

  my @out = sort {$tmp{$a} <=> $tmp{$b}} @tosort;

  return(@out);
}

##########

sub compare_arrays {
  my $rexp = shift @_;
  my @list = @_;

  my @in = ();
  foreach my $elt (@$rexp) {
    if (grep(m%^$elt$%i, @list)) {
      push @in, $elt;
    }
  }

  my @out = ();
  foreach my $elt (@list) {
    if (! grep(m%^$elt$%i, @$rexp)) {
      push @out, $elt;
    }
  }
  return(\@in, \@out);
}

#####

sub confirm_first_array_values {
  my $rexp = shift @_;
  my @list = @_;

  my @in = ();
  my @out = ();
  foreach my $elt (@$rexp) {
    if (grep(m%^$elt$%, @list)) {
      push @in, $elt;
    } else {
      push @out, $elt;
    }
  }

  return(\@in, \@out);
}

##########

sub _uc_lc_array_values {
  my $mode = shift @_;
  my @in = @_;

  my @out = ();
  foreach my $value (@in) {
    my $v = ($mode eq "uc") ? uc($value) :
      ($mode eq "lc") ? lc($value) : $value;
    push @out, $v;
  }

  return(@out);
}

#####

sub uppercase_array_values {
  return(&_uc_lc_array_values("uc", @_));
}

#####

sub lowercase_array_values {
  return(&_uc_lc_array_values("lc", @_));
}

##########

sub get_decimal_length {
  my ($v) = @_;

  my $l = 0;

  if ($v =~ s%^\d+(\.)%$1%) {
    $l = length($v) - 1;
  }

  return($l);
}

#####

sub compute_precision {
  my ($v1, $v2) = @_;

  my $l1 = &get_decimal_length($v1);
  my $l2 = &get_decimal_length($v2);

  my $p;
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
  my ($v1, $v2, $p ) = @_;

  $p = &compute_precision($v1, $v2) if ((defined $p) && ($p == 0));
  $p = 0.000001 if (! defined $p); # default precision

  return(1) if (abs($v1 - $v2) < $p);

  return(0);
}

##########

sub dump_memory_object {
  my ($file, $ext, $obj, $txt_fileheader, $gzip_fileheader) = @_;

  # The default is to write the basic text version
  my $str = Dumper($obj);
  my $fileheader = $txt_fileheader;

  # But if we provide a gzip fileheader, try it
  if (defined $gzip_fileheader) {
    my $tmp = &mem_gzip(Dumper($obj));
    if (defined $tmp) {
      # If gzip worked, we will write this version
      $str = $tmp;
      $fileheader = $gzip_fileheader;
    }
    # Otherwise, we will write the text version
  }

  return( &writeTo($file, $ext, 1, 0, $str, "", "", $fileheader, "") );
}

#####

sub load_memory_object {
  my ($file, $gzhdsk) = @_;

  my $str = &slurp_file($file, "bin");
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
  my $tozip = shift @_;

  my $filename = &get_tmpfilename();

  open(FH, " | /usr/bin/gzip > $filename")
    or return(undef);
  print FH $tozip;
  close FH;

  return(&slurp_file($filename, "bin"));
}

#####

sub mem_gunzip {
  my $tounzip = shift @_;

  my $filename = &get_tmpfilename();

  open FILE, ">$filename"
    or return(undef);
  print FILE $tounzip;
  close FILE;

  my $unzip = "";
  open(FH, "/usr/bin/gzip -dc $filename |")
    or return(undef);
  while (my $line = <FH>) { 
    $unzip .= $line;
  }
  close FH;

  return($unzip);
}

#####

sub file_gunzip {
  my ($in) = @_;

  my $str = &slurp_file($in, "bin");
  return(undef) if (! defined $str);
  
  return(&mem_gunzip($str));
}

##########

sub strip_header {
  my ($header, $str) = @_;

  my $lh = length($header);
  
  my $sh = substr($str, 0, $lh);

  return(substr($str, $lh))
    if ($sh eq $header);
  
  return($str);
}

##########

sub write_syscall_logfile {
  my ($ofile, @command) = @_;

  my ($retcode, $stdout, $stderr) = do_system_call(@command);

  my $otxt = "[[COMMANDLINE]] " . join(" ", @command) . "\n"
    . "[[RETURN CODE]] $retcode\n"
      . "[[STDOUT]]\n$stdout\n\n"
        . "[[STDERR]]\n$stderr\n";

  return(0, $otxt, $stdout, $stderr, $retcode)
    if (! writeTo($ofile, "", 0, 0, $otxt));

  return(1, $otxt, $stdout, $stderr, $retcode);
}

#####

sub get_txt_last_Xlines {
  my ($txt, $X) = @_;

  my @toshowa = ();
  my @a = split(m%\n%, $txt);
  my $e = scalar @a;
  my $b = (($e - $X) > 0) ? ($e - $X) : 0;
  foreach (my $i = $b; $i < $e; $i++) {
    push @toshowa, $a[$i];
  }

  return(@toshowa);
}

####################

sub warn_print {
  print("[Warning] ", join(" ", @_), "\n");
}

##########

sub error_quit {
  print("[ERROR] ", join(" ", @_), "\n");
  exit(1);
}

##########

sub ok_quit {
  print(join(" ", @_), "\n");
  exit(0);
}

####################

sub is_file_ok {
  my ($file) = @_;

  return("Empty filename")
    if (is_blank($file));

  return("File does not exist")
    if (! -e $file);
  return("Is not a file")
    if (! -f $file);
  return("Is not readable")
    if (! -r $file);

  return("");
}

#####

sub get_file_stat {
  my ($file, $pos) = @_;

  my $err = &is_file_ok($file);
  return($err, undef) if (! is_blank($err));

  my @a = stat($file);

  return("No stat obtained ($file)", undef)
    if (scalar @a == 0);

  return("", @a);
}

#####

sub _get_file_info_core {
  my ($pos, $file) = @_;

  my ($err, @a) = &get_file_stat($file);

  return(undef, $err)
    if (! &is_blank($err));

  return($a[$pos], "");
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
  my ($criteria, @files_list) = @_;

  my $func = undef;
  if ($criteria eq "size") {
    $func = \&get_file_size;
  } elsif ($criteria eq "atime") {
    $func = \&get_file_atime;
  } elsif ($criteria eq "mtime") {
    $func = \&get_file_mtime;
  } elsif ($criteria eq "ctime") {
    $func = \&get_file_ctime;
  } else {
    return("Unknown criteria", undef);
  }

  my %tmp = ();
  my @errs = ();
  foreach my $file (@files_list) {
    my ($v, $err) = &$func($file);
    if (! is_blank($err)) {
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

  my $errmsg = join(". ", @errs);

  return($errmsg, @out);
}

#####

# Note: will return undef if any file in the list is not "ok"
sub _XXXest_core {
  my ($mode, @in) = @_;

  my ($err, @or) = &sort_files($mode, @in);

  return(undef)
    if (scalar @or != scalar @in);

  return(@or);
}

#####

sub newest {
  my @or = &_XXXest_core("mtime", @_);

  return(undef) if (scalar @or == 0);

  return(@or[-1]);
}

#####

sub oldest {
  my @or = &_XXXest_core("mtime", @_);

  return(undef) if (scalar @or == 0);

  return(@or[0]);
}

#####

sub biggest {
  my @or = &_XXXest_core("size", @_);

  return(undef) if (scalar @or == 0);

  return(@or[-1]);
}

#####

sub smallest {
  my @or = &_XXXest_core("size", @_);

  return(undef) if (scalar @or == 0);

  return(@or[0]);
}

####################

# Will create directories up to requested depth
sub make_dir {
  my ($dest, $perm) = @_;

  return(1) if (-d $dest);

  $perm = 0755 if (is_blank($perm)); # default permissions

  my $t = "";
  my @todo = split(m%/%, $dest);
  foreach my $d (@todo) {
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
  my ($dir) = @_;

  opendir DIR, "$dir"
    or return("Problem opening directory ($dir) : $!", undef, undef, undef);
  my @fl = grep(! m%^\.\.?%, readdir(DIR));
  close DIR;

  my @d = ();
  my @f = ();
  my @u = ();
  foreach my $entry (@fl) {
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

  return("", \@d, \@f, \@u);
}

#####

sub get_dirs_list {
  my ($dir) = @_;

  my ($err, $rd, $rf, $ru) = &list_dirs_files($dir);

  return(undef) if (! is_blank($err));

  return(@{$rd});
}

#####

sub get_files_list {
  my ($dir) = @_;

  my ($err, $rd, $rf, $ru) = &list_dirs_files($dir);

  return(undef) if (! is_blank($err));

  return(@{$rf});
}

############################################################

1;
