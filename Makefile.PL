use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'File::Transaction::Atomic',
    'VERSION_FROM' => 'Atomic.pm',
    'PREREQ_PM'    => {
                        'Test::More'        => 0,
                        'IO::File'          => 0,
                        'File::Transaction' => 0,
                      },
);

