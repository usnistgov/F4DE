package KWSList;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# KWSEval
# KWSList.pm
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

my $versionid = "KWSList.pm Version: $version";

##

use KWSDetectedList;

use MMisc;
use xmllintHelper;
use MtXML;

#####
my @kwslist_attrs = ('kwlist_filename', 'language', 'system_id', 'min_score', 'max_score'); 
my @dtl_attrs = ('kwid', 'search_time', 'oov_count');
my @term_attrs = ('file', 'channel', 'tbeg', 'dur', 'score', 'decision');


#####
sub __init {
  my $self = shift;
  my $kwslistfile = shift;
  
  $self->{KWSLIST_FILENAME} = $kwslistfile;
  ##
  $self->{TERMLIST_FILENAME} = "";
  $self->{LANGUAGE} = "";
  $self->{SYSTEM_ID} = "";
  $self->{MIN_SCORE} = undef;
  $self->{MAX_SCORE} = undef;
  ## 
  $self->{DIFF_SCORE} = 0.0;
  # those can only exist if MIN_SCORE is set in file header
  $self->{MIN_YES} = undef;
  $self->{MAX_NO} = undef;
  # new default is to NOT CreateTerms
  $self->{CreateTerms} = 0;
  $self->{TERMS} = {};
  # Added to avoid overwriting in file load
  $self->{LoadedFile} = 0; # 0 not loaded
  $self->{LoadInProgress} = 0; 
  # File handles & related variables
  $self->{FH} = undef;
  $self->{linec} = 0;
  $self->{SEfile} = undef;
}

#####

sub new {
  my $class = shift;
  my $kwslistfile = shift;
  my $self = {};
    
  bless $self;
  $self->__init($kwslistfile);
  my $err = "";
  $err = $self->loadFile($kwslistfile) 
    if (defined($kwslistfile));
  MMisc::error_quit($err) if (! MMisc::is_blank($err));

  if (defined $self->{MIN_SCORE}) {
    $self->{DIFF_SCORE} = $self->{MAX_SCORE} - $self->{MIN_SCORE};
  }

  return $self;
}

#####

sub new_empty {
  my $class = shift;
  my $kwslistfile = shift;
  my $self = {};
  
  bless $self;
  $self->__init($kwslistfile);
  
  return $self;
}

#####

sub toString {
  my ($self) = @_;

  # we can not return anything if the file is not loaded or Terms were not generated
  if (! $self->{LoadedFile}) {
    print "File not loaded yet\n";
    return();
  }

  print "Dump of KWSList File\n";
  print "   TermList filename: " . $self->{TERMLIST_FILENAME} . "\n";
  print "   Language: " . $self->{LANGUAGE} . "\n";
  print "   Detected TL:\n";
  if ($self->{CreateTerms} == 0) {
    print "TL were not created -- per user request-- can not print them\n";
    return();
  }
    
  foreach my $terms (sort keys %{ $self->{TERMS} }) {
    print "    ".$self->{TERMS}{$terms}->toString()."\n";
  }
}

#####

sub SetSystemID {
    # ($self, $sysid) 
    $_[0]->{SYSTEM_ID} = $_[1];
}

#####

sub getSystemID {
  # ($self)
  return($_[0]->{SYSTEM_ID});
}

##########

sub get_TERMLIST_FILENAME { return($_[0]->{TERMLIST_FILENAME}); }

########################################

sub __SEcheck {
  return("") if (! defined $_[0]->{SEfile});

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

# Note: "CreateTerms" is selected here (0 for false, 1 for true)
# wihtout it set to 1, TERMs will not be created 
sub openXMLFileAccess {
  my ($self, $kwslistf, $CreateTerms, $bypassxmllint) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);
  return("Refusing to load a file on top of a stream already in progress")
    if ($self->{LoadInProgress} != 0);

 my $err = MMisc::check_file_r($kwslistf);
  return("Problem with input file ($kwslistf): $err")
    if (! MMisc::is_blank($err));

  $self->{KWSLIST_FILENAME} = $kwslistf;

  $self->{CreateTerms} = 1
    if ($CreateTerms != 0);

  my $modfp = MMisc::find_Module_path('KWSList');
  return("Could not obtain \'KWSList.pm\' location, aborting")
      if (! defined $modfp);

  if ($bypassxmllint == 1) {
    open(local *KWSLISTFH, "<$kwslistf")
      or return("Problem opening input file ($kwslistf): $!");
    $self->{FH} = *KWSLISTFH;
  } else {
    my $f4b = 'F4DE_BASE';
    my $xmllint_env = "F4DE_XMLLINT";
    my $xsdpath = (exists $ENV{$f4b}) ? $ENV{$f4b} . "/lib/data" : $modfp . "/../../KWSEval/data";
    my @xsdfilesl = ('KWSEval-kwslist.xsd');
    
    # First let us use xmllint on the file XML file
    my $xmlh = new xmllintHelper();
    my $xmllint = MMisc::get_env_val($xmllint_env, "");
    return("While trying to set \'xmllint\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xmllint($xmllint));
    return("While trying to set \'xsdfilesl\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xsdfilesl(@xsdfilesl));
    return("While trying to set \'Xsdpath\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xsdpath($xsdpath));
    
    #  print STDERR "Loading KWS List file '$kwslistf'.\n";
    
    (local *KWSLISTFH, my $sefile) = $xmlh->run_xmllint_pipe($kwslistf);
    return("While trying to load XML file ($kwslistf) : " . $xmlh->get_errormsg() )
      if ($xmlh->error());
    
    $self->{FH} = *KWSLISTFH;
    $self->{SEfile} = $sefile;
  }
  local *KWSLISTFH = $self->{FH};

  my $doit = 1;
  # Load the KWSLIST header
  while ($doit == 1) {
    my $se_err = $self->__SEcheck();
    return("Problem with validation: $se_err")
      if (! MMisc::is_blank($se_err));

    if (eof(KWSLISTFH)) {
      $doit = -1;
      next;
    }
    my $line = <KWSLISTFH>;
    chomp($line);
    $self->{linec}++;

    my ($err, $closed, $name, $content, %vals) = MtXML::line_extractor($line);
    return("Problem processing File Access: $err")
      if (! MMisc::is_blank($err));
    
    next if ($name eq "");

    if ($name eq 'kwslist') {
      $self->{TERMLIST_FILENAME} = &__get_attr(\%vals, $kwslist_attrs[0]);
      $self->{LANGUAGE} = &__get_attr(\%vals, $kwslist_attrs[1]);
      $self->{SYSTEM_ID} = &__get_attr(\%vals, $kwslist_attrs[2]);
      if (exists $vals{$kwslist_attrs[3]}) {
        $self->{MIN_SCORE} = &__get_attr(\%vals, $kwslist_attrs[3]);
      }
      if (exists $vals{$kwslist_attrs[4]}) {
        $self->{MAX_SCORE} = &__get_attr(\%vals, $kwslist_attrs[4]);
      }
      my $minmax_check = 0;
      $minmax_check += (defined $self->{MIN_SCORE}) ? 1 : 0;
      $minmax_check += (defined $self->{MAX_SCORE}) ? 1 : 0;
      return("If defined in the header, both " . $kwslist_attrs[3] . " and " . $kwslist_attrs[4] . " must be defined") if ($minmax_check == 1);
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

sub getNextDetectedKWlist {
  my ($self) = @_;

  return("Can not process, no loading in progress", undef)
    if ($self->{LoadInProgress} == 0);
  
  local *KWSLISTFH = $self->{FH};

  my $doit = 1;
  my $detectedterm = undef;
  # Load the KWSLIST header
  while ($doit == 1) {
 
    my $se_err = $self->__SEcheck();
    return("Problem with validation: $se_err", undef)
      if (! MMisc::is_blank($se_err));      

    if (eof(KWSLISTFH)) {
      $doit = -1;
      next;
    }
    my $line = <KWSLISTFH>;
    chomp($line);
    $self->{linec}++;
#print "[$line]\n";    
    my ($err, $closed, $name, $content, %vals) = MtXML::line_extractor($line);
    return("Problem processing File Access: $err", undef)
      if (! MMisc::is_blank($err));
    
    next if ($name eq "");
    
    if ($name eq 'detected_kwlist') {
      my $detectedtermid = &__get_attr(\%vals, $dtl_attrs[0]);
      my $detectedsearchtime = &__get_attr(\%vals, $dtl_attrs[1]);
      my $detectedoov = &__get_attr(\%vals, $dtl_attrs[2]);
      
      $detectedterm = new KWSDetectedList($detectedtermid, $detectedsearchtime, $detectedoov);
      if ($self->{CreateTerms} == 1) {
        $self->{TERMS}{$detectedtermid} = $detectedterm;
      }
      $doit = 0 if ($closed == 1);
      next;
    }

    if ($name eq '/detected_kwlist') {
      $doit = 0;
      next;
    }

    if ($name eq 'kw') {
      my $file = &__get_attr(\%vals, $term_attrs[0]);
      my $chan = &__get_attr(\%vals, $term_attrs[1]);
      my $bt = &__get_attr(\%vals, $term_attrs[2]);
      my $dur = &__get_attr(\%vals, $term_attrs[3]);
      my $score = &__get_attr(\%vals, $term_attrs[4]);
      my $decision = &__get_attr(\%vals, $term_attrs[5]);
      
      my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($file);
      if ($e eq 'sph') {
        $file = $f;
      } else {
        $file = MMisc::concat_dir_file_ext('', $f, $e);
      }
      
      if (defined $self->{MIN_SCORE}) {
        return("Score < File 'min_score' [$score < " . $self->{MIN_SCORE} . "]", undef)
          if ($score < $self->{MIN_SCORE});
        return("Score > File 'max_score' [$score < " . $self->{MAX_SCORE} . "]", undef)
          if ($score > $self->{MAX_SCORE});
        
#      $self->{MIN_SCORE} = $score if ($score < $self->{MIN_SCORE});
#      $self->{MAX_SCORE} = $score if ($score > $self->{MAX_SCORE});
      
        $self->{MIN_YES} = $score if (($decision eq 'YES') && ($score < $self->{MIN_YES}));
        $self->{MAX_NO} = $score if (($decision eq 'NO') && ($score > $self->{MAX_NO}));
      }

      push (@{ $detectedterm->{TERMS} }, new KWSTermRecord($file, $chan, $bt, $dur, $score, $decision) );
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
    close KWSLISTFH;
    $self->{FH} = undef;
    $self->{SEfile} = undef;
    return("", undef);
  }

  return("", $detectedterm);
}

##########

# 'justValidate' will ask for TERMs not to be created (ie no rewrite possible)
sub loadXMLFile {
  my ($self, $kwslistf, $justValidate) = MMisc::iuav(\@_, undef, undef, 0);

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);

  # First: open the file access to read the header, asking for TERMs to be created
  my $err = $self->openXMLFileAccess($kwslistf, ($justValidate == 1) ? 0 : 1);
  return($err) if (! MMisc::is_blank($err));
  
  my $doit = 1;
  while ($doit) {
    # Then process each 'kw' at a time
    my ($lerr, $ldw) = $self->getNextDetectedKWlist();
    # any error while reading ?
    return($lerr) if (! MMisc::is_blank($err));
    # Stop processing when the last entry processed is undefined
    $doit = 0 if (! defined $ldw);
#    print ". " . $ldw->{TERMID} . "\n";
  }

  return("");
}

############################################################

sub saveFile {
  my ($self, $fn) = @_;

  MMisc::warn_print("KWSList's \'CreateTerms\' is false, expect no TERMs ")
      if ($self->{CreateTerms} == 0);
  
  my $to = MMisc::is_blank($fn) ? $self->{KWSLIST_FILENAME} : $fn;
  # Re-adapt the file name to remove all ".memdump" (if any)
  $to = &_rm_mds($to);

  # trying to do a streaming rewrite in order to avoid large memory consumption
  my $txt = $self->get_XMLrewrite($to);
  print "Wrote: $to\n";

  return(1);
}

#####

sub __add2x {
  my $txt = shift @_;
  my $rtxt = shift @_;
  local *RWFH = shift @_;
  my $mode = shift @_;

  if ($mode == 2) {
    print RWFH $txt;
  } else {
    $$rtxt .= $txt;
  }
}

##

sub get_XMLrewrite {
  my ($self, $to) = @_;

  my $mode = 1;
  if (! MMisc::is_blank($to)) {
    open RWFH, ">$to"
      or return("");
    $mode = 2;
  }

  my $txt = "";
  
  &__add2x("<kwslist kwlist_filename=\"$self->{TERMLIST_FILENAME}\" language=\"$self->{LANGUAGE}\" system_id=\"$self->{SYSTEM_ID}\">\n", \$txt, *RWFH, $mode);

  foreach my $termsid (sort keys %{ $self->{TERMS} }) {
    &__add2x("  <detected_kwlist kwid=\"$termsid\" search_time=\"$self->{TERMS}{$termsid}->{SEARCH_TIME}\" oov_count=\"$self->{TERMS}{$termsid}->{OOV_TERM_COUNT}\">\n", \$txt, *RWFH, $mode);
    if ($self->{TERMS}{$termsid}->{TERMS}) {
      for (my $i = 0; $i < @{ $self->{TERMS}{$termsid}->{TERMS} }; $i++) {
        &__add2x("    <kw file=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{FILE}\" channel=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{CHAN}\" tbeg=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{BT}\" dur=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{DUR}\" score=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{SCORE}\" decision=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{DECISION}\"/>\n", \$txt, *RWFH, $mode);
      }
    }
    &__add2x("  </detected_kwlist>\n", \$txt, *RWFH, $mode);
  }
  &__add2x("</kwslist>\n", \$txt, *RWFH, $mode);

  close RWFH
    if ($mode == 2);
  
  return($txt);
}

########## 'save' / 'load' Memmory Dump functions

my $MemDump_Suffix = ".memdump";

sub get_MemDump_Suffix { return $MemDump_Suffix; }

my $MemDump_FileHeader_cmp = "\#  KWSEval KWSList MemDump";
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

  MMisc::warn_print("KWSList's \'CreateTerms\' is false, expect no TERMs ")
      if ($self->{CreateTerms} == 0);
  MMisc::warn_print("\'gzip\' MemDump are disabled for \'KWSList\'")
      if ($mode eq "gzip");
  $mode = undef;

  $printw = MMisc::iuv($printw, 1);

  # Re-adapt the file name to remove all ".memdump" (added later in this step)
  $fname = &_rm_mds($fname);

  my $tmp = KWSList->new_empty();
  $tmp->{KWSLIST_FILENAME} = $self->{KWSLIST_FILENAME};
  $tmp->{TERMLIST_FILENAME} = $self->{TERMLIST_FILENAME};
  $tmp->{LANGUAGE} = $self->{LANGUAGE};
  $tmp->{SYSTEM_ID} = $self->{SYSTEM_ID};
  $tmp->{MIN_SCORE} = $self->{MIN_SCORE};
  $tmp->{MAX_SCORE} = $self->{MAX_SCORE};
  $tmp->{DIFF_SCORE} = $self->{DIFF_SCORE};
  $tmp->{MIN_YES} = $self->{MIN_YES};
  $tmp->{MAX_NO} = $self->{MAX_NO};
  $tmp->{CreateTerms} = $self->{CreateTerms};
  $tmp->{TERMS} = undef; # NO TERMS (for now)
  $tmp->{LoadedFile} = $self->{LoadedFile};
  $tmp->{LoadInProgress} = $self->{LoadInProgress};
  $tmp->{FH} = $self->{FH};
  $tmp->{linec} = $self->{linec};
  $tmp->{SEfile} = $self->{SEfile};

  open MEMDUMP, ">$fname$MemDump_Suffix"
    or return("Problem creating memdump file", $fname);

  print MEMDUMP "$MemDump_FileHeader";
  print MEMDUMP "\n# MMisc::get_sorted_MemDump used method: [dump]\n\n";

  print MEMDUMP "{\n";
  
  print MEMDUMP "my \$tmp =\n" . MMisc::get_sorted_MemDump($tmp, undef, 'dump') . ";\n\n";

  foreach my $termsid (sort keys %{ $self->{TERMS} }) {
    print MEMDUMP "\$tmp->{TERMS}{\'$termsid\'} =\n" 
      . MMisc::get_sorted_MemDump($self->{TERMS}{$termsid}, undef, 'dump') . ";\n\n";
  }

  print MEMDUMP "return \$tmp;\n}\n";

  close MEMDUMP;
  print "Wrote: $fname$MemDump_Suffix\n"
    if ($printw);

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
    if (($self->{LoadedFile} != 0) || ($self->{LoadInProgress} != 0));

  my $err = MMisc::check_file_r($file);
  return("Problem with input file ($file): $err")
    if (! MMisc::is_blank($err));

  my $object = MMisc::load_memory_object($file, $MemDump_FileHeader_gz);

  $self->_md_clone_value($object, 'KWSLIST_FILENAME');
  $self->_md_clone_value($object, 'TERMLIST_FILENAME');
  $self->_md_clone_value($object, 'LANGUAGE');
  $self->_md_clone_value($object, 'SYSTEM_ID');
  $self->_md_clone_value($object, 'MIN_SCORE');
  $self->_md_clone_value($object, 'MAX_SCORE');
  $self->_md_clone_value($object, 'DIFF_SCORE');
  $self->_md_clone_value($object, 'MIN_YES');
  $self->_md_clone_value($object, 'MAX_NO');
  $self->_md_clone_value($object, 'CreateTerms');
  $self->_md_clone_value($object, 'TERMS');
  $self->_md_clone_value($object, 'LoadedFile');
  $self->_md_clone_value($object, 'LoadInProgress');
  $self->_md_clone_value($object, 'FH');
  $self->_md_clone_value($object, 'linec');
  $self->_md_clone_value($object, 'SEfile');
 
  return("");
}

#####

sub loadFile {
  my ($self, $kwslistf) = @_;

  return("Refusing to load a file on top of an already existing object")
    if (($self->{LoadedFile} != 0) || ($self->{LoadInProgress} != 0));
  
  my $err = MMisc::check_file_r($kwslistf);
  return("Problem with input file ($kwslistf): $err")
    if (! MMisc::is_blank($err));

  open FILE, "<$kwslistf"
    or return("Problem opening file ($kwslistf) : $!");

  my $header = <FILE>;
  close FILE;
  chomp $header;

  return($self->load_MemDump_File($kwslistf))
    if ( ($header eq $MemDump_FileHeader_cmp)
         || ($header eq $MemDump_FileHeader_gz_cmp) );

  return($self->loadXMLFile($kwslistf));
}

########################################

sub listOOV {
  my ($self, $rarraytermsid) = @_;
  
  # we can not return anything if the file is not loaded or Terms were not generated
  return() 
    if ((! $self->{LoadedFile}) || ($self->{CreateTerms} == 0));

  foreach my $termsid (sort keys %{ $self->{TERMS} }) {
    next if ($self->{TERMS}{$termsid}->{OOV_TERM_COUNT} eq "NA");
    push(@{ $rarraytermsid }, $termsid) 
      if ($self->{TERMS}{$termsid}->{OOV_TERM_COUNT} > 0);
  }
}

#####

sub listIV {
  my ($self, $rarraytermsid) = @_;
  
  # we can not return anything if the file is not loaded or Terms were not generated
  return() 
    if ((! $self->{LoadedFile}) || ($self->{CreateTerms} == 0));

  foreach my $termsid (sort keys %{ $self->{TERMS} }) {
    next if ($self->{TERMS}{$termsid}->{OOV_TERM_COUNT} eq "NA");
    push(@{ $rarraytermsid }, $termsid) 
      if ($self->{TERMS}{$termsid}->{OOV_TERM_COUNT} == 0);
  }
}

############################################################

1;

