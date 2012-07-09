package KWSecf;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# KWSEval
# KWSecf.pm
#
# Original Author: Jerome Ajot
# Extensions: Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
#
# KWSEval is an experimental system.  
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
# $Id$

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "KWSecf.pm Version: $version";

##

use KWSecf_excerpt;

require File::Spec;
use Data::Dumper;

use MMisc;
use xmllintHelper;
use MtXML;

sub __init {
  my $self = shift;
  my $ecffile = shift;

  $self->{FILE} = $ecffile;
  $self->{SIGN_DUR} = 0.0;
  $self->{EVAL_SIGN_DUR} = 0.0;
  $self->{VER} = "";
  $self->{EXCERPT} = ();
  $self->{FILECHANTIME} = {};
  $self->{FILE_EVAL_SIGN_DUR} = {};
  # Added to avoid overwriting in file load
  $self->{LoadedFile} = 0;
}

sub new {
  my $class = shift;
  my $ecffile = shift;
  my $self = {};

  bless $self;
  $self->__init($ecffile);
  my $err = "";
  $err = $self->loadFile($ecffile) if (defined($ecffile));
  MMisc::error_quit($err) if (! MMisc::is_blank($err));
  
  return $self;
}

sub new_empty {
  my $class = shift;
  my $ecffile = shift;
  my $self = {};
  
  bless $self;
  $self->__init($ecffile);

  return $self;
}

sub calcTotalDur
{
  my ($self, $srctypes, $filechans) = @_;
  #only include excerpts included in @$srctypes and @$filechans
  my %excerpts = ();
 EXBUILDER: foreach my $excerpt (@{ $self->{EXCERPT} }) {
    #Filter source type
    if ($srctypes) { 
      for (my $i; $i < @{ $srctypes }; $i++) {
	my $srctype = $excerpt->{SOURCE_TYPE};
	last if ($srctype =~ /^@{ $srctypes }[$i]$/i);
	next EXBUILDER if ($i == scalar(@{ $srctypes }) -1);
      }
    }
    #Filter filechan
    if ($filechans) {
      for (my $i; $i < @{ $filechans }; $i++) {
	my $filechan = $excerpt->{FILE} . "/" . $excerpt->{CHANNEL};
	last if ($filechan =~ /^@{ $filechans }[$i]$/i);
	next EXBUILDER if ($i == scalar(@{ $filechans }) -1);
      }
    }
    push (@{ $excerpts{$excerpt->{FILE}} }, $excerpt);
  }

  my $TotDur = 0.0;
  foreach my $file (keys %excerpts) {
    #Sort excerpts by begin time
    my @sortedExs = sort {$a->{TBEG} <=> $b->{TBEG} || $a->{TEND} <=> $b->{TEND}} @{ $excerpts{$file} };
    for (my $i; $i < @sortedExs; $i++) {
      my $TEND = $sortedExs[$i]->{TEND};
      for (my $j = $i+1; $j < @sortedExs; $j++) {
	$TEND = $sortedExs[$j]->{TBEG} if ($sortedExs[$j]->{TBEG} < $TEND);
      }
      my $dur = ($TEND - $sortedExs[$i]->{TBEG});
      $TotDur += $dur;
    }
  }
  return $TotDur;
}

sub unitTest
{
    my ($file1) = @_;

    my $err = MMisc::check_file_r($file1);
    if (! MMisc::is_blank($err)) {
      print "Issue with needed test file ($file1) : $err\n";
      return(0);
    }

    print "Test ECF\n";
    
    print " Loading File...          ";
    my $ecf = new KWSecf($file1);
    print "OK\n";
    
    print " Filtering 'file'...      ";
    if($ecf->FilteringTime("ar_4489_exA", 1, 1000.0, 1001.0) == 0)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    } 
    
    print " Filtering 'channel'...   ";
    if($ecf->FilteringTime("20010223_1530_1600_NTV_ARB_exA", 1, 1000.0, 1001.0) == 1)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }   
    
    print " Filtering 'in'...        ";
    if($ecf->FilteringTime("20010217_0000_0100_VOA_ARB_exA", 1, 0.0, 1.0) == 1)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }
    
    print " Filtering 'out'...       ";
    if($ecf->FilteringTime("20010217_0000_0100_VOA_ARB_exA", 1, 2000.0, 2001.0) == 0)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }
    
    print " Filtering 'part in'...   ";
    if($ecf->FilteringTime("20010217_0000_0100_VOA_ARB_exA", 1, 1000.0, 2001.0) == 0)
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }
    
    print " Filtering 'multi-seg'... ";
    if( ($ecf->FilteringTime("ar_4758_exA", 2, 350.0, 351.0) == 0) && 
        ($ecf->FilteringTime("ar_4758_exA", 2, 300.0, 300.1) == 1) &&
        ($ecf->FilteringTime("ar_4758_exA", 2, 500.0, 501.0) == 1) )
    {
        print "OK\n";
    }
    else
    {
        print "FAILED!\n";
        return 0;
    }

    print " Calculating total duration(1)... ";
    if (abs($ecf->calcTotalDur - 7997.148) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print " Calculating total duration(2)... ";
    if (abs($ecf->calcTotalDur(["bnews"]) - 3570.363) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print " Calculating total duration(3)... ";
    if (abs($ecf->calcTotalDur([], ["^.*_ARB_.*\/[12]", "ar_4489_exA\/[12]"]) - 3870.853) <= .0005) { print "OK\n"; }
    else { print "FAILED!\n"; return 0; }

    print "All tests OK\n";
    return 1;
}

sub toString
{
    my ($self) = @_;

    print "Dump of ECF File\n";
    print "   File: " . $self->{FILE} . "\n";
    print "   Signal duration: " . $self->{SIGN_DUR} . "\n";
    print "   Version: " . $self->{VER} . "\n";
    print "   Excerpt:\n";
    
    for (my $i=0; $i<@{ $self->{EXCERPT} }; $i++)
    {
        print "    ".$self->{EXCERPT}[$i]->toString()."\n";
    }
}

########################################

sub loadXMLFile {
  my ($self, $ecff) = @_;
  my $ecffilestring = "";

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);
  
  my $err = MMisc::check_file_r($ecff);
  return("Problem with input file ($ecff): $err")
    if (! MMisc::is_blank($err));

  my $modfp = MMisc::find_Module_path('KWSecf');
  return("Could not obtain \'KWSecf.pm\' location, aborting")
    if (! defined $modfp);

  my $f4b = 'F4DE_BASE';
  my $xmllint_env = "F4DE_XMLLINT";
  my $xsdpath = (exists $ENV{$f4b}) ? $ENV{$f4b} . "/lib/data" : $modfp . "/../../KWSEval/data";
  my @xsdfilesl = ('KWSEval-ecf.xsd');

#  print STDERR "Loading ECF file '$ecff'.\n";

  # First let us use xmllint on the file XML file
  my $xmlh = new xmllintHelper();
  my $xmllint = MMisc::get_env_val($xmllint_env, "");
  return("While trying to set \'xmllint\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xmllint($xmllint));
  return("While trying to set \'xsdfilesl\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdfilesl(@xsdfilesl));
  return("While trying to set \'Xsdpath\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdpath($xsdpath));

  my $ecffilestring = $xmlh->run_xmllint($ecff);
  return("$ecff: \'xmllint\' validation failed [" . $xmlh->get_errormsg() . "]\n")
    if ($xmlh->error());

  ## Processing file content

  # Remove all XML comments
  $ecffilestring =~ s%\<\!\-\-.+?\-\-\>%%sg;

  # Remove <?xml ...?> header
  $ecffilestring =~ s%^\s*\<\?xml.+?\?\>%%is;

  # At this point, all we ought to have left is the '<ecf>' content
  return("After initial cleanup, we found more than just \'ecf\', aborting")
    if (! ( ($ecffilestring =~ m%^\s*\<ecf\s%is) && ($ecffilestring =~ m%\<\/ecf\>\s*$%is) ) );
  my $dem = "Martial's DEFAULT ERROR MESSAGE THAT SHOULD NOT BE FOUND IN STRING, OR IF IT IS WE ARE SO VERY UNLUCKY";
  
  # order is important
  my @ecf_attrs = ('source_signal_duration', 'version');
  my @exc_attrs = ('audio_filename', 'channel', 'tbeg', 'dur', 'language', 'source_type');

  my $here = 'ecf';
  my ($err, $string, $section, %ecf_attr) = &element_extractor_check($dem, $ecffilestring, $here, \@ecf_attrs);
  return($err) if (! MMisc::is_blank($err));
  return("After removing '<$here>', found leftover content, aborting")
    if (! MMisc::is_blank($string));

  $self->{SIGN_DUR} = &__get_attr(\%ecf_attr, $ecf_attrs[0]);
  $self->{VER} = &__get_attr(\%ecf_attr, $ecf_attrs[1]);

  my $exp = 'excerpt';
  while (! MMisc::is_blank($section)) {
    # First off, confirm the first section is the expected one
    my $name = MtXML::get_next_xml_name(\$section, $dem);
    return("In \'$here\', while checking for \'$exp\': Problem obtaining a valid XML name, aborting")
      if ($name eq $dem);
    return("In \'$here\': \'$exp\' section not present (instead: $name), aborting")
      if ($name ne $exp);
    ($err, $section, my $dummy, my %exc_attr) = &element_extractor_check($dem, $section, $exp, \@exc_attrs);
    return($err) if (! MMisc::is_blank($err));
    return("While processing <$here>'s <$exp>, found unexpected content: $dummy")
      if (! MMisc::is_blank($dummy));

    my $audio_filename = &__get_attr(\%exc_attr, $exc_attrs[0]);
    my $channel = &__get_attr(\%exc_attr, $exc_attrs[1]);
    my $tbeg = &__get_attr(\%exc_attr, $exc_attrs[2]);
    my $dur = &__get_attr(\%exc_attr, $exc_attrs[3]);
    my $language = &__get_attr(\%exc_attr, $exc_attrs[4]);
    my $source_type = &__get_attr(\%exc_attr, $exc_attrs[5]);

    my $purged_filename = "";
    my ($errf, $d, $f, $e) = MMisc::split_dir_file_ext($audio_filename);
    if (($e eq 'sph') || ($e eq 'wav')) {
      $purged_filename = $f;
    } else {
      $purged_filename = MMisc::concat_dir_file_ext('', $f, $e);
    }

    $self->{EVAL_SIGN_DUR} += sprintf("%.4f", $dur) 
      if (! $self->{FILECHANTIME}{$purged_filename});

    push @{$self->{EXCERPT}}, new KWSecf_excerpt($audio_filename, $channel, $tbeg, $dur, $language, $source_type);

    ### Track the source types for the reports
    push @{$self->{FILECHANTIME}{$purged_filename}{$channel}}, [ ($tbeg, $tbeg + $dur) ];
        
    $self->{FILE_EVAL_SIGN_DUR}{$purged_filename} = 0 
      if (! $self->{FILE_EVAL_SIGN_DUR}{$purged_filename});
    $self->{FILE_EVAL_SIGN_DUR}{$purged_filename} += sprintf("%.4f", $dur);
  }

  foreach my $filename (keys %{$self->{FILE_EVAL_SIGN_DUR}}) {
    my $nbrchannel = scalar(keys(%{$self->{FILECHANTIME}{$filename}}));
    $self->{FILE_EVAL_SIGN_DUR}{$filename} = $self->{FILE_EVAL_SIGN_DUR}{$filename}/$nbrchannel;
  }

  $self->{LoadedFile} = 1;

  return("");
}

#####

sub __get_attr {
  my ($rh, $key) = @_;

  MMisc::error_quit("Requested hash key does not exists ($key)")
      if (! exists $$rh{$key});

  return($$rh{$key});
}

####

sub element_extractor_check {
  my ($dem, $string, $here, $rattr) = @_;

  $string = MMisc::clean_begend_spaces($string);

  (my $err, $string, my $section, my %iattr) = MtXML::element_extractor($dem, $string, $here);
  return($err) if (! MMisc::is_blank($err));

  foreach my $attr (@$rattr) {
    return("Could not find <$here>'s $attr attribute")
      if (! exists $iattr{$attr});
  }

  return("", $string, $section, %iattr);
}

##############################

sub saveFile {
  my ($self, $fn) = @_;
  
  my $to = MMisc::is_blank($fn) ? $self->{FILE} : $fn;
  # Re-adapt the file name to remove all ".memdump" (if any)
  $to = &_rm_mds($to);

  my $txt = $self->get_XMLrewrite();
  return(MMisc::writeTo($to, "", 1, 0, $txt));
}

#####

sub get_XMLrewrite {
  my ($self) = @_;
     
  my $txt = "";

  $txt .= "<ecf source_signal_duration=\"$self->{SIGN_DUR}\" version=\"$self->{VER}\">\n";
     
  if ($self->{EXCERPT}) {
    for (my $i=0; $i < @{ $self->{EXCERPT} }; $i++) {
      my $tbegform = sprintf("%.3f", $self->{EXCERPT}[$i]->{TBEG});
      my $tdurform = sprintf("%.3f", $self->{EXCERPT}[$i]->{DUR});
      
      $txt .= "<excerpt audio_filename=\"$self->{EXCERPT}[$i]->{AUDIO_FILENAME}\" channel=\"$self->{EXCERPT}[$i]->{CHANNEL}\" tbeg=\"$tbegform\" dur=\"$tdurform\" language=\"$self->{EXCERPT}[$i]->{LANGUAGE}\" source_type=\"$self->{EXCERPT}[$i]->{SOURCE_TYPE}\"/>\n";
    }
  }
    
  $txt .= "</ecf>\n";
     
  return($txt);
}

########## 'save' / 'load' Memmory Dump functions

my $MemDump_Suffix = ".memdump";

sub get_MemDump_Suffix { return $MemDump_Suffix; }

my $MemDump_FileHeader_cmp = "\#  KWSEval KWSecf MemDump";
my $MemDump_FileHeader_gz_cmp = $MemDump_FileHeader_cmp . " (Gzip)";
my $MemDump_FileHeader_add = "\n\n";

my $MemDump_FileHeader = $MemDump_FileHeader_cmp . $MemDump_FileHeader_add;
my $MemDump_FileHeader_gz = $MemDump_FileHeader_gz_cmp . $MemDump_FileHeader_add;

#####

sub _rm_mds {
  my ($fname) = @_;

  return($fname) if (MMisc::is_blank($fname));

  # Remove them all
  while ($fname =~ s%$MemDump_Suffix$%%) {1;}

  return($fname);
}

#####

sub save_MemDump {
  my ($self, $fname, $mode, $printw) = @_;

  $printw = MMisc::iuv($printw, 1);

  # Re-adapt the file name to remove all ".memdump" (added later in this step)
  $fname = &_rm_mds($fname);

  my $tmp = MMisc::dump_memory_object
    ($fname, $MemDump_Suffix, $self,
     $MemDump_FileHeader,
     ($mode eq "gzip") ? $MemDump_FileHeader_gz : undef,
     $printw);

  return("Problem during actual dump process", $fname)
    if ($tmp != 1);

  return("", $fname);
}

##########

sub _md_clone_value {
  my ($self, $other, $attr) = @_;

  MMisc::error_quit("Attribute ($attr) not defined in MemDump object")
      if (! exists $other->{$attr});
  $self->{$attr} = $other->{$attr};
}

#####

sub load_MemDump_File {
  my ($self, $file) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);

  my $err = MMisc::check_file_r($file);
  return("Problem with input file ($file): $err")
    if (! MMisc::is_blank($err));

  my $object = MMisc::load_memory_object($file, $MemDump_FileHeader_gz);

  $self->_md_clone_value($object, 'FILE');
  $self->_md_clone_value($object, 'SIGN_DUR');
  $self->_md_clone_value($object, 'EVAL_SIGN_DUR');
  $self->_md_clone_value($object, 'VER');
  $self->_md_clone_value($object, 'EXCERPT');
  $self->_md_clone_value($object, 'FILECHANTIME');
  $self->_md_clone_value($object, 'FILE_EVAL_SIGN_DUR');

  $self->{LoadedFile} = 1;

  return("");
}

#####

sub loadFile {
  my ($self, $ecff) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);
  
  my $err = MMisc::check_file_r($ecff);
  return("Problem with input file ($ecff): $err")
    if (! MMisc::is_blank($err));

  open FILE, "<$ecff"
    or return("Problem opening file ($$ecff) : $!");

  my $header = <FILE>;
  close FILE;
  chomp $header;

  return($self->load_MemDump_File($ecff))
    if ( ($header eq $MemDump_FileHeader_cmp)
         || ($header eq $MemDump_FileHeader_gz_cmp) );

  return($self->loadXMLFile($ecff));
}

####################

sub FilteringTime
{
    my($self, $file, $chan, $bt, $et) = @_;
    
    if($self->{FILECHANTIME}{$file}{$chan})
    {
        for(my $i=0; $i<@{ $self->{FILECHANTIME}{$file}{$chan} }; $i++)
        {
            if( ($bt >= $self->{FILECHANTIME}{$file}{$chan}[$i][0]) && ($et <= $self->{FILECHANTIME}{$file}{$chan}[$i][1]) )
            {
                return(1);
            }
        }
    }
    
    return(0);
}

1;

