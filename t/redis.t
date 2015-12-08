BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll' }

use Mojolicious::Lite;

use Test::More;
plan skip_all => 'set TEST_ONLINE to a redis url to run test'
  unless my $url = $ENV{TEST_ONLINE_REDIS};

use Test::Mojo;
my $t = Test::Mojo->new;

plugin Minion => { SQLite => ':temp:' };
my $minion = app->minion;

plugin 'Minion::Notifier', {transport => $url};
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

