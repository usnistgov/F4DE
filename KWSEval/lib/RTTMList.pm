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

use TranscriptHolder;
@ISA = qw(TranscriptHolder);

use strict;
use Data::Dumper;
use RTTMRecord;
use MMisc;
use Encode;
use encoding 'euc-cn';
use encoding 'utf8';

sub new
{
    my $class = shift;
    my $rttmfile = shift;
    my $language = shift;
    my $normalizationType = shift;
    my $encoding = shift;

    my $self = TranscriptHolder->new();

    $self->{FILE} = $rttmfile;
    $self->{DATA} = {};
    $self->{NOSCORE} = {};
    $self->{TERMLKUP} = {};
	
    bless $self;
    die "Failed: new RTTM failed: \n   ".$self->errormsg()
      if (! $self->setCompareNormalize($normalizationType));
    die "Failed: new RTTM failed: \n   ".$self->errormsg()
      if (! $self->setEncoding($encoding));
    die "Failed: new RTTM failed: \n   ".$self->errormsg()
      if (! $self->setLanguage($language));
    
    $self->loadFile($rttmfile) if (defined($rttmfile));
    
    return $self;
}

sub unitTestFind
{
  my ($rttm, $text, $exp, $thresh) = (@_);

  print " Finding terms ($text, thresh=$thresh)...     ";
  my $out = $rttm->findTermOccurrences($text, $thresh);
  if (@$out != $exp) { 
    print "Failed: ".scalar(@$out)." != $exp\n"; 
    for(my $i=0; $i<@$out; $i++) {
        print "   num $i ";
        foreach my $rttm(@{ $out->[$i] }) {
            print $rttm->{TOKEN}.":".$rttm->{BT}." ";
        }
        print "\n";
     }
  }
  print "OK\n";
  return(1);
}


sub unitTest
{
    my ($file1, $file2) = @_;

    my $err = MMisc::check_file_r($file1);
    if (! MMisc::is_blank($err)) {
      print "Issue with needed test file ($file1) : $err\n";
      return(0);
    }
    $err = MMisc::check_file_r($file2);
    if (! MMisc::is_blank($err)) {
      print "Issue with needed test file ($file2) : $err\n";
      return(0);
    }

    print "Test RTTMList\n";
      
    print " Loading English File (lowerecase normalization)...          ";
    my $rttm_eng_norm = new RTTMList($file1,"english","lowercase", "");
    print "OK\n";

    return 0 unless(unitTestFind($rttm_eng_norm, "Yates",        2,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "of the",       53, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "of the",       49, 0.01));
    return 0 unless(unitTestFind($rttm_eng_norm, "has been a",   3,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "r",            0,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "uh",           0,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "two after",    1,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "s.",           11, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "karachi used", 1,  0.1));
    print " Case insenstivity\n";
    return 0 unless(unitTestFind($rttm_eng_norm, "Jacques Chirac", 2,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "jacques chirac", 2,  0.1));

    print " Loading English File (no normalization)...          ";
    my $rttm_eng_nonorm = new RTTMList($file1,"english","","");
    print "OK\n";

    return 0 unless(unitTestFind($rttm_eng_nonorm, "Yates",        2, 0.1));
    return 0 unless(unitTestFind($rttm_eng_nonorm, "yates",        0, 0.1));
    return 0 unless(unitTestFind($rttm_eng_nonorm, "s.",           0, 0.1));
    return 0 unless(unitTestFind($rttm_eng_nonorm, "karachi used", 0, 0.1));

    print "Space parsing...         \n";
    return 0 unless(unitTestFind($rttm_eng_norm, "   of the",       53, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "   of    the",    53, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "of    the  ",     53, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "   of    the   ", 53, 0.1));
     
    print " Adjacent terms...    \n";
    return 0 unless(unitTestFind($rttm_eng_norm, "word1 word2",       3, 0.5));
    return 0 unless(unitTestFind($rttm_eng_norm, "word1 word2 word3", 2, 0.5));

    print "Loading Cantonese File (no normalization)...          ";
    my $rttm_cant = new RTTMList($file2,"cantonese","","UTF-8");
    print "OK\n";

    return 0 unless(unitTestFind($rttm_cant, $rttm_cant->{DATA}{"file"}{1}[0]->{TOKEN}, 2, 0.5));
    return 0 unless(unitTestFind($rttm_cant, 
                                 $rttm_cant->{DATA}{"file"}{1}[14]->{TOKEN} . " " .
                                 $rttm_cant->{DATA}{"file"}{1}[15]->{TOKEN}, 
                                 2, 0.5));


    return 1;
}

sub toString
{
    my ($self) = @_;
    my ($key, $tok);
    my $str = "";
    
    $str .= "Dump of RTTM File\n";
    $str .= "   File: " . $self->{FILE} . "\n";
    $str .=  "   Records:\n";
    
    foreach my $file(sort keys  %{ $self->{DATA} })
    {
        foreach my $chan(sort keys  %{ $self->{DATA}{$file} })
        {
            for (my $i=0; $i<@{ $self->{DATA}{$file}{$chan} }; $i++)
            {
                $str .= "   ".$self->{DATA}{$file}{$chan}[$i]->toString()."\n";
            }
        }
    }
    return $str;
}

sub loadFile
{
    my ($self, $rttmFile) = @_;
    
    print STDERR "Loading RTTM file '$rttmFile' encoding /$self->{ENCODING}/.\n";
    
    open(RTTM, $rttmFile) or MMisc::error_quit("Unable to open for read RTTM file '$rttmFile' : $!");
    if ($self->{ENCODING} eq "UTF-8"){
      binmode(RTTM, $self->getPerlEncodingString());
    }
    
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
	    my $tok = $spkrs{$spkrname}[$i]->{TOKEN};
	    $tok = lc($tok) if ($self->{COMPARENORMALIZE} eq "lowercase");
	    push (@{ $self->{TERMLKUP}{ $tok }},  $spkrs{$spkrname}[$i]);
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
    $term = lc $term if ($self->{COMPARENORMALIZE} eq "lowercase");
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
