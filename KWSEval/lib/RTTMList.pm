# KWSEval
# RTTMList.pm
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

package RTTMList;
use strict;
use RTTMRecord;
 
sub new
{
    my $class = shift;
    my $rttmfile = shift;
    my $self = {};

    $self->{FILE} = $rttmfile;
    $self->{DATA} = {};
    $self->{NOSCORE} = {};
	
    bless $self;
    $self->loadFile($rttmfile) if (defined($rttmfile));
    
    return $self;
}

sub unitTest
{
    my $file1 = "test1.rttm";
    
    print "Test RTTMList\n";
      
    print " Loading File...         ";
    my $rttml = new RTTMList($file1);
    print "OK\n";
    
    print " Finding terms (1)...    ";
    my $out1 = $rttml->findTermOccurrences("Yates", 0.1);
    print "OK\n";
    
    print " Finding terms (2)...    ";
    my $out2 = $rttml->findTermOccurrences("of the", 0.0);
    print "OK\n";
    
    print " Finding terms (3)...    ";
    my $out3 = $rttml->findTermOccurrences("has been a", 0.5);
    print "OK\n";
    
    print " Number of occurrences... ";
    if( (@$out1 == 2) and (@$out2 == 49) and (@$out3 == 3) )
    {
        print "OK\n";
    }
    else
    {
        print "FAILED\n";
        return 0;
    }
    
    print " Terms accuracy...       ";
    
    for(my $i=0; $i<@$out1; $i++)
    {
        foreach my $rttm(@{ $out1->[$i] })
        {
            if($rttm->{TOKEN} ne "Yates")
            {
                print "FAILED\n";
                return 0;
            }
        }
    }
    
    for(my $i=0; $i<@$out2; $i++)
    {
        if(@{ $out2->[$i] }[0]->{TOKEN} ne "of")
        {
            print "FAILED\n";
            return 0;
        }
        
        if(@{ $out2->[$i] }[1]->{TOKEN} ne "the")
        {
            print "FAILED\n";
            return 0;
        }
    }
    
    for(my $i=0; $i<@$out3; $i++)
    {
        if(@{ $out3->[$i] }[0]->{TOKEN} ne "has")
        {
            print "FAILED\n";
            return 0;
        }
        
        if(@{ $out3->[$i] }[1]->{TOKEN} ne "been")
        {
            print "FAILED\n";
            return 0;
        }
        
        if(@{ $out3->[$i] }[2]->{TOKEN} ne "a")
        {
            print "FAILED\n";
            return 0;
        }
    }
    
    print "OK\n";

    print " Threashold...           ";
    
    for(my $i=0; $i<@$out2; $i++)
    {
        if( sprintf("%.4f", (@{ $out2->[$i] }[1]->{BT} - @{ $out2->[$i] }[0]->{ET})) > 0.0 )
        {
            print "FAILED\n";
            return 0;
        }
    }
    
    for(my $i=0; $i<@$out3; $i++)
    {
        if( sprintf("%.4f", (@{ $out3->[$i] }[1]->{BT} - @{ $out3->[$i] }[0]->{ET})) > 0.5 )
        {
            print "FAILED\n";
            return 0;
        }
        
        if( sprintf("%.4f", (@{ $out3->[$i] }[2]->{BT} - @{ $out3->[$i] }[1]->{ET})) > 0.5 )
        {
            print "FAILED\n";
            return 0;
        }
    }
    
    print "OK\n";
    
    print " Case sensitive...       ";
    
    my $out4 = $rttml->findTermOccurrences("Jacques Chirac", 0.5);
    my $out5 = $rttml->findTermOccurrences("Jacques chirac", 0.5);
    
    if(@$out4 != @$out5)
    {
        print "FAILED\n";
        return 0;
    }
    
    print "OK\n";
    
    print " Space parsing...        ";
    
    my $out6 = $rttml->findTermOccurrences("    of       the   ", 0.0);
    
    if( @$out2 != @$out6 )
    {
        print "FAILED\n";
        return 0;
    }
    
    print "OK\n";
     
    print " Adjacent terms (1)...   ";
    my $out7 = $rttml->findTermOccurrences("word1 word2", 0.5);
    if( @$out7 != 3 )
    {
        print "FAILED\n";
        return 0;
    }
    print "OK\n";
     
    print " Adjacent terms (2)...   ";
    my $out8 = $rttml->findTermOccurrences("word1 word2 word3", 0.5);
    if( @$out8 != 2 )
    {
        print "FAILED\n";
        return 0;
    }
    print "OK\n";


    return 1;
}

sub toString
{
    my ($self) = @_;
    my ($key, $tok);

    print "Dump of RTTM File\n";
    print "   File: " . $self->{FILE} . "\n";
    print "   Records:\n";
    
    foreach my $file(sort keys  %{ $self->{DATA} })
    {
        foreach my $chan(sort keys  %{ $self->{DATA}{$file} })
        {
            for (my $i=0; $i<@{ $self->{DATA}{$file}{$chan} }; $i++)
            {
                print "   ".$self->{DATA}{$file}{$chan}[$i]->toString()."\n";
            }
        }
    }
}

sub loadFile
{
    my ($self, $rttmFile) = @_;
    
    print STDERR "Loading RTTM file '$rttmFile'.\n";
    
    open(RTTM, $rttmFile) or die "Unable to open for read RTTM file '$rttmFile'";
    
    while (<RTTM>)
    {
        chomp;
        
        # Remove comments which start with ;;
        s/;;.*$//;
        
        # Remove unwanted space at the begining and at the end of the line
        s/^\s*//;
        s/\s*$//;
        
        # if the line is empty then ignore
        next if ($_ =~ /^$/);
        
        my ($type, $file, $chan, $bt, $dur, $text, $stype, $spkr, $conf) = split(/\s+/,$_,9);
        
        if(uc($type) eq "LEXEME")
        {
            push (@{ $self->{DATA}{$file}{$chan} }, new RTTMRecord($type, $file, $chan, $bt, $dur, $text, $stype, $spkr, $conf) );
        }
        
        if(uc($type) eq "NOSCORE")
        {
            push (@{ $self->{NOSCORE}{$file}{$chan} }, new RTTMRecord($type, $file, $chan, $bt, $dur, undef, undef, undef, undef) );
        }
    }

    close RTTM;
}

sub findTermOccurrences
{
    my ($self, $term, $threshold) = @_;
    
    my @outList = ();
    $term =~ s/^\s*//;
    $term =~ s/\s*$//;
    my @terms = split(/\s+/, $term);
    
    foreach my $file(sort keys  %{ $self->{DATA} })
    {
        foreach my $chan(sort keys  %{ $self->{DATA}{$file} })
        {
            my %spkrs = ();
            
            foreach my $rttmrecord (@{ $self->{DATA}{$file}{$chan} })
            {
                push (@{ $spkrs{$rttmrecord->{SPKR}} }, $rttmrecord);
            }
            
            # for each speakers
            foreach my $spkrname (sort keys  %spkrs)
            {
                my @tmpList = ();
                my $termpos = 0;
                 
                # for each token
                for (my $i=0; $i<@{ $spkrs{$spkrname} }; $i++)
                {
                    #my $pattern1 = lc($terms[$termpos]);
                    #my $pattern2 = lc($spkrs{$spkrname}[$i]->{TOKEN});
                    
                    #if($pattern2 eq $pattern1)
                    
                    my $pattern1 = $terms[$termpos];
                   	my $pattern2 = $spkrs{$spkrname}[$i]->{TOKEN};
                    
                    if($pattern2 =~ /^$pattern1$/i)
                    {
                        my $contsearch = 1;            
                        push(@tmpList, $spkrs{$spkrname}[$i]);
                        
                        if($termpos != 0)
                        {
                            if( sprintf("%.4f",($spkrs{$spkrname}[$i]->{BT} - $spkrs{$spkrname}[$i-1]->{ET})) > $threshold)
                            {
                                $contsearch = 0;   
                            }
                        }
                        
                        if($contsearch)
                        {
                            $termpos++;
                        
                            if($termpos == @terms)
                            {
                                push(@outList, [ @tmpList ]);
                                @tmpList = ();              
                                $termpos = 0;
                            }
                        }
                        else
                        {
                            @tmpList = ();              
                            $termpos = 0;
                        }
                    }
                    else
                    {
                        $i-- if($termpos != 0);
                        @tmpList = ();
                        $termpos = 0;
                    }
                }
            }
        }
    }
        
    return(\@outList); 
}

1;
