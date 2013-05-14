#!/usr/bin/env perl

# Check we have every module (perl wise)
my ($f4b, @f4bv, $f4d);
BEGIN {
    use Cwd 'abs_path';
    use File::Basename 'dirname';
    $f4d = dirname(abs_path($0));

    $f4b = "F4DE_BASE";
    push @f4bv, (exists $ENV{$f4b})
	? ($ENV{$f4b} . "/common/lib")
	: ("$f4d/../../../common/lib");
}
use lib (@f4bv);

use AutoTable;
use Getopt::Long;
use MMisc;
use Data::Dumper;

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case));

my $out_type = "Txt";
my $sort_row = "Alpha";
my $sort_row_key = "";
my $sort_col = "Alpha";
my $sort_col_key = "";
my $separator = '\s';
my $prefix_text = "";
my $properties = {};

GetOptions
(
 'append:s' => \$prefix_text,
 'type:s' => \$out_type, 
 'row-sort:s' => \$sort_row,
 'col-sort:s' => \$sort_col,
 'separator:s' => \$separator,
 'properties:s@' => \$props,
 'list-props' => sub { MMisc::ok_quit(&list_properties); },
 'help' => sub { MMisc::ok_quit(&get_usage); },
) or MMisc::error_quit("Unknown option(s)\n".&get_usage);

#Format out type options as understood by AutoTable, and setup render
#specific property keys
if ($out_type =~ /te?xt/i) { 
    $out_type = "Txt";
    $sort_row_key = "SortRowKeyTxt";
    $sort_col_key = "SortColKeyTxt";
} elsif ($out_type =~ /csv/i) { 
    $out_type = "CSV";
    $sort_row_key = "SortRowKeyCsv";
    $sort_col_key = "SortColKeyCsv";
} elsif ($out_type =~ /html/i) { 
    $out_type = "HTML"; 
    $sort_row_key = "SortRowKeyHTML";
    $sort_col_key = "SortColKeyHTML";
} elsif ($out_type =~ /latex/i) { 
    $out_type = "LaTeX"; 
    $sort_row_key = "SortRowKeyLaTeX";
    $sort_col_key = "SortColKeyLaTeX";
} else { MMisc::error_quit("Unrecognized type '$out_type'") }

my $at = new AutoTable();

foreach my $prop(@$props) {
    my ($k, $v) = split(/:/, $prop);
    $properties->{$k} = $v;
}

foreach my $prop(keys %$properties) {
    if ($prop eq "separator") {
	$separator = $properties->{$prop};
    } else {
	unless ($at->{Properties}->setValue($prop, $properties->{$prop})) {
	    print &property_error();
	}
    }
}

#Set properties from options
if ($prefix_text) {
    unless ($at->{Properties}->setValue("TxtPrefix", $prefix_text)) {
	print &property_error();
    }
}
unless ($at->{Properties}->setValue($sort_row_key, $sort_row)) {
    print &property_error();
}
unless ($at->{Properties}->setValue($sort_col_key, $sort_col)) {
    print &property_error();
}

while (<STDIN>){
    chomp;
    my @a = split(/$separator/);
        
    $at->addData($a[0], $a[1], $a[2]);
    $at->setSpecial($a[1], $a[2], $a[3]) if (@a > 3);
}

#Render
my $rendered_at = "";
if ($out_type eq "Txt") {
    $rendered_at = $at->renderTxtTable(1);
} elsif ($out_type eq "HTML") {
    $rendered_at = $at->renderHTMLTable(1);
} elsif ($out_type eq "LaTeX") {
    $rendered_at = $at->renderLaTeXTable();
} elsif ($out_type eq "CSV") {
    $rendered_at = $at->renderCSV();
} else {
    MMisc::error_quit("I need a Renderer for now '$out_type'");
}
if ($rendered_at) {
    print $rendered_at;
} else {
    MMisc::error_quit("Didn't render anything, aborting");
}

sub property_error {
    $at->{Properties}{errormsg}->errormsg()."\n";    
}

sub list_properties {
    my $at = new AutoTable();
    $at->{Properties}->printShortPropList();
    return;
}

sub get_usage {
    return <<'EOT';

ATman.pl [ OPTIONS ]
    
    -t, --type        Output type of generated AutoTable
    -r, --row-sort    Sort rows
    -c, --col-sort    Sort Columns
    -s, --separator   Field separator for input file
    -a, --append      Append text to each line when rendering in text mode
    -p, --properties  Specify properties as a list of Property:Value
    -l, --list-props  List accepted properties and values

    -h, --help        Print this text
EOT
}

exit 0;
