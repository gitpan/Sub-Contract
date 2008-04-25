#
#   $Id: check_requirements.pm,v 1.1 2007/03/30 08:38:50 erwan_lemonnier Exp $
#
#   check that all required modules are available
#

eval "use Hook::WrapSub"; plan skip_all => "missing module 'Hook::WrapSub'" if ($@);

1;
