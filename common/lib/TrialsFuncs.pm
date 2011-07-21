# F4DE
# TrialsFuncs.pm
# Author: Jon Fiscus
# Additions: Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. F4DE is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

package TrialsFuncs;

use strict;

use MMisc;
use Data::Dumper;
use SimpleAutoTable;

=pod

=head1 NAME

common/lib/TrialsFuncs - A database object for holding detection decision trials.  

=head1 SYNOPSIS

This object contains a data stucture to hold a database of trials.  A trial is....

=head1 DESCRIPTION

=head2 METHODS

=over 4

=item B<new>(...)  

This is the new

=cut

sub new {
  my $class = shift @_;
  my $trialParams = shift @_;
  my ($taskId, $blockId, $decisionId) = 
    MMisc::iuav(\@_, "Term Detection", "Term", "Occurrence");
  
  MMisc::error_quit("new Trial() called without a \$trialParams value") 
    if (! defined($trialParams));
  
  my $self =
    {
     "TaskID" => $taskId,
     "BlockID" => $blockId,
     "DecisionID" => $decisionId,
     "isSorted" => 1,
     "trials" => {},                ### This gets built as you add trials
     "trialParams" => $trialParams, ### Hash table for passing info to the Trial* objects 
     "suppliedActDecThresh" => undef,  ### Contains the supplied Decision threshhold for the Actual Decisions :)
     "computedActDecThreshRange" => undef,  ### Contains a hash table with the range for the decision threshold
    };
  
  bless $self;
  return $self;
}

sub unitTest {
  print "Test TrialsFuncs\n";
  my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) },
                              "Term Detection", "Term", "Occurrence");
  
  ## How to handle cases in F4DE
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
  $trial->addTrial("second", 0.35, "YES", 0);
  $trial->addTrial("second", 0.2, "NO", 0);
  $trial->addTrial("second", 0.3, "NO", 1);
  
  print " Tests for Trials with Decisions...\n";
  ### Test the contents
  print "  Copying structure...  ";
  my $sorted = $trial->copy();
  print "OK\n";
  print "  Sorting structure...  ";
  $sorted->sortTrials();
  print "OK\n";
  print "  Checking contents...  ";
  my @tmp = ($trial, $trial->copy(), $sorted);
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $tr = $tmp[$i];
    MMisc::error_quit("Not enough blocks")
        if (scalar(keys(%{ $tr->{"trials"} })) != 2);
    MMisc::error_quit("Not enough 'NO TARG' for block 'second'")
        if ( $tr->{"trials"}{"second"}{"NO TARG"} != 1);
    MMisc::error_quit("Not enough 'YES TARG' for block 'second'")
        if ( $tr->{"trials"}{"second"}{"YES TARG"} != 1);
    MMisc::error_quit("Not enough 'NO TARG' for block 'second'")
        if ( $tr->{"trials"}{"second"}{"NO NONTARG"} != 1);
    MMisc::error_quit("Not enough 'YES TARG' for block 'second'")
        if ( $tr->{"trials"}{"second"}{"YES NONTARG"} != 1);
    MMisc::error_quit("Not enough TARGs for block 'second'")
        if (scalar(@{ $tr->{"trials"}{"second"}{"TARG"} }) != 2);
    MMisc::error_quit("Not enough NONTARGs for block 'second'")
        if (scalar(@{ $tr->{"trials"}{"second"}{"NONTARG"} }) != 2);
    if ($tr->{isSorted}) {
      MMisc::error_quit("TARGs not sorted")
          if ($tr->{"trials"}{"second"}{"TARG"}[0] > $tr->{"trials"}{"second"}{"TARG"}[1]);
      MMisc::error_quit("NONTARGs not sorted")
          if ($tr->{"trials"}{"second"}{"NONTARG"}[0] > $tr->{"trials"}{"second"}{"NONTARG"}[1]);
    }
    MMisc::error_quit("pooledTotal trials does not exist")
        if (! $tr->getTrialParamValueExists("TOTAL_TRIALS"));
    MMisc::error_quit("pooledTotal trials not set")
        if ($tr->getTrialParamValue("TOTAL_TRIALS") != 78);
  } 
  print "OK\n";
  #print $trial->dump();
  print "  Computing Decision Score Theshold...  ";
  $trial->computeDecisionScoreThreshold();
  #print $trial->dump();
  MMisc::error_quit("Incorrect computed decision threshold ".$trial->getTrialActualDecisionThreshold()." != 0.325") 
    if (abs(0.325 - $trial->getTrialActualDecisionThreshold()) > 0.0001);
  
  
  print "OK\n";

  if (1){
    my $rtn;
    print "  Testing bad score handling\n";

    print "    No Trials...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    MMisc::error_quit("Failed") if ($trial->_computeDecisionScoreThreshold() ne "pass") ;
    MMisc::error_quit("Threshold defined for No Trials case") 
      if (defined($trial->getTrialActualDecisionThreshold()));
    print "OK\n";

    print "    Overlapping yes/no in TARG, one trial for NONTarg...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    $trial->addTrial("she", 0.7, "NO", 1);
    $trial->addTrial("she", 0.3, "YES", 1);
    $trial->addTrial("she", 0.3, "YES", 0);
    $rtn = $trial->_computeDecisionScoreThreshold();
    #print "\n".$rtn;
    MMisc::error_quit("Failed") if ($rtn eq "pass") ;
    print "OK\n";

    print "    Overlapping yes/no in NONTARG, one trial for TARG...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    $trial->addTrial("she", 0.7, "NO", 0);
    $trial->addTrial("she", 0.3, "YES", 0);
    $trial->addTrial("she", 0.3, "YES", 1);
    $rtn = $trial->_computeDecisionScoreThreshold();
    #print "\n".$rtn;
    MMisc::error_quit("Failed") if ($rtn eq "pass") ;
    print "OK\n";

    print "    YES Decisions only Targ...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    ### YES Only
    $trial->addTrial("YES Only Decision", 0.7, "YES", 1);
    $trial->addTrial("YES Only Decision", 0.3, "YES", 1);
    $trial->addTrial("YES Only Decision", 0.2, "YES", 1);
    $trial->addTrial("YES Only Decision", 0.1, "YES", 1);
    #print $trial->dump();
    $rtn = $trial->_computeDecisionScoreThreshold();
    #print "\nReturn: ".$rtn."\n";
    MMisc::error_quit("Failed\n$rtn") if ($rtn ne "pass") ;
    #print Dumper($trial->{computedActDecThreshRange});
    MMisc::error_quit("Incorrect computed decision threshold ".$trial->getTrialActualDecisionThreshold()." != 0.1") 
      if (abs(0.1 - $trial->getTrialActualDecisionThreshold()) > 0.0001);
    print "OK\n";
    
    print "    NO Decisions only Targ...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    ### No Only
    $trial->addTrial("No Only Decision", 0.7, "NO", 1);
    $trial->addTrial("No Only Decision", 0.3, "NO", 1);
    $trial->addTrial("No Only Decision", 0.2, "NO", 1);
    $trial->addTrial("No Only Decision", 0.1, "NO", 1);
    #print $trial->dump();
    $rtn = $trial->_computeDecisionScoreThreshold();
    #print "\nReturn: ".$rtn."\n";
    #print Dumper($trial->{computedActDecThreshRange});
    MMisc::error_quit("Failed\n$rtn") if ($rtn ne "pass") ;
    MMisc::error_quit("Incorrect computed decision threshold ".$trial->getTrialActualDecisionThreshold()." != 0.7") 
      if (abs(0.7 - $trial->getTrialActualDecisionThreshold()) > 0.0001);
    print "OK\n";

    print "    YES Decisions only NONTarg...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    ### YES Only
    $trial->addTrial("YES Only Decision", 0.7, "YES", 0);
    $trial->addTrial("YES Only Decision", 0.3, "YES", 0);
    $trial->addTrial("YES Only Decision", 0.2, "YES", 0);
    $trial->addTrial("YES Only Decision", 0.1, "YES", 0);
    #print $trial->dump();
    $rtn = $trial->_computeDecisionScoreThreshold();
    #print "\n".$rtn;
    MMisc::error_quit("Failed\n$rtn") if ($rtn ne "pass") ;
    MMisc::error_quit("Incorrect computed decision threshold ".$trial->getTrialActualDecisionThreshold()." != 0.1") 
      if (abs(0.1 - $trial->getTrialActualDecisionThreshold()) > 0.0001);
    print "OK\n";
    
    print "    NO Decisions only NONTarg...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    ### No Only
    $trial->addTrial("No Only Decision", 0.7, "NO", 0);
    $trial->addTrial("No Only Decision", 0.3, "NO", 0);
    $trial->addTrial("No Only Decision", 0.2, "NO", 0);
    $trial->addTrial("No Only Decision", 0.1, "NO", 0);
    #print $trial->dump();
    $rtn = $trial->_computeDecisionScoreThreshold();
    #print "\n".$rtn;
    MMisc::error_quit("Failed\n$rtn") if ($rtn ne "pass") ;
    MMisc::error_quit("Incorrect computed decision threshold ".$trial->getTrialActualDecisionThreshold()." != 0.7") 
      if (abs(0.7 - $trial->getTrialActualDecisionThreshold()) > 0.0001);
    print "OK\n";

    print "    Overlapping yes/no within blocks...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    ### No Targ
    $trial->addTrial("NoTarg", 0.7, "YES", 0);
    $trial->addTrial("NoTarg", 0.3, "YES", 0);
    $trial->addTrial("NoTarg", 0.2, "NO", 0);
    $trial->addTrial("NoTarg", 0.1, "NO", 0);
    ### No NonTarg
    $trial->addTrial("NoNontarg", 0.7, "YES", 1);
    $trial->addTrial("NoNontarg", 0.5, "YES", 1);
    $trial->addTrial("NoNontarg", 0.4, "NO", 1);
    $trial->addTrial("NoNontarg", 0.1, "NO", 1);
    ### This the bad one - both yes/no defined  for both targ and nontarg 
    $trial->addTrial("Both YES-NO for Both Targ/NonTarg", 0.7, "YES", 0);
    $trial->addTrial("Both YES-NO for Both Targ/NonTarg", 0.3, "YES", 0);
    $trial->addTrial("Both YES-NO for Both Targ/NonTarg", 0.2, "NO", 0);
    $trial->addTrial("Both YES-NO for Both Targ/NonTarg", 0.1, "NO", 0);
    $trial->addTrial("Both YES-NO for Both Targ/NonTarg", 0.7, "YES", 1);
    $trial->addTrial("Both YES-NO for Both Targ/NonTarg", 0.5, "YES", 1);
    $trial->addTrial("Both YES-NO for Both Targ/NonTarg", 0.4, "NO", 1);
    $trial->addTrial("Both YES-NO for Both Targ/NonTarg", 0.1, "NO", 1);
    ### This a bad one - both yes defined targ, no/yes defined for nontarg 
    $trial->addTrial("No TARG NO", 0.7, "YES", 0);
    $trial->addTrial("No TARG NO", 0.3, "YES", 0);
    $trial->addTrial("No TARG NO", 0.2, "NO", 0);
    $trial->addTrial("No TARG NO", 0.1, "NO", 0);
    $trial->addTrial("No TARG NO", 0.7, "YES", 1);
    $trial->addTrial("No TARG NO", 0.1, "YES", 1);
    ### This a bad one - both yes defined targ, no/yes defined for nontarg 
    $trial->addTrial("No TARG YES", 0.7, "YES", 0);
    $trial->addTrial("No TARG YES", 0.3, "YES", 0);
    $trial->addTrial("No TARG YES", 0.2, "NO", 0);
    $trial->addTrial("No TARG YES", 0.1, "NO", 0);
    $trial->addTrial("No TARG YES", 0.7, "NO", 1);
    $trial->addTrial("No TARG YES", 0.1, "NO", 1);
    ### This a bad one - both yes defined targ, no/yes defined for nontarg 
    $trial->addTrial("No NONTARG NO", 0.7, "YES", 1);
    $trial->addTrial("No NONTARG NO", 0.3, "YES", 1);
    $trial->addTrial("No NONTARG NO", 0.2, "NO", 1);
    $trial->addTrial("No NONTARG NO", 0.1, "NO", 1);
    $trial->addTrial("No NONTARG NO", 0.7, "YES", 0);
    $trial->addTrial("No NONTARG NO", 0.1, "YES", 0);
    ### This a bad one - both yes defined targ, no/yes defined for nontarg 
    $trial->addTrial("No NONTARG YES", 0.7, "YES", 1);
    $trial->addTrial("No NONTARG YES", 0.3, "YES", 1);
    $trial->addTrial("No NONTARG YES", 0.2, "NO", 1);
    $trial->addTrial("No NONTARG YES", 0.1, "NO", 1);
    $trial->addTrial("No NONTARG YES", 0.7, "NO", 0);
    $trial->addTrial("No NONTARG YES", 0.1, "NO", 0);
    #print $trial->dump();
    $rtn = $trial->_computeDecisionScoreThreshold();
    #print "\n".$rtn;
    MMisc::error_quit("Failed") if ($rtn eq "pass") ;
    print "OK\n";

    print "    Overlapping yes/no across blocks...  ";
    my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) }, "Term Detection", "Term", "Occurrence");
    $trial->addTrial("block1", 0.7, "YES", 0);
    $trial->addTrial("block1", 0.3, "YES", 0);
    $trial->addTrial("block1", 0.2, "NO", 0);
    $trial->addTrial("block1", 0.1, "NO", 0);
    $trial->addTrial("block1", 0.7, "YES", 1);
    $trial->addTrial("block1", 0.3, "YES", 1);
    $trial->addTrial("block1", 0.2, "NO", 1);
    $trial->addTrial("block1", 0.1, "NO", 1);
    $trial->addTrial("block2", 0.7, "YES", 0);
    $trial->addTrial("block2", 0.5, "YES", 0);
    $trial->addTrial("block2", 0.4, "NO", 0);
    $trial->addTrial("block2", 0.1, "NO", 0);
    $trial->addTrial("block2", 0.7, "YES", 1);
    $trial->addTrial("block2", 0.5, "YES", 1);
    $trial->addTrial("block2", 0.4, "NO", 1);
    $trial->addTrial("block2", 0.1, "NO", 1);
    #print $trial->dump();
    $rtn = $trial->_computeDecisionScoreThreshold();
    #print "\n".$rtn;
    MMisc::error_quit("Failed") if ($rtn eq "pass") ;
    print "OK\n";
  }
  
  print " Tests for Trials without decisions...\n";
  my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) },
                              "Term Detection", "Term", "Occurrence");

  ### Uncomment to test the catestrophic failure
  ##  $trial->addTrialWithoutDecision("she", 0.7, 1);
  
  print "   Set the threshold...  ";
  $trial->setTrialActualDecisionThreshold(2.0);
  print "OK\n";

  print "   Add items...  ";
  # One NO Targ
  $trial->addTrialWithoutDecision("she", 1.999999999, 1);
  # Two YES Targ
  $trial->addTrialWithoutDecision("she", 2.0, 1);
  $trial->addTrialWithoutDecision("she", 2.3, 1);
  # Three NO NonTarg
  $trial->addTrialWithoutDecision("she", 0.1, 0);
  $trial->addTrialWithoutDecision("she", 0.2, 0);
  $trial->addTrialWithoutDecision("she", 0.4, 0);
  # Four YES NonTarg
  $trial->addTrialWithoutDecision("she", 3.1, 0);
  $trial->addTrialWithoutDecision("she", 3.2, 0);
  $trial->addTrialWithoutDecision("she", 3.4, 0);
  $trial->addTrialWithoutDecision("she", 3.1, 0);
  ### The only way to add an OMITTED targ is with the add Trial funct
  $trial->addTrial("she", undef, "OMITTED", 1);
  ### Uncomment the following line to set the catestropic failure
  ### $trial->addTrialWithoutDecision("she", undef, 0);
  
  ### Test the counts
  MMisc::error_quit("No Targ insert failed") if ($trial->{"trials"}{"she"}{"NO TARG"} != 1);
  MMisc::error_quit("No NonTarg insert failed") if ($trial->{"trials"}{"she"}{"NO NONTARG"} != 3);
  MMisc::error_quit("Yes Targ insert failed") if ($trial->{"trials"}{"she"}{"YES TARG"} != 2);
  MMisc::error_quit("Yes NonTarg insert failed") if ($trial->{"trials"}{"she"}{"YES NONTARG"} != 4);

  print "Ok\n";
#  print $trial->dump();

  return 1;
}

sub isCompatible(){
  my ($self, $tr2) = @_;
  
  return 0 if (ref($self) ne ref($tr2));

  my @tmp = $self->getTrialParamKeys();
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $k = $tmp[$i];
    return 0 if (! $tr2->getTrialParamValueExists($k));
#    return 0 if ($self->getTrialParamValue($k) ne $tr2->getTrialParamValue($k));
  }

  my @tmp = $tr2->getTrialParamKeys();
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $k = $tmp[$i];
    return 0 if (! $self->getTrialParamValueExists($k));
#    return 0 if ($self->getTrialParamValue($k) ne $tr2->getTrialParamValue($k));
  }

  return 1;    
}


####################################################################################################

=item B<addTrial>(I<$blockID>, I<$sysScore>, I<$decision>, I<$isTarg>)  

Addes a trail, which is a decision made by a system on a specific input, to the trials object.  
The variables are as follows:

I<$blockID> is the statistical sampling block ID for the trial.  This trial structure is designed to handle 
averaging over statistical blocks.  If you don't want to average over blocks, then use a single blockID for 
all trials.

I<$sysScore> is the system's belief that the trial is an instance of the target object.  It can be any floating point # or if 
I<$decision> is /OMITTED/ it can be C<undef>.

I<$decision> is the system's actual decision for the trial.  Please read the detection evaluation framework papers to 
understand the implications of this variable.  The possible values are:

=over

B<YES> Indicating the trial is above the system's threshold for declaring the trial to be an instance.

B<NO> Indicating the trial is below the system's threshold for declaring the trial to be an instance.

B<OMITTED> Indicating the system did not provide an output for this trial.  If the decision is /OMITTED/, then the 
I<$sysScore> is ignored.

=back 

I<$isTarg> is a boolean indicating if the trial is an instance of the target or not.

=cut

sub addTrial {
  my ($self, $block, $sysscore, $decision, $isTarg) = @_;
  
  MMisc::error_quit("Decision must be \"YES|NO|OMITTED\" not '$decision'")
      if ($decision !~ /^(YES|NO|OMITTED)$/);
  my $attr = ($isTarg ? "TARG" : "NONTARG");
  
  $self->_initForBlock($block);
  
  $self->{computedActDecThreshRange} = undef;  ### Resets on new add!!!
  
  ## update the counts
  $self->{"isSorted"} = 0;
  if ($decision ne "OMITTED") {
    push(@{ $self->{"trials"}{$block}{$attr} }, $sysscore);
    ### Track the YES Threshold
    if ($decision eq "YES"){
      $self->{"trials"}{$block}{"MIN YES $attr"} = $sysscore 
        if ((!defined($self->{"trials"}{$block}{"MIN YES $attr"})) || 
            ($sysscore < $self->{"trials"}{$block}{"MIN YES $attr"}));      
    } else {
      $self->{"trials"}{$block}{"MAX NO $attr"} = $sysscore 
        if ((!defined($self->{"trials"}{$block}{"MAX NO $attr"})) || 
            ($sysscore > $self->{"trials"}{$block}{"MAX NO $attr"}));      
    }
  } else {
    MMisc::error_quit("Adding an OMITTED target trail with and defined decision score is illegal")
        if (defined($sysscore));
    MMisc::error_quit("OMITTED trials must be Target trials")
        if (! $isTarg);
  }
  $self->{"trials"}{$block}{$decision." $attr"} ++;
}

####################################################################################################

=item B<addTrialWithoutDecision>(I<$blockID>, I<$sysScore>, I<$isTarg>)  

Adds a trail which for which no "decision" is given.  The decision is set by applying the TrialActualDecisionThreshold that is set via B<setTrialActualDecisionThreshold>.  The threshold must be set and of type "supplied".  The rest of the arguments are as defined in B<addTrial>.

=cut

sub addTrialWithoutDecision {
  my ($self, $block, $sysscore, $isTarg) = @_;
  
  MMisc::error_quit("The ActualDecisionThreshold is not defined but must be in order to add a trial to a Trials object without a decision")
      if (! defined($self->getTrialActualDecisionThreshold()));
  MMisc::error_quit("Score is not defined (and must be) for adding a trial to a Trials object without a decision")
      if (! defined($sysscore));

  $self->addTrial($block, $sysscore, ($sysscore >= $self->getTrialActualDecisionThreshold() ? "YES" : "NO"), $isTarg);
}


sub _initForBlock {
  my ($self, $block) = @_;
  
  if (! defined($self->{"trials"}{$block}{"title"})) {
    $self->{"trials"}{$block}{"TARG"} = [];
    $self->{"trials"}{$block}{"NONTARG"} = [];
    $self->{"trials"}{$block}{"title"} = "$block";
    $self->{"trials"}{$block}{"YES TARG"} = 0;
    $self->{"trials"}{$block}{"NO TARG"} = 0;
    $self->{"trials"}{$block}{"YES NONTARG"} = 0;
    $self->{"trials"}{$block}{"NO NONTARG"} = 0;
    $self->{"trials"}{$block}{"OMITTED TARG"} = 0;
    $self->{"trials"}{$block}{"MIN YES TARG"} = undef;
    $self->{"trials"}{$block}{"MIN YES NONTARG"} = undef;
    $self->{"trials"}{$block}{"MAX NO TARG"} = undef;
    $self->{"trials"}{$block}{"MAX NO NONTARG"} = undef;
  }
}

sub getTaskID {
  my ($self) = @_;
  $self->{TaskID};
}

sub getBlockID {
  my ($self) = @_;
  $self->{BlockID};
}

sub getDecisionID {
  my ($self) = @_;
  $self->{DecisionID};
}

sub getTrialParams {
  my ($self) = @_;
  $self->{trialParams};
}

sub getTrialParamKeys {
  my ($self) = @_;
  keys %{ $self->{trialParams} };
}

sub getTrialParamsStr {
  my ($self) = @_;
  my $str = "{ (";
  my @tmp = keys %{ $self->{trialParams} };
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $k = $tmp[$i];
    $str .= "'$k' => '$self->{trialParams}->{$k}', ";
  }
  $str .= ') }';
  $str;   
}

sub setTrialParamValue {
  my ($self, $key, $val) = @_;
  $self->{trialParams}->{$key} = $val;
}

sub setTrialActualDecisionThreshold {
  my ($self, $val) = @_;
  $self->{suppliedActDecThresh} = $val;
}

sub getTrialActualDecisionThreshold {
  my ($self, $val) = @_;
  if (defined($self->{suppliedActDecThresh})){
    return $self->{suppliedActDecThresh};
  } else { 
    if (! defined($self->{computedActDecThreshRange})){
      $self->computeDecisionScoreThreshold();
    }
    return $self->{computedActDecThreshRange}->{MinYes} if (! defined($self->{computedActDecThreshRange}->{MaxNo}));
    return $self->{computedActDecThreshRange}->{MaxNo} if (! defined($self->{computedActDecThreshRange}->{MinYes}));
    return ($self->{computedActDecThreshRange}->{MinYes} + $self->{computedActDecThreshRange}->{MaxNo}) / 2;
  };
}

sub getTrialParamValueExists(){
  my ($self, $key) = @_;
  exists($self->{trialParams}->{$key});
}

sub getTrialParamValue(){
  my ($self, $key) = @_;
  $self->{trialParams}->{$key};
}

sub dump {
  my($self, $pre) = @_;
  
  my($k1, $k2, $k3) = ("", "", "");
  my $out = "";
  
   $out .= "${pre}Dump of Trial_data  isSorted=".$self->{isSorted}."\n";
  
  my @k1tmp = sort keys %$self;
  for (my $i1 = 0; $i1 < scalar @k1tmp; $i1++) {
    $k1 = $k1tmp[$i1];
    if ($k1 eq "trials") {
      $out .= "${pre}   $k1 -> $self->{$k1}\n";
      my @k2tmp = keys %{ $self->{$k1} };
      for (my $i2 = 0; $i2 < scalar @k2tmp; $i2++) {
        $k2 = $k2tmp[$i2];
	      $out .= "${pre}      $k2 -> $self->{$k1}{$k2}\n";
	
        my @k3tmp = sort keys %{ $self->{$k1}{$k2} };
        for (my $i3 = 0; $i3 < scalar @k3tmp; $i3++) {
          $k3 = $k3tmp[$i3];
	        if ($k3 eq "TARG" || $k3 eq "NONTARG") {
	          my(@a) = @{ $self->{$k1}{$k2}{$k3} };
	          $out .= "${pre}         $k3 (".scalar(@a).") -> (";
	    
      	    if ($#a > 5) {
	            foreach $_(0..2) {
		            $out .= "$a[$_],";
	            }
	            $out .= "...";

	            foreach $_(($#a-2)..$#a) {
		            $out .= ",$a[$_]";
	            }
	          } else {
	            $out .= join(",",@a);
	          }
	         $out .= ")\n";
	       } else {
	         $out .= "${pre}         $k3 -> $self->{$k1}{$k2}{$k3}\n";
	       }
	     }
      }
    } elsif ($k1 eq "computedActDecThreshRange") {
       $out .= "${pre}   $k1 -> (MaxNo=$self->{$k1}{MaxNo}, MinYes=$self->{$k1}{MinYes})\n";
    } else {
       $out .= "${pre}   $k1 -> $self->{$k1}\n";
    }
  }   
  $out;
}

sub copy {
  my ($self, $block) = @_;
  my ($copy) = new TrialsFuncs($self->getTrialParams(), $self->getTaskID(), 
                               $self->getBlockID(), $self->getDecisionID());
    
  my @blocks = ();
  if (defined($block)) {
    push @blocks, $block;
  } else {
    @blocks = keys %{ $self->{"trials"} };
  }
  
  for (my $i1 = 0; $i1 < scalar @blocks; $i1++) {
    my $block = $blocks[$i1];
    my @k2tmp = keys %{ $self->{"trials"}{$block} };
    for (my $i2 = 0; $i2 < scalar @k2tmp; $i2++) {
      my $param = $k2tmp[$i2];
      if ($param eq "TARG" || $param eq "NONTARG") {
	my(@a) = @{ $self->{"trials"}{$block}{$param} };
	$copy->{"trials"}{$block}{$param} = [ @a ];
      } else {
	$copy->{"trials"}{$block}{$param} = $self->{"trials"}{$block}{$param};
      }
    }
  }
  
  $copy->{isSorted} = $self->{isSorted}; 
  $copy->{pooledTotalTrials} = $self->{pooledTotalTrials}; 
  $copy;
}

sub dumpCountSummary {
  my ($self) = @_;

  my $at = new SimpleAutoTable();
  my ($TY, $OT, $NT, $YNT, $NNT) = (0, 0, 0, 0, 0);
  my @ktmp = sort keys %{ $self->{"trials"} };
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    $at->addData($self->getNumYesTarg($block),     "Corr:YesTarg", $block);
    $at->addData($self->getNumOmittedTarg($block), "Miss:OmitTarg", $block);
    $at->addData($self->getNumNoTarg($block),      "Miss:NoTarg", $block);
    $at->addData($self->getNumYesNonTarg($block),  "FA:YesNontarg", $block);
    $at->addData($self->getNumNoNonTarg($block),   "Corr:NoNontarg", $block);
    
    $TY += $self->getNumYesTarg($block);
    $OT += $self->getNumOmittedTarg($block);
    $NT += $self->getNumNoTarg($block);
    $YNT += $self->getNumYesNonTarg($block);
    $NNT += $self->getNumNoNonTarg($block);
  }
  $at->addData("------",  "Corr:YesTarg", "-----");
  $at->addData("------",  "Miss:OmitTarg", "-----");
  $at->addData("------",  "Miss:NoTarg", "-----");
  $at->addData("------", "FA:YesNontarg", "-----");
  $at->addData("------", "Corr:NoNontarg", "-----");
  
  $at->addData($TY,  "Corr:YesTarg", "Total");
  $at->addData($OT,  "Miss:OmitTarg", "Total");
  $at->addData($NT,  "Miss:NoTarg", "Total");
  $at->addData($YNT, "FA:YesNontarg", "Total");
  $at->addData($NNT, "Corr:NoNontarg", "Total");
  
  my $txt = $at->renderTxtTable(2);
  if (! defined($txt)) {
    print "Error:  Dump of Count Summary Failed with ".$at->get_errormsg();
  }
  $txt;
}

sub dumpGrid {
  my ($self) = @_;
  
  my @k1tmp = keys %{ $self->{"trials"} };
  for (my $i1 = 0; $i1 < scalar @k1tmp; $i1++) {
    my $block = $k1tmp[$i1];
    my @k2tmp = sort keys %{ $self->{"trials"}{$block} };
    for (my $i2 = 0; $i2 < scalar @k2tmp; $i2++) {
      my $var = $k2tmp[$i2];
      if ($var eq "TARG" || $var eq "NONTARG") {
        my @k3tmp = @{ $self->{"trials"}{$block}{$var} };
        for (my $i3 = 0; $i3 < scalar @k3tmp; $i3++) {
          my $sc = $k3tmp[$i3];
	  printf "GRID $sc $block-$var %12.10f $sc-$block\n", $sc;
	}
      }
    }
  }
}

sub numerically { $a <=> $b; }

sub sortTrials {
  my ($self) = @_;
  return if ($self->{"isSorted"});

  my @ktmp = keys %{ $self->{"trials"} };
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    $self->{"trials"}{$block}{TARG} = [ sort numerically @{ $self->{"trials"}{$block}{TARG} } ];
    $self->{"trials"}{$block}{NONTARG} = [ sort numerically @{ $self->{"trials"}{$block}{NONTARG} } ];
  }
  
  $self->{"isSorted"} = 1;
}

sub computeDecisionScoreThreshold {
  my ($self) = @_;

  my $rtn = $self->_computeDecisionScoreThreshold();

  if ("pass" ne $rtn){
    MMisc::error_quit($rtn."Error: Computation of Decision Score Threshold Failed.  Aborting");
  }
}

sub _computeDecisionScoreThreshold {
  my ($self) = @_;
  
  my @ktmp = keys %{ $self->{"trials"} };
  my $fail = "";
    
  ### Check within Targets and NonTargets
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    
    my ($minYesTarg) = $self->{"trials"}{$block}{"MIN YES TARG"};
    my ($minYesNonTarg) = $self->{"trials"}{$block}{"MIN YES NONTARG"};
    my ($maxNoTarg) = $self->{"trials"}{$block}{"MAX NO TARG"};
    my ($maxNoNonTarg) = $self->{"trials"}{$block}{"MAX NO NONTARG"};
     
    ### Check that YES/NO decisions don't overlap within TARG/NONTARG.  IF one of the variables is not defined, then the range is valid
    if (defined($minYesTarg) && defined($maxNoTarg)){
      if ($maxNoTarg > $minYesTarg){
        $fail .= "Error: Inconsistent NO/YES decision boundary for Targets for block $block.   Scores for MaxNo=$maxNoTarg > MinYes=$minYesTarg\n";
      }
    }
    if (defined($minYesNonTarg) && defined($maxNoNonTarg)){
      if ($maxNoNonTarg > $minYesNonTarg){
        $fail .= "Error: Inconsistent NO/YES decision boundary for NonTargets for block $block.   Scores for MaxNo=$maxNoNonTarg > MinYes=$minYesNonTarg\n";
      }
    }
  }
  return $fail if ($fail ne "");
  
  ### Check across both the targets/nontargets within block
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    
    my ($minYesTarg) = $self->{"trials"}{$block}{"MIN YES TARG"};
    my ($minYesNonTarg) = $self->{"trials"}{$block}{"MIN YES NONTARG"};
    my ($maxNoTarg) = $self->{"trials"}{$block}{"MAX NO TARG"};
    my ($maxNoNonTarg) = $self->{"trials"}{$block}{"MAX NO NONTARG"};

    ### Find the ovarall min respecting undef
    my $minYes = $minYesTarg;
    if (defined($minYesNonTarg)){
      $minYes = $minYesNonTarg if (!defined($minYes) || (defined($minYes) && ($minYes > $minYesNonTarg)));
    }
    my $maxNo = $maxNoTarg;
    if (defined($maxNoNonTarg)){
      $maxNo = $maxNoNonTarg if (!defined($maxNo) || (defined($maxNo) && ($maxNo < $maxNoNonTarg)));
    }

    ### No YESs
    next if (!defined($minYes));
    
    ### No NOs
    next if (!defined($maxNo));
    
    if ($maxNo > $minYes){
      $fail .= "Error: Insconsistent NO/YES decision boundary for block $block.  Scores for MaxNo=$maxNo > MinYes=$minYes\n";
    }
  }
  return $fail if ($fail ne "");

  {
    ### Check across all blocks
    my $minYes = undef;
    my $maxNo = undef;
    for (my $i = 0; $i < scalar @ktmp; $i++) {
      my $block = $ktmp[$i];
    
      my ($minYesTarg) = $self->{"trials"}{$block}{"MIN YES TARG"};
      my ($minYesNonTarg) = $self->{"trials"}{$block}{"MIN YES NONTARG"};
      my ($maxNoTarg) = $self->{"trials"}{$block}{"MAX NO TARG"};
      my ($maxNoNonTarg) = $self->{"trials"}{$block}{"MAX NO NONTARG"};

      ### Find the ovarall min respecting undef
      $minYes = $minYesTarg    if (defined($minYesTarg)    && ((!defined($minYes) || (defined($minYes) && ($minYes > $minYesTarg)))));
      $minYes = $minYesNonTarg if (defined($minYesNonTarg) && ((!defined($minYes) || (defined($minYes) && ($minYes > $minYesNonTarg)))));

      $maxNo = $maxNoTarg    if (defined($maxNoTarg)       && ((!defined($maxNo)  || (defined($maxNo) &&  ($maxNo  < $maxNoTarg)))));
      $maxNo = $maxNoNonTarg if (defined($maxNoNonTarg)    && ((!defined($maxNo)  || (defined($maxNo) &&  ($maxNo  < $maxNoNonTarg)))));
    }
    if (defined($maxNo) && defined($minYes) && ($maxNo > $minYes)){
      $fail .= "Error: Insconsistent NO/YES decision boundary across blocks.  Scores for MaxNo=$maxNo > MinYes=$minYes\n";
    }
    return $fail if ($fail ne "");

    $self->{computedActDecThreshRange} = { MaxNo => $maxNo, MinYes => $minYes };
  }

  return "pass";
}

sub getBlockIDs {
  my ($self, $block) = @_;
  keys %{ $self->{"trials"} };
}

sub getNumTargScr {
  my ($self, $block) = @_;
  scalar(@{ $self->{"trials"}{$block}{"TARG"} });
}

sub getTargScr {
  my ($self, $block) = @_;
  $self->{"trials"}{$block}{"TARG"};
}

sub getNumNoTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"NO TARG"};
}

sub getNumTarg {
  my ($self, $block) = @_;
  ($self->getNumNoTarg($block) + $self->getNumYesTarg($block) + $self->getNumOmittedTarg($block) );
}

sub getNumSys {
  my ($self, $block) = @_;
  ($self->getNumNoTarg($block) + $self->getNumYesTarg($block) + $self->getNumYesNonTarg($block) + $self->getNumNoNonTarg($block));
}

sub getNumYesTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"YES TARG"};
}

sub getNumOmittedTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"OMITTED TARG"};
}

sub getNumNonTargScr {
  my ($self, $block) = @_;
  scalar(@{ $self->{"trials"}{$block}{"NONTARG"} });
}

sub getNonTargScr {
  my ($self, $block) = @_;
  $self->{"trials"}{$block}{"NONTARG"};
}

sub getNumNoNonTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"NO NONTARG"};
}

sub getNumYesNonTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"YES NONTARG"};
}

sub getNumFalseAlarm {
  my ($self, $block) = @_;
  $self->getNumYesNonTarg($block);
}

sub getNumMiss {
  my ($self, $block) = @_;
  $self->getNumNoTarg($block) + $self->getNumOmittedTarg($block);
}

sub getNumCorrDetect {
  my ($self, $block) = @_;
  $self->getNumYesTarg($block);
}

sub getNumCorrNonDetect {
  my ($self, $block) = @_;
  $self->getNumNoNonTarg($block);
}

sub getNumNonTarg {
  my ($self, $block) = @_;
  ($self->{"trials"}->{$block}->{"NO NONTARG"} + 
   $self->{"trials"}->{$block}->{"YES NONTARG"})
}

sub _stater {
  my ($self, $data) = @_;
  my $sum = 0;
  my $sumsqr = 0;
  my $n = 0;
  for (my $i = 0; $i < scalar @$data; $i++) {
    my $d = $$data[$i];
    $sum += $d;
    $sumsqr += $d * $d;
    $n++;
  }
  ($sum, ($n > 0 ? $sum/$n : undef), ($n <= 1 ? undef : sqrt((($n * $sumsqr) - ($sum * $sum)) / ($n * ($n - 1)))));
}

sub getTotNumTarg {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumTarg($block);
  }
  $self->_stater(\@data);
}

sub getTotNumNonTarg {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumNonTarg($block);
  }
  $self->_stater(\@data);
}

sub getTotNumSys {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumSys($block);
  }
  $self->_stater(\@data);
}

sub getTotNumCorrDetect {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumCorrDetect($block);
  }
  $self->_stater(\@data);
}

sub getTotNumCorrNonDetect {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumCorrNonDetect($block);
  }
  $self->_stater(\@data);
}

sub getTotNumFalseAlarm {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumFalseAlarm($block);
  }
  $self->_stater(\@data);
}

sub getTotNumMiss {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumMiss($block);
  }
  $self->_stater(\@data);
}

sub getTargDecScr {
  my ($self, $block, $ind) = @_;
  $self->{"trials"}->{$block}->{"TARG"}[$ind]; 
}

sub getNonTargDecScr {
  my ($self, $block, $ind) = @_;
  $self->{"trials"}->{$block}->{"NONTARG"}[$ind]; 
}

sub getBlockId {
  my ($self) = @_;
  $self->{"BlockID"};
}

sub getDecisionId {
  my ($self) = @_;
  $self->{"DecisionID"};
}
  
### This is not an instance method
sub mergeTrials{
  my ($r_baseTrial, $mergeTrial, $trial, $mergeType) = @_;

  ### Sanity Check 
  my @blockIDs = $mergeTrial->getBlockIDs();
  MMisc::error_quit("trial merge with multi-block trial data not supported")
      if (@blockIDs > 1);
  MMisc::error_quit("trial merge requires at least one block ID")
      if (@blockIDs > 1);

  ### First the params
  if (! defined($$r_baseTrial)){
    my $tmode = ref($mergeTrial);
    $$r_baseTrial = $tmode->new
      ( $mergeTrial->getTrialParams(),
        $mergeTrial->getTaskID(),
        $mergeTrial->getBlockID(),
        $mergeTrial->getDecisionID() );
  } else { 
    my @ktmp = $$r_baseTrial->getTrialParamKeys();
    for (my $i = 0; $i < scalar @ktmp; $i++) {
      my $mkey = $ktmp[$i];
      my $newVal = $trial->trialParamMerge($mkey,
                                            $$r_baseTrial->getTrialParamValue($mkey), 
                                            $mergeTrial->getTrialParamValue($mkey), $mergeType);
      $$r_baseTrial->setTrialParamValue($mkey, $newVal);
    }
  }

  ### Now the data!!!
  my $newBlock = "pooled";
  if ($mergeType eq "blocked"){
    my @theIDs = $$r_baseTrial->getBlockIDs();
    $newBlock = sprintf("block_%03d",scalar(@theIDs));  
  }
    
  $$r_baseTrial->{isSorted} = 0;
  $$r_baseTrial->_initForBlock($newBlock);
    
  push (@{ $$r_baseTrial->{"trials"}{$newBlock}{"TARG"} }, @{ $mergeTrial->{trials}{$blockIDs[0]}{TARG} });
  push (@{ $$r_baseTrial->{"trials"}{$newBlock}{"NONTARG"} }, @{ $mergeTrial->{trials}{$blockIDs[0]}{NONTARG} });
  foreach my $counter("YES TARG", "NO TARG", "YES NONTARG", "NO NONTARG", "OMITTED TARG"){
    $$r_baseTrial->{"trials"}{$newBlock}{$counter} += $mergeTrial->{"trials"}{$blockIDs[0]}{$counter};
  }    
  
}

### This is a class method
sub buildDEVAModeTestFiles{
  my ($fileRoot) = "MTest";

  use Math::Random::OO::Uniform;

  my %BlockParams = ( "Block1" => { "ID" => "Blue" ,
                                    "ScoreMeanShift" => 0.2 },
                      "Block2" => { "ID" => "Red" ,
                                    "ScoreMeanShift" => 0.4 },
                      "Block3" => { "ID" => "Green" ,
                                    "ScoreMeanShift" => 0.6 },
                      "Block4" => { "ID" => "Purple" ,
                                    "ScoreMeanShift" => -10.0 }
                     );

  print "Build DEVA Mode test files with root name /$fileRoot/\n";
  my $decisionScoreRand = Math::Random::OO::Uniform->new(0,5);
  my $targetRand = Math::Random::OO::Uniform->new(0,1);
  my $blockedTrial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");

  foreach my $block(keys %BlockParams){
    print "   Block ".$BlockParams{$block}{ID}."\n";
    for (my $nt = 0; $nt<100; $nt ++){
      my $scr = $decisionScoreRand->next();
      my $isTarg = ($targetRand->next() > 0.5);
      $scr += $BlockParams{$block}{ScoreMeanShift} if($isTarg);
        
      $blockedTrial->addTrial($BlockParams{$block}{ID}, $scr, ($scr <= 0.5 ? "NO" : "YES" ), ($isTarg ? 1 : 0));
    }
  } 
  $blockedTrial->exportForDEVA("$fileRoot.oneSys",1);
  $blockedTrial->exportForDEVA("$fileRoot.divSys",0, 0.5);
}

sub exportForDEVA{
  my ($self, $root, $numSys, $thresh) = @_;
  my $trialNum = 1;
  my $tid;
  
  $self->computeDecisionScoreThreshold();
  my @blockIDs = $self->getBlockIDs();
  open (REF, ">$root.ref.csv") || MMisc::error_quit("Failed to open $root.ref.csv for reference file");
  print REF "\"TrialID\",\"Targ\"\n";
  if ($numSys == 1){
    open (SYS, ">$root.sys.csv") || MMisc::error_quit("Failed to open $root.sys.csv for system file");
    print SYS "\"TrialID\",\"Score\",\"Decision\"\n";
  } else {
    open (SYSDET, ">$root.sys.detect.csv") || MMisc::error_quit("Failed to open $root.sys.detect.csv for system file");
    print SYSDET "\"TrialID\",\"Score\"\n";
    open (SYSTHR, ">$root.sys.thresh.csv") || MMisc::error_quit("Failed to open $root.sys.thresh.csv for system file");
    print SYSTHR "\"EventID\",\"DetectionThreshold\"\n";
    for (my $block; $block < @blockIDs; $block++){
      print SYSTHR "\"$blockIDs[$block]\",\"$thresh\"\n";
    }  
    open (SYSIND, ">$root.sys.index.csv") || MMisc::error_quit("Failed to open $root.sys.index.csv for system file");
    print SYSIND "\"TrialID\",\"EventID\",\"ClipID\"\n";

  } 
  if (@blockIDs > 1){
    open (MD, ">$root.metadata.csv") || MMisc::error_quit("Failed to open $root.metadata.csv for metadata");
    print MD "\"TrialID\",\"Block\"\n";
  }
    
  for (my $block; $block < @blockIDs; $block++){
    ### The TARGETS
    my $dec = $self->getTargScr($blockIDs[$block]);
    for (my $d = 0; $d < @$dec; $d++){
      my $scr = $dec->[$d];
      my $decision = "n";
      $decision = "y" if (defined($self->{trials}{$blockIDs[$block]}{"MIN YES TARG"}) && $self->{trials}{$blockIDs[$block]}{"MIN YES TARG"} <= $scr);
      $tid = sprintf("TID-%07.f", $trialNum++);    
      print REF "\"$tid\",\"y\"\n";
      if ($numSys == 1){
        print SYS "\"$tid\",\"$scr\",\"$decision\"\n";
      } else {
        print SYSDET "\"$tid\",\"$scr\"\n";
        print SYSIND "\"$tid\",\"$blockIDs[$block]\",\"CLIP-$tid\"\n";
      }
      if (@blockIDs > 1){
        print MD "\"$tid\",\"$blockIDs[$block]\"\n";
      }
    }
    ### The NONTARGETS
    my $dec = $self->getNonTargScr($blockIDs[$block]);
    for (my $d = 0; $d < @$dec; $d++){
      my $scr = $dec->[$d];
      my $decision = "n";
      $decision = "y" if (defined($self->{trials}{$blockIDs[$block]}{"MIN YES NONTARG"}) && $self->{trials}{$blockIDs[$block]}{"MIN YES NONTARG"} <= $scr);
      $tid = sprintf("TID-%07.f", $trialNum++);    
      print REF "\"$tid\",\"n\"\n";
      if ($numSys == 1){
        print SYS "\"$tid\",\"$scr\",\"$decision\"\n";
      } else {
        print SYSDET "\"$tid\",\"$scr\"\n";
        print SYSIND "\"$tid\",\"$blockIDs[$block]\",\"CLIP-$tid\"\n";
      }
      if (@blockIDs > 1){
        print MD "\"$tid\",\"$blockIDs[$block]\"\n";
      }
    }
  }

  open REF;
  if ($numSys == 1){
    open SYS;
    if (@blockIDs > 1){
      close MD;
    }
  } else {
    close SYSREF;
    close SYSIND;
    close SYSDET;
  }
}

sub buildScoreDistributions{
  my ($self, $root) = @_;

  use Statistics::Descriptive;
  use Data::Dumper;
  
  my @blockIDs = $self->getBlockIDs();
  for (my $block; $block < @blockIDs; $block++){
    my $targStat = Statistics::Descriptive::Full->new();
    my $nontargStat = Statistics::Descriptive::Full->new();

    my $dec = $self->getTargScr($blockIDs[$block]);
    for (my $d = 0; $d < @$dec; $d++){
      $targStat->add_data($dec->[$d]);
    }
    ### The NONTARGETS
    my $dec = $self->getNonTargScr($blockIDs[$block]);
    for (my $d = 0; $d < @$dec; $d++){
      $nontargStat->add_data($dec->[$d]);
    }

    my $visMin = $targStat->min();
    $visMin = $nontargStat->min() if ($nontargStat->min() < $visMin);

    my $visMax = $targStat->max();
    $visMax = $nontargStat->max() if ($nontargStat->max() > $visMax);
    
    print "Block $block: visMin=$visMin, visMax=$visMax\n";
    
    ### 
    open TARG, "| his -n 100 -r $visMin:$visMax - | tee targ.his | his2dist_func > targ.his.dist" || die;
    print TARG join("\n",$targStat->get_data())."\n";
    close TARG;
    open NONTARG, "| his -n 100 -r $visMin:$visMax - | tee nontarg.his | his2dist_func > nontarg.his.dist" || die;
    print NONTARG join("\n",$nontargStat->get_data())."\n";
    close NOTARG;
    
    print "./his2gnuplot -s -f targ.his -l Targets -f nontarg.his -l NonTargets foo\n";
    print "hp_plt -png -color foo.plt > foo.png\n";
    
    open DIST, ">CDF.plt" || die;
    print DIST "set terminal postscript\n";                                                                                                                                                                    
    print DIST "set ylabel \"Percent\"\n";                                                                                                                                                                        
    print DIST "set xlabel \"Decision Score\"\n";                                                                                                                                                                        
    print DIST "set title  \"Cumulative distributions of Targets and Non-Targets\"\n";
    print DIST "plot 'targ.his.dist' using 1:2 title \"Targets\" with lines,";                                                                                                                              
    print DIST "     'nontarg.his.dist' using 1:2 title \"NonTargets\" with lines\n";
    close DIST;                                          
    print "hp_plt -png -color CDF.plt > CDF.png\n";
                                                                                                                                                                                           
                                                                   
##    my @partitions = ($visMin);
##    my $nPartitions = 10;
##    for (my $i=0; $i <= $nPartitions; $i++){
##      push @partitions, $visMin + $i * (($visMax - $visMin) / $nPartitions);
##    }
##    print Dumper(\@partitions);
##      
##    my %targHist = $targStat->frequency_distribution(\@partitions);
##    my %nontargHist = $nontargStat->frequency_distribution(\@partitions);
##    my @keys = sort {$a <=> $b} keys %targHist;
##
##    foreach my $k(@keys){
##      print "$k -> $targHist{$k} $nontargHist{$k}\n";
##    }
   
  }
}

1;
