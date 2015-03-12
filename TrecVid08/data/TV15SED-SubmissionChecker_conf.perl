@expected_year = ( "2015" );
@expected_task = ( "retroED", "interactiveED" );
@expected_data = ( "DEV15", "SUB15", "EVAL15" ); # keep Order
@expected_lang = ( "ENG" );
@expected_input = ( "s-camera" );
@expected_sysid_beg = ( "p-", "c-" );
$subname_params = 5;
$subname_param1 = "SED15";

@expected_dir_output = ( "output" );

$pc_check = 1;

%expected_sffn = ();

$check_minMax = 1;

$default_fps = 25;

@forceUseEcf_remove = ( '\.mov\.deint\.mpeg$', '\.mpeg$' );

@{$expected_limitto{$expected_data[0]}} = ( 'PersonRuns', 'CellToEar', 'ObjectPut', 'PeopleMeet', 'PeopleSplitUp', 'Embrace', 'Pointing' );

@{$expected_limitto{$expected_data[1]}} = ( 'PeopleMeet', 'PeopleSplitUp', 'Embrace' );

@{$expected_limitto{$expected_data[2]}} = @{$expected_limitto{$expected_data[0]}};


  
