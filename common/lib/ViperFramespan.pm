package ViperFramespan;

# $Id$

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "ViperFramespan.pm Version: $version";

my %error_msgs =
  (
   # from 'new'
   "NotFramespan"      => "Entry is not a valid framespan",
   "EmptyValue"        => "Must provide a non empty \'value\'",
   "BadRangePair"      => "Badly formed range pair",
   "NegativeValue"     => "Framespan range pair values can not be negative",
   "NotOrdered"        => "Framespan range pair is not ordered",
   "StartAt0"          => "Framespan can not start at 0",
   # Other
   "NoFramespanSet"    => "No framespan set",
  );

## Constructor
sub new {
  my ($class) = shift @_;

  my $tmp = shift @_;
  my ($value, $errmsg) = &_fs_check_and_optimize_value($tmp, 1);
  my $errormsg = &_set_errormsg_txt("", $errmsg);

  my $self =
    {
     value => $value,
     original_value => $tmp,
     errormsg => $errormsg,
    };

  bless $self;
  return($self);
}

####################

sub get_version {
  my ($self) = @_;

  return($versionid);
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

  return($b, $e, "");
}

#####

sub _fs_split_line {
  my $line = shift @_;

  my @o = split(/[\s|\t]+/, $line);

  return(@o);
}

#####

sub _fs_split_line_count {
  my $line = shift @_;

  return(scalar &_fs_split_line($line));
}

#####

sub _fs_check_value {
  my $value = shift @_;
  my $from_new = shift @_;

  if ($value eq "") {
    # If called from new, it is ok
    return($value, "") if ($from_new);
    # Otherwise it should not happen
    return("", $error_msgs{"EmptyValue"});
  }

  # Process pair per pair
  my @todo = &_fs_split_line($value);
  foreach my $key (@todo) {
    my ($b, $e, $txt) = &_fs_split_pair($key);
    return("", $txt) if ($txt !~ m%^\s*$%);
    $txt = &_fs_check_pair($b, $e);
    return("", $txt) if ($txt !~ m%^\s*$%);
  }

  # Recreate a usable string
  $value = join(" ", @todo);

  return($value, "");
}

##########

sub _fs_make_uniques {
  my @a = @_;

  my %tmp;
  foreach my $key (@a) {
    $tmp{$key}++;
  }

  return(keys %tmp);
}

#####

sub _fs_reorder_value {
  my $fs = shift @_;

  # Only 1 element, nothing to do
  return($fs, "") if (&_fs_split_line_count($fs) == 1);

  # More than 1 element, reorder
  my @ftodo = &_fs_split_line($fs);
  @ftodo = &_fs_make_uniques(@ftodo); # ex: '1:2 1:2' -> '1:2'
  my @o = sort _fs_sort @ftodo;
  return($fs, "WEIRD: While reordering frames, did not find the same number of elements between the original array and the result array")
    if (scalar @ftodo != scalar @o);

  $fs = join(" ", @o);

  return($fs, "");
}

##########

sub _fs_shorten_value {
  my $fs = shift @_;

  my ($b, $e, $errormsg);

  ($fs, $errormsg) = &_fs_reorder_value($fs);
  return($fs, $errormsg) if ($errormsg !~ m%^\s*$%);

  # Only 1 element, nothing to do
  return($fs, "") if (&_fs_split_line_count($fs) == 1);

  # More than one element: compute
  my @o = ();

  my @ftodo = &_fs_split_line($fs);
  my $ftc = scalar @ftodo;

  # Get the first element
  my $entry = shift @ftodo;
  ($b, $e, $errormsg) = &_fs_split_pair($entry);
  return($fs, $errormsg) if ($errormsg !~ m%^\s*$%);

  my ($nb, $ne);
  foreach $entry (@ftodo) {
    ($nb, $ne, $errormsg) = &_fs_split_pair($entry);
    return($fs, $errormsg) if ($errormsg !~ m%^\s*$%);

    if ($nb == $e) { # ex: 1:2 2:6 -> 1:6
      $e = $ne;
    } elsif ($nb == 1 + $e) { # ex: 1:1 2:3 -> 1:3
      $e = $ne;
    } elsif ($nb == $b) { # ex: 1:2 1:3 -> 1:3
      $e = $ne;
      # Works because we can not have multiple same entries (ex: '1:2 1:2' was fixed in _fs_reorder_value)
      # and because the reorder insure that '1:2 1:3' is fully ordered properly (ex: no '1:3 1:2' possible)
    } else { # ex: 1:2 12:24 -> 1:2 12:24
      push @o, "$b:$e";
      ($b, $e) = ($nb, $ne);
    }
  }
  push @o, "$b:$e";

  $fs = join(" ", @o);

  return($fs, "");
}

#####

sub _fs_check_and_optimize_value {
  my $value = shift @_;
  my $from_new = shift @_;

  my $errormsg = "";

  # Check the value
  ($value, $errormsg) = &_fs_check_value($value, $from_new);
  return($value, $errormsg) if ($errormsg !~ m%^\s*$%);

  # Then optimize it (if a value is present)
  if ($value ne "") {
    ($value, $errormsg) = &_fs_shorten_value($value);
    return($value, $errormsg) if ($errormsg !~ m%^\s*$%);
  }

  return($value, $errormsg);
}

##########

sub set_value {
  my ($self, $tmp) = @_;

  return(0) if ($self->error());

  my $ok = 1;

  my ($value, $errormsg) = &_fs_check_and_optimize_value($tmp, 0);
  if ($errormsg !~ m%^\s*$%) {
    $self->_set_errormsg($errormsg);
    $ok = 0;
  }

  $self->{value} = $value;
  $self->{original_value} = $tmp;

  return($ok);
}

##########

sub _set_errormsg_txt {
  my ($oh, $add) = @_;

  my $txt = "$oh$add";
#  print "FS * [$oh | $add]\n";

  $txt =~ s%\[ViperFramespan\]\s+%%g;

  return("") if ($txt =~ m%^\s*$%);

  $txt = "[ViperFramespan] $txt";
#  print "FS -> [$txt]\n";
  return($txt);
}

#####

sub _set_errormsg {
  my ($self, $txt) = @_;

  $self->{errormsg} = &_set_errormsg_txt($self->{errormsg}, $txt);
}

##########

sub get_value {
  my ($self) = @_;

  return($self->{value});
}

#####

sub get_original_value {
  my ($self) = @_;

  return($self->{original_value});
}

##########

sub get_errormsg {
  my ($self) = @_;

  return($self->{errormsg});
}

##########

sub _is_value_set {
  my ($self) = @_;

  return(0) if ($self->error());

  my $v = $self->get_value();

  return(0) if ($v =~ m%^\s*$%);

  return(0) if (&_fs_split_line_count($v) == 0);

  return(1);
}

##########

sub error {
  my ($self) = @_;

  return(1) if ($self->get_errormsg() !~ m%^\s*$%);

  return(0);
}

####################

sub _fs_get_begend {
  my $fs = shift @_;

  my ($bf) = ($fs =~ m%^(\d+)\:%);
  my ($ef) = ($fs =~ m%\:(\d+)$%);

  return($bf, $ef);
}

#####

sub _fs_sort {
  return(&_fs_sort_core($a, $b));
}

#####

sub _fs_sort_core {
  my ($a, $b) = @_;

  my ($b1, $e1) = &_fs_get_begend($a);
  my ($b2, $e2) = &_fs_get_begend($b);

  # Order by beginning first
  return($b1 <=> $b2) if ($b1 != $b2);
  # by end if the beginning is the same
  return($e1 <=> $e2);
}

##########

sub sort_cmp {
  my ($self, $other) = @_;

  return(_fs_sort_core($self->get_value(), $other->get_value()));
}


##########

sub count_pairs_in_value {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $value = $self->get_value();

  return(&_fs_split_line_count($value));
}

#####

sub count_pairs_in_original_value {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $ovalue = $self->get_original_value();

  return(&_fs_split_line_count($ovalue));
}

##########

sub check_if_overlap {
  my ($self, $other) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  if (! $other->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $ifs = $self->get_value();
  my $cfs = $other->get_value();

  my ($i_beg, $i_end) = &_fs_get_begend($ifs);
  my ($c_beg, $c_end) = &_fs_get_begend($cfs);

  # No overlap possible
  return(0) if (($c_end < $i_beg) || ($i_end < $c_beg));

  # Othwise: Overlap
  return(1);
}

##########

sub is_within {
  my ($self, $other) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  if (! $other->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $v = $self->get_value();
  my $range = $other->get_value();

  my ($v_beg, $v_end) = &_fs_get_begend($v);
  my ($r_beg, $r_end) = &_fs_get_begend($range);

  # is within
  return(1) if (($v_beg >= $r_beg) && ($v_end <= $r_end));

  # is not within
  return(0);
}

##########

sub middlepoint {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $v = $self->get_value();

  my ($v_beg, $v_end) = &_fs_get_begend($v);

  return($v_beg + (($v_end - $v_beg) / 2));
}

#####

sub middlepoint_distance {
  my ($self, $other) = @_;

  return(-1) if ($self->error());

  if (! $self->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  if (! $other->_is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $m1 = $self->middlepoint();
  my $m2 = $other->middlepoint();

  return($m2 - $m1);
}

########################################

sub unit_test { # Xtreme coding and us ;)
  my ($self) = @_;
  # We get $self and ignore it entirely (unless we encounter an error of course ;) )
  
  my $eh = "unit_test:";
  my $otxt = "";

  # Let us try to set a bad value
  my $fs_tmp1 = new ViperFramespan("Not a framespan");
  my $err1 = $fs_tmp1->get_errormsg();
  $otxt .= "$eh Error while checking \'set_value\'[1] ($err1). "
    if ($err1 ne &_set_errormsg_txt("", $error_msgs{"NotFramespan"}));

  # Or an empty framespan
  my $fs_tmp2 = new ViperFramespan();
  $fs_tmp2->set_value("");
  my $err2 = $fs_tmp2->get_errormsg();
  $otxt .= "$eh Error while checking \'set_value\'[2] ($err2). "
    if ($err2 ne &_set_errormsg_txt("", $error_msgs{"EmptyValue"}));

  # Not ordered framespan
  my $in3 = "5:4";
  my $fs_tmp3 = new ViperFramespan($in3);
  my $err3 = $fs_tmp3->get_errormsg();
  $otxt .= "$eh Error while checking \'set_value\'[3] ($err3). "
    if ($err3 ne &_set_errormsg_txt("", $error_msgs{"NotOrdered"}));

  # Start a 0
  my $in4 = "0:1";
  my $fs_tmp4 = new ViperFramespan();
  $fs_tmp4->set_value($in4);
  my $err4 = $fs_tmp4->get_errormsg();
  $otxt .= "$eh Error while checking \'new\'[4] ($err4). "
    if ($err4 ne &_set_errormsg_txt("", $error_msgs{"StartAt0"}));

  # Reorder
  my $in5 = "4:5 1:2 12:26 8:8";
  my $exp_out5 = "1:2 4:5 8:8 12:26";
  my $fs_tmp5 = new ViperFramespan();
  $fs_tmp5->set_value($in5);
  my $out5 = $fs_tmp5->get_value();
  $otxt .= "$eh Error while checking \'new\'[reorder] (expected: $exp_out5 / Got: $out5). "
    if ($out5 ne $exp_out5);

  # Reorder (2)
  $in5 = "4:7 1:2 1:2";
  $exp_out5 = "1:2 4:7";
  $fs_tmp5->set_value($in5);
  $out5 = $fs_tmp5->get_value();
  $otxt .= "$eh Error while checking \'new\'[reorder] (expected: $exp_out5 / Got: $out5). "
    if ($out5 ne $exp_out5);

  # Shorten
  my $in6 = "1:2 2:3 4:5";
  my $exp_out6 = "1:5";
  my $fs_tmp6 = new ViperFramespan();
  $fs_tmp6->set_value($in6);
  my $out6 = $fs_tmp6->get_value();
  $otxt .= "$eh Error while checking \'new\'[shorten] (expected: $exp_out6 / Got: $out6). "
    if ($out6 ne $exp_out6);

  # Shorten (2)
  $in6 = "1:3 1:2";
  $exp_out6 = "1:3";
  $fs_tmp6->set_value($in6);
  my $out6 = $fs_tmp6->get_value();
  $otxt .= "$eh Error while checking \'new\'[shorten] (expected: $exp_out6 / Got: $out6). "
    if ($out6 ne $exp_out6);

  # No Framespan Set
  my $fs_tmp7 = new ViperFramespan();
  my $test7 = $fs_tmp7->check_if_overlap(); # We are checking against nothing here
  my $err7 = $fs_tmp7->get_errormsg();
  $otxt .= "$eh Error while checking \'check_if_overlap\' ($err7). "
    if ($err7 ne &_set_errormsg_txt("", $error_msgs{"NoFramespanSet"}));

  # Overlap & Within
  my $in8  = "1:10";
  my $in9  = "4:16";
  my $in10 = "11:15";
  my $fs_tmp8  = new ViperFramespan();
  my $fs_tmp9  = new ViperFramespan();
  my $fs_tmp10 = new ViperFramespan();
  $fs_tmp8->set_value($in8);
  $fs_tmp9->set_value($in9);
  $fs_tmp10->set_value($in10);

  my $testa = $fs_tmp8->check_if_overlap($fs_tmp9);
  $otxt .= "$eh Error while checking \'check_if_overlap\' ($in8 and $in9 do overlap, but test says otherwise). "
  if (! $testa);

  my $testb = $fs_tmp8->check_if_overlap($fs_tmp10);
  $otxt .= "$eh Error while checking \'check_if_overlap\' ($in8 and $in10 do not overlap, but test says otherwise). "
  if ($testb);

  my $testc = $fs_tmp10->is_within($fs_tmp9);
  $otxt .= "$eh Error while checking \'is_within\' ($in10 is within $in9, but test says otherwise). "
  if (! $testc);

  my $testd = $fs_tmp9->is_within($fs_tmp10);
  $otxt .= "$eh Error while checking \'is_within\' ($in9 is not within $in10, but test says otherwise). "
  if ($testd);

  # optimize + count_pairs
  my $in11 = "20:40 1:2 1:1 2:6 8:12 20:40"; # 6 pairs (not optimized)
  my $exp_out11 = "1:6 8:12 20:40"; # 3 pairs (once optimized)
  my $fs_tmp11 = new ViperFramespan();
  $fs_tmp11->set_value($in11);
  my $out11 = $fs_tmp11->get_value();
  $otxt .= "$eh Error while checking \'new\'[count_pairs] (expected: $exp_out11 / Got: $out11). "
    if ($out11 ne $exp_out11);

  my $etmp11a = &_fs_split_line_count($in11);
  my $tmp11a = $fs_tmp11->count_pairs_in_original_value();
  $otxt .= "$eh Error while checking \'count_pairs_in_original_value\' (expected: $etmp11a / Got: $tmp11a). "
    if ($etmp11a != $tmp11a);

  my $etmp11b = &_fs_split_line_count($exp_out11);
  my $tmp11b = $fs_tmp11->count_pairs_in_value();
  $otxt .= "$eh Error while checking \'count_pairs_in_value\' (expected: $etmp11b / Got: $tmp11b). "
    if ($etmp11b != $tmp11b);

  # middlepoint + middlepoint_distance
  my $in12 = "20:40";
  my $fs_tmp12 = new ViperFramespan($in12);
  my $exp_out12 = 30; # = 20 + ((40 - 20) / 2)
  my $out12 = $fs_tmp12->middlepoint();
  $otxt .= "$eh Error while checking \'middlepoint\' (expected: $exp_out12 / Got: $out12). "
    if ($exp_out12 != $out12);

  my $in13 = "100:200"; # middlepoint: 150
  my $fs_tmp13 = new ViperFramespan($in13);

  my $out13 = $fs_tmp12->middlepoint_distance($fs_tmp13);
  my $exp_out13 = 120; # from 30 to 150 : +120
  $otxt .= "$eh Error while checking \'middlepoint_distance\'[1] (expected: $exp_out13 / Got: $out13). "
    if ($exp_out13 != $out13);

  my $out14 = $fs_tmp13->middlepoint_distance($fs_tmp12);
  my $exp_out14 = -120; # from 150 to 30 : -120
  $otxt .= "$eh Error while checking \'middlepoint_distance\'[2] (expected: $exp_out14 / Got: $out14). "
    if ($exp_out14 != $out14);

  #####
  # End
  if ($otxt !~ m%^\s*$%) {
    $self->_set_errormsg($otxt);
    return(0);
  }
 
  # return 1 if no error found
  return(1);
}


####################
1;
