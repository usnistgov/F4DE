package TrecVid08HelperFunctions;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 HelperFunctions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08HelperFunctions.pm" is an experimental system.
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


# $Id$

use strict;

use ViperFramespan;
use TrecVid08ViperFile;
use TrecVid08Observation;
use TrecVid08EventList;

use CSVHelper;

use MErrorH;
use MMisc;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08HelperFunctions.pm Version: $version";


############################################################
#################### 'ViperFile_crop' functions

sub ViperFile_crop {
  my ($vf, $beg, $end) = @_;

  return("ViperFile is not validated, aborting", undef)
    if (! $vf->is_validated());
  
  return("End frame before Beginning frame, aborting", undef)
    if ($beg > $end);
  
  return("Beginning frame less than 1, aborting", undef)
    if ($beg < 1);

  my $onf = $vf->get_numframes_value();
  return("Problem obtaining the ViperFile NUMFRAMES value (" . $vf->get_errormsg() . ")", undef)
    if ($vf->error());

  return("Requested end goes past the File's NUMFRAMES, can only crop known values", undef)
    if ($end > $onf);

  ## Cropping is a 2 steps operations:
  # - trim to select values
  # - shifting all elements so that frames start at 1

  # Get an observation representation of all the viper file
  my @ao = $vf->get_all_events_observations();
  return("Problem while obtaining Observations (" . $vf->get_errormsg() . ")", undef)
    if ($vf->error());

  # We need a ViperFramespan to work overlap
  my $fps = $vf->get_fps();
  return("Problem obtaining the ViperFile's fps (" . $vf->get_errormsg() . ")", undef)
    if ($vf->error());
  my $fs_range = new ViperFramespan();
  $fs_range->set_value_beg_end($beg, $end);
  $fs_range->set_fps($fps);
  return("Problem creating a ViperFramespan (" . $fs_range->get_errormsg() . ")", undef)
    if ($fs_range->error());
  my $fsr_txt = $fs_range->get_value();
  return("Problem obtaining the ViperFramespan's value (" . $fs_range->get_errormsg() . ")", undef)
    if ($fs_range->error());

  # Trim each observation in turn
  my @left = ();
  foreach my $obs (@ao) {
    # Check if the observation is even overlapping with the area
    my $fs_ov = $obs->get_framespan_overlap_from_fs($fs_range);
    return("Problem computing the range overlap (" . $obs->get_errormsg() . ")", undef)
      if ($obs->error());
    next if (! defined $fs_ov);

    # Now, Trim to the fs_range
    my $trim_done = $obs->trim_to_fs($fs_range);
    return("Problem trimming observation to selected range (" . $obs->get_errormsg() . ")", undef)
      if ($obs->error());
    next if (! $trim_done);

    push @left, $obs;
  }

  # Now we simply shift by (1 - beg)
  # ex: new beg is 2000 we shift by -1999 to start at 1
  my $fsshift = 1 - $beg;
  if ($fsshift != 0) {
    foreach my $obs (@left) {
      $obs->shift_framespan($fsshift);
      return("Problem shifting observation (" . $obs->get_errormsg() . ")", undef)
	if ($obs->error());
    }
  }

  # Prepare the output ViperFile
  my $vfc = $vf->clone_with_no_events();

  # Next step is to adapt the ViperFile's NUMFRAMES to its new boundaries
  my $nf = $end + $fsshift; # fsshift is negative
  my $an = $vfc->modify_numframes($nf, "Trimmed to [$fsr_txt], then shifted by $fsshift to have the first frame start at 1");
  return("Problem modifying numframes (" . $vfc->get_errormsg() . ")", undef)
    if ($vfc->error());

  # And finaly to add the observations to the newly created file
  foreach my $obs (@left) {
    $vfc->add_observation($obs, 1);
    return("Problem adding cropped observations to viper file (" . $vfc->get_errormsg() . ")", undef)
      if ($vfc->error());
  }

  return("", $vfc);
}

############################################################
#################### 'save' / 'load' Memmory Dump functions

my $VF_MemDump_Suffix = ".memdump";

sub get_MemDump_Suffix { return $VF_MemDump_Suffix; }

my $VF_MemDump_FileHeader_cmp = "\#  TrecVid08ViperFile MemDump";
my $VF_MemDump_FileHeader_gz_cmp = $VF_MemDump_FileHeader_cmp . " (Gzip)";
my $VF_MemDump_FileHeader_add = "\n\n";

my $VF_MemDump_FileHeader = $VF_MemDump_FileHeader_cmp 
  . $VF_MemDump_FileHeader_add;
my $VF_MemDump_FileHeader_gz = $VF_MemDump_FileHeader_gz_cmp
  . $VF_MemDump_FileHeader_add;

##########

sub _rm_mds {
  my ($fname) = @_;

  return($fname) if (MMisc::is_blank($fname));

  # Remove them all
  while ($fname =~ s%$VF_MemDump_Suffix$%%) {1;}

  return($fname);
}

#####

sub save_ViperFile_XML {
  my ($fname, $vf, $printname, $ptxt, @asked_events) = @_;

  # Re-adapt the file name to remove any potential ".memdump"
  $fname = &_rm_mds($fname, 0);

  my $txt = $vf->reformat_xml(@asked_events);
  return("While trying to create the XML text (" . $vf->get_errormsg() . ")", $fname)
    if ($vf->error());

  return("Problem while trying to \'save_ViperFile_XML\'", $fname)
    if (! MMisc::writeTo($fname, "", $printname, 0, $txt, "", $ptxt));

  return("", $fname);
}

##########

sub save_ViperFile_MemDump {
  my ($fname, $aobject, $mode, $printw, $portable, @asked_events) = @_;

  $printw = MMisc::iuv($printw, 1);
  $portable = MMisc::iuv($portable, 0);

  # Re-adapt the file name to remove all ".memdump" (added later in this step)
  $fname = &_rm_mds($fname);

  my $object = undef;
  if (($portable) || (scalar @asked_events > 0)) {
    if (scalar @asked_events > 0) {
      $object = $aobject->clone_with_selected_events(@asked_events);
    } else {
      $object = $aobject->clone();
    }
    return("Clone: " . $aobject->get_errormsg(), $fname)
      if ($aobject->error());
    return("Clone: Undefined Object", $fname)
      if (! defined $object);
    if ($portable) {
      # In order to make it portable, we remove command paths that might differ
      # on different system (ie '/usr/bin/xmllint': force to "xmllint")
      $object->set_xmllint("xmllint", 1);
      return("Portable Clone: " . $object->errormsg(), $fname)
        if ($object->error());
    }
  } else {
    $object = $aobject;
  }
  return("Undefined Object", $fname)
    if (! defined $object);
  return($object->get_errormsg(), $fname)
    if ($object->error());

  my $tmp = MMisc::dump_memory_object
    ($fname, $VF_MemDump_Suffix, $object,
     $VF_MemDump_FileHeader,
     ($mode eq "gzip") ? $VF_MemDump_FileHeader_gz : undef,
     $printw);

  return("Problem during actual dump process", $fname)
    if ($tmp != 1);

  return("", $fname);
}

##########

sub load_ViperFile {
  my ($isgtf, $filename, $fps, $xmllint, $xsdpath) = @_;

  my $err = MMisc::check_file_r($filename);
  return(0, undef, $err)
    if (! MMisc::is_blank($err));
  
  open FILE, "<$filename"
    or return(0, undef, "Problem opening file ($filename) : $!");

  my $header = <FILE>;
  close FILE;
  chomp $header;

  return(&_load_MemDump_ViperFile($isgtf, $filename, $fps))
    if ( ($header eq $VF_MemDump_FileHeader_cmp)
	|| ($header eq $VF_MemDump_FileHeader_gz_cmp) );
  
  return(&_load_XML_ViperFile($isgtf, $filename, $fps, $xmllint, $xsdpath));
}

#####

sub _load_XML_ViperFile {
  my ($isgtf, $tmp, $fps, $xmllint, $xsdpath) = @_;

  # Prepare the object
  my $object = new TrecVid08ViperFile();

  return(0, undef, "While trying to set \'xmllint\' (" 
	 . $object->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $object->set_xmllint($xmllint)) );

  return(0, undef, "While trying to set \'TrecVid08xsd\' (" 
	 . $object->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $object->set_xsdpath($xsdpath)) );

  return(0, undef, "While setting \'gtf\' status (" 
	 . $object->get_errormsg() . ")")
    if ( ($isgtf) && ( ! $object->set_as_gtf()) );

  return(0, undef, "While setting \'file\' ($tmp) (" 
	 . $object->get_errormsg() . ")")
    if ( ! $object->set_file($tmp) );

  return(0, undef, "While setting \'fps\' ($fps) (" 
	 . $object->get_errormsg() . ")")
    if ( (defined $fps) &&  ( ! $object->set_fps($fps) ) );

  # Validate
  return(0, undef, $object->get_errormsg())
    if (! $object->validate());

  return(1, $object, "");
}

#####

sub _load_MemDump_ViperFile {
  my ($isgtf, $file, $fps) = @_;

  my $object = MMisc::load_memory_object($file, $VF_MemDump_FileHeader_gz);

  my $rtxt = "[MemDump] ";

  return(0, undef, $rtxt . "Problem reading memory representation")
    if (! defined $object);

  return(0, undef, $rtxt . "Problem reading memory representation: Not a ViperFile MeMDump") 
    if (ref $object ne "TrecVid08ViperFile");

  # Error ?
  return(0, undef, $rtxt . $object->get_errormsg())
    if ($object->error());

  # Validate
  return(0, undef, $rtxt . $object->get_errormsg())
    if (! $object->validate());

  # GTF ?
 return(0, undef, $rtxt . "Object is not a GTF as expected")
   if ( ($isgtf) && (! $object->check_if_gtf()) );
  # or SYS ?
  return(0, undef, $rtxt . "Object is not SYS as expected")
    if ( (! $isgtf) && (! $object->check_if_sys()) );

  # Set the FPS ?
  if ( (defined $fps) && (! $object->is_fps_set()) ) {
    $object->set_fps($fps);
    return(0, undef, $rtxt . "Problem setting ViperFile's FPS (" . $object->get_errormsg() . ")") if ($object->error());
  }

  return(1, $object, $rtxt . "loaded");
}

############################################################
#################### ECF

sub load_ECF {
  my ($ecffile, $ecfobj, $xmllint, $xsdpath, $fps) = @_;

  my $err = MMisc::check_file_r($ecffile);
  return($err) if (! MMisc::is_blank($err));

  return("While trying to set \'xmllint\' (" . $ecfobj->get_errormsg() . ")")
    if ( ($xmllint ne "") && (! $ecfobj->set_xmllint($xmllint)) );

  return("While trying to set \'TrecVid08xsd\' (" . $ecfobj->get_errormsg() . ")")
    if ( ($xsdpath ne "") && (! $ecfobj->set_xsdpath($xsdpath)) );

  return("While trying to set \'fps\' (" . $ecfobj->get_errormsg() . ")")
    if ( (defined $fps) && (! $ecfobj->set_default_fps($fps)) );

  return("While setting \'file\' ($ecffile) (" . $ecfobj->get_errormsg() . ")")
    if ( ! $ecfobj->set_file($ecffile) );

  # Validate (important to confirm that we can have a memory representation)
  return("file did not validate (" . $ecfobj->get_errormsg() . ")")
    if (! $ecfobj->validate());

  return("");
}

##########

sub add_ViperFileObservations2EventList {
  my ($vf, $el, $dodummy) = @_;

  return("Can only work with validated ViperFile")
    if (! $vf->is_validated());

  my $rej_val = $el->Observation_Rejected();
  my $acc_val = $el->Observation_Added();
  my $spa_val = $el->Observation_SpecialAdd();
  return("Problem obtaining EventList's Observation \'Added\', \'SpecialAdd\' or \'Rejected\' values (" . $el->get_errormsg() . ")", 0, 0, 0)
    if ($el->error());

  my @ao = $vf->get_all_events_observations();
  return("Problem obtaining all Observations from the ViperFile object (" . $vf->get_errormsg() . ")", 0, 0, 0)
    if ($vf->error());

  if ($dodummy) {
    # We also want the dummy observation
    # (to have at least one observation in the event list)
    my $do = $vf->get_dummy_observation();
    return("Problem obtaining the dummy Observations from the ViperFile object (" . $vf->get_errormsg() . ")", 0, 0, 0)
      if ($vf->error());
    push @ao, $do;
  }

  my $rejected = 0;
  my $added = 0;
  my $tobs = 0;
  foreach my $o (@ao) {
    my $status = $el->add_Observation($o);
    return("Problem adding Observation to EventList (" . $el->get_errormsg() . ")", 0, 0, 0)
      if ($el->error());

    my $toadd = 1;
    if ($status == $rej_val) {
      $rejected++;
    } elsif ($status == $acc_val) {
      $added++;
    } elsif ($status == $spa_val) {
      $toadd = 0;
    } else {
      return("Weird EventList \'add_Observation\' return code ($status) at this stage", 0, 0, 0);
    }
    $tobs += $toadd;
  }

  return("", $tobs, $added, $rejected);
}

####################

sub get_new_ViperFile_from_ViperFile_and_ECF {
  my ($vf, $ecfobj) = @_;

  my $el = new TrecVid08EventList();
  return("Problem creating the EventList (" . $el->get_errormsg() . ")", undef)
    if ($el->error());

  return("Problem tying EventList to ECF " . $el->get_errormsg() . ")", undef)
    if (! $el->tie_to_ECF($ecfobj));

  my ($terr, $tobs, $added, $rejected) = add_ViperFileObservations2EventList($vf, $el, 1);
  return("Problem adding ViperFile Observations to EventList: $terr", undef)
    if (! MMisc::is_blank($terr));
  
  my $sffn = $vf->get_sourcefile_filename();
  return("Problem obtaining the sourcefile's filename (" . $vf->get_errormsg() . ")", undef)
    if ($vf->error());

  return("File ($sffn) is not in EventList", undef)
    if (! $el->is_filename_in($sffn));

  my @ecf_vfs = $ecfobj->get_file_ViperFramespans($sffn);
  return("Problem obtaining ECF's Viper Framespan ($sffn): " . $ecfobj->get_errormsg() . ")", undef)
    if ($ecfobj->error());

  if (scalar @ecf_vfs > 0) { # sffn contained within ECF
    #  print "$sffn [" . scalar @ecf_vfs . "]\n";
    foreach my $efs (@ecf_vfs) {
      #    print MMisc::get_sorted_MemDump(\$efs) . "\n";
      my $ok = $vf->is_within($efs);
      return("Problem confirming ECF vs ViperFile framespan overlap (" . $vf->get_errormsg() . ")", undef)
	if ($vf->error());
      return("Problem confirming ECF framespan overlap within ViperFile (" . $efs->get_errormsg() . ")", undef)
	if ($efs->error());
      return("The framespan of the ECF (". $efs->get_value() .") does not appear to be within the ViperFile numframes value (". $vf->get_numframes_value() ."), this will cause issues if left uncorrected", undef)
	if (! $ok);
    }
  } else {
    MMisc::warn_print("\'$sffn\' not contained within ECF file, content used as is");
  }
     
  my $tvf = $vf->clone_with_no_events();
  return("Problem while cloning the ECF modifed ViperFile (" . $vf->get_errormsg() . ")", undef)
    if (! defined $tvf);
  
  my @ao = $el->get_all_Observations($sffn);
  foreach my $obs (@ao) {
    return("Problem adding EventList Observation to new ViperFile (" . $tvf->get_errormsg() .")", undef)
      if ( (! $tvf->add_observation($obs, 1)) || ($tvf->error()) );
  }

  return("", $tvf);
}

####################

sub confirm_all_ECF_sffn_are_listed {
  my ($ecfobj, @flist) = @_;

  my @missing_from_ECF = ();
  my @not_in_ECF = ();
  my @ecflist = $ecfobj->get_files_list();
  return("Problem obtaining ECF's file list (" . $ecfobj->get_errormsg() . ")", \@missing_from_ECF, \@not_in_ECF)
    if ($ecfobj->error());

  return("ECF list seems to contain blank values (" . join("|", @ecflist) . ")", \@missing_from_ECF, \@not_in_ECF)
    if (MMisc::any_blank(@ecflist));
  return("SourceFilenames list seems to contain blank values (" . join("|", @flist) . ")", \@missing_from_ECF, \@not_in_ECF)
    if (MMisc::any_blank(@flist));

  my @tfl = MMisc::make_array_of_unique_values(\@flist);

  my ($rla, $rlb) = MMisc::confirm_first_array_values(\@ecflist, \@tfl);
  @missing_from_ECF = @$rlb; # ie: present in ECF but not in file list

  my ($rla, $rlb) = MMisc::confirm_first_array_values(\@tfl, \@ecflist);
  @not_in_ECF = @$rlb; # ie: not present in the ECF

  return("", \@missing_from_ECF, \@not_in_ECF);
}

####################

sub _only_keep_annotations_with {
  my $okaw = shift @_;
  my $okaw_rm = shift @_;
  my $rokk = shift @_;
  my @in = @_;

  return(@in) if ((MMisc::is_blank($okaw)) || (scalar @in == 0));

  my @out = ();
  foreach my $rh (@in) {
    my $annot = $$rh{$$rokk[7]};

    if ($okaw_rm) {
      my @tmp1 = split(m%\s+%, $annot);
      my @tmp2 = grep(m%^$okaw%, @tmp1);
      $annot = join(" ", @tmp2);
      $$rh{$$rokk[7]} = $annot;
    }

    push @out, $rh
      if ($annot =~ m%$okaw%);
  }

  return(@out);
}

#####

sub extract_trackingcomment_information {
  my $akv = "__all__";
  my ($txt, $keep_tc_key, $mode, $okaw, $okaw_rm) = MMisc::iuav(\@_, "", $akv, 0, "", 0);
  # mode: 0 = keep all occurences for the same xml file 
  # 1 = keep the first one / 2 = keep the latest one
  # okaw: Only Keep Annotations With
  # okaw_rm: Remove all other entries ?

  my @out = ();

  return("Empty data", @out)
    if (MMisc::is_blank($txt));

  $keep_tc_key = $akv if (MMisc::is_blank($keep_tc_key));

  my $dvf = new TrecVid08ViperFile();
  my $tcs = $dvf->get_char_tc_separator();
  my $be  = $dvf->get_char_tc_beg_entry();
  my $ee  = $dvf->get_char_tc_end_entry();
  my $es  = $dvf->get_char_tc_entry_sep();
  my $cs  = $dvf->get_char_tc_comp_sep();
  my $bp  = $dvf->get_char_tc_beg_pre();
  my $ep  = $dvf->get_char_tc_end_pre();
  my @okk = $dvf->get_array_tc_list();
  my @tca = $dvf->get_xtra_tc_authorized_keys();
  return("Problem obtaining some tracking comment information: " . $dvf->get_errormsg())
    if ($dvf->error());

  return("Request key ($keep_tc_key) is not authorized", @out)
    if (($keep_tc_key ne $akv) && (! grep(m%^$keep_tc_key$%, @tca)));

  my @all = split(m%\Q$tcs\E%, $txt);
  return("Could not find any entry" , @out)
    if (scalar @all == 0);

  my $ekv = "__empty__";
  my %allh = ();
  my %isin = ();
  foreach my $entry (@all) {
    $entry = MMisc::clean_begend_spaces($entry);
    return("Entry does not start with expected character ($be)", @out)
      if ($entry !~ s%^\Q$be\E%%);
    return("Entry does not end with expected character ($ee)", @out)
      if ($entry !~ s%\Q$ee\E$%%);
    
    my $pre = $ekv;
    $entry = MMisc::clean_begend_spaces($entry);
    $pre = $1 if ($entry =~ s%^\Q$bp\E([^\Q$ep\E]+)\Q$ep\E%%);
  
    $entry = MMisc::clean_begend_spaces($entry);
    my @av = split(m%\Q$es\E%, $entry);
    return("Could not find any key/value entry" , @out)
      if (scalar @av == 0);
    my %vh = ();
    foreach my $comp (@av) {
      my ($k, $v) = split(m%\Q$cs\E%, $comp);
      $k = MMisc::clean_begend_spaces($k);
      $v = MMisc::clean_begend_spaces($v);
      return("Found unknown key ($k / $v)", @out)
        if (! grep(m%$k$%, @okk));
      $vh{$k} = $v;
    }

    if ((($keep_tc_key eq $akv) || ($pre eq $keep_tc_key)) && ($mode > 0)) {
      my $use = 1;
      my $file = $vh{$okk[0]}; # get the 'File' info
      $use = 0 if ( ($mode == 1) && (exists $isin{$file}) ); # only keep first
      $isin{$file} = \%vh if ($use);
    }

    push @{$allh{$pre}}, \%vh;
  }

  if ($mode > 0) {
    foreach my $key (keys %isin) {
      push @out, $isin{$key};
    } 
    return("", &_only_keep_annotations_with($okaw, $okaw_rm, \@okk, @out));
  }

  ## mode = 0 

  # all keys
  if ($keep_tc_key eq $akv) {
    foreach my $key (keys %allh) {
      push @out, @{$allh{$key}};
    }
    return("", &_only_keep_annotations_with($okaw, $okaw_rm, \@okk, @out));
  }

  # key not in ? (returns an empty array)
  return("", @out)
    if (! exists $allh{$keep_tc_key});

  # key in
  @out = @{$allh{$keep_tc_key}};

  return("", &_only_keep_annotations_with($okaw, $okaw_rm, \@okk, @out));
}

########################################

sub ViperFile2CSVtxt {
  my ($vf, @keys) = @_;

  my $txt = "";

  return("ViperFile is not validated, aborting", $txt)
    if (! $vf->is_validated());

  return("No keys requested", $txt)
    if (scalar @keys == 0);

  my $dobs = $vf->get_dummy_observation();
  return("Problem obtaining dummy observation from ViperFile: " . $vf->get_errormsg(), $txt)
    if ($vf->error());

  return("Unknown keys: " . $dobs->get_errormsg(), $txt)
    if (! $dobs->check_csv_keys(@keys));

  # Get an observation representation of all the viper file
  my @ao = $vf->get_all_events_observations();
  return("Problem while obtaining Observations (" . $vf->get_errormsg() . ")", $txt)
    if ($vf->error());

  my $ch = new CSVHelper();
  return("Problem creating the CSV object :" . $ch->get_errormsg(), $txt)
    if ($ch->error());

  my $tmp = "";

  $ch->set_number_of_columns(scalar @keys);
  return("Problem setting number of columns for CSV: " . $ch->get_errormsg(), $txt)
    if ($ch->error());
  my $tmptxt = $ch->array2csvline(@keys);
  return("Problem adding entries to CSV file: " . $ch->get_errormsg(), $txt)
    if ($ch->error());
  $tmp .= "$tmptxt\n";

  foreach my $obs (@ao) {
    my ($err, @tmp) = &Observation2CSVarray($obs, @keys);
    return($err, $txt) if (! MMisc::is_blank($err));
    
    return("CSV generation from Observation did not return the expected number of keys", $txt)
      if (scalar @keys != scalar @tmp);

    $tmptxt = $ch->array2csvline(@tmp);
    return("Problem adding entries to CSV file: " . $ch->get_errormsg(), $txt)
      if ($ch->error());
    $tmp .= "$tmptxt\n";
  }
  
  return("", $tmp);
}

##########

sub Observation2CSVarray {
  my ($obs, @keys) = @_;

  my @out = ();

  return("Observation is not validated", @out)
    if (! $obs->is_validated());

  return("No keys requested", @out)
    if (scalar @keys == 0);

  return("Unknown keys: " . $obs->get_errormsg(), @out)
    if (! $obs->check_csv_keys(@keys));

  my @array = $obs->get_csv_array(@keys);
  return("Problem obtaining csv array: " . $obs->get_errormsg(), @out)
    if ($obs->error());

  return("", @array);
}

####################

sub Add_CSVfile2VFobject {
  my ($csvf, $vf) = @_;

  my $dobs = $vf->get_dummy_observation();
  return("Problem obtaining dummy observation from ViperFile: " . $vf->get_errormsg())
    if ($vf->error());

  open CSV, "<$csvf"
    or return("Problem opening CSV file: $!\n");

  my $csv = new CSVHelper();
  return("Problem creating the CSV object: " . $csv->get_errormsg())
    if ($csv->error());

  # Process CSV file line per line
  my @headers = ();
  while (my $line = <CSV>) {
    my @columns = $csv->csvline2array($line);
    return("Failed to parse CSV line: " . $csv->get_errormsg())
      if ($csv->error());

    if (scalar @headers == 0) { # extract the CSV headers
      return("When checking the CSV header: " . $dobs->get_errormsg())
        if (! $dobs->check_csv_keys(@columns));
      @headers = @columns;
      $csv->set_number_of_columns(scalar @columns);
      return("Problem setting number of columns for CSV: " . $csv->get_errormsg())
        if ($csv->error());
      next;
    }

    # Add the values to a cloned observation, then to the ViperFile
    return("Did not find the same number of information on line as expected (" . scalar @columns . " vs " . scalar @headers . ")")
      if (scalar @columns != scalar @headers);
    
    my $obs = $dobs->clone();
    return("Problem cloning the dummy observation: " . $dobs->get_errormsg())
      if ($dobs->error());
    
    return("Problem modifying cloned observation to use CSV information: " . $obs->get_errormsg())
      if (! $obs->mod_from_csv_array(\@headers, @columns));
    
    return("Problem re-validating modified observation: " . $obs->get_errormsg())
      if (! $obs->redo_validation());

    return("Problem adding modified clone CSV adapted observation to ViperFile: " . $vf->get_errormsg())
      if (! $vf->add_observation($obs));
  }
  close CSV;

  return("");
}

####################

sub ViperFile_DetectionScore_minMax {
  my ($vf) = @_;

  return("ViperFile is not validated, aborting", undef, undef)
    if (! $vf->is_validated());
  
  return("Can not obtain a \'DetectionScore\' from a REF file", undef, undef)
    if ($vf->check_if_gtf());

  # Get an observation representation of all the viper file
  my @ao = $vf->get_all_events_observations();
  return("Problem while obtaining Observations (" . $vf->get_errormsg() . ")", undef, undef)
    if ($vf->error());

  my $min = undef;
  my $max = undef;

  return("", undef, undef)
    if (scalar @ao == 0);

  foreach my $obs (@ao) {
    my $dec = $obs->Dec();
    return($obs->get_errormsg(), undef, undef)
      if ($obs->error());
    $min = $dec
      if (! defined $min);
    $min = $dec
      if ($dec < $min);
    $max = $dec
      if (! defined $max);
    $max = $dec
      if ($dec > $max);
  }
  
  return("", $min, $max);
}

####################

sub divideby_ViperFile_Observations {
  my ($vf, $by, $sub) = MMisc::iuav(\@_, undef, 0, 0);

  return("No ViperFile provided, aborting", undef)
    if (! defined $vf);

  return("No value provided for division step", undef)
    if (! defined $by);

  return("ViperFile is not validated, aborting", undef)
    if (! $vf->is_validated());
  
  return("Can not obtain a \'DetectionScore\' from a REF file", undef)
    if ($vf->check_if_gtf());

  return("Can not divide by zero", undef)
    if ($by == 0);

  # Get an observation representation of the viper file
  my @ao = $vf->get_all_events_observations();
  return("Problem while obtaining Observations (" . $vf->get_errormsg() . ")", undef)
    if ($vf->error());

  return("", $vf)
    if (scalar @ao == 0); # No observations, no need to go any further

  my $tvf = $vf->clone_with_no_events();
  return("Problem while cloning the ViperFile", undef)
    if (! defined $tvf);

  foreach my $obs (@ao) {
    my $dec = $obs->Dec();
    return($obs->get_errormsg(), undef)
      if ($obs->error());

    $dec = ($dec - $sub) / $by;

    $obs->set_DetectionScore($dec);
    return($obs->get_errormsg(), undef)
      if ($obs->error());

    return("Problem adding Observation to new ViperFile (" . $tvf->get_errormsg() .")", undef)
      if ( (! $tvf->add_observation($obs, 1)) || ($tvf->error()) );
  }

  return("", $tvf);
}

########################################

1;
