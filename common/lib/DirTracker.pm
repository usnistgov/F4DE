package DirTracker;

# Dir Tracker
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "DirTracker.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

# $Id$

use strict;

use MErrorH;
use MMisc;

use File::Monitor;
use File::Monitor::Object;

my $version     = '0.1b';

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "DirTracker.pm Version: $version";

##########
# new(DirToTrack)
## The prupose of this package is to be made aware of TRUE new files added any level of a directory
# By TRUE, we mean files that when performing a 'scan' have a different SHA256digest than a file already processed previously,
# so that if a file A exist and is copied to B into a different directory, B is not listed as a new file
# Limitation: does not handle actual file changes, only addition and deletion
## the 'added' 'deleted' or 'files' functions do care if duplicates and will tell all instances
## warning: data is only valid from the most recent 'scan' function
sub new {

  my ($class, $dir) = @_;

  my $errorh = new MErrorH('DirTracker');
  $errorh->set_errormsg("Can not be instanciated without a directory") 
    if (MMisc::is_blank($dir));
  my ($err, $v) = MMisc::__find_pre($dir);
  $errorh->set_errormsg("Problem with directory ($dir): $err")
    if (! MMisc::is_blank($err));
  my $errorv = $errorh->error();
  
  my $self =
    {
     dir       => $v,
     initdone  => 0, ## set post init
     monitor   => undef,
     files     => undef,
     files2sha => undef, ## {file} = "sha"
     sha2files => undef, ## {sha}{file}
     # added & deleted: valid only until next 'scan'
     added     => undef,
     deleted   => undef,
     # file monitor
     files_monitor => undef,
     fm_changes  => undef, # {filename}{change_type} = (old_value, new_value)
     # error handler
     errorh    => $errorh,
     errorv    => $errorv,      # Cache information
    };
 
  bless $self;
  return($self);
}

##########
# init(FollowFiles)
## must be called to initialize the directory listing, and before any other function can be called
# FollowFiles = 0 (no) or 1 (yes) (default is 0)
sub init {
  my $self = shift @_;
  my $follow = MMisc::iuv(\@_, 0);

  return($self->_set_error_and_return("Init was already run once, can not run it again", 0))
    if ($self->{initdone} != 0);

  my $dir = $self->{dir};

  my $monitor = File::Monitor->new();
  # Recursively get the files in the directory
  $monitor->watch
    ( {
     name        => $dir,
     recurse     => 1
    } );
  # First scan just finds out about the monitored files.
  # No changes will be reported.
  $monitor->scan;
  $self->{monitor} = $monitor;

  # Follow files ?
  if ($follow) {
    $self->{files_monitor} = File::Monitor->new();
  }

  # Now that the watch is set, we obtain the entire files list and obtain its SHA256
  my ($err, @contained_files) = MMisc::find_all_files($dir);
  return($self->_set_error_and_return("Problem finding file list for dir ($dir): $err", 0))
    if (! MMisc::is_blank($err));
  my $now = MMisc::get_scalar_currenttime();
  foreach my $file (@contained_files) {
    $self->{files_monitor}->watch($file) if (defined $self->{files_monitor}); # add each file if followed
    my ($err, $sha256) = MMisc::file_sha256digest($file);
    return($self->_set_error_and_return("Problem obtaining SHA256 digest from file ($file): $err", 0))
      if (! MMisc::is_blank($err));
    $self->{files}{$file} = $now;
    $self->{files2sha}{$file} = $sha256;
    $self->{sha2files}{$sha256}{$file}++;
  }
  
  # initialize the scan for followed files
  $self->{files_monitor}->scan if (defined $self->{files_monitor});
  
  $self->{initdone} = 1;
  return(1);
}

#####
# scan()
## return the list of new (never present previously) files added since last scan
# (rely on SHA256digest to process file copies)
sub scan {
  my ($self) = @_;

  return($self->_set_error_and_return("Init was never run", ))
    if ($self->{initdone} == 0);

  my @out = ();
  my @changes = $self->{monitor}->scan;

  foreach my $change (@changes) {

    my $now = MMisc::get_scalar_currenttime();

    foreach my $file ($change->files_created) { # process added files
      my ($err, $sha256) = MMisc::file_sha256digest($file);
      return($self->_set_error_and_return("Problem obtaining SHA256 digest from file ($file): $err", ))
        if (! MMisc::is_blank($err));
      $self->{files}{$file} = $now;
      $self->{files2sha}{$file} = $sha256;
      if (! exists $self->{sha2files}{$sha256}) { # a "true" new file
        push @out, $file;
      }
      $self->{sha2files}{$sha256}{$file}++;
      # maintain added versus deleted list
      $self->{added}{$file} = $now;
      delete $self->{deleted}{$file};
      $self->{files_monitor}->watch($file) if (defined $self->{files_monitor}); # add each new file if followed
    }

    foreach my $file ($change->files_deleted) { # process deleted files
      return($self->_set_error_and_return("No SHA256 digest for file ($file) present", ))
        if (! exists $self->{files2sha}{$file});
      my $sha256 = $self->{files2sha}{$file};
      delete $self->{file2sha}{$file};
      delete $self->{sha2files}{$sha256}{$file};
      delete $self->{sha2files}{$sha256} if (scalar(keys %{$self->{sha2files}{$sha256}} == 0)); # prune if empty
      # maintain added versus deleted list
      $self->{deleted}{$file} = $now;
      delete $self->{added}{$file};
      delete $self->{files}{$file};
    }
    
  }

  $_[0]->__files_scan();

  return(@out);
}

#####
# sha256digest(FileName)
## return the SHA 256 digest of given file or undef in case of problem
sub sha256digest {
  my ($self, $file) = @_;

  return($self->_set_error_and_return("Init was never run", ))
    if ($self->{initdone} == 0);

  return($self->_set_error_and_return("Do not have an SHA256 digest for file ($file)", undef))
    if (! exists $self->{files2sha}{$file});
  
  return($self->{files2sha}{$file});
}

#####
sub __get_adf {
  my ($self, $mode) = @_;

  return($self->_set_error_and_return("Init was never run", ))
    if ($self->{initdone} == 0);

  my @out = ();
  return(@out) if (! defined $self->{$mode});
  foreach my $file (sort {$self->{$mode}{$a} <=> $self->{$mode}{$b}} keys %{$self->{$mode}}) {
    push @out, $file;
  }

 return(@out);
}

#####
# added()
# deleted() 
# files()
## return list of all (added/deleted/) files (in order of 'scan')
sub added   { $_[0]->__get_adf('added'); }
sub deleted { $_[0]->__get_adf('deleted'); }
sub files   { $_[0]->__get_adf('files'); }

#####
# sub humanreadable_scan()
## return a string with the following information (one file per line)
# [*] new TRUE files
# [+] all added files
# [-] all deleted files
sub humanreadable_scan {
  my @scan = $_[0]->scan();
  my $txt 
    = "[*] " . join("\n[*] ", @scan) 
      . "\n[+] " . join("\n[+] ", $_[0]->added()) 
      . "\n[-] " . join("\n[-] ", $_[0]->deleted())
      . "\n";

  if (defined $_[0]->{fm_changes}) { # file monitor active
    foreach my $file (keys %{$_[0]->{fm_changes}}) {
      foreach my $mode (keys %{$_[0]->{fm_changes}{$file}}) {
        my ($old, $new) = @{$_[0]->{fm_changes}{$file}{$mode}};
        $txt .= "[@] $file (\'$mode\' change from \'$old\' to \'$new\')\n";
      }
    }
  }
  
  return($txt);
}

##########
sub __files_scan {
  return() if (! defined $_[0]->{files_monitor});
  
  # per file modification tracking
  my @changes = $_[0]->{files_monitor}->scan;

  # reset list of changes since last time
  $_[0]->{fm_changes} = undef;
  foreach my $change (@changes) {
    if ($change->is_mtime) { @{$_[0]->{fm_changes}{$change->name}{'mtime'}} = ($change->old_mtime, $change->new_mtime); }
    if ($change->is_ctime) { @{$_[0]->{fm_changes}{$change->name}{'ctime'}} = ($change->old_ctime, $change->new_ctime); }
    if ($change->is_uid)   { @{$_[0]->{fm_changes}{$change->name}{'uid'}} = ($change->old_uid, $change->new_uid); }
    if ($change->is_gid)   { @{$_[0]->{fm_changes}{$change->name}{'gid'}} = ($change->old_gid, $change->new_gid); }
    if ($change->is_mode)  { @{$_[0]->{fm_changes}{$change->name}{'mode'}} = ($change->old_mode, $change->new_mode); }
    if ($change->is_size)  { @{$_[0]->{fm_changes}{$change->name}{'size'}} = ($change->old_size, $change->new_size); }
  }
}


############################################################

sub _set_errormsg {
  $_[0]->{errorh}->set_errormsg($_[1]);
  $_[0]->{errorv} = $_[0]->{errorh}->error();
}

##########

sub get_errormsg { return($_[0]->{errorh}->errormsg()); }

##########

sub error { return($_[0]->{errorv}); }

##########

sub clear_error {
  $_[0]->{errorv} = 0;
  return($_[0]->{errorh}->clear());
}

##########

sub _set_error_and_return {
  my $self = shift @_;
  my $errormsg = shift @_;

  $self->_set_errormsg($errormsg);

  return(@_);
}

############################################################

1;
