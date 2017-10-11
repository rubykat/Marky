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

=head2 tables

Display the tables

=cut
sub tables {
    my $c  = shift;
    $c->render(template=>'tables');
}

=head2 options

For setting the options of the app.

=cut
sub options {
    my $c  = shift;
    $c->marky_set_options();
    $c->render(template => 'settings');
}

=head2 taglist

Display the list of tags in the database.

=cut
sub taglist {
    my $c  = shift;
    $c->render(template=>'taglist');
}

=head2 tagcloud

Display the tags as a tagcloud.

=cut
sub tagcloud {
    my $c  = shift;
    $c->render(template=>'tagcloud');
}

=head2 query

Process a query

=cut
sub query {
    my $c  = shift;
    $c->marky_do_query();
}

=head2 tags

Process a query by tags.

=cut
sub tags {
    my $c  = shift;
    $c->marky_do_query();
}

=head2 add_bookmark

Add a bookmark

=cut
sub add_bookmark {
    my $c  = shift;
    $c->render(template=>'add_bookmark');
}

=head2 save_bookmark

Save a bookmark.

=cut
sub save_bookmark {
    my $c  = shift;
    $c->marky_save_new_bookmark();
    $c->render(template=>'save_bookmark');
}


1;
