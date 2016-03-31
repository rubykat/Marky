package Marky;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->plugin('Config' => { file => "$FindBin::RealBin/../marky.conf" });
    $self->plugin('Marky::DbTableSet');

    my @db_routes = ();
    foreach my $db (@{$self->marky_table_array})
    {
        push @db_routes, "/db/$db";
    }
    $self->plugin('Foil' => { add_prefixes => \@db_routes});

    # -------------------------------------------
    # Config hypnotoad

    $self->config(hypnotoad => {
            pid_file => "$FindBin::RealBin/marky.pid",
            listen => ['http://*:3001'],
            proxy => 1,
        });

    # -------------------------------------------
    $self->secrets([qw(etunAvIlyiejUnnodwyk supernumary55)]);
    $self->sessions->cookie_name('marky');
    $self->sessions->default_expiration(60 * 60 * 24 * 3); # 3 days
    foreach my $key (keys %{$self->config->{defaults}})
    {
        $self->defaults($key, $self->config->{defaults}->{$key});
    }

    # -------------------------------------------

    # Router
    my $r = $self->routes;

    $r->get('/')->to('db#tables');
    $r->get('/opt')->to('db#options');
    $r->get('/db/:db/opt')->to('db#options');

    $r->get('/db/:db/taglist')->to('db#taglist');
    $r->get('/db/:db/tagcloud')->to('db#tagcloud');

    $r->get('/db/:db')->to('db#query');
    $r->get('/db/:db/tags/:tags')->to('db#tags');

    $r->get('/db/:db/add')->to('db#add_bookmark');
    $r->post('/db/:db/add')->to('db#save_bookmark');
}

1;
