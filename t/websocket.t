BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll' }

use Mojolicious::Lite;

use Test::More;
use Test::Mojo;
my $t = Test::Mojo->new;

require Mojo::Pg;

plugin Minion => { SQLite => ':temp:' };
my $minion = app->minion;

use Mercury;
my $mercury = Mercury->new;
use Minion::Notifier::Transport::WebSocket;
my $transport = Minion::Notifier::Transport::WebSocket->new;
my $url = $transport->ua->server->app($mercury)->nb_url->clone;
$transport->url($url->path('/bus/jobs'));
plugin 'Minion::Notifier', {transport => $transport};
my $notifier = app->minion_notifier;

$minion->add_task(live => sub { return 1 });
$minion->add_task(die  => sub { die 'argh' });

my $id;
any '/live' => sub {
  my $c = shift;
  $id = $minion->enqueue('live');
  $notifier->on(job => sub {
    my ($notifier, $id, $message) = @_;
    $c->render(json => {id => $id, message => $message});
  });
  $minion->perform_jobs; 
};

$t->get_ok('/live')
  ->status_is(200)
  ->json_is('/id' => $id)
  ->json_is('/message' => 'finished');

done_testing;

