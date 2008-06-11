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

  open FILE, "<$fname"
    or die("MMisc Internal error: Can not open file to slurp ($fname): $!\n");
  my @all = <FILE>;
  close FILE;
  chomp @all;

  my $tmp = join("\n", @all);

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

sub writeTo {
  my ($file, $ext, $printfn, $append, $txt) = @_;

  my $ofile = "";
  if ((defined $file) && (! &is_blank($file))) {
    if (-d $file) {
      print "WARNING: Provided file ($file) is a directory, will write to STDOUT\n";
    } else {
      $ofile = $file;
      $ofile .= $ext;
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
    print "WARNING: Could not create \'$tofile\' (will write to STDOUT): $!\n"
      if (&is_blank($ofile));
  }

  if (! &is_blank($ofile)) {
    print FILE $txt;
    close FILE;
    print((($da) ? "Appended to file:" : "Wrote:") . "$ofile\n") if ($printfn);
  } else {
    print $txt;
  }
}

############################################################

1;
