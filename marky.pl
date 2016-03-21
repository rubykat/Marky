#!/usr/bin/env perl
use FindBin;
use lib "$FindBin::RealBin" . "/lib";
use Mojolicious::Lite;

plugin 'Config' => { file => "$FindBin::RealBin/marky.conf" };
plugin 'Marky::Looks' => {base_dir => $FindBin::RealBin};
plugin 'Marky::DbTableSet';

sub setup {

    # -------------------------------------------
    # Config hypnotoad

    app->config(hypnotoad => {
            pid_file => "$FindBin::RealBin/marky.pid",
            listen => ['http://*:3001'],
            proxy => 1,
        });

    # -------------------------------------------
    app->secrets([qw(etunAvIlyiejUnnodwyk supernumary55)]);
    app->sessions->cookie_name('marky');
    foreach my $key (keys %{app->config->{defaults}})
    {
        app->defaults($key, app->config->{defaults}->{$key});
    }

    app->defaults(breadcrumb => '<a href="/">Marky</a>');
}
setup();

# ============================================================================

get '/' => sub {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->display_tables();
  };

get '/opt' => sub {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->set_options();
  };

get '/db/:db/opt' => sub {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->set_options();
  };


get '/db/:db/taglist' => sub {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->taglist();
  };

get '/db/:db/tagcloud' => sub {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->tagcloud();
  };

get '/db/:db' => sub {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->do_query();
  };

get '/db/:db/tags/:tags' => sub {
    my $c  = shift;
    $c->marky->set_looks();
    $c->marky->do_query();
  };


# ============================================================================

app->start;

__DATA__
@@ tables.html.ep
% layout 'page';
<h1>Select What Table To Search</h1>
<%== $stuff %>

@@ results.html.ep
% layout 'page';
<%== $results %>

@@ apperror.html.ep
% layout 'page';
<h1>Error</h1>
<%== $errormsg %>
