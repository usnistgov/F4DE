package Framespan;

use strict;

my %error_msgs =
  (
   "EmptyValue"        => "Must provide a non empty \'value\'",
   "NotFramespan"      => "Entry is not a valid framespan",
   "NoFramespanSet"    => "No framespan set",
   "BadRangePair"      => "Badly formed range pair",
   "NegativeValue"     => "Framespan range pair values can not be negative",
   "NotOrdered"        => "Framespan range pair is not ordered",
   "StartAt0"          => "Framespan can not start at 0",
   "Overlap"           => "Framespan overlap detected",
   "NotWithin"         => "Framespan is not within the given range",
  );
   

## Constructor
sub new {
  my ($class) = shift @_;

  my $tmp = shift @_;
  my ($value, $errormsg) = _fs_check_and_optimize_value($tmp, 1);

  my $self =
    {
     value => $value,
     original_value => $tmp,
     errormsg => $errormsg,
    };
  
  bless $self;
  return $self;
}

####################

sub _fs_check_pair {
  my ($b, $e) = @_;

  return($error_msgs{"BadRangePair"})
    if (($b =~ m%^\s*$%) || ($e =~ m%^\s*$%));
  
  return($error_msgs{"NegativeValue"})
    if (($b < 0) || ($e < 0));

  return($error_msgs{"NotOrdered"})
    if ($e < $b);

  return($error_msgs{"StartAt0"})
    if ($b == 0);

  return("");
}

#####

sub _fs_split_pair {
  my ($pair) = shift @_;

  return(0,0, $error_msgs{"NotFramespan"})
    if ($pair !~ m%^\d+\:\d+$%);

  my ($b, $e) = ($pair =~ m%^(\d+)\:(\d+)$%);

  return ($b, $e, "");
}

#####

sub _fs_split_line {
  my $line = shift @_;

  my @o = split(/[\s|\t]+/, $line);

  return @o;
}

#####

sub _fs_split_line_count {
  my $line = shift @_;

  return scalar &_fs_split_line($line);
}

#####

sub _fs_check_value {
  my $value = shift @_;
  my $from_new = shift @_;

  if ($value eq "") {
    # If called from new, it is ok
    return ($value, "") if ($from_new);
    # Otherwise it should not happen
    return ("", $error_msgs{"EmptyValue"});
  }

  # Process pair per pair
  my @todo = &_fs_split_line($value);
  foreach my $key (@todo) {
    my ($b, $e, $txt) = &_fs_split_pair($key);
    return ("", $txt) if ($txt !~ m%^\s*$%);
    $txt = &_fs_check_pair($b, $e);
    return ("", $txt) if ($txt !~ m%^\s*$%);
  }

  # Recreate a usable string
  $value = join(" ", @todo);

  return ($value, "");
}

##########

sub _fs_reorder_value {
  my $fs = shift @_;

  # Only 1 element, nothing to do
  return ($fs, "") if (&_fs_split_line_count($fs) == 1);

  # More than 1 element, reorder
  my @ftodo = &_fs_split_line($fs);
  my @o = sort _fs_sort @ftodo;
  return ($fs, "WEIRD: While reordering frames, did not find the same number of elements between the original array and the result array")
    if (scalar @ftodo != scalar @o);

  $fs = join(" ", @o);

  return($fs, "");
}

##########

sub _fs_shorten_value {
  my $fs = shift @_;

  my ($b, $e, $errormsg);

  ($fs, $errormsg) = &_fs_reorder_value($fs);
  return ($fs, $errormsg) if ($errormsg !~ m%^\s*$%);

  # Only 1 element, nothing to do
  return ($fs, "") if (&_fs_split_line_count($fs) == 1);

  # More than one element: compute
  my @o = ();

  my @ftodo = &_fs_split_line($fs);
  my $ftc = scalar @ftodo;

  # Get the first element
  my $entry = shift @ftodo;
  ($b, $e, $errormsg) = &_fs_split_pair($entry);
  return ($fs, $errormsg) if ($errormsg !~ m%^\s*$%);

  my ($nb, $ne);
  foreach $entry (@ftodo) {
    ($nb, $ne, $errormsg) = &_fs_split_pair($entry);
    return ($fs, $errormsg) if ($errormsg !~ m%^\s*$%);

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
  
  $fs = join(" ", @o);

  return ($fs, "");
}

#####

sub _fs_check_and_optimize_value {
  my $value = shift @_;
  my $from_new = shift @_;

  my $errormsg = "";

  # Check the value
  ($value, $errormsg) = &_fs_check_value($value, $from_new);
  return ($value, $errormsg) if ($errormsg !~ m%^\s*$%);

  # Then optimize it (if a value is present)
  if ($value ne "") {
    ($value, $errormsg) = &_fs_shorten_value($value);
    return ($value, $errormsg) if ($errormsg !~ m%^\s*$%);
  }

  return ($value, $errormsg);
}

##########

sub set_value {
  my ($self, $tmp) = @_;

  my ($value, $errormsg) = _fs_check_and_optimize_value($tmp, 0);
  $self->_set_errormsg($errormsg) if ($errormsg !~ m%^\s*$%);

  $self->{value} = $value;
  $self->{original_value} = $tmp;
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

#####

sub get_original_value {
  my ($self) = @_;

  return ($self->{original_value});
}

##########

sub get_errormsg {
  my ($self) = @_;

  return ($self->{errormsg});
}

##########

sub _is_value_set {
  my ($self) = @_;

  return (0) if ($self->_is_errormsg_set());

  my $v = $self->get_value();

  return (0)
    if ($v eq "");

  return (0)
    if (&_fs_split_line_count($v) == 0);

  return (1);
}

##########

sub _is_errormsg_set {
  my ($self) = @_;

  return (1) if ($self->get_errormsg() ne "");

  return (0);
}

####################

sub _fs_sort {
  return _fs_sort_core($a, $b);
}

#####

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

sub _fs_get_begend {
  my $fs = shift @_;

  my ($bf) = ($fs =~ m%^(\d+)\:%);
  my ($ef) = ($fs =~ m%\:(\d+)$%);

  return ($bf, $ef);
}

#####

sub check_no_overlap {
  my ($self, @others) = @_;

  return (0) if ($self->_is_errormsg_set());

  if (! $self->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(0);
  }

  # Nothing to compare to ? No overlap possible
  return (1) if (scalar @others == 0);

  my $ifs = $self->get_value();
  my ($i_beg, $i_end) = _fs_get_begend($ifs);

  foreach my $fcfs (@others) {
    if (! $fcfs->_is_value_set()) {
      $self->_set_errormsg($error_msgs{"NoFramespanSet"});
      return(0);
    }
    my $cfs = $fcfs->get_value();
    my ($c_beg, $c_end) = _fs_get_begend($cfs);

    # No overlap possible
    next if (($c_end < $i_beg) || ($i_end < $c_beg));

    # Overlap
    $self->_set_errormsg($error_msgs{"Overlap"});
    return(0);
  }

  return(1);
}

#####

sub is_within {
  my ($self, $other) = @_;

  return (0) if ($self->_is_errormsg_set());

  if (! $self->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(0);
  }

  if (! $other->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
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
  $self->_set_errormsg($error_msgs{"NotWithin"});
  return (0);
}


####################
1;
