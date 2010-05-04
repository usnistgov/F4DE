# F4DE
# TrecVid08Trials.pm
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

package TrecVid08Trials;

use TrialsFuncs;
@ISA = qw(TrialsFuncs);

use strict;

use MMisc;
use Data::Dumper;
use SimpleAutoTable;

sub new {
  my ($class, $metricParams) = @_;

  MMisc::error_quit("new TrecVid08Trials called without a \$metricParams value") 
    if (! defined($metricParams));
 
  my $self = TrialsFuncs->new("Event Detection", "Event", "Observation", $metricParams);

  bless($self, $class);

  return $self;
}

1;
