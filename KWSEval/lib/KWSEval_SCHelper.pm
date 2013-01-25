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


#####

sub __cfgcheck {
  my ($specfile, $t, $v, $c) = @_;
  return if ($c == 0);
  MMisc::error_quit("Missing or improper datum [$t] in \'SpecFile\' ($specfile)")
    if ($v);
}

#####

sub loadSpecfile {
  my ($specfile) = @_;

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

#####

sub check_name {
  my ($kwsyear, $eteam, $name, $verb) = @_;
  return(&check_name_kws12($kwsyear, $eteam, $name, $verb))
    if ($kwsyear eq 'KWS12');
  return(&check_name_kws13($kwsyear, $eteam, $name, $verb))
    if ($kwsyear eq 'KWS13');
  MMisc::error_quit("Unknown EXPID name handler for \'$kwsyear\'");
}

##

sub check_name_kws12 {
  my ($kwsyear, $eteam, $name, $verb) = @_;

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
  my ($kwsyear, $eteam, $name, $verb) = @_;

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

  return("Could not find file ($tf) in DBdir", ""); 
}


########################################

1;

