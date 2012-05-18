# F4DE
# TrialsTWV.pm
# Author: Jon Fiscus
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

package TrialsTWV;

use TrialsFuncs;
@ISA = qw(TrialsFuncs);

use strict;

use MMisc;

my @trials_params = ("TotDur", "TrialsPerSecond", "IncludeBlocksWithNoTargets");
sub getParamsList { return(@trials_params); }

sub new {
  my $class = shift @_;
  my $trialsParams = shift @_;
  my ($taskId, $blockId, $decisionId) = 
    MMisc::iuav(\@_, "Keyword Detection", "Keyword", "Occurrence");

  MMisc::error_quit("new TrialsTWV called without a \$trialsParams value") 
    if (! defined($trialsParams));
 
  my $self = TrialsFuncs->new($trialsParams, $taskId, $blockId, $decisionId);

  #######  customizations
  foreach my $p (@trials_params) {
    MMisc::error_quit("parameter \'$p\' not defined")
        if (! $self->getTrialParamValueExists($p));
    if ($p eq "IncludeBlocksWithNoTargets"){
       MMisc::error_quit("parameter \'$p\' must 0 or 1") if ($self->getTrialParamValue($p) !~ /^[01]$/);
    } else {
      MMisc::error_quit("parameter \'$p\' must > 0") if ($self->getTrialParamValue($p) <= 0);
    }
  }

  # Compute the total number of trials 
  $self->setTrialParamValue("TotTrials",
            sprintf("%.0f",$self->getTrialParamValue("TotDur") / $self->getTrialParamValue("TrialsPerSecond")));

  bless($self, $class);

  return $self;
}

sub isBlockEvaluated{
  my ($self, $block) = @_;
  if ($self->getTrialParamValue("IncludeBlocksWithNoTargets") == 1){
    return 1;
  }
  return ($self->getNumTarg($block) > 0); 
}

1;
