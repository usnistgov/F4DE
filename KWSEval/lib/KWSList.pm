# KWSEval
# KWSList.pm
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. KWSEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

package KWSList;
use strict;
use KWSDetectedList;
require File::Spec;

sub new
{
    my $class = shift;
    my $stdlistfile = shift;
    my $self = {};

    $self->{STDLIST_FILENAME} = $stdlistfile;
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
    $self->loadFile($stdlistfile) if (defined($stdlistfile));
    $self->{DIFF_SCORE} = $self->{MAX_SCORE} - $self->{MIN_SCORE};
    
    return $self;
}

sub new_empty
{
    my $class = shift;
    my $stdlistfile = shift;
    my $self = {};

    $self->{STDLIST_FILENAME} = $stdlistfile;
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

sub loadFile
{
    my ($self, $stdlistf) = @_;
    my $stdlistfilestring = "";
    
    print STDERR "Loading KWS List file '$stdlistf'.\n";
    
    open(STDLIST, $stdlistf) or die "Unable to open for read KWSList file '$stdlistf'";
    
    while (<STDLIST>)
    {
    	chomp;
    	$stdlistfilestring .= $_;
    }
    
    close(STDLIST);
    
    #clean unwanted spaces
    $stdlistfilestring =~ s/\s+/ /g;
    $stdlistfilestring =~ s/> </></g;
    $stdlistfilestring =~ s/^\s*//;
    $stdlistfilestring =~ s/\s*$//;
    
    my $stdlisttag;
    my $detectedtermlist;

    if($stdlistfilestring =~ /(<stdlist .*?[^>]*>)([[^<]*<.*[^>]*>]*)<\/stdlist>/)
    {
        $stdlisttag = $1;
        $detectedtermlist = $2;
    }
    else
    {
        die "Invalid KWSList file";
    }
    
    if($stdlisttag =~ /termlist_filename="(.*?[^"]*)"/)
    {
       $self->{TERMLIST_FILENAME} = $1;
    }
    else
    {
        die "KWS: 'termlist_filename' option is missing in kwslist tag";
    }
    
    if($stdlisttag =~ /indexing_time="(.*?[^"]*)"/)
    {
       $self->{INDEXING_TIME} = $1;
    }
    else
    {
        die "KWS: 'indexing_time' option is missing in kwslist tag";
    }
    
    if($stdlisttag =~ /language="(.*?[^"]*)"/)
    {
       $self->{LANGUAGE} = $1;
    }
    else
    {
        die "KWS: 'language' option is missing in kwslist tag";
    }
    
    if($stdlisttag =~ /index_size="(.*?[^"]*)"/)
    {
       $self->{INDEX_SIZE} = $1;
    }
    else
    {
        die "KWS: 'index_size' option is missing in kwslist tag";
    }
    
    if($stdlisttag =~ /system_id="(.*?[^"]*)"/)
    {
       $self->{SYSTEM_ID} = $1;
    }
    else
    {
        die "KWS: 'system_id' option is missing in kwslist tag";
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
            die "KWS: 'termid' option is missing in detected_termlist tag";
        }
        
        if($detectedtag =~ /term_search_time="(.*?[^"]*)"/)
        {
           $detectedsearchtime = $1;
        }
        else
        {
            die "KWS: 'term_search_time' option is missing in detected_termlist tag";
        }
        
        if($detectedtag =~ /oov_term_count="(.*?[^"]*)"/)
        {
           $detectedoov = $1;
        }
        else
        {
            die "KWS: 'oov_term_search' option is missing in detected_termlist tag";
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
                die "KWS: 'file' option is missing in term tag";
            }
            
            if($termtag =~ /channel="(.*?[^"]*)"/)
            {
               $chan = $1;
            }
            else
            {
                die "KWS: 'channel' option is missing in term tag";
            }
            
            if($termtag =~ /tbeg="(.*?[^"]*)"/)
            {
               $bt = $1;
            }
            else
            {
                die "KWS: 'tbeg' option is missing in term tag";
            }
            
            if($termtag =~ /dur="(.*?[^"]*)"/)
            {
               $dur = $1;
            }
            else
            {
                die "KWS: 'dur' option is missing in term tag";
            }
            
            if($termtag =~ /score="(.*?[^"]*)"/)
            {
               $score = $1;
               $self->{MIN_SCORE} = $score if($score < $self->{MIN_SCORE});
               $self->{MAX_SCORE} = $score if($score > $self->{MAX_SCORE});
            }
            else
            {
                die "KWS: 'score' option is missing in term tag";
            }
            
            if($termtag =~ /decision="(.*?[^"]*)"/)
            {
               $decision = $1;
            }
            else
            {
                die "KWS: 'decision' option is missing in term tag";
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
    
    print STDERR "Saving KWS List file '$self->{STDLIST_FILENAME}'.\n";
    
    open(OUTPUTFILE, ">$self->{STDLIST_FILENAME}") or die "Cannot open to write '$self->{STDLIST_FILENAME}'";
     
    print OUTPUTFILE "<stdlist termlist_filename=\"$self->{TERMLIST_FILENAME}\" indexing_time=\"$self->{INDEXING_TIME}\" language=\"$self->{LANGUAGE}\" index_size=\"$self->{INDEX_SIZE}\" system_id=\"$self->{SYSTEM_ID}\">\n";
     
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
     
    print OUTPUTFILE "</stdlist>\n";
     
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

