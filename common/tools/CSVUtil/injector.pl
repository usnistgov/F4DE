#!/usr/bin/env perl

use strict;
#use Data::Dumper;

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
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

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
my $dupl = 0;
my $warnok = 0;
my %ocm = ();
my @er = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:    D                      a   e  h              w     #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'addColumns'  => \$addCol,
   'Duplicates'  => \$dupl,
   'warnColumns' => \$warnok,
   'otherColumnName=s' => \%ocm,
   'extraReplace=s' => \@er,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if (($opt{'help'}) || (scalar @ARGV == 0));

MMisc::error_quit($usage) 
  if (scalar @ARGV < 3);

my ($in, $rin, $out) = @ARGV;

my $replace_mk = "";
my @repl_colname = ();
my %replace = ();
&load_replace($rin, \$replace_mk, \@repl_colname, \%replace);
foreach my $if (@er) { &load_replace($if, \$replace_mk, \@repl_colname, \%replace); }

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

  my @out = ();
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
      MMisc::error_quit("Required key ($k) not found") if (! $warnok);
      MMisc::warn_print("Expected column key ($k) not found");
    }
    $inlc = scalar @inh;
    $ocsvh->set_number_of_columns($inlc);
    @out = [@inh];
  } else {
    @out = &fixline($replace_mk, $inlc, @inh);
  }

  my $otxt = "";
  for (my $i = 0; $i < scalar @out; $i++) {
    my @tmp = @{$out[$i]};
    $otxt .= $ocsvh->array2csvline(@tmp);
    $otxt .= "\n";
    MMisc::error_quit("Problem with output CSV : " . $ocsvh->get_errormsg() . "\n[Line $sh : $line]")
        if ($ocsvh->error());
  }
  print OFILE "$otxt";

  $sh++;
}
close IFILE;
close OFILE;
$sh--; # Remove orig

print "\n** " . scalar(keys %seen_mk) . " Master Keys Found\n";
if (scalar(keys %seen_mk) > 0) {
  foreach my $col (@repl_colname) {
    my $k = (! exists $repl_count{$col}) ? 0 : $repl_count{$col};
    print "  - \'$col\' replaced $k times\n";
  }
}

print "\n** " . scalar(keys %unseen_mk) . " Master Keys NOT Found\n";

foreach my $mk (keys %seen_mk) {
  delete $replace{$mk};
}
print "\n** " . scalar(keys %replace) . " Master Keys from REPLACE not seen:" . join(" ", sort __num keys(%replace)) . "\n";

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
    return([@in]);
  }

  my @out = ();
  my $rc = 0;
  for (my $i = 0; $i < scalar @{$replace{$mk}}; $i++) {
    my %tmp_replace = %{${$replace{$mk}}[$i]};
    my @tmp = @in;
    foreach my $col (@repl_colname) {
      next if (! exists $colm{$col});
      my $cv = $tmp[$colm{$col}];
      my $rv = $tmp_replace{$col};
      next if ($cv eq $rv); # same values
      $tmp[$colm{$col}] = $tmp_replace{$col};
      $repl_count{$col}++;
    }
    push @out, [@tmp];
    $rc++;
  }
#  print("[***] " . Dumper(\@out) . "\n") if ($rc > 1);

  $seen_mk{$mk}++;
  delete $unseen_mk{$mk};

  return(@out);
}

##########

sub load_replace {
  my ($if, $rmk, $rra, $rrh) = @_;
  my %seen = ();

  open RIFILE, "<$if"
    or MMisc::error_quit("Problem opening Replacement input file ($if) : $!");

  my $ricsvh = new CSVHelper();

  my $sh = 1;
  my $rmc = "";
  my @col_name = ();
  while (my $line = <RIFILE>) {
    my @inh = $ricsvh->csvline2array($line);
    MMisc::error_quit("Problem with input CSV : " . $ricsvh->get_errormsg() . "\n[Line $sh : $line]")
        if ($ricsvh->error());
    
    if ($sh == 1) { # Header
      MMisc::error_quit("Need at least two columns in Replacement CSV file to work, found ". scalar @inh) if (scalar @inh < 2);
      
      $ricsvh->set_number_of_columns(scalar @inh);
      
      my %tmp = ();
      for (my $i = 0; $i < scalar @inh; $i++) {
        my $c = $inh[$i];
#        print "[$c] ";
        MMisc::error_name("Column name ($c) has to be unique and non empty")
            if ((MMisc::is_blank($c)) || (++$tmp{$c} > 1));
        if (exists $ocm{$c}) {
          print "  (seen $c column, renaming as " . $ocm{$c} . ")\n";
          $inh[$i] = $ocm{$c};
        }
      }
#      die();
      $rmc = $inh[0];
      MMisc::error_quit("Master key differs [$rmc] vs [$$rmk]")
          if ((! MMisc::is_blank($$rmk)) && ($rmc ne $$rmk));
      $$rmk = $rmc;

      @col_name = @inh[1..$#inh];
      foreach my $c (@col_name) {
        push(@{$rra}, $c) if (! grep(m%^$c$%, @{$rra}));
      }
      $sh++;
      next;
    }

    my $mk = shift @inh;
    if (exists $$rrh{$mk}) {
      MMisc::error_quit("Master Key is not unique ($mk)")
          if (! $dupl);
#      print("  -- FYI: Master Key not unique: $mk\n");
      $seen{$mk}++;
    }
    my %tmp = ();
    for (my $i = 0; $i < scalar @inh; $i++) {
      $tmp{$col_name[$i]} = $inh[$i];
    }
    push @{$$rrh{$mk}}, \%tmp;

    $sh++;
  }
  close RIFILE;

  my @keys = keys %seen;
  if (scalar @keys > 0) {
    print " -- FYI: The following Master Keys are not unique: ";
    foreach my $key (sort __num @keys) {
      print "$key (x" . (1 + $seen{$key}) . ") ";
    }
    print "\n";
  }

  return(1);;
}

## 

sub __num { $a <=> $b; }

####################

sub set_usage{
  my $tmp=<<EOF

$0 [--help] [--addColumns] [--Duplicates] [--warnColumns] [--otherColumnName infilename=outfilename] [--extraReplace replacefile.csv] infile.csv replacefile.csv outfile.csv

Replace columns from input file by columns from replacefile.
Match is done on the first column in replacefile considered the 'master key' (must be a primary key unless \'--Duplicates\' is used), and replaced column names have to match.

Where:
  --help        This help message
  --addColumns  If a column name in 'replacefile.csv' does not exist in 'infile.csv', it will be added to 'outfile.csv'
  --Duplicates  Allow duplicate master keys and will replace all instances found with all candidates
  --warnColumns If a column is in infile but not in outfile, warn instead of exiting with error
  --otherColumnName  Allow renaming of infile column's name to its corresponding value in outfile
  --extraReplace   Add extra replacement entries
EOF
;

  return($tmp);
}
