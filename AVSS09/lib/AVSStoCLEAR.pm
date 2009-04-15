package AVSStoCLEAR;

# AVSStoCLEAR
#
# Author(s): Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSStoCLEAR.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id $

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "AVSStoCLEAR.pm Version: $version";

use MMisc;
use MtXML;
use ViperFramespan;
use MErrorH;

my $avcl_xmlerrorstring = "AVSStoCLEAR-XML_PARSE_ERROR";

## Constructor
sub new {
  my ($class) = shift @_;
  
  my $errormsg = new MErrorH("AVSStoCLEAR");

  my $self =
    {
     clip           => undef,
     ifgap          => 0,
     cam_id         => undef,
     rbboxl         => undef,
     robboxl        => undef,
     id_fs          => undef,
     id_sfs         => undef,
     id_bf          => undef,
     gfs            => undef,
     if_list        => undef,
     end_frame      => undef,
     comp_cache     => undef,
     clip_csv_data  => undef,
     obj_csv_data   => undef,
     # Error Handler
     errormsg       => $errormsg,
    };

  bless($self, $class);
  return($self);
}

##########

sub get_version {
  my ($self) = @_;

  return($versionid);
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errormsg}->set_errormsg($txt);
}

##########

sub get_errormsg {
  my ($self) = @_;
  return($self->{errormsg}->errormsg());
}

##########

sub error {
  my ($self) = @_;
  return($self->{errormsg}->error());
}

##########

sub _set_error_and_return {
  my $self = shift @_;
  my $errormsg = shift @_;

  $self->_set_errormsg($errormsg);

  return(@_);
}

############################################################

sub load_ViPER_AVSS {
  my $self = shift @_;
  my $in = shift @_;
  my $ifgap = MMisc::iuv(shift @_, 5);
  my $gapsh = MMisc::iuv(shift @_, 25);

  return($self->_set_error_and_return("No input file provided", 0))
    if (MMisc::is_blank($in));

  open IN, "<$in"
    or return($self->_set_error_and_return("Could not open input_file ($in) : $!", 0));

  return($self->_set_error_and_return("File already loaded [$in]", 0))
    if (exists $self->{clip}{$in});

  my @content = <IN>;
  close IN;
  chomp @content;
  my $str = join("\n", @content);  

  my $res = "";
  my $doit = 1;
  my $name = "object";
  my $gfs = "";
  my $efs = "";
  my $clip = "";
  my $if_list_comp = "";
  while ($doit) {
    my $section = MtXML::get_named_xml_section($name, \$str, $avcl_xmlerrorstring);
    if ($section eq $avcl_xmlerrorstring) {
      $doit = 0;
      next;
    }
    
    ## Get the clip name the regexp way
    if ($section =~ m%<\s*object\s+[^>]*name=\"Clip\">%) {
      $clip = &_extract_named_Xvalue("DATA-SOURCE", "svalue", $section);
      return($self->_set_error_and_return("Seen the clip entry, but could not extract it or empty value, aborting", 0))
          if ((!defined $clip) || (MMisc::is_blank($clip)));
      $self->{clip_csv_data}{$in}{"Clip"} = $clip;
      
      $res .= "* Clip name: $clip\n";
      next;
    }

    ##
    if ($section =~ m%<\s*object\s+[^>]*name=\"Annotation\">%) {
      my $tmp = "NAME";
      my $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{clip_csv_data}{$in}{"Clip Set"} = $val;

      $tmp = "DATA-SET";
      $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{clip_csv_data}{$in}{"Data Set"} = $val;

      next;
    }
    
    ##
    if ($section =~ m%<\s*object\s+[^>]*name=\"Target-Event-Set\">%) {
      my $tmp = "TIME-OF-DAY";
      my $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{clip_csv_data}{$in}{"Time of Day"} = $val;

      $tmp = "DURATION";
      $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{clip_csv_data}{$in}{"Duration"} = $val;

      $tmp = "DISTRACTION";
      $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $val =~ s%[\(\)]%%g;
      $self->{clip_csv_data}{$in}{"Distraction"} = $val;

      next;
    }

    ##
    if ($section =~ m%<\s*object\s+[^>]*name=\"Target-Event\">%) {
      my $tmp = "CROWD-DENSITY";
      my $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{clip_csv_data}{$in}{"Crowd Density"} = $val;

      next;
    }

    #####
    my ($err, $txt, $idv, $rbbl, $robbl, $loc_xml, $occ_xml, $lfsv, $fsv, $sfsv) = &_process_section($name, $section);
    return($self->_set_error_and_return($err, 0))
      if (! MMisc::is_blank($err));
    next if (MMisc::is_blank($txt));

    $res .= "\n[$doit] $txt";
    $gfs .= " $fsv";
    $efs .= " $lfsv";

    ## We just did process the "Target" section, we need to fill its
    # object's main CSV before continuing
    {
      $self->{obj_csv_data}{$in}{$idv}{"Target ID"} = $idv;
      $self->{obj_csv_data}{$in}{$idv}{"Target Seen"} = "No";
      # set to "no" for now (will be set to yes later if it does appear)

      my $tmp = "NAME";
      my $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{obj_csv_data}{$in}{$idv}{"Name"} = $val;

      $tmp = "DRESS";
      $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{obj_csv_data}{$in}{$idv}{"Dress"} = $val;

      $tmp = "SEX";
      $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{obj_csv_data}{$in}{$idv}{"Sex"} = $val;

      $tmp = "COLOUR";
      $val = &_extract_named_Xvalue($tmp, "svalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{obj_csv_data}{$in}{$idv}{"Colour"} = $val;

      $tmp = "BAG";
      $val = &_extract_named_Xvalue($tmp, "bvalue", $section);
      return($self->_set_error_and_return("Could not extract \"$tmp\" (or empty value), aborting", 0))
        if ((! defined $val) || (MMisc::is_blank($val)));
      $self->{obj_csv_data}{$in}{$idv}{"Bag"} = $val;
    }

    # In case no actual data was contained in the object, skip the rest
    # of the processing; we are interested by the framespan only here
    next if (MMisc::is_blank($loc_xml));

    my ($bf, $ef) = $self->_get_beg_end($sfsv);
    return(0) if ($self->error());

    $self->{rbboxl}{$in}{$idv}  = $rbbl;
    $self->{robboxl}{$in}{$idv} = $robbl;
    $self->{id_fs}{$in}{$idv}   = $fsv;
    $self->{id_sfs}{$in}{$idv}  = $sfsv;
    $self->{id_bf}{$in}{$idv}   = $bf;

    $if_list_comp .= " " . $fsv;

    # Fill the extra CSV information
    {
      my $fs_fs = new ViperFramespan($fsv);
      return($self->_set_error_and_return("Problem creating GapShorten framespan : " . $fs_fs->get_errormsg(), 0))
        if ($fs_fs->error());
      $fs_fs->gap_shorten($gapsh);
      return($self->_set_error_and_return("Problem during GapShorten : " . $fs_fs->get_errormsg(), 0))
        if ($fs_fs->error());

      my $gsc = $fs_fs->count_pairs_in_value();
      return($self->_set_error_and_return("Problem during GapShorten's pair count : " . $fs_fs->get_errormsg(), 0))
        if ($fs_fs->error());
      
      my $gstxt = "";
      if ($gsc > 1) {
        $gstxt = $fs_fs->get_value();
        $res .= "  -> ** Gap in Framespan: $gstxt\n";
      }

      $self->{obj_csv_data}{$in}{$idv}{"Target Seen"} = "Yes";
      $self->{obj_csv_data}{$in}{$idv}{"Beginning Frame"} = $bf;
      $self->{obj_csv_data}{$in}{$idv}{"Ending Frame"} = $ef;
      $self->{obj_csv_data}{$in}{$idv}{"Gaps in Framespan"} = $gstxt;
    }
    
    $doit++;
  }
  
  # Finished processing the file
  return($self->_set_error_and_return("Could not find clip details", 0))
    if (MMisc::is_blank($clip));

  $gfs = $self->_simplify_fs($gfs);
  return(0) if ($self->error());

  $efs = $self->_simplify_fs($efs);
  return(0) if ($self->error());
  my ($dummy, $ef) = $self->_get_beg_end($efs);

  $res .= "\n";
  $res .= "* End Frame: $efs\n";

  $self->{clip}{$in} = $clip;
  $self->{gfs}{$in}  = $gfs;
  $self->{end_frame}{$in} = $ef;
  if ($self->{ifgap} != 0) {
    my $tig = $self->{ifgap};
    return($self->_set_error_and_return("IFramesGap already set ($tig) and different from requested value ($ifgap)", 0))
    if ($ifgap != $tig);
  }
  $self->{ifgap} = $ifgap;

  my ($err, $if_list) = &_compute_iflist($if_list_comp, $ef, $ifgap);
  return($self->_set_error_and_return($err, 0))
    if (! MMisc::is_blank($err));
  $self->{if_list}{$in} = $if_list;

  my $c = $self->get_cam_id($in);
  return(0) if ($self->error());
  $self->{cam_id}{$in} = $c;
  $res .= "* Cam ID: $c\n";

  return(1, $res);
}

##########

sub _create_CLEAR_ViPER {
  my $self = shift @_;
  my $in = shift @_;
  my $gtf = shift @_;
  my $sps = shift @_;

  return("") if ($self->error());

  my $xml = "";
  my $xmlt = "";
  
  return($self->_set_error_and_return("Could not find file [$in]", ""))
    if (! exists $self->{clip}{$in});

  my $clip = $self->{clip}{$in};
  my $gfs  = $self->{gfs}{$in};
  my $endf = $self->{end_frame}{$in};
#  my $sgfs = $self->_get_short_fs($gfs);
  my $ifl  = $self->{if_list}{$in};
  my $sgfs = $self->_get_short_fs($ifl);
  return("") if ($self->error());

  $xml .= &_write_header($clip, $endf, $gtf);
  $xmlt = $self->_create_all_objects_xml($in, ($sps != 0) ? $sps : $gtf);
  return("")
    if ($self->error());
  $xml .= $xmlt;

  $xml .= &_write_trailer($ifl, $sgfs, $gtf);
  
  return($xml);
}

#####

sub create_CLEAR_ViPER { # GTF
  my ($self, $in) = @_;

  return($self->_create_CLEAR_ViPER($in, 1, 0));
}

#####

sub create_CLEAR_SYS_ViPER { # SYS
  my ($self, $in) = @_;

  return($self->_create_CLEAR_ViPER($in, 0, 0));
}

#####

sub create_CLEAR_StarterSYS_ViPER { # Starter SYS
  my ($self, $in) = @_;

  return($self->_create_CLEAR_ViPER($in, 0, -1));
}

#####

sub create_CLEAR_EmptySYS_ViPER { # Empty SYS
  my ($self, $in) = @_;

  return($self->_create_CLEAR_ViPER($in, 0, -2));
}
##########

sub get_comparables {
  my $self = shift @_;
  my $in1 = shift @_;
  my $in2 = shift @_;

  return($self->_set_error_and_return("First key [$in1] not found", undef))
    if (! exists $self->{clip}{$in1});

  return($self->_set_error_and_return("Second key [$in2] not found", undef))
    if (! exists $self->{clip}{$in2});

  my @keys1 = keys %{$self->{id_sfs}{$in1}};
  my @keys2 = keys %{$self->{id_sfs}{$in2}};

  return(undef)
    if ((scalar @keys1 == 0) || (scalar @keys2 == 0));

  # Use cached information if any
  return($self->{comp_cache}{$in1}{$in2})
    if (exists $self->{comp_cache}{$in1}{$in2});
  return($self->{comp_cache}{$in2}{$in1})
    if (exists $self->{comp_cache}{$in2}{$in1});

  my %res = ();
  foreach my $key1 (sort _num @keys1) {
    foreach my $key2 (sort _num @keys2) {
      next if ($key1 != $key2);

      my $k1fs = $self->{id_sfs}{$in1}{$key1};
      my $k2fs = $self->{id_sfs}{$in2}{$key2};

      my $fs_k1 = new ViperFramespan();
      $fs_k1->set_value($k1fs);
      return($self->_set_error_and_return("Problem with 1st key framespan: " . $fs_k1->get_errormsg(), undef))
        if ($fs_k1->error());

      my $fs_k2 = new ViperFramespan();
      $fs_k2->set_value($k2fs);
      return($self->_set_error_and_return("Problem with 2nd key framespan: " . $fs_k1->get_errormsg(), undef))
        if ($fs_k2->error());
  
      my $fs_ov = $fs_k1->get_overlap($fs_k2);
      return($self->_set_error_and_return("Problem with overlap framespan: " . $fs_k1->get_errormsg(), undef))
        if ($fs_k1->error());

      if (! defined $fs_ov) { # No overlap
        $res{$key1} = "NONE";
      } else {
        $res{$key1} = $fs_ov->get_value();
      }
    }
  }
  
  # Cache this information for next time it is asked of us
  $self->{comp_cache}{$in1}{$in2} = \%res;

  return(\%res);
}

##########

sub get_appear_order {
  my $self = shift @_;
  my @keys = @_;

  my @ids = ();
  foreach my $key (@keys) {
    next if (! exists $self->{id_bf}{$key});

    my @tids = $self->_get_ids($key);
    return(undef)
      if ($self->error());
    push @ids, @tids
      if (scalar @tids > 0);
  }
  return(undef)
    if (scalar @ids == 0);

  @ids = MMisc::make_array_of_unique_values(@ids);

  my %resk = ();
  my %resbf = ();
  foreach my $id (@ids) {
    my %tmp = ();
      foreach my $key (@keys) {
      next if (! exists $self->{id_bf}{$key}{$id});

      my $bf = $self->{id_bf}{$key}{$id};

      $tmp{$bf} = $key;
    }
    my $pf = -1;
    foreach my $f (sort _num keys %tmp) {
      push @{$resk{$id}}, $tmp{$f};
      push @{$resbf{$id}}, $f;
      return($self->_set_error_and_return("Two entries for ID [$id] have the same start frame, this should never happen", undef))
        if ($pf == $f);
      $pf = $f;
    }
  }
  
  return(\%resk, \%resbf);
}

##########

sub get_cam_id {
  my $self = shift @_;
  my $in = shift @_;

  return($self->_set_error_and_return("Clip information not available for key [$in]", undef))
    if (! exists $self->{clip}{$in});

  # No need to redo it if we already did it in the past
  return($self->{cam_id}{$in})
    if (exists $self->{cam_id}{$in});

  my $c = $self->{clip}{$in};
  # ex: for \MCT TR 01\MCTTR01b\MCTTR0102b.mov
  # the cam id is "2"
  $c =~ s%^.+\/%%; # remove the unix path
  $c =~ s%^.+\\%%; # remove the win path
  $c =~ s%\..+%%; # remove the extension
  $c =~ s%[^\d]$%%; # remove the trailing qualifier (letter)
  $c =~ s%^.+(\d)$%$1%; # remove everything but the last number

  return($self->_set_error_and_return("Could not extract camera information", undef))
    if (MMisc::is_blank($c));
  
  return($c);
}

####################

sub create_composite_CLEAR_ViPER {
  my $self = shift @_;
  my $clipname = shift @_;
  my $rk = shift @_;
  my $rorder = shift @_;
  my $gtf = MMisc::iuv(shift @_, 1);

  my $gfs = "";
  my $endf = 0;
  my $iflt = "";
  foreach my $k (@$rk) {
    return($self->_set_error_and_return("Could not find key [$k]", ""))
      if (! exists $self->{clip}{$k});
    $gfs .= " " . $self->{gfs}{$k};
    my $te = $self->{end_frame}{$k};
    $endf = ($te > $endf) ? $te : $endf;
    $iflt .= " " . $self->{if_list}{$k};
  }
  $gfs = $self->_simplify_fs($gfs);
  return("") if ($self->error());  
  my $ifl  = $self->_simplify_fs($iflt);
  return("") if ($self->error());
  my $sgfs = $self->_get_short_fs($ifl);
  return("") if ($self->error());

  my $xml = "";
  
  $xml .= &_write_header($clipname, $endf, $gtf);
  
  foreach my $k (@$rk) {
    my $c = $self->get_cam_id($k);
    return("") if ($self->error());
    
    return($self->_set_error_and_return("Could not find requested camera", ""))
      if (! exists $$rorder{$c});
    my @todo = @{$$rorder{$c}};
    
    my $xmlt = $self->_create_all_objects_xml($k, $gtf, \@todo);
    return("")
      if ($self->error());
    $xml .= $xmlt;
  }

  $xml .= &_write_trailer($ifl, $sgfs, $gtf);
  
  return($xml);
}

########################################

sub get_clip_csv_data_headers {
  my $self = shift @_;
  my $in = shift @_;

  return($self->_set_error_and_return("Clip not found [$in]", undef, undef))
    if (! exists $self->{clip_csv_data}{$in});

  my @headers = ("Clip Set", "Clip", "Data Set", "Time of Day",
                 "Duration", "Distraction", "Crowd Density");

  return(@headers);
}

#####

sub get_clip_csv_data {
  my $self = shift @_;
  my $in = shift @_;

  return($self->_set_error_and_return("Clip not found [$in]", undef, undef))
    if (! exists $self->{clip_csv_data}{$in});

  my @headers = $self->get_clip_csv_data_headers($in);
  return(undef) if ($self->error());

  my @content = ();
  foreach my $k (@headers) {
    if (exists $self->{clip_csv_data}{$in}{$k}) {
      push @content, $self->{clip_csv_data}{$in}{$k};
    } else {
      push @content, "NOT DEFINED";
    }
  }

  return(@content);
}

##########

sub get_obj_csv_data_headers {
  my $self = shift @_;
  my $in = shift @_;

  return($self->_set_error_and_return("Clip not found [$in]", undef, undef))
    if (! exists $self->{clip_csv_data}{$in});

  my @headers = ("Target ID", "Target Seen", "Beginning Frame", "Ending Frame",
                 "Name", "Sex", "Dress", "Bag", "Colour", "Gaps in Framespan");

  return(@headers);
}

#####

sub get_obj_csv_data {
  my $self = shift @_;
  my $in = shift @_;
  my $id = shift @_;

  return($self->_set_error_and_return("Clip not found [$in]", undef))
    if (! exists $self->{clip_csv_data}{$in});

  return($self->_set_error_and_return("ID not found [$id]", undef))
    if (! exists $self->{obj_csv_data}{$in}{$id}{"Target ID"});

  my @headers = $self->get_obj_csv_data_headers($in);
  return(undef) if ($self->error());

  my @content = ();
  foreach my $k (@headers) {
    if (exists $self->{obj_csv_data}{$in}{$id}{$k}) {
      push @content, $self->{obj_csv_data}{$in}{$id}{$k};
    } else {
      push @content, "NOT DEFINED";
    }
  }

  return(@content);
}

####################

sub _compute_iflist {
  my ($fsv, $end, $gap) = @_;

  my @ofsl = ();
  my $cur = 1;
  push @ofsl, "$cur:$cur"; # Always start at 1

  if (! MMisc::is_blank($fsv)) { # If a target is found
    my $fs_fs = new ViperFramespan();
    $fs_fs->set_value($fsv);
    return("In _compute_iflist: " . $fs_fs->get_errormsg(), "")
      if ($fs_fs->error());
    my @fsl = $fs_fs->list_frames();
    return($fs_fs->get_errormsg(), "")
      if ($fs_fs->error());
    
    # from "1" to the first listed entry
    my $prev = shift @fsl;
    for (my $v = $prev; $v > 0; $v -= $gap) {
      push @ofsl, "$v:$v";
    }

    # from $prev to $cur
    while (scalar @fsl > 0) {
      $cur = shift @fsl;
      
      # spacing is less than '$gap'
      if ($cur - $prev < $gap) {
        push @ofsl, "$prev:$prev $cur:$cur";
        $prev = $cur;
        next;
      }
      
      # Fill the gap
      for (my $v = $prev; $v < $cur; $v += $gap) {
        push @ofsl, "$v:$v";
      }
      
      $prev = $cur;
    }
  } 
  
  # Fill till the end  (If no target was found cur = 1)
  for (my $v = $cur; $v < $end; $v += $gap) {
    push @ofsl, "$v:$v";
  }

  # Just as a precaution, add the last value
  push @ofsl, "$end:$end";

  my $ffsv = join(" ", @ofsl);
  
  my $fs_fs = new ViperFramespan();
  $fs_fs->set_value($ffsv);
  return("Setting _compute_iflist: " . $fs_fs->get_errormsg(), "")
    if ($fs_fs->error());
  my $tfsv = $fs_fs->get_value();

  return("", $tfsv);
}

####################

sub _xmlrender_loc_occ {
  my $self = shift @_;
  my $in = shift @_;
  my $id = shift @_;
  my $gtf = MMisc::iuv(shift @_, 1);
  
  return($self->_set_error_and_return("Could not find key [$in]", undef))
    if (! exists $self->{clip}{$in});
  return($self->_set_error_and_return("Could not find requested ID [$id] for key [$in]", undef))
    if (! exists $self->{rbboxl}{$in}{$id});

  my $rbbl = $self->{rbboxl}{$in}{$id};
  my %bblist = MMisc::clone(%$rbbl);
  
  my $robbl = $self->{robboxl}{$in}{$id};
  my %obblist = MMisc::clone(%$robbl);

  my $ifg = $self->{ifgap};
  
  return(&_xmlrender_location_and_occluded_and_gfs(\%bblist, \%obblist, $gtf, $ifg));
}

#####

sub _shiftdiv_bboxes {
  my $self = shift @_;
  my $in = shift @_;
  my $id = shift @_;
  my $xp = shift @_;
  my $yp = shift @_;
  my $div = shift @_;
  my $gtf = MMisc::iuv(shift @_, 1);

  return($self->_set_error_and_return("Could not find key [$in]", undef))
    if (! exists $self->{clip}{$in});
  return($self->_set_error_and_return("Could not find requested ID [$id] for key [$in]", undef))
    if (! exists $self->{rbboxl}{$in}{$id});

  my $rbbl = $self->{rbboxl}{$in}{$id};
  my %bblist = MMisc::clone(%$rbbl);
  %bblist = $self->_shiftdiv_bbox($xp, $yp, $div, %bblist);
  return(undef) if ($self->error());

  my $robbl = $self->{robboxl}{$in}{$id};
  my %obblist = MMisc::clone(%$robbl);
  %obblist = $self->_shiftdiv_bbox($xp, $yp, $div, %obblist);
  return(undef) if ($self->error());
  
  my $ifg = $self->{ifgap};

  return(&_xmlrender_location_and_occluded_and_gfs(\%bblist, \%obblist, $gtf, $ifg));
} 

##########

sub _shiftdiv_bbox {
  my $self = shift @_;
  my $xp = shift @_;
  my $yp = shift @_;
  my $div = shift @_;
  my %bbl = @_;

  my %out = ();
  foreach my $k (keys %bbl) {
    my $bb = $bbl{$k};

    my $v = "x";
    $bb = _shiftdiv_bbV($bb, $v, $xp, $div);
    return($self->_set_error_and_return("Could not find \"$v\" in bbox", undef))
      if (! defined $bb);

    $v = "y";
    $bb = _shiftdiv_bbV($bb, $v, $yp, $div);
    return($self->_set_error_and_return("Could not find \"$v\" in bbox", undef))
      if (! defined $bb);

    if ($div != 1) {
      $v = "width";
      $bb = _shiftdiv_bbV($bb, $v, 0, $div);
      return($self->_set_error_and_return("Could not find \"$v\" in bbox", undef))
        if (! defined $bb);
      
      $v = "height";
      $bb = _shiftdiv_bbV($bb, $v, 0, $div);
      return($self->_set_error_and_return("Could not find \"$v\" in bbox", undef))
        if (! defined $bb);
    }

    $out{$k} = $bb;
  }

  return(%out);
}

#####

sub _shiftdiv_bbV {
  my $line = shift @_;
  my $name = shift @_;
  my $value = shift @_;
  my $div = shift @_;

  return(undef)
    unless ($line =~ m%\s$name=\"(\d+)\"%);

  my $v = $1;
  $v /= $div;
  $v += $value;
  $v = sprintf("%d", $v); # Rounding

  $line =~ s%(\s$name=\")\d+(\")%$1$v$2%;

  return($line);
}

############################################################

sub _create_all_objects_xml {
  my $self = shift @_;
  my $in = shift @_;
  my $gtf = MMisc::iuv(shift @_, 1);
  # where: 1 = GTF / 0 = SYS / -1 = StarterSYS / -2 = EmptySYS 
  my $rshdivs = shift @_;

  return("", "") # For EmptySYS, simply return an empty objects string
    if ($gtf == -2);

  my $sts = 0;
  if ($gtf < 0) {
    $sts = 1;
    $gtf = 0;
  }

  return($self->_set_error_and_return("Could not find file [$in]", ""))
    if (! exists $self->{clip}{$in});

  my $xml = "";

  foreach my $idv (sort _num keys %{$self->{rbboxl}{$in}}) {
    my $idadd = 0;
    my $loc_xml = "";
    my $occ_xml = "";
    my $fsv = "";
    my $sfsv = "";
    if (! defined $rshdivs) {
      (my $err, $loc_xml, $occ_xml, $fsv, $sfsv) = 
        $self->_xmlrender_loc_occ($in, $idv, ($sts) ? -1 : $gtf);
      return($self->_set_error_and_return("Problem while generating loc/occ [key: $in / ID: $idv] : $err", ""))
        if (! MMisc::is_blank($err));
    } else {
      my @todo = MMisc::clone(@$rshdivs);
      $idadd = shift @todo;
      my $xp = sprintf("%d", shift @todo); # Rounding
      my $yp = sprintf("%d", shift @todo);
      my $div = shift @todo;
      $div = 1 if ($div == 0);

      (my $err, $loc_xml, $occ_xml, $fsv, $sfsv) = 
        $self->_shiftdiv_bboxes($in, $idv, $xp, $yp, $div, $gtf);

      return($self->_set_error_and_return("Problem while shifting [key: $in / ID: $idv] : $err", ""))
        if (! MMisc::is_blank($err));
    }

    # Do not add if no data generated
    next if (MMisc::is_blank($loc_xml));
    # or no framespan found
    next if (MMisc::is_blank($fsv));

    $xml .= &_generate_object_xml($idv + $idadd, $fsv, $sfsv, $loc_xml, $occ_xml, ($sts) ? -1 : $gtf);
  }
  
  return("", $xml);
}

#####

sub _generate_object_xml {
  my $idv  = shift @_;
  my $fsv  = shift @_;
  my $sfs  = shift @_;
  my $loc_xml = shift @_;
  my $occ_xml = shift @_;
  my $gtf = MMisc::iuv(shift @_, 1);

  my $sts = 0;
  if ($gtf < 0) {
    $sts = 1;
    $gtf = 0;
  }

  if ($sts) {
    # Only keep the first 5 entries in that fs list
    my @fst = split(m%\s+%, $fsv);
    my $k = scalar @fst;
    $k = ($k < 5) ? $k - 1 : 4;
    $fsv = join(" ", @fst[0..$k]);
  }

  # Ready to generate the XML part
  my $xml = "";
  $xml .= "      <object name=\"PERSON\" id=\"$idv\" framespan=\"$fsv\">\n";

  # Location list
  $xml .=<<EOF
        <attribute name=\"LOCATION\">
$loc_xml
        </attribute>
EOF
;

  #!# MM (4/6): MOBILITY is a SV VEHICLE attribute 
#REMOVED#  # Everything is mobile for now
#REMOVED#  # $xml .= "        <attribute name=\"MOBILITY\">\n<data:lvalue framespan=\"$sfs\" value=\"MOBILE\"/>\n</attribute>\n";

  if ($gtf) {
    # Occluded list
    $xml .=<<EOF
        <attribute name=\"OCCLUSION\">
$occ_xml
        </attribute>
EOF
;

    # Nothing is ambigous for now
    $xml .=<<EOF;
        <attribute name=\"AMBIGUOUS\">
          <data:bvalue framespan=\"$sfs\" value=\"false\"/>
        </attribute>
EOF
;

    # Everything is present
    $xml .=<<EOF;
        <attribute name=\"PRESENT\">
          <data:bvalue framespan=\"$sfs\" value=\"true\"/>
        </attribute>
EOF
;

    # Nothing is synthetic
    $xml .=<<EOF
        <attribute name=\"SYNTHETIC\">
          <data:bvalue framespan=\"$sfs\" value=\"false\"/>
        </attribute>
EOF
;
  }

  # END XML object
  $xml .= "      </object>\n";

  return("", $xml);
}

############################################################

sub _process_section {
  my $name = shift @_;
  my $section = shift @_;

  my $lfk = "name";
  my $lfv = "Target";

  my ($err, %tmp) =  MtXML::get_inline_xml_attributes($name, $section);
  return("Problem extracting inline attributes: $err")
    if (! MMisc::is_blank($err));

  # Could not find expected data ?
  return("", "")
    if ((! exists $tmp{$lfk}) || ($tmp{$lfk} ne $lfv));

  # Otherwise...
  my $res = "FOUND: $lfv\n";

  my $fsk = "framespan";
  return("Could not find $fsk")
    if (! exists $tmp{$fsk});

  my $lfsv = $tmp{$fsk};
  $lfsv =~ s%\,% %g;
  $lfsv =~ s%\s\s% %g;
  my $fs_fs = new ViperFramespan();
  $fs_fs->set_value($lfsv);
  return($fs_fs->get_errormsg())
    if ($fs_fs->error());
  $lfsv = $fs_fs->get_value();
  $res .= "  -> Framespan: $lfsv\n";

  my $idk = "id";
  return("Could not find $idk")
    if (! exists $tmp{$idk});

  my $idv = $tmp{$idk};
  $res .= "  -> id: $idv\n";
  
  # Get the visible bbox
  my $atk = "attribute";
  my $atc = "name=\"BOUNDING-BOX\"";
  my @oatc = ("name=\"INITIAL-BOUNDING-BOX\"");
  my ($err, %bblist) = &_get_bboxes(\$section, $atk, $atc, @oatc);
  return($err)
    if (! MMisc::is_blank($err));
  $res .= "  -> extracted BB\n";

  # Get the occluded bbox
  my $atc = "name=\"OCCLUDED-BOUNDING-BOX\"";
  my @oatc = ("name=\"INITIAL-OCCLUDED-BOUNDING-BOX\"");
  my ($err, %obblist) = &_get_bboxes(\$section, $atk, $atc, @oatc);
  return($err)
    if (! MMisc::is_blank($err));
  $res .= "  -> extracted occluded BB\n";

  if ((scalar keys %bblist == 0 ) && (scalar keys %obblist == 0)) {
    $res .= "  -> **NO actual data contained within object**\n";
    return("", $res, $idv, \%bblist, \%obblist, "", "", $lfsv, $lfsv, $lfsv);
  }

  # Get location and occluded xml
  my ($err, $loc_xml, $occ_xml, $fsv, $sfs) = &_xmlrender_location_and_occluded_and_gfs(\%bblist, \%obblist, 1, 0);
  return("location and occluded render: $err")
    if (! MMisc::is_blank($err));

  if (MMisc::is_blank($fsv)) {
    $res .= "  => ** NO framespan extracted, DISCARDING object**\n";
    return("", $res, $idv, \%bblist, \%obblist, "", "", $lfsv, $lfsv, $lfsv);
  }

  $res .= "  -> got XML for location and occlusion + framespan\n";
  $res .= "  -> short \"used\" framespan: $sfs\n";

  return("", $res, $idv, \%bblist, \%obblist, $loc_xml, $occ_xml, $lfsv, $fsv, $sfs);
}

##########

sub _get_remove_section {
  my $rstr = shift @_;
  my $atk = shift @_;
  my $atc = shift @_;

  my $str = MtXML::get_named_xml_section_with_inline_content($atk, $atc, $rstr, $avcl_xmlerrorstring);

  return(0, "Could not find $atk with $atc", "")
    if ($str eq $avcl_xmlerrorstring);
  return(1, "Could not remove xml tag $atk", "")
    if (! MtXML::remove_xml_tags($atk, \$str));

  return(1, "", $str);
}

#####

sub _get_bboxes {
  my $rstr = shift @_;
  my $atk = shift @_;
  my $atc = shift @_;
  my @opt_atc = @_;

  my %res = ();

  my ($found, $err, $str) = &_get_remove_section($rstr, $atk, $atc);
  return($err, %res) if (! MMisc::is_blank($err));
  
  foreach my $oatc (@opt_atc) {
    my ($found, $err, $tmpstr) = &_get_remove_section($rstr, $atk, $oatc);
    return("Found $oatc, but: $err", %res)
      if (($found) && (! MMisc::is_blank($err)));
    next if (! $found);
    $str .= $tmpstr;
  }

  # $str should only contain "bbox"
  my $doit = 1;
  my $bbk = "data:bbox";
  while ($doit) {
    my $txt = MtXML::get_named_xml_section($bbk, \$str, $avcl_xmlerrorstring);
    if ($txt eq $avcl_xmlerrorstring) {
      $doit = 0;
      next;
    }
    # bbox cleanup
    $txt =~ s%\.0%%gs;
    $txt =~ s%\s*\/\>$%/>%gs;
    
    my ($err, $fs) = &_extract_fs($txt);
    return("Problem extracting framespan: $err", %res)
      if (! MMisc::is_blank($err));
    $res{$fs} = $txt;
  }

  return("Leftover data in string [$str]", %res)
    if (! MMisc::is_blank($str));
    
  return("", %res);
}

##########

sub _extract_fs {
  my $str = shift @_;

  if ($str =~ m%framespan\=\"([^\"]+?)\"%) {
    my $fs_fs = new ViperFramespan();
    $fs_fs->set_value($1);
    return($fs_fs->get_erromsg(), "")
      if ($fs_fs->error());
    return("", $fs_fs->get_value());
  }

  return("Could not find framespan", "");
}

####################

sub _xmlrender_location_and_occluded_and_gfs {
  my $rbb = shift @_;
  my $robb = shift @_;
  my $gtf = MMisc::iuv(shift @_, 1);
  my $ifg = MMisc::iuv(shift @_, 0);

  my $sts = 0;
  if ($gtf < 0) {
    $sts = 1;
    $gtf = 0;
  }

  my %comp = ();
  foreach my $key (keys %$rbb) {
    $comp{$key} = $$rbb{$key};
  }
  foreach my $key (keys %$robb) {
    return("framespan is both in bb and obb: $key", "", "", "")
      if (exists $comp{$key});
    $comp{$key} = $$robb{$key};
  }

  my @loc_xml_a = ();
  my @occ_xml_a = ();
  my @ordered_fs = sort _fs_sort keys %comp;
  my @kept_fs = ();
  my @sts_loc_xml_a = ();
  my $prev = 0;
  foreach my $key (@ordered_fs) {
    my $addtxt = "          " . $comp{$key};
    
    # For a SYS file, do not include occluded frames
    if (($gtf) || (! exists $$robb{$key})) {
      push @loc_xml_a, $addtxt;
      push @kept_fs, $key;
    }
    
    # We need the first five consecutive non occluded annotated frames
    if (($sts) && (scalar @sts_loc_xml_a < 5)) {
      my ($err, $b, $e) = &_get_begend_noself($key);
      return($err) if (! MMisc::is_blank($err));
      
      if (($prev != 0) && ($b - $prev > $ifg)) {
        # if the space between the new beginning and the old end is 
        # less than IFramesGap, reset the list
        @sts_loc_xml_a = ();
      } else {
        push @sts_loc_xml_a, $addtxt;
      }
      $prev = $e;
    }

    # ok to fill @occ_xml_a, it will be not used for SYS files
    push @occ_xml_a, "          <data:bvalue framespan=\"$key\" value=\"" . ((exists $$robb{$key}) ? "true" : "false") .  "\"/>";
  }

  #  No framespan kept, discard this object
  return("", "", "", "", "")
    if (scalar @kept_fs == 0);

##### MM (20090414)
# OLD DEFINITION: StarterSYS = first 5 _consecutives_ non occluded frames
#  if ($sts) {
#    return("Could not find 5 consecutive non occluded framespan (only " . scalar @sts_loc_xml_a . ")")
#      if (scalar @sts_loc_xml_a < 5);
#    @loc_xml_a = @sts_loc_xml_a;
#  }

# NEW DEFINITON: StarterSYS = first 5 non occluded frames
  if ($sts) {
    MMisc::warn_print("Could not find 5 non occluded framespan (only " . scalar @loc_xml_a . ")")
      if (scalar @loc_xml_a < 5);
    my $k = scalar @loc_xml_a;
    $k = ($k < 5) ? $k - 1 : 4;
    @loc_xml_a = @loc_xml_a[0..$k]; # Only keep the first 5 (or less) found
  }

  my $loc_xml = join("\n", @loc_xml_a);
  my $occ_xml = join("\n", @occ_xml_a);

  my $fs_fs = new ViperFramespan();
  $fs_fs->set_value(join(" ", @kept_fs));
  return("Could not get the global framespan: " . $fs_fs->get_errormsg(), "", "", "")
    if ($fs_fs->error());
  
  my ($begf, $endf) = $fs_fs->get_beg_end_fs();
  return("framespan error: " . $fs_fs->get_errormsg(), "", "", "")
    if ($fs_fs->error());

  my $fs_sfs = new ViperFramespan();
  $fs_sfs->set_value_beg_end($begf, $endf);
  return("Shorten framespan error: " . $fs_sfs->get_errormsg(), "", "", "")
    if ($fs_sfs->error());

  return("", $loc_xml, $occ_xml, $fs_fs->get_value(), $fs_sfs->get_value());
}

####################

sub _extract_named_Xvalue {
  my $name = shift @_;
  my $Xvalue = shift @_;
  my $section = shift @_;

  return($1)
    if ($section =~ m%<attribute\s+name=\"${name}\">.*?<data:${Xvalue}\s+value=\"([^\"]+?)\"%s);

  return(undef);
}

####################

sub _simplify_fs {
  my $self = shift @_;
  my $v = shift @_;

  my $fs_fs = new ViperFramespan();
  $fs_fs->set_value($v);
  return($self->_set_error_and_return("Framespan error: " . $fs_fs->get_errormsg(), ""))
    if ($fs_fs->error());

  return($fs_fs->get_value());
}

#####

sub _get_short_fs {
  my $self = shift @_;
  my $v = shift @_;

  my $fs_fs = new ViperFramespan();
  $fs_fs->set_value($v);
  return($self->_set_error_and_return("Framespan error: " . $fs_fs->get_errormsg(), ""))
    if ($fs_fs->error());

  my ($begf, $endf) = $fs_fs->get_beg_end_fs();
  return($self->_set_error_and_return("Framespan error: " . $fs_fs->get_errormsg(), ""))
    if ($fs_fs->error());

  my $fs_sfs = new ViperFramespan();
  $fs_sfs->set_value_beg_end($begf, $endf);
  return($self->_set_error_and_return("Shorten framespan error: " . $fs_sfs->get_errormsg(), ""))
    if ($fs_sfs->error());

  return($fs_sfs->get_value());
}

#####

sub _get_begend_noself {
  my $v = shift @_;

  my $fs_fs = new ViperFramespan();
  $fs_fs->set_value($v);
  return("Framespan error: " . $fs_fs->get_errormsg(), -1, -1)
    if ($fs_fs->error());
  my ($b, $e) = $fs_fs->get_beg_end_fs();
  return("Framespan error: " . $fs_fs->get_errormsg(), -1, -1)
    if ($fs_fs->error());

  return("", $b, $e);
}

#####

sub _get_beg_end {
  my $self = shift @_;
  my $v = shift @_;

  my ($err, $b, $e) = &_get_begend_noself($v);
  return($self->_set_error_and_return($err, -1, -1))
    if (! MMisc::is_blank($err));

  return($b, $e);
}

#####

sub _fs_sort {
  my (@f) = split(m%\:%, $a);
  my (@g) = split(m%\:%, $b); 

  my ($b1, $e1) = ($f[0], $f[-1]);
  my ($b2, $e2) = ($g[0], $g[-1]);

  # Order by beginning first
  return($b1 <=> $b2) if ($b1 != $b2);
  # by end if the beginning is the same
  return($e1 <=> $e2);
}

####################

sub _get_ids {
  my $self = shift @_;
  my $in = shift @_;

  return($self->_set_error_and_return("Key not present [$in]", undef))
    if (! exists $self->{id_fs}{$in});

  my @ids = keys %{$self->{id_fs}{$in}};

  return(@ids);
}

####################

sub _adapt_clip {
  my $name = shift @_;

  $name =~ s%\\%\/%g;
  $name =~ s%^\/%file:\/\/%;
  $name =~ s/\s/\%20/g;

  return($name);
}

#####

sub _write_header {
  my $clip = shift @_;
  my $endf = shift @_;
  my $gtf = shift @_;

  $clip = &_adapt_clip($clip);

  my $txt=<<EOF
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
    <descriptor name="PERSON" type="OBJECT">
      <attribute dynamic="true" name="LOCATION" type="http://lamp.cfar.umd.edu/viperdata#bbox"/>
EOF
;

$txt.=<<EOF
      <attribute dynamic="true" name="AMBIGUOUS" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="true" name="OCCLUSION" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="true" name="PRESENT" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
      <attribute dynamic="true" name="SYNTHETIC" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
EOF
  if ($gtf);

$txt.=<<EOF
    </descriptor>
EOF
;

  if ($gtf) {
    $txt .=<<EOF
    <descriptor name="FRAME" type="OBJECT">
      <attribute dynamic="true" name="EVALUATE" type="http://lamp.cfar.umd.edu/viperdata#bvalue"/>
    </descriptor>
EOF
;
  } else {
    $txt .=<<EOF
    <descriptor name="FRAME" type="OBJECT"/>
EOF
      ;
  }

$txt.=<<EOF
    <descriptor name="I-FRAMES" type="OBJECT"/>
  </config>
  <data>
    <sourcefile filename="$clip">
      <file id="0" name="Information">
        <attribute name="FRAMERATE">
          <data:fvalue value="1.0"/>
        </attribute>
        <attribute name="H-FRAME-SIZE"/>
        <attribute name="NUMFRAMES">
          <data:dvalue value="$endf"/>
        </attribute>
        <attribute name="SOURCETYPE"/>
        <attribute name="V-FRAME-SIZE"/>
      </file>
EOF
    ;

  return($txt);
}

#####

sub _write_trailer {
  my $gfs = shift @_;
  my $sgfs = shift @_;
  my $gtf = shift @_;


  my $txt=<<EOF
      <object name="I-FRAMES" id="0" framespan="$gfs"/>
EOF
    ;

  if ($gtf) {
    $txt.=<<EOF
      <object name="FRAME" id="0" framespan="$gfs">
        <attribute name="EVALUATE">
          <data:bvalue framespan="$sgfs" value="true"/>
        </attribute>
      </object>
EOF
      ;
  } else {
    $txt.=<<EOF
      <object name="FRAME" id="0" framespan="$gfs"/>
EOF
;
  }

  $txt.=<<EOF
    </sourcefile>
  </data>
</viper>
EOF
    ;

  return($txt);
}

#####

sub _num { return($a <=> $b); }

############################################################

1;
