#-------------------------------------------------------------------
#
#   $Id: 11_test_out.t,v 1.4 2008/06/16 13:52:40 erwan_lemonnier Exp $
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
    plan tests => 98;

    use_ok("Sub::Contract",'contract');
};

# tests
sub is_integer {
    my $val = shift;
    my $res = (defined $val && $val =~ /^\d+$/) ? 1 : 0;
#    print "is_integer: checking ".((defined $val) ? $val:"undef")." - returns $res\n";
    return $res;
}
sub is_zero    {
#    print "is_zero: checking ".($_[0]||"undef")."\n";
    return defined $_[0] && $_[0] =~ /^0$/;
}

# functions to test
my @results;
my $results;

sub foo_none  { return @results; }
sub foo_one   { return $results; }
sub foo_array { return @results; }
sub foo_hash  { return @results; }
sub foo_mixed { return @results; }

# test pre condition
eval {
    # same for package function
    contract('foo_none')
	->out()
	->enable;

    contract('foo_one')
	->out(\&is_integer)
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
	     foo_none => [],
	     undef,
	     "calling contracted subroutine main::foo_none in scalar or array context",
	     "calling contracted subroutine main::foo_none in scalar or array context",

 	     foo_none => [ 1 ],
	     "function .main::foo_none. returned unexpected result value.s.",
	     "calling contracted subroutine main::foo_none in scalar or array context",
	     "calling contracted subroutine main::foo_none in scalar or array context",

 	     foo_none => [ undef ],
	     "function .main::foo_none. returned unexpected result value.s.",
	     "calling contracted subroutine main::foo_none in scalar or array context",
	     "calling contracted subroutine main::foo_none in scalar or array context",

 	     # test 1 argument
 	     foo_one => [],
	     "return argument 1 of .main::foo_one. fails its contract constraint",
	     "return argument 1 of .main::foo_one. fails its contract constraint",
	     "calling contracted subroutine main::foo_one in array context when its contract says it returns a scalar",

 	     foo_one => [ 2 ],
	     undef,
	     undef,
	     "calling contracted subroutine main::foo_one in array context when its contract says it returns a scalar",

 	     foo_one => [ 'abc' ],
	     "return argument 1 of .main::foo_one. fails its contract constraint",
	     "return argument 1 of .main::foo_one. fails its contract constraint",
	     "calling contracted subroutine main::foo_one in array context when its contract says it returns a scalar",

 	     foo_one => [ undef ],
	     "return argument 1 of .main::foo_one. fails its contract constraint",
	     "return argument 1 of .main::foo_one. fails its contract constraint",
	     "calling contracted subroutine main::foo_one in array context when its contract says it returns a scalar",

 	     # test array arguments
 	     foo_array => [ 1234, undef, 0 ], undef, undef, undef,
 	     foo_array => [ 0, {}, 0 ], undef,undef,undef,
	     foo_array => [ 3485923847, 'abc', 0 ], undef,undef,undef,

	     foo_array => [ 1234, undef, 1 ],
	     "return argument 3 of .main::foo_array. fails its contract constraint",
	     "return argument 3 of .main::foo_array. fails its contract constraint",
	     "return argument 3 of .main::foo_array. fails its contract constraint",

	     foo_array => [ 1234, undef, undef ],
	     "return argument 3 of .main::foo_array. fails its contract constraint",
	     "return argument 3 of .main::foo_array. fails its contract constraint",
	     "return argument 3 of .main::foo_array. fails its contract constraint",

	     foo_array => [ 'abc', undef, 0 ],
	     "return argument 1 of .main::foo_array. fails its contract constraint",
	     "return argument 1 of .main::foo_array. fails its contract constraint",
	     "return argument 1 of .main::foo_array. fails its contract constraint",

	     foo_array => [ 1234, undef, 0, undef ],
	     "function .main::foo_array. returned unexpected result value.s.",
	     "function .main::foo_array. returned unexpected result value.s.",
	     "function .main::foo_array. returned unexpected result value.s.",

 	     foo_array => [ 1234, undef ],
	     "return argument 3 of .main::foo_array. fails its contract constraint",
	     "return argument 3 of .main::foo_array. fails its contract constraint",
	     "return argument 3 of .main::foo_array. fails its contract constraint",

 	     foo_array => [ 1234 ],
	     "return argument 3 of .main::foo_array. fails its contract constraint",
	     "return argument 3 of .main::foo_array. fails its contract constraint",
	     "return argument 3 of .main::foo_array. fails its contract constraint",

 	     foo_array => [ ],
	     "return argument 1 of .main::foo_array. fails its contract constraint",
	     "return argument 1 of .main::foo_array. fails its contract constraint",
	     "return argument 1 of .main::foo_array. fails its contract constraint",

 	     # test hash arguments
 	     foo_hash => [ a => 0, b => 128376 ], undef,undef,undef,
 	     foo_hash => [ b => 128376, a => 0 ], undef,undef,undef,

 	     foo_hash => [ b => 128376, a => 0, c => 0 ],
	     "function .main::foo_hash. returned unexpected result value.s.",
	     "function .main::foo_hash. returned unexpected result value.s.",
	     "function .main::foo_hash. returned unexpected result value.s.",

 	     foo_hash => [ b => 128376, a => 0, 0 ],
	     "odd number of hash-style return arguments in .main::foo_hash.",
	     "odd number of hash-style return arguments in .main::foo_hash.",
	     "odd number of hash-style return arguments in .main::foo_hash.",

 	     foo_hash => [ b => 128376, a => 1 ],
	     "return argument of .main::foo_hash. for key \'a\' fails its contract constraint",
	     "return argument of .main::foo_hash. for key \'a\' fails its contract constraint",
	     "return argument of .main::foo_hash. for key \'a\' fails its contract constraint",

 	     foo_hash => [ b => 128376, a => undef ],
	     "return argument of .main::foo_hash. for key \'a\' fails its contract constraint",
	     "return argument of .main::foo_hash. for key \'a\' fails its contract constraint",
	     "return argument of .main::foo_hash. for key \'a\' fails its contract constraint",

 	     foo_hash => [ b => 'abc', a => 0 ],
	     "return argument of .main::foo_hash. for key \'b\' fails its contract constraint",
	     "return argument of .main::foo_hash. for key \'b\' fails its contract constraint",
	     "return argument of .main::foo_hash. for key \'b\' fails its contract constraint",

 	     foo_hash => [ b => [0], a => 0 ],
	     "return argument of .main::foo_hash. for key \'b\' fails its contract constraint",
	     "return argument of .main::foo_hash. for key \'b\' fails its contract constraint",
	     "return argument of .main::foo_hash. for key \'b\' fails its contract constraint",

	     # test mixed arguments
	     foo_mixed => [ 0, 123, a => 0, b => 128376 ], undef,undef,undef,
	     foo_mixed => [ 'abc', 654, a => 0, b => 1 ], undef,undef,undef,

	     foo_mixed => [ undef, 'abc', a => 0, b => 1 ],
	     "return argument 2 of .main::foo_mixed. fails its contract constraint",
	     "return argument 2 of .main::foo_mixed. fails its contract constraint",
	     "return argument 2 of .main::foo_mixed. fails its contract constraint",

	     foo_mixed => [ undef, 1, a => 1, b => 1 ],
	     "return argument of .main::foo_mixed. for key \'a\' fails its contract constraint",
	     "return argument of .main::foo_mixed. for key \'a\' fails its contract constraint",
	     "return argument of .main::foo_mixed. for key \'a\' fails its contract constraint",

	     foo_mixed => [ undef, 1, a => 0, b => undef ],
	     "return argument of .main::foo_mixed. for key \'b\' fails its contract constraint",
	     "return argument of .main::foo_mixed. for key \'b\' fails its contract constraint",
	     "return argument of .main::foo_mixed. for key \'b\' fails its contract constraint",

	     foo_mixed => [ undef, 1, a => 0, b => undef, 12 ],
	     "odd number of hash-style return arguments in .main::foo_mixed.",
	     "odd number of hash-style return arguments in .main::foo_mixed.",
	     "odd number of hash-style return arguments in .main::foo_mixed.",

	     foo_mixed => [ undef, 1, a => 0 ],
	     "return argument of .main::foo_mixed. for key \'b\' fails its contract constraint",
	     "return argument of .main::foo_mixed. for key \'b\' fails its contract constraint",
	     "return argument of .main::foo_mixed. for key \'b\' fails its contract constraint",
	     );

while (@tests) {
    my $func         = shift @tests;
    @results         = @{ shift @tests };
    my $match_void   = shift @tests;
    my $match_scalar = shift @tests;
    my $match_array  = shift @tests;

    my $args = join(",", map({ (defined $_)?$_:"undef" } @results));

    if ($func eq "foo_one") {
	($results) = @results;
    }

    # call in void context
    eval {
	no strict 'refs';
	&$func();
    };

    if ($match_void) {
	ok( $@ =~ /$match_void/, "void context: $func dies on returning [$args]" );
    } else {
	ok( !defined $@ || $@ eq '', "void context: $func does not die on returning [$args]" );
    }

    # call in scalar context
    eval {
	no strict 'refs';
	my $s = &$func();
    };

    if ($match_scalar) {
	ok( $@ =~ /$match_scalar/, "scalar context: $func dies on returning [$args]" );
    } else {
	ok( !defined $@ || $@ eq '', "scalar context: $func does not die on returning [$args]" );
    }

    # call in array context
    eval {
	no strict 'refs';
	my @s = &$func();
    };

    if ($match_array) {
	ok( $@ =~ /$match_array/, "array context: $func dies on returning [$args]" );
    } else {
	ok( !defined $@ || $@ eq '', "array context: $func does not die on returning [$args]" );
    }
}


