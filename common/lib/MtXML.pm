package MtXML;
#
# $Id$
#
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

use strict;
use MMisc;

# No 'new', simply functions
my $__MtXML_des = '#####default error string#####';

##########

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
  $lf = ">";
  my $e = index($$rstr, $lf, $cpos);
  return(-1, -1) if ($e == -1);

  return($b, $e);
}

#####

sub _find_xml_tag_pos {
  my $name = shift @_;
  my $rstr = shift @_;
  my $offset = MMisc::iuv(shift @_, 0);

  my ($b, $bpos) = &_find_next_tag_pos($rstr, $offset, $name);
  return(-1, -1, -1, -1) if ($b == -1);
                                  
  # if the character before > is a "/", ie we have <name/> and are done
  my $c = substr($$rstr, $bpos - 1, 1);
  return($b, $bpos, -1, -1)
    if ($c eq "/");

  #Otherwise, we know we have to look for "</name>"
  my $ib = $bpos + 1;
  my $lf = "</$name>";
  my $pos = index($$rstr, $lf, $bpos);
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
  
  my $str = substr($$rstr, $b + 1, $e - $b - 1);
  substr($str, -1, 1, "")
    if (substr($str, -1) eq "/");
  
  my $sf = index($str, " ");

  # Could not find any space ? return the string
  return($str) if ($sf == -1);

  # Otherwise, return the name found
  return(substr($str, 0, $sf));
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

    my $str = "";
    # b->ib->ie->e
    if ($ib == -1) { # no ib->ie part, get b->e
      $str = substr($$rstr, $b, $e + 1 - $b);
    } else { # Go from b->ib
      $str = substr($$rstr, $b, $ib - $b);
    }

    # For next run, Continue past just seen entry
    $offset = $e + 1;

    # Try to find " content"
    my $sf = index($str, " $content");
    
    # try on next possibility if not found
    next if ($sf == -1);

    # Found it, blank string, return value
    return(substr($$rstr, $b, $e + 1 - $b, ""));
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
  return($name,  "") if ($name eq $des);

  $section = &get_named_xml_section($name, $rstr, $des);

  return($name, $section);
}

#####

sub get_inline_xml_attributes {
  my $sname = shift @_;
  my $str = shift @_;

  my ($b, $e) = &_find_next_tag_pos(\$str, 0, $sname);
  return("Could not find tag", "") if ($b == -1);

  my $bl = length("<${sname}");
  my $txt = substr($str, $b + $bl, $e - $b - $bl);
  substr($txt, -1, 1, "")
    if (substr($txt, -1) eq "/");

  my $cont = 1;
  my $offset = 0;
  my $l = length($txt);
  my %res = ();
  while (($offset < $l) && ($cont)) {
    my $ep = index($txt, "=", $offset);
    if ($ep == -1) { # No more
      $cont = 0;
      next;
    }

    my $qp1 = index($txt, "\"", $ep + 1);
    return("Could not find beg \"", ())
      if ($qp1 == -1);
    my $qp2 = index($txt, "\"", $qp1 + 1);
    return("Could not find end \"", ())
      if ($qp2 == -1);
   
    my $val = substr($txt, $qp1 + 1, $qp2 - $qp1 - 1);
    my $name = MMisc::clean_begend_spaces(substr($txt, $offset, $ep - $offset));

    $res{$name} = $val;

    $offset = $qp2 + 1;
  }

  return("", %res);
}

########################################

# MtXML::element_extractor(default_error_string, input_string, xml_section_name)
#  return(error_string, output_string, named_section_without_headers, named_section_inlined_attributes)
sub element_extractor {
  my ($dem, $string, $here) = @_;
  
  my $section = &get_named_xml_section($here, \$string, $dem);
  return("Looking for \'$here\': Could not extract section", $string)
    if ($section eq $dem);

  my ($err, %iattr) = &get_inline_xml_attributes($here, $section);
  return("Problem extracting \'$here' attributes: $err", $string, $section) 
    if (! MMisc::is_blank($err));

  # Remove processed header and trailer
  return("Could not clean \'$here\' tag", $string, $section)
    if (! &remove_xml_tags($here, \$section));

  return("", $string, $section, %iattr);
}

########################################

# MtXML::line_extractor(default_error_string, input_string)
# There must be only one FULL content per line (does not have to be closed but must end with >)
# return(error, closed, section_name, section_content, attributes)
sub line_extractor {
  my ($line) = @_;

  # Remove all XML comments
  $line =~ s%\<\!\-\-.+?\-\-\>%%sg;
  # Remove <?xml ...?> header
  $line =~ s%\<\?xml.+?\?\>%%is;

  return("", 1, "") if (MMisc::is_blank($line));

  my $name = &get_next_xml_name(\$line, $__MtXML_des);
  return("Problem finding XML name [$line]", 0, "") if ($name eq $__MtXML_des);
#  print "[$name]\n";
  my ($err, %res) = &get_inline_xml_attributes($name, $line);
  return("Problem extracting attributes for \'$name\' [$line]", 0, "") 
    if (! MMisc::is_blank($err));
#  foreach my $k (keys %res) { print "  -> $k : " . $res{$k} . "\n";  }

  # quick cleanup
  $line =~ s%^\s+%%;
  $line =~ s%\s+$%%;
  return("", 1, $name, $line, %res)
    if (&remove_xml_tags($name, \$line));

  return("", (substr($name, 0, 1) eq '/') ? 1 : 0, $name, "", %res);
}

############################################################

1;
