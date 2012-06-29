package KWSList;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# KWSEval
# KWSList.pm
#
# Author(s): Martial Michel
# Original Author: Jerome Ajot
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
use xmllintHelper;

use Cwd 'abs_path';
use File::Basename 'dirname';

require File::Spec;
use MMisc;

sub new
{
    my $class = shift;
    my $kwslistfile = shift;
    my $self = {};

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
	
    bless $self;
    $self->loadFile($kwslistfile) if (defined($kwslistfile));
    $self->{DIFF_SCORE} = $self->{MAX_SCORE} - $self->{MIN_SCORE};
    
    return $self;
}

sub new_empty
{
    my $class = shift;
    my $kwslistfile = shift;
    my $self = {};

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
	
    bless $self;    
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

sub loadFile {
  my $self = shift @_;
  return($self->loadXMLFile(@_));
}

sub loadXMLFile {
  my ($self, $kwslistf) = @_;

  my $err = MMisc::check_file_r($kwslistf);
  MMisc::error_quit("Problem with input file ($kwslistf): $err")
      if (! MMisc::is_blank($err));

  my $modfp = MMisc::find_Module_path('KWSList');
  MMisc::error_quit("Could not obtain \'KWSList.pm\' location, aborting")
      if (! defined $modfp);

  my $f4b = 'F4DE_BASE';
  my $xmllint_env = "F4DE_XMLLINT";
  my $xsdpath = (exists $ENV{$f4b}) ? $ENV{$f4b} . "/lib/data" : $modfp . "/../../KWSEval/data";
  my @xsdfilesl = ('KWSEval-kwslist.xsd');

  print STDERR "Loading KWS List file '$kwslistf'.\n";

  # First let us use xmllint on the file XML file
  my $xmlh = new xmllintHelper();
  my $xmllint = MMisc::get_env_val($xmllint_env, "");
  MMisc::error_quit("While trying to set \'xmllint\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xmllint($xmllint));
  MMisc::error_quit("While trying to set \'xsdfilesl\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdfilesl(@xsdfilesl));
  MMisc::error_quit("While trying to set \'Xsdpath\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdpath($xsdpath));

  my $kwslistfilestring = $xmlh->run_xmllint($kwslistf);
  MMisc::error_quit("$kwslistf: \'xmllint\' validation failed [" . $xmlh->get_errormsg() . "]\n")
      if ($xmlh->error());

    #clean unwanted spaces
    $kwslistfilestring =~ s/\s+/ /g;
    $kwslistfilestring =~ s/> </></g;
    $kwslistfilestring =~ s/^\s*//;
    $kwslistfilestring =~ s/\s*$//;
    
    my $kwslisttag;
    my $detectedtermlist;

    if($kwslistfilestring =~ /(<kwslist .*?[^>]*>)([[^<]*<.*[^>]*>]*)<\/kwslist>/)
    {
        $kwslisttag = $1;
        $detectedtermlist = $2;
    }
    else
    {
        MMisc::error_quit("Invalid KWSList file");
    }
    
    if($kwslisttag =~ /termlist_filename="(.*?[^"]*)"/)
    {
       $self->{TERMLIST_FILENAME} = $1;
    }
    else
    {
        MMisc::error_quit("KWS: 'termlist_filename' option is missing in kwslist tag");
    }
    
    if($kwslisttag =~ /indexing_time="(.*?[^"]*)"/)
    {
       $self->{INDEXING_TIME} = $1;
    }
    else
    {
        MMisc::error_quit("KWS: 'indexing_time' option is missing in kwslist tag");
    }
    
    if($kwslisttag =~ /language="(.*?[^"]*)"/)
    {
       $self->{LANGUAGE} = $1;
    }
    else
    {
        MMisc::error_quit("KWS: 'language' option is missing in kwslist tag");
    }
    
    if($kwslisttag =~ /index_size="(.*?[^"]*)"/)
    {
       $self->{INDEX_SIZE} = $1;
    }
    else
    {
        MMisc::error_quit("KWS: 'index_size' option is missing in kwslist tag");
    }
    
    if($kwslisttag =~ /system_id="(.*?[^"]*)"/)
    {
       $self->{SYSTEM_ID} = $1;
    }
    else
    {
        MMisc::error_quit("KWS: 'system_id' option is missing in kwslist tag");
    }
    
    while( $detectedtermlist =~ /(<detected_termlist (.*?[^>]*)>(.*?)<\/detected_termlist>)/ )
    {
        my $blockdetected = $1;
        my $detectedtag = $2;
        my $allterms = $3;
        
        my $detectedtermid;
        my $detectedsearchtime;
        my $detectedoov;
        
        if($detectedtag =~ /termid="(.*?[^"]*)"/)
        {
           $detectedtermid = $1;
        }
        else
        {
            MMisc::error_quit("KWS: 'termid' option is missing in detected_termlist tag");
        }
        
        if($detectedtag =~ /term_search_time="(.*?[^"]*)"/)
        {
           $detectedsearchtime = $1;
        }
        else
        {
            MMisc::error_quit("KWS: 'term_search_time' option is missing in detected_termlist tag");
        }
        
        if($detectedtag =~ /oov_term_count="(.*?[^"]*)"/)
        {
           $detectedoov = $1;
        }
        else
        {
            MMisc::error_quit("KWS: 'oov_term_search' option is missing in detected_termlist tag");
        }

        my $detectedterm = new KWSDetectedList($detectedtermid, $detectedsearchtime, $detectedoov);
                
        while( $allterms =~ /(<term (.*?[^>]*)\/>)/ )
        {
            my $termtag = $1;
            
            my $file;
            my $chan;
            my $bt;
            my $dur;
            my $score;
            my $decision;
            
            if($termtag =~ /file="(.*?[^"]*)"/)
            {
                $file = $1;
               
                my ($volume,$directories,$purged_filename) = File::Spec->splitpath($file);
        
                if($purged_filename =~ /(.*?)\.sph$/)
                {
                    $purged_filename = $1;
                }
                
                $file = $purged_filename;
            }
            else
            {
                MMisc::error_quit("KWS: 'file' option is missing in term tag");
            }
            
            if($termtag =~ /channel="(.*?[^"]*)"/)
            {
               $chan = $1;
            }
            else
            {
                MMisc::error_quit("KWS: 'channel' option is missing in term tag");
            }
            
            if($termtag =~ /tbeg="(.*?[^"]*)"/)
            {
               $bt = $1;
            }
            else
            {
                MMisc::error_quit("KWS: 'tbeg' option is missing in term tag");
            }
            
            if($termtag =~ /dur="(.*?[^"]*)"/)
            {
               $dur = $1;
            }
            else
            {
                MMisc::error_quit("KWS: 'dur' option is missing in term tag");
            }
            
            if($termtag =~ /score="(.*?[^"]*)"/)
            {
               $score = $1;
               $self->{MIN_SCORE} = $score if($score < $self->{MIN_SCORE});
               $self->{MAX_SCORE} = $score if($score > $self->{MAX_SCORE});
            }
            else
            {
                MMisc::error_quit("KWS: 'score' option is missing in term tag");
            }
            
            if($termtag =~ /decision="(.*?[^"]*)"/)
            {
               $decision = $1;
            }
            else
            {
                MMisc::error_quit("KWS: 'decision' option is missing in term tag");
            }
            
            if($decision eq "YES")
            {
                $self->{MIN_YES} = $score if($score < $self->{MIN_YES});
            }
            elsif($decision eq "NO")
            {
                $self->{MAX_NO} = $score if($score > $self->{MAX_NO});
            }
            
            push (@{ $detectedterm->{TERMS} }, new KWSTermRecord($file, $chan, $bt, $dur, $score, $decision) ); 
                        
            $allterms =~ s/$termtag//;
        }        
        
        $self->{TERMS}{$detectedtermid} = $detectedterm;

        $detectedtermlist =~ s/$blockdetected//;
    }
}

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

