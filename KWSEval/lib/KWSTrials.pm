# KWSEval
# KWSTrials.pm
# Author: Jon Fiscus
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

package KWSTrials;
use strict;
use MMisc;
 
sub new
{
    my ($class, $taskId, $blockId, $decisionId) = @_;

    my $self =
    {
        "pooledtitle" => "$decisionId Weighted Curve",
        "trialweightedtitle" => "$blockId Weighted Curve",
        "is_poolable" => 1,
        "TaskID" => $taskId,
        "BlockID" => $blockId,
        "DecisionID" => $decisionId,
        "isSorted" => 1,
	"pooledTotalTrials" => undef,
        "trials" => {}  ### This gets built as you add trials
    };

    bless $self;
    return $self;
}

sub unitTest
{
    print "Test Trials\n";
    my $trial = new KWSTrials("Term Detection", "Term", "Occurrence");
    
    ## How to handle cases in KWSEval
    ## Mapped 
    #$trial->addTrial("she", 0.3, <DEC>, 1);
    ## unmapped Ref
    #$trial->addTrial("she", -inf, "NO", 1);
    ## unmapped sys
    #$trial->addTrial("she", 0.3, <DEC>, 0);
    
    $trial->addTrial("she", 0.7, "YES", 1);
    $trial->addTrial("she", 0.3, "NO", 1);
    $trial->addTrial("she", 0.2, "NO", 0);
    $trial->addTrial("second", 0.7, "YES", 1);
    $trial->addTrial("second", 0.3, "YES", 0);
    $trial->addTrial("second", 0.2, "NO", 0);
    $trial->addTrial("second", 0.3, "NO", 1);

    $trial->setPooledTotalTrials(78);

    ### Test the contents
    print " Copying structure...  ";
    my $sorted = $trial->copy();
    print "OK\n";
    print " Sorting structure...  ";
    $sorted->sortTrials();
    print "OK\n";
    print " Checking contents...  ";
    foreach my $tr($trial, $trial->copy(), $sorted){
	MMisc::error_quit("Not enough blocks")
            if (scalar(keys(%{ $tr->{trials} })) != 2);
	MMisc::error_quit("Not enough 'NO TARG' for block 'second'")
            if ( $tr->{trials}{"second"}{"NO TARG"} != 1);
	MMisc::error_quit("Not enough 'YES TARG' for block 'second'")
            if ( $tr->{trials}{"second"}{"YES TARG"} != 1);
	MMisc::error_quit("Not enough 'NO TARG' for block 'second'")
            if ( $tr->{trials}{"second"}{"NO NONTARG"} != 1);
	MMisc::error_quit("Not enough 'YES TARG' for block 'second'")
            if ( $tr->{trials}{"second"}{"YES NONTARG"} != 1);
	MMisc::error_quit("Not enough TARGs for block 'second'")
            if (scalar(@{ $tr->{trials}{"second"}{"TARG"} }) != 2);
	MMisc::error_quit("Not enough NONTARGs for block 'second'")
            if (scalar(@{ $tr->{trials}{"second"}{"NONTARG"} }) != 2);
	if ($tr->{isSorted}){
	    MMisc::error_quit("TARGs not sorted")
                if ($tr->{trials}{"second"}{"TARG"}[0] > $tr->{trials}{"second"}{"TARG"}[1]);
	    MMisc::error_quit("NONTARGs not sorted")
                if ($tr->{trials}{"second"}{"NONTARG"}[0] > $tr->{trials}{"second"}{"NONTARG"}[1]);
	}
	MMisc::error_quit("pooledTotalTrials not set")
            if ($tr->{pooledTotalTrials} != 78);

    }
    print "OK\n";
    return 1;
}

sub setPooledTotalTrials
{
    my ($self, $denom) = @_;
    $self->{pooledTotalTrials} = $denom;
}

sub getPooledTotalTrials
{
    my ($self) = @_;
    $self->{pooledTotalTrials};
}


sub addTrial
{
    my ($self, $block, $sysscore, $decision, $isTarg) = @_;

    MMisc::error_quit("Decision must be \"YES|NO|OMITED\" not '$decision'")
        if ($decision !~ /^(YES|NO|OMITTED)$/);
    my $attr = ($isTarg ? "TARG" : "NONTARG");

    if (! defined($self->{"trials"}{$block}{"title"}))
    {
        $self->{"trials"}{$block}{"TARG"} = [];
        $self->{"trials"}{$block}{"NONTARG"} = [];
        $self->{"trials"}{$block}{"title"} = "$block";
        $self->{"trials"}{$block}{"YES TARG"} = 0;
        $self->{"trials"}{$block}{"NO TARG"} = 0;
        $self->{"trials"}{$block}{"YES NONTARG"} = 0;
        $self->{"trials"}{$block}{"NO NONTARG"} = 0;
        $self->{"trials"}{$block}{"OMITTED TARG"} = 0;
    }

    ## update the counts
    $self->{"isSorted"} = 0;
    if ($decision ne "OMITTED"){
	push(@{ $self->{"trials"}{$block}{$attr} }, $sysscore);
    }
    $self->{"trials"}{$block}{$decision." $attr"} ++;
}

sub dump
{
    my($self, $OUT, $pre) = @_;
    
    my($k1, $k2, $k3);
    print $OUT "${pre}Dump of Trial_data  isSorted=".$self->{isSorted}."\n";
    
    foreach $k1(sort(keys %$self))
    {
        if ($k1 eq 'trials')
        {
            print $OUT "${pre}   $k1 -> $self->{$k1}\n";
            foreach $k2(keys %{ $self->{$k1} })
            {
                print $OUT "${pre}      $k2 -> $self->{$k1}{$k2}\n";
                
                foreach $k3(sort keys %{ $self->{$k1}{$k2} })
                {
                    if ($k3 eq "TARG" || $k3 eq "NONTARG")
                    {
                        my(@a) = @{ $self->{$k1}{$k2}{$k3} };
                        print $OUT "${pre}         $k3 (".scalar(@a).") -> (";
                        
                        if ($#a > 5)
                        {
                            foreach $_(0..2)
                            {
                                print $OUT "$a[$_],";
                            }

                            print $OUT "...";

                            foreach $_(($#a-2)..$#a)
                            {
                                print $OUT ",$a[$_]";
                            }
                        }
                        else
                        {
                            print $OUT join(",",@a);
                        }

                        print $OUT ")\n";
                    }
                    else
                    {
                        print $OUT "${pre}         $k3 -> $self->{$k1}{$k2}{$k3}\n";
                    }
                }
            }
        }
        else
        {
            print $OUT "${pre}   $k1 -> $self->{$k1}\n";
        }
    }	
}

sub copy()
{
    my ($self, $block) = @_;
    my ($copy) = new KWSTrials($self->{TaskID}, $self->{BlockID}, $self->{DecisionID});
    
    my @blocks;
    if (defined($block))
    {
        push @blocks, $block;
    } 
    else 
    {
        @blocks = keys %{ $self->{trials} };
    }
    
    foreach my $block(@blocks)
    {
        foreach my $param(keys %{ $self->{trials}{$block} })
        {
            if ($param eq "TARG" || $param eq "NONTARG")
            {
                my(@a) = @{ $self->{trials}{$block}{$param} };
                $copy->{trials}{$block}{$param} = [ @a ];
            }
            else
            {
                $copy->{trials}{$block}{$param} = $self->{trials}{$block}{$param};
            }
        }
    }
    
    $copy->{isSorted} = $self->{isSorted}; 
    $copy->{pooledTotalTrials} = $self->{pooledTotalTrials}; 
    $copy;
}

sub dumpGrid()
{
    my ($self) = @_;

    foreach my $block(keys %{ $self->{'trials'} }) {
	foreach my $var(sort keys %{ $self->{'trials'}{$block} }) {
	    if ($var eq "TARG" || $var eq "NONTARG") {
		foreach my $sc ( @{ $self->{'trials'}{$block}{$var} }){
		    printf "GRID $sc $block-$var %12.10f $sc-$block\n", $sc;
		}
	    }
	}
    }
}

sub numerically
{
    $a <=> $b;
}

sub sortTrials()
{
    my ($self) = @_;
    return if ($self->{"isSorted"});

    foreach my $block(keys %{ $self->{trials} })
    {
	   $self->{trials}{$block}{TARG} = [ sort numerically @{ $self->{trials}{$block}{TARG} } ];
	   $self->{trials}{$block}{NONTARG} = [ sort numerically @{ $self->{trials}{$block}{NONTARG} } ];
    }
    	
    $self->{"isSorted"} = 1;
}

1;
