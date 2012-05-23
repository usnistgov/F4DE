# KWSEval
# TermList.pm
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

package TermList;

use TranscriptHolder;
@ISA = qw(TranscriptHolder);

use strict;
use TermListRecord;
use MMisc;

sub new
{
    my $class = shift;
    my $termlistfile = shift;

    my $self = TranscriptHolder->new();

    $self->{TERMLIST_FILENAME} = $termlistfile;
    $self->{ECF_FILENAME} = "";
    $self->{VERSION} = "";
    $self->{TERMS} = {};
	
    bless $self;
    $self->loadFile($termlistfile) if (defined($termlistfile));
    
    return $self;
}

sub new_empty
{
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

sub loadFile
{
    my ($self, $tlistf) = @_;
    my $tlistfilestring = "";
    
    print STDERR "Loading Term List file '$tlistf'.\n";
    
    open(TERMLIST, $tlistf) 
      or MMisc::error_quit("Unable to open for read TermList file '$tlistf' : $!");
    if ($self->{ENCODING} eq "UTF-8"){
      binmode(TERMLIST, $self->getPerlEncodingString());
    }
    
    while (<TERMLIST>)
    {
        chomp;
        $tlistfilestring .= $_;
    }
    
    close(TERMLIST);

    #clean unwanted spaces
    $tlistfilestring =~ s/\s+/ /g;
    $tlistfilestring =~ s/> </></g;
    $tlistfilestring =~ s/^\s*//;
    $tlistfilestring =~ s/\s*$//;
    
    my $termlisttag;
    my $allterms;

    if($tlistfilestring =~ /(<termlist .*?[^>]*>)([[^<]*<.*[^>]*>]*)<\/termlist>/)
    {
        $termlisttag = $1;
        $allterms = $2;
    }
    else
    {
        MMisc::error_quit("Invalid TermList file");
    }
        
    if($termlisttag =~ /ecf_filename="(.*?[^"]*)"/)
    {
       $self->{ECF_FILENAME} = $1;
    }
    else
    {
         MMisc::error_quit("TermList: 'ecf_filename' option is missing in termlist tag");
    }
    
    if($termlisttag =~ /version="(.*?[^"]*)"/)
    {
       $self->{VERSION} = $1;
    }
    else
    {
         MMisc::error_quit("TermList: 'version_date' option is missing in termlist tag");
    }
    
    if($termlisttag =~ /language="(.*?[^"]*)"/)
    {
       die "Error: new TermList failed: \n   ".$self->errormsg()  if (! $self->setLanguage($1));
    }
    else
    {
         MMisc::error_quit("TermList: 'language' option is missing in termlist tag");
    }
            
    if($termlisttag =~ /encoding="(.*?[^"]*)"/)
    {
      die "Error: new TermList failed: \n   ".$self->errormsg() if (! $self->setEncoding($1));
    }
    else
    {
      ### Default encoding
       $self->setEncoding("UTF-8");
    }
    
    if($termlisttag =~ /compareNormalize="(.*?[^"]*)"/)
    {
      die "Error: new TermList failed: \n   ".$self->errormsg() if (! $self->setCompareNormalize($1));
      }
    
    ### Decode the data if it is UTF-8
    if ($self->{ENCODING} eq "UFT-8"){
      $tlistfilestring = decode_utf8( $tlistfilestring  );
    }
            
    while( $allterms =~ /(<term termid="(.*?[^"]*)"[^>]*><termtext>(.*?)<\/termtext>(.*?)<\/term>)/ )
    {
        my $previouslength = length($allterms);
        my $x = quotemeta($1);
                
        my %attrib;
        
        $attrib{TERMID} = $2;
        
        MMisc::error_quit("Term ID $attrib{TERMID} already exists")
            if (exists($self->{TERMS}{$attrib{TERMID}}));
        
        $attrib{TEXT} = $3;
        
        my $tmp = $4;
        my $allterminfo = "";
        
        if($tmp =~ /<terminfo>(.*?)<\/terminfo>/)
        {
            $allterminfo = $1;
        }
        
        while( $allterminfo =~ /(<attr><name>(.*?)<\/name><value>(.*?)<\/value><\/attr>)/ )
        {
            my $previouslengthy = length($allterminfo);
            $attrib{$2} = $3;
            $attrib{$2} = sprintf("%02d", $3) if($2 eq "Syllables");
            my $y = quotemeta($1);
            $allterminfo =~ s/$y//;
            MMisc::error_quit("Infinite Loop in 'TermList' parsing!")
                if ( ($previouslengthy == length($allterminfo)) && (length($allterminfo) != 0) );
        }
        
        $self->{TERMS}{$attrib{TERMID}} = new TermListRecord(\%attrib);
        
        $allterms =~ s/$x//;
        
        if( ($previouslength == length($allterms)) && (length($allterms) != 0) )
        {
            print STDERR "Error: Infinite Loop in 'TermList' parsing!\n";
            exit(0);
        }
    }
}

sub saveFile
{
    my ($self, $file) = @_;
    
    ### Write to a different file IF defined
    if (defined($file))
    {
		$self->{TERMLIST_FILENAME} = $file
    }

    open(OUTPUTFILE, ">$self->{TERMLIST_FILENAME}") 
      or MMisc::error_quit("cannot open file '$self->{TERMLIST_FILENAME}' : $!");
#    if ($self->{ENCODING} eq "UTF-8"){
#      binmode OUTPUTFILE, $self->getPerlEncodingString();
#    }
 
#    print OUTPUTFILE "<?xml version=\"1.0\" encoding=\"$self->{ENCODING}\"?>\n";
    
    print OUTPUTFILE "<termlist ecf_filename=\"$self->{ECF_FILENAME}\" language=\"$self->{LANGUAGE}\" encoding=\"$self->{ENCODING}\" compareNormalize=\"$self->{COMPARENORMALIZE}\" version=\"$self->{VERSION}\">\n";
    
    foreach my $termid(sort keys %{ $self->{TERMS} })
    {
        print OUTPUTFILE "<term termid=\"$termid\">\n  <termtext>$self->{TERMS}{$termid}->{TEXT}</termtext>\n";
        print OUTPUTFILE "  <terminfo>\n";
        
        foreach my $termattrname(sort keys %{ $self->{TERMS}{$termid} })
        {
            next if( ($termattrname eq "TERMID") || ($termattrname eq "TEXT") );
            print OUTPUTFILE "    <attr>\n      <name>$termattrname</name>\n      <value>$self->{TERMS}{$termid}->{$termattrname}</value>\n    </attr>\n";
        }
        
        print OUTPUTFILE "  </terminfo>\n</term>\n";
    }
    
    print OUTPUTFILE "</termlist>\n";
    
    close OUTPUTFILE;
}

1;

