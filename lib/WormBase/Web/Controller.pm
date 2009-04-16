package WormBase::Web::Controller;

use strict;
use warnings;
use base 'Catalyst::Controller';

#########################################
# Accessors for configuration variables #
#########################################
sub pages {
  my ( $self, $c ) = @_;
  my @pages = keys %{ $c->config->{pages} };
  return sort @pages;
}

sub widgets {
  my ( $self, $page, $c ) = @_;
  my (@widgets) = @{ $c->config->{pages}->{$page}->{widget_order} };
  return @widgets;
}

sub fields {
  my ( $self, $page, $widget, $c ) = @_;
  my @fields = eval { @{ $c->config->{pages}->{$page}->{widgets}->{$widget} }; };
#  @fields || die
#    "Check configuration for $page:$widget: all widgets specified in widget_order must exist in 'widgets'";
  return @fields;
}

1;
