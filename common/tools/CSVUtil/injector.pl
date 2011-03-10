#!/usr/bin/env perl

use strict;

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "CSVHelper") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Options processing

my $usage = &set_usage();
MMisc::error_quit($usage) if (scalar @ARGV == 0);

# Default values for variables
my $addCol = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                           a      h                    #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'addColumns' => \$addCol,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if (($opt{'help'}) || (scalar @ARGV == 0));

MMisc::error_quit($usage) 
  if (scalar @ARGV < 3);

my ($in, $rin, $out) = @ARGV;

my ($replace_mk, $racn, %replace) = &load_replace($rin);
my @repl_colname = ();
foreach my $c (@$racn) { push @repl_colname, $c; }

open IFILE, "<$in"
  or MMisc::error_quit("Problem opening input file ($in) : $!");
open OFILE, ">$out"
  or MMisc::error_quit("Problem opening output file ($out) : $!");

my $icsvh = new CSVHelper();
my $ocsvh = new CSVHelper();


my $sh = 1;
my %colm = ();
my %seen_mk = ();
my %unseen_mk = ();
foreach my $mk (keys %replace) { $unseen_mk{$mk}++; }
my %repl_count = ();
my $inlc = 0;
while (my $line = <IFILE>) {
  my @inh = $icsvh->csvline2array($line);
  MMisc::error_quit("Problem with input CSV : " . $icsvh->get_errormsg() . "\n[Line $sh : $line]")
      if ($icsvh->error());

  if ($sh == 1) { # Header
    &get_colm(@inh);
    $inlc = scalar @inh;
    $icsvh->set_number_of_columns($inlc);
    MMisc::error_quit("Required primary key ($replace_mk) not found")
        if (! exists $colm{$replace_mk});
    foreach my $k (@repl_colname) {
      next if (exists $colm{$k});
      if ($addCol) {
        $colm{$k} = scalar @inh; # count before adding => get last count
        push @inh, $k;
        next;
      }
      MMisc::error_quit("Required key ($k) not found");
    }
    $inlc = scalar @inh;
    $ocsvh->set_number_of_columns($inlc);
  } else {
    @inh = &fixline($replace_mk, $inlc, @inh);
  }

  my $otxt = $ocsvh->array2csvline(@inh);
  MMisc::error_quit("Problem with output CSV : " . $ocsvh->get_errormsg() . "\n[Line $sh : $line]")
      if ($ocsvh->error());

  print OFILE "$otxt\n";

  $sh++;
}
close IFILE;
close OFILE;
$sh--; # Remove orig

print "\n** " . scalar(keys %seen_mk) . " Master Keys Found\n";
if (scalar(keys %seen_mk) > 0) {
  foreach my $col (@repl_colname) {
    print "  - \'$col\' replaced " . $repl_count{$col} . " times\n";
  }
}

print "\n** " . scalar(keys %unseen_mk) . " Master Keys NOT Found\n";

MMisc::ok_quit("\nDone (processed $sh lines)\n");

####################

sub get_colm {
  for (my $i = 0; $i < scalar @_; $i++) {
    my $v = $_[$i];
    $colm{$v} = $i;
  }
}

##########

sub fixline {
  my ($rmk, $inlc, @in) = @_;

  my $mk = $in[$colm{$rmk}];
  
  # extend columns to the expected output number
  while (scalar @in < $inlc) { push @in, ""; }

  if (! exists $replace{$mk}) {
    $unseen_mk{$mk}++;
    return(@in);
  }

  foreach my $col (@repl_colname) {
    my $cv = $in[$colm{$col}];
    my $rv = $replace{$mk}{$col};
    next if ($cv eq $rv); # same values
    $in[$colm{$col}] = $replace{$mk}{$col};
    $repl_count{$col}++;
  }
 
  $seen_mk{$mk}++;
  delete $unseen_mk{$mk};

  return(@in);
}

##########

sub load_replace {
  my ($if) = @_;

  open RIFILE, "<$if"
    or MMisc::error_quit("Problem opening Replacement input file ($if) : $!");

  my $ricsvh = new CSVHelper();

  my $sh = 1;
  my $rmc = "";
  my %repl = ();
  my @col_name = ();
  while (my $line = <RIFILE>) {
    my @inh = $ricsvh->csvline2array($line);
    MMisc::error_quit("Problem with input CSV : " . $ricsvh->get_errormsg() . "\n[Line $sh : $line]")
        if ($ricsvh->error());

    if ($sh == 1) { # Header
      MMisc::error_quit("Need at least two columns in Replacement CSV file to work, found ". scalar @inh) if (scalar @inh < 2);

      $ricsvh->set_number_of_columns(scalar @inh);
      
      $rmc = $inh[0];
      @col_name = @inh[1..$#inh];
      my %tmp = ();
      foreach my $c (@col_name) {
        MMisc::error_name("Column name ($c) has to be unique and non empty")
            if ((MMisc::is_blank($c)) || (++$tmp{$c} > 1));
      }
      $sh++;
      next;
    }

    my $mk = shift @inh;
    MMisc::error_quit("Master Key uniqueness in doubt ($mk)")
        if (exists $repl{$mk});
    for (my $i = 0; $i < scalar @inh; $i++) {
      $repl{$mk}{$col_name[$i]} = $inh[$i];
    }

    $sh++;
  }
  close RIFILE;

  return($rmc, \@col_name, %repl);
}

####################

sub set_usage{
  my $tmp=<<EOF

$0 [--help] [--addColumns] infile.csv replacefile.csv outfile.csv

Replace columns from input file by columns from replacefile.
Match is done on the first column in replacefile (conisdered a primary key), and replaced column names have to match.

Where:
  --help        This help message
  --addColumns  If a column name in 'replacefile.csv' does not exist in 'infile.csv', it will be added to 'outfile.csv'

EOF
;

  return($tmp);
}
