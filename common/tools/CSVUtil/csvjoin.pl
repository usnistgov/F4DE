#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# csvjoin
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "csvjoin.pl" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../../common/lib");
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
my $partofthistool = "It should have been part of this tools' files.";
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

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                   S              h j    o qrs         #

my $outcsv = "";
my @joincol = ();
my $replace = 0;
my $firstfilekeep = 0;
my $separator=",";
my $quote_char="\"";
my $stdinFiles = 0;

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'outcsv=s'  => \$outcsv,
   'joincol=s' => \@joincol,
   'replace'   => \$replace,
   'separator=s' => \$separator,
   'quote=s' => \$quote_char,
   'LimitKeysToFirstFile'    => \$firstfilekeep,
   'StdinFiles' => \$stdinFiles,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
if ($stdinFiles == 0){
  MMisc::ok_quit("Files must be specified via --StdinFiles or at the end of the command\n$usage\n")
	if ($stdinFiles == 0 && scalar @ARGV == 0);
  MMisc::error_quit("Need at least two \'infile.csv\'\n\n$usage") 
    if (scalar @ARGV < 2);
} else {
  ; ### No checks  
}
MMisc::error_quit("Need at least one \'joincol\'\n\n$usage")
  if (scalar @joincol < 1);
my %jch = (); foreach my $jc (@joincol) { $jch{$jc} = scalar(keys %jch); }
$separator = "\t" if ($separator eq "<TAB>");

my %all = ();
my %header = ();

if ($stdinFiles == 0){
  foreach my $if (@ARGV) {
    &load_file($if);
    $firstfilekeep++ if ($firstfilekeep > 0);
  } 
} else {
  while (<>){
  	chomp;
    &load_file($_);
    $firstfilekeep++ if ($firstfilekeep > 0);
  }
}
#print MMisc::get_sorted_MemDump(\%all);

&save_file($outcsv);

MMisc::ok_quit("Done");

##########

sub add2all {
  my ($rall, $rlh, $rcolm, $txt, $radd, $rremove, @jc) = @_;
  
  if (scalar @jc > 0) {
    my $k = shift @jc;
    my $v = $$rlh[$$rcolm{$k}];
    $txt .= "{\'$k\'=\'$v\'}";
    return() if (($firstfilekeep > 1) && (! MMisc::safe_exists($rall, $v)));
    &add2all(\%{$$rall{$v}}, $rlh, $rcolm, $txt, $radd, $rremove, @jc);
    return();
  }
  
  # scalar @jc = 0
  foreach my $k (keys %{$rcolm}) {
    next if (exists $jch{$k});
    next if (MMisc::safe_exists($rremove, $k));
    MMisc::error_quit("\$all$txt" . "{\'$k\'} already present, will not overwrite (unless \'--replace\' is selected)")
        if ((exists $$rall{$k}) && (! $replace));
    my $v = $$rlh[$$rcolm{$k}];
    $$rall{$k} = $v;
  }
  
  foreach my $k (keys %{$radd}) {
    print "[$k]\n";
    next if (exists $jch{$k});
    next if (MMisc::safe_exists($rremove, $k));
    MMisc::error_quit("\$all$txt" . "{\'$k\'} already present, will not overwrite (unless \'--replace\' is selected)")
        if ((exists $$rall{$k}) && (! $replace));
    my $v = $$radd{$k};
    $$rall{$k} = $v;
    print "[$txt]{$k} = $v\n";
  }
}

##

sub load_file {
  my ($xcsvfile) = @_;

  # extract all separators
  my @splits = split (m%(\:\:|\+\+)%, $xcsvfile);
  # file is always first
  my $if = shift @splits;
  my %toremove = ();
  my %toadd = ();
  while (scalar @splits > 0) {
    my $mode = shift @splits;
    my $content = shift @splits;
    MMisc::error_quit("Empty \'infile.csv\' operator value") 
        if (MMisc::is_blank($content));

    if ($mode eq '::') {
      $toremove{$content}++;
      next;
    }

    if ($mode eq '++') {
      my ($c, @rest) = split(m%\=%, $content);
      MMisc::error_quit("Problem with \'infile.csv\' \'++\' operator, must be of the form: colname=colvalue, got: $content")
          if (@rest != 1);
      my $v = $rest[0];
      $toadd{$c} = $v;
#      print "[$c]++[$v]\n";
      next;
    }

    MMisc::error_quit("Invalid \'infile.csv\' operator ($mode)");
  }

  my $err = MMisc::check_file_r($if);
  MMisc::error_quit("Problem with input file ($if) : $err")
      if (! MMisc::is_blank($err));

  open IFILE, "<$if"
    or MMisc::error_quit("Problem opening input file ($if) : $!");

  my $icsvh = new CSVHelper($quote_char, $separator);

  # load headers
  my $sh = 1;
  my $line = <IFILE>;
  my @lh = $icsvh->csvline2array($line);
  MMisc::error_quit("[File: $if] Problem with input CSV : " . $icsvh->get_errormsg() . "\n[Line $sh : $line]")
      if ($icsvh->error());

  # do column match
  my %colm = ();
  for (my $i = 0; $i < scalar @lh; $i++) {
    my $v = $lh[$i];
    MMisc::error_quit("In file ($if), column ($v) is present more than once")
        if (exists $colm{$v});
    $colm{$v} = $i;
  }

  # confirm the primary keys columns are here
  foreach my $col (@joincol) {
    MMisc::error_quit("In file ($if), can not find primary key column ($col)")
        if (! exists $colm{$col});
  }

  # Add new columns to %header
  for (my $i = 0; $i < scalar @lh; $i++) {
    my $v = $lh[$i];
    next if (exists $header{$v});
    next if ($toremove{$v});
    $header{$v} = scalar(keys %header);
  }
  foreach my $v (keys %toadd) {
    next if (exists $header{$v});
    next if ($toremove{$v});
    $header{$v} = scalar(keys %header);
  }

  # Let's process the file now
  $sh++;
  $icsvh->set_number_of_columns(scalar @lh);
  while (my $line = <IFILE>) {
    my @inh = $icsvh->csvline2array($line);
    MMisc::error_quit("In file ($if), problem with input CSV : " . $icsvh->get_errormsg() . "\n[Line $sh : $line]")
        if ($icsvh->error());

    &add2all(\%all, \@inh, \%colm, "", \%toadd, \%toremove, @joincol);

    $sh++;
  }
  close IFILE;
}

#####

sub __header_sort { $header{$a} <=> $header{$b}; }

##

sub get_todo_list {
  my ($rall, @jc) = @_;

  if (scalar @jc == 1) {
    my @tmp = ();
    foreach my $k (sort(keys %{$rall})) {
      push @tmp, [ $k ];
    }
    return(@tmp);
  }

  my @out = ();
  my $d = shift @jc;
#  print MMisc::get_sorted_MemDump($rall);

  foreach my $k (sort(keys %{$rall})) {
    my @tmp = &get_todo_list(\%{$$rall{$k}}, @jc);
    foreach my $a (@tmp) {
      push @out, [$k, @${a}];
    }
  }

  return(@out);
}

##

sub get_content {
  my ($rall, $c, @d) = @_;

  return($d[$jch{$c}])
    if (exists $jch{$c}); # ie: hash header tables are accessible directly from the hash flat index

  if (scalar @d == 0) {
    return("") if (! exists $$rall{$c});
    return($$rall{$c});
  }

  my $k = shift @d;
  return(&get_content(\%{$$rall{$k}}, $c, @d));
}
  

##

sub save_file {
  my ($of) = @_;

  my @hl = sort __header_sort keys %header;

  open OFILE, ">$of"
    or MMisc::error_quit("Problem opening output file ($of) : $!");
  
  my $ocsvh = new CSVHelper($quote_char, $separator);

  # Write header
  my $sh = 1;
  $ocsvh->set_number_of_columns(scalar @hl);
  my $line = $ocsvh->array2csvline(@hl);
  MMisc::error_quit("Problem with output CSV : " . $ocsvh->get_errormsg() . "\n[Line $sh : $line]")
      if ($ocsvh->error());

  print OFILE "$line\n";
  $sh++;

  # Get list of all primary keys to iterate on
  my @todo = &get_todo_list(\%all, @joincol);
  for (my $i = 0; $i < scalar @todo; $i++) {
    my @linec = ();
    for (my $j = 0; $j < scalar @hl; $j++) {
      push @linec, &get_content(\%all, $hl[$j], @{$todo[$i]});
    }

    my $line = $ocsvh->array2csvline(@linec);
    MMisc::error_quit("Problem with output CSV : " . $ocsvh->get_errormsg() . "\n[Line $sh : $line]")
        if ($ocsvh->error());
    
    print OFILE "$line\n";
    $sh++;
  }

  close OFILE;
}

####################

sub set_usage{
  my $tmp=<<EOF

$0 [--help] --outcsv filename [--joincol name [--joincol name [...]]] [--replace] [--LimitKeysToFirstFile] infile.csv[++colname=colvalue[++...]][::colname[::...]] [infile.csv[...] [...]]

Does a simple CSV join on primary key columns; and will add columns from all files seen
Warning: will stop in case of primary key collision unless --replace is selected

Where:
  --help        This help message
  --outcsv      filename to write the joined table to
  --joincol     primary key column name (used in in \'joincol\' order)
  --replace     In case of primary key collision, replace previous value
  --LimitKeysToFirstFile      If a key from the first file is not present in the following, remove that line from the output file
  --separator   Separator character for both input and output files, use <TAB> for tab separator
  --quote       Quote field character for both input and output files
  --StdinFiles  Read the infile.csv files from STDIN

Options can be specified for infile.csv:
  ++colname=colvalue will add extra columns to the loaded file
  ::colname  remove specified columns from loaded file

EOF
;

  return($tmp);
}
