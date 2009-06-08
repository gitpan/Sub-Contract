#-------------------------------------------------------------------
#
#   Sub::Contract::Memoizer - Implement the memoizing behaviour of a contract
#
#   $Id: Memoizer.pm,v 1.11 2009/06/08 19:44:28 erwan_lemonnier Exp $
#

package Sub::Contract::Memoizer;

use strict;
use warnings;
use Carp qw(croak confess);
use Data::Dumper;
use Symbol;
use Sub::Contract::Cache;

our $VERSION = '0.11';

#---------------------------------------------------------------
#
#
# the cache profiler
#
#
#---------------------------------------------------------------

# turn on cache statistics
my $CACHE_STATS_ON = 0;
if (defined $ENV{PERL5SUBCONTRACTSTATS} && $ENV{PERL5SUBCONTRACTSTATS} eq '1') {
    $CACHE_STATS_ON = 1;
}

my %CACHE_STATS;

# for the compiler to know if the cache profiler is on
sub _is_profiler_on {
    return $CACHE_STATS_ON;
}

# private functions used to update stat counters
sub _incr_miss {
    $CACHE_STATS{$_[0]}->{calls}++;
}

sub _incr_hit {
    $CACHE_STATS{$_[0]}->{calls}++;
    $CACHE_STATS{$_[0]}->{hits}++;
}


# show cache statistics, if any
END {
    if ($CACHE_STATS_ON) {
	print "------------------------------------------------------\n";
	print "Statistics from Sub::Contract's function result cache:\n";
	foreach my $func (sort keys %CACHE_STATS) {
	    my $hits = $CACHE_STATS{$func}->{hits};
	    my $calls = $CACHE_STATS{$func}->{calls};
	    if ($calls) {
		my $rate = int(1000*$hits/$calls)/10;
		print "  ".sprintf("%-60s:",$func)."  $rate % hits (calls: $calls, hits: $hits)\n";
	    }
	}
	print "------------------------------------------------------\n";
    }
}

#---------------------------------------------------------------
#
#
# memoization - implement the cache behavior of a contract
#
#
#---------------------------------------------------------------

sub cache {
    my ($self,%args) = @_;
    my $size = delete $args{size} || 10000; # default size 10000 elements

    croak "cache() got unknown arguments: ".Dumper(%args) if (%args);
    croak "size should be a number" if (!defined $size || $size !~ /^\d+$/);

    # NOTE: $contract->reset() deletes this cache
    $self->{cache} = new Sub::Contract::Cache( namespace => $self->contractor,
					       size => $size );

    if ($CACHE_STATS_ON && !exists $CACHE_STATS{$self->contractor}) {
	$CACHE_STATS{$self->contractor} = { calls => 0, hits => 0 };
    }

    return $self;
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

    # we assume that the cached function is context insensitive and hence should
    # return the same result independently of context.

    # the code to generate the key has to be the same as in Compiler.pm 
    my $key_array = join( ":", map( { (defined $_) ? $_ : "undef"; } "array", @$args) );
    my $key_scalar = join( ":", map( { (defined $_) ? $_ : "undef"; } "scalar", @$args) );

    $self->{cache}->set($key_array,$results);
    $self->{cache}->set($key_scalar,$results);

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

=item C<< $contract->clear_cache >>

=item C<< $contract->add_to_cache(\@args, \@results) >>

=back

=head1 SEE ALSO

See 'Sub::Contract'.

=head1 VERSION

$Id: Memoizer.pm,v 1.11 2009/06/08 19:44:28 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 LICENSE

See Sub::Contract.

=cut



