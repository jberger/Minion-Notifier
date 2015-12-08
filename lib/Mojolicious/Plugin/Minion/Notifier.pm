package Mojolicious::Plugin::Minion::Notifier;

use Mojo::Base 'Mojolicious::Plugin';

use Minion::Notifier;

sub register {
  my ($plugin, $app, $config) = @_;
  $config->{minion} ||= eval { $app->minion } || die 'A minion instance is required';
  if (!$config->{transport} && $config->{minion}->backend->isa('Minion::Backend::Pg')) {
    require Minion::Notifier::Transport::Pg;
    $config->{transport} = Minion::Notifier::Transport::Pg->new(pg => $config->{minion}->backend->pg);
  }
  my $notifier = Minion::Notifier->new($config);
  $app->helper(minion_notifier => sub { $notifier });
  $notifier->attach;
  return $notifier;
}

1;

