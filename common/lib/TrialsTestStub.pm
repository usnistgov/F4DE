# F4DE
# TrialsTestStub.pm
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

package TrialsTestStub;

use TrialsFuncs;
@ISA = qw(TrialsFuncs);

use strict;

use MMisc;

my @trials_params = ("TOTALTRIALS");
sub getParamsList { return(@trials_params); }

sub new {
  my ($class, $trialParams) = @_;

  MMisc::error_quit("new TrialsTestStub called without a \$trialParams value") 
    if (! defined($trialParams));
 
  my $self = TrialsFuncs->new("Detection", "Block", "Trial", $trialParams);

  #######  customizations
  foreach my $p (@trials_params) {
    MMisc::error_quit("parameter \'$p\' not defined")
        if (! exists($self->{trialParams}->{$p}));
    MMisc::error_quit("parameter \'$p\' must > 0")
        if ($self->{trialParams}->{$p} <= 0);
  }

  bless($self, $class);

  return $self;
}

1;