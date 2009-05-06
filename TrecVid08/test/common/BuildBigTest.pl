#!/usr/bin/env perl

use strict;
use Math::Random::OO::Normal;
use Data::Dumper;

sub makeCSV(){
    my ($eventID, $miss, $missActPct, $fa, $faActPct, $omitPct, $durFrame) = @_;

    my $faThreshIndex = sprintf("%d",scalar(@$fa) - (scalar(@$fa)*$faActPct));
    my $faMid = ($fa->[$faThreshIndex] + $fa->[$faThreshIndex-1])/2; 
    print "faThreshIndex = $faThreshIndex, mid = $faMid\n";

    my $missThreshIndex = sprintf("%d",scalar(@$miss)*$missActPct);
    my $missMid = ($miss->[$missThreshIndex] + $miss->[$missThreshIndex-1])/2; 
    print "missThreshIndex = $missThreshIndex, mid = $missMid\n";

    my $omitThreshIndex = sprintf("%d",scalar(@$miss)*$omitPct);
    print "omitThreshIndex = $omitThreshIndex\n";
    
    ### Make the references
    my @refs = ();
    my $id = 0;
    for (my $m=0; $m<@$miss; $m++){
	push @refs, [ (($m+1)*100, ($m+1)*100+50, $id++) ];
    }
#    print Dumper(\@refs);

    my @sysMiss = ();
    ### Make the miss occurrences
    $id = 0;
    my $start = 100;
    for (my $m=0; $m<@$miss; $m++){
	  my $dec = ($m < $missThreshIndex) ? "false" : "true";
	  my $snorm = $miss->[$m] - $missMid;
	
  	  push @sysMiss, [ ($start, $start+50, $id++, $miss->[$m], $snorm, $dec) ] if ($omitThreshIndex <= $m);
      $start += 100;
    }
#    print Dumper(\@sysMiss);

    my @sysFA = ();
    ### Make the FA occurrences
    for (my $f=0; $f<@$fa; $f++){
	my $dec = ($f < $faThreshIndex) ? "false" : "true";
	my $snorm = $fa->[$f] - $faMid;
	push @sysFA, [ ($start, $start+50, $id++, $fa->[$f], $snorm, $dec) ];
    $start += 100;
    }
#    print Dumper(\@sysFA);

    foreach my $data(@refs){
        my $obj = "      <object name=\"$eventID\" id=\"".$data->[2]."\" framespan=\"".$data->[0].":".$data->[1]."\">\n".
                  '        <attribute name="BoundingBox"/>'."\n".
                  '        <attribute name="DetectionDecision"/>'."\n".
                  '        <attribute name="DetectionScore"/>'."\n".
                  '        <attribute name="Point"/>'."\n".
                  '      </object>'."\n";
        print REF $obj;
    }
    foreach my $data(@sysMiss, @sysFA){
        my $obj = "      <object name=\"$eventID\" id=\"".$data->[2]."\" framespan=\"".$data->[0].":".$data->[1]."\">\n".
                  '        <attribute name="BoundingBox"/>'."\n".
                  '        <attribute name="DetectionDecision">'."\n".
                  "          <data:bvalue value=\"".$data->[5]."\"/>\n".
                  '        </attribute>'."\n".
                  '        <attribute name="DetectionScore">'."\n".
                  "          <data:fvalue value=\"".$data->[4]."\"/>\n".
                  '        </attribute>'."\n".
                  '        <attribute name="Point"/>'."\n".
                  '      </object>'."\n";
        print SYS $obj;
    }
        
}

sub head(){
    my $file = shift @_;
    my $durFrame = shift @_;

my $a = <<END;
<?xml version="1.0" encoding="UTF-8"?>
<viper xmlns="http://lamp.cfar.umd.edu/viper#" xmlns:data="http://lamp.cfar.umd.edu/viperdata#">
  <config>
    <descriptor name="Information" type="FILE">
      <attribute dynamic="false" name="SOURCETYPE" type="http://lamp.cfar.umd.edu/viperdata#lvalue">
        <data:lvalue-possibles>
          <data:lvalue-enum value="SEQUENCE"/>
          <data:lvalue-enum value="FRAMES"/>
        </data:lvalue-possibles>
      </attribute>
      <attribute dynamic="false" name="NUMFRAMES" type="http://lamp.cfar.umd.edu/viperdata#dvalue"/>
      <attribute dynamic="false" name="FRAMERATE" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="false" name="H-FRAME-SIZE" type="http://lamp.cfar.umd.edu/viperdata#dvalue"/>
      <attribute dynamic="false" name="V-FRAME-SIZE" type="http://lamp.cfar.umd.edu/viperdata#dvalue"/>
    </descriptor>
    <descriptor name="ObjectPut" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="ObjectGet" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="OpposingFlow" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="TakePicture" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="UseATM" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="PeopleMeet" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="VestAppears" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="CellToEar" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="PeopleSplitUp" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="Embrace" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="SitDown" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="ElevatorNoEntry" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="PersonRuns" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="ObjectTransfer" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="DoorOpenClose" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="Pointing" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
    <descriptor name="StandUp" type="OBJECT">
      <attribute dynamic="true" name="BoundingBox" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
      <attribute dynamic="false" name="DetectionDecision" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="false" name="DetectionScore" type="http://lamp.cfar.umd.edu/viperdata#fvalue"/>
      <attribute dynamic="true" name="Point" type="http://lamp.cfar.umd.edu/viperdata#point"/>
    </descriptor>
  </config>
  <data>
    <sourcefile filename="file:$file.mpg">
      <file id="0" name="Information">
        <attribute name="FRAMERATE">
          <data:fvalue value="25"/>
        </attribute>
        <attribute name="H-FRAME-SIZE"/>
        <attribute name="NUMFRAMES">
          <data:dvalue value="$durFrame"/>
        </attribute>
        <attribute name="SOURCETYPE"/>
        <attribute name="V-FRAME-SIZE"/>
      </file>
END
$a
}

sub tail(){
    "    </sourcefile>\n".   
    "  </data>\n".
    "</viper>\n";
}

my $distm0s1= Math::Random::OO::Normal->new(0,1);
my $distm0s2 = Math::Random::OO::Normal->new(0,2);
$distm0s1->seed(0.42);
$distm0s2->seed(0.84);

my $durHr = 1;
my $durFrame = $durHr * 3600 * 25;

open REF, "> test4-BigTest.ref.xml" || die;
print REF &head("TestBT", $durFrame);
    
open SYS, "> test4-BigTest.sys.xml" || die;
print SYS &head("TestBT", $durFrame);

&makeCSV("Pointing", [ fillArray($distm0s1, 25 * $durHr)  ], 0.5, 
                     [ fillArray($distm0s1, 25 * $durHr) ], 0.5 , 
         0.0);

&makeCSV("ObjectGet", [ fillArray($distm0s1, 25 * $durHr)  ], 0.3, 
                      [ fillArray($distm0s1, 25 * $durHr) ], 0.3 , 
         0.0);

&makeCSV("CellToEar", [ ()  ], 0.0, 
                      [ fillArray($distm0s1, 25 * $durHr) ], 0.3 , 
         0.0);

print REF tail();
print SYS tail();



sub fillArray(){
    my ($dist, $n) = @_;

    my @a = ();
    foreach (0..199){
	push @a, $dist->next();
    }
    sort { $a <=> $b } @a;
}



