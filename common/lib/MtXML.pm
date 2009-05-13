package MtXML;

# M's tiny XML Functions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "MtXML.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;
use MMisc;

# No 'new', simply functions

##########

sub __plf {
  my ($lf, $rs, $p, $a) = @_;
  print "[$lf] -> [", substr($$rs, $p, length($lf) + $a), "]\n";
}  



sub _find_next_tag_pos {
  my $rstr = shift @_;
  my $offset = MMisc::iuv(shift @_, 0);
  my $name = MMisc::iuv(shift @_, "");

  ## With $name="" we are looking for any tag in between < >
  
  # First find the beginning tag "<name"
  my $lf = "<$name";
  my $b = index($$rstr, $lf, $offset);
  return(-1, -1) if ($b == -1);
  my $cpos = $b + length($lf);
                                  
  # Then the first ">"
  my $lf = ">";
  my $e = index($$rstr, $lf, $cpos);
  return(-1, -1) if ($e == -1);

  return($b, $e);
}

#####

sub _find_xml_tag_pos {
  my $name = shift @_;
  my $rstr = shift @_;
  my $offset = MMisc::iuv(shift @_, 0);

  my ($b, $pos) = &_find_next_tag_pos($rstr, $offset, $name);
  return(-1, -1, -1, -1) if ($b == -1);
                                  
  # if the character before > is a "/", ie we have <name/> and are done
  my $c = substr($$rstr, $pos - 1, 1);
  return($b, $pos, -1, -1)
    if ($c eq "/");

  #Otherwise, we know we have to look for "</name>"
  my $ib = $pos + 1;
  my $lf = "</$name>";
  my $pos = index($$rstr, $lf, $pos);
  return(-1, -1, -1, -1) if ($pos == -1);

  my $e = $pos + length($lf) - 1;
  my $ie = $pos - 1;

  # b    ib - 1 | ib                       ie | ie + 1       e
  # |-----------|-----------------------------|--------------|
  # >-----------< = ib - b
  #             >-----------------------------< = ie + 1 - ib
  #                                           >--------------< = e - ie
  # >--------------------------------------------------------< = e + 1 - b

  return($b, $e, $ib, $ie);
}

#####

sub _find_tag_string {
  my $name = shift @_;
  my $rstr = shift @_;
  my $replace = shift @_;
  my $offset = shift @_;

  my ($b, $e, $ib, $ie) = &_find_xml_tag_pos($name, $rstr, $offset);

  return("") if ($b == -1);

  my $txt = "";

  if (defined $replace) {
    $txt = substr($$rstr, $b, $e + 1 - $b, $replace);
  } else {
    $txt = substr($$rstr, $b, $e + 1 - $b);
  }

  return($txt);
}
  
##########

sub remove_xml_tags {
  my $name = shift @_;          # tag name
  my $rstr = shift @_;          # reference to the string

  my ($b, $e, $ib, $ie) = &_find_xml_tag_pos($name, $rstr);

  return(0) if ($b == -1);

  # <name/> case
  if ($ib == -1) {
    substr($$rstr, $b, $e + 1 - $b, "");
    return(1);
  }

  # <name> ... </name> case
  substr($$rstr, $ie + 1, $e - $ie, ""); # Remove end first to not shorten string beginning
  substr($$rstr, $b, $ib - $b, "");
  return(1);
}

##########

sub remove_xml_section {
  my $name = shift @_;          # tag name
  my $rstr = shift @_;          # reference to the string

  my ($b, $e, $ib, $ie) = &_find_xml_tag_pos($name, $rstr);

  return(0) if ($b == -1);

  substr($$rstr, $b, $e + 1 - $b, "");
  return(1);
}

##########

sub get_next_xml_name {
  my $rstr = shift @_; # reference to string
  my $txt = shift @_; # Default error string (returned if nothing found)

  my ($b, $e) = &_find_next_tag_pos($rstr, 0, "");
  return($txt) if ($b == -1);

  # Much faster regexp on subset of full string
  my $str = substr($$rstr, $b, $e + 1 - $b);
  if ($str =~ m%^<(.+)/?>$%s) {
    my $tmp = $1;
    my @a = split(m%\s+%, $tmp);
    $txt = $a[0];
  }

  return($txt);
}

##########

sub get_named_xml_section {
  my $name = shift @_;          # tag name
  my $rstr = shift @_;          # reference to the string
  my $txt = shift @_;           # Default error string

  my $wrkstr = &_find_tag_string($name, $rstr, "");
  return($txt) if (MMisc::is_blank($wrkstr));

  return($wrkstr);
}

##########

sub get_named_xml_section_with_inline_content {
  my $name = shift @_;          # tag name
  my $content = shift @_;       # inline content
  my $rstr = shift @_;          # reference to the string
  my $txt = shift @_;           # Default error string
  
  my $offset = 0;
  my $cont = 1;
  while ($cont) {
    my ($b, $e, $ib, $ie) = &_find_xml_tag_pos($name, $rstr, $offset);
    return($txt) if ($b == -1);

    # Much faster regexp on subset of full string
    my $str = "";
    # b->ib->ie->e
    if ($ib == -1) { # no ib->ie part, get b->e
      $str = substr($$rstr, $b, $e + 1 - $b);
    } else { # Go from b->ib
      $str = substr($$rstr, $b, $ib - 1, $ib - $b);
    }

    if ($str =~ m%<${name}\s.*${content}[^>]*/?>%) {
      $txt = substr($$rstr, $b, $e + 1 - $b, "");
      $cont = 0;
    }

    # Continue past just seen entry
    $offset = $e + 1;
  }

  return($txt);
}


##########

sub get_next_xml_section {
  my $rstr = shift @_;          # reference to the string
  my $des = shift @_;           # Default error string

  my $name = $des;
  my $section = $des;

  $name = &get_next_xml_name($rstr, $des);
  if ($name eq $des) {
    return($name,  "");
  }

  $section = &get_named_xml_section($name, $rstr, $des);

  return($name, $section);
}

##########

sub split_xml_tag {
  my $tag = shift @_;

  if ($tag =~ m%^([^\=]+)\=(.+)$%) {
    my ($name, $value) = ($1, $2);

    $name = MMisc::clean_begend_spaces($name);

    $value = MMisc::clean_begend_spaces($value);
    $value =~ s%^\s*\"%%;
    $value =~ s%\"\s*$%%;

    return($name, $value);
  } else {
    return("", "");
  }
}

#####

sub split_xml_tag_list_to_hash {
  my @list = @_;

  my %hash = ();
  foreach my $tag (@list) {
    my ($name, $value) = &split_xml_tag($tag);
    return("Problem splitting inlined attribute ($tag)", ())
      if (MMisc::is_blank($name));

    return("Inlined attribute ($name) appears to be present multiple times", ())
      if (exists $hash{$name});
    
    $hash{$name} = $value;
  }

  return("", %hash);
}

#####

sub split_line_into_tags {
  my $line = shift @_;

  my @all = ();
  while ($line =~ s%([^\s]+?)\s*(\=)\s*(\"[^\"]*?\")%%) {
    push @all, "$1$2$3";
  }
  return("Leftover text after tag extraction ($line)", ())
    if (! MMisc::is_blank($line));
  
  return("", @all);
}

#####

sub get_inline_xml_attributes {
  my $name = shift @_;
  my $str = shift @_;

  my ($b, $e) = &_find_next_tag_pos(\$str, 0, $name);
  return("Could not find tag", "") if ($b == -1);

  my $txt = substr($str, $b, $e + 1 - $b);
  $txt =~ s%<${name}%%s;
  $txt =~ s%^\s+%%;
  $txt =~ s%\/?\>$%%;

  my ($err, @all) = &split_line_into_tags($txt);
  return($err, ()) if (! MMisc::is_blank($err));
  return("", ()) if (scalar @all == 0); # None found

  my ($res, %hash) = &split_xml_tag_list_to_hash(@all);
  return($res, ()) if (! MMisc::is_blank($res));

  return("", %hash);
}

############################################################

1;
