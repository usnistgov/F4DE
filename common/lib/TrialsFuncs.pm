# STDEval
# Trials.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. STDEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

package Trials;
use strict;
use Data::Dumper;
 

sub new
{
    my ($class, $taskId, $blockId, $decisionId, $metricParams) = @_;

    die "Error: new Trial() called without a \$metricParams value" if (! defined($metricParams));

    my $self =
    {
        "TaskID" => $taskId,
        "BlockID" => $blockId,
        "DecisionID" => $decisionId,
        "isSorted" => 1,
        "trials" => {},  ### This gets built as you add trials
        "metricParams" => $metricParams  ### Hash table for passing info to the Metric* objects 
    };

    bless $self;
    return $self;
}

sub unitTest
{
    print "Test Trials\n";
    my $trial = new Trials("Term Detection", "Term", "Occurrence", { (TOTAL_TRIALS => 78) } );
    
    ## How to handle cases in STDEval
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

    ### Test the contents
    print " Copying structure...  ";
    my $sorted = $trial->copy();
    print "OK\n";
    print " Sorting structure...  ";
    $sorted->sortTrials();
    print "OK\n";
    print " Checking contents...  ";
    foreach my $tr($trial, $trial->copy(), $sorted){
	die "Error: Not enough blocks" if (scalar(keys(%{ $tr->{"trials"} })) != 2);
	die "Error: Not enough 'NO TARG' for block 'second'" if ( $tr->{"trials"}{"second"}{"NO TARG"} != 1);
	die "Error: Not enough 'YES TARG' for block 'second'" if ( $tr->{"trials"}{"second"}{"YES TARG"} != 1);
	die "Error: Not enough 'NO TARG' for block 'second'" if ( $tr->{"trials"}{"second"}{"NO NONTARG"} != 1);
	die "Error: Not enough 'YES TARG' for block 'second'" if ( $tr->{"trials"}{"second"}{"YES NONTARG"} != 1);
	die "Error: Not enough TARGs for block 'second'" if (scalar(@{ $tr->{"trials"}{"second"}{"TARG"} }) != 2);
	die "Error: Not enough NONTARGs for block 'second'" if (scalar(@{ $tr->{"trials"}{"second"}{"NONTARG"} }) != 2);
	if ($tr->{isSorted}){
	    die "Error: TARGs not sorted" if ($tr->{"trials"}{"second"}{"TARG"}[0] > $tr->{"trials"}{"second"}{"TARG"}[1]);
	    die "Error: NONTARGs not sorted" if ($tr->{"trials"}{"second"}{"NONTARG"}[0] > $tr->{"trials"}{"second"}{"NONTARG"}[1]);
	}
	die "Error: pooledTotal trials does not exist" if (! $tr->getMetricParamValueExists("TOTAL_TRIALS"));
	die "Error: pooledTotal trials not set" if ($tr->getMetricParamValue("TOTAL_TRIALS") != 78);

    }
    print "OK\n";
    return 1;
}

sub addTrial
{
    my ($self, $block, $sysscore, $decision, $isTarg) = @_;

    die "Error: Decision must be \"YES|NO|OMITTED\" not '$decision'" if ($decision !~ /^(YES|NO|OMITTED)$/);
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

sub getTaskID(){
    my($self) = @_;
    $self->{TaskID};
}

sub getBlockID(){
    my($self) = @_;
    $self->{BlockID};
}

sub getDecisionID(){
    my($self) = @_;
    $self->{DecisionID};
}

sub getMetricParams(){
    my($self) = @_;
    $self->{metricParams};
}

sub getMetricParamsStr(){
    my($self) = @_;
    my $str = "{ (";
    foreach my $k(keys %{ $self->{metricParams} }){
        $str .= "'$k' => '$self->{metricParams}->{$k}', ";
    }
    $str .= ') }';
    $str;   
}

sub setMetricParamValue(){
    my($self, $key, $val) = @_;
    $self->{metricParams}->{$key} = $val;
}

sub getMetricParamValueExists(){
    my($self, $key) = @_;
    exists($self->{metricParams}->{$key});
}

sub getMetricParamValue(){
    my($self, $key) = @_;
    $self->{metricParams}->{$key};
}

sub dump
{
    my($self, $OUT, $pre) = @_;
    
    my($k1, $k2, $k3);
    print $OUT "${pre}Dump of Trial_data  isSorted=".$self->{isSorted}."\n";
    
    foreach $k1(sort(keys %$self))
    {
        if ($k1 eq "trials")
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
    my ($copy) = new Trials($self->getTaskID(), $self->getBlockID(), $self->getDecisionID(), $self->getMetricParams());
    
    my @blocks;
    if (defined($block))
    {
        push @blocks, $block;
    } 
    else 
    {
        @blocks = keys %{ $self->{"trials"} };
    }
    
    foreach my $block(@blocks)
    {
        foreach my $param(keys %{ $self->{"trials"}{$block} })
        {
            if ($param eq "TARG" || $param eq "NONTARG")
            {
                my(@a) = @{ $self->{"trials"}{$block}{$param} };
                $copy->{"trials"}{$block}{$param} = [ @a ];
            }
            else
            {
                $copy->{"trials"}{$block}{$param} = $self->{"trials"}{$block}{$param};
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

    foreach my $block(keys %{ $self->{"trials"} }) {
	foreach my $var(sort keys %{ $self->{"trials"}{$block} }) {
	    if ($var eq "TARG" || $var eq "NONTARG") {
		foreach my $sc ( @{ $self->{"trials"}{$block}{$var} }){
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

    foreach my $block(keys %{ $self->{"trials"} })
    {
	   $self->{"trials"}{$block}{TARG} = [ sort numerically @{ $self->{"trials"}{$block}{TARG} } ];
	   $self->{"trials"}{$block}{NONTARG} = [ sort numerically @{ $self->{"trials"}{$block}{NONTARG} } ];
    }
    	
    $self->{"isSorted"} = 1;
}

sub getBlockIDs(){
    my ($self, $block) = @_;
    keys %{ $self->{"trials"} };
}

sub getNumTargScr(){
    my ($self, $block) = @_;
    scalar(@{ $self->{"trials"}{$block}{"TARG"} });
}

sub getNumNoTarg(){
    my ($self, $block) = @_;
    $self->{"trials"}->{$block}->{"NO TARG"};
}

sub getNumTarg(){
    my ($self, $block) = @_;
    ($self->{"trials"}->{$block}->{"NO TARG"} + 
     $self->{"trials"}->{$block}->{"YES TARG"} +
     $self->{"trials"}->{$block}->{"OMITTED TARG"})
}

sub getNumYesTarg(){
    my ($self, $block) = @_;
    $self->{"trials"}->{$block}->{"YES TARG"};
}

sub getNumOmittedTarg(){
    my ($self, $block) = @_;
    $self->{"trials"}->{$block}->{"OMITTED TARG"};
}

sub getNumNonTargScr(){
    my ($self, $block) = @_;
    scalar(@{ $self->{"trials"}{$block}{"NONTARG"} });
}

sub getNumNoNonTarg(){
    my ($self, $block) = @_;
    $self->{"trials"}->{$block}->{"NO NONTARG"};
}

sub getNumYesNonTarg(){
    my ($self, $block) = @_;
    $self->{"trials"}->{$block}->{"YES NONTARG"};
}

sub getNumNonTarg(){
    my ($self, $block) = @_;
    ($self->{"trials"}->{$block}->{"NO NONTARG"} + 
     $self->{"trials"}->{$block}->{"YES NONTARG"})
}

sub getTargDecScr(){
   my ($self, $block, $ind) = @_;
   $self->{"trials"}->{$block}->{"TARG"}[$ind]; 
}

sub getNonTargDecScr(){
   my ($self, $block, $ind) = @_;
   $self->{"trials"}->{$block}->{"NONTARG"}[$ind]; 
}

sub getBlockId(){
    my ($self) = @_;
    $self->{"BlockID"};
}

sub getDecisionId(){
    my ($self) = @_;
    $self->{"DecisionID"};
}

1;
