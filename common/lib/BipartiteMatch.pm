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
# The trick it to keep the code totaly independent from knowing what
# the objects it works on are, so try to rely on not object related
# packages such as
# the Misc Functions
use MMisc;
# and the Error Handler
use MErrorH;

## Constructor
sub new {
  my ($class) = shift @_;
  
  my $errormsg = new MErrorH("BipartiteMatch");

  my $errortxt = (scalar @_ != 4) ? "BipartiteMatch \'new\' parameters are: (\\%%refObjects, \\%%sysObjects, \\&KernelFunction, \\\@KernelFunction_AdditionalParameters). " : "";

  my ($rrefObjects, $rsysObjects, $rKernelFunction, $rKernelAdditionalParameters) = @_;

  $errortxt .= "The refObjects reference can not be undef, it has to be a reference to an empty hash at minimum. " if (! defined $rrefObjects);
  $errortxt .= "The sysObjects reference can not be undef, it has to be a reference to an empty hash at minimum. " if (! defined $rsysObjects);
  $errortxt .= "The KernelFunction reference can not be undef, it has to be a reference to an empty function at minimum" if (! defined $rKernelFunction);
  $errortxt .= "The KernelFunction Additional Parameters reference can not be undef, it has to be a reference to an empty array at minimum" if (! defined $rKernelAdditionalParameters);

  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     refObj         => $rrefObjects,
     sysObj         => $rsysObjects,
     KernelFunction => $rKernelFunction,
     KernelAddParam => $rKernelAdditionalParameters,
     computed       => 0,
     # Computation results
     joint_values   => undef,
     false_alarm_values   => undef,
     missed_detect_values => undef,
     mapping        => undef,
     # 'MappedRecords'
     unmapped_ref   => undef,
     unmapped_sys   => undef,
     mapped         => undef,
     # Convenience access
     rev_joint_values => undef,
     rev_mapping    => undef,
     # Algorithm selection
     clique_cohorts => 0,
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

  my @out = ();

  my @mapped = $self->get_mapped_ids();
  return(@out) if (($self->error()) || (scalar @mapped == 0));

  my %sysObj = %{$self->{sysObj}};
  my %refObj = %{$self->{refObj}};

  my @tmp = ();
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

  my @out = ();

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

########## 'joint_values', 'false_alarm_values', 'missed_detect_values', 'mapping'

sub _get_XXX_hash {
  my ($self, $xxx) = @_;

  if (! $self->is_computed()) {
    $self->_set_errormsg("Can only obtain values from a computed BPM");
    return(undef);
  }
  
  my $rxxx = $self->{$xxx};
  my %res = %{$rxxx};

  return(%res);
}

#####

sub _set_rev_hash {
  my ($self, $hname, $rev_hname) = @_;

  my %tmp = $self->_get_XXX_hash($hname);
  return(undef) if ($self->error());

  my %rev_tmp = ();
  foreach my $ref_id (keys %tmp) {
    foreach my $sys_id (keys %{$tmp{$ref_id}}) {
      $rev_tmp{$sys_id}{$ref_id} = $tmp{$ref_id}{$sys_id};
    }
  }

  $self->{$rev_hname} = \%rev_tmp;
}

##### 'joint_values'

sub get_jointvalues_refsys_value {
  my ($self, $ref_id, $sys_id) = @_;

  my %jv = $self->_get_XXX_hash("joint_values");
  return(undef) if ($self->error());

  if (! exists $jv{$ref_id}{$sys_id}) {
    $self->_set_errormsg("Can not find key pair (ref_id: $ref_id / sys_id: $sys_id)");
    return(undef);
  }

  return($jv{$ref_id}{$sys_id});
}

#####

sub is_jointvalues_refsys_defined {
  my ($self, $ref_id, $sys_id) = @_;

  my $v = $self->get_jointvalues_refsys_value($ref_id, $sys_id);
  return(undef) if ($self->error());

  return((defined $v) ? 1 : 0);
}

#####

sub get_jointvalues_ref_defined_list {
  my ($self, $ref_id) = @_;

  my %jv = $self->_get_XXX_hash("joint_values");
  return(undef) if ($self->error());

  if (! exists $jv{$ref_id}) {
    $self->_set_errormsg("Can not find ref_id ($ref_id)");
    return(undef);
  }

  my @res = ();
  foreach my $sys_id (keys %{$jv{$ref_id}}) {
    my $v = $self->is_jointvalues_refsys_defined($ref_id, $sys_id);
    return(undef) if ($self->error());
    push @res, $sys_id if ($v);
  }

  return(@res);
}

#####  

sub get_jointvalues_sys_defined_list {
  my ($self, $sys_id) = @_;

  # First create it if not set yet
  $self->_set_rev_hash("joint_values", "rev_joint_values")
    if (! defined $self->{rev_joint_values});
  return(undef) if ($self->error());

  my %rev_jv = $self->_get_XXX_hash("rev_joint_values");
  return(undef) if ($self->error());

  if (! exists $rev_jv{$sys_id}) {
    $self->_set_errormsg("Can not find sys_id ($sys_id)");
    return(undef);
  }

  my @res = ();
  foreach my $ref_id (keys %{$rev_jv{$sys_id}}) {
    my $v = $self->is_jointvalues_refsys_defined($ref_id, $sys_id);
    return(undef) if ($self->error());
    push @res, $ref_id if ($v);
  }

  return(@res);
}

##### 'false_alarm_values'

sub get_sys_falsealarmvalues {
  my ($self, $sys_id) = @_;

  my %fav = $self->_get_XXX_hash("false_alarm_values");
  return(undef) if ($self->error());

  if (! exists $fav{$sys_id}) {
    $self->_set_errormsg("Can not find sys_id ($sys_id)");
    return(undef);
  }

  return($fav{$sys_id});
}

##### 'missed_detect_values'

sub get_ref_misseddetectvalues {
  my ($self, $ref_id) = @_;

  my %mdv = $self->_get_XXX_hash("missed_detect_values");
  return(undef) if ($self->error());

  if (! exists $mdv{$ref_id}) {
    $self->_set_errormsg("Can not find ref_id ($ref_id)");
    return(undef);
  }

  return($mdv{$ref_id});
}

##### 'mapping'

sub get_ref_mapping {
  my ($self, $ref_id) = @_;

  my %map = $self->_get_XXX_hash("mapping");
  return(undef) if ($self->error());

  return(undef)
    if (! exists $map{$ref_id});

  return($map{$ref_id});
}

#####

sub is_ref_mapped {
  my ($self, $ref_id) = @_;

  my $v = $self->get_ref_mapping($ref_id);
  return(undef) if ($self->error());

  return(0) if (! defined $v);

  return(1);
}

#####  

sub get_sys_mapping {
  my ($self, $sys_id) = @_;

  # First create it if not set yet
  $self->_set_rev_hash("mapping", "rev_mapping")
    if (! defined $self->{rev_mapping});
  return(undef) if ($self->error());

  my %rev_map = $self->_get_XXX_hash("rev_mapping");
  return(undef) if ($self->error());

  return(undef)
    if (! exists $rev_map{$sys_id});

  return($rev_map{$sys_id});
}

#####

sub is_sys_mapped {
  my ($self, $sys_id) = @_;

  my $v = $self->get_sys_mapping($sys_id);
  return(undef) if ($self->error());

  return(0) if (! defined $v);

  return(1);
}

########## 'ref' & 'sys'

sub get_sys {
  my ($self, $sysid) = @_;

  if (! exists $self->{sysObj}{$sysid}) {
    $self->_set_errormsg("Can not find requested \'sysid\' ($sysid) in SYS objects");
    return(undef);
  }

  return($self->{sysObj}{$sysid});
}

#####

sub get_ref {
  my ($self, $refid) = @_;

  if (! exists $self->{refObj}{$refid}) {
    $self->_set_errormsg("Can not find requested \'refid\' ($refid) in REF objects");
    return(undef);
  }

  return($self->{refObj}{$refid});
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

  my $clique_cohorts = $self->using_clique_cohorts();

  my @kp = @{$self->{KernelAddParam}};
  my %sysObj = %{$self->{sysObj}};
  my %refObj = %{$self->{refObj}};

  ##### Compute joint values
  my %joint_values = ();
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
  my %fa_values = ();
  while (my ($sys_id, $sys_obj) = each %sysObj) {
    my ($err, $res) = &{$self->{KernelFunction}}(undef, $sys_obj, @kp);
    if (! MMisc::is_blank($err)) {
      $self->_set_errormsg("While computing the false alarm values for sys ID ($sys_id): $err");
      return(0);
    }
    $fa_values{$sys_id} = $res;
  }
  $self->{false_alarm_values} = \%fa_values;

  ##### Compute missed detect values
  my %md_values = ();
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
  my ($err, %map) = &_map_ref_to_sys(\%joint_values, \%fa_values, \%md_values, $clique_cohorts);
  if (! MMisc::is_blank($err)) {
    $self->_set_errormsg("While computing mapping: $err");
    return(0);
  }
  $self->{mapping} = \%map;

  # Set MappedRecord
  my %ref_ids = ();
  foreach my $ref_id (keys %refObj) {
    $ref_ids{$ref_id}++;
  }
  my %sys_ids = ();
  foreach my $sys_id (keys %sysObj) {
    $sys_ids{$sys_id}++;
  }
  # 'mapped'
  my @mapped = ();
  my @unmapped_ref = ();
  my @unmapped_sys = ();
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

sub use_clique_cohorts {
  my ($self) = @_;
  $self->{clique_cohorts} = 1;
}

#####

sub use_cohorts {
  my ($self) = @_;
  $self->{clique_cohorts} = 0;
}

#####

sub using_clique_cohorts {
  my ($self) = @_;

  return(1) if ($self->{clique_cohorts} == 1);

  return(0);
}

#####

sub using_cohorts {
  my ($self) = @_;

  return(1) if ($self->{clique_cohorts} == 0);

  return(0);
}

#####

sub _map_ref_to_sys {
  my ($rjv, $rfa, $rmd, $cc) = @_;
  
  if ($cc) {
    return(&_map_ref_to_sys_clique_cohorts($rjv, $rfa, $rmd));
  } else {
    return(&_map_ref_to_sys_cohorts($rjv, $rfa, $rmd));
  }
}

##########

sub _clique_sys2ref {
  my ($cid, $rjv, $sys_id, $rtdr, $rtds, $cr, $cs) = @_;

  my $done = 0;
  foreach my $ref_id (keys %{$rtdr}) {
    next if (! exists $$rtdr{$ref_id});
    if (defined $$rjv{$ref_id}{$sys_id}) {
      delete $$rtds{$sys_id} if (exists $$rtds{$sys_id});
      delete $$rtdr{$ref_id} if (exists $$rtdr{$ref_id});
      $$cs{$cid}{$sys_id}++;
      $$cr{$cid}{$ref_id}++;
      &_clique_ref2sys($cid, $rjv, $ref_id, $rtdr, $rtds, $cr, $cs);
      $done++;
    }
  }

  return($done);
}

#####

sub _clique_ref2sys {
  my ($cid, $rjv, $ref_id, $rtdr, $rtds, $cr, $cs) = @_;
  
  my $done = 0;
  foreach my $sys_id (keys %{$rtds}) {
    next if (! exists $$rtds{$sys_id});
    if (defined $$rjv{$ref_id}{$sys_id}) {
      delete $$rtdr{$ref_id} if (exists $$rtdr{$ref_id});
      delete $$rtds{$sys_id} if (exists $$rtds{$sys_id});
      $$cr{$cid}{$ref_id}++;
      $$cs{$cid}{$sys_id}++;
      &_clique_sys2ref($cid, $rjv, $sys_id, $rtdr, $rtds, $cr, $cs);
      $done++;
    }
  }

  return($done);
}

##########

sub _map_ref_to_sys_clique_cohorts {
  my ($rjv, $rfa, $rmd) = @_;

  my %td_ref = ();
  my %td_sys = ();
  foreach my $ref_id (keys %{$rjv}) { 
    $td_ref{$ref_id}++;
    foreach my $sys_id (keys %{$$rjv{$ref_id}}) {
      $td_sys{$sys_id}++;
    }
  }
  
  ###### Split into 'cliques'
  my $cid = 0;
  my %c_ref = ();
  my %c_sys = ();
  
  # Process all refs first
  foreach my $ref_id (keys %td_ref) {
    next if (! exists $td_ref{$ref_id});
    $cid++ if (&_clique_ref2sys($cid, $rjv, $ref_id, \%td_ref, \%td_sys, \%c_ref, \%c_sys));
  }
  
  # Then the leftover sys
  foreach my $sys_id (keys %td_sys) {
    next if (! exists $td_sys{$sys_id});
    $cid++ if (&_clique_sys2ref($cid, $rjv, $sys_id, \%td_ref, \%td_sys, \%c_ref, \%c_sys));
  }
  
  # Now process clique per clique
  my %map = ();
  for (my $i = 0; $i < $cid; $i++) {
    my @rl = ();
    @rl = keys %{$c_ref{$i}} if (exists $c_ref{$i});
    my @sl = ();
    @sl = keys %{$c_sys{$i}} if (exists $c_sys{$i});
    
    # We can only map if there is at least one entry per array
    next if ((scalar @rl == 0) || (scalar @sl == 0));

    my %tmp_jv = ();
    foreach my $ref_id (@rl) {
      foreach my $sys_id (@sl) {
        $tmp_jv{$ref_id}{$sys_id} = $$rjv{$ref_id}{$sys_id};
      }
    }
    my %tmp_fa = ();
    foreach my $sys_id (@sl) {
      $tmp_fa{$sys_id} = $$rfa{$sys_id};
    }
    my %tmp_md = ();
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
  my %ref_info = ();
  my %sys_info = ();
  my %reversed_values = ();

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
  my %map = ();
  foreach my $ref (values %ref_info) {
    next if (exists $ref->{cohort});

    # Collect cohorts
    my @ref_cohorts = ();
    my @sys_cohorts = ();
    my %sys_map = ();
    my %ref_map = ();
    my @queue = ();
    @queue = ($ref->{id}, 1);
    $ref->{cohort} = 1;
    $ref->{mapped} = 1;
    push @ref_cohorts, $ref;
    $ref_map{$ref->{id}} = 1;
    while (@queue > 0) {
      my ($id, $ref_type) = splice(@queue, 0, 2); # Remove (and returns) the first two elements of @queue
      if ($ref_type) {          # Find sys cohorts for this ref
        foreach my $sys_id (keys %{$joint_values{$id}}) {
          next if ((defined $sys_map{$sys_id}) or (not defined $joint_values{$id}{$sys_id}));
          $sys_map{$sys_id} = 1;
          my $sys = $sys_info{$sys_id};
          $sys->{cohort} = 1;
          $sys->{mapped} = 1;
          push @sys_cohorts, $sys;
          splice(@queue, scalar @queue, 0, $sys_id, 0); # eq 'push @queue, $sys_id, 0'
        }
      } else {                  # find ref cohorts for this sys
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
    my %costs = ();
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

  #  print "[%score] ", MMisc::get_sorted_MemDump(\%score);

  # No element
  return ("", ()) 
    if (scalar @keys == 0);

  # 1 element: skip graph matching an simply pick the minimum cost map
  if (scalar @keys == 1) {
    my $key = $keys[0];
    my %costs = %{$score{$key}};
    my %map = ();
    my $imin = undef;
    foreach my $i (keys %costs) {
      $imin = $i if ((not defined $imin) or ($costs{$imin} > $costs{$i}));
    }
    $map{$key} = $imin;
    return("", %map);
  }
  
  # More than 1 element
  my $INF = 1E30;
  my $required_precision = 1E-12;
  my @row_mate = ();
  my @col_mate = ();
  my @row_dec = ();
  my @col_inc = ();
  my @parent_row = ();
  my @unchosen_row = ();
  my @slack_row = ();
  my @slack = ();
  my $k = 0;
  my $l = 0;
  my $row = 0;
  my $col = 0;
  my @col_min = ();
  my $cost = 0;
  my %hcost = ();
  my $t = 0;
  
  my @rows = keys %score;
  my $md = "md";
  $md .= "0" if (exists $score{$md}); # ?
  my @cols = ();
  my %hcols = (); 
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
  
  my $s = 0;
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
  }                             # cycle to next stage
  
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
  
  my %map = ();
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
    print "[$td] ", MMisc::get_sorted_MemDump($self->{$td});
  }
}

#####

sub _display_all {
  my ($self) = @_;

  print MMisc::get_sorted_MemDump(\$self);
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

################################################################################

sub _unit_test_kernel {
  my ($ref, $sys, @params) = @_;

  return("", -1) if (! defined $sys);
  return("", 0) if (! defined $ref);


  if ((($ref % 10) < 5) || (($sys % 10) < 5)) {
    return("", 1);
  } else {
    return("", undef);
  }
}

#####

sub unit_test {
  my $makecall = shift @_;

  print "Testing BipartiteMatch ..." if ($makecall);

  my $i = 10;

  my %sys_bpm = ();
  my %ref_bpm = ();
  for (my $j = 0; $j < $i; $j++) {
    $sys_bpm{$j} = $j;
    $ref_bpm{$j} = $j;
  }
  my @kp = ();

  my $bpm = new BipartiteMatch(\%ref_bpm, \%sys_bpm, \&_unit_test_kernel, \@kp);
  MMisc::error_quit("While creating the Bipartite Matching object (" . $bpm->get_errormsg() . ")")
    if ($bpm->error());

  $bpm->compute();
  MMisc::error_quit("While computing the Bipartite Matching (" . $bpm->get_errormsg() . ")")
    if ($bpm->error());

  if (! $makecall) {
    $bpm->_display("joint_values");
    $bpm->_display("mapped", "unmapped_ref", "unmapped_sys");
    
    return(1);
  }

  MMisc::ok_quit(" OK");
}


############################################################

1;
