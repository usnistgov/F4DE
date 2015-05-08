package BabelLex;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
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
  my ($my_class, $lex_file, $romanized, $encoding, $dur_file, $map_file) = @_;

  $romanized = ($romanized eq "no" || $romanized eq "0") ? 0 : 1;
  &printIntro ($lex_file, $romanized, $encoding, $dur_file, $map_file);

  my $self = new TranscriptHolder('BabelLex');

  $self = {
    MAPFILE          => $map_file,
    LEXFILE          => $lex_file,
    DURFILE          => $dur_file,
    MAPTABLE         => {},
    LEXTABLE         => {},
    DURTABLE         => {},
    MISSINGPHONES    => {},
    ROMANIZED        => $romanized,
    ENCODING         => $encoding,
    MAPLOADSTATUS    => 0,        # 0 = table not loaded
    LEXLOADSTATUS    => 0,        # 1 = load in progress
    DURLOADSTATUS    => 0,        # 2 = table loaded
    AVERAGEPHONE     => 0,        # Substitution for missing phones
    LEXPHONESPERCHAR => 0,        # Ratio of phones per character in lex file
    DURATIONSTATUS   => "OK",     # Indicates OK/Estimated duration calculations
    PHONESIZESTATUS  => "OK"      # Indicates OK/Estimated phone calculations
  };

  #
  # The DURATIONSTATUS is used to collect and report the status of the duration
  # calculation. It is used in a manner similar to that of ERRNO flag. When
  # the getDurationHash() routine is invoked, it sets the DURATIONSTATUS to "OK".
  # Then, as the durations are calculated, the status can be downgraded to
  # either "Estimated" or "Failed". At the conclusion of the calculations the
  # DURATIONSTATUS is copied into the return hash. 
  #
  # ########### IMPORTANT!: The DURATIONSTATUS should not be used for any other
  #                         purposes as it may become overwritten.
  #
  # The status can be set to "OK", "Estimated", and "Failed".
  #
  #  "OK" status is given to the return data hash when all the phone duration
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
  #  "Failed" status is returned when a keyword or any word in a key phrase can
  # not be found in the lexicon hash table. Consequently, there will be no known
  # pronunciations to work with. The rest of the return data is set to 0.
  #


  bless $self;

  if (!$encoding) {

    print ("Warning! Continuing without encoding...\n");
  }
  else {

    $self->setEncoding($encoding);
  }

  if (!$lex_file)
  {
    MMisc::error_quit("Lexicon file and Romanized flag are required for\
      this module");
  }

  $self->loadLexFile($lex_file);

  if ($dur_file)
  {
    $self->loadDurFile ($dur_file, $map_file);
  }

  return $self;

} #new()

################################################################################
sub printIntro()
{
  my ($lex_file, $romanized, $encoding, $dur_file, $map_file) = @_;

  my $rome_text = ($romanized == 1) ?
    "Romanized column expected" : "Romanized column not expected";

  print "\n                             ***\n";
  print "Lexicon: $lex_file ($encoding)\n";
  print "$rome_text\n\n";
  
  if ($dur_file) {

    print "Durations: $dur_file\n";
  }
  else {

    print "Durations: No pnone durations filename received yet\n";
  }

  if ($map_file) {

    print "XSAMPA-to-Phone Map: $map_file";
  }
  else {

    print "Phone Maps: No pnone map filename received yet";
  }

  print "\n***\n\n";

} #printIntro()


################################################################################
# Map file provides mapping from the XSAMPA characters used in lexicon files to
# the phones used in the phone duration files. While some of these are the same
# some others can be different and the map file provides the translation needed.
################################################################################
sub loadMapFile() {

  my ($self, $file) = @_;

  if ($self->{MAPLOADSTATUS} > 0) {

    return "XSAMPA/Phone map file is already loaded or in progress";
  }
  else {

    $self->{MAPLOADSTATUS} = 1;
  }

  open my $DATA, $file or die "Couldn't open $file";


  my $header = <$DATA>; # Skip the file header
  while(<$DATA>) {

    my @words = split('\t', $_);
    chomp (@words);
    $self->{MAPTABLE}{$words[0]} = $words[1];
  }

  close $DATA;

  $self->{MAPFILE}       = $file;
  $self->{MAPLOADSTATUS} = 2;

  print "XSAMPA-to-Phone Map: $file";
  print "\n***\n\n";

  return "XSAMPA-to-Phone map file successfully loaded from $file";

} #loadMapFile()


################################################################################
# Lexicon file is a collection of words presented in one column. The second 
# column may be the "romanaized" version of the word. Some languages will not
# have the romanized version. The "romanized" flag indicates whether to account
# for the romanized column or not. The following columns are one or more pro-
# nunciations of the words. This routine loads the words and all available pro-
# nunciations into a hash for future use.
################################################################################
sub loadLexFile()
{
  my ($self, $file) = @_;

  my $num_words     = 0; # number of calculated average ratio values
  my $total_average = 0; # this is the total of average ratio values

  if ($self->{LEXLOADSTATUS} > 0)
  {
    return "Lexicon file is already loaded or in progress";
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
    my $phone_size = 0;

    my @words = split('\t', $_);
    chomp (@words);

    for (my $i = 1 + $self->{ROMANIZED}; $words[$i]; $i++)
    {
      my @adjusted = $self->adjustPronunciation($words[$i]);

      push (@{$entry{"pron"}},     $words[$i]);
      push (@{$entry{"adj_pron"}}, \@adjusted);
      push (@{$entry{"duration"}}, -1);          # duration unknown

      $phone_size = ($phone_size lt @adjusted) ? @adjusted : $phone_size;
    }

    $self->{LEXTABLE}{$words[0]} = \%entry;

    # Words length should always be > 0, if it is 0 then it's either a bug reading
    # the data or an error in the data. Either way we'll just die here and debug
    $total_average += $phone_size / length ($words[0]);
    $num_words++;

    #print Dumper(\%entry);
  }

  close $DATA;

  $self->{LEXPHONESPERCHAR} = $total_average / $num_words;
  $self->{LEXFILE}          = $file;
  $self->{LEXLOADSTATUS}    = 2;

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
  my ($self, $file, $mapfile) = @_;
  my $total                   = 0;
  my $num_phones              = 0;


  if ($self->{DURLOADSTATUS} > 0)
  {
    print "Duration file is already loaded or in progress";
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

  print "                             ***\n";
  print "Durations: " . $file . "\n";
  
  if (!$mapfile) {

    print "Warning! Continuing without XSAMPA to Phone map file...";
    print "\n***\n\n";
  }
  else {

    print "Mapfile: " . $mapfile . "\n";
    $self->loadMapFile($mapfile);
  }

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
  my $verbose  = 0;

  foreach my $word (keys $self->{LEXTABLE})
  {
    my $entry = \$self->{LEXTABLE}{$word};
    my @prons = @{${$$entry}{"adj_pron"}};
    my $var_num  = 0;
    my $status   = "OK";

    my $numphones           = 0;
    my $max_numphones       = 0;
    ${$$entry}{"numphones"} = 0;

    foreach my $variant (@prons)
    {
      my $duration = 0;
      foreach my $character (@$variant)
      {
        if ($character ne '.' && $character ne '#')
        {
          $numphones++;
          if ($self->{DURTABLE}{$character})
          {
            $duration += $self->{DURTABLE}{$character};
          }
          elsif ($self->{MAPTABLE}{$character})
          {
            my $mapped_character = $self->{MAPTABLE}{$character};
            if ($self->{DURTABLE}{$mapped_character})
            {
              # We are here because we didn't find the character in the phone
              # durations file, so instead we looked up a substitution in the
              # phone map file and now we will use it in the duration calcu-
              # lations. This is not an error.
              $duration += $self->{DURTABLE}{$mapped_character};
            }
            else
            {
              # Here  we didn't find the substituted phone in the phone map
              # file either, so we will substitute the duration we are
              # looking for with an average phone duration that we have
              # calculated when loaded the phone duration file. This is a
              # temporary workaround that should not get used as soon as
              # we have a correct finalized phone map file.
              if ($mapped_character ne "removed")
              {
                $duration += $self->{AVERAGEPHONE};
                $status = "Estimated";
                if ($self->{MISSINGPHONES}{$character})
                {
                  $self->{MISSINGPHONES}{$character}++;
                }
                else
                {
                  $self->{MISSINGPHONES}{$character} = 1;
                }
                if ($verbose)
                {
                  print ("Maptable substitution $mapped_character");
                  print (" for $character duration not found, Estimating.\n");
                }
              }
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
            if ($self->{MISSINGPHONES}{$character})
            {
              $self->{MISSINGPHONES}{$character}++;
            }
            else
            {
              $self->{MISSINGPHONES}{$character} = 1;
            }
            if ($verbose)
            {
              print ("Syllable $character not in Maptable and not in");
              print (" duration file, Estimating.\n");
            }
          }
        }
      } #foreach my $character (@$variant)

      # Store calculated duration and its "OK" or "Estimated" status
      # in the Lexicon hash table for future lookups.
      ${$$entry}{"duration"}[$var_num] = $duration;
      ${$$entry}{"status"}[$var_num] = $status;
      $var_num++;

      $max_numphones = $numphones if ($numphones > $max_numphones);
      $numphones     = 0;
    } #foreach my $variant (@prons)

    ${$$entry}{"numphones"} = $max_numphones;

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
  my ($self, $key_phrase, $num_phones_ref) = @_;

  my @word_array = split(" ", $key_phrase);
  my $duration   = 0;
  my @durations;

  if (scalar(@word_array) > 1)
  {
    foreach my $word (@word_array)
    {
      my $num_phones = 0;
      if (!$self->{LEXTABLE}{$word})
      {
        # One of the words in this key-phrase doesn't exsist in our
        # lexicon, so we using the pre-calculated ratio of average number
        # of phones per character, and pre-calculated average phone duration
        # to report both number of phones and the duration. The status is
        # reported as Estimated returning 0 values.
        $self->{DURATIONSTATUS}  = "Estimated";
        $self->{PHONESIZESTATUS} = "Estimated";
        print "The keyword $word is unknown, duration estimated\n";
        $num_phones = int (length ($word_array[0]) * $self->{LEXPHONESPERCHAR} + 0.5);
        $duration  += $num_phones * $self->{AVERAGEPHONE};;
      }
      else
      {
        # Just adding average durations of every word in a phrase together
        $duration += $self->getSingleWordDurationAverage ($word, \$num_phones);
      }
      $$num_phones_ref += $num_phones;
    }
    # Store the sum of averages in the array and return
    push (@durations, $duration);
    return \@durations;
  }
  elsif (scalar(@word_array) == 1)
  {
    if (!$self->{LEXTABLE}{$word_array[0]})
    {
      # This key-word doesn't exsist in our lexicon, so we are using the
      # pre-calculated ratio of average number of phones per character, and
      # pre-calculated average phone duration to report both number of phones
      # and the duration. The status is reported as Estimated
      $self->{DURATIONSTATUS}  = "Estimated";
      $self->{PHONESIZESTATUS} = "Estimated";
      print "The keyword $key_phrase is unknown, duration estimated\n";
      $$num_phones_ref = int (length ($word_array[0]) * $self->{LEXPHONESPERCHAR} + 0.5);
      $durations[0]    = $$num_phones_ref * $self->{AVERAGEPHONE};

      return \@durations;
    }
    
    return \@{$self->getSingleWordDurations($word_array[0], $num_phones_ref)};
  }
  else
  {
    # Empty key-word! Report Failed status and return 0 values.
    $self->{DURATIONSTATUS}  = "Failed";
    $self->{PHONESIZESTATUS} = "Failed";
    print "Empty key-word, duration invalid\n";
    $durations[0] = 0;
    $$num_phones_ref = 0;
    return \@durations;
  }

} #getDurations()


################################################################################
sub getSingleWordDurations()
{
  my ($self, $key_word, $num_phones_ref) = @_;

  my $entry = \$self->{LEXTABLE}{$key_word};

  # Consider the data status for every pronunciation variant and set the 
  # global DURATIONSTATUS accordingly. Here the status can only vary from OK to
  # Estimated. So if global status is OK, then symply accept the local value,
  # but if the global status has already been downgraded to Estimated, then
  # just ignore the local status because once the global status was set to
  # Estimated, it can not go back to OK.
  my @stati = @{${$$entry}{"status"}};
  foreach my $stat (@stati)
  {
    $self->{DURATIONSTATUS} =
      ($self->{DURATIONSTATUS} eq "OK") ? $stat : $self->{DURATIONSTATUS};
  }

  $$num_phones_ref = ${$$entry}{"numphones"};
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
    my $num_phones = 0;
    if (!$self->{LEXTABLE}{$word})
    {
      # One of the words in this key-phrase doesn't exsist in our
      # lexicon, so we using the pre-calculated ratio of average number
      # of phones per character, and pre-calculated average phone duration
      # to report both number of phones and the duration. The status is
      # reported as Estimated returning 0 values.
      $self->{DURATIONSTATUS}  = "Estimated";
      print "The keyword $word is unknown, duration estimated\n";
      $num_phones = int (length ($word) * $self->{LEXPHONESPERCHAR} + 0.5);
      $duration  += $num_phones * $self->{AVERAGEPHONE};
    }
    else
    {
      $duration += $self->getSingleWordDurationAverage($word);
    }
  }

  return $duration;

} #getDurationAverage()

################################################################################
sub getSingleWordDurationAverage()
{
  my ($self, $key_word, $num_phones_ref) = @_;

  my $dur_sum  = 0;
  my $num_durs = 0;

  my @durations = @{$self->getSingleWordDurations($key_word, $num_phones_ref)};

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

  foreach my $char (@result) {

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

  MMisc::error_quit("Error: Missing  phone durations file") if
    ($self->{DURLOADSTATUS} != 2);

  my $ret;
  my $num_phones = 0;

  $ret = {

    DURSTATUS  => "OK",
    DURATIONS  => [],
    DURAVERAGE => 0,
    SIZESTATUS => "OK",
    NUMPHONES  => 0
  };

  $self->{DURATIONSTATUS}  = "OK";
  $self->{PHONESIZESTATUS} = "OK";

  my @duration = @{$self->getDurations ($key_phrase, \$num_phones)};
  my $status = $self->{DURATIONSTATUS};

  if ($status eq "Failed") {

    $ret->{DURSTATUS} = $status;
    push (@{$ret->{DURATIONS}}, 0);
    $ret->{DURAVERAGE} = 0;
    $ret->{NUMPHONES}  = 0;
    $ret->{DURSTATUS}  = $status;
  }
  else {

    foreach my $dur (@duration) {

      push (@{$ret->{DURATIONS}}, $dur);
    }

    my $durave = $self->getDurationAverage ($key_phrase);
    $status = ($status eq "OK") ? $self->{DURATIONSTATUS} : $status;

    $ret->{DURSTATUS}  = $status;
    $ret->{DURAVERAGE} = $durave;
    $ret->{NUMPHONES}  = $num_phones;
    $ret->{SIZESTATUS} = $self->{PHONESIZESTATUS};
  }
  
  return $ret;

} #getDurationHash()


################################################################################
sub getMissingPhones()
{
  my ($self) = @_;

  return $self->{MISSINGPHONES};

} #getMissingPhones()


################################################################################
sub getOOVCount()
{
  my ($self, $key_phrase) = @_;
  my @word_array = split(" ", $key_phrase);
  my $oov = 0;

  MMisc::error_quit("Error: Attempt to look up an empty keyword")
    if (@word_array == 0);

  foreach my $word (@word_array) {

    $oov ++ if (! exists($self->{LEXTABLE}{$word}));
  }

  return $oov;
}

################################################################################
sub unitTest()
{
  my $mapfile = "/home/vad/TestData/102+103+201+203+206-phoneMaps.txt";

  my $lexfile = "/home/vad/TestData/IARPA-babel102b-v0.5a.lexicon";
  #my $lexfile = "/home/vlad/poc/lexicon.head";
  #my $lexfile = "/home/vad/TestData/IARPA-babel102b-v0.5a.lexicon.small";

  my $romanized = "";

  #my $durfile = "/home/vlad/poc/babel102b-v0.5a-phone_stats.perPhone.txt";
  my $durfile = "/home/vad/TestData/babel102b-v0.5a-phone_stats.perPhone.txt";
  
  my $encoding = "UTF-8";

  #my $lp = new BabelLex($lexfile, $romanized, $encoding, $durfile, $mapfile);
  #my $lp = new BabelLex($lexfile, $romanized, $encoding, $durfile);


  my $lp = new BabelLex($lexfile, $romanized, $encoding);

  $lp->loadDurFile($durfile, $mapfile);
 
  my $multiword = 3;
  my $phrase = " ";

  
  foreach my $keys (keys $lp->{LEXTABLE}) {

    my %res = %{$lp->getDurationHash($keys)};
    my $oov = $lp->getOOVCount($keys);

    print "Durations($res{DURSTATUS}): " . join(", ", @{$res{DURATIONS}}) . "\t";
    print "  Ave: " . $res{DURAVERAGE} . "\t \t";
    print "NumPhones($res{SIZESTATUS}): " . $res{NUMPHONES} . "\t \t";
    print "OOV Count: " . $oov . "\n";

    $phrase = $phrase . $keys . " ";
    $multiword--;

    if ($multiword == 0) {

      %res = %{$lp->getDurationHash($phrase)};
      $oov = $lp->getOOVCount($phrase);

      print "Durations($res{DURSTATUS}): " . join(", ", @{$res{DURATIONS}});
      print "\t  Ave: " . $res{DURAVERAGE};
      print "\t \tNumPhones($res{SIZESTATUS}): " . $res{NUMPHONES};
      print "\t \tOOV Count: " . $oov . "\t [$phrase]\n\n";

      $phrase    = " ";
      $multiword = 3;
    }
  }

  #print Dumper($lp);

} #unitTest()
