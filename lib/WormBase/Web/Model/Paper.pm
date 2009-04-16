package WormBase::Web::Model::Paper;
use base qw/Catalyst::Model::Factory/;

# Fetch the default args and pass along some extras
# including our C::Log::Log4perl
sub prepare_arguments {
  my ($self, $c) = @_;
  my $args  = $c->config->{'Model::Paper'}->{args};
  $args->{class}   = 'Paper';
  $args->{request} = $c->stash->{request};
  $args->{log}     = $c->log;
  $args->{ace_model} = $c->model('AceDB');
#  $args->{dbh_gff} = $c->model('GFF');
#  $args->{gbrowse_conf_dir} = $c->config->{gbrowse_conf_dir};
  return $args;
}

1;
