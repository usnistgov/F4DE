package TermList;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# KWSEval
# TermList.pm
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

use TranscriptHolder;
@ISA = qw(TranscriptHolder);

use strict;
use AutoTable;
use Encode;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TermList.pm Version: $version";

##

use TermListRecord;

use MMisc;
use xmllintHelper;
use MtXML;

#####
my @tlist_attrs = ( 'ecf_filename', 'language', 'encoding', 'compareNormalize', 'version' );
my @term_attrs = ('kwid');

#####
sub new {
  my $class = shift;
  my $termlistfile = shift;  
  my $charSplitText = shift;
  my $charSplitTextNotASCII = shift;
  my $charSplitTextDeleteHyphens = shift;

  my $self = TranscriptHolder->new();
  
  $self->{TERMLIST_FILENAME} = $termlistfile;
  $self->{ECF_FILENAME} = "";
  $self->{VERSION} = "";
  # new default is to NOT CreateTerms
  $self->{CreateTerms} = 0;
  $self->{TERMS} = {};
  $self->{charSplitText} = $charSplitText;
  $self->{charSplitTextNotASCII} = $charSplitTextNotASCII;
  $self->{charSplitTextDeleteHyphens} = $charSplitTextDeleteHyphens;

  # Added to avoid overwriting in file load
  $self->{LoadedFile} = 0; # 0 not loaded
  $self->{LoadInProgress} = 0; 
  # File handles & related variables
  $self->{FH} = undef;
  $self->{linec} = 0;
  $self->{SEfile} = undef;
  
  bless $self;
  
  my $err = "";
  $err = $self->loadFile($termlistfile) if (defined($termlistfile));
  MMisc::error_quit($err) if (! MMisc::is_blank($err));
  
  return $self;
}

sub new_empty {
  my $class = shift;
  my $termlistfile = shift;
  my $self = {};
  
  $self->{TERMLIST_FILENAME} = $termlistfile;
  $self->{ECF_FILENAME} = shift;
  $self->{VERSION} = shift;
  die "Failed: New TermList failed: \n   ".$self->errormsg() if (! $self->setLanguage(shift));
  die "Failed: New TermList failed: \n   ".$self->errormsg() if (! $self->setEncoding(shift));
  die "Failed: New TermList failed: \n   ".$self->errormsg() if (! $self->setCompareNormalize(shift));
  $self->{TERMS} = {};
  
  $self->{LoadedFile} = 0;
  
  bless $self;    
  return $self;
}

sub unitTest
{
  print "TList Unit Test\n";
  print "OK\n";
}

sub union_intersection
{
    my($list1, $list2, $out_union, $out_intersection) = @_;
    
    my %union;
    my %isect;    
    foreach my $e (@{ $list1 }, @{ $list2 }) { $union{$e}++ && $isect{$e}++ }

    @{ $out_union } = keys %union;
    @{ $out_intersection } = keys %isect;
}

sub multiarray
{
    my($list1, $list2, $multi) = @_;
    
    foreach my $e1 (@{ $list1 })
    {
        foreach my $e2 (@{ $list2 })
        {
            push(@{$multi}, ($e1 ne "")?"$e1|$e2":"$e2");
        }
    }
}

sub QueriesToTermSet
{
    my ($self, $arrayqueries, $filterTerms) = @_;
    
    my %attributes;

    foreach my $termid(keys %{ $self->{TERMS} } )
    {
        foreach my $attrib_name(keys %{ $self->{TERMS}{$termid} })
        {
            if( ($attrib_name ne "TERMID") && ($attrib_name ne "TEXT") )
            {
                $attributes{$attrib_name} = 1;
            }
        }
    }
    
    foreach my $quer(@{ $arrayqueries })
    {
        MMisc::error_quit("$quer is not a valid attribute.")
            if (!$attributes{$quer});
    }
    
    my %hashterm;

    foreach my $termid(keys %{ $self->{TERMS} } )
    {
        foreach my $attrib_name(keys %{ $self->{TERMS}{$termid} })
        {
            if( ($attrib_name ne "TERMID") && ($attrib_name ne "TEXT") )
            {
                my $attribute_value = $self->{TERMS}{$termid}->{$attrib_name};
                push(@{ $hashterm{$attrib_name}{$attribute_value} }, $termid);
            }
        }
    }

    my @multivalues = ("");
    my @sorted_queries = sort @{ $arrayqueries };
    
    foreach my $quer(@sorted_queries)
    {
        my @values = sort keys %{ $hashterm{$quer} };
        my @finalmulti;
        multiarray(\@multivalues, \@values, \@finalmulti);
        @multivalues = @finalmulti;
    }
    
    my %hashlistterms;

    foreach my $multivalue(@multivalues)
    {
        my @values = split(/\|/, $multivalue);
    
        my @listterm = @{ $hashterm{$sorted_queries[0]}{$values[0]} };
        my $title = "$sorted_queries[0] $values[0]";
        
        for(my $i=1; $i<@sorted_queries; $i++)
        {
            my @outtmp;
            my @out_inter;
            union_intersection(\@listterm, \@{ $hashterm{$sorted_queries[$i]}{$values[$i]} }, \@outtmp, \@out_inter);
            @listterm = @out_inter;
            $title .= "|$sorted_queries[$i] $values[$i]";
        }
        
        $title =~ s/ /_/g;
    
        push(@{ $hashlistterms{$title} }, @listterm);
    }

    foreach my $finalkey(sort keys %hashlistterms)
    {
        push(@{ $filterTerms->{$finalkey} }, @{ $hashlistterms{$finalkey} });
    }
}

sub addTerm                                                                                                                                                                                  
{                                                                                                                                                                                            
  my ($self, $term, $id) = @_;                                                                                                                                                               
  $self->{TERMS}{$id} = $term;                                                                                                                                                               
}                                                                                                                                                                                            
                                                                                                                                                                                             
sub setVersion
{                                                                                                                                                                                            
  my ($self, $ver) = @_;                                                                                                                                                               
  $self->{VERSION} = $ver;
}                                                                                                                                                                                            
                                                                                                                                                                                             
sub getVersion
{                                                                                                                                                                                            
  my ($self) = @_;                                                                                                                                                               
  return $self->{VE0RSION};
}                                                                                                                                                                                            
                                                                                                                                                                                             
sub getTermIDs
{
    my ($self) = @_;

    return(keys %{ $self->{TERMS} });
}


sub getTermFromID
{
    my ($self, $termID) = @_;

    if (exists($self->{TERMS}{$termID})){ 
      return($self->{TERMS}{$termID});
    }
    return(undef);
}

sub removeTermByID
{
    my ($self, $termID) = @_;

    if (exists($self->{TERMS}{$termID})){ 
      delete($self->{TERMS}{$termID});
    }
}

sub getTermFromText
{
    my ($self, $termText) = @_;

    foreach my $id(keys %{ $self->{TERMS} }){
      if ($self->{TERMS}{$id}{TEXT} eq $termText){ 
        return($self->{TERMS}{$id});  
      }
    }
    return(undef);
}

sub getTermFromTextAfterCharSplit
{
    my ($self, $termText, $charSplitTextNotASCII, $charSplitTextDeleteHyphens) = @_;


    foreach my $id(keys %{ $self->{TERMS} }){
      $self->{TERMS}{$id}{_INTERNAL_CH} = $self->charSplitText($self->{TERMS}{$id}{TEXT}, $charSplitTextNotASCII, $charSplitTextDeleteHyphens)
        if (! exists($self->{TERMS}{$id}{_INTERNAL_CH}));
      if ($self->{TERMS}{$id}{_INTERNAL_CH} eq $termText){ 
        return($self->{TERMS}{$id});  
      }
    }
    return(undef);
}

sub toString
{
    my ($self) = @_;

    print "Dump of TermList File\n";
    print "   File: " . $self->{TERMLIST_FILENAME} . "\n";
    print "   ECF filename: " . $self->{ECF_FILENAME} . "\n";
    print "   Version: " . $self->{VERSION} . "\n";
    print "   Language: " . $self->{LANGUAGE} . "\n";
    print "   TermList:\n";
    
    foreach my $terms(sort keys %{ $self->{TERMS} })
    {
        print "    ".$self->{TERMS}{$terms}->toString()."\n";
    }
}

########################################

sub __precheck_kwlist_encoding {
  my ($file) = @_;
  open FILE, "<$file"
    or return("Problem opening file ($file) : $!");
  my $txt = "";
  read(FILE, $txt, 2048);
  close FILE;

  my ($err, %res) = MtXML::get_inline_xml_attributes('kwlist', $txt);
  return($err) if (! MMisc::is_blank($err));
  return("", $res{'encoding'}) if (exists $res{'encoding'});

  return("", "");
}

#####

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

# Note: "CreateTerms" is selected here (0 for false, 1 for true)
# wihtout it set to 1, KWs will not be created 
sub openXMLFileAccess {
  my ($self, $kwlistf, $CreateTerms, $bypassxmllint) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);
  return("Refusing to load a file on top of a stream already in progress")
    if ($self->{LoadInProgress} != 0);

 my $err = MMisc::check_file_r($kwlistf);
  return("Problem with input file ($kwlistf): $err")
    if (! MMisc::is_blank($err));

  $self->{TERMLIST_FILENAME} = $kwlistf;

  $self->{CreateTerms} = 1
    if ($CreateTerms != 0);

  my $modfp = MMisc::find_Module_path('TermList');
  return("Could not obtain \'TermList.pm\' location, aborting")
      if (! defined $modfp);

  ($err, my $xml_encoding) = &__precheck_kwlist_encoding($kwlistf);
  return("Problem while extracting encoding: $err")
    if (! MMisc::is_blank($err));
  if ($xml_encoding =~ m%^gb2312$%i) {
    MMisc::warn_print("Forcing XMLlint bypass for $xml_encoding files")
        if ($bypassxmllint == 0);
    $bypassxmllint = 1;
  }

  if ($bypassxmllint == 1) {
    open(local *KWLISTFH, "<$kwlistf")
      or return("Problem opening input file ($kwlistf): $!");
    $self->{FH} = *KWLISTFH;
  } else {
    my $f4b = 'F4DE_BASE';
    my $xmllint_env = "F4DE_XMLLINT";
    my $xsdpath = (exists $ENV{$f4b}) ? $ENV{$f4b} . "/lib/data" : $modfp . "/../../KWSEval/data";
    my @xsdfilesl = ('KWSEval-kwlist.xsd');

    # First let us use xmllint on the file XML file
    my $xmlh = new xmllintHelper();
    my $xmllint = MMisc::get_env_val($xmllint_env, "");
    return("While trying to set \'xmllint\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xmllint($xmllint));
    return("While trying to set \'xsdfilesl\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xsdfilesl(@xsdfilesl));
    return("While trying to set \'Xsdpath\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xsdpath($xsdpath));
    return("While trying to set xmllint's encoding: " . $xmlh->get_errormsg())
      if ((! MMisc::is_blank($xml_encoding)) && (! $xmlh->set_encoding($xml_encoding)));
    
    #  print STDERR "Loading KW List file '$kwlistf'.\n";
    
    (local *KWLISTFH, my $sefile) = $xmlh->run_xmllint_pipe($kwlistf);
    return("While trying to load XML file ($kwlistf) : " . $xmlh->get_errormsg() )
      if ($xmlh->error());

    $self->{FH} = *KWLISTFH;
    $self->{SEfile} = $sefile;
  }
  local *KWLISTFH = $self->{FH};

  my $doit = 1;
  # Load the KWLIST header
  while ($doit == 1) {
    my $se_err = $self->__SEcheck();
    return("Problem with validation: $se_err")
      if (! MMisc::is_blank($se_err));

    if (eof(KWLISTFH)) {
      $doit = -1;
      next;
    }
    my $line = <KWLISTFH>;
    chomp($line);
    $self->{linec}++;

    my ($err, $closed, $name, $content, %vals) = MtXML::line_extractor($line);
    return("Problem processing File Access: $err")
      if (! MMisc::is_blank($err));
    
    next if ($name eq "");

    if ($name eq 'kwlist') {
      $self->{ECF_FILENAME} = &__get_attr(\%vals, $tlist_attrs[0]);
      return("new TermList failed: " . $self->errormsg())
        if (! $self->setLanguage(&__get_attr(\%vals, $tlist_attrs[1])));
      return("new TermList failed: " . $self->errormsg())
        if (! $self->setEncoding(&__get_attr(\%vals, $tlist_attrs[2])));
      return("new TermList failed: " . $self->errormsg())
        if (! $self->setCompareNormalize(&__get_attr(\%vals, $tlist_attrs[3])));
      $self->{VERSION} = &__get_attr(\%vals, $tlist_attrs[4]);
      $doit = 0; # we are done reading the header
      binmode KWLISTFH, $self->getPerlEncodingString()
        if (! MMisc::is_blank($self->{ENCODING}));
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

sub getNextKW {
  my ($self) = @_;

  return("Can not process, no loading in progress", undef)
    if ($self->{LoadInProgress} == 0);
  
  local *KWLISTFH = $self->{FH};
  my %attrib = ();
  my ($attr_name, $attr_value) = ("", "");
  my $doit = 1;
  my $kw = undef;
  # Load the KWLIST header
  while ($doit == 1) {
 
    my $se_err = $self->__SEcheck();
    return("Problem with validation: $se_err", undef)
      if (! MMisc::is_blank($se_err));      

    if (eof(KWLISTFH)) {
      $doit = -1;
      next;
    }
    my $line = <KWLISTFH>;
    $line = decode_utf8($line)
      if ($self->{ENCODING} eq 'UTF-8');
    chomp($line);
    $self->{linec}++;
    
    my ($err, $closed, $name, $content, %vals) = MtXML::line_extractor($line);
    return("Problem processing File Access: $err", undef)
      if (! MMisc::is_blank($err));
#    print "{$name} [$line]\n";

    next if ($name eq "");
    
    if ($name eq 'kw') {
      $attrib{TERMID} = &__get_attr(\%vals, $term_attrs[0]);
      return("Term ID $attrib{TERMID} already exists")
        if (exists($self->{TERMS}{$attrib{TERMID}}));

      if ($closed) {
        $kw = new TermListRecord(\%attrib);
        if ($self->{CreateTerms} == 1) {
          $self->{TERMS}{$attrib{TERMID}} = $kw;
        }
        $doit = 0;
      }
      next;
    }

    if ($name eq '/kw') {
      $kw = new TermListRecord(\%attrib);
      if ($self->{CreateTerms} == 1) {
        $self->{TERMS}{$attrib{TERMID}} = $kw;
      }
      $doit = 0;
      next;
    }
    
    if ($name eq 'kwtext') {
      $attrib{TEXT} = ( ! $self->{charSplitText}) ? $content 
        : $self->charSplitText($content, $self->{charSplitTextNotASCII}, $self->{charSplitTextDeleteHyphens});
      next;
    }

    next if ($name eq 'kwinfo'); # we do not need the header

    if ($name eq 'attr') {
      ($attr_name, $attr_value) = ("", "");
      next;
    }

    if ($name eq 'name') {
      $attr_name = $content;
      next;
    }

    if ($name eq 'value') {
      $attr_value = $content;
      next;
    }

    if ($name eq '/attr') {
#      print "[$attr_name] -> [$attr_value]\n";
      $attrib{$attr_name} = ($attr_name eq 'Syllables') ? sprintf("%02d", $attr_value) : $attr_value;
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
    close KWLISTFH;
    $self->{FH} = undef;
    $self->{SEfile} = undef;
    return("", undef);
  }

  return("", $kw);
}

####################

# 'justValidate' will ask for TERMs not to be created (ie no rewrite possible)
sub loadXMLFile {
  my ($self, $kwlistf, $justValidate) = MMisc::iuav(\@_, undef, undef, 0);

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);

  # First: open the file access to read the header, asking for TERMs to be created
  my $err = $self->openXMLFileAccess($kwlistf, ($justValidate == 1) ? 0 : 1);
  return($err) if (! MMisc::is_blank($err));
  
  my $doit = 1;
  while ($doit) {
    # Then process each 'kw' at a time
    my ($lerr, $ldw) = $self->getNextKW();
    # any error while reading ?
    return($lerr) if (! MMisc::is_blank($lerr));
    # Stop processing when the last entry processed is undefined
    $doit = 0 if (! defined $ldw);
#    print ". " . $ldw->{TERMID} . "\n";
  }

  return("");
}

############################################################

sub saveFileCSV
{
    my ($self, $file) = @_;
    
    open(OUTPUTFILE, ">$file") 
      or MMisc::error_quit("cannot open file '$file' : $!");
    if ($self->{ENCODING} eq "UTF-8"){
       binmode OUTPUTFILE, $self->getPerlEncodingString();
    }
 
    my $at = new AutoTable();

    foreach my $termid(sort keys %{ $self->{TERMS} }) {
      foreach my $termattrname(sort keys %{ $self->{TERMS}{$termid} }) {
        $at->addData($self->{TERMS}{$termid}->{$termattrname},$termattrname,$termid);
      }
    }    
    print OUTPUTFILE $at->renderCSV();    
    close OUTPUTFILE;
}

############################################################

sub saveFile {
  my ($self, $fn) = @_;
  
  my $to = MMisc::is_blank($fn) ? $self->{TERMLIST_FILENAME} : $fn;
  # Re-adapt the file name to remove all ."memdump" (if any)
  $to = &_rm_mds($to);
  my $txt = $self->get_XMLrewrite();
  return(MMisc::writeTo($to, "", 1, 0, $txt, undef, undef, undef, undef, undef, (! MMisc::is_blank($self->{ENCODING})) ? $self->getPerlEncodingString() : undef ));
}

#####

sub get_XMLrewrite {
  my ($self) = @_;
  
  my $txt = "";
    
  $txt .= "<kwlist ecf_filename=\"$self->{ECF_FILENAME}\" language=\"$self->{LANGUAGE}\" encoding=\"$self->{ENCODING}\" compareNormalize=\"$self->{COMPARENORMALIZE}\" version=\"$self->{VERSION}\">\n";
  
  foreach my $termid (sort keys %{ $self->{TERMS} }) {
    $txt .= "  <kw kwid=\"$termid\">\n";
    $txt .= "    <kwtext>$self->{TERMS}{$termid}->{TEXT}</kwtext>\n";
    my $in = "";
    foreach my $termattrname (sort keys %{ $self->{TERMS}{$termid} }) {
      next if( ($termattrname eq "TERMID") || ($termattrname eq "TEXT") || $termattrname =~ /_INTERNAL_/);
      $in .= "      <attr>\n";
      $in .= "        <name>$termattrname</name>\n";
      $in .= "        <value>$self->{TERMS}{$termid}->{$termattrname}</value>\n";
      $in .= "      </attr>\n";
    }
    $txt .= "    <kwinfo>\n$in    </kwinfo>\n" if (! MMisc::is_blank($in));
    $txt .= "  </kw>\n";
  }
  
  $txt .= "</kwlist>\n";
  
  return($txt);
}

########## 'save' / 'load' Memmory Dump functions

my $MemDump_Suffix = ".memdump";

sub get_MemDump_Suffix { return $MemDump_Suffix; }

my $MemDump_FileHeader_cmp = "\#  KWSEval TermList MemDump";
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

  $self->_md_clone_value($object, 'TERMLIST_FILENAME');
  $self->_md_clone_value($object, 'ECF_FILENAME');
  $self->_md_clone_value($object, 'VERSION');
  $self->_md_clone_value($object, 'CreateTerms');
  $self->_md_clone_value($object, 'TERMS');
  $self->_md_clone_value($object, 'charSplitText');
  $self->_md_clone_value($object, 'charSplitTextNotASCII');
  $self->_md_clone_value($object, 'charSplitTextDeleteHyphens');
  $self->_md_clone_value($object, 'LoadedFile');
  $self->_md_clone_value($object, 'LoadInProgress');
  $self->_md_clone_value($object, 'FH');
  $self->_md_clone_value($object, 'linec');
  $self->_md_clone_value($object, 'SEfile');
  $self->_md_clone_value($object, 'COMPARENORMALIZE');
  $self->_md_clone_value($object, 'ENCODING');
  $self->_md_clone_value($object, 'LANGUAGE');

  $self->{LoadedFile} = 1;

  return("");
}

#####

sub loadFile {
  my ($self, $tlist) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);
  
  my $err = MMisc::check_file_r($tlist);
  return("Problem with input file ($tlist): $err")
    if (! MMisc::is_blank($err));

  open FILE, "<$tlist"
    or return("Problem opening file ($tlist) : $!");

  my $header = <FILE>;
  close FILE;
  chomp $header;

  return($self->load_MemDump_File($tlist))
    if ( ($header eq $MemDump_FileHeader_cmp)
         || ($header eq $MemDump_FileHeader_gz_cmp) );

  return($self->loadXMLFile($tlist));
}

############################################################

1;

