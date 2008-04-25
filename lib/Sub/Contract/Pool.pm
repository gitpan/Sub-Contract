#
#   Sub::Contract::Pool - The pool of contracts
#
#   $Id: Pool.pm,v 1.7 2008/04/25 14:01:52 erwan_lemonnier Exp $
#

package Sub::Contract::Pool;

use strict;
use warnings;

use Carp qw(croak);

use vars qw($AUTOLOAD);
use accessors qw( _contract_index
		);

use base qw(Exporter);

our @EXPORT = ();
our @EXPORT_OK = ('get_contract_pool');

#---------------------------------------------------------------
#
#   A singleton pattern with lazy initialization and embedded constructor
#

my $pool;

sub get_contract_pool {
    if (!defined $pool) {
	$pool = bless({},__PACKAGE__);
	$pool->_contract_index({});
    }
    return $pool;
}

# make sure no one calls the constructor
sub new {
    croak "use get_contract_pool() instead of new()";
}

#---------------------------------------------------------------
#
#   list_all_contracts - return all contracts registered in the pool
#

sub list_all_contracts {
    my $self = shift;
    return values %{$self->_contract_index};
}

#---------------------------------------------------------------
#
#   has_contract -
#

# TODO: should it be removed? to use find_contract instead? would it be too slow?

sub has_contract {
    my ($self, $contractor) = @_;

    croak "method has_contract() expects a fully qualified function name as argument"
	if ( scalar @_ != 2 ||
	     !defined $contractor ||
	     ref $contractor ne '' ||
	     $contractor !~ /::/
	);

    my $index = $self->_contract_index;
    return exists $index->{$contractor};
}

#---------------------------------------------------------------
#
#   _add_contract
#

sub _add_contract {
    my ($self, $contract) = @_;

    croak "method add_contract() expects only 1 argument"
	if (scalar @_ != 2);
    croak "method add_contract() expects an instance of Sub::contract as argument"
	if (!defined $contract || ref $contract ne 'Sub::Contract');

    my $index = $self->_contract_index;
    my $contractor = $contract->contractor;

    croak "trying to contract function [$contractor] twice"
	if ($self->has_contract($contractor));

    $index->{$contractor} = $contract;

    return $self;
}

################################################################
#
#
#   Operations on contracts during runtime
#
#
################################################################

sub enable_all_contracts {
    my $self = shift;
    map { $_->enable } $self->list_all_contracts;
}

sub disable_all_contracts {
    my $self = shift;
    map { $_->disable } $self->list_all_contracts;
}

sub enable_contracts_matching {
    my $self = shift;
    map { $_->enable } $self->find_contracts_matching(@_);
}

sub disable_contracts_matching {
    my $self = shift;
    map { $_->disable } $self->find_contracts_matching(@_);
}

sub find_contracts_matching {
    my $self = shift;
    my $match = shift;
    my @contracts;

#    use Data::Dumper;
#    print "caller is: ".Dumper();

# TODO: fix croak level is called from enable/disable_matching
#    local $Carp::CarpLevel = 2 if ((caller(1))[3] =~ /^Sub::Contract::Pool::(enable|disable)_contracts_matching$/);

    croak "method find_contracts_matching() expects a regular expression"
	if (scalar @_ != 0 || !defined $match || ref $match ne '');

    while ( my ($name,$contract) = each %{$self->_contract_index} ) {
	push @contracts, $contract if ($name =~ /$match/);
    }

    return @contracts;
}

################################################################
#
#   compile contracts on demand at runtime
#

sub AUTOLOAD {
    my $caller = $AUTOLOAD;
}



1;

__END__

=head1 NAME

Sub::Contract::Pool - A pool of all subroutine contracts

=head1 SYNOPSIS

    use Sub::Contract::Pool qw(get_contract_pool);

    my $pool = get_contract_pool();

TODO

=head1 DESCRIPTION

All subroutine contracts defined via creating instances of
Sub::Contract or Sub::Contract::Memoizer are automatically
added to a pool of contracts.

You can query this pool to retrieve contracts defined for
specific parts of your code, and modify, recompile, enable
and disable contracts selectively at runtime.

Sub::Contract::Pool is a singleton pattern, giving you
access to a unique contract pool created at compile time
by Sub::Contract.

=head1 API

=over 4

=item C<< my $pool = get_contract_pool() >>;

Return the contract pool.

=item C<< new() >>

Pool constructor, for internal use only.
DO NOT USE NEW, always use C<< get_contract_pool() >>.

=item C<< $pool->list_all_contracts >>

Return all contracts registered in the pool.

=item C<< $pool->has_contract($fully_qualified_name) >>

Return true if the subroutine identified by C<$fully_qualified_name>
has a contract.

=item C<< $pool->enable_all_contracts >>

Enable all the contracts registered in the pool.

=item C<< $pool->disable_all_contracts >>

Disable all the contracts registered in the pool.

=item C<< $pool->enable_contracts_matching($regexp) >>

Enable all the contracts registered in the pool whose contractor's
fully qualified names matches the string C<$regexp>. C<regexp> works
as for C<find_contracts_matching>.

=item C<< $pool->disable_contracts_matching($regexp) >>

Disable all the contracts registered in the pool whose contractor's
fully qualified names matches the string C<$regexp>. C<regexp> works
as for C<find_contracts_matching>.

=item C<< $pool->find_contracts_matching($regexp) >>

Find all the contracts registered in the pool and whose contractor's
fully qualified names matches the string C<$regexp>.
TODO

=back

=head1 SEE ALSO

See 'Sub::Contract'.

=head1 VERSION

$Id: Pool.pm,v 1.7 2008/04/25 14:01:52 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 LICENSE

See Sub::Contract.

=cut



