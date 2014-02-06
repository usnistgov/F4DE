package BabelLex;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# KWSEval
# TermList.pm
#
# Original Author: Vlad Dreyvitser
#
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain.
#
# KWSEval is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.
#

use TranscriptHolder;
@ISA = qw(TranscriptHolder);

use strict;

use MMisc;


use warnings;
use utf8;
use Data::Dumper;

################################################################################
sub new
{
  my ($my_class, $map_file, $lex_file, $romanized, $encoding, $dur_file) = @_;

		$romanized = ($romanized eq "no" || $romanized eq "0") ? 0 : 1;
  &printIntro ($map_file, $lex_file, $romanized, $encoding, $dur_file);

		my $self = new TranscriptHolder('BabelLex');

  $self = {
    MAPFILE       => $map_file,
    LEXFILE       => $lex_file,
    DURFILE       => $dur_file,
    MAPTABLE      => {},
    LEXTABLE      => {},
    DURTABLE      => {},
    ROMANIZED     => $romanized,
    ENCODING      => $encoding,
    MAPLOADSTATUS => 0,             # 0 = table not loaded
    LEXLOADSTATUS => 0,             # 1 = load in progress
    DURLOADSTATUS => 0              # 2 = table loaded
  };

  bless $self;

		$self->setEncoding($encoding);

		if (!$map_file || !$lex_file)
		{
		  MMisc::error_quit("Lexicon file, Romanized flag, and XSAMPA-to_Phone \
				  Map file are required for this module");
		}

		$self->loadMapFile($map_file);
  $self->loadLexFile($lex_file);

  if ($dur_file)
  {
    $self->loadDurFile ($dur_file);
  }

  return $self;

} #new()

################################################################################
sub printIntro()
{
  my ($map_file, $lex_file, $romanized, $encoding, $dur_file) = @_;

  my $rome_text = ($romanized == 1) ?
     "Romanized column expected" :
       "Romanized column not expected";

  print "\n                             ***\n";
  print "                           Warning!\
        This version of BabelLex has missing duration \
               times temporary substitutions!\n\n";

  print "                    - XSAMPA-to-Phone Map -\
  $map_file\n";
  print "                         - Lexicon -\
  $lex_file ($encoding)\n";
  print "                 --- $rome_text ---\n\n";
  
  if ($dur_file)
  {
    print "                        - Durations -\
    $dur_file";
  }
  else
  {
    print "                        - Durations -\
          No filename for pnone durations received";
  }
  print "\n\n                             ***\n\n";

} #printIntro()


################################################################################
sub loadMapFile()
{
  my ($self, $file) = @_;

  if ($self->{MAPLOADSTATUS} > 0)
  {
    return "XSAMPA/Phone map file is already loaded or in progress";
  }
  else
  {
    $self->{MAPLOADSTATUS} = 1;
  }

  open my $DATA, $file or die "Couldn't open $file";


  my $header = <$DATA>; # Skip the file header
  while(<$DATA>)
  {
    my @words = split('\t', $_);
    chomp (@words);
    $self->{MAPTABLE}{$words[0]} = $words[1];
  }

		#print Dumper($self->{MAPTABLE});
  close $DATA;

  $self->{MAPFILE}       = $file;
  $self->{MAPLOADSTATUS} = 2;

  return "XSAMPA-to-Phone map file successfully loaded from $file";

} #loadMapFile()


################################################################################
sub loadLexFile()
{
  my ($self, $file) = @_;

  if ($self->{LEXLOADSTATUS} > 0)
  {
    return "Lexicon file is already loaded or in progress";
  }
		elsif ($self->{MAPLOADSTATUS} < 2)
		{
				MMisc::error_quit("Can't load lexicon without XSAMPA-to_Phone Map");
		}
  else
  {
    $self->{LEXLOADSTATUS} = 1;
  }

  open my $DATA, $file or MMisc::error_quit("Couldn't open $file");
		binmode ($DATA, ":encoding($self->{ENCODING})") if ($self->{ENCODING} ne "");

  while(<$DATA>)
  {
    my %entry;
    my @words = split('\t', $_);
    chomp (@words);

    for (my $i = 1 + $self->{ROMANIZED}; $words[$i]; $i++)
    {
      my @adjusted = $self->adjustPronunciation($words[$i]);

      push (@{$entry{"pron"}},     $words[$i]);
      push (@{$entry{"adj_pron"}}, \@adjusted);
      push (@{$entry{"duration"}}, -1);          # duration unknown
    }

    $self->{LEXTABLE}{$words[0]} = \%entry;

		#print Dumper(\%entry);
  }

  close $DATA;

  $self->{LEXFILE}       = $file;
  $self->{LEXLOADSTATUS} = 2;

  if ($self->{DURLOADSTATUS} == 2)
  {
    $self->calculateDurations();
  }

  return "Lexicon data successfully loaded from $file";

} #loadLexFile()


################################################################################
sub loadDurFile()
{
  my ($self, $file) = @_;

  if ($self->{DURLOADSTATUS} > 0)
  {
    return "Duration file is already loaded or in progress";
  }
  else
  {
    $self->{DURLOADSTATUS} = 1;
  }

  open my $DATA, $file or die "Couldn't open $file";


  my $header = <$DATA>; # Skip the file header
  while(<$DATA>)
  {
    my @words = split('\t', $_);
    $self->{DURTABLE}{$words[0]} = $words[1]; # $1 for the mean duration
  }

  close $DATA;

  $self->{DURFILE}       = $file;
  $self->{DURLOADSTATUS} = 2;

  if ($self->{LEXLOADSTATUS} == 2)
  {
    $self->calculateDurations();
  }

		#print "                             ***\n";
		#print "                        - Durations -\
		#$file\n\n";
		#print "                             ***\n\n\n";

  
  return "Duration data successfully loaded from $file";

} #loadDurFile()


################################################################################
sub calculateDurations
{
  my ($self)   = @_;

  foreach my $word (keys $self->{LEXTABLE})
  {
    my $entry = \$self->{LEXTABLE}{$word};
    my @prons = @{${$$entry}{"adj_pron"}};
    my $var_num  = 0;

    foreach my $variant (@prons)
    {
      my $duration = 0;
      foreach my $syllable (@$variant)
      {
        if ($syllable ne '.' && $syllable ne '#')
        {
          if ($self->{DURTABLE}{$syllable})
          {
            $duration += $self->{DURTABLE}{$syllable};
          }
										elsif ($self->{MAPTABLE}{$syllable})
										{
												$syllable = $self->{MAPTABLE}{$syllable};
												if ($self->{DURTABLE}{$syllable})
												{
												  $duration += $self->{DURTABLE}{$syllable};
												}
												else
												{
														#print "Error! mapped [$syllable] not found\n";
														print "![$syllable]";
												  $duration = -100;
										  }
										}
          else
          {
												#print "Error! [$syllable] not found\n";
												print "![$syllable]";
            $duration = -100;
          }
        }
      } #foreach my $syllable (@$variant)

      ${$$entry}{"duration"}[$var_num] = $duration;
      $var_num++;

    } #foreach my $variant (@prons)

  } #foreach my $word (keys $self->{LEXTABLE})
  
} #calculateDurations()


################################################################################
sub getDurations()
{
  my ($self, $key_phrase) = @_;
  my @word_array = split(" ", $key_phrase);
  my $duration   = 0;
  my @durations;

  if (scalar(@word_array) > 1)
  {
    foreach my $word (@word_array)
    {
      $duration += $self->getSingleWordDurationAverage($word);
    }
    push (@durations, $duration);
    return \@durations;
  }
  elsif (scalar(@word_array) == 1)
  {
    return \@{$self->getSingleWordDurations($word_array[0])};
  }
  else
  {
    # This should never happen
    return \@durations;
  }

} #getDurations()


################################################################################
sub getSingleWordDurations()
{
  my ($self, $key_word) = @_;

  my $entry = \$self->{LEXTABLE}{$key_word};

  return [@{${$$entry}{"duration"}}];
  
} #getSingleWordDurations()


################################################################################
sub getDurationAverage()
{
  my ($self, $key_phrase) = @_;
  my @word_array = split(" ", $key_phrase);
  my $duration   = 0;

  foreach my $word (@word_array)
  {
    $duration += $self->getSingleWordDurationAverage($word);
  }

  return $duration;

} #getDurationAverage()

################################################################################
sub getSingleWordDurationAverage()
{
  my ($self, $key_word) = @_;

  my $dur_sum  = 0;
  my $num_durs = 0;

  my @durations = @{$self->getSingleWordDurations($key_word)};

  foreach my $dur (@durations)
  {
    $dur_sum += $dur;
    $num_durs++;
  }

  if ($num_durs > 0)
  {
    return $dur_sum/$num_durs;
  }
  else
  {
    # This should never happen
    return 0;
  }

} #getSingleWordDurationAverage()


################################################################################
sub adjustPronunciation()
{
  my ($self, $string) = @_;
		my @result = split(" ", $string);

		my $i = 0;
		foreach my $char (@result)
		{
				# 2014/02/05: No longer replacing the lexicon characters with mapped
				# phones. Instead just changing a string into an array and returning.
				# The mapped characters lookup will take place in the calculateDurations
				# routine only if the original characters duration can not be found.
				#$result[$i] = $self->{MAPTABLE}{$char};

				$result[$i] = $char;
				$i++;
		}
		
  return @result;
} #adjustPronunciation()


################################################################################
sub unitTest()
{
  my $mapfile = "/Users/vad/2013.12.16-PhoneDurations/temporary_102+103+201+203+206-phoneMaps.txt";

  my $lexfile = "/Users/vad/2013.12.16-PhoneDurations/IARPA-babel102b-v0.5a.lexicon";
  #my $lexfile = "/home/vlad/poc/lexicon.head";
  #my $lexfile = "/Users/vad/2013.12.16-PhoneDurations/IARPA-babel102b-v0.5a.lexicon.small";

  my $romanized = "";

  #my $durfile = "/home/vlad/poc/babel102b-v0.5a-phone_stats.perPhone.txt";
  my $durfile = "/Users/vad/2013.12.16-PhoneDurations/babel102b-v0.5a-phone_stats.perPhone.txt";
  
		my $encoding = "UTF-8";

  my $lp = new BabelLex($mapfile, $lexfile, $romanized, $encoding, $durfile);

		#my $lp = new BabelLex($mapfile, $lexfile, $romanized, $encoding);

		#$lp->loadDurFile($durfile);
 
  my $multiword = 3;
  my $phrase = " ";

  foreach my $keys (keys $lp->{LEXTABLE})
  {
    my @duration = @{$lp->getDurations($keys)};
				print join(", ", @duration);
    my $dur_ave = $lp->getDurationAverage($keys);
				print "\t\tAverage = $dur_ave\n";

    $phrase = $phrase . $keys . " ";
    $multiword--;
    
    if ($multiword == 0)
    {
						print "[$phrase]: ";
      @duration = @{$lp->getDurations($phrase)};
						print join(", ", @duration);
      $dur_ave = $lp->getDurationAverage($phrase);
						print ", Ave = $dur_ave\n\n\n";
  
      $phrase    = " ";
      $multiword = 3;
    }
  }

  #print Dumper($lp);

} #unitTest()
