package AVSS09HelperFunctions;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# AVSS09 Helper Functions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS09ECF.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

use MMisc;

use AVSS09ViperFile;
use AVSS09ECF;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "AVSS09HelperFunctions.pm Version: $version";

########################################

sub load_ViperFile {
  my ($isgtf, $filename, $frameTol, $xmllint, $xsdpath) = @_;

  my $ok_domain = AVSS09ViperFile::get_okdomain();
  my $cdtspmode = AVSS09ViperFile::get_cdtspmode();

  my ($ok, $cldt, $msg) = CLEARDTHelperFunctions::load_ViperFile
    ($isgtf, $filename, $ok_domain, $frameTol, $xmllint, $xsdpath, $cdtspmode);

  return($ok, undef, $msg)
    if (! $ok);

  my $it = AVSS09ViperFile->new($cldt);
  return(0, undef, $msg . $it->get_errormsg())
    if ($it->error());

  my $ok = $it->validate();
  return(0, undef, $msg . $it->get_errormsg())
    if ($it->error());
  return($ok, undef, $msg . "Problem during validation process")
    if (! $ok);

  return(1, $it, $msg . "");
}

##########

sub VF_write_XML_MemDumps {
  my ($vf, $fname, $isgtf, $MemDump, $skSSM, $stdouttext) = @_;

  my ($err, $ndf) = $vf->write_XML($fname, $isgtf, $stdouttext);
  MMisc::error_quit($err) if (! MMisc::is_blank($err));   
  
  if (defined $MemDump) {
    $vf->write_MemDumps($ndf, $isgtf, $MemDump, $skSSM);
    MMisc::error_quit("Problem while trying to perform \'MemDump\'")
        if ($vf->error());
  }

  return($ndf);
}

##########

sub load_ECF_file {
  my ($file, $xmllint, $xsdpath) = @_;

  my $err = MMisc::check_file_r($file);
  return($err, undef) if (! MMisc::is_blank($err));
  
  # Prepare the object
  my $object = new AVSS09ECF();
  return("While trying to set \'xmllint\' : " . $object->get_errormsg(), undef)
    if ( (! MMisc::is_blank($xmllint)) && (! $object->set_xmllint($xmllint)) );

  return("While trying to set \'TrecVid08xsd\' : " . $object->get_errormsg(), undef)
    if ( (! MMisc::is_blank($xsdpath)) && (! $object->set_xsdpath($xsdpath)) );

  return("While setting \'file\' ($file) : " . $object->get_errormsg() , undef)
    if ( ! $object->set_file($file) );

  return("Validating: " . $object->get_errormsg(), undef)
    if (! $object->validate());

  return("", $object);
}

##########

sub clone_VF_apply_ECF_for_ttid {
  my ($vf, $ecf, $ttid, $verb) = @_;

  return($vf->get_errormsg()) if ($vf->error());
  return($ecf->get_errormsg()) if ($ecf->error());

  my ($sffn) = $vf->get_sourcefile_filename();
  return($vf->get_errormsg()) if ($vf->error());

  return("Sourcefile ($sffn) is not part of tracking trial ($ttid)")
    if (! $ecf->is_sffn_in_ttid($ttid, $sffn));

  my ($isgtf) = $vf->check_if_gtf();
  return($vf->get_errormsg()) if ($vf->error());
  return("Can only apply an ECF to a GTF") if (! $isgtf);

  my $count = 0;

  print $count++, ") Clone ViperFile\n" if ($verb);
  my $nvf = $vf->clone();
  return($vf->get_errormsg()) if ($vf->error());
  return("Got no clone") if (! defined $nvf);
  
  ##### 1) EVALUATE
  # Get from ECF
  my $evfs = $ecf->get_ttid_sffn_evaluate($ttid, $sffn);
  return($ecf->get_errormsg()) if ($ecf->error());
  # Apply to the new VF
  print $count++, ") Applying Evaluate [$evfs]\n" if ($verb);
  my $res = $nvf->set_evaluate_range($evfs);
  return($nvf->get_errormsg()) if ($nvf->error());
  print " -> Evaluate [$res]\n" if ($verb);

  ##### 2) DCF
  # Get from ECF
  my ($dcffs) = $ecf->get_ttid_sffn_dcf($ttid, $sffn);
  return($ecf->get_errormsg()) if ($ecf->error());
  # Apply to the new VF (if any)
  if (defined $dcffs) {
    print $count++, ") Applying DCF [$dcffs]\n" if ($verb);
    my $res = $nvf->add_DCF($dcffs);
    return($nvf->get_errormsg()) if ($nvf->error());
    print " -> DCF [$res]\n" if ($verb);
  }

  ##### 3) DCR
  # Get from ECF
  my $rdcr = $ecf->get_ttid_sffn_dcr($ttid, $sffn);
  return($ecf->get_errormsg()) if ($ecf->error());
  # Apply to the new VF (if any)
  if (scalar @$rdcr > 0) {
    foreach my $rh (@$rdcr) {
      my %h = MMisc::clone(%$rh);
      my @k = keys %h;
      return("Did not find 1 master key for DCR, found " . scalar @k)
        if (scalar @k != 1);
      my $fs = $k[0];
      my %loc_fs_bbox = %{$h{$fs}};
      print $count++, ") Creating DCR [$fs]\n" if ($verb);
      my $res = $nvf->create_DCR($fs, \%loc_fs_bbox);
      return($nvf->get_errormsg()) if ($nvf->error());
      print " -> ID [$res]\n" if ($verb);
    }
  }
  
  # All done
  return("", $nvf);
}

############################################################

1;
