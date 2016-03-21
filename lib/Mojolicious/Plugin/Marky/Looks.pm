package Mojolicious::Plugin::Marky::Looks;

=head1 NAME

Mojolicious::Plugin::Marky::Looks - looks for app

=head1 VERSION

This describes version 0.1 of Marky

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Mojolicious::Plugin::Marky::Looks;

=head1 DESCRIPTION

Bookmarking and Tutorial Library application.
Pretty themes; putting them in the application
instead of in javascript; it's faster this way.
Also other looks like breadcrumbs and other header stuff.

=cut

use Mojo::Base 'Mojolicious::Plugin';
use common::sense;
use File::Serialize;
use Path::Tiny;

=head1 REGISTER

=cut

sub register {
    my ( $self, $app, $conf ) = @_;

    my $base_dir = $conf->{base_dir};
    $self->_get_themes($base_dir);

    $app->helper( 'marky.theme_selector' => sub {
        my $c        = shift;
        my %args     = @_;

        return $self->_make_theme_selector(%args);
    } );

    $app->helper( 'marky.set_looks' => sub {
        my $c        = shift;
        my %args     = @_;

        return $self->_set_looks($c,%args);
    } );
}

=head1 Helper Functions

These are functions which are NOT exported by this plugin.

=cut

=head2 _get_themes

Get the list of themes from the themes.json file.

=cut

sub _get_themes {
    my $self = shift;
    my $base_dir = path(shift);

    my $theme_file = $base_dir->child("public/styles/themes/themes.json");
    if (!-f $theme_file)
    {
        die "'$theme_file' not found";
    }
    $self->{themes} = deserialize_file $theme_file;
    if (!defined $self->{themes})
    {
        die "failed to read themes from $theme_file";
    }
    if (ref $self->{themes} ne 'HASH')
    {
        die "themes not HASH $theme_file";
    }
    if (!exists $self->{themes}->{themes})
    {
        die "themes->themes not there $theme_file";
    }
    if (ref $self->{themes}->{themes} ne 'ARRAY')
    {
        die "themes->themes not ARRAY $theme_file";
    }
} # _get_themes

=head2 _make_theme_selector

For selecting themes.

=cut

sub _make_theme_selector {
    my $self = shift;
    my %args = @_;

    my $curr_theme = $args{current_theme};
    my $opt_url = $args{opt_url};

    my @out = ();
    push @out, "<div class='themes'>";
    push @out, "<form action='$opt_url'>";
    push @out, '<input type="submit" value="Select theme"/>';
    push @out, '<select name="theme">';
    my @themes = @{$self->{themes}->{themes}};
    for (my $i=0; $i < @themes; $i++)
    {
        my $th = $themes[$i];
        if ($th eq $curr_theme)
        {
            push @out, "<option value='$th' selected>$th</option>";
        }
        else
        {
            push @out, "<option value='$th'>$th</option>";
        }
    }
    push @out, '</select>';
    push @out, '</form>';
    push @out, '</div>';

    my $out = join("\n", @out);
    return $out;
} # _make_theme_selector

=head2 _make_navbar

Top-level navigation.
The difficulty with this is that using a reverse-proxy means that
all relative-ish URLs will be rewritten to be relative to this app.
So we need to take account of the host the request is coming from.
Absolute full URLs shouldn't be re-written.

=cut

sub _make_navbar {
    my $self = shift;
    my $c = shift;
    my %args = @_;

    my $rhost = $c->req->headers->host;
    my $nb_host = $rhost;
    if (exists $c->config->{vhosts}->{$rhost}->{navbar_host})
    {
        $nb_host = $c->config->{vhosts}->{$rhost}->{navbar_host};
    }
    my @out = ();
    push @out, '<nav>';
    push @out, '<ul>';
    # we start always with Home
    push @out, "<li><a href='http://$nb_host/'>Home</a></li>";
    if (exists $c->config->{vhosts}->{$rhost}->{navbar_links})
    {
        foreach my $link (@{$c->config->{vhosts}->{$rhost}->{navbar_links}})
        {
            my $name = $link;
            if ($link =~ m{(\w+)/?$})
            {
                $name = ucfirst(lc($1));
            }
            if ($link =~ /^http/)
            {
                push @out, "<li><a href='${link}'>$name</a></li>";
            }
            else
            {
                push @out, "<li><a href='http://${nb_host}${link}'>$name</a></li>";
            }
        }
    }
    push @out, '</ul>';
    push @out, '</nav>';

    my $out = join("\n", @out);
    return $out;
} # _make_navbar

=head2 _set_looks

For selecting themes.

=cut

sub _set_looks {
    my $self = shift;
    my $c = shift;
    my %args = @_;

    my $url = $c->req->headers->referrer;
    my $rhost = $c->req->headers->host;
    my $logoid = 'logo';
    my $hostname = $rhost;
    if (exists $c->config->{vhosts}->{$rhost})
    {
        $hostname = $c->config->{vhosts}->{$rhost}->{name};
        $logoid = $c->config->{vhosts}->{$rhost}->{logoid};
    }
    my $breadcrumb = "<b>$hostname</b> <a href='/'>Home</a>";
    if (defined $url)
    {
        $breadcrumb .= " &gt; <a href='$url'>$url</a>";
    }
    $c->stash(breadcrumb => $breadcrumb);
    $c->stash(logoid => $logoid);
    $c->stash(navbar => $self->_make_navbar($c,%args));

    my $db = $c->param('db');
    my $theme = $c->session('theme');
    $theme = 'silver' if !$theme;
    $c->stash(theme=>$theme);
    my $opt_url = $c->url_for(
        ($db ?  "/db/$db/opt" : "/opt")
    );
    my $theme_sel = $self->_make_theme_selector(
        current_theme=>$theme,
        opt_url=>$opt_url,
    );
    $c->stash(rightside=>$theme_sel);
} # _set_looks

1; # End of Mojolicious::Plugin::Marky::Looks
__END__
