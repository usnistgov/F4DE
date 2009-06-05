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
  my ($vf, $fname, $isgtf, $MemDump, $skSSM, $stdouttext, $ov) = @_;

  if ((! MMisc::is_blank($fname)) && (! $ov)) {
    my $efn = AVSS09ViperFile::get_XML_filename($fname);
    if (MMisc::does_file_exists($efn)) {
      MMisc::warn_print("Output ViperFile ($efn) already exists, and overwrite not requested, skippping XML and MemDumps (if any) rewrite");
      return($efn);
    }
  }

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
  if ((defined $rdcr) && (scalar @$rdcr > 0)) {
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

##########

sub load_DTScorer_ResultsCSV {
  my ($csvfile, $rsffnl, $rcid) = @_;

  my $err = MMisc::check_file_r($csvfile);
  return("Can not find CSV file ($csvfile): $err")
      if (! MMisc::is_blank($err));

  open CSV, "<$csvfile"
    or return("Problem opening CSV file ($csvfile): $!");

  my $csvh = new CSVHelper();
  return("Problem creating the CSV object: " . $csvh->get_errormsg())
    if ($csvh->error());

  my $header = <CSV>;
  return("CSV file contains no data ?")
    if (! defined $header);
  my @headers = $csvh->csvline2array($header);
  return("Problem extracting csv line:" . $csvh->get_errormsg())
    if ($csvh->error());
  return("CSV file ($csvfile) contains no usable data")
    if (scalar @headers < 2);

  my %pos = ();
  for (my $i = 0; $i < scalar @headers; $i++) {
    $pos{$headers[$i]} = $i;
  }

  my @needed = ("Video", "MOTA");
  foreach my $key (@needed) {
    return("Could not find needed key ($key) in results")
      if (! exists $pos{$key});
  }

  $csvh->set_number_of_columns(scalar @headers);
  return("Problem setting the number of columns for the csv file:" . $csvh->get_errormsg())
    if ($csvh->error());

  my %sffnh = ();
  # There is a strange tendency to uppercase the entire output scoring array
  # but we need the exact sffn value, so lowercase everything
  foreach my $sffn (@$rsffnl) {
    my $lcsffn = lc $sffn;
    return("Problem with lowercasing \'sffn\' keys ($sffn), an entry with the same name already exists")
      if (exists $sffnh{$lcsffn});
    $sffnh{$lcsffn} = $sffn;
  }

  my %cid = %$rcid;
  my %oh = ();
  my $cont = 1;
  while ($cont) {
    my $line = <CSV>;
    if (MMisc::is_blank($line)) {
      $cont = 0;
      next;
    }

    my @linec = $csvh->csvline2array($line);
    return("Problem extracting csv line:" . $csvh->get_errormsg())
      if ($csvh->error());
    my $sffn = $linec[$pos{$needed[0]}];
    my $mota = $linec[$pos{$needed[1]}];

    my $sffnk = lc $sffn;
    MMisc::error_quit("Could not find \'sffn\' ($sffn) in list of expected ones [or already processed ?]")
      if (! exists $sffnh{$sffnk});
    $sffn = $sffnh{$sffnk};
    delete $sffnh{$sffnk};

    return("Could not find \'sffn\' ($sffn) corresponding \'camid\' [available sffn: " . join(",", @$rsffnl) . "]")
      if (! exists $cid{$sffn});
    my $camid = $cid{$sffn};
    
    $oh{$camid} = $mota;
  }
  close(CSV);

  return("Missing some \'sffn\' results: " . join(",", keys %sffnh))
    if (scalar keys %sffnh > 0);

  return($err, %oh);
}

############################################################

1;
