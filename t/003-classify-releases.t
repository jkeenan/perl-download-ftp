# -*- perl -*-
# t/003-classify-releases.t
use strict;
use warnings;

use Perl::Download::FTP;
use Test::More;
unless ($ENV{PERL_ALLOW_NETWORK_TESTING}) {
    plan 'skip_all' => "Set PERL_ALLOW_NETWORK_TESTING to conduct live tests";
}
else {
    plan tests =>  4;
}
use Test::RequiresInternet ('ftp.cpan.org' => 21);
use List::Compare::Functional qw(
    is_LsubsetR
);

my ($self, $host, $dir);
my (@allarchives, @gzips, @bzips, @xzs);
my $default_host = 'ftp.cpan.org';
my $default_dir  = '/pub/CPAN/src/5.0';

$self = Perl::Download::FTP->new( {
    host        => $default_host,
    dir         => $default_dir,
    Passive     => 1,
} );
ok(defined $self, "Constructor returned defined object when using default values");
isa_ok ($self, 'Perl::Download::FTP');

@allarchives = $self->ls();
my $allcount = scalar(@allarchives);
ok($allcount, "ls(): returned >0 elements: $allcount");

my $classified = $self->classify_releases(\@allarchives);
my $classified_count =
    (scalar keys %{$classified->{dev}}) +
    (scalar keys %{$classified->{prod}}) +
    (scalar keys %{$classified->{rc}});
is($classified_count, $allcount,
    "Got expected number of classified entries: $allcount");

