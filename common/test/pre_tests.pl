#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

use strict;
use xmllintHelper;
use MMisc;

my $err = 0;

##########
print "** Checking for Perl Required Packages:\n";
my $ms = 1;

$ms = &_chkpkg("Getopt::Long", "Data::Dumper", "File::Temp",
               "Cwd", "Text::CSV");
if ($ms > 0) {
  print "  ** ERROR: Not all packages found, you will not be able to run the program (and some F4DE package will most likely fail this step), install the missing packages and re-run the checks\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}

##########
print "\n** Checking for xmllint:\n";
my $xmllint_env = "F4DE_XMLLINT";
my $xmllint = MMisc::get_env_val($xmllint_env, "");
if ($xmllint ne "") {
  print "- using the one specified by the $xmllint_env environment variable ($xmllint)\n";
}

my $error = "";
# Confirm xmllint is present and at least 2.6.30
my $xobj = new xmllintHelper();
$xobj->set_xmllint($xmllint);
if ($xobj->error()) {
  print $xobj->get_errormsg();
  print "After installing a suitable version, set the $xmllint_env environment variable to ensure the use of the proper version if it is not in your PATH\n";
  $err++;
} else {
  $xmllint = $xobj->get_xmllint();
  print "  xmllint ($xmllint) is valid and its version is recent enough\n";
}

####################

MMisc::error_quit("\nSome issues, fix before attempting to run make check again\n") if ($err);

MMisc::ok_quit("\n** Pre-requisite testing done\n\n");

####################

sub _chkpkg {
  my @tocheck = @_;

  my $ms = scalar @tocheck;
  foreach my $i (@tocheck) {
    print "- $i : ";
    my $v = MMisc::check_package($i);
    my $t = $v ? "ok" : "**missing**";
    print "$t\n";
    $ms -= $v;
  }

  return($ms);
}
