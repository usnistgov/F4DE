# STDEval
# DETCurve.pm
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
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package DETCurve;

use strict;
use Trials;
use MetricTestStub;
use Data::Dumper;
use DETCurveSet;
use MetricFuncs;

my(@tics) = (0.00001, 0.0001, 0.001, 0.004, .01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 40, 60, 80, 90, 95, 98, 99, 99.5, 99.9);

sub new
  {
    my ($class, $trials, $metric, $style, $lineTitle, $listIsolineCoef, $gzipPROG) = @_;
        
    my $self =
      { 
       TRIALS => $trials,
       METRIC => $metric,
       STYLE => undef,
       LINETITLE => $lineTitle,
       MINSCORE => undef,
       MAXSCORE => undef,
       MAXIMIZEBEST => undef,
       BESTCOMB => { DETECTIONSCORE => undef, COMB => undef, MFA => undef, MMISS => undef },
       SYSTEMDECISIONVALUE => undef, ### this is the value based on the system's hard decisions
       POINTS => undef, ## 2D array (score, Mmiss, Mfa, comb);  IF style is blocked, then (sampleStandardDev(Mmiss), ssd(Mfa), ssd(ssdComb), $numBlocks) 
       LAST_GNU_DETFILE_PNG => "",
       LAST_GNU_THRESHPLOT_PNG => "",
       LAST_SERIALIZED_DET => "",
       MESSAGES => "",
       ISOLINE_COEFFICIENTS => $listIsolineCoef,
       ISOLINE_COEFFICIENTS_INDEX => 0,         
       ISOPOINTS => {},
       GZIPPROG => (defined($gzipPROG) ? $gzipPROG : "gzip"),
       POINT_COMPUTATION_ATTEMPTED => 0,
      };
        
    bless $self;
        
    #   print Dumper($listIsolineCoef);
        
    die "Error: Style must be '(pooled|blocked|block=\\S+)' not '$style'" if ($style !~ /^(pooled|blocked|block=(\S+))$/);
    die "Error: Combined metric must have the output of combType() be 'maximizable|minimizable'" 
      if ($metric->combType() !~ /^(maximizable|minimizable)$/);
    $self->{MAXIMIZEBESTC} = ($metric->combType() eq "maximizable");
        
    if ($style =~ /^(pooled|blocked)$/) {
      $self->{STYLE} = "$style";
    } else {
      die "Error: Curve style '$style' not implemented";
    }
        
    return $self;
  }

sub thisabs{ ($_[0] < 0) ? $_[0]*(-1) : $_[0]; }

sub unitTest
  {
    print "Test DETCurve\n";
        
    ###POOLED###        my $trial = new Trials("Term Detection", "Term", "Occurrence");
    ###POOLED###        my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
    ###POOLED###        
    ###POOLED###        $trial->addTrial("she", 0.1, "NO", 0);
    ###POOLED###        $trial->addTrial("she", 0.2, "NO", 0);
    ###POOLED###        $trial->addTrial("she", 0.3, "NO", 1);
    ###POOLED###        $trial->addTrial("she", 0.4, "NO", 0);
    ###POOLED###        $trial->addTrial("she", 0.5, "NO", 0);
    ###POOLED###        $trial->addTrial("she", 0.6, "NO", 0);
    ###POOLED###        $trial->addTrial("she", 0.7, "NO", 1);
    ###POOLED###        $trial->addTrial("she", 0.8, "YES", 0);
    ###POOLED###        $trial->addTrial("she", 0.9, "YES", 1);
    ###POOLED###        $triafl->addTrial("she", 1.0, "YES", 1);
    ###POOLED###        $trial->addTrial("he", 0.41, "NO", 1);
    ###POOLED###        $trial->addTrial("he", 0.51, "YES", 0);
    ###POOLED###        $trial->addTrial("he", 0.61, "YES", 0);
    ###POOLED###        $trial->addTrial("he", 0.7, "YES", 1);
    ###POOLED###        
    ###POOLED###        print " Computing pooled curve...";
    ###POOLED####       print $trial->dump(*STDOUT,"");
    ###POOLED###        
    ###POOLED###        my $det = new DETCurve($trial, "pooled", "footitle", 1, 0.1, 0.0001, \@isolinecoef, undef );
    ###POOLED###        print "  OK\n";
    ###POOLED###
    ###POOLED###    ## This was built from DETtesting-v2 with MissingTarg=0, MissingNonTarg=0
    ###POOLED###        #                Thr   Pmiss  Pfa    val
    ###POOLED###        my @points =  [ (0.1,  0.000, 1.000, 0.867) ];
    ###POOLED###        push @points, [ (0.2,  0.000, 0.875, 0.883) ];
    ###POOLED###        push @points, [ (0.3,  0.000, 0.750, 0.900) ];
    ###POOLED###        push @points, [ (0.4,  0.167, 0.750, 0.733) ];
    ###POOLED###        push @points, [ (0.41, 0.167, 0.625, 0.750) ];
    ###POOLED###        push @points, [ (0.5,  0.333, 0.625, 0.583) ];
    ###POOLED###        push @points, [ (0.51, 0.333, 0.500, 0.600) ];
    ###POOLED###        push @points, [ (0.6,  0.333, 0.375, 0.617) ];
    ###POOLED###        push @points, [ (0.61, 0.333, 0.250, 0.633) ];
    ###POOLED###        push @points, [ (0.7,  0.333, 0.125, 0.650) ];
    ###POOLED###        push @points, [ (0.7,  0.500, 0.125, 0.483) ];
    ###POOLED###        push @points, [ (0.8,  0.667, 0.125, 0.317) ];
    ###POOLED###        push @points, [ (0.9,  0.667, 0.000, 0.333) ];
    ###POOLED###        push @points, [ (1.0,  0.833, 0.000, 0.167) ];
    ###POOLED###        print " Checking points...";
    ###POOLED###        
    ###POOLED###    for (my $i=0; $i<@points; $i++)
    ###POOLED###    {
    ###POOLED###                die "Error: Det point isn't correct for point $i expected '".join( ",", @{$points[$i]} ).
    ###POOLED###                        "' got '".join(",",@{ $det->{POINTS}[$i]})."'"
    ###POOLED###                        if ($points[$i][0] != $det->{POINTS}[$i][0] ||
    ###POOLED###                        thisabs($points[$i][1] - sprintf("%.3f",$det->{POINTS}[$i][1])) > 0.001 ||
    ###POOLED###                        thisabs($points[$i][2] - sprintf("%.3f",$det->{POINTS}[$i][2])) > 0.001 ||
    ###POOLED###                        thisabs($points[$i][3] - sprintf("%.3f",$det->{POINTS}[$i][3])) > 0.001);
    ###POOLED###        }
    ###POOLED###        
    ###POOLED###    print "  OK\n";
    ###POOLED###    print " Checking BestComb...";
    ###POOLED###    
    ###POOLED###        my ($scr, $val, $Pmiss, $Pfa) = ($det->getBestCombDetectionScore(),
    ###POOLED###                                                                         $det->getBestCombValue(),
    ###POOLED###                                                                         $det->getBestCombPMiss(),
    ###POOLED###                                                                         $det->getBestCombPFA());
    ###POOLED###                                     
    ###POOLED###        die "Error: Max value detection score incorrect $scr != 1.00" if (thisabs($scr - 0.30) > 0.001);
    ###POOLED###        die "Error: Max value value incorrect $val != 0.900" if (thisabs($val - 0.900) > 0.001);
    ###POOLED###        print "  OK\n";
    ###POOLED###        $det->setSystemDecisionValue(0.5);
    ###POOLED####       $det->writeGNUGraph("foo");
    ###POOLED###    print " Computing pooled curve with nonTargetDenominator...";
    ###POOLED###    $trial->setPooledTotalTrials(40);
    ###POOLED###    $trial->addTrial("he", undef, "OMITTED", 1);
    ###POOLED###    $trial->addTrial("he", undef, "OMITTED", 1);
    ###POOLED###    $trial->addTrial("he", undef, "OMITTED", 1);
    ###POOLED###    $trial->addTrial("he", undef, "OMITTED", 1);
    ###POOLED###    my $detFixDenom = new DETCurve($trial, "pooled", undef, "TargetDenom", 1.0, 0.1, 0.0001, \@isolinecoef, undef);
    ###POOLED###    print "  OK\n";
    ###POOLED####       $detFixDenom->writeGNUGraph("fooDen");
    ###POOLED###    @points = ();
    ###POOLED###    ## This was built from DETtesting-v2 with MissingTarg=4, MissingNonTarg=22
    ###POOLED###    #                Thr   Pmiss  Pfa    val
    ###POOLED###        @points =     [ (0.1,  0.400, 0.267, 0.520) ];
    ###POOLED###        push @points, [ (0.2,  0.400, 0.233, 0.530) ];
    ###POOLED###        push @points, [ (0.3,  0.400, 0.200, 0.540) ];
    ###POOLED###        push @points, [ (0.4,  0.500, 0.200, 0.440) ];
    ###POOLED###        push @points, [ (0.41, 0.500, 0.167, 0.450) ];
    ###POOLED###        push @points, [ (0.5,  0.600, 0.167, 0.350) ];
    ###POOLED###        push @points, [ (0.51, 0.600, 0.133, 0.360) ];
    ###POOLED###        push @points, [ (0.6,  0.600, 0.100, 0.370) ];
    ###POOLED###        push @points, [ (0.61, 0.600, 0.067, 0.380) ];
    ###POOLED###        push @points, [ (0.7,  0.600, 0.033, 0.390) ];
    ###POOLED###        push @points, [ (0.7,  0.700, 0.033, 0.290) ];
    ###POOLED###        push @points, [ (0.8,  0.800, 0.033, 0.190) ];
    ###POOLED###        push @points, [ (0.9,  0.800, 0.000, 0.200) ];
    ###POOLED###        push @points, [ (1.0,  0.900, 0.000, 0.100) ];
    ###POOLED###    print " Checking points...";
    ###POOLED###    
    ###POOLED###    for (my $i=0; $i<@points; $i++)
    ###POOLED###    {
    ###POOLED###                die "Error: Det point isn't correct for point $i expected '".join(",",@{$points[$i]}).
    ###POOLED###                        "' got '".join(",",@{ $detFixDenom->{POINTS}[$i]})."'"
    ###POOLED###                        if ($points[$i][0] != $detFixDenom->{POINTS}[$i][0] ||
    ###POOLED###                        thisabs($points[$i][1] - $detFixDenom->{POINTS}[$i][1]) > 0.001 ||
    ###POOLED###                        thisabs($points[$i][2] - $detFixDenom->{POINTS}[$i][2]) > 0.001 ||
    ###POOLED###                        thisabs($points[$i][3] - $detFixDenom->{POINTS}[$i][3]) > 0.001);
    ###POOLED###    }
    ###POOLED###  print "  OK\n";
    blockWeightedUnitTest();
    #   unitTestMultiDet();

    return 1;
  }

sub blockWeightedUnitTest()
  {
    print " Computing blocked curve without data...";
    my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
    
    #####################################  Without data  ###############################    
    my $emptyTrial = new Trials("Term Detection", "Term", "Occurrence", { ("TOTALTRIALS" => 100) });

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
    my $emptydet = new DETCurve($emptyTrial, $met, "blocked", "footitle", \@isolinecoef, undef);
    die "Error: Empty det should not be successful()" if ($emptydet->successful());
    print "  OK\n";

    #####################################  With data  ###############################    
    print " Computing blocked curve with data...";
    my $trial = new Trials("Term Detection", "Term", "Occurrence", { ("TOTALTRIALS" => 10) });

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
                                    "blocked", "footitle", \@isolinecoef, "gzip");
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
    push @points, [ (0.41,  0.583, 0.444, -443.983, 0.382,    0.096,   96.288,   3) ];
    push @points, [ (0.5, 0.667, 0.403, -402.404, 0.382,    0.087,   86.407,   3) ];
    push @points, [ (0.51,  0.667, 0.347, -346.854, 0.382,    0.024,   24.344,   3) ];
    push @points, [ (0.6, 0.667, 0.250, -249.642, 0.382,    0.083,   83.076,   3) ];
    push @points, [ (0.61,  0.667, 0.194, -194.092, 0.382,    0.048,   48.397,   3) ];
    push @points, [ (0.7, 0.667, 0.097,  -96.879, 0.382,    0.087,   86.568,   3) ];
    push @points, [ (0.8,  0.833, 0.056,  -55.383, 0.289,    0.096,   95.927,   3) ];
    push @points, [ (0.9,  0.833, 0.000,    0.167, 0.289,    0.000,    0.289,   3) ];
    push @points, [ (1.0,  0.917, 0.000,    0.083, 0.144,    0.000,    0.144,   3) ];
    print " Checking points...";
    for (my $i=0; $i<@points; $i++) {
      die "Error: Det point isn't correct for point $i:\n   expected '".join(",",@{$points[$i]})."'\n".
        "        got '".join(",",@{ $blockdet->{POINTS}[$i]})."'"
          if ($points[$i][0] != $blockdet->{POINTS}[$i][0] ||
              thisabs($points[$i][1] - sprintf("%.3f",$blockdet->{POINTS}[$i][1])) > 0.001 ||
              thisabs($points[$i][2] - sprintf("%.3f",$blockdet->{POINTS}[$i][2])) > 0.001 ||
              thisabs($points[$i][3] - sprintf("%.3f",$blockdet->{POINTS}[$i][3])) > 0.001 ||
              thisabs($points[$i][4] - sprintf("%.3f",$blockdet->{POINTS}[$i][4])) > 0.001 ||
              thisabs($points[$i][5] - sprintf("%.3f",$blockdet->{POINTS}[$i][5])) > 0.001 ||
              thisabs($points[$i][6] - sprintf("%.3f",$blockdet->{POINTS}[$i][6])) > 0.001 ||
              thisabs($points[$i][7] - sprintf("%.3f",$blockdet->{POINTS}[$i][7])) > 0.001);
    }
    #$blockdet->writeGNUGraph("fooblock");
    
    print "  OK\n";
  }

sub unitTestMultiDet{
  print " Checking multi...";

  my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
  my $trial = new Trials("Term Detection", "Term", "Occurrence", { ("TOTALTRIALS" => undef) });
    
  $trial->addTrial("she", 0.10, "NO", 0);
  $trial->addTrial("she", 0.15, "NO", 0);
  $trial->addTrial("she", 0.20, "NO", 0);
  $trial->addTrial("she", 0.25, "NO", 0);
  $trial->addTrial("she", 0.30, "NO", 1);
  $trial->addTrial("she", 0.35, "NO", 0);
  $trial->addTrial("she", 0.40, "NO", 0);
  $trial->addTrial("she", 0.45, "NO", 1);
  $trial->addTrial("she", 0.50, "NO", 0);
  $trial->addTrial("she", 0.55, "YES", 1);
  $trial->addTrial("she", 0.60, "YES", 1);
  $trial->addTrial("she", 0.65, "YES", 0);
  $trial->addTrial("she", 0.70, "YES", 1);
  $trial->addTrial("she", 0.75, "YES", 1);
  $trial->addTrial("she", 0.80, "YES", 1);
  $trial->addTrial("she", 0.85, "YES", 1);
  $trial->addTrial("she", 0.90, "YES", 1);
  $trial->addTrial("she", 0.95, "YES", 1);
  $trial->addTrial("she", 1.0, "YES", 1);

  my $trial2 = new Trials("Term Detection", "Term", "Occurrence", { ("TOTALTRIALS" => undef) });
    
  $trial2->addTrial("she", 0.10, "NO", 0);
  $trial2->addTrial("she", 0.15, "NO", 0);
  $trial2->addTrial("she", 0.20, "NO", 0);
  $trial2->addTrial("she", 0.25, "NO", 0);
  $trial2->addTrial("she", 0.30, "NO", 1);
  $trial2->addTrial("she", 0.35, "NO", 1);
  $trial2->addTrial("she", 0.40, "NO", 0);
  $trial2->addTrial("she", 0.45, "NO", 1);
  $trial2->addTrial("she", 0.50, "NO", 0);
  $trial2->addTrial("she", 0.55, "YES", 1);
  $trial2->addTrial("she", 0.60, "YES", 1);
  $trial2->addTrial("she", 0.65, "YES", 0);
  $trial2->addTrial("she", 0.70, "YES", 0);
  $trial2->addTrial("she", 0.75, "YES", 1);
  $trial2->addTrial("she", 0.80, "YES", 0);
  $trial2->addTrial("she", 0.85, "YES", 1);
  $trial2->addTrial("she", 0.90, "YES", 1);
  $trial2->addTrial("she", 0.95, "YES", 1);
  $trial2->addTrial("she", 1.0, "YES", 1);

  my $det1 = new DETCurve($trial, 
                          new MetricSTD({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
                          "pooled", "DET1", \@isolinecoef, undef);
  my $det2 = new DETCurve($trial2, 
                          new MetricSTD({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial2),
                          "pooled", "DET2", \@isolinecoef, undef);
    
  DETCurve::writeMultiDetGraph("foomerge", [($det1, $det2)]);
  print DETCurve::writeMultiDetSummary([($det1, $det2)], "text");
}

sub serialize
  {
    my ($self, $file) = @_;
    $self->{LAST_SERIALIZED_DET} = $file;
    open (FILE, ">$file") || die "Error: Unable to open file '$file' to serialize STDDETSet to";
    my $orig = $Data::Dumper::Indent; 
    $Data::Dumper::Indent = 0;
    
    ### Purity controls how self referential objects are written;
    my $origPurity = $Data::Dumper::Purity;
    $Data::Dumper::Purity = 1;
             
    print FILE Dumper($self); 
    
    $Data::Dumper::Indent = $orig;
    $Data::Dumper::Purity = $origPurity;
    
    close FILE;
    system("$self->{GZIPPROG} -9 -f $file > /dev/null");
  }

sub readFromFile
  {
    my ($file, $gzipPROG) = @_;
    my $str = "";
    my $compressed = 0;
    
    if ( ( $file =~ /.+\.gz$/ ) && ( -e $file ) && ( -f $file ) && ( -r $file ) ) {
      system("$gzipPROG -d -f $file > /dev/null");
      $compressed = 1;
    }

    $file =~ s/\.gz$//;

    open (FILE, "$file") || die "Failed to open $file for read";
    while (<FILE>) {
      $str .= $_ ;
    }
    close FILE;
    system("$gzipPROG -9 -f $file > /dev/null") if( $compressed );
    my $VAR1;
    eval $str;
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

sub getStyle{
  my $self = shift;
  $self->{STYLE}
}

sub getTrials(){
  my ($self) = @_;
  $self->{TRIALS};
}

sub getMetric(){
  my ($self) = @_;
  $self->{METRIC};
}

sub getDETPng(){
  my ($self) = @_;
  $self->{LAST_GNU_DETFILE_PNG};
}

sub getThreshPng(){
  my ($self) = @_;
  $self->{LAST_GNU_THRESHPLOT_PNG};
}

sub getSerializedDET(){
  my ($self) = @_;
  $self->{LAST_SERIALIZED_DET};
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
  
  $self->{LINETITLE};
}

sub IntersectionIsolineParameter
  {
    my ($self, $x1, $y1, $x2, $y2) = @_;
    my ($t, $xt, $yt) = (undef, undef, undef);
    return (undef, undef, undef, undef) if( ( scalar( @{ $self->{ISOLINE_COEFFICIENTS} } ) == 0 ) || ( scalar( @{ $self->{ISOLINE_COEFFICIENTS} } ) == $self->{ISOLINE_COEFFICIENTS_INDEX} ) );

    for (my $i=$self->{ISOLINE_COEFFICIENTS_INDEX}; $i<@{ $self->{ISOLINE_COEFFICIENTS} }; $i++) {
      my $m = $self->{ISOLINE_COEFFICIENTS}->[$i];
      ($t, $xt, $yt) = IntersectionParameter($m, $x1, $y1, $x2, $y2);
                
      if ( defined( $t ) ) {
        if ( $t >= 0 && $t <= 1 ) {
          $self->{ISOLINE_COEFFICIENTS_INDEX} = $i+1;
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
    my ($self, $x1, $y1, $x2, $y2) = @_;
    my @out = ();
    my ($t, $m, $xt, $yt) = (undef, undef, undef, undef);
        
    do
      {
        ($t, $m, $xt, $yt) = $self->IntersectionIsolineParameter($x1, $y1, $x2, $y2);
        push( @out, [($t, $m, $xt, $yt)] ) if( defined( $t ) );
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

sub AddIsolineInformation
  {
    my ($self, $blocks, $paramt, $isolinecoef, $estMFa, $estMMiss) = @_;
        
    $self->{ISOPOINTS}{$isolinecoef}{INTERPOLATED_MFA} = $estMFa;
    $self->{ISOPOINTS}{$isolinecoef}{INTERPOLATED_MMISS} = $estMMiss;
        
    foreach my $b ( keys %{ $blocks } ) {
      # Add info of previous in the block id
      $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MFA} = (1-$paramt)*($blocks->{$b}{PREVMFA}) + $paramt*($blocks->{$b}{MFA});
      $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MMISS} = (1-$paramt)*($blocks->{$b}{PREVMMISS}) + $paramt*($blocks->{$b}{MMISS});
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
        
    ## For faster computation;
    $self->{TRIALS}->sortTrials();
        
    if ($self->{STYLE} eq "blocked") {
      $self->{POINTS} = $self->Compute_blocked_DET_points($self->{TRIALS});
    } elsif ($self->{STYLE} eq "pooled") {
      die "Pooled DET curves no longer supported!!!!"
        
        ##              my @targ = ();
        #               my @nontarg = ();
        #               my $omittedTarg = 0;
        #               
        #               foreach my $block(keys %{ $self->{TRIALS}->{'trials'} })
        #               {
        #                       push @targ, @{ $self->{TRIALS}->{'trials'}{$block}{TARG}};      
        #                       push @nontarg, @{ $self->{TRIALS}->{'trials'}{$block}{NONTARG} };
        #                       $omittedTarg += $self->{TRIALS}->{'trials'}{$block}{"OMITTED TARG"};
        #               }
        #
        ##              $self->{TRIALS}->dump(*STDOUT, "");
        #               $self->{POINTS} = $self->Compute_DET_points(0, \@targ, \@nontarg, $self->{TRIALS}->getPooledTotalTrials(), $omittedTarg);
    } else {
      die "Error: DET style $self->{STYLE} not implemented";
    }
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
    
    ### Reduce the block set to only ones with targets and setup the DS!
    foreach $block ($trial->getBlockIDs()) {
      next if ($trial->getNumTarg($block) <= 0);
        
      $numBlocks++;
      $blocks{$block} = { TARGi => 0, NONTARGi => 0, MFA => undef, MMISS => undef, COMB => undef, PREVMFA => undef, PREVMMISS => undef,
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
    
    #    if ($numBlocks <= 1)
    #    {
    #           $self->{MESSAGES} .= "WARNING: '".$self->{TRIALS}->getBlockId()."' weighted DET curves can not be computed with $numBlocks ".$self->{TRIALS}->getBlockId()."s\n";
    #           return undef;
    #    }

    if (!defined($self->{MINSCORE}) || !defined($self->{MAXSCORE})) {
      $self->{MESSAGES} .= "WARNING: '".$self->{TRIALS}->getBlockId()."' weighted DET curves can not be computed, no detection scores exist for block\n";
      return undef;
    }

    #   print "Blocks: '".join(" ",keys %blocks)."'  minScore: $minScore\n";
    my ($mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb) = $self->computeBlockWeighted(\%blocks, $numBlocks, $trial);
    push(@Outputs, [ ( $minScore, $mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb, $numBlocks) ] );

    my $prevMin = $minScore;
    $self->{BESTCOMB}{DETECTIONSCORE} = $minScore;
    $self->{BESTCOMB}{COMB} = $TWComb;
    $self->{BESTCOMB}{MFA} = $mFa;
    $self->{BESTCOMB}{MMISS} = $mMiss;
    
    while ($self->updateMinScoreForBlockWeighted(\%blocks, \$minScore, $trial)) {
      # Add info of previous average
      $previousAvgMfa = $mFa;
      $previousAvgMmiss = $mMiss;
      ($mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb) = $self->computeBlockWeighted(\%blocks, $numBlocks, $trial);
                
      my @listparams = $self->AllIntersectionIsolineParameter($previousAvgMfa, $previousAvgMmiss, $mFa, $mMiss);

      foreach my $setelt ( @listparams ) {
        my ($paramt, $isolinecoef, $estMFa, $estMMiss) = @{ $setelt };                  
        $self->AddIsolineInformation(\%blocks, $paramt, $isolinecoef, $estMFa, $estMMiss) if( defined ( $paramt ) );
      }
                
      push(@Outputs, [ ( $minScore, $mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb, $numBlocks ) ] );

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
    }
    
    \@Outputs;
  }

sub updateMinScoreForBlockWeighted
  {
    my ($self, $blocks, $minScore, $trial) = @_;
    my $change = 0;
        
    #Advance Skipping the min
    foreach $b(keys %$blocks) {
      # Add info of previous in the block id
      $blocks->{$b}{PREVMFA} = $blocks->{$b}{MFA};
      $blocks->{$b}{PREVMMISS} = $blocks->{$b}{MMISS};
        
      while ($blocks->{$b}{TARGi} < $blocks->{$b}{TARGNScr} &&
             $trial->getTargDecScr($b, $blocks->{$b}{TARGi}) <= $$minScore) {
        $blocks->{$b}{MFA} = undef;
        $blocks->{$b}{TARGi} ++;
        $change++;
      }
                
      while ($blocks->{$b}{NONTARGi} < $blocks->{$b}{NONTARGNScr} &&
             $trial->getNonTargDecScr($b,$blocks->{$b}{NONTARGi}) <= $$minScore) {
        $blocks->{$b}{MFA} = undef;
        $blocks->{$b}{NONTARGi} ++;
        $change++;
      }
    }
        
    my $newMin = undef;
    my $dataLeft = 0;
    foreach $b(keys %$blocks) {
      $newMin = $trial->getTargDecScr($b, $blocks->{$b}{TARGi})
        if (($blocks->{$b}{TARGi} < $blocks->{$b}{TARGNScr}) &&
            (!defined($newMin) || $newMin > $trial->getTargDecScr($b, $blocks->{$b}{TARGi})));
                                        
      $newMin = $trial->getNonTargDecScr($b,$blocks->{$b}{NONTARGi})
        if (($blocks->{$b}{NONTARGi} < $blocks->{$b}{NONTARGNScr}) &&
            (!defined($newMin) || $newMin > $trial->getNonTargDecScr($b, $blocks->{$b}{NONTARGi})));
                                        
      $dataLeft = 1 if (($blocks->{$b}{TARGi} < $blocks->{$b}{TARGNScr}) ||
                        ($blocks->{$b}{NONTARGi} < $blocks->{$b}{TARGNScr}));
    }
        
    if (! $dataLeft) {
      # We stepped off the last system output.  Therefore, we need to need to signify it
      $$minScore = undef;
      0;                        ## no change
    } else {
      $$minScore = $newMin if (defined($newMin)); ## Return the prevMin if there was nothing left
      $change;
    }
  }

sub computeBlockWeighted
  {
    my ($self, $blocks, $numBlocks, $trial) = @_;
    my $b = "";
        
    foreach $b (keys %$blocks) {
      if (!defined($blocks->{$b}{MFA})) {
        my $NMiss = $blocks->{$b}{TARGi} + $trial->getNumOmittedTarg($b);
        my $NFalse = $blocks->{$b}{NONTARGNScr} - $blocks->{$b}{NONTARGi};                                                                                                                                   
        ## Caching: Calculate is not yet calculated
        $blocks->{$b}{MMISS} = $NMiss; #$self->{METRIC}->errMissBlockCalc($NMiss, $b);
        $blocks->{$b}{MFA}   = $NFalse; #$self->{METRIC}->errFABlockCalc  ($NFalse, $b);
                        
        ## Cost function
        #                       $blocks->{$b}{COMB} = $self->{METRIC}->combCalc($blocks->{$b}{MMISS}, $blocks->{$b}{MFA});
                        
        #               }
        #               else 
        #               {
        #                       print "$b Computed\n";
      }
    }

    my ($combAvg, $combSSD, $missAvg, $missSSD, $faAvg, $faSSD) = $self->{METRIC}->combBlockSetCalc($blocks);
        
    ($missAvg, $faAvg, $combAvg, $missSSD, $faSSD, $combSSD);
  }

###No Longer supported### sub Compute_DET_points{
###No Longer supported###     my ($self, $presorted, $ra_Targets, $ra_NonTarg, $totalTrials, $omittedTarg) = @_;
###No Longer supported### 
###No Longer supported### #    print "Computing DET #targ=".scalar(@$ra_Targets)." #nontarg=".scalar(@$ra_NonTarg)."\n";
###No Longer supported### 
###No Longer supported###     #
###No Longer supported###     #   Variables
###No Longer supported###     my($PMIN)=0.0005;
###No Longer supported###     my($PMAX)=0.5;
###No Longer supported###     my($SMAX)=9e99;
###No Longer supported###     my(@Outputs) = ();
###No Longer supported###     my(@TARGET) = ();
###No Longer supported###     my(@NONTARGET) = ();
###No Longer supported###     my($Pmiss, $Pfa) = (undef, undef);
###No Longer supported### 
###No Longer supported###     if ($presorted){
###No Longer supported###       @TARGET = @$ra_Targets;
###No Longer supported###       @NONTARGET = @$ra_NonTarg;
###No Longer supported###     } else {
###No Longer supported###       #
###No Longer supported###       #   Sort the target and non-target scores
###No Longer supported###       @TARGET = sort { $a <=> $b } @$ra_Targets;
###No Longer supported###       @NONTARGET = sort { $a <=> $b } @$ra_NonTarg;
###No Longer supported###     }
###No Longer supported###     if (@TARGET > 0 && @NONTARGET > 0){
###No Longer supported###       $self->{MINSCORE} = ($TARGET[0] < $NONTARGET[0]) ? $TARGET[0] : $NONTARGET[0];
###No Longer supported###       $self->{MAXSCORE} = ($TARGET[$#TARGET] > $NONTARGET[$#NONTARGET]) ? $TARGET[$#TARGET] : $NONTARGET[$#NONTARGET];
###No Longer supported###     } else {
###No Longer supported###       $self->{MINSCORE} = ($#TARGET > 0) ? $TARGET[0] : $NONTARGET[0];
###No Longer supported###       $self->{MAXSCORE} = ($#TARGET > 0) ? $TARGET[$#TARGET] : $NONTARGET[$#NONTARGET];
###No Longer supported###     }
###No Longer supported### #    print "MIN is $self->{MINSCORE} max is  $self->{MAXSCORE}\n";
###No Longer supported###     #
###No Longer supported###     #  // Append SMAX to very end 
###No Longer supported###     push(@TARGET,$SMAX);
###No Longer supported###     push(@NONTARGET,$SMAX);
###No Longer supported### 
###No Longer supported###     my $nonTargDenom = (!defined($totalTrials) ? $#NONTARGET : $totalTrials - ($omittedTarg + $#TARGET));
###No Longer supported### 
###No Longer supported###     my ($indTarg, $indNTarg, $score, $value, $NMiss, $NFalse, $NCorr) = (0, 0, 0, 0, 0, 0, 0);
###No Longer supported###     $self->{MAXVALUE}{DETECTIONSCORE} = $self->{MINSCORE};
###No Longer supported###     $self->{MAXVALUE}{VALUE} = 0.0;
###No Longer supported###     $self->{MAXVALUE}{PMISS} = 0.0;
###No Longer supported###     $self->{MAXVALUE}{PFA} = 1.0;
###No Longer supported### #    push(@Outputs, [ ( $self->{MINSCORE}, 0.0, 1.0, 0.0) ] );;
###No Longer supported### #    print "TARG = ".join(" ",@TARGET)."\n";
###No Longer supported### #    print "NONTARG = ".join(" ",@NONTARGET)."\n";
###No Longer supported###     while  ( ($indTarg < $#TARGET) || ($indNTarg < $#NONTARGET)) {
###No Longer supported###       if ( $TARGET[$indTarg] <= $NONTARGET[$indNTarg] && $indTarg < $#TARGET) {
###No Longer supported###           $score = $TARGET[$indTarg];
###No Longer supported###       } else {
###No Longer supported###           $score = $NONTARGET[$indNTarg];
###No Longer supported###       }
###No Longer supported###       $NMiss = $indTarg + $omittedTarg;
###No Longer supported###       $NFalse = $#NONTARGET - $indNTarg;
###No Longer supported###       $NCorr = ($#TARGET+$omittedTarg) - $NMiss;
###No Longer supported###       
###No Longer supported###       $Pmiss = ($#TARGET > 0) ? ($NMiss) / ($omittedTarg + $#TARGET) : 0;
###No Longer supported###       $Pfa = ($#NONTARGET > 0) ? ($NFalse) / $nonTargDenom : 0;
###No Longer supported###       $value = (($self->{VALUE_V} * ($NCorr)) - ($self->{VALUE_C} * ($#NONTARGET - $indNTarg))) / ($self->{VALUE_V} * ($omittedTarg + $#TARGET));
###No Longer supported###       push(@Outputs, [ ( $score, $Pmiss, $Pfa, $value ) ] );;
###No Longer supported###       if ($value > $self->{MAXVALUE}{VALUE}){
###No Longer supported###           $self->{MAXVALUE}{DETECTIONSCORE} = $score;
###No Longer supported###           $self->{MAXVALUE}{VALUE} = $value;
###No Longer supported###           $self->{MAXVALUE}{PFA} = $Pfa;
###No Longer supported###           $self->{MAXVALUE}{PMISS} = $Pmiss;
###No Longer supported###       }
###No Longer supported### #     print "score=$score indNTarg=$indNTarg indTarg=$indTarg omitTarg=$omittedTarg nonTargDen=$nonTargDenom NMiss=$NMiss #false=$NFalse NCorr=$NCorr NonTargDenom=$nonTargDenom PMisss=$Pmiss Pfa=$Pfa\n";
###No Longer supported### 
###No Longer supported###       if ( $TARGET[$indTarg] <= $NONTARGET[$indNTarg] && $indTarg < $#TARGET) {
###No Longer supported###           $indTarg++;
###No Longer supported###       } else {
###No Longer supported###           $indNTarg++;
###No Longer supported###       }
###No Longer supported###       
###No Longer supported###     }
###No Longer supported###     \@Outputs;
###No Longer supported### }

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

sub write_gnuplot_threshold_header{
  my ($self, $FP, $title, $min_x, $max_x) = @_;

  print $FP "## GNUPLOT command file\n";
  print $FP "set terminal postscript color\n";
  print $FP "set data style lines\n";
  print $FP "set key 1,1\n";
  print $FP "set title '$title'\n";
  print $FP "set xlabel 'Detection Score'\n";
  print $FP "set grid\n";

  print $FP "plot [$min_x:$max_x] [0:1] \\\n";
}

sub write_gnuplot_DET_header{
  my($self, $FP, $title, $x_min, $x_max, $y_min, $y_max, $keyLoc, $includeRandom, $xScale, $yScale) = @_;

  my($p_x_min, $p_x_max) = ( ppndf($x_min/100), ppndf($x_max/100) );
  my($p_y_min, $p_y_max) = ( ppndf($y_min/100), ppndf($y_max/100) );
    
  my $ratio = ($p_y_max - $p_y_min) / ($p_x_max - $p_x_min);
    
  print $FP "## GNUPLOT command file\n";
  print $FP "set terminal postscript color\n";
  print $FP "set data style lines\n";
  print $FP "set noxzeroaxis\n";
  print $FP "set noyzeroaxis\n";
  if (defined($keyLoc)) {
    print $FP "set key $keyLoc spacing .5\n";
  }
  if ($xScale eq "nd" && $yScale eq "nd") {
    $ratio = ($p_y_max - $p_y_min) / ($p_x_max - $p_x_min);
    print $FP "set size ratio $ratio\n";
  } elsif ($xScale eq "log" && $yScale eq "log") {
    $ratio = (log($y_max) - log($y_min)) / (log($x_max) - log($x_min));
    print $FP "set size ratio $ratio\n";
  } elsif ($xScale eq "lin" && $yScale eq "lin") {
    $ratio = ($y_max - $y_min) / ($x_max - $x_min);
    print $FP "set size ratio $ratio\n";
  } else {
    print $FP "set size ratio 0.85\n";
  }
  print $FP "set title '$title'\n";
  print $FP "set grid\n";
  print $FP "set pointsize 3\n";
  print $FP "set ylabel '".$self->{METRIC}->errMissLab()." (in ".$self->{METRIC}->errMissUnitLabel().")'\n";
  print $FP "set xlabel '".$self->{METRIC}->errFALab()." (in ".$self->{METRIC}->errFAUnitLabel().")'\n";

  if ($xScale eq "nd") {
    print $FP "set noxtics\n"; 
    &write_tics($FP, 'xtics', $x_min, $x_max);
  } elsif ($xScale eq "log") {
    print $FP "set xtics\n"; 
    print $FP "set logscale x\n"; 
  } else {                      # linear
    print $FP "set xtics\n"; 
  }
  ### Write the tic marks

  if ($yScale eq "nd") {
    print $FP "set noytics\n"; 
    &write_tics($FP, 'ytics', $y_min, $y_max);
  } elsif ($yScale eq "log") {
    print $FP "set ytics\n"; 
    print $FP "set logscale y\n"; 
  } else {                      # linear
    print $FP "set ytics\n"; 
  }
    
  my $xrange = ($xScale eq "nd" ? "[${p_x_min}:${p_x_max}]" : "[${x_min}:${x_max}]");
  my $yrange = ($yScale eq "nd" ? "[${p_y_min}:${p_y_max}]" : "[${y_min}:${y_max}]");
  print $FP "plot $xrange $yrange \\\n";
  print $FP "   -x title 'Random Performance' with lines 1" if ($includeRandom);

}

sub write_tics{ 
  my($FP, $axis, $min, $max) = @_;
  my($lab, $i, $prev) = ("", 0, 0);

  print $FP "set $axis (";
  for ($i=0, $prev=0; $i<= $#tics; $i++) {
    if ($tics[$i] >= $min && $tics[$i] <= $max) {
      print $FP ", " if ($prev > 0);
      print $FP "\\\n    " if (($prev % 5) == 0);
      if ($tics[$i] > 99) {
        $lab = sprintf("%.1f", $tics[$i]);
      } elsif ($tics[$i] >= 1) {
        $lab = sprintf("%d", $tics[$i]);
      } elsif ($tics[$i] >= 0.1) {
        ($lab = sprintf("%.1f", $tics[$i])) =~ s/^0//;
      } elsif ($tics[$i] >= 0.01) {
        ($lab = sprintf("%.2f", $tics[$i])) =~ s/^0//;
      } elsif ($tics[$i] >= 0.001) {
        ($lab = sprintf("%.3f", $tics[$i])) =~ s/^0//;
      } elsif ($tics[$i] >= 0.0001) {
        ($lab = sprintf("%.4f", $tics[$i])) =~ s/^0//;
      } else {
        ($lab = sprintf("%.5f", $tics[$i])) =~ s/^0//;
      }

      printf $FP "'$lab' %.4f",ppndf($tics[$i]/100);
      $prev ++;
    }
  }
  print $FP ")\n";
}

### Options for graphs:
### title  -> the plot title
### noSerialize -> do not write the serialized DET Curves if the element exists
### Xmin -> Set the minimum X coordinate
### Xmax -> Set the maximum X coordinate
### Ymin -> Set the minimum Y coordinate
### Ymax -> Set the maximum Y coordinate
### lTitleNoPointInfo  -> do not write the Max Point Info if the element exisst
### lTitleNoDETType    -> do not write the DET Type if the element exists
### lTitleNoBestComb   -> do not write the Max Value if the element exists
### KeyLoc -> set the key location.  Values can be left | right | top | bottom | outside | below 
### Isolines -> Draw the isolines coefs

### This is NOT an instance METHOD!!!!!!!!!!!!!!
sub writeMultiDetGraph
  {
    ### $options is a pointer to a hash table to tweak the graph
    my ($fileRoot, $detset, $options) = @_;
    
    my $numDET = scalar(@{ $detset->getDETList() });
    return undef if ($numDET < 0);
    
    my ($missStr, $faStr, $combStr) = ( $detset->getDETForID(0)->{METRIC}->errMissLab(), $detset->getDETForID(0)->{METRIC}->errFALab(), 
                                        $detset->getDETForID(0)->{METRIC}->combLab());
    my $combType = ($detset->getDETForID(0)->{METRIC}->combType() eq "minimizable" ? "Min" : "Max");
    my %multiInfo = ();

    #    ### If there's one, do one!!!
    #    if (scalar(@{ $dets }) == 1){
    #      if (! $dets->[0]->writeGNUGraph($fileRoot, $options)){
    #           die "Failed to write single GNUGraph for multidet";
    #      }
    #      $multiInfo{COMBINED_DET_PNG} = "$fileRoot.png";
    #      return \%multiInfo;  
    #    }
    
    ### Use the options
    my $title = "Combined DET Plot";
    my ($xmin, $xmax, $ymin, $ymax, $keyLoc, $Isolines, $Isopoints) = (0.0001, 40, 5, 98, "top", undef, undef);
    my ($gnuplotPROG, $xScale, $yScale, $makePNG, $reportActual) = (undef, "nd", "nd", 1, 1);
    
    if (defined $options) {
      if (exists($options->{yScale})) {
        if ($options->{yScale} eq "nd") {
          $yScale = "nd";         $ymin = 5;   $ymax = 98;
        } elsif ($options->{yScale} eq "log") {
          $yScale = "log";    $ymin = 0.001; $ymax = 100;
        } elsif ($options->{yScale} eq "linear") {
          $yScale = "lin"; $ymin = 0;   $ymax = 100;
        } else {
          print STDERR "Warning: Unknown DET yScale '$options->{yScale}' defaulting to normal deviate\n";
        }
      }    
      if (exists($options->{xScale})) {
        if ($options->{xScale} eq "nd") {
          $xScale = "nd";         $xmin = 0.0001; $xmax = 40;
        } elsif ($options->{xScale} eq "log") {
          $xScale = "log";    $xmin = 0.001;    $xmax = 100;
        } elsif ($options->{xScale} eq "linear") {
          $xScale = "lin"; $xmin = 0;      $xmax = 100;
        } else {
          print STDERR "Warning: Unknown DET xScale '$options->{xScale}' defaulting to normal deviate\n";
        }
      }    

      $title = $options->{title} if (exists($options->{title}));
      $xmin = $options->{Xmin} if (exists($options->{Xmin}));
      $xmax = $options->{Xmax} if (exists($options->{Xmax}));
      $ymin = $options->{Ymin} if (exists($options->{Ymin}));
      $ymax = $options->{Ymax} if (exists($options->{Ymax}));
      $keyLoc = $options->{KeyLoc} if (exists($options->{KeyLoc}));
      $keyLoc = $options->{KeyLoc} if (exists($options->{KeyLoc}));
      $Isolines = $options->{Isolines} if (exists($options->{Isolines}));
      $Isopoints = $options->{Isopoints} if (exists($options->{Isopoints}));
      $makePNG = $options->{BuildPNG} if (exists($options->{BuildPNG}));
      $gnuplotPROG = $options->{gnuplotPROG} if (exists($options->{gnuplotPROG}));
      $reportActual = $options->{ReportActual} if (exists($options->{ReportActual}));
    }

    ### Check the metric types to see if the random curve is defined
    my $includeRandomCurve = 1;
    $includeRandomCurve = 0 if ($detset->getDETForID(0)->{METRIC}->errMissUnit() ne "Prob" || $detset->getDETForID(0)->{METRIC}->errFAUnit() ne "Prob");
    my $needComma = ($includeRandomCurve ? 1 : 0);
        
    ### open  the jointPlot
    #    print "Writing DET to GNUPLOT file $fileRoot.*\n";
    open (MAINPLT,"> $fileRoot.plt") ||
      die("unable to open DET gnuplot file $fileRoot.plt");
    $detset->getDETForID(0)->write_gnuplot_DET_header(*MAINPLT, $title, $xmin, $xmax, $ymin, $ymax, $keyLoc, $includeRandomCurve, $xScale, $yScale);

    my @colors = (1..40);  splice(@colors, 0, 1);

    ### Draw the isolines
    if ( defined($Isolines) && $Isolines == 1 ) {
      my $troot = sprintf( "%s.isolines", $fileRoot );
      my $color = "rgb \"\#DDDDDD\"";
      open( ISODAT, "> $troot" ); 
                
      foreach my $tic_s ( @tics ) {
        if ( ( $tic_s >= $xmin ) && ( $tic_s <= $ymax ) ) {
          my $isocoef = $tic_s/$xmin;
          my $x = $xmin;
                                
          while ( $x <= $xmax ) {
            my $pfa = ppndf( $x/100 );
            my $pmiss = ppndf( $isocoef*$x/100) ;
            printf ISODAT "$pfa $pmiss\n";
                                
            if ( $x < 0.0001 ) {
              $x += 0.000001;
            } elsif ( $x < 0.001  ) {
              $x += 0.00001;
            } elsif ( $x < 0.004  ) {
              $x += 0.00004;
            } elsif ( $x < 0.01   ) {
              $x += 0.0001;
            } elsif ( $x < 0.02   ) {
              $x += 0.0002;
            } elsif ( $x < 0.05   ) {
              $x += 0.0005;
            } elsif ( $x < 0.1    ) {
              $x += 0.001;
            } elsif ( $x < 0.2    ) {
              $x += 0.002;
            } elsif ( $x < 0.5    ) {
              $x += 0.005;
            } elsif ( $x < 1      ) {
              $x += 0.01;
            } elsif ( $x < 2      ) {
              $x += 0.02;
            } elsif ( $x < 5      ) {
              $x += 0.05;
            } else {
              $x += 0.1;
            }
          }
                                
          printf ISODAT "\n";
        }
      }
                
      close( ISODAT );
      if ($needComma) {
        printf MAINPLT ",\\\n";
      }
      printf MAINPLT "  '$troot' title 'isolines' with lines lt $color";
      $needComma = 1;
    }
        
    ### Draw the isopoints
    if ( defined( $Isopoints ) ) {
      my $trootpoints1 = sprintf( "%s.isopoints.1", $fileRoot );
      my $trootpoints2 = sprintf( "%s.isopoints.2", $fileRoot );
      my $trootlines = sprintf( "%s.isopoints.3", $fileRoot );
      my $colorpoints1 = $colors[0];
      my $colorpoints2 = $colors[1];
      my $colorlines = "rgb \"\#333333\"";
      my $isnodiff = 0;
      open( POINTS1DAT, "> $trootpoints1" );
      open( POINTS2DAT, "> $trootpoints2" );
      open( LINESDAT, "> $trootlines" );
                
      foreach my $isoelt ( @{ $Isopoints } ) {
        my @elt = @$isoelt;
                        
        my $x1 = ppndf( $elt[0] );
        my $y1 = ppndf( $elt[1] );
        my $x2 = ppndf( $elt[2] );
        my $y2 = ppndf( $elt[3] );
                        
        printf POINTS1DAT "$x1 $y1\n";
        printf POINTS2DAT "$x2 $y2\n";
                        
        if ( $elt[4] == 1 ) {
          $isnodiff = 1;
          my $t = 0;
                                
          while ( $t <= 1 ) {
            my $x = (1-$t)*$elt[2] + $t*$elt[0];
            my $y = (1-$t)*$elt[3] + $t*$elt[1];
                                
            my $pfa = ppndf( $x );
            my $pmiss = ppndf( $y ) ;
            printf LINESDAT "$pfa $pmiss\n";
                                
            if ( $x < 0.0001 ) {
              $t += 0.0001;
            } elsif ( $x < 0.001  ) {
              $t += 0.001;
            } elsif ( $x < 0.004  ) {
              $t += 0.004;
            } elsif ( $x < 0.01   ) {
              $t += 0.01;
            } elsif ( $x < 0.02   ) {
              $t += 0.02;
            } elsif ( $x < 0.05   ) {
              $t += 0.05;
            } else {
              $t += 0.1;
            }
          }
                                
          printf LINESDAT "\n";
        }
      }
                
      close( POINTS1DAT );
      close( POINTS2DAT );
      close( LINESDAT );
      if ($needComma) {
        printf MAINPLT ",\\\n";
      }
      printf MAINPLT "  '$trootlines' title 'no diff' with lines lt $colorlines" if( $isnodiff );
      printf MAINPLT ",\\\n  '$trootpoints1' notitle with points lt $colorpoints1 pt 6 ps 1";
      printf MAINPLT ",\\\n  '$trootpoints2' notitle with points lt $colorpoints2 pt 6 ps 1";
      $needComma = 1;
    }
        
    ### Write Individual Dets
    for (my $d=0; $d < $numDET; $d++) {
#      my $troot = sprintf("%s.sub%02d",$fileRoot,$d);
       my $troot = sprintf("%s.%s",$fileRoot, $detset->getFSKeyForID($d));
      my ($actComb, $actCombSSD, $actMiss, $actMissSSD, $actFa, $actFaSSD) = $detset->getDETForID($d)->getMetric()->getActualDecisionPerformance();
                
      if ($detset->getDETForID($d)->writeGNUGraph($troot, $options)) {
        #                       my $typeStr = ($dets->[$d]->{STYLE} eq "pooled" ? 
        #                                  "Pooled ".$dets->[$d]->{TRIALS}->getBlockId()." ".$dets->[$d]->{TRIALS}->getDecisionId() :
        #                                  $dets->[$d]->{TRIALS}->getBlockId()." Wtd.");
        my ($scr, $comb, $miss, $fa) = ($detset->getDETForID($d)->getBestCombDetectionScore(),
                                        $detset->getDETForID($d)->getBestCombComb(),
                                        $detset->getDETForID($d)->getBestCombMMiss(),
                                        $detset->getDETForID($d)->getBestCombMFA());
                        
        my $ltitle = "";
        #                       $ltitle .= $typeStr if (! (defined($options) && exists($options->{lTitleNoDETType})));
        $ltitle .= " ".$detset->getDETForID($d)->{LINETITLE};
        $ltitle .= " ".sprintf("$combType $combStr=%.3f", $comb) if (! (defined($options) && exists($options->{lTitleNoBestComb})));
        $ltitle .= sprintf("=($faStr=%.6f, $missStr=%.4f, scr=%.3f)", $fa, $miss, $scr) if (! (defined($options) && exists($options->{lTitleNoPointInfo})));
        if ($needComma) {
          printf MAINPLT ",\\\n";
        }
                    
        my $xcol = ($xScale eq "nd" ? "3" : "5");
        my $ycol = ($yScale eq "nd" ? "2" : "4");
        printf MAINPLT "  '$troot.dat.1' using $xcol:$ycol title '$ltitle' with lines $colors[$d]";
        $xcol = ($xScale eq "nd" ? "6" : "4");
        $ycol = ($yScale eq "nd" ? "5" : "3");
        printf MAINPLT ",\\\n  '$troot.dat.2' using $xcol:$ycol notitle with points lc $colors[$d] pt 7";

        if ($reportActual){
          $xcol = ($xScale eq "nd" ? "11" : "9");
          $ycol = ($yScale eq "nd" ? "10" : "8");
          printf MAINPLT ", \\\n    '$troot.dat.2' using $xcol:$ycol title 'Actual ".sprintf("$combStr=%.3f", $actComb)."' with points lc $colors[$d] pt 6";
        }
        $needComma = 1;
      }
    }
        
    print MAINPLT "\n";
    
    close MAINPLT;
    if ($makePNG) {
      $multiInfo{COMBINED_DET_PNG} = "$fileRoot.png";
      buildPNG($fileRoot, (exists($options->{gnuplotPROG}) ? $options->{gnuplotPROG} : undef));
    }
    \%multiInfo;
  }

sub writeGNUGraph{
  my ($self, $fileRoot, $options) = @_;
  my ($missStr, $faStr, $ combStr) = ( $self->{METRIC}->errMissLab(), $self->{METRIC}->errFALab(), $self->{METRIC}->combLab());
  my $combType = ($self->{METRIC}->combType() eq "minimizable" ? "Min" : "Max");
  $self->computePoints();

  if (!defined($self->{POINTS})) {
    print STDERR "WARNING: Writing DET plot to $fileRoot.* failed.  Points not computed\n";
    return 0;
  }

  #    my $typeStr = ($self->{STYLE} eq "pooled" ? "Pooled ".$self->{TRIALS}->getBlockId()." ".$self->{TRIALS}->getDecisionId() : 
  #                $self->{TRIALS}->getBlockId()." Wtd.");
  #    my $title = $typeStr . " Detection Error Tradeoff Curve"; 
  my $title = "Detection Error Tradeoff Curve"; 
  my ($xmin, $xmax, $ymin, $ymax, $keyLoc, $makePNG) = (0.0001, 40, 5, 98, "top", 1);
  my ($gnuplotPROG, $xScale, $yScale, $reportActual) = (undef, "nd", "nd", 1);
  if (defined $options) {
    $title = $options->{title} if (exists($options->{title}));

    if (exists($options->{yScale})) {
      if ($options->{yScale} eq "nd") {
        $yScale = "nd";         $ymin = 5;   $ymax = 98;
      } elsif ($options->{yScale} eq "log") {
        $yScale = "log";    $ymin = 0.001; $ymax = 100;
      } elsif ($options->{yScale} eq "linear") {
        $yScale = "lin"; $ymin = 0;   $ymax = 100;
      } else {
        print STDERR "Warning: Unknown DET yScale '$options->{yScale}' defaulting to normal deviate\n";
      }
    }    
    if (exists($options->{xScale})) {
      if ($options->{xScale} eq "nd") {
        $xScale = "nd";         $xmin = 0.0001; $xmax = 40;
      } elsif ($options->{xScale} eq "log") {
        $xScale = "log";    $xmin = 0.001;    $xmax = 100;
      } elsif ($options->{xScale} eq "linear") {
        $xScale = "lin"; $xmin = 0;      $xmax = 100;
      } else {
        print STDERR "Warning: Unknown DET xScale '$options->{xScale}' defaulting to normal deviate\n";
      }
    }    

    $xmin = $options->{Xmin} if (exists($options->{Xmin}));
    $xmax = $options->{Xmax} if (exists($options->{Xmax}));
    $ymin = $options->{Ymin} if (exists($options->{Ymin}));
    $ymax = $options->{Ymax} if (exists($options->{Ymax}));
    $keyLoc = $options->{KeyLoc} if (exists($options->{KeyLoc}));
    $makePNG = $options->{BuildPNG} if (exists($options->{BuildPNG}));
    $gnuplotPROG = $options->{gnuplotPROG} if (exists($options->{gnuplotPROG}));
    $reportActual = $options->{ReportActual} if (exists($options->{ReportActual}));
  }    
    
  ### Serialize the file for later usage
  $self->serialize("$fileRoot.srl") unless (defined $options && exists($options->{noSerialize}));

  ### Check the metric types to see if the random curve is defined
  my $includeRandomCurve = 1;
  $includeRandomCurve = 0 if ($self->{METRIC}->errMissUnit() ne "Prob" || $self->{METRIC}->errFAUnit() ne "Prob");
        
  #    print "Writing DET to GNUPLOT file $fileRoot.*\n";
  open(PLT,"> $fileRoot.plt") ||
    die("unable to open DET gnuplot file $fileRoot.plt");
  open(THRESHPLT,"> $fileRoot.thresh.plt") ||
    die("unable to open DET gnuplot file $fileRoot.thresh.plt");
  $self->write_gnuplot_DET_header(*PLT, $title, $xmin, $xmax, $ymin, $ymax, $keyLoc, $includeRandomCurve, $xScale, $yScale);

  ### The line data file
  my $withErrorCurve = 1;
  open(DAT,"> $fileRoot.dat.1") ||
    die("unable to open DET gnuplot file $fileRoot.dat.1"); 
  print DAT "# DET Graph made by DETCurve\n";
  print DAT "# Trial Params = ".($self->{TRIALS}->getMetricParamsStr())."\n";
  print DAT "# Metric Params = ".($self->{METRIC}->getParamsStr(""))."\n";
  #    print DAT "# DET Type: $typeStr\n";
  if ($self->{STYLE} eq "pooled") {
    $withErrorCurve = 0;
    print DAT "# score ppndf($missStr) ppndf($faStr) $missStr $faStr $combStr\n";
    for (my $i=0; $i<@{ $self->{POINTS} }; $i++) {
      print DAT $self->{POINTS}[$i][0]." ".
        ppndf($self->{POINTS}[$i][1])." ".
          ppndf($self->{POINTS}[$i][2])." ".
            $self->{POINTS}[$i][1]." ".
              $self->{POINTS}[$i][2]." ".
                $self->{POINTS}[$i][3]."\n";
    }
  } else {
    print DAT "# Abbreviations: ssd() is the sample Standard Deviation of a Variable\n";
    print DAT "#                ppndf() is the normal deviant of a probability. ppndf(.5)=0\n"; 
    print DAT "#                -2SE(v) is v - 2(StandardError(v)) = v - 2 * (sampleStandardDev / sqrt(n-1)\n";
    print DAT "#                        the value \"NA\" is used when n <= 1\n"; 
    print DAT "# 1:score 2:ppndf($missStr) 3:ppndf($faStr) 4:$missStr 5:$faStr 6:$combStr 7:ppndf(-2SE($missStr)) 8:ppndf(-2SE($faStr)) 9:ppndf(+2SE($missStr)) 10:ppndf(+2SE($faStr)) 11:-2SE($missStr) 12:-2SE($faStr) 13:+2SE($missStr) 14:+2SE($faStr) 15:SE($combStr)\n";
    for (my $i=0; $i<@{ $self->{POINTS} }; $i++) {
      print DAT $self->{POINTS}[$i][0]." ".
        ppndf($self->{POINTS}[$i][1])." ".
          ppndf($self->{POINTS}[$i][2])." ".
            $self->{POINTS}[$i][1]." ".
              $self->{POINTS}[$i][2]." ".
                $self->{POINTS}[$i][3]." ".
                  (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ppndf($self->{POINTS}[$i][1] - 2*($self->{POINTS}[$i][4] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                    (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ppndf($self->{POINTS}[$i][2] - 2*($self->{POINTS}[$i][5] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                      (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ppndf($self->{POINTS}[$i][1] + 2*($self->{POINTS}[$i][4] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                        (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ppndf($self->{POINTS}[$i][2] + 2*($self->{POINTS}[$i][5] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                          (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ($self->{POINTS}[$i][1] - 2*($self->{POINTS}[$i][4] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                            (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ($self->{POINTS}[$i][2] - 2*($self->{POINTS}[$i][5] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                              (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ($self->{POINTS}[$i][1] + 2*($self->{POINTS}[$i][4] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                                (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ($self->{POINTS}[$i][2] + 2*($self->{POINTS}[$i][5] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                                  (($self->{POINTS}[$i][7]-1 <= 0) ? "NA" : ($self->{POINTS}[$i][2] - 2*($self->{POINTS}[$i][6] / sqrt($self->{POINTS}[$i][7]-1))))." ".
                                    "\n";
      $withErrorCurve = 0 if ($self->{POINTS}[$i][7]-1 <= 0)
    }
  }
  close DAT;
    
  ### The points data file
  open(DAT,"> $fileRoot.dat.2") ||
    die("unable to open DET gnuplot file $fileRoot.dat.2"); 
  print DAT "# Points for DET Graph made by DETCurve\n";
  #     print DAT "# DET Type: $typeStr\n";
  print DAT "# 1:Best${combStr}DetectionScore 2:Best${combStr}Value 3:Best$missStr 4:Best$faStr 5:ppndf(Best$missStr) 6:ppndf(Best$faStr) 7:ActualComb 8:Actual$missStr 9:Actual$faStr 10:ppndf(Actual$missStr) 11:ppndf(Actual$faStr)\n";
  my ($scr, $comb, $miss, $fa) = ($self->getBestCombDetectionScore(),
                                  $self->getBestCombComb(),
				  $self->getBestCombMMiss(),
				  $self->getBestCombMFA());
  my ($actComb, $actCombSSD, $actMiss, $actMissSSD, $actFa, $actFaSSD) = $self->{METRIC}->getActualDecisionPerformance();
  print DAT "$scr $comb $miss $fa ".ppndf($miss)." ".ppndf($fa)." $actComb $actMiss $actFa ".ppndf($actMiss)." ".ppndf($actFa)."\n";
  close DAT; 
  my $ltitle = "$self->{LINETITLE}";
  $ltitle .= sprintf(" $combType $combStr=%.3f", $comb)
    if (! (defined($options) && exists($options->{lTitleNoBestComb})));
  $ltitle .= sprintf(" ($faStr=%.6f, $missStr=%.4f, scr=%.3f)", $fa, $miss, $scr)
    if (! (defined($options) && exists($options->{lTitleNoPointInfo})));
    
  my $xcol = ($xScale eq "nd" ? "3" : "5");
  my $ycol = ($yScale eq "nd" ? "2" : "4");
  print PLT ",\\\n" if ($includeRandomCurve);
  printf PLT "    '$fileRoot.dat.1' using $xcol:$ycol title '$ltitle' with lines 2";
  $xcol = ($xScale eq "nd" ? "6" : "4");
  $ycol = ($yScale eq "nd" ? "5" : "3");
  printf PLT ", \\\n    '$fileRoot.dat.2' using $xcol:$ycol notitle with points lc 2 pt 7";
  if ($reportActual){
    $xcol = ($xScale eq "nd" ? "11" : "9");
    $ycol = ($yScale eq "nd" ? "10" : "8");
    printf PLT ", \\\n    '$fileRoot.dat.2' using $xcol:$ycol title 'Actual ".sprintf("$combStr=%.3f", $actComb)."' with points lc 2  pt 6";
  }
  if ($withErrorCurve) {
    $xcol = ($xScale eq "nd" ? "8" : "12");
    $ycol = ($yScale eq "nd" ? "7" : "13");
    printf PLT ", \\\n    '$fileRoot.dat.1' using $xcol:$ycol title '+/- 2 Standard Error' with lines 3"; 
    $xcol = ($xScale eq "nd" ? "10" : "14");
    $ycol = ($yScale eq "nd" ? "9" : "13");
    printf PLT ", \\\n    '$fileRoot.dat.1' using $xcol:$ycol notitle with lines 3";
  }
  print PLT "\n";
  close PLT;
  if ($makePNG) {
    buildPNG($fileRoot, $gnuplotPROG);
    $self->{LAST_GNU_DETFILE_PNG} = "$fileRoot.png";
  }
    
  my $pad = 0.00;
  if ($self->{MINSCORE} == $self->{MAXSCORE}) {
    $pad = 0.000001;
  }
  #    $self->write_gnuplot_threshold_header(*THRESHPLT, "$typeStr Threshold Plot for $self->{LINETITLE}", $self->{MINSCORE}-$pad, $self->{MAXSCORE}+$pad);
  $self->write_gnuplot_threshold_header(*THRESHPLT, "Threshold Plot for $self->{LINETITLE}", $self->{MINSCORE}-$pad, $self->{MAXSCORE}+$pad);
  print THRESHPLT "  '$fileRoot.dat.1' using 1:4 title '$missStr' with lines 2, \\\n";
  print THRESHPLT "  '$fileRoot.dat.1' using 1:5 title '$faStr' with lines 3, \\\n";
  print THRESHPLT "  '$fileRoot.dat.1' using 1:6 title '$combStr' with lines 4";
  if ($reportActual){
    print THRESHPLT ", \\\n  $actComb title 'Actual $combStr ".sprintf("%.3f",$actComb)."' with lines 5";
  }
  if (defined($self->getBestCombComb())) {
    print THRESHPLT ", \\\n  '$fileRoot.dat.2' using 1:2 title '$combType $combStr ".sprintf("%.3f, scr %.3f",$comb,$scr)."' with points 6";
    print THRESHPLT ", \\\n  ".$self->getBestCombComb()." title '$combType $combStr' with lines 6";
  }
  print THRESHPLT "\n";
  close THRESHPLT;
  if ($makePNG) {
    buildPNG($fileRoot.".thresh", $gnuplotPROG);
    $self->{LAST_GNU_THRESHPLOT_PNG} = "$fileRoot.thresh.png";
  }
  1;
}

## This is NOT and instance method
### To see the test pattern: (echo set terminal png medium size 600,400; echo test) | gnuplot > foo.png
sub buildPNG
  {
    my ($fileRoot, $gnuplot) = @_;

    $gnuplot = "gnuplot" if (!defined($gnuplot));
    
    ## Use this with gnuplot 3.X
    #	system("cat $fileRoot.plt | perl -pe \'\$_ = \"set terminal png medium \n\" if (\$_ =~ /set terminal/)\' | gnuplot > $fileRoot.png");
    system("cat $fileRoot.plt | perl -pe \'\$_ = \"set terminal png medium size 768,2048 crop\n\" if (\$_ =~ /set terminal/)\' | $gnuplot > $fileRoot.png");
  }

1;
