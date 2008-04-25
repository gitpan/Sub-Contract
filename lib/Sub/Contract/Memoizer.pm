#-------------------------------------------------------------------
#
#   Sub::Contract::Memoizer - Implement the memoizing behaviour of a contract
#
#   $Id: Memoizer.pm,v 1.2 2007/04/27 12:46:29 erwan_lemonnier Exp $
#
#   070320 erwan First cast
#

package Sub::Contract::Memoizer;

use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper;
use Symbol;

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

sub memoize {
    my ($self,%args) = @_;
    my $size = delete $args{size};

    croak "memoize() got unknown arguments: ".Dumper(%args) if (%args);

    # TODO: ->reset should play well with memoize

    $self->{is_memoized} = 1;
    # TODO: use Memoize

#    my $cache = new Sub::Pluto::Cache();
#    $cache->set_size($size) if ($size);
#    $self->_cache($cache);

    return $self;
}

#sub unmemoize ?

#sub is_memoized {
#    return $_[0]->_is_memoized();
#}

sub flush_cache {
    my $self = shift;
    # TODO: call Memoize::flush_cache on right function
    return $self;
}

1;

#__END__

=pod

=head1 NAME

Sub::Contract::Memoizer - Implement the memoizing behaviour of a contract

=head1 SYNOPSIS

See 'Sub::Contract'.

=head1 DESCRIPTION

Subroutine contracts defined with Sub::Contract can memoize
the contractor's results. This optional behaviour is implemented
in Sub::Contract::Memoizer.

=head1 API

See 'Sub::Contract'.

=over 4

=item C<< memoize >>

=item C<< flush_cache >>

=back

=head1 SEE ALSO

See 'Sub::Contract'.

=head1 VERSION

$Id: Memoizer.pm,v 1.2 2007/04/27 12:46:29 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 LICENSE

See Sub::Contract.

=cut



