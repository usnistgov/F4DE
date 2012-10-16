# F4DE
# KWSAlignment.pm
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


package KWSAlignment;

use strict;

use KWSList;
use RTTMList;
use KWSecf;
use TermList;
use TrialsTWV;
use MetricTWV;
use AutoTable;
use BipartiteMatch;
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
  $self->{QUICKECF} = {};
  
  ##Filter Data
  $self->{SRCTYPEGROUPS} = undef; #{Group name}->@ of src types allowed in that group
  $self->{TERMGROUPS} = undef; #{Group name}->@ of termids allowed in that group
  $self->{ATTRIBUTE} = undef; #Attribute to group by, groups should be the values of this attribute
  $self->{FILECHANS} = undef; #@ of 'file/chan's allowed in the conditional report
  ##
  $self->{OOVCOUNTS} = (); #track term oov counts for filtering.

  #Add ecf segments to QuickECF lookup
  foreach my $ecfexcerpt (@{ $self->{ECF}{EXCERPT} }) {
    push (@{ $self->{QUICKECF}{$ecfexcerpt->{FILE}}{$ecfexcerpt->{CHANNEL}} }, $ecfexcerpt);
  }

  bless $self;
  return $self;
}

sub alignTerms
{
  my ($self, $csvreportfile, $termFilters, $groupFilter, $fthreshold, $sthreshold, $KoefC, $KoefV, $listIsolineCoef, $trialsPerSec, $probofterm, $pooled, $includeBlocksWNoTarg, $justSystemTerms) = @_;
  #fthreshold being the max time gap betwen two words that can be considered to be in the same term
  #sthreshold being the max time different between a system's term detection midpoint and the reference term's timeframe

  #BipartiteMatch Kernel params
  my $epsilonTime = 1e-8; #this weights time congruence in the joint mapping table
  my $epsilonScore = 1e-6; #this weights score congruence in the joint mapping table

  $includeBlocksWNoTarg = 0 if ($includeBlocksWNoTarg != 1);
  $justSystemTerms = 0 if ($justSystemTerms != 1);

  $self->configure_csv_writer($csvreportfile) if defined $csvreportfile;

  my %qtrials = (); #Conditional trials
  my $qdetset = new DETCurveSet();

  my $totdur = $self->{ECF}->calcTotalDur(undef, $self->{FILECHANS});
  my $trials = new TrialsTWV({ ("TotDur" => $totdur, "TrialsPerSecond" => $trialsPerSec, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg) });
  my $detset = new DETCurveSet();
  
  my %missed_terms = map {$_ => $_} keys %{ $self->{TERMLIST}{TERMS} }; #track terms missed by kws
  my $kws_done_loading = 0;
  while (1) {
    #get next detected list
    my @detected_results = $self->{KWSLIST}->getNextDetectedKWlist() unless $kws_done_loading;
    my ($msg, $detected_list) = ($detected_results[0], $detected_results[1]);
    warn $msg unless MMisc::is_blank($msg);
    #
    my $termid = "";
    if (!defined $detected_list) {
      last if $justSystemTerms == 1;
      $kws_done_loading = 1;
      $termid = (keys %missed_terms)[0];
      last unless $termid; #if no detected list and no terms, then done
      delete $missed_terms{$termid};
    } else {
      $termid = $detected_list->{TERMID};
      delete $missed_terms{$termid};
      $self->{OOVCOUNTS}{$termid} = $detected_list->{OOV_TERM_COUNT};
    }

    #build TERMLKUP
    my %termlkup = ();
    foreach my $sys_term (@{ $detected_list->{TERMS} }) {
      push @{ $termlkup{$sys_term->{FILE}}{$sys_term->{CHAN}} }, $sys_term if (KWSAlignment::belongsInECF($self, $sys_term) == 1);
    }

    my %refoccs = %{ $self->{RTTMLIST}->findTermOccurrences($self->{TERMLIST}->{TERMS}{$termid}{TEXT}, $fthreshold) };
    
    my $trialBlock = $termid;
    $trialBlock = "Pooled" if ($pooled);
    my %blockMetaData = ();
    $blockMetaData{"Text"} = $self->{TERMLIST}->{TERMS}{$termid}{TEXT} if (not $pooled);

    my %usedfilechans = ();
    foreach my $file (keys %refoccs) {
      foreach my $chan (keys %{ $refoccs{$file} }) {
	$usedfilechans{$file}{$chan} = 1;
	
	my %refs = ();
      REFBUILD: foreach my $ref (@{ $refoccs{$file}{$chan} }) {
	  foreach my $tfilter (@{ $termFilters }) {
	    next REFBUILD if (&{ $tfilter }($self, $ref) == 0);
	  }
	  $refs{$ref} = $ref;
	}
	my %syss = ();

      SYSBUILD: foreach my $sys (@{ $termlkup{$file}{$chan} }) {
	  foreach my $tfilter (@{ $termFilters }) {
	    next SYSBUILD if (&{ $tfilter }($self, $sys) == 0);
	  }
	  $syss{$sys} = $sys;
	}
	
	my @kparams = ( $epsilonTime, $epsilonScore, $sthreshold );
	my $biMatch = new BipartiteMatch(\%refs, \%syss, \&_bipartiteKernel, \@kparams);
	$biMatch->compute();

	#Hits
	foreach my $mapped (@{ $biMatch->{mapped} }) {
	  my $sysid = $mapped->[0];
	  my $refid = $mapped->[1];

	  $self->csv_write_align_str($self->{TERMLIST}{TERMS}{$termid}, $refs{$refid}, $syss{$sysid}) 
	    if defined $csvreportfile;
	  
	  #Add hit to trial
	  $trials->addTrial($trialBlock, $syss{$sysid}->{SCORE}, $syss{$sysid}->{DECISION}, 1, \%blockMetaData);
	  
	  #Add hit to conditional trial
	  next if (not defined $groupFilter);
	  foreach my $group (@{ &{ $groupFilter }($self, $refs{$refid}, $self->{TERMLIST}->{TERMS}{$termid}) }) {
	    my $grpTotDur = $totdur;
	    $grpTotDur = $self->{ECF}->calcTotalDur($self->{SRCTYPEGROUPS}->{$group}, $self->{FILECHANS}) if ($groupFilter eq \&KWSAlignment::groupByECFSourceType);
	    $qtrials{$group} = new TrialsTWV({ ("TotDur" => $grpTotDur, "TrialsPerSecond" => $trialsPerSec, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg) }) if (not defined $qtrials{$group});
	    $qtrials{$group}->addTrial($termid, $syss{$sysid}->{SCORE}, $syss{$sysid}->{DECISION}, 1, \%blockMetaData);
	  }
	}
	#Misses
	foreach my $refid (@{ $biMatch->{unmapped_ref} }) {

	  $self->csv_write_align_str($self->{TERMLIST}{TERMS}{$termid}, $refs{$refid}, undef) 
	    if defined $csvreportfile;
	  
	  #Add miss to trial
	  $trials->addTrial($trialBlock, undef, "OMITTED", 1, \%blockMetaData);
	  
	  #Add miss to conditional trial
	  next if (not defined $groupFilter);
	  foreach my $group (@{ &{ $groupFilter }($self, $refs{$refid}, $self->{TERMLIST}->{TERMS}{$termid}) }) {
	    my $grpTotDur = $totdur;
	    $grpTotDur = $self->{ECF}->calcTotalDur($self->{SRCTYPEGROUPS}->{$group}, $self->{FILECHANS}) if ($groupFilter eq \&KWSAlignment::groupByECFSourceType);
	    $qtrials{$group} = new TrialsTWV({ ("TotDur" => $grpTotDur, "TrialsPerSecond" => $trialsPerSec, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg) }) if (not defined $qtrials{$group});
	    $qtrials{$group}->addTrial($termid, undef, "OMITTED", 1, \%blockMetaData);
	  }
	}
	#FA & Corr!Det
	foreach my $sysid (@{ $biMatch->{unmapped_sys} }) {
	  my $alignresult = "CORR!DET";
	  $alignresult = "FA" if ($syss{$sysid}->{DECISION} eq "YES");
	  #Record as Correct non-detect or False Alarm
	  $self->csv_write_align_str($self->{TERMLIST}{TERMS}{$termid}, undef, $syss{$sysid}) 
	    if defined $csvreportfile;

	  #Add FA or Corr!Det to trial
	  $trials->addTrial($trialBlock, $syss{$sysid}->{SCORE}, $syss{$sysid}->{DECISION}, 0, \%blockMetaData);
	  
	  #Add FA or Corr!Det to conditional trial
	  next if (not defined $groupFilter);
	  foreach my $group (@{ &{ $groupFilter }($self, $syss{$sysid}, $self->{TERMLIST}->{TERMS}{$termid}) }) {
	    my $grpTotDur = $totdur;
	    $grpTotDur = $self->{ECF}->calcTotalDur($self->{SRCTYPEGROUPS}->{$group}, $self->{FILECHANS}) if ($groupFilter eq \&KWSAlignment::groupByECFSourceType);	    
	    $qtrials{$group} = new TrialsTWV({ ("TotDur" => $grpTotDur, "TrialsPerSecond" => $trialsPerSec, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg) }) if (not defined $qtrials{$group});
	    $qtrials{$group}->addTrial($termid, $syss{$sysid}->{SCORE}, $syss{$sysid}->{DECISION}, 0, \%blockMetaData);
	  }
	}
      }
    }
    #Check for terms in file/chan combintations which weren't present in ref occurrences
    foreach my $file (keys %termlkup ) {
      foreach my $chan (keys %{ $termlkup{$file} }) {
	next if (defined $usedfilechans{$file}{$chan} && $usedfilechans{$file}{$chan} == 1);
	#record as FA or Corr!Det
	foreach my $sysocc (@{ $termlkup{$file}{$chan} }) {
	  my $alignresult = "CORR!DET";
	  $alignresult = "FA" if ($sysocc->{DECISION} eq "YES");
	  #Record as Correct non-detect or False Alarm
	  $self->csv_write_align_str($self->{TERMLIST}{TERMS}{$termid}, undef, $sysocc) 
	    if defined $csvreportfile;
	  	  
	  #Add FA or Corr!Det to trial
	  $trials->addTrial($trialBlock, $sysocc->{SCORE}, $sysocc->{DECISION}, 0, \%blockMetaData);
	    
	  #Add FA or Corr!Det to conditional trial
	  next if (not defined $groupFilter);
	  foreach my $group (@{ &{ $groupFilter }($self, $sysocc, $self->{TERMLIST}->{TERMS}{$termid}) }) {
	    my $grpTotDur = $totdur;
	    $grpTotDur = $self->{ECF}->calcTotalDur($self->{SRCTYPEGROUPS}->{$group}, $self->{FILECHANS}) if ($groupFilter eq \&KWSAlignment::groupByECFSourceType);
	    $qtrials{$group} = new TrialsTWV({ ("TotDur" => $grpTotDur, "TrialsPerSecond" => $trialsPerSec, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg) }) if (not defined $qtrials{$group});
	    $qtrials{$group}->addTrial($termid, $sysocc->{SCORE}, $sysocc->{DECISION}, 0, \%blockMetaData);
	  }
	}
      }
    }

    #Add TermIDs as empty blocks if no data
    if (not defined $trials->{"trials"}{$termid}) {
      unless ($pooled) {
	$trials->addEmptyBlock($termid);
	$trials->addBlockMetaData($termid, \%blockMetaData);
      }
      
      if (defined $groupFilter) {
	my @possible_groups = (); #empty trials should be added to all groups
	push (@possible_groups, keys %{ $self->{SRCTYPEGROUPS} });
	push (@possible_groups, keys %{ $self->{TERMGROUPS} });
	push (@possible_groups, @{ &{ $groupFilter }($self, undef, $self->{TERMLIST}->{TERMS}{$termid})}) if ($groupFilter eq \&KWSAlignment::groupByAttributes);
	foreach my $group (@possible_groups) {
	  my $grpTotDur = $totdur;
	  $grpTotDur = $self->{ECF}->calcTotalDur($self->{SRCTYPEGROUPS}->{$group}, $self->{FILECHANS}) if ($groupFilter eq \&KWSAlignment::groupByECFSourceType);
	  if ($grpTotDur == 0) {
	    MMisc::warn_print("No ECF segments available for group : $group, (group duration is 0)");
	    next;
	  }

	  $qtrials{$group} = new TrialsTWV({ ("TotDur" => $grpTotDur, "TrialsPerSecond" => $trialsPerSec, "IncludeBlocksWithNoTargets" => $includeBlocksWNoTarg) }) if (not defined $qtrials{$group});
	  if (not defined $qtrials{$group}->{"trials"}{$termid}) {
	    $qtrials{$group}->addEmptyBlock($termid);
	    $qtrials{$group}->addBlockMetaData($termid, \%blockMetaData);
	  }
	}
      }
    }
  } #End of termid loop
    
  #Build DETCurveSet
  my $metric = new MetricTWV({ ('Cost' =>$KoefC, 'Value' => $KoefV, 'Ptarg' => $probofterm ) }, $trials);
  my $detcurve = new DETCurve($trials, $metric, $trials->{"DecisionID"}, $listIsolineCoef, undef);
  $detset->addDET($trials->{"DecisionID"}, $detcurve);

  #Build conditional DETCurveSet
  foreach my $qtrialname (sort keys %qtrials) {
    my $metric = new MetricTWV({ ('Cost' =>$KoefC, 'Value' => $KoefV, 'Ptarg' => $probofterm ) }, $qtrials{$qtrialname});
    my $qdetcurve = new DETCurve($qtrials{$qtrialname}, $metric, $qtrialname, $listIsolineCoef, undef);
    $qdetset->addDET($qtrialname, $qdetcurve);
  }

  $self->csv_close() if defined $csvreportfile;

  return [ $detset, $qdetset ];
}

###### CSV Writer #########

sub configure_csv_writer {
 my ($self, $filename) = @_;

 open CSVFH, ">$filename";
 binmode CSVFH, $self->{RTTMLIST}->getPerlEncodingString() if $self->{RTTMLIST}->{ENCODING} ne "";
 *CSVFH;
 print CSVFH "language,file,channel,termid,term,ref_bt,ref_et,sys_bt,sys_et,sys_score,sys_decision,alignment\n";
}
sub csv_write_align_str {
  my ($self, $term, $refs, $sys) = @_;
  my $result = $sys ? ($sys->{DECISION} eq "YES" ? ($refs ? "CORR" : "FA") : ($refs ? "MISS" : "FA")) : "MISS";
  print CSVFH join(",",
			    $self->{RTTMLIST}->{LANGUAGE},
			    ($refs->[0] || $sys)->{FILE},
			    ($refs->[0] || $sys)->{CHAN},
			    $term->{TERMID},
			    $term->{TEXT},
			    $refs->[0]->{BT},
			    $refs->[-1]->{ET},
			    $sys->{BT},
			    $sys->{ET},
			    $sys->{SCORE},
			    $sys->{DECISION},
			    $result) . "\n" if defined *CSVFH;
}
sub csv_close {
  my $self = shift;
  close CSVFH if defined *CSVFH;
}

#>===========Filters==========<#

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
  my ($self, $rec) = @_;

  $rec = $rec->[0] if (ref($rec) eq "ARRAY");

  foreach my $filechan (@{ $self->{FILECHANS} }) {
    return 1 if (($rec->{FILE} . "/" . $rec->{CHAN}) =~ /^$filechan$/i);
  }
  return 0;
}

sub belongsInECF
{
  my ($self, $rec) = @_;

  $rec = $rec->[0] if (ref($rec) eq "ARRAY");

  foreach my $ecfexcerpt (@{ $self->{QUICKECF}{$rec->{FILE}}{$rec->{CHAN}} }) {
    if ($rec->{FILE} eq $ecfexcerpt->{FILE} &&
	$rec->{CHAN} eq $ecfexcerpt->{CHANNEL} &&
	$rec->{BT} >= $ecfexcerpt->{TBEG} &&
	$rec->{ET} <= $ecfexcerpt->{TEND}) {
      return 1;
    }
  }
  return 0;
}

sub groupByTerms
{
  my ($self, $rec, $term) = @_;

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
  my ($self, $rec, $term) = @_;

  my @groups = ();
  if ($self->{OOVCOUNTS}{$term->{TERMID}} > 0) {
    push (@groups, "OOV"); }
  else {
    push (@groups, "IV"); }
  
  return \@groups;
}

sub groupByECFSourceType
{
  my ($self, $rec, $term) = @_;

  #if rttm record set get first rttm record
  $rec = $rec->[0] if (ref($rec) eq "ARRAY");

  my @groups = ();
  foreach my $group (keys %{ $self->{SRCTYPEGROUPS} }) {
    my $ecfexcerpt = $self->_ecfOfRecord($rec);
    if (defined $ecfexcerpt) {
      foreach my $srctype (@{ $self->{SRCTYPEGROUPS}{$group} }) {
	if ($ecfexcerpt->{SOURCE_TYPE} =~ /^$srctype$/i) {
	  push (@groups, $group);
	  last;
	}
      }
    }
  }
  return \@groups;
}

#>============================<#

sub _dumprefocc
{
  my ($ref) = @_;
  print "Token: ";
  foreach my $rec (@{ $ref }) { print $rec->{TOKEN} . " "; }
  print "\n";
  print "File: " . $ref->[0]->{FILE} . "\tChan: " . $ref->[0]->{CHAN} . "\n";
  print "BT: " . $ref->[0]->{BT} . "\tET: " . $ref->[-1]->{ET} . "\n";
}

sub _dumpsysocc
{
  my ($sys) = @_;
  
  print "File: " . $sys->{FILE} . "\tChan: " . $sys->{CHAN} . "\n";
  print "BT: " . $sys->{BT} . "\tET: " . $sys->{ET} . "\n";
  print "Score: " . $sys->{SCORE} . "\tDec: " . $sys->{DECISION} . "\n";
}

sub _bipartiteKernel
{
  my ($ref, $sys, @params) = @_;

  return ('', -1) if (!defined $ref || !defined $sys);

  #params[0] = epsilon time, params[1] = epsilon score, params[2] = alignment threshold
  my $maxBT = 0.0;
  if ($sys->{BT} > $ref->[0]->{BT}) { $maxBT = $sys->{BT} }
  else { $maxBT = $ref->[0]->{BT} }
  my $minET = 0.0;
  if ($sys->{ET} < $ref->[-1]->{ET}) { $minET = $sys->{ET} }
  else { $minET = $ref->[-1]->{ET} }

  my $dTime = $minET - $maxBT;
  return ('', undef) if ($sys->{MID} < $ref->[0]->{BT} - $params[2] || $sys->{MID} > $ref->[-1]->{ET} + $params[2]);

  my $kscore = 1 + ($params[0] * $dTime) + ($params[1] * $sys->{SCORE});
  return ('', $kscore);
}

sub _ecfOfRecord
{
  my ($self, $rec) = @_;

  #if rttm record set get first rttm record
  $rec = $rec->[0] if (ref($rec) eq "ARRAY");

  foreach my $ecfexcerpt (@{ $self->{QUICKECF}{$rec->{FILE}}{$rec->{CHAN}} }) {
    return $ecfexcerpt if ($rec->{BT} >= $ecfexcerpt->{TBEG} && $rec->{ET} <= $ecfexcerpt->{TEND});
  }
  return undef;
}

sub unitTest
{
  print "Test KWSAlignment\n";
  my $path = shift;

  my $rttmfile = $path . "test6.rttm";
  my $kwsfile = $path . "test6.kwslist.xml";
  my $ecffile = $path . "test6.ecf.xml";
  my $termlistfile = $path . "test6.kwlist.xml";

  print "Loading Files..\n";
  print "Loading TermList...\t";
  my $tlist = new TermList($termlistfile, 0, 0, 0);
  print "OK\n";
  print "Loading RTTMList...\t";
  my $rttm = new RTTMList($rttmfile, $tlist->getLanguage(), $tlist->getCompareNormalize(), $tlist->getEncoding(), 0, 0, 0);
  print "OK\n";
  print "Loading KWSList...\t";
  my $kws = new KWSList();
  $kws->openXMLFileAccess($kwsfile);
  print "OK\n";
  print "Loading KWSecf...\t";
  my $ecf = new KWSecf($ecffile);
  print "OK\n";
  print "Done Loading\n\n";
  
  print "Creating Alignment Object...\t";
  my $kwsalign = new KWSAlignment($rttm, $kws, $ecf, $tlist);
  print "OK\n";

  my $findthresh = 0.5;
  my $alignthresh = 0.5;
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
		   "BNEWS+CTS" => [ "bnews", "cts" ]
		  );
  my @filechans = ("FILE01/1");
  my @attributes = ("Characters");
  $kwsalign->setFilterData(\%ecfgroups, \%termgroups, undef, \@attributes);

  my $groupfilter = \&groupByECFSourceType;
  my $termfilter = \&groupByTerms;
  print "Aligning...\t";
  my @results = @{ $kwsalign->alignTerms(undef, [], $termfilter, $findthresh, $alignthresh, $KoefC, $KoefV, \@isolinecoef, $trialspersec, $probofterm, 0) };
  print "OK\n";

  my $detset = $results[0];
  my $qdetset = $results[1];

  my $trials = $detset->{DETList}[0]->{DET}->getTrials();

  print "Checking Num Trials...\t";
  if ($trials->{"trialParams"}{"TotTrials"} == 100) { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking Trial Duration...\t";
  if ($trials->{"trialParams"}{"TotDur"} == 100) { print "OK\n" }
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
  $kws = new KWSList();
  $kws->openXMLFileAccess($kwsfile, 1);
  $kwsalign->{KWSLIST} = $kws;
  my @presults = @{ $kwsalign->alignTerms(undef, [], $termfilter, $findthresh, $alignthresh, $KoefC, $KoefV, \@isolinecoef, $trialspersec, $probofterm, 1) };

  my $pdetset = $presults[0];
  my $ptrials = $pdetset->{DETList}[0]->{DET}->getTrials();
    
  print "Checking pooled trial counts(1)...\t";
  if ($ptrials->{"trials"}->{"Pooled"}{"YES TARG"} == 17 &&
      $ptrials->{"trials"}->{"Pooled"}{"NO TARG"} == 0 &&
      $ptrials->{"trials"}->{"Pooled"}{"OMITTED TARG"} == 18 &&
      $ptrials->{"trials"}->{"Pooled"}{"YES NONTARG"} == 10 &&
      $ptrials->{"trials"}->{"Pooled"}{"NO NONTARG"} == 0) { print "OK\n" }
  else { print "FAILED\n"; return 0 }
      
  $kwsalign->{FILECHANS} = \@filechans;
  my @termstofilter = @{ $kwsalign->{KWSLIST}{TERMS}{"TERM-01"}{TERMS} };
  my @filteredterms = ();
  print "Checking term filters(1)...\t";
  foreach my $term (@termstofilter) {
    push (@filteredterms, $term) if ($kwsalign->filterByFileChan($term) == 1); }
  if (scalar(@filteredterms) == 10) { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  @filteredterms = ();
  print "Checking term filters(2)...\t";
  foreach my $term (@termstofilter) {
    push (@filteredterms, $term) if ($kwsalign->belongsInECF($term) == 1); }
  if (scalar(@filteredterms) == 12) { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  my $testterm = $kwsalign->{TERMLIST}->{TERMS}{"TERM-01"};
  print "Checking group filters(1)...\t";
  if ($kwsalign->groupByTerms(undef, $testterm)->[0] eq "1 Word Terms") { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking group filters(2)...\t";
  if ($kwsalign->groupByAttributes(undef, $testterm)->[0] eq "Characters-3") { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking group filters(3)...\t";
  if ($kwsalign->groupByOOV(undef, $testterm)->[0] eq "IV") { print "OK\n" }
  else { print "FAILED\n"; return 0 }
  print "Checking group filters(4)...\t";
  if ($kwsalign->groupByECFSourceType($termstofilter[0], undef)->[0] eq "BNEWS+CTS") { print "OK\n" }
  else { print "FAILED\n"; return 0 }

  print "\nAll tests...\tOK\n";
  return 1;
}

1;
