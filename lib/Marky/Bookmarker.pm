package Marky::Bookmarker;

=head1 NAME

Marky::Bookmarker - adding bookmarks

=head1 VERSION

This describes version 0.1 of Marky::Bookmarker

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Marky::Bookmarker;

=head1 DESCRIPTION

Bookmarking and Tutorial Library application.
Adding bookmarks.
These are YAML files added to a designated Bookmarks directory,
where they can then be added to the database by stickerx.

=cut

use common::sense;
use File::Serialize;
use Path::Tiny;
use Text::NeatTemplate;
use POSIX qw(strftime);
use IPC::System::Simple qw(run EXIT_ANY);

=head1 METHODS

=head2 new

Create a new object, setting global values for the object.

    my $obj = Marky::Bookmarker->new(
        database=>$database);

=cut

sub new {
    my $class = shift;
    my %parameters = (@_);
    my $self = bless ({%parameters}, ref ($class) || $class);

    $self->_set_defaults();

    return ($self);
} # new

=head2 fields

Add a new bookmark

my @fields = $bookm->fields();

=cut

sub fields {
    my $self = shift;

    my @fields = @{$self->{fields}};
    return @fields;
} # fields

=head2 save_new_bookmark

Add a new bookmark

$results = $bookm->save_new_bookmark(data=>\%hash);

=cut

sub save_new_bookmark {
    my $self = shift;
    my %args = @_;

    return $self->_save_new_bookmark(%args);
} # save_new_bookmark

=head2 bookmark_form

Return a form for the bookmark

my $form = $bookm->bookmark_form(action=>$url);

=cut

sub bookmark_form {
    my $self = shift;
    my %args = @_;

    return $self->_add_bookmark_form(%args);
} # bookmark_form

=head2 bookmarklet

Return a bookmarklet

my $bm = $bookm->bookmarklet(action=>$url);

=cut

sub bookmarklet {
    my $self = shift;
    my %args = @_;

    return $self->_make_bookmarklet(%args);
} # bookmarklet


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

    if (!-d $self->{bookmark_dir})
    {
        die "No bookmark dir at " . $self->{bookmark_dir};
    }
    if (!defined $self->{fields})
    {
        die "No fields given";
    }
    if (!defined $self->{titlefield})
    {
        $self->{titlefield} = 'title';
    }
    $self->{timestampfield} = '' if !defined $self->{timestampfield};

    if (!defined $self->{editform_template})
    {
        $self->{editform_template} =<<'EOT';
<div class="editform">
<form action="{$action}" method="post">
EOT
        foreach my $col (@{$self->{fields}})
        {
            if ($col =~ /(description|summary)/i)
            {
                $self->{editform_template} .=<<"EOT";
<div class="item">
<label>$col</label><br/>
<textarea name="$col" rows="4" cols="50">
{\$${col}}
</textarea></div>
EOT
            }
            elsif ($col =~ /tags/i)
            {
                $self->{editform_template} .=<<"EOT";
<div class="item">
<label>$col</label> <input type="text" name="$col" value="{\$${col}}" size="50" {?${col}_datalist list="${col}Datalist"}/>
{?${col}_datalist <datalist id="${col}Datalist">[\$${col}_datalist]</datalist>}
</div>
EOT
            }
            else
            {
                $self->{editform_template} .=<<"EOT";
<div class="item">
<label>$col</label> <input type="text" name="$col" value="{\$${col}}" size="50"/>
</div>
EOT
            }
        }
        $self->{editform_template} .=<<'EOT';
<input type="submit" value="Save">
</form></div>
EOT
    }

    return $self;

} # _set_defaults

=head2 _add_bookmark_form

Create an "add bookmark" form.

$bookm->_add_bookmark_form(action=>$url);

=cut

sub _add_bookmark_form {
    my $self = shift;
    my %args = @_;

    my $tobj = Text::NeatTemplate->new();
    my $datalist_name = '';
    my $datalist_str = '';
    if ($args{tagfield})
    {
        $datalist_name = $args{tagfield} . '_datalist';
        my @tags = @{$args{tag_array}};
        foreach my $tag (@tags)
        {
            $datalist_str .= "<option value='$tag' />\n";
        }
    }
    my $form = $tobj->fill_in(
        data_hash=>{%args,
            $datalist_name=>$datalist_str,
        },
        template=>$self->{editform_template},
    );
    return $form;
} # _add_bookmark_form

=head2 _make_bookmarklet

Create a javascript bookmarklet for adding a bookmark.

my $bml = $bookm->_make_bookmarklet(%args);

=cut

sub _make_bookmarklet {
    my $self = shift;
    my %args = @_;

    my $add_url = $args{action};
    my $titlefield = $self->{titlefield};
    my $bookmarklet =<<"EOT";
<a class="button" onclick="alert('Drag this link to your bookmarks toolbar, or right-click it and choose Bookmark This Link...');return false;" href="javascript:javascript:(function(){var%20bm_url%20=%20location.href;var%20title%20=%20document.title%20||%20bm_url;window.open('${add_url}?url='%20+%20encodeURIComponent(bm_url)+'&amp;${titlefield}='%20+%20encodeURIComponent(title)+'&amp;description='%20+%20encodeURIComponent(document.getSelection())+'&amp;source=bookmarklet','_blank','menubar=no,toolbar=no,dialog=1');})();"><b>✚Marky link</b></a> 
EOT
    return $bookmarklet;
} # _make_bookmarklet

=head2 _construct_filename

Figure out a (unique) name from the given title.

my $fn = $bookm->_construct_filename(title->$title);

=cut

sub _construct_filename ($%) {
    my $self = shift;
    my %args = @_;

    my $title = $args{title};
    my $dir = path($self->{bookmark_dir});

    my $basename = ($title ? $title : 'bookmark');
    $basename =~ s/[^a-zA-Z0-9 ]//g;
    $basename =~ s/\s+/_/g;
    $basename =~ s/_$//;

    # check if a file of the same name already exists
    my @matching_files = $dir->children(qr/^${basename}/);
    my $count = scalar @matching_files;
    if ($count > 0)
    {
        # this gives Foo, Foo002, Foo003
        $basename = sprintf('%s%00d', $basename, $count + 1);
    }

    return "${basename}.yml";
} # _construct_filename

=head2 _save_new_bookmark

Add a new bookmark

$results = $bookm->_save_new_bookmark(data=>\%hash);

=cut

sub _save_new_bookmark {
    my $self = shift;
    my %args = @_;

    my $data = $args{data};
    # if we have a timestamp field, figure its value
    if ($self->{timestampfield})
    {
        my $now = strftime '%Y-%m-%d %H:%M:%S', localtime;
        $data->{$self->{timestampfield}} = $now;
    }

    my $filename = $self->_construct_filename(title=>$data->{$self->{titlefield}});
    my $bm_dir = path($self->{bookmark_dir});
    my $fullname = $bm_dir->child($filename)->stringify;
    serialize_file $fullname => $data;

    if (-x $self->{update_script})
    {
        my $exit_val = run(EXIT_ANY, $self->{update_script}, $fullname);
        if ($exit_val != 0)
        {
            return 0;
        }
    }
    return 1;
} # _save_new_bookmark

1; # End of Marky::Bookmarker
__END__
