use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
use 5.006;
WriteMakefile(
    NAME          => 'Class::Date',
    VERSION_FROM  => 'Date.pm',
    ABSTRACT_FROM => 'Date.pod',
    AUTHOR        => 'Balazs Szabo (dLux)',
    LICENSE       => 'perl',
    MIN_PERL_VERSION => 5.006,
    BUILD_REQUIRES => {
           'Test::More'     => '1.001',
    },
    META_MERGE        => {
       resources => {
           repository  =>  'http://code.google.com/p/perl-class-date/',
       },
       x_contributors => [
           'dLux (Szabó, Balázs) <dlux@dlux.hu>',
           'Matt Sergeant <matt@sergeant.org>',
           'Tatsuhiko Miyagawa <miyagawa@cpan.org>',
           'Stas Bekman <stas@stason.org>',
           'Chris Winters <chris@cwinters.com>',
           'Benoit Beausejour <bbeausej@pobox.com>',
           'Gabor Szabo <szabgab@cpan.org>',
       ],
    },
    dist              => { 
        PREOP => $^X.' -MPod::Text -e "pod2text(q(Date.pod))" > README'
    }
)
