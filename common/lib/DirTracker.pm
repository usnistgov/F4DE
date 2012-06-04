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
     init_scandate => undef, # a modified file is a file whose scandate differs from the 'init' scan date
     last_scandate => undef, # date of the last scan
     monitor   => undef,
     files     => undef, # {file} = scandate
     files2sha => undef, ## {file} = sha
     sha2files => undef, ## {sha}{file}
     # added & deleted: valid only until next 'scan'
     added     => undef, # {file} = scandate
     deleted   => undef, # {file} = scandate
     # file monitor
     files_monitor => undef,
     fm_changes  => undef, # {filename}{change_type} = (old_value, new_value)
     # error handler
     errorh    => $errorh,
     errorv    => $errorv,      # Cache information
     # fake SHA counter
     fakeshac  => 0,
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
    if (defined $self->{init_scandate});

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
    my $sha256 = $self->__file_sha256digest($file);
    $self->{files}{$file} = $now;
    $self->{files2sha}{$file} = $sha256;
    $self->{sha2files}{$sha256}{$file}++;
  }
  
  # initialize the scan for followed files
  $self->{files_monitor}->scan if (defined $self->{files_monitor});
  
  $self->{init_scandate} = $now;
  return(1);
}

#####
# scan()
## return the list of new (never present previously) files added since last scan
# (rely on SHA256digest to process file copies)
sub scan {
  return($_[0]->_set_error_and_return("Init was never run", ))
    if (! defined $_[0]->{init_scandate});

  my @out = ();
  my @changes = $_[0]->{monitor}->scan;

  my @fm_changes = undef;
  if (defined $_[0]->{files_monitor}) {
    for (my $i = 0; $i < scalar @changes; $i++) {
      foreach my $file ($changes[$i]->files_created) { # quick add of new files before scan
        $_[0]->{files_monitor}->watch($file);
      }
      foreach my $file ($changes[$i]->files_deleted) { # removal too
        $_[0]->{files_monitor}->unwatch($file);
      }
    }
    @fm_changes = $_[0]->{files_monitor}->scan;
  }

  my $now = MMisc::get_scalar_currenttime();
 for (my $i = 0; $i < scalar @changes; $i++) {

    foreach my $file ($changes[$i]->files_created) { # process added files
      my $sha256 = $_[0]->__file_sha256digest($file);
      $_[0]->{files}{$file} = $now;
      $_[0]->{files2sha}{$file} = $sha256;
      if (! exists $_[0]->{sha2files}{$sha256}) { # a "true" new file
        push @out, $file;
      }
      $_[0]->{sha2files}{$sha256}{$file}++;
      # maintain added versus deleted list
      $_[0]->{added}{$file} = $now;
      delete $_[0]->{deleted}{$file};
    }

    foreach my $file ($changes[$i]->files_deleted) { # process deleted files
      return($_[0]->_set_error_and_return("No SHA256 digest for file ($file) present", ))
        if (! exists $_[0]->{files2sha}{$file});
      my $sha256 = $_[0]->{files2sha}{$file};
      delete $_[0]->{file2sha}{$file};
      delete $_[0]->{sha2files}{$sha256}{$file};
      delete $_[0]->{sha2files}{$sha256} if (scalar(keys %{$_[0]->{sha2files}{$sha256}} == 0)); # prune if empty
      # maintain added versus deleted list
      $_[0]->{deleted}{$file} = $now;
      delete $_[0]->{added}{$file};
      delete $_[0]->{files}{$file};
    }
    
  }

  my @tout = $_[0]->__files_scan($now, @fm_changes);
  push @out, @tout if (scalar @tout > 0);
  $_[0]->{last_scandate} = $now;

  return(@out);
}

#####
# sha256digest(FileName)
## return the SHA 256 digest of given file or undef in case of problem
sub sha256digest {
  return($_[0]->_set_error_and_return("Init was never run", undef))
    if (! defined $_[0]->{init_scandate});

  return($_[0]->_set_error_and_return("Do not have an SHA256 digest for file (" . $_[1] . ")", undef))
    if (! exists $_[0]->{files2sha}{$_[1]});
  
  return($_[0]->{files2sha}{$_[1]});
}

#####
sub __get_adf {
  # 0: self
  # 1: self entry (ex: 'added')
  # 2: scandate: keep entries added since scandate value (undef for all)
  return($_[0]->_set_error_and_return("Init was never run", ))
    if (! defined $_[0]->{init_scandate});

  my @out = ();
  return(@out) if (! defined $_[0]->{$_[1]});
  foreach my $file (sort {$_[0]->{$_[1]}{$a} <=> $_[0]->{$_[1]}{$b}} keys %{$_[0]->{$_[1]}}) {
    next if ((defined $_[2]) && ($_[0]->{$_[1]}{$file} < $_[2]));
    push @out, $file;
  }

 return(@out);
}

#####
# added()
# deleted() 
# modified()
# files()
## return list of all (added/deleted/modified/) files (in order of 'scan')
sub added    { $_[0]->__get_adf('added'); }
sub deleted  { $_[0]->__get_adf('deleted'); }
sub files    { $_[0]->__get_adf('files'); }
sub modified { $_[0]->__get_modified(); }

#####
# just_added()
# just_deleted() 
# just_modified()
# just_files()
## return list of all (added/deleted/modified/) files that were XXX in the last scan
sub just_added    { $_[0]->__get_adf('added', $_[0]->{last_scandate}); }
sub just_deleted  { $_[0]->__get_adf('deleted', $_[0]->{last_scandate}); }
sub just_files    { $_[0]->__get_adf('files', $_[0]->{last_scandate}); }
sub just_modified { $_[0]->__get_modified($_[0]->{last_scandate}); }

#####
# added_since(scandate)
# added_deleted(scandate) 
# added_modified(scandate)
# added_files(scandate)
## return list of all (added/deleted/modified/) files that were XXX since the asked scandate (in order of 'scan') 
sub added_since    { $_[0]->__get_adf('added', $_[1]); }
sub deleted_since  { $_[0]->__get_adf('deleted', $_[1]); }
sub files_since    { $_[0]->__get_adf('files', $_[1]); }
sub modified_since { $_[0]->__get_modified($_[1]); }

#####
sub __get_modified {
  return($_[0]->_set_error_and_return("Init was never run", ))
    if (! defined $_[0]->{init_scandate});

  my @out = ();
  return(@out) if (! defined $_[0]->{files});
  my %tmp = ();
  foreach my $file (keys %{$_[0]->{files}}) {
    next if ($_[0]->{files}{$file} == $_[0]->{init_scandate});
    next if ((defined $_[1]) && ($_[0]->{files}{$file} < $_[1]));
    $tmp{$file} = $_[0]->{files}{$file};
  }

  foreach my $file (sort {$tmp{$a} <=> $tmp{$b}} keys %tmp) {
    push @out, $file;
  }

 return(@out);
}

#####
# sub humanreadable_scan(showSHA256)
## return a string with the human readable / computer parsable information on changes since last scan
sub humanreadable_scan {
  my @scan = $_[0]->scan();
 
  my $txt = "";
  $txt .= $_[0]->__phre("trueNew", $_[1], @scan);
  $txt .= $_[0]->__phre("added", $_[1], $_[0]->added());
  $txt .= $_[0]->__phre("deleted", $_[1], $_[0]->deleted());
  $txt .= $_[0]->__phre("modified", $_[1], $_[0]->modified());

  if (defined $_[0]->{fm_changes}) { # file monitor active
    foreach my $file (keys %{$_[0]->{fm_changes}}) {
      foreach my $mode (keys %{$_[0]->{fm_changes}{$file}}) {
        my ($old, $new) = @{$_[0]->{fm_changes}{$file}{$mode}};
        $txt .= "[$mode] $file (was:$old) (now:$new)\n";
      }
    }
  }
  
  return($txt);
}

sub __phre {
  my ($self, $h, $s) = MMisc::shiftX(3, \@_);

  return("") if (scalar @_ == 0);
  my $ret = "";
  for (my $i = 0; $i < scalar @_; $i++) {
    $ret .= "[$h] " . $_[$i];
    $ret .= ($s) ? " [SHA256=" . $self->sha256digest($_[$i]) . "]" : "";
    $ret .= "\n";
  }

  return($ret);
}

##########
# __files_scan($now, @changes)
sub __files_scan {
  return() if (! defined $_[0]->{files_monitor});

  my @out = ();

  # reset list of changes since last time
  $_[0]->{fm_changes} = undef;
  for (my $i = 2; $i < scalar @_; $i++) {
    next if (exists $_[0]->{deleted}{$_[$i]->name});
    if ($_[$i]->is_mtime) { @{$_[0]->{fm_changes}{$_[$i]->name}{'mtime'}} = ($_[$i]->old_mtime, $_[$i]->new_mtime); }
    if ($_[$i]->is_ctime) { @{$_[0]->{fm_changes}{$_[$i]->name}{'ctime'}} = ($_[$i]->old_ctime, $_[$i]->new_ctime); }
    if ($_[$i]->is_uid)   { @{$_[0]->{fm_changes}{$_[$i]->name}{'uid'}}   = ($_[$i]->old_uid,   $_[$i]->new_uid);   }
    if ($_[$i]->is_gid)   { @{$_[0]->{fm_changes}{$_[$i]->name}{'gid'}}   = ($_[$i]->old_gid,   $_[$i]->new_gid);   }
    if ($_[$i]->is_mode)  { @{$_[0]->{fm_changes}{$_[$i]->name}{'mode'}}  = (MMisc::mode2perms($_[$i]->old_mode),  MMisc::mode2perms($_[$i]->new_mode));  }
    if ($_[$i]->is_size)  { @{$_[0]->{fm_changes}{$_[$i]->name}{'size'}}  = ($_[$i]->old_size,  $_[$i]->new_size);  }
    
    # if mtime, ctime or size has changed, chances are the sha256 has too, so 
    if (($_[$i]->is_mtime) || ($_[$i]->is_ctime) || ($_[$i]->is_size)) {
      $_[0]->{files}{$_[$i]->name} = $_[1]; # file was modified
      my $osha = $_[0]->{files2sha}{$_[$i]->name};
      my $sha256 = $_[0]->__file_sha256digest($_[$i]->name);
      if ($sha256 ne $osha) { # file's SHA256 was modified
        $_[0]->{files2sha}{$_[$i]->name} = $sha256; # modify file's SHA entry
        delete $_[0]->{sha2files}{$osha}{$_[$i]->name}; # delete old sha to file entry
        # if there was no entry for this new SHA256, we have a true new candidate
        push @out, $_[$i]->name if (! exists $_[0]->{sha2files}{$sha256});
        $_[0]->{sha2files}{$sha256}{$_[$i]->name}++; # create a new one
      }
    }
  }

  return(@out);
}

##########
# (self, filename)
sub __file_sha256digest {
  my ($err, $sha256) = MMisc::file_sha256digest($_[1]);
  if (! MMisc::is_blank($err)) {
    MMisc::warn_print("Problem obtaining SHA256 digest for entity ($err) , will return unique non sha value");
    return(sprintf("XXX_Not_an_SHA_value_ZZZ:%06d", ++$_[0]->{fakeshac}));
  }
  
  return($sha256);
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
