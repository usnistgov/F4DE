package AccellionHelper;

# Accellion command line tool Helper
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "ViperFramespan.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

use MErrorH;
use MMisc;

my $version     = '0.1b';

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "AccellionHelper.pm Version: $version";

my @modes = ('upload', 'download'); # Order is important

## Constructor
sub new {
  my ($class, $tool, $upload_basecfg, $download_basecfg) = @_;

  my $errorh = new MErrorH('AccellionHelper');
  my $err = MMisc::check_file_x($tool);
  $errorh->set_errormsg("Problem with tool ($tool) : $err") 
    if (! MMisc::is_blank($err));
  my $errorv = $errorh->error();

  my $self =
    {
     tool      => $tool,
     $modes[0] => {},
     $modes[1] => {},
     errorh    => $errorh,
     errorv    => $errorv, # Cache information
    };
 
  bless $self;
  return($self);
}

####################

sub get_version { return($versionid); }

############################################################
#################### UPLOAD options

##########
## IncludeSubDirs: To send all files in subdirectories (default: set)
sub set_IncludeSubDirs   { $_[0]->__binopt_true($modes[0], 'IncludeSubDirs'); }
sub unset_IncludeSubDirs { $_[0]->__binopt_false($modes[0], 'IncludeSubDirs'); }

##########
## EmailSubject : The subject of the email message
# Only one line of text is allowed
# Default message is : UploadSummary
sub set_EmailSubject   { $_[0]->__set_option($modes[0], 'EmailSubject', $_[1]); }
sub unset_EmailSubject { $_[0]->__unset_option($modes[0], 'EmailSubject'); }

##########
# EmailTemplate: path to a file contianing e-Mail body template  
# The template may contain placeholders marked with a $. Each place holder will be substituted with the value from the Substitions file
sub set_EmailTemplate   { $_[0]->__set_option($modes[0], 'EmailTemplate', $_[1]); }
sub unset_EmailTemplate { $_[0]->__unset_option($modes[0], 'EmailTemplate'); }

##########
# TemplateSubstituitions: path to the file that specifies the place holder substitution values for the e-mail body template
# Each line of the file must contain one 'placeholder = value' pair
sub set_TemplateSubstituitions   { $_[0]->__set_option($modes[0], 'TemplateSubstituitions', $_[1]); }
sub unset_TemplateSubstituitions { $_[0]->__unset_option($modes[0], 'TemplateSubstituitions'); }

##########
# ReturnReceipt: To request an intimation e-mail being sent to the AAA account owner whenever a file is downloaded by a recipient. 
sub set_ReturnReceipt   { $_[0]->__binopt_true($modes[0], 'ReturnReceipt'); }
sub unset_ReturnReceipt { $_[0]->__binopt_false($modes[0], 'ReturnReceipt'); }

##########
# RecipientAuthentication: To set authentication scheme for the recipient
# Valid Options: na- no authentication – anybody can download the file by clicking on the link
#                vr- verify recipient – download is allowed only to the direct recipients of the e-mail
#                vi- verify internal  - the direct recipients may forward the link to same domain e-mail id’s
#                ck- cookie – any authenticated user on the FTA appliance may download the file
# Default: as set on Courier Manager
sub set_RecipientAuthentication   { $_[0]->__set_mcq($modes[0], 'RecipientAuthentication', $_[1], ['na', 'vr', 'vi', 'ck']); }
sub unset_RecipientAuthentication { $_[0]->__unset_option($modes[0], 'RecipientAuthentication'); }

##########
# LinkValidity: To set the number of days for which the link will remain valid
# Valid Options: any number greater than 0 
# Default: as set on Courier Manager
sub set_LinkValidity   { 
  return($_[0]->_set_error_and_return("Invalid \'LinkValidity\' value (" . $_[1]. ") : must be integer and over 0"))
    if ((! MMisc::is_integer($_[1])) || ($_[1] < 1));
  $_[0]->__set_option($modes[0], 'LinkValidity', $_[1]);
}
sub unset_LinkValidity { $_[0]->__unset_option($modes[0], 'LinkValidity'); }

##########
# EmailCopyToOwner: To decide if a copy of the e-mail is to be sent to the owner of the AAA account
# Valid Options : 0 / 1
# Default : as set on Courier Manager
sub set_EmailCopyToOwner   { $_[0]->__binopt_true($modes[0], 'EmailCopyToOwner'); }
sub unset_EmailCopyToOwner { $_[0]->__binopt_false($modes[0], 'EmailCopyToOwner'); }

##########
# RenameSuffix : Folder is renamed with this suffix after upload
# So for eg if set to -sent the folder will be renamed to C:\Uploadfolder-sent
sub set_RenameSuffix   { $_[0]->__set_option($modes[0], 'RenameSuffix', $_[1]); }
sub unset_RenameSuffix { $_[0]->__unset_option($modes[0], 'RenameSuffix'); }

##########
# LocationLabel : Label assigned to a sender agent
sub set_LocationLabel   { 
  $_[0]->__set_option($modes[0], 'LocationLabel', $_[1]);
  $_[0]->__set_option($modes[1], 'LocationLabel', $_[1]);
}
sub unset_LocationLabel {
  $_[0]->__unset_option($modes[0], 'LocationLabel'); 
  $_[0]->__unset_option($modes[1], 'LocationLabel'); 
}

########################################
## upload

sub upload {
  my ($self, $path, @mailto) = @_;

  return(0) if (! $self->__set_mail($modes[0], 'MailTo', @mailto));
  $self->__set_path($modes[0], 'Path', $path);

  my $cfgfile = $self->obtain_configfile($modes[0]);
  return(0) if ($self->error());

  return($self->runtool($cfgfile));
}

############################################################
#################### DOWNLOAD options

##########
# LocationLabel : Comma separated location labels to download files from
# If not specified then files will be downloaded for all senders
# sub set_LocationLabel   { # defined in 'upload'
# sub unset_LocationLabel { # defined in 'upload'

##########
# Filter : Only files matching this filter are downloaded 
# Valid Options : Only single DOS wildcard match is supported ie like *.ext
# If not specified all files are downloaded
# This filter is applied to each of the location labels specified by LocationLabel
sub set_Filter   { $_[0]->__set_option($modes[1], 'Filter', $_[1]); }
sub unset_Filter { $_[0]->__unset_option($modes[1], 'Filter'); }

##########
# CreateLocationDirectory : Download files from a Location Label to a subdirectory named LocationLabel in the Path
# Default is 1. Eg : Files from sender1 will be downloaded to directory C:\Downloadfolder\sender1 , etc
# If set 0 subdirectory will not be created. Eg : Files from sender1 will be downloaded to C:\Downloadfolder , etc
sub set_CreateLocationDirectory   { $_[0]->__binopt_true($modes[1], 'CreateLocationDirectory'); }
sub unset_CreateLocationDirectory { $_[0]->__binopt_false($modes[1], 'CreateLocationDirectory'); }

##########
# CreateFullPath : Create the full path of the file as it was uploaded ( part of the path after the foldername )
# Default is 1. A file uploaded as C:\Uploadfolder\folder1\file1 by sender1 
# will be downloaded to C:\Downloadfolder\sender1\Uploadfolder\folder1\file1
# If set 0 the full path is not created.  A file uploaded as C:\Uploadfolder\folder1\file1 by sender1 
# will be downloaded to C:\Downloadfolder\sender1\file1
sub set_CreateFullPath   { $_[0]->__binopt_true($modes[1], 'CreateFullPath'); }
sub unset_CreateFullPath { $_[0]->__binopt_false($modes[1], 'CreateFullPath'); }

############################################################
####################

sub obtain_configfile {
  # 0: self
  # 1: mode

  my $tmpfile = MMisc::get_tmpfilename();
  open FILE, ">$tmpfile"
    or return($_[0]->_set_error_and_return("Problem creating configuration file ($tmpfile) : $!", 0));
  print FILE "[configuration]\n";
  print FILE "Task = " . $_[1] . "\n";
  foreach my $cmd (keys %{$_[0]->{$_[1]}}) {
    my $v = ${$_[0]->{$_[1]}}{$cmd};
    next if (MMisc::is_blank($v));
    print FILE "$cmd = $v\n";
  }
  close FILE;

  return($tmpfile);
}

##########

sub runtool {
  #0: self
  #1: cfg file
 
  my @cmd = ($_[0]->{tool}, '-t', $_[1]);
  
  my ($ok, $otxt, $stdout, $stderr, $retcode, $logfile) 
    = MMisc::write_syscall_logfile($_[1] . ".log", @cmd);

  return($_[0]->_set_error_and_return("Problem with running tool, see log: $logfile"))
    if ((! $ok) || ($retcode != 0));

  return(1);
}

############################################################

sub check_bad_emails {
  #0 : self
  #1+: email addresses
  my $errs = 0;
  for (my $i = 1; $i < scalar @_; $i++) {
    my $err = MMisc::is_email($_[$i]);
    if (! MMisc::is_blank($err)) {
      $_[0]->set_errormsg("Problem with email address (" . $_[$i] . ") : $err");
      $errs++;
    }
  }
  return($errs);
}

##########

sub __set_value { ${$_[0]->{$_[1]}}{$_[2]} = $_[3]; return(1); }

sub __set_mail {
  my ($self, $mode, $option, @emails) = @_;
  return(0) if ($self->check_bad_emails(@emails));
  return($self->__set_value($mode, $option, join(",", @emails)));
}

sub __set_path { return($_[0]->__set_value($_[1], $_[2], MMisc::get_file_full_path($_[3]))); }

sub __set_mcq {
  my ($self, $mode, $option, $value, $rpossibles) = @_;
  my %h = MMisc::array1d_to_ordering_hash($rpossibles);
  return($_[0]->_set_error_and_return("Invalid \'$option\' value ($value), possible values: " . join(", ", @$rpossibles), 0))
    if (! exists $h{$value});
  return($_[0]->__set_value($_[1], $_[2], $_[3]));
}  

#####

sub __set_option   { return($_[0]->__set_value($_[1], $_[2], $_[3])); }
sub __unset_option { return($_[0]->__set_value($_[1], $_[2], "")); }

#####

sub ___binopt_true  { return($_[0]->__set_value($_[1], $_[2], 1)); }
sub ___binopt_false { return($_[0]->__set_value($_[1], $_[2], 0)); }

#################### 'clone'

sub clone {
  return(undef) if ($_[0]->{errorv});
  return(new AccellionHelper($_[0]->{tool}));
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
