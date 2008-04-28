#-------------------------------------------------------------------
#
#   $Id: 03_test_invariant.t,v 1.4 2008/04/28 15:43:32 erwan_lemonnier Exp $
#

package My::Test;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Sub::Contract qw(contract);

my $zoulou = 3;

sub foo {
    $zoulou = $_[0];
}

sub test_invariant {
    return $zoulou == 3;
}

sub set_zoulou { $zoulou = shift }

package main;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Test::More;
use Data::Dumper;

BEGIN {

    use check_requirements;
    plan tests => 10;

    use_ok("Sub::Contract",'contract');
};

contract('My::Test::foo')
    ->invariant(\&My::Test::test_invariant)
    ->enable;

# void context
eval { My::Test::foo(3) };
ok(!defined $@ || $@ eq "", "invariant passes ($@)");

eval { My::Test::foo(2) };
ok( $@ =~ /invariant fails after calling subroutine \[My::Test::foo\] at .*03_test_invariant.t line 49/, "invariant fails after");

eval { My::Test::foo(3) };
ok( $@ =~ /invariant fails before calling subroutine \[My::Test::foo\] at .*03_test_invariant.t line 52/, "invariant fails before");

# scalar context
My::Test::set_zoulou(3);
eval { my $s = My::Test::foo(3) };
ok(!defined $@ || $@ eq "", "invariant passes");

eval { my $s = My::Test::foo(2) };
ok( $@ =~ /invariant fails after calling subroutine \[My::Test::foo\] at .*03_test_invariant.t line 60/, "invariant fails after");

eval { my $s = My::Test::foo(3) };
ok( $@ =~ /invariant fails before calling subroutine \[My::Test::foo\] at .*03_test_invariant.t line 63/, "invariant fails before");

# array context
My::Test::set_zoulou(3);
eval { my @s = My::Test::foo(3) };
ok(!defined $@ || $@ eq "", "invariant passes");

eval { my @s = My::Test::foo(2) };
ok( $@ =~ /invariant fails after calling subroutine \[My::Test::foo\] at .*03_test_invariant.t line 71/, "invariant fails after");

eval { my @s = My::Test::foo(3) };
ok( $@ =~ /invariant fails before calling subroutine \[My::Test::foo\] at .*03_test_invariant.t line 74/, "invariant fails before");



