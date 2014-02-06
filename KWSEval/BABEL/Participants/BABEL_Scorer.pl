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
my $version     = "0.5";
if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^0-9\.]//g;
  $version = "$version (CVS: $cvs_version)";
}
my $versionid = "BABEL_Scorer Version: $version";

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
my $tlist_ext_rgx = '\.kwlist\d*\.xml';

my $stm_ext = ".stm";
my $rttm_ext = ".rttm";

my $kwslist_ext = ".kwslist.xml";
my $ctm_ext = ".ctm";

my $kwseval = "$f4d/../../tools/KWSEval/KWSEval.pl";

my $detutil = "$f4d/../../../common/tools/DETUtil/DETUtil.pl";

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
my $sysmetadatadumpf = "";
my $sysmetadatadump = undef;
my $eteam = undef;
my $bypassxmllint = 0;
my $xpng = 0;
my $pendingfile = "";
my $releasefile = "";
my $extendedRunIndusDataDef = undef;
my $forceSpecfile = undef;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:    DEF H  K    P  ST V X    cdef h         rst v     #
# Mult:     EF                                               #

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
   'x|extendedRunIndusDataDef=s' => \$extendedRunIndusDataDef,
   'ProcGraph=s'  => \$ProcGraph,
   'Hsha256id=s' => \$sha256,
   'Tsctkbin=s' => \$sctkbindir,
   'tSystemDescription=s' => \$sysdesc,
   'mSystemMeta=s' => \$sysmetadatadumpf,
   'ExpectedTeamName=s' => \$eteam,
   'XmllintBypass' => \$bypassxmllint,
   'ExcludePNGFileFromTxtTable'          => \$xpng,
   'FilePending=s' => \$pendingfile,
   'FileRelease=s' => \$releasefile,
   'ForceSpecfile:s' => \$forceSpecfile,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Leftover arguemnts on the command line: " . join(" ", @ARGV) . "\n\n$usage")
  if (scalar @ARGV != 0);


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

MMisc::error_quit("\'FilePending\' and \'FileRelease\' must be used at the same time")
  if ((MMisc::all_blank($pendingfile, $releasefile) == 0)
      && (MMisc::any_blank($pendingfile, $releasefile))); 

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
if (defined($extendedRunIndusDataDef)){
  $err = MMisc::check_file_r($extendedRunIndusDataDef);
  MMisc::error_quit("Problem with 'extendedRunIndusDataDef': $err")
    if (! MMisc::is_blank($err));
  ### Make the extended computation directory if needed
  $err = MMisc::check_dir_w($scrdir."-Extended");
  if (! MMisc::is_blank($err)){
    MMisc::error_quit("Failed to make Extended Scoring '$scrdir-Extended'")
      if (! MMisc::make_dir($scrdir."-Extended")); 
  }  
}
if (! MMisc::is_blank($sysmetadatadumpf)) {
    $err = MMisc::check_file_r($sysmetadatadumpf);
    if (! MMisc::is_blank($err)) {
	$sysmetadatadump = MMisc::load_memory_object($sysmetadatadumpf);
    }
}

$ENV{PATH} .= ":".$sctkbindir if (! MMisc::is_blank($sctkbindir));
my $sclite = "sclite";
my $hubscore = "hubscr.pl";
my $csrfilt = "csrfilt.sh";

my $tmp = scalar @donefile;
for (my $i = 0; $i < $tmp; $i++) {
  my $v = shift @donefile;
  push @donefile, split(m%\:%, $v);
}

MMisc::error_quit("No \'Specfile\' given, will not continue processing\n\n$usage\n")
  if (MMisc::is_blank($specfile));
my $err = MMisc::check_file_r($specfile);
MMisc::error_quit("Problem with \'Specfile\' ($specfile) : $err")
  if (! MMisc::is_blank($err));

## Find 
my %ecfs = ();
my %tlists = ();
my %rttms = ();
my %stms = ();
for (my $i = 0; $i < scalar @dbDir; $i++) {
  $err = MMisc::check_dir_r($dbDir[$i]);
  MMisc::error_quit("Problem with \'dbDir\' (" . $dbDir[$i] . ") : $err")
    if (! MMisc::is_blank($err));
  KWSEval_SCHelper::obtain_ecf_tlist
      ($dbDir[$i], 
       $ecf_ext, \%ecfs, 
       $tlist_ext_rgx, \%tlists, 
       $rttm_ext, \%rttms, 
       \%stms);
}
MMisc::error_quit("Did not find any ECF or TLIST files; will not be able to continue")
  if ((scalar (keys %ecfs) == 0) || (scalar (keys %tlists) == 0));
KWSEval_SCHelper::check_ecf_tlist_pairs($verb, \%ecfs, \%tlists, $rttm_ext, \%rttms, $stm_ext, \%stms);

########################################

if (defined $forceSpecfile) {
  if (! MMisc::is_blank($forceSpecfile)) {
    $specfile = $forceSpecfile;
    my $err = MMisc::check_file_r($specfile);
    MMisc::error_quit("Problem with \'ForceSpecfile\' ($specfile) : $err")
      if (! MMisc::is_blank($err));
  }
} else {
# Find the preferred specfile
  $specfile = KWSEval_SCHelper::selectSpecfile($specfile, @dbDir);
}
my $kwsyear = KWSEval_SCHelper::loadSpecfile($specfile, $ctm_ext, $kwslist_ext);

my @Scase_toSequester = KWSEval_SCHelper::get_Scase_toSequester();
my %AuthorizedSet = KWSEval_SCHelper::get_AuthorizedSet();

# Remove the file ending (and extract it value for 'mode' selector)
my $mode = undef;
if ($sysfile =~ m%$kwslist_ext$%i) {
  $mode = $kwslist_ext;
} elsif ($sysfile =~ m%$ctm_ext$%i) {
  $mode = $ctm_ext;
}
MMisc::error_quit("File must end in either \'$kwslist_ext\' or \'$ctm_ext\' to be usable")
  if (! defined $mode);

my ($lerr, $ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $ltrncond, $lsysid, $lversion, $lp, $lr, $laud) = KWSEval_SCHelper::check_name($kwsyear, $eteam, $expid, $mode, $verb);
MMisc::error_quit($lerr) if (! MMisc::is_blank($lerr));

MMisc::error_quit("No Rule set for <PARTITION>=$lpart <SCASE>=$lscase")
  if (! MMisc::safe_exists(\%AuthorizedSet, $lpart, $lscase));
MMisc::error_quit("The <PARTITION>=$lpart <SCASE>=$lscase combination is not authorized")
  if ($AuthorizedSet{$lpart}{$lscase} == 0);


MMisc::error_quit("Can not score; no usable ECF & TLIST files with <CORPUSID> = $lcorpus | <PARTITION> = $lpart in \'dbDir\'")
  if (! MMisc::safe_exists(\%ecfs, $lcorpus, $lpart));

MMisc::error_quit("Error: Corpus id $lcorpus does not begin with /babel###/")
  if ($lcorpus !~ /^((IARPA-)?babel(\d\d\d)).*$/);
my $languageID = $1;
my $lang = $3;

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
my $indusCorporaDefsFile = undef;
foreach (@dbDir){
  if (-d "$_/${lcorpus}_${lpart}"){
    $db = "$_/${lcorpus}_${lpart}";
    ### Now look for the CorporaDefsFile
    if (defined($extendedRunIndusDataDef)){
      $indusCorporaDefsFile = $extendedRunIndusDataDef;
    } elsif (-f "$_/IndusCorporaDefs.pl"){
      $indusCorporaDefsFile = "$_/IndusCorporaDefs.pl";
    }
    last;
  }
}
MMisc::error_quit("Step 1 failed to find the reference file database. Aborting") if (! defined($db));
print "Info: dbDir = $db\n";
MMisc::error_quit("Step 1 failed to find the IndusCorporaDefs file in the dbDir $db, Aborting") if (! defined($indusCorporaDefsFile));
my $indusCorporaDefs = undef;
eval `cat $indusCorporaDefsFile`;
MMisc::error_quit("Step 1 failed to load $indusCorporaDefsFile successfully.  Aborting") if (! defined($indusCorporaDefs));
my $reqIDB = 3;
MMisc::error_quit("Step 1 failed: IndusDB too old.  Must be > $reqIDB.  Aborting") if (!exists ($indusCorporaDefs->{versionID}));
MMisc::error_quit("Step 1 failed: IndusDB too old.  Must be > $reqIDB.  Aborting") if ($indusCorporaDefs->{versionID} < $reqIDB);
print "Info: indusCorporaDefsFile = $indusCorporaDefsFile version '".$indusCorporaDefs->{version}."'\n";

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
sub copySystemDescription{
  my ($sdesc, $dir) = @_;

  if ($sdesc ne ""){
    if (-f $sdesc){
      system "mkdir -p $dir/SystemDescription";
      system "cp $sdesc $dir/SystemDescription";
    } else {
      _warn_add("System description defined /$sdesc/, but does not exist");
    }  
  }
}

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
  
  my $compRoot = "$scrdir/$def->{outputRoot}";
  my $extendedCompRoot = "$scrdir-Extended/$def->{outputRoot}";

  ### Check the preferred Scoring attributes
#  print "    Check of run ".$def->{"runDesc"}."\n";
  foreach my $attr(keys %{ $def->{"RunAttributes"} }){
#    print "       Check $attr $preferredScoring->{$attr} =~ $def->{RunAttributes}{$attr}\n"; 
    if (exists($preferredScoring->{$attr})){
      if ($def->{"RunAttributes"}{$attr} !~ /$preferredScoring->{$attr}/){
#         print "          Run Attribute $attr=/".$def->{"RunAttributes"}{$attr}."/ does not match definition.  Skipping\n";
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
  my $usedCompRoot = (! defined($extendedRunIndusDataDef)) ? $compRoot : $extendedCompRoot;
  $com .= " $kwseval -I \"$def->{systemDesc}\" ".
    " -iso ''".
    " -e $def->{ECF}".
    " -r $def->{RTTM}".
    " -t $def->{KWLIST}".
    " -s $def->{KWSLIST}".
    " $def->{KWSEVAL_OPTS}{$lscase}".
    " -f $usedCompRoot".
    " -y TXT -y HTML";
  $com .= " --XmllintBypass" if ($bypassxmllint);
  $com .= " --ExcludePNGFileFromTxtTable" if ($xpng);

  my $__run = 1;
  $__run = 0 if (-f "$compRoot.log");
  if (defined($extendedRunIndusDataDef)){
     $__run = 0 if (-f "$extendedCompRoot.log");
  }
  if ($__run){
    my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.log", $com);
    MMisc::writeTo("$compRoot.sh", "", 0, 0, "$com\n");
    MMisc::error_quit("Scoring execution ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);
  } else {
    print "Skipping execution\n";
  } 
  
  MMisc::writeTo($readme, "", 0, 1, "\n");
  if (!defined($extendedRunIndusDataDef)){
    print "  Execution completed.  Copying to results\n";
    copyToResult($scrdir, $resdir, $def->{outputRoot}, $def->{RESULTS}{$scase});
  } else {
    print "  Execution completed.  Not Copying to Results because Extended Scoring requested\n";
  }
  return("complete");
}

sub execSTTScoreRun{
  my ($def, $scase, $readme) = @_;
  
  my $compRoot = "$scrdir/$def->{outputName}";

  print "\nStep 2: STT scoring execution ".$def->{runID}.": Scase $scase: ".$def->{runDesc}."\n";

  MMisc::error_quit("Problem with scoring case.  Results copy not defined") if (! exists($def->{RESULTS}{$scase}));

  ### Check the SCLITE Version
  my $minScliteVersionNum = 2.7;
  my @scliteVersion=grep { $_ =~ /sclite Version:/ } split(/\n/,`$sclite 2>&1 `);
  MMisc::error_quit("SCLITE Version check failed: Not able to exec sclite and get the version tag") if (@scliteVersion != 1);
  MMisc::error_quit("SCLITE Version check failed: Not able to parse sclite version tag /$scliteVersion[0]/") 
     if ($scliteVersion[0] !~ /sclite Version:\s+(\d+(\.\d+)+)/);
  my $scliteVersionNum = $1;
  MMisc::error_quit("SCLITE Version check failed: Minmum version $minScliteVersionNum higher that available version $scliteVersionNum")
     if ($minScliteVersionNum > $scliteVersionNum); 

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
  my $GLM = undef;
  for (my $i = 0; $i < scalar @dbDir; $i++) {
    my $_tmp_GLM = $dbDir[$i] . "/babel$lang.glm";
    $err = MMisc::check_file_r($_tmp_GLM);
    if (MMisc::is_blank($err)){
      $GLM = $_tmp_GLM;
      last;
    }
  }
  if (defined $GLM){
    print "  GLM $GLM exists and will be used\n";
  } else {
    print "  GLM $GLM not found.  No filtering will occur\n";
  }

  MMisc::writeTo($readme, "", 0, 1, "STT Scoring ".$def->{runID}.": Scase $scase: ".$def->{runDesc}."\n   Output file root name: $def->{outputName}\n");

  ### Check the Input files to make sure the exist
  foreach my $file ("STM", "SYS"){
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
  my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.ctm.sort.log", $com);
  MMisc::error_quit("CTM Sorting execution failed ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);

  $com = "$hubscore sortSTM < $def->{STM} > $def->{CTM}.ref.sort";
  MMisc::writeTo("$compRoot.sh", "", 0, 1, "$com\n");
  my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.stm.sort.log", $com);
  MMisc::error_quit("CTM Sorting execution failed ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);

  my $ctmFile = "$def->{CTM}.sort";
  my $stmFile = "$def->{CTM}.ref.sort";
  
  if (defined($GLM)){
    $com = "$csrfilt -i ctm $GLM < $def->{CTM}.sort > $def->{CTM}.filter "; 
    MMisc::writeTo("$compRoot.sh", "",0, 1, "$com\n");
    my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$compRoot.filter.log", $com);
    MMisc::error_quit("CTM Filter execution failed ".$def->{runID}." returned $ret. Aborting") if ($retcode != 0);
    $ctmFile = "$def->{CTM}.filter";

    $com = "$csrfilt -i stm $GLM < $def->{CTM}.ref.sort > $def->{CTM}.ref.filter "; 
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
    " -D -F".
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
  my $compRoot = "$scrdir";
  my $extendedCompRoot = "$scrdir-Extended";
  
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
    my $foundSrl = 0;
    my $stype = ($def->{scoreDefs}->{$sdef}{RunAttributes}{"KWSProtocol"} eq "Occur" ? "Occurrence" : "Segment");
    my $srl = "$compRoot/$def->{scoreDefs}{$sdef}{outputRoot}.dets/sum.$stype.srl.gz";
    $foundSrl = 1 if (-f $srl);
    if (! $foundSrl && defined($extendedRunIndusDataDef)){
      $srl = "$extendedCompRoot/$def->{scoreDefs}{$sdef}{outputRoot}.dets/sum.$stype.srl.gz";
      $foundSrl = 1 if (-f $srl);
    }
    $use = 0 unless($foundSrl);
    
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

  my $usedCompRoot = (! defined($extendedRunIndusDataDef)) ? $compRoot : $extendedCompRoot;

  if (! -f "$usedCompRoot/$def->{ensembleRoot}.png"){ 
    $com = "$detutil $def->{DETOPTIONS}{$scase} --generateCSV --txtTable -I -Q 0.3 -T '$mainTitle' --plot ColorScheme=colorPresentation";
    $com .= ($xpng == 1) ? " --ExcludePNGFileFromTxtTable" : "";
    $com .= " -o $usedCompRoot/$def->{ensembleRoot}.png ";
    $com .= join(" ",@srls);
    MMisc::writeTo("$usedCompRoot/$def->{ensembleRoot}.sh", "", 0, 0, "$com\n");
    my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) = MMisc::write_syscall_logfile("$usedCompRoot/$def->{ensembleRoot}.log", $com);
    MMisc::error_quit("DETUtil ".$def->{ensembleID}." failed returned $ret. Aborting") if ($retcode != 0);    
  } else {
    print "Skipping previously completed execution\n";
  }

  if (!defined($extendedRunIndusDataDef)){
    print "  Execution completed.  Copying to results\n";
    copyToResult($usedCompRoot, $resdir, $def->{ensembleRoot}, $def->{RESULTS}{$scase});
  } else {
    print "  Execution completed.  Not Copying to Results because Extended Scoring requested\n";
  } 
}

### ROOT is going to be
###   Occur | InfSeg -> scoring type
###   AppInterp | AppSeg | MITLLFA -> reference time mark derivation
###   AppWordSeg | SplitChar -> Style of transcript 

### Look up the preferred scoring settings for the language
MMisc::error_quit("Step 1 failed to find the preferred scoring options in indusCorporaDefsFile for $languageID in the dbDir.  Aborting") 
   if (! exists($indusCorporaDefs->{languages}{$languageID}));

my $preferredScoring = $indusCorporaDefs->{languages}{$languageID};
#print Dumper($preferredScoring); 
foreach my $__req("KWSProtocol", "TokTimes", "TokSeg", "Set", "STTOptions"){
   MMisc::error_quit("Step 1 failed: $__req not defined in IndusCorpusDefs for $languageID.  Aborting") 
      if (! exists($preferredScoring->{$__req}));
   if ($__req ne "STTOptions"){
     print "Info: indusCorporaDefsFile for $languageID: $__req => $preferredScoring->{$__req}\n";
   } else {
     foreach my $__req__stt(keys %{ $preferredScoring->{$__req} }){
       print "Info: indusCorporaDefsFile for $languageID: $__req\{$__req__stt\} => $preferredScoring->{$__req}{$__req__stt}\n";
     }
   }
}

if ($ltask =~ /KWS/){
  print "Beginning $ltask scoring\n";

  my %RunDefs = ();  
  ### Make the run structures via foreac
  foreach my $setID(sort keys % {$indusCorporaDefs->{sets}}){
    my ($setStr) = $indusCorporaDefs->{sets}{$setID}{Desc};
    my $ecf = $indusCorporaDefs->{sets}{$setID}{ECF};
    
    foreach my $protocolDEF("Occur:Occurrence scoring", "InfSeg:Inferred Segment scoring"){
      my ($protocolID, $protocolStr) = split(/:/, $protocolDEF);
      my ($proto) = {"Occur" => "-c -o -b -d",
                     "InfSeg" => "-c -o -b -d -g"};
 
      foreach my $tokTimesDEF("AppenInterp:Uniform Appen times", "MITLLFA2:MITLL Force Ali. V2", "MITLLFA3:MITLL Force Ali. V3", "STD06FA:STD06 Force Aligment Times"){
        my ($tokTimesID, $tokTimesStr) = split(/:/, $tokTimesDEF);
        my $rttms = {"AppenInterp" => "$db/${lcorpus}_${lpart}.rttm",
                     "MITLLFA2" => "$db/${lcorpus}_${lpart}.mitllfa2.rttm",
                     "MITLLFA3" => "$db/${lcorpus}_${lpart}.mitllfa3.rttm",
                     "STD06FA" => "$db/${lcorpus}_${lpart}.std06FA.rttm"};

        foreach my $tokSegDEF("AppenWordSeg:Original orthography", "SplitCharText:Split character texts"){
          my ($tokSegID, $tokSegStr) = split(/:/, $tokSegDEF);
          my ($tokSegs) = {"AppenWordSeg" => "",
                           "SplitCharText" => "-x charsplit -x deleteHyphens -x notASCII"};

          my $runID = "$setID-$protocolID-$tokTimesID-$tokSegID";
          my $def = { "runID" => "$runID"};
          $def->{"runDesc"} = "$setStr, $protocolStr, $tokTimesStr, $tokSegStr";
          $def->{"systemDesc"} = "$lsysid $lversion: $lcorpus $lpart - $setStr";
          $def->{"KWSLIST"} = $sysfile;
          my ($err, $n_tlist) = 
            KWSEval_SCHelper::check_kwslist_kwlist($sysfile, $bypassxmllint, @dbDir);
          MMisc::error_quit("Problem with KWSList's KWList entry: $err")
              if (! MMisc::is_blank($err));
          $n_tlist =~ s%^.+\.(kwlist\d*\.xml)$%$1%i;
          $def->{"KWLIST"} = "$db/${lcorpus}_${lpart}.annot.$n_tlist";
          $def->{"ECF"} = $ecf;
          $def->{"RTTM"} = $rttms->{$tokTimesID};
          $def->{"outputRoot"} = $runID;
          $def->{"KWSEVAL_OPTS"} = { "BaDev" =>  $proto->{$protocolID}." ".$tokSegs->{$tokSegID}." -a --ExcludePNGFileFromTxtTable",
                                     "BaEval" => $proto->{$protocolID}." ".$tokSegs->{$tokSegID}." -a --ExcludePNGFileFromTxtTable --ExcludeCountsFromReports" };
          $def->{"RESULTS"} = {"BaDev" => $indusCorporaDefs->{sets}{$setID}{KWS}{BaDev},
                               "BaEval" => $indusCorporaDefs->{sets}{$setID}{KWS}{BaEval}};
          $def->{"filePreReq"} = [ ];
          push @{ $def->{"filePreReq"} }, $ecf if ($setID ne "Full");  ### Non-Full is optional
          push @{ $def->{"filePreReq"} }, $rttms->{$tokTimesID} if ($tokTimesID ne "MITLLFA3");  ### Non-Full is optional

          $def->{"RunAttributes"} = {"Set" => $setID,  "KWSProtocol" => $protocolID,  "TokTimes" => $tokTimesID,  "TokSeg"=> $tokSegID};
          $def->{"RunAttributeStr"}={"Set" => $setStr, "KWSProtocol" => $protocolStr, "TokTimes" => $tokTimesStr, "TokSeg"=> $tokSegStr};
          
          $RunDefs{$runID} = $def;
          }
      }
    }
  }
#  print Dumper(\%RunDefs);
  copySystemDescription($sysdesc, $scrdir);

  ## Interate of the DEFS
  my $readme = "$scrdir/Readme.txt";             
  ### Add some content to the README
  MMisc::writeTo($readme, "", 0, 0, "Program: $versionid\n");  ## Initial erase
  MMisc::writeTo($readme, "", 0, 1, "Date: ".`date`);
  MMisc::writeTo($readme, "", 0, 1, join("\n",@parseInfo)."\n");
  MMisc::writeTo($readme, "", 0, 1, "\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
  MMisc::writeTo($readme, "", 0, 1,   "!!!  These results (all files and content) are FOUO until they have been vetted for release.  !!!\n");
  MMisc::writeTo($readme, "", 0, 1,   "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n");
 
#  execKWSScoreRun($kwRun1, $lscase, $readme, $preferredScoring);
  my @completed = ();
  foreach my $defKey(sort keys %RunDefs){
    my $status = execKWSScoreRun($RunDefs{$defKey}, $lscase, $readme, $preferredScoring); 
    push (@completed, $defKey) if ($status eq "complete");
  }

  print "\nCompleted KWS Runs:\n   ".join("\n   ",@completed)."\n";
 
  my $detOpts = " --plot 'ExtraPoint=Team = $lteam:.004:.12:0:1::' ";
    $detOpts .= " --plot 'ExtraPoint=System = ${lsysid}_${lversion}:.004:.10:0:1::' ",;
    $detOpts .= " --plot 'ExtraPoint=Data = $lcorpus $lpart:.004:.0805:0:1::' ";
    $detOpts .= " --plot 'ExtraPoint=SHA256 = $sha256:.004:.062:0:1::' " if ($sha256 ne "");

  execKWSEnsemble2({scoreDefs => \%RunDefs,
                    selectDefs => { "Set" => ".*", "TokTimes" => ".*",
                                    "TokSeg" => ".*", "KWSProtocol" => "Occur"},
                    ensembleID => "Ensemble.AllOccur",
                    ensembleRoot => "Ensemble.AllOccur",
                    ensembleTitle => "All Occurrence Scorings",
                    DETOPTIONS => { "BaDev" => $detOpts,
                                    "BaEval" => "$detOpts  --ExcludePNGFileFromTxtTable --ExcludeCountsFromReports"},                                    
                    RESULTS => {
                       "BaDev" =>  [  "\\.log", "\\.sh", ".png", ".results.txt"],
                       "BaEval" => [  "\\.log", "\\.sh", ".png", ".results.txt"],
                    }
                  },
                  $lscase, $readme);
  
  print "\nStep 4: Cleanup\n";
  print "  Scoring completed.  Copying readme and system description\n";
  copyToResult($scrdir, $resdir, "Readme", [ ".txt" ]);
  copySystemDescription($sysdesc, $resdir);
} elsif ($ltask =~ /STT/){
  print "Beginning $ltask scoring\n";

  my $sttRun1 = { "runID" => "Run1",
               "runDesc" => "Full submission - Word based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Full Set",
               "filePreReq" => [ ],
               "outputName" => "FullSet-WER",
               "STM" => "$db/${lcorpus}_${lpart}.stm",
               "SYS" => $sysfile,
               "SCLITE_OPTS" => $preferredScoring->{"STTOptions"}{"encoding"},
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt",                               ],
               }
             };
             
  my $sttRun2 = { "runID" => "Run2",
               "runDesc" => "Full submission - Char based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Full Set",
               "filePreReq" => [ ],
               "outputName" => "FullSet-CER",
               "STM" => "$db/${lcorpus}_${lpart}.stm",
               "SYS" => $sysfile,
               "SCLITE_OPTS" => "-c NOASCII DH ". $preferredScoring->{"STTOptions"}{"encoding"},
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt",                               ],
               }
             };

  my $sttRun3 = { "runID" => "Run3",
               "runDesc" => "Dev subset - Word based",
               "systemDesc" => "$lteam ${lsysid}_$lversion $lcorpus-$lpart $ltrncond - Dev Subset",
               "filePreReq" => [ "$db/${lcorpus}_${lpart}.dev.stm" ],
               "outputName" => "DevSubset-WER",
               "STM" => "$db/${lcorpus}_${lpart}.dev.stm",
               "SYS" => $sysfile,
               "SCLITE_OPTS" => $preferredScoring->{"STTOptions"}{"encoding"},
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
               "SCLITE_OPTS" => "-c NOASCII DH ". $preferredScoring->{"STTOptions"}{"encoding"},
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
               "SCLITE_OPTS" =>  $preferredScoring->{"STTOptions"}{"encoding"},
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
               "SCLITE_OPTS" => "-c NOASCII DH ". $preferredScoring->{"STTOptions"}{"encoding"},
               "RESULTS" => {
                 "BaDev"  => [  "\\.sh", "\\.sys.txt", "\\.raw.txt", "\\.dtl.txt", "\\.prf.txt", "\\.sgml"],
                 "BaEval" => [  "\\.sh", "\\.sys.txt", "\\.raw.txt"                               ],
               }
             };
             
  my $readme = "$scrdir/Readme.txt";             
  my $sttMesg = "Contents: This directory contains STT scoring reports.  The file is organized by sets of the results organized\n".
                "          by the following file prefixes.  Not all prefixes will exist depending on the dataset scored.\n".
                "\n".
                "          FullSet_Word - Word based scoring on the full data set\n".
                "          FullSet_Char - Character based scoring on the full data set\n".
                "          DevSubset_Word - Word based scoring on the (10 hr.) Development subset.\n".
                "          DevSubset_Char - Character based scoring on the (10 hr.) Development subset.\n".
                "          DevProgSubset_Word - Word based scoring on the (5 hr.) Development Progress subset.  No transcripts will be provided\n".
                "          DevProgSubset_Char - Character based scoring on the (5 hr.) Development Progress subset.  No transcripts will be provided\n".
                "\n".
                "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n".
                "!!!  These results (all files and content) are FOUO until they have been vetted for release.  !!!\n".
                "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n".
                "\n";
  MMisc::writeTo($readme, "", 0, 0, "Program: $versionid\n");  ## Initial erase
  MMisc::writeTo($readme, "", 0, 1, "Date: ".`date`);
  MMisc::writeTo($readme, "", 0, 1, join("\n",@parseInfo)."\n");
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

if (MMisc::all_blank($pendingfile, $releasefile) == 0) {
  if (grep(m%^$lscase$%, @Scase_toSequester)) {
    MMisc::error_quit("Could not create \'FilePending\' file ($pendingfile)")
        if (! MMisc::writeTo($pendingfile));
  } else {
    MMisc::error_quit("Could not create \'FileRelease\' file ($releasefile)")
        if (! MMisc::writeTo($releasefile));
  }
}

MMisc::ok_exit();

############################################################

sub set_usage {
  my $usage = "$0 [--version | --help] [--Verbose] [--KWSEval tool [--XmllintBypass] [--ExcludePNGFileFromTxtTable]] [--DETUtil tool] [--Tsctkbin dir] [--Hsha256id sha] [--fileCreate file [--fileCreate file [...]]] [--tSystemDescription file] [--mSystemMeta file] [--ProcGraph tool] [--ExpectedTeamName TEAM] --Specfile perlEvalfile [--ForceSpecfile [perlEvalfile]] --expid EXPID --sysfile file --compdir dir --resdir dir --dbDir dir [--dbDir dir [...]] [--FilePending file --FileRelease file]\n";
  $usage .= "\n";
  $usage .= "Will score a submission file against data present in the dbDir.\n";
  $usage .= "\nThe program needs a \'dbDir\' to load some of its eval specific definitions; this directory must contain pairs of <CORPUSID>_<PARTITION> \".ecf.xml\" and \".kwlist.xml\" files that match the component of the EXPID to confirm expected data validity, as well as a <CORPUSID>_<PARTITION> directory containing reference data needed for scoring.\n";
  $usage .= "\n";
  $usage .= "  --version    Display tool version\n";
  $usage .= "  --help       Display this help message\n";
  $usage .= "  --Verbose    Be more verbose\n";
  $usage .= "  --KWSEval    Location of the KWSEval tool (default: $kwseval)\n";
  $usage .= "  --XmllintBypass      Bypass xmllint check of the KWSList XML file (this will reduce the memory footprint when loading the file, but requires that the file be formatted in a way similar to how \'xmllint --format\' would)\n";
  $usage .= "  --ExcludePNGFileFromTxtTable  Exclude PNG files loaction from output text tables\n";
  $usage .= "  --DETUtil    Location of the DETUtil tool (default: $detutil)\n";
  $usage .= "  --Hsha256id  SHA256 ID\n";
  $usage .= "  --fileCreate   If requested, once succesfully run, will create the file before exiting with success (: separated or multiple can be specified)\n";
  $usage .= "  --ProcGraph  Location of the ProcGraph tool.  If defined ProcGraph will be run. (default: UNDEF)\n";
  $usage .= "  --ExpectedTeamName  Expected value of TEAM (used to check EXPID content)\n";
  $usage .= "  --Tsctkbin   Location of SCTK's bin directory\n";
  $usage .= "  --tSystemDescription   System description file\n";
  $usage .= "  --mSystemMeta        System metadata file\n";
  $usage .= "  --Specfile   Configuration file containing EXPID definition (note: if a specfile with the same filename is found in a dbDir, this specialized version will be used unless --ForceSpecfile is used)\n";
  $usage .= "  --ForceSpecfile  Force the use of the default specfile if no value is provided, or the selected file is provided (overriding the dbDir lookup)\n";
  $usage .= "  --sysfile    System input file\n";
  $usage .= "  --compdir    Directory where computation can be performed\n";
  $usage .= "  --resdir     Directory that will be returned to participants\n";
  $usage .= "  --dbDir      Directory containing ECF, TLIST, RTTM files (: separated or multiple can be specified)\n";
  $usage .= "  --FilePending  Specify the file that will be created if a <SCASE> is listed in the configuration file as to be sequestered, until authorized for release\n";
  $usage .= "  --FileRelease  Specify the file that will be created if a <SCASE> is not listed in the configuration file as to be sequestered\n";
  $usage .= "  --extendedRunIndusDataDef  Specify an alternate IndusDataDef file.  This changes the behavior to:\n";
  $usage .= "           (1) Existing runs in Computation directory are linked into to Computation-Extended.\n";
  $usage .= "           (2) Additional computations are stored in Computation-Extended.\n";
  $usage .= "           (3) No Resuls directory is made.\n";

  $usage .= "\n";
  
  return($usage);
}
