# KWSEval
# CacheOccurrences.pm
# Author: Jerome Ajot
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

package CacheOccurrences;

use TranscriptHolder;
@ISA = qw(TranscriptHolder);

use strict;

use KWSTermRecord;
use TermListRecord;
use TermList;
use Data::Dumper;
use MMisc;


sub new
{
    my $class = shift;

    my $self = TranscriptHolder->new();

    $self->{FILENAME} = shift;
    $self->{SYSTEMVRTTM} = shift;
    $self->{THRESHOLD} = shift;
    $self->{REFLIST} = shift;
    die "Error: New CacheOccurrences failed: \n   ".$self->errormsg()
      if (! $self->setEncoding(shift));
    die "Error: New CacheOccurrences failed: \n   ".$self->errormsg()
      if (! $self->setCompareNormalize(shift));
	
    bless $self;    
    return $self;
}

sub saveFile
{
    my ($self, $termlist) = @_;

	print STDERR "Writing cache file to '$self->{FILENAME}'.\n";
        
    open(CACHE_FILE, ">$self->{FILENAME}") 
      or MMisc::error_quit("cannot open cache file '$self->{FILENAME}' : $!");
    if ($self->{ENCODING} eq "UTF-8"){
      binmode CACHE_FILE, $self->getPerlEncodingString();
    }

    print CACHE_FILE "<rttm_cache_file system_V=\"$self->{SYSTEMVRTTM}\" find_threshold=\"$self->{THRESHOLD}\" encoding=\"$self->{ENCODING}\">\n";
    
    foreach my $termid(sort keys %{ $self->{REFLIST} })
    {
		foreach my $terms(keys %{ $self->{REFLIST}{$termid} })
		{
			print CACHE_FILE "    <term termid=\"$termid\"><termtext>$terms</termtext>\n";
			
			if(exists($self->{REFLIST}{$termid}{$terms}))
			{
				for(my $i=0; $i<@{ $self->{REFLIST}{$termid}{$terms} }; $i++)
				{
					print CACHE_FILE "        <occurrence file=\"$self->{REFLIST}{$termid}{$terms}[$i]->{FILE}\" channel=\"$self->{REFLIST}{$termid}{$terms}[$i]->{CHAN}\" begt=\"$self->{REFLIST}{$termid}{$terms}[$i]->{BT}\" dur=\"$self->{REFLIST}{$termid}{$terms}[$i]->{DUR}\"/>\n";
				}
			}
			
			print CACHE_FILE "    </term>\n";
		}
    }
    
    print CACHE_FILE "</rttm_cache_file>\n";
    
    close(CACHE_FILE);
}

sub loadFile
{
    my ($self, $terms) = @_;
    my $cachefilestring = "";
    
    print STDERR "Loading Cache file '$self->{FILENAME}'.\n";
    
    open(CACHE_FILE, "<$self->{FILENAME}") 
      or MMisc::error_quit("cannot open cache file '$self->{FILENAME}' : $!");
    
    while (<CACHE_FILE>)
    {
        chomp;
        $cachefilestring .= $_;
    }
    
    close(CACHE_FILE);
    
    #clean unwanted spaces
    $cachefilestring =~ s/\s+/ /g;
    $cachefilestring =~ s/> </></g;
    $cachefilestring =~ s/^\s*//;
    $cachefilestring =~ s/\s*$//;
    
    my $cachelisttag;
    my $termlist;

    if($cachefilestring =~ /(<rttm_cache_file .*?[^>]*>)([[^<]*<.*[^>]*>]*)<\/rttm_cache_file>/)
    {
        $cachelisttag = $1;
        $termlist = $2;
    }
    else
    {
        MMisc::error_quit("Invalid Cache file");
    }
    
    if($cachelisttag =~ /system_V="(.*?[^"]*)"/)
    {
       $self->{SYSTEMVRTTM} = $1;
    }
    else
    {
        MMisc::error_quit("Cache: 'system_V' option is missing in rttm_cache_file tag");
    }
    
    if($cachelisttag =~ /find_threshold="(.*?[^"]*)"/)
    {
       $self->{THRESHOLD} = $1;
    }
    else
    {
        MMisc::error_quit("Cache: 'find_threshold' option is missing in rttm_cache_file tag");
    }

    if($cachelisttag =~ /encoding="(.*?[^"]*)"/)
    {
       $self->{ENCODING} = $1;
    } else {
       $self->{ENCODING} = "UTF-8";
    }
    
        ### Decode the data if it is UTF-8
    if ($self->{ENCODING} eq "UFT-8"){
      $termlist = decode_utf8( $termlist  );
    }

    while( $termlist =~ /(<term termid="(.*?[^"]*)"[^>]*><termtext>(.*?)<\/termtext>(.*?)<\/term>)/ )
    {
        my $allterm = $1;
        my $termid = $2;
        my $termtext = $3;
        my $occurrences = $4;
                
        while( $occurrences =~ /(<occurrence (.*?[^>]*)\/>)/ )
        {
            my $alloccur = $1;
            my $alloptions = $2;
            
            my $file;
            my $channel;
            my $begt;
            my $dur;
            
            if($alloptions =~ /file="(.*?[^"]*)"/)
            {
                $file = $1;
            }
            else
            {
                MMisc::error_quit("Cache: 'file' option is missing in occurrence tag");
            }
            
            if($alloptions =~ /channel="(.*?[^"]*)"/)
            {
                $channel = $1;
            }
            else
            {
                MMisc::error_quit("Cache: 'channel' option is missing in occurrence tag");
            }
            
            if($alloptions =~ /begt="(.*?[^"]*)"/)
            {
                $begt = $1;
            }
            else
            {
                MMisc::error_quit("Cache: 'begt' option is missing in occurrence tag");
            }
            
            if($alloptions =~ /dur="(.*?[^"]*)"/)
            {
                $dur = $1;
            }
            else
            {
                MMisc::error_quit("Cache: 'dur' option is missing in occurrence tag");
            }
            
            push( @{ $self->{REFLIST}{$termid}{$termtext} }, new KWSTermRecord($file, $channel, $begt, $dur, undef, undef));
                        
            $occurrences =~ s/$alloccur//;
        }
                
        $termlist =~ s/$allterm//;
    }

    close(CACHE_FILE);
}

1;
