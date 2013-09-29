use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'KoList',
    VERSION_FROM  => 'lib/KoList.pm',
    PREREQ_PM     => {
        'Kossy' =>  '0.19',
    },
    MIN_PERL_VERSION => '5.008001'
);

