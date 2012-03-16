#!/usr/bin/env perl

use lib("../../../common/lib");

use MMisc;
use AutoTable;

my ($if, $if2, $pk, $k, $r) = @ARGV;

my $err = MMisc::check_file_r($if);
MMisc::error_quit("Problem with input file ($if) : $err")
  if (! MMisc::is_blank($err));

my $err = MMisc::check_file_r($if2);
MMisc::error_quit("Problem with input file ($if2) : $err")
  if (! MMisc::is_blank($err));

my @apk = split(m%\,%, $pk);
my @ak  = split(m%\,%, $k);
my @ar  = split(m%\,%, $r);

&doit(\@apk, \@ak, \@ar);

MMisc::ok_quit("Done");

sub __aterr { MMisc::error_quit("Issue with AT : " . $_[0]->get_errormsg()) if ($_[0]->error()); }

sub doit {
  my ($rmkc, $rk, $rr) = MMisc::iuav(\@_, undef, undef, undef);

  print "######################################## [$text]\n";

  my $at = new AutoTable();
  $at->loadCSVandSpecial($if, $if2, $rmkc, $rk, $rr); &__aterr($at);
  $at->setProperties({ "KeyColumnCsv" => "Keep"}); &__aterr($at);
  print " (The default is not to show the \'MasterKey\' column, here we will show it for the CSV file)\n";
  print "\n##########\n[**] Text\n" . $at->renderTxtTable(); &__aterr($at);
  my ($csv, $sp) = $at->renderCSVandSpecial(); &__aterr($at);
  print "\n##########\n[**] CSV\n$csv\n";
  print "\n\n[**] SpecialCSV\n$sp\n";
  print "\n##########\n[**] HTML\n" . $at->renderHTMLTable(); &__aterr($at);
  print "\n##########\n[**] LaTeX\n" . $at->renderLaTeXTable(); &__aterr($at);
}
