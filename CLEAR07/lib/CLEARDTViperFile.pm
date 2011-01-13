package CLEARDTViperFile;

# CLEAR Detection and Tracking ViperFile
#
# Original Author(s) & Additions: Martial Michel
# Modified by Vasant Manohar to suit CLEAR/VACE evaluation framework
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEARDTViperFile.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "CLEARDTViperFile.pm Version: $version";

use ViperFramespan;
use MErrorH;
use MMisc;

use MtXML;

use CLEARSequence;
use CLEARFrame;
use CLEARObject;
use CLEAROBox;
use CLEARPoint;

use xmllintHelper;

########################################

# Required XSD files
my @xsdfilesl = ( "CLEAR.xsd", "CLEAR-viper.xsd", "CLEAR-viperdata.xsd" ); # Important that the main file be first

##### Memory representations

my %hash_file_attributes_types = 
  (
   "NUMFRAMES" => "dvalue",
   "SOURCETYPE" => undef,
   "H-FRAME-SIZE" => "dvalue",
   "V-FRAME-SIZE" => "dvalue",
   "FRAMERATE" => "fvalue",
  );

my @array_file_inline_attributes =
  ( "id", "name" ); # 'id' is to be first

# Authorized Object List
my @mandatory_objects = ("I-FRAMES", "FRAME"); # These are common across all video domains
my @eval_objects = ("TEXT", "FACE", "HAND", "PERSON", "VEHICLE"); # Some object-domain pairs are not supported. E.g. TEXT in Surveillance (SV)
my @ok_objects = (@mandatory_objects, @eval_objects);

# List of object attributes (reference annotations and system output) along with the domain these are defined on. Should make sure that the object's 
# spatial location attribute is in the very beginning. Additional location attributes follow before other attributes. 
# We specify the default values for each attribute. If there isn't a default value, we leave it as NULL (""). This is mainly used for reference annotations
# if the attribute value is not default, then the object is treated as 'Dont Care'.
my %list_objects_attributes;
@{$list_objects_attributes{"GL"}{"I-FRAMES"}}       = ();
@{$list_objects_attributes{"GL"}{"FRAME"}}          = ( { "name" => "EVALUATE",         "type" => "bvalue",     "dynamic" => 1,     "default" => "true"     } );
@{$list_objects_attributes{"BN"}{"TEXT"}}           = ( { "name" => "LOCATION",         "type" => "obox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "TYPE",             "type" => "dvalue",     "dynamic" => 0,     "default" => "1"        },
                                                        { "name" => "READABILITY",      "type" => "dvalue",     "dynamic" => 1,     "default" => "2"        },
                                                        { "name" => "CONTENT",          "type" => "svalue",     "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "OCCLUSION",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "LOGO",             "type" => "bvalue",     "dynamic" => 0,     "default" => "false"    }, 
                                                        { "name" => "DCR",              "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    }
                                                      );
@{$list_objects_attributes{"BN"}{"FACE"}}           = ( { "name" => "LOCATION",         "type" => "obox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "VISIBLE",          "type" => "bvalue",     "dynamic" => 1,     "default" => "true"     },
                                                        { "name" => "SYNTHETIC",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "AMBIGUITY FACTOR", "type" => "dvalue",     "dynamic" => 1,     "default" => "0"        }
                                                      );
@{$list_objects_attributes{"MR"}{"FACE"}}           = ( { "name" => "LOCATION",         "type" => "obox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "SYNTHETIC",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "AMBIGUITY FACTOR", "type" => "dvalue",     "dynamic" => 1,     "default" => "0"        }
                                                      );
@{$list_objects_attributes{"MR"}{"HAND"}}           = ( { "name" => "LOCATION",         "type" => "point",      "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "LARGEBOX",         "type" => "obox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "VISIBLE",          "type" => "bvalue",     "dynamic" => 1,     "default" => "true"     }, 
                                                        { "name" => "SYNTHETIC",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "HANDGEAR",         "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "OCCLUSION",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    }
                                                      );
@{$list_objects_attributes{"MR"}{"PERSON"}}         = ( { "name" => "BODY LOCATION",    "type" => "obox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "HEAD LOCATION",    "type" => "obox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "SYNTHETIC",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "OCCLUSION",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    }
                                                      );
@{$list_objects_attributes{"SV"}{"PERSON"}}         = ( { "name" => "LOCATION",         "type" => "bbox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "PRESENT",          "type" => "bvalue",     "dynamic" => 1,     "default" => "true"     },
                                                        { "name" => "OCCLUSION",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "SYNTHETIC",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "AMBIGUOUS",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    }
                                                      );
@{$list_objects_attributes{"UV"}{"PERSON"}}         = ( { "name" => "LOCATION",         "type" => "bbox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "PRESENT",          "type" => "bvalue",     "dynamic" => 1,     "default" => "true"     },
                                                        { "name" => "OCCLUSION",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "SYNTHETIC",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "AMBIGUOUS",        "type" => "bvalue",     "dyanmic" => 1,     "default" => "false"    }
                                                      );
@{$list_objects_attributes{"SV"}{"VEHICLE"}}        = ( { "name" => "LOCATION",         "type" => "bbox",       "dynamic" => 1,     "default" => ""         }, 
                                                        { "name" => "PRESENT",          "type" => "bvalue",     "dynamic" => 1,     "default" => "true"     },
                                                        { "name" => "OCCLUSION",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "AMBIGUOUS",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "MOBILITY",         "type" => "lvalue",     "dynamic" => 1,     "default" => "MOBILE"   }
                                                      );
@{$list_objects_attributes{"UV"}{"VEHICLE"}}        = ( { "name" => "LOCATION",         "type" => "obox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "GROUPBOX",         "type" => "obox",       "dynamic" => 1,     "default" => ""         },
                                                        { "name" => "VISIBLE",          "type" => "bvalue",     "dynamic" => 1,     "default" => "true"     },
                                                        { "name" => "OCCLUSION",        "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    },
                                                        { "name" => "MOBILITY",         "type" => "lvalue",     "dynamic" => 1,     "default" => "MOVING"   }
                                                      );

# The following are a list of attributes that are optional for an object (in reference annotations).
# If present, their value will be interpreted. We don't care if they are not there.
my %opt_list_objects_attributes;
@{$opt_list_objects_attributes{"GL"}{"I-FRAMES"}}           = ();
@{$opt_list_objects_attributes{"GL"}{"FRAME"}}              = ( { "name" => "CROWD",                    "type" => "bvalue",         "dynamic" => 1,         "default" => "false"    },
                                                                { "name" => "MULTIPLE VEHICLE",         "type" => "bvalue",         "dynamic" => 1,         "default" => "false"    },
                                                                { "name" => "MULTIPLE VEHICLES",        "type" => "bvalue",         "dynamic" => 1,         "default" => "false"    },
                                                                { "name" => "MULTIPLE TEXT AREAS",      "type" => "bvalue",         "dynamic" => 1,         "default" => "false"    }
                                                              );
@{$opt_list_objects_attributes{"BN"}{"TEXT"}}               = (); 
@{$opt_list_objects_attributes{"BN"}{"FACE"}}               = (); 
@{$opt_list_objects_attributes{"MR"}{"FACE"}}               = ( { "name" => "VISIBLE",                  "type" => "bvalue",         "dynamic" => 1,         "default" => "true"     },
                                                                { "name" => "PRESENT",                  "type" => "bvalue",         "dynamic" => 1,         "default" => "true"     }
                                                              ); 
@{$opt_list_objects_attributes{"MR"}{"HAND"}}               = (); 
@{$opt_list_objects_attributes{"MR"}{"PERSON"}}             = ( { "name" => "HEAD SHOULDER LOCATION",   "type" => "obox",           "dynamic" => 1,         "default" => ""         }, 
                                                                { "name" => "VISIBLE",                  "type" => "bvalue",         "dynamic" => 1,         "default" => "true"     },
                                                                { "name" => "PRESENT",                  "type" => "bvalue",         "dynamic" => 1,         "default" => "true"     },
                                                                { "name" => "DCR",                      "type" => "bvalue",         "dynamic" => 1,         "default" => "false"    },
                                                                { "name" => "AMBIGUOUS",                "type" => "bvalue",         "dynamic" => 1,         "default" => "false"    },
                                                                { "name" => "HEAD GEAR",                "type" => "bvalue",         "dynamic" => 1,         "default" => "false"    },
                                                                { "name" => "HEADGEAR",                 "type" => "bvalue",         "dynamic" => 1,         "default" => "false"    },
                                                              );
@{$opt_list_objects_attributes{"SV"}{"PERSON"}}             = (); 
@{$opt_list_objects_attributes{"UV"}{"PERSON"}}             = (); 
@{$opt_list_objects_attributes{"SV"}{"VEHICLE"}}            = ();
@{$opt_list_objects_attributes{"UV"}{"VEHICLE"}}            = ();

# Unlike the optional attributes, these are attributes whose values don't affect the evaluation setting
# even if they are present.
my %dont_care_list_objects_attributes; 
@{$dont_care_list_objects_attributes{"GL"}{"I-FRAMES"}}         = (); 
@{$dont_care_list_objects_attributes{"GL"}{"FRAME"}}            = (); 
@{$dont_care_list_objects_attributes{"BN"}{"TEXT"}}             = (); 
@{$dont_care_list_objects_attributes{"BN"}{"FACE"}}             = ( { "name" => "HEADGEAR",     "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    } ); 
@{$dont_care_list_objects_attributes{"MR"}{"FACE"}}             = ( { "name" => "HEADGEAR",     "type" => "bvalue",     "dynamic" => 1,     "default" => "false"    } ); 
@{$dont_care_list_objects_attributes{"MR"}{"HAND"}}             = (); 
@{$dont_care_list_objects_attributes{"MR"}{"PERSON"}}           = (); 
@{$dont_care_list_objects_attributes{"SV"}{"PERSON"}}           = ( { "name" => "MOBILITY",     "type" => "lvalue",     "dynamic" => 1,     "default" => "MOBILE"   } ); 
@{$dont_care_list_objects_attributes{"UV"}{"PERSON"}}           = ( { "name" => "MOBILITY",     "type" => "lvalue",     "dynamic" => 1,     "default" => "MOBILE"   } ); 
@{$dont_care_list_objects_attributes{"SV"}{"VEHICLE"}}          = ( { "name" => "CATEGORY",     "type" => "dvalue",     "dynamic" => 1,     "default" => ""         } ); 
@{$dont_care_list_objects_attributes{"UV"}{"VEHICLE"}}          = ( { "name" => "CATEGORY",     "type" => "dvalue",     "dynamic" => 1,     "default" => ""         } ); 

my @not_gtf_required_objects_attributes = ();

my %hash_objects_attributes_types;
my %hash_objects_attributes_types_dynamic;
my %hash_objects_attributes_types_default;

my %hasharray_inline_attributes;
@{$hasharray_inline_attributes{"bbox"}}     = ("x", "y", "height", "width");
@{$hasharray_inline_attributes{"obox"}}	    = ("x", "y", "height", "width", "rotation");
@{$hasharray_inline_attributes{"textline"}} = ("x", "y", "height", "width", "rotation", "offsets", "occlusions", "text");
@{$hasharray_inline_attributes{"point"}}    = ("x", "y");
@{$hasharray_inline_attributes{"fvalue"}}   = ("value");
@{$hasharray_inline_attributes{"bvalue"}}   = ("value");
@{$hasharray_inline_attributes{"dvalue"}}   = ("value");
@{$hasharray_inline_attributes{"svalue"}}   = ("value");
@{$hasharray_inline_attributes{"lvalue"}}   = ("value");

my @array_objects_inline_attributes = 
  ("name", "id", "framespan"); # order is important

my %not_gtf_required_dummy_values =
  (
   $not_gtf_required_objects_attributes[0] => 0,
   $not_gtf_required_objects_attributes[1] => 0,
  );

my @spmode_ok_list = 
  (
   "AVSS09", # AVSS09 Evaluation
  ); # Order is important

##########
# Default values to compare against (constant values)
my $default_error_value = "default_error_value";
my $framespan_max_default = "all";

########## Some rules that can be changed (here, specific for CLEAR)
# Maximum number of pair per framespan found
# For Trecvid08, only one pair (ie one framespan range) is authorized per framespan (0 for unlimited)
my $max_pair_per_fs = 0; # positive number / 0 for unlimited
# Check if IDs list have to start at 0
my $check_ids_start_at_zero = 0;
# Check that IDs are consecutive
my $check_ids_are_consecutive = 0;


########################################

## Constructor
sub new {
  my ($class, $evaldomain, $spmode) = 
    ($_[0], MMisc::iuv($_[1],  ""), MMisc::iuv($_[2],  ""));

  my $errortxt = (scalar @_ > 3) ? "CLEARDTViperFile takes maximum of 2 parameter (evaluation domain, special mode)" : "";

  # If the evaluation domain is not known at this point, we will set the required hashes later when 
  # the command line options are processed. This is for 'dummy' object that is used to do checks 
  # before processing files.
  &_fill_required_hashes($evaldomain, $spmode)
    if (! MMisc::is_blank($evaldomain));

  my $fs_tmp = ViperFramespan->new();

  my $xmllintobj = new xmllintHelper();
  $xmllintobj->set_xsdfilesl(@xsdfilesl);
  $errortxt .= $xmllintobj->get_errormsg() if ($xmllintobj->error());

  my $errormsg = MErrorH->new("CLEARDTViperFile");
  $errormsg->set_errormsg($errortxt);

  my $self =
    {
     xmllintobj     => $xmllintobj,
     gtf            => 0, # By default, files are not GTF
     file           => "",
     domain         => $evaldomain,
     fhash          => undef,
     comment        => "", # Comment to be written to write (or to each 'Observation' when generated)
     validated      => 0, # To confirm file was validated
     tol_in_frames  => 0, # The frame tolerance allowed for attributes to be outside of the object framespan 
     fs_framespan_max => $fs_tmp,
     spmode         => $spmode, # Special mode (so far AVSS09 only)
     errormsg       => $errormsg,
    };

  bless $self;
  return($self);
}

#####

sub _fill_required_hashes {
  my ($evaldomain, $spmode) = @_;

  my $checkFlag = 0;

  for (my $outloop = 0; $outloop < scalar @ok_objects; $outloop++) {
    my $key = $ok_objects[$outloop];
    my $domain;

    if (grep(m%^$key$%, @mandatory_objects)) { $domain = "GL"; }
    else { $domain = $evaldomain; }

    next if (! exists $list_objects_attributes{$domain}{$key});

    # Check if we have set at least one hash for an evaluation object in the domain
    if ($domain eq $evaldomain) { $checkFlag = 1; }

    # First fill the hash for reference annotation attributes
    my ( %this_hash_object_attributes_types, %this_hash_object_attributes_types_dynamic, %this_hash_object_attributes_types_default );
    my @this_object_attributes = @{$list_objects_attributes{$domain}{$key}};
    for (my $inloop = 0; $inloop < scalar @this_object_attributes; $inloop++) {
      my $keya  = $this_object_attributes[$inloop]->{"name"};
      my $keyt  = $this_object_attributes[$inloop]->{"type"};

      $this_hash_object_attributes_types{$keya} = $keyt;
      $this_hash_object_attributes_types_dynamic{$keya} = $this_object_attributes[$inloop]->{"dynamic"};
      $this_hash_object_attributes_types_default{$keya} = $this_object_attributes[$inloop]->{"default"};
    }

    if ( scalar @{$opt_list_objects_attributes{$domain}{$key}} > 0 ) {
        my @this_object_opt_attributes = @{$opt_list_objects_attributes{$domain}{$key}};
        for (my $inloop = 0; $inloop < scalar @this_object_opt_attributes; $inloop++) {
          my $keya  = $this_object_opt_attributes[$inloop]->{"name"};
          my $keyt  = $this_object_opt_attributes[$inloop]->{"type"};

          $this_hash_object_attributes_types{$keya} = $keyt;
          $this_hash_object_attributes_types_dynamic{$keya} = $this_object_opt_attributes[$inloop]->{"dynamic"};
          $this_hash_object_attributes_types_default{$keya} = $this_object_opt_attributes[$inloop]->{"default"};
        }
    }

    if ( scalar @{$dont_care_list_objects_attributes{$domain}{$key}} > 0 ) {
        my @this_object_dont_care_attributes = @{$dont_care_list_objects_attributes{$domain}{$key}};
        for (my $inloop = 0; $inloop < scalar @this_object_dont_care_attributes; $inloop++) {
          my $keya  = $this_object_dont_care_attributes[$inloop]->{"name"};
          my $keyt  = $this_object_dont_care_attributes[$inloop]->{"type"};

          $this_hash_object_attributes_types{$keya} = $keyt;
          $this_hash_object_attributes_types_dynamic{$keya} = $this_object_dont_care_attributes[$inloop]->{"dynamic"};
          $this_hash_object_attributes_types_default{$keya} = $this_object_dont_care_attributes[$inloop]->{"default"};
        }
    }
    $hash_objects_attributes_types{$key}{1} = \%this_hash_object_attributes_types;
    $hash_objects_attributes_types_dynamic{$key}{1} = \%this_hash_object_attributes_types_dynamic;
    $hash_objects_attributes_types_default{$key}{1} = \%this_hash_object_attributes_types_default;

    # Fill the hash for system output attributes
    my ( %sys_hash_object_attributes_types, %sys_hash_object_attributes_types_dynamic, %sys_hash_object_attributes_types_default );
    my @sys_object_attributes;

    # Use all the location attributes in the reference annotation and the first attribute in the list (the first attribute is mandatory)
    for (my $inloop = 0; $inloop < scalar @{$list_objects_attributes{$domain}{$key}}; $inloop++) {
        push @sys_object_attributes, $list_objects_attributes{$domain}{$key}->[$inloop]
            if (($inloop == 0) || ($list_objects_attributes{$domain}{$key}->[$inloop]{"type"} eq "obox") || ($list_objects_attributes{$domain}{$key}->[$inloop]{"type"} eq "bbox") || ($list_objects_attributes{$domain}{$key}->[$inloop]{"type"} eq "point"));
    }

    # Use the ones that are optional as well.
    for (my $inloop = 0; $inloop < scalar @{$opt_list_objects_attributes{$domain}{$key}}; $inloop++) {
        push @sys_object_attributes, $opt_list_objects_attributes{$domain}{$key}->[$inloop]
            if (($opt_list_objects_attributes{$domain}{$key}->[$inloop]{"type"} eq "obox") || ($opt_list_objects_attributes{$domain}{$key}->[$inloop]{"type"} eq "bbox") || ($opt_list_objects_attributes{$domain}{$key}->[$inloop]{"type"} eq "point"));
    }

    for (my $inloop = 0; $inloop < scalar @sys_object_attributes; $inloop++) {
      my $keya  = $sys_object_attributes[$inloop]->{"name"};
      my $keyt  = $sys_object_attributes[$inloop]->{"type"};

      $sys_hash_object_attributes_types{$keya} = $keyt;
      $sys_hash_object_attributes_types_dynamic{$keya} = $sys_object_attributes[$inloop]->{"dynamic"};
      $sys_hash_object_attributes_types_default{$keya} = $sys_object_attributes[$inloop]->{"default"};
    }

    $hash_objects_attributes_types{$key}{0} = \%sys_hash_object_attributes_types;
    $hash_objects_attributes_types_dynamic{$key}{0} = \%sys_hash_object_attributes_types_dynamic;
    $hash_objects_attributes_types_default{$key}{0} = \%sys_hash_object_attributes_types_default;
  }

  MMisc::error_quit("Unsupported object-domain pair (Input file contains objects that are not supported in '$evaldomain')")
      if (! $checkFlag);

  ## Special Modes
#  print "hash_objects_attributes_types:\n" . MMisc::get_sorted_MemDump(\%hash_objects_attributes_types) . "\n\n\n";
#  print "opt_list_objects_attributes:\n" . MMisc::get_sorted_MemDump(\%opt_list_objects_attributes);
#  MMisc::ok_quit();

  if ($spmode eq $spmode_ok_list[0]) { # AVSS09
    MMisc::error_quit("AVSS09 mode is only usable for Surveillance type domain")
        if ($evaldomain ne "SV");

    ## FRAME
    # SYS: No EVALUATE
    delete $hash_objects_attributes_types{'FRAME'}{'0'}{'EVALUATE'};
    # REF: No CROWD, MULTIPLE TEXT AREAS, MULTIPLE VEHICLE, MULTIPLE VEHICLES
    delete $hash_objects_attributes_types{'FRAME'}{'1'}{'CROWD'};
    delete $hash_objects_attributes_types{'FRAME'}{'1'}{'MULTIPLE TEXT AREAS'};
    delete $hash_objects_attributes_types{'FRAME'}{'1'}{'MULTIPLE VEHICLE'};
    delete $hash_objects_attributes_types{'FRAME'}{'1'}{'MULTIPLE VEHICLES'};

    ## PERSON
    # REF: No MOBILITY
    delete $hash_objects_attributes_types{'PERSON'}{'1'}{'MOBILITY'};

    ## VEHICLE: Not authorized
    delete $hash_objects_attributes_types{'VEHICLE'};
  }
}

#####

sub set_required_hashes {
  my ($self, $evaldomain, $spmode) = @_;
  &_fill_required_hashes($evaldomain, $spmode);
  $self->_set_domain($evaldomain);
}

####################

sub set_frame_tolerance {
  my ($self, $tif) = @_;

  if (! defined $tif) { $self->_set_errormsg("'tif' is not defined in 'set_frame_tolerance'"); return 0; }
  $self->{tol_in_frames} = $tif;
  return 1;
}

sub get_frame_tolerance {
  my $self = $_[0];
  return $self->{tol_in_frames};
}

####################

sub _set_domain {
  my ($self, $evaldomain) = @_;

  if (! defined $evaldomain) { $self->_set_errormsg("'evaldomain is not defined in '_set_domain'"); return 0; }
  $self->{domain} = $evaldomain;
}

sub get_domain {
  my $self = $_[0];
  return($self->{domain});
}

####################

sub get_version {
  my $self = $_[0];
  return($versionid);
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errormsg}->set_errormsg($txt);
}

##########

sub get_errormsg {
  my $self = $_[0];
  return($self->{errormsg}->errormsg());
}

##########

sub error {
  my $self = $_[0];
  return($self->{errormsg}->error());
}

############################################################

sub get_required_xsd_files_list {
  my $self = $_[0];

  return(-1) if ($self->error());

  return(@xsdfilesl);
}

#####

sub validate_objects_list {
  my ($self, @tmpa) = @_;

  my @objects = MMisc::uppercase_array_values(\@tmpa);

  @objects = split(m%\,%, join(",", @objects));
  @objects = &_make_array_of_unique_values(@objects);
  my ($in, $out) = MMisc::compare_arrays(\@ok_objects, \@objects);
  if (scalar @$out > 0) {
    $self->_set_errormsg("Found some unknown object type: " . join(" ", @$out));
    return();
  }

  return(@objects);
}

#####

sub get_full_objects_list {
  my $self = $_[0];

  return(-1) if ($self->error());

  return(@ok_objects);
}

#####

sub _get_hasharray_inline_attributes {
  my $self = $_[0];

  return(-1) if ($self->error());

  return(%hasharray_inline_attributes);
}

########## 'xmllint'

sub set_xmllint {
  my ($self, $xmllint, $nocheck) = MMisc::iuav(\@_, undef, "", 0);

  return(0) if ($self->error());

  $self->{xmllintobj}->set_xmllint($xmllint, $nocheck);

  if ($self->{xmllintobj}->error()) {
    $self->_set_errormsg($self->{xmllintobj}->get_errormsg());
    return(0);
  }

  return(1);
}

#####

sub _is_xmllint_set {
  my $self = $_[0];

  return(0) if ($self->error());

  return($self->{xmllintobj}->is_xmllint_set());
}

#####

sub get_xmllint {
  my $self = $_[0];

  return(-1) if ($self->error());

  if (! $self->_is_xmllint_set()) {
    $self->_set_errormsg("\'xmllint\' is not set");
    return(0);
  }

  return($self->{xmllintobj}->get_xmllint());
}

########## 'xsdpath'

sub set_xsdpath {
  my ($self, $xsdpath, $nocheck) = MMisc::iuav(\@_, undef, "", 0);

  return(0) if ($self->error());

  $self->{xmllintobj}->set_xsdpath($xsdpath, $nocheck);
  if ($self->{xmllintobj}->error()) {
    $self->_set_errormsg($self->{xmllintobj}->get_errormsg());
    return(0);
  }

  return(1);
}

#####

sub _is_xsdpath_set {
  my $self = $_[0];

  return(0) if ($self->error());

  return($self->{xmllintobj}->is_xsdpath_set());
}

#####

sub get_xsdpath {
  my $self = $_[0];

  return(-1) if ($self->error());

  if (! $self->_is_xsdpath_set()) {
    $self->_set_errormsg("\'xsdpath\' is not set");
    return(0);
  }

  return($self->{xmllintobj}->get_xsdpath());
}

########## 'gtf'

sub set_as_gtf {
  my $self = $_[0];

  return(0) if ($self->error());

  $self->{gtf} = 1;
  return(1);
}

#####

sub check_if_gtf {
  my $self = $_[0];

  return(0) if ($self->error());

  return($self->{gtf});
}

#####

sub check_if_sys {
  my $self = $_[0];

  return(0) if ($self->error());

  my $r = ($self->{gtf}) ? 0 : 1;

  return($r);
}

########## 'fhash'

sub _set_fhash {
  my ($self, %fhash) = @_;

  return(0) if ($self->error());

  $self->{fhash} = \%fhash;
  return(1);
}

#####

sub _is_fhash_set {
  my $self = $_[0];

  return(0) if ($self->error());

  return(1) if (defined $self->{fhash});

  return(0);
}

#####

sub _get_fhash {
  my $self = $_[0];

  return(-1) if ($self->error());

  if (! $self->_is_fhash_set()) {
    $self->_set_erromsg("\'fhash\' is not set");
    return(0);
  }

  my $rfhash = $self->{fhash};

  my %res = %{$rfhash};

  return(%res);
}

########## 'file'

sub set_file {
  my ($self, $file, $nocheck) =MMisc::iuav(\@_, undef, "", 0);

  return(0) if ($self->error());

  if (MMisc::is_blank($file)) {
    $self->_set_errormsg("Empty file name");
    return(0);
  }
  
  if (! $nocheck) {
    if (! -e $file) {
      $self->_set_errormsg("File does not exists ($file)");
      return(0);
    }
    if (! -r $file) {
      $self->set_errormsg("File is not readable ($file)");
      return(0);
    }
    if (! -f $file) {
      $self->set_errormsg("Parameter is not a file ($file)");
      return(0);
    }
  }

  $self->{file} = $file;
  return(1);
}

#####

sub _is_file_set {
  my $self = $_[0];

  return(0) if ($self->error());

  return(0) if (MMisc::is_blank($self->{file}));

  return(1);
}

#####

sub get_file {
  my $self = $_[0];

  return(-1) if ($self->error());

  if (! $self->_is_file_set()) {
    $self->_set_errormsg("\'file\' is not set");
    return(0);
  }

  return($self->{file});
}

########## 'framespan_max'

sub _is_framespan_max_set {
  my $self = $_[0];

  return(0) if ($self->error());

  my $fs_tmp = $self->{fs_framespan_max};

  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error accessing the \'framespan_max\' object (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  return(1) if ($fs_tmp->is_value_set());

  return(0);
}

#####

sub _get_framespan_max_value {
  my $self = $_[0];

  return(0) if ($self->error());

  if (! $self->_is_framespan_max_set()) {
    $self->_set_errormsg("Can not get \'framespan_max\', it appears not to be set yet");
    return(0);
  }

  my $fs_tmp = $self->{fs_framespan_max};

  my $v = $fs_tmp->get_value();

  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error accessing the \'framespan_max\' object (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  return($v);
}

#####

sub _get_framespan_max_object {
  my $self = $_[0];

  return(0) if ($self->error());

  if (! $self->_is_framespan_max_set()) {
    $self->_set_errormsg("Can not get \'framespan_max\', it appears not to be set yet");
    return(0);
  }

  my $fs_tmp = $self->{fs_framespan_max};

  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error accessing the \'framespan_max\' object (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  return($fs_tmp);
}

#####

sub _set_framespan_max_value {
  my ($self, $fs) = @_;

  return(0) if ($self->error());

  my $fs_tmp = $self->{fs_framespan_max};

  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error accessing the \'framespan_max\' object (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  my $v = $fs_tmp->set_value($fs);
  if ($fs_tmp->error()) {
    $self->_set_errormsg("Error setting the \'framespan_max\' (" . $fs_tmp->get_errormsg() . ")");
    return(0);
  }

  return(1);
}

########## 'comment'

sub _addto_comment {
  my ($self, $comment) = @_;

  return(0) if ($self->error());

  $self->{comment} .= "\n" if ($self->_is_comment_set());

  $self->{comment} .= $comment;
  return(1);
}

#####

sub _is_comment_set {
  my $self = $_[0];

  return(0) if ($self->error());

  return(1) if (! MMisc::is_blank($self->{comment}));

  return(0);
}

#####

sub _get_comment {
  my $self = $_[0];

  return(-1) if ($self->error());

  if (! $self->_is_comment_set()) {
    $self->_set_errormsg("\'comment\' not set");
    return(0);
  }

  return($self->{comment});
}

########################################

sub is_validated {
  my $self = $_[0];

  return(0) if ($self->error());

  return(1) if ($self->{validated} == 1);

  return(0);
}

#####

sub validate {
  my ($self, $xtracheck) = $_[0];


  return(0) if ($self->error());

  # No need to re-validate if the file was already validated :)
  return(1) if ($self->is_validated());

  if (! $self->_is_file_set()) {
    $self->_set_errormsg("No file set (use \'set_file\') before calling the \'validate\' function");
    return(0);
  }
  my $ifile = $self->get_file();

  if (! $self->_is_xmllint_set()) {
    # We will try to set it up from PATH
    return(0) if (! $self->set_xmllint());
  }

  if (! $self->_is_xsdpath_set()) {
    # We will try to set it up from '.'
    return(0) if (! $self->set_xsdpath("."));
  }

  # Load the XML through xmllint
  my ($bigstring) = $self->{xmllintobj}->run_xmllint($ifile);
  if ($self->{xmllintobj}->error()) {
    $self->_set_errormsg($self->{xmllintobj}->get_errormsg());
    return(0);
  }
  # No data from xmllint ?
  if (MMisc::is_blank($bigstring)) {
    $self->_set_errormsg("WEIRD: The XML data returned by xmllint seems empty");
    return(0);
  }

  # Initial Cleanups & Check
  my $isgtf = $self->check_if_gtf();
  (my $res, $bigstring) = &_data_cleanup($bigstring, $isgtf);
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }

  # Process the data part
  my %fdata;
  ($res, %fdata) = $self->_data_processor($bigstring, $isgtf);
  if (! MMisc::is_blank($res)) {
    $self->_set_errormsg($res);
    return(0);
  }

  if ($xtracheck) {
    my $res = &_validate_frames(\%fdata);
    if (! MMisc::is_blank($res)) {
      $self->_set_errormsg($res);
      return(0);
    }
  }

  $self->_set_fhash(%fdata);
  $self->{validated} = 1;

  return(1);
}

#####

sub _validate_frames {
  my ($rh) = @_;

  my @pbl = ();
  for (my $i = 0; $i < scalar @eval_objects; $i++) {
    next if (! MMisc::safe_exists($rh, $eval_objects[$i]));

    foreach my $id (keys %{$$rh{$eval_objects[$i]}}) {
      next if (! MMisc::safe_exists($rh, $eval_objects[$i], $id, $array_objects_inline_attributes[2]));
      my $gfs = $$rh{$eval_objects[$i]}{$id}{$array_objects_inline_attributes[2]};
      my $gfs_fs = ViperFramespan->new();
      return("Problem with " . $eval_objects[$i] . " # $id 's framespan ($gfs): " . $gfs_fs->get_errormsg)
        if (! $gfs_fs->set_value($gfs));

      my $gfs_fsv = $gfs_fs->get_value();

      foreach my $key (keys %{$$rh{$eval_objects[$i]}{$id}}) {
        next if ($key eq $array_objects_inline_attributes[2]);

        my $tmpfs = join(" ", keys %{$$rh{$eval_objects[$i]}{$id}{$key}});
        my $tmpfs_fs = ViperFramespan->new();
        return("Problem with " . $eval_objects[$i] . " # $id 's $key framespan ($tmpfs_fs): " . $tmpfs_fs->get_errormsg)
        if (! $tmpfs_fs->set_value($tmpfs));
        
        my $tmpfs_fsv = $tmpfs_fs->get_value();

        # At this point, post cleanup the strings should be exactly the same
        push @pbl, ("Problem with " . $eval_objects[$i] . " # $id 's $key, contained framepsans ($tmpfs_fsv) does not exactly match container's framespan ($gfs_fsv).  ##### ")
          if ($tmpfs_fsv ne $gfs_fsv);
      }
    }
  }

  return(join("", @pbl));
}

####################

sub reformat_xml {
  my ($self, @tmpa) = @_;

  my @limitto_objects = MMisc::uppercase_array_values(\@tmpa);

  my $domain = $self->get_domain();
  my $isgtf  = $self->check_if_gtf();

  return(-1) if ($self->error());

  if (scalar @limitto_objects == 0) {
    @limitto_objects = @ok_objects;
  } else {
    @limitto_objects = $self->validate_objects_list(@limitto_objects);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only rewrite the XML for a validated file");
    return(0);
  }

  my $comment = "";
  $comment = $self->_get_comment() if ($self->_is_comment_set());

  my %tmp = $self->_get_fhash();

  return(&_writeback2xml($comment, $domain, $isgtf, \%tmp, @limitto_objects));
}

##########

sub get_base_xml {
  my ($self, $isgtf, @tmpa) = @_;

  my @limitto_objects = MMisc::uppercase_array_values(\@tmpa);
  my $domain = $self->get_domain();

  return(-1) if ($self->error());

  if (scalar @limitto_objects == 0) {
    @limitto_objects = @ok_objects;
  } else {
    @limitto_objects = $self->validate_objects_list(@limitto_objects);
    return(0) if ($self->error());
  }

  my %tmp = ();
  return(&_writeback2xml("", $domain, $isgtf, \%tmp, @limitto_objects));
}

####################

sub _display_all {
  my $self = $_[0];

  return(-1) if ($self->error());

  return(MMisc::get_sorted_MemDump(\$self));
}

#####

sub _display {
  my ($self, @limitto_objects) = @_;

  return(-1) if ($self->error());

  if (scalar @limitto_objects == 0) {
    @limitto_objects = @ok_objects;
  } else {
    @limitto_objects = $self->validate_objects_list(@limitto_objects);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'_display\' for a validated file");
    return(0);
  }

  my %in = $self->_get_fhash();
  my %out = &_clone_fhash_selected_objects(\%in, @limitto_objects);

  return(MMisc::get_sorted_MemDump(\%out));
}

########################################

sub _get_short_sf_file {
  my $txt = $_[0];

  # Remove all 'file:' or related
  $txt =~ s%^.+\:%%g;

  # Remove all paths
  $txt =~ s%^.+\/%%g;

  # lowercase
#  $txt = lc($txt);

  return($txt);
}

#####

sub get_sourcefile_filename {
  my $self = $_[0];

  return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'get_sourcefile_filename\' for a validated file");
    return(0);
  }

  my %lk = $self->_get_fhash();

  if (! defined $lk{"file"}{"filename"}) {
    $self->_set_errormsg("WEIRD: In \'get_sourcefile_filename\': Could not find the filename");
    return(0);
  }

  my $fname = $lk{"file"}{"filename"};

  $fname = &_get_short_sf_file($fname);

  return($fname);
}

####################

sub remove_all_objects {
  my $self = $_[0];

  return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only \"remove all objects\" for a validated file");
    return(0);
  }

  my %in = $self->_get_fhash();
  my %out = &_clone_fhash_selected_objects(\%in);

  $self->_set_fhash(%out);
  return(1);
}

##########

sub _clone_core {
  my ($self, $keep_objects) = @_;

  return(undef) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only \'clone\' a validated file");
    return(undef);
  }
  
  my $domain = $self->get_domain();
  my $spmode = $self->get_spmode();

  my $clone = new CLEARDTViperFile($domain, $spmode);
  
  $clone->set_xmllint($self->get_xmllint(), 1);
  $clone->set_xsdpath($self->get_xsdpath(), 1);
  $clone->set_as_gtf() if ($self->check_if_gtf());
  $clone->set_file($self->get_file(), 1);

  my %in = $self->_get_fhash();
  my %out;
  if ($keep_objects) {
    %out = &_clone_fhash_selected_objects(\%in, @ok_objects);
  } else {
    %out = &_clone_fhash_selected_objects(\%in);
  }
  $clone->_set_fhash(%out);
  $clone->{validated} = 1;

  return(undef) if ($self->error());
  if ($clone->error()) {
    $self->_set_errormsg("A problem occurred while \'clone\'-ing (" . $clone->get_errormsg() .")");
    return(undef);
  }

  return($clone);
}

#####

sub clone {
  my $self = $_[0];

  return($self->_clone_core(1));
}

#####

sub clone_with_no_objects {
 my $self = $_[0];

  return($self->_clone_core(0));
}

##########

sub _get_fhash_file_numframes {
  my $self = $_[0];

  return(0) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only get \'numframes\' for a validated file");
    return(0);
  }

  my %tmp = $self->_get_fhash();

  if (! exists $tmp{"file"}{"NUMFRAMES"}) {
    $self->_set_errormsg("WEIRD: Can not access file's \'numframes\'");
    return(0);
  }

  return($tmp{"file"}{"NUMFRAMES"});
}

####

sub _set_fhash_file_numframes {
  my ($self, $numframes, $ignoresmallervalues, $commentadd) = @_;

  if ($numframes <= 0) {
    $self->_set_errormsg("Can not set file's \'numframes\' to a negative or zero value");
    return(0);
  }

  my $cnf = $self->_get_fhash_file_numframes();
  return(0) if ($self->error());

  if ($numframes <= $cnf) {
    return(1) if ($ignoresmallervalues);

    $self->_set_errormsg("Can not reduce the file\'s \'numframes\' value");
    return(0);
  }

  my %tmp = $self->_get_fhash();

  if (! exists $tmp{"file"}{"NUMFRAMES"}) {
    $self->_set_errormsg("WEIRD: Can not access file's \'numframes\'");
    return(0);
  }

  $tmp{"file"}{"NUMFRAMES"} = $numframes;

  $self->_set_fhash(%tmp);
  $self->_addto_comment("NUMFRAMES extended from $cnf to $numframes" . ((! MMisc::is_blank($commentadd)) ? " ($commentadd)" : ""));
  return(0) if ($self->error());

  return(1);
}

#####

sub extend_numframes {
  my ($self, $numframes, $commentadd) = @_;

  return($self->_set_fhash_file_numframes($numframes, 1, $commentadd));
}

##########

sub get_first_available_object_id {
  my ($self, $object) = @_;

  return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only get first available object id for a validated file");
    return(-1);
  }

  if (! grep(m%^$object$%, @ok_objects)) {
    $self->set_errormsg("Eventtype ($object) is not a recognized one");
    return(-1);
  }

  my %tmp = $self->_get_fhash();

  # No object of this type set yet, so the first id available (0)
  return(0) if (! exists $tmp{$object});

  my @keys = sort _numerically  keys %{$tmp{$object}};

  return(1 + $keys[-1]);
}

##########

sub _bvalue_convert {
  my ($attr, @values) = @_;

  print "[_bvalue_convert] Somebody called me. Am not ready yet\n";
  return(@values) if ($hash_objects_attributes_types{$attr} ne "bvalue");

  my @out;
  foreach my $i (@values) {
    if ($i == 1) {
      push @out, "true";
    } elsif ($i == 0) {
      push @out, "false";
    } else {
      push @out, $i;
    }
  }

  return(@out);
}

#####

sub change_sourcefile_filename {
  my ($self, $nfname) = @_;

  return(-1) if ($self->error());

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only call \'change_sourcefile_filename\' for a validated file");
    return(0);
  }

  my %lk = $self->_get_fhash();

  if (! defined $lk{"file"}{"filename"}) {
    $self->_set_errormsg("WEIRD: In \'get_sourcefile_filename\': Could not find the filename");
    return(0);
  }

  my $oname = $lk{"file"}{"filename"};
  my $soname = &_get_short_sf_file($oname);

  $lk{"file"}{"filename"} = $nfname;
  $self->_set_fhash(%lk);

  $self->_addto_comment("\'sourcefile\' changed from \'$oname\' (short: \'$soname\') to \'$nfname\'");

  return(-1) if ($self->error());

  return(1);
}


############################################################
# Internals
########################################

sub _data_cleanup {
  my ($bigstring, $isgtf) = @_;

  # Remove all XML comments
  $bigstring =~ s%\<\!\-\-.+?\-\-\>%%sg;

  # Remove <?xml ...?> header
  return("Could not find a proper \'<?xml ... ?>\' header, skipping", $bigstring)
    if (! ($bigstring =~ s%^\s*\<\?xml.+?\?\>%%is));

  # Remove <viper ...> and </viper> header and trailer
  return("Could not find a proper \'viper\' tag, aborting", $bigstring)
    if (! MtXML::remove_xml_tags("viper", \$bigstring));

  # Remove <config> section
  return("Could not find a proper \'config\' section, aborting", $bigstring)
    if (! MtXML::remove_xml_section("config", \$bigstring) && $isgtf);

  # At this point, all we ought to have left is the '<data>' content
  return("After initial cleanup, we found more than just viper \'data\', aborting", $bigstring)
    if (! ( ($bigstring =~ m%^\s*\<data>%is) && ($bigstring =~ m%\<\/data\>\s*$%is) ) );

  return("", $bigstring);
}

########################################

sub _data_processor {
  my ($self, $string, $isgtf) = @_;

  my $res = "";
  my %fdata = ();

  #####
  # First off, confirm the first section is 'data' and remove it
  my $name = MtXML::get_next_xml_name(\$string, $default_error_value);
  return("Problem obtaining a valid XML name, aborting", $string)
    if ($name eq $default_error_value);
  return("\'data\' section not present (instead: $name), aborting", $string)
    if ($name !~ m%^data$%i);
  return("Problem cleaning \'data\' tags", $string)
    if (! MtXML::remove_xml_tags($name, \$string));

  #####
  # Now, the next --and only-- section is to be a 'sourcefile'
  my $name = MtXML::get_next_xml_name(\$string, $default_error_value);
  return("Problem obtaining a valid XML name, aborting", $string)
    if ($name eq $default_error_value);
  return("\'sourcefile\' section not present (instead: $name), aborting", $string)
    if ($name !~ m%^sourcefile$%i);
  my $tmp = $string;
  my $section = MtXML::get_named_xml_section($name, \$string, $default_error_value);
  return("Problem obtaining the \'sourcefile\' XML section, aborting", $tmp)
    if ($name eq $default_error_value);
  # And nothing else should be left in the file
  return("Data left in addition to the \'sourcefile\' XML section, aborting", $string)
    if (! MMisc::is_blank($string));
  # Parse it
  ($res, %fdata) = $self->_parse_sourcefile_section($name, $section, $isgtf);

  if (! MMisc::is_blank($res)){
    my @resA = split(/\n/, $res);
    my $str = "";
    for (my $_i=0; $_i<@resA; $_i++){  
        $str .= "Problem while processing the \'sourcefile\' XML section (" . 
                "Error ".($_i+1)." of ".scalar(@resA).": $resA[$_i])\n";
    }
    return($str, ());
  }
  return($res, %fdata);
}

#####

sub _find_hash_key {
  my ($name, %hash) = @_;

  my @keys = keys %hash;

  my @list = grep(m%^${name}$%i, @keys);
  return("key ($name) does not seem to be present", "")
    if (scalar @list == 0);
  return("key ($name) seems to be present multiple time (" . join(", ", @list) .")", "")
    if (scalar @list > 1);
  
  return("", $list[0]);
}

####################

sub _parse_sourcefile_section {
  my ($self, $name, $str, $isgtf) = @_;

  my %res;
  
  #####
  # First, get the inline attributes from the 'sourcefile' inline attribute itself
  my ($text, %iattr) = MtXML::get_inline_xml_attributes($name, $str);
  return($text, ()) if (! MMisc::is_blank($text));

  # We should only have a \'filename\'
  my @keys = keys %iattr;
  return("Found multiple keys in the \'sourcefile\' inlined attributes", ())
    if (scalar @keys > 1);
  ($text, my $found) = &_find_hash_key("filename", %iattr);
  return($text, ()) if (! MMisc::is_blank($text));

  my $filename = $iattr{$found};

  #####
  # We can now remove the \'sourcefile\' header and trailer tags
  return("WEIRD: could not remove the \'$name\' header and trailer tags", ())
    if (! MtXML::remove_xml_tags($name, \$str));

  #####
  # Get the 'file' section
  my $sec = MtXML::get_named_xml_section("file", \$str, $default_error_value);
  return("No \'file\' section found in the \'sourcefile\'", ())
    if ($sec eq $default_error_value);
  ($text, my %fattr) = $self->_parse_file_section($sec, "file", $isgtf);
  return($text, ()) if (! MMisc::is_blank($text));
  
  # Complete %fattr and start filling %res
  $fattr{"filename"} = $filename;
  %{$res{"file"}} = %fattr;

  ##########
  # Process all that is left in the string (should only be objects)
  $str = MMisc::clean_begend_spaces($str);
  
  my @error_list = ();
  while (! MMisc::is_blank($str)) {
    my $sec = MtXML::get_named_xml_section("object", \$str, $default_error_value);
    if ($sec eq $default_error_value) {
       push (@error_list, ("No \'object\' section left in the \'sourcefile\'"));
    } else {
        ($text, my $object_type, my $object_id, my $object_framespan, my %oattr)
          = $self->_parse_object_section($sec, $isgtf);
        if (! MMisc::is_blank($text)){
            if (! grep(/^warning/i, $text)) {
                push (@error_list, $text);
            }
            else {
                my $filename = $self->get_file();
                print "$filename: $text\n";
            }
        } else {

            ##### Sanity
    
            # Check that the object name is an authorized object name
            if (! grep(/^$object_type$/, @ok_objects)){
                push (@error_list, "Found unknown object type ($object_type) in \'object\'");
            } else {
               # Check that the object type/id key does not already exist
               # A fix put in to handle if there are multiple object sections have the same ID.
               # We report an error only if the framespans of object sections overlap with each other. If they don't
               # we append the section to the existing memory representation.
               if (exists $res{$object_type}{$object_id}){
                  my $obj_fs = ViperFramespan->new();
    	          $obj_fs->set_value($res{$object_type}{$object_id}{"framespan"});

                  my $in_fs = ViperFramespan->new();
    	          $in_fs->set_value($object_framespan);

                  my $ok = $in_fs->is_within($obj_fs);
                  return("ViperFramespan error (" . $in_fs->get_errormsg() . ")", ()) if ($in_fs->error());
                  if ($ok) { push (@error_list, "Only one unique (object type, id) key authorized ($object_type, $object_id)"); }
                  else {
                    my $new_fs = $obj_fs->add_fs_to_value($in_fs->get_value());
                    $res{$object_type}{$object_id}{"framespan"} = $obj_fs->get_value();

                    my @tmpa = keys %oattr;
                    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
                      my $key = $tmpa[$ki];
                        if (exists $res{$object_type}{$object_id}{$key}) {
                            my %inhash = %{$oattr{$key}};
                            map { $res{$object_type}{$object_id}{$key}{$_} = $inhash{$_} } keys %inhash;
                        }
                        else {
                            $res{$object_type}{$object_id}{$key} = $oattr{$key};
                        }
                    }
                  }
               } else {
                  ##### Add to %res directly
                  %{$res{$object_type}{$object_id}} = %oattr;
                  $res{$object_type}{$object_id}{"framespan"} = $object_framespan;
               }
            }
        }
    }        

    # Prepare string for the next run
    $str = MMisc::clean_begend_spaces($str);
  }

  # Check if the required objects are present
  push (@error_list, "Missing 'I-FRAMES' section in file")
      if (! defined $res{'I-FRAMES'});
  push (@error_list, "Missing 'FRAME' section in file")
      if (! defined $res{'FRAME'});
  push (@error_list, "More than one 'FRAME' section present in file")
      if (defined $res{'FRAME'} && (scalar keys %{$res{'FRAME'}} > 1));

  if (@error_list > 0){
     return(join("\n",@error_list), ());
  }
  
  ##### Final Sanity Checks

  if (($check_ids_start_at_zero) || ($check_ids_are_consecutive)) {
    for (my $obi = 0; $obi < scalar @ok_objects; $obi++) {
      my $object = $ok_objects[$obi];
      next if (! exists $res{$object});
      my @list = sort _numerically keys %{$res{$object}};
      
      if ($check_ids_start_at_zero) {
	return("Event ID list must always start at 0 (for object \'$object\', start at " . $list[0] . ")", ())
	  if ($list[0] != 0);
      }
      
      if ($check_ids_are_consecutive) {
	return("Event ID list must always start at 0 and have no gap (for object \'$object\', seen "
	       . scalar @list . " elements (0 -> " . $list[-1] . ")", ())
	  if (scalar @list != $list[-1] + 1); 
      }
    }
  }

  return("", %res);
}

####################

sub _make_array_of_unique_values {
  my %tmp;
  for (my $ki = 0; $ki < scalar @_; $ki++) {
    my $key = $_[$ki];
    $tmp{$key}++;
  }

  return(keys %tmp);
}

#####

sub _parse_file_section {
  my ($self, $str, $wtag, $isgtf) = @_;

  my %file_hash;

  my ($text, %attr) = MtXML::get_inline_xml_attributes($wtag, $str);
  return($text, ()) if (! MMisc::is_blank($text));

  my $framespan_max = $framespan_max_default;

  my @expected = @array_file_inline_attributes;
  my @tmpa = keys %attr;
  my ($in, $out) = MMisc::compare_arrays(\@expected, \@tmpa);
  return("Could not find all the expected inline \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected inline \'$wtag\' attributes (" . join(", ", @$out) . ")", ())
    if (scalar @$out > 0);

  # Get the file id
  return("WEIRD: Could not find the \'id\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[0]});
  my $fid = $attr{$expected[0]};
  return("Only one authorized $wtag id [0, here $fid]", ())
    if ($fid != 0);
  $file_hash{"file_id"} = $fid;

  # Remove the \'file\' header and trailer tags
  return("WEIRD: could not remove the \'$wtag\' header and trailer tags", ())
    if (! MtXML::remove_xml_tags($wtag, \$str));

  #####
  # Process each "attribute" left now
  ($text, %attr) = $self->_parse_attributes(\$str, $wtag, $isgtf);
  return("While parsing the \'$wtag\' \'attribute\'s : $text", ())
    if (! MMisc::is_blank($text));

  # Confirm they are the ones we want
  my %expected_hash = %hash_file_attributes_types;
  @expected = keys %expected_hash;
  my @tmpa = keys %attr;
  ($in, $out) = MMisc::compare_arrays(\@expected, \@tmpa);
  return("Could not find all the expected \'$wtag\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'$wtag\' attributes (" . join(", ", @$out) . ")", ())
    if (scalar @$out > 0);

  # Check they are of valid type & reformat them for the output file hash
  for (my $ki = 0; $ki < scalar @expected; $ki++) {
    my $key = $expected[$ki];
    $file_hash{uc($key)} = undef;
    my $val = $expected_hash{$key};
    next if (! defined $val);
    my @comp = keys %{$attr{$key}};
    next if (scalar @comp == 0);
    my @expected2;
    push @expected2, $val;
    ($in, $out) = MMisc::compare_arrays(\@expected2, \@comp);
    return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type (" . join(", ", @$out) . ")", ())
      if (scalar @$out > 0);

    return("WEIRD: Could not find the value associated with the \'$key\' \'$wtag\' attribute", ())
      if (! exists $attr{$key}{$val}{$framespan_max});
    $file_hash{uc($key)} = ${$attr{$key}{$val}{$framespan_max}}[0];
  }

  # Set the "framespan_max" from the NUMFRAMES entry
  my $key = "NUMFRAMES";
  return("No \'$key\' \'$wtag\' attribute defined", ())
    if (! defined $file_hash{uc($key)});
  my $val = $file_hash{uc($key)};
  return("Invalid value for \'$key\' \'$wtag\' attribute", ())
    if ($val < 0);

  $framespan_max = "1:$val";
  return("Problem setting the framespan_max object value ($framespan_max)")
    if (! $self->_set_framespan_max_value($framespan_max));

  return("", %file_hash);
}

##########

sub _parse_object_section {
  my ($self, $str, $isgtf) = @_;

  # print "$str\n";
  my $wtag = "object";

  my $object_name;
  my $object_id;
  my $object_framespan;
  my %object_hash;

  my $tif = $self->get_frame_tolerance();

  my ($text, %attr) = MtXML::get_inline_xml_attributes($wtag, $str);
  return($text, ()) if (! MMisc::is_blank($text));

  my $framespan_max = $self->_get_framespan_max_value();
  return("Problem obtaining the \'framespan_max\' value", ()) if ($self->error());
  my $fs_framespan_max = $self->_get_framespan_max_object();
  return("Problem obtaining the \'framespan_max\' object", ()) if ($self->error());

  my @expected = @array_objects_inline_attributes;
  my @tmpa = keys %attr;
  my ($in, $out) = MMisc::compare_arrays(\@expected, \@tmpa);
  return("WARNING: Could not find all the expected inline \'$wtag\' attributes. Skipping \'$wtag\' section", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected inline \'$wtag\' attributes (" . join(", ", @$out) . ")", ())
    if (scalar @$out > 0);

  # Get the object name
  return("WARNING: Could not obtain the \'name\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[0]});
  $object_name = $attr{$expected[0]};

  # Get the object id
  return("WARNING: Could not obtain the \'id\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[1]});
  $object_id = $attr{$expected[1]};

  # Get the object framespan
  return("WARNING: Could not obtain the \'framespan\' inline \'$wtag\' attribute", ())
    if (! exists $attr{$expected[2]});
  my $tmp = $attr{$expected[2]};

  my $fs_tmp = ViperFramespan->new();
  return("ViperFramespan ($tmp) error (" . $fs_tmp->get_errormsg() . ")", ())
    if (! $fs_tmp->set_value($tmp));
  my $ok = $fs_tmp->is_within($fs_framespan_max, $tif);
  return("ViperFramespan ($tmp) error (" . $fs_tmp->get_errormsg() . ")", ()) if ($fs_tmp->error());
  return("ViperFramespan ($tmp) is not within range (" . $fs_framespan_max->get_original_value() . ")", ()) if (! $ok);
  my $pc = $fs_tmp->count_pairs_in_original_value();
  return("ViperFramespan ($tmp) error (" . $fs_tmp->get_errormsg() . ")", ()) if ($fs_tmp->error());
  return("ViperFramespan ($tmp) contains more than $max_pair_per_fs range pair(s)") if (($max_pair_per_fs) && ($pc > $max_pair_per_fs));
  $object_framespan = $fs_tmp->get_value();

  # Remove the \'object\' header and trailer tags
  return("WEIRD: could not remove the \'$wtag\' header and trailer tags", ())
    if (! MtXML::remove_xml_tags($wtag, \$str));

  #####
  # Process each "attribute" left now
  ($text, %attr) = $self->_parse_attributes(\$str, uc($object_name), $isgtf, $object_framespan);
  return("While parsing the \'$wtag\' (ID: $object_id) \'attribute\'s : $text", ())
    if (! MMisc::is_blank($text));

  # Confirm they are the ones we want
  MMisc::error_quit("Internal -- Can not find requested key: $object_name / $isgtf")
      if (! MMisc::safe_exists(\%hash_objects_attributes_types, 
                               uc($object_name), $isgtf));
  my %expected_hash = %{$hash_objects_attributes_types{uc($object_name)}{$isgtf}};
  @expected = keys %expected_hash;
  my @tmpa = keys %attr;
  ($in, $out) = MMisc::compare_arrays(\@expected, \@tmpa);
  if ((scalar @$in != scalar @expected) && $isgtf) {
     # If you don't find all the attributes, check if all the required ones are present.
     my $domain = $self->get_domain();
     my @tmpa = &get_values_from_array_of_hashes("name", @{$list_objects_attributes{$domain}{uc($object_name)}});
     for (my $inc = 0; $inc < scalar @tmpa; $inc++) {
       my $attr_name = $tmpa[$inc];
        return("Could not find all the expected \'$wtag\' attributes", ())
           if (! grep(m%^$attr_name$%i, @$in));
     }
  }

  return("Found some unexpected \'$wtag\' attributes (" . join(", ", @$out) . ")", ())
    if (scalar @$out > 0);

  my @det_sub = @not_gtf_required_objects_attributes;

  # Check they are of valid type & reformat them for the output object hash
  for (my $ki = 0; $ki < scalar @expected; $ki++) {
    my $key = $expected[$ki];
    my $val = $expected_hash{$key};
    next if (! defined $val);
    my @comp = keys %{$attr{$key}};
    if (scalar @comp == 0) {
      next if ($isgtf);
      return("Expected \'$wtag\' required attribute ($key) does not have a value", ())
	if (grep(m%^$key$%, @det_sub));
      next;
    } else {
      # GTF must not have the Detection attributes set
      return("\'$wtag\' attribute ($key) should not have a value for GTF", ())
	if (($isgtf) && (grep(m%^$key$%, @det_sub)));
    }
    my @expected2;
    push @expected2, $val;
    ($in, $out) = MMisc::compare_arrays(\@expected2, \@comp);
    return("Could not confirm all the expected \'$wtag\' attributes", ())
      if (scalar @$in != scalar @expected2);
    return("Found some unexpected \'$wtag\' attributes type (" . join(", ", @$out) . ")", ())
      if (scalar @$out > 0);

    my @tmpa = keys %{$attr{$key}{$val}};
    for (my $fi = 0; $fi < scalar @tmpa; $fi++) {
      my $fs = $tmpa[$fi];
      @{$object_hash{uc($key)}{$fs}} = @{$attr{$key}{$val}{$fs}};
    }
  }

  return("", uc($object_name), $object_id, $object_framespan, %object_hash);
}

####################

sub _data_process_array_core {
  my ($name, $rattr, @expected) = @_;

  my @tmpa = keys %$rattr;
  my ($in, $out) = MMisc::compare_arrays(\@expected, \@tmpa);
  return("Could not find all the expected \'data\:$name\' attributes", ())
    if (scalar @$in != scalar @expected);
  return("Found some unexpected \'data\:$name\' attributes (" . join(", ", @$out) . ")", ())
    if (scalar @$out > 0);

  my @res;
  for (my $ki = 0; $ki < scalar @expected; $ki++) {
    my $key = $expected[$ki];
    push @res, $$rattr{$key};
  }

  return("", @res);
}

#####

sub _data_process_type {
  my ($type, %attr) = @_;

  return("Found some unknown \'data\:\' type ($type)", ())
    if (! exists $hasharray_inline_attributes{$type});

  my @expected = @{$hasharray_inline_attributes{$type}};

  return(&_data_process_array_core($type, \%attr, @expected));
}

#####

sub _extract_data {
  my ($self, $str, $fspan, $allow_nofspan, $type, $obj_name, $isgtf) = @_;

  my %attr;
  my (@afspan, @attr_beg_frs, @attr_end_frs);
  my $tif = $self->get_frame_tolerance();

  my $fs_fspan = ViperFramespan->new();
  if (! $allow_nofspan) {
    return("ViperFramespan ($fspan) error (" . $fs_fspan->get_errormsg() . ")", ())
      if (! $fs_fspan->set_value($fspan));
  }

  while (! MMisc::is_blank($str)) {
    my $name = MtXML::get_next_xml_name(\$str, $default_error_value);
    return("Problem obtaining a valid XML name, aborting", $str)
      if ($name eq $default_error_value);
    return("\'data\' extraction process does not seem to have found one, aborting", $str)
      if ($name !~ m%^data\:%i);
    my $section = MtXML::get_named_xml_section($name, \$str, $default_error_value);
    return("Problem obtaining the \'data\:\' XML section, aborting", "")
      if ($name eq $default_error_value);

    # All within a data: entry is inlined, so get the inlined content
    my ($text, %iattr) = MtXML::get_inline_xml_attributes($name, $section);
    return($text, ()) if (! MMisc::is_blank($text));

    # From here we work per 'data:' type
    $name =~ s%^data\:%%;

    # Check the framespan (if any)
    my $lfspan;
    my $key = "framespan";
    if (exists $iattr{$key}) {
      $lfspan = $iattr{$key};

      my $fs_lfspan = ViperFramespan->new();
      return("ViperFramespan ($lfspan) error (" . $fs_lfspan->get_errormsg() . ")", ())
	if (! $fs_lfspan->set_value($lfspan));
      my $iw = $fs_lfspan->is_within($fs_fspan, $tif);
      return("ViperFramespan ($lfspan) error (" . $fs_lfspan->get_errormsg() . ")", ()) if ($fs_lfspan->error());
      return("ViperFramespan ($lfspan) is not within range (" . $fs_fspan->get_original_value() . ")", ()) if (! $iw);
      my $pc = $fs_lfspan->count_pairs_in_original_value();
      return("ViperFramespan ($lfspan) error (" . $fs_lfspan->get_errormsg() . ")", ()) if ($fs_lfspan->error());
      return("ViperFramespan ($lfspan) contains more than $max_pair_per_fs range pair(s)") if (($max_pair_per_fs) && ($pc > $max_pair_per_fs));

      if (scalar @afspan > 0) {
        my ($ov, $rovfs) = $fs_lfspan->check_if_overlap_s(\@afspan);
        return("ViperFramespan ($lfspan) error (" . $fs_lfspan->get_errormsg() . ")", ()) if ($fs_lfspan->error());
        return("ViperFramespan ($lfspan) overlap another framespan (" . $$rovfs->get_original_value() . ") within the same object attribute", ()) if ($ov);
      }
      push @afspan, $fs_lfspan;

      delete $iattr{$key};
      $lfspan = $fs_lfspan->get_value();

      # Store the begin and end frames of the attribute to estimate the total framespan of the attribute
      my ($a_beg_fr, $a_end_fr) = $fs_lfspan->get_beg_end_fs();	
      push @attr_beg_frs, $a_beg_fr;
      push @attr_end_frs, $a_end_fr;
    } elsif ($allow_nofspan) {
      # This is an element for which we know at this point we do not have to worry about its framespan status
      # (most likely not processing any "object" but a "file"), make it valid for the entire provided framespan
      $lfspan = $fspan;
    } else {
      # if none was specified, check if the type is dynamic
      return("Can not confirm the dynamic status of found \'data\:\' type ($name)", ())
	if (! exists $hash_objects_attributes_types_dynamic{$obj_name}{$isgtf}->{$type});

      # If it is, a framespan should have been provided
      return("No framespan provided for dynamic \'data\:\' type ($name)", ())
	if ($hash_objects_attributes_types_dynamic{$obj_name}{$isgtf}->{$type} == 1);

      # otherwise, it means that it is valid for the entire provided framespan
      $lfspan = $fspan;
    }

    # Process the leftover elements
    ($text, @{$attr{$name}{$lfspan}}) = &_data_process_type($name, %iattr);
    return($text, ()) if (! MMisc::is_blank($text));
  }

  # was:
#  if (scalar @attr_beg_frs > 0) {

  # modified 2009-09-08 after receiving Vasant's validation code:CONTENT 
  # and LARGEBOX _only_ are authorized to have non fully overlapping framespans
  if ( (uc($type) ne "CONTENT") && (uc($type) ne "LARGEBOX") 
       && (scalar @attr_beg_frs > 0) ) {

    @attr_beg_frs = MMisc::reorder_array_numerically(\@attr_beg_frs);
    @attr_end_frs = MMisc::reorder_array_numerically(\@attr_end_frs);
    my $attr_fr_span = sprintf("%d:%d", $attr_beg_frs[0], $attr_end_frs[-1]);

    my $fs_attr_fspan = ViperFramespan->new();
    return("ViperFramespan ($attr_fr_span) error (" . $fs_attr_fspan->get_errormsg() . ")", ())
      if (! $fs_attr_fspan->set_value($attr_fr_span));
    my $iw = $fs_fspan->is_within($fs_attr_fspan, $tif);
    return("ViperFramespan (" . $fs_fspan->get_value() . ") error (" . $fs_fspan->get_errormsg() . ")", ()) if ($fs_fspan->error());
    return("ViperFramespan (" . $fs_attr_fspan->get_value() . ") is incomplete for the range (" . $fs_fspan->get_original_value() . ")", ()) if (! $iw);
  }

  return("", %attr);
}

#####

sub _parse_attributes {
  my ($self, $rstr, $obj_name, $isgtf, $fspan) = @_;

  my %attrs;
  my $allow_nofspan = 0;
  if (MMisc::is_blank($fspan)) {
    if (! $self->_is_framespan_max_set()) {
      $fspan = $framespan_max_default;
    } else {
      return("WEIRD: At this point the framespan range should be defined", ());
    }
    $allow_nofspan = 1;
  }
  
  # We process all the "attributes"
  while (! MMisc::is_blank($$rstr)) {
    my $sec = MtXML::get_named_xml_section("attribute", $rstr, $default_error_value);
    return("Could not find an \'attribute\'", ()) if ($sec eq $default_error_value);

    # Get its name
    my ($text, %iattr) = MtXML::get_inline_xml_attributes("attribute", $sec);
    return($text, ()) if (! MMisc::is_blank($text));

    return("Found more than one inline attribute for \'attribute\'", ())
      if (scalar %iattr != 1);
    return("Could not find the \'name\' of the \'attribute\'", ())
      if (! exists $iattr{"name"});

    my $name = $iattr{"name"};

    # Now get its content
    return("WEIRD: could not remove the \'attribute\' header and trailer tags", ())
      if (! MtXML::remove_xml_tags("attribute", \$sec));

    # Process the content
    $sec = MMisc::clean_begend_spaces($sec);
    
    if (MMisc::is_blank($sec)) {
      $attrs{uc($name)} = undef;
    } else {
      ($text, my %tmp) = $self->_extract_data($sec, $fspan, $allow_nofspan, $name, $obj_name, $isgtf);
      return("Error while processing the \'data\:\' content of the \'$name\' \'attribute\' ($text)", ())
	if (! MMisc::is_blank($text));
      %{$attrs{uc($name)}} = %tmp;
    }
    
  } # while

  return("", %attrs);
}

########################################

sub _numerically {
  return($a <=> $b);
}

##########

sub _framespan_sort {
  return($a->sort_cmp($b));
}

########################################

sub _wbi { # writeback indent
  my $indent = $_[0];

  my $spacer = "  ";
  my $txt = "";
  
  for (my $i = 0; $i < $indent; $i++) {
    $txt .= $spacer;
  }

  return($txt);
}     

#####

sub _wb_print { # writeback print
  my ($indent, @content) = @_;

  my $txt = "";

  $txt .= &_wbi($indent);
  $txt .= join("", @content);

  return($txt);
}

#####

sub _writeback_file {
  my ($indent, %file_hash) = @_;

  my $txt = "";
  $txt .= &_wb_print($indent++, "<file id=\"" . $file_hash{'file_id'} . "\" name=\"Information\">\n");

  my @tmpa = sort keys %hash_file_attributes_types;
  for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
    my $key = $tmpa[$ki];
    $txt .= &_wb_print($indent, "<attribute name=\"$key\"");
    if (defined $file_hash{$key}) {
      $txt .= ">\n";
      $txt .= &_wb_print(++$indent, "<data:" . $hash_file_attributes_types{$key} . " value=\"" . $file_hash{$key} . "\"/>\n");
      $txt .= &_wb_print(--$indent, "</attribute>\n");
    } else {
      $txt .= "/>\n";
    }
  }

  $txt .= &_wb_print(--$indent, "</file>\n");

  return($txt);
}

#####

sub _writeback_object {
  my ($domain, $isgtf, $indent, $object, $id, %object_hash) = @_;

  my $txt = "";
  $txt .= &_wb_print($indent++, "<object name=\"$object\" id=\"$id\" framespan=\"" . $object_hash{'framespan'} . "\">\n");

  # comment (optional)
  $txt .= &_wb_print($indent, "<!-- " . $object_hash{"comment"} . " -->\n")
    if (exists $object_hash{"comment"});

  # attributes
  my @tmpa = sort keys %{$hash_objects_attributes_types{$object}{$isgtf}};
  for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
    my $key = $tmpa[$ki];
    # If an optional attribute is not defined, don't write to file.
    next if ((! defined $object_hash{$key}) && grep(m%^$key$%, &get_values_from_array_of_hashes("name", @{$opt_list_objects_attributes{$domain}{$object}})));
    $txt .= &_wb_print($indent, "<attribute name=\"$key\"");
    if (defined $object_hash{$key}) {
      $txt .= ">\n";

      $indent++;
      my @afs;
      my @tmpb = keys %{$object_hash{$key}};
      for (my $fi = 0; $fi < scalar @tmpb; $fi++) {
        my $fs = $tmpb[$fi];
	my $fs_tmp = ViperFramespan->new();
	MMisc::error_quit("[CLEARDTViperFile] Internal Error: WEIRD: In \'_writeback_object\' (" . $fs_tmp->get_errormsg() .")")
            if (! $fs_tmp->set_value($fs));
	push @afs, $fs_tmp;
      }
      my @tafs = sort _framespan_sort @afs;
      for (my $tafsi = 0; $tafsi < scalar @tafs; $tafsi++) {
        my $fs_fs = $tafs[$tafsi];
	my $fs = $fs_fs->get_value();
	$txt .= &_wb_print
	  ($indent,
	   "<data:" . $hash_objects_attributes_types{$object}{$isgtf}->{$key},
	   ($hash_objects_attributes_types_dynamic{$object}{$isgtf}->{$key}) ? " framespan=\"$fs\"" : "",
	   " ");
        
	my @subtxta;
	my @name_a = @{$hasharray_inline_attributes{$hash_objects_attributes_types{$object}{$isgtf}->{$key}}};
	my @value_a = @{$object_hash{$key}{$fs}};
        for (my $ai = 0; $ai < scalar @name_a; $ai++) {
	  my $name = $name_a[$ai];
	  my $value = $value_a[$ai];
	  push @subtxta, "$name\=\"$value\"";
	}
	$txt .= join(" ", @subtxta);

	$txt .= "/>\n";
      }

      $txt .= &_wb_print(--$indent, "</attribute>\n");
    } else {
      $txt .= "/>\n";
    }
  }
  

  $txt .= &_wb_print(--$indent, "</object>\n");

  return($txt);
}

##########

sub _writeback2xml {
  my ($comment, $domain, $isgtf, $rlhash, @asked_objects) = @_;

  my $txt = "";
  my $indent = 0;

  my %lhash = %{$rlhash};

  # Common header
  $txt .= &_wb_print($indent, "<?xml version\=\"1.0\" encoding=\"UTF-8\"?>\n");
  $txt .= &_wb_print($indent, "<viper xmlns=\"http://lamp.cfar.umd.edu/viper\#\" xmlns:data=\"http://lamp.cfar.umd.edu/viperdata\#\">\n");
  $txt .= &_wb_print(++$indent, "<config>\n");
  $txt .= &_wb_print(++$indent, "<descriptor name=\"Information\" type=\"FILE\">\n");
  $txt .= &_wb_print(++$indent, "<attribute dynamic=\"false\" name=\"SOURCETYPE\" type=\"http://lamp.cfar.umd.edu/viperdata#lvalue\">\n");
  $txt .= &_wb_print(++$indent, "<data:lvalue-possibles>\n");
  $txt .= &_wb_print(++$indent, "<data:lvalue-enum value=\"SEQUENCE\"/>\n");
  $txt .= &_wb_print($indent, "<data:lvalue-enum value=\"FRAMES\"/>\n");
  $txt .= &_wb_print(--$indent, "</data:lvalue-possibles>\n");
  $txt .= &_wb_print(--$indent, "</attribute>\n");
  $txt .= &_wb_print($indent, "<attribute dynamic=\"false\" name=\"NUMFRAMES\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print($indent, "<attribute dynamic=\"false\" name=\"FRAMERATE\" type=\"http://lamp.cfar.umd.edu/viperdata#fvalue\"/>\n");
  $txt .= &_wb_print($indent, "<attribute dynamic=\"false\" name=\"H-FRAME-SIZE\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print($indent, "<attribute dynamic=\"false\" name=\"V-FRAME-SIZE\" type=\"http://lamp.cfar.umd.edu/viperdata#dvalue\"/>\n");
  $txt .= &_wb_print(--$indent, "</descriptor>\n");

  # Write all objects
  for (my $oi = 0; $oi < scalar @asked_objects; $oi++) {
    my $object = $asked_objects[$oi];
    next if (! exists $lhash{$object});
    $txt .= &_wb_print($indent++, "<descriptor name=\"$object\" type=\"OBJECT\">\n");
    my @tmpa = sort keys %{$hash_objects_attributes_types{$object}{$isgtf}};
    for (my $ki = 0; $ki < scalar @tmpa; $ki++) {
      my $key = $tmpa[$ki];
      $txt .= &_wb_print
	($indent,
	 "<attribute dynamic=\"",
	 ($hash_objects_attributes_types_dynamic{$object}{$isgtf}->{$key}) ? "true" : "false",
	 "\" name=\"$key\" type=\"http://lamp.cfar.umd.edu/viperdata#",
	 $hash_objects_attributes_types{$object}{$isgtf}->{$key}, 
	 "\"/>\n");
    }
    $txt .= &_wb_print(--$indent, "</descriptor>\n");
  }

  # End 'config', begin 'data'
  $txt .= &_wb_print(--$indent, "</config>\n");
  $txt .= &_wb_print($indent++, "<data>\n");

  if (scalar %lhash > 0) { # Are we just writing a spec XML file ?
    $txt .= &_wb_print($indent++, "<sourcefile filename=\"" . $lhash{'file'}{'filename'} . "\">\n");

    # comment (optional)
    $txt .= &_wb_print($indent, "<!-- " . $comment . " -->\n")
      if (! MMisc::is_blank($comment));

    # file
    $txt .= &_writeback_file($indent, %{$lhash{'file'}});

    # Objects
    for (my $oi = 0; $oi < scalar @asked_objects; $oi++) {
      my $object = $asked_objects[$oi];
      if (exists $lhash{$object}) {
	my @ids = keys %{$lhash{$object}};
        my @tids = sort _numerically @ids;
        for (my $idi = 0; $idi < scalar @tids; $idi++) {
          my $id = $tids[$idi];
	  $txt .= &_writeback_object($domain, $isgtf, $indent, $object, $id, %{$lhash{$object}{$id}});
	}
      }
    }

    # End the sourcefile
    $txt .= &_wb_print(--$indent, "</sourcefile>\n");
  }

  # end data and viper
  $txt .= &_wb_print(--$indent, "</data>\n");
  $txt .= &_wb_print(--$indent, "</viper>\n");

  return($txt);
}

########################################

sub _clone_fhash_selected_objects {
  my ($rin_hash, @asked_objects) = @_;

  my %in_hash = %{$rin_hash};
  my %out_hash;

  %{$out_hash{"file"}} = %{$in_hash{"file"}};

  for (my $oi = 0; $oi < scalar @asked_objects; $oi++) {
    my $object = $asked_objects[$oi];
    if (exists $in_hash{$object}) {
      %{$out_hash{$object}} = %{$in_hash{$object}};
    }
  }

  return(%out_hash);
}

########################################

sub reformat_ds {
  my ($self, $eval_sequence, $isgtf, @tmpa) = @_;

  my @limitto_objects = MMisc::uppercase_array_values(\@tmpa);

  return(-1) if ($self->error());

  if (ref($eval_sequence) ne "CLEARSequence") {
    $self->_set_errormsg("Can only reformat to object type 'CLEARSequence'");
    return(0);
  }

  if (scalar @limitto_objects == 0) {
    @limitto_objects = @ok_objects;
  } else {
    @limitto_objects = $self->validate_objects_list(@limitto_objects);
    return(0) if ($self->error());
  }

  if (! $self->is_validated()) {
    $self->_set_errormsg("Can only reformat the data structure for a validated file");
    return(0);
  }
  else { $eval_sequence->set_as_validated(); }

  $eval_sequence->set_as_gtf() if ($isgtf);

  $self->_set_file_details($eval_sequence, $isgtf);
  if ($self->error()) {
    $self->_set_errormsg("Failed to set file details in 'reformat_ds'");
    return(0);
  }

  my $ovlp_fs = $self->_set_frame_instances($eval_sequence, $isgtf);
  if ($self->error()) {
    $self->_set_errormsg("Failed to set frame instances in 'reformat_ds'");
    return(0);
  }

  $self->_set_object_instances($eval_sequence, $ovlp_fs, $isgtf, @limitto_objects);
  if ($self->error()) {
    $self->_set_errormsg("Failed to set object instances in 'reformat_ds'");
    return(0);
  }
  
  return(1);
}

##########

sub _set_file_details {
  my ($self, $eval_sequence, $isgtf) = @_;

  return(-1) if ($self->error());

  my %tmp = $self->_get_fhash();
  my %file_hash = %{$tmp{'file'}};

  if (! defined $file_hash{'filename'}) {
    $self->_set_errormsg("Missing video source 'filename' in 'file' section");
    return(0);
  }
  $eval_sequence->setSourceFileName($file_hash{'filename'});

  if ($isgtf && (! defined $file_hash{'NUMFRAMES'})) {
    $self->_set_errormsg("Missing total 'NUMFRAMES' in 'file' section");
    return(0);
  }

  if (defined $file_hash{'NUMFRAMES'}) {
    $eval_sequence->setVideoFrSpan(1, $file_hash{'NUMFRAMES'});
  }

  my @frameDims;
  if ((defined $file_hash{'H-FRAME-SIZE'}) && (defined $file_hash{'V-FRAME-SIZE'})) { @frameDims = ($file_hash{'H-FRAME-SIZE'}, $file_hash{'V-FRAME-SIZE'}); }
  else { @frameDims = (720, 480); }
  $eval_sequence->setFrameDims(\@frameDims);

}

##########

sub _set_frame_instances {
  my ($self, $eval_sequence, $isgtf) = @_;

  return(-1) if ($self->error());

  my %tmp = $self->_get_fhash();

  my ( %iframes_hash, %frame_hash );

  if (! defined $tmp{'FRAME'}) {
    $self->_set_errormsg("Missing 'FRAME' information in Viper File");
    return(0);
  }

  if (! defined $tmp{'I-FRAMES'}) {
    $self->_set_errormsg("Missing 'I-FRAMES' information in Viper File");
    return(0);
  }

  my $fr_fs = ViperFramespan->new();
  %frame_hash = %{$tmp{'FRAME'}};
  my @fkey = keys %frame_hash;
  if (! $fr_fs->set_value($frame_hash{$fkey[0]}{'framespan'})) {
    $self->_set_errormsg("FRAME: ViperFramespan ($frame_hash{$fkey[0]}{'framespan'}) error (" . $fr_fs->get_errormsg() . ")");
    return(0);
  }

  my $if_fs = ViperFramespan->new();
  %iframes_hash = %{$tmp{'I-FRAMES'}};

  my @ikey = keys %iframes_hash;
  if (! $if_fs->set_value($iframes_hash{$ikey[0]}{'framespan'})) {
    $self->_set_errormsg("I-FRAMES: ViperFramespan ($iframes_hash{$ikey[0]}{'framespan'}) error (" . $if_fs->get_errormsg() . ")");
    return(0);
  }

  my $ovlp_fs = $if_fs->get_overlap($fr_fs);
  if(! defined $ovlp_fs) {
    $self->_set_errormsg("There was no overlap between the 'FRAME' object framespan and the 'I-FRAMES'");
    return(0);
  }

  my @tmpa = $ovlp_fs->list_frames();
  my @ovlp_frames = MMisc::reorder_array_numerically(\@tmpa);
  $eval_sequence->setSeqFrSpan($ovlp_frames[0], $ovlp_frames[-1]);

  for (my $fni = 0; $fni < scalar @ovlp_frames; $fni++) {
    my $frameNum = $ovlp_frames[$fni];
    my $frame = CLEARFrame->new($frameNum);
    if (ref($frame) ne "CLEARFrame") {
      $self->_set_errormsg("Failed 'CLEARFrame' instance creation ($frame)");
      return(0);
    }
    $eval_sequence->addToFrameList($frame);
    if ($eval_sequence->error()) {
      $self->_set_errormsg("Error adding framenum: $frameNum (" . $eval_sequence->get_errormsg() . ")");
      return(0);
    }
  }

  if ($isgtf) {
    my $gtFrameList = $eval_sequence->getFrameList();
    my %frame_attr = %{$frame_hash{$fkey[0]}};
    my @tmpa = keys %frame_attr;
    for (my $fi = 0; $fi < scalar @tmpa; $fi++) {
      my $fakey = $tmpa[$fi];
      next if ($fakey eq "framespan"); # We have already taken care of this
      my %attr = %{$frame_attr{$fakey}};
      my @tmpb = keys %attr;
      for (my $ai = 0; $ai < scalar @tmpb; $ai++) {
        my $attkey = $tmpb[$ai];
        if (! $fr_fs->set_value($attkey)) {
          $self->_set_errormsg("$fakey: ViperFramespan ($attkey) error (" . $fr_fs->get_errormsg() . ")");
          return(0);
        }

        my $attr_fs = $ovlp_fs->get_overlap($fr_fs);
        next if(! defined $attr_fs);

        my @attr_frames = $attr_fs->list_frames();
        my @att_value = @{$attr{$attkey}};
        for (my $ati = 0; $ati < scalar @attr_frames; $ati++) {
          my $attr_fr = $attr_frames[$ati];
          if ($att_value[0] ne $hash_objects_attributes_types_default{'FRAME'}{$isgtf}->{$fakey}) { $gtFrameList->{$attr_fr}->setDontCare(1); }
          elsif (! defined $gtFrameList->{$attr_fr}->getDontCare()) { $gtFrameList->{$attr_fr}->setDontCare(0); }
        }
      }
    }
    $eval_sequence->setFrameList($gtFrameList);
  }

  return($ovlp_fs);
}

##########

sub _set_object_instances {
  my ($self, $eval_sequence, $ovlp_fs, $isgtf, @asked_objects) = @_;
  
  return(-1) if ($self->error());
  if(ref($ovlp_fs) ne "ViperFramespan") {
    $self->_set_errormsg("The overlap framespan should be an instance of 'ViperFramespan'");
    return(-1);
  }

  my %tmp = $self->_get_fhash();
  my $domain = $self->get_domain();
  my $eval_obj = "";
  my @tmpa = keys %tmp;
  for (my $ti = 0; $ti < scalar @tmpa; $ti++) {
    my $tkey = $tmpa[$ti];
    next if (($tkey eq "file") || ($tkey eq "I-FRAMES") || ($tkey eq "FRAME")); # We have already taken care of this
    $eval_obj = $tkey;
    last;
  }

  $eval_sequence->setEvalObj($eval_obj);
  return(1) if ( (MMisc::is_blank($eval_obj)) || (! defined $tmp{$eval_obj}) ); # No evaluation object in file

  my $ob_fs = ViperFramespan->new();
  my %object_hash = %{$tmp{$eval_obj}};
  my @tmpa = keys %object_hash;
  my @okey = MMisc::reorder_array_numerically(\@tmpa);

  $eval_sequence->setSeqObjectIds(\@okey);
  if ($eval_sequence->error()) {
    $self->_set_errormsg("SEQUENCE: Error setting 'Sequence Object Ids' (" . $eval_sequence->get_errormsg() . ")");
    return(0);
  }

  my $frameList = $eval_sequence->getFrameList();
  for (my $oi = 0; $oi < scalar @okey; $oi++) {
    my $object_id = $okey[$oi];
    if (! $ob_fs->set_value($object_hash{$object_id}{'framespan'})) {
      $self->_set_errormsg("OBJECT: ViperFramespan ($object_hash{$object_id}{'framespan'}) error (" . $ob_fs->get_errormsg() . ")");
      return(0);
    }

    my $obj_fs = $ovlp_fs->get_overlap($ob_fs);
    next if(! defined $obj_fs);

    my @obj_frames = $obj_fs->list_frames();
    for (my $ofn = 0; $ofn < scalar @obj_frames; $ofn++) {
      my $objFrNum = $obj_frames[$ofn];
      my $object = CLEARObject->new($object_id);
      if(ref($object) ne "CLEARObject") {
        $self->_set_errormsg("Failed 'CLEARObject' instance creation ($object)");
        return(0);
      }

      $frameList->{$objFrNum}->addToObjectList($object);
      if ($frameList->{$objFrNum}->error()) {
        $self->_set_errormsg("Error adding object ID: $object_id to framenum: $objFrNum (" . $frameList->{$objFrNum}->get_errormsg() . ")");
        return(0);
      }
    }

    my ($obj_beg_fr, $obj_end_fr) = MMisc::min_max_r(\@obj_frames);

    my %obj_attr = %{$object_hash{$object_id}};

    # Push all location attributes of this object
    my @location_attrs;
    my @object_attrs = @{$list_objects_attributes{$domain}{$eval_obj}};
    for (my $inloop = 0; $inloop < scalar @object_attrs; $inloop++) {
        push @location_attrs, $object_attrs[$inloop]->{"name"}
            if (($object_attrs[$inloop]->{"type"} eq "obox") || ($object_attrs[$inloop]->{"type"} eq "bbox") || ($object_attrs[$inloop]->{"type"} eq "point"));
    }

    # Push the ones that are optional as well
    my @opt_object_attrs = @{$opt_list_objects_attributes{$domain}{$eval_obj}};
    for (my $inloop = 0; $inloop < scalar @opt_object_attrs; $inloop++) {
        push @location_attrs, $opt_object_attrs[$inloop]->{"name"}
            if (($opt_object_attrs[$inloop]->{"type"} eq "obox") || ($opt_object_attrs[$inloop]->{"type"} eq "bbox") || ($opt_object_attrs[$inloop]->{"type"} eq "point"));
    }

    my ( $checkFlag, $isDontCare ) = ( 0, 0 );
    my $fr_fs = ViperFramespan->new();
    for (my $inloop = 0; $inloop < scalar @location_attrs; $inloop++) {
        next if (! defined $obj_attr{$location_attrs[$inloop]});

        # The location attribute in index 0 is mandatory. If that is missing and a subsequent location attribute is
        # defined, we make this object as a Dont Care. E.g. Vehicle in UAV - if LOCATION attribute is missing and the
        # GROUPBOX attribute is defined, the region should be treated as a dont care.
        # Important to note that the above should be true in all framespans of the object. This will not work if the LOCATION
        # attribute is defined in certain framespans and the GROUPBOX attribute is defined in others for a given object.
        # However, this does not happen in VACE/CLEAR annotations. Still worth noting for any future extensions.

        $isDontCare = 1 if (($isgtf) && (! $checkFlag) && ($inloop > 0)) ;

        my %attr = %{$obj_attr{$location_attrs[$inloop]}};
        my @tmpb = keys %attr;
        for (my $ai = 0; $ai < scalar @tmpb; $ai++) {
          my $attkey = $tmpb[$ai];
          if (! $fr_fs->set_value($attkey)) {
            $self->_set_errormsg("$location_attrs[$inloop]: ViperFramespan ($attkey) error (" . $fr_fs->get_errormsg() . ")");
            return(0);
          }

          my $attr_fs = $obj_fs->get_overlap($fr_fs);
          next if(! defined $attr_fs);

          my @attr_frames = $attr_fs->list_frames();
          my @att_value = @{$attr{$attkey}};
          for (my $afi = 0; $afi < scalar @attr_frames; $afi++) {
            my $attr_fr = $attr_frames[$afi];
            # We have already validated. The attribute type should be correct. 
            my $objectList = $frameList->{$attr_fr}->getObjectList();
            my $loc = undef;
            if (scalar @att_value == 2) {
              $loc = CLEARPoint->new(@att_value);
              if (ref($loc) ne "CLEARPoint") {
                $self->_set_errormsg("Failed 'CLEARPoint' object instance creation ($loc)");
                return(0);
              }
              $objectList->{$object_id}->setPoint($loc);
              $checkFlag = 1; # To check if at least one location attribute is set
            }
            elsif (scalar @att_value == 4) {
              $loc = CLEAROBox->new(@att_value, 0); # BBox is just OBox with orientation as 0
              if (ref($loc) ne "CLEAROBox") {
                $self->_set_errormsg("Failed 'CLEAROBox' object instance creation ($loc)");
                return(0);
              }

              # If OBox is already defined, then compute a bigger box (used in Peron task in MRoom
              # where we have Head and Body location defined as seperate boxes).
              my $currOBox = $objectList->{$object_id}->getOBox();
              if (! defined $currOBox) { $objectList->{$object_id}->setOBox($loc); }
              else { 
                $currOBox->computeBigBox($loc);
                $objectList->{$object_id}->setOBox($currOBox);
              }
              $checkFlag = 1; # To check if at least one location attribute is set
            }
            elsif (scalar @att_value == 5) {
              $loc = CLEAROBox->new(@att_value);
              if (ref($loc) ne "CLEAROBox") {
                $self->_set_errormsg("Failed 'CLEAROBox' object instance creation ($loc)");
                return(0);
              }

              # If OBox is already defined, then compute a bigger box (used in Peron task in MRoom
              # where we have Head and Body location defined as seperate boxes).
              my $currOBox = $objectList->{$object_id}->getOBox();
              if (! defined $currOBox) { $objectList->{$object_id}->setOBox($loc); }
              else { 
                $currOBox->computeBigBox($loc);
                $objectList->{$object_id}->setOBox($currOBox);
              }
              $checkFlag = 1; # To check if at least one location attribute is set
            }
            else { # Sanity check for validation error
              $self->_set_errormsg("Unknown data type for '$location_attrs[$inloop]' attribute for 'OBJECT' (ID: $object_id)");
              return(0);
            }
            if (($isgtf) && (($loc->getX() < 0) || ($loc->getY() < 0) || $isDontCare)) { $objectList->{$object_id}->setDontCare(1); }
            $frameList->{$attr_fr}->setObjectList($objectList);
          }
        }
    }

    # Make sure at least one location attribute is set
    if (! $checkFlag) {
        $self->_set_errormsg("Missing required attribute ($location_attrs[0]) value");
        return(0);
    }

    if ($isgtf) {
      my @tmpa = keys %obj_attr;
      for (my $fi = 0; $fi < scalar @tmpa; $fi++) {
        my $fakey = $tmpa[$fi]; # Set the rest of the attributes in the reference annotation
           next if (($fakey eq "framespan") || (grep(m%^$fakey$%, @location_attrs))); # We have already taken care of this
           # Skip if it is an attribute that doesn't affect the evaluation settings. E.g. HEADGEAR in FACE annotation
           next if (grep(m%^$fakey$%, &get_values_from_array_of_hashes("name", @{$dont_care_list_objects_attributes{$domain}{$eval_obj}}))); 

           my %attr = %{$obj_attr{$fakey}};
        my @tmpb = keys %attr;
        for (my $ai = 0; $ai < scalar @tmpb; $ai++) {
           my $attkey = $tmpb[$ai];
             if (! $fr_fs->set_value($attkey)) {
                    $self->_set_errormsg("$fakey: ViperFramespan ($attkey) error (" . $fr_fs->get_errormsg() . ")");
                    return(0);
             }

             my $attr_fs = $obj_fs->get_overlap($fr_fs);
             next if(! defined $attr_fs);

             my @attr_frames = $attr_fs->list_frames();
             my ($attr_beg_fr, $attr_end_fr) = MMisc::min_max_r(\@attr_frames);
             my @att_value = @{$attr{$attkey}};
             for (my $afi = 0; $afi < scalar @attr_frames; $afi++) {
               my $attr_fr = $attr_frames[$afi];
               my $objectList = $frameList->{$attr_fr}->getObjectList();
               next if (! exists $objectList->{$object_id});
               if (($hash_objects_attributes_types{$eval_obj}{$isgtf}->{$fakey} eq "bvalue") || ($hash_objects_attributes_types{$eval_obj}{$isgtf}->{$fakey} eq "dvalue")) {
                   if ($att_value[0] ne $hash_objects_attributes_types_default{$eval_obj}{$isgtf}->{$fakey}) { $objectList->{$object_id}->setDontCare(1); }
                   elsif (! defined $objectList->{$object_id}->getDontCare()) { $objectList->{$object_id}->setDontCare(0); }
               }
               elsif ($fakey eq "MOBILITY") {
                   if ($att_value[0] ne $hash_objects_attributes_types_default{$eval_obj}{$isgtf}->{$fakey}) { 
                        if (($attr_beg_fr > $obj_beg_fr) || ($attr_end_fr < $obj_end_fr)) { $objectList->{$object_id}->setDontCare(1); }
                        else { delete $objectList->{$object_id}; }
                   }
                   elsif (! defined $objectList->{$object_id}->getDontCare()) { $objectList->{$object_id}->setDontCare(0); }
               }
               elsif ($fakey eq "CONTENT") { $objectList->{$object_id}->setContent($att_value[0]); }
               $frameList->{$attr_fr}->setObjectList($objectList);
             }
           }
        }
     }
  }

  $eval_sequence->setFrameList($frameList);

  return(1);
}

##########

sub get_values_from_array_of_hashes {
  my ($key, @array_of_hash) = @_;

  my @out;
  for (my $hi = 0; $hi < scalar @array_of_hash; $hi++) {
    my $hash = $array_of_hash[$hi];
    push @out, $hash->{$key};
  }

  return @out;
}

################################################## Special Modes

sub get_spmode_list { return(@spmode_ok_list); }

#####

sub get_AVSS09_spmode_key { return($spmode_ok_list[0]); }

#####

sub is_spmode_ok {
  my ($self, $mode) = @_;

  if (! grep(m%^$mode$%, @spmode_ok_list)) {
    $self->_set_errormsg("Unknow special mode ($mode)");
    return(0);
  }

  return(1);
}

##### 

sub set_spmode {
  my ($self, $mode) = @_;

  my $t = $self->get_spmode();
  if ((! MMisc::is_blank($t)) && ($t ne $mode)) {
    $self->_set_errormsg("Special mode already set to \"$t\", can not change to \"$mode\"");
    return(0);
  }

  $self->is_spmode_ok($mode);
  return(0) if ($self->error());

  return(1);
}

##### 
  
sub get_spmode {
  my $self = $_[0];
  return($self->{spmode});
}

  
########################################

1;
