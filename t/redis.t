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
Mojo::IOLoop->one_tick; # ensure that setup_listener is called

$minion->add_task(live => sub { return 1 });
$minion->add_task(die  => sub { die 'argh' });

my $id;
any '/live' => sub {
  my $c = shift;
  my @events;
  $notifier->on(job => sub {
    my (undef, @args) = @_;
    push @events, \@args;
    return unless $args[1] =~ /finished|failed/;
    $c->render(json => {id => $id, events => \@events});
  });
  $id = $minion->enqueue('live');
  $minion->perform_jobs;
};

$t->get_ok('/live')
  ->status_is(200)
  ->json_is('/id' => $id);

my @expect = (
  [$id => 'enqueue'],
  [$id => 'dequeue'],
  [$id => 'finished'],
);
$t->json_is('/events' => \@expect);

done_testing;

