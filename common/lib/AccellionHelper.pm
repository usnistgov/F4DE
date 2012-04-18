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
my @post_modes = ('PostSendScript', 'PostDownloadScript', 'PostEmailDownloadScript'); # Order is important

##########
# new(AgentLocation)
# will check tool major version for compatibility
sub new {
  my ($class, $tool) = @_;

  my $errorh = new MErrorH('AccellionHelper');
  my $err = MMisc::check_file_x($tool);
  $errorh->set_errormsg("Problem with tool ($tool) : $err") 
    if (! MMisc::is_blank($err));
  my $toolv = __get_tool_major_version($tool);
  $errorh->set_errormsg("Problem with tool ($tool) : Could not define version number") 
    if ($toolv == 0);
  my $errorv = $errorh->error();

  my $self =
    {
     tool      => $tool,
     toolv     => $toolv,
     $modes[0] => {},
     $modes[1] => {},
     $post_modes[0] => {},
     $post_modes[1] => {},
     $post_modes[2] => {},
     errorh    => $errorh,
     errorv    => $errorv,      # Cache information
     dbg_donotrun    => 0,
     dbg_showlogpath => 0, 
    };
 
  bless $self;
  return($self);
}

####################

# get_version()
# Obtain the version number of the Perl Package
sub get_version { return($versionid); }

# get_tool_major_version()
# Obtain the major version number of the Agent tool
sub get_tool_major_version { return($_[0]->{toolv}); }


##########

sub debug_set_toolv        { $_[0]->{toolv} = $_[1]; }
sub debug_set_donotrun     { $_[0]->{dbg_donotrun} = $_[1]; }
sub debug_set_showlogpath  { $_[0]->{dbg_showlogpath} = $_[1]; }


############################################################
#################### UPLOAD options

########## upload (v1,v2)
# set_IncludeSubDirs()
# set_IncludeSubDirs()
## To send all files in subdirectories (default: set)
# unset to exclude files in subfolders
sub set_IncludeSubDirs   { $_[0]->__binopt_true([1,2], [$modes[0]], 'IncludeSubDirs'); }
sub unset_IncludeSubDirs { $_[0]->__binopt_false([1,2], [$modes[0]], 'IncludeSubDirs'); }


########## upload (v1,v2)
# set_EmailSubject(subjectText)
# unset_EmailSubject()
## The subject of the email message
# Only one line of text is allowed
# Default message is : UploadSummary
sub set_EmailSubject   { $_[0]->__set_with_constraint([1,2], [$modes[0]], 'EmailSubject', $_[1], (($_[1] =~ tr%\n%%) == 0), "must be contained within one line of text"); }
sub unset_EmailSubject { $_[0]->__unset_option([1,2], [$modes[0]], 'EmailSubject'); }


########## upload (v1,v2)
# set_EmailTemplate(TemplateFile)
# unset_EmailTemplate()
## Path to a file contianing e-Mail body template  
# The template may contain placeholders marked with a $
# Each place holder will be substituted with the value from the Substitions file
sub set_EmailTemplate   { $_[0]->__set_file_r([1,2], [$modes[0]], 'EmailTemplate', $_[1]); }
sub unset_EmailTemplate { $_[0]->__unset_option([1,2], [$modes[0]], 'EmailTemplate'); }


########## upload (v1,v2)
# set_TemplateSubstituitions(TemplateSubstitutionFile)
# unset_TemplateSubstituitions()
## Path to the file that specifies the place holder substitution values for the e-mail body template
# Each line of the file must contain one 'placeholder = value' pair
# (v2) First line of the file must be [EmailSubs]
# $Date and $Time are substituted with the current date and time if not specified in this file
sub set_TemplateSubstituitions   { $_[0]->__set_file_r([1,2], [$modes[0]], 'TemplateSubstituitions', $_[1]); }
sub unset_TemplateSubstituitions { $_[0]->__unset_option([1,2], [$modes[0]], 'TemplateSubstituitions'); }


########## upload (v1,v2)
# set_ReturnReceipt()
# unset_ReturnReceipt()
## To request an intimation e-mail being sent to the AAA account owner whenever a file is downloaded by a recipient. 
sub set_ReturnReceipt   { $_[0]->__binopt_true([1,2], [$modes[0]], 'ReturnReceipt'); }
sub unset_ReturnReceipt { $_[0]->__binopt_false([1,2], [$modes[0]], 'ReturnReceipt'); }


########## upload (v1,v2)
# set_RecipientAuthentication(AuthenticationScheme)
# unset_RecipientAuthentication()
## To set authentication scheme for the recipient
# Valid Options: na- no authentication – anybody can download the file by clicking on the link
#                vr- verify recipient – download is allowed only to the direct recipients of the e-mail
#                vi- verify internal  - the direct recipients may forward the link to same domain e-mail id’s
#                ck- cookie – any authenticated user on the FTA appliance may download the file
# Default: (v1) as set on Courier Manager (v2) vr
sub set_RecipientAuthentication   { $_[0]->__set_mcq([1,2], [$modes[0]], 'RecipientAuthentication', $_[1], ['na', 'vr', 'vi', 'ck']); }
sub unset_RecipientAuthentication { $_[0]->__unset_option([1,2], [$modes[0]], 'RecipientAuthentication'); }


########## upload (v1,v2)
# set_LinkValidity(numberOfDays)
# unset_LinkValidity()
## To set the number of days for which the link will remain valid
# Valid Options: any number greater than 0 
# Default: as set on Courier Manager
sub set_LinkValidity   { $_[0]->__set_with_constraint([1,2], [$modes[0]], 'LinkValidity', $_[1], ((MMisc::is_integer($_[1])) && ($_[1] > 0)), 'must be integer and over 0'); }
sub unset_LinkValidity { $_[0]->__unset_option([1,2], [$modes[0]], 'LinkValidity'); }


########## upload (v1,v2)
# set_EmailCopyToOwner()
# unset_EmailCopyToOwner()
## To decide if a copy of the e-mail is to be sent to the owner of the AAA account
# Default : as set on Courier Manager
sub set_EmailCopyToOwner   { $_[0]->__binopt_true([1,2], [$modes[0]], 'EmailCopyToOwner'); }
sub unset_EmailCopyToOwner { $_[0]->__binopt_false([1,2], [$modes[0]], 'EmailCopyToOwner'); }


########## upload (v1,v2)
# set_RenameSuffix(suffixString)
# unset_RenameSuffix()
## Folder is renamed with this suffix after upload
# So for eg if set to -sent the folder will be renamed to C:\Uploadfolder-sent
sub set_RenameSuffix   { $_[0]->__set_option([1,2], [$modes[0]], 'RenameSuffix', $_[1]); }
sub unset_RenameSuffix { $_[0]->__unset_option([1,2], [$modes[0]], 'RenameSuffix'); }


########## upload (v1)
# set_LocationLabel(labelString)
# unset_set_LocationLabel()
## LocationLabel : Label assigned to a sender agent
sub set_LocationLabel   { $_[0]->__set_option([1], [$modes[0], $modes[1]], 'LocationLabel', $_[1]); }
sub unset_LocationLabel { $_[0]->__unset_option([1], [$modes[0], $modes[1]], 'LocationLabel'); }


########## upload (v2)
# set_MailCc(arrayOfAddresses)
# unset_MailCc()
## List of recipients to send a copy of the email with links to the uploaded files ( comma separated )
sub set_MailCc   { my $self = shift @_; $self->__set_mail([2], [$modes[0]], 'MailCc', @_); }
sub unset_MailCc { $_[0]->__unset_option([2], [$modes[0]], 'MailCc'); }


########## upload (v2)
# set_MailBcc(emailAddresses)
# unset_MailBcc()
## List of recipients to send a blind copy of the email with links to the uploaded files ( comma separated )
sub set_MailBcc   { my $self = shift @_; $self->__set_mail([2], [$modes[0]], 'MailBcc', @_); }
sub unset_MailBcc { $_[0]->__unset_option([2], [$modes[0]], 'MailBcc'); }


########## upload (v2)
# set_HTMLMessageBody()
# unset_HTMLMessageBody()
## To specify that the e-mail tempalte is HTML text (default: false)
sub set_HTMLMessageBody   { $_[0]->__binopt_true([2], [$modes[0]], 'HTMLMessageBody'); }
sub unset_HTMLMessageBody { $_[0]->__binopt_false([2], [$modes[0]], 'HTMLMessageBody'); }


########## upload (v2)
# set_ReturnReceiptAddresses(emailAddresses)
# unset_ReturnReceiptAddresses(emailAddresses)
## list of e-mail id's to get the download intimation e-mail in addition to the account owner ( comma separated )
sub set_ReturnReceiptAddresses   { my $self = shift @_; $self->__set_mail([2], [$modes[0]], 'ReturnReceiptAddresses', @_); }
sub unset_ReturnReceiptAddresses { $_[0]->__unset_option([2], [$modes[0], $modes[1]], 'ReturnReceiptAddresses'); }


########## upload (v2)
# set_EnableResume()
# unset_EnableResume()
## To decide if the current task should be compared with earlier unfinished tasks and to restart a 'same' old unfinished task
# (Default : false) Set it to true so that the task may be completed by restarting an earlier unfinished try for the same task. 
# Note: to resume a task, the earlier try should also have set this parameter to 1. 
# Recommendation: This parameter should be set to 1 while sending large files
sub set_EnableResume   { $_[0]->__binopt_true([2], [$modes[0], $modes[1]], 'EnableResume'); }
sub unset_EnableResume { $_[0]->__binopt_false([2], [$modes[0], $modes[1]], 'EnableResume'); }


########## upload (v2)
# set_SendNewOrChanged()
# unset_SendNewOrChanged()
## To enable sending only new or changed files as compared to files sent earlier.
# When this option is turned on AAA keeps track of the modified files
# (default: false) Set it to true to send only those files that have not been sent earlier or have changed since being sent previously
# Note: AAA keeps track of sent files only if this parameter is set to true
sub set_SendNewOrChanged   { $_[0]->__binopt_true([2], [$modes[0]], 'SendNewOrChanged'); }
sub unset_SendNewOrChanged { $_[0]->__binopt_false([2], [$modes[0]], 'SendNewOrChanged'); }


########## upload (v2)
# set_SendNewerThan("YYYY-MM-DD-HH-mm-SS")
# unset_SendNewerThan()
## To specify the cutoff for file creation or modification time. Only files created or modified after the specified date-time will be sent
# Valid Options : a date-time value in the format YYYY-MM-DD-HH-mm-SS (where YYYY= year, MM=month, DD=day of the month, HH=hour, mm=minute, SS=second)
# Default : None, all files are sent irrespective of their date-time stamp.
sub set_SendNewerThan   { $_[0]->__set_with_constraint([2], [$modes[0]], 'SendNewerThan', $_[1], ($_[1] =~ m%^\d{4}\-\d{2}\-\d{2}\-\d{2}\-\d{2}\-\d{2}$%), 'possible values must be of the form: YYYY-MM-DD-HH-mm-SS'); }
sub unset_SendNewerThan { $_[0]->__unset_option([2], [$modes[0]], 'SendNewerThan'); }


########## upload (v2)
# set_SendOnlyToAccellion()
# unset_SendOnlyToAccellion()
## To send the file/s only to the Accellion inbox of the recipients - the e-mail with links is not sent
# default: false, the e-mail with download links is also sent to the recipient email ids
sub set_SendOnlyToAccellion   { $_[0]->__binopt_true([2], [$modes[0]], 'SendOnlyToAccellion'); }
sub unset_SendOnlyToAccellion { $_[0]->__binopt_false([2], [$modes[0]], 'SendOnlyToAccellion'); }


########## upload (v2)
# set_ContinuousRun()
# unset_ContinuousRun()
## To scan a folder every 5 seconds, and send the detected files according to the rest of the parameters (default: false)
sub set_ContinuousRun   { $_[0]->__binopt_true([2], [$modes[0], $modes[1]], 'ContinuousRun'); }
sub unset_ContinuousRun { $_[0]->__binopt_false([2], [$modes[0], $modes[1]], 'ContinuousRun'); }


########## upload (v2)
# set_ScanFrequency(inSeconds)
# unset_ScanFrequency()
## To set the time interval after which the AAA looks for new files to upload
# Valid only in Continuous Scan mode
# default: 5 seconds; values must be > 1
sub set_ScanFrequency   { $_[0]->__set_with_constraint([2], [$modes[0], $modes[1]], 'ScanFrequency', $_[1], ((MMisc::is_integer($_[1])) && ($_[1] > 1)), 'must be integer and over 1'); }
sub unset_ScanFrequency { $_[0]->__unset_option([2], [$modes[0], $modes[1]], 'ScanFrequency'); }


########## upload (v2)
# set_PostSendProcess(mode)
# unset_PostSendProcess()
## To delete/rename a file after uploading it, if running in continuous scan mode
# 0: deletes files after sending
# 1: rename the files by appending the RenameSuffix to the filename 
# 2: reserved
# 3: do nothing (default)
sub set_PostSendProcess   { $_[0]->__set_mcq([2], [$modes[0]], 'PostSendProcess', $_[1], ['0', '1', '2', '3']); }
sub unset_PostSendProcess { $_[0]->__unset_option([2], [$modes[0]], 'PostSendProcess'); }


########## upload (v2)
# set_GetRecipientFromPath(AAARegularExpression)
# unset_GetRecipientFromPath()
## Enable AAA to extract recipient email-id/s from the upload path itself 
# Valid Options : A valid regular expression (invalid Regular Expression is ignored)
# E.g. if the GetRecipientFromPath = ^.*?(?=\\) and the upload Path c:\uploadfolder contains a file c:\uploadfolder\abc@somedomain.com\file1.doc , this file will be sent to abc@somedomain.com along with the email-id specified in MailTo 
# Note: Only supported for ContinuousRun=1
# Default is Blank
sub set_GetRecipientFromPath   { $_[0]->__set_option([2], [$modes[0]], 'GetRecipientFromPath', $_[1]); }
sub unset_GetRecipientFromPath { $_[0]->__unset_option([2], [$modes[0]], 'GetRecipientFromPath'); }


########## upload (v2)
# set_ExcludeFilter(AAARegularExpression)
# unset_ExcludeFilter()
## AAA will not send files that match the provided regular expression filter
# Valid Options: A valid regular expression (invalid ones are ignored) 
# e.g.  ExcludeFilter = doc$|exe$ will exclude all doc and exe files
# Note: Valid only in Continuous Scan mode
# Default is Blank
sub set_ExcludeFilter   { $_[0]->__set_option([2], [$modes[0]], 'ExcludeFilter', $_[1]); }
sub unset_ExcludeFilter { $_[0]->__unset_option([2], [$modes[0]], 'ExcludeFilter'); }


########## upload (v2)
# set_IncludeFilter(AAARegularExpression)
# unset_IncludeFilter()
## AAA will upload ONLY those files that match the provided regular expression filter
# Valid Options: A valid regular expression (invalid ones are ignored) 
# e.g. IncludeFilter = csv$ will result in sending only csv files 
# Note: Valid only in Continuous Scan mode
# Default is Blank
sub set_IncludeFilter   { $_[0]->__set_option([2], [$modes[0]], 'IncludeFilter', $_[1]); }
sub unset_IncludeFilter { $_[0]->__unset_option([2], [$modes[0]], 'IncludeFilter'); }


########## upload (v2)
# set_ZipBeforeSending()
# unset_ZipBeforeSending()
## Folder (in Single Run Mode) or Files (in continuous mode) are zipped before being sent
# (Default : false) Set to true to create a single zip of the files/folder before being sent
sub set_ZipBeforeSending   { $_[0]->__binopt_true([2], [$modes[0]], 'ZipBeforeSending'); }
sub unset_ZipBeforeSending { $_[0]->__binopt_false([2], [$modes[0]], 'ZipBeforeSending'); }


########## upload (v2)
# set_EncryptBeforeSending()
# unset_EncryptBeforeSending()
## The file(s) are encrypted before sending. While downloading, the Appliance will decrypt it on the fly using the key in the link
# (Default : false) Set to true to encrypt files before being sent
## Warning: when sending a file between "agents", this behavior might happen: 
# "this Encrypted files cannot be downloaded as the decryption key is not stored on the appliance"
# so it is recommended to only use this option if the file is send to a user via an email link
sub set_EncryptBeforeSending   { $_[0]->__binopt_true([2], [$modes[0]], 'EncryptBeforeSending'); }
sub unset_EncryptBeforeSending { $_[0]->__binopt_false([2], [$modes[0]], 'EncryptBeforeSending'); }


########## upload (v2)
# set_PostUploadTaskScript(Type, Name, Call, RunCondition, WaitForResult, FailureMode, ArrayOfParameters)
## AAA can be configured to invoke an external script or executable after attempting an upload task
# The parameters to configure the external script  are:
# Type : the type of the external script - executable or script or a python module
#   Valid Options : exe,  shell or python
#   Default : no default. Must be specified as one of the three options
# Name: Name of the external script to be called
#   Valid Options : Name or full_path of the script to be invoked
#   Default : no default. Must be specified. 
# Call: required only if the external script is a python module
#   Valid options: the name of the method that is to be called from the external python module
#   Default : no default. Must be specified. 
# RunCondition: To decide if the external script is to be called after a successful or failed send attempt (or both cases)
#   Valid options: RunAlways, RunOnSuccess or RunOnFailure
#   Default: RunOnSuccess
# WaitForResult: To decide if the AAA should wait and log the result returned by the external script
#   Valid options: 0 or 1
#   Default: 0
# FailureMode: To decide if the external script failure should be treated as 'send' failure or not
#   Valid options: FailTask or IgnoreFailure
#   Default: FailTask
# Parameter(s): to be passed to the external script, 
#   Valid options: any valid command line parameter value. 
#   A few special values are - $FILE_PATH$, $FILE_LIST$, $Result$, $SenderId$, $MailTo$, $MailCc$, $MailBcc$,
#     $EMAIL_PATH$, $BODY_PATH$, $ATT_DIR$,
#   Default:None
sub set_PostUploadTaskScript {
  my $self = shift @_;
  return($self->__set_PostScript([2], [$post_modes[0]], @_));
}


########################################
########## upload (v1,v2)
# upload(PathOrDir, ArrayOfEmails)
## Upload file or directory to specified email addresses
sub upload {
  my ($self, $bpath, @mailto) = @_;

  return(0) if (! $self->__set_mail([1,2], [$modes[0]], 'MailTo', @mailto));

  my $path = MMisc::get_file_full_path($bpath);
  if (MMisc::does_file_exist($path)) {
    my $err = MMisc::check_file_r($path);
    return($_[0]->_set_error_and_return("Issue with File to \'upload\' ($path): $err", 0))
      if (! MMisc::is_blank($err));
  } elsif (MMisc::does_dir_exist($path)) {
    my $err = MMisc::check_dir_r($path);
    return($_[0]->_set_error_and_return("Issue with Directory to \'upload\' ($path): $err", 0))
      if (! MMisc::is_blank($err));
  } else {
    return($_[0]->_set_error_and_return("Issue with file/dir to \'upload\' ($path): not a file or directory ?", 0));
  }
  return(0)
    if (! $self->__set_path([1,2], [$modes[0]], 'Path', $path));

  my $post = "";
  if (($self->{toolv} == 2) && (scalar(keys %{$self->{$post_modes[0]}}) > 0)) {
    $post .= $_[0]->get_section($post_modes[0], $post_modes[0], "") . "\n\n";
  }

  my $cfgfile = $self->obtain_configfile($modes[0], "", $post);
  return(0) if ($self->error());

  return($self->runtool($cfgfile));
}


########## upload (v1,v2)
# upload_with_email(PathOrDir, EmailSubject, EmailBodyFile, ArrayOfEmails)
## extension to the 'upload' function to add e-mail subject and body
# EmailSubject and/or EmailBodyFile can be empty to bypass their use
sub upload_with_email {
  my ($self, $path, $subj, $emailfile, @mailto) = @_;

  if (! MMisc::is_blank($subj)) {
    return(0)
      if (! $self->set_EmailSubject($subj));
  }

  if (! MMisc::is_blank($emailfile)) {
    return(0)
      if (! $self->set_EmailTemplate($emailfile));
  }

  return($self->upload($path, @mailto));
}


########## upload (v1,v2)
# preferred_upload(PathOrDir, EmailSubject, EmailBodyFile, ArrayOfEmails)
## extension to the 'upload' function to add e-mail subject and body with default upload options so that:
# (v1,v2) get a return receipt when the file is downloaded
# (v1,v2) download is allowed only to the direct recipients of the e-mail
# (v1,v2) the link will remain valid for 14 days
# (v1,v2) copy of the e-mail is to be sent to the owner of the AAA account
# (v2) send only new or changed files as compared to files sent earlier
sub preferred_upload {
  my ($self, $path, $subj, $emailfile, @mailto) = @_;

  # get a return receipt
  return(0)
    if (! $self->set_ReturnReceipt());
  
  # must a validated user to download
  return(0)
    if (! $self->set_RecipientAuthentication('vr'));

  # set link validity to 2 weeks
  return(0) 
    if (! $self->set_LinkValidity(14)); 

  # copy user of this upload
  return(0)
    if (! $self->set_EmailCopyToOwner());
  
  if ($self->{toolv} == 2) {
    return(0)
      if (! $self->set_SendNewOrChanged());
  }

  return($self->upload_with_email($path, $subj, $emailfile, @mailto));
}


########## upload (v1)
# preferred_upload_withLabel(PathOrDir, EmailSubject, EmailBodyFile, Label, ArrayOfEmails)
## extension to the 'preferred_upload' function to add a Label
sub preferred_upload_withLabel {
  my ($self, $path, $subj, $emailfile, $label, @mailto) = @_;

  return(0)
    if (! $self->set_LocationLabel($label));

  return($self->preferred_upload($path, $subj, $emailfile, @mailto));
}


########## upload (v2)
# continuous_preferred_upload(DirToUploadFrom, EmailSubject, EmailBodyFile, CheckInterval, ArrayOfEmails)
## extension to preferred_upload to continuously upload files from given directory
# Warning: tool will not exit from this mode
sub continuous_preferred_upload {
  my ($self, $tdir, $subj, $emailfile, $checki, @mailto) = @_;
  
  return(0)
    if (! $self->set_ContinuousRun());

  my $dir = MMisc::get_file_full_path($tdir);
  my $err = MMisc::check_dir_r($dir);
  return($self->_set_error_and_return("\'continuous_upload\' can only be used with directories ($dir): $err", 0))
    if (! MMisc::is_blank($err));

  return(0)
    if (! $self->set_ScanFrequency($checki));

  return($self->preferred_upload($tdir, $subj, $emailfile, @mailto));
}


################################################################################
#################### DOWNLOAD options

########## download (v1)
# set_LocationLabel(labelString)
# unset_LocationLabel()
# Comma separated location labels to download files from
# If not specified then files will be downloaded for all senders
# sub set_LocationLabel   { # defined in 'upload' section
# sub unset_LocationLabel { # defined in 'upload' section


########## download (v1)
# set_Filter(AAAwildcard)
# unset_Filter()
## Only files matching this filter are downloaded 
# Valid Options : Only single DOS wildcard match is supported ie like *.ext
# If not specified all files are downloaded
# This filter is applied to each of the location labels specified by LocationLabel
sub set_Filter   { $_[0]->__set_option([1], [$modes[1]], 'Filter', $_[1]); }
sub unset_Filter { $_[0]->__unset_option([1], [$modes[1]], 'Filter'); }


########## download (v1)
# set_CreateLocationDirectory()
# unset_CreateLocationDirectory()
## Download files from a Location Label to a subdirectory named LocationLabel in the Path
# Default is true. Eg : Files from sender1 will be downloaded to directory C:\Downloadfolder\sender1 , etc
# If set to false, subdirectory will not be created. Eg : Files from sender1 will be downloaded to C:\Downloadfolder , etc
sub set_CreateLocationDirectory   { $_[0]->__binopt_true([1], [$modes[1]], 'CreateLocationDirectory'); }
sub unset_CreateLocationDirectory { $_[0]->__binopt_false([1], [$modes[1]], 'CreateLocationDirectory'); }


########## download (v1)
# set_CreateFullPath()
# unset_CreateFullPath()
## Create the full path of the file as it was uploaded ( part of the path after the foldername )
# Default is true. A file uploaded as C:\Uploadfolder\folder1\file1 by sender1 
# will be downloaded to C:\Downloadfolder\sender1\Uploadfolder\folder1\file1
# If set to false, the full path is not created.  A file uploaded as C:\Uploadfolder\folder1\file1 by sender1 
# will be downloaded to C:\Downloadfolder\sender1\file1
sub set_CreateFullPath   { $_[0]->__binopt_true([1], [$modes[1]], 'CreateFullPath'); }
sub unset_CreateFullPath { $_[0]->__binopt_false([1], [$modes[1]], 'CreateFullPath'); }


########## download (v2)
# set_ContinuousRun()
# unset_ContinuousRun()
## To scan the user's inbox on the Accellion Appliance for any new files to download. Default scan frequency is 5 seconds
# Default is false
# sub set_ContinuousRun   { # defined in 'upload' section
# sub unset_ContinuousRun { # defined in 'upload' section


########## download (v2)
# set_DownloadAgain()
# unset_DownloadAgain()
## To download files again if the downloaded copy is removed
# (default: false) Valid only in Continuous Scan mode
sub set_DownloadAgain   { $_[0]->__binopt_true([2], [$modes[1]], 'DownloadAgain'); }
sub unset_DownloadAgain { $_[0]->__binopt_false([2], [$modes[1]], 'DownloadAgain'); }


########## download (v2)
# set_DownloadMailBody()
# unset_DownloadMailBody()
## To download the e-mail text along with the files (default: false)
sub set_DownloadMailBody   { $_[0]->__binopt_true([2], [$modes[1]], 'DownloadMailBody'); }
sub unset_DownloadMailBody { $_[0]->__binopt_false([2], [$modes[1]], 'DownloadMailBody'); }


########## download (v2)
# set_EnableResume()
# unset_EnableResume()
## To decide if the current task should be compared with earlier unfinished tasks and to restart a 'same' old unfinished task
# (Default : false) Set to true so that the task may be completed by restarting an earlier unfinished try for the same task
# Note: to resume a task, the earlier try should also have set this parameter to true. 
# sub set_EnableResume   { # defined in 'upload' section
# sub unset_EnableResume { # defined in 'upload' section


########## download (v2)
# set_ScanFrequency(inSeconds)
# unset_ScanFrequency()
## To set the time interval after which the AAA looks for new files to download
# Valid only in Continuous Scan mode
# sub set_ScanFrequency   { # defined in 'upload' section
# sub unset_ScanFrequency { # defined in 'upload' section


########## download (v2)
# set_SenderEmail(emailAdress)
# unset_SenderEmail()
## Download only the files that have been sent by from this e-mail address
# Default is blank - i.e. download irrespective of the sender
sub set_SenderEmail   { $_[0]->__set_mail([2], [$modes[1]], 'SenderEmail', $_[1]); }
sub unset_SenderEmail { $_[0]->__unset_option([2], [$modes[1]], 'SenderEmail'); }


########## download (v2)
# set_EmailAge(numberDays)
# unset_EmailAge()
## Download files that have been received in the last EmailAge days only
# Not usable in a Continuous Run
# Valid Options : 0 or any positive whole number, 0 means unlimited (default: 0)
sub set_EmailAge   { $_[0]->__set_with_constraint([2], [$modes[1]], 'EmailAge', $_[1], ((MMisc::is_integer($_[1])) && ($_[1] >= 1)), 'possible values >= 0'); }
sub unset_EmailAge { $_[0]->__unset_option([2], [$modes[1]], 'EmailAge'); }


########## download (v2)
# set_UnzipAfterDownloading()
# unset_UnzipAfterDownloading()
## Unzip any downloaded zip files (default: false)
sub set_UnzipAfterDownloading   { $_[0]->__binopt_true([2], [$modes[1]], 'UnzipAfterDownloading'); }
sub unset_UnzipAfterDownloading { $_[0]->__binopt_false([2], [$modes[1]], 'UnzipAfterDownloading'); }


########## download (v2)
# set_PostDownloadTaskScript(Type, Name, Call, RunCondition, WaitForResult, FailureMode, ArrayOfParameters)
# set_PostEmailDownloadTaskScript(Type, Name, Call, RunCondition, WaitForResult, FailureMode, ArrayOfParameters)
## AAA can be configured to invoke an external script or executable after attempting an download task
# The parameters to configure the external script are:
# Type : the type of the external script - executable or script or a python module
#   Valid Options : exe,  shell or python
#   Default : no default. Must be specified as one of the three options
# Name: Name of the external script to be called
#   Valid Options : Name or full_path of the script to be invoked
#   Default : no default. Must be specified. 
# Call: required only if the external script is a python module
#   Valid options: the name of the method that is to be called from the external python module
#   Default : no default. Must be specified. 
# RunCondition: To decide if the external script is to be called after a successful or failed send attempt (or both cases)
#   Valid options: RunAlways, RunOnSuccess or RunOnFailure
#   Default: RunOnSuccess
# WaitForResult: To decide if the AAA should wait and log the result returned by the external script
#   Valid options: 0 or 1
#   Default: 0
# FailureMode: To decide if the external script failure should be treated as 'send' failure or not
#   Valid options: FailTask or IgnoreFailure
#   Default: FailTask
# Parameter(s): to be passed to the external script, 
#   Valid options: any valid command line parameter value. 
#   A few special values are - $FILE_PATH$, $FILE_LIST$, $Result$, $SenderId$, $MailTo$, $MailCc$, $MailBcc$,
#     $EMAIL_PATH$, $BODY_PATH$, $ATT_DIR$,
#   Default:None
sub set_PostDownloadTaskScript {
  my $self = shift @_;
  return($self->__set_PostScript([2], [$post_modes[1]], @_));
}
sub set_PostEmailDownloadTaskScript {
  my $self = shift @_;
  return($self->__set_PostScript([2], [$post_modes[2]], @_));
}


########################################
########## download (v1,v2)
# download(PathToDownloadTo)
## Download all content into given path
sub download {
  my ($self, $path) = @_;

  return(0)
    if (! $self->__set_dir_w([1,2], [$modes[1]], 'Path', $path));

  my $post = "";
  if ($self->{toolv} == 2) {
    for (my $i = 1; $i < scalar @post_modes; $i++) {
      if (scalar(keys %{$self->{$post_modes[$i]}}) > 0) {
        $post .= $_[0]->get_section($post_modes[$i], $post_modes[$i], "") . "\n\n";
      }
    }
  }

  my $cfgfile = $self->obtain_configfile($modes[1], "", $post);
  return(0) if ($self->error());
#  print "[$cfgfile]\n";

  return($self->runtool($cfgfile));
}


########## download (v1)
# download_withLabel(PathToDownloadTo, Label)
## Download only content matching "Label" into given path
sub download_withLabel {
  my ($self, $path, $label) = @_;

  return(0)
    if (! $self->set_LocationLabel($label));

  return($self->download($path));
}


########## preferred_download (v1,v2)
# preferred_download(PathToDownloadTo)
## Set default download options 
# (v2) To download the e-mail text along with the files
sub preferred_download {
  my ($self, $path) = @_;

  # nothing to set for v1, call 'download' as is
  return($self->download($path))
    if ($self->{toolv} == 1);

  # obtain the email body with the file
  return(0)
    if (! $self->set_DownloadMailBody());

  return($self->download($path));
}


########## download (v2)
# preferred_download_fromEmail(PathToDownloadTo, Email)
## Extension to preferred download function; download only from specific email address
sub preferred_download_fromEmail {
  my ($self, $path, $email) = @_;

  return(0)
    if (! $self->set_SenderEmail($email));


  return($self->preferred_download($path));
}


########## download (v2)
# preferred_download_newSince(PathToDownloadTo, numberDays)
## Extension to preferred download function; download only files newer than numberDays
sub preferred_download_newSince {
  my ($self, $path, $since) = @_;

  return(0)
    if (! $self->set_EmailAge($since));

  return($self->preferred_download($path));
}


########## download (v2)
# preferred_download_fromEmail_newSince(PathToDownloadTo, Email, numberDays)
## Extension to preferred download function; download only files from Email newer than numberDays
sub preferred_download_fromEmail_newSince {
  my ($self, $path, $email, $since) = @_;

  return(0)
    if (! $self->set_EmailAge($since));

  return($self->preferred_download_newSince($path, $since));
}


########## download (v2)
# continuous_preferred_download(PathToDownloadTo, CheckInterval)
## Download all content from any source continously (checking every CheckInterval seconds)
# Warning: tool will not exit from this mode
sub continuous_preferred_download {
  my ($self, $path, $checki) = @_;

  return(0)
    if (! $self->set_ContinuousRun());

  return(0)
    if (! $self->set_ScanFrequency($checki));

  return($self->preferred_download($path));
}


########## download (v2)
# continuous_preferred_download_fromEmail(PathToDownloadTo, Email, CheckInterval)
## Download all content from selected source continously (checking every CheckInterval seconds)
# Warning: tool will not exit from this mode
sub continuous_preferred_download_fromEmail {
  my ($self, $path, $email, $checki) = @_;

  return(0)
    if (! $self->set_SenderEmail($email));

  return($self->continuous_preferred_download($path, $checki));
}


################################################################################
########################################

sub reset {
  for (my $i = 0; $i < scalar @modes; $i++) { $_[0]->{$modes[$i]} = {}; }
  for (my $i = 0; $i < scalar @post_modes; $i++) { $_[0]->{$post_modes[$i]} = {}; }
}


############################################################
####################

sub get_section {
  # 0: self
  # 1: mode
  # 2: section name
  # 3: pre-text

  my $txt = "[" . $_[2] . "]\n";
  $txt .= $_[3];
  foreach my $cmd (sort keys %{$_[0]->{$_[1]}}) {
    my $v = ${$_[0]->{$_[1]}}{$cmd};
    next if (MMisc::is_blank($v));
    $txt .= "$cmd = $v\n";
  }

  return($txt);
}

##

sub obtain_configfile {
  # 0: self
  # 1: mode
  # 2: pre-text
  # 3: post-text

  my $tmpfile = MMisc::get_tmpfilename();
  open FILE, ">$tmpfile"
    or return($_[0]->_set_error_and_return("Problem creating configuration file ($tmpfile) : $!", 0));
  print FILE $_[2] . "\n";
  print FILE $_[0]->get_section($_[1], 'configuration', "Task = " . $_[1] . "\n") . "\n";
  print FILE $_[3] . "\n";
  close FILE;

  return($tmpfile);
}

##########

sub runtool {
  #0: self
  #1: cfg file

  if ($_[0]->{dbg_donotrun} == 1) {
    MMisc::warn_print("\"DO NOT RUN\" requested, config file location: " . $_[1] . "\n");
    return(1);
  }

  if ($_[0]->{dbg_showlogpath} == 1) {
    print "[Log file will be found at: " . $_[1] . ".log]\n";
  }

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

sub __set_value { 
  #0: self
  #1: array ref to ok versions
  #2: array ref to modes list
  #3: option name
  #4: option value

  # check this option is available for the tool's version
  my $v = $_[0]->{toolv};
  my $ok = 0;
  for (my $i = 0; $i < scalar @{$_[1]}; $i++) {
    $ok++ if ($v == ${$_[1]}[$i]);
  }
  return($_[0]->_set_error_and_return("The option \'" . $_[3] ."\' is not available for this tool version ($v), it only work for: " . join(" ", @{$_[1]})), 0)
    if (! $ok);

  for (my $i = 0; $i < scalar @{$_[2]}; $i++) {
    ${$_[0]->{${$_[2]}[$i]}}{$_[3]} = $_[4];
  }

  return(1);
}

##

sub __set_mail {
  my ($self, $versions, $mode, $option, @emails) = @_;
  return(0) if ($self->check_bad_emails(@emails));
  return($self->__set_value($versions, $mode, $option, join(",", @emails)));
}

##

sub __set_file_r { 
  my $t = MMisc::get_file_full_path($_[4]);
  return($_[0]->__set_with_constraint($_[1], $_[2], $_[3], $t, (MMisc::is_file_r($t)), MMisc::check_file_r($t)));
}

##

sub __set_dir_w { 
  my $t = MMisc::get_file_full_path($_[4]);
  return($_[0]->__set_with_constraint($_[1], $_[2], $_[3], $t, (MMisc::is_dir_w($t)), MMisc::check_dir_w($t)));
}

##

sub __set_path { return($_[0]->__set_value($_[1], $_[2], $_[3], MMisc::get_file_full_path($_[4]))); }

##

sub __set_mcq {
  my ($self, $versions, $mode, $option, $value, $rpossibles) = @_;
  my %h = MMisc::array1d_to_ordering_hash($rpossibles);
  return($_[0]->_set_error_and_return("Invalid \'$option\' value ($value), possible values: " . join(", ", @$rpossibles), 0))
    if (! exists $h{$value});
  return($_[0]->__set_value($_[1], $_[2], $_[3], $_[4]));
}  

##

sub __set_with_constraint {
  my ($self, $versions, $mode, $option, $value, $constraintmet, $errtxt) = @_;
  return($_[0]->_set_error_and_return("Invalid \'$option\' value ($value), $errtxt", 0))
    if (! $constraintmet);
  return($_[0]->__set_value($_[1], $_[2], $_[3], $_[4]));
}

#####

sub __set_option   { return($_[0]->__set_value($_[1], $_[2], $_[3], $_[4])); }
sub __unset_option { return($_[0]->__set_value($_[1], $_[2], $_[3], "")); }

#####

sub __binopt_true  { return($_[0]->__set_value($_[1], $_[2], $_[3], 1)); }
sub __binopt_false { return($_[0]->__set_value($_[1], $_[2], $_[3], 0)); }

##########

sub __set_PostScript {
  my ($self, $rv, $rm) = MMisc::shiftX(3, \@_);
  my @tmp = MMisc::shiftX(6, \@_);
  my ($type, $name, $call, $runc, $wfr, $fm) = MMisc::iuav(\@tmp, '', '', '', 'RunOnSuccess', 0, 'FailTask');

  # Type
  return(0)
    if (! $self->__set_mcq($rv, $rm, 'Type', $type, ['exe', 'shell', 'python']));
  # Name
  return(0) 
    if (! $self->__set_file_r($rv, $rm, 'Name', $name));
  # Call
  if ($type eq 'python') {
    return($self->_set_error_and_return("\'Call\' must be set if \'Type\' is set to \"python\"", 0))
      if (MMisc::is_blank($call));
    return(0)
      if (! $self->__set_value($rv, $rm, 'Call', $call));
  }
  # RunCondition
  return(0)
    if (! $self->__set_mcq($rv, $rm, 'RunCondition', $runc, ['RunAlways', 'RunOnSuccess', 'RunOnFailure']));
  # WaitForResult
  return(0)
    if (! $self->__set_with_constraint($rv, $rm, 'WaitForResult', $wfr, (($wfr == 0) || ($wfr == 1)), "value must 0 or 1"));
  # FailureMode
  return(0)
    if (! $self->__set_mcq($rv, $rm, 'FailureMode', $fm, ['FailTask', 'IgnoreFailure']));

  # No 'Parameter' ? Done
  return(1) if (scalar @_ == 0);

  for (my $i = 1; $i < 1 + scalar @_; $i++) {
    return(0)
      if (! $self->__set_value($rv, $rm, "Parameter$i", $_[$i - 1]));
  }

  return(1);
}

############################################################

sub __get_tool_major_version {
  my ($tool) = @_;
  # The tool does not answer the --version command line option, so the way to get this
  # information is to check in the help for v1 only options

  my @cmd = ($tool, '--help');
  
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call(@cmd);

  return(1) if ($stdout =~ m%LOCATIONLABEL%);
  return(2) if ($stdout =~ m%AAAgent\sVersion\s\=\s2\.%);

  return(0);
}

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
