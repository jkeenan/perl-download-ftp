# -*- perl -*-
# t/003-releases.t
use strict;
use warnings;

use Perl::Download::FTP;
use Test::More;
#unless ($ENV{AUTHOR_TESTING}) {
#    plan 'skip_all' => "Set AUTHOR_TESTING to conduct live tests";
#}
#else {
    plan tests =>  8;
#}
use Test::RequiresInternet ('ftp.cpan.org' => 21);
use List::Compare::Functional qw(
    is_LsubsetR
);
#use Data::Dump qw(dd pp);

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
#pp($classified);

my @prod = $self->list_production_releases('gz');
cmp_ok(scalar(@prod), '>=', 1, "Non-zero number of .gz tarballs listed");
#pp(\@prod);
my @three_oldest = (
  "perl-5.6.0.tar.gz",
  "perl5.005.tar.gz",
  "perl5.004.tar.gz",
);
for (my $i = 0; $i <= $#three_oldest; $i++) {
    is($prod[$i-3], $three_oldest[$i], "Got $three_oldest[$i] where expected");
}

