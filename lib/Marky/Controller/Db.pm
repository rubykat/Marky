package Marky::Controller::Db;
use Mojo::Base 'Mojolicious::Controller';

sub tables {
    my $c  = shift;
    $c->render(template=>'tables');
}

sub options {
    my $c  = shift;
    $c->marky_set_options();
}

sub taglist {
    my $c  = shift;
    $c->render(template=>'taglist');
}

sub tagcloud {
    my $c  = shift;
    $c->render(template=>'tagcloud');
}

sub query {
    my $c  = shift;
    $c->marky_do_query();
}

sub tags {
    my $c  = shift;
    $c->marky_do_query();
}

sub add_bookmark {
    my $c  = shift;
    $c->render(template=>'add_bookmark');
}
sub save_bookmark {
    my $c  = shift;
    $c->marky_save_new_bookmark();
    $c->render(template=>'save_bookmark');
}


1;
