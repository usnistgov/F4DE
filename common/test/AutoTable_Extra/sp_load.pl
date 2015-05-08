#!/usr/bin/env perl
#
# $Id$
#

use lib("../../../common/lib");

use MMisc;
use AutoTable;

my ($if, $if2, $pk, $k, $r, $sort) = @ARGV;

my $err = MMisc::check_file_r($if);
MMisc::error_quit("Problem with input file ($if) : $err")
  if (! MMisc::is_blank($err));

my $err = MMisc::check_file_r($if2);
MMisc::error_quit("Problem with input file ($if2) : $err")
  if (! MMisc::is_blank($err));

my @apk = split(m%\,%, $pk);
my @ak  = split(m%\,%, $k);
my @ar  = split(m%\,%, $r);

my %sorts = 
  (
   'reverse'    => 'main::reverse_sort',
   'sha1'       => 'main::sha1digest_sort',
   'sha224'     => 'main::sha224digest_sort',
   'sha256'     => 'main::sha256digest_sort',
   'sha384'     => 'main::sha384digest_sort',
   'sha512'     => 'main::sha512digest_sort',
   'sha512224'     => 'main::sha512224digest_sort',
   'sha512256'     => 'main::sha512256digest_sort',
  );

&doit(\@apk, \@ak, \@ar, $sort);

MMisc::ok_quit("Done");

########################################

sub __aterr { MMisc::error_quit("Issue with AT : " . $_[0]->get_errormsg()) if ($_[0]->error()); }
#####

sub reverse_sort { my ($a,$b) = @_; return (-($a cmp $b)); }

sub sha1digest_sort { my ($a,$b) = @_; return (MMisc::string_sha1digest($a) cmp MMisc::string_sha1digest($b)); }

sub sha224digest_sort { my ($a,$b) = @_; return (MMisc::string_sha224digest($a) cmp MMisc::string_sha224digest($b)); }

sub sha256digest_sort { my ($a,$b) = @_; return (MMisc::string_sha256digest($a) cmp MMisc::string_sha256digest($b)); }

sub sha384digest_sort { my ($a,$b) = @_; return (MMisc::string_sha384digest($a) cmp MMisc::string_sha384digest($b)); }

sub sha512digest_sort { my ($a,$b) = @_; return (MMisc::string_sha512digest($a) cmp MMisc::string_sha512digest($b)); }

sub sha512224digest_sort { my ($a,$b) = @_; return (MMisc::string_sha512224digest($a) cmp MMisc::string_sha512224digest($b)); }

sub sha512256digest_sort { my ($a,$b) = @_; return (MMisc::string_sha512256digest($a) cmp MMisc::string_sha512256digest($b)); }

sub doit {
  my ($rmkc, $rk, $rr, $sort) = MMisc::iuav(\@_, undef, undef, undef, undef);

  print "######################################## [$text]\n";

  my $at = new AutoTable();
  $at->loadCSVandSpecial($if, $if2, $rmkc, $rk, $rr); &__aterr($at);
  $at->setProperties({ "KeyColumnCsv" => "Keep"}); &__aterr($at);
  if (defined $sort) {
    my $name = (exists $sorts{$sort}) ? $sorts{$sort} : '';
    MMisc::error_quit("Unknown sort function") if (MMisc::is_blank($name));
    #
    print "-- [Sort=$sort/$name]\n";
    $at->setProperties({ "KeyColumnTxt" => "Keep"}); &__aterr($at);
    $at->setProperties({ "KeyColumnCsv" => "Keep"}); &__aterr($at);
    $at->setProperties({ "KeyColumnHTML" => "Keep"}); &__aterr($at);
    $at->setProperties({ "KeyColumnLaTeX" => "Keep"}); &__aterr($at);
    #
    $at->setProperties({ 'SortRowKeyTxt' => "\&Function=$name" }); &__aterr($at);
    $at->setProperties({ 'SortRowKeyCsv' => "\&Function=$name" }); &__aterr($at);
    $at->setProperties({ 'SortRowKeyHTML' => "\&Function=$name" }); &__aterr($at);
    $at->setProperties({ 'SortRowKeyLaTeX' => "\&Function=$name" }); &__aterr($at);
  }
  print " (The default is not to show the \'MasterKey\' column, here we will show it for the CSV file)\n";
  print "\n##########\n[**] Text\n" . $at->renderTxtTable(); &__aterr($at);
  my ($csv, $sp) = $at->renderCSVandSpecial(); &__aterr($at);
  print "\n##########\n[**] CSV\n$csv\n";
  print "\n\n[**] SpecialCSV\n$sp\n";
  print "\n##########\n[**] HTML\n" . $at->renderHTMLTable(); &__aterr($at);
  print "\n##########\n[**] LaTeX\n" . $at->renderLaTeXTable(); &__aterr($at);
}
