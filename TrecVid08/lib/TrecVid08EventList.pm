package TrecVid08EventList;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 EventList
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08EventList.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;
use TrecVid08ViperFile;
use TrecVid08Observation;
use TrecVid08ECF;
use ViperFramespan;

use MErrorH;
use MMisc;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08EventList.pm Version: $version";

my @ok_events = ();
my @full_ok_events = ();
my $obs_dummy_key = "";

my $obs_added = 1;
my $obs_SPadd = 101;
my $obs_rejected = 99;

## Constructor
sub new {
  my ($class) = shift @_;

  my $errormsg = new MErrorH("TrecVid08EventList");

  $errormsg->set_errormsg("\'new\' does not accept any parameter. ") if (scalar @_ > 0);

  my $tmp = &_set_infos();
  $errormsg->set_errormsg("Could not obtain the list authorized events ($tmp). ") if (! MMisc::is_blank($tmp));

  my $self =
    {
     MinDec_s    => undef,
     RangeDec_s  => undef,
     isgtf       => -1,
     ihash       => undef,
     ihash_changed  => 0,
     ecfobj      => undef,
     errormsg    => $errormsg,
    };

  bless $self;
  return($self);
}

#####

sub _set_infos_ViperFile {
  my $dummy = new TrecVid08ViperFile();
  @ok_events = $dummy->get_full_events_list();
  return($dummy->get_errormsg());
}

#####

sub _set_infos_Observations {
  my $dummy = new TrecVid08Observation();
  $obs_dummy_key = $dummy->get_key_dummy_eventtype();
  @full_ok_events = @ok_events;
  push @full_ok_events, $obs_dummy_key;
  return($dummy->get_errormsg());
}

#####

sub _set_infos {
  my $txt = "";

  # the viperfile one need to be run first to get ok_events
  $txt .= &_set_infos_ViperFile();
  # now we can set full_ok_events
  $txt .= &_set_infos_Observations();

  return($txt);
}

##########

sub get_version {
  my ($self) = @_;

  return($versionid);
}

########## 'changed'

sub _set_ihash_changed_core {
  my ($self, $val) = @_;

  return(0) if ($self->error());

  $self->{ihash_changed} = $val;
  return(1);
}

#####

sub _has_ihash_changed {
  my ($self) = @_;

  return($self->{ihash_changed});
}

#####

sub _set_ihash_changed {
  my ($self) = @_;

  return($self->_set_ihash_changed_core(1));
}

#####

sub _set_ihash_unchanged {
  my ($self) = @_;

  return($self->_set_ihash_changed_core(0));
}

########## 'ihash'

sub _set_ihash {
  my ($self, %ihash) = @_;

  return(0) if ($self->error());

  $self->{ihash} = \%ihash;

  # Every single time we modify the hash, the number of entries has changed and we have to recalculate MinDec and RangeDec
  $self->_set_ihash_changed();
  return(0) if ($self->error());

  return(1);
}

#####

sub _is_ihash_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{ihash});

  return(0);
}

#####

sub _get_ihash {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_ihash_set()) {
    $self->_set_erromsg("\'ihash\' is not set");
    return(0);
  }

  my $rihash = $self->{ihash};

  my %res = %{$rihash};

  return(%res);
}

########## 'isgtf'

sub set_isgtf {
  my ($self, $status) = @_;

  return(0) if ($self->error());

  $self->{isgtf} = $status;
  return(1);
}

#####

sub _is_isgtf_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{isgtf} != -1);

  return(0);
}

#####

sub get_isgtf {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_isgtf_set()) {
    $self->_set_errormsg("\'isgtf\' not set");
    return(0);
  }

  return($self->{isgtf});
}

################################################## 'Observations' function

sub Observation_Added {
  my ($self) = @_;
  return($obs_added);
}

#####

sub Observation_SpecialAdd {
  my ($self) = @_;
  return($obs_SPadd);
}

#####

sub Observation_Rejected {
  my ($self) = @_;
  return($obs_rejected);
}

#####

sub _add_observation_core {
  my ($self, $obs, %ihash) = @_;

  my $filename = $obs->get_filename();
  my $eventtype = $obs->get_eventtype();
  my $o_isgtf = $obs->get_isgtf();
  if ($obs->error()) {
    $self->_set_errormsg("Problem obtaining Observation's \'filename\', \'eventtype\' or \'isgtf\' information (" . $obs->get_errormsg() . ")");
    return(0);
  }

  if (! grep(m%^$eventtype$%, @full_ok_events) ) {
    $self->_set_errormsg("Can not add Observation to EventList, it has an invalid eventtype ($eventtype)");
    return(0);
  }

  my $s_isgtf = $self->get_isgtf();
  return(0) if ($self->error());

  if ($s_isgtf != $o_isgtf) {
    $self->_set_errormsg("Can not add an Observation to the EventList if their GTF status is different");
    return(0);
  }

  # Check according to the ECF (if any) [and bypass for the dummy event]
  if (($eventtype ne $obs_dummy_key) && ($self->is_ECF_set())) {
    if (! $self->is_filename_in_ECF($filename)) {
      return(0) if ($self->error());
      return($obs_rejected);
    }
    if (! $self->_is_obs_fs_within_ECF_fs($obs)) {
      return(0) if ($self->error());
      return($obs_rejected);
    }
  }

  push @{$ihash{$filename}{$eventtype}}, $obs;
  $self->_set_ihash(%ihash);
  return(0) if ($self->error());

  # Was added, select the return value
  my $res = ($eventtype eq $obs_dummy_key) ? $obs_SPadd : $obs_added;

  return($res);
}

#####

sub _add_first_observation {
  my ($self, $obs) = @_;

  my $isgtf = $obs->get_isgtf();
  if ($obs->error()) {
    $self->_set_errormsg("Problem obtaining Observation's \'isgtf\' information (" . $obs->get_errormsg() . ")");
    return(0);
  }

  $self->set_isgtf($isgtf);
  return(0) if ($self->error());

  my %ihash = (); # Empty hash
  return($self->_add_observation_core($obs, %ihash));
}

#####

sub _add_new_observation {
  my ($self, $obs) = @_;

  my %ihash = $self->_get_ihash();
  return(0) if ($self->error());

  return($self->_add_observation_core($obs, %ihash));
}

#####

sub add_Observation {
  my ($self, $obs) = @_;

  return(0) if ($self->error());

  if (! defined $obs) {
    $self->_set_errormsg("Can not add an undefined observation");
    return(0);
  }

  if ($obs->error()) {
    $self->_set_errormsg("Observation seems to have issue(s) (" . $obs->get_errormsg() . ")");
    return(0);
  }

  if (! $obs->is_validated()) {
    $self->_set_errormsg("Can not add a non validated Observation");
    return(0);
  }

  if (! $self->_is_ihash_set()) {
    return($self->_add_first_observation($obs));
  } else {
    return($self->_add_new_observation($obs));
  }
}

##########

sub get_filenames_list {
  my ($self) = @_;

  return() if ($self->error());

  return() if (! $self->_is_ihash_set());

  my %ihash = $self->_get_ihash();

  my @list = keys %ihash;

  return(@list);
}

#####

sub is_filename_in {
  my ($self, $filename) = @_;

  return(0) if ($self->error());

  my @list = $self->get_filenames_list();
  return(0) if ($self->error());

  return(1) if (grep(m%^$filename$%, @list));

  return(0);
}

##########

sub _get_events_list_core {
  my ($self, $filename) = @_;

  my $in = $self->is_filename_in($filename);
  return() if ($self->error());
  if (! $in) {
    $self->_set_errormsg("No such filename ($filename) in this EventList");
    return();
  }

  my %ihash = $self->_get_ihash();
  if (! exists $ihash{$filename}) {
    $self->_set_errormsg("WEIRD: key ($filename) is not in first level of \%ihash. ");
    return();
  }
  my %subset = %{$ihash{$filename}};

  my @list = keys %subset;

  return(@list);
}

#####

sub get_full_events_list {      # Include $obs_dummy_key if in it
  my ($self, $filename) = @_;

  return($self->_get_events_list_core($filename));
}

#####

sub get_events_list { # Remove $obs_dummy_key if it is in the list
  my ($self, $filename) = @_;

  my @in = $self->_get_events_list_core($filename);
  return() if ($self->error());

  my @out = grep(! m%^$obs_dummy_key$%, @in);

  return(@out);
}

#####

sub is_event_in {
  my ($self, $filename, $event) = @_;

  return(0) if ($self->error());

  if (! grep(m%^$event$%, @full_ok_events) ) {
    $self->_set_errormsg("Requested event ($event) is not a recognized event. ");
    return(0);
  }

  my @list = $self->get_full_events_list($filename);
  return(0) if ($self->error());

  return(1) if (grep(m%^$event$%, @list));

  return(0);
}

##########

sub get_Observations_list {
  my ($self, $filename, $event) = @_;

  my $in = $self->is_event_in($filename, $event);
  return() if ($self->error());
  return() if (! $in);

  my %ihash = $self->_get_ihash();
  if (! exists $ihash{$filename}{$event}) {
    $self->_set_errormsg("WEIRD: key ($filename / $event) is not in \%ihash. ");
    return();
  }

  my @list = @{$ihash{$filename}{$event}};

  return(@list);
}

#####

sub get_dummy_Observations_list {
  my ($self, $filename) = @_;

  return($self->get_Observations_list($filename, $obs_dummy_key));
}

#####

sub count_Observations {
  my ($self, $filename, $event) = @_;

  my @list = $self->get_Observation_list($filename, $event);
  return(0) if ($self->error());

  return(scalar @list);
}

#####

sub has_Observations {
  my ($self, $filename, $event) = @_;

  my $count = $self->count_Observations($filename, $event);

  my $res = ($count > 0) ? 1 : 0;

  return($res);
}

##########

sub get_all_Observations {
  my ($self, $filename, $incdummy) = @_;

  my @tmp = ();

  my @evl = ();
  if ($incdummy) {
    @evl = $self->get_full_events_list($filename);
  } else {
    @evl = $self->get_events_list($filename);
  }
  return(@tmp) if ($self->error());

  my @out = ();
  foreach my $ev (@evl) {
    my @o = $self->get_Observations_list($filename, $ev);
    return(@tmp) if ($self->error());
    push @out, @o;
  }

  return(@out);
}

##########

sub get_1st_dummy_observation {
  my ($self, $filename) = @_;

  return(undef) if (! $self->is_filename_in($filename));

  return(undef) if (! $self->is_event_in($filename, $obs_dummy_key));

  my @o = $self->get_Observations_list($filename, $obs_dummy_key);

  return(undef) if (scalar @o == 0);

  return($o[0]);
}

############################################################

sub comparable_filenames {
  my ($self, $other) = @_;

  return(0) if ($self->error());

  if ($other->error()) {
    $self->_set_errormsg("Comparable EventList problem (" . $other->get_errormsg() . ")");
    return(0);
  }

  # Get the file list
  my @sl = $self->get_filenames_list();
  return(0) if ($self->error());

  my @ol = $other->get_filenames_list();
  if ($other->error()) {
    $self->_set_errormsg("Comparable EventList problem (" . $other->get_errormsg() . ")");
    return(0);
  }

  # Convert the list to hash for easy comparison
  my %hsl = ();
  foreach my $f (@sl) {
    $hsl{$f}++;
  }
  my %hol = ();
  foreach my $f (@ol) {
    $hol{$f}++;
  }

  # Compare
  my @common = ();
  my @only_in_sl = ();
  my @only_in_ol = ();
  foreach my $key (keys %hsl) {
    if (exists $hol{$key}) {
      push @common, $key;
      delete $hsl{$key};
      delete $hol{$key};
    } else {
      push @only_in_sl, $key;
      delete $hsl{$key};
    }
  }
  push @only_in_ol, keys %hol;

  return(\@common, \@only_in_sl, \@only_in_ol);
}

############################################################

sub _is_MinDec_s_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{MinDec_s});

  return(0);
}

#####

sub get_MinDec_s {
  my ($self) = @_;

  return(-1) if ($self->error());

  return($self->_compute_Min_Range_Dec_s("MinDec_s"));
}

########## 

sub _is_RangeDec_s_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{RangeDec_s});

  return(0);
}

#####

sub get_RangeDec_s {
  my ($self) = @_;

  return(-1) if ($self->error());

  return($self->_compute_Min_Range_Dec_s("RangeDec_s"));
}

##########

sub _get_Min_Range_Dec_s_value {
  my ($self, $key) = @_;

  return($self->{$key});
}

#####

sub _compute_Min_Range_Dec_s {
  my ($self, $key) = @_;

  return(0) if ($self->error());

  my $MD_isset = $self->_is_MinDec_s_set();
  my $RD_isset = $self->_is_RangeDec_s_set();
  my $hchanged = $self->_has_ihash_changed();
  return(0) if ($self->error());

  # We do not need to compute it if (it is already set) && (ihash has not changed since last time we called this function)
  return($self->_get_Min_Range_Dec_s_value($key)) if (($MD_isset) && ($RD_isset) && (! $hchanged));

  my ($min, $max) = $self->_get_global_DetectionScore_minMax();
  return(0) if ($self->error());

  my $MinDec_s = $min;          # ok to be negative
  my $RangeDec_s = $max - $min;

  $self->_set_ihash_unchanged();
  return(0) if ($self->error());

  $self->{MinDec_s} = $MinDec_s;
  $self->{RangeDec_s} = $RangeDec_s;

  return($self->_get_Min_Range_Dec_s_value($key));
}

#####

sub _get_global_DetectionScore_minMax {
  my ($self) = @_;

  my @all_ds = ();

  my @filelist = $self->get_filenames_list();
  return() if ($self->error());

  foreach my $file (@filelist) {
    my @eventlist = $self->get_events_list($file);
    return() if ($self->error());

    foreach my $event (@eventlist) {
      my @obs_list = $self->get_Observations_list($file, $event);
      return() if ($self->error());

      foreach my $obs (@obs_list) {
        my $ds = $obs->Dec();
        if ($obs->error()) {
          $self->_set_errormsg("Problem obtaining the \'Dec\' value for an Observation (" . $obs->get_errormsg() . ")");
          return();
        }
        push @all_ds, $ds;
      }
    }
  }

  return() if ($self->error());

  return(MMisc::min_max_r(\@all_ds));
}

####################

sub _display_all {
  my ($self) = shift @_;

  return(-1) if ($self->error());

  return(MMisc::get_sorted_MemDump(\$self));
}

########################################

# ECF

sub is_ECF_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (defined $self->{ecfobj});

  return(0);
}

#####

sub _get_ECF_handler {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_ECF_set()) {
    $self->_set_errormsg("EventList not tied to any ECF Handler");
    return(0);
  }

  return($self->{ecfobj});
}

#####

sub tie_to_ECF {
  my ($self, $ecfobj) = @_;

  return(0) if ($self->error());

  if ($self->is_ECF_set()) {
    $self->_set_errormsg("EventList already tied to one ECF");
    return(0);
  }

  if ($self->_is_ihash_set()) {
    $self->_set_errormsg("Can not \'tie_to_ECF\' if the EventList already contains any Observation");
    return(0);
  }

  if (! $ecfobj->is_validated()) {
    $self->_set_errormsg("Can not add an non validated ECF");
    return(0);
  }

  $self->{ecfobj} = $ecfobj;

  return(1);
}

#####

sub is_filename_in_ECF {
  my ($self, $fn) = @_;

  return(0) if ($self->error());

  my $ecfobj = $self->_get_ECF_handler();
  return(0) if ($self->error());

  my $ifi = $ecfobj->is_filename_in($fn);
  if ($ecfobj->error()) {
    $self->_set_errormsg("Problem while checking if the filename was within the ECF (" . $ecfobj->get_errormsg() . ")");
    return(0);
  }

  return($ifi);
}

#####

sub get_ECF_file_ViperFramespans {
  my ($self, $fn) = @_;

  return(0) if ($self->error());

  my $ecfobj = $self->_get_ECF_handler();
  return(0) if ($self->error());

  my @fs_ecfs = $ecfobj->get_file_ViperFramespans($fn);
  if ($ecfobj->error()) {
    $self->_set_errormsg("Problem obtaining the ECF's framespans (" . $ecfobj->get_errormsg() . ")");
    return(0);
  }
  
  return(@fs_ecfs);
}

#####

sub _is_obs_fs_within_ECF_fs {
  my ($self, $obs) = @_;

  return(0) if ($self->error());

  my $filename = $obs->get_filename();
  my $fs_obs = $obs->get_framespan();
  if ($obs->error()) {
    $self->_set_errormsg("Problem obtaining Observation's \'filename\' or \'framespan\' information (" . $obs->get_errormsg() . ")");
    return(0);
  }

  my @fs_ecfs = $self->get_ECF_file_ViperFramespans($filename);
  return(0) if ($self->error());

  # We get the observation's middlepoint in order to check
  # that it is within the ECF's framespan in order to
  # accept or reject it (and we work in seconds)
  my $mp = $fs_obs->extent_middlepoint_ts();
  if ($fs_obs->error()) {
    $self->_set_errormsg("Problem obtaining the Observation's Framespan's ts middlepoint (" . $fs_obs->get_errormsg() .")");
    return(0);
  }

  foreach my $fs_fs (@fs_ecfs) {
    my ($bts, $ets) = $fs_fs->get_beg_end_ts();
    if ($fs_fs->error()) {
      $self->_set_errormsg("Problem obtaining the ECF's framespan beg and end ts (" . $fs_fs->get_errormsg() .")");
      return(0);
    }
    #    print "[ $bts : $ets ] ";
    if (($mp >= $bts) && ($mp <= $ets)) { # No need to continue, simply return true if is_within
      #      print " **\n";
      return(1);
    }
  }
  #  print "\n";

  # Could never find it within ...
  return(0);
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

sub clear_error {
  my ($self) = @_;
  return($self->{errormsg}->clear());
}

############################################################

1;
