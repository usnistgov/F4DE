#!/usr/bin/env perl

use lib ("../../lib", "../../../CLEAR07/lib", "../../../common/lib");

use strict;

use MMisc;
use AVSS09ViperFile;
use AVSS09HelperFunctions;

my $xsdpath = "../../../CLEAR07/data";
my ($retstatus, $object, $msg) = 
    AVSS09HelperFunctions::load_ViperFile(1, "../common/test_file3.clear.xml", 0, "", $xsdpath);

MMisc::error_quit("ERROR: $msg")
  if (! $retstatus);

my $inc = 0;

&obj_print(1, 1);

print "**********PRE\n";
my $dcf = MMisc::iuv($object->get_DCF(), "no DCF");
print "# DCF: $dcf\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());
##
my $ev = MMisc::iuv($object->get_evaluate_range(), "none");
print "# Ev: $ev\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

my %loc_fs_bbox = ( '10000:12010' => [100, 100, 200, 200] );
my $id = $object->create_DCR("10000:12010", \%loc_fs_bbox, "10500:11000");
MMisc::error_quit($object->get_errormsg()) if ($object->error());
print "** Created DCR [ID $id]\n";

&obj_print(1, 1);

my @idl = $object->get_person_id_list();
MMisc::error_quit($object->get_errormsg()) if ($object->error());
    
foreach my $id (@idl) {
  my ($fs) = $object->get_person_fs($id);
  print "########## ID: $id\n* fs     : $fs\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());
      
  my $dcr = MMisc::iuv($object->is_DCR($id), "not a DCR");
  print "* dcr    : $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());
      
  my $v = "11100:11200";
  my $dcr = MMisc::iuv($object->set_DCR($id, $v), "no framepsan part of DCR");
  print "* set dcr [$v]: $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());

  $v = "11000:11350";
  my $dcr = MMisc::iuv($object->set_DCR($id, $v), "no framepsan part of DCR");
  print "* set dcr [$v]: $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());

  &obj_print(1, 1);

  $v = "10550:10600";
  my $dcr = MMisc::iuv($object->unset_DCR($id, $v), "no framepsan part of DCR");
  print "* rem dcr [$v]: $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());

  $v = "10750:11000";
  my $dcr = MMisc::iuv($object->unset_DCR($id, $v), "no framepsan part of DCR");
  print "* rem dcr [$v]: $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());

  my $dcr = MMisc::iuv($object->unset_DCR($id), "no framepsan part of DCR");
  print "* rem dcr [full fs]: $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());
  
  my $dcr = MMisc::iuv($object->set_DCR($id), "no framepsan part of DCR");
  print "* set dcr [full object]: $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());
  
  my $dcr = MMisc::iuv($object->unset_DCR($id), "no framepsan part of DCR");
  print "* rem dcr [full fs]: $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());
  
  my $dcr = MMisc::iuv($object->is_DCR($id), "no framepsan part of DCR");
  print "* is dcr : $dcr\n";
  MMisc::error_quit($object->get_errormsg()) if ($object->error());

  &obj_print(1, 1);

}

print "##### DCF\n";
my $dcf = MMisc::iuv($object->get_DCF(), "no DCF");
print "# DCF: $dcf\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

my $v = "200:5000 5100:6000";
my $dcf = MMisc::iuv($object->add_DCF($v), "no DCF");
print "# Add DCF [$v] : $dcf\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

$v = "500:1000";
my $dcf = MMisc::iuv($object->remove_DCF($v), "no DCF");
print "# Rem DCF [$v] : $dcf\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

&obj_print(1, 1);

print "##### EVALUATE\n";
my $ev = MMisc::iuv($object->get_evaluate_range(), "none");
print "# Ev: $ev\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

my $ev = MMisc::iuv($object->set_evaluate_all(), "none");
print "# Ev [all]: $ev\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

my $v = "200:5000 5100:6000";
my $ev = MMisc::iuv($object->set_evaluate_range($v), "none");
print "# Set Ev [$v] : $ev\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

$v = "500:1000";
my $ev = MMisc::iuv($object->set_evaluate_range($v), "none");
print "# Set Ev [$v] : $ev\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

my $ev = MMisc::iuv($object->get_evaluate_range(), "none");
print "# Ev: $ev\n";
MMisc::error_quit($object->get_errormsg()) if ($object->error());

&obj_print(1, 1);

## END
print "\n\n\n";
MMisc::ok_quit("OK");

sub obj_print {
  my ($txt) = $object->reformat_xml();
  my $doval   = shift @_;
  my $doprint = shift @_;

  &doprint($txt) if ($doprint);

  return() if (! $doval);

  my $fname = "/tmp/AVSS09_special_test1-temp_file_" . $inc++ . ".xml";
  MMisc::error_quit("Problem during rewrite")
      if (! $object->write_XML($fname, 1, ""));

  my ($retstatus, $obj, $msg) = 
    AVSS09HelperFunctions::load_ViperFile(1, $fname, 0, "", $xsdpath);

  MMisc::error_quit("ERROR reloading rewritten file: $msg")
      if (! $retstatus);
  print " --> Loaded written XML file and validated ok\n";
}

#####

sub doprint {
  my ($txt) = @_;
    print<<EOF
\n\n\n\n\n# Object rewrite:
****************************************
$txt
****************************************
\n\n
EOF
      ;
}
