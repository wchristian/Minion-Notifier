package Minion::Notifier;

use Mojo::Base 'Mojo::EventEmitter';

use Mojo::IOLoop;

has minion => sub { die 'A Minion instance is required' };

has transport => sub { Minion::Notifier::Transport->new };

sub app { shift->minion->app }

sub attach {
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

  #Mojo::IOLoop->next_tick(sub{
    $self->transport->on(notified => sub {
      my ($transport, $id, $event) = @_;
      $self->emit(job => $id, $event);
      $self->emit("job:$id" => $event);
      $self->emit($event    => $id);
    });
    $self->transport->listen;
  #});

  return $self;
}

1;

