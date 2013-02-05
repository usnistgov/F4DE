package xmllintHelper;

# "xmllint" (& XSD) Functions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "xmllintHelper.pm" is an experimental system.
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

####################

sub new {
  my ($class) = shift @_;

  my $errortxt = (scalar @_ > 0) ? "xmllintHelper does not accept parameters" : "";

  my $errormsg = new MErrorH("xmllintHelper");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     xmllint        => "",
     xsdpath        => "",
     xsdfilesl      => undef,
     encoding       => '',
     errormsg       => $errormsg,
    };

  bless $self;
  return($self);
}

##########

sub set_xmllint {
  my ($self, $xmllint, $nocheck) = MMisc::iuav(\@_, undef, "", 0);

  my $nxmllint = $xmllint;
  if (! $nocheck) {
    ($nxmllint, my $error) = &_check_xmllint($xmllint);

    if (! MMisc::is_blank($error)) {
      $self->_set_errormsg($error);
      return(0);
    }
  }

  $self->{xmllint} = $nxmllint;
  return(1);
}

#####

sub is_xmllint_set {
  my ($self) = @_;

  return(1) if (! MMisc::is_blank($self->{xmllint}));

  return(0);
}

#####

sub get_xmllint {
  my ($self) = @_;

  if (! $self->is_xmllint_set()) {
    $self->_set_errormsg("\'xmllint\' is not set");
    return(0);
  }

  return($self->{xmllint});
}

#####

sub _check_xmllint {
  my ($xmllint) = shift @_;

  if (MMisc::is_blank($xmllint)) {
    $xmllint = &MMisc::cmd_which("xmllint");
    return("", "Could not find a valid \'xmllint\' command in the PATH, aborting\n") if (! defined $xmllint);
  }

  $xmllint =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  # Check that the file for xmllint exists and is an executable file
  my $err = MMisc::check_file_x($xmllint);
  return("", "\'xmllint\' ($xmllint) problem: $err\n") 
    if (! MMisc::is_blank($err));

  # Now check that it actually is xmllint
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call($xmllint, '--version');
  return("", "\'xmllint\' ($xmllint) does not seem to be a valid \'xmllint\' command, aborting\n")
    if ($retcode != 0);
  
  if ($stderr =~ m%using\s+libxml\s+version\s+(\d+)%) {
    # xmllint print the command name followed by the version number
    my $version = $1;
    return("", "\'xmllint\' ($xmllint) version too old: requires at least 2.6.30 (ie 20630, installed $version), aborting\n")
      if ($version < 20630);
  } else {
    return("", "Could not confirm that \'xmllint\' is valid, aborting\n");
  }

  return($xmllint, "");
}

############################################################

sub set_xsdfilesl {
  my ($self, @xsdfilesl) = @_;

  return(0) if ($self->error());

  if (scalar @xsdfilesl == 0) {
    $self->_set_errormsg("No \'xsdfilesl\' provided");
    return(0);
  }

  push @{$self->{xsdfilesl}}, @xsdfilesl;
  return(1);
}

#####

sub get_xsdfilesl {
  my ($self) = @_;

  my @xsdfilesl = @{$self->{xsdfilesl}};

  return(@xsdfilesl);
}

#####

sub is_xsdfilesl_set {
  my ($self) = @_;

  my @xsdfilesl = $self->get_xsdfilesl();

  return(0) if (scalar @xsdfilesl == 0);

  return(1);
}

############################################################

sub set_xsdpath {
  my ($self, $xsdpath, $nocheck) = MMisc::iuav(\@_, undef, "", 0);

  return(0) if ($self->error());

  if (! $self->is_xsdfilesl_set()) {
    $self->_set_errormsg("Can only \'set_xsdpath\' once \'xsdfilesl\' has been set");
    return(0);
  }

  if (! $nocheck) {
    my @xsdfilesl = $self->get_xsdfilesl();
    my $error = "";
    # Confirm that the required xsdfiles are available
    ($xsdpath, $error) = &_check_xsdfiles($xsdpath, @xsdfilesl);
    if (! MMisc::is_blank($error)) {
      $self->_set_errormsg($error);
      return(0);
    }
  }

  $self->{xsdpath} = $xsdpath;
  return(1);
}

#####

sub is_xsdpath_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{xsdpath}));

  return(0);
}

#####

sub get_xsdpath {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_xsdpath_set()) {
    $self->_set_errormsg("\'xsdpath\' is not set");
    return(0);
  }

  return($self->{xsdpath});
}

#####

sub _check_xsdfiles {
  my $xpths = shift @_;
  my @xsdfiles = @_;

  my @x = split(m%\s+%, $xpths);

  my %xp = ();
  my %xpl = ();
  for (my $i = 0; $i < scalar @xsdfiles; $i++) {
    my $fname = $xsdfiles[$i];
    for (my $j = 0; $j < scalar @x; $j++) {
      my $xsdpath = $x[$j];
      next if (exists $xp{$fname});

      $xsdpath =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;
      $xsdpath =~ s%(.)\/$%$1%;
      
      my $file = "$xsdpath/$fname";
      next if (! MMisc::is_file_r($file));
      $xp{$fname} = $xsdpath;
    }
    return("", "Could not find required XSD file ($fname) at selected path ($xpths), aborting\n")
      if (! exists $xp{$fname});
    
    $xpl{$xp{$fname}}++;
  }

  my @keys = keys %xpl;
  return("", "Found more than one valid path (" . join(" ", @keys) . ")for XSD files (" . join(" ", @xsdfiles) . "), aborting\n")
      if (scalar @keys > 1);
  my $xsdpath = shift @keys;
  
  return($xsdpath, "");
}

############################################################

sub set_encoding {
  my ($self, $encoding) = @_;

  return(0) if ($self->error());

  $self->{encoding} = $encoding;
  return(1);
}

#####

sub get_encoding {
  my ($self) = @_;

  my $encoding = $self->{encoding};

  return($encoding);
}

#####

sub is_encoding_set {
  my ($self) = @_;

  my $encoding = $self->get_encoding();

  return(0) if (MMisc::is_blank($encoding));

  return(1);
}

############################################################

sub run_xmllint_pipe {
  my ($self, $file) = @_;

  my $xmllint = $self->get_xmllint();
  my $xsdpath = $self->get_xsdpath();
  my @xsdfilesl = $self->get_xsdfilesl();
  return(undef) if ($self->error());
  
  my $stderr_file = MMisc::get_tmpfile();

  $file =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;

  my @cmd = ($xmllint, "--path", "\"$xsdpath\"", 
             "--schema", $xsdpath . "/" . $xsdfilesl[0]);
  if ($self->is_encoding_set()) {
    push @cmd, '--encode', $self->get_encoding();
  }
  push @cmd, '--format';
  push @cmd, $file;

  local *SE;
  open SE, ">$stderr_file" 
    or MMisc::error_quit("Problem creating temporary file ? ($stderr_file)");
  close SE;

  local *FH;
  open(FH, join(" ", @cmd) . " 2> $stderr_file |");
  return(*FH, $stderr_file);
}

#####

sub run_xmllint {
  my ($self, $file, $ofile) = @_;
  
  my $xmllint = $self->get_xmllint();
  my $xsdpath = $self->get_xsdpath();
  my @xsdfilesl = $self->get_xsdfilesl();
  
  return("") if ($self->error());
  
  $file =~ s{^~([^/]*)}{$1?(getpwnam($1))[7]:($ENV{HOME} || $ENV{LOGDIR})}ex;
  my $fileout = 1;
  if (MMisc::is_blank($ofile)) {
    $ofile = MMisc::get_tmpfile();
  } elsif ($ofile eq 'NOOUT') {
    $fileout = 0;
  }
  if ($fileout) {
    open FILE, ">$ofile"
      or $self->_set_error_and_return_scalar("Problem creating output file ($ofile)", "");
    close FILE;
  }

  my @cmd = ($xmllint, "--path", "\"$xsdpath\"", 
             "--schema", $xsdpath . "/" . $xsdfilesl[0]);
  if ($self->is_encoding_set()) {
    push @cmd, '--encode', $self->get_encoding();
  }
  if ($fileout) {
    push @cmd, '--output', $ofile;
    push @cmd, '--format';
  } else {
    push @cmd, '--noout';
  }
  push @cmd, $file;
  
#  print "[**] " . join(" | ", @cmd) . "\n";
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call(@cmd);
  
  if ($retcode != 0) {
    $self->_set_errormsg("Problem validating file with \'xmllint\' ($stderr), aborting");
    return("");
  }
#  print "[$ofile]\n";

  return("") if (! $fileout);

  return(MMisc::slurp_file($ofile));
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

#####

sub _set_error_and_return_array {
  my $self = shift @_;
  my $errormsg = shift @_;
  $self->_set_errormsg($errormsg);
  return(@_);
}

#####

sub _set_error_and_return_scalar {
  $_[0]->_set_errormsg($_[1]);
  return($_[2]);
}

############################################################

1;
