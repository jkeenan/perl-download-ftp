# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Perl::Download::FTP' ); }

my $object = Perl::Download::FTP->new ();
isa_ok ($object, 'Perl::Download::FTP');


