#!/usr/bin/env perl
#
# $Id$
#

use strict;
use Getopt::Long;
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/common/lib");
}
use lib (@f4bv);

use MMisc;

my $usage = "$0 [-removeext] [-xexec] [-link] basedestdir adddestdir files\n\n"
  . "Will install all \'files\' in \'basedestdir/addestdir\'\n\n"
  . "Where:\n"
  . "  -removeext   removes the file extension\n"
  . "  -xexec       makes the file executable\n"
  . "  -link        makes symbolic links instead of using rsync\n";

my $remext = 0;
my $isexec = 0;
my $makelink = 0;
GetOptions
  (
   'removeext'  => \$remext,
   'xecec'      => \$isexec,
   'link'       => \$makelink,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n$usage");

MMisc::error_quit("Not enough arguments\n\n$usage")
  if (scalar @ARGV < 3);

my ($tbdd, $destdir, @srcfiles) = @ARGV;
my $bdd = MMisc::get_dir_actual_dir($tbdd);
MMisc::error_quit("\'basedestdir\' dir can not be \'\/\', sorry")
  if ($bdd eq "/");
$bdd =~ s%/$%%;

# Checks
my $etxt = "";
my $err = MMisc::check_dir_w($bdd);
$etxt .= "Directory \'$bdd\': $err. "
  if (! MMisc::is_blank($err));
foreach my $f (@srcfiles) {
  $err = MMisc::check_file_r($f);
  $etxt .= "File \'$f\': $err. " 
    if (! MMisc::is_blank($err));
}
MMisc::error_quit($etxt) 
  if (! MMisc::is_blank($etxt));

# Make the destination directory
my $fdd = "$bdd/$destdir";
MMisc::error_quit("Problem creating writable directory ($fdd)")
  if (! MMisc::make_wdir($fdd));
foreach my $f (@srcfiles) {
  &doit($f, $fdd);
}

MMisc::ok_exit();

##########

sub _chmodx {
  my $dfile = MMisc::get_file_actual_file(shift @_);
  
  if ($isexec) {
    return if (-x $dfile);
    `chmod a+x $dfile`;
    MMisc::error_quit("Problem running \'chmod\' command on $dfile")
	if ($? != 0);
    MMisc::error_quit("Could not make file ($dfile) executable")
	if (! -x $dfile);
  } else {
    return if (! -x $dfile);
    `chmod a-x $dfile`;
    MMisc::error_quit("Problem running \'chmod\' command on $dfile")
	if ($? != 0);
    MMisc::error_quit("Could not make file ($dfile) not executable")
	if (-x $dfile);
  }
}

#####

sub linkit {
  my $file = shift @_;
  my $to  = shift @_;

  my $sfile = $file;
  $sfile =~ s%^.+/([^/]+)$%$1%;

  my $dfile = $sfile;
  $dfile =~ s%\.[^\.]+$%% if ($remext);

  my $from = $file;
  $from =~ s%^(.+)/[^/]+$%$1%;

  # of note: for 'cd' the from/to change, therefore:
  my $relpath = MMisc::compute_actual_dir_relative_path($to, $from);
  MMisc::error_quit("Could not compute relative path from ($to) to ($from)")
      if (! defined $relpath);

  my $here = MMisc::get_pwd();
  MMisc::error_quit("Could not chdir to destination directory ($to)")
      if (! chdir($to));
  
  if (! -l $dfile) { # nothing present, let us try to create a symlink
    `ln -s $relpath/$sfile $dfile`;
    MMisc::error_quit("Problem making a symbolic link from [$file] into [$to]")
	if ($? != 0);
  }
  &_chmodx($dfile);

  MMisc::error_quit("Could not chdir to source directory ($here)")
      if (! chdir($here));
}

#####

sub rsyncit {
  my $file = shift @_;
  my $fdd  = shift @_;

  my $fe = $file;
  $fe =~ s%^.+/([^/]+)$%$1%;
  my $dfile = "$fdd/$fe";
  $dfile =~ s%\.[^\.]+$%% if ($remext);
  `rsync -a $file $dfile`;
  MMisc::error_quit("Problem rsync-ing file [$file] as [$dfile]")
      if ($? != 0);
  MMisc::error_quit("ERROR: copying file ($file -> $dfile)\n")
      if ((! -e $dfile) && (! -f $dfile));
  &_chmodx($dfile);
}

#####

sub doit {
  if ($makelink) {
    &linkit(@_);
  } else {
    &cpit(@_);
  }
}
