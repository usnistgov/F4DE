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
#  whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST
# MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING
# MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

package PropList;

use strict;
use Data::Dumper;

sub new {
  my ($class) = @_;
  
  my $self =
    {
     KEYS       => undef, # The key hash (and default values)
     authval    => undef, # List of authorized values per key
     errormsg   => "",
    };
  
  bless $self;
  return $self;
}

##########

sub error {
  my ($self) = @_;

  return(1) if (! &_is_blank($self->get_errormsg()));

  return(0);
}

#####

sub get_errormsg {
  my ($self) = @_;

  return($self->{errormsg});
}

#####

sub _set_errormsg_txt {
  my ($oh, $add) = @_;

  my $txt = "$oh$add";

  $txt =~ s%\[PropList\]\s+%%g;

  return("") if (&_is_blank($txt));

  $txt = "[PropList] $txt";

  return($txt);
}

#####

sub _set_errormsg {
  my ($self, $txt) = @_;

  $self->{errormsg} = &_set_errormsg_txt($self->{errormsg}, $txt);
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
    if (! grep(m%^$value$%, @av)) {
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
    
    foreach my $key(keys %$ht){
        if (! $self->setValue($key, $ht->{$key})){
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
    return(0, undef);
  }

  return(1, $self->{KEYS}{$key});
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
    return(0);
  }

  return()
    if (! exists $self->{authval}{$key});

  return(@{$self->{authval}{$key}});
}

############################################################
    
sub unit_test {
  my $err = 0;
  my $cl = "PropList";
  
  my $p = new PropList();
  if (! $p->addProp("key1", undef)) {
    print STDERR "Error: $cl: Unable to add a key\n";
    $err++;
  }

  if (! $p->addProp("key2", 'value2')){
    print STDERR "Error: $cl: Unable to add a key\n";
    $err++;
  }

  if ($p->addProp("key1", undef)){
    print STDERR "Error: $cl: re-add of 'key1' succeeded but shouldn't have\n";
    $err++;
  }
  
  if ($p->addProp("key3", undef, (1,2,3))) {
    if (! $p->setValue("key3", 1)) {
      print STDERR "Error: $cl: Could not add 'key3' value\n";
      $err++;
    }
    if ($p->setValue("key3", 11)) {
      print STDERR "Error: $cl: Could had a not authorized 'key3' value\n";
      $err++;
    }
  }
  
 # $p->_display();
  $p->printPropList();

  print STDERR "$err Unit Test Errors\n";

  return($err);
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
  
  foreach my $key (sort @pl) {
    print "KEY: $key\n";
    my $v = $self->getValue($key);
    print "Value: ", ((defined $v) ? $v : "undef"), "\n";
    my @av = $self->getAuthorizedValues($key);
    print "Authorized Values (", scalar @av, "):\n" if (scalar @av > 0);
    my $i = 1;
    foreach my $a (@av) {
      print $i++, " : ", ((defined $a) ? $a : "undef"), "\n";
    }
    print "\n";
  }
}

##########

sub _is_blank {
  my $txt = shift @_;
  return(($txt =~ m%^\s*$%));
}

################################################################################

1;
