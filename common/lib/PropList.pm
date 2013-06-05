# PropList.pm
# 
# Original Author: Jon Fiscus
# Extension Author: Martial Michel
#
# This software was developed at the National Institute of Standards and 
# Technology by employees of the Federal Government in the course of 
# their official duties.  Pursuant to Title 17 Section 105 of the 
# United States Code this software is not subject to copyright
# protection within the United States and is in the public domain.
#
# This is an experimental system.  NIST assumes no responsibility
#  whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST
# MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING
# MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

# $Id$

package PropList;

use strict;

use MErrorH;
use Data::Dumper;

sub new {
  my ($class) = @_;
  
  my $errormsg = new MErrorH("PropList");

  my $self =
    {
     KEYS       => undef,       # The key hash (and default values)
     authval    => undef,       # List of authorized values per key
     errormsg   => $errormsg,
    };
  
  bless $self;
  return $self;
}

##########

sub addProp {
  my ($self, $key, $defaultValue, @authorized_values) = @_;

  if (exists($self->{KEYS}{$key})) {
    $self->_set_errormsg("Already added a definition for this key ($key). ");
    return(0);
  }

  $self->{KEYS}{$key} = $defaultValue;

  @{$self->{authval}{$key}} = @authorized_values
    if (scalar @authorized_values > 0);

  return(1);
}

##########

sub setValue {
  my ($self, $key, $value) = @_;

  if (! exists $self->{KEYS}{$key}) {
    $self->_set_errormsg("Key ($key) does not exist in Defined list. ");
    return(0);
  }

  if (exists $self->{authval}{$key}) {
    my @av = @{$self->{authval}{$key}};
    my $found = 0;
    if ($value =~ m%^\&%) { # enable call to 'main::function'. Syntax: &text=main::function
      my $comp = $value;
      $comp =~ s%(\=).+$%$1%;
      $found = scalar(grep(m%^$comp%, @av));
    } else {
      $found = scalar(grep(m%^$value$%, @av));
    }
    if ($found == 0) {
      $self->_set_errormsg("Value ($value) not in the authorized list (" . join(",", @av) . ") for key ($key). ");
      return(0);
    }
  }

  $self->{KEYS}{$key} = $value;

  return(1);
}

##########

sub setValueFromHash(){
  my ($self, $ht) = @_;
  my $err = 0;
    
  my @tmp = keys %$ht;
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $key = $tmp[$i];
    if (! $self->setValue($key, $ht->{$key})) {
      $err ++; 
    }
  }
  ($err == 0) ? 1 : 0;
}

##########

sub getValue {
  my ($self, $key) = @_;

  if (! exists $self->{KEYS}{$key}) {
    $self->_set_errormsg("Key ($key) does not exist in Defined List. ");
    return(undef);
  }

  return($self->{KEYS}{$key});
}

##########

sub getPropList {
  my ($self) = @_;

  my @pl = keys %{$self->{KEYS}};

  return(@pl);
}

#####

sub getAuthorizedValues {
  my ($self, $key) = @_;

  if (! exists $self->{KEYS}{$key}) {
    $self->_set_errormsg("Key ($key) does not exist in Defined list. ");
    return();
  }

  return()
    if (! exists $self->{authval}{$key});

  return(@{$self->{authval}{$key}});
}

############################################################
    
sub unit_test {
  my $makecall = shift @_;
  
  print "Testing PropList ..." if ($makecall);
  
  my @err = ();
  my $cl = "PropList";
  
  my $p = new PropList();
  push @err, "Error: $cl: Unable to add a key"
    if (! $p->addProp("key1", undef));
  
  push @err, "Error: $cl: Unable to add a key"
    if (! $p->addProp("key2", 'value2'));
  
  push @err, "Error: $cl: re-add of 'key1' succeeded but shouldn't have"
    if ($p->addProp("key1", undef));
  
  if ($p->addProp("key3", undef, (1,2,3))) {
    push @err, "Error: $cl: Could not add 'key3' value\n"
      if (! $p->setValue("key3", 1));
    
    push @err, "Error: $cl: Should not have been authorized to add a 'key3' value\n"
      if ($p->setValue("key3", 11));
  }

  push @err, "Error: $cl: Unable to add a special \&Function key"
    if (! $p->addProp("funckey", undef, "\&Function="));

  my $name = "\&Function=PropList::unit_test";
  push @err, "Error: $cl: Unable to set the \&Function value"
    if (! $p->setValue("funckey", $name));

  my $v = $p->getValue("funckey");
  push @err, "Error: $cl: Obtained value for \&Function is invalid (exp: $name / got: $v)"
    if ($v ne $name);
  
  if (! $makecall) {
    # $p->_display();
    $p->printPropList();
    
    print STDERR scalar(@err) . " Unit Test Errors\n";
    
    return(scalar @err);
  }
  
  MMisc::error_quit(" failed\n" . join("\n", @err) . "\n")
      if (scalar @err > 0);

  MMisc::ok_quit(" OK");
}

##########

sub _display() {
  my ($self) = @_;

  print Dumper($self);
}

##########

sub printPropList {
  my ($self) = @_;

  my @pl = $self->getPropList();
  my @tmp = sort @pl;
  for (my $j = 0; $j < scalar @tmp; $j++) {
    my $key = $tmp[$j];
    print "KEY: $key\n";
    my $v = $self->getValue($key);
    print "Value: ", ((defined $v) ? $v : "undef"), "\n";
    my @av = $self->getAuthorizedValues($key);
    print "Authorized Values (", scalar @av, "):\n" if (scalar @av > 0);
    my $i = 1;
    for (my $k = 0; $k < scalar @av; $k++) {
      my $a = $av[$k];
      print $i++, " : ", ((defined $a) ? $a : "undef"), "\n";
    }
    print "\n";
  }
}

############################################################

sub printShortPropList {
    my ($self) = @_;
    
    my @pl = $self->getPropList();
    foreach my $prop (sort @pl) {
	print "$prop :: ".$self->getValue($prop);
	my @av = $self->getAuthorizedValues($prop);
	print " (".join(" | ", @av).")" if (scalar(@av) > 0);
	print "\n";
    }
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
