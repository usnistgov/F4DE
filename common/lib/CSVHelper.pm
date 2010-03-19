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
  my ($class) = shift @_;
  my $qc = shift @_;
  my $sc = shift @_;

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
  my ($self, $n) = @_;

  return(0) if ($self->error());
  
  return($self->_set_error_and_return("\'column number\' can not be less than 1", 0))
    if ($n < 1);

  return(1);
}

#####

sub get_number_of_columns {
  my ($self) = @_;
  return($self->{col_nbr}); 
}

#####

sub array2csvline {
  my ($self, @array) = @_;

  my $cn  = $self->{col_nbr};
  return($self->_set_error_and_return("Given number of elements in array (" . scalar @array . ") is different from expected number ($cn)", undef))
    if ((defined $cn) && ($cn != scalar @array));

  my $ch = $self->{csvh};
  return($self->_set_error_and_return
         ("Problem adding elements to CSV: " 
          . $ch->error_diag() . " (" . $ch->error_input() . ")"
          , undef))
    if (! $ch->combine(@array));

  my $txt = $ch->string();

  return($txt);
}

#####

sub csvline2array {
  my ($self, $value) = @_;

  my @bad = ();

  my $ch = $self->{csvh};
  return($self->_set_error_and_return
         ("Problem obtaining array from CSV line [$value]: " 
          . $ch->error_diag() . " (" . $ch->error_input() . ")"
          , @bad))
    if (! $ch->parse($value));

  my @columns = $ch->fields();
  my $cn  = $self->{col_nbr};
  return($self->_set_error_and_return("Number of elements in extracted array (" . scalar @columns . ") is different from expected number ($cn)", @bad))
    if ((defined $cn) && ($cn != scalar @columns));

  return(@columns);
}

#####

sub csvline2hash {
  my ($self, $value, $rha) = @_;

  my @columns = $self->csvline2array($value);
  return() if ($self->error());
  my %out = ();
  for (my $i = 0; $i < scalar @$rha; $i++) {
    $out{$$rha[$i]} = $columns[$i];
  }

  return(%out);
}

##########

sub __loadCSV {
  my ($self, $file) = @_;

  my $err = MMisc::check_file_r($file);
  return("Problem with file ($file): $err")
    if (! MMisc::is_blank($err));

  open CSV, "<$file"
    or return("Problem while opening file ($file): $!");
 
  return("");
}

#####

sub loadCSV_getheader {
  my ($self, $file) = @_;

  my @h = ();
  my $err = $self->__loadCSV($file);
  return($self->_set_error_and_return($err, @h))
    if (! MMisc::is_blank($err));

  my $line = <CSV>;
  close CSV;

  return($self->csvline2array($line));
}

#####

sub loadCSV_tohash {
  my ($self, $file, @keysorder) = @_;

  my %out = ();

  my $err = $self->__loadCSV($file);
  return($self->_set_error_and_return($err, %out))
    if (! MMisc::is_blank($err));
 
  my $line = <CSV>;

  my @headers = $self->csvline2array($line);
  return(%out) if ($self->error());

  my %pos = ();
  for (my $i = 0; $i < scalar @headers; $i++) {
    $pos{$headers[$i]} = $i;
  }

  my @nf = ();
  my %nd = ();
  for (my $i = 0; $i < scalar @keysorder; $i++) {
    my $h = $keysorder[$i];
    push @nf, $h
      if (! exists $pos{$h});
    $nd{$h} = $pos{$h};
  }
  return($self->_set_error_and_return("Could not find requested headers: " . join(", ", @nf), %out))
    if (scalar @nf > 0);

  $self->set_number_of_columns(scalar @headers);
  return(%out) if ($self->error());

  my $cont = 1;
  my $code = "";
  while ($cont) {
    my $line = <CSV>;
    if (MMisc::is_blank($line)) {
      $cont = 0;
      next;
    }
    
    my @array = $self->csvline2array($line);
    return(%out) if ($self->error());

    my $bt = "push \@\{\$out";
    for (my $i = 0; $i < scalar @keysorder; $i++) {
      my $h = $keysorder[$i];
      $bt .= "{\'" . $array[$pos{$h}] . "\'}";
    }

  for (my $i = 0; $i < scalar @headers; $i++) {
    my $h = $headers[$i];
    next if (exists $nd{$h});

    my $v = $array[$i];
    $code .= $bt . "{\'$h\'}}, \'$v\';\n"
    }

    $cont++;
  }
  close CSV;

  return($self->_set_error_and_return("Do not have any code data to reload", %out))
    if (MMisc::is_blank($code));
#  print "** Code:\n$code\n";
  eval $code;

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
