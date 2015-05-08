#!/usr/bin/env perl
#
# $Id$
#

use strict;
use MMisc;

use MtSQLite;

my $err = 0;

#####
print "\n** SQLite command line location: ";

my ($err, $sqlite, $sv) = MtSQLite::get_sqlitecmd();

if (MMisc::is_blank($sqlite)) {
  print "** could not find \'sqlite3\' in your PATH **\n";
  $err++;
} else {
  print "$sqlite";
  if (! MMisc::is_blank($err)) {
    print " ** Problem with version: $err **";
    $err++;
  }
  print " [$sv]" if (! MMisc::is_blank($sv));
  print "\n";
}

##########
MMisc::error_quit("Not all tests ok")
  if ($err);

MMisc::ok_quit();
