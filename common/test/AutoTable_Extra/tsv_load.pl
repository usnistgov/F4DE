#!/usr/bin/env perl
#
# $Id$
#

use lib("../../../common/lib");

use MMisc;
use AutoTable;

my ($if) = @ARGV;

my $err = MMisc::check_file_r($if);
MMisc::error_quit("Problem with input file ($if) : $err")
  if (! MMisc::is_blank($err));


my $at = new AutoTable();
$at->loadCSV($if, undef, undef, undef, undef, "\t"); &__aterr($at);
$at->setProperties({ "KeyColumnCsv" => "Keep"}); &__aterr($at);
print " (The default is not to show the \'MasterKey\' column, here we will show it for the CSV file)\n";
print "\n\n[**] Text\n" . $at->renderTxtTable(); &__aterr($at);
my ($csv, $sp) = $at->renderCSVandSpecial(); &__aterr($at);
print "\n\n[**] CSV\n$csv\n";
print "\n\n[**] SpecialCSV\n$sp\n";

MMisc::ok_quit("Done");

sub __aterr { MMisc::error_quit("Issue with AT : " . $_[0]->get_errormsg()) if ($_[0]->error()); }
