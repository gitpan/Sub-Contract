#-------------------------------------------------------------------
#
#   $Id: 02_test_basic_contract.t,v 1.4 2008/04/25 13:52:07 erwan_lemonnier Exp $
#

#-------------------------------------------------------------------
#
#   test package
#

package My::Test;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Sub::Contract qw(contract);

sub foo { return 'test'; };

sub get_contract {
    return contract('foo');
}

#-------------------------------------------------------------------
#
#   main tests
#

package main;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Test::More;
use Data::Dumper;

BEGIN {

    use check_requirements;
    plan tests => 25;

    use_ok("Sub::Contract",'contract');
    use_ok("Sub::Contract::Pool",'get_contract_pool');
};

my $value;
sub foo { return $value; }

my $c1 = contract('foo');

# test that the contract pool now contains all those contracts
my $pool = get_contract_pool();
is(ref $pool, 'Sub::Contract::Pool', "check got a contract pool");

my @all = $pool->list_all_contracts();
is(scalar @all, 1, "one contract registered");
is_deeply($all[0], $c1, "that's the expected contract");

# test private attributes
my $expect = {
    is_memoized => 0,
    is_enabled => 0,
    contractor => 'main::foo',
    pre => undef,
    post => undef,
    in => undef,
    out => undef,
    invariant => undef,
};

is_deeply($c1, $expect, "check contract structure");

# check alternative constructors
$c1->{contractor} = 'main::foo2';
my $c2 = new Sub::Contract('foo2');
is_deeply($c1,$c2,"new Sub::Contract() returns same as contract()");

$c1->{contractor} = 'main::foo3';
my $c3 = Sub::Contract->new('foo3');
is_deeply($c1,$c3,"Sub::Contract->new() returns same as contract()");

$c1->{contractor} = 'main::foo4';
my $c4 = Sub::Contract->new('foo4', caller => 'main');
is_deeply($c1,$c4,"Sub::Contract->new() returns same as contract() when caller specified");

$c1->{contractor} = 'My::Test::foo';
is_deeply($c1,My::Test::get_contract,"same when called from another package than main::");

$c1->{contractor} = 'My::Test::foo2';
my $c6 = Sub::Contract->new('foo2', caller => 'My::Test');
is_deeply($c1,$c6,"same as above, but set by caller =>");


$c1->{contractor} = "main::foo";

# testing contractor
is($c1->contractor,"main::foo","test contractor");
is($c2->contractor,"main::foo2","test contractor");
is($c3->contractor,"main::foo3","test contractor");
is($c4->contractor,"main::foo4","test contractor");

# check that whatever happened didn't affect the contractor
$value = "bob";
is(foo(),"bob","foo returns bob before contract enabled");

# now enabling contract
$c1->enable();
is(foo(),"bob","foo returns bob after contract enabled");

# now disabling contract
$c1->disable();
is(foo(),"bob","foo returns bob after contract disabled");

# how is the pool now?
@all = $pool->list_all_contracts();
is(scalar @all, 6, "pool now contains 6 contracts");

# test croaks in new()
eval { Sub::Contract->new('foo') };
ok( $@ =~ /trying to contract function \[main::foo\] twice at .*02_test_basic_contract.t/, "croak when contracting a sub twice");

eval { Sub::Contract->new() };
ok( $@ =~ /new\(\) expects a subroutine name as first argument at .*02_test_basic_contract.t/, "croak when undefined sub in new()");

eval { Sub::Contract->new('blah',1,2) };
ok( $@ =~ /new\(\) got unknown arguments:/, "croak when unknown arguments in new()");

# test croaks in contract()
eval { contract() };
ok( $@ =~ /contract\(\) expects only one argument, a subroutine name at .*02_test_basic_contract.t/, "contract() croaks on no arguments");

eval { contract(1,2) };
ok( $@ =~ /contract\(\) expects only one argument, a subroutine name at .*02_test_basic_contract.t/, "contract() croaks on too many arguments");

eval { contract(undef) };
ok( $@ =~ /contract\(\) expects only one argument, a subroutine name at .*02_test_basic_contract.t/, "contract() croaks on undefined argument");

# TODO: test more croaks?



