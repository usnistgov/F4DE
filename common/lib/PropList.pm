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
     KEYS       => undef,       # the key hash (and default values)
     type       => undef,       # the key special type
     fixfunc    => undef,       # fix function
     authval    => undef,       # list of authorized values per key
     authfunc   => undef,       # list of authorized functions per key
     errormsg   => $errormsg,
    };
  
  bless $self;
  return $self;
}

##########
my $rule = '[a-zA-Z0-9_\-\.]+';
my @ok_types = ('scalar', 'array', 'hash', 'array of array', 'array of hash');

sub __checkA {
  return(0) if (! (${$_[1]} =~ m%^\@?\@\d*$%));
  
  my $type = (${$_[1]} =~ m%^\@\@%) ? $ok_types[3] : $ok_types[1];
  if (${$_[1]} =~ m%^\@?\@(\d+)$%) {
    ${$_[1]} = join(':', $type, $1);
  } else {
    ${$_[1]} = join(':', $type, '');
  }
  
  return(1);
}

##

sub __checkH {
  return(0) if (! (${$_[1]} =~ m%^\@?\%($rule)(\:$rule)*$%));
  
  my $type = (${$_[1]} =~ m%^\@\%%) ? $ok_types[4] : $ok_types[2];
  ${$_[1]} =~ s%^\@?\%%%;
  ${$_[1]} = join(':', $type, ${$_[1]});
  
  return(1);
}

##

sub __getKTF {
  my ($self, $key, $T, $F) = @_;
#  print "[$key / $T / $F]\n";

  if ($key =~ s%((\@?\@|\@?\%|\&)[^\@\%\&]*)$%%) {
    my $tmp = $1;
    if ($tmp =~ s%^\&%%) {
      return($_[0]->_set_error_and_return_array("multiple fix functions  ($tmp / $F)", 
                                                $key, $T, $tmp))
        if (! MMisc::any_blank($F, $tmp));
      return($_[0]->__getKTF($key, $T, $tmp));
    } elsif ($tmp =~ m%^\@?\%%) {
      return($_[0]->_set_error_and_return_array("multiple types ($tmp / $T)", $key, $tmp, $F))
        if (! MMisc::any_blank($T, $tmp));
      return($_[0]->_set_error_and_return_array("Invalid hash definition ($tmp)", $key, $tmp, $F))
        if ($_[0]->__checkH(\$tmp) == 0);
      return($_[0]->__getKTF($key, $tmp, $F));
    } elsif ($tmp =~ m%^\@?\@%) {
      return($_[0]->_set_error_and_return_array("multiple types ($tmp / $T)", $key, $T, $F))
        if (! MMisc::any_blank($T, $tmp));
      return($_[0]->_set_error_and_return_array("Invalid array definition ($tmp)", $key, $tmp, $F)) if ($_[0]->__checkA(\$tmp) == 0);
      return($_[0]->__getKTF($key, $tmp, $F));
    } else {
      return($_[0]->_set_error_and_return_array("unknown entry ($tmp)", $key, $T, $F));
    }  
  }

  return($self->_set_error_and_return_array("key ($key) can only contain characters that match m\%\^$rule\$\%", $key, $T, $F)) if (! ($key =~ m%^$rule$%));
  
  return($key, $T, $F);
}

##
  
sub addProp {
  my ($self, $fkey, $defaultValue, @authorized_values) = @_;
#  print "[$fkey]\n";

  my ($key, $type, $func) = $_[0]->__getKTF($fkey, '', '');
  return(0) if ($self->error());
#  print "[$fkey] -> [$key/$type/$func]\n";
  
  return($self->_set_error_and_return_scalar("Already added a definition for this key ($key)", 0)) if (exists $self->{KEYS}{$key});

  @{$self->{type}{$key}} = (MMisc::is_blank($type)) ? ($ok_types[0]) : split(m%\:%, $type);
  $type = $self->{type}{$key}[0];

  $self->{fixfunc}{$key} = $func
    if (! MMisc::is_blank($func));

  if (scalar @authorized_values > 0) {
    for (my $i = 0; $i < scalar @authorized_values; $i++) {
      my $v = $authorized_values[$i];
      if ($v =~ m%^\&%) {
        push @{$self->{authfunc}{$key}}, $v;
      } else {
        push @{$self->{authval}{$key}}, $v;
      }
    }
  }
    
  if (defined $defaultValue) {
    $_[0]->__setXvalue('KEYS', $key, $defaultValue, 0);
  } else {
    if ($type eq $ok_types[0]) {
      $self->{KEYS}{$key} = undef;
    } elsif (($type eq $ok_types[1]) || ($type eq $ok_types[3]) || ($type eq $ok_types[4])) {
      @{$self->{KEYS}{$key}} = ();
    } elsif ($type eq $ok_types[2]) {
      %{$self->{KEYS}{$key}} = ();
    }
  }

  return(1);
}

##########

sub __checkAV {
  my ($self, $value, @av) = @_;

  my $ok = 0;
  for (my $i = 0; $i < scalar @av && $ok == 0; $i++) {
    my $v = $av[$i];
    if ($value =~ m%^$v$%i) { $ok++; }
  }

  return($ok);
}

##


sub __setXvalue {
  my ($self, $keyname, $key, $value, $dochecks) = @_;

  if ($dochecks) {
    $self->_set_error_and_return_scalar("Key ($key) does not exist in Defined list. ", 0)
      if (! exists $self->{$keyname}{$key});

    # run the fix function (if any)
    if (! MMisc::is_blank($self->{fixfunc}{$key})) {
      my $rsf = $self->{fixfunc}{$key};
      $value = &{\&$rsf}($value);
    }
  
    my $found = 0;
    my @av = ();
    if ($value =~ m%^\&%) { # enable call to 'main::function'. Syntax: &text=main::function
      return($self->_set_error_and_return_scalar("Can not add a function call as a value ($value) as none is set for key ($key). ", 0))
      if (! exists $self->{authfunc}{$key});
      @av = @{$self->{authfunc}{$key}};
      my $comp = $value;
      $comp =~ s%(\=).+$%$1%;
      $found = $self->__checkAV($comp, @av);
    } else {
      # check against authorized keys list (if any)
      if (exists $self->{authval}{$key}) {
        @av = @{$self->{authval}{$key}};
        $found = $self->__checkAV($value, @av);
      }
    }
    return($self->_set_error_and_return_scalar("Value ($value) not in the authorized list (" . join(", ", @av) . ") for key ($key). ", 0))
      if ((scalar @av > 0) && ($found == 0));

  } # dochecks

  my @tc = @{$self->{type}{$key}};
#  print join(" | ", @tc) . "\n";
  my $type = shift @tc;
  if ($type eq $ok_types[0]) { # scalar
    $self->{$keyname}{$key} = $value;
  } elsif (($type eq $ok_types[1]) || ($type eq $ok_types[3])) { # array / array of array
    my @split = split(m%\:%, $value);
#    print join(" ", @tc) . " / " . scalar @split . "\n";
    if (scalar @tc > 0) {
      my $nc = $tc[0];
#      print scalar @split . " -- $nc\n";
      return($self->_set_error_and_return_scalar("Can not set the array value as requested, expecting $nc components, got " . scalar @split . ". ", 0))
        if (scalar @split != $nc);
    }
    if ($type eq $ok_types[1]) {
      @{$self->{$keyname}{$key}} = @split;
    } else {
      push @{$self->{$keyname}{$key}}, \@split;
    }
  } elsif (($type eq $ok_types[2]) || ($type eq $ok_types[4])) { # hash
    my @split = split(m%\:%, $value);
    return($self->_set_error_and_return_scalar("Can not set the array hash as requested, expecting " . scalar @tc . " components, got " . scalar @split . ". ", 0))
      if (scalar @split != scalar @tc);
    my %h = (); for (my $i = 0; $i < scalar @tc; $i++) { $h{$tc[$i]} = $split[$i]; }
    if ($type eq $ok_types[2]) {
      %{$self->{$keyname}{$key}} = %h;
    } else {
      push @{$self->{$keyname}{$key}}, \%h;
    }
  } else {
    return($self->_set_error_and_return_scalar("Unknown internal type (" . $self->{type}{$key}[0] . "). ", 0));
  }
      
  return(1);
}

##########

sub setValue { $_[0]->__setXvalue('KEYS', $_[1], $_[2], 1); }


#####

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

sub getType {
  return($_[0]->_set_error_and_return_scalar("Key (" . $_[1] . ") does not exist in Defined List", undef))
    if (! exists $_[0]->{KEYS}{$_[1]});

  return($_[0]->{type}{$_[1]}[0]);
}

#####

sub getValue {
  return($_[0]->_set_error_and_return_scalar("Key (" . $_[1] . ") does not exist in Defined List", undef))
    if (! exists $_[0]->{KEYS}{$_[1]});

  my $type = $_[0]->{type}{$_[1]}[0];
  if ($type eq $ok_types[0]) { # scalar 
    return($_[0]->{KEYS}{$_[1]});
  } elsif (($type eq $ok_types[1]) || ($type eq $ok_types[3]) || ($type eq $ok_types[4])) { # array / array of array/hash
    return(@{$_[0]->{KEYS}{$_[1]}});
  } elsif ($type eq $ok_types[2]) { # hash
    return(%{$_[0]->{KEYS}{$_[1]}});
  }

  return($_[0]->_set_error_and_return_scalar("Invalid type ($type) for Key (" . $_[1] . ")", undef))
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

  my @out = ();
  push @out, @{$self->{authval}{$key}}
    if (exists $self->{authval}{$key});
  push @out, @{$self->{authfunc}{$key}}
    if (exists $self->{authfunc}{$key});

  return(@out);
}

############################################################

sub __UT_gray2grey { $_[0] =~ s%gray%grey%; return($_[0]); }

sub unit_test {
  my $makecall = shift @_;
  
  print "Testing PropList ..." if ($makecall);
  
  my @err = ();
  my $cl = "PropList";
  
  my $p = new PropList();
  push @err, "Error: $cl: Unable to add a key: " . $p->get_errormsg()
    if (! $p->addProp("key1", undef));
  $p->clear_error();

  push @err, "Error: $cl: Unable to add a key:" . $p->get_errormsg()
    if (! $p->addProp("key2", 'value2'));
  $p->clear_error();
  
  push @err, "Error: $cl: re-add of 'key1' succeeded but shouldn't have:" . $p->get_errormsg()
    if ($p->addProp("key1", undef));
  $p->clear_error();
  
  if ($p->addProp("key3", undef, (1,2,3))) {
    push @err, "Error: $cl: Could not add 'key3' value:" . $p->get_errormsg()
      if (! $p->setValue("key3", 1));
    $p->clear_error();
    
    push @err, "Error: $cl: Should not have been authorized to add a 'key3' value:" . $p->get_errormsg()
      if ($p->setValue("key3", 11));
  }
  $p->clear_error();

  ## Function value
  push @err, "Error: $cl: Unable to add a special \&Function authorized value: " . $p->get_errormsg()
    if (! $p->addProp("funckey", undef, "\&Function="));
  $p->clear_error();

  my $name = "\&Function=PropList::unit_test";
  push @err, "Error: $cl: Unable to set the \&Function value: " . $p->get_errormsg()
    if (! $p->setValue("funckey", $name));
  $p->clear_error();

  my $v = $p->getValue("funckey");
  push @err, "Error: $cl: Obtained value for \&Function is invalid (exp: $name / got: $v): " . $p->get_errormsg()
    if ($v ne $name);
  $p->clear_error();

  ## Array type
  push @err, "Error: $cl: Unable to add a key of array type: " . $p->get_errormsg()
    if (! $p->addProp("arraytest@", undef));
  $p->clear_error();

  my @res = $p->getValue('arraytest');
  push @err, "Error: $cl: Expected an empty array, got some data: " . join(" ", @res)
    if (scalar @res > 0);

  my @exp = (1, 2, 3);
  push @err, "Error: $cl: Unable to set the array type value: " . $p->get_errormsg()
    if (! $p->setValue("arraytest", join(":", @exp)));
  $p->clear_error();

  @res = $p->getValue('arraytest');
  for (my $i = 0; $i < scalar @exp; $i++) {
    push @err, ("Error: $cl: Invalid array value (exp: " . $exp[$i] . " / got: " . $res[$i] . ") ") if ($exp[$i] ne $res[$i]);
  }

  ## Array type with a default value
  @exp = ("val1", "val2", "val3", "val4");
  push @err, "Error: $cl: Unable to add a key of array type: " . $p->get_errormsg()
    if (! $p->addProp("arraytest2\@4", join(':', @exp)));
  $p->clear_error();

  @res = $p->getValue('arraytest2');
  for (my $i = 0; $i < scalar @exp; $i++) {
    push @err, ("Error: $cl: Invalid array value (exp: " . $exp[$i] . " / got: " . $res[$i] . ") ") if ($exp[$i] ne $res[$i]);
  }

  ## Array with a set number of arguments
  push @err, "Error: $cl: Unable to add a key of sized array type: " . $p->get_errormsg()
    if (! $p->addProp("Sarraytest\@2", undef));
  $p->clear_error();

  push @err, "Error: $cl: Should not have been authorized to add wrong sized array type value"
    if ($p->setValue("Sarraytest", join(":", @exp)));
  $p->clear_error();
  
  push @err, "Error: $cl: Was not able to set a sized array type value: " . $p->get_errormsg()
    if (! $p->setValue("Sarraytest", join(":", @exp[0..1])));
  $p->clear_error();
  
  ## Hash
  my @testh_k = ( 'key1', 'key2', 'key3');
  my @testh_v = ( 'val1', 'val2', 'val3' );
  push @err, "Error: $cl: Unable to add a key of hash type: " . $p->get_errormsg()
    if (! $p->addProp("hashtest\%" . join (":", @testh_k), undef));
  $p->clear_error();

  push @err, "Error: $cl: Unable to set the hash type value: " . $p->get_errormsg()
    if (! $p->setValue("hashtest", join(":", @testh_v)));
  $p->clear_error();

  my %hres = $p->getValue('hashtest');
  for (my $i = 0; $i < scalar @testh_k; $i++) {
    my $exp = $testh_v[$i];
    my $res = $hres{$testh_k[$i]};
    push @err, ("Error: $cl: Invalid array value (exp: $exp / got: $res) ")
      if ($exp[$i] ne $res[$i]);
  }
 
  ## Fix function
  push @err, "Error: $cl: Unable to add a fixfunc key:" . $p->get_errormsg()
    if (! $p->addProp('fixfunc&PropList::__UT_gray2grey', undef, ('grey', 'color')));
  
  push @err, "Error: $cl: Unable to add a key that ought to have been fixed: " . $p->get_errormsg()
    if (! $p->setValue('fixfunc', 'gray'));
  $p->clear_error();

  # check that we got 'grey'
  my $v = $p->getValue("fixfunc");
  push @err, "Error: $cl: Obtained value for was not fixed as expected (exp: grey / got: $v): " . $p->get_errormsg()
    if ($v ne 'grey');
  $p->clear_error();

  # try to use a non authorized value
  push @err, "Error: $cl: Should not have authorized to add a non listed key: " . $p->get_errormsg()
    if ($p->setValue('fixfunc', 'red'));
  $p->clear_error();
  
  # regexp check
  push @err, "Error: $cl: Unable to add a key with regexp authorized values:" . $p->get_errormsg()
    if (! $p->addProp('regcheck', undef, ('A\d\d', 'B\d\d\d', 'C\d+', 'Extra')));
  
  push @err, "Error: $cl: Should have been able to add a value matched against regexp: " . $p->get_errormsg()
    if (! $p->setValue('regcheck', 'A01'));
  $p->clear_error();

  push @err, "Error: $cl: Should NOT have been able to add a value matched against regexp: " . $p->get_errormsg()
    if ($p->setValue('regcheck', 'A012'));
  $p->clear_error();

  push @err, "Error: $cl: Should NOT have been able to add a value not in regexp list: " . $p->get_errormsg()
    if ($p->setValue('regcheck', 'D012'));
  $p->clear_error();

  push @err, "Error: $cl: Should have been able to add value : " . $p->get_errormsg()
    if (! $p->setValue('regcheck', 'Extra'));
  $p->clear_error();

  ## Array of array
  push @err, "Error: $cl: Unable to add a key of array of array type: " . $p->get_errormsg()
    if (! $p->addProp("aoa\@\@2", undef));
  $p->clear_error();

  my @res = $p->getValue('aoa');
  push @err, "Error: $cl: Expected an empty array, got some data: " . join(" ", @res)
    if (scalar @res > 0);

  my @exp1 = (1, 2);
  my @exp2 = (3, 4);
  push @err, "Error: $cl: Unable to set the array of array value: " . $p->get_errormsg()
    if (! $p->setValue("aoa", join(":", @exp1)));
  $p->clear_error();
  push @err, "Error: $cl: Unable to set the array of array value: " . $p->get_errormsg()
    if (! $p->setValue("aoa", join(":", @exp2)));
  $p->clear_error();
  push @err, "Error: $cl: was able to set an array of array value with more elements than authorized: " . $p->get_errormsg()
    if ($p->setValue("aoa", join(":", @exp1, @exp2)));
  $p->clear_error();

  my @aoa_res = $p->getValue('aoa');
  if (scalar @aoa_res != 2) {
    push @err, "Error: $cl: For array of array, did not find two elements, found " . scalar @aoa_res;
  } else {
    my @a = @{$aoa_res[0]}; push @a, @{$aoa_res[1]};
    my @b = @exp1; push @b, @exp2;
    for (my $i = 0; $i < scalar @a; $i++) {
      push (@err, "Error: $cl: For array of array, did not expected value (" . $b[$i] . "), found: " . $a[$i]) if ($a[$i] ne $b[$i]);
    }
  }

  ## Array of hash
  push @err, "Error: $cl: Unable to add a key of array of hash type: " . $p->get_errormsg()
    if (! $p->addProp("aoh\@\%" . join (":", @testh_k), undef));
  $p->clear_error();
  
    push @err, "Error: $cl: Unable to set an array of hash value: " . $p->get_errormsg()
    if (! $p->setValue("aoh", join(":", @testh_v)));
  $p->clear_error();

  push @err, "Error: $cl: Unable to set an array of hash value: " . $p->get_errormsg()
    if (! $p->setValue("aoh", join(":", @testh_k)));
  $p->clear_error();

  push @err, "Error: $cl: Should not have been able to set an array of hash value"
    if ($p->setValue("aoh", join(":", @testh_k, @testh_v)));
  $p->clear_error();
  
  my @aoh_res = $p->getValue('aoh');
  if (scalar @aoh_res != 2) {
    push @err, "Error: $cl: For array of hash, did not find two elements, found " . scalar @aoh_res;
  } else {
    my %a = %{$aoh_res[0]};
    for (my $i = 0; $i < scalar @testh_k; $i++) {
      my $k = $testh_k[$i]; my $e = $testh_v[$i]; my $v = $a{$k};
      push (@err, "Error: $cl: For array of hash, did not find expected value ($e) for key ($k), found: $v") if ($v ne $e);
    }
    my %a = %{$aoh_res[1]};
    for (my $i = 0; $i < scalar @testh_k; $i++) {
      my $k = $testh_k[$i]; my $e = $testh_k[$i]; my $v = $a{$k};
      push (@err, "Error: $cl: For array of hash, did not find expected value ($e) for key ($k), found: $v") if ($v ne $e);
    }
  }
  

  ## 
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

    my @tc = @{$self->{type}{$key}};
    my $type = shift @tc;
    print "type: $type";
    if ($type eq $ok_types[0]) {
      print "\n";
    } elsif (($type eq $ok_types[1]) || ($type eq $ok_types[3])) {
      print (" (of " . $tc[0] . " elements)") if (scalar @tc > 0);
      print "\n";
    } elsif (($type eq $ok_types[2]) || ($type eq $ok_types[4])) {
      print "\n  keys: " . join(" ", @tc) . "\n";
    } else {
      print "type: UNKNOWN\n";
    }

    if (exists $self->{fixfunc}{$key}) {
      print "Key fixing function: " . $self->{fixfunc}{$key} . "\n";
    }

    my @av = $self->getAuthorizedValues($key);
    print "Authorized Values (", scalar @av, "):\n" if (scalar @av > 0);
    my $i = 1;
    for (my $k = 0; $k < scalar @av; $k++) {
      my $a = $av[$k];
      print "  ", $i++, " : ", ((defined $a) ? $a : "undef"), "\n";
    }


    if ($type eq $ok_types[0]) {
      my $v = $self->getValue($key);
      print "Value: ", ((defined $v) ? $v : "undef"), "\n";
      print "\n";
    } elsif (($type eq $ok_types[1]) || ($type eq $ok_types[3]) || ($type eq $ok_types[4])) {
      my @v = $self->getValue($key);
      print "Value: " . MMisc::get_sorted_MemDump(\@v) . "\n";
    } elsif ($type eq $ok_types[2]) {
      my %v = $self->getValue($key);
      print "Value: " . MMisc::get_sorted_MemDump(\%v) . "\n";
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
