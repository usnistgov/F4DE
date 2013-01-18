#!/usr/bin/env perl

# BABEL_Scorer
# Author: Jon Fiscus
# Preliminary: Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# BABEL_Scorer is an experimental system.  
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
# Version

# $Id$
my $version     = "0.2b";
if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^0-9\.]//g;
  $version = "$version (CVS: $cvs_version)";
}
my $versionid = "BABEL_Scorer Version: $version";

##########
# Check we have every module (perl wise)

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
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "KWSEval_SCHelper") {
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

####################
# Options processing

my $ecf_ext = '.ecf.xml';
my $tlist_ext = '.kwlist.xml';

my $rttm_ext = ".rttm";

my $kwslist_ext = ".kwslist.xml";

my $kwseval = (exists $ENV{$f4b})
  ? $ENV{$f4b} . "/bin/KWSEval"
  : dirname(abs_path($0)) . "/../../tools/KWSEval/KWSEval.pl";

my $detutil = (exists $ENV{$f4b})
  ? $ENV{$f4b} . "/bin/DETUtil"
  : dirname(abs_path($0)) . "/../../../common/tools/DETUtil/DETUtil.pl";

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

my $expid = "";
my $sysfile = "";
my $scrdir = "";
my $resdir = "";
my @dbDir = ();
my $specfile = "";
my @donefile = ();
my $verb = 0;
my $ProcGraph = undef;
my $sha256 = "";
my $sctkbindir = "";
my $sysdesc = "";
my $eteam = undef;
my $bypassxmllint = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:    DE  H  K    P  ST V X    cdef h         rst v     #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'Verbose'    => \$verb,
   'expid=s'    => \$expid,
   'sysfile=s'  => \$sysfile,
   'compdir=s'  => \$scrdir,
   'resdir=s'   => \$resdir,
   'dbDir=s'    => \@dbDir,
   'Specfile=s' => \$specfile,
   'fileCreate=s' => \@donefile,
   'KWSEval=s'  => \$kwseval,
   'DETUtil=s'  => \$detutil,
   'ProcGraph=s'  => \$ProcGraph,
   'Hsha256id=s' => \$sha256,
   'Tsctkbin=s' => \$sctkbindir,
   'tSystemDescription=s' => \$sysdesc,
   'ExpectedTeamName=s' => \$eteam,
   'XmllintBypass' => \$bypassxmllint,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("\'expid\' required\n\n$usage")
  if (MMisc::is_blank($expid));
MMisc::error_quit("\'sysfile\' required\n\n$usage")
  if (MMisc::is_blank($sysfile));
MMisc::error_quit("\'scrdir\' required\n\n$usage")
  if (MMisc::is_blank($scrdir));
MMisc::error_quit("\'resdir\' required\n\n$usage")
  if (MMisc::is_blank($resdir));
MMisc::error_quit("No \'dbDir\' specified, aborting")
  if (scalar @dbDir == 0);
my $tmp = scalar @dbDir;
for (my $i = 0; $i < $tmp; $i++) {
  my $v = shift @dbDir;
  push @dbDir, split(m%\:%, $v);
}

my $err = MMisc::check_file_r($sysfile);
MMisc::error_quit("Problem with \'sysfile\' file ($sysfile): $err")
  if (! MMisc::is_blank($err));
$err = MMisc::check_dir_w($scrdir);
MMisc::error_quit("Problem with \'scrdir\' file ($scrdir): $err")
  if (! MMisc::is_blank($err));
$err = MMisc::check_dir_w($resdir);
MMisc::error_quit("Problem with \'resdir\' file ($resdir): $err")
  if (! MMisc::is_blank($err));
$err = MMisc::check_file_x($kwseval);
MMisc::error_quit("Problem with \'kwseval\' tool ($kwseval): $err")
  if (! MMisc::is_blank($err));
$err = MMisc::check_file_x($detutil);
MMisc::error_quit("Problem with \'detutil\' tool ($detutil): $err")
  if (! MMisc::is_blank($err));

$ENV{PATH} .= ":".$sctkbindir if (! MMisc::is_blank($sctkbindir));
my $sclite = "sclite";
my $hubscore = "hubscr.pl";
my $csrfilt = "csrfilt.sh";

my $tmp = scalar @donefile;
for (my $i = 0; $i < $tmp; $i++) {
  my $v = shift @donefile;
  push @donefile, split(m%\:%, $v);
}

## Find 
my %ecfs = ();
my %tlists = ();
my %rttms = ();
for (my $i = 0; $i < scalar @dbDir; $i++) {
  $err = MMisc::check_dir_r($dbDir[$i]);
  MMisc::error_quit("Problem with \'dbDir\' (" . $dbDir[$i] . ") : $err")
    if (! MMisc::is_blank($err));
  &obtain_ecf_tlist($dbDir[$i], \%ecfs, \%tlists, \%rttms);
}
MMisc::error_quit("Did not find any ECF or TLIST files; will not be able to continue")
  if ((scalar (keys %ecfs) == 0) || (scalar (keys %tlists) == 0));
&check_ecf_tlist_pairs(\%ecfs, \%tlists, \%rttms);

########################################

my $kwsyear = KWSEval_SCHelper::loadSpecfile($specfile);

my ($lerr, $ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $ltrncond, $lsysid, $lversion, $lp, $lr, $laud) = KWSEval_SCHelper::check_name($kwsyear, $eteam, $expid, $verb);
MMisc::error_quit($lerr) if (! MMisc::is_blank($lerr));

MMisc::error_quit("Can not score; no usable ECF & TLIST files with <CORPUSID> = $lcorpus | <PARTITION> = $lpart in \'dbDir\'")
  if (! MMisc::safe_exists(\%ecfs, $lcorpus, $lpart));

MMisc::error_quit("Error: Corpus id $lcorpus does not begin with /babel###/")
  if ($lcorpus !~ /^(babel(\d\d\d)).*$/);
my $languageID = $1;
my $lang = $2;

my @summaryDETS = ();


print "Step 1: Parse input\n";
my @parseInfo = ("Info: EXPID = $expid",
                 "Info: Team = $lteam",
                 "Info: Corpus = $lcorpus",
                 "Info: Partition = $lpart",
                 "Info: ScoringCase = $lscase",
                 "Info: Task = $ltask",
                 "Info: TrainingCond = $ltrncond",
                 "Info: SystemID = $lsysid",
                 "Info: Version = $lversion",
                 "Info: Language ID = $languageID",
                 "Info: Language = $lang",
                 "Info: SCTKBin = $sctkbindir",
                 "Info: SHA256 = $sha256",
                 );
print join("\n",@parseInfo)."\n";

my ($com, $ret);
my $db = undef;
foreach (@dbDir){
  if (-d "$_/${lcorpus}_${lpart}"){
    $db = "$_/${lcorpus}_${lpart}";
    last;
  }
}
MMisc::error_quit("Step 1 failed to find the reference file database. Aborting") if (! defined($db));
print "Info: dbDir = $db\n";

### Paranoia check for the DryRun.  This will be implemented elsewhere!!!!!!
if ($lcorpus =~ /babel101b-v0.4c-DryRunEval-v3/){
  if ($lscase =~ /(BADev|Dev)/){
    MMisc::error_quit("Step 1 failed. Scoring case $lscase not supported for $lcorpus. Aborting") if ($lscase =~ /(BADev|Dev)/);
  }
}

### Plan out the scoring for Cantonese - 101
###  ## Audio divisions
###    Score full data set
###    Score Dev Only
###    Score Dev-eval only
###  ## Term set divisions
###    BBN Terms
###    New Terms
###  ## conditional scoring
###    Roman vs. Non-Roman keywords
###    Non-Roman keywords : by character length
###    Combine DET: Full data, Dev only, dev-eval
###   Reporting
###    BaDev - Not re

sub copyToResult{
  my ($scrdir, $resdir, $fileRootName, $fileRegexps) = @_;
  
  my $resFiles = "";
  foreach my $file(split(/\s/, `(cd $scrdir ; find $fileRootName.*)`)){
    my $needIt = 0;
    foreach my $exp(@$fileRegexps){
      $needIt = 1 if ($file =~ /$fileRootName$exp$/);
    }
    if ($needIt){
#      print "   copy $file\n";
      $resFiles .= " $file";
    }
#    print "   not $file\n" unless ($needIt);
  }
  system("(cd $scrdir ; tar cf - $resFiles) | (cd $resdir; tar xvf -) 2>&1 | sed 's/^/    /'");
  
}

sub execKWSScoreRun{
  my ($def, $scase, $readme, $preferredScoring) = @_;
  
  my $compRoot = "$scrdir/".$def->{outputRoot};

  ### Check the preferred Scoring attributes
  foreach my $attr(keys %{ $def->{"RunAttributes"} }){
#    print "Check $attr $preferredScoring->{$attr} =~ $def->{RunAttributes}{$attr}\n"; 
    if (exists($preferredScoring->{$attr})){
      if ($def->{"RunAttributes"}{$attr} !~ /$preferredScoring->{$attr}/){
#         print "          Run Attribute $attr does not match definition.  Skipping\n";
         return("NotRequested");
      }
    }
  }

  print "\nStep 2: KWS scoring execution ".$def->{runID}.": Scase $scase: ".$def->{runDesc}."\n";

  MMisc::error_quit("Problem with scoring case.  Results copy not defined") if (! exists($def->{RESULTS}{$scase}));

  ### Check the pre-requisites.  If they exist, run.  If not, Skip
  my $skip = "";
  foreach my $prereq(@{ $def->{filePreReq} }){
    my $err = MMisc::check_file_r($prereq);
    $skip .= " $prereq" if (! MMisc::is_blank($err));
  }
  if ($skip){
    print "   Pre-requist file(s)$skip do not exist.  Skipping run.\n";
    return("skipped");
  }
  
  MMisc::writeTo($readme, "", 0, 1, "KWS Scoring ".$def->{runID}.": Scase $scase: ".$def->{runDesc}."\n   Output file root name: $def->{outputRoot}\n");

  ### Check the Input files to make sure the exist
  foreach my $file("ECF", "RTTM", "KWLIST", "KWSLIST"){
    my $err = MMisc::check_file_r($def->{$file});
    MMisc::error_quit("Problem with needed $file ($def->{$file}): $err") if (! MMisc::is_blank($err));
  }

  $com = "";
  if (defined($ProcGraph)){
    my $procDir = "$compRoot.procgraph";
    system "mkdir -p $procDir";
    $com = "$ProcGraph --cumul --Tree --outdir $procDir --gnuplot --Generat -- ";
  }  
  $com .= "$kwseval -I \"$def->{systemDesc}\" ".
    " -e $def->{ECF}".
    " -r $def->{RTTM}".
    " -t $def->{KWLIST}".
    " -s $def->{KWSLIST}".
    " $def->{KWSEVAL_OPTS}".
    " -f $compRoot".
    " -y TXT -y HTML";
  $com .= " -X" if ($bypassxmllint);

  if (! -f "$compRoot.log"){
    my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.log", $com);
    MMisc::writeTo("$compRoot.sh", "", 0, 0, "$com\n");
    MMisc::error_quit("Scoring execution ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);
  } else {
    print "Skipping execution\n";
  } 
  
  MMisc::writeTo($readme, "", 0, 1, "\n");
  print "  Execution completed.  Copying to results\n";
  copyToResult($scrdir, $resdir, $def->{outputRoot}, $def->{RESULTS}{$scase});
  return("complete");
}

sub execSTTScoreRun{
  my ($def, $scase, $readme) = @_;
  
  my $compRoot = "$scrdir/$def->{outputName}";

  print "\nStep 2: STT scoring execution ".$def->{runID}.": Scase $scase: ".$def->{runDesc}."\n";

  MMisc::error_quit("Problem with scoring case.  Results copy not defined") if (! exists($def->{RESULTS}{$scase}));

  ### Check the pre-requisites.  If they exist, run.  If not, Skip
  my $skip = "";
  foreach my $prereq(@{ $def->{filePreReq} }){
    my $err = MMisc::check_file_r($prereq);
    $skip .= " $prereq" if (! MMisc::is_blank($err));
  }
  if ($skip){
    MMisc::writeTo($readme, "", 0, 1, "   Pre-requist file(s)$skip do not exist.  Skipping run.\n\n");
    print "   Pre-requist file(s)$skip do not exist.  Skipping run.\n";
    return;
  }

  ### Checking for a GLM
  my $GLM = "$dbDir[0]/babel$lang.glm";
  $err = MMisc::check_file_r($GLM);
  if (MMisc::is_blank($err)){
    print "  GLM $GLM exists and will be used\n";
  } else {
    print "  $GLM not found.  No filtering will occur\n";
    $GLM = undef;
  }

  MMisc::writeTo($readme, "", 0, 1, "STT Scoring ".$def->{runID}.": Scase $scase: ".$def->{runDesc}."\n   Output file root name: $def->{outputName}\n");

  ### Check the Input files to make sure the exist
  foreach my $file("STM", "SYS"){
    my $err = MMisc::check_file_r($def->{$file});
    MMisc::error_quit("Problem with needed $file ($def->{$file}): $err") if (! MMisc::is_blank($err));
  }
  
  ### Check the extension of the SYS file and convert to CTM if necessary
  if ($def->{SYS} =~ /.ctm$/){
    $def->{CTM} = $def->{SYS};
  } else {
    MMisc::error_quit("Unable to handle system input file $def->{SYS}): $err");
  }

  $com = "$hubscore sortCTM < $def->{CTM} > $def->{CTM}.sort";
  MMisc::writeTo("$compRoot.sh", "", 0, 1, "$com\n");
  my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.sort.log", $com);
  MMisc::error_quit("CTM Sorting execution failed ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);

  my $ctmFile = "$def->{CTM}.sort";
  my $stmFile = $def->{STM};
  
  if (defined($GLM)){
    $com = "$csrfilt -i ctm $GLM < $def->{CTM}.sort > $def->{CTM}.filter "; 
    MMisc::writeTo("$compRoot.sh", "",0, 1, "$com\n");
    my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.filter.log", $com);
    MMisc::error_quit("CTM Filter execution failed ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);
    $ctmFile = "$def->{CTM}.filter";

    $com = "$csrfilt -i stm $GLM < $def->{STM} > $def->{CTM}.ref.filter "; 
    MMisc::writeTo("$compRoot.sh", "", 0, 1, "$com\n");
    my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.filter.log", $com);
    MMisc::error_quit("CTM Filter execution failed ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);  
    $stmFile = "$def->{CTM}.ref.filter";
  }
  
  $com = "$sclite -r $stmFile stm".
    " -h $ctmFile ctm '$def->{systemDesc}'".
    " -O $scrdir".
    " -n $def->{outputName}".
    " -o sum rsum prf dtl sgml".
    " -f 0".
    " -D -F -e utf-8".
    " $def->{SCLITE_OPTS}";

  if (! -f "$compRoot.log"){
    my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.log", $com);
    MMisc::writeTo("$compRoot.sh", "", 0, 1, "$com\n");
    MMisc::error_quit("Scoring execution ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);
    ## Rename the files to .txt extensions
    foreach my $type("sys", "raw", "prf", "dtl"){
      system "mv $scrdir/$def->{outputName}.$type $scrdir/$def->{outputName}.$type.txt"; 
    }
  } else {
    print "Skipping previously execution\n";
  }
  
  MMisc::writeTo($readme, "", 0, 1, "\n");
  print "  Execution completed.  Copying to results\n";
  copyToResult($scrdir, $resdir, $def->{outputName}, $def->{RESULTS}{$scase});
}

sub execKWSEnsemble2{
  my ($def, $scase, $readme) = @_;

  ### Loop through the scoreDefs to see what can be used
  print "\nStep 3: Building ".$def->{ensembleID}.": Scase $scase: ".$def->{ensembleTitle}."\n";
  
  my %attrValues = ();
  my @useSdefs = ();
  foreach my $sdef(sort keys %{ $def->{scoreDefs} }){
    my $use = 1;
    foreach my $attr(keys %{ $def->{selectDefs} }){
      if ($def->{scoreDefs}->{$sdef}{RunAttributes}{$attr} !~ /$def->{selectDefs}{$attr}/) {
#        print "$sdef not possible\n";
        $use = 0;
      }
    }
    my $stype = ($def->{scoreDefs}->{$sdef}{RunAttributes}{"Protocol"} eq "Occur" ? "Occurrence" : "Segment");
    my $srl = "$scrdir/$def->{scoreDefs}{$sdef}{outputRoot}.dets/sum.$stype.srl.gz";
    $use = 0 if (! -f $srl);
    
    if ($use){
#      print "using $sdef\n";
      push @useSdefs, { sdef => $sdef, srl => $srl };
      foreach my $attr(keys %{ $def->{selectDefs} }){
        $attrValues{$attr}{$def->{scoreDefs}->{$sdef}{RunAttributes}{$attr}} = $def->{scoreDefs}->{$sdef}{RunAttributeStr}{$attr} ;
      }
    }
  }
#  print Dumper(\%attrValues);
#  print Dumper(\@useSdefs);
  ### Make the titles   
  my $mainTitle = undef;
  foreach my $attr(sort keys %attrValues){
    my @strs = sort keys %{ $attrValues{$attr} };
    if (@strs <= 1){
      $mainTitle .= ", " if (defined($mainTitle));
      $mainTitle .= "$attrValues{$attr}{$strs[0]}";
    } else {
      for (my $s=0; $s<@useSdefs; $s++){
        $useSdefs[$s]->{title} .= ", " if (exists($useSdefs[$s]->{title}));
        $useSdefs[$s]->{title} .= $def->{scoreDefs}->{$useSdefs[$s]->{sdef}}{RunAttributes}{$attr};
      }
    }
  }
  my @srls = ();
  for (my $s=0; $s<@useSdefs; $s++){
    push @srls, "'".$useSdefs[$s]->{srl}.":".$useSdefs[$s]->{title}."'";
  }
  print "  Main Title: '$mainTitle'\n";
#  print "SRLs:\n   ".join("\n   ",@srls)."\n";
  if (@srls == 0) {
    print "No SRLs: Not computing\n";
    return;
  }
  
  if (! -f "$scrdir/$def->{ensembleRoot}.png"){ 
    $com = "$detutil $def->{DETOPTIONS} --txtTable -I -Q 0.3 -T '$mainTitle' -o $scrdir/$def->{ensembleRoot}.png ".join(" ",@srls);
    MMisc::writeTo("$scrdir/$def->{ensembleRoot}.sh", "", 0, 0, "$com\n");
    my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$scrdir/$def->{ensembleRoot}.log", $com);
    MMisc::error_quit("DETUtil ".$def->{ensembleID}." failed returned $ret. Aborting") if ($retcode != 0);    
  } else {
    print "Skipping previously completed execution\n";
  }

  print "  Execution completed.  Copying to results\n";
  copyToResult($scrdir, $resdir, $def->{ensembleRoot}, $def->{RESULTS}{$scase});

}

### ROOT is going to be
###   Occur | InfSeg -> scoring type
###   AppInterp | AppSeg | MITLLFA -> reference time mark derivation
###   AppWordSeg | SplitChar -> Style of transcript 

if ($ltask =~ /KWS/){
  print "Beginning $ltask scoring\n";

  my %RunDefs = ();  
  ### Make the run structures via foreac
  foreach my $setDEF("Full:Full Submission", "DevSubset:Dev Subset", "DevProgSubset:Dev-Progress Subset"){
    my ($setID, $setStr) = split(/:/, $setDEF);
    my $ecfs = {"Full" => "$db/${lcorpus}_${lpart}.scoring.ecf.xml", 
                "DevSubset" => "$db/${lcorpus}_${lpart}.scoring.dev.ecf.xml",
                "DevProgSubset" => "$db/${lcorpus}_${lpart}.scoring.dev-progress.ecf.xml"};
    my $BaDev  = {"Full" => [      "\\.alignment.csv", "\\.log", "\\.sh", "\\.sum.*", "\\.bsum.*", "\\.dets/.*srl.gz", "\\.dets/.*.png"],
                  "DevSubset" => [ "\\.alignment.csv", "\\.log", "\\.sh", "\\.sum.*", "\\.bsum.*", "\\.dets/.*srl.gz", "\\.dets/.*.png"],
                  "DevProgSubset" => [ ] };
    my $BaEval = {"Full" => [                          "\\.log", "\\.sh",                                              "\\.dets/.*.png"],
                  "DevSubset" => [ "\\.alignment.csv", "\\.log", "\\.sh", "\\.sum.*", "\\.bsum.*",                     "\\.dets/.*.png"],
                  "DevProgSubset" => [                 "\\.log", "\\.sh",                                              "\\.dets/.*.png"] };
    
    foreach my $protocolDEF("Occur:Occurrence scoring", "InfSeg:Inferred Segment scoring"){
      my ($protocolID, $protocolStr) = split(/:/, $protocolDEF);
      my ($proto) = {"Occur" => "-c -o -b -d",
                     "InfSeg" => "-c -o -b -d -g"};
 
      foreach my $tokTimesDEF("AppenInterp:Uniform Appen times", "MITLLFA2:MITLL Force Ali. V2", "MITLLFA3:MITLL Force Ali. V3"){
        my ($tokTimesID, $tokTimesStr) = split(/:/, $tokTimesDEF);
        my $rttms = {"AppenInterp" => "$db/${lcorpus}_${lpart}.rttm",
                     "MITLLFA2" => "$db/${lcorpus}_${lpart}.mitllfa2.rttm",
                     "MITLLFA3" => "$db/${lcorpus}_${lpart}.mitllfa3.rttm"};

        foreach my $tokSegDEF("AppenWordSeg:Original orthography", "SplitCharText:Split character texts"){
          my ($tokSegID, $tokSegStr) = split(/:/, $tokSegDEF);
          my ($tokSegs) = {"AppenWordSeg" => "",
                           "SplitCharText" => "-x charsplit -x deleteHyphens -x notASCII"};

          my $runID = "$setID-$protocolID-$tokTimesID-$tokSegID";
          my $def = { "runID" => "$runID"};
          $def->{"runDesc"} = "$setStr, $protocolStr, $tokTimesStr, $tokSegStr";
          $def->{"systemDesc"} = "$lsysid $lversion: $lcorpus $lpart - $setStr";
          $def->{"KWSLIST"} = $sysfile;
          $def->{"KWLIST"} = "$db/${lcorpus}_${lpart}.annot.kwlist.xml";
          $def->{"ECF"} = $ecfs->{$setID};
          $def->{"RTTM"} = $rttms->{$tokTimesID};
          $def->{"outputRoot"} = $runID;
          $def->{"KWSEVAL_OPTS"} = $proto->{$protocolID}." ".$tokSegs->{$tokSegID};
          $def->{"RESULTS"} = {"BaDev" => $BaDev->{$setID}, "BaEval" => $BaEval->{$setID} };
          $def->{"filePreReq"} = [ ];
          push @{ $def->{"filePreReq"} }, $ecfs->{$setID} if ($setID ne "Full");  ### Non-Full is optional
          push @{ $def->{"filePreReq"} }, $rttms->{$tokTimesID} if ($tokTimesID ne "MITLLFA3");  ### Non-Full is optional

          $def->{"RunAttributes"} = {"Set" => $setID,  "Protocol" => $protocolID,  "TokTimes" => $tokTimesID,  "TokSeg"=> $tokSegID};
          $def->{"RunAttributeStr"}={"Set" => $setStr, "Protocol" => $protocolStr, "TokTimes" => $tokTimesStr, "TokSeg"=> $tokSegStr};
          
          $RunDefs{$runID} = $def;
        }
      }
    }
  }
#  print Dumper(\%RunDefs);
  ## Interate of the DEFS
  my $readme = "$scrdir/Readme.txt";             
  ### Add some content to the README
  MMisc::writeTo($readme, "", 0, 0, "Program: $versionid\n");  ## Initial erase
  MMisc::writeTo($readme, "", 0, 1, "Date: ".`date`);
  MMisc::writeTo($readme, "", 0, 1, join("\n",@parseInfo)."\n");
 
  my $preferredScoring = undef;
  if ($lang eq "101") { $preferredScoring     = { "Set" => "Full|DevSubset|DevProgSubset",
                                                  "TokTimes" => "MITLLFA[23]", 
                                                  "TokSeg" => "SplitCharText", 
                                                  "Protocol" => "Occur" } 
                      }
  elsif ($lang eq "104") { $preferredScoring  = { "Set" => "Full",
                                                  "TokTimes" => "MITLLFA3", 
                                                  "TokSeg" => "AppenWordSeg", 
                                                  "Protocol" => "Occur" } 
                          }
  elsif ($lang eq "105") { $preferredScoring  = { "Set" => "Full",
                                                  "TokTimes" => "MITLLFA3", 
                                                  "TokSeg" => "AppenWordSeg", 
                                                  "Protocol" => "Occur" } 
                          }
  elsif ($lang eq "106") { $preferredScoring  = { "Set" => "Full",
                                                  "TokTimes" => "MITLLFA3", 
                                                  "TokSeg" => "AppenWordSeg", 
                                                  "Protocol" => "Occur" } 
                          }
  else {
    MMisc::error_quit("Internale error: KWS evaluation does not have preferred scoring set language $languageID defined")
  }
  
#  execKWSScoreRun($kwRun1, $lscase, $readme, $preferredScoring);
  my @completed = ();
  foreach my $defKey(sort keys %RunDefs){
    my $status = execKWSScoreRun($RunDefs{$defKey}, $lscase, $readme, $preferredScoring); 
    push (@completed, $defKey) if ($status eq "complete");
  }

  print "\nCompleted KWS Runs:\n   ".join("\n   ",@completed)."\n";
 
  my $detOpts = " --plot 'ExtraPoint=Team = $lteam:.004:.1:0:1::' ";
    $detOpts .= " --plot 'ExtraPoint=System = ${lsysid}_${lversion}:.004:.085:0:1::' ",;
    $detOpts .= " --plot 'ExtraPoint=Data = $lcorpus $lpart:.004:.070:0:1::' ";
    $detOpts .= " --plot 'ExtraPoint=SHA256 = $sha256:.004:.055:0:1::' " if ($sha256 ne "");

  execKWSEnsemble2({scoreDefs => \%RunDefs,
                    selectDefs => { "Set" => ".*", "TokTimes" => ".*",
                                    "TokSeg" => ".*", "Protocol" => "Occur"},
                    ensembleID => "Ensemble.AllOccur",
                    ensembleRoot => "Ensemble.AllOccur",
                    ensembleTitle => "All Occurrence Scorings",
                    DETOPTIONS => $detOpts, 
                    RESULTS => {
                       "BaDev" =>  [  "\\.log", "\\.sh", ".png", ".results.txt"],
                       "BaEval" => [  "\\.log", "\\.sh", ".png", ".results.txt"],
                    }
                  },
                  $lscase, $readme);
  
  print "\nStep 4: Cleanup\n";
  print "  Scoring completed.  Copying readme\n";
  copyToResult($scrdir, $resdir, "Readme", [ ".txt" ]);
} elsif ($ltask =~ /STT/){
  print "Beginning $ltask scoring\n";

  my $sttRun1 = { "runID" => "Run1",
               "runDesc" => "Full submission - Word based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Full Set",
               "filePreReq" => [ ],
               "outputName" => "FullSet-WER",
               "STM" => "$db/${lcorpus}_${lpart}.stm",
               "SYS" => $sysfile,
               "SCLITEL_OPTS" => "",
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt", "\\.raw.txt"                               ],
               }
             };
             
  my $sttRun2 = { "runID" => "Run2",
               "runDesc" => "Full submission - Char based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Full Set",
               "filePreReq" => [ ],
               "outputName" => "FullSet-CER",
               "STM" => "$db/${lcorpus}_${lpart}.stm",
               "SYS" => $sysfile,
               "SCLITE_OPTS" => "-c NOASCII DH",
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt", "\\.raw.txt"                               ],
               }
             };

  my $sttRun3 = { "runID" => "Run3",
               "runDesc" => "Dev subset - Word based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Dev Subset",
               "filePreReq" => [ "$db/${lcorpus}_${lpart}.dev.stm" ],
               "outputName" => "DevSubset-WER",
               "STM" => "$db/${lcorpus}_${lpart}.dev.stm",
               "SYS" => $sysfile,
               "SCLITEL_OPTS" => "",
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
               }
             };
             
             
  my $sttRun4 = { "runID" => "Run4",
               "runDesc" => "Dev subset - Char based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Dev Subset",
               "filePreReq" => [ "$db/${lcorpus}_${lpart}.dev.stm" ],
               "outputName" => "DevSubset-CER",
               "STM" => "$db/${lcorpus}_${lpart}.dev.stm",
               "SYS" => $sysfile,
               "SCLITE_OPTS" => "-c NOASCII DH",
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
               }
             };

  my $sttRun5 = { "runID" => "Run5",
               "runDesc" => "Dev Progress subset - Word based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Dev Pogress Subset",
               "filePreReq" => [ "$db/${lcorpus}_${lpart}.dev-progress.stm" ],
               "outputName" => "DevProgSubset-WER",
               "STM" => "$db/${lcorpus}_${lpart}.dev-progress.stm",
               "SYS" => $sysfile,
               "SCLITEL_OPTS" => "",
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt", "\\.raw.txt"                               ],
               }
             };
             
             
  my $sttRun6 = { "runID" => "Run6",
               "runDesc" => "Dev Progress subset - Char based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Dev Progress Subset",
               "filePreReq" => [ "$db/${lcorpus}_${lpart}.dev-progress.stm" ],
               "outputName" => "DevProgSubset-CER",
               "STM" => "$db/${lcorpus}_${lpart}.dev-progress.stm",
               "SYS" => $sysfile,
               "SCLITE_OPTS" => "-c NOASCII DH",
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt", "\\.raw.txt"                               ],
               }
             };
             
  my $readme = "$scrdir/Readme.txt";             
  my $sttMesg = "File: Readme.txt\n".
                "Date: ".`date`.
                "Contents: This directory contains STT scoring reports.  The file is organized by sets of the results organized\n".
                "          by the following file prefixes.  Not all prefixes will exist depending on the dataset scored.\n".
                "\n".
                "          FullSet_Word - Word based scoring on the full data set\n".
                "          FullSet_Char - Character based scoring on the full data set\n".
                "          DevSubset_Word - Word based scoring on the (10 hr.) Development subset.\n".
                "          DevSubset_Char - Character based scoring on the (10 hr.) Development subset.\n".
                "          DevProgSubset_Word - Word based scoring on the (5 hr.) Development Progress subset.  No transcripts will be provided\n".
                "          DevProgSubset_Char - Character based scoring on the (5 hr.) Development Progress subset.  No transcripts will be provided\n".
                "\n".
                "!!!  These results (all files and content) are FOUO until they have been vetted for release.  !!!\n".
                "\n";
  MMisc::writeTo($readme, "", 0, 1, $sttMesg);
 
  execSTTScoreRun($sttRun1, $lscase, $readme);
  execSTTScoreRun($sttRun2, $lscase, $readme);
  execSTTScoreRun($sttRun3, $lscase, $readme);
  execSTTScoreRun($sttRun4, $lscase, $readme);
  execSTTScoreRun($sttRun5, $lscase, $readme);
  execSTTScoreRun($sttRun6, $lscase, $readme);

  print "\nStep 3: Cleanup\n";
  print "  Scoring completed.  Copying readme\n";
  copyToResult($scrdir, $resdir, "Readme", [ ".txt" ]);

}

########################################################################
# If we are here, all went well, exit with 'ok' status (expected by caller)
if (scalar @donefile > 0) {
  for (my $i = 0; $i < scalar @donefile; $i++) {
    MMisc::error_quit("Could not create \'donefile\' (" . $donefile[$i] . ")")
        if (! MMisc::writeTo($donefile[$i]));
  }
}
MMisc::ok_exit();

############################################################

sub split_corpus_partition {
  my ($f, $e) = @_;
  $f =~ s%$e$%%i;
  my (@rest) = split(m%\_%, $f);
  MMisc::error_quit("Could not split ($f) in <CORPUSID>_<PARTITION>")
    if (scalar @rest != 2);
  return("", @rest);
}

#####

sub prune_list {
  my $dir = shift @_;
  my $ext = shift @_;
  my $robj = shift @_;

  my @list = grep(m%$ext$%i, @_);
  my %rest = MMisc::array1d_to_ordering_hash(\@_);
  for (my $i = 0; $i < scalar @list; $i++) {
    my $file = $list[$i];
    my ($err, $cid, $pid) = split_corpus_partition($file, $ext);
    MMisc::error_quit($err) if (! MMisc::is_blank($err));
    my $here = "$dir/$file";
    MMisc::warn_print("An \'$ext\' file already exist for <CORPUSID> = $cid | <PARTITION> = $pid (" . $$robj{$cid}{$pid} . "), being replaced by: $here")
      if (MMisc::safe_exists($robj, $cid, $pid));
    $$robj{$cid}{$pid} = $here;
    delete $rest{$file};
  }

  return(sort {$rest{$a} <=> $rest{$b}} (keys %rest));
}

##

sub obtain_ecf_tlist {
  my ($dir, $recf, $rtlist, $rrttm) = @_;

  my @files = MMisc::get_files_list($dir);

  @files = &prune_list($dir, $tlist_ext, $rtlist, @files);
  @files = &prune_list($dir, $rttm_ext, $rrttm, @files);
  @files = &prune_list($dir, $ecf_ext, $recf, @files);
}

#####

sub check_ecf_tlist_pairs {
  my ($recf, $rtlist, $rrttm) = @_;

  vprint(1, "Checking found ECF & TLIST");
  my @tmp1 = keys %$recf;
  push @tmp1, keys %$rtlist;
  foreach my $k1 (sort (MMisc::make_array_of_unique_values(\@tmp1))) {
    MMisc::error_quit("While checking for matching ECF & KWlist pairs: can not find any ECF with <CORPUSID>: $k1")
      if (! exists $$recf{$k1});
    MMisc::error_quit("While checking for matching ECF & KWlist pairs: can not find any KWlist with <CORPUSID>: $k1")
      if (! exists $$rtlist{$k1});
    my @tmp2 = keys %{$$recf{$k1}};
    push @tmp2, keys %{$$rtlist{$k1}};
    foreach my $k2 (sort (MMisc::make_array_of_unique_values(\@tmp2))) {
      MMisc::error_quit("While checking for matching ECF & KWlist pairs: can not find any ECF with <PARTITION>: $k2")
        if (! exists $$recf{$k1}{$k2});
      MMisc::error_quit("While checking for matching ECF & KWlist pairs: can not find any KWlist with <PARTITION>: $k2")
        if (! exists $$rtlist{$k1}{$k2});
      my @a = ();
      push (@a, $rttm_ext) if (MMisc::safe_exists($rrttm, $k1, $k2));
      my $tmp = (scalar @a > 0) ? " | \'" . join("\' & \'", @a) . "\' found" : "";
      vprint(2, "Have <CORPUSID> = $k1 | <PARTITION> = $k2$tmp");
    }
  }
}

##########

sub vprint {
  return if (! $verb);
  my $s = "********************";
  print substr($s, 0, shift @_), " ", join("", @_), "\n";
}


############################################################

sub set_usage {
  my $usage = "$0 [--version | --help] [--Verbose] [--KWSEval tool [--XmllintBypass]] [--DETUtil tool] [--Tsctkbin dir] [--Hsha256id sha] [--fileCreate file [--fileCreate file [...]]] [--ProcGraph tool] [--ExpectedTeamName TEAM] --Specfile specfile --expid EXPID --sysfile file --compdir dir --resdir dir --dbDir dir [--dbDir dir [...]]\n";
  $usage .= "\n";
  $usage .= "Will score a submission file against data present in the dbDir.\n";
  $usage .= "\nThe program needs a \'dbDir\' to load some of its eval specific definitions; this directory must contain pairs of <CORPUSID>_<PARTITION> \".ecf.xml\" and \".kwlist.xml\" files that match the component of the EXPID to confirm expected data validity, as well as a <CORPUSID>_<PARTITION> directory containing reference data needed for scoring.\n";
  $usage .= "\n";
  $usage .= "  --version    Display tool version\n";
  $usage .= "  --help       Display this help message\n";
  $usage .= "  --Verbose    Be more verbose\n";
  $usage .= "  --KWSEval    Location of the KWSEval tool (default: $kwseval)\n";
  $usage .= "  --XmllintBypass      Bypass xmllint check of the KWSList XML file (this will reduce the memory footprint when loading the file, but requires that the file be formatted in a way similar to how \'xmllint --format\' would)\n";
  $usage .= "  --DETUtil    Location of the DETUtil tool (default: $detutil)\n";
  $usage .= "  --Hsha256id  SHA256 ID\n";
  $usage .= "  --fileCreate   If requested, once succesfully run, will create the file before exiting with success (: separated or multiple can be specified)\n";
  $usage .= "  --ProcGraph  Location of the ProcGraph tool.  If defined ProcGraph will be run. (default: UNDEF)\n";
  $usage .= "  --ExpectedTeamName  Expected value of TEAM (used to check EXPID content)\n";
  $usage .= "  --Tsctkbin   Location of SCTK's bin directory\n";
  $usage .= "  --Specfile   Configuration file containing EXPID definition\n";
  $usage .= "  --sysfile    System input file\n";
  $usage .= "  --compdir    Directory where computation can be performed\n";
  $usage .= "  --resdir     Directory that will be returned to participants\n";
  $usage .= "  --dbDir      Directory containing ECF, TLIST, RTTM files (: separated or multiple can be specified)\n";

  $usage .= "\n";
  
  return($usage);
}
