# KWSEval
# KWSecf.pm
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

package KWSecf;
use strict;

use KWSecf_excerpt;
require File::Spec;
use Data::Dumper;

use MMisc;
 
sub new
{
    my $class = shift;
    my $ecffile = shift;
    my $self = {};

    $self->{FILE} = $ecffile;
    $self->{SIGN_DUR} = 0.0;
    $self->{EVAL_SIGN_DUR} = 0.0;
    $self->{VER} = "";
    $self->{EXCERPT} = ();
    $self->{FILECHANTIME} = {};
    $self->{FILE_EVAL_SIGN_DUR} = {};
	
    bless $self;
    $self->loadFile($ecffile) if (defined($ecffile));
    
    return $self;
}

sub new_empty
{
    my $class = shift;
    my $ecffile = shift;
    my $self = {};

    $self->{FILE} = $ecffile;
    $self->{SIGN_DUR} = 0.0;
    $self->{EVAL_SIGN_DUR} = 0.0;
    $self->{VER} = "";
    $self->{EXCERPT} = ();
    $self->{FILECHANTIME} = {};
    $self->{FILE_EVAL_SIGN_DUR} = {};
	
    bless $self;    
    return $self;
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
      $TotDur += $dur;
    }
  }
  return $TotDur;
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
    
    print " Loading File...          ";
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
    if (abs($ecf->calcTotalDur - 7997.148) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print " Calculating total duration(2)... ";
    if (abs($ecf->calcTotalDur(["bnews"]) - 3570.363) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print " Calculating total duration(3)... ";
    if (abs($ecf->calcTotalDur([], ["^.*_ARB_.*\/[12]", "ar_4489_exA\/[12]"]) - 3870.853) <= .0005) { print "OK\n"; }
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
    print "   Version: " . $self->{VER} . "\n";
    print "   Excerpt:\n";
    
    for (my $i=0; $i<@{ $self->{EXCERPT} }; $i++)
    {
        print "    ".$self->{EXCERPT}[$i]->toString()."\n";
    }
}

sub loadFile
{
    my ($self, $ecff) = @_;
    my $ecffilestring = "";

	print STDERR "Loading ECF file '$ecff'.\n";

    open(ECF, $ecff) 
      or MMisc::error_quit("Unable to open for read ECF file '$ecff' : $!");
    
    while (<ECF>)
    {
        chomp;
        $ecffilestring .= $_;
    }
    
    close(ECF);
    
    #clean unwanted spaces
    $ecffilestring =~ s/\s+/ /g;
    $ecffilestring =~ s/> </></g;
    $ecffilestring =~ s/^\s*//;
    $ecffilestring =~ s/\s*$//;
    
    my $ecftag;
    my $allexcerpt;

    if($ecffilestring =~ /(<ecf .*?[^>]*>)([[^<]*<.*[^>]*>]*)<\/ecf>/)
    {
        $ecftag = $1;
        $allexcerpt = $2;
    }
    else
    {
        MMisc::error_quit("Invalid ECF file");
    }
    
    if($ecftag =~ /source_signal_duration="([0-9]*[\.[0-9]*]*[^"]*)"/)
    {
       $self->{SIGN_DUR} = $1;
    }
    else
    {
        MMisc::error_quit("ECF: 'source_signal_duration' option is missing in ecf tag");
    }
    
    if($ecftag =~ /version="(.*?[^"]*)"/)
    {
       $self->{VER} = $1;
    }
    else
    {
        MMisc::error_quit("ECF: 'version' option is missing in ecf tag");
    }
    
    my $excerpt;
    
    while($allexcerpt =~ /(<excerpt .*?[^>]*\/>)/)
    {
        $excerpt = $1;
        
        my $audio_filename;
        my $channel;
        my $tbeg;
        my $dur;
        my $language;
        my $source_type;
        
        if($excerpt =~ /audio_filename="(.*?[^"]*)"/)
        {
           $audio_filename = $1;
        }
        else
        {
            MMisc::error_quit("ECF: 'audio_filename' option is missing in excerpt tag");
        }
        
        my ($volume,$directories,$purged_filename) = File::Spec->splitpath($audio_filename);
        
        if($purged_filename =~ /(.*?)\.(sph|wav)$/)
        {
            $purged_filename = $1;
        }
        
        if($excerpt =~ /channel="(.*?[^"]*)"/)
        {
           $channel = $1;
        }
        else
        {
            MMisc::error_quit("ECF: 'channel' option is missing in excerpt tag");
        }
        
        if($excerpt =~ /tbeg="(.*?[^"]*)"/)
        {
           $tbeg = $1;
        }
        else
        {
            MMisc::error_quit("ECF: 'tbeg' option is missing in excerpt tag");
        }
        
        if($excerpt =~ /dur="(.*?[^"]*)"/)
        {
           $dur = $1;
        }
        else
        {
            MMisc::error_quit("ECF: 'dur' option is missing in excerpt tag");
        }
        
        if($excerpt =~ /language="(.*?[^"]*)"/)
        {
           $language = $1;
        }
        else
        {
            MMisc::error_quit("ECF: 'language' option is missing in excerpt tag");
        }
        
        if($excerpt =~ /source_type="(.*?[^"]*)"/)
        {
           $source_type = $1;
        }
        else
        {
            MMisc::error_quit("ECF: 'source_type' option is missing in excerpt tag");
        }
        
        $self->{EVAL_SIGN_DUR} += sprintf("%.4f", $dur) if(!$self->{FILECHANTIME}{$purged_filename});

        push(@{ $self->{EXCERPT} }, new KWSecf_excerpt($audio_filename, $channel, $tbeg, $dur, $language, $source_type) );
        ### Track the source types for the reports
        push(@{ $self->{FILECHANTIME}{$purged_filename}{$channel} }, [ ($tbeg, $tbeg + $dur) ]);
        
        $self->{FILE_EVAL_SIGN_DUR}{$purged_filename} = 0 if(!$self->{FILE_EVAL_SIGN_DUR}{$purged_filename});
        $self->{FILE_EVAL_SIGN_DUR}{$purged_filename} += sprintf("%.4f", $dur);
                
        $allexcerpt =~ s/$excerpt//;
    }
    
    foreach my $filename(keys %{ $self->{FILE_EVAL_SIGN_DUR} })
    {
        my @tmp = keys %{ $self->{FILECHANTIME}{$filename} };
        my $nbrchannel = scalar(@tmp);
        $self->{FILE_EVAL_SIGN_DUR}{$filename} = $self->{FILE_EVAL_SIGN_DUR}{$filename}/$nbrchannel;
    }
}

sub SaveFile
{
     my($self) = @_;
     
     open(OUTPUTFILE, ">$self->{FILE}") 
       or MMisc::error_quit("Cannot open to write '$self->{FILE}' : $!");
     
     print OUTPUTFILE "<ecf source_signal_duration=\"$self->{SIGN_DUR}\" version=\"$self->{VER}\">\n";
     
     if($self->{EXCERPT})
     {
        for(my $i=0; $i<@{ $self->{EXCERPT} }; $i++)
        {
            my $tbegform = sprintf("%.3f", $self->{EXCERPT}[$i]->{TBEG});
            my $tdurform = sprintf("%.3f", $self->{EXCERPT}[$i]->{DUR});
            
            print OUTPUTFILE "<excerpt audio_filename=\"$self->{EXCERPT}[$i]->{AUDIO_FILENAME}\" channel=\"$self->{EXCERPT}[$i]->{CHANNEL}\" tbeg=\"$tbegform\" dur=\"$tdurform\" language=\"$self->{EXCERPT}[$i]->{LANGUAGE}\" source_type=\"$self->{EXCERPT}[$i]->{SOURCE_TYPE}\"/>\n";
        }
     }
     
     print OUTPUTFILE "</ecf>\n";
     
     close(OUTPUTFILE);
}

sub FilteringTime
{
    my($self, $file, $chan, $bt, $et) = @_;
    
    if($self->{FILECHANTIME}{$file}{$chan})
    {
        for(my $i=0; $i<@{ $self->{FILECHANTIME}{$file}{$chan} }; $i++)
        {
            if( ($bt >= $self->{FILECHANTIME}{$file}{$chan}[$i][0]) && ($et <= $self->{FILECHANTIME}{$file}{$chan}[$i][1]) )
            {
                return(1);
            }
        }
    }
    
    return(0);
}

1;

