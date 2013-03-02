package WormBase::Update::Production::UpdateFTPSymlinks;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'update symlinks on the production FTP site',
);

sub run {
    my $self = shift;       
    $self->update_ftp_site_symlinks();
}




1;
