package DispatcherHelper;

# DispatcherHelper
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "DispatcherHelper.pm" is an experimental system.
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

use DirTracker;

my $version     = '0.1b';

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "DispatcherHelper.pm Version: $version";

############################################################
## new()

sub new {
  my ($class) = @_;

  my $errorh = new MErrorH('DispatcherHelper');
  my $errorv = $errorh->error();

  my $self = 
    {
     # Configuration
     id           => undef, # input dir 
     tosleep      => 60, # scan interval (default is 60 seconds)
     cmd          => undef, # command to run
     salttool     => "",    # SHA256 salt tool 
     ignore       => undef, # array of files to ignore
     verb         => 0,  # verbosity level

     # Internals
     dt           => undef, # DirTracker instance
     tocheck      => undef, 
     tochecksoon  => undef,
     sepoch       => 0, # Start Epoch
     lepoch       => 0, # Last Scan Epoch
     doit         => 1, # Iteration number

     # Ready
     ready        => 0,

     # error handler
     errorh    => $errorh,
     errorv    => $errorv,
    };

  bless $self;
  return($self);
}


##########
## 'id'

sub set_dir {
  my $err = MMisc::check_dir_r($_[1]);
  $_[0]->_set_error_and_return("Problem with directory (" . $_[1] . "): $err", 0)
    if (! MMisc::is_blank($err));
  $_[0]->_set_error_and_return("Can not change value once initialization is complete", 0)
    if ($_[0]->{ready} == 1);
  $_[0]->{id} = $_[1];
}

##

sub get_dir {
  $_[0]->_set_error_and_return("value not set", 0)
    if (! defined($_[0]->{id}));
  return($_[0]->{id});
}


##########
## 'cmd'

sub set_command {
  my $err = MMisc::check_file_x($_[1]);
  $_[0]->_set_error_and_return("Problem with executable (" . $_[1] . "): $err", 0)
    if (! MMisc::is_blank($err));
  $_[0]->{cmd} = $_[1];
}

##

sub get_command {
  $_[0]->_set_error_and_return("value not set", undef)
    if (! defined($_[0]->{cmd}));
  return($_[0]->{cmd});
}


##########
## 'tosleep'
my $tsmin = 10;

sub set_scaninterval {
  $_[0]->_set_error_and_return("value under minimum value of ${tsmin}s", 0)
    if ($_[1] < $tsmin);
  $_[0]->{tosleep} = $tsmin;
  return(1);
}

##

sub get_scaninterval {
  return($_[0]->{tosleep});
}


##########
## 'salttool'

sub set_salttool {
  my $err = MMisc::check_file_x($_[1]);
  $_[0]->_set_error_and_return("Problem with executable (" . $_[1] . "): $err", 0)
    if (! MMisc::is_blank($err));
  $_[0]->_set_error_and_return("Can not change value once initialization is complete", 0)
    if ($_[0]->{ready} == 1);
  $_[0]->{salttool} = $_[1];
}

##

sub get_salttool {
  return($_[0]->{salttool});
}

##########
## 'verb'

sub set_verbosity_level {
  $_[0]->{verb} = ($_[1] < 1) ? 0 : ($_[1] > 2) ? 2 : $_[1];
  return(1);
}

sub get_verbosity_level {
  return($_[0]->{verb});
}


##########
## 'ignore'

sub addto_ignore {
  $_[0]->_set_error_and_return("can not use an empty value", 0)
    if (MMisc::is_blank($_[1]));
  push @{$_[0]->{ignore}}, $_[1];
  return(1);
}

sub getlist_ignore {
  return($_[0]->{ignore});
}


##############################
## init()

sub init {
  $_[0]->_set_error_and_return("\'init\' already done, will not restart it", 0)
    if ($_[0]->{ready} == 1);

  $_[0]->_set_error_and_return("\'dir\' value not set, can not initialize", 0)
    if (! defined($_[0]->{id}));
  $_[0]->_set_error_and_return("\'command\' value not set, can not initialize", 0)
    if (! defined($_[0]->{cmd}));
  $_[0]->_set_error_and_return("\'scaninterval\' value not set, can not initialize", 0)
    if (! defined($_[0]->{tosleep}));

  my $dt = new DirTracker($_[0]->{id}, $_[0]->{salttool});
  $_[0]->_set_error_and_return("Problem with DirTracker: " . $dt->get_errormsg(), 0)
    if ($dt->error());
  $_[0]->{dt} = $dt;

  $_[0]->{sepoch} = MMisc::get_currenttime();
  MMisc::vprint(($_[0]->{verb} > 0), "!! Performing initial scan of (" . $_[0]->{id} . ")\n");

  $_[0]->{dt}->init(1);
  $_[0]->_set_error_and_return("Problem with DirTracker initialization: " . $_[0]->{dt}->get_errormsg(), 0)
    if ($_[0]->{dt}->error());
  
  $_[0]->{ready} = 1;
  return(1);
}


##############################
## loop()

sub loop {
  $_[0]->_set_error_and_return("\'init\' not done, can not loop", 0)
    if ($_[0]->{ready} == 0);
  
  while ($_[0]->{doit}) {
    $_[0]->single_iteration();
    return(0) if ($_[0]->error());
  }
}

##############################
# single_iteration()

sub single_iteration {
  $_[0]->_set_error_and_return("\'init\' not done, can not run iteration", 0)
    if ($_[0]->{ready} == 0);

  MMisc::vprint(($_[0]->{verb} > 0), "  (sleeping " . $_[0]->{tosleep} . "s)\n");
  sleep($_[0]->{tosleep});
  MMisc::vprint(($_[0]->{verb} > 0), "[" . sprintf("%.02f", MMisc::get_elapsedtime($_[0]->{sepoch})) . "] Iteration: " . $_[0]->{doit} . "\n");
  
  my @newfiles = $_[0]->{dt}->scan();
  $_[0]->_set_error_and_return("Problem with DirTracker scan: " . $_[0]->{dt}->get_errormsg(), 0) if ($_[0]->{dt}->error());
  MMisc::vprint(($_[0]->{verb} > 0), "!! Performing updated scan of (" . $_[0]->{id} . ")\n");
  $_[0]->{lepoch} = MMisc::get_currenttime();

  if ($_[0]->{verb} > 1) {
    foreach my $file ($_[0]->{dt}->just_added()) { MMisc::vprint(($_[0]->{verb} > 1), " (justAdded) $file\n"); }
    foreach my $file ($_[0]->{dt}->just_deleted()) { MMisc::vprint(($_[0]->{verb} > 1), " (justDeleted) $file\n"); }
    foreach my $file ($_[0]->{dt}->just_modified()) { MMisc::vprint(($_[0]->{verb} > 1), " (justModified) $file\n"); }
  }
  
  foreach my $file (@newfiles) {
    MMisc::vprint(($_[0]->{verb} > 0), "++ new file candidate: $file\n");
    my $err = MMisc::check_file_r($file);
    if (! MMisc::is_blank($err)) {
      MMisc::warn_print("Can not use file ($file): $err");
      next;
    }
    
    my $sha256 = $_[0]->{dt}->sha256digest($file);
    if ($_[0]->{dt}->error()) {
      MMisc::warn_print("Problem obtaining new file's SHA256 ($file), skipping");
      $_[0]->{dt}->clear_error();
      next;
    }
    
    MMisc::vprint(($_[0]->{verb} > 1), "%% SHA256: $sha256\n");
    ${$_[0]->{tochecksoon}}{$file} = $sha256;
  }
  
  foreach my $file (keys %{$_[0]->{tocheck}}) {
    # check if file changed since last check
    MMisc::vprint(($_[0]->{verb} > 0), "== confirming file ($file) has not changed since last scan\n"); 
    my $sha256 = $_[0]->{dt}->sha256digest($file);
    if ($_[0]->{dt}->error()) {
      MMisc::warn_print("Problem obtaining old file's SHA256 ($file), skipping");
      $_[0]->{dt}->clear_error();
      delete ${$_[0]->{tocheck}}{$file};
      next;
    }
    
    if ($sha256 ne ${$_[0]->{tocheck}}{$file}) {
      MMisc::warn_print("File ($file) not finished copying/downloading, will check again next iteration");
      MMisc::vprint(($_[0]->{verb} > 1), "%% newSHA256: $sha256\n");
      MMisc::vprint(($_[0]->{verb} > 1), "%% oldSHA256: " . ${$_[0]->{tocheck}}{$file} . "\n");
      ${$_[0]->{tocheck}}{$file} = $sha256;
      next;
    }
    
    # same file, process it
    $_[0]->__process_file($file);
    delete ${$_[0]->{tocheck}}{$file}; # do not process it next time
  }
  
  # add new files to next check
  foreach my $file (keys %{$_[0]->{tochecksoon}}) {
    ${$_[0]->{tocheck}}{$file} = ${$_[0]->{tochecksoon}}{$file};
    delete ${$_[0]->{tochecksoon}}{$file};
  }
  
  $_[0]->{doit}++;
  return(1);
}


##########
## __process_file($file)  

sub __process_file {
  if (scalar @{$_[0]->{ignore}} > 0) {
    my $file_part = $_[1];
    $file_part =~ s%^.+/%%;
    my $skipfile = 0;
    for (my $i = 0; $i < scalar @{$_[0]->{ignore}} || $skipfile; $i++) {
      my $v = ${$_[0]->{ignore}}[$i];
      $skipfile = ($file_part =~ m%$v%) ? 1 : 0;
    }
    if ($skipfile) {
      MMisc::vprint(($_[0]->{verb} > 0), ">> Ignoring file (" . $_[1] . ")\n");
      return();
    }
  }
  
  my $command = $_[0]->{cmd} . " " . $_[1];
  MMisc::vprint(($_[0]->{verb} > 0), ">> Background command: $command\n");
  
  # run command in background, as far as WE are concerned we did our job
  system("$command &");
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

