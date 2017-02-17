package Marky::Controller::Db;

#ABSTRACT: Marky::Controller::Db - Database controller for Marky
=head1 NAME

Marky::Controller::Db - Database controller for Marky

=head1 SYNOPSIS

    use Marky::Controller::Db;

=head1 DESCRIPTION

Database controller for Marky

=cut

use Mojo::Base 'Mojolicious::Controller';

sub tables {
    my $c  = shift;
    $c->render(template=>'tables');
}

sub options {
    my $c  = shift;
    $c->marky_set_options();
    $c->render(template => 'settings');
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
