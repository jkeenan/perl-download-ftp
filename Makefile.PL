

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Perl::Download::FTP',
    VERSION_FROM => 'lib/Perl/Download/FTP.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Identify Perl releases and download the most recent via FTP',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);
