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
  chomp @all if ($mode ne "bin");

  my $jc = ($mode ne "bin") ? "\n" : "";
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

############################################################

1;
