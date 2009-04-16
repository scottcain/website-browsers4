package WormBase::Web::Model::Antibody;
use base qw/Catalyst::Model::Factory/;

# Fetch the default args and pass along some extras
# including our C::Log::Log4perl
sub prepare_arguments {
  my ($self, $c) = @_;
  my $args  = $c->config->{'Model::Antibody'}->{args};
  $args->{class}     = 'Antibody';
  $args->{request}   = $c->stash->{request};
  $args->{log}       = $c->log;
  $args->{ace_model} = $c->model('AceDB');
  return $args;
}

1;
