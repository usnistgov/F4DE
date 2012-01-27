# KWSEval
# KWSTools.pm
# Author: Jerome Ajot <jerome.ajot@nist.gov>

package KWSTools;
use strict;
use warnings;
require Exporter;
our @ISA = qw ( Exporter );
our @EXPORT = qw ( numeric_sort unique min max element_of remove_element remove_all_element count_element intersection );
our $VERSION = 0.1;

sub numeric_sort { return sort { $a <=> $b } @_; }

sub unique
{
	my %l = ();
	foreach my $e (@_) { $l{$e}++; }
	return keys %l;
}

sub max
{
	my $max = shift;
	foreach $_ (@_) { $max = $_ if $_ > $max; }
	return $max;
}

sub min
{
	my $min = shift;
	foreach $_ (@_) { $min = $_ if $_ < $min; }
	return $min;
}

sub element_of
{
	my $e = shift;
	foreach my $el(@_) { return 1 if("$e" eq "$el"); }
	return 0;
}

sub remove_element
{
	my $re = shift;
	my @tmplist = @_;
	my $index = undef;
	for(my $i=0; $i<@tmplist; $i++)	{ $index = $i if("$tmplist[$i]" eq "$re"); }
	delete $tmplist[$index] if(defined($index));
}

sub remove_all_element
{
	my $re = shift;
	my @tmplist = @_;
	my $sizeoldlist = undef;
	do
	{
		$sizeoldlist = scalar(@tmplist);
		@tmplist = remove_element($re, @tmplist);
	}
	while($sizeoldlist != scalar(@tmplist));
	return @tmplist;
}

sub count_element
{
	my $ec = shift;
	my %l = ();
	foreach my $e (@_) { $l{$e}++ if("$e" eq "$ec"); }
	return $l{$ec};
}

sub union{ return unique(@_); }

sub intersection
{
	my %l = ();
	my @listout;
	foreach my $e (@_) { $l{$e}++; }
	foreach my $e (keys %l) { push(@listout, $e) if($l{$e} > 1); }
	return @listout;	
}

1;
