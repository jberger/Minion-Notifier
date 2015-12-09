package Minion::Notifier;

use Mojo::Base 'Mojo::EventEmitter';

our $VERSION = '0.01';
$VERSION = eval $VERSION;

has minion => sub { die 'A Minion instance is required' };

has transport => sub { Minion::Notifier::Transport->new };

sub app { shift->minion->app }

sub setup_listener {
  my $self = shift;

  $self->transport->on(notified => sub {
    my ($transport, $id, $event) = @_;
    $self->emit(job => $id, $event);
    $self->emit("job:$id" => $id, $event);
    $self->emit($event    => $id);
  });
  $self->transport->listen;

  return $self;
}

sub setup_worker {
  my $self = shift;

  my $dequeue = sub {
    my ($worker, $job) = @_;
    my $id = $job->id;
    $job->on(finished => sub { $self->transport->send($id, 'finished') });
    $job->on(failed   => sub { $self->transport->send($id, 'failed') });
  };

  $self->minion->on(worker => sub {
    my ($minion, $worker) = @_;
    $worker->on(dequeue => $dequeue);
  });

  return $self
}

1;

=head1 NAME

Minion::Notifier - Notify listeners when a Minion task has completed

=head1 SYNOPSIS

  use Mojolicious::Lite;

  plugin Minion => { Pg => 'posgressql://...'};

  plugin 'Minion::Notifier';

  app->minion->add_task( doit => sub { ... } );

  any '/doit' => sub {
    my $c = shift;
    my $id = $c->minion->enqueue(doit => [...]);
    $c->minion_notifier->on(job => sub {
      my ($notifier, $job_id, $message) = @_;
      return unless $job_id eq $id;
      $c->render( text => "job $id: $message" );
    });
  };

=head1 DESCRIPTION

Although L<Minion> is a highly capable job queue, it does not natively have a mechanism to notify listeners when a job has finished or failed.
L<Minion::Notifier> provides this feature using pluggable L<Transport|Minion::Notifier::Transport> backends.
Currently supported are L<Postgres|Minion::Notifier::Transport::Pg>, L<Redis|Minion::Notifier::Transport::Redis>, and L<WebSocket|Minion::Notifier::Transport::WebSocket>.

Note that this is an early release and the mechansim for loading plugins, especially third-party plugins is likely to change.

=head1 EVENTS

L<Minion::Notifier> inherits all events from L<Mojo::EventEmitter> and emits the following new ones.

=head2 job

  $notifier->on(job => sub { my ($notifier, $job_id, $message) = @_; ... });

Emitted on any message from the backend for all jobs.
Currently the message is the final status, ie. "finished" or "failed", though this may change.

=head2 job:$id

  $notifier->on("job:1234" => sub { my ($notifier, $job_id, $message) = @_; ... });

Emitted on any message from the backend for specific jobs.
Note that the id is still passed so that you may reuse callbacks if desired.
Currently the message is the final status, ie. "finished" or "failed", though this may change.

=head2 finished

  $notifier->on(finished => sub { my ($notifier, $job_id) = @_; ... });

Emitted whenever any job reaches a state of "finished".
Since the above messages are simply the statuses, the status is not repeated as an argument, though this is subject to change.

=head2 failed

  $notifier->on(failed => sub { my ($notifier, $job_id) = @_; ... });

Emitted whenever any job reaches a state of "failed".
Since the above messages are simply the statuses, the status is not repeated as an argument, though this is subject to change.

=head1 ATTRIBUTES

L<Minion::Notifier> inherits all of the attributes from L<Mojo::EventEmitter> and implements the following new ones.

=head2 minion

The L<Minion> instance to listen to.
Note that this attribute is used to gain access to the L<"application instance"|/app">.

=head2 transport

An instance of L<Minion::Notifier::Transport> or more likely a subclass thereof.
This is used to moderate the communication between processes and even hosts.

=head1 METHODS

L<Minion::Notifier> inherits all of the methods from L<Mojo::EventEmitter> and implements the following new ones.

=head2 app

A shortcut for C<< $notifier->minion->app >>.

=head2 setup_listener

Setup the linkages that allow for notifications to be received.
This is called automatically by L<Mojolicious::Plugin::Minion::Notifier> once the ioloop has started.

=head2 setup_worker

Setup the linkages that cause the jobs to send notifications when reaching "finished" or "failed" states.
This is called automatically by L<Mojolicious::Plugin::Minion::Notifier>.


=head1 SEE ALSO

=over

=item *

L<Mojolicious> - Real-time web framework

=item *

L<Minion> - The L<Mojolicious> job queue

=item *

L<Mercury> - A lightweight message broker using L<Mojolicious>' WebSockets for transport

=back

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Minion-Notifier>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
