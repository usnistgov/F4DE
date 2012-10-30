package KWSecf;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# KWSEval
# KWSecf.pm
#
# Original Author: Jerome Ajot
# Extensions: Martial Michel
# 
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
#
# $Id$

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "KWSecf.pm Version: $version";

##

use KWSecf_excerpt;

require File::Spec;
use Data::Dumper;

use MMisc;
use xmllintHelper;
use MtXML;

##########
my @ecf_attrs = ('source_signal_duration', 'version', 'language');
my @exc_attrs = ('audio_filename', 'channel', 'tbeg', 'dur', 'source_type');
#####

sub __init {
  my $self = shift;
  my $ecffile = shift;

  $self->{FILE} = $ecffile;
  $self->{SIGN_DUR} = 0.0;
  $self->{EVAL_SIGN_DUR} = 0.0;
  $self->{LANGUAGE} = "";
  $self->{VER} = "";
  $self->{EXCERPT} = ();
  $self->{FILECHANTIME} = {};
  $self->{FILE_EVAL_SIGN_DUR} = {};

  # Added to avoid overwriting in file load
  $self->{LoadedFile} = 0; # 0 not loaded
  $self->{LoadInProgress} = 0; 
  # File handles & related variables
  $self->{FH} = undef;
  $self->{linec} = 0;
  $self->{SEfile} = undef;
}

sub new {
  my $class = shift;
  my $ecffile = shift;
  my $self = {};

  bless $self;
  $self->__init($ecffile);
  my $err = "";
  $err = $self->loadFile($ecffile) if (defined($ecffile));
  MMisc::error_quit($err) if (! MMisc::is_blank($err));
  
  return $self;
}

sub new_empty {
  my $class = shift;
  my $ecffile = shift;
  my $self = {};
  
  bless $self;
  $self->__init($ecffile);

  return $self;
}

sub getFile
{
   my $self = shift;
   return($self->{FILE});
}

sub calcTotalDur
{
  my ($self, $srctypes, $filechans) = @_;
  #only include excerpts included in @$srctypes and @$filechans
  my %excerpts = ();
 EXBUILDER: foreach my $excerpt (@{ $self->{EXCERPT} }) {
    #Filter source type
    if ($srctypes) { 
      for (my $i; $i < @{ $srctypes }; $i++) {
	my $srctype = $excerpt->{SOURCE_TYPE};
	last if ($srctype =~ /^@{ $srctypes }[$i]$/i);
	next EXBUILDER if ($i == scalar(@{ $srctypes }) -1);
      }
    }
    #Filter filechan
    if ($filechans) {
      for (my $i; $i < @{ $filechans }; $i++) {
	my $filechan = $excerpt->{FILE} . "/" . $excerpt->{CHANNEL};
	last if ($filechan =~ /^@{ $filechans }[$i]$/i);
	next EXBUILDER if ($i == scalar(@{ $filechans }) -1);
      }
    }
    push (@{ $excerpts{$excerpt->{FILE}} }, $excerpt);
  }

  my $TotDur = 0.0;
  foreach my $file (keys %excerpts) {
    #Sort excerpts by begin time
    my @sortedExs = sort {$a->{TBEG} <=> $b->{TBEG} || $a->{TEND} <=> $b->{TEND}} @{ $excerpts{$file} };
    for (my $i; $i < @sortedExs; $i++) {
      my $TEND = $sortedExs[$i]->{TEND};
      for (my $j = $i+1; $j < @sortedExs; $j++) {
	$TEND = $sortedExs[$j]->{TBEG} if ($sortedExs[$j]->{TBEG} < $TEND);
      }
      my $dur = ($TEND - $sortedExs[$i]->{TBEG});
      $TotDur += $dur * ($sortedExs[$i]->{SOURCE_TYPE} eq "splitcts" ? 0.5 : 1)
    }
  }
  return ($TotDur);
}

sub unitTest
{
    my ($file1) = @_;

    my $err = MMisc::check_file_r($file1);
    if (! MMisc::is_blank($err)) {
      print "Issue with needed test file ($file1) : $err\n";
      return(0);
    }

    print "Test ECF\n";

    print " Loading File ($file1)...          ";
    my $ecf = new KWSecf($file1);
    print "OK\n";
    
    print " Filtering 'file'...      ";
    if($ecf->FilteringTime("ar_4489_exA", 1, 1000.0, 1001.0) == 0)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    } 
    
    print " Filtering 'channel'...   ";
    if($ecf->FilteringTime("20010223_1530_1600_NTV_ARB_exA", 1, 1000.0, 1001.0) == 1)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }   
    
    print " Filtering 'in'...        ";
    if($ecf->FilteringTime("20010217_0000_0100_VOA_ARB_exA", 1, 0.0, 1.0) == 1)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }
    
    print " Filtering 'out'...       ";
    if($ecf->FilteringTime("20010217_0000_0100_VOA_ARB_exA", 1, 2000.0, 2001.0) == 0)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }
    
    print " Filtering 'part in'...   ";
    if($ecf->FilteringTime("20010217_0000_0100_VOA_ARB_exA", 1, 1000.0, 2001.0) == 0)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }
    
    print " Filtering 'multi-seg'... ";
    if( ($ecf->FilteringTime("ar_4758_exA", 2, 350.0, 351.0) == 0) && 
        ($ecf->FilteringTime("ar_4758_exA", 2, 300.0, 300.1) == 1) &&
        ($ecf->FilteringTime("ar_4758_exA", 2, 500.0, 501.0) == 1) )
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }

    print " Calculating total duration(1)... ";
    my ($dur) = $ecf->calcTotalDur();
    if (abs($dur - 8997.148) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print " Calculating total duration(2)... ";
    ($dur) = $ecf->calcTotalDur(["bnews"]);
    if (abs($dur - 3570.363) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print " Calculating total duration(3)... ";
    ($dur) = $ecf->calcTotalDur([], ["^.*_ARB_.*\/[12]", "ar_4489_exA\/[12]"]);
    if (abs($dur - 3870.853) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print " Calculating total duration(4)... ";
    ($dur) = $ecf->calcTotalDur(["cts"]);
    if (abs($dur - 4426.785) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print " Calculating total duration(5)... ";
    ($dur) = $ecf->calcTotalDur(["splitcts"]);
    if (abs($dur - 1000.000) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }


    print "All tests OK\n";
    return 1;
}

sub toString
{
    my ($self) = @_;

    print "Dump of ECF File\n";
    print "   File: " . $self->{FILE} . "\n";
    print "   Signal duration: " . $self->{SIGN_DUR} . "\n";
    print "   Language: " . $self->{LANGUAGE} . "\n";
    print "   Version: " . $self->{VER} . "\n";
    print "   Excerpt:\n";
    
    for (my $i=0; $i<@{ $self->{EXCERPT} }; $i++)
    {
        print "    ".$self->{EXCERPT}[$i]->toString()."\n";
    }
}

########################################

sub __SEcheck {
  my $txt = MMisc::slurp_file($_[0]->{SEfile});
  if (! MMisc::is_blank($txt)) {
    return($txt) if (! ($txt =~ m%validates%gi));
  }
  return("");
}

#####

sub __get_attr {
  my ($rh, $key) = @_;

  MMisc::error_quit("Requested hash key does not exists ($key)")
      if (! exists $$rh{$key});

  return($$rh{$key});
}

#####

sub openXMLFileAccess {
  my ($self, $ecf) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);
  return("Refusing to load a file on top of a stream already in progress")
    if ($self->{LoadInProgress} != 0);

 my $err = MMisc::check_file_r($ecf);
  return("Problem with input file ($ecf): $err")
    if (! MMisc::is_blank($err));

  $self->{FILE} = $ecf;

  my $modfp = MMisc::find_Module_path('KWSecf');
  return("Could not obtain \'KWSecf.pm\' location, aborting")
      if (! defined $modfp);

  my $f4b = 'F4DE_BASE';
  my $xmllint_env = "F4DE_XMLLINT";
  my $xsdpath = (exists $ENV{$f4b}) ? $ENV{$f4b} . "/lib/data" : $modfp . "/../../KWSEval/data";
  my @xsdfilesl = ('KWSEval-ecf.xsd');

  # First let us use xmllint on the file XML file
  my $xmlh = new xmllintHelper();
  my $xmllint = MMisc::get_env_val($xmllint_env, "");
  return("While trying to set \'xmllint\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xmllint($xmllint));
  return("While trying to set \'xsdfilesl\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdfilesl(@xsdfilesl));
  return("While trying to set \'Xsdpath\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdpath($xsdpath));

#  print STDERR "Loading ECF file '$ecf'.\n";
  
  (local *ECFFH, my $sefile) = $xmlh->run_xmllint_pipe($ecf);
  return("While trying to ECF file ($ecf) : " . $xmlh->get_errormsg() )
    if ($xmlh->error());

  $self->{FH} = *ECFFH;
  $self->{SEfile} = $sefile;

  my $doit = 1;
  # Load the header
  while ($doit == 1) {
    my $se_err = $self->__SEcheck();
    return("Problem with validation: $se_err")
      if (! MMisc::is_blank($se_err));

    if (eof(ECFFH)) {
      $doit = -1;
      next;
    }
    my $line = <ECFFH>;
    chomp($line);
    $self->{linec}++;

    my ($err, $closed, $name, $content, %vals) = MtXML::line_extractor($line);
    return("Problem processing File Access: $err")
      if (! MMisc::is_blank($err));
    
    next if ($name eq "");

    if ($name eq 'ecf') {
      $self->{SIGN_DUR} = &__get_attr(\%vals, $ecf_attrs[0]);
      $self->{VER}      = &__get_attr(\%vals, $ecf_attrs[1]);
      $self->{LANGUAGE} = &__get_attr(\%vals, $ecf_attrs[2]);
      $doit = 0; # we are done reading the header
      next;
    }

    return("Invalid content: $line");
  }

  if ($doit == -1) {
    # Reached EOF already ?
    my $se_err = $self->__SEcheck();
    return("Problem with validation: $se_err")
      if (! MMisc::is_blank($se_err));
    
    return("Reached EOF in header ?");
  }

  $self->{LoadInProgress} = 1;
  return("");
}

#####

sub getNextExerpt {
  my ($self) = @_;

  return("Can not process, no loading in progress", undef)
    if ($self->{LoadInProgress} == 0);
  
  local *ECFFH = $self->{FH};
  my %attrib = ();
  my ($attr_name, $attr_value) = ("", "");
  my $doit = 1;
  my $kwex = undef;
  while ($doit == 1) {
     my $se_err = $self->__SEcheck();
    return("Problem with validation: $se_err", undef)
      if (! MMisc::is_blank($se_err));      

    if (eof(ECFFH)) {
      $doit = -1;
      next;
    }
    my $line = <ECFFH>;
    chomp($line);
    $self->{linec}++;
    
    my ($err, $closed, $name, $content, %vals) = MtXML::line_extractor($line);
    return("Problem processing File Access: $err", undef)
      if (! MMisc::is_blank($err));
#    print "{$name} [$line]\n";

    next if ($name eq "");
    
    if ($name eq 'excerpt') {
      my $audio_filename = &__get_attr(\%vals, $exc_attrs[0]);
      my $channel = &__get_attr(\%vals, $exc_attrs[1]);
      my $tbeg = &__get_attr(\%vals, $exc_attrs[2]);
      my $dur = &__get_attr(\%vals, $exc_attrs[3]);
      my $source_type = &__get_attr(\%vals, $exc_attrs[4]);

      my $purged_filename = "";
      my ($errf, $d, $f, $e) = MMisc::split_dir_file_ext($audio_filename);
      if (($e eq 'sph') || ($e eq 'wav')) {
        $purged_filename = $f;
      } else {
        $purged_filename = MMisc::concat_dir_file_ext('', $f, $e);
      }
      
      $self->{EVAL_SIGN_DUR} += sprintf("%.4f", $dur) 
        if (! MMisc::safe_exists(\%{$self->{FILECHANTIME}}, $purged_filename));

      $kwex = new KWSecf_excerpt($audio_filename, $channel, $tbeg, $dur, $self->{LANGUAGE}, $source_type);
      push @{$self->{EXCERPT}}, $kwex;

      ### Track the source types for the reports
      push @{$self->{FILECHANTIME}{$purged_filename}{$channel}}, [ ($tbeg, $tbeg + $dur) ];
        
      $self->{FILE_EVAL_SIGN_DUR}{$purged_filename} = 0 
        if (! $self->{FILE_EVAL_SIGN_DUR}{$purged_filename});
      $self->{FILE_EVAL_SIGN_DUR}{$purged_filename} += sprintf("%.4f", $dur);

      $doit = 0 if ($closed);
      next;
    }

    # Unprocessed content
    next if (substr($name, 0, 1) eq '/');
    return("UNKNOWN Line: $line", undef);
  }
  
  if ($doit == -1) { # EOF
    my $se_err = $self->__SEcheck();
    return($se_err, undef) if (! MMisc::is_blank($se_err));
    $self->{LoadedFile} = 1;
    $self->{LoadInProgress} = 0;
    close ECFFH;
    $self->{FH} = undef;
    $self->{SEfile} = undef;
    return("", undef);
  }

  return("", $kwex);
}

##########

sub loadXMLFile {
  my ($self, $ecf) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);

  # First: open the file access to read the header
  my $err = $self->openXMLFileAccess($ecf);
  return($err) if (! MMisc::is_blank($err));
  
  my $doit = 1;
  while ($doit) {
    # Then process each 'excerpt' at a time
    my ($lerr, $kwex) = $self->getNextExerpt();
    # any error while reading ?
    return($lerr) if (! MMisc::is_blank($err));
    # Stop processing when the last entry processed is undefined
    $doit = 0 if (! defined $kwex);
  }

  return("");
}

#####

sub element_extractor_check {
  my ($dem, $string, $here, $rattr) = @_;

  $string = MMisc::clean_begend_spaces($string);

  (my $err, $string, my $section, my %iattr) = MtXML::element_extractor($dem, $string, $here);
  return($err) if (! MMisc::is_blank($err));

  foreach my $attr (@$rattr) {
    return("Could not find <$here>'s $attr attribute")
      if (! exists $iattr{$attr});
  }

  return("", $string, $section, %iattr);
}

##############################

sub saveFile {
  my ($self, $fn) = @_;
  
  my $to = MMisc::is_blank($fn) ? $self->{FILE} : $fn;
  # Re-adapt the file name to remove all ".memdump" (if any)
  $to = &_rm_mds($to);

  my $txt = $self->get_XMLrewrite();
  return(MMisc::writeTo($to, "", 1, 0, $txt));
}

#####

sub get_XMLrewrite {
  my ($self) = @_;
     
  my $txt = "";

  $txt .= "<ecf source_signal_duration=\"$self->{SIGN_DUR}\" language=\"$self->{LANGUAGE}\" version=\"$self->{VER}\">\n";
     
  if ($self->{EXCERPT}) {
    for (my $i=0; $i < @{ $self->{EXCERPT} }; $i++) {
      my $tbegform = sprintf("%.3f", $self->{EXCERPT}[$i]->{TBEG});
      my $tdurform = sprintf("%.3f", $self->{EXCERPT}[$i]->{DUR});
      
      $txt .= "  <excerpt audio_filename=\"$self->{EXCERPT}[$i]->{AUDIO_FILENAME}\" channel=\"$self->{EXCERPT}[$i]->{CHANNEL}\" tbeg=\"$tbegform\" dur=\"$tdurform\" source_type=\"$self->{EXCERPT}[$i]->{SOURCE_TYPE}\"/>\n";
    }
  }
    
  $txt .= "</ecf>\n";
     
  return($txt);
}

########## 'save' / 'load' Memmory Dump functions

my $MemDump_Suffix = ".memdump";

sub get_MemDump_Suffix { return $MemDump_Suffix; }

my $MemDump_FileHeader_cmp = "\#  KWSEval KWSecf MemDump";
my $MemDump_FileHeader_gz_cmp = $MemDump_FileHeader_cmp . " (Gzip)";
my $MemDump_FileHeader_add = "\n\n";

my $MemDump_FileHeader = $MemDump_FileHeader_cmp . $MemDump_FileHeader_add;
my $MemDump_FileHeader_gz = $MemDump_FileHeader_gz_cmp . $MemDump_FileHeader_add;

#####

sub _rm_mds {
  my ($fname) = @_;

  return($fname) if (MMisc::is_blank($fname));

  # Remove them all
  while ($fname =~ s%$MemDump_Suffix$%%) {1;}

  return($fname);
}

#####

sub save_MemDump {
  my ($self, $fname, $mode, $printw) = @_;

  $printw = MMisc::iuv($printw, 1);

  # Re-adapt the file name to remove all ".memdump" (added later in this step)
  $fname = &_rm_mds($fname);

  my $tmp = MMisc::dump_memory_object
    ($fname, $MemDump_Suffix, $self,
     $MemDump_FileHeader,
     ($mode eq "gzip") ? $MemDump_FileHeader_gz : undef,
     $printw);

  return("Problem during actual dump process", $fname)
    if ($tmp != 1);

  return("", $fname);
}

##########

sub _md_clone_value {
  my ($self, $other, $attr) = @_;

  MMisc::error_quit("Attribute ($attr) not defined in MemDump object")
      if (! exists $other->{$attr});
  $self->{$attr} = $other->{$attr};
}

#####

sub load_MemDump_File {
  my ($self, $file) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);

  my $err = MMisc::check_file_r($file);
  return("Problem with input file ($file): $err")
    if (! MMisc::is_blank($err));

  my $object = MMisc::load_memory_object($file, $MemDump_FileHeader_gz);

  $self->_md_clone_value($object, 'FILE');
  $self->_md_clone_value($object, 'SIGN_DUR');
  $self->_md_clone_value($object, 'EVAL_SIGN_DUR');
  $self->_md_clone_value($object, 'LANGUAGE');
  $self->_md_clone_value($object, 'VER');
  $self->_md_clone_value($object, 'EXCERPT');
  $self->_md_clone_value($object, 'FILECHANTIME');
  $self->_md_clone_value($object, 'FILE_EVAL_SIGN_DUR');

  $self->_md_clone_value($object, 'LoadedFile');
  $self->_md_clone_value($object, 'LoadInProgress');
  $self->_md_clone_value($object, 'FH');
  $self->_md_clone_value($object, 'linec');
  $self->_md_clone_value($object, 'SEfile');

  $self->{LoadedFile} = 1;

  return("");
}

#####

sub loadFile {
  my ($self, $ecff) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);
  
  my $err = MMisc::check_file_r($ecff);
  return("Problem with input file ($ecff): $err")
    if (! MMisc::is_blank($err));

  open FILE, "<$ecff"
    or return("Problem opening file ($ecff) : $!");

  my $header = <FILE>;
  close FILE;
  chomp $header;

  return($self->load_MemDump_File($ecff))
    if ( ($header eq $MemDump_FileHeader_cmp)
         || ($header eq $MemDump_FileHeader_gz_cmp) );

  return($self->loadXMLFile($ecff));
}

sub getFileEvalSignalDur(){
  my ($self, $file) = @_;
  return (exists($self->{FILE_EVAL_SIGN_DUR}{$file})) ? $self->{FILE_EVAL_SIGN_DUR}{$file} : undef;
}

sub getFileEvalSignalDurList(){
  my ($self) = @_;
  return (keys %{ $self->{FILE_EVAL_SIGN_DUR} });
}

####################

sub FilteringTime {
  my ($self, $file, $chan, $bt, $et) = @_;
  
  if (MMisc::safe_exists(\%{$self->{FILECHANTIME}}, $file, $chan)) {
    for (my $i=0; $i < @{ $self->{FILECHANTIME}{$file}{$chan} }; $i++) {
      return(1) if ( ($bt >= $self->{FILECHANTIME}{$file}{$chan}[$i][0]) 
                     && ($et <= $self->{FILECHANTIME}{$file}{$chan}[$i][1]) )
    }
  }
    
  return(0);
}

########################################

1;

