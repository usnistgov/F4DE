$expid_count = 11;
@expid_tag  = ( 'KWS13' ); # should only contain 1 entry
@expid_partition = ( 'conv-dev', 'conv-eval' ); # order is important
@expid_scase = ( 'BaDev', 'BaEval', 'BaSurp' ); # order is important
@expid_task = ( 'KWS', 'STT' ); # order is important
@expid_lp = ( 'FullLP', 'LimitedLP' ); # order is important
@expid_lr = ( 'BaseLR', 'BabelLR', 'OtherLR' ); # order is important
@expid_aud = ( 'NTAR', 'TAR' ); # order is important
@expid_sysid_beg = ( "p-", "c-" ); # order is important

## To Sequester: ie require manual release
@Scase_toSequester = ( $expid_scase[1], $expid_scase[2] );

#####
## AuthorizedSet{partition}{scase}

# First unauthorize everything
foreach my $_tmp_part (@expid_partition) {
  foreach my $_tmp_scase (@expid_scase) {
    $AuthorizedSet{$_tmp_part}{$_tmp_scase} = 0;
  }
}

# Authorize all scase for 'conv-dev'
$AuthorizedSet{$expid_partition[0]}{$expid_scase[0]} = 1;
$AuthorizedSet{$expid_partition[0]}{$expid_scase[1]} = 1;
$AuthorizedSet{$expid_partition[0]}{$expid_scase[2]} = 1;
$AuthorizedSet{$expid_partition[0]}{$expid_scase[3]} = 1;

# Authorize only BaEval and BaSurp scase for 'conv-eval'
$AuthorizedSet{$expid_partition[1]}{$expid_scase[2]} = 1;
$AuthorizedSet{$expid_partition[1]}{$expid_scase[3]} = 1;
