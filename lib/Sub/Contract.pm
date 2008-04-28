#-------------------------------------------------------------------
#
#   Sub::Contract - Programming by contract and memoizing in one
#
#   $Id: Contract.pm,v 1.14 2008/04/28 15:50:54 erwan_lemonnier Exp $
#

package Sub::Contract;

use strict;
use warnings;
use Carp qw(croak confess);
use Data::Dumper;
use Sub::Contract::ArgumentChecks;
use Sub::Contract::Debug qw(debug);
use Sub::Contract::Pool qw(get_contract_pool);
use Symbol;

# Add compiling and memoizing abilities through multiple inheritance, to keep code separate
use base qw( Exporter
	     Sub::Contract::Compiler
	     Sub::Contract::Memoizer );

our @EXPORT = qw();
our @EXPORT_OK = qw( contract
		     undef_or
		     defined_and
		     );

our $VERSION = '0.02';

my $pool = Sub::Contract::Pool::get_contract_pool();

# the argument list passed to the contractor
local @Sub::Contract::args;
local $Sub::Contract::wantarray;
local @Sub::Contract::results;

#---------------------------------------------------------------
#
#   contract - declare a contract
#

sub contract {
    croak "contract() expects only one argument, a subroutine name" if (scalar @_ != 1 || !defined $_[0]);
    my $caller = caller;
    return new Sub::Contract($_[0], caller => $caller);
}

#---------------------------------------------------------------
#
#   undef_or - take a test coderef and returns a test coderef that
#              passes if argument is undefined or validate the coderef
#

sub undef_or {
    croak "undef_or() expects a coderef" if (scalar @_ != 1 || !defined $_[0] || ref $_[0] ne 'CODE');
    my $test = shift;
    return sub {
	return 1 if (!defined $_[0]);
	return &$test(@_);
    };
}

#---------------------------------------------------------------
#
#   defined_and - take a test coderef and returns a test coderef that
#                 passes if argument is defined and validate the coderef
#

sub defined_and {
    croak "defined_and() expects a coderef" if (scalar @_ != 1 || !defined $_[0] || ref $_[0] ne 'CODE');
    my $test = shift;
    return sub {
	return 0 if (!defined $_[0]);
	return &$test(@_);
    };
}

################################################################
#
#
#   Object API
#
#
################################################################

#---------------------------------------------------------------
#
#   new - instantiate a new subroutine contract
#

sub new {
    my ($class,$fullname,%args) = @_;
    $class = ref $class || $class;
    my $caller = delete $args{caller} || caller();

    croak "new() expects a subroutine name as first argument" if (!defined $fullname);
    croak "new() got unknown arguments: ".Dumper(%args) if (keys %args != 0);

    # TODO: test for contractor existence here
    my $contractor_cref;
    my $contractor;

    if ($fullname !~ /::/) {
	$contractor_cref = *{ qualify_to_ref($fullname,$caller) }{CODE};
	$contractor = qualify($fullname,$caller);
    } else {
	$contractor_cref = *{ qualify_to_ref($fullname) }{CODE};
	$contractor = qualify($fullname);
    }

    if (!defined $contractor_cref) {
	croak "Can't find subroutine named '".$contractor."'";
    }

    # create instance of contract
    my $self = bless({}, $class);
    $self->{is_enabled}      = 0;                  # 1 if contract is enabled
    $self->{is_memoized}     = 0;                  # TODO: needed?
    $self->{contractor}      = $contractor;        # The fully qualified name of the contracted subroutine
    $self->{contractor_cref} = $contractor_cref;   # A code reference to the contracted subroutine

    $self->reset;

    # add self to the contract pool (if not already in)
    croak "trying to contract function [$contractor] twice"
	if ($pool->has_contract($contractor));

    $pool->_add_contract($self);

    return $self;
}

#---------------------------------------------------------------
#
#   reset - reset all constraints in a contract
#

sub reset {
    my $self = shift;
    $self->{in}          = undef;        # An array of coderefs checking respective input arguments
    $self->{out}         = undef;        # An array of coderefs checking respective return arguments
    $self->{pre}         = undef;        # Coderef checking pre conditions
    $self->{post}        = undef;        # Coderef checking post conditions
    $self->{invariant}   = undef;        # Coderef checking an invariant condition
    $self->{is_memoized} = 0;
    return $self;
}

#---------------------------------------------------------------
#
#   in, out - declare conditions for each of the subroutine's in- and out-arguments
#

sub _set_in_out {
    my ($type,$self,@checks) = @_;
    local $Carp::CarpLevel = 2;
    my $validator = new Sub::Contract::ArgumentChecks($type);

    my $pos = 0;

    # check arguments passed in list-style
    while (@checks) {
	my $check = shift @checks;

	if (!defined $check || ref $check eq 'CODE') {
	    # ok
	    $validator->add_list_check($check);
	} elsif (ref $check eq '') {
	    # this is a hash key. we expect hash syntax from there on
	    unshift @checks, $check;
	    last;
	} else {
	    croak "invalid contract definition: argument at position $pos in $type() should be undef or a coderef or a string";
	}
	$pos++;
    }

    # @checks should be either empty or describe hash checks (sequence of string => coderef)
    if (scalar @checks % 2) {
	croak "invalid contract definition: odd number of arguments from position $pos in $type(), can't ".
	    "constrain hash-style passed arguments";
    }

    # check arguments passed in hash-style
    my %known_keys;
    while (@checks) {
	my $key = shift @checks;
	my $check = shift @checks;

	if (defined $key && ref $key eq '') {
	    # is this key defined more than once?
	    if (exists $known_keys{$key}) {
		croak "invalid contract definition: constraining argument \'$key\' twice in $type()";
	    }
	    $known_keys{$key} = 1;

	    # ok with key. verify $check
	    if (!defined $check || ref $check eq 'CODE') {
		# ok
		$validator->add_hash_check($key,$check);
	    } else {
		croak "invalid contract definition: check for \'$key\' should be undef or a coderef in $type()";
	    }
	} else {
	    croak "invalid contract definition: argument at position $pos should be a string in $type()";
	}
	$pos += 2;
    }

    # everything ok!perl 06
    $self->{$type} = $validator;
    return $self;
}

sub in   { return _set_in_out('in',@_); }
sub out  { return _set_in_out('out',@_); }

#---------------------------------------------------------------
#
#   pre, post - declare pre and post conditions on subroutine
#

sub _set_pre_post {
    my ($type,$self,$subref) = @_;
    local $Carp::CarpLevel = 2;

    croak "the method $type() expects exactly one argument"
	if (scalar @_ != 3);
    croak "the method $type() expects a code reference as argument"
	if (defined $subref && ref $subref ne 'CODE');

    $self->{$type} = $subref;

    return $self;
}

sub pre  { return _set_pre_post('pre',@_); }
sub post { return _set_pre_post('post',@_); }

#---------------------------------------------------------------
#
#   invariant - adds an invariant condition
#

sub invariant {
    my ($self,$subref) = @_;

    croak "the method invariant() expects exactly one argument"
	if (scalar @_ != 2);
    croak "the method invariant() expects a code reference as argument"
	if (defined $subref && ref $subref ne 'CODE');

    $self->{invariant} = $subref;

    return $self;
}

#---------------------------------------------------------------
#
#   contractor - returns the contractor subroutine's fully qualified name
#

sub contractor {
    return $_[0]->{contractor};
}

#---------------------------------------------------------------
#
#   contractor_cref - return a code ref to the contractor subroutine
#

sub contractor_cref {
    return $_[0]->{contractor_cref};
}


# TODO: implement return?

# contract('my_func')
#     ->invariant( sub { die "blah" if (ref $_[0] ne 'blob'); } )
#     ->in(prsid => \&check1,
#          fndid => \&check2,
#     )->out(\&is_boolean)
#     ->memoize( max => 1000 );
#
# or
#     ->cache( size => 1000 );
#
# sub my_func {}
#
# my $pool = Sub::Contract::Pool::get_pool;
# $pool->enable_all_contracts;


1;

__END__

=head1 NAME

WARNING!!!

This is an alfa release!
Some features are not implemented yet and test coverage is still low!!

WARNING!!!


Sub::Contract - Pragmatic contract programming for Perl

=head1 SYNOPSIS

To contract a function 'divid' that accepts a hash of 2 integer values
and returns a list of 2 integer values:

    contract('divid')
        ->in(a => sub { defined $_ && $_ =~ /^\d+$/},
             b => sub { defined $_ && $_ =~ /^\d+$/},
            )
        ->out(sub { defined $_ && $_ =~ /^\d+$/},
              sub { defined $_ && $_ =~ /^\d+$/},
             )
        ->enable;

    sub divid {
	my %args = @_;
	return ( int($args{a} / $args{b}), $args{a} % $args{b} );
    }

Or, if you have a function C<is_integer>:

    contract('divid')
        ->in(a => \&is_integer,
             b => \&is_integer,
            )
        ->out(\&is_integer, \&is_integer);
        ->enable;

If C<divid> was a method of an instance of 'Maths::Integer':

    contract('divid')
        ->in(sub { defined $_ && ref $_ eq 'Maths::Integer' },
             a => \&is_integer,
             b => \&is_integer,
            )
        ->out(\&is_integer, \&is_integer);
        ->enable;

Or if you don't want to do any check on the type of self:

    contract('divid')
         ->in(undef,
              a => \&is_integer,
              b => \&is_integer,
             )
        ->out(\&is_integer, \&is_integer);
        ->enable;

You can also declare invariants, pre- and post-conditions as in
usual contract programming implementations:

    contract('foo')
         ->pre( \&validate_state_before )
         ->post( \&validate_state_after )
         ->invariant( \&validate_state )
         ->enable;

You may memoize a function's results, using its contract:

    contract('foo')->memoize->enable;

You may list contracts during runtime, modify them and recompile
them dynamically, or just turn them off. See 'Sub::Contract::Pool'
for details.

=head1 DESCRIPTION

Sub::Contract offers a pragmatic way to implement parts of the programming
by contract paradigm in Perl.

Sub::Contract is not a design-by-contract framework.

Perl is a weakly typed language in which variables have a dynamic content
at runtime. A feature often wished for in such circumstances is a way
to define constraints on a subroutine's arguments and on its
return values. A constraint is basically a test that the specific argument
has to pass otherwise we croak.

For example, a subroutine C<add()> that takes 2 integers and return their
sum could have constraints on both input arguments and on the return value
stating that they must be defined and be integers or else we croak. That
kind of tests is usually writen explicitely within the subroutine's
body, hence leading to an overflow of argument validation code. With Sub::Contract
you can move this code outside the subroutine body in a relatively simple
and elegant way.

Sub::Contract doesn't aim at implementing all the properties of contract
programming, but focuses on some that have proven handy in practice
and tries to do it with a simple syntax.

With Sub::Contract you can specify a contract per subroutine (or method).
A contract is a set of constraints on the subroutine's input arguments, its
returned values, or on a state before and after being called. If one
of these constraints gets broken at runtime, the contract fails and a
runtime error (die or croak) is emitted.

Contracts generated by Sub::Contract are objects. Any contract can
be disabled, modified, recompiled and re-enabled at runtime.

All new contracts are automatically added to a contract pool.
The contract pool can be searched at runtime for contracts matching
some conditions.

A compiled contract takes the form of an anonymous subroutine wrapped
around the contracted subroutine. Since it is a very appropriate place
to perform memoization of the contracted subroutine's result, contracts
also offer memoizing as an option.

There may be only one contract per subroutine. To modify a subroutine's contract,
you need to get the contract object for this subroutine and alter it. You
can fetch the contract by querying the contract pool (see Sub::Contract::Pool).

The contract definition API is designed pragmatically. Experience shows
that contracts in Perl are mostly used to enforce some form of
argument type validation, hence compensating for Perl's lack of strong
typing, or to replace some assertion code.

In some cases, one may want to enable contracts during development,
but disable them in production to meet speed requirements (though this is
not encouraged). That is easily done with the contract pool.

=head1 DISCUSSION

=head2 Definitions

To make things easier to describe, let's agree on the meaning of the following terms:

=over 4

=item Contractor The contractor is a subroutine whose pre- and post-call
state and input and return arguments are verified against constraints
defined in a contract.

=item Contract Defines a set of constraints that a contractor has to conform with
and eventually memoizes the contractor's results.

=item Constraint A test that returns true when the constraint passes, or either
returns false or croaks (dies) when the constraint fails.
Constraints are specified inside the contract as code references to some test
code.

=back

=head2 Contracts as objects

Sub::Contract differs from traditional contract programming
frameworks in that it implements contracts as objects that
can be dynamically altered during runtime. The idea of altering
a contract during runtime may seem to conflict with the definition
of a contract, but it makes sense when considering that Perl being
a dynamic language, all code can change its behaviour during runtime.

Furthermore, the availability of all contracts via the contract pool
at runtime gives a powerfull self introspection mechanism.

=head2 Error messages

When a call to a contractor breaks the contract, the constraint code
will return false or croak. If it returns false, Sub::Contract will
emit an error looking as if the contractor croaked.

=head2 Contracts and context

In Perl, contractors are always called in a given context. It can be either scalar
context, array context or no context (no return value expected).

How this affects a contractor's contract is rather tricky. For example,
if a function that always returns an array is called in scalar context, should
we consider it a contract breach?

TODO: For technical reasons, constraints defined with the C<out()> methods
are context sensitive. If the constraints apply to an array of values...

=head2 Issues with contract programming

=over 4

=item Inheritance

Contracts do not behave well with inheritance, mostly because there is
no standard way of inheriting the parent class's contracts. In Sub::Contract,
child classes do not inherit contracts,
but any call to a contractor subroutine belonging to the parent class
from within the child class is verified against the parent's contract.

=item Relevant error messages

To be usable, contracts must be specific about what fails. Therefore
it is prefered that constraints croak from within the contract and with
a detailed error message, rather than just return false.

A failed constraint must cause an error that points to the line at which
the contractor was called. This is the case if your constraints croak, but
not if they die.

=back

=head2 Other contract APIs in Perl

=over 4

=item * Sub::Contract VERSUS Class::Contract

Class::Contract implements contract programming in a way that is more faithfull to the
original contract programming syntax defined by Eiffel. It also enables design-by-contract,
meaning that your classes are implemented inside the contract, rather than having class
implementation and contract definition as 2 distinct code areas.

Class::Contract does not provide memoization from within the contract.

=item * Sub::Contract VERSUS Class::Agreement

Class::Agreement offers the same functionality as Sub::Contract, though with a somewhat
heavier syntax if you are only seeking to validate input arguements and return values.

Class::Agreement does not provide memoization from within the contract.




TODO: more description
TODO: how to enable contracts -> enable on each contract, or via the pool

TODO: validation code should not change @_, else weird bugs...


=back

=head1 Object API

=over 4

=item C<< my $contract = new Sub::Contract($qualified_name) >>

Return an empty contract for the function named C<$qualified_name>.

If C<$qualified_name> is a function name without the package it is in,
the function is assumed to be in the caller package.

    # contract on the subroutine 'foo' in the local package
    my $c = new Sub::Contract('foo');

    # contract on the subroutine 'foo' in the package 'Bar::Blob'
    my $c = new Sub::Contract('Bar::Blob::foo');

A given function can be contracted only once. If you want to modify a
function's contract after having enabled the contract, you can't just
call C<Sub::Contract->new> again. Instead you must retrieve the contract
object for this function, modify it and enable it anew. Retrieving the
function's contract object can be done by querying the contract pool
(See 'Sub::Contract::Pool').

=item C<< my $contract = new Contract::Sub($name, caller => $package) >>

Same as above, excepts that the contractor is the function C<$name>
located in package C<$package>.

=item C<< $contract->invariant($coderef) >>

Execute C<$coderef> both before and after calling the contractor.
C<$coderef> gets in arguments the arguments passed to the contractor.
C<$coderef> should return 1 if the condition passes and 0 if it fails.
C<$coderef> may croak, in which case the error will look as if caused
by the calling code. Do not C<die> from C<$coderef>, always use C<croak>
instead.

    package MyCircle;

    use accessors qw(pi);

    # define a contract on method perimeter that controls
    # that the object's attribute pi remains equal to 3.14
    # before and after calling ->perimeter()

    contract('perimeter')
        ->invariant(sub { croak "pi has changed" if ($_[0]->x != 3.14) })
        ->enable;

    sub perimeter { ... }

=item C<< $contract->pre($coderef) >>

Same as C<invariant> but executes C<$coderef> only before calling the
contractor.

=item C<< $contract->post($coderef) >>

Same as C<pre> but executes C<$coderef> when returning from calling
the contractor.

=item C<< $contract->in(@checks) >>

Validate each input argument of the contractor one by one.

C<@checks> declares which validation functions should be called
for each input argument. The syntax of C<@checks> supports arguments
passed in array-style or hash-style or a mix of both.


TODO: syntax for @checks

=item C<< $contract->out(@checks) >>

Same as C<in> but for validating return arguments one by one.

C<out()> validates return values in a context sensitive way. See
'Contract and context' under 'Discussion' for details. If this
restriction disturbs you, you may want to implement your constraints
with C<post()> rather than C<out()>.

=item C<< $contract->memoize >>

Enable memoization of the contractor's results.

TODO: detail arguments

=item C<< $contract->flush_cache >>

Empty the contractor's cache of memoized results.

=item C<< $contract->enable >>

Compile and enable a contract. If the contract is already enabled, it is
first disabled, then re-compiled and enabled.

Enabling the contract consists in dynamically generating
some code that validates the contract before and after calls to the
contractor and wrapping this code around the contractor.

=item C<< $contract->disable >>

Disable the contract: remove the wrapper code generated and added by C<enable>
from around the contractor.

=item C<< $contract->is_enabled >>

Return true if this contract is currently enabled.

=item C<< $contract->contractor >>

Return the fully qualified name name of the subroutine affected by this contract.

=item C<< $contract->contractor_cref >>

Return a code reference to the contracted subroutine.

=item C<< $contract->reset >>

Remove all previously defined constraints from this contract and disable
memoization. C<reset> has no effect on the contract validation code as long as you
don't call C<enable> after C<reset>. C<reset> is usefull if you want to
redefine a contract from scratch during runtime.

=back

=head1 Class API

=over 4

=item C<< contract($qualified_name) >>

Same as C<new Sub::Contract($qualified_name)>.
Must be explicitly imported:

    use Sub::Contract qw(contract);

    contract('add_integers')
        ->in(\&is_integer, \&is_integer)
        ->enable;

    sub add_integers {...}

=item C<< undef_or($coderef) >>

Syntax sugar to allow you to specify a constraint on an argument
saying 'this argument must be undefined or validate this test'.

Assuming you have a test function C<is_integer> that passes if its
argument is an integer and croaks otherwise, you could write:

    use Sub::Contract qw(contract undef_or);

    # set_value takes only 1 argument that must be either
    # undefined or be validated by is_integer()
    contract('set_value')
        ->in(undef_or(\&is_integer))
        ->enable;

    sub set_value {...}


=item C<< defined_and($coderef) >>

Syntax sugar to allow you to specify a constraint on an argument
saying 'this argument must be defined and validate this test'.

Example:

    use Sub::Contract qw(contract defined_and undef_or);

    # set_name takes a hash that must contain a key 'name'
    # that must be defined and validate is_word(), and may
    # contain a key 'nickname' that can be either undefine
    # or must validate is_word().
    contract('set_name')
        ->in( name => defined_and(\&is_word),
              nickname => undef_or(\&is_word))
        ->enable;

   sub set_name {...}

=back

=head1 Class variables

The value of the following variables is set by Sub::Contract before
executing any contract validation code. They are designed to be used
inside the contract validation code and nowhere else!

=over 4

=item C<< $Sub::Contract::wantarray >>

1 if the contractor is called in array context, 0 if it is called
in scalar context, and undef if called in no context. This affects
the value of C<< Sub::Contract::results >>.

=item C<< @Sub::Contract::args >>

The input arguments that the contractor is being called with.

=item C<< @Sub::Contract::results >>

The result(s) returned by the contractor, as seen by its caller.
Can also be accessed with the exported function 'returns'.

=back

The following example code uses those variables to validate
that a function C<foo> returns C<< 'array' >> in array context
and C<< 'scalar' >> in scalar context:

    use Sub::Contract qw(contract results);

    contract('foo')
        ->post(
            sub {
                 my @results = returns;

                 if ($Sub::Contract::wantarray == 1) {
                     return defined $results[0] && $results[0] eq "array";
                 } elsif ($Sub::Contract::wantarray == 0) {
                     return defined $results[0] && $results[0] eq "scalar";
                 } else {
                    return 1;
		 }
	     }
        )->enable;

=head1 SEE ALSO

See Carp::Datum, Class::Agreement, Class::Contract.

=head1 BUGS

See 'Issues with contract programming' under 'Discussion'.

=head1 VERSION

$Id: Contract.pm,v 1.14 2008/04/28 15:50:54 erwan_lemonnier Exp $

=head1 AUTHORS

Erwan Lemonnier C<< <erwan@cpan.org> >>,
as part of the Pluto developer group at the Swedish Premium Pension Authority.

=head1 LICENSE AND DISCLAIMER

This code was developed at the Swedish Premium Pension Authority as part of
the Authority's software development activities. This code is distributed
under the same terms as Perl itself. We encourage you to help us improving
this code by sending feedback and bug reports to the author(s).

This code comes with no warranty. The Swedish Premium Pension Authority and the author(s)
decline any responsibility regarding the possible use of this code or any consequence
of its use.

=cut



