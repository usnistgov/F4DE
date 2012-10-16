# F4DE
# KWSSegAlign.pm
# Author: David Joy
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

package KWSSegAlign;

use strict;

use KWSList;
use RTTMList;
use KWSecf;
use TermList;
use TrialsDiscreteTWV;
use MetricDiscreteTWV;
use AutoTable;
use Data::Dumper;

use DETCurveGnuplotRenderer;

sub new
{
  my $class = shift;
  my $self = {};

  $self->{RTTMLIST} = shift;
  $self->{KWSLIST} = shift;
  $self->{ECF} = shift;
  $self->{TERMLIST} = shift;  
  $self->{TERMLKUP} = {};

  ##Filter Data
  $self->{SRCTYPEGROUPS} = undef; #{Group name}->@ of src types allowed in that group
  $self->{TERMGROUPS} = undef; #{Group name}->@ of termids allowed in that group
  $self->{ATTRIBUTE} = undef; #Attribute to group by, groups should be the values of this attribute
  $self->{FILECHANS} = (); #@ of 'file/chan's allowed in the conditional report
  ##

  #Create index of terms by file/channel
  foreach my $termid (sort keys %{ $self->{KWSLIST}{TERMS} }) {
    foreach my $term (@{ $self->{KWSLIST}{TERMS}{$termid}{TERMS} }) {
      push (@{ $self->{TERMLKUP}{$termid}{$term->{FILE}}{$term->{CHAN}} }, $term);
    }
  }

  bless $self;
  return $self;
}

sub alignSegments
{
  my ($self, $csvreportfile, $segmentFilters, $groupFilter, $threshhold, $KoefC, $KoefV, $probofterm, $listIsolineCoef, $pooled, $includeBlocksWNoTarg, $justSystemTerms) = @_;
  open (CSVREPORT, ">$csvreportfile") if (defined $csvreportfile);
  binmode(CSVREPORT, $self->{RTTMLIST}->getPerlEncodingString()) if (defined $csvreportfile && $self->{RTTMLIST}->{ENCODING} ne "");
  print CSVREPORT "file,channel,termid,term,ref_bt,ref_et,sys_bt,sys_et,sys_score,sys_decision,alignment\n" if (defined $csvreportfile);

  $includeBlocksWNoTarg = 0 if ($includeBlocksWNoTarg != 1);
  $justSystemTerms = 0 if ($justSystemTerms != 1);

  my @segments = ();
  foreach my $ecfexcerpt (@{ $self->{ECF}{EXCERPT} }) {
    push (@segments, @{ $self->{RTTMLIST}->segmentsFromTimeframe($ecfexcerpt->{FILE}, $ecfexcerpt->{CHANNEL}, $ecfexcerpt->{TBEG}, $ecfexcerpt->{DUR}, $ecfexcerpt) });
  }

  my @fsegments = (); #filtered segments
  SEGFILTER: foreach my $segment (@segments) {
    foreach my $filter (@{ $segmentFilters }) {
      next SEGFILTER if (&{ $filter }($self, $segment) == 0);
    }
    push (@fsegments, $segment);
  }
  
  MMisc::error_quit("Segment filter yielded no segments for inferred segmentation alignment.  Aborting.")  if(@segments <= 0);
#  print "Segments found: ".scalar(@segments)."\n";
  
    #Initialize trials
  my %qtrials = (); #Conditional trials
  my $qdetset = new DETCurveSet();
  #Generate trial group trial counts
  my %grouptcounts = ();
  my @groups = ();
  @groups = keys %{ $self->{SRCTYPEGROUPS} } if ($groupFilter eq \&KWSSegAlign::groupByECFSourceType);
 # @groups = keys %{ $self->{TERMGROUPS} } if ($groupFilter eq \&KWSSegAlign::groupByTerms);
 # @groups = @{ $self->{ATTRIBUTES} } if ($groupFilter eq \&KWSSegAlign::groupByAttributes);
 # @groups = ("OOV", "IV") if ($groupFilter eq \&KWSSegAlign::groupByOOV);

  foreach my $group (@groups) {
    if ($groupFilter eq \&KWSSegAlign::groupByECFSourceType) {
      $grouptcounts{$group} = $self->_countECFGroupSegments($group, \@fsegments); }
    else { $grouptcounts{$group} = scalar(@fsegments); }
  }

  my $trials = new TrialsDiscreteTWV({ ( "TotTrials" => scalar(@fsegments), "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg ) });
  my $detset = new DETCurveSet();

  foreach my $segment (@fsegments) {
    my @terms = values %{ $self->{TERMLIST}{TERMS} };
    foreach my $term (@terms) {
      my $trialBlock = $term->{TERMID};
      $trialBlock = "Pooled" if ($pooled);

      my %blockMetaData = ();
      $blockMetaData{"Text"} = $self->{TERMLIST}->{TERMS}{$term->{TERMID}}{TEXT} if (not $pooled);

      my @crecords = (); #Records contained in the segment.
      #Need rttm for normalization
      my $istarget = $segment->hasTerm($term->{TEXT}, $threshhold, $self->{RTTMLIST});
      
      foreach my $record (@{ $self->{TERMLKUP}{$term->{TERMID}}{$segment->{FILE}}{$segment->{CHAN}} }) {
	if ($record->{BT} >= $segment->{BT} && $record->{ET} <= $segment->{ET}) {
	  push (@crecords, $record);
	}
	elsif ($record->{MID} >= $segment->{BT} && $record->{MID} <= $segment->{ET}) {
          #print "WARNING: KWSTermRecord was not precisely inside of segment\n";
	  push (@crecords, $record);
	}
      }

      if (@crecords > 0) {
	#If multiple records contained in segment we take the one with the highest score.
	my $dominantrec = (sort {$b->{SCORE} <=> $a->{SCORE}} @crecords)[0];
	my $align_result = $istarget ? "CORR" : $dominantrec->{DECISION} =~ /yes/i ? "FA" : "CORR!DET";
	print CSVREPORT $self->{TERMLIST}{LANGUAGE} . "," . $segment->{FILE} . "," . $segment->{CHAN} . "," . $term->{TERMID} . "," . $term->{TEXT} . "," . $segment->{BT} . "," . $segment->{ET} . "," . $dominantrec->{BT} . "," . $dominantrec->{ET} . "," . $dominantrec->{SCORE} . "," . $dominantrec->{DECISION} . "," . $align_result . "\n" if (defined $csvreportfile);

	#Add trial for occurence report
	$trials->addTrial($trialBlock, $dominantrec->{SCORE}, $dominantrec->{DECISION}, $istarget, \%blockMetaData);

	#Add trial for conditional occurence report based on whatever grouping filter is being used
	next if (not defined $groupFilter);
	foreach my $group (@{ &{ $groupFilter }($self, $segment, $term) }) {
	  my $totTrials = scalar(@fsegments);
	  $totTrials = $grouptcounts{$group} if (defined $grouptcounts{$group});
	  $qtrials{$group} = new TrialsDiscreteTWV({ ( "TotTrials" => $totTrials, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg ) }) if (not defined $qtrials{$group});
	  $qtrials{$group}->addTrial($term->{TERMID}, $dominantrec->{SCORE}, $dominantrec->{DECISION}, $istarget, \%blockMetaData);
	}
      }
      elsif ($istarget) {
	$trials->addTrial($trialBlock, undef, "OMITTED", $istarget, \%blockMetaData);

	print CSVREPORT $self->{TERMLIST}{LANGUAGE} . "," . $segment->{FILE} . "," . $segment->{CHAN} . "," . $term->{TERMID} . "," . $term->{TEXT} . "," . $segment->{BT} . "," . $segment->{ET} . "," . "," .  ","  . ","  . "," . "MISS\n" if (defined $csvreportfile);

	next if (not defined $groupFilter);
	foreach my $group (@{ &{ $groupFilter }($self, $segment, $term) }) {
	  my $totTrials = scalar(@fsegments);
	  $totTrials = $grouptcounts{$group} if (defined $grouptcounts{$group});
	  $qtrials{$group} = new TrialsDiscreteTWV({ ( "TotTrials" => $totTrials, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg ) }) if (not defined $qtrials{$group});
	  $qtrials{$group}->addTrial($term->{TERMID}, undef, "OMITTED", $istarget, \%blockMetaData);
	}
      }
    }
  }

#####
  #Add empty blocks for terms which are not in sys
  foreach my $term (values %{ $self->{TERMLIST}{TERMS} }) {
    last if $justSystemTerms == 1;
    my $termid = $term->{TERMID};
    if (not defined $trials->{"trials"}{$termid}) {
      my %blockMetaData = ();
      $blockMetaData{"Text"} = $self->{TERMLIST}->{TERMS}{$term->{TERMID}}{TEXT} if (not $pooled);
      
      $trials->addEmptyBlock($termid);
      $trials->addBlockMetaData($termid, \%blockMetaData);
      
      if (defined $groupFilter) {
	my @possible_groups = (); #empty trials should be added to all groups
	push (@possible_groups, keys %{ $self->{SRCTYPEGROUPS} });
	push (@possible_groups, keys %{ $self->{TERMGROUPS} });
	push (@possible_groups, @{ &{ $groupFilter }($self, undef, $term)}) if ($groupFilter eq \&KWSSegAlign::groupByAttributes);
	foreach my $group (@possible_groups) {
	  my $totTrials = scalar(@fsegments);
	  $totTrials = $grouptcounts{$group} if (defined $grouptcounts{$group});
	  $qtrials{$group} = new TrialsDiscreteTWV({ ("TotTrials" => $totTrials, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg) }) if (not defined $qtrials{$group});
	  if (not defined $qtrials{$group}->{"trials"}{$termid}) {
	    $qtrials{$group}->addEmptyBlock($termid);
	    $qtrials{$group}->addBlockMetaData($termid, \%blockMetaData);
	  }
	}
      }
    }
  }
#####

  my $metric = new MetricDiscreteTWV({ ('Cost' =>$KoefC, 'Value' => $KoefV, 'Ptarg' => $probofterm ) }, $trials);
  my $detcurve = new DETCurve($trials, $metric, $trials->{"DecisionID"}, $listIsolineCoef, undef);
  $detset->addDET($trials->{"DecisionID"}, $detcurve);
  #Build DETCurve(Set) for conditional occurence report
  foreach my $qtrialname (sort keys %qtrials) {
    my $metric = new MetricDiscreteTWV({ ('Cost' =>$KoefC, 'Value' => $KoefV, 'Ptarg' => $probofterm ) }, $qtrials{$qtrialname});
    my $qdetcurve = new DETCurve($qtrials{$qtrialname}, $metric, $qtrialname, $listIsolineCoef, undef);
    $qdetset->addDET($qtrialname, $qdetcurve);
  }

  close (CSVREPORT) if (defined $csvreportfile);
  
  return [ $detset, $qdetset ]; 
}


#>======<> DETCurve Filters <>======<#

sub setFilterData
{
  my ($self, $srctypegroups, $termgroups, $filechans, $attributes) = @_;
  
  $self->{SRCTYPEGROUPS} =$srctypegroups if (defined $srctypegroups);
  $self->{TERMGROUPS} = $termgroups if (defined $termgroups);
  $self->{FILECHANS} = $filechans if (defined $filechans);
  $self->{ATTRIBUTES} = $attributes if (defined $attributes);
}

sub filterByFileChan
{
  my ($self, $segment) = @_;

  foreach my $filechan (@{ $self->{FILECHANS} }) {
    return 1 if (($segment->{FILE} . "/" . $segment->{CHAN}) =~ /^$filechan$/i);
  }
  return 0;
}

sub groupByTerms
{
  my ($self, $segment, $term) = @_;

  my @groups = ();
  foreach my $group (keys %{ $self->{TERMGROUPS} }) {
    foreach my $termid (@{ $self->{TERMGROUPS}{$group} }) {
      if ($term->{TERMID} =~ /^$termid$/i) {
	push (@groups, $group);
	last;
      }
    }
  }
  return \@groups;
}

sub groupByECFSourceType
{
  my ($self, $segment, $term) = @_;

  my @groups = ();
  foreach my $group (keys %{ $self->{SRCTYPEGROUPS} })
  {
    if (defined $segment->{ECFSRCTYPE}) {
      foreach my $srctype (@{ $self->{SRCTYPEGROUPS}{$group} }) {
	if ($segment->{ECFSRCTYPE} =~ /^$srctype$/i) {
	  push (@groups, $group);
	  last;
	}
      }
    }
  }
  return \@groups;
}

sub groupByAttributes
{
  my ($self, $rec, $term) = @_;
  my @groups = ();
  foreach my $attrvalexp (@{ $self->{ATTRIBUTES} }) {
    my ($attribute, $value_regexp) = ($attrvalexp, undef);
    if ($attrvalexp =~ /^(.+):regex=(.+)$/){
      ($attribute, $value_regexp) = ($1, $2)
    }
    my $value = $term->{$attribute};
    if (defined($value)){
      push (@groups, ($attribute . "-" . $value)) if ((!defined $value_regexp) || ($value =~ /$value_regexp/));
    }
  }
  return \@groups;
}

sub groupByOOV 
{
  my ($self, $segment, $term) = @_;
  my @groups = ();
  if ($self->{KWSLIST}{TERMS}{$term->{TERMID}}{OOV_TERM_COUNT} > 0) {
    push (@groups, "OOV"); }
  else {
    push (@groups, "IV"); }
  
  return \@groups;
}

#>==================================<#

sub _countECFGroupSegments
{
  my ($self, $group, $segments) = @_;
  my $count = 0;
  foreach my $seg (@{ $segments }) {
    if (defined $seg->{ECFSRCTYPE}) {
      foreach my $srctype (@{ $self->{SRCTYPEGROUPS}{$group} }) {
	if ($seg->{ECFSRCTYPE} =~ /^$srctype$/i) {
	  $count++;
	  last;
	}
      }
    }
  }
  return $count;
}

sub unitTest
{
  print "Test KWSSegAlign\n";
  my $path = shift;

  my $rttmfile = $path . "test5.rttm";
  my $kwsfile = $path . "test5.kwslist.xml";
  my $ecffile = $path . "test5.ecf.xml";
  my $termlistfile = $path . "test5.kwlist.xml";

#NOTE: This unit test assumes that overlapping sections of speech are collapsed into one segment.
#Any changes to RTTMList which intentionally change how segments are composed will recquire a refactor of this unit test.

  print "  Loading Files..\n";
  print "Loading TermList...\t";
  my $termlist = new TermList($termlistfile, 0, 0, 0);
  print "OK\n";
  print "Loading RTTMList...\t";
  my $rttmlist = new RTTMList($rttmfile, $termlist->getLanguage(), $termlist->getCompareNormalize(), $termlist->getEncoding(), 0, 0, 0);
  print "OK\n";
  print "Loading KWSList...\t";
  my $kwslist = new KWSList($kwsfile);
  print "OK\n";
  print "Loading KWSecf...\t";
  my $ecflist = new KWSecf($ecffile);
  print "OK\n";
  print "  Done Loading\n\n";

  print "Creating Alignment Object...\t";
  my $kwssegalign = new KWSSegAlign($rttmlist, $kwslist, $ecflist, $termlist);
  print "OK\n";
  
  my $findthresh = 0.5;
  my $KoefV = 1;
  my $KoefC = sprintf("%.4f", $KoefV/10);
  my $trialspersec = 1;
  my $probofterm = 0.0001;
  my @isolinecoef = (.1, 1, 3);

  my %termgroups = (
		    "1 Word Terms" => [ "TERM-01", "TERM-02" ],
		    "2 Word Terms" => [ "TERM-03" ],
		   );
  my %ecfgroups = (
		   "BNEWS+CTS" => [ "bnews", "cts" ],
		   "CONFMTG" => [ "confmtg" ],
		  );
  my @filechans = ("FILE01/1");
  my @attributes = "Characters";
  $kwssegalign->setFilterData(\%ecfgroups, \%termgroups, \@filechans, \@attributes);
  my $termfilter = \&groupByTerms;

  print "Aligning Segments...\t";
  my @results = @{ $kwssegalign->alignSegments(undef, [], $termfilter, $findthresh, $KoefC, $KoefV, $probofterm, \@isolinecoef) };
  print "OK\n";

  my $detset = $results[0];
  my $qdetset = $results[1];

  my $trials = $detset->{DETList}[0]->{DET}->getTrials();

  print "Checking Num Trials...\t";
  if ($trials->{"trialParams"}{"TotTrials"} == 20) { print "OK\n" }
  else { print "FAILED\n"; return 0 }

  print "Checking trial counts(1)...\t";
  if ($trials->{"trials"}->{"TERM-01"}{"YES TARG"} ==  10 &&
    $trials->{"trials"}->{"TERM-01"}{"NO TARG"} == 0 &&
    $trials->{"trials"}->{"TERM-01"}{"OMITTED TARG"} == 5 &&
    $trials->{"trials"}->{"TERM-01"}{"YES NONTARG"} == 2 &&
    $trials->{"trials"}->{"TERM-01"}{"NO NONTARG"} == 0) { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking trial counts(2)...\t";
  if ($trials->{"trials"}->{"TERM-02"}{"YES TARG"} ==  5 &&
    $trials->{"trials"}->{"TERM-02"}{"NO TARG"} == 0 &&
    $trials->{"trials"}->{"TERM-02"}{"OMITTED TARG"} == 10 &&
    $trials->{"trials"}->{"TERM-02"}{"YES NONTARG"} == 3 &&
    $trials->{"trials"}->{"TERM-02"}{"NO NONTARG"} == 0) { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking trial counts(3)...\t";
  if ($trials->{"trials"}->{"TERM-03"}{"YES TARG"} ==  2 &&
    $trials->{"trials"}->{"TERM-03"}{"NO TARG"} == 0 &&
    $trials->{"trials"}->{"TERM-03"}{"OMITTED TARG"} == 3 &&
    $trials->{"trials"}->{"TERM-03"}{"YES NONTARG"} == 5 &&
    $trials->{"trials"}->{"TERM-03"}{"NO NONTARG"} == 0) { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  
  my $qtrials0 = $qdetset->{DETList}[0]->{DET}->getTrials();
  my $qtrials1 = $qdetset->{DETList}[1]->{DET}->getTrials();
  print "Checking conditional trial counts(1)...\t";
  if (keys %{ $qtrials0->{"trials"} } == 3) { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking conditional trial counts(2)...\t";
  if (keys %{ $qtrials1->{"trials"} } == 2) { print "OK\n" }
  else { print "FAILED\n"; return 0 }

  #checking pooled results
  my @presults = @{ $kwssegalign->alignSegments(undef, [], $termfilter, $findthresh, $KoefC, $KoefV, $probofterm, \@isolinecoef, 1) };

  my $pdetset = $presults[0];
  my $ptrials = $pdetset->{DETList}[0]->{DET}->getTrials();
  
  print "Checking pooled trial counts(1)...\t";
  if ($ptrials->{"trials"}->{"Pooled"}{"YES TARG"} == 17 &&
      $ptrials->{"trials"}->{"Pooled"}{"NO TARG"} == 0 &&
      $ptrials->{"trials"}->{"Pooled"}{"OMITTED TARG"} == 18 &&
      $ptrials->{"trials"}->{"Pooled"}{"YES NONTARG"} == 10 &&
      $ptrials->{"trials"}->{"Pooled"}{"NO NONTARG"} == 0) { print "OK\n" }
  else { print "FAILED\n"; return 0 }

  my @termstofilter = @{ $kwssegalign->{KWSLIST}{TERMS}{"TERM-01"}{TERMS} };
  my @filteredterms = ();
  print "Checking term filters(1)...\t";
  foreach my $term (@termstofilter) {
    push (@filteredterms, $term) if ($kwssegalign->filterByFileChan($term) == 1); }
  if (scalar(@filteredterms) == 10) { print "OK\n" }
  else { print "FAILED\n"; return 0 }

  my $testseg = @{ $kwssegalign->{RTTMLIST}->getAllSegments($kwssegalign->{ECF}) }[0];

  my $testterm = $kwssegalign->{TERMLIST}->{TERMS}{"TERM-01"};
  print "Checking group filters(1)...\t";
  if ($kwssegalign->groupByTerms(undef, $testterm)->[0] eq "1 Word Terms") { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking group filters(2)...\t";
  if ($kwssegalign->groupByAttributes(undef, $testterm)->[0] eq "Characters-3") { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking group filters(3)...\t";
  if ($kwssegalign->groupByOOV(undef, $testterm)->[0] eq "IV") { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking group filters(4)...\t";
  if ($kwssegalign->groupByECFSourceType($testseg, undef)->[0] eq "BNEWS+CTS") { print "OK\n" }
  else { print "FAILED\n"; return 0 }


  print "\nAll tests...\tOK\n";
  return 1;
}

1;
