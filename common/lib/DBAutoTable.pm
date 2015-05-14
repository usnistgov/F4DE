package DBAutoTable;

use MMisc;
use MErrorH;
use PropList;
use CSVHelper;
use DBI;

use Data::Dumper;

sub new {
  my ($class) = shift @_;
  
  my $self = { dbFiles => shift,
	       dbh => undef,
             } ;

  bless $self;
  $self->_open();

  return($self);
}

sub _open{
  my ($self) = @_;

  $self->{dbh} = DBI->connect(          
    "dbi:SQLite:dbname=".$self->{dbFiles}->[0], 
    "",                          
    "",                          
    { RaiseError => 1 },         
    ) or die $DBI::errstr;
  ### Attach the others here.
  for (my $d=1; $d<@{ $self->{dbFiles} }; $d++){
    $self->DBRunReturnAT([( "attach database '$self->{dbFiles}->[$d]' as DB$d" )]);
  }
}

sub DBClose{
  my ($self) = @_;
  $self->{dbh}->disconnect();
}

sub DBRunNoOutput{
  my ($self, $stmts) = @_;

  my $sth = $self->{dbh}->prepare(join("\n",@$stmts)."\n");
  $sth->execute();
  $sth->finish();
}

sub DBRunReturnAT{
  my ($self, $stmts) = @_;

  my $sth = $self->{dbh}->prepare(join("\n",@$stmts)."\n");
  $sth->execute();

  my $ht;
  my $at = new AutoTable();
  my $line = 0;
  while (defined($ht = $sth->fetchrow_hashref)){
    foreach my $key(keys %$ht){
      $at->addData($ht->{$key}, $key, sprintf("%06d",$line));
    }
    $line++;
  }
  return($at);
}

sub DBMakeTableFromAT{
  my ($self, $at, $rows, $tblName, $isTempTable) = @_;

  my @colids = $at->getColIDs("AsAdded");

  my $str = "create ".($isTempTable ? "temp" : "")." table $tblName ( ";
  $str .= join(" TEXT ,",@colids)." TEXT );";
  #print $str."\n";
  $self->DBRunNoOutput([($str)]);

  foreach my $row(@$rows){
    $str = "INSERT INTO $tblName (".join(",", @colids).") VALUES (";
    foreach my $col(2..scalar(@colids)){ $str .= '?,' }
    $str .= '?)';

    my @v = ();
    for (my $col=0; $col<@colids; $col++){
      push @v, $at->getData($colids[$col], $row);
    }

    #print "($str, @v);\n";
    $self->{dbh}->do($str, undef, @v);

  }

  my $atx = $self->DBRunReturnAT([ ("select * from $tblName")]);
  #  print $atx->renderByType("txt");
}

1;
