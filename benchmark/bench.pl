use strict;
use warnings;
use lib "../lib/", "t/", "lib/",".";
use Benchmark qw(:all);

use Sub::Contract;
use ContractClosure;

# TODO: copy pluto version to t/, use Test::Benchmark, bench even hash args and mixes, bench cache

sub test { return 1 }

sub foo1 { return @_ }

sub foo2 { return @_ }

sub foo3 {
    my ($a) = shift @_;
    die "bleh" if (@_);
    die "bloo" if (!defined $a);
    return $a;
}

Sub::Contract::contract('foo1')->in(\&test)->out(\&test)->enable;

ContractClosure::contract('foo2',
			  in => { defined => 1,
				  check => [ \&test ],
			      },
    out => { defined => 1,
	     check => [ \&test ],
	 },
    );

timethese(1000000, {
    'Sub::Contract'   => sub { foo1(1) },
    'ContractClosure' => sub { foo2(1) },
    'Inline'          => sub { foo3(1) },
}
);
