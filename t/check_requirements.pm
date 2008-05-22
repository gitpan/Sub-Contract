#
#   $Id: check_requirements.pm,v 1.3 2008/05/22 16:03:24 erwan_lemonnier Exp $
#
#   check that all required modules are available
#

eval "use accessors"; plan skip_all => "missing module 'accessors'" if ($@);
eval "use Sub::Name"; plan skip_all => "missing module 'Sub::Name'" if ($@);
eval "use Cache"; plan skip_all => "missing module 'Cache'" if ($@);
1;
