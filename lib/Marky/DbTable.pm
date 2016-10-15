package Marky::DbTable;

=head1 NAME

Marky::DbTable - querying one database table, base class

=head1 VERSION

This describes version 0.1 of Marky::DbTable

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Marky::DbTable;;

=head1 DESCRIPTION

Bookmarking and Tutorial Library application.
Querying one database table, returning result.

=cut

use common::sense;
use Sort::Naturally;
use Text::NeatTemplate;
use HTML::TagCloud;

=head1 METHODS

=head2 new

Create a new object, setting global values for the object.

    my $obj = Marky::DbTable->new(
        database=>$database);

=cut

sub new {
    my $class = shift;
    my %parameters = (@_);
    my $self = bless ({%parameters}, ref ($class) || $class);

    $self->_set_defaults();

    return ($self);
} # new

=head2 query_raw

Query the database, return an array of results.

$results = $dbtable->query_raw($sql);

=cut

sub query_raw {
    my $self = shift;
    my %args = @_;

    if (!$self->_connect())
    {
        return undef;
    }

    my $data = $self->_search(%args);
    return $data;
} # query_raw

=head2 query

Query the database, return results and query-tags.

$results = $dbtable->query(
    location=>$base_url,
    %args);

=cut

sub query {
    my $self = shift;
    my %args = @_;

    if (!$self->_connect())
    {
        return undef;
    }

    return $self->_process_request(%args);
} # query

=head2 taglist

Query the database, return a taglist

=cut

sub taglist {
    my $self = shift;
    my %args = @_;

    if (!$self->_connect())
    {
        return undef;
    }

    return $self->_process_taglist(%args);
} # taglist

=head2 tagcloud

Query the database, return a tagcloud.

=cut

sub tagcloud {
    my $self = shift;
    my %args = @_;

    if (!$self->_connect())
    {
        return undef;
    }

    return $self->_process_tagcloud(%args);
} # tagcloud

=head2 total_records

Query the database, return the total number of records.

=cut

sub total_records {
    my $self = shift;
    my %args = @_;

    if (!$self->_connect())
    {
        return undef;
    }

    return $self->_total_records(%args);
} # total_records

=head2 what_error

There was an error, what was it?

=cut

sub what_error {
    my $self = shift;
    my %args = @_;

    return $self->{error};
} # what_error

=head1 Helper Functions

These are functions which are NOT exported by this plugin.

=cut

=head2 _set_defaults

Set the defaults for the object if they are not defined already.

=cut
sub _set_defaults {
    my $self = shift;
    my $conf = shift;

    foreach my $key (keys %{$conf})
    {
        if (defined $conf->{$key})
        {
            $self->{$key} = $conf->{$key};
        }
    }

    $self->{user} = '' if !defined $self->{user};
    $self->{password} = '' if !defined $self->{password};

    if (!defined $self->{database} or $self->{database} eq '')
    {
        die "No database given";
    }
    if (!defined $self->{table})
    {
        die "No table given";
    }
    if (!defined $self->{columns})
    {
        die "No columns given";
    }
    if (!defined $self->{sort_columns})
    {
        $self->{sort_columns} = $self->{columns};
    }
    $self->{tagfield} = 'tags' if !defined $self->{tagfield};
    $self->{default_limit} = 100 if !defined $self->{default_limit};

    if (!defined $self->{row_template})
    {
        $self->{row_template} =<<'EOT';
<li>
<div class="linkcontainer">
<span class="linktitle">{$title}</span>
<div class="linkdescription">
{?description [$description:html]}
</div>
{?all_tags <div class="linktaglist">[$all_tags]</div>}
</div>
</li>
EOT
    }

    if (!defined $self->{tags_template})
    {
        $self->{tags_template} =<<'EOT';
<a href="{$url}/{?tags_query [$tags_query]}{?qquery ?[$qquery]}" class="tag {?not_in_list button}">{?not_in_list <span class="fa fa-tag"></span>} {$tag}{?num_tags  ([$num_tags])}</a>
EOT
    }
    if (!defined $self->{tag_query_template})
    {
        $self->{tag_query_template} =<<'EOT';
<a title="Remove tag" href="{$url}/{?tags_query [$tags_query]}?deltag={$tag}{?q &q=[$q]}{?p &p=[$p]}" class="tag button"><span class="fa fa-tag"></span> {$tag} <span class="remove fa fa-remove"></span></a>
EOT
    }
    if (!defined $self->{q_query_template})
    {
        $self->{q_query_template} =<<'EOT';
<a title="Remove term" href="{$url}/{?tags_query tags/[$tags_query]}?delterm={$qterm}{?q &q=[$q]}{?p &p=[$p]}" class="tag button"><span class="fa fa-question"></span> {$qterm} <span class="remove fa fa-close"></span></a>
EOT
    }
    if (!defined $self->{results_template})
    {
        $self->{results_template} =<<'EOT';
{?searchform [$searchform]}
{?pagination [$pagination]}
{?total <p>[$total] records found. Page [$p] of [$num_pages].</p>}
{?query <div class="query">[$query]</div>}
{?sql <p class="sql">[$sql]</p>}
{?result <div class="results fancy">[$result]</div>}
EOT
    }
    if (!defined $self->{pagination_template})
    {
        $self->{pagination_template} =<<'EOT';
<div class="pagination">
<span class="prev">{?prev_page <a title="Prev" class="prevnext" href="[$location]/[$tq]?p=[$prev_page]&q=[$q]">}<span class="fa fa-chevron-left"></span> Prev{?prev_page </a>}</span>
<span class="next">{?next_page <a title="Next" href="[$location]/[$tq]?p=[$next_page]&q=[$q]">}Next <span class="fa fa-chevron-right"></span>{?next_page </a>}</span>
</div>
EOT
    }
    if (!defined $self->{searchform})
    {
        $self->{searchform} =<<'EOT';
<div class="searchform">
<form class="searcher" action="{$action}">
<span class="textin"><label class="fa fa-question">Any:</label> <input type="text" name="q" value="{$q}"/></span>
<span class="textin"><label class="fa fa-tags">Tags:</label> <input type="text" name="tags" value="{$tags}"></span>
<span class="selector"><label>Pg:</label> {$selectP}</span>
<input type="submit" value="Search">
</form>
<form class="setter" action="{$opt_url}">
<span class="selector"><label>N:</label> {$selectN}</span>
<span class="selector"><label>Sort:</label> {$sorting}</span>
<input type="submit" value="Set">
</form></div>
EOT
    }
    return $self;

} # _set_defaults

=head2 _connect

Connect to the database
EMPTY BASE METHOD

=cut

sub _connect {
    my $self = shift;

    return undef;
} # _connect

=head2 _search

Query the database, return an array of results.
EMPTY BASE METHOD

=cut

sub _search {
    my $self = shift;
    my $q = shift;

    return undef;
} # _search

=head2 _process_request

Process the request, return HTML
Note that if there are no query-strings, it will return ALL the results.
It's so annoying to have a search-engine which barfs at empty searches.

$dbtable->_process_request(%args);

=cut

sub _process_request {
    my $self = shift;
    my %args = @_;

    my $dbh = $self->{dbh};
    my $location = $args{location};
    $args{n} = 20 if !defined $args{n};
    my $tobj = Text::NeatTemplate->new();

    my $data = $self->_search(
        %args
    );
    if (!defined $data)
    {
        return undef;
    }

    my $searchform = $self->_format_searchform(
        %args,
        data=>$data,
    );
    my $pagination = $self->_format_pagination(
        %args,
        data=>$data,
    );
    my $result = $self->_format_rows(
        %args,
        rows=>$data->{rows},
        total=>$data->{total},
        tags_query=>$args{tags},
        tags_action=>"$location/tags",
    );
    my %all_tags = $self->_create_taglist(
        rows=>$data->{rows},
        total=>$data->{total},
    );
    my $query_tags = $self->_format_taglist(
        %args,
        all_tags=>\%all_tags,
        tags_query=>$args{tags},
        tags_action=>"$location/tags",
    );
    my $tquery_str = $self->_format_tag_query(
        %args,
        tags_query=>$args{tags},
        tags_action=>"$location/tags");
    my $qquery_str = $self->_format_q_query(
        %args,
        tags_query=>$args{tags},
        action=>$location);
    my $query_str = join(' ', $tquery_str, $qquery_str);
    my $html = $tobj->fill_in(
        data_hash=>{
            %args,
            p=>($args{p} ? $args{p} : 1),
            sql=>($args{show_sql} ? $data->{sql} : ''),
            query=>$query_str,
            result=>$result,
            total=>$data->{total},
            num_pages=>$data->{num_pages},
            searchform=>$searchform,
            pagination=>$pagination,
        },
        template=>$self->{results_template},
    );

    return { results=>$html,
        query_tags=>$query_tags,
        searchform=>$searchform,
        pagination=>$pagination,
        total=>$data->{total},
        num_pages=>$data->{num_pages},
    };
} # _process_request

=head2 _process_taglist

Process the request, return HTML of all the tags.

$dbtable->_process_taglist(%args);

=cut

sub _process_taglist {
    my $self = shift;
    my %args = @_;

    my $dbh = $self->{dbh};
    my $location = $args{location};
    $args{n} = 20 if !defined $args{n};
    my $tobj = Text::NeatTemplate->new();

    my $data = $self->_search(
        %args
    );

    my %all_tags = $self->_create_taglist(
        rows=>$data->{rows},
        total=>$data->{total},
    );
    my $count = keys %all_tags;
    my $query_tags = $self->_format_taglist(
        %args,
        all_tags=>\%all_tags,
        total_tags=>$count,
        tags_query=>$args{tags},
        tags_action=>"$location/tags",
    );

    return { results=>$query_tags,
        query_tags=>$query_tags,
        total=>$data->{total},
        total_tags=>$count,
        num_pages=>$data->{num_pages},
    };
} # _process_taglist

=head2 _process_tagcloud

Process the request, return HTML of all the tags.

$dbtable->_process_tagcloud(%args);

=cut

sub _process_tagcloud {
    my $self = shift;
    my %args = @_;

    my $dbh = $self->{dbh};
    my $location = $args{location};
    $args{n} = 20 if !defined $args{n};
    my $tobj = Text::NeatTemplate->new();

    my $data = $self->_search(
        %args
    );

    my %all_tags = $self->_create_taglist(
        rows=>$data->{rows},
        total=>$data->{total},
    );
    my $count = keys %all_tags;
    my $query_tags = $self->_format_taglist(
        %args,
        all_tags=>\%all_tags,
        tags_query=>$args{tags},
        tags_action=>"$location/tags",
    );
    my $tagcloud = $self->_format_tagcloud(
        %args,
        all_tags=>\%all_tags,
        tags_query=>$args{tags},
        tags_action=>"$location/tags",
    );

    return { results=>$tagcloud,
        query_tags=>$query_tags,
        total=>$data->{total},
        total_tags=>$count,
        num_pages=>$data->{num_pages},
    };
} # _process_tagcloud

=head2 _total_records

Find the total records in the database.
EMPTY BASE METHOD

=cut

sub _total_records {
    my $self = shift;

    return undef;
} # _total_records

=head2 _format_searchform

Format an array of results hashrefs into HTML

$result = $self->_format_searchform(
    total=>$total,
    tags_query=>$tags_query,
    location=>$action_url);

=cut

sub _format_searchform {
    my $self = shift;
    my %args = @_;

    my $data = $args{data};
    my $location = $args{location};
    my $tobj = Text::NeatTemplate->new();

    my $selectN = '';
    my @os = ();
    push @os, '<select name="n">';
    foreach my $limit (qw(10 20 50 100))
    {
        if ($limit == $args{n})
        {
            push @os, "<option value='$limit' selected>$limit</option>";
        }
        else
        {
            push @os, "<option value='$limit'>$limit</option>";
        }
    }
    push @os, '</select>';
    $selectN = join("\n", @os);

    my $total = $data->{total};
    my $num_pages = $data->{num_pages};
    if ($args{p} > $num_pages)
    {
        $args{p} = 1;
    }

    my $selectP = '';
    @os = ();
    push @os, '<select name="p">';
    for (my $p = 1; $p <= $num_pages; $p++)
    {
        if ($p == $args{p})
        {
            push @os, "<option value='$p' selected>$p</option>";
        }
        else
        {
            push @os, "<option value='$p'>$p</option>";
        }
    }
    push @os, '</select>';
    $selectP = join("\n", @os);

    my $db = $args{db};
    my $sorting = '';
    @os = ();
    foreach my $sf (qw(sort_by sort_by2 sort_by3))
    {
        push @os, "<select name='${db}_$sf'>";
        push @os, "<option value=''> </option>";
        foreach my $s (sort @{$self->{sort_columns}})
        {
            if ($s eq $args{$sf})
            {
                push @os, "<option value='$s' selected>$s</option>";
            }
            else
            {
                push @os, "<option value='$s'>$s</option>";
            }
            my $s_desc = "${s} DESC";
            if ($s_desc eq $args{$sf})
            {
                push @os, "<option value='$s_desc' selected>$s_desc</option>";
            }
            else
            {
                push @os, "<option value='$s_desc'>$s_desc</option>";
            }
        }
        push @os, '</select>';
    }
    $sorting = join("\n", @os);

    my $searchform = $tobj->fill_in(
        data_hash=>{
            %args,
            action=>$location,
            selectN=>$selectN,
            selectP=>$selectP,
            sorting=>$sorting,
        },
        template=>$self->{searchform},
    );

    return $searchform;
} # _format_searchform

=head2 _format_pagination

Format the prev/next links.

$result = $self->_format_pagination(
    total=>$total,
    tags_query=>$tags_query,
    location=>$action_url);

=cut

sub _format_pagination {
    my $self = shift;
    my %args = @_;

    my $data = $args{data};
    my $location = $args{location};
    my $tobj = Text::NeatTemplate->new();

    my $total = $data->{total};
    my $num_pages = $data->{num_pages};
    if ($args{p} > $num_pages)
    {
        $args{p} = $num_pages;
    }
    if ($args{p} < 1)
    {
        $args{p} = 1;
    }
    my $prev_page = $args{p} - 1;
    if ($prev_page < 1)
    {
        $prev_page = 0;
    }
    my $next_page = $args{p} + 1;
    if ($next_page > $num_pages)
    {
        $next_page = 0;
    }
    my $tq = '';
    if ($args{tags})
    {
        $tq = 'tags/' . $args{tags};
    }

    my $pagination = $tobj->fill_in(
        data_hash=>{
            %args,
            tq=>$tq,
            prev_page=>$prev_page,
            next_page=>$next_page,
        },
        template=>$self->{pagination_template},
    );

    return $pagination;
} # _format_pagination

=head2 _format_rows

Format an array of results hashrefs into HTML

$result = $self->_format_rows(
    rows=>$result_arrayref,
    total=>$total,
    tags_query=>$tags_query,
    tags_action=>$action_url);

=cut

sub _format_rows {
    my $self = shift;
    my %args = @_;

    my @rows = @{$args{rows}};
    my $total = $args{total};

    my @out = ();
    push @out, '<ul>';
    my $tobj = Text::NeatTemplate->new();
    foreach my $row_hash (@rows)
    {
        # format the tags, then format the row
        my @tags = split(/\|/, $row_hash->{$self->{tagfield}});
        my $tags_str = $self->_format_tag_collection(
            %args,
            in_list=>0,
            tags_array=>\@tags);
        $row_hash->{all_tags} = $tags_str;
        my $text = $tobj->fill_in(data_hash=>$row_hash,
                                  template=>$self->{row_template});
        push @out, $text;
    }
    push @out, "</ul>\n";

    my $results = join("\n", @out);

    return $results;
} # _format_rows

=head2 _create_taglist

Count up all the tags in the results.

%all_tags = $self->_create_taglist(
    rows=>$result_arrayref);

=cut

sub _create_taglist {
    my $self = shift;
    my %args = @_;

    my @rows = @{$args{rows}};

    my %all_tags = ();
    foreach my $row_hash (@rows)
    {
        # iterate over the tags
        my @tags = split(/\|/, $row_hash->{$self->{tagfield}});
        foreach my $tag (@tags)
        {
            if ($tag)
            {
                $all_tags{$tag}++;
            }
        }
    }
    return %all_tags;
} # _create_taglist

=head2 _format_tagcloud

Format a hash of tags into HTML

$tagcloud = $dbtable->_format_tagcloud(
    all_tags=>\%all_tags,
    tags_query=>$tags_query,
    tags_action=>$action_url);

=cut

sub _format_tagcloud {
    my $self = shift;
    my %args = @_;

    my $cloud = HTML::TagCloud->new(levels=>30);
    my @out = ();
    push @out, '<div id="tagcloud">';
    foreach my $tag (nsort keys %{$args{all_tags}})
    {
        my $tq = '';
        if (!$args{tags_query})
        {
            $tq = $tag;
        }
        elsif ($args{tags_query} =~ /\Q$tag\E/)
        {
            # this tag is already in the query
            $tq = $args{tags_query};
        }
        else
        {
            $tq = "$args{tags_query}+${tag}";
        }
        my $tag_url = "$args{location}/tags/$tq";
        $cloud->add($tag, $tag_url, $args{all_tags}->{$tag});
    }
    my $tc = $cloud->html_and_css();
    push @out, $tc;
    push @out, "</div>\n";

    my $taglist = join("\n", @out);

    return $taglist;
} # _format_tagcloud

=head2 _format_taglist

Format a hash of tags into HTML

$taglist = $dbtable->_format_taglist(
    all_tags=>\%all_tags,
    tags_query=>$tags_query,
    tags_action=>$action_url);

=cut

sub _format_taglist {
    my $self = shift;
    my %args = @_;

    my @out = ();
    push @out, '<div id="alltags">';
    if (exists $args{total_tags}
            and defined $args{total_tags}
            and $args{total_tags})
    {
        push @out, "<p>Tag-count: $args{total_tags}</p>";
    }
    push @out, "<ul id='listtag'>\n";
    my $tl = $self->_format_tag_collection(
        %args,
        in_list=>1,
    );
    push @out, $tl;
    push @out, "</ul>\n";
    push @out, "</div>\n";

    my $taglist = join("\n", @out);

    return $taglist;
} # _format_taglist

=head2 _format_tag_collection

Format an array of tags into HTML

$taglist = $dbtable->_format_tag_collection(
    in_list=>0,
    all_tags=>\%all_tags,
    tags_array=>\@tags,
    tags_query=>$tags_query,
    tags_action=>$action_url);

=cut

sub _format_tag_collection {
    my $self = shift;
    my %args = @_;

    my $tags_query = $args{tags_query};
    my $tags_action = $args{tags_action};
    my @tags = ($args{all_tags} ? nsort keys %{$args{all_tags}} : nsort @{$args{tags_array}});
    my $qquery = '';
    my @qq = ();
    push @qq, "q=$args{q}" if $args{q};
    push @qq, "p=$args{p}" if $args{p};
    my $qquery = join('&', @qq);

    my $tobj = Text::NeatTemplate->new();
    my @out = ();
    foreach my $tag (@tags)
    {
        my $tq = '';
        if (!$tags_query)
        {
            $tq = $tag;
        }
        elsif ($tags_query =~ /\Q$tag\E/)
        {
            # this tag is already in the query
            $tq = $tags_query;
        }
        else
        {
            $tq = "${tags_query}+${tag}";
        }
        push @out, "<li>" if $args{in_list};
        push @out, $tobj->fill_in(data_hash=>{tag=>$tag,
            num_tags=>(defined $args{all_tags} ? $args{all_tags}->{$tag} : undef),
            in_list=>$args{in_list},
            not_in_list=>!$args{in_list},
            tags_query=>$tq,
            qquery=>$qquery,
            url=>$tags_action},
            template=>$self->{tags_template});
        push @out, "</li>\n" if $args{in_list};
    }

    my $taglist = join("\n", @out);

    return $taglist;
} # _format_tag_collection

=head2 _format_tag_query

Format a tag query into components which can be removed from the query

$tagq_str = $dbtable->_format_tag_query(
    tags_query=>$tags_query,
    tags_action=>$action_url);

=cut

sub _format_tag_query {
    my $self = shift;
    my %args = @_;

    my $tags_query = $args{tags_query};
    my $tags_action = $args{tags_action};
    my @terms = split(/[ +]/, $tags_query);

    my $tobj = Text::NeatTemplate->new();
    my @out = ();
    foreach my $tag (@terms)
    {
        my $tq = '';
        if (!$tags_query)
        {
            $tq = $tag;
        }
        elsif ($tags_query =~ /\Q$tag\E/)
        {
            # this tag is already in the query
            $tq = $tags_query;
        }
        else
        {
            $tq = "${tags_query}+${tag}";
        }
        push @out, $tobj->fill_in(data_hash=>{
                %args,
                tag=>$tag,
                tags_query=>$tq,
                url=>$tags_action},
            template=>$self->{tag_query_template});
    }

    my $taglist = join("\n", @out);

    return $taglist;
} # _format_tag_query

=head2 _format_q_query

Format a q query into components which can be removed from the query

$tagq_str = $dbtable->_format_q_query(
    q=>$q,
    tags_query=>$tags_query,
    action=>$action_url);

=cut

sub _format_q_query {
    my $self = shift;
    my %args = @_;

    if (!$args{q})
    {
        return '';
    }
    my @terms = split(/[ +]/, $args{q});

    my $tobj = Text::NeatTemplate->new();
    my @out = ();
    foreach my $term (@terms)
    {
        push @out, $tobj->fill_in(data_hash=>{
                %args,
                qterm=>$term,
                tags_query=>$args{tags_query},
                qquery=>$args{q},
                url=>$args{action}},
            template=>$self->{q_query_template});
    }

    my $qlist = join("\n", @out);

    return $qlist;
} # _format_q_query

1; # End of Marky::DbTable
__END__
