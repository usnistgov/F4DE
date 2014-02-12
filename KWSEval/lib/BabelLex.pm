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
    DURLOADSTATUS => 0,             # 2 = table loaded
    AVERAGEPHONE  => 0,             # Substitution for missing phones
    DATASTATUS    => "OK"           # Indicates (not)estimated calculations
  };

  #
  # The DATASTATUS is used to collect and report the status of the duration
  # calculation. It is used in a manner similar to that of ERRNO flag. When
  # the getDurationHash() routine is invoked, it sets the DATASTATUS to "OK".
  # Then, as the durations are calculated, the status can be downgraded to
  # either "Estimated" or "Failed". At the conclusion of the calculations the
  # DATASTATUS is copied into the return hash. 
  #
  # ########### IMPORTANT!: The DATASTATUS should not be used for any other
  #                         purposes as it may become overwritten.
  #
  # The status can be set to "OK", "Estimated", and "Failed".
  #
  #   "OK" status is given to the return data hash when all the phone duration
  # values have been either located directly in the Phone Duration file, or
  # first translated with the help of the Phone Map file and then located in
  # the Phone Duration file.
  #
  #  "Estimated" status is given when any of the phones required to calculate a
  # word or phrase duration were not found in either Phone Duration or Phone
  # Map files. In such cases the previously calculated average phone duration
  # value for the given lexicon is used in place of the missing phone duration.
  # Hence, the calculation status is deemed Estimated.
  #
  # "Failed" status is returned when a keyword or any word in a key phrase can
  # not be found in the lexicon hash table. Consecuntly, there will be no known
  # pronunciations to work with. The rest of the return data is set to 0.
  #


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

  print "\n***\n";
  print "XSAMPA-to-Phone Map: $map_file\n";
  print "Lexicon: $lex_file ($encoding)\n";
  print "$rome_text\n\n";
  
  if ($dur_file)
  {
    print "Durations: $dur_file";
  }
  else
  {
    print "Durations: No filename for pnone durations received yet";
  }
  print "\n***\n\n";

} #printIntro()


################################################################################
# Map file provides mapping from the XSAMPA characters used in lexicon files to
# the phones used in the phone duration files. While most of these are the same
# some are different and the map file provides the translation needed.
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
# Lexicon file is a collection of words ipresented in one column. The second 
# column may be the "romanaized" version of the word. Some languages will not
# have the romanized version. The "romanized" flag indicates whether to account
# for the romanized column or not. The following columns are one or more pro-
# nunciations of the words. This routine loads the words and all available pro-
# nunciations into a hash for future use.
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
# Phone Duration file provides the duration values for the phones. This routine
# loads the file data into a hash for future use.
################################################################################
sub loadDurFile()
{
  my ($self, $file) = @_;
  my $total      = 0;
  my $num_phones = 0;


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
    $total += $words[1];
    $num_phones++;
  }

  close $DATA;

  $self->{DURFILE}       = $file;
  $self->{DURLOADSTATUS} = 2;

  if ($self->{LEXLOADSTATUS} == 2)
  {
    $self->calculateDurations();
  }

  # The average phone duration for the given lexicon is calculated so if
  # in the future duration calculations any phones are missing, then this
  # average value will be used in the missing phones duration place.
  $self->{AVERAGEPHONE} = $total / $num_phones;

    #print "                             ***\n";
    #print "                        - Durations -\
    #$file\n\n";
    #print "                             ***\n\n\n";

  
  return "Duration data successfully loaded from $file";

} #loadDurFile()


################################################################################
# Once Lexicon, Duration, and Map files are loaded, this routine will be called
# to go through the collection of the words loaded into the LEXTABLE hash, and
# for every pronunciation of that word will calculate the duration value, which
# is then also stored in the same hash for future use.
################################################################################
sub calculateDurations
{
  my ($self)   = @_;

  foreach my $word (keys $self->{LEXTABLE})
  {
    my $entry = \$self->{LEXTABLE}{$word};
    my @prons = @{${$$entry}{"adj_pron"}};
    my $var_num  = 0;
    my $status   = "OK";

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
              # We are here because we didn't find the syllable in the phone
              # durations file, so instead we looked up a substitution in the
              # phone map file and now we will use it in the duration calcu-
              # lations. This is not an error.
              $duration += $self->{DURTABLE}{$syllable};
            }
            else
            {
              # Here  we didn't find the substituted phone in the phone map
              # file either, so we will substitute the duration we are
              # looking for with an average phone duration that we have
              # calculated when loaded the phone duration file. This is a
              # temporary workaround that should not get used as soon as
              # we have a correct finalized phone map file.
              $duration += $self->{AVERAGEPHONE};
              $status = "Estimated";
            }
          }
          else
          {
            # Here  we didn't find the phone either in the phone duration file
            # or in the phone map file, so we are substituting the duration we
            # are looking for with an average phone duration that we have
            # calculated when loaded the phone duration file. This is a
            # temporary workaround that should not get used as soon as
            # we have a correct finalized phone map file.
            $duration += $self->{AVERAGEPHONE};
            $status = "Estimated";
            #print "![$syllable]";
          }
        }
      } #foreach my $syllable (@$variant)

      # Store calculated duration and its "OK" or "Estimated" status
      # in the Lexicon hash table for future lookups.
      ${$$entry}{"duration"}[$var_num] = $duration;
      ${$$entry}{"status"}[$var_num] = $status;
      $var_num++;

    } #foreach my $variant (@prons)

  } #foreach my $word (keys $self->{LEXTABLE})
  
} #calculateDurations()


################################################################################
# This routine expects to be passed a keyword or a multi-word key-phrase. It 
# will return the durations for every pronunciation of a single keyword, or in
# case of a multi-word key-phrase, it will return a single value that is a sum
# of averages of all available pronunciations durations for every word in the
# key-phrase.
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
      if (!$self->{LEXTABLE}{$word})
      {
        # One of the words in this key-phrase doesn't exsist in our
        # lexicon, so we are giving up, reporting Failed status and
        # returning 0 values.
        $self->{DATASTATUS} = "Failed";
        print "The keyword $word is unknown, duration invalid\n";
        $durations[0] = 0;
        return \@durations;
      }

      # Just adding average durations of every word in a phrase together
      $duration += $self->getSingleWordDurationAverage($word);
    }
    # Store the sum of averages in the array and return
    push (@durations, $duration);
    return \@durations;
  }
  elsif (scalar(@word_array) == 1)
  {
    if (!$self->{LEXTABLE}{$word_array[0]})
    {
      # This key-word doesn't exsist in our lexicon, so we are giving up,
      # reporting Failed status and returning 0 values.
      $self->{DATASTATUS} = "Failed";
      print "The keyword $key_phrase is unknown, duration invalid\n";
      $durations[0] = 0;
      return \@durations;
    }
    
    return \@{$self->getSingleWordDurations($word_array[0])};
  }
  else
  {
    # Empty key-word! Report Failed status and return 0 values.
    $self->{DATASTATUS} = "Failed";
    print "Empty key-word, duration invalid\n";
    $durations[0] = 0;
    return \@durations;
  }

} #getDurations()


################################################################################
sub getSingleWordDurations()
{
  my ($self, $key_word) = @_;

  my $entry = \$self->{LEXTABLE}{$key_word};

  # Consider the data status for every pronunciation variant and set the 
  # global DATASTATUS accordingly. Here the status can only vary from OK to
  # Estimated. So if global status is OK, then symply accept the local value,
  # but if the global status has already been downgraded to Estimated, then
  # just ignore the local status because once the global status was set to
  # Estimated, it can not go back to OK.
  my @stati = @{${$$entry}{"status"}};
  foreach my $stat (@stati)
  {
    $self->{DATASTATUS} =
      ($self->{DATASTATUS} eq "OK") ? $stat : $self->{DATASTATUS};
  }

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
    if (!$self->{LEXTABLE}{$word})
    {
      # One of the words in this key-phrase doesn't exsist in our
      # lexicon, so we are giving up, reporting Failed status and
      # returning 0 values.
      $self->{DATASTATUS} = "Failed";
      print "The keyword $word is unknown, duration invalid\n";
      return 0;
    }

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
sub getDurationHash()
{
  my ($self, $key_phrase) = @_;

  my $ret;

  $ret = {
    STATUS     => "OK",
    DURATIONS  => [],
    DURAVERAGE => 0
  };

  $self->{DATASTATUS} = "OK";
  my @duration = @{$self->getDurations($key_phrase)};
  my $status = $self->{DATASTATUS};
  if ($status eq "Failed")
  {
    $ret->{STATUS} = $status;
    push (@{$ret->{DURATIONS}}, 0);
    $ret->{DURAVERAGE} = 0;
  }
  else
  {
    foreach my $dur (@duration)
    {
      push (@{$ret->{DURATIONS}}, $dur);
    }

    my $durave = $self->getDurationAverage($key_phrase);
    $status = ($status eq "OK") ? $self->{DATASTATUS} : $status;

    $ret->{STATUS} = $status;
    $ret->{DURAVERAGE} = $durave;
  }
  
  return $ret;

} #getDurationHash()


################################################################################
sub unitTest()
{
  my $mapfile = "/Users/vad/TestData/102+103+201+203+206-phoneMaps.txt";

  my $lexfile = "/Users/vad/TestData/IARPA-babel102b-v0.5a.lexicon";
  #my $lexfile = "/home/vlad/poc/lexicon.head";
  #my $lexfile = "/Users/vad/TestData/IARPA-babel102b-v0.5a.lexicon.small";

  my $romanized = "";

  #my $durfile = "/home/vlad/poc/babel102b-v0.5a-phone_stats.perPhone.txt";
  my $durfile = "/Users/vad/TestData/babel102b-v0.5a-phone_stats.perPhone.txt";
  
  my $encoding = "UTF-8";

  my $lp = new BabelLex($mapfile, $lexfile, $romanized, $encoding, $durfile);

  #my $lp = new BabelLex($mapfile, $lexfile, $romanized, $encoding);

  #$lp->loadDurFile($durfile);
 
  my $multiword = 3;
  my $phrase = " ";

  
  foreach my $keys (keys $lp->{LEXTABLE})
  {
    my %res = %{$lp->getDurationHash($keys)};

    print "Status = " . $res{STATUS} . "\t";
    print "Durations = " . join(", ", @{$res{DURATIONS}}) . "\t";
    print "Average = " . $res{DURAVERAGE} . "\n";

    $phrase = $phrase . $keys . " ";
    $multiword--;

    if ($multiword == 0)
    {
      #print "[$phrase]:\n";
      %res = %{$lp->getDurationHash($phrase)};

      print "Status = " . $res{STATUS};
      print "\tDurations = " . join(", ", @{$res{DURATIONS}});
      print "\tAverage = " . $res{DURAVERAGE} . "\t [$phrase]\n\n";

      $phrase    = " ";
      $multiword = 3;
    }
  }

  #foreach my $keys (keys $lp->{LEXTABLE})
  #{
    #my @duration = @{$lp->getDurations($keys)};
    #print join(", ", @duration);
    #my $dur_ave = $lp->getDurationAverage($keys);
    #print "\t\tAverage = $dur_ave\n";

    #$phrase = $phrase . $keys . " ";
    #$multiword--;
    
    #if ($multiword == 0)
    #{
      #print "[$phrase]: ";
      #@duration = @{$lp->getDurations($phrase)};
      #print join(", ", @duration);
      #$dur_ave = $lp->getDurationAverage($phrase);
      #print ", Ave = $dur_ave\n\n\n";
  #
      #$phrase    = " ";
      #$multiword = 3;
    #}
  #}

  #print Dumper($lp);

} #unitTest()
