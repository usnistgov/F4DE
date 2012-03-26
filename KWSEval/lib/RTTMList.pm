



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
use Data::Dumper;
use RTTMRecord;
use MMisc;
 
sub new
{
    my $class = shift;
    my $rttmfile = shift;
    my $self = {};

    $self->{FILE} = $rttmfile;
    $self->{DATA} = {};
    $self->{NOSCORE} = {};
    $self->{TERMLKUP} = {};
	
    bless $self;
    $self->loadFile($rttmfile) if (defined($rttmfile));
    
    return $self;
}

sub unitTest
{
    my ($file1) = @_;

    my $err = MMisc::check_file_r($file1);
    if (! MMisc::is_blank($err)) {
      print "Issue with needed test file ($file1) : $err\n";
      return(0);
    }

    print "Test RTTMList\n";
      
    print " Loading File...          ";
    my $rttml = new RTTMList($file1);
    print "OK\n";
    
    print " Finding terms (1)...     ";
    my $out1 = $rttml->findTermOccurrences("Yates", 0.1);
    print "OK\n";
    
    print " Finding terms (2)...     ";
    my $out2 = $rttml->findTermOccurrences("of the", 0.0);
    print "OK\n";
    
    print " Finding terms (3)...     ";
    my $out3 = $rttml->findTermOccurrences("has been a", 0.5);
    print "OK\n";
    
    print " Finding terms (9)...     ";
    my $out9 = $rttml->findTermOccurrences("r", 0.5);
    print "OK\n";
    
    print " Finding terms (10)...     ";
    my $out10 = $rttml->findTermOccurrences("uh", 0.5);
    print "OK\n";
    
    print " Finding terms (11)...     ";
    my $out11 = $rttml->findTermOccurrences("two after", 0.5);
    print "OK\n";
    
    print " Finding terms (12)...     ";
    my $out12 = $rttml->findTermOccurrences("s.", 0.5);
    print "OK\n";
    
    print " Number of occurrences... ";
    if( (@$out1 == 2) and (@$out2 == 49) and (@$out3 == 3) and (@$out9 == 0) and (@$out10 == 0) and (@$out11 == 1) 
        and (@$out12 == 11) )
    {
        print "OK\n";
    }
    else
    {
        print "FAILED\n";
        return 0;
    }
    
    print " Terms accuracy...        ";
    
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

    print " Threshold...             ";
    
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
    
    print " Case sensitive...        ";
    
    my $out4 = $rttml->findTermOccurrences("Jacques Chirac", 0.5);
    my $out5 = $rttml->findTermOccurrences("Jacques chirac", 0.5);
    
    if(@$out4 != @$out5)
    {
        print "FAILED\n";
        return 0;
    }
    
    print "OK\n";
    
    print " Space parsing...         ";
    
    my $out6 = $rttml->findTermOccurrences("    of       the   ", 0.0);
    
    if( @$out2 != @$out6 )
    {
        print "FAILED\n";
        return 0;
    }
    
    print "OK\n";
     
    print " Adjacent terms (1)...    ";
    my $out7 = $rttml->findTermOccurrences("word1 word2", 0.5);
    if( @$out7 != 3 )
    {
        print "FAILED\n";
        return 0;
    }
    print "OK\n";
     
    print " Adjacent terms (2)...    ";
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
    
    open(RTTM, $rttmFile) or MMisc::error_quit("Unable to open for read RTTM file '$rttmFile' : $!");
    
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
        {
        if(uc($type) eq "LEXEME")
        {
            push (@{ $self->{DATA}{$file}{$chan} }, new RTTMRecord($type, $file, $chan, $bt, $dur, $text, $stype, $spkr, $conf) );
        }  
        elsif(uc($type) eq "NOSCORE")
        {
            push (@{ $self->{NOSCORE}{$file}{$chan} }, new RTTMRecord($type, $file, $chan, $bt, $dur, undef, undef, undef, undef) );
        }
	}
    }

    foreach my $file(sort keys %{ $self->{DATA} })
    {
      foreach my $chan(sort keys %{ $self->{DATA}{$file} })
      {
	my %spkrs = ();

	foreach my $rttmrecord (@{ $self->{DATA}{$file}{$chan} })
	{
	  push (@{ $spkrs{$rttmrecord->{SPKR}} }, $rttmrecord);
	}

	foreach my $spkrname (sort keys %spkrs)
	{
	  for (my $i=0; $i<@{ $spkrs{$spkrname} }; $i++)
	  {
	    #Link speaker records
	    if ($i<@{ $spkrs{$spkrname} }-1)
	    {
	      $spkrs{$spkrname}[$i]->{NEXT} = $spkrs{$spkrname}[$i+1];
	    }

	    next if ($spkrs{$spkrname}[$i]->{STYPE} eq "frag");
	    next if ($spkrs{$spkrname}[$i]->{STYPE} eq "fp");

	    #Add records to term lookup table
	    push (@{ $self->{TERMLKUP}{lc $spkrs{$spkrname}[$i]->{TOKEN}} },  $spkrs{$spkrname}[$i]);
	  }
	}
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
    $term = lc $term;
    my @terms = split(/\s+/, $term);
    #print Dumper (\@terms);
    #Currently no order to returned matches
    foreach my $record (@{ $self->{TERMLKUP}{$terms[0]} })
    {
      my @tmpList = ();
      push (@tmpList, $record);
      my $termpos = 1;
      my $currecord = $record;
      my $hoprecord = $record;
      while ($termpos < @terms)
      {
	if (defined $hoprecord->{NEXT} &&
	    sprintf("%.4f", ($hoprecord->{NEXT}{BT} - $hoprecord->{ET})) <= $threshold)
	{
	  
	  if ($hoprecord->{NEXT}{STYPE} eq "frag" ||
	      $hoprecord->{NEXT}{STYPE} eq "fp")
	  {
	    $hoprecord = $hoprecord->{NEXT};
	    next;
	  }

	  my $pattern1 = $terms[$termpos];
	  my $pattern2 = $hoprecord->{NEXT}{TOKEN};

	  if ($pattern2 =~ /^\Q$pattern1\E$/i)
	  {
	    $currecord = $hoprecord->{NEXT};
	    $hoprecord = $currecord;
	    push (@tmpList, $currecord);
	  }
	  else
	  {
	    #Next record wasn't a match
	    @tmpList = ();
	    last;
	  }
	}
	else
	{
	  #Reached the end of records for that speaker or threshold not met
	  @tmpList = ();
	  last;
	}

	$termpos++;
      }

      push (@outList, [ @tmpList ]) if (@tmpList > 0); 
    }

    return(\@outList); 
}

1;
