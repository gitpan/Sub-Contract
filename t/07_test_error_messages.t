#-------------------------------------------------------------------
#
#   $Id: 07_test_error_messages.t,v 1.3 2008/04/25 14:01:52 erwan_lemonnier Exp $
#

package main;

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Test::More;
use Data::Dumper;
use Carp qw(croak confess longmess);

BEGIN {

    use check_requirements;
    plan tests => 9;

    use_ok("Sub::Contract",'contract');
};

#------------------------------------------------------------
#
# test errors in condition code
#
#------------------------------------------------------------

sub foo {
    return 1;
}

sub _die {
    die "whatever";
}

# test die from a sub
my $c = contract('foo')
    ->invariant(\&_die)
    ->enable;

eval { foo(); };
ok($@ =~ /whatever at .*07_test_error_messages.t line 34/, "condition dies with correct error message (called sub)");

# test die called from contract def
$c->reset
    ->invariant(sub {
	die "enough!!";
    })
    ->enable;

eval { foo(); };
ok($@ =~ /enough!! at .*07_test_error_messages.t line 48/, "condition dies with correct error message (anonymous sub)");

# test croak
$c->reset
    ->invariant(sub {
	croak "croaking now";
    })
    ->enable;

eval { foo(); };
ok($@ =~ /croaking now at .*07_test_error_messages.t line 62/, "condition croaks with correct error message (anonymous sub)");

# test confess
$c->reset
    ->invariant(sub {
	confess "confessing now";
    })
    ->enable;

eval { foo(); };

ok($@ =~ /confessing now at .*07_test_error_messages.t line 72/, "condition confesses with correct error message (anonymous sub)");

#------------------------------------------------------------
#
# test constraint failures
#
#------------------------------------------------------------

# invariant before
$c->reset->invariant( sub { return 0; } )->enable;
eval { foo(); };
ok($@ =~ /invariant fails before calling subroutine \[main::foo\] at .*07_test_error_messages.t line 84/, "invariant fails before");

# invariant after
my $count = 0;
$c->reset->invariant( sub { $count++; return $count != 1; } )->enable;
eval { foo(); };
ok($@ =~ /invariant fails before calling subroutine \[main::foo\] at .*07_test_error_messages.t line 90/, "invariant fails before");

# pre fails
$c->reset->pre( sub { return 0; } )->enable;
eval { foo(); };
ok($@ =~ /pre-condition fails before calling subroutine \[main::foo\] at .*07_test_error_messages.t line 95/, "pre condition fails");

# post fails
$c->reset->post( sub { return 0; } )->enable;
eval { foo(); };
ok($@ =~ /post-condition fails after calling subroutine \[main::foo\] at .*07_test_error_messages.t line 100/, "post condition fails");

# TODO: add more tests

