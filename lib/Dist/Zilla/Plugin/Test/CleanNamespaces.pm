use strict;
use warnings;
package Dist::Zilla::Plugin::Test::CleanNamespaces;
# ABSTRACT: Generate a test to check that all namespaces are clean
# KEYWORDS: plugin testing namespaces clean dirty imports exports subroutines methods
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '0.007';

use Moose;
with (
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::TextTemplate',
    'Dist::Zilla::Role::PrereqSource',
);
use MooseX::Types::Stringlike 'Stringlike';
use Moose::Util::TypeConstraints 'role_type';
use Path::Tiny;
use namespace::autoclean;

sub mvp_multivalue_args { qw(skips) }
sub mvp_aliases { return { skip => 'skips' } }

has skips => (
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    handles => { skips => 'sort' },
    lazy => 1,
    default => sub { [] },
);

has filename => (
    is => 'ro', isa => Stringlike,
    coerce => 1,
    lazy => 1,
    default => sub { path('xt', 'author', 'clean-namespaces.t') },
);

sub _tcn_prereq { '0.15' }

around dump_config => sub
{
    my ($orig, $self) = @_;
    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        skips => [ $self->skips ],
        filename => $self->filename,
        blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
    };

    return $config;
};

sub register_prereqs
{
    my $self = shift;

    $self->zilla->register_prereqs(
        {
            type  => 'requires',
            phase => $self->filename =~ /^t/ ? 'test' : 'develop',
        },
        'Test::CleanNamespaces' => $self->_tcn_prereq,
    );
}

has _file => (
    is => 'rw', isa => role_type('Dist::Zilla::Role::File'),
);

sub gather_files
{
    my $self = shift;

    require Dist::Zilla::File::InMemory;
    $self->add_file( $self->_file(
        Dist::Zilla::File::InMemory->new(
            name => $self->filename,
            content => <<'TEST',
use strict;
use warnings;

# this test was generated with {{ ref $plugin }} {{ $plugin->VERSION }}

use Test::More 0.94;
use Test::CleanNamespaces {{ $tcn_prereq }};

subtest all_namespaces_clean => sub {{
    $skips
    ? "{\n    namespaces_clean(
        " . 'grep { my $mod = $_; not grep { $mod =~ $_ } ' . $skips . " }
            Test::CleanNamespaces->find_modules\n    );\n};"
    : '{ all_namespaces_clean() };'
}}

done_testing;
TEST
        ))
    );
}

sub munge_file
{
    my ($self, $file) = @_;

    return unless $file == $self->_file;

    $file->content(
        $self->fill_in_string(
            $file->content,
            {
                dist => \($self->zilla),
                plugin => \$self,
                skips => \( join(', ', map { 'qr/' . $_ . '/' } $self->skips) ),
                tcn_prereq => \($self->_tcn_prereq),
            }
        )
    );

    return;
}

__PACKAGE__->meta->make_immutable;
__END__

=pod

=head1 SYNOPSIS

In your F<dist.ini>:

    [Test::CleanNamespaces]
    skip = ::Dirty$

=head1 DESCRIPTION

This is a L<Dist::Zilla> plugin that runs at the
L<gather files|Dist::Zilla::Role::FileGatherer> stage, providing a test file
(configurable, defaulting to F<xt/author/clean-namespaces.t>).

This test will scan all modules in your distribution and check that their
namespaces are "clean" -- that is, that there are no remaining imported
subroutines from other modules that are now callable as methods at runtime.

You can fix this in your code with L<namespace::clean> or
L<namespace::autoclean>.

=for Pod::Coverage mvp_multivalue_args mvp_aliases register_prereqs gather_files munge_file

=head1 CONFIGURATION OPTIONS

=head2 filename

The name of the generated test. Defaults to F<xt/author/clean-namespaces.t>.

=head2 skip

A regular expression describing a module name that should not be checked. Can
be used more than once.

=head1 TO DO (or: POSSIBLE FEATURES COMING IN FUTURE RELEASES)

=for stopwords FileFinder

=for :list
* use of a configurable L<FileFinder|Dist::Zilla::Role::FileFinder> for finding
source files to check (depends on changes planned in L<Test::CleanNamespaces>)

=head1 SEE ALSO

=for :list
* L<Test::CleanNamespaces>
* L<namespace::clean>
* L<namespace::autoclean>
* L<namespace::sweep>
* L<Sub::Exporter::ForMethods>
* L<Sub::Name>
* L<Sub::Install>
* L<MooseX::MarkAsMethods>

=cut
