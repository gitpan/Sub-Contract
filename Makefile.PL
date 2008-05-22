use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Sub::Contract',
    VERSION_FROM      => 'lib/Sub/Contract.pm', # finds $VERSION
    PREREQ_PM         => {
      accessors => 0.02,
      Sub::Name => 0.02,
      Cache     => 2.00,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Sub/Contract.pm', # retrieve abstract from module
       AUTHOR         => 'Erwan Lemonnier <erwan@cpan.org>') : ()),
);

