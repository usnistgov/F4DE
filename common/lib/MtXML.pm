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

sub remove_xml_tags {
  my $name = shift @_;          # tag name
  my $rstr = shift @_;          # reference to the string

  if ($$rstr =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    return(1);
  } elsif ($$rstr =~ s%\s*\<${name}(\>|\s+[^\>]+\>)(.+?)\<\/${name}\>%$2%s) {
    return(1);
  }

  return(0);
}

##########

sub remove_xml_section {
  my $name = shift @_;          # tag name
  my $rstr = shift @_;          # reference to the string

  if ($$rstr =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    return(1);
  } elsif ($$rstr =~ s%\s*\<${name}(\>|\s+[^\>]+\>).+?\<\/${name}\>%%s) {
    return(1);
  }

  return(0);
}

##########

sub get_next_xml_name {
  my $str = shift @_;           # String
  my $txt = shift @_; # Default error string (returned if nothing found)

  if ($str =~ m%^\s*\<\s*([^\>]+)%s) {
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
  
  if ($$rstr =~ s%(\<${name}(\/\>|\s+[^\>]+\/\>))%%s) {
    $txt = $1;
  } elsif ($$rstr =~ s%(\<${name}(\>|\s+[^\>]+\>).+?\<\/${name}\>)%%s) {
    $txt = $1;
  }

  return($txt);
}

##########

sub get_named_xml_section_with_inline_content {
  my $name = shift @_;          # tag name
  my $content = shift @_;       # inline content
  my $rstr = shift @_;          # reference to the string
  my $txt = shift @_;           # Default error string
  
  if ($$rstr =~ s%(\<${name}(\s+[^\>]*$content[^\>]*\/\>))%%s) {
    $txt = $1;
  } elsif ($$rstr =~ s%(\<${name}(\s+[^\>]*$content[^\>]*\>).+?\<\/${name}\>)%%s) {
    $txt = $1;
  }

  return($txt);
}


##########

sub get_next_xml_section {
  my $rstr = shift @_;          # reference to the string
  my $des = shift @_;           # Default error string

  my $name = $des;
  my $section = $des;

  $name = &get_next_xml_name($$rstr, $des);
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

  my $txt = "";
  if ($str =~ s%\s*\<${name}(\/\>|\s+[^\>]+\/\>)%%s) {
    $txt = $1;
  } elsif ($str =~ s%\s*\<${name}(\>|\s+[^\>]+\>)%%s) {
    $txt = $1;
  }
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
