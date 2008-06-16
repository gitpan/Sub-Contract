#-------------------------------------------------------------------
#
#   $Id: 09_test_too_many_args.t,v 1.3 2008/06/13 15:27:50 erwan_lemonnier Exp $
#

package main;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Test::More;
use Data::Dumper;
use Carp qw(croak);

BEGIN {

    use check_requirements;
    plan tests => 41;

    use_ok("Sub::Contract",'contract');
};

my @res;

# functions to test
contract('foo_none')
    ->in()
    ->out()
    ->enable;

sub foo_none  { return @res; }

contract('foo_array')
    ->in(undef,undef)
    ->out(undef,undef)
    ->enable;

sub foo_array { return @res; }

contract('foo_hash')
    ->in(a => undef, b => undef)
    ->out(c => undef, d => undef)
    ->enable;

sub foo_hash  { return @res; }

contract('foo_mixed')
    ->in(undef,undef,a => undef, b => undef)
    ->out(undef,undef,c => undef, d => undef)
    ->enable;

sub foo_mixed { return @res; }

# test foo_none
eval { foo_none() };
ok(!defined $@ || $@ eq "", "foo_none no args");

eval { foo_none(12) };
ok($@ =~ /got unexpected input argument\(s\)/, "foo_none unexpected input arguments");

@res = ();
eval { foo_none() };
ok(!defined $@ || $@ eq "", "foo_none with 0 result values and void context");
eval { my $s = foo_none() };
ok($@ =~ /calling contracted subroutine main::foo_none in scalar or array context/, "foo_none with 0 result values and scalar context");
eval { my @s = foo_none() };
ok($@ =~ /calling contracted subroutine main::foo_none in scalar or array context/, "foo_none with 0 result values and array context");

@res = (1);
eval { foo_none() };
ok($@ =~ /returned unexpected result value\(s\)/, "foo_none with 1 result values and void context");
eval { my $s = foo_none() };
ok($@ =~ /calling contracted subroutine main::foo_none in scalar or array context/, "foo_none with 1 result values and scalar context");
eval { my @s = foo_none() };
ok($@ =~ /calling contracted subroutine main::foo_none in scalar or array context/, "foo_none with 1 result values and array context");

@res = (1,2);
eval { foo_none() };
ok($@ =~ /returned unexpected result value\(s\)/, "foo_none with 2 result values and void context");
eval { my $s = foo_none() };
ok($@ =~ /calling contracted subroutine main::foo_none in scalar or array context/, "foo_none with 2 result values and scalar context");
eval { my @s = foo_none() };
ok($@ =~ /calling contracted subroutine main::foo_none in scalar or array context/, "foo_none with 2 result values and array context");

# test foo_array
eval { foo_array(3,4) };
ok(!defined $@ || $@ eq "", "foo_array 2 input args");

eval { foo_array(1) };
ok(!defined $@ || $@ eq "", "foo_array 1 input arg");

eval { foo_array(3,4,6) };
ok($@ =~ /got unexpected input argument\(s\)/, "foo_array 3 input args");

# we miss that the 2nd return value is missing. that's fine
@res = (1);
eval { foo_array() };
ok(!defined $@ || $@ eq "", "foo_array with 1 result values and void context");
eval { my $s = foo_array() };
ok(!defined $@ || $@ eq "", "foo_array with 1 result values and scalar context");
eval { my @s = foo_array() };
ok(!defined $@ || $@ eq "", "foo_array with 1 result values and array context");

@res = (1,2);
eval { foo_array() };
ok(!defined $@ || $@ eq "", "foo_array with 2 result values and void context");
eval { my $s = foo_array() };
ok(!defined $@ || $@ eq "", "foo_array with 2 result values and scalar context");
eval { my @s = foo_array() };
ok(!defined $@ || $@ eq "", "foo_array with 2 result values and array context");

@res = (1,2,3);
eval { foo_array() };
ok($@ =~ /returned unexpected result value\(s\)/, "foo_array with 3 result values and void context");
eval { my $s = foo_array() };
ok($@ =~ /returned unexpected result value\(s\)/, "foo_array with 3 result values and scalar context");
eval { my @s = foo_array() };
ok($@ =~ /returned unexpected result value\(s\)/, "foo_array with 3 result values and array context");

# test foo_hash
@res = (c => 1, d => 2);
eval { foo_hash(a => 1, b => 2) };
ok(!defined $@ || $@ eq "", "foo_hash 2 input hash args ($@)");

eval { foo_hash(a => 1, bboo => 2) };
ok($@ =~ /got unexpected input argument\(s\): bboo/, "foo_hash unexpected input args");

eval { foo_hash(a => 1) };
ok(!defined $@ || $@ eq "", "foo_hash only 1 input arg");

# missing keys = ok
@res = (c => 1);
eval { foo_hash() };
ok(!defined $@ || $@ eq "", "foo_hash with 1 result values and void context");
eval { my $s = foo_hash() };
ok(!defined $@ || $@ eq "", "foo_hash with 1 result values and scalar context");
eval { my @s = foo_hash() };
ok(!defined $@ || $@ eq "", "foo_hash with 1 result values and array context");

@res = (c => 1, d => 2, poo => 5);
eval { foo_hash() };
ok($@ =~ /returned unexpected result value\(s\): poo/, "foo_hash with 3 result values and void context");
eval { my $s = foo_hash() };
ok($@ =~ /returned unexpected result value\(s\): poo/, "foo_hash with 3 result values and scalar context");
eval { my @s = foo_hash() };
ok($@ =~ /returned unexpected result value\(s\): poo/, "foo_hash with 3 result values and array context");

# just to improve coverage:
eval { my $s = foo_hash(1,2,3) };
ok($@ =~ /odd number of hash-style input arguments/, "foo_hash with 3 input values but scalar context");

# test foo_mixed
@res = (0,1,c => 1, d => 2);
eval { foo_mixed(0,1,a => 1, b => 2) };
ok(!defined $@ || $@ eq "", "foo_mixed 4 input hash/list args");

eval { foo_mixed(0,1,a => 1, o => 2) };
ok($@ =~ /got unexpected input argument\(s\)/, "foo_mixed unexpected input args");

eval { foo_mixed(0,1,a => 1, o => 2,8) };
ok($@ =~ /odd number of hash-style input arguments/, "foo_mixed with 5 input values but scalar context");

eval { foo_mixed(a => 1) };
ok(!defined $@ || $@ eq "", "foo_mixed only 1 input arg");

@res = (1,2,c => 1, d => 2, p => 5);
eval { foo_mixed() };
ok($@ =~ /returned unexpected result value\(s\): p/, "foo_mixed with 8 result values and void context");
eval { my $s = foo_mixed() };
ok($@ =~ /returned unexpected result value\(s\): p/, "foo_mixed with 8 result values and scalar context");
eval { my @s = foo_mixed() };
ok($@ =~ /returned unexpected result value\(s\): p/, "foo_mixed with 8 result values and array context");



