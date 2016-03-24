package Marky::Controller::Db;
use Mojo::Base 'Mojolicious::Controller';

sub tables {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->display_tables();
}

sub options {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->set_options();
}

sub taglist {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->taglist();
}

sub tagcloud {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->tagcloud();
}

sub query {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->do_query();
}

sub tags {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->do_query();
}

1;
