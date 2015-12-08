package Minion::Notifier::Transport::WebSocket;

use Mojo::Base 'Minion::Notifier::Transport';

use Mojo::URL;
use Mojo::UserAgent;

has ua => sub { Mojo::UserAgent->new };

has url => sub { die 'url is required' };

sub listen {
  my $self = shift;
  my $url = $self->_url;

  $self->ua->websocket($url => sub {
    my ($ua, $tx) = @_;
    $tx->on(json => sub {
      my ($tx, $data) = @_;
      $self->emit(notified => @$data);
    });
  });
}

sub send {
  my ($self, $id, $message) = @_;
  my $url = $self->_url;
  $self->ua->websocket($url => sub {
    my ($ua, $tx) = @_;
    $tx->send({json => [$id, $message]}); #TODO finish after send?
  });
}

sub _url {
  my $self = shift;
  my $url = $self->url;
  $url = Mojo::URL->new($url) unless ref $url;
  unless ($url->protocol =~ /^ws/) {
    $url->scheme($url->protocol eq 'https' ? 'wss' : 'ws');
  }
  return $url;
}

1;

