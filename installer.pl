#!/usr/bin/env perl

use strict;

my $envv = "F4DE_BASE";

my @tdd = ("bin", "lib", "lib/data");
die("ERROR: Set the $envv environment variable with the base destination directory before continuing\nThe script will create the following directories in it: " . join (", ", @tdd) . "\n")
  if (! $ENV{$envv});

my $bdd = $ENV{$envv};
die("ERROR: Destination dir can not be \'\/\', sorry")
  if ($bdd eq "/");

my @needd = ("common", "TrecVid08");
my (@tbs, @tls, @tds);
foreach my $nd (@needd) {
  die("ERROR: Script must be run in base source directory (did not find $nd)\n")
    if ((! -e $nd) || (! -d $nd));
  push @tbs, &_find_files($nd, ".pl");
  push @tls, &_find_files($nd, ".pm");
  push @tds, &_find_files($nd, "data");
}
foreach my $ra (\@tbs,\@tls,\@tds) {
  die("Could not find some elements\n")
    if (scalar @{$ra} == 0);
}

my @rdd;
$bdd =~ s%\/$%%;
foreach my $edd (@tdd) {
  my $dd = "$bdd/$edd";
  &_mkdir($dd);
  push @rdd, $dd;
}

&_cp($rdd[0], "pl", 1, @tbs);
&_cp($rdd[1], "", 0, @tls);
&_cp($rdd[2], "", 0, @tds);

print("\nDone.\n");
print("\nIf you have not done so, yet, please set up the \'$envv\' environment variable to \'$bdd\'\n");

exit(0);

sub _mkdir {
  my $dir = shift @_;

  die("ERROR: Not a directory ($dir)\n") if ((-e $dir) && (! -d $dir));
  return("") if (-e $dir);

  print "Creating Directory: $dir\n";
  `mkdir -p $dir`;

  die("ERROR: Could not create requested directory ($dir)")
    if ((! -e $dir) || (! -d $dir));
}

sub _find_files {
  my $sd = shift @_;
  my $ext = shift @_;

  my @l = `find $sd -type f | grep -i $ext | grep -v CVS | grep -v '\~'`;
  chomp @l;

  return(@l);
}

sub _cp {
  my $ddir = shift @_;
  my $ext = shift @_;
  my $x = shift @_;
  my @files = @_;

  foreach my $file (@files) {
    my $dfile = $file;
    $dfile =~ s%\.$ext$%%; # remove the extension if given
    my $fd = $dfile;
    $fd =~ s%^(.+)/([^\/]+)$%$2%;
    $fd = "$ddir/$fd";
    `cp $file $fd`;
    die("ERROR: copying file ($file) to dir ($ddir) [ie: $fd]\n")
      if ((! -e $fd) && (! -f $fd));
    if ($x) {
      `chmod a+x $fd`;
      die("ERROR: could not make file ($fd) exectubale")
	if (! -x $fd);
    }
    print "Installed: $fd\n";
  }
}
