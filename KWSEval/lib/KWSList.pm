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

sub __init {
  my $self = shift;
  my $kwslistfile = shift;

  $self->{KWSLIST_FILENAME} = $kwslistfile;
  $self->{TERMLIST_FILENAME} = "";
  $self->{MIN_SCORE} = 9999.0;
  $self->{MAX_SCORE} = -9999.0;
  $self->{MIN_YES} = 9999.0;
  $self->{MAX_NO} = -9999.0;
  $self->{DIFF_SCORE} = 0.0;
  $self->{INDEXING_TIME} = "";
  $self->{LANGUAGE} = "";
  $self->{INDEX_SIZE} = "";
  $self->{SYSTEM_ID} = "";
  $self->{TERMS} = {};
}

sub new {
  my $class = shift;
  my $kwslistfile = shift;
  my $self = {};
    
  bless $self;
  $self->__init($kwslistfile);
  my $err = "";
  $err = $self->loadFile($kwslistfile) if (defined($kwslistfile));
  MMisc::error_quit($err) if (! MMisc::is_blank($err));
  $self->{DIFF_SCORE} = $self->{MAX_SCORE} - $self->{MIN_SCORE};
  
  return $self;
}

sub new_empty {
  my $class = shift;
  my $kwslistfile = shift;
  my $self = {};
  
  bless $self;    
  $self->__init($kwslistfile);
  
  return $self;
}

sub toString
{
    my ($self) = @_;

    print "Dump of KWSList File\n";
    print "   TermList filename: " . $self->{TERMLIST_FILENAME} . "\n";
    print "   Indexing time: " . $self->{INDEXING_TIME} . "\n";
    print "   Language: " . $self->{LANGUAGE} . "\n";
    print "   Detected TL:\n";
    
    foreach my $terms(sort keys %{ $self->{TERMS} })
    {
        print "    ".$self->{TERMS}{$terms}->toString()."\n";
    }
}

sub SetSystemID
{
    my ($self, $sysid) = @_;
    $self->{SYSTEM_ID} = $sysid;
}

########################################

sub loadFile {
  my $self = shift @_;
  return($self->loadXMLFile(@_));
}

#####

sub loadXMLFile {
  my ($self, $kwslistf) = @_;

  my $err = MMisc::check_file_r($kwslistf);
  return("Problem with input file ($kwslistf): $err")
      if (! MMisc::is_blank($err));

  my $modfp = MMisc::find_Module_path('KWSList');
  return("Could not obtain \'KWSList.pm\' location, aborting")
      if (! defined $modfp);

  my $f4b = 'F4DE_BASE';
  my $xmllint_env = "F4DE_XMLLINT";
  my $xsdpath = (exists $ENV{$f4b}) ? $ENV{$f4b} . "/lib/data" : $modfp . "/../../KWSEval/data";
  my @xsdfilesl = ('KWSEval-kwslist.xsd');

#  print STDERR "Loading KWS List file '$kwslistf'.\n";

  # First let us use xmllint on the file XML file
  my $xmlh = new xmllintHelper();
  my $xmllint = MMisc::get_env_val($xmllint_env, "");
  return("While trying to set \'xmllint\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xmllint($xmllint));
  return("While trying to set \'xsdfilesl\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdfilesl(@xsdfilesl));
  return("While trying to set \'Xsdpath\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdpath($xsdpath));
  
  my $kwslistfilestring = $xmlh->run_xmllint($kwslistf);
  return("$kwslistf: \'xmllint\' validation failed [" . $xmlh->get_errormsg() . "]\n")
    if ($xmlh->error());

  ## Processing file content

  # Remove all XML comments
  $kwslistfilestring =~ s%\<\!\-\-.+?\-\-\>%%sg;

  # Remove <?xml ...?> header
  $kwslistfilestring =~ s%^\s*\<\?xml.+?\?\>%%is;
  
  # At this point, all we ought to have left is the '<kwslist>' content
  return("After initial cleanup, we found more than just \'kwslist\', aborting")
    if (! ( ($kwslistfilestring =~ m%^\s*\<kwslist\s%is) && ($kwslistfilestring =~ m%\<\/kwslist\>\s*$%is) ) );
  my $dem = "Martial's DEFAULT ERROR MESSAGE THAT SHOULD NOT BE FOUND IN STRING, OR IF IT IS WE ARE SO VERY UNLUCKY";
  # and if we extract it, the remaining string should be empty
  my $string = MtXML::get_named_xml_section('kwslist', \$kwslistfilestring, $dem);
  return("Could not extract '<kwslist>' datum, aborting")
    if ($string eq $dem);
  return("After removing '<kwslist>', found leftover content, aborting")
    if (! MMisc::is_blank($kwslistfilestring));
  
  # Order is important
  my @kwslist_attrs = ('termlist_filename', 'indexing_time', 'language', 'index_size', 'system_id'); 
  my @dtl_attrs = ('termid', 'term_search_time', 'oov_term_count');
  my @term_attrs = ('file', 'channel', 'tbeg', 'dur', 'score', 'decision');

  my ($err, $string, @results) = 
    &kwslist_xml_processor($string, $dem, 'kwslist', \@kwslist_attrs, 'detected_termlist', \@dtl_attrs,'term', \@term_attrs);
  return("Problem during XML internal processing: $err")
    if (! MMisc::is_blank($err));
  return("Leftover content post XML internal processing: $string")
    if (! MMisc::is_blank($string));

#  print MMisc::get_sorted_MemDump(\@results);
  # @results is of the form:
  # [ \%kwslist_attr, [ \%dtl_attr, [ \%term_attr, \%term_attr, ...], \%dtl_attr, [ \%term_attr ...], ...] ]

  # Empty array element by element
  
  # kwslist
  my $rkwslist_attr = shift @results;
  return("Found unexpected data in extracted XML")
    if (scalar @results > 1);
  if (scalar @results == 1) { # contains at least one 'detected_termlist'
    my $rtbd = shift @results;
    return("Expected ARRAY in extracted data")
      if (ref($rtbd) ne 'ARRAY');
    while (scalar @$rtbd > 0) {
      my $rdtl_attr = shift @$rtbd;
      my $detectedtermid = &__get_attr($rdtl_attr, $dtl_attrs[0]);
      my $detectedsearchtime = &__get_attr($rdtl_attr, $dtl_attrs[1]);
      my $detectedoov = &__get_attr($rdtl_attr, $dtl_attrs[2]);
      my $detectedterm = new KWSDetectedList($detectedtermid, $detectedsearchtime, $detectedoov);

      if (scalar @$rtbd > 0) { # data left, if the first one is an array it is a 'term'
        my $temp = $$rtbd[0];
        if (ref($temp) eq 'ARRAY') {
          for (my $i = 0; $i < scalar @$temp; $i++) {
            my $rterm_attr = $$temp[$i];
            my $file = &__get_attr($rterm_attr, $term_attrs[0]);
            my $chan = &__get_attr($rterm_attr, $term_attrs[1]);
            my $bt = &__get_attr($rterm_attr, $term_attrs[2]);
            my $dur = &__get_attr($rterm_attr, $term_attrs[3]);
            my $score = &__get_attr($rterm_attr, $term_attrs[4]);
            my $decision = &__get_attr($rterm_attr, $term_attrs[5]);

            my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($file);
            if ($e eq 'sph') {
              $file = $f;
            } else {
              $file = MMisc::concat_dir_file_ext('', $f, $e);
            }

            $self->{MIN_SCORE} = $score if ($score < $self->{MIN_SCORE});
            $self->{MAX_SCORE} = $score if ($score > $self->{MAX_SCORE});

            $self->{MIN_YES} = $score if (($decision eq 'YES') && ($score < $self->{MIN_YES}));
            $self->{MAX_NO} = $score if (($decision eq 'NO') && ($score > $self->{MAX_NO}));
            
            push (@{ $detectedterm->{TERMS} }, new KWSTermRecord($file, $chan, $bt, $dur, $score, $decision) ); 
          }
          $self->{TERMS}{$detectedtermid} = $detectedterm;
          shift @$rtbd; # remove processed element
        }
      }
    }
  }

  $self->{TERMLIST_FILENAME} = &__get_attr($rkwslist_attr, $kwslist_attrs[0]);
  $self->{INDEXING_TIME} = &__get_attr($rkwslist_attr, $kwslist_attrs[1]);
  $self->{LANGUAGE} = &__get_attr($rkwslist_attr, $kwslist_attrs[2]);
  $self->{INDEX_SIZE} = &__get_attr($rkwslist_attr, $kwslist_attrs[3]);
  $self->{SYSTEM_ID} = &__get_attr($rkwslist_attr, $kwslist_attrs[4]);

#  print MMisc::get_sorted_MemDump(\$self);

  return("");
}

####################

sub __get_attr {
  my ($rh, $key) = @_;

  MMisc::error_quit("Requested hash key does not exists ($key)")
      if (! exists $$rh{$key});

  return($$rh{$key});
}

#####

sub kwslist_xml_processor {
  my ($string, $dem, $here, $rattr, $exp) = MMisc::shiftX(5, \@_);

  $string = MMisc::clean_begend_spaces($string);

  (my $err, $string, my $section, my %iattr) = MtXML::element_extractor($dem, $string, $here);
  return($err) if (! MMisc::is_blank($err));

  foreach my $attr (@$rattr) {
    return("Could not find <$here>'s $attr attribute")
      if (! exists $iattr{$attr});
  }

  # this was the last depth
  if (MMisc::is_blank($exp)) {
    return("In \'$here\': Leftover data post last depth", $section)
      if (! MMisc::is_blank($section));
    return("", $string, \%iattr);
  }

  my @results = ();
  while (! MMisc::is_blank($section)) {
    # First off, confirm the first section is the expected one
    my $name = MtXML::get_next_xml_name(\$section, $dem);
    return("In \'$here\', while checking for \'$exp\': Problem obtaining a valid XML name, aborting")
      if ($name eq $dem);
    return("In \'$here\': \'$exp\' section not present (instead: $name), aborting")
      if ($name ne $exp);
    ($err, $section, my @tmp_results) = &kwslist_xml_processor($section, $dem, $exp, @_);
    return("In \'$here\', while processinging for \'$exp\': $err", $string)
      if (! MMisc::is_blank($err));
    push @results, @tmp_results;
  }

  return("", $string, \%iattr, [@results]);
}

############################################################

sub saveFile
{
    my($self) = @_;
    
    print STDERR "Saving KWS List file '$self->{KWSLIST_FILENAME}'.\n";
    
    open(OUTPUTFILE, ">$self->{KWSLIST_FILENAME}") 
      or MMisc::error_quit("Cannot open to write '$self->{KWSLIST_FILENAME}' : $!");
     
    print OUTPUTFILE "<kwslist termlist_filename=\"$self->{TERMLIST_FILENAME}\" indexing_time=\"$self->{INDEXING_TIME}\" language=\"$self->{LANGUAGE}\" index_size=\"$self->{INDEX_SIZE}\" system_id=\"$self->{SYSTEM_ID}\">\n";
     
    foreach my $termsid(sort keys %{ $self->{TERMS} })
    {
        print OUTPUTFILE "  <detected_termlist termid=\"$termsid\" term_search_time=\"$self->{TERMS}{$termsid}->{SEARCH_TIME}\" oov_term_count=\"$self->{TERMS}{$termsid}->{OOV_TERM_COUNT}\">\n";
        if($self->{TERMS}{$termsid}->{TERMS})
        {
            for(my $i=0; $i<@{ $self->{TERMS}{$termsid}->{TERMS} }; $i++)
            {
                print OUTPUTFILE "    <term file=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{FILE}\" channel=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{CHAN}\" tbeg=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{BT}\" dur=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{DUR}\" score=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{SCORE}\" decision=\"$self->{TERMS}{$termsid}->{TERMS}[$i]->{DECISION}\"/>\n";
            }
        }
        
        print OUTPUTFILE "  </detected_termlist>\n";
    }
     
    print OUTPUTFILE "</kwslist>\n";
     
    close(OUTPUTFILE);
}

sub listOOV
{
    my($self, $arraytermsid) = @_;
    
    foreach my $termsid(sort keys %{ $self->{TERMS} })
    {
        next if($self->{TERMS}{$termsid}->{OOV_TERM_COUNT} eq "NA");
        push(@{ $arraytermsid }, $termsid) if($self->{TERMS}{$termsid}->{OOV_TERM_COUNT} > 0);
    }
}

sub listIV
{
    my($self, $arraytermsid) = @_;
    
    foreach my $termsid(sort keys %{ $self->{TERMS} })
    {
        next if($self->{TERMS}{$termsid}->{OOV_TERM_COUNT} eq "NA");
        push(@{ $arraytermsid }, $termsid) if($self->{TERMS}{$termsid}->{OOV_TERM_COUNT} == 0);
    }
}

1;

