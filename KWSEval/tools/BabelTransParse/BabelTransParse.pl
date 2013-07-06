#!/usr/bin/env perl -w
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# KWSEval
# 
# Original Authors: Jon Fiscus, Martial Michel

# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# KWSEval is an experimental system.  
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

### Die on any warning and give a stack trace
#use Carp qw(cluck);
#$SIG{__WARN__} = sub { cluck "Warning:\n", @_, "\n";  die; };

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1a";

if ($version =~ m/a$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "BabelTransParse Version: $version";

##########
# Check we have every module (perl wise)

my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "RTTMList", "KWSecf", "TermList") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long", "Data::Dumper") {
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

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

my $verbose = 0;
my $encoding = "ASCII";
my $root = undef;
my $lang = undef;
my $norm = "";
my $fileOfTF = "";
my $transPath = ".";

GetOptions
( 
 'language=s'                          => \$lang,
 'root=s'                              => \$root,
 'file-of-transfiles=s'                => \$fileOfTF,
 'trans-path=s'                        => \$transPath,
 'encoding=s'                          => \$encoding,
 'compareNormalize=s'                  => \$norm,
 'Verbose'                             => \$verbose,
 'version'                             => sub { MMisc::ok_quit($versionid); },
 'help'                                => sub { MMisc::ok_quit($usage); },
) or MMisc::error_quit("Unknown option(s)\n\n$usage\n");

### Check the encoding parameter
MMisc::error_quit("Character encoding /$encoding/ must be either [ASCII|UTF-8]") 
  if( $encoding !~ /^(ASCII|UTF-8)$/ );
MMisc::error_quit("Root name required\n") if(! defined($root));
MMisc::error_quit("Language required\n") if(! defined($lang));

my $db = ();

my $totalDuration = 0;
my @tfiles = @ARGV;
$transPath .= "/" if ($transPath =~ m:^[^/]+$:);
if ($fileOfTF ne "") {
  open (FILEOFTF, $fileOfTF) or MMisc::error_quit("Cannot open file '$fileOfTF'.");
  while (<FILEOFTF>) {
    s/^\s+//;
    s/\s+$//;
    $_ .= ".txt" if ($_ !~ m:.txt$:i);
    push (@tfiles, $transPath . $_)
  }
  close FILEOFTF;
}
print "Processing Babel files\n";
foreach my $trans(@tfiles){
#  print "   $trans\n";
  my ($trans_bt, $trans_et) = (999999999, -1);
  ### Extract meaning from the name
  if ($trans =~ /(BABEL_(BP|OPT)_(\d{3})_(\d{5})_(\d{8})_(\d{6})_(inLine|outLine).txt)/){
    $db->{$trans}{PERIOD} = $2;
    $db->{$trans}{LANG} = $3;
    $db->{$trans}{SID} = $4;
    $db->{$trans}{DATE} = $5;
    $db->{$trans}{LINE} = $7;
  } elsif ($trans =~ /(BABEL_(BP|OPT)_(\d{3})_(\d{5})_(\d{8})_(\d{6})_([a-zA-Z\d]{2})_scripted.txt)/) {
    $db->{$trans}{PERIOD} = $2;
    $db->{$trans}{LANG} = $3;
    $db->{$trans}{SID} = $4;
    $db->{$trans}{DATE} = $5;
    $db->{$trans}{PROMPTID} = $7;
  }

  ### open the file
  if ($encoding eq "ASCII"){
    open (TRANS, "$trans") || MMisc::error_quit("Failed to open ASCII mode file $trans");
  } elsif ($encoding eq "UTF-8"){
    open (TRANS, "<:encoding(UTF-8)", "$trans") || MMisc::error_quit("Failed to open UTF-8 mode file $trans");
    binmode STDOUT, "utf8";
  }
  my $lastTime = undef;
  my $thisTime = undef;
  my $text = undef;
  my $lastWasTime = 0;

  while (<TRANS>){
    chomp;
    if ($_ =~ /^\[(\d+\.\d+)]$/){
      $thisTime = $1;
      if ($lastWasTime){
        print "Warning: Consecutive times for $trans found at $lastTime and $thisTime.  Inserting <no-speech>\n";
        MMisc::error_quit("Internal error: \$text defined when it should not be for consecutive times") if (defined($text));
        $text = "<no-speech>";
      }
      
      if (defined($text)){  ### I have transcript data so flush it
        push @{ $db->{$trans}{transcript} }, {bt=>$lastTime, et=>$thisTime, text=>$text};
        $text = undef;
      }
      $trans_bt = $thisTime if ($trans_bt > $thisTime);
      $trans_et = $thisTime if ($trans_et < $thisTime);
      $lastWasTime = 1;
    } else { 
      $text = $_;
      $lastWasTime = 0;
    }

    $lastTime = $thisTime;
  }
  $db->{$trans}{bt} = $trans_bt;
  $db->{$trans}{et} = $trans_et;
  $totalDuration += $trans_et - $trans_bt;
  close TRANS;
#  MMisc::error_quit("End of file with a non-used transcript line") if (defined($text));
  print("End of file with a non-used transcript line\n") if (defined($text));
}
#print Dumper($db);

### 
my $unigram = ();
my $bigram = ();
my $trigram = ();
open (ECF, ">$root.ecf.xml") || die "Failed to open $root.ecf.xml";
print "   Building file $root.ecf.xml\n";

open (RTTM, ">$root.rttm") || die "Failed to open $root.rttm";
binmode(RTTM, "utf8") if ($encoding eq "UTF-8");
print "   Building file $root.rttm\n";

open (SYSRTTM, ">$root.sys.rttm") || die "Failed to open $root.sys.rttm";
binmode(SYSRTTM, "utf8") if ($encoding eq "UTF-8");
print "   Building file $root.sys.rttm\n";

open (STM, ">$root.stm") || die "Failed to open $root.stm";
binmode(STM, "utf8") if ($encoding eq "UTF-8");
print "   Building file $root.stm\n";

open (TLIST, ">$root.kwlist.xml") || die "Failed to open $root.kwlist.xml";
binmode TLIST, "utf8" if ($encoding eq "UTF-8");
print "   Building file $root.kwlist.xml\n";

print ECF "<ecf source_signal_duration=\"$totalDuration\" language=\"$lang\" version=\"ECF Built by BabelTransParse.pl\">\n";
foreach my $trans(sort {$db->{$a}{SID}<=>$db->{$b}{SID}} keys %$db){
#  print Dumper($db->{$trans});
#  die;
  my $outTransName = $trans;
  $outTransName =~ s:.*/::;
  $outTransName =~ s:\.[^.]*$::;
  print ECF "  <excerpt audio_filename=\"$outTransName\" ".
    "channel=\"1\" ".
    "tbeg=\"".sprintf("%.3f",$db->{$trans}{bt})."\" ".
    "dur=\"".sprintf("%.3f",$db->{$trans}{et})."\" ".
    "source_type=\"splitcts\"/>\n";
  ### Interate over the segments
  my $spkr = 1;
  for (my $seg=0; $seg < @{ $db->{$trans}{transcript} }; $seg++){
#    print "$seg $db->{$trans}{transcript}[$seg]{bt} $db->{$trans}{transcript}[$seg]{et}\n";
    my $dur = sprintf("%.3f",($db->{$trans}{transcript}[$seg]{et} - $db->{$trans}{transcript}[$seg]{bt}));
    my $bt = sprintf("%.3f",$db->{$trans}{transcript}[$seg]{bt});
    my $et = sprintf("%.3f",$db->{$trans}{transcript}[$seg]{et});
    print RTTM "SPEAKER $outTransName 1 $bt $dur <NA> <NA> spkr1 <NA>\n";
    print SYSRTTM "SPEAKER $outTransName 1 $bt $dur <NA> <NA> spkr1 <NA>\n";
    my @toks = split(/\s+/,$db->{$trans}{transcript}[$seg]{text});
    my $lastToken = undef;
    my $lastLastToken = undef;
    my $stmText = "";
    my $subToken = "";
    my $lexCount = 0;
    my $punct = '[\`\~\!\@\#\$\%\^\&\*\(\)\-\_\+\=\[\]\{\}\|\\\<\>\,\.\/\?]';
    my $notpunct = '[^\`\~\!\@\#\$\%\^\&\*\(\)\-\_\+\=\[\]\{\}\|\\\<\>\,\.\/\?]';
    my $wrd = '[^\`\~\!\@\#\$\%\^\&\*\(\)\-\_\+\=\[\]\{\}\|\\\<\>\,\.\/\?]+([_-][^\`\~\!\@\#\$\%\^\&\*\(\)\-\_\+\=\[\]\{\}\|\\\<\>\,\.\/\?]+)*';
    my $isNoScoreKWS = 0;
    my $isNoScoreSTT = 0;
    print "Warning: No tokens $outTransName $bt\n" if (@toks == 0);
    my $tokBt = $bt;
    for (my $t = 0; $t < @toks; $t++){
      my $token = $toks[$t];
      my($type,$stype) = ("LEXEME", "lex");
      if ($token eq "<hes>"){          $stype = "fp"; }
      elsif ($token eq "(())"){        $stype = "un-lex";    $isNoScoreSTT = 1; }
      elsif ($token eq "<foreign>"){   $stype = "for-lex";   }
      elsif ($token eq "<female-to-male>"){   $type = "skip"; $spkr ++; }
      elsif ($token eq "<male-to-female>"){   $type = "skip"; $spkr ++; }
      elsif ($token eq "<breath>"){    $type = "NON-LEX";    $stype = "breath"; }
      elsif ($token eq "<cough>"){     $type = "NON-LEX";    $stype = "cough"; }
      elsif ($token eq "<lipsmack>"){  $type = "NON-LEX";    $stype = "lipsmack"; }
      elsif ($token eq "<no-speech>"){ $type = "NON-LEX";    $stype = "other"; }
      elsif ($token eq "<laugh>"){     $type = "NON-LEX";    $stype = "laugh"; }
      elsif ($token eq "<dtmf>"){      $type = "NON-SPEECH"; $stype = "noise"; }
      elsif ($token eq "<ring>"){      $type = "NON-SPEECH"; $stype = "noise"; }
      elsif ($token eq "<click>"){     $type = "NON-SPEECH"; $stype = "noise"; }
      elsif ($token eq "<ring>"){      $type = "NON-SPEECH"; $stype = "noise"; }
      elsif ($token eq "<sta>"){       $type = "NON-SPEECH"; $stype = "noise"; }
      elsif ($token eq "<int>"){       $type = "NON-SPEECH"; $stype = "noise"; }
      elsif ($token eq "<prompt>"){    $type = "NON-SPEECH"; $stype = "other"; $isNoScoreSTT = 1; $isNoScoreKWS = 1; }
      elsif ($token eq "<overlap>"){   $type = "NON-SPEECH"; $stype = "other"; $isNoScoreSTT = 1; $isNoScoreKWS = 1; }
      elsif ($token =~ /^\*(${wrd})\*$/){   $token = $1;                 }  ## Mispronounced
      elsif ($token =~ /^\*(${wrd}-)\*$/){  $token = $1;     $stype = "frag";            }  ## Mispronounced fragment
      elsif ($token =~ /^(${wrd}-)$/){                       $stype = "frag";             }  ## Fragments
      elsif ($token =~ /^(-${wrd})$/){                       $stype = "frag";             }  ## Fragments
#      elsif ($token =~ /^(${notpunct}+(_${notpunct}+)+)$/){      $stype = "frag";  }  ## Acronyms
      elsif ($token =~ /^\~$/){        $type = "NON-SPEECH"; $stype = "other"  }  ## truncations
      elsif ($token =~ /^$wrd$/){    ;                                       } ## Do nothing
      else {
        print "Illegal Token $token in $outTransName\n";
      }
      next if ($type eq "skip");
      $dur = sprintf("%.3f",($db->{$trans}{transcript}[$seg]{et} - $db->{$trans}{transcript}[$seg]{bt}) / (@toks + 1));
      $tokBt = sprintf("%.3f",$db->{$trans}{transcript}[$seg]{bt} + ($dur * $t));
 
      print RTTM "$type $outTransName 1 $tokBt $dur $token $stype spkr1 0.5\n";
      $lexCount ++ if ($type eq "LEXEME" && $stype eq "lex");
      if (($lexCount + 3) % 10 == 0){
        ##  Don't make an output unless it's the 3rd word (+10). IE, 10% del
        ;
      } elsif (($lexCount + 5) % 10 == 0){
        ##  make an output a sub on the 5th word (+10). IE, 10% sub
        print SYSRTTM "$type $outTransName 1 $tokBt $dur $token$token $stype spkr1 0.5\n" ;
      } elsif (($lexCount + 8) % 10 == 0){
        ##  make an output an ins on the 8th word (+10). IE, 10% ins
        my $dur2 = sprintf("%.3f",($db->{$trans}{transcript}[$seg]{et} - $db->{$trans}{transcript}[$seg]{bt}) / (@toks + 1) / 2.0);
        my $btdur2 = sprintf("%.3f",$db->{$trans}{transcript}[$seg]{bt} + ($dur * $t) + $dur2);
        print SYSRTTM "$type $outTransName 1 $tokBt $dur2 $token $stype spkr1 0.5\n"; 
        print SYSRTTM "$type $outTransName 1 $btdur2 $dur2 $token$token $stype spkr1 0.5\n";
      } else {
        print SYSRTTM "$type $outTransName 1 $tokBt $dur $token $stype spkr1 0.5\n" ;
      }

      ### Build the reference STM for STT scoring
      if ($type eq "LEXEME"){
        my $isOptDel = ($stype eq "fp" || $stype eq "frag" || $stype eq "for-lex");
        $stmText .= " ".($isOptDel ? "(".$token.")" : $token) 
      }
      
      if ($stype eq "lex"){
        $unigram->{$token} ++;
      }
      if ($stype eq "lex" && defined($lastToken)){
        $bigram->{$lastToken." ".$token} ++;
      }
      if ($stype eq "lex" && defined($lastToken) && defined($lastLastToken)){
        $trigram->{$lastLastToken." ".$lastToken." ".$token} ++;
      }
      $lastLastToken = ($stype eq "lex" ? $lastToken : undef);
      $lastToken = ($stype eq "lex" ? $token : undef);
    }
    if ($isNoScoreKWS){
      print RTTM "NOSCORE $outTransName 1 $bt $dur <NA> <NA> <NA> <NA>\n";
    }
    if ($isNoScoreSTT){
      print STM ";;$outTransName 1 Aggregated $bt $et $stmText\n";
      print STM "$outTransName 1 Aggregated $bt $et IGNORE_TIME_SEGMENT_IN_SCORING\n";
    } else {
      print STM "$outTransName 1 Aggregated $bt $et $stmText\n";
    }
  }
}

print TLIST "<kwlist ecf_filename=\"$root.kwlist.xml\" version=\"20060511-0900\" language=\"$lang\" encoding=\"$encoding\" compareNormalize=\"$norm\">\n";

my @sortedunigrams = sort { $unigram->{$b} <=> $unigram->{$a} } keys %$unigram;
print "Using 10 unigrams for terms\n";
for (my $i=0; $i<10; $i++){
#  print "$i $unigram->{$sortedunigrams[$i]}\n";
  print TLIST "<kw kwid=\"TEST-".sprintf("%02d",$i)."\"><kwtext>$sortedunigrams[$i]</kwtext></kw>\n";
}

my @sortedBigrams = sort { $bigram->{$b} <=> $bigram->{$a} } keys %$bigram;
print "Using 10 bigrams for terms\n";
for (my $i=0; $i<10; $i++){
#  print "$i $bigram->{$sortedBigrams[$i]}\n";
  print TLIST "<kw kwid=\"TEST-".sprintf("%02d",$i+10)."\"><kwtext>$sortedBigrams[$i]</kwtext></kw>\n";
}

my @sortedtrigrams = sort { $trigram->{$b} <=> $trigram->{$a} } keys %$trigram;
print "Using 10 trigrams for terms\n";
for (my $i=0; $i<10; $i++){
#  print "$i $trigram->{$sortedtrigrams[$i]}\n";
  print TLIST "<kw kwid=\"TEST-".sprintf("%02d",$i+20)."\"><kwtext>$sortedtrigrams[$i]</kwtext></kw>\n";
}

print TLIST "</kwlist>\n";

#<?xml version="1.0" encoding="UTF-8"?>
#<termlist ecf_filename="expt_06_std_eval06_eng_all_spch_expt_1.ecf.xml" language="english" version="20061103-0942">
#<term termid="Eval06_eng_0001">
#  <termtext>know</termtext>
#  <terminfo>
#  </terminfo>
#<termlist>


print ECF "</ecf>\n";

close ECF;
close RTTM;
close SYSRTTM;
close STM;
close TLIST;



sub set_usage {
  my $tmp = "";

	$tmp .= "BabelTransParse.pl [ OPTIONS ] files...\n";
	$tmp .= "\n";
	$tmp .= "\n";

  return($tmp);
}

