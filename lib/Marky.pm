package Marky;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->plugin('Config' => { file => "$FindBin::RealBin/../marky.conf" });
    $self->plugin('Marky::Looks' => {base_dir => $FindBin::RealBin . "/.."});
    $self->plugin('Marky::DbTableSet');

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

    $self->defaults(breadcrumb => '<a href="/">Marky</a>');
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

}

1;
