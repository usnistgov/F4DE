package Point;

# Point
#
# Author(s): Vasant Manohar
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "Point.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

# use module
use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "Point.pm Version: $version";

##########
# Check we have every module (perl wise)

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";

# MErrorH.pm
unless (eval "use MErrorH; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"MErrorH\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# "MMisc.pm"
unless (eval "use MMisc; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# For the '_display()' function
unless (eval "use Data::Dumper; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"Data::Dumper\" is not available in your Perl installation. ", 
                "Please visit \"http://search.cpan.org/~ilyam/Data-Dumper-2.121/Dumper.pm\" for installation information\n");
    $have_everything = 0;
  }

# Something missing ? Abort
error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Constructor 
# Using double-argument form of bless() for an inheritable constructor
# Rather than being uniquely a class method, we'll set it up so that 
# it can be called as either a class method or an object method.

#######################

sub new {
    my ( $proto, $x, $y ) = @_;
    my $class = ref($proto) || $proto;

    my $_errormsg = MErrorH->new("Point");
    my $errortxt = "";
    $_errormsg->set_errormsg($errortxt);

    my $self =
        {
         _x              => $x,
         _y              => $y,
         #ErrorHandler
         _errormsg       => $_errormsg,
        };

    return "'x' not defined" if (! defined $x);
    return "'y' not defined" if (! defined $y);
    bless ( $self, $class );
    return $self;
}

#######################

sub getX {
    my ( $self ) = @_;
    return $self->{_x};
}

sub getY {
    my ( $self ) = @_;
    return $self->{_y}; 
}

#######################

sub computeDistance {
    my ( $self, $other ) = @_;

    my $gtPoint = {
                   x => $self->getX(),
                   y => $self->getY(),
                  };
    my $soPoint = {
                   x => $other->getX(),
                   y => $other->getY(),
                  };

    my $distance = sqrt(($gtPoint->{x} - $soPoint->{x})*($gtPoint->{x} - $soPoint->{x}) + ($gtPoint->{y} - $soPoint->{y})*($gtPoint->{y} - $soPoint->{y}));

    return $distance;
}

#######################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{_errormsg}->set_errormsg($txt);
}

sub get_errormsg {
  my ($self) = @_;
  return($self->{_errormsg}->errormsg());
}

sub error {
  my ($self) = @_;
  return($self->{_errormsg}->error());
}

#######################

sub warn_print {
  print "WARNING: ", @_;

  print "\n";
}

#######################

sub error_quit {
  print("${ekw}: ", @_);

  print "\n";
  exit(1);
}

1;
