#-------------------------------------------------------------------
#
#   $Id: 01_test_compile.t,v 1.5 2008/04/25 10:59:36 erwan_lemonnier Exp $
#

use strict;
use warnings;
use lib "../lib/", "t/", "lib/";
use Test::More;

BEGIN {

    use check_requirements;
    plan tests => 6;

    use_ok("Sub::Contract::Debug");
    use_ok("Sub::Contract::Pool");
    use_ok("Sub::Contract::ArgumentChecks");
    use_ok("Sub::Contract::Memoizer");
    use_ok("Sub::Contract::Compiler");
    use_ok("Sub::Contract");
};

