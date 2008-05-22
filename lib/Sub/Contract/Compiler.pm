#
#   Sub::Contract::Compiler - Compile, enable and disable a contract
#
#   $Id: Compiler.pm,v 1.11 2008/05/22 16:03:24 erwan_lemonnier Exp $
#

package Sub::Contract::Compiler;

use strict;
use warnings;
use Carp qw(croak confess);
use Data::Dumper;
use Sub::Contract::Debug qw(debug);
use Hook::WrapSub qw(wrap_subs unwrap_subs);
use Sub::Name;

#---------------------------------------------------------------
#
#   enable - recompile contract and reenable it
#

sub enable {
    my $self = shift;

    debug(1,"Sub::Contract: enabling contract for [".$self->contractor."]");

    $self->disable if ($self->{is_enabled});

    # list all variables with same names in enable() as in _generate_code()
    my $contractor    = $self->contractor;
    my $validator_in  = $self->{in};
    my $validator_out = $self->{out};
    my $check_in      = $self->{pre};
    my $check_out     = $self->{post};
    my $invariant     = $self->{invariant};
    my $cache         = $self->{cache};

    my @list_checks_in;
    my %hash_checks_in;
    if (defined $validator_in) {
	@list_checks_in = @{$validator_in->list_checks};
	%hash_checks_in = %{$validator_in->hash_checks};
    }

    my @list_checks_out;
    my %hash_checks_out;
    if (defined $validator_out) {
	@list_checks_out = @{$validator_out->list_checks};
	%hash_checks_out = %{$validator_out->hash_checks};
    }

    # compile code to validate pre and post constraints
    my $code_pre  = _generate_code('before',
				   $contractor,
				   $validator_in,
				   $check_in,
				   $invariant,
				   # a mapping to local variable names
				   {
				       contractor => "contractor",
				       validator  => "validator_in",
				       check      => "check_in",
				       invariant  => "invariant",
				       list_check => "list_checks_in",
				       hash_check => "hash_checks_in",
				   },
				   );

    my $code_post = _generate_code('after',
				   $contractor,
				   $validator_out,
				   $check_out,
				   $invariant,
				   # a mapping to local variable names
				   {
				       contractor => "contractor",
				       validator  => "validator_out",
				       check      => "check_out",
				       invariant  => "invariant",
				       list_check => "list_checks_out",
				       hash_check => "hash_checks_out",
				   },
				   );

    # find contractor's code ref
    my $cref = $self->contractor_cref;

    # if caching is enabled, start with it
    if (defined $cache) {
    }




    # wrap validation code around contracted sub


    my $str_cache_enter         = "";
    my $str_cache_return_array  = "";
    my $str_cache_return_scalar = "";

    if ($cache) {
	$str_cache_enter = sprintf q{
	    if (!defined $Sub::Contract::wantarray) {
		_croak "calling memoized contracted subroutine %s in void context";
	    }

	    if (grep({ ref $_; } @_)) {
		_croak "contract cannot memoize result when input arguments contain references";
	    }

	    my $key = join(":", map( { (defined $_) ? $_ : "undef"; } ( ($Sub::Contract::wantarray) ? "array":"scalar"),@_));
	    if ($cache->exists($key)) {
                if ($Sub::Contract::wantarray) {
		    return @{$cache->get($key)};
		} else {
		    return $cache->get($key);
		}
	    }
	}, $contractor;

	$str_cache_return_array = sprintf q{
	    $cache->set($key,\@Sub::Contract::results);
	};

	$str_cache_return_scalar = sprintf q{
	    $cache->set($key,$s);
	};
    }

    my $str_contract = sprintf q{
	use Carp;

	my $cref_pre = sub {
	    %s
	};

	my $cref_post = sub {
	    %s
	};

	$contract = sub {

	    local $Sub::Contract::wantarray = wantarray;

	    %s

	    # TODO: this code is not re-entrant. use local variables for args/wantarray/results. is local enough?

	    local @Sub::Contract::args = @_;
	    local @Sub::Contract::results = ();

	    if (!defined $Sub::Contract::wantarray) {
		# void context
		&$cref_pre() if ($cref_pre);  # TODO: those if ($cref_pre/post) could be removed
		&$cref(@Sub::Contract::args);
		@Sub::Contract::results = ();
		&$cref_post(@Sub::Contract::results) if ($cref_post);
		return ();

	    } elsif ($Sub::Contract::wantarray) {
		# array context
		&$cref_pre() if ($cref_pre);
		@Sub::Contract::results = &$cref(@Sub::Contract::args);
		&$cref_post() if ($cref_post);
		%s
		return @Sub::Contract::results;

	    } else {
		# scalar context
		&$cref_pre() if ($cref_pre);
		my $s = &$cref(@Sub::Contract::args);
		@Sub::Contract::results = ($s);
		&$cref_post() if ($cref_post);
		%s
		return $s;
	    }
	}
    },
    $code_pre,
    $code_post,
    $str_cache_enter,
    $str_cache_return_array,
    $str_cache_return_scalar;


    # compile code
    $str_contract =~ s/^\s+//gm;

    debug(2,join("\n",
		 "Sub::Contract: wrapping this code around [".$self->contractor."]:",
		 "-------------------------------------------------------",
		 $str_contract,
		 "-------------------------------------------------------"));

    my $contract;
    eval $str_contract;

    if (defined $@ and $@ ne "") {
	confess "BUG: failed to compile contract ($@)";
    }

    # replace contractor with contract sub
    $^W = 0;
    no strict 'refs';
    no warnings;
    *{ $self->contractor } = $contract;

    my $name = $self->contractor;
    $name =~ s/::([^:]+)$/::contract_$1/;
    subname $name, $contract;

    $self->{is_enabled} = 1;

    return $self;
}

sub disable {
    my $self = shift;
    if ($self->{is_enabled}) {
	debug(1,"Sub::Contract: disabling contract on [".$self->contractor."]");

	# restore original sub
	$^W = 0;
	no strict 'refs';
	no warnings;
	*{ $self->contractor } = $self->{contractor_cref};

	# TODO: remove memoization
	$self->{is_enabled} = 0;
    }
    return $self;

}

sub is_enabled {
    return $_[0]->{is_enabled};
}

#---------------------------------------------------------------
#
#   _compile - generate the code to validate the contract before
#              or after a call to the contractor function
#

# TODO: insert _croak inline in compiled code
# croak from contract code, with proper stack level
sub _croak {
    my $msg = shift;
    local $Carp::CarpLevel = 2;
    confess "$msg";
}

# TODO: insert _run inline in compiled code
# run a condition, with proper stack level if croak
sub _run {
    my ($func,@args) = @_;
    local $Carp::CarpLevel = 4;
    my $res = $func->(@args);
    local $Carp::CarpLevel = 0; # is this needed? isn't local doing its job?
    return $res;
}

# The strategy we use for building the contract validation sub is to
# to (quite horribly) build a string containing the code of the validation sub,
# then compiling this code with eval. We could instead use a closure,
# but that would mean that many things we can test at compile time would
# end up being tested each time the closure is called which would be a
# waste of cpu.

sub _generate_code {
    my ($state,$contractor,$validator,$check_condition,$check_invariant,$varnames) = @_;
    my (@list_checks,%hash_checks);

    croak "BUG: wrong state" if ($state !~ /^before|after$/);

    # the code validating the pre or post-call part of the contract, as a string
    my $str_code = "";

    # code validating the contract invariant
    if (defined $check_invariant) {
	$str_code .= sprintf q{
	    if (!_run($%s,@Sub::Contract::args)) {
		_croak "invariant fails %s calling subroutine [$%s]";
	    }
	}, $varnames->{invariant}, $state, $varnames->{contractor};
    }

    # code validating the contract pre/post condition
    if (defined $check_condition) {
	if ($state eq 'before') {
	    $str_code .= sprintf q{
		if (!_run($%s,@Sub::Contract::args)) {
		    _croak "pre-condition fails before calling subroutine [$%s]";
		}
	    }, $varnames->{check}, $varnames->{contractor};
	} else {
	    # if the contractor is called without context, the result is set to ()
	    # so we can't validate the returned arguments. maybe we should issue a warning?
	    $str_code .= sprintf q{
		if (!_run($%s,@Sub::Contract::results)) {
		    _croak "post-condition fails after calling subroutine [$%s]";
		}
	    }, $varnames->{check}, $varnames->{contractor};
	}
    }

    # compile the arguments validation code
    if (defined $validator) {

	@list_checks = @{$validator->list_checks};
	%hash_checks = %{$validator->hash_checks};

	# get args/@_ from right source
	if ($state eq 'before') {
	    $str_code .= q{ my @args = @Sub::Contract::args; };
	} else {
	    $str_code .= q{ my @args = @Sub::Contract::results; };
	}

	# do we have arguments to validate?
	if ($validator->has_list_args || $validator->has_hash_args) {

	    # add code validating heading arguments passed in list style
	    my $pos = 1;
	    for (my $i=0; $i<scalar(@list_checks); $i++) {
		if (defined $list_checks[$i]) {
		    $str_code .= sprintf q{
			_croak "%s argument %s of [$%s] fails its contract constraint" if (!_run($%s[%s], $args[0]));
		    },
		    ($state eq 'before')?'input':'return',
		    $pos,
		    $varnames->{contractor},
		    $varnames->{list_check},
		    $i;
		}

		$str_code .= q{
		    shift @args;
		};
		$pos++;
	    }

	    # add code validating trailing arguments passed in hash style
	    if ($validator->has_hash_args) {

		# croak if odd number of elements
		$str_code .= sprintf q{
		    _croak "odd number of hash-style %s arguments in [$%s]" if (scalar @args %% 2);
		    my %%args = @args;
		},
		($state eq 'before')?'input':'return',
		$varnames->{contractor};

		# check the value of each key in the argument hash
		while (my ($key,$check) = each %hash_checks) {
		    if (defined $check) {
			$str_code .= sprintf q{
			    _croak "%s argument of [$%s] for key \'%s\' fails its contract constraint" if (!_run($%s{%s}, $args{%s}));
			},
			($state eq 'before')?'input':'return',
			$varnames->{contractor},
			$key,
			$varnames->{hash_check},
			$key,
			$key;
		    }

		    $str_code .= sprintf q{
			delete $args{%s};
		    }, $key;
		}
	    }
	}

	# there should be no arguments left
	if ($validator->has_hash_args) {
	    $str_code .= sprintf q{
		_croak "function [$%s] %s: ".join(" ",keys %%args) if (%%args);
	    }, $varnames->{contractor}, ($state eq 'before')?'got unexpected input argument(s)':'returned unexpected result value(s)';
	} else {
	    $str_code .= sprintf q{
		_croak "function [$%s] %s" if (@args);
	    }, $varnames->{contractor}, ($state eq 'before')?'got unexpected input argument(s)':'returned unexpected result value(s)';
	}
    }

    return $str_code;
}

1;

__END__

=head1 NAME

Sub::Contract::Compiler - Compile, enable and disable a contract

=head1 SYNOPSIS

See 'Sub::Contract'.

=head1 DESCRIPTION

Subroutine contracts defined with Sub::Contract must be compiled
and enabled in order to start applying onto the contractor. A
contractor can even be disabled later on, or recompiled after
changes. Those methods are implemented in Sub::Contract::Compiler
and inherited by Sub::Contract.

=head1 API

See 'Sub::Contract'.

=over 4

=item enable()

See 'Sub::Contract'.

=item disable()

See 'Sub::Contract'.

=item is_enabled()

See 'Sub::Contract'.

=back

=head1 SEE ALSO

See 'Sub::Contract'.

=head1 VERSION

$Id: Compiler.pm,v 1.11 2008/05/22 16:03:24 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 LICENSE

See Sub::Contract.

=cut

