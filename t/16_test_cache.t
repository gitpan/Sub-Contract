#-------------------------------------------------------------------
#
#   $Id: 16_test_cache.t,v 1.4 2008/06/18 14:02:31 erwan_lemonnier Exp $
#

package main;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Test::More;
use Data::Dumper;

BEGIN {

    use check_requirements;
    plan tests => 27;

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
ok($@ =~ /cannot memoize result of main::foo_scalar when input arguments contain references/, "contract fail if args contain references");

# wrong context
eval { foo_scalar(3,3); };
ok($@ =~ /calling memoized subroutine main::foo_scalar in void context/, "contract fail when void context");

# test an early bug, in which different subs shared the same cache
contract("pif")->cache->enable;
contract("paf")->cache->enable;

sub pif {
    return (a => 1, b => 2);
}

sub paf {
    return (a => "boum");
}

my %r1 = pif(1,2,3);
is_deeply(\%r1, {a => 1, b => 2}, "calling pif once");
%r1 = pif(1,2,3);
is_deeply(\%r1, {a => 1, b => 2}, "calling pif twice");

%r1 = paf(1,2,3);
is_deeply(\%r1, {a => "boum"}, "calling paf. got paf's answer and not pif's");

# TODO: fill cache heavily
