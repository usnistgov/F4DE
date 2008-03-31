package Framespan;

use strict;

## Constructor
sub new {
  my ($class) = shift @_;

  my $tmp = shift @_;
  my ($value, $errormsg) = _fs_check_value($tmp, 1);

  my $self =
    {
     value => $value,
     errormsg => $errormsg,
    };
  
  bless $self;
  return $self;
}

####################

sub _fs_check_value {
  my $value = shift @_;
  my $from_new = shift @_;

  if ($value eq "") {
    # If called from new, it is ok
    return ($value, "") if ($from_new);
    # Otherwise it should not happen
    return ("", "Must provide a non empty value");
  }

  # Split entry
  my @todo = split(/[\s|\t]+/, $value);

  foreach my $key (@todo) {
    return ("", "Entry is not a framespan")
      if ($key !~ m%^\d+\:\d+$%);
  }

  $value = join(" ", @todo);
  return ($value, "");
}

##########

sub set_value {
  my ($self, $tmp) = @_;

  my ($value, $errormsg) = _fs_check_value($tmp, 0);
  $self->_set_errormsg($errormsg) if ($errormsg ne "");

  $self ->{value} = $value;
}

##########

sub _set_errormsg {
  my ($self, $txt) = @_;

  $self->{errormsg} = $txt;
}

##########

sub get_value {
  my ($self) = @_;

  return ($self->{value});
}

##########

sub get_errormsg {
  my ($self) = @_;

  return ($self->{errormsg});
}

##########

sub _is_value_set {
  my ($self) = @_;

  return (0) if ($self->get_errormsg() ne "");

  my $v = $self->get_value();

  return (0)
    if ($v eq "");

  return (1);
}

####################

sub _fs_sort {
  return _fs_sort_core($a, $b);
}

sub _fs_sort_core {
  my ($a, $b) = @_;
  my ($b1) = ($a =~ m%^(\d+)\:%);
  my ($e1) = ($a =~ m%\:(\d+)$%);

  my ($b2) = ($b =~ m%^(\d+)\:%);
  my ($e2) = ($b =~ m%\:(\d+)$%);

  # Order by beginning first
  return ($b1 <=> $b2)
    if ($b1 != $b2);
  # by end if the beginning is the same
  return ($e1 <=> $e2);
}

##########

sub sort_cmp {
  my ($self, $other) = @_;

  return (_fs_sort_core($self->get_value(), $other->get_value()));
}

##########

sub reorder {
  my ($self) = @_;

  return (0) if ($self->get_errormsg() ne "");

  if (! $self->_is_value_set()) {
    $self->_set_errormsg("No framespan set");
    return(0);
  }

  my $fs = $self->get_value();

  my @ftodo = split(/[\s|\t]+/, $fs);

  my @o = sort _fs_sort @ftodo;

  if (scalar @ftodo != scalar @o) {
    $self->_set_errormsg("WEIRD: While reordering frames, did not find the same number of elements between the original array and the result array");
    return(0);
  }

  my $res = join(" ", @o);

  $self->set_value($res);

  return (1);
}

##########

sub _fs_shorten_check {
  my ($b, $e, $txt) = @_;

  return("badly formed range pair")
    if (($b =~ m%^\s*$%) || ($e =~ m%^\s*$%));
  
  return("framespan range pair values can not be negative")
    if (($b < 0) || ($e < 0));

  return("framespan range pair is not ordered")
    if ($e < $b);

  return("");
}

#####

sub shorten {
  my ($self) = @_;

  return (0) if ($self->get_errormsg() ne "");

  if (! $self->_is_value_set()) {
    $self->_set_errormsg("No framespan set");
    return(0);
  }

  my $fs = $self->get_value();

  my @ftodo = split(/[\s|\t]+/, $fs);

  my $ftc = scalar @ftodo;

  # no elements ?
  if ($ftc == 0) {
    $self->_set_errormsg("No values in framespan range");
    return(0);
  }

  my $entry = shift @ftodo;
  my ($b, $e) = ($entry =~ m%^(\d+)\:(\d+)$%);
  my $text = &_fs_shorten_check($b, $e, $entry);
  if ($text !~ m%^\s*$%) {
    $self->_set_errormsg($text);
    return (0);
  }

  # Only 1 element ?
  if ($ftc == 1) {
    $self->set_value($fs);
    return (1);
  }

  # More than one element: compute
  my @o = ();

  foreach $entry (@ftodo) {
    my ($nb, $ne) = ($entry =~ m%^(\d+)\:(\d+)$%);
    $text = &_fs_shorten_check($b, $e, $entry);
    if ($text !~ m%^\s*$%) {
      $self->_set_errormsg($text);
      return (0);
    }

    if ($nb == $e) { # ex: 1:2 2:6 -> 1:6
      $e = $ne;
    } elsif ($nb == 1 + $e) { # ex: 1:1 2:3 -> 1:3
      $e = $ne;
    } else { # ex: 1:2 12:24 -> 1:2 12:24
      push @o, "$b:$e";
      ($b, $e) = ($nb, $ne);
    }
  }
  push @o, "$b:$e";
  
  my $res = join(" ", @o);
  
  $self->set_value($res);

  return (1);
}

##########

sub fix {
  my ($self, $max) = @_;

  return (0) if ($self->get_errormsg() ne "");

  if (! defined($max)) {
    $self->set_errormsg("[Framespan.pm] fix function require the maximum framespan to compare to");
    return (0);
  }

  if (! $self->_is_value_set()) {
    $self->_set_errormsg("No framespan set");
    return(0);
  }

  if (! $max->_is_value_set()) {
    $self->_set_errormsg("No framespan set for max framespan");
    return(0);
  }

  my $fs = $self->get_value();
  my $mfs = $max->get_value();

  return (1)
    if ($fs eq $mfs);

  my $text;

  # Reorder (just in case)
  return (0) if (! $self->reorder());

  # Shorten range of framespan entries (Also performs a check on pair ordering)
  # NOTE: must be done after full reorder since it relies on entries to be ordered to work
  return (0) if (! $self->shorten());

  my ($bf, $ef) = &_fs_get_begend($fs);
  if ($bf < 1) {
    $self->set_errormsg("A framespan must always start at frame \#1");
    return (0);
  }

  $self->set_value($fs);

  return (1);
}

##########

sub _fs_get_begend {
  my $fs = shift @_;

  my ($bf) = ($fs =~ m%^(\d+)\:%);
  my ($ef) = ($fs =~ m%\:(\d+)$%);

  return ($bf, $ef);
}

#####

sub check_no_overlap {
  my ($self, @others) = @_;

  return (0) if ($self->get_errormsg() ne "");

  if (! $self->_is_value_set()) {
    $self->_set_errormsg("No framespan set");
    return(0);
  }

  # Nothing to compare to ? No overlap possible
  return (1) if (scalar @others == 0);

  my $ifs = $self->get_value();
  my ($i_beg, $i_end) = _fs_get_begend($ifs);

  foreach my $fcfs (@others) {
    if (! $fcfs->_is_value_set()) {
      $self->_set_errormsg("No framespan set");
      return(0);
    }
    my $cfs = $fcfs->get_value();
    my ($c_beg, $c_end) = _fs_get_begend($cfs);

    # No overlap possible
    next if (($c_end < $i_beg) || ($i_end < $c_beg));

    # Overlap
    $self->_set_errormsg("framespan overlap detected");
    return(0);
  }

  return(1);
}

#####

sub is_within {
  my ($self, $other) = @_;

  return (0) if ($self->get_errormsg() ne "");

  if (! $self->_is_value_set()) {
    $self->_set_errormsg("No framespan set");
    return(0);
  }

  if (! $other->_is_value_set()) {
    $self->_set_errormsg("No framespan set for comparable");
    return(0);
  }

  my $v = $self->get_value();
  my $range = $other->get_value();

  my ($v_beg, $v_end) = _fs_get_begend($v);
  my ($r_beg, $r_end) = _fs_get_begend($range);

  # is within
  return (1)
    if (($v_beg >= $r_beg) && ($v_end <= $r_end));

  # is not within
  $self->_set_errormsg("framespan is not within the given range");
  return (0);
}


####################
1;
