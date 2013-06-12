# F4DE
# TrialsPrecRecallFbeta.pm
# Author: Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# F4DE is an experimental system.  
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

package TrialsPrecRecallFbeta;

use TrialsFuncs;
@ISA = qw(TrialsFuncs);

use strict;

use MMisc;

my @trials_params = ();
sub getParamsList { return(@trials_params); }

sub new {
  my $class = shift @_;
  my $trialParams =shift  @_;
  my ($taskId, $blockId, $decisionId) = MMisc::iuav(\@_, "Detection", "Block", "Trial");

  MMisc::error_quit("new TrialsPrecRecallFbeta called without a \$trialParams value") 
    if (! defined($trialParams));
 
  my $self = TrialsFuncs->new($trialParams, $taskId, $blockId, $decisionId);

  #######  customizations
  foreach my $p (@trials_params) {
    MMisc::error_quit("parameter \'$p\' not defined")
        if (! exists($self->{trialParams}->{$p}));
  }

  bless($self, $class);

  return $self;
}

1;
