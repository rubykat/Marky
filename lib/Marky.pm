package Marky;

# ABSTRACT: web application for bookmark databases
=head1 NAME

Marky - web application for bookmark databases

=head1 SYNOPSIS

    use Marky;

=head1 DESCRIPTION

Bookmarking and Tutorial Library application.

=cut

use Mojo::Base 'Mojolicious';
use Path::Tiny;

# This method will run once at server start
sub startup {
    my $self = shift;

    # -------------------------------------------
    # Configuration
    # check:
    # * current working directory
    # * parent of CWD
    # -------------------------------------------
    my $conf_basename = "marky.conf";
    my $conf_file = path(Path::Tiny->cwd, $conf_basename);
    if (! -f $conf_file)
    {
        $conf_file = path(Path::Tiny->cwd->parent, $conf_basename);
    }
    # the MARKY_CONFIG environment variable overrides the default
    if (defined $ENV{MARKY_CONFIG} and -f $ENV{MARKY_CONFIG})
    {
        $conf_file = $ENV{MARKY_CONFIG};
    }
    print STDERR "CONFIG: $conf_file\n";
    my $mojo_config = $self->plugin('Config' => { file => $conf_file });

    $self->plugin('Marky::DbTableSet');

    my @db_routes = ();
    foreach my $db (@{$self->marky_table_array})
    {
        push @db_routes, "/db/$db";
    }
    $self->plugin('Foil' => { add_prefixes => \@db_routes});

    $self->plugin(NYTProf => $mojo_config);

    # -------------------------------------------
    # Templates
    # -------------------------------------------
    push @{$self->renderer->classes}, __PACKAGE__;

    # -------------------------------------------
    # secrets, cookies and defaults
    # -------------------------------------------
    $self->secrets([qw(etunAvIlyiejUnnodwyk supernumary55)]);
    $self->sessions->cookie_name('marky');
    $self->sessions->default_expiration(60 * 60 * 24 * 3); # 3 days
    foreach my $key (keys %{$self->config->{defaults}})
    {
        $self->defaults($key, $self->config->{defaults}->{$key});
    }

    # -------------------------------------------

    # -------------------------------------------
    # Router
    # -------------------------------------------
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

1; # end of Marky

# Here come the TEMPLATES!

__DATA__
@@ add_bookmark.html.ep
% layout 'foil';
% content_for 'head_extra' => begin
<link rel="stylesheet" href="<%= url_for('/css') %>/fa/css/font-awesome.min.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/marky.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/bookmark.css" type="text/css" />
% end
% content_for 'verso' => begin
<nav><%== marky_db_related_list %></nav>
% end
% content_for 'recto' => begin
<p class="total"><%= marky_total_records %> records in <%= param('db') %></p>
<%== marky_add_bookmark_bookmarklet %>
<%== foil_theme_selector %>
% end
<h1>Add Bookmark for <%= param('db') %></h1>
<%== marky_add_bookmark_form %>
 
@@ apperror.html.ep
% layout 'foil';
% content_for 'verso' => begin
<nav><%== marky_db_related_list %></nav>
% end
% content_for 'recto' => begin
<%== foil_theme_selector %>
% end
<h1>Error: <%= param('db') %></h1>
<%== $errormsg %>
 
@@ results.html.ep
% layout 'foil';
% content_for 'head_extra' => begin
<link rel="stylesheet" href="<%= url_for('/css') %>/fa/css/font-awesome.min.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/marky.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/results.css" type="text/css" />
% end
% content_for 'verso' => begin
<nav><%== marky_db_related_list %></nav>
<nav><%== $query_taglist %></nav>
% end
% content_for 'recto' => begin
<p class="total"><%= marky_total_records %> records in <%= param('db') %></p>
<%== foil_theme_selector %>
% end
<h1>Search <%= param('db') %></h1>
<%== $results %>
 
@@ save_bookmark.html.ep
% layout 'foil';
% content_for 'head_extra' => begin
<link rel="stylesheet" href="<%= url_for('/css') %>/fa/css/font-awesome.min.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/marky.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/bookmark.css" type="text/css" />
% end
% content_for 'verso' => begin
<nav><%== marky_db_related_list %></nav>
% end
% content_for 'recto' => begin
<p class="total"><%= marky_total_records %> records in <%= param('db') %></p>
<%== marky_add_bookmark_bookmarklet %>
<%== foil_theme_selector %>
% end
<h1>Bookmark for <%= param('db') %></h1>
<%== content 'results' %>
 
@@ settings.html.ep
% layout 'foil';
% content_for 'head_extra' => begin
<link rel="stylesheet" href="<%= url_for('/css') %>/fa/css/font-awesome.min.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/marky.css" type="text/css" />
% end
% content_for 'verso' => begin
<nav><%== marky_table_list %></nav>
% end
% content_for 'recto' => begin
<%== foil_theme_selector %>
% end
<h1>Settings</h1>
<%== marky_settings %>
 
@@ tables.html.ep
% layout 'foil';
% content_for 'head_extra' => begin
<link rel="stylesheet" href="<%= url_for('/css') %>/fa/css/font-awesome.min.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/marky.css" type="text/css" />
% end
% content_for 'verso' => begin
<nav><%== marky_table_list %></nav>
% end
% content_for 'recto' => begin
<%== foil_theme_selector %>
% end
<h1>Select What Table To Search</h1>
<%== marky_table_list %>
 
@@ tagcloud.html.ep
% layout 'foil';
% content_for 'head_extra' => begin
<link rel="stylesheet" href="<%= url_for('/css') %>/fa/css/font-awesome.min.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/marky.css" type="text/css" />
% end
% content_for 'verso' => begin
<nav><%== marky_db_related_list %></nav>
% end
% content_for 'recto' => begin
<p class="total"><%= marky_total_records %> records in <%= param('db') %></p>
<%== foil_theme_selector %>
% end
<h1>Tag Cloud: <%= param('db') %></h1>
<%== marky_tagcloud %>
 
@@ taglist.html.ep
% layout 'foil';
% content_for 'head_extra' => begin
<link rel="stylesheet" href="<%= url_for('/css') %>/fa/css/font-awesome.min.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/marky.css" type="text/css" />
<link rel="stylesheet" href="<%= url_for('/css') %>/taglist.css" type="text/css" />
% end
% content_for 'verso' => begin
<nav><%== marky_db_related_list %></nav>
% end
% content_for 'recto' => begin
<p class="total"><%= marky_total_records %> records in <%= param('db') %></p>
<%== foil_theme_selector %>
% end
<h1>Tag List: <%= param('db') %></h1>
<%== marky_taglist %>
 
