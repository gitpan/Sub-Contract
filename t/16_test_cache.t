#-------------------------------------------------------------------
#
#   $Id: 16_test_cache.t,v 1.1 2008/05/22 16:02:03 erwan_lemonnier Exp $
#

package main;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Test::More;
use Data::Dumper;

BEGIN {

    use check_requirements;
    plan tests => 24;

    use_ok("Sub::Contract",'contract');
};

my @results;

sub foo_array {
    return @results;
}

my $results;

sub foo_scalar {
    return $results;
}

my $c1 = contract('foo_array')->cache->enable;
my $c2 = contract('foo_scalar')->cache->enable;

my $obj1 = bless({ a=> 1},"oops");

my @tests = (
	     # @results,  foo args,  foo results

	     # caching various structs in scalar contexts
	     0, 123, ["abc"], 123,
	     0, 456, ["abc"], 123,
	     0, 456, ["bcd"], 456,
	     0, 3, ["bcd"], 456,
	     0, 4, ["bcd"], 456,

	     0, "bob", [1,2,3], "bob",
	     0, "123", [1,2,3], "bob",
	     0, "789", [1,2,3], "bob",

	     0, $obj1,     [1,2],   $obj1,
	     0, undef,     [1,2],   $obj1,

	     0, [1,2,[3,4]],            ["bob"], [1,2,[3,4]],
	     0, undef,                  ["bob"], [1,2,[3,4]],
	     0, "o",                    ["bab"], "o",

	     # caching various structs in array contexts
	     1, [1,2,3], ["abc"], [1,2,3],
	     1, [],      ["abc"], [1,2,3],
	     1, [],      ["abc"], [1,2,3],
	     1, [],      ["bcd"], [],

	     1, [ $obj1 ], [1,2],   [ $obj1 ],
	     1, [ undef ], [1,2],   [ $obj1 ],

	     1, [1,2,[3,4]],  ["bob"], [1,2,[3,4]],
	     1, [],           ["bob"], [1,2,[3,4]],

	     );

while (@tests) {
    my $wantarray = shift @tests;
    my $res  = shift @tests;
    my $args = shift @tests;
    my $want = shift @tests;

    if ($wantarray) {
	@results = @{$res};
	my @a = foo_array(@$args);
	is_deeply(\@a,$want,"\@{foo(".join(",",@$args).")} = (".join(",",@$want).")");
    } else {
	$results = $res;
	my $a = foo_scalar(@$args);
	is_deeply($a,$want,"\${foo(".join(",",@$args).")} = ".$want);
    }
}

# key contain references
eval { my $a = foo_scalar({1,2,3,4},3); };
ok($@ =~ /contract cannot memoize result when input arguments contain references/, "contract fail if args contain references");

# wrong context
eval { foo_scalar(3,3); };
ok($@ =~ /calling memoized contracted subroutine main::foo_scalar in void context/, "contract fail when void context");

# TODO: fill cache heavily
