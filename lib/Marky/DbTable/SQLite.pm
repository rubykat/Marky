package Marky::DbTable::SQLite;

=head1 NAME

Marky::DbTable::SQLite - querying one database table

=head1 VERSION

This describes version 0.1 of Marky::DbTable::SQLite

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Marky::DbTable::SQLite;

=head1 DESCRIPTION

Bookmarking and Tutorial Library application.
Querying one database table, returning result.

=cut

use parent "Marky::DbTable";
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

=head1 METHODS

=head1 Helper Functions

These are functions which are NOT exported by this plugin.

=cut

=head2 _set_defaults

Set the defaults for the object if they are not defined already.

=cut
sub _set_defaults {
    my $self = shift;
    my $conf = shift;

    $self->SUPER::_set_defaults($conf);
    return $self;

} # _set_defaults

=head2 _connect

Connect to the database
If we've already connected, do nothing.

=cut

sub _connect {
    my $self = shift;

    my $old_dbh = $self->{dbh};
    if ($old_dbh)
    {
        return 1;
    }

    # The database is either a DSN (data source name)
    # or a file name. If it's a file name, assume it's SQLite
    my $database = $self->{database};
    if ($database)
    {
        my $dsn = $database;
        my $user = $self->{user};
        my $pw = $self->{password};
        if (-f $database)
        {
            $dsn = "dbi:SQLite:dbname=$database";
        }
        my $dbh = DBI->connect($dsn, $user, $pw);
        if (!$dbh)
        {
            $self->{error} = "Can't connect to $database $DBI::errstr";
            return 0;
        }
        $self->{dbh} = $dbh;
    }
    else
    {
	$self->{error} = "No Database given." . Dump($self);
        return 0;
    }

    return 1;
} # _connect

=head2 _search

Search the database;
returns the total, the query, and the results for the current page.

$hashref = $dbtable->_search(
q=>$query_string,
tags=>$tags,
p=>$p,
n=>$items_per_page,
sort_by=>$order_by,
);

=cut

sub _search {
    my $self = shift;
    my %args = @_;

    my $dbh = $self->{dbh};

    # first find the total
    my $q = $self->_query_to_sql(%args,get_total=>1);
    my $sth = $dbh->prepare($q);
    if (!$sth)
    {
        $self->{error} = "FAILED to prepare '$q' $DBI::errstr";
        return undef;
    }
    my $ret = $sth->execute();
    if (!$ret)
    {
        $self->{error} = "FAILED to execute '$q' $DBI::errstr";
        return undef;
    }
    my @ret_rows=();
    my $total = 0;
    my @row;
    while (@row = $sth->fetchrow_array)
    {
        $total = $row[0];
    }
    my $num_pages = 1;
    if ($args{n})
    {
        $num_pages = ceil($total / $args{n});
        $num_pages = 1 if $num_pages < 1;
    }

    if ($total > 0)
    {
        $q = $self->_query_to_sql(%args,total=>$total);
        $sth = $dbh->prepare($q);
        if (!$sth)
        {
            $self->{error} = "FAILED to prepare '$q' $DBI::errstr";
            return undef;
        }
        $ret = $sth->execute();
        if (!$ret)
        {
            $self->{error} = "FAILED to execute '$q' $DBI::errstr";
            return undef;
        }

        while (my $hashref = $sth->fetchrow_hashref)
        {
            push @ret_rows, $hashref;
        }
    }
    return {rows=>\@ret_rows,
        total=>$total,
        num_pages=>$num_pages,
        sql=>$q};
} # _search

=head2 _total_records

Find the total records in the database.

$dbtable->_total_records();

=cut

sub _total_records {
    my $self = shift;

    my $dbh = $self->{dbh};

    my $q = $self->_query_to_sql(get_total=>1);

    my $sth = $dbh->prepare($q);
    if (!$sth)
    {
        $self->{error} = "FAILED to prepare '$q' $DBI::errstr";
        return undef;
    }
    my $ret = $sth->execute();
    if (!$ret)
    {
        $self->{error} = "FAILED to execute '$q' $DBI::errstr";
        return undef;
    }
    my $total = 0;
    my @row;
    while (@row = $sth->fetchrow_array)
    {
        $total = $row[0];
    }
    return $total;
} # _total_records

=head2 _build_where

Build (part of) a WHERE condition

$where_cond = $dbtable->build_where(
    q=>$query_string,
    field=>$field_name,
);

=cut

sub _build_where {
    my $self = shift;
    my %args = @_;
    my $field = $args{field};
    my $query_string = $args{q};
    
    # no query, no WHERE
    if (!$query_string)
    {
        return '';
    }

    my $sql_where = '';

    # If there is no field, it is a simple query string;
    # the simple query string will search all columns in OR fashion
    # that is (col1 GLOB term OR col2 GLOB term...) etc
    # only allow for '-' prefix, not the complex Search::Query stuff
    # Note that if this is a NOT term, the query clause needs to be
    # (col1 NOT GLOB term AND col2 NOT GLOB term)
    # and checking for NULL too
    if (!$field)
    {
        my @and_clauses = ();
        my @terms = split(/[ +]/, $query_string);
        for (my $i=0; $i < @terms; $i++)
        {
            my $term = $terms[$i];
            my $not = 0;
            if ($term =~ /^-(.*)/)
            {
                $term = $1;
                $not = 1;
            }
            if ($not) # negative term, match NOT AND
            {
                my @and_not_clauses = ();
                foreach my $col (@{$self->{columns}})
                {
                    my $clause = sprintf('(%s IS NULL OR %s NOT GLOB "*%s*")', $col, $col, $term);
                    push @and_not_clauses, $clause;
                }
                push @and_clauses, "(" . join(" AND ", @and_not_clauses) . ")";
            }
            else # positive term, match OR
            {
                my @or_clauses = ();
                foreach my $col (@{$self->{columns}})
                {
                    my $clause = sprintf('%s GLOB "*%s*"', $col, $term);
                    push @or_clauses, $clause;
                }
                push @and_clauses, "(" . join(" OR ", @or_clauses) . ")";
            }
        }
        $sql_where = join(" AND ", @and_clauses);
    }
    elsif ($field eq 'tags'
            or $field eq $self->{tagfield})
    {
        my $tagfield = $self->{tagfield};
        my @and_clauses = ();
        my @terms = split(/[ +]/, $query_string);
        for (my $i=0; $i < @terms; $i++)
        {
            my $term = $terms[$i];
            my $not = 0;
            my $equals = 1; # make tags match exactly by default
            if ($term =~ /^-(.*)/)
            {
                $term = $1;
                $not = 1;
            }
            # use * for a glob marker
            if ($term =~ /^\*(.*)/)
            {
                $term = $1;
                $equals = 0;
            }
            if ($not and !$equals)
            {
                my $clause = sprintf('(%s IS NULL OR %s NOT GLOB "*%s*")', $tagfield, $tagfield, $term);
                push @and_clauses, $clause;
            }
            elsif ($not and $equals) # negative term, match NOT AND
            {
                my $clause = sprintf('(%s IS NULL OR (%s != "%s" AND %s NOT GLOB "%s|*" AND %s NOT GLOB "*|%s|*" AND %s NOT GLOB "*|%s"))',
                    $tagfield,
                    $tagfield, $term,
                    $tagfield, $term,
                    $tagfield, $term,
                    $tagfield, $term,
                );
                push @and_clauses, $clause;
            }
            elsif ($equals) # positive term, match OR
            {
                my $clause = sprintf('(%s = "%s" OR %s GLOB "%s|*" OR %s GLOB "*|%s|*" OR %s GLOB "*|%s")',
                    $tagfield, $term,
                    $tagfield, $term,
                    $tagfield, $term,
                    $tagfield, $term,
                );
                push @and_clauses, $clause;
            }
            else 
            {
                my $clause = sprintf('%s GLOB "*%s*"', $tagfield, $term);
                push @and_clauses, $clause;
            }
        }
        $sql_where = join(" AND ", @and_clauses);
    }
    else # other columns
    {
        my $parser = Search::Query->parser(
            query_class => 'SQL',
            query_class_opts => {
                like => 'GLOB',
                wildcard => '*',
                fuzzify2 => 1,
            },
            null_term => 'NULL',
            default_field => $field,
            default_op => '~',
            fields => [$field],
            );
        my $query  = $parser->parse($args{q});
        $sql_where = $query->stringify;
    }

    return ($sql_where ? "(${sql_where})" : '');
} # _build_where

=head2 _query_to_sql

Convert a query string to an SQL select statement
While this leverages on Select::Query, it does its own thing
for a generic query and for a tags query

$sql = $dbtable->_query_to_sql(
q=>$query_string,
tags=>$tags,
p=>$p,
n=>$items_per_page,
sort_by=>$order_by,
sort_by2=>$order_by2,
sort_by3=>$order_by3,
);

=cut

sub _query_to_sql {
    my $self = shift;
    my %args = @_;

    my $p = $args{p};
    my $items_per_page = $args{n};
    my $total = ($args{total} ? $args{total} : 0);
    my $order_by = '';
    if ($args{sort_by} and $args{sort_by2} and $args{sort_by3})
    {
        $order_by = join(', ', $args{sort_by}, $args{sort_by2}, $args{sort_by3});
    }
    elsif ($args{sort_by} and $args{sort_by2})
    {
        $order_by = join(', ', $args{sort_by}, $args{sort_by2});
    }
    elsif ($args{sort_by})
    {
        $order_by = $args{sort_by};
    }
    else
    {
        $order_by = join(', ', @{$self->{default_sort}});
    }

    my $offset = 0;
    if ($p and $items_per_page)
    {
        $offset = ($p - 1) * $items_per_page;
        if ($total > 0 and $offset >= $total)
        {
            $offset = $total - 1;
        }
        elsif ($offset <= 0)
        {
            $offset = 0;
        }
    }

    my @and_clauses = ();
    foreach my $col (@{$self->{columns}})
    {
        if ($args{$col})
        {
            my $clause = $self->_build_where(field=>$col, q=>$args{$col});
            push @and_clauses, $clause;
        }
    }
    if ($args{'tags'} and $self->{tagfield} ne 'tags')
    {
        my $clause = $self->_build_where(field=>'tags', q=>$args{'tags'});
        push @and_clauses, $clause;
    }

    if ($args{q})
    {
        my $clause = $self->_build_where(field=>'', q=>$args{q});
        push @and_clauses, $clause;
    }
    # if there's an extra condition in the configuration, add it here
    if ($self->{extra_cond})
    {
        if (@and_clauses)
        {
            push @and_clauses, "(" . $self->{extra_cond} . ")";
        }
        else
        {
            push @and_clauses, $self->{extra_cond};
        }
    }
    my $sql_where = join(" AND ", @and_clauses);

    my $q = '';
    if ($args{get_total})
    {
        $q = "SELECT COUNT(*) FROM " . $self->{table};
        $q .= " WHERE $sql_where" if $sql_where;
    }
    else
    {
        $q = "SELECT * FROM " . $self->{table};
        $q .= " WHERE $sql_where" if $sql_where;
        $q .= " ORDER BY $order_by" if $order_by;
        $q .= " LIMIT $items_per_page" if $items_per_page;
        $q .= " OFFSET $offset" if $offset;
    }

    return $q;
} # _query_to_sql

1; # End of Marky::DbTable::SQLite
__END__
