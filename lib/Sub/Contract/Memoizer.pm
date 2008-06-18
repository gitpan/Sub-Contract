#-------------------------------------------------------------------
#
#   Sub::Contract::Memoizer - Implement the memoizing behaviour of a contract
#
#   $Id: Memoizer.pm,v 1.8 2008/06/18 14:02:31 erwan_lemonnier Exp $
#

package Sub::Contract::Memoizer;

use strict;
use warnings;
use Carp qw(croak confess);
use Data::Dumper;
use Symbol;

use Cache::Memory;

our $VERSION = '0.09';

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
# memoization
#
#
#---------------------------------------------------------------


#
# the cache part
#

# TODO: implement file cache
# TODO: implement expiry time

sub cache {
    my ($self,%args) = @_;
    my $size = delete $args{size} || 10485760; # default size = 10mb

    croak "cache() got unknown arguments: ".Dumper(%args) if (%args);
    croak "size should be a number" if (!defined $size || $size !~ /^\d+$/);

    # NOTE: $contract->reset() deletes this cache
    $self->{cache} = new Cache::Memory( namespace => $self->contractor, size_limit => $size );

    if ($CACHE_STATS_ON && !exists $CACHE_STATS{$self->contractor}) {
	$CACHE_STATS{$self->contractor} = { calls => 0, hits => 0 };
    }

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

    if ($CACHE_STATS_ON) {
	$CACHE_STATS{$self->contractor} = { calls => 0, hits => 0 };
    }


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

$Id: Memoizer.pm,v 1.8 2008/06/18 14:02:31 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 LICENSE

See Sub::Contract.

=cut



