# F4DE Package
# DETCurve.pm
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
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package DETCurve;

use strict;
use TrialsFuncs;

use MetricFuncs;
use MetricTestStub;
use MetricTV08;
use MetricNormLinearCostFunct;

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
       SYSTEMDECISIONVALUE => undef, ### this is the value based on the system's hard decisions
       POINTS => undef, ## 2D array (score, Mmiss, Mfa, comb);  IF style is blocked, then (sampleStandardDev(Mmiss), ssd(Mfa), ssd(ssdComb), $numBlocks) 
       LAST_GNU_DETFILE_PNG => "",
       LAST_GNU_THRESHPLOT_PNG => "",
       LAST_SERIALIZED_DET => "",
       MESSAGES => "",
       ISOLINE_COEFFICIENTS => [ sort {$a <=> $b} @$listIsolineCoef],
       ISOLINE_COEFFICIENTS_INDEX => 0,         
       ISOPOINTS => {},
       GZIPPROG => (defined($gzipPROG) ? $gzipPROG : "gzip"),
       EVALSTRUCT => (defined($evalstruct)) ? 1 : 0,
       POINT_COMPUTATION_ATTEMPTED => 0,
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
    my $tmp = "/tmp/serialize";
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

sub bigDETUnitTest {
  printf("Running a series of large DET Curves\n");
  my ($doProfile) = 0;
  
 foreach my $size(10000, 100000, 1000000, 3000000, 6000000, 8000000, 10000000){
#  foreach my $size(2000000, 5000000, 10000000){
#  foreach my $size(1000003){
    system "/home/fiscus/Projects/STD/STDEval/tools/ProcGragh/ProcGraph.pl --cumul --Tree --outdir /tmp --filebase BigDet.$size -- ".
          " perl ".($doProfile ? "-d:DProf" : "")." -I . -e 'use DETCurve; DETCurve::oneBigDET(\"/tmp/BigDet.$size\", $size)'"; 
#    print "\n";
  }
}

sub oneBigDET
  {
   my ($root, $nt) = @_;

    print " Computing big DET Curve... ".($nt)." trials\n";
    my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
    
    #####################################  Without data  ###############################    
    my $emptyTrial = new TrialsFuncs({ ("TOTALTRIALS" => $nt) },
                                     "Term Detection", "Term", "Occurrence");

    print "   ... adding trials\n";
    for (my $i=0; $i<$nt/2; $i++){
    	my $r = (($i % 1000)  == 0 ? 0.5 : rand());
    	$emptyTrial->addTrial("he", $r, ($r < 0.5 ? "NO" : "YES"), 1);
      $r = (($i % 1000)  == 0 ? 0.5 : rand());
      $emptyTrial->addTrial("he", $r, ($r < 0.5 ? "NO" : "YES"), 0);
    	print "   Made trials < ".(2*$i)."\n" if ($i*2 % 1000000 == 0); 
    }
    
    my $met = new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $emptyTrial);
    if (ref($met) ne "MetricTestStub") {
      die "Error: Unable to create a MetricTestStub object with message '$met'\n";
    }
    
    my $emptydet = new DETCurve($emptyTrial, $met, "footitle", \@isolinecoef, undef);
    use DETCurveSet;
    my $ds = new DETCurveSet("title");
    $ds->addDET("Biggy", $emptydet);
#    my %ht = ("createDETfiles", 1, "serialize", 0);
    my %ht = ("createDETfiles", 1);
    print $ds->renderAsTxt($root, 1, 1, \%ht);
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
    push @points, [ (0.41,  0.583, 0.444, -443.983, 0.382,    0.096,   96.288,   3) ];
    push @points, [ (0.5, 0.667, 0.403, -402.404, 0.382,    0.087,   86.407,   3) ];
    push @points, [ (0.51,  0.667, 0.347, -346.854, 0.382,    0.024,   24.344,   3) ];
    push @points, [ (0.6, 0.667, 0.250, -249.642, 0.382,    0.083,   83.076,   3) ];
    push @points, [ (0.61,  0.667, 0.194, -194.092, 0.382,    0.048,   48.397,   3) ];
    push @points, [ (0.7, 0.667, 0.097,  -96.879, 0.382,    0.087,   86.568,   3) ];
    push @points, [ (0.8,  0.833, 0.056,  -55.383, 0.289,    0.096,   95.927,   3) ];
    push @points, [ (0.9,  0.833, 0.000,    0.167, 0.289,    0.000,    0.289,   3) ];
    push @points, [ (1.0,  0.917, 0.000,    0.083, 0.144,    0.000,    0.144,   3) ];
    print " Checking the number of points...";
    die "Error: Number of computed DET points not correct.  Expected ".scalar(@points)." != ".scalar(@{ $blockdet->{POINTS} })."\n" 
      if (@points != @{ $blockdet->{POINTS} });
    print "  Ok\n";
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
    my ($self, $file) = @_;
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
 
    if ( ( $file =~ /.+\.gz$/ ) && ( -e $file ) && ( -f $file ) && ( -r $file ) ) {
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

    ### If it's a binary we're going to have to parse it.
    if ($binary) {
      @arr = MMisc::unmarshal_matrix($marshal_str);
      $VAR1->{"POINTS"} = \@arr;
    }

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

sub getSerializedDET(){
  my ($self) = @_;
  $self->{LAST_SERIALIZED_DET};
}

sub getPoints(){
  my ($self) = @_;
  $self->computePoints();
  (exists($self->{POINTS}) ? $self->{POINTS} : undef); 
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

    #print "[*] Entered 'computePoints'\n";
        
    ## For faster computation;
    $self->{TRIALS}->sortTrials();
        
    $self->{POINTS} = $self->Compute_blocked_DET_points($self->{TRIALS});

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
      my ($mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb) = $self->computeBlockWeighted(\%blocks, $numBlocks, $trial);
      push(@Outputs, [ ( "NaN", $mMiss, $mFa, $TWComb, $ssdMMiss, $ssdMFa, $ssdComb, $numBlocks) ] );

      $self->{BESTCOMB}{DETECTIONSCORE} = "NaN";
      $self->{BESTCOMB}{COMB} = $TWComb;
      $self->{BESTCOMB}{MFA} = $mFa;
      $self->{BESTCOMB}{MMISS} = $mMiss;

      $self->{MESSAGES} .= "WARNING: '".$self->{TRIALS}->getBlockId()."' weighted DET curves can not be computed, no detection scores exist for block\n";

      return \@Outputs;
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
        $self->AddIsolineInformation(\%blocks, $paramt, $isolinecoef, $estMFa, $estMMiss, $minScore) if( defined ( $paramt ) );
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
                        ($blocks->{$b}{NONTARGi} < $blocks->{$b}{NONTARGNScr}));
                        
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
      }
    }

    my ($combAvg, $combSSD, $missAvg, $missSSD, $faAvg, $faSSD) = $self->{METRIC}->combBlockSetCalc($blocks);
        
    ($missAvg, $faAvg, $combAvg, $missSSD, $faSSD, $combSSD);
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

    if ($a->{DET}->getMaximizable()) {
        return $b_score <=> $a_score; 
    } else {
        return $a_score <=> $b_score; 
    }
}

sub compareBest ($$) {
    my ($a, $b) = @_;

    if ($a->{DET}->getMaximizable()) {
        return $b->{DET}->getBestCombComb() <=> $a->{DET}->getBestCombComb();
    } else {
        return $a->{DET}->getBestCombComb() <=> $b->{DET}->getBestCombComb();
    }
}

1;
