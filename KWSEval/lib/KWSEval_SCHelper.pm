package KWSEval_SCHelper;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# KWSEval
# KWSEval_SCHelper.pm
#
# Author: Martial Michel
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

my $versionid = "KWEval_SCHelper.pm Version: $version";

##
use MMisc;
use KWSList;

##########
# Expected values
my $expid_count = 9;
my @expid_tag;
my @expid_corpus;
my @expid_partition;
my @expid_scase;
my @expid_task;
my @expid_trncond;
my @expid_sysid_beg;
my @expid_lp;
my @expid_lr;
my @expid_aud;

my @Scase_toSequester;

my %AuthorizedSet;
my $ctm_rgx = undef;
my $kwslist_rgx = undef;
my %Task2Regexp;

##########

sub selectSpecfile {
  my ($default, @dirs) = @_;
  
  my $fn = $default;
  $fn =~ s%^.+/%%; # keep only the file part

  foreach my $dir (reverse @dirs) {
    my $tc = "$dir/$fn";
    if (MMisc::does_file_exist($tc)) {
      MMisc::warn_print("Found a version of the configuration file in a dbDir entry, using: $tc");
      return($tc);
    }
  }

  return($default);
}

##########

sub __cfgcheck {
  my ($specfile, $t, $v, $c) = @_;
  return if ($c == 0);
  MMisc::error_quit("Missing or improper datum [$t] in \'SpecFile\' ($specfile)")
    if ($v);
}

#####

sub loadSpecfile {
  my ($specfile, $uctm_rgx, $ukwslist_rgx) = @_;

  MMisc::error_quit("One of CTM or KWSLIST regexp is not provided to the function, aborting")
      if ((! defined $uctm_rgx) || (! defined $ukwslist_rgx));

  # reset values
  @expid_tag = ();
  @expid_corpus = ();
  @expid_partition = ();
  @expid_scase = ();
  @expid_task = ();
  @expid_trncond = ();
  @expid_sysid_beg = ();
  @expid_lp = ();
  @expid_lr = ();
  @expid_aud = ();
  @Scase_toSequester = ();
  %AuthorizedSet = ();
  %Task2Regexp = ();
  $ctm_rgx = $uctm_rgx;
  $kwslist_rgx = $ukwslist_rgx;

  my $tmpstr = MMisc::slurp_file($specfile);
  MMisc::error_quit("Problem loading \'Specfile\' ($specfile)")
      if (! defined $tmpstr);
  eval $tmpstr;
  MMisc::error_quit("Problem during \'SpecFile\' use ($specfile) : " . join(" | ", $@))
      if $@;
  
  # EXPID side
  &__cfgcheck($specfile, "\@expid_tag", (scalar @expid_tag == 0), 1);
  &__cfgcheck($specfile, "\@expid_partition", (scalar @expid_partition == 0), 1);
  &__cfgcheck($specfile, "\@expid_scase", (scalar @expid_scase == 0), 1);
  &__cfgcheck($specfile, "\@expid_task", (scalar @expid_task == 0), 1);
  &__cfgcheck($specfile, "\@expid_trncond", (scalar @expid_trncond == 0), ($expid_count == 9));
  &__cfgcheck($specfile, "\@expid_lp", (scalar @expid_lp == 0), ($expid_count == 11));
  &__cfgcheck($specfile, "\@expid_lr", (scalar @expid_lr == 0), ($expid_count == 11));
  &__cfgcheck($specfile, "\@expid_aud", (scalar @expid_aud == 0), ($expid_count == 11));
  &__cfgcheck($specfile, "\@expid_sysid_beg", (scalar @expid_sysid_beg == 0), 1);

  MMisc::error_quit("More \@Scase_toSequester than scase in \'SpecFile\' ($specfile)")
      if (scalar @Scase_toSequester > scalar @expid_scase);
  MMisc::error_quit("No \%AuthorizedSet set in \'SpecFile\' ($specfile)")
      if (scalar keys %AuthorizedSet == 0);
  MMisc::error_quit("No \%Task2Regexp set in \'SpecFile\' ($specfile)")
      if (scalar keys %Task2Regexp == 0);
  
  return($expid_tag[0]);
}

#####

sub cmp_exp {
  my ($t, $v, @e) = @_;

  return("$t ($v) does not compare to expected value (" . join(" ", @e) ."). ")
    if (! grep(m%^$v$%, @e));

  return("");
}

#####

sub vprint {
  my $verb = shift @_;
  return if (! $verb);
  my $s = "********************";
  print substr($s, 0, shift @_), " ", join("", @_), "\n";
}

##########

sub get_Scase_toSequester { return(@Scase_toSequester); }
sub get_AuthorizedSet { return(%AuthorizedSet); }

##########

sub check_name {
  my ($kwsyear, $eteam, $name, $ext, $verb) = @_;
  return(&check_name_kws12($kwsyear, $eteam, $name, $ext, $verb))
    if ($kwsyear eq 'KWS12');
  return(&check_name_kws13($kwsyear, $eteam, $name, $ext, $verb))
    if ($kwsyear eq 'KWS13');
  return(&check_name_kws14($kwsyear, $eteam, $name, $ext, $verb))
    if ($kwsyear eq 'KWS14');
  MMisc::error_quit("Unknown EXPID name handler for \'$kwsyear\'");
}

##

sub check_name_kws12 {
  my ($kwsyear, $eteam, $name, $ext, $verb) = @_;

  my $et = "\'EXP-ID\' not of the form \'${kwsyear}_<TEAM>_<CORPUS>_<PARTITION>_<SCASE>_<TASK>_<TRNCOND>_<SYSID>_<VERSION>\' : ";
  
  my ($ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $ltrncond, $lsysid, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters. ", "")
    if (MMisc::any_blank($ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $ltrncond, $lsysid, $lversion));
  
  my $err = "";
  
  $err .= &cmp_exp($kwsyear, $ltag, @expid_tag);

  $err .= " <TEAM> ($lteam) is different from required <TEAM> ($eteam). "
    if ((defined $eteam) && ($eteam ne $lteam));
  
  $err .= &cmp_exp("<PARTITION>",  $lpart, @expid_partition);
  $err .= &cmp_exp("<SCASE>", $lscase, @expid_scase);
  $err .= &cmp_exp("<TASK>", $ltask, @expid_task);

  if (grep(m%^$ltask$%, @expid_task)) {
    if (! MMisc::safe_exists(\%Task2Regexp, $ltask)) {
      &err .= "Can not find an extension match for task ($ltask). ";
    } else {
      my $tv = $Task2Regexp{$ltask};
      $err .= "File's extension ($ext) for task ($ltask) does not match authorized regexp ($tv). "
        if ($ext !~ m%^$tv$%);
    }
  }

  $err .= &cmp_exp("<TRNCOND>", $ltrncond, @expid_trncond);
  
  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expid_sysid_beg) . "). "
    if (! grep(m%^$b$%, @expid_sysid_beg));
  
  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) || ($lversion > 199) );
  # More than 199 submissions would make anybody suspicious ;)
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  &vprint($verb, 3, "$ltag | <TEAM> = $lteam | <CORPUS> = $lcorpus | <PARTITION> = $lpart | <SCASE> = $lscase | <TASK> = $ltask | <TRNCOND> = $ltrncond | <SYSID> = $lsysid | <VERSION> = $lversion");
  
  return("", $ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $ltrncond, $lsysid, $lversion, undef, undef, undef);
}

##

sub check_name_kws13 {
  my ($kwsyear, $eteam, $name, $ext, $verb) = @_;

  my $et = "\'EXP-ID\' not of the form \'${kwsyear}_<TEAM>_<CORPUS>_<PARTITION>_<SCASE>_<TASK>_<LP>_<LR>_<AUD>_<SYSID>_<VERSION>\' : ";
  
  my ($ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $llp, $llr, $laud, $lsysid, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters. ", "")
    if (MMisc::any_blank($ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $llp, $llr, $laud, $lsysid, $lversion));
  
  my $err = "";
  
  $err .= &cmp_exp($kwsyear, $ltag, @expid_tag);

  $err .= " <TEAM> ($lteam) is different from required <TEAM> ($eteam). "
    if ((defined $eteam) && ($eteam ne $lteam));
  
  $err .= &cmp_exp("<PARTITION>",  $lpart, @expid_partition);
  $err .= &cmp_exp("<SCASE>", $lscase, @expid_scase);
  $err .= &cmp_exp("<TASK>", $ltask, @expid_task);

  if (grep(m%^$ltask$%, @expid_task)) {
    if (! MMisc::safe_exists(\%Task2Regexp, $ltask)) {
      &err .= "Can not find an extension match for task ($ltask). ";
    } else {
      my $tv = $Task2Regexp{$ltask};
      $err .= "File's extension ($ext) for task ($ltask) does not match authorized regexp ($tv). "
        if ($ext !~ m%^$tv$%);
    }
  }

  $err .= &cmp_exp("<LP>", $llp, @expid_lp);
  $err .= &cmp_exp("<LR>", $llr, @expid_lr);
  $err .= &cmp_exp("<AUD>", $laud, @expid_aud);
  
  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expid_sysid_beg) . "). "
    if (! grep(m%^$b$%, @expid_sysid_beg));
  
  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ! MMisc::is_integer($lversion));
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  &vprint($verb, 3, "$ltag | <TEAM> = $lteam | <CORPUS> = $lcorpus | <PARTITION> = $lpart | <SCASE> = $lscase | <TASK> = $ltask | <LP> = $llp | <LR> = $llr | <AUD> = $laud | <SYSID> = $lsysid | <VERSION> = $lversion");
  
  return("", $ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, undef, $lsysid, $lversion, $llr, $llp, $laud);
}

################################################################################

sub check_name_kws14 {
  my ($kwsyear, $eteam, $name, $ext, $verb) = @_;

  my $et = "\'EXP-ID\' not of the form \'${kwsyear}_<TEAM>_<CORPUS>_<PARTITION>_<SCASE>_<TASK>_<SYSID>_<VERSION>\' : ";
  
  my ($ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $lsysid, $lversion,
      @left) = split(m%\_%, $name);
  
  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);
  
  return($et ." missing parameters. ", "")
    if (MMisc::any_blank($ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, $lsysid, $lversion));
  
  my $err = "";
  
  $err .= &cmp_exp($kwsyear, $ltag, @expid_tag);

  $err .= " <TEAM> ($lteam) is different from required <TEAM> ($eteam). "
    if ((defined $eteam) && ($eteam ne $lteam));
  
  $err .= &cmp_exp("<PARTITION>",  $lpart, @expid_partition);
  $err .= &cmp_exp("<SCASE>", $lscase, @expid_scase);
  $err .= &cmp_exp("<TASK>", $ltask, @expid_task);

  if (grep(m%^$ltask$%, @expid_task)) {
    if (! MMisc::safe_exists(\%Task2Regexp, $ltask)) {
      &err .= "Can not find an extension match for task ($ltask). ";
    } else {
      my $tv = $Task2Regexp{$ltask};
      $err .= "FileX's extension ($ext) for task ($ltask) does not match authorized regexp ($tv). "
        if ($ext !~ m%^$tv$%);
    }
  }
  
  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expid_sysid_beg) . "). "
    if (! grep(m%^$b$%, @expid_sysid_beg));
  
  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ! MMisc::is_integer($lversion));
  
  return($et . $err, "")
    if (! MMisc::is_blank($err));
  
  &vprint($verb, 3, "$ltag | <TEAM> = $lteam | <CORPUS> = $lcorpus | <PARTITION> = $lpart | <SCASE> = $lscase | <TASK> = $ltask | <SYSID> = $lsysid | <VERSION> = $lversion");
  
  return("", $ltag, $lteam, $lcorpus, $lpart, $lscase, $ltask, undef, $lsysid, $lversion);
}

################################################################################

sub check_system_description {
#Specific to KWS14
    my ($sys_desc_f, $recognized_resources) = @_;
    #recognized_resources should be a hash ref
    $recognized_resources = {} unless defined $recognized_resources;
    
    my @required_times = ("Ingestion Elapsed Time",
			  "Ingestion Total CPU Time",
			  "Ingestion Maximum CPU Memory",
			  "Search Elapsed Time",
			  "Search Total CPU Time",
			  "Search Maximum CPU Memory");

    my %desc_data = ();
    my $found_datadef = 0;
    open SYSDESC, "<$sys_desc_f" or return "Problem opening system description file '$sys_desc_f'";
    while (my $line = <SYSDESC>) {
	if (!$found_datadef && (my @match = $line =~ /(BaseLR)\{([^\+:,]+)\}(,(BabelLR)\{(([^\+:,]+\+?)*)\})?(,(OtherLR)\{(([^\+:,]+\+?)*)\})?:
                                 (AM)\{(([^\+:,]+\+?)*)\},(LM)\{(([^\+:,]+\+?)*)\},(PRON)\{(([^\+:,]+\+?)*)\},(AR)\{(([^\+:,]+\+?)*)\}/x)) {
	    $found_datadef = 1;
	    foreach my $i (0, 3, 7, 10, 13, 16, 19) { # BaseLR, BabelLR, OtherLR # AM, LM, PRON, AR
		next if MMisc::is_blank($match[$i]);
		my $def_type = $match[$i] =~ /LR$/ ? "LRDEFS" : "USAGEDEFS";

		push @{ $desc_data{$def_type}{$match[$i]} }, split(/\+/, $match[$i+1]);

		foreach my $res_id (@{ $desc_data{$def_type}{$match[$i]} }) {
	    	    MMisc::warn_print("Unrecognized resource ID '$res_id' for '$match[$i]' in system description") unless $recognized_resources->{$res_id};
	    	}
	    }

	} elsif (my @match = $line =~ /((Ingestion|Search)\s(Elapsed\sTime|Total\s(CPU|GPU)\sTime|Maximum\s(CPU|GPU)\sMemory)).*?-\s*([\d]+(:\d+)*(\.\d+)?)/) {
	    $desc_data{TIME}{$match[0]} = $match[5];
	}
    }
    close SYSDESC;

    return "System description is missing <DATADEF> line!" unless $found_datadef;
    # Check required times
    foreach my $time (@required_times) {
	if (MMisc::is_blank($desc_data{TIME}{$time})) {
	    return "System description is missing required data '$time'!";
	}
    }

    return("", \%desc_data);
}

###################################################################

sub get_recog_resources {
    my (@dbdirs) = @_;
    
    my %resources = ();
    my $resource_fn = "DataDefs.tsv";
    my $resource_fc = 0; #Count to make sure we found at least one resource file

    foreach my $dbdir (@dbdirs) {
	my $rf = $dbdir."/$resource_fn";
	if (MMisc::does_file_exist($rf)) {
	    open RSRCF, "<$rf" or return "Problem opening resource file '$rf'";
	    my $header = <RSRCF>;
	    while (my $line = <RSRCF>) {
		my ($rsrcID) = split(/\t/, $line);
		chomp($rsrcID);
		$resources{$rsrcID} = 1;
	    }
	    close RSRCF;
	    $resource_fc++;
	}
    }
    return "Couldn't find a $resource_fn file in dbDir(s) ".join(', ', @dbdirs) unless $resource_fc > 0;
    return "", \%resources;
}

################################################################################

sub check_kwslist_kwlist {
  my ($kwslistf, $bypassxmllint, @dbdir) = @_;

  # Load the KWSLIST to get the actual "TERMLIST_FILENAME" ...
  my $object = new KWSList(undef);
  my $err = $object->openXMLFileAccess($kwslistf, 0, $bypassxmllint);
  return("Problem checking KWSList file header ($kwslistf): $err", "")
    if (! MMisc::is_blank($err));
  my $tf = $object->get_TERMLIST_FILENAME();
  return("Problem examining KWSList file's header, could not find a \'kwlist\' entry", "")
    if (MMisc::is_blank($tf));

  ## if no dbDir is provided, we simply return the path found as is
  return("", $tf) if (scalar @dbdir == 0);

  ## Otherwise we try to find the file in dbDir 

  # remove any path
  $tf =~ s%^.+/%%;

  for (my $i = 0; $i < scalar @dbdir; $i++) {
    my $file = $dbdir[$i] . "/$tf";
    return("", $file)
      if (MMisc::does_file_exist($file));
  }

  return("Could not find in dbDir the \'kwlist_filename\' ($tf) listed in the header of the \'kwslist.xml\'", ""); 
}

############################################################

sub split_corpus_partition {
  my ($f, $e) = @_;
  $f =~ s%$e$%%i;
  my (@rest) = split(m%\_%, $f);
  MMisc::error_quit("Could not split ($f) in <CORPUSID>_<PARTITION>")
    if (scalar @rest != 2);
  return("", @rest);
}

#####

sub prune_list {
  my $dir = shift @_;
  my $ext = shift @_;
  my $robj = shift @_;
  my $duplok = shift @_;

  my @list = grep(m%$ext$%i, @_);
  my %rest = MMisc::array1d_to_ordering_hash(\@_);
  for (my $i = 0; $i < scalar @list; $i++) {
    my $file = $list[$i];
    my ($err, $cid, $pid) = split_corpus_partition($file, $ext);
    MMisc::error_quit($err) if (! MMisc::is_blank($err));
    my $here = "$dir/$file";
    if ($duplok == 0) {
      MMisc::warn_print("An \'$ext\' file already exist for <CORPUSID> = $cid | <PARTITION> = $pid (" . $$robj{$cid}{$pid} . "), being replaced by: $here")
        if (MMisc::safe_exists($robj, $cid, $pid));
    }
    $$robj{$cid}{$pid} = $here;
    delete $rest{$file};
  }

  return(sort {$rest{$a} <=> $rest{$b}} (keys %rest));
}

##

sub obtain_ecf_tlist {
  my ($dir, $ecf_ext, $recf, $tlist_ext_rgx, $rtlist, $rttm_ext, $rrttm, $stm_ext, $rstm) = @_;

  my @files = MMisc::get_files_list($dir);

  @files = &prune_list($dir, $tlist_ext_rgx, $rtlist, 1, @files);
  @files = &prune_list($dir, $rttm_ext, $rrttm, 0, @files);
  @files = &prune_list($dir, $ecf_ext, $recf, 0, @files);
  @files = &prune_list($dir, $stm_ext, $rstm, 0, @files);
}

#####

sub check_ecf_tlist_pairs {
  my ($verb, $recf, $rtlist, $rttm_ext, $rrttm, $stm_ext, $rstm) = @_;

  vprint($verb, 1, "Checking found ECF & TLIST");
  my @tmp1 = keys %$recf;
  push @tmp1, keys %$rtlist;
  foreach my $k1 (sort (MMisc::make_array_of_unique_values(\@tmp1))) {
    MMisc::error_quit("While checking for matching ECF & KWlist pairs: can not find any ECF with <CORPUSID>: $k1")
      if (! exists $$recf{$k1});
    MMisc::error_quit("While checking for matching ECF & KWlist pairs: can not find any KWlist with <CORPUSID>: $k1")
      if (! exists $$rtlist{$k1});
    my @tmp2 = keys %{$$recf{$k1}};
    push @tmp2, keys %{$$rtlist{$k1}};
    foreach my $k2 (sort (MMisc::make_array_of_unique_values(\@tmp2))) {
      MMisc::error_quit("While checking for matching ECF & KWlist pairs: For <CORPUSID>: $k1, can not find any ECF with <PARTITION>: $k2")
        if (! exists $$recf{$k1}{$k2});
      MMisc::error_quit("While checking for matching ECF & KWlist pairs: <CORPUSID>: $k1, can not find any KWlist with <PARTITION>: $k2")
        if (! exists $$rtlist{$k1}{$k2});
      my @a = ();
      push (@a, $rttm_ext) if (MMisc::safe_exists($rrttm, $k1, $k2));
      push (@a, $stm_ext) if (MMisc::safe_exists($rstm, $k1, $k2));
      my $tmp = (scalar @a > 0) ? " | \'" . join("\' & \'", @a) . "\' found" : "";
      vprint($verb, 2, "Have <CORPUSID> = $k1 | <PARTITION> = $k2$tmp");
    }
  }
}

########################################

1;

