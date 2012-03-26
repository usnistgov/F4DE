#!/usr/bin/env perl

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 Global CSV to individual CSV files
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Global CSV to individual CSV files" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08 Global CSV to individual CSV files Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../lib", "$f4d/../../../common/lib");
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

my @ok_dec = ("keep", "reject"); # order is important
my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Default values for variables
my $odir = "";
my $select = "";
my $roe = 1;
my $dktrue = 0;
my $verb = 0;
my @qsl = ();
my $qsfile = "";
my $qsa_more = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used: Q  D            Q            d fgh      o   s  v x   #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'outdir=s' => \$odir,
   'select=s'   => \$select,
   'duplicates_warn'  => sub { $roe = 0; },
   'Duplicate_keepTrue' => \$dktrue,
   'Verb'     => \$verb,
   'quick_select=s' => \@qsl,
   'QS_Analyze=s' => \$qsfile,
   'AnalyzeMore' => \$qsa_more,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Need 1 file argument to work\n$usage\n") 
  if (scalar @ARGV != 1);

if (! MMisc::is_blank($odir)) {
  # Check the directory
  my ($err) = MMisc::check_dir_w($odir);
  MMisc::error_quit("Provided \'outdir\' option directory ($odir): $err")
    if (! MMisc::is_blank($err));
  $odir .= "/" if ($odir !~ m%\/$%); # Add a trailing slash
}

if (! MMisc::is_blank($select)) {
  my ($err) = MMisc::check_file_x($select);
  MMisc::error_quit("Provided \'select\' tool ($select): $err")
    if (! MMisc::is_blank($err));
}

my $in = shift @ARGV;
my $err = MMisc::check_file_r($in);
MMisc::error_quit("Problem with input file ($in): $err")
  if (! MMisc::is_blank($err));
my %qs_all = ();
my %all = &load_globalCSV($in);
#debug#MMisc::ok_quit(MMisc::writeTo("test", ".md", 1, 0, MMisc::get_sorted_MemDump(\%all)));
&write_sffnCSV(%all);
&write_qsCSV($qsfile, %qs_all) if (! MMisc::is_blank($qsfile));

MMisc::ok_quit("Done\n");

########## END

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

##########

sub find_pos {
  my $rwant = shift @_;
  my @header = @_;
  my @want = @$rwant;

  my @f = ();
  foreach my $k (@want) {
    my $found = 0;
    for (my $i = 0; $i < scalar @header; $i++) {
      next if ($found);
      if ($header[$i] eq $k) {
        push @f, $i;
        $found = 1;
      }
    }
    MMisc::error_quit("Could not find [$k] in header")
        if (! $found);
  }

  return(@f);
}

##########


sub load_globalCSV {
  my ($in) = @_;

  open FILE, "<$in"
    or MMisc::error_quit("Could not open IN file ($in): $!\n");
  
  # Get CSV Handler
  my $csvh = new CSVHelper();
  MMisc::error_quit("Could not create valid CSVHelper")
      if (! defined $csvh);
  
  # Get header
  my $line = <FILE>;
  
  my @header = $csvh->csvline2array($line);
  MMisc::error_quit("Problem with CSV header: " . $csvh->get_errormsg())
      if ($csvh->error());
  MMisc::error_quit("Problem with header (no element)")
      if (scalar @header == 0);
  $csvh->set_number_of_columns(scalar @header);
  
  my @want = ("File","Event","Framespan","isGood", "AnnotList"); # Order is important
  my @pos = &find_pos(\@want, @header);
  
  my %all = ();
  my $linec = 1;
  while (my $line = <FILE>) {
    $linec++;
    next if (MMisc::is_blank($line));
    
    my @lcont = $csvh->csvline2array($line);
    MMisc::error_quit("[line #$linec] Problem with CSV line: " . $csvh->get_errormsg())
        if ($csvh->error());

    my ($mcttr, $evt, $ffs, $igv, $antl) = 
      ($lcont[$pos[0]], $lcont[$pos[1]], $lcont[$pos[2]],
       $lcont[$pos[3]], $lcont[$pos[4]]);
  
    my $tmp_antl = $antl;
    $tmp_antl =~ s%\(.+?\)%%g;
    print "** [line $linec] Seen: $mcttr / $evt / $ffs / $igv / $tmp_antl\n";

    ## duplicate
    if (MMisc::safe_exists(\%all, $mcttr, $evt, $ffs)) {  
      my $tmp_txt = sprintf("[line #$linec] Already have a value for this %s / %s / %s ( %s / %s / %s)", $want[0], $want[1], $want[2], $mcttr, $evt, $ffs);
      MMisc::error_quit($tmp_txt) if ($roe);

      if (! $dktrue) {
        print "$tmp_txt => skipping\n";
        next;
      }

      my $ov = $all{$mcttr}{$evt}{$ffs};

      if (! $igv) {
        print "$tmp_txt => With \"false\" isGood, skipping\n";
        next;
      }

      print "$tmp_txt => new entry with \"true\" isGood, keeping\n";
    }

    ## quick select
    my %qs_keep = ();
    my %qs_keep_more = ();
    if (scalar @qsl > 0) {
      my $keep = 0;
      for (my $i = 0; (($i < scalar @qsl) && ($keep <= 0)); $i++) {
        my $qs = $qsl[$i];
        if ($antl =~ m%$qs%) {
          $keep = (MMisc::is_blank($qsfile)) ? 1 : -1;
          $qs_keep{$qs}++;
          if ($qsa_more) {
            MMisc::error_quit("Can not extract extra information for [$qs] from [$antl]")
                if (! ($antl =~ m%$qs\(\d+\|([\d\:\s]+?)\)%));
            $qs_keep_more{$qs} = $1;
          }
        }
      }
      if ($keep == 0) {
        print "  -- quick select rejection\n";
        next;
      }
    }
    
    ## select
    if (! MMisc::is_blank($select)) {
      my $cmdline = "$select \"$antl\"";
      my ($rc, $so, $se) = MMisc::do_system_call($cmdline);
      MMisc::error_quit("[line #$linec] Problem calling \'select\' ($cmdline)\n** Stdout: $so\n\n** Stderr: $se\n") if ($rc != 0);
      $so =~ s%^(\w+)%%;
      my $eok = "ok";
      my $ok = $1;
      MMisc::error_quit("[line #$linec] Did not receive the expected \"$ok\" value (\"$ok\" instead)")
          if ($eok ne $ok);
      my $decision = MMisc::clean_begend_spaces($so);
      MMisc::error_quit("[line #$linec] Empty decision")
          if (MMisc::is_blank($decision));
      MMisc::error_quit("[line #$linec] Unknown \'select\' decision ($decision), expecting one of: " . join(" ", @ok_dec))
          if (! grep(m%^$decision$%, @ok_dec));
      
      # Reject: do not add entry to processed list
      if ($decision eq $ok_dec[-1]) {
        print "  -- Rejected\n" if ($verb);
        next;
      }
    }
    
    $all{$mcttr}{$evt}{$ffs} = $igv;
#debug#print  MMisc::get_sorted_MemDump(\%all), "\n";
    ## Quick Select
    for (my $qs_i = 0; $qs_i < scalar @qsl; $qs_i++) {
      if (MMisc::safe_exists(\%qs_all, $mcttr, $evt, $ffs, $qsl[$qs_i])) {
        delete $qs_all{$mcttr}{$evt}{$ffs}{$qsl[$qs_i]};
      }
    }
    foreach my $qs_v (keys %qs_keep) {
      $qs_all{$mcttr}{$evt}{$ffs}{$qs_v} = [$igv, ($qsa_more) ? $qs_keep_more{$qs_v}: ""];
    }

    print "  -> Added\n";
  }

  return(%all);
}

##########

sub _die_mkdir {
  my ($dir) = @_;

  MMisc::error_quit("Could not create directory: $dir")
      if (! MMisc::make_dir($dir));
}

#####

sub fs_begend {
  my ($tfs) = @_;

  return("", "") if (MMisc::is_blank($tfs));
  
  MMisc::error_quit("Could not extract beg from framespan ($tfs)")
      if (! ($tfs =~ m%^(\d+)\:%));
  my $beg = $1;
  
  MMisc::error_quit("Could not extract end from framespan ($tfs)")
      if (! ($tfs =~ m%\:(\d+)$%));
  my $end = $1;

  return($beg, $end);
}

##

sub write_qsCSV {
  my ($ofile, %tmp_all) = @_;

  # Get CSV Handler
  my $csvh = new CSVHelper();
  MMisc::error_quit("Could not create valid CSVHelper")
      if (! defined $csvh);

  my @header = ("XMLFile", "EventType", "Framespan");
  push(@header, ("BegFrame", "EndFrame")) if ($qsa_more);
  push @header, ("isGood");
  for (my $i = 0; $i < scalar @qsl; $i++) {
    my $n = $qsl[$i];
    push @header, $n;
    push(@header, ("$n Framespan", "$n BegFrame", "$n EndFrame")) if ($qsa_more);
  }
  my $fh = $csvh->array2csvline(@header);
  MMisc::error_quit("Problem with CSV header: " . $csvh->get_errormsg())
      if ($csvh->error());
  $csvh->set_number_of_columns(scalar @header);

  my $all_txt = "";
  foreach my $xf (sort keys %tmp_all) {
    foreach my $evt (sort keys %{$tmp_all{$xf}}) {
      foreach my $fs (sort keys %{$tmp_all{$xf}{$evt}}) {
        my $igv = undef;
        my @tmpa = ();
        for (my $qs_i = 0; $qs_i < scalar @qsl; $qs_i++) {
          my $qs_v = 0;
          my $tfs = "";
          if (MMisc::safe_exists(\%qs_all, $xf, $evt, $fs, $qsl[$qs_i])) {
            ($igv, $tfs) = @{$qs_all{$xf}{$evt}{$fs}{$qsl[$qs_i]}};
            $qs_v = 1;
          }
          push @tmpa, $qs_v;
          push(@tmpa, ($tfs, &fs_begend($tfs))) if ($qsa_more);
        }

        my @line = ($xf, $evt, $fs);
        push(@line, (&fs_begend($fs))) if ($qsa_more);
        push @line, ($igv, @tmpa);
        
        my $fl = $csvh->array2csvline(@line);
        MMic::error_quit("Problem generating file line: " . $csvh->get_errormsg())
            if ($csvh->error());

        $all_txt .= "$fl\n";
      }
    }
  }

  if (MMisc::is_blank($all_txt)) {
    print "[**] Nothing to write for \'$ofile\'\n";
    return();
  }
    
  MMisc::error_quit("Problem writing file ($ofile)")
      if (! MMisc::writeTo($ofile, "", 1, 0, "$fh\n$all_txt"));
}

#####

sub write_sffnCSV {
  my %all = @_;

  # Get CSV Handler
  my $csvh = new CSVHelper();
  MMisc::error_quit("Could not create valid CSVHelper")
      if (! defined $csvh);

  my @sffn_header = ("EventType", "Framespan");
  my $fh = $csvh->array2csvline(@sffn_header);
  MMisc::error_quit("Problem with CSV header: " . $csvh->get_errormsg())
      if ($csvh->error());
  $csvh->set_number_of_columns(scalar @sffn_header);

  my $all_dir = "${odir}00-All_isGood";
  &_die_mkdir($all_dir);
  my $yes_dir = "${odir}01-Yes_isGood";
  &_die_mkdir($yes_dir);
  my $no_dir  = "${odir}02-No_isGood";
  &_die_mkdir($no_dir);
  
  foreach my $sffn (sort keys %all) {
    print "** SFFN : $sffn\n";
 
    my $all_txt = "$fh\n";
    my $yes_txt = "$fh\n";
    my $no_txt  = "$fh\n";
    
    my ($ac, $yc, $nc) = (0, 0, 0);
    
    foreach my $event (sort keys %{$all{$sffn}}) {
      my $allc = 0;
      my $yesc = 0;
      my $noc = 0;
    
      foreach my $fs (keys %{$all{$sffn}{$event}}) {
        my $v = $all{$sffn}{$event}{$fs};

        my $fl = $csvh->array2csvline($event, $fs);
        MMic::error_quit("Problem generating file line: " . $csvh->get_errormsg())
            if ($csvh->error());

        $all_txt .= "$fl\n";
        $allc++;

        if ($v) {
          $yes_txt .= "$fl\n";
          $yesc++;
        } else {
          $no_txt .= "$fl\n";
          $noc++;
        }
      }
 
      $ac += $allc;
      $yc += $yesc;
      $nc += $noc;

      MMisc::error_quit("YES + NO != ALL ($yesc + $noc != $allc)")
          if ($yesc + $noc != $allc);
      print sprintf(" |-> Event: %20s [ALL: %02d = %02d YES + %02d NO]\n", $event, $allc, $yesc, $noc);
    }

    if ($ac > 0) {
      my $all_file = "$all_dir/$sffn.csv";
      MMisc::error_quit("Problem writing file ($all_file)")
          if (! MMisc::writeTo($all_file, "", 1, 0, $all_txt));
    } else {
      print "[$sffn] 0 events, skipping file writing\n";
    }

    if ($yc > 0) {
      my $yes_file = "$yes_dir/$sffn.csv";
      MMisc::error_quit("Problem writing file ($yes_file)")
          if (! MMisc::writeTo($yes_file, "", 1, 0, $yes_txt));
    } else {
      print "[$sffn] 0 \"YES\" events, skipping file writing\n";
    }

    if ($nc > 0) {
      my $no_file = "$no_dir/$sffn.csv";
      MMisc::error_quit("Problem writing file ($no_file)")
          if (! MMisc::writeTo($no_file, "", 1, 0, $no_txt));
    } else {
      print "[$sffn] 0 \"NO\" events, skipping file writing\n";
    }

 }

}

############################################################

sub set_usage {
  my $dok = join(" ", @ok_dec);
  my $tmp=<<EOF
$versionid

Usage: $0 [options] global.csv 

Will extract data content from a "global.csv" file into sffn.csv files needed to reinject adjudicated files into XML files.

FYI: In order, the program does (if selected): duplicate check, then quick select check, then select check.

 Where:
  --help              Print this usage information and exit
  --version           Print version number and exit
  --outdir dir           Specify the output directory
  --quick_select text    When checking the "AnnotList" if the text enter is seen, keep the entry. Multiple quick_select can be used, it will work as an "OR".
  --select program           Program called to with the "AnnotList" column from the global.csv file, to "select" if the line should be kept or rejected from the output (expected to return two parameters; "ok" followed by one of: $dok)
  --duplicates_warn   When finding duplicate keys, do not exit with error status, simply discard found duplicates
  --Duplicate_keepTrue  When finding duplicate keys, do not discard isGood=true entry, replace isGood=false ones
EOF
    ;

    return $tmp;
}
