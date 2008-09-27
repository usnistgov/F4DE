package CSVHelper;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# CSV Helper Functions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CSVHelper.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

use Text::CSV;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CSVHelper.pm Version: $version";

########## No 'new' ... only functions to be useful

sub get_csv_handler {
  my $qc = shift @_;

  my $csv = undef;
  my %options = ();
  $options{always_quote} = 1;
  $options{binary} = 1;
  if (! MMisc::is_blank($qc)) {
    return($csv) 
      if (length($qc) > 1);
    $options{quote_char}  = $qc;
    $options{escape_char} = $qc;
  }
  $csv = Text::CSV->new(\%options);

  return($csv);
}

#####

sub array2csvtxt {
  my ($ch, @array) = @_;

  return(undef)
    if (! defined $ch);

  return(undef)
    if (! $ch->combine(@array));

  my $txt = $ch->string();
  return($txt);
}

#####

sub csvtxt2array {
  my ($ch, $value) = @_;

  return(undef)
    if (! defined $ch);

  return(undef)
    if (! $ch->parse($value));

  my @columns = $ch->fields();
  return(@columns);
}

########################################

1;
