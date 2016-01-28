# F4DE Package
#
# $Id$
#
# DETCurve.pm
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
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

BEGIN {
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }
}

package DETCurve;

use strict;
use TrialsFuncs;

use MetricFuncs;
use MetricTestStub;
use MetricTV08;
use MetricNormLinearCostFunct;
use MetricTWV;
use MetricDiscreteTWV;
use MetricPrecRecallFbeta;
use MetricRo;

use Data::Dumper;
use DETCurveSet;
use PropList;
use MMisc;

my(@tics) = (0.00001, 0.0001, 0.001, 0.004, .01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 40, 60, 80, 90, 95, 98, 99, 99.5, 99.9);

sub new
  {
    my ($class, $trials, $metric, $lineTitle, $listIsolineCoef, $gzipPROG, $evalstruct) = @_;
        
    my $self =
      { 
       TRIALS => $trials,
       METRIC => $metric,
       LINETITLE => $lineTitle,
       MINSCORE => undef,
       MAXSCORE => undef,
       MAXIMIZEBEST => undef,
       BESTCOMB => { DETECTIONSCORE => undef, COMB => undef, MFA => undef, MMISS => undef },
       OPTIMUMCOMB => { DETECTIONSCORE => undef, COMB => undef, MFA => undef, MMISS => undef, BLOCKS => {()} },
       SUPREMUMCOMB => { DETECTIONSCORE => undef, COMB => undef, MFA => undef, MMISS => undef, BLOCKS => {()} },
       SYSTEMDECISIONVALUE => undef, ### this is the value based on the system's hard decisions
       POINTS => undef, ## 2D array (score, Mmiss, Mfa, comb);  IF style is blocked, then (sampleStandardDev(Mmiss), ssd(Mfa), ssd(ssdComb), $numBlocks) 
       LAST_GNU_DETFILE_PNG => "",
       LAST_GNU_THRESHPLOT_PNG => "",
       LAST_GNU_MEASURE_THRESHPLOT_PNG => undef,
       LAST_SERIALIZED_DET => "",
       MESSAGES => "",
       ISOLINE_COEFFICIENTS => [ sort {$a <=> $b} @$listIsolineCoef],
       ISOLINE_COEFFICIENTS_INDEX => 0,         
       ISOPOINTS => {},
       GZIPPROG => (defined($gzipPROG) ? $gzipPROG : "gzip"),
       EVALSTRUCT => (defined($evalstruct)) ? 1 : 0,
       POINT_COMPUTATION_ATTEMPTED => 0,
       FIXED_MFA_VLAUES => undef,
       CURVE_STYLE => "UniqThreshold",
       GLOBALMEASURES => {},
      };
        
    bless $self;
        
    #   print Dumper($listIsolineCoef);
        
    die "Error: Combined metric must have the output of combType() be 'maximizable|minimizable'" 
      if ($metric->combType() !~ /^(maximizable|minimizable)$/);
    $self->{MAXIMIZEBEST} = ($metric->combType() eq "maximizable");
                
    return $self;
  }

sub thisabs{ ($_[0] < 0) ? $_[0]*(-1) : $_[0]; }

sub unitTest
  {
    print "Test DETCurve\n";
    blockWeightedUnitTest();
    srlLoadTest();
    #   unitTestMultiDet();
    # bigDETUnitTest();
    globalMeasureUnitTest();
    return 1;
  }

sub srlLoadTest {
    print " Testing srl loading\n";

    use MetricNormLinearCostFunct;
    ################################### A target point
    ### Pmiss == 0.1  - 1 misses
    ### PFa == 0.0075  - 3 FA  
    ### Cost == 0.8425
         
    my $trial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trial->addTrial("she", 0.03, "NO", 0);
    $trial->addTrial("she", 0.04, "NO", 0);
    $trial->addTrial("she", 0.05, "NO",  0);
    $trial->addTrial("she", 0.10, "NO", 0);
    $trial->addTrial("she", 0.15, "NO", 1);
    foreach (1..391){
        $trial->addTrial("she", 0.17, "NO", 0);
    }
    $trial->addTrial("she", 0.17, "NO", 0);
    $trial->addTrial("she", 0.20, "NO", 0);
    $trial->addTrial("she", 0.25, "YES", 1);
    $trial->addTrial("she", 0.65, "YES", 1);
    $trial->addTrial("she", 0.70, "YES", 0);
    $trial->addTrial("she", 0.70, "YES", 0);
    $trial->addTrial("she", 0.70, "YES", 0);
    $trial->addTrial("she", 0.75, "YES", 1);
    $trial->addTrial("she", 0.75, "YES", 1);
    $trial->addTrial("she", 0.85, "YES", 1);
    $trial->addTrial("she", 0.85, "YES", 1);
    $trial->addTrial("she", 0.98, "YES", 1);
    $trial->addTrial("she", 0.98, "YES", 1);
    $trial->addTrial("she", 1.0, "YES", 1);

    my $sortKeys = $Data::Dumper::Sortkeys;
    $Data::Dumper::Sortkeys = 1;

    my @isolinecoef = ( 31 );
    my $met = new MetricNormLinearCostFunct({ ('CostFA' => 1, 'CostMiss' => 10, 'Ptarg' => 0.01 ) }, $trial);
    my $legacyDet = new DETCurve($trial, $met, "Targetted point", \@isolinecoef, undef, 1);
    $legacyDet->computePoints();
    my $binaryDet = new DETCurve($trial, $met, "Targetted point", \@isolinecoef, undef, undef);
    $binaryDet->computePoints();

    print "  Legacy srl load test ... ";
    # Write the det to a file the old school way and read it back in.
    my $tmp = "/tmp/serialize";
    $legacyDet->serialize($tmp);
    my $readLegacyDet = DETCurve::readFromFile("$tmp.gz", "gzip");

    # Compare the dets.
    die "  Error: Legacy dets don't match.\n" if (Dumper(\$legacyDet) ne Dumper(\$readLegacyDet));

    # Delete the temp file.
    if (unlink("$tmp.gz") != 1) {
      print "  !!! Warning: Serialization tests passed but file removal of '$tmp.gz' failed\n";
    }
    print "OK\n";

    print "  Binary srl load test ... ";
    # Write the det to a file the old school way and read it back in.
    $tmp = "/tmp/serialize";
    $binaryDet->serialize($tmp);
    my $readBinaryDet = DETCurve::readFromFile("$tmp.gz", "gzip");

    # Compare the dets.
    die "  Error: Binary dets don't match.\n" if (Dumper(\$legacyDet) ne Dumper(\$readLegacyDet));

    # Delete the temp file.
    if (unlink("$tmp.gz") != 1) {
      print "  !!! Warning: Serialization tests passed but file removal of '$tmp.gz' failed\n";
    }
    print "OK\n";

    $Data::Dumper::Sortkeys = $sortKeys;
    
}

sub _testOneBlock{
  my ($mesg, $trial, $points, $expGlob, $expOptSup, $expBlockOptSup, $expRatios, $expBlockRatios, $expPrecAtRecall) = @_;
  my ($report, $blockReport) = ("", "");
  
  print "  $mesg\n";
  my @isolinecoef = (100, 10);
  my $met = new MetricNormLinearCostFunct({ ('CostFA' => 1, 'CostMiss' => 10, 'Ptarg' => 0.01 ) }, $trial);
  my $det = new DETCurve($trial, $met, "Targetted point", \@isolinecoef, undef, 1);
  foreach my $gm(keys %$expGlob){
    if    ($gm eq "AP"){    $det->computeAvgPrec(); }
    elsif ($gm eq "APP"){   $det->computeAvgPrecPrime(); }
    elsif ($gm eq "MAP"){   $det->computeMeanAvgPrec(); }
    elsif ($gm eq "MAPP"){  $det->computeMeanAvgPrecPrime(); }
    else {
      die "Requested global measure /$gm/ in _testOneBlock not defined";
    }
  }

  if ($det->testGeneratedPoints($points, "    ") ne "ok"){ 
    print "\n   Error: points do not match\n";  
    print $det->getPointsAsPerlArrayOfArrays();
    exit 1;
  }
  print "Ok\n";
  print "    Checking Global Measures ".join(", ", sort keys %$expGlob)." .. ";
  foreach my $gm(keys %$expGlob){
    if (! exists($det->{GLOBALMEASURES}{$gm})){
      print "\n  Error!!! Global Measure $gm not computed\n".Dumper($det->{GLOBALMEASURES});
      exit(1);
    }
    if ((! defined($expGlob->{$gm})) && $det->{GLOBALMEASURES}{$gm}{STATUS} eq "Computed"){
      print "\n  Error!!! Global computation of $gm produced data but expected undefined\n";
      print Dumper($det->{GLOBALMEASURES}{$gm});
      exit(1);
    } elsif (defined($expGlob->{$gm}) && $det->{GLOBALMEASURES}{$gm}{STATUS} ne "Computed"){
      print "\n  Error!!! Global computation for $gm.  expected a computation but it failed\n";
      print Dumper($det->{GLOBALMEASURES}{$gm});
      exit(1);
    } elsif (abs($det->{GLOBALMEASURES}{$gm}{MEASURE}{$gm} - $expGlob->{$gm}) > 0.001){
      print "\n  Error!!! Global computation for $gm.  expected $expGlob->{$gm}, got $det->{GLOBALMEASURES}{$gm}{MEASURE}{$gm}\n";
      print Dumper($det->{GLOBALMEASURES}{$gm});
      exit(1);
    }
  }
  print "ok\n";

  print "    Checking Overall Optimum and Supremum .. ";
  foreach my $k(keys %$expOptSup){
    foreach my $attr(keys %{ $expOptSup->{$k} }){
      if ((! defined($expOptSup->{$k}{$attr})) && defined($det->{$k}{$attr})){
        print "\n  Error!!! $k computation failed for attribute $attr but expected undefined\n";
        print Dumper($det->{$k});
        exit(1);
      } elsif (abs($det->{$k}{$attr} - $expOptSup->{$k}{$attr}) > 0.001){
        print "\n  Error!!! $k computation failed for attribute $attr but expected $expOptSup->{$k}{$attr}, got $det->{$k}{$attr}\n";
        print Dumper($det->{$k});
        exit(1);
      }
    }
  }
  print "Ok\n";

  print "    Checking Block Optimum and Supremum .. ";
  foreach my $blk(keys %$expBlockOptSup){
    foreach my $k(keys %{ $expBlockOptSup->{$blk} }){
      foreach my $attr(keys %{ $expBlockOptSup->{$blk}{$k} }){
        if ((! defined($expBlockOptSup->{$blk}{$k}{$attr})) && defined($det->{$k}{BLOCKS}{$blk}{$attr})){
          print "\n  Error!!! $k computation failed for attribute $attr of block $blk but expected undefined\n";
          print Dumper($det->{$k});
          exit(1);
        } elsif (abs($det->{$k}{BLOCKS}{$blk}{$attr} - $expBlockOptSup->{$blk}{$k}{$attr}) > 0.001){
          print "\n  Error!!! $k computation failed for attribute $attr of block $blk.  ".
                "expected $expBlockOptSup->{$blk}{$k}{$attr}, got $det->{$k}{BLOCKS}{$blk}{$attr}\n";
          print Dumper($det->{$k});
          exit(1);
        }
      }
    }
  }
  print "Ok\n";

  if (scalar(keys %$expRatios) > 0){  
    print "    Checking Ratios .. ";
    foreach my $coef(keys %$expRatios){
      foreach my $attr(keys %{ $expRatios->{$coef} }){
        ### Overall
        if ((defined($expRatios->{$coef}{$attr})) && !defined($det->{ISOPOINTS}{$coef}{$attr})){
          print "\n  Error!!! ISOPOINTS for coeff $coef failed for attribute $attr\n";
          print Dumper($det->{ISOPOINTS}{$coef});
          exit(1);
        } elsif (abs($expRatios->{$coef}{$attr} - $det->{ISOPOINTS}{$coef}{$attr}) > 0.001){
          print "\n  Error!!! ISOPOINTS for coeff $coef failed for attribute $attr.  ".
                "expected $expRatios->{$coef}{$attr}, got $det->{ISOPOINTS}{$coef}{$attr}\n";
          print Dumper($det->{ISOPOINTS}{$coef});
          exit(1);
        }
      }
      ### for blocks
      foreach my $block(keys %$expBlockRatios){
        foreach my $attr(keys %{ $expBlockRatios->{$block}{$coef} }){
          if ((defined($expBlockRatios->{$block}{$coef}{$attr})) && !defined($det->{ISOPOINTS}{$coef}{BLOCKS}{$block}{$attr})){
            print "\n  Error!!! ISOPOINTS for coeff $coef of block $block failed for attribute $attr\n";
            print Dumper($det->{ISOPOINTS}{$coef});
            exit(1);
          } elsif (abs($expBlockRatios->{$block}{$coef}{$attr} - $det->{ISOPOINTS}{$coef}{BLOCKS}{$block}{$attr}) > 0.001){
            print "\n  Error!!! ISOPOINTS for coeff $coef of block $block failed for attribute $attr.  ".
                  "expected $expBlockRatios->{$block}{$coef}{$attr}, got $det->{ISOPOINTS}{$coef}{BLOCKS}{$block}{$attr}\n";
            print Dumper($det->{ISOPOINTS}{$coef});
            exit(1);
          }
        }
      }
    }
    print "Ok\n";
  }
  
  if (scalar(keys %$expPrecAtRecall) > 0){  
    print "    Checking Precision at recall .. \n";
    foreach my $met(keys %$expPrecAtRecall){
      print "      $met.. ";
      $det->computePrecAtRecall($met);
      my $res = $det->{GLOBALMEASURES}{$met};
      foreach my $l1(keys %{ $expPrecAtRecall->{$met} }){
        if (ref($expPrecAtRecall->{$met}{$l1}) eq "HASH"){
          foreach my $l2(keys %{ $expPrecAtRecall->{$met}{$l1} }){
            if ($res->{$l1}{$l2} ne $expPrecAtRecall->{$met}{$l1}{$l2}){
              print "Error: $l1,$l2=>".$expPrecAtRecall->{$met}{$l1}{$l2}." != to expected $res->{$l1}{$l2}\n";
              exit 1;
            }
          }
       } else {
          if ($res->{$l1} ne $expPrecAtRecall->{$met}{$l1}){
            print "Error: $l1=>".$expPrecAtRecall->{$met}{$l1}." != to expected $res->{$l1}\n";
            exit 1;
          }
        }
      }
      print "Ok\n";
    }
  }

  ### Rendering the reports to pass back
  my $ds = new DETCurveSet("Test DET");
  my $rtn = $ds->addDET("First", $det);
  MMisc::error_quit("Unable to add single DET to a set /$rtn/") if ($rtn ne "success");
  
  my $opts = {(createDETfiles => 1, ReportGlobal => 1, ExcludePNGFileFromTextTable => 1, "ReportOptimum" => 1, "ReportSupremum" => 1,
               ReportIsoRatios => 1, DrawIsoratiolines => 1, Isoratiolines => \@isolinecoef )};
  $report = $ds->renderAsTxt("foomerge", 1, $opts);  
#  print $report;
  $blockReport = $ds->renderBlockedReport(1, undef, undef, undef, undef, $opts);  
#  print $report;

  return($report, $blockReport); 
}

sub globalMeasureUnitTest(){
   #use Carp qw(cluck);
   ### Die on warning
   #$SIG{__WARN__} = sub { cluck "Warning:\n", @_, "\n";  die; };
   ### On die, make a stack trace
   #$SIG{__DIE__} = \&Carp::confess;
  print "Global Measure Unit Test\n";
  my ($report, $blockReport);
		
    use MetricNormLinearCostFunct;
         
    my $trial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trial->addTrial("she", 0.04, "NO", 1); #20
    $trial->addTrial("she", 0.05, "NO", 0);
    $trial->addTrial("she", 0.10, "NO", 0);
    $trial->addTrial("she", 0.10, "NO", 0);
    $trial->addTrial("she", 0.10, "NO", 0);
    $trial->addTrial("she", 0.15, "NO", 0);
    $trial->addTrial("she", 0.17, "NO", 0);
    $trial->addTrial("she", 0.20, "NO", 0);
    $trial->addTrial("she", 0.25, "YES", 0);
    $trial->addTrial("she", 0.65, "YES", 0);
    $trial->addTrial("she", 0.69, "YES", 1); #10
    $trial->addTrial("she", 0.70, "YES", 0);
    $trial->addTrial("she", 0.70, "YES", 0);
    $trial->addTrial("she", 0.73, "YES", 0);
    $trial->addTrial("she", 0.75, "YES", 1); #6
    $trial->addTrial("she", 0.85, "YES", 0);
    $trial->addTrial("she", 0.90, "YES", 0);
    $trial->addTrial("she", 0.92, "YES", 1); #3
    $trial->addTrial("she", 0.98, "YES", 0);
    $trial->addTrial("she", 1.0, "YES", 1);  #1
    #           Thr   Pmiss     Pfa   TWval  SSDPmiss, SSDPfa, SSDValue, #blocks
    my $trialPts
        = [ [ ( 0.040,  0.000,  1.000,  9.900, undef, undef, undef,  1.000 ) ],
            [ ( 0.050,  0.200,  1.000, 10.100, undef, undef, undef,  1.000 ) ],
            [ ( 0.100,  0.200,  0.933,  9.440, undef, undef, undef,  1.000 ) ],
            [ ( 0.150,  0.200,  0.733,  7.460, undef, undef, undef,  1.000 ) ],
            [ ( 0.170,  0.200,  0.667,  6.800, undef, undef, undef,  1.000 ) ],
            [ ( 0.200,  0.200,  0.600,  6.140, undef, undef, undef,  1.000 ) ],
            [ ( 0.250,  0.200,  0.533,  5.480, undef, undef, undef,  1.000 ) ],
            [ ( 0.650,  0.200,  0.467,  4.820, undef, undef, undef,  1.000 ) ],
            [ ( 0.690,  0.200,  0.400,  4.160, undef, undef, undef,  1.000 ) ],
            [ ( 0.700,  0.400,  0.400,  4.360, undef, undef, undef,  1.000 ) ],
            [ ( 0.730,  0.400,  0.267,  3.040, undef, undef, undef,  1.000 ) ],
            [ ( 0.750,  0.400,  0.200,  2.380, undef, undef, undef,  1.000 ) ],
            [ ( 0.850,  0.600,  0.200,  2.580, undef, undef, undef,  1.000 ) ],
            [ ( 0.900,  0.600,  0.133,  1.920, undef, undef, undef,  1.000 ) ],
            [ ( 0.920,  0.600,  0.067,  1.260, undef, undef, undef,  1.000 ) ],
            [ ( 0.980,  0.800,  0.067,  1.460, undef, undef, undef,  1.000 ) ],
            [ ( 1.000,  0.800,  0.000,  0.800, undef, undef, undef,  1.000 ) ] ];

    ### Same data as $trial but with 5 OMITTED trials
    my $trialOmitted = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trialOmitted->addTrial("she", 0.04, "NO", 1); #20
    $trialOmitted->addTrial("she", 0.05, "NO", 0);
    $trialOmitted->addTrial("she", 0.10, "NO", 0);
    $trialOmitted->addTrial("she", 0.10, "NO", 0);
    $trialOmitted->addTrial("she", 0.10, "NO", 0);
    $trialOmitted->addTrial("she", 0.15, "NO", 0);
    $trialOmitted->addTrial("she", 0.17, "NO", 0);
    $trialOmitted->addTrial("she", 0.20, "NO", 0);
    $trialOmitted->addTrial("she", 0.25, "YES", 0);
    $trialOmitted->addTrial("she", 0.65, "YES", 0);
    $trialOmitted->addTrial("she", 0.69, "YES", 1); #10
    $trialOmitted->addTrial("she", 0.70, "YES", 0);
    $trialOmitted->addTrial("she", 0.70, "YES", 0);
    $trialOmitted->addTrial("she", 0.73, "YES", 0);
    $trialOmitted->addTrial("she", 0.75, "YES", 1); #6
    $trialOmitted->addTrial("she", 0.85, "YES", 0);
    $trialOmitted->addTrial("she", 0.90, "YES", 0);
    $trialOmitted->addTrial("she", 0.92, "YES", 1); #3
    $trialOmitted->addTrial("she", 0.98, "YES", 0);
    $trialOmitted->addTrial("she", 1.0, "YES", 1);  #1
    $trialOmitted->addTrial("she", undef, "OMITTED", 1);  
    $trialOmitted->addTrial("she", undef, "OMITTED", 1);  
    $trialOmitted->addTrial("she", undef, "OMITTED", 1);  
    $trialOmitted->addTrial("she", undef, "OMITTED", 1);  
    $trialOmitted->addTrial("she", undef, "OMITTED", 1);  
    my $trialOmittedPts = 
          [ [ ( 0.040,  0.500,  1.000, 10.400, undef, undef, undef,  1.000 ) ],
            [ ( 0.050,  0.600,  1.000, 10.500, undef, undef, undef,  1.000 ) ],
            [ ( 0.100,  0.600,  0.933,  9.840, undef, undef, undef,  1.000 ) ],
            [ ( 0.150,  0.600,  0.733,  7.860, undef, undef, undef,  1.000 ) ],
            [ ( 0.170,  0.600,  0.667,  7.200, undef, undef, undef,  1.000 ) ],
            [ ( 0.200,  0.600,  0.600,  6.540, undef, undef, undef,  1.000 ) ],
            [ ( 0.250,  0.600,  0.533,  5.880, undef, undef, undef,  1.000 ) ],
            [ ( 0.650,  0.600,  0.467,  5.220, undef, undef, undef,  1.000 ) ],
            [ ( 0.690,  0.600,  0.400,  4.560, undef, undef, undef,  1.000 ) ],
            [ ( 0.700,  0.700,  0.400,  4.660, undef, undef, undef,  1.000 ) ],
            [ ( 0.730,  0.700,  0.267,  3.340, undef, undef, undef,  1.000 ) ],
            [ ( 0.750,  0.700,  0.200,  2.680, undef, undef, undef,  1.000 ) ],
            [ ( 0.850,  0.800,  0.200,  2.780, undef, undef, undef,  1.000 ) ],
            [ ( 0.900,  0.800,  0.133,  2.120, undef, undef, undef,  1.000 ) ],
            [ ( 0.920,  0.800,  0.067,  1.460, undef, undef, undef,  1.000 ) ],
            [ ( 0.980,  0.900,  0.067,  1.560, undef, undef, undef,  1.000 ) ],
            [ ( 1.000,  0.900,  0.000,  0.900, undef, undef, undef,  1.000 ) ] ];

    ### Same data as $trial but with 5 NoSystem trials
    my $trialNoSystem = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trialNoSystem->addTrial("she", undef, "OMITTED", 1);  
    $trialNoSystem->addTrial("she", undef, "OMITTED", 1);  
    $trialNoSystem->addTrial("she", undef, "OMITTED", 1);  
    $trialNoSystem->addTrial("she", undef, "OMITTED", 1);  
    $trialNoSystem->addTrial("she", undef, "OMITTED", 1);  
    my $trialNoSystemPts = 
          [ [ (    undef,  1.000, undef, undef, undef, undef, undef,  1.000 ) ] ];

    ### Same data as $trial but with 5 OnlyFASystem trials
    my $trialOnlyFASystem = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trialOnlyFASystem->addTrial("she", undef, "OMITTED", 1);  
    $trialOnlyFASystem->addTrial("she", undef, "OMITTED", 1);  
    $trialOnlyFASystem->addTrial("she", undef, "OMITTED", 1);  
    $trialOnlyFASystem->addTrial("she", undef, "OMITTED", 1);  
    $trialOnlyFASystem->addTrial("she", undef, "OMITTED", 1);  
    $trialOnlyFASystem->addTrial("she", 0.10, "NO", 0);
    $trialOnlyFASystem->addTrial("she", 0.10, "NO", 0);
    #           Thr   Pmiss     Pfa   TWval  SSDPmiss, SSDPfa, SSDValue, #blocks
    my $trialOnlyFASystemPts = 
          [ [ (    0.1,  1.000, 1.0, 10.900, undef, undef, undef,  1.000 ) ] ];

    ### Same data as $trial but with 5 EmptyBlock trials
    my $trialEmptyBlock = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trialEmptyBlock->addEmptyBlock("she");

    my $trial2 = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trial2->addTrial("she", 0.15, "NO", 1); #15
    $trial2->addTrial("she", 0.17, "NO", 0);
    $trial2->addTrial("she", 0.20, "NO", 0);
    $trial2->addTrial("she", 0.25, "YES", 0);
    $trial2->addTrial("she", 0.65, "YES", 0);
    $trial2->addTrial("she", 0.69, "YES", 0); 
    $trial2->addTrial("she", 0.70, "YES", 0);
    $trial2->addTrial("she", 0.70, "YES", 0);
    $trial2->addTrial("she", 0.73, "YES", 0);
    $trial2->addTrial("she", 0.75, "YES", 0);
    $trial2->addTrial("she", 0.85, "YES", 0);
    $trial2->addTrial("she", 0.90, "YES", 0);
    $trial2->addTrial("she", 0.92, "YES", 1); #3
    $trial2->addTrial("she", 0.98, "YES", 0);
    $trial2->addTrial("she", 1.0, "YES", 1);  #1
    my $trial2Pts = 
          [ [ ( 0.150,  0.000,  1.000,  9.900, undef, undef, undef,  1.000 ) ],
            [ ( 0.170,  0.333,  1.000, 10.233, undef, undef, undef,  1.000 ) ],
            [ ( 0.200,  0.333,  0.917,  9.408, undef, undef, undef,  1.000 ) ],
            [ ( 0.250,  0.333,  0.833,  8.583, undef, undef, undef,  1.000 ) ],
            [ ( 0.650,  0.333,  0.750,  7.758, undef, undef, undef,  1.000 ) ],
            [ ( 0.690,  0.333,  0.667,  6.933, undef, undef, undef,  1.000 ) ],
            [ ( 0.700,  0.333,  0.583,  6.108, undef, undef, undef,  1.000 ) ],
            [ ( 0.730,  0.333,  0.417,  4.458, undef, undef, undef,  1.000 ) ],
            [ ( 0.750,  0.333,  0.333,  3.633, undef, undef, undef,  1.000 ) ],
            [ ( 0.850,  0.333,  0.250,  2.808, undef, undef, undef,  1.000 ) ],
            [ ( 0.900,  0.333,  0.167,  1.983, undef, undef, undef,  1.000 ) ],
            [ ( 0.920,  0.333,  0.083,  1.158, undef, undef, undef,  1.000 ) ],
            [ ( 0.980,  0.667,  0.083,  1.492, undef, undef, undef,  1.000 ) ],
            [ ( 1.000,  0.667,  0.000,  0.667, undef, undef, undef,  1.000 ) ] ];

    my $trial3 = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trial3->setPreserveTrialID(1);
    $trial3->addTrial("she", 0.15, "NO",  1, undef, "id25"); #15
    $trial3->addTrial("she", 0.17, "NO",  0, undef, "id24");
    $trial3->addTrial("she", 0.20, "NO",  0, undef, "id23");
    $trial3->addTrial("she", 0.25, "YES", 0, undef, "id22");
    $trial3->addTrial("she", 0.65, "YES", 0, undef, "id21");
    $trial3->addTrial("she", 0.69, "YES", 0, undef, "id20"); 
    $trial3->addTrial("she", 0.70, "YES", 0, undef, "id19");
    $trial3->addTrial("she", 0.70, "YES", 0, undef, "id18");
    $trial3->addTrial("she", 0.73, "YES", 0, undef, "id17");
    $trial3->addTrial("she", 0.75, "YES", 0, undef, "id16");
    $trial3->addTrial("she", 0.92, "YES", 0, undef, "id15");
    $trial3->addTrial("she", 0.92, "YES", 0, undef, "id14");
    $trial3->addTrial("she", 0.92, "YES", 0, undef, "id12");
    $trial3->addTrial("she", 0.92, "YES", 1, undef, "id13"); #3
    $trial3->addTrial("she", 1.0, "YES",  1, undef, "id11");  #1
    my $trial3Pts =
          [ [ ( 0.150,  0.000,  1.000,  9.900, undef, undef, undef,  1.000 ) ],
            [ ( 0.170,  0.333,  1.000, 10.233, undef, undef, undef,  1.000 ) ],
            [ ( 0.200,  0.333,  0.917,  9.408, undef, undef, undef,  1.000 ) ],
            [ ( 0.250,  0.333,  0.833,  8.583, undef, undef, undef,  1.000 ) ],
            [ ( 0.650,  0.333,  0.750,  7.758, undef, undef, undef,  1.000 ) ],
            [ ( 0.690,  0.333,  0.667,  6.933, undef, undef, undef,  1.000 ) ],
            [ ( 0.700,  0.333,  0.583,  6.108, undef, undef, undef,  1.000 ) ],
            [ ( 0.730,  0.333,  0.417,  4.458, undef, undef, undef,  1.000 ) ],
            [ ( 0.750,  0.333,  0.333,  3.633, undef, undef, undef,  1.000 ) ],
            [ ( 0.920,  0.333,  0.250,  2.808, undef, undef, undef,  1.000 ) ],
            [ ( 1.000,  0.667,  0.000,  0.667, undef, undef, undef,  1.000 ) ] ];
  
    my $trial4 = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
    $trial4->setPreserveTrialID(1);
    $trial4->addTrial("she", 0.15, "NO",  0, undef);
    $trial4->addTrial("she", 0.17, "NO",  0, undef);
    $trial4->addTrial("she", 0.20, "NO",  1, undef);
    $trial4->addTrial("she", 0.25, "YES", 0, undef);
    $trial4->addTrial("she", 0.65, "YES", 0, undef);
    $trial4->addTrial("she", 0.69, "YES", 0, undef); 
    $trial4->addTrial("she", 0.70, "YES", 1, undef);
    $trial4->addTrial("she", 0.71, "YES", 0, undef);
    $trial4->addTrial("she", 0.73, "YES", 0, undef);
    $trial4->addTrial("she", 0.75, "YES", 1, undef);
    $trial4->addTrial("she", 0.80, "YES", 0, undef);
    $trial4->addTrial("she", 0.86, "YES", 1, undef);
    $trial4->addTrial("she", 0.90, "YES", 1, undef);
    $trial4->addTrial("she", 0.92, "YES", 1, undef);  
    $trial4->addTrial("she", 1.00, "YES", 1, undef);
    my $trial4Pts =
          [ [ ( 0.150,  0.000,  1.000,  9.900, undef, undef, undef,  1.000 ) ],
            [ ( 0.170,  0.000,  0.875,  8.662, undef, undef, undef,  1.000 ) ],
            [ ( 0.200,  0.000,  0.750,  7.425, undef, undef, undef,  1.000 ) ],
            [ ( 0.250,  0.143,  0.750,  7.568, undef, undef, undef,  1.000 ) ],
            [ ( 0.650,  0.143,  0.625,  6.330, undef, undef, undef,  1.000 ) ],
            [ ( 0.690,  0.143,  0.500,  5.093, undef, undef, undef,  1.000 ) ],
            [ ( 0.700,  0.143,  0.375,  3.855, undef, undef, undef,  1.000 ) ],
            [ ( 0.710,  0.286,  0.375,  3.998, undef, undef, undef,  1.000 ) ],
            [ ( 0.730,  0.286,  0.250,  2.761, undef, undef, undef,  1.000 ) ],
            [ ( 0.750,  0.286,  0.125,  1.523, undef, undef, undef,  1.000 ) ],
            [ ( 0.800,  0.429,  0.125,  1.666, undef, undef, undef,  1.000 ) ],
            [ ( 0.860,  0.429,  0.000,  0.429, undef, undef, undef,  1.000 ) ],
            [ ( 0.900,  0.571,  0.000,  0.571, undef, undef, undef,  1.000 ) ],
            [ ( 0.920,  0.714,  0.000,  0.714, undef, undef, undef,  1.000 ) ],
            [ ( 1.000,  0.857,  0.000,  0.857, undef, undef, undef,  1.000 ) ] ];
  
    _testOneBlock("Full system coverage of trials", $trial, $trialPts, 
                  { AP => 0.563333, APP => 0.20241409},
                  { OPTIMUMCOMB  => { COMB => 0.8, MMISS => 0.8, MFA => 0.0, DETECTIONSCORE => undef},
                    SUPREMUMCOMB => { COMB => 0.0, MMISS => 0.0, MFA => 0.0, DETECTIONSCORE => undef}},
                  { "she" => {OPTIMUMCOMB  => { COMB => 0.8, MMISS => 0.8, MFA => 0, DETECTIONSCORE => 1},
                              SUPREMUMCOMB => { COMB => 0.0, MMISS => 0.0, MFA => 0.0, DETECTIONSCORE => 0.5}}},
                  { 10  => { INTERPOLATED_COMB => 1.32666, INTERPOLATED_MMISS => 0.6666, INTERPOLATED_MFA => 0.0667, INTERPOLATED_DETECTSCORE => 0.98},
                    100 => { INTERPOLATED_COMB => 0.87920, INTERPOLATED_MMISS => 0.8000, INTERPOLATED_MFA => 0.0080, INTERPOLATED_DETECTSCORE => 1.00}},
                  { "she" => { 10 =>  { COMB => 1.32666, MMISS => 0.6666, MFA => 0.0667},
                               100 => { COMB => 0.87920, MMISS => 0.8000, MFA => 0.0080}}},
                  { # "P\@R0" =>  { STATUS => "NotDefined"} ,
                    "P\@R20" => { STATUS => "Computed", MEASURE => { "P\@R20" => 1 } },
                    "P\@R60" => { STATUS => "Computed", MEASURE => { "P\@R60" => 0.5 } } }
                  );
    _testOneBlock("Full system coverage of trials, unsorted trials case 1", $trial2, $trial2Pts, 
                  { AP => 0.62222, APP => 0.336341704},
                  { OPTIMUMCOMB  => { COMB => 0.6666, MMISS => 0.6667, MFA => 0.0, DETECTIONSCORE => undef},
                    SUPREMUMCOMB => { COMB => 0,      MMISS => 0.0, MFA => 0.0, DETECTIONSCORE => undef}},
                  { "she" => {OPTIMUMCOMB  => { COMB => 0.6667, MMISS => 0.6667, MFA => 0, DETECTIONSCORE => 1},
                              SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}}});
    _testOneBlock("Full system coverage of trials, unsorted trials case 2", $trial3, $trial3Pts, 
                  { AP => 0.62222, APP => 0.336341704},
                  { OPTIMUMCOMB  => { COMB => 0.6666, MMISS => 0.6667, MFA => 0.0, DETECTIONSCORE => undef},
                    SUPREMUMCOMB => { COMB => 0,      MMISS => 0.0, MFA => 0.0, DETECTIONSCORE => undef}},
                  { "she" => {OPTIMUMCOMB  => { COMB => 0.6667, MMISS => 0.6667, MFA => 0, DETECTIONSCORE => 1},
                              SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}}});
    _testOneBlock("Full system coverage of trials, Optimum internal", $trial4, $trial4Pts, 
                  { AP => 0.862637, APP => 0.572757},
                  { OPTIMUMCOMB  => { COMB => 0.429, MMISS => 0.429, MFA => 0.0, DETECTIONSCORE => undef},
                    SUPREMUMCOMB => { COMB => 0,     MMISS => 0.0, MFA => 0.0, DETECTIONSCORE => undef}},
                  { "she" => {OPTIMUMCOMB  => { COMB => 0.429, MMISS => 0.429, MFA => 0, DETECTIONSCORE => 0.860},
                              SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}}});
    _testOneBlock("Omitted Trials", $trialOmitted, $trialOmittedPts, 
                  { AP => 0.281666, APP => 0.1005993},
                  { OPTIMUMCOMB  => { COMB => 0.9, MMISS => 0.9, MFA => 0.0, DETECTIONSCORE => undef},
                    SUPREMUMCOMB => { COMB => 0.5, MMISS => 0.5, MFA => 0.0, DETECTIONSCORE => undef}},
                  { "she" => {OPTIMUMCOMB  => { COMB => 0.9, MMISS => 0.9, MFA => 0, DETECTIONSCORE => 1},
                              SUPREMUMCOMB => { COMB => 0.5, MMISS => 0.5, MFA => 0.0, DETECTIONSCORE => 0.5}}});
    _testOneBlock("No System output", $trialNoSystem, $trialNoSystemPts, 
                  { AP => 0, APP => undef},
                  { OPTIMUMCOMB  => { COMB => undef, MMISS => undef, MFA => undef, DETECTIONSCORE => undef},
                    SUPREMUMCOMB => { COMB => undef, MMISS => undef, MFA => undef, DETECTIONSCORE => undef}},
                  { "she" => {OPTIMUMCOMB  => undef,
                              SUPREMUMCOMB => undef }});
    _testOneBlock("Only system false alarms", $trialOnlyFASystem, $trialOnlyFASystemPts, 
                  { AP => 0, APP => 0},
                  { OPTIMUMCOMB  => { COMB => 10.9, MMISS => 1.0, MFA => 1.0, DETECTIONSCORE => undef},
                    SUPREMUMCOMB => { COMB => 1.0,  MMISS => 1.0, MFA => 0.0, DETECTIONSCORE => undef}},
                  { "she" => {OPTIMUMCOMB  => { COMB => 10.9, MMISS => 1, MFA => 1, DETECTIONSCORE => 0.1},
                              SUPREMUMCOMB => { COMB => 1,    MMISS => 1, MFA => 0, DETECTIONSCORE => 0.5}}});
                    

 
  print "Computing Mean Average Precision\n";
  my $mbTrial = new TrialsFuncs({ () }, "Term Detection", "Term", "Occurrence");
  $mbTrial->setPreserveTrialID(1);
  my $blkNum = 1;
  foreach my $_tr($trial, $trial2, $trial3, $trial4, $trialOmitted, $trialNoSystem, $trialOnlyFASystem){
#  foreach my $_tr($trial, $trial2, $trial3, $trial4){
#  foreach my $_tr($trial, $trial2, $trial3, $trial4, ){
    my @blocks = $_tr->getBlockIDs();
    my $ranks = $_tr->getRanks($blocks[0]);
    #   print Dumper($ranks);
    foreach my $rankData(@$ranks){
      $mbTrial->addTrial("blk-$blkNum", $rankData->[1], ($rankData->[1] > .23 ? "YES" : "NO"), $rankData->[2],
        undef, (defined($rankData->[3]) ? $rankData->[3] : undef));
    }
    for (my $_m = 0; $_m < $_tr->getNumOmittedTarg($blocks[0]); $_m++){
      $mbTrial->addTrial("blk-$blkNum", undef, "OMITTED", 1, undef, undef);
    }
    $blkNum++;
  }
  ### Add an empty block
  $mbTrial->addEmptyBlock("blk-empty");
  my $mbTrialPts =  
          [ [ ( 0.040,  0.357,  1.000, 10.257,  0.476,  0.000, undef,  7.000 ) ],
            [ ( 0.050,  0.400,  1.000, 10.300,  0.462,  0.000, undef,  7.000 ) ],
            [ ( 0.100,  0.400,  0.978, 10.080,  0.462,  0.034, undef,  7.000 ) ],
            [ ( 0.150,  0.400,  0.744,  7.770,  0.462,  0.387, undef,  7.000 ) ],
            [ ( 0.170,  0.495,  0.701,  7.439,  0.388,  0.375, undef,  7.000 ) ],
            [ ( 0.200,  0.495,  0.631,  6.738,  0.388,  0.340, undef,  7.000 ) ],
            [ ( 0.250,  0.516,  0.581,  6.263,  0.361,  0.316, undef,  7.000 ) ],
            [ ( 0.650,  0.516,  0.510,  5.562,  0.361,  0.280, undef,  7.000 ) ],
            [ ( 0.690,  0.516,  0.439,  4.861,  0.361,  0.246, undef,  7.000 ) ],
            [ ( 0.700,  0.559,  0.390,  4.422,  0.344,  0.213, undef,  7.000 ) ],
            [ ( 0.710,  0.579,  0.290,  3.453,  0.318,  0.158, undef,  7.000 ) ],
            [ ( 0.730,  0.579,  0.269,  3.246,  0.318,  0.153, undef,  7.000 ) ],
            [ ( 0.750,  0.579,  0.199,  2.545,  0.318,  0.127, undef,  7.000 ) ],
            [ ( 0.800,  0.642,  0.171,  2.333,  0.294,  0.095, undef,  7.000 ) ],
            [ ( 0.850,  0.642,  0.150,  2.127,  0.294,  0.118, undef,  7.000 ) ],
            [ ( 0.860,  0.642,  0.114,  1.770,  0.294,  0.098, undef,  7.000 ) ],
            [ ( 0.900,  0.663,  0.114,  1.790,  0.282,  0.098, undef,  7.000 ) ],
            [ ( 0.920,  0.683,  0.078,  1.453,  0.279,  0.092, undef,  7.000 ) ],
            [ ( 0.980,  0.841,  0.036,  1.199,  0.140,  0.040, undef,  7.000 ) ],
            [ ( 1.000,  0.841,  0.000,  0.841,  0.140,  0.000, undef,  7.000 ) ] ];
  if ($^V ge 5.18.0) { # results with new hash algorithm introduced in Perl 5.18
    ($report, $blockReport) =
      _testOneBlock
      ("Combined Block DET", $mbTrial, $mbTrialPts, 
       { MAP => 0.4217259, MAPP => 0.258063},
       { OPTIMUMCOMB  => { COMB => 0.8555, MMISS => 0.8555, MFA => 0.0, DETECTIONSCORE => undef},
	 SUPREMUMCOMB => { COMB => 0.3571, MMISS => 0.3571, MFA => 0.0, DETECTIONSCORE => undef}},
       { "blk-1"=>{OPTIMUMCOMB  => undef,
		   SUPREMUMCOMB => { COMB => 0.0, MMISS => 0.0, MFA => 0.0, DETECTIONSCORE => 0.5}},
	 "blk-2"=>{OPTIMUMCOMB  => undef,
		   SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}},
	 "blk-3"=>{OPTIMUMCOMB  => { COMB => 0.6667, MMISS => 0.6667, MFA => 0, DETECTIONSCORE => 1},
		   SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}},
	 "blk-4"=>{OPTIMUMCOMB  => undef,
		   SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}},
	 "blk-5"=>{OPTIMUMCOMB  => { COMB => 0.9, MMISS => 0.9, MFA => 0, DETECTIONSCORE => 1},
		   SUPREMUMCOMB => { COMB => 0.5, MMISS => 0.5, MFA => 0.0, DETECTIONSCORE => 0.5}},
	 "blk-6"=>{OPTIMUMCOMB  => undef,
		   SUPREMUMCOMB => undef },
	 "blk-7"=>{OPTIMUMCOMB  => { COMB => 1,    MMISS => 1, MFA => 0, DETECTIONSCORE => 0.15},
		   SUPREMUMCOMB => { COMB => 1,    MMISS => 1, MFA => 0, DETECTIONSCORE => 0.5}}
       }
      );
  } else {

    ($report, $blockReport) =
      _testOneBlock("Combined Block DET", $mbTrial, $mbTrialPts, 
		    { MAP => 0.4217259, MAPP => 0.258063},
		    { OPTIMUMCOMB  => { COMB => 0.7437, MMISS => 0.744, MFA => 0.0, DETECTIONSCORE => undef},
		      SUPREMUMCOMB => { COMB => 0.3571, MMISS => 0.3571, MFA => 0.0, DETECTIONSCORE => undef}},
		    { "blk-1"=>{OPTIMUMCOMB  => { COMB => 0.8, MMISS => 0.8, MFA => 0, DETECTIONSCORE => 1},
				SUPREMUMCOMB => { COMB => 0.0, MMISS => 0.0, MFA => 0.0, DETECTIONSCORE => 0.5}},
		      "blk-2"=>{OPTIMUMCOMB  => { COMB => 0.6667, MMISS => 0.6667, MFA => 0, DETECTIONSCORE => 1},
				SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}},
		      "blk-3"=>{OPTIMUMCOMB  => { COMB => 0.6667, MMISS => 0.6667, MFA => 0, DETECTIONSCORE => 1},
				SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}},
		      "blk-4"=>{OPTIMUMCOMB  => { COMB => 0.429, MMISS => 0.429, MFA => 0, DETECTIONSCORE => 0.860},
				SUPREMUMCOMB => { COMB => 0,      MMISS => 0,      MFA => 0, DETECTIONSCORE => 0.5}},
		      "blk-5"=>{OPTIMUMCOMB  => { COMB => 0.9, MMISS => 0.9, MFA => 0, DETECTIONSCORE => 1},
				SUPREMUMCOMB => { COMB => 0.5, MMISS => 0.5, MFA => 0.0, DETECTIONSCORE => 0.5}},
		      "blk-6"=>{OPTIMUMCOMB  => undef,
				SUPREMUMCOMB => undef },
		      "blk-7"=>{OPTIMUMCOMB  => { COMB => 1,    MMISS => 1, MFA => 0, DETECTIONSCORE => 0.15},
				# Things change in the context of other blocks because this can now go to FA=1
				#{ COMB => 10.9, MMISS => 1, MFA => 1, DETECTIONSCORE => 0.1}
				SUPREMUMCOMB => { COMB => 1,    MMISS => 1, MFA => 0, DETECTIONSCORE => 0.5}}
		    }
		    
		   );
  }
  #print $report;
  #print $blockReport;
  
}

sub bigDETUnitTest {
  printf("Running a series of large DET Curves\n");
  my ($doProfile) = 0;
  
 foreach my $size(1000){
#  foreach my $size(2000000, 5000000, 10000000){
#  foreach my $size(1000003){
   if (0){
     system "/home/fiscus/Projects/STD/STDEval/tools/ProcGragh/ProcGraph.pl --cumul --Tree --outdir /tmp --filebase BigDet.$size -- ".
          " perl ".($doProfile ? "-d:DProf" : "")." -I . -e 'use DETCurve; DETCurve::oneBigDET(\"/tmp/BigDet.$size\", $size)'"; 
   } elsif (0) {
     system " perl ".($doProfile ? "-d:DProf" : "")." -I . -e 'use DETCurve; DETCurve::oneBigDET(\"/tmp/BigDet.$size\", $size, \"UniqThreshold\")'"; 
   } else {
#     DETCurve::oneBigDET("/tmp/BigDet.$size", $size/10, $size, 100, "Articulated"); #"UniqThreshold"); 
     DETCurve::oneBigDET("/tmp/BigDet.$size", $size, $size, 2, "UniqThreshold"); 
   }
   print "\n";
  }
}

sub oneBigDET
  {
   my ($root, $nt, $nnt, $numblk, $style) = @_;

    print " Computing big DET Curve... ".($nt)." trials\n";
    use Math::Random::OO::Uniform;
    my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );  
    my $rand = Math::Random::OO::Normal->new(0,1);

    
    #####################################  Without data  ###############################    
#     my $emptyTrial = new TrialsFuncs({ ("TOTALTRIALS" => $nt + $nnt) },
#                                     "Term Detection", "Term", "Occurrence");
    my $emptyTrial = new TrialsTWV({ ("TotDur" => ($nt + $nnt)*100, TrialsPerSecond => 1, 
                                      IncludeBlocksWithNoTargets => 1) },
                                     "Term Detection", "Term", "Occurrence");

    print "   ... adding trials\n";
    my $tot = 0;
    for (my $blk=0; $blk<$numblk; $blk++){
     
      for (my $i=0; $i<$nt*9/10; $i++){
        my $r = $rand->next() + 2 + ($blk * 1);
        $emptyTrial->addTrial("he$blk", $r, ($r < 0.0 ? "NO" : "YES"), 1);
        $tot++;
        print "   Block $blk Made trials < $tot\n" if ($tot % 10000 == 0); 
      }
      for (my $i=0; $i<$nt/10; $i++){
        $emptyTrial->addTrial("he$blk", undef, "OMITTED", 1);
        $tot++;
        print "   Block $blk Made trials < $tot\n" if ($tot % 10000 == 0); 
      }
      for (my $i=0; $i<$nnt; $i++){
        my $r = $rand->next() - 2 + ($blk * 1);
        $emptyTrial->addTrial("he$blk", $r, ($r < 0.0 ? "NO" : "YES"), 0);
        $tot++;
        print "   Block $blk Made trials < $tot\n" if ($tot % 10000 == 0); 
      }
    }
#    print $emptyTrial->dump();
#    my $met = new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $emptyTrial);
    my $met = new MetricTWV({ ('Cost' => 0.1, 'Value' => 1, 'Ptarg' => 0.0001 ) }, $emptyTrial);
    if (ref($met) ne "MetricTWV") {
      die "Error: Unable to create a MetricTestStub object with message '$met'\n";
    }
    $met->setPerformGlobalMeasure("MAP", "true");

    my $emptydet = new DETCurve($emptyTrial, $met, "footitle", \@isolinecoef, undef);
    $emptydet->setCurveStyle($style);
    use DETCurveSet;
    my $ds = new DETCurveSet("title");
    $ds->addDET("Biggy", $emptydet);
#    my %ht = ("createDETfiles", 1, "serialize", 0);
    my $options = {"yScale" => "nd", "xScale" => "nd",
                   "Xmin" => 0.0001, "Xmax" => 99.9, "Ymin" => 0.001, "Ymax" => 99.9,
                   "DETShowPoint_Ratios" => 1,
                   "DETShowPoint_Best" => 1,
                   "DETShowPoint_Actual" => 1,
                   "DETShowPoint_Optimum" => 1,
                   "DETShowPoint_Supremum" => 1,
                   "ReportGlobal" => 1,
                   #"ReportIsoRatios" => 1,
                   "ReportOptimum" => 1,
                   "ReportSupremum" => 1,
                   "DrawIsometriclines" => 1, "Isometriclines" => [(.8, .6, .4)],
                   "DrawIsoratiolines" => 1,  "Isoratiolines" => [ (5, 40, 80) ],
                   "DETLineAttr" => { ("Art DET1" => { label => "New DET1", lineWidth => 1, pointSize => 2, pointTypeSet => "circle", color => "rgb \"#ff00ff\"" },
                                       "Art DET2" => { label => "New DET2", lineWidth => 1, pointSize => 3, pointTypeSet => "circle", color => "rgb \"#00ff00\"" },
                                       "Normal 2" => { label => "Norm 2", lineWidth => 1, pointSize => 1, pointTypeSet => "square", color => "rgb \"#0000ff\"" },
                                       "Normal 1" =>   { label => "Norm 1", lineWidth => 1, pointSize => 1, pointTypeSet => "circle", color => "rgb \"#222222\"" })}};
    my $dcRend = new DETCurveGnuplotRenderer($options)  ;
    $dcRend->writeMultiDetGraph("BIGDET",  $ds);
    $ds->renderReport(".", 0, $options, "-", undef, undef, ":utf8"); 
    $ds->renderBlockedReport(0, "-", undef, undef, ":utf8", $options); 

}

sub blockWeightedUnitTest()
  {
    print " Computing blocked curve without data...";
    my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
    
    #####################################  Without data  ###############################    
    my $emptyTrial = new TrialsFuncs({ ("TOTALTRIALS" => 100) },
                                    "Term Detection", "Term", "Occurrence");

    $emptyTrial->addTrial("he", undef, "OMITTED", 1);
    $emptyTrial->addTrial("he", undef, "OMITTED", 1);
    $emptyTrial->addTrial("he", undef, "OMITTED", 1);
    $emptyTrial->addTrial("she", undef, "OMITTED", 1);
    $emptyTrial->addTrial("she", undef, "OMITTED", 1);
    $emptyTrial->addTrial("she", undef, "OMITTED", 1);

    my $met = new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $emptyTrial);
    if (ref($met) ne "MetricTestStub") {
      die "Error: Unable to create a MetricTestStub object with message '$met'\n";
    }
    my $emptydet = new DETCurve($emptyTrial, $met, "footitle", \@isolinecoef, undef);
    die "Error: Empty det should be successful()" if (! $emptydet->successful());
    die "Error: Empty det have value 0" if ($emptydet->getBestCombComb() != 0);
    die "Error: Empty det have Pmiss == 1" if ($emptydet->getBestCombMMiss() <=  1 - 0.000001);
    die "Error: Empty det have PFa   == 0" if ($emptydet->getBestCombMFA() > 0 + 0.0000001);
#    $emptydet->writeGNUGraph("foo", {()});

    print "  OK\n";

    #####################################  With data  ###############################    
    print " Computing blocked curve with data...";
    my $trial = new TrialsFuncs({ ("TOTALTRIALS" => 10) },
                               "Term Detection", "Term", "Occurrence");

    $trial->addTrial("she", 0.1, "NO", 0);
    $trial->addTrial("she", 0.2, "NO", 0);
    $trial->addTrial("she", 0.3, "NO", 1);
    $trial->addTrial("she", 0.4, "NO", 0);
    $trial->addTrial("she", 0.5, "NO", 0);
    $trial->addTrial("she", 0.6, "NO", 0);
    $trial->addTrial("she", 0.7, "NO", 1);
    $trial->addTrial("she", 0.8, "YES", 0);
    $trial->addTrial("she", 0.9, "YES", 1);
    $trial->addTrial("she", 1.0, "YES", 1);

    $trial->addTrial("he", 0.41, "NO", 1);
    $trial->addTrial("he", 0.51, "YES", 0);
    $trial->addTrial("he", 0.61, "YES", 0);
    $trial->addTrial("he", 0.7, "YES", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);

    $trial->addTrial("skip", 0.41, "NO", 0);
    $trial->addTrial("skip", 0.51, "YES", 0);
    $trial->addTrial("skip", 0.61, "YES", 0);
    $trial->addTrial("skip", 0.7, "YES", 0);

    $trial->addTrial("notskip", 0.41, "NO", 0);
    $trial->addTrial("notskip", 0.51, "YES", 0);
    $trial->addTrial("notskip", 0.61, "YES", 0);
    $trial->addTrial("notskip", 0.7, "YES", 0);
    $trial->addTrial("notskip", undef, "OMITTED", 1);
    $trial->addTrial("notskip", undef, "OMITTED", 1);

    my $blockdetOrig = new DETCurve($trial, 
                                    new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
                                    "footitle", \@isolinecoef, "gzip");
    $blockdetOrig->computePoints();
    print "  OK\n";
    print " Serializing to a file...";
    my $sroot = "/tmp/serialize";
    $blockdetOrig->serialize($sroot);
    my $blockdetSrl = DETCurve::readFromFile("$sroot.gz", "gzip");
    print "  OK\n";
    if (unlink("$sroot.gz") != 1) {
      print "!!!!Warning: Serialization tests passed but file removal of '$sroot.gz' failed\n";
    }
    my $blockdet = $blockdetSrl;

    ## This was built from DETtesting-v2 with MissingTarg=0, MissingNonTarg=0
    #    
    #               Thr    Pmiss  Pfa    TWval     SSDPmiss, SSDPfa, SSDValue, #blocks
    my @points = [  (0.1,  0.500, 0.611, -610.550, 0.500,    0.347,  346.550,   3) ];
    push @points, [ (0.2,  0.500, 0.556, -555.000, 0.500,    0.255,  254.235,   3) ];
    push @points, [ (0.3,  0.500, 0.500, -499.450, 0.500,    0.167,  166.401,   3) ];
    push @points, [ (0.4,  0.583, 0.500, -499.533, 0.382,    0.167,  166.525,   3) ];
    push @points, [ (0.41, 0.583, 0.444, -443.983, 0.382,    0.096,   96.288,   3) ];
    push @points, [ (0.5,  0.667, 0.403, -402.404, 0.382,    0.087,   86.407,   3) ];
    push @points, [ (0.51, 0.667, 0.347, -346.854, 0.382,    0.024,   24.344,   3) ];
    push @points, [ (0.6,  0.667, 0.250, -249.642, 0.382,    0.083,   83.076,   3) ];
    push @points, [ (0.61, 0.667, 0.194, -194.092, 0.382,    0.048,   48.397,   3) ];
    push @points, [ (0.7,  0.667, 0.097,  -96.879, 0.382,    0.087,   86.568,   3) ];
    push @points, [ (0.8,  0.833, 0.056,  -55.383, 0.289,    0.096,   95.927,   3) ];
    push @points, [ (0.9,  0.833, 0.000,    0.167, 0.289,    0.000,    0.289,   3) ];
    push @points, [ (1.0,  0.917, 0.000,    0.083, 0.144,    0.000,    0.144,   3) ];

    my $ret = $blockdet->testGeneratedPoints(\@points, "  ");
    die $ret if ($ret ne "ok");
    print "  OK\n";
    
    print " Checking MMiss for fixed MFA...";
    my $MMissPnts = $blockdet->computeMMissForFixedMFA([(.03, .08, .5, .6, .7, .9)]);
    die "Error: Computation of MMiss for fixed MFA failed for id 1" if (abs($MMissPnts->[0]{InterpMMiss} - 0.8333) >= 0.0001);
    die "Error: Computation of MMiss for fixed MFA failed for id 2" if (abs($MMissPnts->[1]{InterpMMiss} - 0.7355) >= 0.0001);
    die "Error: Computation of MMiss for fixed MFA failed for id 3" if (abs($MMissPnts->[2]{InterpMMiss} - 0.5416) >= 0.0001);
    die "Error: Computation of MMiss for fixed MFA failed for id 4" if (abs($MMissPnts->[3]{InterpMMiss} - 0.5000) >= 0.0001);
    die "Error: Computation of MMiss for fixed MFA failed for id 5" if (abs($MMissPnts->[4]{InterpMMiss} - 0.4272) >= 0.0001);
    die "Error: Computation of MMiss for fixed MFA failed for id 6" if (abs($MMissPnts->[5]{InterpMMiss} - 0.2636) >= 0.0001);
    ##
    die "Error: Computation of Score for fixed MFA failed for id 1" if (abs($MMissPnts->[0]{InterpScore} - 0.8460) >= 0.0001);
    die "Error: Computation of Score for fixed MFA failed for id 2" if (abs($MMissPnts->[1]{InterpScore} - 0.7413) >= 0.0001);
    die "Error: Computation of Score for fixed MFA failed for id 3" if (abs($MMissPnts->[2]{InterpScore} - 0.3500) >= 0.0001);
    die "Error: Computation of Score for fixed MFA failed for id 4" if (abs($MMissPnts->[3]{InterpScore} - 0.1200) >= 0.0001);
    die "Error: Computation of Score for fixed MFA failed for id 5" if (abs($MMissPnts->[4]{InterpScore} - 0.1000) >= 0.0001);
    die "Error: Computation of Score for fixed MFA failed for id 6" if (abs($MMissPnts->[5]{InterpScore} - 0.1000) >= 0.0001);
    print "  OK\n";

    
    print " Checking Area...";
    $blockdet->computeArea();
    print "  OK\n";
}

sub articulatedDetUnitTest{
    use DETCurveSet;
    use DETCurveGnuplotRenderer;

    my $ds = new DETCurveSet("title");

    my $trial = new TrialsFuncs({ ("TOTALTRIALS" => 10) },
                               "Term Detection", "Term", "Occurrence");

    $trial->addTrial("she", 0.1, "NO", 0);
    $trial->addTrial("she", 0.2, "NO", 0);
    $trial->addTrial("she", 0.3, "NO", 1);
    $trial->addTrial("she", 0.4, "NO", 0);
    $trial->addTrial("she", 0.5, "NO", 0);
    $trial->addTrial("she", 0.6, "NO", 0);
    $trial->addTrial("she", 0.7, "NO", 1);
    $trial->addTrial("she", 0.8, "YES", 0);
    $trial->addTrial("she", 0.9, "YES", 1);
    $trial->addTrial("she", 1.0, "YES", 1);

    $trial->addTrial("he", 0.41, "NO", 1);
    $trial->addTrial("he", 0.51, "YES", 0);
    $trial->addTrial("he", 0.61, "YES", 0);
    $trial->addTrial("he", 0.7, "YES", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);

    $trial->addTrial("skip", 0.41, "NO", 0);
    $trial->addTrial("skip", 0.51, "YES", 0);
    $trial->addTrial("skip", 0.61, "YES", 0);
    $trial->addTrial("skip", 0.7, "YES", 0);

    $trial->addTrial("notskip", 0.41, "NO", 0);
    $trial->addTrial("notskip", 0.51, "YES", 0);
    $trial->addTrial("notskip", 0.61, "YES", 0);
    $trial->addTrial("notskip", 0.7, "YES", 0);
    $trial->addTrial("notskip", undef, "OMITTED", 1);
    $trial->addTrial("notskip", undef, "OMITTED", 1);

##################  Testing the reduces block with the previous test data

    print " Checking Articulated DET with sample data ...\n";
    ## This was built from DETtesting-v2 with MissingTarg=0, MissingNonTarg=0
    #    
    #               Thr    Pmiss  Pfa    TWval     SSDPmiss, SSDPfa, SSDValue, #blocks
    my @points = [  (0.1,  0.500, 0.611, -610.550, 0.500,    0.347,  346.550,   3) ];
#    push @points, [ (0.2,  0.500, 0.556, -555.000, 0.500,    0.255,  254.235,   3) ];
    push @points, [ (0.3,  0.500, 0.500, -499.450, 0.500,    0.167,  166.401,   3) ];
#    push @points, [ (0.4,  0.583, 0.500, -499.533, 0.382,    0.167,  166.525,   3) ];
    push @points, [ (0.41, 0.583, 0.444, -443.983, 0.382,    0.096,   96.288,   3) ];
#    push @points, [ (0.5,  0.667, 0.403, -402.404, 0.382,    0.087,   86.407,   3) ];
#    push @points, [ (0.51, 0.667, 0.347, -346.854, 0.382,    0.024,   24.344,   3) ];
#    push @points, [ (0.6,  0.667, 0.250, -249.642, 0.382,    0.083,   83.076,   3) ];
#    push @points, [ (0.61, 0.667, 0.194, -194.092, 0.382,    0.048,   48.397,   3) ];
    push @points, [ (0.7,  0.667, 0.097,  -96.879, 0.382,    0.087,   86.568,   3) ];
#    push @points, [ (0.8,  0.833, 0.056,  -55.383, 0.289,    0.096,   95.927,   3) ];
    push @points, [ (0.9,  0.833, 0.000,    0.167, 0.289,    0.000,    0.289,   3) ];
    push @points, [ (1.0,  0.917, 0.000,    0.083, 0.144,    0.000,    0.144,   3) ];

    my $artBaseDet = new DETCurve($trial, 
                                  new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
                                  "Art Base", [()], "gzip");
    $artBaseDet->setCurveStyle("Articulated");

    my $reducedDet = new DETCurve($trial, 
                                  new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
                                  "Norm Base", [()], "gzip");
    $reducedDet->setCurveStyle("UniqThreshold");
#    $reducedDet->computePoints();
#    $artBaseDet->computePoints();
#    my $ret = $reducedDet->testGeneratedPoints(\@points, "  ");
#    die $ret if ($ret ne "ok");
#    $ds->addDET("Art Base", $artBaseDet);
#    $ds->addDET("Normal Base", $reducedDet);
    print "  OK\n";
    
    print " Checking Detailed Articulated DET ...\n";
    
    #####################################  With data  ###############################    
    
    my $artTrial = new TrialsFuncs({ ("TOTALTRIALS" => 60) },
                               "Term Detection", "Term", "Occurrence");
    ### 10 targets the range 0.1 - 1
    $artTrial->addTrial("she", 0.1, "NO", 1);
    $artTrial->addTrial("she", 0.2, "NO", 1);
    $artTrial->addTrial("she", 0.3, "NO", 1);
    $artTrial->addTrial("she", 0.4, "NO", 1);
    $artTrial->addTrial("she", 0.5, "NO", 1);
    $artTrial->addTrial("she", 0.6, "YES", 1);
    $artTrial->addTrial("she", 0.8997, "YES", 1);
    $artTrial->addTrial("she", 0.8998, "YES", 1);
    $artTrial->addTrial("she", 0.8999, "YES", 1);
    $artTrial->addTrial("she", 1.0, "YES", 1);
    my $scr = 0;
    ## case 1;  11 NT
    for (my $i=0, my $st=0.1; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.2; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.2; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.4; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.5; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.6; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.7; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.8; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.9; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=1.0; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }

    my $artDet = new DETCurve($artTrial, 
                              new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $artTrial),
                              "artDet", [ (.35, .7, .98, 1.9, 40, 99) ], "gzip");
    $artDet->setCurveStyle("Articulated");

    my $uniqThrDet = new DETCurve($artTrial, 
                                  new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $artTrial),
                                  "UnigThr", [ (.35, .7, .98, 1.9, 40, 99) ], "gzip");
    $artDet->computePoints();
    $uniqThrDet->computePoints();
    $ds->addDET("Art DET1", $artDet);
    $ds->addDET("Normal 1", $uniqThrDet);
    
#######
    my $artTrial2 = new TrialsFuncs({ ("TOTALTRIALS" => 60) },
                               "Term Detection", "Term", "Occurrence");
    ### 10 targets the range 0.1 - 1
    $artTrial2->addTrial("she", 0.2, "NO", 1);
    $artTrial2->addTrial("she", 0.4, "NO", 1);
    $artTrial2->addTrial("she", 0.4, "NO", 1);
    $artTrial2->addTrial("she", 0.4, "NO", 1);
    $artTrial2->addTrial("she", 0.74, "NO", 1);
    $artTrial2->addTrial("she", 0.78, "YES", 1);
    $artTrial2->addTrial("she", 0.8, "YES", 1);
    $artTrial2->addTrial("she", 0.84, "YES", 1);
    $artTrial2->addTrial("she", 0.8, "YES", 1);
    $artTrial2->addTrial("she", 0.9, "YES", 1);
    my $scr = 0;
    ## case 1;  11 NT
    for (my $i=0, my $st=0.1; $i<13; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.2; $i<9; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.2; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.4; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.5; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.6; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.7; $i<5; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.8; $i<1; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=0.9; $i<1; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }
    for (my $i=0, my $st=1.0; $i<1; $i++){ $scr = $st + $i * 0.02; $artTrial2->addTrial("she", $scr, $scr < 55 ? "NO" : "YES", 0); }

    my $artDet2 = new DETCurve($artTrial2, 
                              new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $artTrial2),
                              "artDET2", [ (.35, .7, .98, 1.28, 40, 99) ], "gzip");
    $artDet2->setCurveStyle("Articulated");

    my $uniqThrDet2 = new DETCurve($artTrial2, 
                                  new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $artTrial2),
                                  "uniqThr2", [ (.35, .7, .98, 1.9, 40, 99) ], "gzip");
#    $artDet2->computePoints();
#    $uniqThrDet2->computePoints();
#    $ds->addDET("Art DET2", $artDet2);
#    $ds->addDET("Normal 2", $uniqThrDet2);
#######
    my $dcRend = new DETCurveGnuplotRenderer(
      {"yScale" => "linear", "xScale" => "linear",
       "CurveLineStyle" => "linespoints", 
       "Xmin" => 0, "Xmax" => 100, "Ymin" => 0, "Ymax" => 100,
       "DETShowPoint_Ratios" => 0,
       "DrawIsoratiolines" => 1, "Isoratiolines" => [ (.35, .7, .98, 1.9, 40, 99) ],
       "DETLineAttr" => { ("Art Base" => { lineWidth => 1, pointSize => 2, pointTypeSet => "circle", color => "rgb \"#00ff00\"" },
                           "Art DET1" => { lineWidth => 1, pointSize => 2, pointTypeSet => "circle", color => "rgb \"#00ff\"" },
                           "Art DET2" => { lineWidth => 1, pointSize => 3, pointTypeSet => "circle", color => "rgb \"#ff0000\"" },
                           "Normal Base" => { lineWidth => 1, pointSize => 1, pointTypeSet => "square", color => "rgb \"#222222\"" },
                           "Normal 2" => { lineWidth => 1, pointSize => 1, pointTypeSet => "square", color => "rgb \"#222222\"" },
                           "Normal 1" => { lineWidth => 1, pointSize => 1, pointTypeSet => "circle", color => "rgb \"#222222\"" })}})  ;
    $dcRend->writeMultiDetGraph("ARTDET",  $ds);
exit;
    print " Checking Articulated DET with sample data ...\n";
    ## This was built from DETtesting-v2 with MissingTarg=0, MissingNonTarg=0
    #    
    #               Thr    Pmiss  Pfa    TWval     SSDPmiss, SSDPfa, SSDValue, #blocks
    my @points = [  (0.1,  0.500, 0.611, -610.550, 0.500,    0.347,  346.550,   3) ];
    my $ret = $artDet->testGeneratedPoints(\@points, "  ");
    die $ret if ($ret ne "ok");
    print "  OK\n";
}

### This method compares a "100% correct" 2-dim table of point to the calculated points
sub testGeneratedPoints{
  my ($self, $points, $pre) = @_;
  my ($compPoints) = $self->getPoints();
  my $errors = 0;
  my $msg = "";
  
  if (0){ 
    for (my $i=0; $i<@$compPoints; $i++) {
      print "$i=";
      for (my $j=0; $j<@{ $compPoints->[$i] }; $j++) {
        printf(", %.3f",$compPoints->[$i][$j]);
      }
      print "\n";
    }
  }
  print "${pre}Checking the number of points...";
  if (@$points != @$compPoints){
    $msg .= "Error: Number of computed DET points not correct.  Expected ".scalar(@$points)." != ".scalar(@$compPoints)."\n" ;
    $errors++;
    print "  Failed\n";
  } else {
    print "  Ok\n";
  }
  print "${pre}Checking points...";
  my $ptErr = 0;
  my $ptMsg = "";
  for (my $i=0; $i<@$points; $i++) {
    $ptErr = 0;
    $ptMsg = "";
    for (my $value=0; $value < 8; $value++){
      if (thisabs($points->[$i][$value] - sprintf("%.3f",$compPoints->[$i][$value])) > 0.00){
         $ptMsg .= "$value,";
         $ptErr ++;
      }
    }
    if ($ptErr > 0){
      $msg .= "Error: Det isn't correct for point $i values ($ptMsg) failed:\n   expected '".join(",",@{$points->[$i]})."'\n".
              "        got '".join(",",@{$compPoints->[$i]})."'";
      $errors++;          
      last;
    }
  }    
  return ($errors > 0) ? $msg : "ok";
}


# Old serialize
#sub serialize2
#  {
#    my ($self, $file) = @_;
#    $self->{LAST_SERIALIZED_DET} = $file;
#    open (FILE, ">$file") || die "Error: Unable to open file '$file' to serialize STDDETSet to";
#    my $orig = $Data::Dumper::Indent; 
#    $Data::Dumper::Indent = 0;
#    
#    ### Purity controls how self referential objects are written;
#    my $origPurity = $Data::Dumper::Purity;
#    $Data::Dumper::Purity = 1;
#             
#    print FILE Dumper($self); 
#    
#    $Data::Dumper::Indent = $orig;
#    $Data::Dumper::Purity = $origPurity;
#    
#    close FILE;
#    system("$self->{GZIPPROG} -9 -f $file > /dev/null");
#  }

# Serialize avoiding creating temporary variables and arrays for POINTS 
# structure.
sub serialize
  {
    my ($self, $file, $separateIsoRatios) = @_;
    ### if not defined, don't separate the isoratios
    $separateIsoRatios = (! defined($separateIsoRatios)) ? 0 : $separateIsoRatios;
    
    $self->{LAST_SERIALIZED_DET} = $file;
    open (FILE, ">$file") || die "Error: Unable to open file '$file' to serialize DETCurve to";
    my $orig = $Data::Dumper::Indent; 
    $Data::Dumper::Indent = 0;
    
    ### Purity controls how self referential objects are written;
    my $origPurity = $Data::Dumper::Purity;
    $Data::Dumper::Purity = 1;
    
    my $p = $self->{'POINTS'};
    $self->{POINTS} = undef;
    
    my $t = $self->{'TRIALS'}{'trials'};
    $self->{'TRIALS'}{'trials'} = undef;

    my $_i = $self->{'ISOPOINTS'};
    $self->{'ISOPOINTS'} = undef if ($separateIsoRatios);

    print FILE Dumper($self);
    
    my $origTerse = $Data::Dumper::Terse;
    $Data::Dumper::Terse = 1;
	
	# TRIALS
	print FILE "\$VAR1->{'TRIALS'}{'trials'} = {";
    my $firstkey = 1;
    
    foreach my $k (keys %$t)
    {
    	print FILE "," if(!$firstkey);
		$firstkey = 0 unless(!$firstkey);
		print FILE "'"."$k"."' => {";
		
		my $firstkeyelt = 1;
		
		foreach my $e (keys %{ $t->{$k} })
		{
			print FILE "," if(!$firstkeyelt);
			$firstkeyelt = 0 unless(!$firstkeyelt);
			
			if($e =~ /^(TARG|NONTARG)$/)
			{				
				print FILE "'"."$e"."' => [";
				
				for(my $i=0; $i<scalar(@{ $t->{$k}{$e} }); $i++)
				{
					print FILE "," if($i>0);
					print FILE Dumper $t->{$k}{$e}->[$i];
				}
				
				print FILE "]";
			}
			else
			{
				print FILE "'"."$e"."' => ";
				print FILE Dumper $t->{$k}{$e};
			}
		}
		
		print FILE "}";
    }
    
    print FILE "};";
	
    # POINTS
    if ($self->{EVALSTRUCT}) {
        print FILE "\$VAR1->{'POINTS'} = [";
        
        for(my $i=0; $i<scalar(@$p); $i++)
    	{
    		print FILE "," if($i>0);

            print FILE "[";

    		for(my $j=0; $j<scalar(@{$p->[$i]}); $j++)
    		{
    			print FILE "," if($j>0);
    			print FILE Dumper $p->[$i][$j];
    			
    			#if(defined($p->[$i][$j]))
    			#{
    			#	print FILE "'"."$p->[$i][$j]"."'";
    			#}
    			#else
    			#{
    			#	print FILE "undef";
    			#}
    		}
    		
    		print FILE "]";
    	}
    	
        print FILE "];";
    } else {
        print FILE "\n";
        print FILE MMisc::marshal_matrix(@$p);
    }

    close FILE;
    system("$self->{GZIPPROG} -9 -f $file > /dev/null");

    $Data::Dumper::Indent = $orig;
    $Data::Dumper::Purity = $origPurity;
    $Data::Dumper::Terse = $origTerse;
   
    $self->{'POINTS'} = $p;
    $self->{'TRIALS'}{'trials'} = $t;
    $self->{'ISOPOINTS'} = $_i;

    my @co = sort {$a <=> $b} (keys %{ $self->{ISOPOINTS} });
    if (@co > 0 && $separateIsoRatios){
	my $coeff;
	my $sysRespStatFile = "$file.isoratio.SystemResponseStats.daf.tsv";
	my $blkRespStatFile = "$file.isoratio.BlockResponseStats.daf.tsv";
	print "Writing IsoRatio Stats to $sysRespStatFile - coeff(".join(",",@co).")\n";

	my $metStr = $self->{METRIC}->combLab();
	#######################################################################################
	open (ISOSYS, ">$sysRespStatFile") || die "Error: Unable to open file '$sysRespStatFile' for iso coefficients";
	print ISOSYS "sysID";	
	foreach $coeff (@co){ 
	    print ISOSYS "\tR${metStr}${coeff}_".$self->{METRIC}->combLab()."_c";
	    print ISOSYS "\tR${metStr}${coeff}_".$self->{METRIC}->errMissLab()."_c";
	    print ISOSYS "\tR${metStr}${coeff}_".$self->{METRIC}->errFALab()."_c";
	    print ISOSYS "\tR${metStr}${coeff}_"."Threshold_c";
	}
	print ISOSYS "\n";
        ###Data
	print ISOSYS "<SYSID>";
	foreach $coeff (@co){ 
	    print ISOSYS "\t".$self->{ISOPOINTS}{$coeff}{INTERPOLATED_COMB};
	    print ISOSYS "\t".$self->{ISOPOINTS}{$coeff}{INTERPOLATED_MMISS};
	    print ISOSYS "\t".$self->{ISOPOINTS}{$coeff}{INTERPOLATED_MFA};
	    print ISOSYS "\t".$self->{ISOPOINTS}{$coeff}{INTERPOLATED_DETECTSCORE};
	}
	print ISOSYS "\n";
	close ISOSYS;

	#######################################################################################
	open (ISOBLK, ">$blkRespStatFile") || die "Error: Unable to open file '$blkRespStatFile' for iso coefficients";
	print ISOBLK "sysID\tblockID";	
	my %blkIDs = ();
	foreach $coeff (@co){ 
	    print ISOBLK "\tR${metStr}${coeff}_".$self->{METRIC}->combLab()."_c";
	    print ISOBLK "\tR${metStr}${coeff}_".$self->{METRIC}->errMissLab()."_c";
	    print ISOBLK "\tR${metStr}${coeff}_".$self->{METRIC}->errFALab()."_c";
	    print ISOBLK "\tR${metStr}${coeff}_"."Threshold_c";
	    foreach my $b ( keys %{ $self->{ISOPOINTS}{$coeff}{BLOCKS} } ) {
		$blkIDs{$b} = 1;
	    }
	}
	print ISOBLK "\n";
	foreach my $b ( sort keys(%blkIDs) ) {
	    print ISOBLK "<SYSID>\t$b";
	    foreach $coeff (@co){ 
		print ISOBLK "\t".$self->{ISOPOINTS}{$coeff}{BLOCKS}{$b}{COMB};
		print ISOBLK "\t".$self->{ISOPOINTS}{$coeff}{BLOCKS}{$b}{MMISS};
		print ISOBLK "\t".$self->{ISOPOINTS}{$coeff}{BLOCKS}{$b}{MFA};
		print ISOBLK "\t".$self->{ISOPOINTS}{$coeff}{INTERPOLATED_DETECTSCORE};
	    }
	    print ISOBLK "\n";
	}

	close ISOBLK;
    }
  }

sub readFromFile
  {
    my ($file, $gzipPROG) = @_;
    my $str = "";
    my $tmpFile = undef;

    ### The following vars are used for the new-skool marshalling, sweet.
    my $marshal_str = "";
    my $binary = 0;
    my @arr = undef;
 
    my $err = MMisc::check_file_r($file);
    MMisc::error_quit("Unable to read srl file ($file): $err") if (! MMisc::is_blank($err));
 
    if ( ( $file =~ /.+\.gz$/ ) ) {
      $str = MMisc::file_gunzip($file)
    } else {
      $str = MMisc::slurp_file($file, "text")
    }

    ### Check to see if this sucker is a binary srl.
    if ($str =~ m/(begin\s+\d+\s+\d+.+)/s) {
      $binary = 1;
      $marshal_str = $1;
      $str =~ s/begin\s+\d+\s+\d+.+//s;
    }

    my $VAR1;
    eval $str;
    MMisc::error_quit("Problem in \'DETCurve.pm::readFromFile()\' eval-ing code : " . join(" | ", $@))
        if $@;

    ### If it's a binary we're going to have to parse it.
    if ($binary) {
      @arr = MMisc::unmarshal_matrix($marshal_str);
      $VAR1->{"POINTS"} = \@arr;
    }

    ### Chack for and correct backward compatability problems in the TrialsStructure
    $VAR1->getTrials()->fixBackwardCompatabilityProblems();
    

    $VAR1;
  }

sub isCompatible(){
  my ($self, $DET2) = @_;

  #Make sure the metric objects are the same
  return 0 if (! $self->{METRIC}->isCompatible($DET2->{METRIC}));
  return 0 if (! $self->{TRIALS}->isCompatible($DET2->{TRIALS}));
    
  return 1;    
}

sub successful
  {
    my ($self) = @_;
    $self->computePoints();
    defined($self->{POINTS});
  }

sub getMessages{
  my ($self) = @_;
  $self->{MESSAGES};
}

sub getBestCombDetectionScore{
  my $self = shift;
  $self->computePoints();
  $self->{BESTCOMB}{DETECTIONSCORE}
}

sub getBestCombComb{
  my $self = shift;
  $self->computePoints();
  $self->{BESTCOMB}{COMB}
}

sub getBestCombMMiss{
  my $self = shift;
  $self->computePoints();
  $self->{BESTCOMB}{MMISS}
}

sub getBestCombMFA{
  my $self = shift;
  $self->computePoints();
  $self->{BESTCOMB}{MFA}
}

sub getOptimumCombDetectionScore{
  my $self = shift;
  $self->computePoints();
  $self->{OPTIMUMCOMB}{DETECTIONSCORE}
}

sub getOptimumCombComb{
  my $self = shift;
  $self->computePoints();
  $self->{OPTIMUMCOMB}{COMB}
}

sub getOptimumCombMMiss{
  my $self = shift;
  $self->computePoints();
  $self->{OPTIMUMCOMB}{MMISS}
}

sub getOptimumCombMFA{
  my $self = shift;
  $self->computePoints();
  $self->{OPTIMUMCOMB}{MFA}
}

sub getOptimumCombDetectionScoreForBlock{
  my $self = shift;
  my $block = shift;
  $self->computePoints();
  $self->{OPTIMUMCOMB}{BLOCKS}{$block}{DETECTIONSCORE}
}

sub getOptimumCombCombForBlock{
  my $self = shift;
  my $block = shift;
  $self->computePoints();
  $self->{OPTIMUMCOMB}{BLOCKS}{$block}{COMB}
}

sub getOptimumCombMMissForBlock{
  my $self = shift;
  my $block = shift;
  $self->computePoints();
  $self->{OPTIMUMCOMB}{BLOCKS}{$block}{MMISS}
}

sub getOptimumCombMFAForBlock{
  my $self = shift;
  my $block = shift;
  $self->computePoints();
  $self->{OPTIMUMCOMB}{BLOCKS}{$block}{MFA}
}

sub getSupremumCombDetectionScore{
  my $self = shift;
  $self->computePoints();
  $self->{SUPREMUMCOMB}{DETECTIONSCORE}
}

sub getSupremumCombComb{
  my $self = shift;
  $self->computePoints();
  $self->{SUPREMUMCOMB}{COMB}
}

sub getSupremumCombMMiss{
  my $self = shift;
  $self->computePoints();
  $self->{SUPREMUMCOMB}{MMISS}
}

sub getSupremumCombMFA{
  my $self = shift;
  $self->computePoints();
  $self->{SUPREMUMCOMB}{MFA}
}

sub getSupremumCombDetectionScoreForBlock{
  my $self = shift;
  my $block = shift;
  $self->computePoints();
  $self->{SUPREMUMCOMB}{BLOCKS}{$block}{DETECTIONSCORE}
}

sub getSupremumCombCombForBlock{
  my $self = shift;
  my $block = shift;
  $self->computePoints();
  $self->{SUPREMUMCOMB}{BLOCKS}{$block}{COMB}
}

sub getSupremumCombMMissForBlock{
  my $self = shift;
  my $block = shift;
  $self->computePoints();
  $self->{SUPREMUMCOMB}{BLOCKS}{$block}{MMISS}
}

sub getSupremumCombMFAForBlock{
  my $self = shift;
  my $block = shift;
  $self->computePoints();
  $self->{SUPREMUMCOMB}{BLOCKS}{$block}{MFA}
}

sub getTrials(){
  my ($self) = @_;
  $self->{TRIALS};
}

sub getMetric{
  my ($self) = @_;
  $self->{METRIC};
}

sub getDETPng(){
  my ($self) = @_;
  $self->{LAST_GNU_DETFILE_PNG};
}

sub setDETPng(){
  my ($self, $png) = @_;
  $self->{LAST_GNU_DETFILE_PNG} = $png;
}

sub getThreshPng(){
  my ($self) = @_;
  $self->{LAST_GNU_THRESHPLOT_PNG};
}

sub setThreshPng(){
  my ($self, $png) = @_;
  $self->{LAST_GNU_THRESHPLOT_PNG} = $png;
}

sub setMeasureThreshPng(){
  my ($self, $measure, $png) = @_;
  $self->{LAST_GNU_MEASURE_THRESHPLOT_PNG}{$measure} = $png;
}

sub getMeasureThreshPngHT(){
  my ($self) = @_;
  $self->{LAST_GNU_MEASURE_THRESHPLOT_PNG}
}


sub getSerializedDET(){
  my ($self) = @_;
  $self->{LAST_SERIALIZED_DET};
}

sub getPoints(){
  my ($self) = @_;
  $self->computePoints();
  (exists($self->{POINTS}) ? $self->{POINTS} : undef); 
}

sub getPointsAsPerlArrayOfArrays(){
  my ($self) = @_;
  $self->computePoints();
  my $str = "my \$pts = [ ";
  for (my $i=0; $i < @{ $self->{POINTS} }; $i++){
    $str .= "            " if ($i != 0);
    $str .= "[ (";
    for (my $j=0; $j<@{ $self->{POINTS}[$i] }; $j++){
      $str .= (defined($self->{POINTS}[$i][$j]) ? 
               sprintf("%6.3f", $self->{POINTS}[$i][$j]) : "undef");
      $str .= ", " if ($j < @{ $self->{POINTS}[$i] } - 1); 
    }
    $str .= " ) ]";
    $str .= ",\n" if ($i < @{ $self->{POINTS} }-1)
  }
  $str .= " ];\n";
  return $str;
}


sub getMinDecisionScore(){
  my ($self) = @_;
  $self->{MINSCORE};
}

sub getMaxDecisionScore(){
  my ($self) = @_;
  $self->{MAXSCORE};
}

sub setSystemDecisionValue{
  my $self = shift;
  my $val = shift;
  $self->computePoints();
  $self->{SYSTEMDECISIONVALUE} = $val;
}

sub getSystemDecisionValue{
  my $self = shift;
  $self->computePoints();
  $self->{SYSTEMDECISIONVALUE};
}

sub getLineTitle{
  my $self = shift;
  
  return("EMPTY") if (! exists $self->{LINETITLE});

  $self->{LINETITLE};
}

sub setLineTitle{
  my ($self, $title) = @_;
  
  $self->{LINETITLE} = $title;
}

sub getMaximizable {
    my ($self) = @_;

    (defined($self->{MAXIMIZEBEST})) ? 1 : 0;
}

sub IntersectionIsolineParameter
  {
    my ($self, $x1, $y1, $x2, $y2, $moveOnToNext) = @_;
    my ($t, $xt, $yt) = (undef, undef, undef);
    return (undef, undef, undef, undef) if( ( scalar( @{ $self->{ISOLINE_COEFFICIENTS} } ) == 0 ) || ( scalar( @{ $self->{ISOLINE_COEFFICIENTS} } ) == $self->{ISOLINE_COEFFICIENTS_INDEX} ) );

    for (my $i=$self->{ISOLINE_COEFFICIENTS_INDEX}; $i<@{ $self->{ISOLINE_COEFFICIENTS} }; $i++) {
      my $m = $self->{ISOLINE_COEFFICIENTS}->[$i];
      ($t, $xt, $yt) = IntersectionParameter($m, $x1, $y1, $x2, $y2);
                
      if ( defined( $t ) ) {
        if ( $t >= 0 && $t <= 1 ) {
          $self->{ISOLINE_COEFFICIENTS_INDEX} = $i+1 if ($moveOnToNext);
          return ($t, $m, $xt, $yt);
        } elsif ( $t > 1 ) {
          $self->{ISOLINE_COEFFICIENTS_INDEX} = $i;
          return (undef, undef, undef, undef);
        }
      }
    }
        
    return (undef, undef, undef, undef);
  }

sub AllIntersectionIsolineParameter
  {
    my ($self, $x1, $y1, $x2, $y2, $moveOnToNext) = @_;
    my @out = ();
    my ($t, $m, $xt, $yt) = (undef, undef, undef, undef);

        
    do
      {
        ($t, $m, $xt, $yt) = $self->IntersectionIsolineParameter($x1, $y1, $x2, $y2, $moveOnToNext);
#    print "All - ($x1, $y1) ($x2, $y2), $moveOnToNext) - ($t, $m, $xt, $yt) - ".$self->{ISOLINE_COEFFICIENTS_INDEX}.
#             " (".join(",",@{ $self->{ISOLINE_COEFFICIENTS} }).")\n";
        if( defined( $t ) ){
#          print "     Found Line = moveOntToNext=$moveOnToNext\n";
          push( @out, [($t, $m, $xt, $yt)] );
          return(@out) if (! $moveOnToNext);
        }
      }
        while ( defined( $t ) );
        
    return( @out );
  }

sub IntersectionParameter
  {
    my ($m, $x1, $y1, $x2, $y2) = @_;
    my ($t, $xt, $yt) = (undef, undef, undef);
    return (undef, undef, undef) if( $m == 0 ); 
        
    if ( $x1 == $x2 ) {
      $t = ($m*$x1 - $y1)/($y2-$y1);
      $xt = $x1;
      $yt = $m*$xt;
    } elsif ( $y1 == $y2 ) {
      $t = (($y1/$m) - $x1)/($x2-$x1);
      $yt = $y1;
      $xt = $yt/$m;
    } else {
      my $a = ($y1-$y2)/($x1-$x2);
      return (undef, undef, undef) if($a == $m); # which should never happen
      my $b = $y1 - $a*$x1;
      $xt = $b/($m-$a);
      $t = ($xt-$x1)/($x2-$x1);
      $yt = $m*$xt;
    }
        
    return ($t, $xt, $yt);
  }

sub getIsolinePoints
  {
    my ($self) = @_;
    $self->{ISOPOINTS};
  }

sub getIsolinePointsMFAValue
  {
    my ($self, $coeff) = @_;
    if (exists($self->{ISOPOINTS}{$coeff})){
      $self->{ISOPOINTS}{$coeff}{INTERPOLATED_MFA};
    } else {
      undef;
    }
  }
  
sub getIsolinePointsMMissValue
  {
    my ($self, $coeff) = @_;
    if (exists($self->{ISOPOINTS}{$coeff})){
      $self->{ISOPOINTS}{$coeff}{INTERPOLATED_MMISS};
    } else {
      undef;
    }
  }
  
sub getIsolinePointsCombValue
  {
    my ($self, $coeff) = @_;
    if (exists($self->{ISOPOINTS}{$coeff})){
      $self->{ISOPOINTS}{$coeff}{INTERPOLATED_COMB};
    } else {
      undef;
    }
  }
  
sub getIsolinePointsDetectionScoreValue
  {
    my ($self, $coeff) = @_;
    if (exists($self->{ISOPOINTS}{$coeff})){
      $self->{ISOPOINTS}{$coeff}{INTERPOLATED_DETECTSCORE};
    } else {
      undef;
    }
  }
  
sub AddIsolineInformation
  {
    my ($self, $blocks, $paramt, $isolinecoef, $estMFa, $estMMiss, $detectScore) = @_;
        
    $self->{ISOPOINTS}{$isolinecoef}{INTERPOLATED_MFA} = $estMFa;
    $self->{ISOPOINTS}{$isolinecoef}{INTERPOLATED_MMISS} = $estMMiss;
    $self->{ISOPOINTS}{$isolinecoef}{INTERPOLATED_COMB} = $self->{METRIC}->combCalc($estMMiss, $estMFa);
    $self->{ISOPOINTS}{$isolinecoef}{INTERPOLATED_DETECTSCORE} = $detectScore;

    foreach my $b ( keys %{ $blocks } ) {
      # Add info of previous in the block id
      my $interpMFA = (1-$paramt)*($blocks->{$b}{PREVMFA}) + $paramt*($blocks->{$b}{MFA});
      my $interpMMISS = (1-$paramt)*($blocks->{$b}{PREVMMISS}) + $paramt*($blocks->{$b}{MMISS});
      $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MFA} = $self->{METRIC}->errFABlockCalc($interpMMISS, $interpMFA, $b);
      $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MMISS} = $self->{METRIC}->errMissBlockCalc($interpMMISS, $interpMFA, $b);
      # Value function
      $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{COMB} = $self->{METRIC}->combCalc($self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MMISS},
                                                                                     $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MFA});
    }
  }

sub computePoints
  {
    my $self = shift;


    ### This function implements the delayed point computation which only occurs IFF the data is requested
    if ($self->{POINT_COMPUTATION_ATTEMPTED}) {
      return;
    }
    $self->{POINT_COMPUTATION_ATTEMPTED} = 1;

    #print "[*] Entered 'computePoints'\n";
        
    ## For faster computation;
    $self->{TRIALS}->sortTrials();
        
#    print "Computing points: ".`date`;
    $self->{POINTS} = $self->Compute_blocked_DET_points($self->{TRIALS});
#    print "Point computatiuon complete: ".`date`;

    ## Global Computations
    $self->computeGlobalMeasures($self->{METRIC}->getGlobalMeasures()); 
  }

sub Compute_blocked_DET_points
  {
    my ($self, $trial) = @_;
    my @Outputs = ();

    $self->{TRIALS}->sortTrials();
    my %blocks = ();
    my $block = "";
    my $minScore = undef;
    my $maxScore = undef;
    my $numBlocks = 0;
    my $previousAvgMmiss = 0;
    my $previousAvgMfa = 0;
    my $findMaxComb = ($self->{METRIC}->combType() eq "maximizable" ? 1 : 0);
    my $style = ($self->getCurveStyle() eq "UniqThreshold") ? 1 : ($self->getCurveStyle() eq "Articulated" ? 2 : -1); 

    ### Reduce the block set to only ones with targets and setup the DS!
    foreach $block ($trial->getBlockIDs()) {
      next if (! $trial->isBlockEvaluated($block));

      $numBlocks++;
      $blocks{$block} = { TARGi => 0, NONTARGi => 0, MFA => undef, MMISS => undef,
                          CACHEDMFA => undef, CACHEDMMISS => undef, COMB => undef, 
                          PREVMFA => undef, PREVMMISS => undef, PREVTARGi => undef, PREVNONTARGi => undef,
                          OPTIMUMCOMB => { DETECTIONSCORE => undef, COMB => undef, MFA => undef, MMISS => undef},
                          SUPREMUMCOMB => { DETECTIONSCORE => 0.5, COMB => undef, MFA => 0, MMISS => $trial->getNumOmittedTarg($block)},
                          TARGNScr => $trial->getNumTargScr($block), NONTARGNScr =>  $trial->getNumNonTargScr($block)};
      if ($blocks{$block}{TARGNScr} > 0) {
        $minScore = $trial->getTargDecScr($block,0)
          if (!defined($minScore) || $minScore > $trial->getTargDecScr($block,0));
        $maxScore = $trial->getTargDecScr($block,$blocks{$block}{TARGNScr} - 1) 
          if (!defined($maxScore) || $maxScore < $trial->getTargDecScr($block,$blocks{$block}{TARGNScr} - 1));
      }
      if ($blocks{$block}{NONTARGNScr} > 0) {
        $minScore = $trial->getNonTargDecScr($block,0) 
          if (!defined($minScore) || $minScore > $trial->getNonTargDecScr($block,0));
        $maxScore = $trial->getNonTargDecScr($block,$blocks{$block}{NONTARGNScr} - 1)
          if (!defined($maxScore) || $maxScore < $trial->getNonTargDecScr($block,$blocks{$block}{NONTARGNScr} - 1));
      }
    }

    $self->{MINSCORE} = $minScore;
    $self->{MAXSCORE} = $maxScore;
    
    if (!defined($self->{MINSCORE}) || !defined($self->{MAXSCORE})) {
      my ($mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb) = $self->computeBlockWeighted(\%blocks, $numBlocks, $trial, $minScore);
      push(@Outputs, [ ( "NaN", $mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb, $numBlocks) ] );

      $self->{BESTCOMB}{DETECTIONSCORE} = "NaN";
      $self->{BESTCOMB}{COMB} = $TWComb;
      $self->{BESTCOMB}{MFA} = $mFa;
      $self->{BESTCOMB}{MMISS} = $mMiss;

      $self->{MESSAGES} .= "WARNING: '".$self->{TRIALS}->getBlockId()."' weighted DET curves can not be computed, no detection scores exist for block\n";

      return \@Outputs;
    }

#    print "Blocks: '".join(" ",keys %blocks)."'  minScore: $minScore\n";
    my ($mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb) = $self->computeBlockWeighted(\%blocks, $numBlocks, $trial, $minScore);
    push(@Outputs, [ ( $minScore, $mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb, $numBlocks) ] );
#    print "    (mMiss=$mMiss, mFa=$mFa, minScore=$minScore)\n";

    my $prevMin = $minScore;
    $self->{BESTCOMB}{DETECTIONSCORE} = $minScore;
    $self->{BESTCOMB}{COMB} = $TWComb;
    $self->{BESTCOMB}{MFA} = $mFa;
    $self->{BESTCOMB}{MMISS} = $mMiss;
    $previousAvgMmiss = $mMiss;
    $previousAvgMfa = $mFa;
    
    my $scoreBound = undef;
    my $lastMove = undef;
    my $prevMove = undef;

    my $stateInfo = { PREVMMISS => $mMiss, PREVMFA => $mFa, PREVMINSCORE => $minScore };
    my @listparams;
    #print "  Init ".MetricFuncs::getBlocksStructSummary(\%blocks)." NumRetrieved=".MetricFuncs::getBlocksStructNumRetrieved(\%blocks)."\n";

  POINT:    
    while ($self->updateMinScoreForBlockWeighted(\%blocks, \$minScore, $trial, $style, \$stateInfo)){
      #print "    ".MetricFuncs::getBlocksStructSummary(\%blocks)." NumRetrieved=".MetricFuncs::getBlocksStructNumRetrieved(\%blocks)."\n";
      ### Calculate the current scores
      ($mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb) = $self->computeBlockWeighted(\%blocks, $numBlocks, $trial, $minScore);

      @listparams = $self->AllIntersectionIsolineParameter($previousAvgMfa, $previousAvgMmiss, $mFa, $mMiss, 1);
      foreach my $setelt ( @listparams ) {
        my ($paramt, $isolinecoef, $estMFa, $estMMiss) = @{ $setelt };
	$self->AddIsolineInformation(\%blocks, $paramt, $isolinecoef, $estMFa, $estMMiss, $minScore) if( defined ( $paramt ) );
      }
                
      push(@Outputs, [ ( $minScore, $mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb, $numBlocks ) ] );
      #print "    consuming point (".join(", ", @{ $Outputs[$#Outputs] })."\n";

      if ($findMaxComb) {
        if ($TWComb > $self->{BESTCOMB}{COMB}) {
          $self->{BESTCOMB}{DETECTIONSCORE} = $minScore;
          $self->{BESTCOMB}{COMB} = $TWComb;
          $self->{BESTCOMB}{MFA} = $mFa;
          $self->{BESTCOMB}{MMISS} = $mMiss;
        }
      } else {
        if ($TWComb < $self->{BESTCOMB}{COMB}) {
          $self->{BESTCOMB}{DETECTIONSCORE} = $minScore;
          $self->{BESTCOMB}{COMB} = $TWComb;
          $self->{BESTCOMB}{MFA} = $mFa;
          $self->{BESTCOMB}{MMISS} = $mMiss;
        }
      } 
                
      $prevMin = $minScore;
      $prevMove = $lastMove;
      $previousAvgMfa = $mFa;
      $previousAvgMmiss = $mMiss;
    }
    #print "  Final ".MetricFuncs::getBlocksStructSummary(\%blocks)." NumRetrieved=".MetricFuncs::getBlocksStructNumRetrieved(\%blocks)."\n";

    ### Retrieve the Optimum Combined
    my ($combBSet, $combBSetSSD, $missBSet, $missBSetSSD, $faBSet, $faBSetSSD) = 
      $self->getMetric()->combBlockSetCalc(\%blocks, undef, "OPTIMUMCOMB");
    $self->{OPTIMUMCOMB}{COMB} = $combBSet;
    $self->{OPTIMUMCOMB}{MMISS} = $missBSet;
    $self->{OPTIMUMCOMB}{MFA} = $faBSet;
  
    foreach my $blk(keys %blocks){
      if (defined($blocks{$blk}{OPTIMUMCOMB}{DETECTIONSCORE})){
        $self->{OPTIMUMCOMB}{BLOCKS}{$blk}{DETECTIONSCORE} = $blocks{$blk}{OPTIMUMCOMB}{DETECTIONSCORE};
        $self->{OPTIMUMCOMB}{BLOCKS}{$blk}{COMB} =           $blocks{$blk}{OPTIMUMCOMB}{COMB};
        $self->{OPTIMUMCOMB}{BLOCKS}{$blk}{MFA} =            $blocks{$blk}{OPTIMUMCOMB}{CACHEDMFA};
        $self->{OPTIMUMCOMB}{BLOCKS}{$blk}{MMISS} =          $blocks{$blk}{OPTIMUMCOMB}{CACHEDMMISS};
      }    
    }    
#    print Dumper($self->{OPTIMUMCOMB});    
#    print Dumper(\%blocks);
#    print Dumper([ $self->getMetric()->combBlockSetCalc(\%blocks, undef, "SUPREMUMCOMB") ]); 
    ### Retrieve the Supremum Combined
    my ($combBSet, $combBSetSSD, $missBSet, $missBSetSSD, $faBSet, $faBSetSSD) = 
      $self->getMetric()->combBlockSetCalc(\%blocks, undef, "SUPREMUMCOMB");
    $self->{SUPREMUMCOMB}{COMB} = $combBSet;
    $self->{SUPREMUMCOMB}{MMISS} = $missBSet;
    $self->{SUPREMUMCOMB}{MFA} = $faBSet;

    foreach my $blk(keys %blocks){
      if (defined($blocks{$blk}{SUPREMUMCOMB}{DETECTIONSCORE})){
        $self->{SUPREMUMCOMB}{BLOCKS}{$blk}{DETECTIONSCORE} = $blocks{$blk}{SUPREMUMCOMB}{DETECTIONSCORE};
        $self->{SUPREMUMCOMB}{BLOCKS}{$blk}{COMB} =           $blocks{$blk}{SUPREMUMCOMB}{COMB};
        $self->{SUPREMUMCOMB}{BLOCKS}{$blk}{MFA} =            $blocks{$blk}{SUPREMUMCOMB}{CACHEDMFA};
        $self->{SUPREMUMCOMB}{BLOCKS}{$blk}{MMISS} =          $blocks{$blk}{SUPREMUMCOMB}{CACHEDMMISS};
      }    
    }    
#    print Dumper(\%blocks);
#    print Dumper($self->{SUPREMUMCOMB});    
    
    return \@Outputs;
  }

sub _minUndefSafe{
   my $m = undef;
   foreach (@_){
     $m = $_ if (!defined($m) || (defined($m) && defined($_) && $m > $_));
   }
   return $m;
}

sub updateMinScoreForBlockWeighted
{
  my ($self, $blocks, $minScore, $trial, $style, $stateInfo) = @_;
  my $change = 0;
  my $boundChange = 0;

#  print "-----------------------    Starting update\n";
  ### Record were we came from        
  foreach $b(keys %$blocks) {
    # Add info of previous in the block id
    $blocks->{$b}{PREVMFA} = $blocks->{$b}{MFA};
    $blocks->{$b}{PREVMMISS} = $blocks->{$b}{MMISS};
    $blocks->{$b}{PREVTARGi} = $blocks->{$b}{TARGi};
    $blocks->{$b}{PREVNONTARGi} = $blocks->{$b}{NONTARGi};
  } 

  if (exists(${$stateInfo}->{NextMin})){
#    print Dumper($$stateInfo);
    $$minScore = ${$stateInfo}->{NextMin};
    delete ${$stateInfo}->{NextMin};
  } else {
  
  #Advance Skipping the min and record the next new MIN
  my $nextTargVal = undef;
  my $nextNonTargVal = undef;
  my $val;
  my $N_change = 0;
  foreach $b(keys %$blocks) { 
    ### Skip the current minScores for targs
    while ($blocks->{$b}{TARGi} < $blocks->{$b}{TARGNScr} &&
           $trial->getTargDecScr($b, $blocks->{$b}{TARGi}) <= $$minScore) {
      $blocks->{$b}{TARGi} ++;
      $N_change ++;
    }
    ### Skip the current minScores for nontargs
    while ($blocks->{$b}{NONTARGi} < $blocks->{$b}{NONTARGNScr} &&
           $trial->getNonTargDecScr($b,$blocks->{$b}{NONTARGi}) <= $$minScore) {
      $blocks->{$b}{NONTARGi} ++;
      $N_change ++;
    }
    ### Targi and nonTargi now point to the next position in the arrays.  We next need to decide 
    ###   OPTION 1: What the threshold would be for this position
    if ($blocks->{$b}{TARGi} < $blocks->{$b}{TARGNScr}){
      $val = $trial->getTargDecScr($b, $blocks->{$b}{TARGi});
      $nextTargVal = $val if (!defined($nextTargVal) || $nextTargVal > $val);        
    }
    if ($blocks->{$b}{NONTARGi} < $blocks->{$b}{NONTARGNScr}) {
      $val = $trial->getNonTargDecScr($b,$blocks->{$b}{NONTARGi});
      $nextNonTargVal = $val if (!defined($nextNonTargVal) || $nextNonTargVal > $val);        
    }
  }
#  print "After Initial shift: "; MetricFuncs::dumpBlocksStruct($blocks);
  
  my ($N_min) = _minUndefSafe($nextTargVal, $nextNonTargVal);
#  print "    Next: min=$N_min, change=$N_change (Tar=$nextTargVal, NTar=$nextNonTargVal)\n";
  ### Are we done?
  if (!defined($N_min)){
#    print "    !!! End of the search no next Minimum\n";
    return(0);
  }
  
  if ($style == 1) {
    $$minScore = $N_min;

  } else {
    my $PrecF_min = undef;
    my $PrecM_min = undef;
    my $nextNextTarg = undef;
    my $nextNextNonTarg = undef;

    if (defined($nextTargVal)){
      foreach $b(keys %$blocks) { 
        $blocks->{$b}{NONTARGi} = $blocks->{$b}{PREVNONTARGi};
        while ($blocks->{$b}{NONTARGi} < $blocks->{$b}{NONTARGNScr} &&
               $trial->getNonTargDecScr($b,$blocks->{$b}{NONTARGi}) < $nextTargVal) {

          $val = $trial->getNonTargDecScr($b, $blocks->{$b}{NONTARGi});
          if ($val > $nextNonTargVal){
            $nextNextNonTarg = $val if (!defined($nextNextNonTarg) || $nextNextNonTarg < $val);       
          }
          $blocks->{$b}{NONTARGi} ++;
        }
  
      }    
#      print "        nextNextNonTarg: min=$nextNextNonTarg\n";
    }

    if (defined($nextNonTargVal)){
      foreach $b(keys %$blocks) { 
        $blocks->{$b}{TARGi} = $blocks->{$b}{PREVTARGi};
        while ($blocks->{$b}{TARGi} < $blocks->{$b}{TARGNScr} &&
               $trial->getTargDecScr($b,$blocks->{$b}{TARGi}) < $nextNonTargVal) {

          $val = $trial->getTargDecScr($b, $blocks->{$b}{TARGi});
          if ($val > $nextTargVal){
            $nextNextTarg = $val if (!defined($nextNextTarg) || $nextNextTarg < $val);       
          }
          $blocks->{$b}{TARGi} ++;
        }
  
      }    
#      print "        nextNextTarg: min=$nextNextTarg\n";
    }

    if (defined($nextTargVal) && defined($nextNonTargVal)){
        ### Need to decide what to d
#      print "one\n";
      if (defined($nextNextNonTarg) && $nextTargVal > $nextNonTargVal && $nextTargVal > $nextNextNonTarg){ 
##        print "two\n";
        ${$stateInfo}->{NextMin} = $nextNextNonTarg if ($nextNextNonTarg > $nextNonTargVal);
        $$minScore = $nextNonTargVal;

#        $$minScore = $nextNextNonTarg;
      } elsif (defined($nextNextTarg) && $nextNonTargVal > $nextTargVal && $nextNonTargVal > $nextNextTarg){ 
##        print "three\n";
        ${$stateInfo}->{NextMin} = $nextNextTarg if ($nextNextTarg > $nextTargVal);
        $$minScore = $nextTargVal;

#        $$minScore = $nextNextTarg;
        
      } else {    
        $$minScore = $N_min;
      }
    } elsif (!defined($nextTargVal)) {    
##      print "five\n";
      ${$stateInfo}->{NextMin} = $nextNextNonTarg if (defined($nextNextNonTarg) && $nextNextNonTarg > $nextNonTargVal);
      $$minScore = $nextNonTargVal;      
     } elsif (!defined($nextNonTargVal)) {    
##      print "six\n";
      ${$stateInfo}->{NextMin} = $nextNextTarg if (defined($nextNextTarg) && $nextNextTarg > $nextTargVal);
      $$minScore = $nextTargVal;      
    } else {
      $$minScore = $N_min;
    }
#    $$minScore = _minUndefSafe($N_min, $nextNextTarg, $nextNextNonTarg);
  }
}
       
#  print "    !!! Min set to $$minScore\n";
  ### Advance just like before
  my $dataLeft = 0;
  $change = 0;
  foreach $b(keys %$blocks) { 
    $blocks->{$b}{TARGi} = $blocks->{$b}{PREVTARGi};
    while ($blocks->{$b}{TARGi} < $blocks->{$b}{TARGNScr} &&
           $trial->getTargDecScr($b, $blocks->{$b}{TARGi}) < $$minScore) {
       $blocks->{$b}{MMISS} = undef;
       $blocks->{$b}{TARGi} ++;
      $change++;
    }
    $blocks->{$b}{NONTARGi} = $blocks->{$b}{PREVNONTARGi};            
    while ($blocks->{$b}{NONTARGi} < $blocks->{$b}{NONTARGNScr} &&
           $trial->getNonTargDecScr($b,$blocks->{$b}{NONTARGi}) < $$minScore) {
      $blocks->{$b}{MFA} = undef;
      $blocks->{$b}{NONTARGi} ++;
      $change++;
    }
    $dataLeft = 1 if (($blocks->{$b}{TARGi} < $blocks->{$b}{TARGNScr}) ||
                      ($blocks->{$b}{NONTARGi} < $blocks->{$b}{NONTARGNScr}));
  }
#  print "    Change = $change, $dataLeft\n";
#  print "    After final shift: "; MetricFuncs::dumpBlocksStruct($blocks);
  if (! $dataLeft) {
    # We stepped off the last system output.  Therefore, we need to need to signify it
    $$minScore = undef;
    return 0;                        ## no change
  } else {
    return $change;
  }
}

sub computeBlockWeighted
  {
    my ($self, $blocks, $numBlocks, $trial, $thresh) = @_;
    my $b = "";
        
    foreach $b (keys %$blocks) {
      if (!defined($blocks->{$b}{MMISS})) {
        my $NMiss = $blocks->{$b}{TARGi} + $trial->getNumOmittedTarg($b);
        ## Caching: Calculate is not yet calculated
        $blocks->{$b}{MMISS}        = $NMiss; 
        $blocks->{$b}{CACHEDMMISS}  = undef;
        $blocks->{$b}{CACHEDMFA}  = undef;
      }
      if (!defined($blocks->{$b}{MFA})) {
        my $NFalse = $blocks->{$b}{NONTARGNScr} - $blocks->{$b}{NONTARGi};                                                                                                                                   
        ## Caching: Calculate is not yet calculated
        $blocks->{$b}{MFA}          = $NFalse; 
        $blocks->{$b}{CACHEDMMISS}  = undef;
        $blocks->{$b}{CACHEDMFA}  = undef;
      }
    }
#    foreach $b (keys %$blocks) {
#        my $NMiss = $blocks->{$b}{TARGi} + $trial->getNumOmittedTarg($b);
#        my $NFalse = $blocks->{$b}{NONTARGNScr} - $blocks->{$b}{NONTARGi};                                                                                                                                   
#        print "($b, $NMiss, $NFalse)"
#    }
#    print "\n";

    my ($combAvg, $combSSD, $missAvg, $missSSD, $faAvg, $faSSD) = $self->{METRIC}->combBlockSetCalc($blocks, $thresh);
        
    ($missAvg, $faAvg, $combAvg, $missSSD, $faSSD, $combSSD);
  }

sub interpolateYDim{
  my ($x1, $y1, $x2, $y2, $newX) = @_;
#  print "Interpolate: ($x1,$y1) ($x2,$y2) = newX=$newX\n";
  my ($newY) = ($x2-$x1 == 0) ? (($y2+$y1)/2) : ($y2 + ( ($y1-$y2) * (($x2-$newX) / ($x2-$x1))));  
#  print ("  newY=$newY\n");
  return $newY;

### unit tests
#  die if (abs(interpolateYDim(1,1,3,3,2.5) - 2.5) >= 0.0001);
#  die if (abs(interpolateYDim(3,3,1,1,2.5) - 2.5) >= 0.0001);
#  die if (abs(interpolateYDim(1,2,4,5,2.5) - 3.5) >= 0.0001);
  ## extrapolation
#  die if (abs(interpolateYDim(1,2,4,5,7.5) - 8.5) >= 0.0001);
  ## horizontal line
#  die if (abs(interpolateYDim(1,2,2,2,7.5) - 2) >= 0.0001);
  ## vertical line
#  die if (abs(interpolateYDim(1,2,1,8,1) - 5) >= 0.0001);

}

sub computeMMissForFixedMFA{
  my ($self, $MFAPoints) = @_;
  
  $self->computePoints();
  my @computedMMiss = ();

  ## Sort the target FA points to be in ascending order
  my @sortedMFA = sort {$a<=>$b} @$MFAPoints;
  
  ### Loop through all the computed points, 
  my $points = $self->getPoints();

  ### Iterate through the range on REVERSE ORDER to match the sortedMFA
  my $lastMFA = 0.0;
  my $lastMMiss = 1.0;
  my $lastThresh = $points->[@$points - 1][0];
  for (my $ind=@$points - 1; $ind >= 0 && @sortedMFA > 0; $ind--){
    if ($lastMFA <= $sortedMFA[0] && $sortedMFA[0] <= $points->[$ind][2]){
      #print "Found line for $sortedMFA[0] @ $ind\n";
      if ($ind-1 >= 0 && ($sortedMFA[0] == $points->[$ind-1][2])){
        ### Look ahead for constant MFAs and use the last index
        $lastMFA = $points->[$ind][2];
        $lastMMiss = $points->[$ind][1];
        $lastThresh = $points->[$ind][0];
        while ($ind-1 >= 0 && ($sortedMFA[0] == $points->[$ind-1][2])){
          $ind --;
          #print "   shifting index for mulitiple MFAs\n";
        }
      }
      push @computedMMiss, { MFA => $sortedMFA[0],
                             InterpMMiss => 
                                 interpolateYDim($lastMFA, $lastMMiss, $points->[$ind][2], $points->[$ind][1], $sortedMFA[0]),
                             InterpScore => 
                                 interpolateYDim($lastMFA, $lastThresh, $points->[$ind][2], $points->[$ind][0], $sortedMFA[0]) };
      shift(@sortedMFA);
    }
    $lastMFA = $points->[$ind][2];
    $lastMMiss = $points->[$ind][1];
    $lastThresh = $points->[$ind][0];
  }

  ### Interpolate the last point...     Remember there is NO 0% miss, 100%FA point
  while (@sortedMFA > 0){
      push @computedMMiss, { MFA => $sortedMFA[0],
                             InterpMMiss => 
                                 interpolateYDim($lastMFA, $lastMMiss, 0, 1, $sortedMFA[0]),
                             InterpScore => $lastThresh};
      shift(@sortedMFA);
  }

  $self->{FIXED_MFA_VALUES} = \@computedMMiss;
}

sub _area{
  my ($x1, $y1, $x2, $y2) = @_;
  my $width = ($x2-$x1);
  $width *= -1 if ($width < 0);
  my $area = $width * ($y1+$y2)/2;
  # print "Area ($x1, $y1) -> ($x2, $y2) = $area\n";
  return($area);
}

##
##        *
##        |     *
##        |     |      *
##        |     |      |
##        ---------------
## thr    max          min
## index  max          min  
sub computeArea{
  my ($self) = @_;
  
  $self->computePoints();
  
  ### Loop through all the computed points, 
  my $points = $self->getPoints();

  my $area = 0;
  ### Interpolate the first point...  Remember there is NO 0% miss, 100%FA point
  $area += _area(1.0, 0, $points->[0][2], $points->[0][1]);
  ### Iterate throught the range
  for (my $ind=0; $ind< @$points - 1; $ind++){
    $area += _area($points->[$ind][2], $points->[$ind][1], $points->[$ind+1][2], $points->[$ind+1][1]);
  }
  ### Interpolate the last point...  Remember there is NO 0% miss, 100%FA point
  $area += _area($points->[$#$points][2], $points->[$#$points][1], 0, 1.0);

  #  print "Total Area = $area\n";
}

sub computeOracleThresh{
  my ($self) = @_;
  my %apData = ();

}

sub computeOracleSuprema{
  my ($self) = @_;
  my %apData = ();

}

### $blockMeasureID is either AP, APP, APPct, APPPct
sub _computeMeanForAP{
  my ($self, $blockMeasureID) = @_;
  my %apData = ();
  my $measureID = "M".$blockMeasureID;
  
  ### IF already computed, don't recompute
  return if (exists($self->{GLOBALMEASURES}{$measureID}));

  if ($blockMeasureID !~ /^(AP|APP|APpct|APPpct)$/){
    $apData{STATUS} = "NotApplicable";
    $apData{STATUSMESG} = "Error computing $measureID.  BlockMeasureID does not match the pattern";
    $self->{GLOBALMEASURES}{$measureID} = \%apData;
    return;
  }
  
  $apData{MEASURE}{STRING} = $measureID;
  ### Lop off the pct if it exists
  $apData{MEASURE}{STRING} =~ s/pct//;
  #  $apData{MEASURE}{FORMAT} = "%.2f";   These will be set from the first computation below
  #  $apData{MEASURE}{ABBREVSTRING} = $measureID;
  #  $apData{MEASURE}{UNIT} = ""; 
 
  my %blockStats = ();
  my %blockInfo = ();
  my ($sum, $numBlk) = (0,0);
  foreach my $block($self->{TRIALS}->getBlockIDs()){
    $self->_computeAvgPrecByType($blockMeasureID, $block);
#    print "global $block: ".Dumper($self->{GLOBALMEASURES} );
    if ($self->{GLOBALMEASURES}{$blockMeasureID}{STATUS} eq "NotApplicable"){
      $apData{STATUS} = "NotApplicable";
      $apData{STATUSMESG} = "Error computing $blockMeasureID for $block.  Status was /$self->{GLOBALMEASURES}{$blockMeasureID}{STATUS}/ with message /$self->{GLOBALMEASURES}{$blockMeasureID}{STATUSMESG}/";
      $self->{GLOBALMEASURES}{$measureID} = \%apData;
      delete $self->{GLOBALMEASURES}{$blockMeasureID};
      return;
    }
    ### it worked

    ### Set the format and unit if the first time through
    if ($numBlk == 0){
      $apData{MEASURE}{FORMAT} =          $self->{GLOBALMEASURES}{$blockMeasureID}{MEASURE}{FORMAT};
      $apData{MEASURE}{UNIT} =            $self->{GLOBALMEASURES}{$blockMeasureID}{MEASURE}{UNIT};      
      $apData{MEASURE}{ABBREVSTRING} =    "M".$self->{GLOBALMEASURES}{$blockMeasureID}{MEASURE}{ABBREVSTRING};      
      $apData{MEASURE}{PERBLOCKMEASURE} = $blockMeasureID;
      $apData{MEASURE}{PERBLOCKABBREVSTRING} = $self->{GLOBALMEASURES}{$blockMeasureID}{MEASURE}{ABBREVSTRING};      
    }
    
    ### Harvest the stats IFF the data was computable
    if ($self->{GLOBALMEASURES}{$blockMeasureID}{STATUS} eq "Computed"){
      $blockStats{$block} = $self->{GLOBALMEASURES}{$blockMeasureID}{MEASURE}{$blockMeasureID};  
      $sum += $self->{GLOBALMEASURES}{$blockMeasureID}{MEASURE}{$blockMeasureID};  
      $numBlk ++;
    } else {
      $blockStats{$block} = undef;  
      $blockInfo{$block}{STATUS} = $self->{GLOBALMEASURES}{$blockMeasureID}{STATUS}; 
      $blockInfo{$block}{STATUSMESG} = $self->{GLOBALMEASURES}{$blockMeasureID}{STATUSMESG}; 
    }
    
    ### Delete the block stats
    delete $self->{GLOBALMEASURES}{$blockMeasureID};   
  }
  $apData{STATUS} = "Computed";
  $apData{STATUSMESG} = "Successful";
  $apData{MEASURE}{$measureID} = $sum / $numBlk;
  $apData{MEASURE}{PERBLOCK} = \%blockStats;
  $apData{MEASURE}{PERBLOCKINFO} = \%blockInfo;
  $self->{GLOBALMEASURES}{$measureID} = \%apData;
  return;   
}

sub computeAvgPrec{
  my ($self) = @_;
  my %apData = ();

  $self->_computeAvgPrecByType("AP", undef);
}

sub computeAvgPrecPrime{
  my ($self) = @_;

  $self->_computeAvgPrecByType("APP", undef);
}

sub computeAvgPrecPct{
  my ($self) = @_;

  $self->_computeAvgPrecByType("APpct", undef);
}

sub computeAvgPrecPrimePct{
  my ($self) = @_;

  $self->_computeAvgPrecByType("APPpct", undef);
}

sub computeMeanAvgPrec{
  my ($self) = @_;

  $self->_computeMeanForAP("AP");
}

sub computeMeanAvgPrecPrime{
  my ($self) = @_;

  $self->_computeMeanForAP("APP");
}

sub computeMeanAvgPrecPct{
  my ($self) = @_;

  $self->_computeMeanForAP("APpct");
}

sub computeMeanAvgPrecPrimePct{
  my ($self) = @_;

  $self->_computeMeanForAP("APPpct");
}

sub computePrecAtRecall{
  my ($self, $metStr) = @_;
  my %apData = ();

  $self->_computeAvgPrecByType($metStr, undef);
}


#  Un-weighted
#    Precision(rank) =  tp(rank) / [tp(rank) + fp(rank)]
#

#    Precision'(rank) = p * tp(rank) / [ p * tp(rank) + f * fp(rank) ] where
#        p = 100 / number of positive event videos in the searched video set
#        f = 99,900 / number of false event videos in the searched video set
      
      
# Status messages:
#  NotApplicable = Fatal error
#  NotComputable = For a reason, this block does not have an AP
  
sub _computeAvgPrecByType{
  my ($self, $measureID, $blockID) = @_;
  my ($weightP, $weightF, $scale) = (1, 1, 1);
  my %apData = ();

  if ($measureID eq "APP"){
    $scale = 1;
    $apData{MEASURE}{STRING} = "AP'";
    $apData{MEASURE}{ABBREVSTRING} = "AP'";
    $apData{MEASURE}{FORMAT} = "%.2f"; 
    $apData{MEASURE}{UNIT} = ""; 
  } elsif ($measureID eq "APPpct"){
    $scale = 100;
    $apData{MEASURE}{STRING} = "AP'";
    $apData{MEASURE}{ABBREVSTRING} = "AP'";
    $apData{MEASURE}{FORMAT} = "%.1f"; 
    $apData{MEASURE}{UNIT} = "%"; 
###############################################    
  } elsif ($measureID eq "AP"){
    $apData{MEASURE}{STRING} = "AP";
    $apData{MEASURE}{ABBREVSTRING} = "AP";
    $apData{MEASURE}{FORMAT} = "%.2f";
    $apData{MEASURE}{UNIT} = ""; 
  } elsif ($measureID eq "APpct"){
    $scale = 100;
    $apData{MEASURE}{STRING} = "AP";
    $apData{MEASURE}{ABBREVSTRING} = "AP";
    $apData{MEASURE}{FORMAT} = "%.1f";
    $apData{MEASURE}{UNIT} = "%"; 
################################################
  } elsif ($measureID =~ /^P\@R(\d\d|\d\d\d)/){
    $apData{MEASURE}{STRING} = $measureID;
    $apData{MEASURE}{ABBREVSTRING} = $measureID;
    $apData{MEASURE}{FORMAT} = "%.2f";
    $apData{MEASURE}{UNIT} = ""; 
  } elsif ($measureID =~ /^P\@R(\d\d|\d\d\d)/){
    $scale = 100;
    $apData{MEASURE}{STRING} = $measureID;
    $apData{MEASURE}{ABBREVSTRING} = $measureID;
    $apData{MEASURE}{FORMAT} = "%.1f";
    $apData{MEASURE}{UNIT} = "%"; 
################################################
  } else {
    $apData{STATUS} = "NotDefined";
    $apData{STATUSMESG} = "Measure ID /$measureID/ is not defined";
    $self->{GLOBALMEASURES}{$measureID} = \%apData;
    return;    
  } 

  ### IF already computed, don't recompute
  return if (exists($self->{GLOBALMEASURES}{$measureID}));
  
  ### Set the block ID
  my $blk = undef;
    
  #### if blockID is UNDEF, then compute for the ONLY block
  if (! defined($blockID)){
    ## Only Run IFF there is a single block
    my @blocks = $self->{TRIALS}->getBlockIDs();
    if (@blocks > 1){
       $apData{STATUS} = "NotApplicable";
       $apData{STATUSMESG} = "Not defined for multiple blocks in as Trials Structure";
       $self->{GLOBALMEASURES}{$measureID} = \%apData;
       return;
    }
    $blk = $blocks[0];
  } else {
    ### We are computing for the specified block
    if (! $self->{TRIALS}->blockExists($blockID)){
       $apData{STATUS} = "NotApplicable";
       $apData{STATUSMESG} = "Supplied blockID $blockID does not exist in the Trials Structure";
       $self->{GLOBALMEASURES}{$measureID} = \%apData;
       return;
    }    
    $blk = $blockID;
  }
  
  ## Make sure the block is evaluable
  if (! $self->{TRIALS}->isBlockEvaluated($blk)){
     $apData{STATUS} = "NotComputable";
     $apData{STATUSMESG} = "Single Block '$blk' is not evaluable";
     $self->{GLOBALMEASURES}{$measureID} = \%apData;
     return;
  }

  ## Start the code
  ## Step 1, build the 2-d array    
  ## Sort  the trials
  
  my $ranks = $self->{TRIALS}->getRanks($blk);
  if (0){                                    
    my $r = $self->{TRIALS}->getRanks($blk); 
    for (my $i=0; $i<@$r; $i++){             
      print join(",",@{$r->[$i]})."\n" if ($r->[$i]->[2] == 1);
    }                                        
  }                                          

  if ($measureID =~ /^AP.*/){
    if ($measureID eq "APP" || $measureID eq "APPpct"){
      if ($self->{TRIALS}->getNumTarg($blk) == 0){
         $apData{STATUS} = "NotComputable";
         $apData{STATUSMESG} = "Single Block '$blk' has no target trails to compute ".$apData{MEASURE}{ABBREVSTRING};
         $self->{GLOBALMEASURES}{$measureID} = \%apData;
         return;
      }
      if ($self->{TRIALS}->getNumNonTarg($blk) == 0){
         $apData{STATUS} = "NotComputable";
         $apData{STATUSMESG} = "Single Block '$blk' has no non-target trails to compute ".$apData{MEASURE}{ABBREVSTRING};
         $self->{GLOBALMEASURES}{$measureID} = \%apData;
         return;
      }
      $weightP = 100 / $self->{TRIALS}->getNumTarg($blk); 
      $weightF = 99900 / $self->{TRIALS}->getNumNonTarg($blk); 
    }
    # print "  WeightP = $weightP\n  WeightF = $weightF\n";
    my $sum = 0;
    my $numPos = 0;
    my $numNonPos = 0;
    my $numTarg = $self->{TRIALS}->getNumTarg($blk);
    for (my $t=0; $t<@$ranks; $t++){
      if ($ranks->[$t]->[2] > 0){
      	$numPos ++;
      	$sum += (($weightP * $numPos) / (($weightF * $numNonPos) + ($weightP * $numPos))) * $scale;
      	#print "  Add: (($weightP * $numPos) / (($weightF * $numNonPos) + ($weightP * $numPos))) * $scale = $sum;\n";
      } else {
      	$numNonPos ++;
      }
    }
    if ($numPos > 0){
      $apData{STATUS} = "Computed";
      $apData{STATUSMESG} = "Successful";
      $apData{MEASURE}{$measureID} = $sum / $numTarg;
      $apData{MEASURE}{POSRANKS} = $ranks;
    } else {
      $apData{STATUS} = "Computed";
      $apData{STATUSMESG} = "Successful.  No Positives for block $blk";
      $apData{MEASURE}{$measureID} = 0;
      $apData{MEASURE}{POSRANKS} = $ranks;
  #  } else {
  #    $apData{STATUS} = "NotApplicable";
  #    $apData{STATUSMESG} = "No Positives for block $blk";
  #    $apData{MEASURE}{POSRANKS} = $ranks;
    }
  } elsif ($measureID =~ /^P\@R(\d\d|\d\d\d)/){
    my $threshVal = $1;
    my $thresh = $1/100;  ### The recall percentage is the digits / 100
    if ($threshVal <= 0) {
      $apData{STATUS} = "NotComputable";
      $apData{STATUSMESG} = "Precision at Recall <= 0 not defined";
      $self->{GLOBALMEASURES}{$measureID} = \%apData;
      return;
    }
    if ($threshVal > 100) {
      $apData{STATUS} = "NotComputable";
      $apData{STATUSMESG} = "Precision at Recall > 100% not defined";
      $self->{GLOBALMEASURES}{$measureID} = \%apData;
      return;
    }
    if ($self->{TRIALS}->getNumTarg($blk) == 0){
      $apData{STATUS} = "NotComputable";
      $apData{STATUSMESG} = "Single Block '$blk' has no target trails to compute ".$apData{MEASURE}{ABBREVSTRING};
      $self->{GLOBALMEASURES}{$measureID} = \%apData;
      return;
    }
    if ($self->{TRIALS}->getNumNonTarg($blk) == 0){
      $apData{STATUS} = "NotComputable";
      $apData{STATUSMESG} = "Single Block '$blk' has no non-target trails to compute ".$apData{MEASURE}{ABBREVSTRING};
      $self->{GLOBALMEASURES}{$measureID} = \%apData;
      return;
    }
    my $numPos = 0;
    my $numNonPos = 0;
    my $numTarg = $self->{TRIALS}->getNumTarg($blk);
    for (my $t=0; $t<@$ranks; $t++){
      if ($ranks->[$t]->[2] > 0){
      	$numPos ++;
      } else {
      	$numNonPos ++;
      }
      last if ($numPos/$numTarg >= $thresh)
    }
    $apData{STATUS} = "Computed";
    $apData{STATUSMESG} = "Successful";
    $apData{MEASURE}{$measureID} = $numPos / ($numPos + $numNonPos);
    # $apData{MEASURE}{numPos} = $numPos;
    # $apData{MEASURE}{retreived} = $numPos + $numNonPos;
  }

  $self->{GLOBALMEASURES}{$measureID} = \%apData;

  #print Dumper(\%apData);
}

sub computeGlobalMeasures{
  my ($self) = @_;
  # die "About to divy out global comp".join(" ",@$measureSet);
# die "computeGlobal is ".join(" ",@{$self->getMetric()->getGlobalMeasures()});
  foreach my $mea(@{ $self->getMetric()->getGlobalMeasures()}){
    $self->computeAvgPrec() if ($mea eq "AP");
    $self->computeAvgPrecPrime() if ($mea eq "APP");
    $self->computeAvgPrecPct() if ($mea eq "APpct");
    $self->computeAvgPrecPrimePct() if ($mea eq "APPpct");
    $self->computeMeanAvgPrec() if ($mea eq "MAP");
    $self->computeMeanAvgPrecPrime() if ($mea eq "MAPP");
    $self->computeMeanAvgPrecPct() if ($mea eq "MAPpct");
    $self->computeMeanAvgPrecPrimePct() if ($mea eq "MAPPpct");
    $self->computeOracleTresh() if ($mea eq "OracleThresh");
    $self->computeOracleSuprema() if ($mea eq "OracleSuprema");
    $self->computePrecAtRecall($mea) if ($mea eq "P\@R\d+");

  }
}

sub getGlobalMeasure{
  my ($self, $measure) = @_;
  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}));
  return $self->{GLOBALMEASURES}{$measure}{MEASURE}{$measure};
}

sub getGlobalMeasureForBlock{
  my ($self, $measure, $block) = @_;
  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}{MEASURE}{PERBLOCKMEASURE}));
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}{MEASURE}{PERBLOCK}{$block}));
  
  return $self->{GLOBALMEASURES}{$measure}{MEASURE}{PERBLOCK}{$block};
}

sub getGlobalMeasureIDs{
  my ($self) = @_;
  $self->computeGlobalMeasures();
  return () unless(exists($self->{GLOBALMEASURES}));
  return sort (keys %{ $self->{GLOBALMEASURES} });
}

sub getGlobalMeasureIDsWithBlocks{
  my ($self) = @_;
  $self->computeGlobalMeasures();
  my @ids = ();
  return @ids unless(exists($self->{GLOBALMEASURES}));
  foreach my $mea($self->getGlobalMeasureIDs()){
    if (exists($self->{GLOBALMEASURES}{$mea}{MEASURE}{PERBLOCKMEASURE})){
      push @ids, $mea;
    }
  }
  return (sort(@ids));
}

sub getGlobalMeasureString{
  my ($self, $measure) = @_;

  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}));
  return $self->{GLOBALMEASURES}{$measure}{MEASURE}{STRING};
}

sub getGlobalMeasureStringForBlock{
  my ($self, $measure) = @_;

  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}{MEASURE}{PERBLOCKMEASURE}));
  return $self->{GLOBALMEASURES}{$measure}{MEASURE}{PERBLOCKMEASURE};
}

sub getGlobalMeasureAbbrevString{
  my ($self, $measure) = @_;
  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}));
  return $self->{GLOBALMEASURES}{$measure}{MEASURE}{ABBRREVSTRING};
}

sub getGlobalMeasureAbbrevStringForBlock{
  my ($self, $measure) = @_;
  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}{MEASURE}{PERBLOCKMEASURE}));
  return $self->{GLOBALMEASURES}{$measure}{MEASURE}{PERBLOCKABBREVSTRING};
}

sub getGlobalMeasureFormat{
  my ($self, $measure) = @_;
  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}));
  return $self->{GLOBALMEASURES}{$measure}{MEASURE}{FORMAT};
}

sub getGlobalMeasureUnit{
  my ($self, $measure) = @_;
  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}));
  return $self->{GLOBALMEASURES}{$measure}{MEASURE}{UNIT};
}

sub getGlobalMeasureStructure{
  my ($self, $measure) = @_;
  $self->computeGlobalMeasures();
  return undef unless(exists($self->{GLOBALMEASURES}{$measure}));
  return $self->{GLOBALMEASURES}{$measure};
}

sub ppndf
  {
    my ($ival) = @_;
    ## A lot of predefined variables

    my $SPLIT=0.42;
        
    my $EPS=2.2204e-16;
    my $LL=140;
        
    my $A0=2.5066282388;
    my $A1=-18.6150006252;
    my $A2=41.3911977353;
    my $A3=-25.4410604963;
    my $B1=-8.4735109309;
    my $B2=23.0833674374;
    my $B3=-21.0622410182;
    my $B4=3.1308290983;
    my $C0=-2.7871893113;
    my $C1=-2.2979647913;
    my $C2=4.8501412713;
    my $C3=2.3212127685;
    my $D1=3.5438892476;
    my $D2=1.6370678189;
    my ($p, $q, $r, $retval) = (0, 0, 0, 0);
        
    if ($ival >= 1.0) {
      $p = 1 - $EPS;
    } elsif ($ival <= 0.0) {
      $p = $EPS;
    } else {
      $p = $ival;
    }
        
    $q = $p - 0.5;
        
    if (abs($q) <= $SPLIT ) {
      $r = $q * $q;
      $retval = $q * ((($A3 * $r + $A2) * $r + $A1) * $r + $A0) /
        (((($B4 * $r + $B3) * $r + $B2) * $r + $B1) * $r + 1.0);
    } else {
      if ( $q > 0.0 ) {
        $r = 1.0 - $p;
      } else {
        $r = $p;
      }
                
      if ($r <= 0.0) {
        printf ("Found r = %f\n", $r);
        return;
      }
                
      $r = sqrt( (-1.0 * log($r)));
                
      $retval = ((($C3 * $r + $C2) * $r + $C1) * $r + $C0) / 
        (($D2 * $r + $D1) * $r + 1.0);
                
      if ($q < 0) {
        $retval = $retval * -1.0;
      }
    }
        
    return ($retval);
  }

sub compareActual ($$) {
    my ($a, $b) = @_;
    my ($a_score, $b_score, @tmp) = (0, 0, undef);

    @tmp = $a->{DET}->getMetric()->getActualDecisionPerformance();
    $a_score = $tmp[0];

    @tmp = $b->{DET}->getMetric()->getActualDecisionPerformance();
    $b_score = $tmp[0];

    if (! $a->{DET}->getMaximizable()) {
        return $b_score <=> $a_score; 
    } else {
        return $a_score <=> $b_score; 
    }
}

sub compareBest ($$) {
    my ($a, $b) = @_;

    if (! $a->{DET}->getMaximizable()) {
        return $b->{DET}->getBestCombComb() <=> $a->{DET}->getBestCombComb();
    } else {
        return $a->{DET}->getBestCombComb() <=> $b->{DET}->getBestCombComb();
    }
}

sub getSmoothedDET{
  my ($self, $smoothWindowSize, $targExtraDecisions, $nonTargExtraDecisions) = @_;

  my $trial = $self->getTrials();
  ### Set the Trial metrics based on the metricType
  my $otrial = $trial->getSmoothTrials( $smoothWindowSize, $targExtraDecisions, $nonTargExtraDecisions);

  if (defined($trial->getTrialActualDecisionThreshold())){
    $otrial->setTrialActualDecisionThreshold($trial->getTrialActualDecisionThreshold());
  }
  ### Make a metric clone
  my $metric = $self->getMetric()->cloneForTrial($otrial);

  my $outDet = new DETCurve($otrial, $metric, "Smoothed ".$self->getLineTitle(), [()], $self->{GZIPPROG});
  $outDet->computePoints();

  return($outDet);
}

sub getCurveStyle{
  my ($self) = @_;
  my $st = $self->{CURVE_STYLE};
  return (! defined($st) ? "UniqThreshold" : ($st eq "" ? "UniqThreshold" : $st));
}

sub setCurveStyle{
  my ($self, $style) = @_;
  $self->{CURVE_STYLE} = $style;
  die "Error: Unknown curve style /$style/.  Must be either (UniqThreshold|Articulated)" if ($style !~ /^(UniqThreshold|Articulated)$/);
}

1;
