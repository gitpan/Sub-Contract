#-------------------------------------------------------------------
#
#   $Id: 11_test_out.t,v 1.3 2008/05/07 09:08:21 erwan_lemonnier Exp $
#

package My::Test;

sub new { return bless({},'My::Test'); }
sub method_hash { return 1; }

package main;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Test::More;
use Data::Dumper;
use Carp qw(croak);

BEGIN {

    use check_requirements;
    plan tests => 30;

    use_ok("Sub::Contract",'contract');
};

# tests
sub is_integer {
#    print "is_integer: checking ".($_[0]||"undef")."\n";
    return defined $_[0] && $_[0] =~ /^\d+$/;
}
sub is_zero    {
#    print "is_zero: checking ".($_[0]||"undef")."\n";
    return defined $_[0] && $_[0] =~ /^0$/;
}

# functions to test
my @results;

sub foo_none  { return @results; }
sub foo_array { return @results; }
sub foo_hash  { return @results; }
sub foo_mixed { return @results; }

# test pre condition
eval {
    # same for package function
    contract('foo_none')
	->out()
	->enable;

    contract('foo_array')
	->out(\&is_integer,
	      undef,
	      \&is_zero,
	      )
	->enable;

    contract('foo_hash')
	->out(a => \&is_zero,
	      b => \&is_integer,
	      )
	->enable;

    contract('foo_mixed')
	->out(undef,
	      \&is_integer,
	      a => \&is_zero,
	      b => \&is_integer,
	      )
	->enable;

};

ok(!defined $@ || $@ eq '', "compiled contracts");

my @tests = (
	     # test no arguments
	     foo_none => [], undef,
	     foo_none => [ 1 ], "function .main::foo_none. returned unexpected result value.s.",
	     foo_none => [ undef ], "function .main::foo_none. returned unexpected result value.s.",

	     # test array arguments
	     foo_array => [ 1234, undef, 0 ], undef,
	     foo_array => [ 0, {}, 0 ], undef,
	     foo_array => [ 3485923847, 'abc', 0 ], undef,
	     foo_array => [ 1234, undef, 1 ], "return argument 3 of .main::foo_array. fails its contract constraint",
	     foo_array => [ 1234, undef, undef ], "return argument 3 of .main::foo_array. fails its contract constraint",
	     foo_array => [ 'abc', undef, 0 ], "return argument 1 of .main::foo_array. fails its contract constraint",

	     foo_array => [ 1234, undef, 0, undef ], "function .main::foo_array. returned unexpected result value.s.",
	     foo_array => [ 1234, undef ], "return argument 3 of .main::foo_array. fails its contract constraint",
	     foo_array => [ 1234 ], "return argument 3 of .main::foo_array. fails its contract constraint",
	     foo_array => [ ], "return argument 1 of .main::foo_array. fails its contract constraint",

	     # test hash arguments
	     foo_hash => [ a => 0, b => 128376 ], undef,
	     foo_hash => [ b => 128376, a => 0 ], undef,
	     foo_hash => [ b => 128376, a => 0, c => 0 ], "function .main::foo_hash. returned unexpected result value.s.",
	     foo_hash => [ b => 128376, a => 0, 0 ], "odd number of hash-style return arguments in .main::foo_hash.",
	     foo_hash => [ b => 128376, a => 1 ], "return argument of .main::foo_hash. for key \'a\' fails its contract constraint",
	     foo_hash => [ b => 128376, a => undef ], "return argument of .main::foo_hash. for key \'a\' fails its contract constraint",
	     foo_hash => [ b => 'abc', a => 0 ], "return argument of .main::foo_hash. for key \'b\' fails its contract constraint",
	     foo_hash => [ b => [0], a => 0 ], "return argument of .main::foo_hash. for key \'b\' fails its contract constraint",

	     # test mixed arguments
	     foo_mixed => [ 0, 123, a => 0, b => 128376 ], undef,
	     foo_mixed => [ 'abc', 654, a => 0, b => 1 ], undef,
	     foo_mixed => [ undef, 'abc', a => 0, b => 1 ], "return argument 2 of .main::foo_mixed. fails its contract constraint",
	     foo_mixed => [ undef, 1, a => 1, b => 1 ], "return argument of .main::foo_mixed. for key \'a\' fails its contract constraint",
	     foo_mixed => [ undef, 1, a => 0, b => undef ], "return argument of .main::foo_mixed. for key \'b\' fails its contract constraint",
	     foo_mixed => [ undef, 1, a => 0, b => undef, 12 ], "odd number of hash-style return arguments in .main::foo_mixed.",
	     foo_mixed => [ undef, 1, a => 0 ], "return argument of .main::foo_mixed. for key \'b\' fails its contract constraint",

	     );

while (@tests) {
    my $func = shift @tests;
    @results = @{ shift @tests };
    my $match = shift @tests;
    my $args = join(",", map({ (defined $_)?$_:"undef" } @results));

    my @got;

    eval {
	no strict 'refs';

	# note: func should return a list even though called in undef context
	if ($func =~ /method/) {
	    @got = My::Test->$func();
	} else {
	    @got = &$func();
	}
    };

    if ($match) {
	ok( $@ =~ /$match.*\n.*(My::Test|main)::contract_$func\(.*at .*11_test_out.t line \d+/, "$func dies on returning [$args]" );
    } else {
	ok( !defined $@ || $@ eq '', "$func does not die on returning [$args]" );
    }
}



