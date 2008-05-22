#-------------------------------------------------------------------
#
#   Sub::Contract::Memoizer - Implement the memoizing behaviour of a contract
#
#   $Id: Memoizer.pm,v 1.3 2008/05/22 16:03:24 erwan_lemonnier Exp $
#

package Sub::Contract::Memoizer;

use strict;
use warnings;
use Carp qw(croak confess);
use Data::Dumper;
use Symbol;

use Cache::Memory;

#---------------------------------------------------------------
#
#
#   Memoization
#
#
#---------------------------------------------------------------

#
# the cache part
#

# TODO: implement stats => 1
# TODO: implement file cache
# TODO: implement expiry time

sub cache {
    my ($self,%args) = @_;
    my $size = delete $args{size} || 10000000; # default size = 10mb

    croak "cache() got unknown arguments: ".Dumper(%args) if (%args);
    croak "size should be a number" if (!defined $size || $size !~ /^\d+$/);

    # NOTE: $contract->reset() deletes this cache
    $self->{cache} = new Cache::Memory( size_limit => $size );

    return $self;
}

sub _make_cache_key {
    my (@args) = @_;

    # NOTE: previously, we used Dumper(@args) as the key, but Dumper is quite
    # slow, hence the use of join() here. But join will replace references
    # with an adress code while concatening to the string. 2 series of input
    # arguments with the same scalar reference, but for which the refered scalar
    # had different values will therefore yield the same key, though the
    # results will be different.
    # therefore we want to forbid the use of contract's cache whith references
    # but we have to think of speed...

    if (grep({ ref $_; } @args)) {
	confess "ERROR: cache cannot handle input arguments that are references. arguments were:\n".Dumper(@args);
    }

    @args = map { (defined $_) ? $_ : "undef"; } @args;

    return join(":",@args);
}

sub get_cache {
    return $_->{cache};
}

sub has_cache {
    return (exists $_->{cache}) ? 1:0;
}

sub clear_cache {
    my $self = shift;
    confess "contract defines no cache" if (!exists $self->{cache});
    $self->{cache}->clear;
    return $self;
}

sub add_to_cache {
    my ($self,$args,$results) = @_;
    confess "add_to_cache expects an array ref of arguments" if (!defined $args || ref $args ne "ARRAY");
    confess "add_to_cache expects an array ref of results"   if (!defined $results || ref $results ne "ARRAY");
    confess "contract defines no cache" if (!exists $self->{cache});

    my $key = _make_cache_key(@{$args});
    $self->{cache}->set($key,$results);

    return $self;
}

1;

=pod

=head1 NAME

Sub::Contract::Memoizer - Implement the caching behaviour of a contract

=head1 SYNOPSIS

See 'Sub::Contract'.

=head1 DESCRIPTION

Subroutine contracts defined with Sub::Contract can memoize
the contractor's results. This optional behaviour is implemented
in Sub::Contract::Memoizer.

=head1 API

See 'Sub::Contract'.

=over 4

=item C<< $contract->cache([size => $max_size]) >>

=item C<< $contract->has_cache([size => $max_size]) >>

=item C<< $contract->get_cache >>

Returns the instance of Cache used by this contract.

=item C<< $contract->clear_cache >>

=item C<< $contract->add_to_cache(\@args, \@results) >>

=back

=head1 SEE ALSO

See 'Sub::Contract'.

=head1 VERSION

$Id: Memoizer.pm,v 1.3 2008/05/22 16:03:24 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 LICENSE

See Sub::Contract.

=cut



