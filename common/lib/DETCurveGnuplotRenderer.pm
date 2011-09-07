# F4DE
# DETCurveGnuplotRenderer.pm
# Author: Jon Fiscus, Jerome Ajot
# Testers: George Doddington.
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

package DETCurveGnuplotRenderer;

use strict;

use MMisc;

use TrialsFuncs;
use MetricFuncs;
use MetricTestStub;
use Data::Dumper;
use DETCurveSet;
use PropList;
use DETCurve;


my $bvc = "bmargin vertical center";
my $bvh = "bmargin horizontal center";

sub new
  {
    my ($class, $options) = @_;
        
    my $self = { 
      ### The Graphics Context.  This contains ALL the options
       props => _initProps(),
       
       DrawIsoratiolines => 0,
       DrawIsometriclines => 0,
       Isoratiolines => undef,  ### Coefficients
       Isometriclines => undef, ### Coefficients
       Isopoints => undef,
       title => "DET Plot",
       gnuplotPROG => undef,
       makePNG => 1,
       DETShowPoint_Actual => 1,
       PointSet => undef,
#       PerfBox => undef,
       DETLineAttr => undef,
       # Control the values on the DET Lines
       DETShowPoint_Actual => 0,
       DETShowPoint_Best => 0,
       DETShowPoint_Ratios => 0,
       DETShowPoint_SupportValues => [ ('C', 'M', 'F', 'T')],
       
       serialize => 1,
       BuildPNG => 1,
       HD => 0,
       AutoAdapt => 0,
                
       ### Display ranges
       Bounds => { xmin => { disp => undef, req => undef, metric => undef} ,
                   xmax => { disp => undef, req => undef, metric => undef} ,
                   ymin => { disp => undef, req => undef, metric => undef} ,
                   ymax => { disp => undef, req => undef, metric => undef}  },
       
       ### Default color props
       pointSize => 2,
       pointTypes =>  [ [ (6, 7) ], [ (4, 5) ], [ (8, 9) ], [ (10, 11) ], [ (12, 13) ] ],
       colorsRGB => [ (2..100) ],
       lineWidths => [ ( 1, 3, 5) ],
       
       NDtics => [ (0.00001, 0.0001, 0.001, 0.004, .01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 40, 60, 80, 90, 95, 98, 99, 99.5, 99.9) ],
    };  
    bless $self;
    $self->_setDefaultRanges();  
    $self->_parseOptions($options);
        
    return $self;
  }

sub _initProps{
  my $props = new PropList();
  die "Error making a proplist for the DETCurveGnuplotRenderer /".$props->get_errormsg()."/"  if ($props->error());
  die "Failed to add property xScale" unless ($props->addProp("xScale", "nd", ("nd", "log", "linear")));
  die "Failed to add property yScale" unless ($props->addProp("yScale", "nd", ("nd", "log", "linear")));
  die "Failed to add property FAUnit" unless ($props->addProp("FAUnit", "Prob", ("Prob", "Rate")));
  die "Failed to add property ColorScheme" unless ($props->addProp("ColorScheme", "color", ("color", "grey")));
  die "Failed to add property MissUnit" unless ($props->addProp("MissUnit", "Prob", ("Prob", "Rate")));
  die "Failed to add property KeySpacing" unless ($props->addProp("KeySpacing", "0.7", ()));
  die "Failed to add property KeyLoc" unless ($props->addProp("KeyLoc", "top", ("left", "right", "center", "top", "bottom", "outside", "below",
                                                              "left top",    "center top",    "right top",
                                                              "left center", "center center", "right center",
                                                              "left bottom", "center bottom", "right bottom")));
  die "Failed to add property PointSetAreaDefinition" unless ($props->addProp("PointSetAreaDefinition", "Radius", ("Area", "Radius")));
  
  $props;
}

sub _setDefaultRanges{
  my ($self) = @_;
  
  if ($self->{props}->getValue("yScale") eq "nd") {
    $self->{Bounds}{ymin}{disp} = 5;   $self->{Bounds}{ymax}{disp} = 98;
  } elsif ($self->{props}->getValue("yScale") eq "log") {
    $self->{Bounds}{ymin}{disp} = 0.001; $self->{Bounds}{ymax}{disp} = 100; 
  } elsif ($self->{props}->getValue("yScale") eq "linear") {
    $self->{Bounds}{ymin}{disp} = 0;   $self->{Bounds}{ymax}{disp} = 100;      
  }

  if ($self->{props}->getValue("xScale") eq "nd") {
     $self->{Bounds}{xmin}{disp} = 0.0001;  $self->{Bounds}{xmax}{disp} = 40;
  } elsif ($self->{props}->getValue("xScale") eq "log") {
     $self->{Bounds}{xmin}{disp} = 0.001;   $self->{Bounds}{xmax}{disp} = 100; 
  } elsif ($self->{props}->getValue("xScale") eq "linear") {
     $self->{Bounds}{xmin}{disp} = 0;       $self->{Bounds}{xmax}{disp} = 100;      
  }    
}

sub _extractMetricProps{
  my ($self, $metric) = @_;
  
  die "Failed to add property FAUnit" unless ($self->{props}->setValue("FAUnit", $metric->errFAUnit()));
  die "Failed to add property MissUnit" unless ($self->{props}->setValue("MissUnit", $metric->errMissUnit()));

  $self->_setComputedProps();
}

sub _setComputedProps{
  my ($self) = @_;

  $self->{Bounds}{xmin}{disp} = MMisc::max($self->{Bounds}{xmin}{req}, 0) if (defined($self->{Bounds}{xmin}{req}));
  $self->{Bounds}{ymin}{disp} = MMisc::max($self->{Bounds}{ymin}{req}, 0) if (defined($self->{Bounds}{ymin}{req}));
  
  if (defined($self->{Bounds}{xmax}{req})){
    if (($self->{props}->getValue("FAUnit") eq "Prob") && $self->{props}->getValue("xScale") eq "nd"){
       $self->{Bounds}{xmax}{disp} = (MMisc::min($self->{Bounds}{xmax}{req}, 100));
    } elsif ($self->{props}->getValue("FAUnit") eq "Prob"){
       $self->{Bounds}{xmax}{disp} = (MMisc::min($self->{Bounds}{xmax}{req}, 1));
    } else {
       $self->{Bounds}{xmax}{disp} = $self->{Bounds}{xmax}{req};
    }
  }
  
  if (defined($self->{Bounds}{ymax}{req})){
    if ($self->{props}->getValue("MissUnit") eq "Prob" && $self->{props}->getValue("yScale") eq "nd"){
      $self->{Bounds}{ymax}{disp} = (MMisc::min($self->{Bounds}{ymax}{req}, 100));
    } elsif ($self->{props}->getValue("MissUnit") eq "Prob"){
      $self->{Bounds}{ymax}{disp} = (MMisc::min($self->{Bounds}{ymax}{req}, 1));
    } else {
      $self->{Bounds}{ymax}{disp} = $self->{Bounds}{ymax}{req};
    }
  }

  ### These are in metric Scale 
  $self->{Bounds}{xmin}{metric} = ($self->{props}->getValue("FAUnit") eq "Prob" && 
                                   $self->{props}->getValue("xScale") eq "nd") ? ($self->{Bounds}{xmin}{disp}/100) : $self->{Bounds}{xmin}{disp};
  $self->{Bounds}{xmax}{metric} = ($self->{props}->getValue("FAUnit") eq "Prob" &&
                                   $self->{props}->getValue("xScale") eq "nd") ? ($self->{Bounds}{xmax}{disp}/100) : $self->{Bounds}{xmax}{disp};
  $self->{Bounds}{ymin}{metric} = ($self->{props}->getValue("MissUnit") eq "Prob" && 
                                   $self->{props}->getValue("yScale") eq "nd") ? ($self->{Bounds}{ymin}{disp}/100) : $self->{Bounds}{ymin}{disp};
  $self->{Bounds}{ymax}{metric} = ($self->{props}->getValue("MissUnit") eq "Prob" &&
                                   $self->{props}->getValue("yScale") eq "nd") ? ($self->{Bounds}{ymax}{disp}/100) : $self->{Bounds}{ymax}{disp};

}

sub _parseOptions{
  my ($self, $options) = @_;
  
  return unless (defined $options);

  if (exists($options->{HD})){
    $self->{HD} = $options->{HD};
  }

  if (exists($options->{AutoAdapt})){
    $self->{AutoAdapt} = $options->{AutoAdapt};
  }
  
  if (exists($options->{yScale})) {
    if (! $self->{props}->setValue("yScale", $options->{"yScale"})){
      die "Error: DET option yScale illegal. ".$self->{props}->get_errormsg();
    }
  }  
  if (exists($options->{xScale})) {
    if (! $self->{props}->setValue("xScale", $options->{"xScale"})){
      die "Error: DET option xScale illegal. ".$self->{props}->get_errormsg();
    }
  }  

  $self->_setDefaultRanges();

  if (exists($options->{PointSet})){
    $self->{PointSet} = $options->{PointSet};
    ### This needs validation
  }

  if (exists($options->{PerfBox})){
    $self->{PerfBox} = $options->{PerfBox};
#    print MMisc::get_sorted_MemDump($self->{PerfBox}) . "\n";
    ### This needs validation
  }
  if (exists($options->{PointSetAreaDefinition})){
    if (! $self->{props}->setValue("PointoSetAreaDefinition", $options->{"PointSetAreaDefinition"})){
      die "Error: DET option PointSetAreaDefinition illegal. ".$self->{props}->get_errormsg();
    }
  }  
  if (exists($options->{DETLineAttr})){
    $self->{DETLineAttr} = $options->{DETLineAttr};
    ### This needs validation
  }
  if (exists($options->{gnuplotPROG})){
    $self->{gnuplotPROG} = $options->{gnuplotPROG};
    ### This needs validation
  }
  
  $self->{serialize} = $options->{serialize} 
    if (exists($options->{serialize}));
  
  $self->{BuildPNG} = $options->{BuildPNG} if (exists($options->{BuildPNG}));

  $self->{Bounds}{xmin}{req} = $options->{Xmin} if (exists($options->{Xmin}));
  $self->{Bounds}{xmax}{req} = $options->{Xmax} if (exists($options->{Xmax}));
  $self->{Bounds}{ymin}{req} = $options->{Ymin} if (exists($options->{Ymin}));
  $self->{Bounds}{ymax}{req} = $options->{Ymax} if (exists($options->{Ymax}));

  $self->{title} = $options->{title} if (exists($options->{title}));

  if (exists($options->{KeyLoc})){
    if (! $self->{props}->setValue("KeyLoc", $options->{KeyLoc})){
      die "Error: DET option KeyLoc illegal. ".$self->{props}->get_errormsg();
    }
  }
  
  if (exists($options->{KeySpacing})){
    if (! $self->{props}->setValue("KeySpacing", $options->{KeySpacing})){
      die "Error: DET option KeySpacing illegal. ".$self->{props}->get_errormsg();
    }
  }
  
  ### Controls the point statistics plotted on the DET Curve
  $self->{DETShowPoint_Actual} = $options->{DETShowPoint_Actual} if (exists($options->{DETShowPoint_Actual}));
  $self->{DETShowPoint_Best}   = $options->{DETShowPoint_Best}   if (exists($options->{DETShowPoint_Best}));
  $self->{DETShowPoint_Ratios} = $options->{DETShowPoint_Ratios} if (exists($options->{DETShowPoint_Ratios}));
  
  ### Applies to values reported for the ALL points, order is followed 
  $self->{DETShowPoint_SupportValues} = $options->{DETShowPoint_SupportValues} if (exists($options->{DETShowPoint_SupportValues}));
          
  $self->{Isoratiolines} = $options->{Isoratiolines} if (exists($options->{Isoratiolines}));
  $self->{DrawIsoratiolines} = $options->{DrawIsoratiolines} if (exists($options->{DrawIsoratiolines}));
  $self->{Isometriclines} = $options->{Isometriclines} if (exists($options->{Isometriclines}));
  $self->{DrawIsometriclines} = $options->{DrawIsometriclines} if (exists($options->{DrawIsometriclines}));
  $self->{Isopoints} = $options->{Isopoints} if (exists($options->{Isopoints}));

  $self->{makePNG} = $options->{BuildPNG} if (exists($options->{BuildPNG}));
  $self->{gnuplotPROG} = $options->{gnuplotPROG} if (exists($options->{gnuplotPROG}));
  $self->{pointSize} = $options->{PointSize} if (exists($options->{PointSize}));

  if (exists($options->{ColorScheme})){
    if (! $self->{props}->setValue("ColorScheme", $options->{ColorScheme})){
      die "Error: DET option ColorScheme illegal. ".$self->{props}->get_errormsg();
    }
    if ($self->{props}->getValue("ColorScheme") eq "grey"){
      $self->{colorsRGB} = [ ("rgb \"#000000\"", "rgb \"#c0c0c0\"", "rgb \"#909090\"", "rgb \"#606060\"") ];    
    } elsif ($self->{props}->getValue("ColorScheme") eq "color"){
      $self->{colorsRGB} = [ (2..100) ];    
    }
  }  
}

sub thisabs{ ($_[0] < 0) ? $_[0]*(-1) : $_[0]; }

sub unitTest{
#  offGraphLabelUnitTest();
#  renderUnitTest();
  return 1;
}

sub renderUnitTest{
  my ($dir) = @_;

  print "Test DETCurveGnuplotRenderer...Dir=$dir...";
  my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
  my $trial = new TrialsFuncs({ ("TOTALTRIALS" => 40) }, 
                              "Term Detection", "Term", "Occurrence");
    
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

  my $trial2 = new TrialsFuncs({ ("TOTALTRIALS" => 40) },
                               "Term Detection", "Term", "Occurrence");
    
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

  my $trial3 = new TrialsFuncs({ ("TOTALTRIALS" => 40) },
                               "Term Detection", "Term", "Occurrence");
    
  $trial3->addTrial("she", 0.10, "NO", 1);
  $trial3->addTrial("she", 0.15, "NO", 1);
  $trial3->addTrial("she", 0.20, "NO", 1);
  $trial3->addTrial("she", 0.25, "NO", 1);
  $trial3->addTrial("she", 0.30, "NO", 0);
  $trial3->addTrial("she", 0.35, "NO", 0);
  $trial3->addTrial("she", 0.40, "YES", 0);
  $trial3->addTrial("she", 0.45, "YES", 1);
  $trial3->addTrial("she", 0.50, "YES", 1);
  $trial3->addTrial("she", 0.55, "YES", 1);
  $trial3->addTrial("she", 0.60, "YES", 1);
  $trial3->addTrial("she", 0.65, "YES", 0);
  $trial3->addTrial("she", 0.70, "YES", 1);
  $trial3->addTrial("she", 0.75, "YES", 1);
  $trial3->addTrial("she", 0.80, "YES", 0);
  $trial3->addTrial("she", 0.85, "YES", 1);
  $trial3->addTrial("she", 0.90, "YES", 1);
  $trial3->addTrial("she", 0.95, "YES", 1);
  $trial3->addTrial("she", 1.0, "YES", 1);

  my $trial4 = new TrialsFuncs({ ("TOTALTRIALS" => 20) },
                               "Term Detection", "Term", "Occurrence");
  
  $trial4->addTrial("she", 0.50, "YES", 1);
  $trial4->addTrial("she", 0.50, "YES", 1);
  $trial4->addTrial("she", 0.50, "YES", 1);
  $trial4->addTrial("she", 0.50, "YES", 1);
  $trial4->addTrial("she", 0.50, "YES", 1);
  $trial4->addTrial("she", 0.50, "YES", 1);
  $trial4->addTrial("she", 0.50, "YES", 1);
  $trial4->addTrial("she", undef, "OMITTED", 1);
  $trial4->addTrial("she", undef, "OMITTED", 1);
  $trial4->addTrial("she", undef, "OMITTED", 1);
  $trial4->addTrial("she", undef, "OMITTED", 1);
  $trial4->addTrial("she", undef, "OMITTED", 1);
  $trial4->addTrial("she", 0.50, "YES", 0);
  $trial4->addTrial("she", 0.50, "YES", 0);
  $trial4->addTrial("she", 0.50, "YES", 0);
  $trial4->addTrial("she", 0.50, "YES", 0);
  $trial4->addTrial("she", 0.50, "YES", 0);

  my $det1 = new DETCurve($trial, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
                          "DET1", \@isolinecoef, undef);
  my $det2 = new DETCurve($trial2, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial2),
                          "DET2", \@isolinecoef, undef);
  my $det3 = new DETCurve($trial3, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial3),
                          "DET3", \@isolinecoef, undef);
  my $det4 = new DETCurve($trial4, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial4),
                          "DET4", \@isolinecoef, undef);
  my $ds = new DETCurveSet("title");
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("Name 1", $det1));
  die "Error: Failed to add second det" if ("success" ne $ds->addDET("Name 2", $det2));
  die "Error: Failed to add third det"  if ("success" ne $ds->addDET("Name 3", $det3));
  die "Error: Failed to add third 4th"  if ("success" ne $ds->addDET("Name 4", $det4));

  system "rm -rf $dir";
  system "mkdir -p $dir";
  my $options = { ("ColorScheme" => "grey",
                   "DrawIsometriclines" => 1,
                   "serialize" => 0,
                   "Isometriclines" => [ (0.7, 0.5, 0.3, 0, -5) ],
                   "DETLineAttr" => { ("Name 1" => { label => "New DET1", lineWidth => 9, pointSize => 2, pointTypeSet => "square", color => "rgb \"#0000ff\"" }),
                                    },
                   "PointSet" => [ { MMiss => .4,  MFA => .05, pointSize => 1,  pointType => 10, color => "rgb \"#ff0000\"", label => "Point1=10", justification => "left"}, 
                                   { MMiss => .4,  MFA => .40, pointSize => 8,  pointType => 8, color => "rgb \"#ff0000\"", label => "Point2=8" }, 
                                   { MMiss => .4,  MFA => .80, pointSize => 8,  pointType => 12, color => "rgb \"#ff0000\"", label => "Point2=12" }, 
                                   { MMiss => .2,  MFA => .05, pointSize => 4,  pointType => 4, color => "rgb \"#ff0000\"", label => "Point2=4" }, 
                                   { MMiss => .2,  MFA => .40, pointSize => 4, pointType => 6, color => "rgb \"#ff0000\"" }, 
                                   ] ,
                   "PerfBox" => [ { MMiss => 0.70, MFA => 0.20, color => "rgb \"#000000\"", title => "Inner Box 1"},  
                                  { MMiss => 0.40, MFA => 0.10, color => "rgb \"#ff0000\"", title => "Inner Box 2"},  
                                  { MMiss => 0.20, MFA => 0.80, color => "rgb \"#00ff00\"", title => "Inner Box 3"},  
                                ]
                                   ) };
  
  $options->{Xmin} = .00001;
  $options->{Xmax} = 99.9;
  $options->{Ymin} = .1;
  $options->{Ymax} = 99;
  $options->{xScale} = "nd";
  $options->{yScale} = "nd";
  $options->{title} = "ND vs. ND";

  $options->{KeyLoc} = "bottom";
  $options->{HD} = 0;
  $options->{AutoAdapt} = 0;
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1.nd.nd",  $ds);

  $options->{KeyLoc} = "bottom";
  $options->{HD} = 1;
  $options->{AutoAdapt} = 0;
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1HD.nd.nd",  $ds);

  $options->{KeyLoc} = "below";
  $options->{HD} = 1;
  $options->{AutoAdapt} = 1;
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1HDa.nd.nd",  $ds);
  
  $options->{Xmin} = .0001;
  $options->{Xmax} = 1;
  $options->{Ymin} = .001;
  $options->{Ymax} = 1;
  $options->{xScale} = "log";
  $options->{yScale} = "log";
  $options->{title} = "LOG vs. LOG";

  $options->{KeyLoc} = "bottom";
  $options->{HD} = 0;
  $options->{AutoAdapt} = 0;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1.log.log",  $ds);

  $options->{KeyLoc} = "bottom";
  $options->{HD} = 1;
  $options->{AutoAdapt} = 0;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1HD.log.log",  $ds);

  $options->{KeyLoc} = "below";
  $options->{HD} = 1;
  $options->{AutoAdapt} = 1;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1HDa.log.log",  $ds);

  $options->{xScale} = "linear";
  $options->{yScale} = "linear";
  $options->{title} = "LIN vs. LIN";
  $options->{DETShowPoint_Actual} = 0;
  $options->{PointSize} = 4;
  $options->{ColorScheme} = "color";

  $options->{KeyLoc} = "bottom";
  $options->{HD} = 0;
  $options->{AutoAdapt} = 0;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1.lin.lin",  $ds);

  $options->{KeyLoc} = "bottom";
  $options->{HD} = 1;
  $options->{AutoAdapt} = 0;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1HD.lin.lin",  $ds);

  $options->{KeyLoc} = "below";
  $options->{HD} = 1;
  $options->{AutoAdapt} = 1;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1HDa.lin.lin",  $ds);

  $options->{xScale} = "log";
  $options->{yScale} = "nd";
  $options->{Ymax} = "99.9";
  $options->{Ymin} = "5";
  $options->{title} = "ND vs. LOG";
  $options->{DETShowPoint_Actual} = 0;
  $options->{PointSize} = 4;
  $options->{ColorScheme} = "color";

  $options->{KeyLoc} = "bottom";
  $options->{HD} = 0;
  $options->{AutoAdapt} = 0;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1.nd.log",  $ds);
  
  $options->{KeyLoc} = "bottom";
  $options->{HD} = 1;
  $options->{AutoAdapt} = 0;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1HD.nd.log",  $ds);

  $options->{KeyLoc} = "below";
  $options->{HD} = 1;
  $options->{AutoAdapt} = 1;
  $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/g1HDa.nd.log",  $ds);

  &__renderUnitTest_HTML($dir, "");
  &__renderUnitTest_HTML($dir, "HD");
  &__renderUnitTest_HTML($dir, "HDa");

  print "OK\n";  
  return 1;
}

sub __renderUnitTest_HTML {
  my ($dir, $m) = @_;

  my $f = "$dir/index$m.html";
  open (HTML, ">$f") || die("Error making multi-det HTML file ($f)");
  print HTML "<HTML>\n";
  print HTML "<BODY>\n";
  print HTML " <TABLE border=1>\n";
  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.nd.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.log.log.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.lin.lin.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.log.png\"></TD>\n";
  print HTML "  </TR>\n";
  
  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.nd.Name_1.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.log.log.Name_1.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.lin.lin.Name_1.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.log.Name_1.png\"></TD>\n";
  print HTML "  </TR>\n";

  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.nd.Name_1.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.log.log.Name_1.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.lin.lin.Name_1.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.log.Name_1.thresh.png\"></TD>\n";
  print HTML "  </TR>\n";

  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.nd.Name_2.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.log.log.Name_2.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.lin.lin.Name_2.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.log.Name_2.thresh.png\"></TD>\n";
  print HTML "  </TR>\n";

  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.nd.Name_3.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.log.log.Name_3.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.lin.lin.Name_3.thresh.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"g1$m.nd.log.Name_3.thresh.png\"></TD>\n";
  print HTML "  </TR>\n";

  print HTML " </TABLE>\n";
  print HTML "</BODY>\n";
  print HTML "</HTML>\n";
  
  close (HTML);
}

sub offGraphLabelUnitTest(){
  print " Checking off Graph Label tests...";
  my $ret = "";
  $ret = _getOffAxisLabel(0.9, 0.1, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 1 and returned '$ret'"  if ($ret !~ /Q1/);  
  $ret = _getOffAxisLabel(0.9, 0.5, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 2 and returned '$ret'"  if ($ret !~ /Q2/);  
  $ret = _getOffAxisLabel(0.9, 0.9, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 3 and returned '$ret'"  if ($ret !~ /Q3/);  

  $ret = _getOffAxisLabel(0.5, 0.1, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 4 and returned '$ret'"  if ($ret !~ /Q4/);  
  $ret = _getOffAxisLabel(0.5, 0.5, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 5 and returned '$ret'"  if ($ret ne "");  
  $ret = _getOffAxisLabel(0.5, 0.9, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 6 and returned '$ret'"  if ($ret !~ /Q6/);  

  $ret = _getOffAxisLabel(0.1, 0.1, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 7 and returned '$ret'"  if ($ret !~ /Q7/);  
  $ret = _getOffAxisLabel(0.1, 0.5, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 8 and returned '$ret'"  if ($ret !~ /Q8/);  
  $ret = _getOffAxisLabel(0.1, 0.9, 20, 80, "nd", 20, 80, "nd", 9, 9, 6, 1);    die " ND Quad 9 and returned '$ret'"  if ($ret !~ /Q9/);  

  $ret = _getOffAxisLabel(0.9, 0.1, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 1 and returned '$ret'"  if ($ret !~ /Q1/);  
  $ret = _getOffAxisLabel(0.9, 0.5, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 2 and returned '$ret'"  if ($ret !~ /Q2/);  
  $ret = _getOffAxisLabel(0.9, 0.9, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 3 and returned '$ret'"  if ($ret !~ /Q3/);  

  $ret = _getOffAxisLabel(0.5, 0.1, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 4 and returned '$ret'"  if ($ret !~ /Q4/);  
  $ret = _getOffAxisLabel(0.5, 0.5, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 5 and returned '$ret'"  if ($ret ne "");  
  $ret = _getOffAxisLabel(0.5, 0.9, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 6 and returned '$ret'"  if ($ret !~ /Q6/);  

  $ret = _getOffAxisLabel(0.1, 0.1, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 7 and returned '$ret'"  if ($ret !~ /Q7/);  
  $ret = _getOffAxisLabel(0.1, 0.5, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 8 and returned '$ret'"  if ($ret !~ /Q8/);  
  $ret = _getOffAxisLabel(0.1, 0.9, 0.2, 0.8, "linear", 0.2, 0.8, "linear", 9, 9, 6, 1);    die " Linear Quad 9 and returned '$ret'"  if ($ret !~ /Q9/);  

  $ret = _getOffAxisLabel(0.9, 0.0, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 1 and returned '$ret'"  if ($ret !~ /Q1/);  
  $ret = _getOffAxisLabel(0.9, 0.1, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 1 and returned '$ret'"  if ($ret !~ /Q1/);  
  $ret = _getOffAxisLabel(0.9, 0.5, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 2 and returned '$ret'"  if ($ret !~ /Q2/);  
  $ret = _getOffAxisLabel(0.9, 0.9, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 3 and returned '$ret'"  if ($ret !~ /Q3/);  

  $ret = _getOffAxisLabel(0.5, 0.0, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 4 and returned '$ret'"  if ($ret !~ /Q4/);  
  $ret = _getOffAxisLabel(0.5, 0.1, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 4 and returned '$ret'"  if ($ret !~ /Q4/);  
  $ret = _getOffAxisLabel(0.5, 0.5, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 5 and returned '$ret'"  if ($ret ne "");  
  $ret = _getOffAxisLabel(0.5, 0.9, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 6 and returned '$ret'"  if ($ret !~ /Q6/);  

  $ret = _getOffAxisLabel(0.1, 0.0, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 7 and returned '$ret'"  if ($ret !~ /Q7/);  
  $ret = _getOffAxisLabel(0.1, 0.1, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 7 and returned '$ret'"  if ($ret !~ /Q7/);  
  $ret = _getOffAxisLabel(0.1, 0.5, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 8 and returned '$ret'"  if ($ret !~ /Q8/);  
  $ret = _getOffAxisLabel(0.1, 0.9, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 9 and returned '$ret'"  if ($ret !~ /Q9/);  

  $ret = _getOffAxisLabel(0.0, 0.0, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 7 and returned '$ret'"  if ($ret !~ /Q7/);  
  $ret = _getOffAxisLabel(0.0, 0.1, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 7 and returned '$ret'"  if ($ret !~ /Q7/);  
  $ret = _getOffAxisLabel(0.0, 0.5, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 8 and returned '$ret'"  if ($ret !~ /Q8/);  
  $ret = _getOffAxisLabel(0.0, 0.9, 0.2, 0.8, "log", 0.2, 0.8, "log", 9, 9, 6, 1);    die " Linear Quad 9 and returned '$ret'"  if ($ret !~ /Q9/);  

  print "  Ok\n";
}

sub lineTitleControlUnitTest{
  my ($dir) = @_;

  print "Test DETCurveGnuplotRenderer...Dir=$dir...";
  my @isolinecoef = ( 5, 10, 20, 40, 80, 160 );
  my $trial = new TrialsFuncs({ ("TOTALTRIALS" => 40) }, 
                              "Term Detection", "Term", "Occurrence");
    
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

  my $trial2 = new TrialsFuncs({ ("TOTALTRIALS" => 40) },
                               "Term Detection", "Term", "Occurrence");
    
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
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial),
                          "Event 1", \@isolinecoef, undef);
  my $det2 = new DETCurve($trial2, 
                          new MetricTestStub({ ('ValueC' => 0.1, 'ValueV' => 1, 'ProbOfTerm' => 0.0001 ) }, $trial2),
                          "Event 2", \@isolinecoef, undef);
  my $ds = new DETCurveSet("title");
  die "Error: Failed to add first det" if ("success" ne $ds->addDET("Name 1", $det1));
  die "Error: Failed to add second det" if ("success" ne $ds->addDET("Name 2", $det2));

  system "rm -rf $dir";
  system "mkdir -p $dir";
  my $options = {};
  
  my $f = "$dir/LC.index.html";
  open (HTML, ">$f") || die("Error making multi-det HTML file ($f)");
  print HTML "<HTML>\n";
  print HTML "<BODY>\n";
  print HTML " <TABLE border=1>\n";

  ########################################################
  $options = { "Isoratiolines" =>  [ ( 20, 40, 80 ) ]};
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/LC.default",  $ds);
  print HTML "  <TR>\n";
  print HTML "   <TD colspan=2>Default settings<br><pre>".Dumper($options)."</pre><\TD>\n";
  print HTML "  <\TR>\n";
  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.default.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.default.Name_1.png\"></TD>\n";
  print HTML "  </TR>\n";

  ########################################################
  $options = { "Isoratiolines" =>  [ ( 20, 40, 80 ) ],
                "DETShowPoint_Actual" => 1,
                "DETShowPoint_Best" => 1,
                "DETShowPoint_Ratios" => 1};
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/LC.all",  $ds);
  print HTML "  <TR>\n";
  print HTML "   <TD colspan=2><pre>".Dumper($options)."</pre><\TD>\n";
  print HTML "  <\TR>\n";
  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.all.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.all.Name_1.png\"></TD>\n";
  print HTML "  </TR>\n";
  
  ########################################################
  $options = { "Isoratiolines" =>  [ ( 20, 40, 80 ) ],
                "DETShowPoint_Actual" => 1};
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/LC.act",  $ds);
  print HTML "  <TR>\n";
  print HTML "   <TD colspan=2><pre>".Dumper($options)."</pre><\TD>\n";
  print HTML "  <\TR>\n";
  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.act.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.act.Name_1.png\"></TD>\n";
  print HTML "  </TR>\n";
    
  
  ########################################################
  $options = { "Isoratiolines" =>  [ ( 20, 40, 80 ) ],
                "DETShowPoint_Best" => 1};
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/LC.best",  $ds);
  print HTML "  <TR>\n";
  print HTML "   <TD colspan=2><pre>".Dumper($options)."</pre><\TD>\n";
  print HTML "  <\TR>\n";
  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.best.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.best.Name_1.png\"></TD>\n";
  print HTML "  </TR>\n";

  ########################################################
  $options = { "Isoratiolines" =>  [ ( 20, 40, 80 ) ],
                "DETShowPoint_Ratios" => 1};
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/LC.rat",  $ds);
  print HTML "  <TR>\n";
  print HTML "   <TD colspan=2><pre>".Dumper($options)."</pre><\TD>\n";
  print HTML "  <\TR>\n";
  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.rat.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.rat.Name_1.png\"></TD>\n";
  print HTML "  </TR>\n";

  ########################################################
  $options = { "Isoratiolines" =>  [ ( 20, 40, 80 ) ],
                "DETShowPoint_SupportValues" => [('C', 'T')],
                "DETShowPoint_Actual" => 1,
                "DETShowPoint_Best" => 1,
                "DETShowPoint_Ratios" => 1};
  my $dcRend = new DETCurveGnuplotRenderer($options);
  $dcRend->writeMultiDetGraph("$dir/LC.sel",  $ds);
  print HTML "  <TR>\n";
  print HTML "   <TD colspan=2><pre>".Dumper($options)."</pre><\TD>\n";
  print HTML "  <\TR>\n";
  print HTML "  <TR>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.sel.png\"></TD>\n";
  print HTML "   <TD width=25%> <IMG src=\"$dir/LC.sel.Name_1.png\"></TD>\n";
  print HTML "  </TR>\n";
    
  
  print HTML " </TABLE>\n";
  print HTML "</BODY>\n";
  print HTML "</HTML>\n";
  close HTML;
}


######################  Beginning of the code #################
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
    $self->{ISOPOINTS}{$isolinecoef}{INTERPOLATED_COMB} = $self->{METRIC}->combCalc($estMMiss, $estMFa);
        
    foreach my $b ( keys %{ $blocks } ) {
      # Add info of previous in the block id
      $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MFA} = (1-$paramt)*($blocks->{$b}{PREVMFA}) + $paramt*($blocks->{$b}{MFA});
      $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MMISS} = (1-$paramt)*($blocks->{$b}{PREVMMISS}) + $paramt*($blocks->{$b}{MMISS});
      # Value function
      $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{COMB} = $self->{METRIC}->combCalc($self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MMISS},
                                                                                     $self->{ISOPOINTS}{$isolinecoef}{BLOCKS}{$b}{MFA});
    }
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

sub _gnuplotSafeString{
  my ($str) = @_;
  $str =~ s/[\'\"]/_/g;
  $str;
}


sub write_gnuplot_threshold_header{
  my ($self, $FP, $title) = @_;

  print $FP "## GNUPLOT command file\n";
  print $FP "set terminal postscript color\n";
  #  print $FP "set data style lines\n"; 
  # ^ obsoleted 
  print $FP "set style data lines\n";
  print $FP "set title '"._gnuplotSafeString($title)."'\n";
  print $FP "set xlabel 'Detection Score'\n";
  print $FP "set grid\n";
  print $FP "set size ratio 0.85\n";

}

sub write_gnuplot_DET_header{
  my($self, $metric, $FP, $labels) = @_;

  my $xScale = $self->{props}->getValue("xScale"); 
  my $yScale = $self->{props}->getValue("yScale"); 
  my $keyLoc = $self->{props}->getValue("KeyLoc"); 
  my $keySpacing = $self->{props}->getValue("KeySpacing"); 
  my $title = $self->{title}; 
  
  print $FP "set terminal postscript color\n";
  print $FP "set noxzeroaxis\n";
  print $FP "set noyzeroaxis\n";
  print $FP "### Using xScale = $xScale\n";
  print $FP "### Using yScale = $yScale\n";
  print $FP "set style fill  transparent solid 0.10 noborder\n";

  if (defined($keyLoc)) {
    $keyLoc = $bvc if ($keyLoc eq "below");  ### Gnuplot changed
    print $FP "set key $keyLoc spacing $keySpacing ". ($keyLoc eq $bvc ? "box" : "")."\n";
  }
  
  my $ratio = 0.85;
  if ($xScale eq "nd" && $yScale eq "nd") {
    $ratio = (ppndf($self->{Bounds}{ymax}{metric}) - ppndf($self->{Bounds}{ymin}{metric}))/(ppndf($self->{Bounds}{xmax}{metric}) - ppndf($self->{Bounds}{xmin}{metric}));
  } elsif ($xScale eq "log" && $yScale eq "log") {
    $ratio = (log($self->{Bounds}{ymax}{metric}) - log($self->{Bounds}{ymin}{metric}))/(log($self->{Bounds}{xmax}{metric}) - log($self->{Bounds}{xmin}{metric}));
  } elsif ($xScale eq "lin" && $yScale eq "lin") {
    $ratio = ($self->{Bounds}{ymax}{metric} - $self->{Bounds}{ymin}{metric})/($self->{Bounds}{xmax}{metric} - $self->{Bounds}{xmin}{metric});
  }
  print $FP "set size ratio $ratio\n";
  
  print $FP "set title '"._gnuplotSafeString($title)."'\n";
  print $FP "set grid\n";
  print $FP "set pointsize 3\n";
  my $ylab = (($self->{props}->getValue("MissUnit") eq "Prob" && $yScale eq "nd") ? " %" : "");
  $ylab .= ($metric->errMissUnitLabel() ne "" ? " ".$metric->errMissUnitLabel() : "");
  $ylab = "(in$ylab)" if ($ylab ne "");

  my $xlab = (($self->{props}->getValue("FAUnit") eq "Prob" && $xScale eq "nd") ? " %" : "");
  $xlab .= ($metric->errFAUnitLabel() ne "" ? " ".$metric->errFAUnitLabel() : "");
  $xlab = "(in$xlab)" if ($xlab ne "");
  
  print $FP "set ylabel '".$metric->errMissLab()." $ylab'\n";
  print $FP "set xlabel '".$metric->errFALab()." $xlab'\n";

  print $FP join("\n",@$labels)."\n" if (defined($labels));
  if ($xScale eq "nd") {
    print $FP "set noxtics\n"; 
    print $FP $self->_ticsLine('xtics', $self->{Bounds}{xmin}{disp}, $self->{Bounds}{xmax}{disp});
  } elsif ($xScale eq "log") {
    print $FP "set xtics\n"; 
    print $FP "set logscale x\n"; 
  } else {                      # linear
    print $FP "set xtics\n"; 
  }
  ### Write the tic marks

  if ($yScale eq "nd") {
    print $FP "set noytics\n"; 
    print $FP $self->_ticsLine('ytics', $self->{Bounds}{ymin}{disp}, $self->{Bounds}{ymax}{disp});
  } elsif ($yScale eq "log") {
    print $FP "set ytics\n"; 
    print $FP "set logscale y\n"; 
  } else {                      # linear
    print $FP "set ytics\n"; 
  }
    
  my $xrange = ($xScale eq "nd" ? "[".ppndf($self->{Bounds}{xmin}{metric}).":".ppndf($self->{Bounds}{xmax}{metric})."]" : "[$self->{Bounds}{xmin}{metric}:$self->{Bounds}{xmax}{metric}]");
  my $yrange = ($yScale eq "nd" ? "[".ppndf($self->{Bounds}{ymin}{metric}).":".ppndf($self->{Bounds}{ymax}{metric})."]" : "[$self->{Bounds}{ymin}{metric}:$self->{Bounds}{ymax}{metric}]");
  print $FP "plot $xrange $yrange \\\n";
}

sub _ticsLine{ 
  my($self, $axis, $min, $max) = @_;
  my($lab, $i, $prev) = ("", 0, 0);
  my $tics = $self->{NDtics};
  
  my $line = "set $axis (";
  for ($i=0, $prev=0; $i< @$tics; $i++) {
    if ($tics->[$i] >= $min && $tics->[$i] <= $max) {
      $line .= ", " if ($prev > 0);
      $line .= "\\\n    " if (($prev+1 % 10) == 0);
      if ($tics->[$i] > 99) {
        $lab = sprintf("%.1f", $tics->[$i]);
      } elsif ($tics->[$i] >= 1) {
        $lab = sprintf("%d", $tics->[$i]);
      } elsif ($tics->[$i] >= 0.1) {
        ($lab = sprintf("%.1f", $tics->[$i])) =~ s/^0//;
      } elsif ($tics->[$i] >= 0.01) {
        ($lab = sprintf("%.2f", $tics->[$i])) =~ s/^0//;
      } elsif ($tics->[$i] >= 0.001) {
        ($lab = sprintf("%.3f", $tics->[$i])) =~ s/^0//;
      } elsif ($tics->[$i] >= 0.0001) {
        ($lab = sprintf("%.4f", $tics->[$i])) =~ s/^0//;
      } else {
        ($lab = sprintf("%.5f", $tics->[$i])) =~ s/^0//;
      }
      $line .= sprintf "'$lab' %.4f",ppndf($tics->[$i]/100);
      $prev ++;
    }
  }
  $line .= ")\n";
  $line;
}

sub _drawIsoratiolines{
  my ($self, $fileRoot, $PLOTCOMS, $metric) = @_;

  return if (! $self->{DrawIsoratiolines});

  my $troot = sprintf( "%s.isoratiolines", $fileRoot );
  my $color = "rgb \"\#DDDDDD\"";
  open( ISODAT, "> $troot" ); 
            
  foreach my $isocoef (@{ $self->{Isoratiolines} } ) {
    my $x = $self->{Bounds}{xmin}{metric};
                               
    while ($x <= $self->{Bounds}{xmax}{metric}) {
      my $pfa = ($self->{props}->getValue("xScale") eq "nd" ? ppndf($x) : $x);
      my $pmiss = ($self->{props}->getValue("yScale") eq "nd" ? ppndf($isocoef*$x) : $isocoef*$x);
      printf ISODAT "$pfa $pmiss\n";
            
      if   ( $x < 0.0001 ) { $x += 0.000001; }
      elsif( $x < 0.001  ) { $x += 0.00001; }
      elsif( $x < 0.004  ) { $x += 0.00004; }
      elsif( $x < 0.01   ) { $x += 0.0001; }
      elsif( $x < 0.02   ) { $x += 0.0002; } 
      elsif( $x < 0.05   ) { $x += 0.0005; }
      elsif( $x < 0.1    ) { $x += 0.001; }
      elsif( $x < 0.2    ) { $x += 0.002; }
      elsif( $x < 0.5    ) { $x += 0.005; }
      elsif( $x < 1      ) { $x += 0.01; }
      elsif( $x < 2      ) { $x += 0.02; }
      elsif( $x < 5      ) { $x += 0.05; }
      else                 { $x += 0.1; }
    }
    printf ISODAT "\n";
  }
  close( ISODAT );
  push @$PLOTCOMS, "  '$troot' title 'Iso-cost ratio lines' with lines lt $color";
}

sub _drawIsometriclines{
  my ($self, $fileRoot, $PLOTCOMS, $labels, $metric) = @_;

  return if (! $self->{DrawIsometriclines});

  my $troot = sprintf( "%s.isometriclines", $fileRoot );
  my $color = ($self->{props}->getValue("ColorScheme") eq "color" ? "rgb \"\#FFD700\"" : "rgb \"\#b0b0b0\"");
  open( ISODAT, "> $troot" );
      
  my $labelind = 10;
            
  foreach my $isocoef (@{ $self->{Isometriclines} } ) {
    my $ytemp = $metric->MISSForGivenComb($isocoef, $self->{Bounds}{xmin}{metric});
    my $xtemp = $metric->FAForGivenComb($isocoef, $self->{Bounds}{ymax}{metric});
          
    my $linelabel = _getIsoMetricLineLabel($ytemp, $self->{Bounds}{xmin}{metric}, 
                                           $self->{Bounds}{ymin}{metric}, $self->{Bounds}{ymax}{metric}, $self->{props}->getValue("yScale"), 
                                           $self->{Bounds}{xmin}{metric}, $self->{Bounds}{xmax}{metric}, $self->{props}->getValue("xScale"),
                                           $color, $labelind, sprintf("%.3f", $isocoef), $xtemp);
    push (@$labels, $linelabel);
                            
    my $pred_y = $self->{Bounds}{ymin}{metric}+1;    
    my $x = $self->{Bounds}{xmin}{metric};
    while ($x <= $self->{Bounds}{xmax}{metric} && $pred_y != $self->{Bounds}{ymin}{metric}) {
      my $pfa = ($self->{props}->getValue("xScale") eq "nd" ? ppndf($x) : $x);
      $pred_y = MMisc::max($self->{Bounds}{ymin}{metric},$metric->MISSForGivenComb($isocoef, $x));
            
      my $pmiss = ($self->{props}->getValue("yScale") eq "nd" ? ppndf($pred_y) : $pred_y);
            
      printf ISODAT "$pfa $pmiss\n";
            
      if   ( $x < 0.0001 ) { $x += 0.000001; }
			elsif( $x < 0.001  ) { $x += 0.00001; }
			elsif( $x < 0.004  ) { $x += 0.00004; }
			elsif( $x < 0.01   ) { $x += 0.0001; }
			elsif( $x < 0.02   ) { $x += 0.0002; }
			elsif( $x < 0.05   ) { $x += 0.0005; }
			elsif( $x < 0.1    ) { $x += 0.001; }
			elsif( $x < 0.2    ) { $x += 0.002; }
			elsif( $x < 0.5    ) { $x += 0.005; }
			elsif( $x < 1      ) { $x += 0.01; }
			elsif( $x < 2      ) { $x += 0.02; }
			elsif( $x < 5      ) { $x += 0.05; }
			else                 { $x += 0.1; }
    }
                                     
    printf ISODAT "\n";
          
    $labelind++;
  }
                
  close( ISODAT );
   
  push @$PLOTCOMS, "  '$troot' title 'Iso-" . $metric->combLab() . " lines' with lines lt $color";
}

sub _makePointSetLabels{
  my ($self) = @_;

  my @labs = ();
  return @labs if (! defined($self->{PointSet}));
    
  my $pset = $self->{PointSet};
 
  foreach my $point(@$pset){
    my ($xpos, $ypos) = (_getValueInGraph($point->{MFA}, $self->{Bounds}{xmin}{metric}, $self->{Bounds}{xmax}{metric}, $self->{props}->getValue("xScale")),
                         _getValueInGraph($point->{MMiss}, $self->{Bounds}{ymin}{metric}, $self->{Bounds}{ymax}{metric}, $self->{props}->getValue("yScale")));

    ### If the points are off the graph, place them in the border
    if ($xpos < 0) { $xpos = -0.02; }
    if ($ypos < 0) { $ypos = -0.02; }
    if ($xpos > 1) { $xpos =  1.02; }
    if ($ypos > 1) { $ypos =  1.02; }

    ### Point size is the radius.  This option tells the program to plot it as area of Radius    
    my $sizeDef = ($self->{props}->getValue("PointSetAreaDefinition"));
    my $mySize = (exists($point->{pointSize}) ? $point->{pointSize} : 1);
    if ($sizeDef eq "Area"){
      ### $mySize = Pi * r * r
      $mySize = sqrt($mySize / 3.141592653589) / sqrt(1 / 3.141592653589);
    }

    push @labs, 
        "set label \"".(exists($point->{label}) ? $point->{label} : "")."\" " .
        (exists($point->{justification}) ? $point->{justification}." " : "") .
        " point ".
        "lc ".(exists($point->{color}) ? $point->{color} : 1)." ".
        "pt ".(exists($point->{pointType}) ? $point->{pointType} : 1)." ".
        "ps ".$mySize." ".
        "at graph $xpos, graph  $ypos";              
  }      
  @labs;
}

sub _log10{
  my ($v) = @_;
  ($v == 0) ? undef : log($v)/log(10)
}

sub _getValueInGraph
{
	my ($x, $xmin, $xmax, $scale) = @_;
	if    ($scale eq "nd" )   { return((ppndf($x) - ppndf($xmin)) / (ppndf($xmax) - ppndf($xmin))); }
  	elsif ($scale eq "log") { return((($x <= 0) ? -1 : (_log10($x) - _log10($xmin)) / (_log10($xmax) - _log10($xmin)))); }
  	else                    { return(($x - $xmin) / ($xmax - $xmin)); }
}

## this functions Checks the extent of the graph frame and builds labels for points off the graph
sub _getOffAxisLabel{
  my ($self, $yval, $xval, $color, $pointType, $pointSize, $qstr) = @_;

  my $gyval = _getValueInGraph($yval, $self->{Bounds}{ymin}{metric}, $self->{Bounds}{ymax}{metric}, $self->{props}->getValue("yScale"));
  my $gxval = _getValueInGraph($xval, $self->{Bounds}{xmin}{metric}, $self->{Bounds}{xmax}{metric}, $self->{props}->getValue("xScale"));

  ### Check to see if the MinBest and actual are off axis
  ###    Q1   Q2   Q3
  ###       ------
  ###    Q4 | Q5 | Q6
  ###       ------
  ###    Q7   Q8   Q9
  # Q1
  if ($gyval > 1 && $gxval < 0) { return "set label \"".($qstr == 1 ? "Q1" : "")."\" point lc $color pt $pointType ps $pointSize at graph  -0.02, graph   1.02"; }
  # Q2
  if ($gyval > 1 && $gxval < 1) { return "set label \"".($qstr == 1 ? "Q2" : "")."\" point lc $color pt $pointType ps $pointSize at graph $gxval, graph   1.02"; }
  # Q3
  if ($gyval > 1 && $gxval > 1) { return "set label \"".($qstr == 1 ? "Q3" : "")."\" point lc $color pt $pointType ps $pointSize at graph   1.02, graph   1.02"; }
  # Q4
  if ($gyval > 0 && $gxval < 0) { return "set label \"".($qstr == 1 ? "Q4" : "")."\" point lc $color pt $pointType ps $pointSize at graph  -0.02, graph $gyval"; }
  # Q5
  if ($gyval > 0 && $gxval < 1) { return ""; }
  # Q6
  if ($gyval > 0 && $gxval > 1) { return "set label \"".($qstr == 1 ? "Q6" : "")."\" point lc $color pt $pointType ps $pointSize at graph     1.02, graph $gyval"; }
  # Q7
  if ($gyval < 0 && $gxval < 0) { return "set label \"".($qstr == 1 ? "Q7" : "")."\" point lc $color pt $pointType ps $pointSize at graph    -0.02, graph  -0.02"; }
  # Q8
  if ($gyval < 0 && $gxval < 1) { return "set label \"".($qstr == 1 ? "Q8" : "")."\" point lc $color pt $pointType ps $pointSize at graph   $gxval, graph  -0.02"; }
  # Q9
  if ($gyval < 0 && $gxval > 1) { return "set label \"".($qstr == 1 ? "Q9" : "")."\" point lc $color pt $pointType ps $pointSize at graph     1.02, graph  -0.02"; }
  "";
}

sub _getIsoMetricLineLabel
{
	my ($yval, $xval, $ymin, $ymax, $yScale, $xmin, $xmax, $xScale, $color, $indexl, $qstr, $xtemp) = @_;
	my $gyval = _getValueInGraph($yval, $ymin, $ymax, $yScale);
	my $gxval = _getValueInGraph($xval, $xmin, $xmax, $xScale);
	my $just = "left";
	$gxval = 0 if($gxval < 0);
	
	if($gyval > 1)
	{
		$gxval = _getValueInGraph($xtemp, $xmin, $xmax, $xScale);
		$gyval = 0.99;
		$gxval -= 0.005;
		$just = "right";
	} else {
  	$gyval -= 0.01;
	  $gxval += 0.005;
  }
	return "set label $indexl \"$qstr\" at graph $gxval, graph $gyval $just nopoint textcolor $color";
}

sub _getLineTitleString
{
	my ($self, $type, $ratio, $det, $offAxisArr, $offAxisColor, $offAxisClosedPoint, $offAxisPointSize, $offAxisQStr) = @_;
  
  my ($metStr, $comb, $fa, $miss, $thr) = ();
  my $title = "";

  my ($missStr, $faStr, $combStr) = ( $det->{METRIC}->errMissLab(), $det->{METRIC}->errFALab(), 
                                      $det->{METRIC}->combLab());
  if ($type eq "Actual"){
     my ($MeanActComb, $SampleStdDevActComb, $MeanMiss, $SampleStdDevMiss, $MeanFA, $SampleStdDevFA) =
            $det->getMetric()->getActualDecisionPerformance();
     ($metStr, $comb, $fa, $miss, $thr) = ("Actual", $MeanActComb, $MeanFA, $MeanMiss,
                                           $det->getTrials()->getTrialActualDecisionThreshold());
  } elsif ($type eq "Best"){
     ($metStr, $comb, $fa, $miss, $thr) = ($det->{METRIC}->combType() eq "minimizable" ? "Min" : "Max", 
                                           $det->getBestCombComb(),
                                           $det->getBestCombMMiss(),
                                           $det->getBestCombMFA(),
                                           $det->getBestCombDetectionScore());
  } elsif ($type eq "ErrorRatio"){
    ($metStr, $comb, $fa, $miss, $thr) = ("IsoRatio=$ratio", 
                                          $det->getIsolinePointsCombValue($ratio), 
                                          $det->getIsolinePointsMFAValue($ratio),
                                          $det->getIsolinePointsMMissValue($ratio),
                                          $det->getIsolinePointsDetectionScoreValue($ratio));
  }

  my $lab = $self->_getOffAxisLabel($miss, $fa, $offAxisColor, $offAxisClosedPoint, $offAxisPointSize, $offAxisQStr); 
  push (@$offAxisArr, $lab) if ($lab ne "");

  $title = "$metStr ";
  foreach my $supVal(@{ $self->{DETShowPoint_SupportValues} }){
    $title .= sprintf(" $faStr=%.3f", $fa) if ($supVal eq "F");
    $title .= sprintf(" $missStr=%.3f", $miss) if ($supVal eq "M");
    $title .= sprintf(" Thr=%.3f", $thr) if ($supVal eq "T");
    $title .= sprintf(" $combStr=%.3f", $comb) if ($supVal eq "C");
  }
  $title;        
}

### Options for graphs:
### title  -> the plot title
### serialize -> write the serialized DET Curves
### Xmin -> Set the minimum X coordinate
### Xmax -> Set the maximum X coordinate
### Ymin -> Set the minimum Y coordinate
### Ymax -> Set the maximum Y coordinate
### lTitleNoDETType    -> write the DET Type if the element exists
### DETShowPoint_Best  -> write the Max Value if the element exists
### KeyLoc -> set the key location.  Values can be left | right | top | bottom | outside | below 
### Isolines -> Draw the isolines coefs

### This is NOT an instance METHOD!!!!!!!!!!!!!!
sub writeMultiDetGraph
  {
    ### $options is a pointer to a hash table to tweak the graph
    my ($self, $fileRoot, $detset) = @_;

    my $numDET = scalar(@{ $detset->getDETList() });
    return undef if ($numDET < 0);
    
    $self->_extractMetricProps($detset->getDETForID(0)->{METRIC});

    my ($missStr, $faStr, $combStr) = ( $detset->getDETForID(0)->{METRIC}->errMissLab(), $detset->getDETForID(0)->{METRIC}->errFALab(), 
                                        $detset->getDETForID(0)->{METRIC}->combLab());
    my $combType = ($detset->getDETForID(0)->{METRIC}->combType() eq "minimizable" ? "Min" : "Max");
    ### Consult the properties
    my $xScale = $self->{props}->getValue("xScale");
    my $yScale = $self->{props}->getValue("yScale");    

    ### This contains info from individual DET plots
    my %multiInfo = ();

    ### Set labels for off-graph points
    my @offAxisLabels = ();                                                                                                     
     
    ### $this text element constitutes the extra plot commands for the graph
    my @PLOTCOMS;

    ### Add extra points
    push @offAxisLabels, $self->_makePointSetLabels();
    
    ### Check the metric types to see if the random curve is defined
    if ($self->{props}->getValue("MissUnit") eq "Prob" && $self->{props}->getValue("FAUnit") eq "Prob"){
       push @PLOTCOMS, "  -x title 'Random Performance' with lines lt 1";
    }

    ### Draw the isometriclines
    $self->_drawIsometriclines($fileRoot, \@PLOTCOMS, \@offAxisLabels, $detset->getDETForID(0)->{METRIC});

    ### Draw the isoratiolines
    $self->_drawIsoratiolines($fileRoot, \@PLOTCOMS, $detset->getDETForID(0)->{METRIC});
        
    ### Draw the isopoints
    if ( defined( $self->{Isopoints} ) ) {
      my $trootpoints1 = sprintf( "%s.isopoints.1", $fileRoot );
      my $trootpoints2 = sprintf( "%s.isopoints.2", $fileRoot );
      my $trootlines = sprintf( "%s.isopoints.3", $fileRoot );
      my $colorpoints1 = $self->{colorsRGB}->[0];
      my $colorpoints2 = $self->{colorsRGB}->[1];
      my $colorlines = "rgb \"\#333333\"";
      my $isnodiff = 0;
      open( POINTS1DAT, "> $trootpoints1" );
      open( POINTS2DAT, "> $trootpoints2" );
      open( LINESDAT, "> $trootlines" );
                
      foreach my $isoelt ( @{ $self->{Isopoints} } ) {
        my @elt = @$isoelt;
                        
        my $x1 = ($xScale eq "nd" ? ppndf( $elt[0] ) : $elt[0] );
        my $y1 = ($yScale eq "nd" ? ppndf( $elt[1] ) : $elt[1] );
        my $x2 = ($xScale eq "nd" ? ppndf( $elt[2] ) : $elt[2] );
        my $y2 = ($yScale eq "nd" ? ppndf( $elt[3] ) : $elt[3] );
                        
        printf POINTS1DAT "$x1 $y1\n";
        printf POINTS2DAT "$x2 $y2\n";
                        
        if ( $elt[4] == 1 ) {
          $isnodiff = 1;
          my $t = 0;
                                
          while ( $t <= 1 ) {
            my $x = (1-$t)*$elt[2] + $t*$elt[0];
            my $y = (1-$t)*$elt[3] + $t*$elt[1];
                                
            my $pfa = ($xScale eq "nd" ? ppndf( $x ) : $x);
            my $pmiss =  ($yScale eq "nd" ? ppndf( $y ) : $y);
            printf LINESDAT "$pfa $pmiss\n";
                                
            if   ( $x < 0.0001 ) { $t += 0.0001; }
			elsif( $x < 0.001  ) { $t += 0.001; }
			elsif( $x < 0.004  ) { $t += 0.004; }
			elsif( $x < 0.01   ) { $t += 0.01; }
			elsif( $x < 0.02   ) { $t += 0.02; }
			elsif( $x < 0.05   ) { $t += 0.05; }
			else                 { $t += 0.1; }
          }
                                
          printf LINESDAT "\n";
        }
      }
                
      close( POINTS1DAT );
      close( POINTS2DAT );
      close( LINESDAT );
     
      push @PLOTCOMS, "  '$trootlines' title 'no diff' with lines lt $colorlines" if( $isnodiff );
      push @PLOTCOMS, "  '$trootpoints1' notitle with points lt $colorpoints1 pt 6 ps 1";
      push @PLOTCOMS, "  '$trootpoints2' notitle with points lt $colorpoints2 pt 6 ps 1";
    }
        
    ### Write Individual Dets
    for (my $d=0; $d < $numDET; $d++) {
      my $openPoint = $self->{pointTypes}->[ $d % scalar(@{ $self->{pointTypes} }) ]->[0];
      my $closedPoint = $self->{pointTypes}->[ $d % scalar(@{ $self->{pointTypes} }) ]->[1];
      my $lineWidth = $self->{lineWidths}->[ $d % scalar(@{ $self->{lineWidths} }) ];
      my $color = $self->{colorsRGB}->[ $d % scalar(@{ $self->{colorsRGB} }) ];
      my $nokey = "";
      my $thisPointSize = $self->{pointSize};
      my $thisPointSizeDiv2 = $thisPointSize / 2;
      
      my $lineTitle = $detset->getDETForID($d)->{LINETITLE};
      if (exists($self->{DETLineAttr})){
        if (exists($self->{DETLineAttr}{$detset->getTitleForID($d)})){
          my $info = $self->{DETLineAttr}{$detset->getTitleForID($d)};
          ### Override the plotting style
          $lineTitle = $info->{label} if (exists($info->{label}));
          $thisPointSize = $info->{pointSize} if (exists($info->{pointSize}));
          $thisPointSizeDiv2 = $thisPointSize / 2;
          $lineWidth = $info->{lineWidth} if (exists($info->{lineWidth}));
          $color = $info->{color}         if (exists($info->{color}));
          $nokey = $info->{nokey} if (exists($info->{nokey}));
          if (exists($info->{pointTypeSet})){
             if ($info->{pointTypeSet} eq "square")    { $openPoint = 4;  $closedPoint = 5; } 
             if ($info->{pointTypeSet} eq "circle")    { $openPoint = 6;  $closedPoint = 7; } 
             if ($info->{pointTypeSet} eq "triangle")  { $openPoint = 8;  $closedPoint = 9; }
             if ($info->{pointTypeSet} eq "utriangle") { $openPoint = 10; $closedPoint = 11; }
             if ($info->{pointTypeSet} eq "diamond")   { $openPoint = 12; $closedPoint = 13; }
          }
          
        }
      }

      my ($actComb, $actCombSSD, $actMiss, $actMissSSD, $actFa, $actFaSSD) = $detset->getDETForID($d)->getMetric()->getActualDecisionPerformance();
      my ($sysSum, $sysAvg, $sysSSD) = $detset->getDETForID($d)->getTrials()->getTotNumSys();
      if ($sysSum == 0) {
        push @PLOTCOMS, "  -10000 title \""._gnuplotSafeString($detset->getDETForID($d)->{LINETITLE})." Omitted - No Data\" with linespoints lc $color lw $lineWidth pt $closedPoint ps $thisPointSize";

        ### Skip the rest BECAUSE There is NO DATA to plot
        next;
      }
    
       my $troot = sprintf("%s.%s",$fileRoot, $detset->getFSKeyForID($d));
       
       #########  Since this is recursive, the title gets appended with the sub-title the set it back
       my $saveTitle = $self->{title};
       $self->{title} .= " - " . $detset->getTitleForID($d);
       my $ret = $self->writeGNUGraph($troot, $detset->getDETForID($d));
       $self->{title} = $saveTitle;
       
       if ($ret) {                        
        my $ltitle = $lineTitle;
        my ($xcol, $ycol);
    
        ### Add the PERF Box BEFORE the First DET Curve
        if (exists($self->{PerfBox}) && $d == 0){
          ### Make the plot commands  
          my $boxDef = $self->{PerfBox};
          my $nbox = 0;
          foreach my $box (@$boxDef){
            my $xcol = ($xScale eq "nd" ? "2" : "4") + ($nbox*4);
            my $ycol = ($yScale eq "nd" ? "1" : "3") + ($nbox*4);
            my $title = "notitle";
            $title = "title \"$box->{title}\"" if (exists($box->{title}));
            push @PLOTCOMS, sprintf("   '$troot.dat.4' using $xcol:$ycol $title with filledcurves lt $box->{color}");
            $nbox++;
          }
        }
                         
        ### The curve
        $xcol = ($xScale eq "nd" ? "3" : "5");
        $ycol = ($yScale eq "nd" ? "2" : "4");
        if ($self->{DETShowPoint_Actual} || ($self->{DETShowPoint_Best}) || $self->{DETShowPoint_Ratios}){
          ### PLOT the Curve with NO TITLE because it will be used for the 1st point 
          push @PLOTCOMS, "  '$troot.dat.1' using $xcol:$ycol notitle with lines lc $color lw $lineWidth";
        } else { 
          push @PLOTCOMS, "  '$troot.dat.1' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with lines lc $color lw $lineWidth";
          $ltitle = "";
        }
        
        ### Actual
        if ($self->{DETShowPoint_Actual}){
          $xcol = ($xScale eq "nd" ? "11" : "9");
          $ycol = ($yScale eq "nd" ? "10" : "8");
          
          $ltitle .= " - " if ($ltitle ne "");
          $ltitle .= $self->_getLineTitleString("Actual", 0, $detset->getDETForID($d), 
                                                \@offAxisLabels, $color, $openPoint, $thisPointSize, 0); 
          push @PLOTCOMS, "    '$troot.dat.2' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with linespoints lc $color pt $openPoint ps $thisPointSize";
          ## Clear out the title!
          $ltitle = "";
        }
        
        ### The BEST point
        if ($self->{DETShowPoint_Best}){
          $xcol = ($xScale eq "nd" ? "6" : "4");
          $ycol = ($yScale eq "nd" ? "5" : "3");

          $ltitle .= " - " if ($ltitle ne "");
          $ltitle .= $self->_getLineTitleString("Best", 0, $detset->getDETForID($d),
                                                \@offAxisLabels, $color, $closedPoint, $thisPointSize, 0); 
          push @PLOTCOMS, "  '$troot.dat.2' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with points lc $color pt $closedPoint lw $lineWidth ps $thisPointSize";

          ## Clear out the title!
          $ltitle = "";
        }
        
        ### If I want iso ratio points
        if ($self->{DETShowPoint_Ratios}){
          $xcol = ($xScale eq "nd" ? "6" : "4");
          $ycol = ($yScale eq "nd" ? "5" : "3");
          foreach my $ratio(@{ $self->{Isoratiolines} }){    
            $ltitle .= " - " if ($ltitle ne "");
            $ltitle .= $self->_getLineTitleString("ErrorRatio", $ratio, $detset->getDETForID($d),
                                                  \@offAxisLabels, $color, $closedPoint, $thisPointSize, 0); 
            push @PLOTCOMS, "  '$troot.dat.3' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with points lc $color pt $closedPoint lw $lineWidth ps $thisPointSizeDiv2";
            ## Clear out the title!
            $ltitle = "";
          }
        }

      }

    }
        
    ### open  the jointPlot
    #    print "Writing DET to GNUPLOT file $fileRoot.*\n";
    open (MAINPLT,"> $fileRoot.plt") ||
      die("unable to open DET gnuplot file $fileRoot.plt");
    $self->write_gnuplot_DET_header($detset->getDETForID(0)->{METRIC}, *MAINPLT, \@offAxisLabels);
    print MAINPLT join(",\\\n", @PLOTCOMS);
    close MAINPLT;


    if ($self->{makePNG}) {
      $multiInfo{COMBINED_DET_PNG} = "$fileRoot.png";
      buildPNG($fileRoot, (exists($self->{gnuplotPROG}) ? $self->{gnuplotPROG} : undef), $self->{HD}, $self->{AutoAdapt});
    }
    \%multiInfo;
  }

sub writeGNUGraph{
  my ($self, $fileRoot, $det) = @_;
  
  my $metric = $det->getMetric();
  
  $self->_extractMetricProps($metric);

  ### Consult the properties
  my $xScale = $self->{props}->getValue("xScale");
  my $yScale = $self->{props}->getValue("yScale");    

  my ($missStr, $faStr, $combStr) = ( $metric->errMissLab(), $metric->errFALab(), $metric->combLab());
  my $combType = ($ metric->combType() eq "minimizable" ? "Min" : "Max");

  ## Make sure the points are computed
  $det->computePoints();

  my $points = $det->getPoints();
  if (!defined($points)) {
    print STDERR "WARNING: Writing DET plot to $fileRoot.* failed.  Points not computed\n";
    return 0;
  }
 
  ### Serialize the file for later usage
  $det->serialize("$fileRoot.srl") if ($self->{serialize});
  
  ### Set labels for off-graph points
  my @offAxisLabels = ();                                                                                                     

  ### $this text element constitutes the extra plot commands for the graph
  my @PLOTCOMS = ();

 	### Draw the isometriclines
  $self->_drawIsometriclines($fileRoot, \@PLOTCOMS, \@offAxisLabels, $metric);

  ### Draw the isoratiolines
  $self->_drawIsoratiolines($fileRoot, \@PLOTCOMS, $metric);
        
  open(THRESHPLT,"> $fileRoot.thresh.plt") ||
    die("unable to open DET gnuplot file $fileRoot.thresh.plt");

  ### The line data file
  my $withErrorCurve = 1;
  open(DAT,"> $fileRoot.dat.1") ||
    die("unable to open DET gnuplot file $fileRoot.dat.1"); 
  print DAT "# DET Graph made by DETCurve\n";
  print DAT "# Trial Params = ".($det->getTrials()->getTrialParamsStr())."\n";
  print DAT "# Metric Params = ".($metric->getParamsStr(""))."\n";
  #    print DAT "# DET Type: $typeStr\n";
  print DAT "# Abbreviations: ssd() is the sample Standard Deviation of a Variable\n";
  print DAT "#                ppndf() is the normal deviant of a probability. ppndf(.5)=0\n"; 
  print DAT "#                -2SE(v) is v - 2(StandardError(v)) = v - 2 * (sampleStandardDev / sqrt(n-1)\n";
  print DAT "#                        the value \"NA\" is used when n <= 1\n"; 
  print DAT "# 1:score 2:ppndf($missStr) 3:ppndf($faStr) 4:$missStr 5:$faStr 6:$combStr 7:ppndf(-2SE($missStr)) 8:ppndf(-2SE($faStr)) 9:ppndf(+2SE($missStr)) 10:ppndf(+2SE($faStr)) 11:-2SE($missStr) 12:-2SE($faStr) 13:+2SE($missStr) 14:+2SE($faStr) 15:SE($combStr)\n";
  for (my $i=0; $i<@{ $points }; $i++) {
      my @a = ($points->[$i][0], 
               ppndf($points->[$i][1]), 
               ppndf($points->[$i][2]),
               $points->[$i][1],
               $points->[$i][2],
               $points->[$i][3]);
      if ($points->[$i][7]-1 <= 0) {
        push @a, "NA NA NA NA NA NA NA NA";
      } else {
        push @a, (ppndf($points->[$i][1] - 2*($points->[$i][4] / sqrt($points->[$i][7]))), 
                  ppndf($points->[$i][2] - 2*($points->[$i][5] / sqrt($points->[$i][7]))), 
                  ppndf($points->[$i][1] + 2*($points->[$i][4] / sqrt($points->[$i][7]))),
                  ppndf($points->[$i][2] + 2*($points->[$i][5] / sqrt($points->[$i][7]))),
                  ($points->[$i][1] - 2*($points->[$i][4] / sqrt($points->[$i][7]))),
                  ($points->[$i][2] - 2*($points->[$i][5] / sqrt($points->[$i][7]))),
                  ($points->[$i][1] + 2*($points->[$i][4] / sqrt($points->[$i][7]))),
                  ($points->[$i][2] + 2*($points->[$i][5] / sqrt($points->[$i][7]))),
                  ($points->[$i][2] - 2*($points->[$i][6] / sqrt($points->[$i][7]))));
      }
      push @a, "\n";
      print DAT join(" ",@a);
      $withErrorCurve = 0 if ($points->[$i][7]-1 <= 0)
  }
  close DAT;
    
  ### The points data file
  open(DAT,"> $fileRoot.dat.2") ||
    die("unable to open DET gnuplot file $fileRoot.dat.2"); 
  print DAT "# Points for DET Graph made by DETCurve\n";
  #     print DAT "# DET Type: $typeStr\n";
  print DAT "# 1:Best${combStr}DetectionScore 2:Best${combStr}Value 3:Best$missStr 4:Best$faStr 5:ppndf(Best$missStr) 6:ppndf(Best$faStr) 7:ActualComb 8:Actual$missStr 9:Actual$faStr 10:ppndf(Actual$missStr) 11:ppndf(Actual$faStr)\n";
  my ($scr, $comb, $miss, $fa) = ($det->getBestCombDetectionScore(),
                                  $det->getBestCombComb(),
				  $det->getBestCombMMiss(),
				  $det->getBestCombMFA());
  my ($actComb, $actCombSSD, $actMiss, $actMissSSD, $actFa, $actFaSSD) = $metric->getActualDecisionPerformance();
  print DAT "$scr $comb $miss $fa ".ppndf($miss)." ".ppndf($fa)." $actComb $actMiss $actFa ".ppndf($actMiss)." ".ppndf($actFa)."\n";
  close DAT; 
  
  ### The iso ratio points data file
  # print Dumper($det->{ISOPOINTS});
  if (defined($self->{Isoratiolines})){
    open(DAT,"> $fileRoot.dat.3") ||
      die("unable to open DET gnuplot file $fileRoot.dat.3"); 
    print DAT "# The iso ratio points for the DET curve\n";
    #     print DAT "# DET Type: $typeStr\n";
    print DAT "# 1:ratio 2:DetectionScore 3:$missStr 4:$faStr 5:ppndf($missStr) 6:ppndf($faStr)\n";
    foreach my $ratio(sort { $a <=> $b } @{ $self->{Isoratiolines}}){
      print DAT "$ratio ".$det->{ISOPOINTS}{$ratio}{INTERPOLATED_DETECTSCORE}." ".$det->{ISOPOINTS}{$ratio}{INTERPOLATED_MMISS}." ".$det->{ISOPOINTS}{$ratio}{INTERPOLATED_MFA}.
          " ".ppndf($det->{ISOPOINTS}{$ratio}{INTERPOLATED_MMISS})." ".ppndf($det->{ISOPOINTS}{$ratio}{INTERPOLATED_MFA})."\n";
    }
    close DAT; 
  } 
  
  ### use the properties
#  my $color = $self->{colorsRGB}->[ $d % scalar(@{ $self->{colorsRGB} }) ];
  my $pointSize = $self->{pointSize};
  my $pointSizeDiv2 = $pointSize / 2;
 
  my ($curveColor, $errCurveColor, $randomColor) = (2, 3, 1); 
  if ($self->{props}->getValue("ColorScheme") eq "grey"){
    ($curveColor, $errCurveColor, $randomColor) = ($self->{colorsRGB}->[1], $self->{colorsRGB}->[2], $self->{colorsRGB}->[0]);
  }
  
  ### Include a random Curve?
  if ($self->{props}->getValue("MissUnit") ne "Prob" || $self->{props}->getValue("FAUnit") ne "Prob"){
    push @PLOTCOMS, "  -x title 'Random Performance' with lines lc $randomColor";
  }  

  ### Set the title
  my $ltitle = $self->{title};
  my ($xcol, $ycol);

  ### This is ONLY the linetrace
  $xcol = ($xScale eq "nd" ? "3" : "5");
  $ycol = ($yScale eq "nd" ? "2" : "4");
  if ($self->{DETShowPoint_Actual} || ($self->{DETShowPoint_Best}) || $self->{DETShowPoint_Ratios}){
    push @PLOTCOMS, "    '$fileRoot.dat.1' using $xcol:$ycol notitle with lines lc $curveColor";
  } else {  
    push @PLOTCOMS, "    '$fileRoot.dat.1' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with lines lc $curveColor";
    $ltitle = "";
  }
  
  ### Actual for the DET
  if ($self->{DETShowPoint_Actual}){
    $ltitle .= " - " if ($ltitle ne "");
    $ltitle .= $self->_getLineTitleString("Actual", 0, $det, 
                                          \@offAxisLabels, $curveColor, 6, $pointSize, 0); 

    $xcol = ($xScale eq "nd" ? "11" : "9");
    $ycol = ($yScale eq "nd" ? "10" : "8");
    push @PLOTCOMS, sprintf("   '$fileRoot.dat.2' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with linespoints lc $curveColor pt 6 ps $pointSize ");

#    $ltitle  .= " Actual ".sprintf("$combStr=%.3f", $actComb);
#    my $bestlab = $self->_getOffAxisLabel($miss, $fa, 2, 7, $pointSize, 0); 
#    push (@offAxisLabels, $bestlab) if ($bestlab ne "");
#    $xcol = ($xScale eq "nd" ? "11" : "9");
#    $ycol = ($yScale eq "nd" ? "10" : "8");
#    push @PLOTCOMS, sprintf("   '$fileRoot.dat.2' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with linespoints lc $curveColor pt 6 ps $pointSize ");
#    my $lab = $self->_getOffAxisLabel($actMiss, $actFa, 2, 6, $pointSize, 0); 
#    push (@offAxisLabels, $lab) if ($lab ne "");
    
    ## Clear out the title!
    $ltitle = "";
  }

  ### The BEST point
  if ($self->{DETShowPoint_Best}){
    $xcol = ($xScale eq "nd" ? "6" : "4");
    $ycol = ($yScale eq "nd" ? "5" : "3");

    $ltitle .= " - " if ($ltitle ne "");
    $ltitle .= $self->_getLineTitleString("Best", 0, $det, 
                                          \@offAxisLabels, $curveColor, 7, $pointSize, 0); 

    push @PLOTCOMS, sprintf("    '$fileRoot.dat.2' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with points lc $curveColor pt 7 ps $pointSize");
    ## Clear out the title!
    $ltitle = "";
  }
  
  ### Error curves
  if ($withErrorCurve) {
    $ltitle .= " - " if ($ltitle ne "");
    $ltitle .= "+/- 2 Standard Error";
    $xcol = ($xScale eq "nd" ? "8" : "12");
    $ycol = ($yScale eq "nd" ? "7" : "13");
    push @PLOTCOMS, sprintf("  '$fileRoot.dat.1' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with lines lc $curveColor"); 
    $xcol = ($xScale eq "nd" ? "10" : "14");
    $ycol = ($yScale eq "nd" ? "9" : "13");
    push @PLOTCOMS, "  '$fileRoot.dat.1' using $xcol:$ycol notitle with lines lc $curveColor";
    ## Clear out the title!
    $ltitle = "";
  }

  
  ### if the we want the ratio points 
  if ($self->{DETShowPoint_Ratios}){
    $xcol = ($xScale eq "nd" ? "6" : "4");
    $ycol = ($yScale eq "nd" ? "5" : "3");
    foreach my $ratio(@{ $self->{Isoratiolines} }){    
      $ltitle .= " - " if ($ltitle ne "");
      $ltitle .= $self->_getLineTitleString("ErrorRatio", $ratio, $det,
                                                  \@offAxisLabels, $curveColor, 7, $pointSize, 0); 
      push @PLOTCOMS, sprintf("    '$fileRoot.dat.3' using $xcol:$ycol title '"._gnuplotSafeString($ltitle)."' with points lc $curveColor pt 7 ps $pointSizeDiv2");  
      ## Clear out the title!
      $ltitle = "";
    }
  }

  ### Make the boxes
  if (exists($self->{PerfBox})){
#    print MMisc::get_sorted_MemDump($self->{PerfBox}) . "\n";
    ### Build the data file
    my $boxDef = $self->{PerfBox};
    open(DAT,"> $fileRoot.dat.4") ||
      die("unable to open DET gnuplot file $fileRoot.dat.4"); 
    print DAT "# The driver file for the performance boxes.  This file contains ".scalar(@$boxDef)." quartets of coordinates for each box.\n";
    #     print DAT "# DET Type: $typeStr\n";
    print DAT "# [ ppndf($missStr) ppndf($faStr) $missStr $faStr ]+\n";
    foreach my $box(@$boxDef){   print DAT ppndf($box->{MMiss})." ".ppndf(0.0).        " ".$box->{MMiss}." ".(0.0).      " ";   }
    print DAT "\n";
    foreach my $box(@$boxDef){   print DAT ppndf($box->{MMiss})." ".ppndf($box->{MFA})." ".$box->{MMiss}." ".$box->{MFA}." ";   }
    print DAT "\n";
    foreach my $box(@$boxDef){   print DAT ppndf(0.0).          " ".ppndf($box->{MFA})." ".(0.0)        ." ".$box->{MFA}." ";   }
    print DAT "\n";
    foreach my $box(@$boxDef){   print DAT ppndf(0.0).          " ".ppndf(1.0).        " ".(0.0)        ." ".(1.0)      ." ";   }
    print DAT "\n";
    close DAT; 
    ### Make the plot commands  
    my $nbox = 0;
    foreach my $box(@$boxDef){
      $xcol = ($xScale eq "nd" ? "2" : "4") + ($nbox*4);
      $ycol = ($yScale eq "nd" ? "1" : "3") + ($nbox*4);
      my $title = "notitle";
      $title = "title \"$box->{title}\"" if (exists($box->{title}));
      push @PLOTCOMS, sprintf("   '$fileRoot.dat.4' using $xcol:$ycol $title with filledcurves lt $box->{color}");
      $nbox++;
    }
  }

  #    print "Writing DET to GNUPLOT file $fileRoot.*\n";
  open(PLT,"> $fileRoot.plt") ||
    die("unable to open DET gnuplot file $fileRoot.plt");
  $self->write_gnuplot_DET_header($metric, *PLT, \@offAxisLabels);
  print PLT join(",\\\n",@PLOTCOMS);
  close PLT;
  
  if ($self->{BuildPNG}) {
    buildPNG($fileRoot, $self->{gnuplotPROG}, $self->{HD}, $self->{AutoAdapt});
    $det->setDETPng("$fileRoot.png");
  }
  
  ########################  THRESHOLD PLOT  ####################################
  my ($threshMin, $threshMax) = ($det->getMinDecisionScore(), $det->getMaxDecisionScore());
  if (!defined($threshMin)){
    $threshMin = 0;
    $threshMax = 1;
  } elsif ($threshMin == $threshMax) {
    $threshMin -= 0.000001;
    $threshMax += 0.000001;
  }
  $self->write_gnuplot_threshold_header(*THRESHPLT, "Threshold Plot for $self->{title}");
  if (defined($threshMin)){
    print THRESHPLT "plot [$threshMin:$threshMax]  \\\n";
    print THRESHPLT "  '$fileRoot.dat.1' using 1:4 title '$missStr' with lines lt 2, \\\n";
    print THRESHPLT "  '$fileRoot.dat.1' using 1:5 title '$faStr' with lines lt 3, \\\n";
    print THRESHPLT "  '$fileRoot.dat.1' using 1:6 title '$combStr' with lines lt 4";
    if ($self->{DETShowPoint_Actual}){
      print THRESHPLT ", \\\n  $actComb title 'Actual $combStr ".sprintf("%.3f",$actComb)."' with lines lt 5";
    }
    if (defined($det->getBestCombComb())) {
      print THRESHPLT ", \\\n  '$fileRoot.dat.2' using 1:2 title '$combType $combStr ".sprintf("%.3f, scr %.3f",$comb,$scr)."' with points lt 6";
#      print THRESHPLT ", \\\n  ".$det->getBestCombComb()." title '$combType $combStr' with lines lt 6";
    }
    print THRESHPLT "\n";
  } else {
    print THRESHPLT "set label \"No detection outputs produced by the system.  Threshold plot is empty.\" at graph 0.2, graph 0.5\n";
    print THRESHPLT "set size ratio 1\n"; 
    print THRESHPLT "plot [0:1] [0:1] -x notitle with points\n";
  }
  close THRESHPLT;
  if ($self->{BuildPNG}) {
    buildPNG($fileRoot.".thresh", $self->{gnuplotPROG}, $self->{HD}, $self->{AutoAdapt});
    $det->setThreshPng("$fileRoot.thresh.png");
  }
  1;
}

## This is NOT and instance method
### To see the test pattern: (echo set terminal png medium size 600,400; echo test) | gnuplot > foo.png
sub buildPNG
{
  my ($fileRoot, $gnuplot, $hd, $aa) = @_;
  
  my ($w, $h, $sp1, $sp2) = ($hd) ? (3000, 3000, 6, 6) : (800, 800, 12, 12);
  
#  print "\n** [$fileRoot, $gnuplot, $hd, $aa | $w, $h, $sp1, $sp2]\n";
  if (MMisc::is_blank($gnuplot)) {
    (my $err, $gnuplot, my $version) = &get_gnuplotcmd();
    MMisc::error_quit($err) if (! MMisc::is_blank($err));
  } 
  
  my $hasbMargin = 0;
  my $numTitle = 0;
  my $inPlot = 0;
  ### Pre-read the file to count titles so that IF 'set key bmargin' is used, it looks good. 
  open (FILE, $fileRoot.".plt") || die "Error: Failed to open GNUPLOT driver file '$fileRoot.plt' for read\n";
  while (<FILE>){
    if ($_ =~ /plot\s+\[/) { $inPlot = 1; }
    if ($_ =~ /set\s+key\s+bmargin/) { $hasbMargin = 1; }
    if ($inPlot && $_ =~ /\susing\s.*\s+title\s/) { $numTitle++; }
#    print "$_";
  }
  close FILE;
  #MMisc::error_quit("[$fileRoot]");
  
#  my $font = ($hd) ? "font arial 20" : "medium";
  my $font = ($hd) ? "font arial 20" : "font Verdana 11";

  ## Use this with gnuplot 3.X
  #	system("cat $fileRoot.plt | perl -pe \'\$_ = \"set terminal png medium \n\" if (\$_ =~ /set terminal/)\' | gnuplot > $fileRoot.png");
  #    my $newTermCommand = "set terminal png medium size 10000,10000 crop xffffff x000000 x404040 x000000 xc0c0c0 x909090 x606060   x000000 xc0c0c0 x909090 x606060";

  my ($W, $H) = ($w + $aa, $h + $aa);
  my $sedv = $bvc;

  if ($hasbMargin){
    my $sp = $sp2;
    if ($numTitle > 10) { # After 10, we try to force double columns
      $sp = $sp1;
      $sedv = $bvh; # switch labels from vertical to horizontal
    }
 
    $W = $w + ($aa * (1 + $hd));
    $H = $h + ($aa/2) + ($numTitle*$sp);
  }

  my $newTermCommand = "set terminal png truecolor $font size " . sprintf("%d,%d", $W ,$H) . " crop";

  my $pngf = "$fileRoot.png";

  my $ipf = "$fileRoot.plt";
  open IFILE, "<$ipf"
    or MMisc::error_quit("Problem using input plot file ($ipf) : $!");
  my $ipfc = "";
  while (my $line = <IFILE>) {
    $line =~ s%$bvc%$sedv%;
    $line =~ s%^set terminal.+$%$newTermCommand%;
    if (($hd) && ($line =~ m%with\s+lines\s+lt\s+(\d+)(\s*\,)*%)) {
      my $v = sprintf("%d", (2*$1)+1);
      $line =~ s%(with\s+lines\s+lt\s+\d+)(\s*\,)?%$1 lw $v $2%;
    }
    if (($hd) && ($line =~ m%with\s+linespoints\s+lc\s+\d+\s+pt\s+\d+\s+ps\s+(\d+)%)) {
      my $v = sprintf("%d", (1.5*$1)+1);
      $line =~ s%(with\s+linespoints\s+lc\s+\d+\s+pt\s+\d+\s+ps\s+\d+)%$1 lw $v%;
    }    
    $ipfc .= $line;
  }

  my $opf = "$fileRoot\_png.plt";
  open OFILE, ">$opf"
    or MMisc::error_quit("Problem opening output plot file ($opf) : $!");
  print OFILE $ipfc;
  close OFILE;
#  print "[$opf] $ipfc";


  system("cat $opf | $gnuplot > $pngf");
  
  if ($aa) {
    my $cmd = "identify $pngf";
    my ($rc, $stdout, $stderr) = MMisc::do_system_call($cmd);
    MMisc::error_quit("Could not run \'$cmd\'") if ($rc != 0);
    # ex: 05-Reports/Comps_00/CellToEar/global.det.png PNG 795x1848
    if ($stdout =~ m%PNG\s+(\d+)x(\d+)%) {
      my ($x, $y) = ($1, $2);
#      print " ****** [$x / $y] *****\n";
      return() if ($x > ($w*0.9)); # at least 90% of expected width !
    } else {
      MMisc::error_quit("Could not extract size of PNG");
    }
    
    &buildPNG($fileRoot, $gnuplot, $hd, $aa + 100); # add 100 pixels to height
  }
  
}

####################
my $gnuplotcmdb = "gnuplot";
my $gnuplotcmd = "";
my $gnuplotminv = "4.2";

sub get_gnuplotcmd { 
  return("", $gnuplotcmd, "")
    if (! MMisc::is_blank($gnuplotcmd));

  $gnuplotcmd = MMisc::cmd_which($gnuplotcmdb);
  my ($err, $version) = &__check_gnuplot();
  return($err, $gnuplotcmd, $version);
}

##
sub __check_gnuplot {
  return("No gnuplot command location information")
    if (MMisc::is_blank($gnuplotcmd));

  my $cmd = "$gnuplotcmd --version";
  my ($rc, $oso, $se) = MMisc::do_system_call($cmd);
  return("Problem obtaining Gnuplot ($gnuplotcmd) version [using: $cmd]")
    if ($rc != 0);
  chomp($oso);
  my $so = $oso;
  return("version information does not start with proper \'gnuplot\' keyword ($so)")
    if (! ($so =~ s%^gnuplot\s%%));

  # gnuplot 4.2 patchlevel 5 -> 4.2.0.5
  $so =~ s%^(\d+\.\d+)\s%$1.0%;
  $so =~ s%\s*patchlevel\s+%.%;
  $so =~ s%\s+$%%;

  my ($err, $bv) = MMisc::get_version_comp($gnuplotminv, 5, 1000);
  return("Problem obtaining default version number ($err)") 
    if (! MMisc::is_blank($err));
  my ($err, $cv) = MMisc::get_version_comp($so, 5, 1000);
  return("Problem obtaining comparable version number ($err) [$oso / $so]") 
    if (! MMisc::is_blank($err));
  
  return("Version of Gnuplot ($so) [at: $gnuplotcmd] is not at least minimum required version ($gnuplotminv)")
    if ($cv < $bv);

  return("", $oso);
}


####################
1;
