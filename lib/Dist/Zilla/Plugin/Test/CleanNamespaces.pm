use strict;
use warnings;
package Dist::Zilla::Plugin::Test::CleanNamespaces;
# ABSTRACT: Generate a test to check that all namespaces are clean
# KEYWORDS: plugin testing namespaces clean dirty imports exports subroutines methods
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with (
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::TextTemplate',
    'Dist::Zilla::Role::PrereqSource',
);
use MooseX::Types::Stringlike 'Stringlike';
use Path::Tiny;
use namespace::autoclean;

sub mvp_multivalue_args { qw(skips) }
sub mvp_aliases { return { skip => 'skips' } }

has skips => (
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    handles => { skips => 'elements' },
    lazy => 1,
    default => sub { [] },
);

has filename => (
    is => 'ro', isa => Stringlike,
    coerce => 1,
    lazy => 1,
    default => sub { path('xt', 'release', 'clean-namespaces.t') },
);

sub register_prereqs
{
    my $self = shift;

    $self->zilla->register_prereqs(
        {
            type  => 'requires',
            phase => $self->filename =~ /^t/ ? 'test' : 'develop',
        },
        'Test::CleanNamespaces' => '0.08',
    );
}

sub gather_files
{
    my $self = shift;

    require Dist::Zilla::File::InMemory;
    $self->add_file( Dist::Zilla::File::InMemory->new(
        name => $self->filename,
        content => <<'TEST',
use strict;
use warnings;

# this test was generated with {{ ref($plugin) . ' ' . ($plugin->VERSION || '<self>') }}

use Test::More 0.94;
use Test::CleanNamespaces 0.04;

subtest all_namespaces_clean => sub {{
    $skips
    ? "{\n    namespaces_clean(
        " . 'grep { my $mod = $_; not grep { $mod =~ $_ } ' . $skips . " }
            Test::CleanNamespaces->find_modules\n    );\n};"
    : '{ all_namespaces_clean() };'
}}

done_testing;
TEST
    ));
}

sub munge_file
{
    my ($self, $file) = @_;

    return unless $file->name eq $self->filename;

    $file->content(
        $self->fill_in_string(
            $file->content,
            {
                dist => \($self->zilla),
                plugin => \$self,
                skips => \( join(', ', map { 'qr/' . $_ . '/' } $self->skips) ),
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
(configurable, defaulting to F<xt/release/clean-namespaces.t>).

This test will scan all modules in your distribution and check that their
namespaces are "clean" -- that is, that there are no remaining imported
subroutines from other modules that are now callable as methods at runtime.

You can fix this in your code with L<namespace::clean> or
L<namespace::autoclean>.

=for Pod::Coverage mvp_multivalue_args mvp_aliases register_prereqs gather_files munge_file

=head1 CONFIGURATION OPTIONS

=head2 filename

The name of the generated test. Defaults to F<xt/release/clean-namespaces.t>.

=head2 skip

A regular expression describing a module name that should not be checked. Can
be used more than once.

=head1 TO DO (or: POSSIBLE FEATURES COMING IN FUTURE RELEASES)

=for stopwords FileFinder

=begin :list

* use of a configurable L<FileFinder|Dist::Zilla::Role::FileFinder> for finding
source files to check (depends on changes planned in L<Test::CleanNamespaces>)

=end :list

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-Test-CleanNamespaces>
(or L<bug-Dist-Zilla-Plugin-Test-CleanNamespaces@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-Test-CleanNamespaces@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 SEE ALSO

=begin :list

* L<Test::CleanNamespaces>
* L<namespace::clean>
* L<namespace::autoclean>
* L<namespace::sweep>
* L<Sub::Exporter::ForMethods>
* L<Sub::Install>
* L<MooseX::MarkAsMethods>

=end :list

=cut
