package Marky::DbTable::Xapian;

=head1 NAME

Marky::DbTable::Xapian - querying one database table

=head1 VERSION

This describes version 0.1 of Marky::DbTable::Xapian

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Marky::DbTable::Xapian;

=head1 DESCRIPTION

Bookmarking and Tutorial Library application.
Querying one database table, returning result.

=cut

use parent "Marky::DbTable";
use common::sense;
use YAML::Any;
use Search::Xapian qw/:standard/; 

use Sort::Naturally;
use Text::NeatTemplate;
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

    if (!-d $self->{database})
    {
        die "Xapian database must be a directory";
    }

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

    # The database given as the directory where the database resides.
    my $database = $self->{database};
    if (-d $database)
    {
        my $dbh = Search::Xapian::Database->new( $database );
        if (!$dbh)
        {
            $self->{error} = "Can't connect to $database $?";
            return 0;
        }
        $self->{dbh} = $dbh;
        my $qp = new Search::Xapian::QueryParser( $dbh );
        $qp->set_stemmer(new Search::Xapian::Stem("english"));
        $qp->set_default_op(OP_AND);
        $self->{query_parser} = $qp;
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
    my $qparser = $self->{query_parser};
    my $enquire = Search::Xapian::Enquire->new($dbh);
    my $q = $args{q};
    if ($args{tags})
    {
        my @terms = split(/[ +]/, $args{tags});
        foreach my $t (@terms)
        {
            $q += " keywords=$t";
        }
        $q =~ s/^\s//;
        $q =~ s/\s$//;
    }
    if ($q)
    {
        $enquire->set_query($qparser->parse_query($q));
    }
    else
    {
        $enquire->set_query(Search::Xapian::Query::MatchAll());
    }
    ##$enquire->set_sort_by_value($sort_by, $rsort) if defined $sort_by;

    my $max = ($args{n} ? $args{n} : $self->{default_limit});
    my $mset = $enquire->get_mset(0, $max);
    my $total = $mset->get_matches_estimated();

    my @ret_rows=();
    my $num_pages = 1;
    if ($args{n})
    {
        $num_pages = ceil($total / $args{n});
        $num_pages = 1 if $num_pages < 1;
    }

    if ($total > 0)
    {
        foreach my $m ($mset->items()) {
            my $data_str = $m->get_document()->get_data();
            my $vals = {};
            # data is key=value pairs
            while($data_str =~ /(\w+)=([^\n]+)\n?/g)
            {
                my $key = $1;
                my $val = $2;
                $vals->{$key} = $val;
                # fix up abs file urls
                if ($key eq 'url'
                        and $val =~ /file:/)
                {
                    my $relurl = $val;
                    $relurl =~ s!file://!!;
                    $relurl =~ s!^.*/contents/!!;
                    $vals->{relurl} = $relurl;
                }
            }
            push @ret_rows, $vals;
        }
    }
    return {rows=>\@ret_rows,
        total=>$total,
        num_pages=>$num_pages,
        sql=>$enquire->get_query()->get_description()};
} # _search

=head2 _total_records

Find the total records in the database.

$dbtable->_total_records();

=cut

sub _total_records {
    my $self = shift;

    my $dbh = $self->{dbh};
    my $qparser = $self->{query_parser};
    my $enquire = Search::Xapian::Enquire->new($dbh);
    $enquire->set_query(Search::Xapian::Query::MatchAll());
    my $mset = $enquire->get_mset(0, 1);
    my $total = $mset->get_matches_estimated();

    return $total;
} # _total_records

1; # End of Marky::DbTable::Xapian
__END__
