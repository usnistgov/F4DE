package BipartiteMatch;

# BipartiteMatch
#
# Author(s): Martial Michel
# Includes code from: Jerome Ajot, Jon Fiscus, George Doddington
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "BipartiteMatch.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "BipartiteMatch.pm Version: $version";

########################################
# The trick it to keep the code totaly independent from any other package
# (except for Dumper, 
use Data::Dumper;
# the Misc Functions
use MMisc;
# and the Error Handler
use MErrorH;

## Constructor
sub new {
  my ($class) = shift @_;
  
  my $errormsg = new MErrorH("BipartiteMatch");

  my $errortxt = (scalar @_ != 4) ? "BipartiteMatch \'new\' parameters are: (\\%%refObjects, \\%%sysObjects, \\&KernelFunction, \\\@KernelFunction_AdditionalParameters)" : "";
  $errormsg->set_errormsg($errortxt);

  my ($rrefObjects, $rsysObjects, $rKernelFunction, $rKernelAdditionalParameters) = @_;

  my $self =
    {
     refObj         => $rrefObjects,
     sysObj         => $rsysObjects,
     KernelFunction => $rKernelFunction,
     KernelAddParam => $rKernelAdditionalParameters,
     computed       => 0,
     # Computation results
     joint_values   => undef,
     false_alarms_values   => undef,
     missed_detect_values  => undef,
     mapping        => undef,
     # 'MappedRecords'
     unmapped_ref   => undef,
     unmapped_sys   => undef,
     mapped         => undef,
     # Error Handler
     errormsg       => $errormsg,
    };

  bless $self;
  return($self);
}

####################

sub get_version {
  my ($self) = @_;

  return($versionid);
}

########## 'mapped', 'unmapped_ref', 'unmapped_sys' IDs

sub _get_XXX_ids {
  my ($self, $xxx) = @_;

  return(undef) if ($self->error());

  if (! $self->is_computed()) {
    $self->_set_errormsg("Can not call \'get_${xxx}_ids\' on a non \'computed\' value");
    return(undef);
  }

  my $rxxx = $self->{$xxx};
  my @res = @{$rxxx};

  return(@res);
}

#####

sub get_mapped_ids {
  my ($self) = @_;

  return($self->_get_XXX_ids("mapped"));
}

#####

sub get_unmapped_ref_ids {
  my ($self) = @_;

  return($self->_get_XXX_ids("unmapped_ref"));
}

#####

sub get_unmapped_sys_ids {
  my ($self) = @_;

  return($self->_get_XXX_ids("unmapped_sys"));
}

########## 'mapped', 'unmapped_ref', 'unmapped_sys' Objects

sub _get_known_key_in_hash {
  my ($self, $key, %inhash) = @_;

  if (! exists $inhash{$key}) {
    $self->_set_errormsg("Can not find requested known existing key ($key) in given hash");
    return(undef);
  }

  my $val = $inhash{$key};

  return($val);
}

#####

sub get_mapped_objects {
  my ($self) = @_;

  my @out;

  my @mapped = $self->get_mapped_ids();
  return(@out) if (($self->error()) || (scalar @mapped == 0));

  my %sysObj = %{$self->{sysObj}};
  my %refObj = %{$self->{refObj}};

  my @tmp;
  # mapped is the only two dimensional array
  for (my $i = 0; $i < scalar @mapped; $i++) {
    my ($sys_id, $ref_id) = @{$mapped[$i]};

    my $sys_obj = $self->_get_known_key_in_hash($sys_id, %sysObj);
    return(@out) if ($self->error());

    my $ref_obj = $self->_get_known_key_in_hash($ref_id, %refObj);
    return(@out) if ($self->error());

    push @tmp, [ ($sys_obj, $ref_obj) ];
  }

  @out = @tmp;

  return(@out);
}

#####

sub _get_XXX_objects {
  my ($self, $xxx, %inhash) = @_;

  my @out;

  my @xxxs = $self->_get_XXX_ids($xxx);
  return(@out) if (($self->error()) || (scalar @xxxs == 0));

  foreach my $obj_id (@xxxs) {
    my $obj = $self->_get_known_key_in_hash($obj_id, %inhash);
    return(undef) if ($self->error());

    push @out, $obj;
  }

  return(@out);
}

#####

sub get_unmapped_ref_objects {
  my ($self) = @_;

  my %refObj = %{$self->{refObj}};

  return($self->_get_XXX_objects("unmapped_ref", %refObj));
}

#####

sub get_unmapped_sys_objects {
  my ($self) = @_;

  my %sysObj = %{$self->{sysObj}};

  return($self->_get_XXX_objects("unmapped_sys", %sysObj));
}

########## 'computed'

sub is_computed {
  my ($self) = @_;

  return(0) if ($self->error());

  return($self->{computed});
}

################################################################################

# Original Authors: Jerome Ajot, Jon Fiscus
# Adapted by: Martial Michel
# (was part of STDEval : STDEval.pl)

sub compute {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->is_computed());

  my @kp = @{$self->{KernelAddParam}};
  my %sysObj = %{$self->{sysObj}};
  my %refObj = %{$self->{refObj}};

  ##### Compute joint values
  my %joint_values;
  while (my ($ref_id, $ref_obj) = each %refObj) {
    while (my ($sys_id, $sys_obj) = each %sysObj) {
      my ($err, $res) = &{$self->{KernelFunction}}($ref_obj, $sys_obj, @kp);
      if (! MMisc::is_blank($err)) {
	$self->_set_errormsg("While computing the joint values for sys ID ($sys_id) and ref ID ($ref_id): $err");
	return(0);
      }
      $joint_values{$ref_id}{$sys_id} = $res;
    }
  }
  $self->{joint_values} = \%joint_values;

  ##### Compute false alarms values
  my %fa_values;
  while (my ($sys_id, $sys_obj) = each %sysObj) {
    my ($err, $res) = &{$self->{KernelFunction}}(undef, $sys_obj, @kp);
    if (! MMisc::is_blank($err)) {
      $self->_set_errormsg("While computing the false alarm values for sys ID ($sys_id): $err");
      return(0);
    }
    $fa_values{$sys_id} = $res;
  }
  $self->{false_alarms_values} = \%fa_values;

  ##### Compute missed detect values
  my %md_values;
  while (my ($ref_id, $ref_obj) = each %refObj) {
    my ($err, $res) = &{$self->{KernelFunction}}($ref_obj, undef, @kp);
    if (! MMisc::is_blank($err)) {
      $self->_set_errormsg("While computing the missed detect values for ref ID ($ref_id): $err");
      return(0);
    }
    $md_values{$ref_id} = $res;
  }
  $self->{missed_detect_values} = \%md_values;

  ##### Compute mapping
  my ($err, %map) = &_map_ref_to_sys(\%joint_values, \%fa_values, \%md_values);
  if (! MMisc::is_blank($err)) {
    $self->_set_errormsg("While computing mapping: $err");
    return(0);
  }
  $self->{mapping} = \%map;

  # Set MappedRecord
  my %ref_ids;
  foreach my $ref_id (keys %refObj) {
    $ref_ids{$ref_id}++;
  }
  my %sys_ids;
  foreach my $sys_id (keys %sysObj) {
    $sys_ids{$sys_id}++;
  }
  # 'mapped'
  my @mapped;
  my @unmapped_ref;
  my @unmapped_sys;
  while (my ($ref_id, $sys_id) = each %map) {
    push @mapped, [ ($sys_id, $ref_id) ];
    delete $sys_ids{$sys_id};
    delete $ref_ids{$ref_id};
  }
  # 'unmapped_ref'
  push @unmapped_ref, keys %ref_ids;
  # 'unmapped_sys'
  push @unmapped_sys, keys %sys_ids;

  $self->{mapped} = \@mapped;
  $self->{unmapped_ref} = \@unmapped_ref;
  $self->{unmapped_sys} = \@unmapped_sys;

  $self->{computed} = 1;
  return(1);
}

################################################################################

sub _map_ref_to_sys {
  my ($rjv, $rfa, $rmd) = @_;
  return(&_map_ref_to_sys_cohorts($rjv, $rfa, $rmd));
}

##########

sub _clique_sys2ref {
 my ($cid, $rjv, $sys_id, $rtdr, $rtds, $cr, $cs) = @_;

#  print "S[$cid][$sys_id]\n";
  foreach my $ref_id (keys %{$rtdr}) {
    next if (! exists $$rtdr{$ref_id});
    if (defined $$rjv{$ref_id}{$sys_id}) {
      delete $$rtds{$sys_id} if (exists $$rtds{$sys_id});
      delete $$rtdr{$ref_id} if (exists $$rtdr{$ref_id});
      $$cs{$cid}{$sys_id}++;
      $$cr{$cid}{$ref_id}++;
      &_clique_ref2sys($cid, $rjv, $ref_id, $rtdr, $rtds, $cr, $cs);
    }
  }

}

#####

sub _clique_ref2sys {
  my ($cid, $rjv, $ref_id, $rtdr, $rtds, $cr, $cs) = @_;
  
#  print "R[$cid][$ref_id]\n";
  foreach my $sys_id (keys %{$rtds}) {
    next if (! exists $$rtds{$sys_id});
    if (defined $$rjv{$ref_id}{$sys_id}) {
      delete $$rtdr{$ref_id} if (exists $$rtdr{$ref_id});
      delete $$rtds{$sys_id} if (exists $$rtds{$sys_id});
      $$cr{$cid}{$ref_id}++;
      $$cs{$cid}{$sys_id}++;
      &_clique_sys2ref($cid, $rjv, $sys_id, $rtdr, $rtds, $cr, $cs);
    }
  }

}

##########

sub _map_ref_to_sys_clique_cohorts {
  my ($rjv, $rfa, $rmd) = @_;

  my %td_ref;
  my %td_sys;
  foreach my $ref_id (keys %{$rjv}) { 
    $td_ref{$ref_id}++;
    foreach my $sys_id (keys %{$$rjv{$ref_id}}) {
      $td_sys{$sys_id}++;
    }
  }
  
  ###### Split into 'cliques'
  my $cid = 0;
  my %c_ref;
  my %c_sys;
  
  # Process all refs first
  foreach my $ref_id (keys %td_ref) {
    next if (! exists $td_ref{$ref_id});
    &_clique_ref2sys($cid, $rjv, $ref_id, \%td_ref, \%td_sys, \%c_ref, \%c_sys);
    $cid++;
  }
  
  # Then the leftover sys
  foreach my $sys_id (keys %td_sys) {
    next if (! exists $td_sys{$sys_id});
    &_clique_sys2ref($cid, $rjv, $sys_id, \%td_ref, \%td_sys, \%c_ref, \%c_sys);
    $cid++;
  }
  
  # Now process clique per clique
  my %map;
  for (my $i = 0; $i < $cid; $i++) {
    my @rl;
    @rl = keys %{$c_ref{$i}} if (exists $c_ref{$i});
    my @sl;
    @sl = keys %{$c_sys{$i}} if (exists $c_sys{$i});
    
    # We can only map if there is at least one entry per array
    next if ((scalar @rl == 0) || (scalar @sl == 0));

    my %tmp_jv;
    foreach my $ref_id (@rl) {
      foreach my $sys_id (@sl) {
	$tmp_jv{$ref_id}{$sys_id} = $$rjv{$ref_id}{$sys_id};
      }
    }
    my %tmp_fa;
    foreach my $sys_id (@sl) {
      $tmp_fa{$sys_id} = $$rfa{$sys_id};
    }
    my %tmp_md;
    foreach my $ref_id (@rl) {
      $tmp_md{$ref_id} = $$rmd{$ref_id};
    }
    
    my ($err, %tmp_map) = &_map_ref_to_sys_cohorts(\%tmp_jv, \%tmp_fa, \%tmp_md);
    return($err, %map) if (! MMisc::is_blank($err));

    # Add the temp result to the global result
    foreach my $ref_id (keys %tmp_map) {
      $map{$ref_id} = $tmp_map{$ref_id};
    }
    
  }

  return("", %map);
}

####################

# Original Author: George Doddington
# Adapted by: Martial Michel
# (was Part of STDEval : Mapping.pm)

sub _map_ref_to_sys_cohorts {
  my ($rjv, $rfa, $rmd) = @_;

  my %joint_values = %{$rjv};
  my %fa_values = %{$rfa};
  my %md_values = %{$rmd};

  # Create ref_info, sys_info and reversed_values
  my (%ref_info, %sys_info, %reversed_values);

  foreach my $ref_id (keys %joint_values) {
    return("No missed detect value for ref ID \'$ref_id\'", ())
      if (! defined $md_values{$ref_id});

    $ref_info{$ref_id}
      = {
	 id  => $ref_id,
	 val => $md_values{$ref_id}
	};

    while (my ($sys_id, $value) = each %{$joint_values{$ref_id}}) {
      $reversed_values{$sys_id}{$ref_id} = $value;
    }
  }

  foreach my $sys_id (keys %reversed_values) {
    return("No false alarm value for sys ID \'$sys_id\'", ())
      if (! defined $fa_values{$sys_id});

    $sys_info{$sys_id}
      = {
	 id  => $sys_id,
	 val => $fa_values{$sys_id}
	};
  }

  # Group ref and sys IDs into "cohort sets" and map each set independently
  my %map;
  foreach my $ref (values %ref_info) {
    next if (exists $ref->{cohort});

    # Collect cohorts
    my (@ref_cohorts, @sys_cohorts, %sys_map, %ref_map, @queue);
    @queue = ($ref->{id}, 1);
    $ref->{cohort} = 1;
    $ref->{mapped} = 1;
    push @ref_cohorts, $ref;
    $ref_map{$ref->{id}} = 1;
    while (@queue > 0) {
      my ($id, $ref_type) = splice(@queue, 0, 2); # Remove (and returns) the first two elements of @queue
      if ($ref_type) { # Find sys cohorts for this ref
	foreach my $sys_id (keys %{$joint_values{$id}}) {
	  next if ((defined $sys_map{$sys_id}) or (not defined $joint_values{$id}{$sys_id}));
	  $sys_map{$sys_id} = 1;
	  my $sys = $sys_info{$sys_id};
	  $sys->{cohort} = 1;
	  $sys->{mapped} = 1;
	  push @sys_cohorts, $sys;
	  splice(@queue, scalar @queue, 0, $sys_id, 0); # eq 'push @queue, $sys_id, 0'
	}
      } else { # find ref cohorts for this sys
	foreach my $ref_id (keys %{$reversed_values{$id}}) {
	  next if ((defined $ref_map{$ref_id}) or (not defined $reversed_values{$id}{$ref_id}));
	  $ref_map{$ref_id} = 1;
	  my $ref = $ref_info{$ref_id};
	  $ref->{cohort} = 1;
	  $ref->{mapped} = 1;
	  push @ref_cohorts, $ref;
	  splice(@queue, scalar @queue, 0, $ref_id, 1);
	}
      }
    }

    # Map cohorts
    my %costs;
    foreach my $ref_cohort (@ref_cohorts) {
      my ($ref_id, $md_value) = ($ref_cohort->{id}, $ref_cohort->{val});
      foreach my $sys_cohort (@sys_cohorts) {
	my ($sys_id, $fa_value) = ($sys_cohort->{id}, $sys_cohort->{val});
	$costs{$ref_id}{$sys_id} = $md_value + $fa_value - $joint_values{$ref_id}{$sys_id}
	  if (defined $joint_values{$ref_id}{$sys_id});
      }
    }

    my ($err, %cohort_map) = &_weighted_bipartite_graph_matching(\%costs);
    return("Cohort mapping through Weighted Bipartite Graph Matching failed ($err)", ())
      if (! MMisc::is_blank($err));
    while (my ($ref_id, $sys_id) = each %cohort_map) {
      $map{$ref_id} = $sys_id;
    }
  }

  return("", %map);
}

################################################################################

# Original Author: George Doddington
# Adapted by: Martial Michel
# (was part of STDEval : Graph_Matching.pm)

sub _weighted_bipartite_graph_matching {
  my ($rscore) = @_;

  return("input undefined", ())
    if (! defined $rscore);

  my %score = %{$rscore};
  my @keys = keys %score;

#  print "[%score] ", Dumper(\%score);

  # No element
  return ("", ()) 
    if (scalar @keys == 0);

  # 1 element: skip graph matching an simply pick the minimum cost map
  if (scalar @keys == 1) {
    my $key = $keys[0];
    my %costs = %{$score{$key}};
    my (%map, $imin);
    foreach my $i (keys %costs) {
      $imin = $i if ((not defined $imin) or ($costs{$imin} > $costs{$i}));
    }
    $map{$key} = $imin;
    return("", %map);
  }
  
  # More than 1 element
  my $INF = 1E30;
  my $required_precision = 1E-12;
  my (@row_mate, @col_mate, @row_dec, @col_inc);
  my (@parent_row, @unchosen_row, @slack_row, @slack);
  my ($k, $l, $row, $col, @col_min, $cost, %hcost);
  my $t = 0;
  
  my @rows = keys %score;
  my $md = "md";
  $md .= "0" if (exists $score{$md}); # ?
  my (@cols, %hcols);
  my $min_score = $INF;
  foreach $row (@rows) {
    foreach $col (keys %{$score{$row}}) {
      $min_score = MMisc::min($min_score, $score{$row}{$col});
      $hcols{$col} = $col;
    }
  }
  @cols = keys %hcols;
  my $fa = "fa";
  $fa .= "0" if (exists $hcols{$fa}); # ?
  my $reverse_search = scalar @rows < scalar @cols; # search is faster when ncols <= nrows
  foreach $row (@rows) {
    foreach $col (keys %{$score{$row}}) {
      ($reverse_search ? $hcost{$col}{$row} : $hcost{$row}{$col})
	= $score{$row}{$col} - $min_score;
    }
  }
  push @rows, $md;
  push @cols, $fa;
  if ($reverse_search) {
    my @xr = @rows;
    @rows = @cols;
    @cols = @xr;
  }
  
  my $nrows = scalar @rows;
  my $ncols = scalar @cols;
  my $nmax = MMisc::max($nrows, $ncols);
  my $no_match_cost = - $min_score * (1 + $required_precision);
  
  # subtract the column minimas
  for ($l = 0; $l < $nmax; $l++) {
    $col_min[$l] = $no_match_cost;
    next if ($l > $ncols);
    $col = $cols[$l];
    foreach $row (keys %hcost) {
      next if (! defined $hcost{$row}{$col});
      my $val = $hcost{$row}{$col};
      $col_min[$l] = $val if ($val < $col_min[$l]);
    }
  }
  
  # initial stage
  for ($ l =0; $l < $nmax; $l++) {
    $col_inc[$l] = 0;
    $slack[$l] = $INF;
  }
  
 ROW:
  for ($k = 0; $k < $nmax; $k++) {
    $row = ($k < $nrows) ? $rows[$k] : undef;
    my $row_min = $no_match_cost;
    for (my $l = 0; $l < $ncols; $l++) {
      my $col = $cols[$l];
      my $val = (((defined $row) and (defined $hcost{$row}{$col})) ? $hcost{$row}{$col} : $no_match_cost) - $col_min[$l];
      $row_min = $val if ($val < $row_min);
    }
    $row_dec[$k] = $row_min;
    for ($l = 0; $l < $nmax; $l++) {
      $col = ($l < $ncols) ? $cols[$l] : undef;
      $cost = ( ((defined $row) and (defined $col) and (defined $hcost{$row}{$col})) ? $hcost{$row}{$col} : $no_match_cost) - $col_min[$l];
      if (($cost == $row_min) and (not defined $row_mate[$l])) {
	$col_mate[$k] = $l;
	$row_mate[$l] = $k;
	# matching row $k with column $l
	next ROW;
      }
    }
    $col_mate[$k] = -1;
    $unchosen_row[$t++] = $k;
  }
  
  goto CHECK_RESULT if ($t == 0);
  
  my $s;
  my $unmatched = $t;
  # start stages to get the rest of the matching
  while (1) {
    my $q = 0;
    
    while (1) {
      while ($q < $t) {
	# explore node q of forest; if matching can be increased, update matching
	$k = $unchosen_row[$q];
	$row = ($k < $nrows) ? $rows[$k] : undef;
	$s = $row_dec[$k];
	for ($l = 0; $l < $nmax; $l++) {
	  if ($slack[$l] > 0) {
	    $col = ($l < $ncols) ? $cols[$l] : undef;
	    $cost = (((defined $row) and (defined $col) and (defined $hcost{$row}{$col})) ? $hcost{$row}{$col} : $no_match_cost) - $col_min[$l];
	    my $del = $cost - $s + $col_inc[$l];
	    if ($del < $slack[$l]) {
	      if ($del == 0) {
		goto UPDATE_MATCHING if (! defined $row_mate[$l]);
		$slack[$l] = 0;
		$parent_row[$l] = $k;
		$unchosen_row[$t++] = $row_mate[$l];
	      } else {
		$slack[$l] = $del;
		$slack_row[$l] = $k;
	      }
	    }
	  }
	}
	
	$q++;
      }
      
      # introduce a new zero into the matrix by modifying row_dec and col_inc
      # if the matching can be increased update matching
      $s = $INF;
      for ($l = 0; $l < $nmax; $l++) {
	if (($slack[$l]) and ($slack[$l] < $s)) {
	  $s = $slack[$l];
	}
      }
      for ($q = 0; $q < $t; $q++) {
	$row_dec[$unchosen_row[$q]] += $s;
      }
      
      for ($l = 0; $l < $nmax; $l++) {
	if ($slack[$l]) {
	  $slack[$l] -= $s;
	  if ($slack[$l] == 0) {
	    # look at a new zero and update matching with col_inc uptodate if there's a breakthrough
	    $k = $slack_row[$l];
	    if (! defined $row_mate[$l]) {
	      for (my $j = $l + 1; $j < $nmax; $j++) {
		if ($slack[$j] == 0) {
		  $col_inc[$j] += $s;
		}
	      }
	      goto UPDATE_MATCHING;
	    } else {
	      $parent_row[$l] = $k;
	      $unchosen_row[$t++] = $row_mate[$l];
	    }
	  }
	} else {
	  $col_inc[$l] += $s;
	}
      }
    }
    
  UPDATE_MATCHING:
    # update the matching by pairing row k with column l
    while (1) {
      my $j = $col_mate[$k];
      $col_mate[$k] = $l;
      $row_mate[$l] = $k;
      # matching row $k with column $l
      last UPDATE_MATCHING if ($j < 0);
      $k = $parent_row[$j];
      $l = $j;
    }
    
    $unmatched--;
    goto CHECK_RESULT if ($unmatched == 0);
    
    $t = 0;			
    # get ready for another stage
    for ($l = 0; $l < $nmax; $l++) {
      $parent_row[$l] = -1;
      $slack[$l] = $INF;
    }
    for ($k = 0; $k < $nmax; $k++) {
      $unchosen_row[$t++] = $k if ($col_mate[$k] < 0);
    }
  } # cycle to next stage
  
 CHECK_RESULT:
  # rigorously check results before handing them back
  for ($k = 0; $k < $nmax; $k++) {
    $row = ($k < $nrows) ? $rows[$k] : undef;
    for ($l = 0; $l < $nmax; $l++) {
      $col = ($l < $ncols) ? $cols[$l] : undef;
      $cost = (((defined $row) and (defined $col) and (defined $hcost{$row}{$col})) ? $hcost{$row}{$col} : $no_match_cost) - $col_min[$l];
      if ($cost < ($row_dec[$k] - $col_inc[$l])) {
	next if ( $cost > (($row_dec[$k] - $col_inc[$l]) - $required_precision * MMisc::max(abs($row_dec[$k]), abs($col_inc[$l]))) );
	return("BGM: this cannot happen: cost{$row}{$col} ($cost) cannot be less than row_dec{$row} ($row_dec[$k]) - col_inc{$col} ($col_inc[$l])", ());
      }
    }
  }
  
  for ($k = 0; $k < $nmax; $k++) {
    $row = ($k < $nrows) ? $rows[$k] : undef;
    $l = $col_mate[$k];
    $col = ($l < $ncols) ? $cols[$l] : undef;
    $cost = (((defined $row) and (defined $col) and (defined $hcost{$row}{$col})) ? $hcost{$row}{$col} : $no_match_cost) - $col_min[$l];
    if (($l < 0) or ($cost != ($row_dec[$k] - $col_inc[$l]))) {
      next if (! ( ($l<0) or abs($cost - ($row_dec[$k] - $col_inc[$l])) > ($required_precision * MMisc::max(abs($row_dec[$k]), abs($col_inc[$l]))) ) );
      return("BGM: every row should have a column mate: row $row doesn't, col: $col", ());
    }
  }
  
  my %map;
  for ($l = 0; $l < scalar @row_mate; $l++) {
    $k = $row_mate[$l];
    $row = ($k < $nrows) ? $rows[$k] : undef;
    $col = ($l < $ncols) ? $cols[$l] : undef;
    next if (! ((defined $row) and (defined $col) and (defined $hcost{$row}{$col})) );
    if ($reverse_search) {
      $map{$col} = $row;
    } else {
      $map{$row} = $col;
    }
  }

  return("", %map);
}


################################################################################

sub _display {
  my ($self, @todisplay) = @_;

  foreach my $td (@todisplay) {
    print "[$td] ", Dumper($self->{$td});
  }
}

#####

sub _display_all {
  my ($self) = @_;

  print Dumper(\$self);
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

############################################################

1;
