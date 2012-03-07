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

use MErrorH;
use MMisc;
use Text::CSV;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CSVHelper.pm Version: $version";

########################################

## Constructor
sub new {
  my ($class, $qc, $sc) = @_;

  my %options = ();
  $options{always_quote} = 1;
  $options{binary} = 1;

  my $csvh = undef;

  if ((defined $qc) && (length($qc) > 0)) {
    $options{quote_char}  = $qc;
    $options{escape_char} = $qc;
  }

  $options{sep_char} = $sc
    if ((defined $sc) && (length($sc) > 0));

  $csvh = Text::CSV->new(\%options);

  my $errortxt = "";
  if (! defined $csvh) {
    $errortxt = "Problem creating CSV handler: " . Text::CSV->error_diag();
  }

  my $errorh = new MErrorH("CSVHelper");
  $errorh->set_errormsg($errortxt);
  my $errorv = $errorh->error();

  my $self =
    {
     csvh            => $csvh,
     col_nbr         => undef,
     errorv          => $errorv,
     errorh          => $errorh,
    };

  bless $self;
  return($self);
}

#####

sub set_number_of_columns {
  # arg 0: self
  # arg 1: number of columns

  return(0) if ($_[0]->{errorv});
  
  return($_[0]->_set_error_and_return("\'column number\' can not be less than 1", 0))
    if ($_[1] < 1);

  $_[0]->{col_nbr} = $_[1];

  return(1);
}

#####

sub get_number_of_columns {
  # arg 0 : self
  return($_[0]->{col_nbr}); 
}

#####

sub array2csvline {
  # arg 0 : self
  # rest  : array
  my $self = shift @_;

  return($self->_set_error_and_return("Given number of elements in array (" . scalar @_ . ") is different from expected number (" . $self->{col_nbr} . ")", undef))
    if ((defined $self->{col_nbr}) && ($self->{col_nbr} != scalar @_));

  return($self->_set_error_and_return
         ("Problem adding elements to CSV: " 
          . $self->{csvh}->error_diag() . " (" . $self->{csvh}->error_input() . ")"
          , undef))
    if (! $self->{csvh}->combine(@_));

  return($self->{csvh}->string());
}

#####

sub csvline2array {
  # arg 0 : self
  # arg 1 : value

  my @bad = ();
  return($_[0]->_set_error_and_return
         ("Problem obtaining array from CSV line [" . $_[1] . "]: " 
          . $_[0]->{csvh}->error_diag() . " (" . $_[0]->{csvh}->error_input() . ")"
          , @bad))
    if (! $_[0]->{csvh}->parse($_[1]));

  my @columns = $_[0]->{csvh}->fields();
  return($_[0]->_set_error_and_return("Number of elements in extracted array (" . scalar @columns . ") is different from expected number (" . $_[0]->{col_nbr} . ")", @bad))
    if ((defined $_[0]->{col_nbr}) && ($_[0]->{col_nbr} != scalar @columns));

  return(@columns);
}

#####

sub csvline2hash {
  # arg 0 : self
  # arg 1 : value
  # arg 2 : reference to array of columns headers

  my @columns = $_[0]->csvline2array($_[1]);
  return() if ($_[0]->{errorv});
  my %out = ();
  for (my $i = 0; $i < scalar @{$_[2]}; $i++) {
    $out{${$_[2]}[$i]} = $columns[$i];
  }

  return(%out);
}

##########

sub __loadCSV {
  # arg 0 : self
  # arg 1 : file name

  my $err = MMisc::check_file_r($_[1]);
  return("Problem with file ($_[1]): $err")
    if (! MMisc::is_blank($err));

  open CSV, "<" . $_[1]
    or return("Problem while opening file ($_[1]): $!");
 
  return("");
}

#####

sub loadCSV_getheader {
  # arg 0 : self
  # arg 1 : file name

  my @h = ();
  my $err = $_[0]->__loadCSV($_[1]);
  return($_[0]->_set_error_and_return($err, @h))
    if (! MMisc::is_blank($err));

  my $line = <CSV>;
  close CSV;

  return($_[0]->csvline2array($line));
}

#####

sub loadCSV_tohash {
  # arg 0 : self
  # arg 1 : file name
  my $self = shift @_;
  my $file = shift @_;
  # rest : keys order

  my %out = ();

  my $err = $self->__loadCSV($file);
  return($self->_set_error_and_return($err, %out))
    if (! MMisc::is_blank($err));
 
  my $line = <CSV>;

  my @headers = $self->csvline2array($line);
  return(%out) if ($self->{errorv});

  my %pos = ();
  for (my $i = 0; $i < scalar @headers; $i++) {
    $pos{$headers[$i]} = $i;
  }

  my @nf = ();
  my %rh = MMisc::clone(%pos);
  my %nd = ();
  for (my $i = 0; $i < scalar @_; $i++) {
    my $h = $_[$i];
    if (! exists $pos{$h}) {
      push @nf, $h;
      next;
    }
    $nd{$h} = $pos{$h};
    delete $rh{$h};
  }
  return($self->_set_error_and_return("Could not find requested headers: " . join(", ", @nf), %out))
    if (scalar @nf > 0);

  my $doa = scalar(keys %rh); # do filled array or do increments ?

  $self->set_number_of_columns(scalar @headers);
  return(%out) if ($self->{errorv});

  my $cont = 1;
  my $code = "";
  while ($cont) {
    my $line = <CSV>;
    if (MMisc::is_blank($line)) {
      $cont = 0;
      next;
    }
    
    my @array = $self->csvline2array($line);
    return(%out) if ($self->{errorv});

    if ($doa) {
#      my $bt = "push \@\{\$out";
#      for (my $i = 0; $i < scalar @_; $i++) {
#        my $h = $_[$i];
#        $bt .= "{\'" . $array[$pos{$h}] . "\'}";
#      }
#      
#      for (my $i = 0; $i < scalar @headers; $i++) {
#        my $h = $headers[$i];
#        next if (exists $nd{$h});
#        
#        my $v = $array[$i];
#        $code .= $bt . "{\'$h\'}}, \'$v\';\n";
#       }

     my @d = ();
     for (my $i = 0; $i < scalar @_; $i++) { push @d, $array[$pos{$_[$i]}]; }
     for (my $i = 0; $i < scalar @headers; $i++) {
       my $h = $headers[$i];
       next if (exists $nd{$h});
       my $v = $array[$i];
       MMisc::push_tohash(\%out, $v, @d, $h);
     }

    } else { # increment value
#      my $bt = "\$out";
#      for (my $i = 0; $i < scalar @_; $i++) {
#        my $h = $_[$i];
#        $bt .= "{\'" . $array[$pos{$h}] . "\'}";
#      }
#      $code .= $bt . "++;\n";

      my @d = ();
      for (my $i = 0; $i < scalar @_; $i++) { push @d, $array[$pos{$_[$i]}]; }
      MMisc::inc_tohash(\%out, @d);
    }
    
    $cont++;
  }
  close CSV;

#  print "** Code:\n$code\n";
#  return($self->_set_error_and_return("Do not have any code data to reload", %out))
#    if (MMisc::is_blank($code));
#  eval $code;
#  return($self->_set_error_and_return("Problem in \'CSVHelper::loadCSV_tohash\' eval-ing code : " . join(" | ", $@)))
#    if $@;

  return(%out);
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errorh}->set_errormsg($txt);
  $self->{errorv} = $self->{errorh}->error();
}

#####

sub get_errormsg {
  # arg 0: self
  return($_[0]->{errorh}->errormsg());
}

#####

sub error {
  # arg 0: self
  return($_[0]->{errorv});
}

#####

sub _set_error_and_return {
  my $self = shift @_;
  my $errormsg = shift @_;

  $self->_set_errormsg($errormsg);

  return(@_);
}

############################################################

1;
