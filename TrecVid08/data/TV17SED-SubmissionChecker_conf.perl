my $_tmp_syear= "17";
@expected_year = ( "20$_tmp_syear" );
@expected_task = ( "retroED" );
@expected_data = ( "DEV$_tmp_syear", "SUB$_tmp_syear", "EVAL$_tmp_syear" ); # keep Order
@expected_lang = ( "ENG" );
@expected_input = ( "s-camera" );
@expected_sysid_beg = ( "p-", "c-" );
$subname_params = 5;
$subname_param1 = "SED$_tmp_syear";

@expected_dir_output = ( "output" );

$pc_check = 1;

%expected_sffn = ();

$check_minMax = 1;

$default_fps = 25;

@forceUseEcf_remove = ( '\.mov\.deint\.mpeg$', '\.mpeg$' );

@{$expected_limitto{$expected_data[0]}} = ( 'PersonRuns', 'CellToEar', 'ObjectPut', 'PeopleMeet', 'PeopleSplitUp', 'Embrace', 'Pointing' );

@{$expected_limitto{$expected_data[1]}} = ( 'PeopleMeet', 'PeopleSplitUp', 'Embrace' );

@{$expected_limitto{$expected_data[2]}} = @{$expected_limitto{$expected_data[0]}};
  
