#!/usr/bin/env perl

use strict;

my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../../common/lib");
}
use lib (@f4bv);

use MMisc;

my $usage = "$0 dtdfile xmlfile xmllint_cmd [xmllint_options]\n".
"Desc:  Adapt an XML file to use a local copy of a DTD file an run xmllint_location xmllint_options on it\n";
MMisc::error_quit("Not enough arguments on command line\n\n$usage\n")
  if (scalar @ARGV < 3);


##########
# Check DTD & XML files
my $dtd = shift @ARGV;
my $xml = shift @ARGV;
my $btool = shift @ARGV;

my $err0 = MMisc::check_file_r($dtd);
MMisc::error_quit("Problem with \'dtdfile\' ($dtd) : $err0")
  if (! MMisc::is_blank($err0));
$err0 = MMisc::check_file_r($xml);
MMisc::error_quit("Problem with \'xmlfile\' ($xml) : $err0")
  if (! MMisc::is_blank($err0));
my $tool = MMisc::cmd_which($btool);
MMisc::error_quit("Problem with finding tool ($btool)")
  if (! defined $tool);
$err0 = MMisc::check_file_x($tool);
MMisc::error_quit("Problem with \'xmllint_cmd\' ($tool) : $err0")
  if (! MMisc::is_blank($err0));

##########
# Get temp dir
my $tdir = MMisc::get_tmpdir();
MMisc::error_quit("Issue obtaining temporary directory")
  if (! defined $tdir);

##########
# Copy DTD file to temp dir
my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($dtd);
MMisc::error_quit("Problem spliting file information ($dtd) : $err")
  if (! MMisc::is_blank($err));
my $ldtd = MMisc::concat_dir_file_ext($tdir, $f, $e);
$err = MMisc::filecopy($dtd, $ldtd);
MMisc::error_quit("Problem copying DTD file ($dtd) to local copy ($ldtd): $err")
  if (! MMisc::is_blank($err));

##########
# Adapt XML file to use local copy
($err, $d, $f, $e) = MMisc::split_dir_file_ext($xml);
MMisc::error_quit("Problem spliting file information ($xml) : $err")
  if (! MMisc::is_blank($err));
my $lxml = MMisc::concat_dir_file_ext($tdir, $f, $e);

my $slurp = MMisc::slurp_file($xml, 'bin');
MMisc::error_quit("Problem reading XML file ($xml): seems empty ?")
  if (! defined $slurp);

# fix "Private" External DTDs
#ex: <!DOCTYPE madcat SYSTEM "ftp://jaguar.ncsl.nist.gov/madcat/resources/madcat.v1.0.6.dtd">
#ex: <!DOCTYPE mteval SYSTEM "ftp://jaguar.ncsl.nist.gov/mt/resources/mteval-xml-v1.6.dtd">
if ($slurp =~ s%(\<\!\s*doctype[^\>]+?system)[^\>]+?(\>)%$1 \"file://$ldtd\"$2%isg) {
  # replace all of them just in case some are commented
  MMisc::error_quit("Problem writing output xml ($lxml)")
      if (! MMisc::writeTo($lxml, undef, 0, 0, $slurp));
} else {
  MMisc::error_quit("Did not find requested \'doctype\' regexp, aborting");
}

##########
# 
#MMisc::ok_quit("$lxml\n");

my $cmd = "$tool " . join(" ", @ARGV) . " $lxml";
system($cmd);
