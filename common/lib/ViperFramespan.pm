package ViperFramespan;

# Viper Framespan
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


## IMPORTANT NOTE: few of the frames comparison functions check if the fps (if set) match; it is left to the library user to confirm this

use strict;

use MErrorH;
use MMisc;

my $version     = '0.1b';

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "ViperFramespan.pm Version: $version";

my %error_msgs =
  (
   # from 'new'
   'NotFramespan'      => 'Entry is not a valid framespan. ',
   'EmptyValue'        => "Must provide a non empty \'value\'. ",
   'BadRangePair'      => 'Badly formed range pair. ',
   'NegativeValue'     => 'Framespan range pair values can not be negative. ',
   'NotOrdered'        => 'Framespan range pair is not ordered. ',
   'StartAt0'          => 'Framespan can not start at 0. ',
   'WeirdValue'        => 'Strange value provided. ',
   # Other
   'NoFramespanSet'    => 'No framespan set. ',
   # 'fps'
   'negFPS'            => 'FPS can not negative. ',
   'zeroFPS'           => 'FPS can not be equal to 0. ',
   'FPSNotSet'         => 'FPS not set, can not perform time based operations. ',
   'NotAFrame'         => 'Value is not a valid frame value. ',
   'NotAts'            => 'Value is not a valid value in seconds. ',
  );

## Constructor
sub new {
  my ($class, $tmp) = @_;

  my ($value, $errmsg) = &_fs_check_and_optimize_value($tmp, 1);
  my $errorh = new MErrorH('ViperFramespan');
  $errorh->set_errormsg($errmsg) if (! MMisc::is_blank($errmsg));
  my $errorv = $errorh->error();

  my $self =
    {
     value    => $value,
     valueset => (length($value) > 0) ? 1 : 0,
     original_value => $tmp,
     fps      => -1,
     beg      => undef,
     end      => undef,
     errorh   => $errorh,
     errorv   => $errorv, # Cache information
    };

  ($self->{beg}, $self->{end}) = &_fs_get_begend($value)
    if ($self->{valueset});
 
  bless $self;
  return($self);
}

####################

sub get_version {
  my $self = $_[0];

  return($versionid);
}

####################

sub _fs_check_pair {
  my ($b, $e) = @_;

  return($error_msgs{'NotOrdered'})
    if ($e < $b);

  return($error_msgs{'StartAt0'})
    if ($b == 0);

  return('');
}

#####

sub _fs_split_pair_nocheck {
  # arg 0: fs

  my $sc = index($_[0], ':', 0);
  my $bf = substr($_[0], 0, $sc);
  my $ef = substr($_[0], $sc + 1); # go until end of string

  return($bf, $ef);
}

#####

sub _fs_split_pair {
  # arg 0: fs

  return('', $1, $2)  if ($_[0] =~ m%^(\d+)\:(\d+)$%);

  return($error_msgs{'NotFramespan'}, 0, 0);
}

#####

sub _fs_split_line { return(split(/[\s|\t]+/, $_[0])); }

#####

sub _fs_split_line_count { return(scalar &_fs_split_line($_[0])); }

#####

sub _fs_check_value {
  my ($value, $from_new) = @_;

  if ($value eq '') { # Ok not to called 'is_blank'
    # If called from new, it is ok
    return($value, '') if ($from_new);
    # Otherwise it should not happen
    return('', $error_msgs{'EmptyValue'});
  }

  # Process pair per pair
  $value = MMisc::clean_begend_spaces($value);
  my @todo = &_fs_split_line($value);
  for (my $i = 0; $i < scalar @todo; $i++) {
    my $key = $todo[$i];
    my ($txt, $b, $e) = &_fs_split_pair($key);
    return('', $txt) if (! MMisc::is_blank($txt));
    $txt = &_fs_check_pair($b, $e);
    return('', $txt) if (! MMisc::is_blank($txt));
  }

  return(MMisc::fast_join(' ', \@todo), '');
}

##########

sub _fs_make_uniques {
  my %tmp = MMisc::array1d_to_count_hash($_[0]);
  return(keys %tmp);
}

#####

sub _fs_reorder_value {
  my $fs = $_[0];

  # Only 1 element, nothing to do
  return($fs, '') if (&_fs_split_line_count($fs) == 1);

  # More than 1 element, reorder
  my @ftodo = &_fs_split_line($fs);
  @ftodo = &_fs_make_uniques(\@ftodo); # ex: '1:2 1:2' -> '1:2'
  my @o = sort _fs_sort @ftodo;
  return($fs, 'WEIRD: While reordering frames, did not find the same number of elements between the original array and the result array')
    if (scalar @ftodo != scalar @o);

  return(MMisc::fast_join(' ', \@o), '');
}

##########

sub _fs_shorten_value {
  my $fs = $_[0];

  my $errormsg = '';

  ($fs, $errormsg) = &_fs_reorder_value($fs);
  return($fs, $errormsg) if (! MMisc::is_blank($errormsg));

  my @ftodo = &_fs_split_line($fs);

  # Only 1 element, nothing to do
  return($fs, '') if (scalar @ftodo == 1);

  # More than one element: compute
  my @o = ();

  # Get the first element
  my ($b, $e) = &_fs_split_pair_nocheck($ftodo[0]);

  for (my $i = 1; $i < scalar @ftodo; $i++) {
    my $entry = $ftodo[$i];
    my ($nb, $ne) = &_fs_split_pair_nocheck($entry);

    if ($nb == $e) {            # ex: 1:2 2:6 -> 1:6
      $e = $ne;
    } elsif ($nb == 1 + $e) {   # ex: 1:1 2:3 -> 1:3
      $e = $ne;
    } elsif ($nb == $b) {       # ex: 1:2 1:3 -> 1:3
      $e = $ne;
      # Works because we can not have multiple same entries (ex: '1:2 1:2' was fixed in _fs_reorder_value)
      # and because the reorder insure that '1:2 1:3' is fully ordered properly (ie: no '1:3 1:2' possible)
    } elsif ($nb < $e) {
      # All this also work because we have insured a full re-ordering of pairs
      if ($ne >= $e) {          # ex: 10:30 20:40 -> 10:40
        $e = $ne;
      }
      # The else here would be ex: 10:30 20:25 -> 10:30
      # Do nothing, simply forget this value
    } else {                    # ex: 1:2 12:24 -> 1:2 12:24
      push @o, "$b:$e";
      ($b, $e) = ($nb, $ne);
    }
  }
  push @o, "$b:$e";

  return(MMisc::fast_join(' ', \@o), '');
}

#####

sub _fs_check_and_optimize_value {
  my ($value, $from_new) = @_;

  my $errormsg = '';

  # Check the value
  ($value, $errormsg) = &_fs_check_value($value, $from_new);
  return($value, $errormsg) if (! MMisc::is_blank($errormsg));

  # Then optimize it (if a value is present)
  if ($value ne '') { # Ok not to use 'is_blank' as value is checked after
    ($value, $errormsg) = &_fs_shorten_value($value);
    return($value, $errormsg) if (! MMisc::is_blank($errormsg));
  }

  return($value, $errormsg);
}

##########

sub set_value {
  my ($self, $tmp, $skopt) = @_;

  return(0) if ($self->{errorv});

  my $ok = 1;

  my $value = $tmp;
  if (! $skopt) {
    ($value, my $errormsg) = &_fs_check_and_optimize_value($tmp, 0);
    if (! MMisc::is_blank($errormsg)) {
      $self->_set_errormsg($errormsg);
      $ok = 0;
    }
  }

  $self->{value} = $value;
  $self->{valueset} = (length($value) > 0) ? 1 : 0;
  $self->{original_value} = $tmp;
  ($self->{beg}, $self->{end}) = &_fs_get_begend($value);

  return($ok);
}

#####

sub set_value_beg_end {
  my ($self, $beg, $end) = @_;
  return($self->set_value("$beg:$end"));
}

#####

sub set_value_from_beg_to {
  my ($self, $v) = @_;
  return($self->set_value_beg_end(1, $v));
}

#####

sub add_fs_to_value {
  my ($self, $v) = @_;

  return(0) if ($self->{errorv});

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0);
  }

  my $value = $self->{value};
  $value .= " $v";

  return($self->set_value($value));
}

#########

sub union {
  # arg 0: self
  # arg 1: other

  return(0) if ($_[0]->{errorv});

  if ( (! $_[0]->{valueset}) 
       || (! defined $_[1]) || (! $_[1]->{valueset}) ) {
    $_[0]->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0);
  }

  return($_[0]->add_fs_to_value($_[1]->{value}));
}

#####

sub intersection {
  my ($self, $other) = @_;

  return($self->get_overlap($other));
}

########## 'fps'

sub set_fps {
  my ($self, $fps) = @_;

  return(0) if ($self->{errorv});

  if (lc($fps) eq 'pal') {
    $fps = 25;
  } elsif (lc($fps) eq 'ntsc') {
    $fps = 30000 / 1001;
  }

  my ($ok, $fps) = MMisc::is_get_float($fps);
  if ((! $ok) || (! defined($fps))) {
    $self->_set_errormsg($error_msgs{'WeirdValue'});
    return(0);
  }

  if ($fps < 0) {
    $self->_set_errormsg($error_msgs{'negFPS'});
    return(0);
  } elsif ($fps == 0) {
    $self->_set_errormsg($error_msgs{'zeroFPS'});
    return(0);
  }

  $self->{fps} = $fps;
  return(1);
}

#####

sub is_fps_set {
  my $self = $_[0];

  return(0) if ($self->{errorv});

  return(1) if ($self->{fps} != -1);

  return(0);
}

#####

sub get_fps {
  my $self = $_[0];

  return(0) if ($self->{errorv});

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{'FPSNotSet'});
    return(0);
  }

  return($self->{fps});
}

##########

sub get_value {
  my $self = $_[0];

  return($self->{value});
}

#####

sub get_original_value {
  my $self = $_[0];

  return($self->{original_value});
}

##########

sub is_value_set {
  # arg 0: self

  return(0) if ($_[0]->{errorv});

  return($_[0]->{valueset});
}

####################

sub _fs_get_begend {
  # arg 0: fs
  my $sc = index($_[0], ':', 0);
  my $bf = substr($_[0], 0, $sc);

  $sc = rindex($_[0], ':'); # look from end of string
  my $ef = substr($_[0], $sc + 1); # go until the end of string

  return($bf, $ef);
}

#####

sub _fs_sort {
  return(&_fs_sort_core($a, $b));
}

#####

sub _fs_sort_core {
  # arg 0: first fs
  # arg 1: second fs
  my ($b1, $e1) = &_fs_get_begend($_[0]);
  my ($b2, $e2) = &_fs_get_begend($_[1]);

  # Order by beginning first
  return($b1 <=> $b2) if ($b1 != $b2);
  # by end if the beginning is the same
  return($e1 <=> $e2);
}

##########

sub sort_cmp {
  # arg 0: self
  # arg 1: other
  return(&_fs_sort_core($_[0]->{value}, $_[1]->{value}));
}


##########

sub count_pairs_in_value {
  # arg 0: self
  return(-1) if ($_[0]->{errorv});

  if (! $_[0]->{valueset}) {
    $_[0]->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(-1);
  }

  return(&_fs_split_line_count($_[0]->{value}));
}

##########

sub get_list_of_framespans {
  my $self = $_[0];

  my @list = ();
  return(undef) if ($self->{errorv});

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(undef);
  }

  my $value = $self->{value};
  my $fps = undef;
  $fps = $self->get_fps() if ($self->is_fps_set());
  my @todo = &_fs_split_line($value);
  for (my $i = 0; $i < scalar @todo; $i++) {
    my $p = $todo[$i];
    my $nfs = new ViperFramespan();
    if (! $nfs->set_value($p, 1)) {
      $self->_set_errormsg("Failed to set sub framespan value \'$p\'");
      return(undef); 
    }
    if (defined($fps) && (! $nfs->set_fps($fps))) {
      $self->_set_errormsg("Failed to set sub framespan fps \'$fps\'");
      return(undef); 
    }
    if ($nfs->{errorv}) {
      $self->_set_errormsg($nfs->get_errormsg());
      return(undef);
    }
    push @list, $nfs;
  }
  return(\@list);
}

#####

sub count_pairs_in_original_value {
  my $self = $_[0];

  return(-1) if ($self->{errorv});

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(-1);
  }

  my $ovalue = $self->get_original_value();

  return(&_fs_split_line_count($ovalue));
}

##########

sub check_if_overlap {
  # arg 0: self
  # arg 1: other

  if ( (! $_[0]->{valueset}) 
       || (! defined $_[1]) || (! $_[1]->{valueset}) ) {
    $_[0]->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0);
  }
  
  return(0) if ($_[0]->{errorv});

  # No overlap possible
  return(0) if (($_[1]->{end} < $_[0]->{beg}) || ($_[0]->{end} < $_[1]->{beg}));

  # Othwise: Overlap
  return(1);
}

#####

sub check_if_overlap_s {
  # arg 0: self
  # arg 1: ref to array of ViperFramespan
  # return on first overlap found (and a ref to the ViperFramespan that overlaps)

  if (! $_[0]->{valueset}) {
    $_[0]->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0, undef);
  }

  return(0, undef) if (scalar @_ == 1);
  return(0, undef) if (scalar @{$_[1]} == 0);

  for (my $i = 1; $i < scalar @{$_[1]}; $i++) {
    if ( (! defined ${$_[1]}[$i]) || (! ${$_[1]}[$i]->{valueset}) ) {
      $_[0]->_set_errormsg($error_msgs{'NoFramespanSet'});
      return(0, undef);
    }
    next if
      ((${$_[1]}[$i]->{end} < $_[0]->{beg}) 
       || ($_[0]->{end} < ${$_[1]}[$i]->{beg}));
    return(1, \${$_[1]}[$i]);
  }

  return(0, undef);
}

##########

sub _get_overlap_core {
  my ($i_beg, $i_end, $c_beg, $c_end) = @_;

  # return (ov_b, ov_e, new_i_beg, new_i_end, new_c_beg, new_c_end) 
  # (ov_b, ov_e) = (0, 0) if no overlap
  # (new_X_beg, new_X_end) = (0, 0) if "drop"

  # 1: ib---ie           -> Drop 1
  # 2:         cb---ce   -> Keep 2
  return(0, 0, 0, 0, $c_beg, $c_end)
    if ($i_end < $c_beg);

  # 1:         ib---ie   -> Keep 1
  # 2: cb---ce           -> Drop 2
  return(0, 0, $i_beg, $i_end, 0, 0)
    if ($c_end < $i_beg);

  if (($c_beg >= $i_beg) && ($c_beg <= $i_end)) {
    if ($c_end >= $i_end) {
      #  1: ib----------ie
      #  2:  cb--------------ce
      # ov:  cb---------ie
      # 1':
      # 2':         ie+1-----ce
      return($c_beg, $i_end, 0, 0, $i_end+1, $c_end);
    } else {
      #  1: ib----------ie
      #  2:    cb-----ce
      # ov:    cb-----ce
      # 1':       ce+1--ie
      # 2':
      return($c_beg, $c_end, $c_end + 1, $i_end, 0, 0);
    }
  } elsif ($c_beg < $i_end) {
    if ($c_end < $i_end) {
      #  1:     ib----------ie
      #  2:  cb---------ce
      # ov:     ib------ce
      # 1':         ce+1----ie
      # 2':
      return($i_beg, $c_end, $c_end + 1, $i_end, 0, 0);
    } else {
      #  1:     ib----------ie
      #  2:  cb------------------ce
      # ov:     ib----------ie
      # 1':
      # 2':             ie+1-----ce
      return($i_beg, $i_end, 0, 0, $i_end + 1, $c_end);
    }
  }
  
  return(undef);
}

#####

sub _get_overlap_wrapper {
  my ($i_beg, $i_end, $c_beg, $c_end) = @_;

  my ($ovb, $ove, $ib, $ie, $cb, $ce) = 
    &_get_overlap_core($i_beg, $i_end, $c_beg, $c_end);
#  print "==> ov[$ovb:$ove] n1[$ib:$ie] n2[$cb:$ce]\n";

  return(undef) if (! defined $ovb);

  # We can not have values in "i" and "c" at the same time
  return(undef) if (($ib != 0) && ($ie != 0) && ($cb != 0) && ($ce != 0));

  # Values disappears if beg > end

  if ($ovb > $ove) {
    $ovb = 0;
    $ove = 0;
  }

  if ($ib > $ie) {
    $ib = 0;
    $ie = 0;
  }

  if ($cb > $ce) {
    $cb = 0;
    $ce = 0;
  }

  return($ovb, $ove, $ib, $ie, $cb, $ce);
}

#####

sub _split_pair_to_2darray {
  my @out = ();
  for (my $i = 0; $i < scalar @_; $i++) {
    my ($b, $e) = &_fs_split_pair_nocheck($_[$i]);
    push @out, [$b, $e];
  }

  return(@out);
}

#####

sub get_overlap {
  # arg 0: self
  # arg 1: other

  # Worry about the fps first
  my $sfps = undef;
  my $ofps = undef;
  $sfps = $_[0]->get_fps() if ($_[0]->is_fps_set());
  $ofps = $_[1]->get_fps() if ($_[1]->is_fps_set());
  my $fps = undef;
  if ((defined $sfps) && (defined $ofps)) {
    if ($sfps != $ofps) {
      $_[0]->_set_errormsg("Can not process a \'get_overlap\' function for framespans with different fps");
      return(undef);
    }
    $fps = $sfps;
  } else {
    # If one of the two entity has its fps set, copy it
    # (we hope the caller knows to check comparables)
    $fps = $sfps if (defined $sfps);
    $fps = $ofps if (defined $ofps);
  }

  # Check error in the 'other'
  if ($_[1]->{errorv}) {
    $_[0]->_set_errormsg("Can not \'get_overlap\' from bad \'other\' (" . $_[1]->get_errormsg() . ')');
    return(undef);
  }

  # We only need to worry about overlap if there is even one possible
  return(undef) if (! $_[0]->check_if_overlap($_[1]));
  return(undef) if ($_[0]->{errorv});

  # Now in order to compute the overlap we work pair per pair
#  print "******************** Overlap\n*****In1: " . $_[0]->{value} . "\n*****In2: " . $_[1]->{value} . "\n";

  # [MM 20090420 with Jon's Help] New technique : go from o(n*m) to o(n+m) 

  my @spl = &_split_pair_to_2darray(&_fs_split_line($_[0]->{value}));
  my @opl = &_split_pair_to_2darray(&_fs_split_line($_[1]->{value}));

  # Resulting overlap array
   my @ova = ();
  
  # We rely on the fact that "new" ordered and simplified every value
  # so we have an fully ordered comparable set of data
  my $cont = 1;
  while ($cont) {
    # Always work with the first element of each list
    my ($b1, $e1) = ($spl[0][0], $spl[0][1]);
    my ($b2, $e2) = ($opl[0][0], $opl[0][1]);
#    print "\n*[Iteration:$cont] 1[$b1:$e1] 2[$b2:$e2]\n";
    
    my ($ovb, $ove, $nb1, $ne1, $nb2, $ne2) = 
      &_get_overlap_wrapper($b1, $e1, $b2, $e2);
#    print "-> ov[$ovb:$ove] n1[$nb1:$ne1] n2[$nb2:$ne2]\n";

    if (! defined $ovb) {
      $_[0]->_set_errormsg("Problem in \'get_overlap\' obtained overlap information");
      return(undef);
    }
    
    # If we have an overlap, add it to the overlap list
    push @ova, "$ovb:$ove"
      if (($ovb != 0) && ($ove != 0));
    
    # Do we need to drop one element for spl ?
    if (($nb1 == 0) && ($ne1 == 0)) {
      shift @spl;
    } else { # or replace its content ?
      $spl[0][0] = $nb1;
      $spl[0][1] = $ne1;
    }
    
    # Do we need to drop one element for opl ?
    if (($nb2 == 0) && ($ne2 == 0)) {
      shift @opl;
    } else { # or replace its content ?
      $opl[0][0] = $nb2;
      $opl[0][1] = $ne2;
    }
    
    $cont++;
    
    # We are done when one list is empty
    $cont = 0 if ((scalar @opl == 0) || (scalar @spl == 0));
  }
  
  # No overlapping value at all
  return(undef) if (scalar @ova == 0);

  # Generate a new framespan out of it
  my $ovp = MMisc::fast_join(' ', \@ova);

#  print "*****Out: $ovp\n\n";

  my $nfs = new ViperFramespan($ovp);
  if ($nfs->{errorv}) {
    $_[0]->_set_errormsg('Problem creating new ViperFramespan for overlap value (' . $nfs->get_errormsg() . ')');
    return(undef);
  }
  if (defined($fps) && (! $nfs->set_fps($fps))) {
    $_[0]->_set_errormsg("Failed to set new ViperFramespan fps '$fps' (" . $nfs->get_errormsg() . ')');
    return(undef); 
  }

  return($nfs);
}

##########

sub get_beg_end_fs {
  # arg 0: self
  
  return(-1) if ($_[0]->{errorv});

  if (! $_[0]->{valueset}) {
    $_[0]->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(-1);
  }

  return($_[0]->{beg}, $_[0]->{end});
}

#####

sub is_within {
  my ($self, $other, $tif) = @_;
  # tif: tolerance (in frames)
  # technicaly a double tolerance since the same value is added to the end
  # and substracted to the beginning

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(0) if ($self->{errorv});

  $ tif = 0 if (! defined $tif);
  if ($tif < 0) {
    $self->_set_errormsg("In \'is_within\', the \'tolerance (in frames)\' value has to be >= 0");
    return(0);
  }

  my ($r_beg, $r_end) = $other->get_beg_end_fs();
  if ($other->{errorv}) {
    $self->_set_errormsg($other->get_errormsg());
    return(0);
  }

  # is within: tolerate a difference of $tif
  return(1) if ( ($v_beg >= ($r_beg - $tif)) && ($v_end <= ($r_end + $tif)) );

  # is not within
  return(0);
}

##########

sub _fs_not_value {
  my ($fs, $min, $max) = @_;

  my @o = ();

  my @ftodo = &_fs_split_line($fs);

  my ($b, $e) = (0, 0);
  for (my $i = 0; $i < scalar @ftodo; $i++) {
    my $entry = $ftodo[$i];
    ($b, $e) = &_fs_split_pair_nocheck($entry);

    push @o, ($min . ':' . ($b - 1))
      if ($b > $min);

    $min = $e + 1; # Move 'min' each time
  }
  push @o, "$min:$max"
    if ($e < $max);

  return(MMisc::fast_join(' ', \@o));
}

#####

sub bounded_not {
  my ($self, $min, $max) = @_;

  return(undef) if ($self->{errorv});

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(undef);
  }

  # First, limit to min/Max
  my $tfs = new ViperFramespan("$min:$max");
  if ($tfs->{errorv}) {
    $self->_set_errormsg("Problem with min/Max values ($min/$max): " . $tfs->get_errormsg());
    return(undef);
  }
  
  my $ofs = $self->get_overlap($tfs);
  return(undef) if ($self->{errorv});

  # If framespan is not within min/Max, return the full min/Max framespan
  return($tfs) if (! defined $ofs);

  my $fsv = $ofs->{value};

  my $ffsv = &_fs_not_value($fsv, $min, $max);

  my $nfs = new ViperFramespan();
  if (! $nfs->set_value($ffsv)) {
    $self->_set_errormsg("Failed to set new framespan value of \'$ffsv\'");
    return(undef); 
  }

  return($nfs);
}

##########

sub get_xor {
  # arg 0: self
  # arg 1: other

  return(undef) if ($_[0]->{errorv});

  if ( (! $_[0]->{valueset}) 
       || (! defined $_[1]) || (! $_[1]->{valueset}) ) {
    $_[0]->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(undef);
  }

  ### XOR is equivalent to the not of the overlap intersecting with the union

  # Work with clones in order not to modify source value
  my $cl1 = $_[0]->clone();
  my $cl2 = $_[0]->clone();
  
  # Get the union
  my $ok = $cl1->union($_[1]);
  if ($cl1->{errorv}) {
    $_[0]->_set_errormsg('In XOR during union: ' . $cl1->get_errormsg());
    return(undef);
  }

  # Need min/Max of union for not overlap bounding
  my ($min, $max) = $cl1->get_beg_end_fs();
  if ($cl1->{errorv}) {
    $_[0]->_set_errormsg('In XOR during beg/end get: ' . $cl1->get_errormsg());
    return(undef);
  }

  # Get the overlap
  my $ov = $cl2->get_overlap($_[1]);
  if ($cl2->{errorv}) {
    $_[0]->_set_errormsg('In XOR during intersection: ' . $cl2->get_errormsg());
    return(undef);
  }

  my $nov = undef;
  # If there is no overlap possible
  if (! defined $ov) {
    $nov = new ViperFramespan("$min:$max");
  } else {
    # Get the not of the overlap restricted to min/Max
    $nov = $ov->bounded_not($min, $max);
    if ($ov->{errorv}) {
      $_[0]->_set_errormsg("In XOR during \"not overlap\": " . $ov->get_errormsg());
      return(undef);
    }
  }
  if (! defined $nov) {
    $_[0]->_set_errormsg("In XOR during \"not overlap\": Could not create a value");
    return(undef);
  }
  if ($nov->{errorv}) {
    $_[0]->_set_errormsg("In XOR during \"not overlap\": " . $nov->get_errormsg());
    return(undef);
  }

  # Do the intersection between the non overlap and the union
  my $res = $nov->get_overlap($cl1);
  if ($nov->{errorv}) {
    $_[0]->_set_errormsg('In XOR during final step: ' . $nov->get_errormsg());
    return(undef);
  }

  if ($res->{errorv}) {
    $_[0]->_set_errormsg('In XOR, in result: ' . $res->get_errormsg());
    return(undef);
  }

  return($res);
}

##########

sub remove {
  my ($self, $other) = @_;

  my $ok = $self->check_if_overlap($other);
  return(0) if ($self->{errorv});

  # no need to remove anything if they do not overlap
  return(1) if (! $ok); 
 
  my $x = $self->get_xor($other);
  return(0) if ($self->{errorv});
  if (! defined $x) {
    $self->_set_errormsg('In remove, could not perform first step');
    return(0);
  }
    
  my $ov = $self->get_overlap($x);
  return(0) if ($self->{errorv});

  my $fsv = $ov->{value};

  return($self->set_value($fsv, 1));
}


##########

sub extent_middlepoint {
  my $self = $_[0];

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(0) if ($self->{errorv});

  my $d = $self->extent_duration();
  return($d) if ($self->{errorv});

  return($v_beg + ($d / 2));
}

#####

sub extent_middlepoint_distance {
  # arg 0: self
  # arg 1: other

  return(-1) if ($_[0]->{errorv});

  if ( (! $_[0]->{valueset}) 
       || (! defined $_[1]) || (! $_[1]->{valueset}) ) {
    $_[0]->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0);
  }

  return($_[1]->extent_middlepoint() - $_[0]->extent_middlepoint());
}

#####

sub extent_duration {
  my $self = $_[0];

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(-1) if ($self->{errorv});

  # 1:3 is 1:2:3 so duration 3, and
  # 1:1 is 1, so duration 1
  # therefore end - beg + 1
  my $d = 1 + $v_end - $v_beg;

  return($d);
}

#####

sub get_beg_fs {
  my $self = $_[0];

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(0) if ($self->{errorv});

  return($v_beg);
}

#####

sub get_end_fs {
  my $self = $_[0];

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(0) if ($self->{errorv});

  return($v_end);
}

##########

sub duration {
  my $self = $_[0];

  return(0) if ($self->{errorv});

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0);
  }

  my $v = $self->{value};

  my @pairs = &_fs_split_line($v);

  my $d = 0;
  for (my $i = 0; $i < scalar @pairs; $i++) {
    my $p = $pairs[$i];
    my ($b, $e) = &_fs_split_pair_nocheck($p);

    # As for extent_duration:
    # 1:3 is 1:2:3 so duration 3, and
    # 1:1 is 1, so duration 1
    # therefore end - beg + 1
    $d += 1 + $e - $b;
  }

  return($d);
}

##########

sub gap_shorten {
  my ($self, $gap) = @_;

  return(0) if ($self->{errorv});

  if ($gap < 2) {
    $self->_set_errormsg("In \'gap_shorten\', \'gap\' value can not be less than 2");
    return(0);
  }

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0);
  }

  # Note: We know that new reorder and optimize values, so we can trust data
  my $fs = $self->{value};

  my @ftodo = &_fs_split_line($fs);

  # Only 1 element, nothing to do
  return(1) if (scalar @ftodo == 1);

  # More than one element: compute
  my @o = ();

  # Get the first element
  my ($b, $e) = &_fs_split_pair_nocheck($ftodo[0]);

  for (my $i = 1; $i < scalar @ftodo; $i++) {
    my $entry = $ftodo[$i];
    my ($nb, $ne) = &_fs_split_pair_nocheck($entry);

    my $v = $nb - $e;

    if ($gap < $v) { # ex: 1:2 6:7 w/ gap = 3 ==> 1:2 6:7
      push @o, "$b:$e";
      ($b, $e) = ($nb, $ne);
    } else {          # ex: 1:2 6:7 w/ gap = 4 ==> 1:7
      $e = $ne;
    }
  }
  push @o, "$b:$e";

  $self->set_value(MMisc::fast_join(' ', \@o));
  return(0) if ($self->{errorv});

  return(1);
}

######################################## 'ts' functions

sub _frame_to_ts {
  my ($self, $frame, $inc) = @_;

  return(0) if ($self->{errorv});

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{'FPSNotSet'});
    return(0);
  }

  my ($ok, $frame) = MMisc::is_get_float($frame);
  if ((! $ok) || (! defined($frame))) {
    $self->_set_errormsg($error_msgs{'NotAFrame'});
    return(0);
  }

  $frame += $inc;

  my $fps = $self->get_fps();

  return($frame / $fps);
}

#####

sub frame_to_ts {
  my ($self, $frame) = @_;

  # Decrease 1 because a '0' ts is a '1' frame
  return($self->_frame_to_ts($frame, -1.0));
}

#####

sub end_frame_to_ts {
  my ($self, $fl) = @_;

  return($self->_frame_to_ts($fl, 0.0));
}

#####

sub _ts_to_frame {
  my ($self, $ts, $inc) = @_;

  return(0) if ($self->{errorv});

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{'FPSNotSet'});
    return(0);
  }

  my ($ok, $ts) = MMisc::is_get_float($ts);
  if ((! $ok) || (! defined($ts))) {
    $self->_set_errormsg($error_msgs{'NotAts'});
    return(0);
  }

  my $fps = $self->get_fps();

  my $frame = $fps * $ts;

  $frame += $inc;
  # Convert to dec 
  $frame = sprintf("%d", $frame);

  return($frame);
}

#####

sub ts_to_frame {
  my ($self, $ts) = @_;
  # add 1 because a '0' ts is a '1' frame
  return($self->_ts_to_frame($ts, 1.0));
}

#####

sub end_ts_to_frame {
  my ($self, $ts) = @_;
  return($self->_ts_to_frame($ts, 0.0));
}

##########

sub _get_begend_ts_core {
  my $self = $_[0];

  return(0) if ($self->{errorv});

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{'FPSNotSet'});
    return(0);
  }
  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0);
  }

  my ($beg, $end) = ($self->{beg}, $self->{end});

  # Frames start at 1 but ts start at 0 (but frame_to_ts takes care of it)
  # So we do not touch beg

  # For 'end' we add 1 because the frame is valid until
  # the end of the framespan end value (example "1:1" is from beginning of 1
  # to end of 1)
  $end++;

  return($beg, $end);
}

#####

sub get_beg_end_ts {
  my $self = $_[0];

  my ($beg, $end) = $self->_get_begend_ts_core();
  return($beg) if ($self->{errorv});

  my $beg_ts = $self->frame_to_ts($beg);
  my $end_ts = $self->frame_to_ts($end);

  return($beg_ts, $end_ts);
}

#####

sub get_beg_ts {
  my $self = $_[0];

  my ($beg, $end) = $self->get_beg_end_ts();
  return($beg) if ($self->{errorv});

  return($beg);
}

#####

sub get_end_ts {
  my $self = $_[0];

  my ($beg, $end) = $self->get_beg_end_ts();
  return($beg) if ($self->{errorv});

  return($end);
}

##########

sub extent_middlepoint_ts {
  # arg 0: self

  return(-1) if ($_[0]->{errorv});

  if (! $_[0]->is_fps_set()) {
    $_[0]->_set_errormsg($error_msgs{'FPSNotSet'});
    return(-1);
  }

  my $mf = $_[0]->extent_middlepoint();
  return($mf) if ($_[0]->{errorv});

  return($_[0]->end_frame_to_ts($mf));
}

#####

sub extent_middlepoint_distance_ts {
  # arg 0: self
  # arg 1: other

  my $m1 = $_[0]->extent_middlepoint_ts();
  return($m1) if ($_[0]->{errorv});

  my $m2 = $_[1]->extent_middlepoint_ts();
  if ($_[1]->{errorv}) {
    $_[0]->_set_errormsg($_[1]->get_errormsg());
    return($m2);
  }

  return($m2 - $m1);
}

#####

sub extent_duration_ts {
  my $self = $_[0];

  return(-1) if ($self->{errorv});

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{'FPSNotSet'});
    return(-1);
  }

  my $d = $self->extent_duration();
  return($d) if ($self->{errorv});

  return($self->end_frame_to_ts($d));
}

#####

sub duration_ts {
  my $self = $_[0];

  return(-1) if ($self->{errorv});

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{'FPSNotSet'});
    return(-1);
  }

  my $d = $self->duration();
  return($d) if ($self->{errorv});

  return($self->end_frame_to_ts($d));
}

######################################## framespan shift function

sub negative_value_shift {
  my ($self, $val) = @_;

  return(0) if ($self->{errorv});

  # "negative" shifts correct all values under 1
  return($self->value_shift($val, 1));
}

#####

sub value_shift {
  my ($self, $val, $neg) = @_;

  return(0) if ($self->{errorv});

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(0);
  }

  $val = -$val
    if ($neg);

  my $fs = $self->{value};

  my @in = &_fs_split_line($fs);
  my @out = ();
  for (my $i = 0; $i < scalar @in; $i++) {
    my $entry = $in[$i];
    my ($b, $e) = &_fs_split_pair_nocheck($entry);

    $b += $val;
    $e += $val;

    if ($neg) {
      $b = 1 if ($b < 1);
      $e = 1 if ($e < 1);
    }

    push @out, "$b:$e";
  }

  return($self->set_value(MMisc::fast_join(' ', \@out)));
}

#####

sub value_shift_auto {
  my ($self, $val) = @_;

  return(0) if ($self->{errorv});

  return($self->negative_value_shift(-$val))
    if ($val < 0);

  return($self->value_shift($val));
}

######################################## list of frames

sub list_frames {
  my $self = $_[0];

  my @out = ();

  return(@out) if ($self->{errorv});

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(@out);
  }

  my $v = $self->{value};

  my @todo = &_fs_split_line($v);
  for (my $i = 0; $i < scalar @todo; $i++) {
    my $pair = $todo[$i];
    my ($b, $e) = &_fs_split_pair_nocheck($pair);

    for (my $c = $b; $c <= $e; $c++) {
      push @out, $c;
    }
  }

  return(@out);
}

#####

sub list_pairs {
  my $self = $_[0];

  my @out = ();

  return(@out) if ($self->{errorv});

  if (! $self->{valueset}) {
    $self->_set_errormsg($error_msgs{'NoFramespanSet'});
    return(@out);
  }

  my $v = $self->{value};

  my @todo = &_fs_split_line($v);

  return(MMisc::make_array_of_unique_values(\@todo));
}

########################################

sub unit_test {                 # Xtreme coding and us ;)
  my ($notverb, $makecall) = @_;

  my $eh = 'unit_test:';
  my @otxt = ();

  print 'Testing ViperFramespan ... ' if ($makecall);

  # Let us try to set a bad value
  my $fs_tmp1 = new ViperFramespan('Not a framespan');
  my $err1 = $fs_tmp1->get_errormsg();
  my $ee = $error_msgs{'NotFramespan'};
  push(@otxt, "$eh [#1] Error while checking \'set_value\'[1] ($err1).")
    if ($err1 !~ m%$ee$%);
  
  # Or an empty framespan
  my $fs_tmp2 = new ViperFramespan();
  $fs_tmp2->set_value('');
  my $err2 = $fs_tmp2->get_errormsg();
  $ee = $error_msgs{'EmptyValue'};
  push(@otxt, "$eh [#2] Error while checking \'set_value\'[2] ($err2).")
    if ($err2 !~ m%$ee$%);
  
  # Not ordered framespan
  my $in3 = '5:4';
  my $fs_tmp3 = new ViperFramespan($in3);
  my $err3 = $fs_tmp3->get_errormsg();
  $ee = $error_msgs{'NotOrdered'};
  push(@otxt, "$eh [#3] Error while checking \'set_value\'[3] ($err3).")
    if ($err3 !~ m%$ee$%);
  
  # Start a 0
  my $in4 = '0:1';
  my $fs_tmp4 = new ViperFramespan();
  $fs_tmp4->set_value($in4);
  my $err4 = $fs_tmp4->get_errormsg();
  $ee = $error_msgs{'StartAt0'};
  push(@otxt, "$eh [#4] Error while checking \'new\'[4] ($err4).")
    if ($err4 !~ m%$ee$%);
  
  # Reorder
  my $in5 = '4:5 1:2 12:26 8:8';
  my $exp_out5 = '1:2 4:5 8:8 12:26';
  my $fs_tmp5 = new ViperFramespan();
  $fs_tmp5->set_value($in5);
  my $out5 = $fs_tmp5->get_value();
  push(@otxt, "$eh [#5a] Error while checking \'new\'[reorder] (expected: $exp_out5 / Got: $out5).")
    if ($out5 ne $exp_out5);

  # Reorder (2)
  $in5 = '4:7 1:2 1:2';
  $exp_out5 = '1:2 4:7';
  $fs_tmp5->set_value($in5);
  $out5 = $fs_tmp5->get_value();
  push(@otxt, "$eh [#5b] Error while checking \'new\'[reorder] (expected: $exp_out5 / Got: $out5). ")
    if ($out5 ne $exp_out5);
  
  # Shorten
  my $in6 = '1:2 2:3 4:5';
  my $exp_out6 = '1:5';
  my $fs_tmp6 = new ViperFramespan();
  $fs_tmp6->set_value($in6);
  my $out6 = $fs_tmp6->get_value();
  push(@otxt, "$eh [#6a] Error while checking \'new\'[shorten] (expected: $exp_out6 / Got: $out6).")
    if ($out6 ne $exp_out6);
  
  # Shorten (2)
  $in6 = '1:3 1:2';
  $exp_out6 = '1:3';
  $fs_tmp6->set_value($in6);
  my $out6 = $fs_tmp6->get_value();
  push(@otxt, "$eh [#6b] Error while checking \'new\'[shorten] (expected: $exp_out6 / Got: $out6).")
    if ($out6 ne $exp_out6);
  
  # No Framespan Set
  my $fs_tmp7 = new ViperFramespan();
  my $test7 = $fs_tmp7->check_if_overlap(); # We are checking against nothing here
  my $err7 = $fs_tmp7->get_errormsg();
  $ee = $error_msgs{'NoFramespanSet'};
  push(@otxt, "$eh [#7] Error while checking \'check_if_overlap\' ($err7).")
    if ($err7 !~ m%$ee$%);
  
  # Overlap & Within
  my $in8  = '1:10';
  my $in9  = '4:16';
  my $in10 = '11:15';
  my $fs_tmp8  = new ViperFramespan();
  my $fs_tmp9  = new ViperFramespan();
  my $fs_tmp10 = new ViperFramespan();
  $fs_tmp8->set_value($in8);
  $fs_tmp9->set_value($in9);
  $fs_tmp10->set_value($in10);
  
  my $testa = $fs_tmp8->check_if_overlap($fs_tmp9);
  push(@otxt, "$eh [#8a] Error while checking \'check_if_overlap\' ($in8 and $in9 do overlap, but test says otherwise).")
    if (! $testa);
  
  my $testb = $fs_tmp8->check_if_overlap($fs_tmp10);
  push(@otxt, "$eh [#8b] Error while checking \'check_if_overlap\' ($in8 and $in10 do not overlap, but test says otherwise).")
    if ($testb);
  
  my $testc = $fs_tmp10->is_within($fs_tmp9);
  push(@otxt, "$eh [#8c] Error while checking \'is_within\' ($in10 is within $in9, but test says otherwise).")
    if (! $testc);
  
  my $testd = $fs_tmp9->is_within($fs_tmp10);
  push(@otxt, "$eh [#8d] Error while checking \'is_within\' ($in9 is not within $in10, but test says otherwise).")
    if ($testd);
  
  my @tmpa = ($fs_tmp10, $fs_tmp9);
  my ($teste, $rfs) = $fs_tmp8->check_if_overlap_s(\@tmpa);
  if (! $teste) {
    push(@otxt, "$eh [#8e] Error while checking \'check_if_overlap_s\' ($in8 vs $in10 and $in9 do overlap, but test says otherwise).");
  } else {
    push(@otxt, "$eh [#8e] Error while checking \'check_if_overlap_s\' ($in8 vs $in10 and $in9 do overlap for part of $in9, but returned ViperFramepsan object [" . $$rfs->get_value() . "] is different")
    if ($$rfs->get_value() ne $in9);
  }
  
  # optimize + count_pairs
  my $in11 = '20:40 1:2 1:1 2:6 8:12 20:40'; # 6 pairs (not optimized)
  my $exp_out11 = '1:6 8:12 20:40'; # 3 pairs (once optimized)
  my $fs_tmp11 = new ViperFramespan();
  $fs_tmp11->set_value($in11);
  my $out11 = $fs_tmp11->get_value();
  push(@otxt, "$eh [#11a] Error while checking \'new\'[count_pairs] (expected: $exp_out11 / Got: $out11).")
    if ($out11 ne $exp_out11);
  
  my $etmp11a = &_fs_split_line_count($in11);
  my $tmp11a = $fs_tmp11->count_pairs_in_original_value();
  push(@otxt, "$eh [#11b] Error while checking \'count_pairs_in_original_value\' (expected: $etmp11a / Got: $tmp11a).")
    if ($etmp11a != $tmp11a);
  
  my $etmp11b = &_fs_split_line_count($exp_out11);
  my $tmp11b = $fs_tmp11->count_pairs_in_value();
  push(@otxt, "$eh [#11c] Error while checking \'count_pairs_in_value\' (expected: $etmp11b / Got: $tmp11b).")
    if ($etmp11b != $tmp11b);
  
  # extent_middlepoint + extent_middlepoint_distance
  my $in12 = '20:39';
  my $fs_tmp12 = new ViperFramespan($in12);
  my $exp_out12 = 30;           # = 20 + (((39+1) - 20) / 2)
  my $out12 = $fs_tmp12->extent_middlepoint();
  push(@otxt, "$eh [#12] Error while checking \'extent_middlepoint\' (expected: $exp_out12 / Got: $out12).")
    if ($exp_out12 != $out12);
  
  my $in13 = '100:199';         # extent_middlepoint: 150
  my $fs_tmp13 = new ViperFramespan($in13);

  my $out13 = $fs_tmp12->extent_middlepoint_distance($fs_tmp13);
  my $exp_out13 = 120;          # from 30 to 150 : +120
  push(@otxt, "$eh [#13] Error while checking \'extent_middlepoint_distance\'[1] (expected: $exp_out13 / Got: $out13).")
    if ($exp_out13 != $out13);

  my $out14 = $fs_tmp13->extent_middlepoint_distance($fs_tmp12);
  my $exp_out14 = -120;         # from 150 to 30 : -120
  push(@otxt, "$eh [#14] Error while checking \'extent_middlepoint_distance\'[2] (expected: $exp_out14 / Got: $out14).")
    if ($exp_out14 != $out14);

  my $out15 = $fs_tmp12->extent_duration();
  my $exp_out15 = 20;           # 20 [0] to 39 [19] = 20
  push(@otxt, "$eh [#15a] Error while checking \'extent_duration\' (expected: $exp_out15 / Got: $out15).")
    if ($exp_out15 != $out15);

  my $out15 = $fs_tmp12->duration();
  my $exp_out15 = 20; # 20 [0] to 39 [19] = 20 (same as extent_duration because there is no gap in the framespan)
  push(@otxt, "$eh [#15b] Error while checking \'duration\' (expected: $exp_out15 / Got: $out15).")
    if ($exp_out15 != $out15);

  my $out16 = $fs_tmp11->get_list_of_framespans();
  my @expSub = split(/ /, $exp_out11);
  push(@otxt, "$eh [#16] Error getting a list of framespan expected: 3 / got: ".scalar(@$out16) . '.')
    if (scalar(@expSub) != scalar(@$out16));
  MMisc::error_quit($fs_tmp11->get_errormsg())
        if ($fs_tmp11->error());
  for (my $_i = 0; $_i < scalar @expSub; $_i++) {
    MMisc::error_quit($out16->[$_i]->get_errormsg())
        if ($out16->[$_i]->error());
    push(@otxt, "$eh [#16+] Error get_list_of_framespan list[$_i] incorrect.  expected '$expSub[$_i]' / got '".$out16->[$_i]->get_value()."'. ") 
      if ($expSub[$_i] ne $out16->[$_i]->get_value())
  }

  ### unit test overlap
  my $fs_tmp17 = new ViperFramespan();
  my $fs_tmp18 = new ViperFramespan();
  my @pairs = 
    (
     [ '3:6', '3:6', '3:6' ], 
     [ '3:6', '4:6', '4:6' ], 
     [ '3:6', '6:6', '6:6' ], 
     [ '3:6', '4:7', '4:6' ], 
     [ '3:6', '6:7', '6:6' ], 
     [ '3:6', '7:8', '' ],
     [ '1:5 10:15 20:50', '8:40', '10:15 20:40' ],
     [ '1:5 8:20 25:50 55:80 85:100', '1:100', '1:5 8:20 25:50 55:80 85:100' ],
     [ '2:2 6:6 12:12', '6:6', '6:6' ],
     [ '1:1 3:3', '2:2', '' ],
     [ '1:1 3:3 5:5 7:7 9:9', '9:9 3:5', '3:3 5:5 9:9' ],
    );
  for (my $p = 0; $p < scalar @pairs; $p++) {
    $fs_tmp17->set_value($pairs[$p][0]);
    $fs_tmp18->set_value($pairs[$p][1]);
    my $fs_new = $fs_tmp17->get_overlap($fs_tmp18);
#    print ("[*] ", $fs_tmp17->get_errormsg(), "\n") if ($fs_tmp17->error());
    if (MMisc::is_blank($pairs[$p][2])) {
      if (defined $fs_new) {
        push(@otxt, "$eh [#17a] Error overlap calc for (".join(', ',@{ $pairs[$p] }[0..1]).') returned something [ ' . $fs_new->get_value() . ']');
        next;
      }
#      print "[undef]\n";
    } else {
      if (! defined $fs_new) {
        push(@otxt, "$eh [#17b] Error overlap calc for (".join(', ',@{ $pairs[$p] }[0..1]).') did not return anything [expected: ' . $pairs[$p][2] . ']');
        next;
      }
      my $ret = $fs_new->get_value();
#     print "[" . $pairs[$p][0] . "] ov [" . $pairs[$p][1] . "] -> [$ret]\n";
      push(@otxt, "$eh [#17c] Error overlap calc for (".join(', ',@{ $pairs[$p] }).') returned ' . $ret . '.') 
        if ($ret ne $pairs[$p][2]);
    }
  }
    
  # List frames
  my $in19 = '4:7 1:2 1:2';
  my $exp_out19 = '1 2 4 5 6 7';
  my $fs_tmp19 = new ViperFramespan($in19);
  my @aout19 = $fs_tmp19->list_frames();
  my $out19 = join(' ', @aout19);
  push(@otxt, "$eh [#19] Error while checking \'list_frames\' (expected: $exp_out19 / Got: $out19).")
    if ($out19 ne $exp_out19);
    
  # xor
  my $in20_1 = '500:800 900:1000 1200:1300';
  my $in20_2 = '100:1100';
  my $exp_out20_1 = '500:800 900:1000'; # overlap ( <=> and )
  my $exp_out20_2 = '100:1100 1200:1300'; # union ( <=> or )
  my $exp_out20_3 = '100:499 801:899 1001:1300'; # bounded not (of overlap)
  my $exp_out20_4 = '100:499 801:899 1001:1100 1200:1300'; # xor
  my $exp_out20_5 = '100:499 801:899 1001:1100'; # remove 1 from 2
  
  my $fs_tmp20_1 = new ViperFramespan($in20_1);
  my $fs_tmp20_2 = new ViperFramespan($in20_2);

  my $fs_out20_1 = $fs_tmp20_1->get_overlap($fs_tmp20_2);
  my $out20_1 = $fs_out20_1->get_value();
  push(@otxt, "$eh [#20a] Error while checking \'get_overlap\' (expected: $exp_out20_1 / Got: $out20_1).")
    if ($out20_1 ne $exp_out20_1);

  my $fs_tmp20_3 = $fs_tmp20_1->clone();
  my $ok_out20_3 = $fs_tmp20_3->union($fs_tmp20_2);
  my $out20_2 = $fs_tmp20_3->get_value();
  push(@otxt, "$eh [#20b] Error while checking \'union\' (expected: $exp_out20_2 / Got: $out20_2).")
    if ($out20_2 ne $exp_out20_2);

  my $fs_tmp20_4 = $fs_out20_1->bounded_not(100, 1300);
  my $out20_3 = $fs_tmp20_4->get_value();
  push(@otxt, "$eh [#20c] Error while checking \'get_overlap\' (expected: $exp_out20_3 / Got: $out20_3).")
    if ($out20_3 ne $exp_out20_3);

  my $fs_tmp20_5 = $fs_tmp20_1->get_xor($fs_tmp20_2);
  my $out20_4 = $fs_tmp20_5->get_value();
  push(@otxt, "$eh [#20d] Error while checking \'get_xor\' (expected: $exp_out20_4 / Got: $out20_4).")
    if ($out20_4 ne $exp_out20_4);
  
  my $ok = $fs_tmp20_2->remove($fs_tmp20_1);
  my $out20_5 = $fs_tmp20_2->get_value();
  push(@otxt, "$eh [#20e] Error while checking \'remove\' (expected: $exp_out20_5 / Got: $out20_5).")
    if ($out20_5 ne $exp_out20_5);
  
  # not (bounded) + xor
  my $in21_1 = '20:50 60:80';
  my $in21_2 = '10:20 80:100';
  my $exp_out21_1 = '10:19 51:59 81:100';
  my $exp_out21_2 = '21:79';
  my $exp_out21_5 = '10:100';

  my $fs_tmp21_1 = new ViperFramespan($in21_1);
  my $fs_tmp21_2 = new ViperFramespan($in21_2);

  my $fs_tmp21_3 = $fs_tmp21_1->bounded_not(10, 100);
  my $out21_3 = $fs_tmp21_3->get_value();
  push(@otxt, "$eh [#21a] Error while checking \'bounded_not\' (expected: $exp_out21_1 / Got: $out21_3).")
    if ($out21_3 ne $exp_out21_1);

  my $fs_tmp21_4 = $fs_tmp21_2->bounded_not(10, 100);
  my $out21_4 = $fs_tmp21_4->get_value();
  push(@otxt, "$eh [#21b] Error while checking \'bounded_not\' (expected: $exp_out21_2 / Got: $out21_4).")
    if ($out21_4 ne $exp_out21_2);

  my $fs_tmp21_5 = $fs_tmp21_2->get_xor($fs_tmp21_4);
  my $out21_5 = $fs_tmp21_5->get_value();
  push(@otxt, "$eh [#21c] Error while checking \'bounded_not\' (expected: $exp_out21_5 / Got: $out21_5).")
    if ($out21_5 ne $exp_out21_5);

  # xor, overlap
  my $in22_1 = '1:10 20:30 40:50 60:70';
  my $in22_2 = '10:20 30:60';
  my $exp_out22_1 = '1:9 11:19 21:29 31:39 51:59 61:70'; # xor
  my $exp_out22_2 = '10:10 20:20 30:30 40:50 60:60'; # ov
  my $exp_out22_3 = '1:70'; # union
  my $exp_out22_4 = $exp_out22_1; # not of ov 
  my $exp_out22_5 = '1:9 21:29 61:70'; # rem 2 from 1
  my $exp_out22_6 = '80:90'; # ! in1 between (80,90)
  my $exp_out22_7 = '11:19'; # ! in1 between (10,20)
  #8: ! in 2 between (10,20) => undef
  
  my $fs_tmp22_1 = new ViperFramespan($in22_1);
  my $fs_tmp22_2 = new ViperFramespan($in22_2);

  my $fs_tmp22_3 = $fs_tmp22_1->get_xor($fs_tmp22_2);
  my $out22_1 = $fs_tmp22_3->get_value();
  push(@otxt, "$eh [#22a] Error while checking \'get_xor\' (expected: $exp_out22_1 / Got: $out22_1).")
    if ($out22_1 ne $exp_out22_1);
  
  my $fs_tmp22_4 = $fs_tmp22_1->get_overlap($fs_tmp22_2);
  my $out22_2 = $fs_tmp22_4->get_value();
  push(@otxt, "$eh [#22b] Error while checking \'get_overlap\' (expected: $exp_out22_2 / Got: $out22_2).")
    if ($out22_2 ne $exp_out22_2);

  my $fs_tmp22_5 = $fs_tmp22_2->clone();
  my $ok = $fs_tmp22_5->union($fs_tmp22_1);
  my $out22_3 = $fs_tmp22_5->get_value();
  push(@otxt, "$eh [#22c] Error while checking \'union\' (expected: $exp_out22_3 / Got: $out22_3).")
    if ($out22_3 ne $exp_out22_3);
  
  my $fs_tmp22_6 = $fs_tmp22_4->bounded_not(1, 70);
  my $out22_4 = $fs_tmp22_6->get_value();
  push(@otxt, "$eh [#22d] Error while checking \'not overlap\' (expected: $exp_out22_4 / Got: $out22_4).")
    if ($out22_4 ne $exp_out22_4);

  my $fs_tmp22_7 = $fs_tmp22_1->clone();
  my $ok = $fs_tmp22_7->remove($fs_tmp22_2);
  my $out22_5 = $fs_tmp22_7->get_value();
  push(@otxt, "$eh [#22e] Error while checking \'remove\' (expected: $exp_out22_5 / Got: $out22_5).")
    if ($out22_5 ne $exp_out22_5);

  my $fs_tmp22_8 = $fs_tmp22_1->bounded_not(80, 90);
  my $out22_6 = $fs_tmp22_8->get_value();
  push(@otxt, "$eh [#22f] Error while checking \'bounded_not\' (expected: $exp_out22_6 / Got: $out22_6).")
    if ($out22_6 ne $exp_out22_6);

  my $fs_tmp22_9 = $fs_tmp22_1->bounded_not(10, 20);
  my $out22_7 = $fs_tmp22_9->get_value();
  push(@otxt, "$eh [#22g] Error while checking \'bounded_not\' (expected: $exp_out22_7 / Got: $out22_7).")
    if ($out22_7 ne $exp_out22_7);

  my $fs_tmp22_10 = $fs_tmp22_2->bounded_not(10, 20);
  push(@otxt, "$eh [#22h] Error while checking \'bounded_not\' (expected: undef).")
    if (defined $fs_tmp22_10);

  # Big overlap (1)
  my @a_tmp23a = ();
  my @a_tmp23b = ();
  my @a_out23 = ();
  for (my $f = 1; $f < 1000; $f++) {
    push @a_tmp23a, sprintf("%d:%d", $f*100,      $f*100 + 50);
    push @a_tmp23b, sprintf("%d:%d", $f*100 + 25, $f*100 + 50 + 25);
    push @a_out23,  sprintf("%d:%d", $f*100 + 25, $f*100 + 50);
  }
  my $fs_tmp23a = new ViperFramespan(join(' ', @a_tmp23a));
  my $fs_tmp23b = new ViperFramespan(join(' ', @a_tmp23b));
  my $exp_out23 = join(' ', @a_out23);
  my $fs_out23 = $fs_tmp23a->get_overlap($fs_tmp23b);
  my $out23 = $fs_out23->get_value();
  push(@otxt, "$eh [#23] Error while checking (big1) \'get_overlap\' (expected: $exp_out23 / Got: $out23).")
    if ($exp_out23 ne $out23);

  # Big overlap (2)
  my @a_tmp24a = ();
  my @a_tmp24b = ();
  my @a_out24 = ();
  for (my $f = 1; $f < 1000; $f++) {
    push @a_tmp24a, sprintf("%d:%d", $f*2, $f*2);
    push @a_tmp24b, sprintf("%d:%d", $f*8, $f*8 + 1);
    next if ($f > 249);
    push @a_out24,  sprintf("%d:%d", $f*8, $f*8);
  }
  my $fs_tmp24a = new ViperFramespan(join(' ', @a_tmp24a));
  my $fs_tmp24b = new ViperFramespan(join(' ', @a_tmp24b));
  my $exp_out24 = join(' ', @a_out24);
  my $fs_out24 = $fs_tmp24a->get_overlap($fs_tmp24b);
  my $out24 = $fs_out24->get_value();
  push(@otxt, "$eh [#24] Error while checking (big2) \'get_overlap\' (expected: $exp_out24 / Got: $out24).")
    if ($exp_out24 ne $out24);

  # Specific overlap
  my $fs_tmp25a = new ViperFramespan('5401:5401 5413:5413 5425:5425 5437:5437 5449:5449 5461:5461 5473:5473 5485:5485 5497:5497 5509:5509 5521:5521 5533:5533 5545:5545 5557:5557 5569:5569 5581:5581 5593:5593 5605:5605 5617:5617 5629:5629 5641:5641 5653:5653 5665:5665 5677:5677 5689:5689 5701:5701 5713:5713 5725:5725 5737:5737 5749:5749 5761:5761 5773:5773 5785:5785 5797:5797 5809:5809 5821:5821 5833:5833 5845:5845 5857:5857 5869:5869 5881:5881 5893:5893 5905:5905 5917:5917 5929:5929 5941:5941 5953:5953 5965:5965 5977:5977 5989:5989 6001:6001 6013:6013 6025:6025 6037:6037 6049:6049 6061:6061 6073:6073 6085:6085 6097:6097 6109:6109 6121:6121 6133:6133 6145:6145 6157:6157 6169:6169 6181:6181 6193:6193 6205:6205 6217:6217 6229:6229 6241:6241 6253:6253 6265:6265 6277:6277 6289:6289 6301:6301 6313:6313 6325:6325 6337:6337 6349:6349 6361:6361 6373:6373 6385:6385 6397:6397 6409:6409 6421:6421 6433:6433 6445:6445 6457:6457 6469:6469 6481:6481 6493:6493 6505:6505 6517:6517 6529:6529 6541:6541 6553:6553 6565:6565 6577:6577 6589:6589 6601:6601 6613:6613 6625:6625 6637:6637 6649:6649 6661:6661 6673:6673 6685:6685 6697:6697 6709:6709 6721:6721 6733:6733 6745:6745 6757:6757 6769:6769 6781:6781 6793:6793 6805:6805 6817:6817 6829:6829 6841:6841 6853:6853 6865:6865 6877:6877 6889:6889 6901:6901 6913:6913 6925:6925 6937:6937 6949:6949 6961:6961 6973:6973 6985:6985 6997:6997 7009:7009 7021:7021 7033:7033 7045:7045 7057:7057 7069:7069 7081:7081 7093:7093 7105:7105 7117:7117 7129:7129 7141:7141 7153:7153 7165:7165 7177:7177 7189:7189 7201:7201 7213:7213 7225:7225 7237:7237 7249:7249 7261:7261 7273:7273 7285:7285 7297:7297 7309:7309 7321:7321 7333:7333 7345:7345 7357:7357 7369:7369 7381:7381 7393:7393 7405:7405 7417:7417 7429:7429 7441:7441 7453:7453 7465:7465 7477:7477 7489:7489 7501:7501 7513:7513 7525:7525 7537:7537 7549:7549 7561:7561 7573:7573 7585:7585 7597:7597 7609:7609 7621:7621 7633:7633 7645:7645 7657:7657 7669:7669 7681:7681 7693:7693 7705:7705 7717:7717 7729:7729 7741:7741 7753:7753 7765:7765 7777:7777 7789:7789 7801:7801 7813:7813 7825:7825 7837:7837 7849:7849 7861:7861 7873:7873 7885:7885 7897:7897 7909:7909 7921:7921 7933:7933 7945:7945 7957:7957 7969:7969 7981:7981 7993:7993 8005:8005 8017:8017 8029:8029 8041:8041 8053:8053 8065:8065 8077:8077 8089:8089 8101:8101 8113:8113 8125:8125 8137:8137 8149:8149 8161:8161 8173:8173 8185:8185 8197:8197 8209:8209 8221:8221 8233:8233');
  my $fs_tmp25b = new ViperFramespan('7519:7699 7701:7701 7708:7723 7725:7725 7727:7867 7889:7889 7891:7896 7902:7983 7985:7989 7991:7991 8051:8051 8085:8085 8087:8240');
  my $exp25 = '7525:7525 7537:7537 7549:7549 7561:7561 7573:7573 7585:7585 7597:7597 7609:7609 7621:7621 7633:7633 7645:7645 7657:7657 7669:7669 7681:7681 7693:7693 7717:7717 7729:7729 7741:7741 7753:7753 7765:7765 7777:7777 7789:7789 7801:7801 7813:7813 7825:7825 7837:7837 7849:7849 7861:7861 7909:7909 7921:7921 7933:7933 7945:7945 7957:7957 7969:7969 7981:7981 8089:8089 8101:8101 8113:8113 8125:8125 8137:8137 8149:8149 8161:8161 8173:8173 8185:8185 8197:8197 8209:8209 8221:8221 8233:8233';
  my $fs_ov25 = $fs_tmp25a->get_overlap($fs_tmp25b);
  my $out25 = $fs_ov25->get_value();
  push(@otxt, "$eh [#25] Error while checking (specific) \'get_overlap\' (expected: $exp25 / Got: $out25).")
    if ($exp25 ne $out25);

  ########## TODO: unit_test for all 'fps' functions ##########

  #####
  # End
  if (scalar @otxt > 0) {
    my $txt = "[ViperFramespan] unit_test errors:\n - " . join("\n - ", @otxt) . "\n";
    MMisc::error_quit("failed\n$txt") if ($makecall);
    print($txt) if (! $notverb);
    return(0);
  }
 
  MMisc::ok_quit('OK') if ($makecall);
  # return 1 if no error found
  return(1);
}

#################### 'clone'

sub clone {
  my $self = $_[0];

  return(undef) if ($self->{errorv});

  my $clone = new ViperFramespan($self->get_original_value());
  $clone->set_fps($self->get_fps()) if ($self->is_fps_set());

  return($clone);
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errorh}->set_errormsg($txt);
  $self->{errorv} = $self->{errorh}->error();
}

##########

sub get_errormsg {
  my $self = $_[0];
  return($self->{errorh}->errormsg());
}

##########

sub error {
  # arg 0: self
  return($_[0]->{errorv});
}

##########

sub clear_error {
  my $self = $_[0];
  $self->{errorv} = 0;
  return($self->{errorh}->clear());
}

############################################################

1;
