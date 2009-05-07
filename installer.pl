#!/usr/bin/env perl

use strict;
use Getopt::Long;
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

my $remext = 0;
my $isexec = 0;
GetOptions
  (
   'removeext'  => \$remext,
   'xecec'      => \$isexec,
  ) or error_quit("Wrong option(s) on the command line, aborting\n");

error_quit("Usage: $0 [options] basedestdir adddestdir files\n")
  if (scalar @ARGV < 3);

my ($bdd, $destdir, @srcfiles) = @ARGV;
error_quit("ERROR: Destination dir can not be \'\/\', sorry")
  if ($bdd eq "/");

$bdd =~ s%/$%%;

# Checks
my $etxt = "";
$etxt .= "Directory \'$bdd\' is not a directory" if (! -d $bdd);
$etxt .= "Directory \'$bdd\' not writable" if (! -w $bdd);
foreach my $f (@srcfiles) {
  $etxt .= "File \'$f\' missing\n" if (! -e $f);
  $etxt .= "File \'$f\' not a file\n" if (! -f $f);
  $etxt .= "File \'$f\' readable\n" if (! -r $f);
}
error_quit($etxt) if ($etxt ne "");

#ok_quit("[*] ", join("  |  ", @ARGV), "\n");

# Make the destination directory
my $fdd = "$bdd/$destdir";
&_mkdir($fdd);
foreach my $f (@srcfiles) {
  &_cp($f, $fdd);
}

ok_quit();

##########

sub _mkdir {
  my $dir = shift @_;

  error_quit("ERROR: Not a directory ($dir)\n") if ((-e $dir) && (! -d $dir));
  return() if (-e $dir);

  `mkdir -p $dir`;

  error_quit("ERROR: Could not create requested directory ($dir)")
    if ((! -e $dir) || (! -d $dir));
}

#####

sub _chmodx {
  my $dfile = shift @_;

  if ($isexec) {
    return if (-x $dfile);
    `chmod a+x $dfile`;
    error_quit("ERROR: could not make file ($dfile) executable")
      if (! -x $dfile);
  } else {
    return if (! -x $dfile);
    `chmod a-x $dfile`;
    error_quit("ERROR: could not make file ($dfile) not executable")
      if (-x $dfile);
  }
}

#####

sub _cp {
  my $file = shift @_;
  my $fdd  = shift @_;

  my $fe = $file;
  $fe =~ s%^.+/([^/]+)$%$1%;
  my $dfile = "$fdd/$fe";
  $dfile =~ s%\.[^\.]+$%% if ($remext);
  `rsync -a $file $dfile`;
  error_quit("ERROR: copying file ($file -> $dfile)\n")
    if ((! -e $dfile) && (! -f $dfile));
  &_chmodx($dfile);
}

##########

sub ok_quit {
  print @_;
  exit(0);
}

#####

sub error_quit {
  print @_;
  exit(1);
}
