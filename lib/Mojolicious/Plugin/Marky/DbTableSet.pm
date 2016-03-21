package Mojolicious::Plugin::Marky::DbTableSet;

=head1 NAME

Mojolicious::Plugin::Marky::DbTableSet - querying one database table

=head1 VERSION

This describes version 0.1 of Marky

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Mojolicious::Plugin::Marky::DbTableSet;;

=head1 DESCRIPTION

Bookmarking and Tutorial Library application.
Querying one database table, returning result.

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Marky::DbTable;
use common::sense;
use DBI;
use Path::Tiny;
use Search::Query;
use Sort::Naturally;
use Text::NeatTemplate;
use YAML::Any;
use POSIX qw(ceil);
use HTML::TagCloud;
use Mojo::URL;

=head1 REGISTER

=cut

sub register {
    my ( $self, $app, $conf ) = @_;

    $self->_init($app,$conf);

    $app->helper( 'marky.do_query' => sub {
        my $c        = shift;
        my %args = @_;

        return $self->_do_query($c);
    } );

    $app->helper( 'marky.display_tables' => sub {
        my $c        = shift;
        my %args = @_;

        return $self->_display_tables($c);
    } );

    $app->helper( 'marky.make_tc_list' => sub {
        my $c        = shift;
        my $db        = shift;

        return $self->_make_tc_list($c,$db);
    } );

    $app->helper( 'marky.taglist' => sub {
        my $c        = shift;
        my %args = @_;

        return $self->_taglist($c,%args);
    } );

    $app->helper( 'marky.tagcloud' => sub {
        my $c        = shift;
        my %args = @_;

        return $self->_tagcloud($c,%args);
    } );
    $app->helper( 'marky.set_options' => sub {
        my $c        = shift;
        my %args = @_;

        return $self->_set_options($c,%args);
    } );
}

=head1 Helper Functions

These are functions which are NOT exported by this plugin.

=cut

=head2 _init

Initialize.

=cut
sub _init {
    my $self = shift;
    my $app = shift;
    my $conf = shift;

    $self->{dbtables} = {};
    my $tnav = "<div class='dblist'><ul>";
    foreach my $t (sort keys %{$app->config->{tables}})
    {
        $self->{dbtables}->{$t} = Marky::DbTable->new(%{$app->config->{tables}->{$t}});
        my $url = $app->url_for("/db/$t");
        $tnav .= "<li><a href='$url'>$t</a></li>\n";
    }
    $tnav .= "</ul></div>";
    $app->defaults(sidenav => $tnav);
    return $self;
} # _init

=head2 _do_query

Do a query, looking at the params and session.

=cut

sub _do_query {
    my $self = shift;
    my $c = shift;
    my $app = $c->app;

    my $db = $c->param('db');
    if (!exists $self->{dbtables}->{$db})
    {
        $c->render(template => 'apperror',
            errormsg=>"<p>No such db: $db</p>");
        return;
    }

    my $tags = $c->param('tags');
    my $q = $c->param('q');
    my $p = $c->param('p');

    my $n = $c->session('n');
    my $sort_by = $c->session("${db}_sort_by");
    my $sort_by2 = $c->session("${db}_sort_by2");
    my $sort_by3 = $c->session("${db}_sort_by3");

    my $delterm = $c->param('delterm');
    if ($delterm && $q)
    {
        $q =~ s/\b[ +]?$delterm\b//;
        $q =~ s/[ +]$//;
        $q =~ s/^[ +]//;
        $c->param('q'=>$q);
        $c->param(delterm=>undef);
    }
    my $deltag = $c->param('deltag');
    if ($deltag && $tags)
    {
        $tags =~ s/\b[ +]?$deltag\b//;
        $tags =~ s/[ +]$//;
        $tags =~ s/^[ +]//;
        $c->param('tags'=>$tags);
        $c->param(deltag=>undef);
    }
    my $opt_url = $c->url_for("/db/$db/opt");
    my $location = $c->url_for("/db/$db");
    my $res = $self->{dbtables}->{$db}->query(location=>$location,
        opt_url=>$opt_url,
        db=>$db,
        q=>$q,
        tags=>$tags,
        n=>$n,
        p=>$p,
        sort_by=>$sort_by,
        sort_by2=>$sort_by2,
        sort_by3=>$sort_by3,
        show_sql=>$app->config->{tables}->{$db}->{show_sql},
    );
    my $tcnav = $self->_make_tc_list($c,$db);
    my $snav = join("\n", $tcnav, $res->{sidebar});
    $c->stash('results' => $res->{results});
    $c->render(template => 'results',
        footer=>$res->{searchform},
        sidenav=>$snav);
} # _do_query

=head2 _make_tc_list

Make a taglist/tagcloud list for this db

=cut

sub _make_tc_list {
    my $self  = shift;
    my $c  = shift;
    my $db = shift;

    my $db_url = $c->url_for("/db/$db");
    my @out = ();
    push @out, "<div class='dblist'><ul>";
    push @out, "<li><a href='${db_url}'>$db</a></li>";
    foreach my $t (qw(taglist tagcloud))
    {
        push @out, "<li><a href='${db_url}/$t'>$db $t</a></li>";
    }
    push @out, "</ul></div>";
    my $out = join("\n", @out);
    return $out;
} # _make_tc_list

=head2 _make_table_list

Make a list of all the dbtables.

=cut

sub _make_table_list {
    my $self  = shift;
    my $c  = shift;

    my @out = ();
    push @out, "<div class='dblist'><ul>";
    foreach my $t (sort keys %{$self->{dbtables}})
    {
        my $url = $c->url_for("/db/$t");
        push @out, "<li><a href='$url'>$t</a></li>";
    }
    push @out, "</ul></div>";
    my $out = join("\n", @out);
    return $out;
} # _make_table_list

=head2 _display_tables

Make a list of all the dbtables.

=cut

sub _display_tables {
    my $self  = shift;
    my $c  = shift;

    my $out = $self->_make_table_list($c);

    $c->stash('stuff' => $out);
    $c->render(template => 'tables',
        sidenav=>$out);
} # _display_tables

=head2 _taglist

Make a taglist for a db

=cut

sub _taglist {
    my $self  = shift;
    my $c  = shift;
    my %args = @_;

    my $db = $c->param('db');
    my $opt_url = $c->url_for("/db/$db/opt");
    my $location = $c->url_for("/db/$db");
    my $res = $self->{dbtables}->{$db}->taglist(location=>$location,
        opt_url=>$opt_url,
        db=>$db,
        n=>0,
    );
    my $tcnav = $self->_make_tc_list($c,$db);
    $c->stash('results' => $res->{results});
    $c->render(template => 'results',
        sidenav=>$tcnav);
} # _taglist

=head2 _tagcloud

Make a tagcloud for a db

=cut

sub _tagcloud {
    my $self  = shift;
    my $c  = shift;
    my %args = @_;

    my $db = $c->param('db');
    my $opt_url = $c->url_for("/db/$db/opt");
    my $location = $c->url_for("/db/$db");
    my $res = $self->{dbtables}->{$db}->tagcloud(location=>$location,
        opt_url=>$opt_url,
        db=>$db,
        n=>0,
    );
    my $tcnav = $self->_make_tc_list($c,$db);
    $c->stash('results' => $res->{results});
    $c->render(template => 'results',
        sidenav=>$tcnav);
} # _tagcloud

=head2 _set_options

Set options in the session

=cut

sub _set_options {
    my $self  = shift;
    my $c  = shift;
    my %args = @_;

    # Set options for things like n
    # Note that we don't delete old values
    # because this can be called with different sets of values
    # For example the themes are called by themselves on a different form
    my @db = (sort keys %{$self->{dbtables}});

    my @fields = (qw(n theme));
    foreach my $db (@db)
    {
        push @fields, "${db}_sort_by";
        push @fields, "${db}_sort_by2";
        push @fields, "${db}_sort_by3";
    }
    foreach my $field (@fields)
    {
        my $val = $c->param($field);
        if ($val)
        {
            $c->session->{$field} = $val;
        }
    }
    $c->redirect_to($c->req->headers->referrer);
} # _set_options

1; # End of Mojolicious::Plugin::Marky::DbTableSet
__END__
