#!/usr/bin/env perl

use strict;
use TV08TestCore;

my $err = 0;

##########
print "** Checking for Perl Packages:\n";
my @tocheck = ("Getopt::Long", "Data::Dumper", "File::Temp", 
#	       "Statistics::Descriptive::Discrete", 
	       );
my $ms = scalar @tocheck;
foreach my $i (@tocheck) {
  print "- $i : ";
  my $v = TV08TestCore::check_package($i);
  my $t = $v ? "ok" : "**missing**";
  print "$t\n";
  $ms -= $v;
}
if ($ms > 0) {
  print "  ** Not all packages found, you will not be able to run the program, please install the missing ones\n\n";
  $err++;
} else {
  print "  Found all packages\n\n";
}

##########
print "** Checking for xmllint:\n";
my $xmllint_env = "TV08_XMLLINT";
my $xmllint = TV08TestCore::_get_env_val($xmllint_env, "");
if ($xmllint ne "") {
  print "- using the one specified by the $xmllint_env environment variable ($xmllint)\n";
}

my $error = "";
# Confirm xmllint is present and at least 2.6.30
($xmllint, $error) = &_check_xmllint($xmllint);
if (! &TV08TestCore::is_blank($error)) {
  print "$error\n";
  print "After installing a suitable version, set the $xmllint_env environment variable to ensure the use of the proper version if it is not in your PATH\n";
  $err++;
} else {
  print "  xmllint ($xmllint) is ok and recent enough\n";
}

####################

error_quit("\nSome issues, fix before attempting to run make check again\n") if ($err);

ok_quit("\n** Pre-requisite testing done\n\n");


########################################

sub _check_xmllint {
  my $xmllint = shift @_;

  # If none provided, check if it is available in the path
  if ($xmllint eq "") {
    my ($retcode, $stdout, $stderr) = &TV08TestCore::_do_system_call('which', 'xmllint');
    return("", "Could not find a valid \'xmllint\' command in the PATH, aborting\n")
      if ($retcode != 0);
    $xmllint = $stdout;
  }

  $xmllint =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  # Check that the file for xmllint exists and is an executable file
  return("", "\'xmllint\' ($xmllint) does not exist, aborting\n")
    if (! -e $xmllint);

  return("", "\'xmllint\' ($xmllint) is not a file, aborting\n")
    if (! -f $xmllint);

  return("", "\'xmllint\' ($xmllint) is not executable, aborting\n")
    if (! -x $xmllint);

  # Now check that it actually is xmllint
  my ($retcode, $stdout, $stderr) = &TV08TestCore::_do_system_call($xmllint, '--version');
  return("", "\'xmllint\' ($xmllint) does not seem to be a valid \'xmllint\' command, aborting\n")
    if ($retcode != 0);
  
  if ($stderr =~ m%using\s+libxml\s+version\s+(\d+)%) {
    # xmllint print the command name followed by the version number
    my $version = $1;
    return("", "\'xmllint\' ($xmllint) version too old: requires at least 2.6.30 (ie 20630, installed $version), aborting\n")
      if ($version <= 20630);
  } else {
    return("", "Could not confirm that \'xmllint\' is valid, aborting\n");
  }

  return($xmllint, "");
}

####################

sub ok_quit {
  print @_;
  exit(0);
}

#####

sub error_quit {
  print @_;
  exit(1);
}
