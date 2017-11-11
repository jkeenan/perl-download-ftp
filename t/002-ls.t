# -*- perl -*-
# t/002-ls.t
use strict;
use warnings;

use Perl::Download::FTP;
use Test::More qw(no_plan); # tests => 2;
use List::Compare::Functional qw(
    is_LsubsetR
);

my ($self, $host, $dir);
my (@allarchives, @gzips, @bzips, @xzs);

$self = Perl::Download::FTP->new();
ok(defined $self, "Constructor returned defined object when using default values");
isa_ok ($self, 'Perl::Download::FTP');

my @exp_gzips = (
  "perl-5.10.0-RC2.tar.gz",
  "perl-5.10.0.tar.gz",
  "perl-5.26.0.tar.gz",
  "perl-5.26.1-RC1.tar.gz",
  "perl-5.27.0.tar.gz",
  "perl-5.6.0.tar.gz",
  "perl-5.6.1-TRIAL1.tar.gz",
  "perl-5.6.1-TRIAL2.tar.gz",
  "perl-5.6.1-TRIAL3.tar.gz",
  "perl5.003_07.tar.gz",
  "perl5.004.tar.gz",
  "perl5.004_01.tar.gz",
  "perl5.005.tar.gz",
  "perl5.005_01.tar.gz",
);

my @exp_bzips = (
  "perl-5.10.1.tar.bz2",
  "perl-5.12.2-RC1.tar.bz2",
  "perl-5.26.1-RC1.tar.bz2",
  "perl-5.27.0.tar.bz2",
  "perl-5.8.9.tar.bz2",
);

my @exp_xzs = (
  "perl-5.21.10.tar.xz",
  "perl-5.21.6.tar.xz",
  "perl-5.22.0-RC1.tar.xz",
  "perl-5.22.0.tar.xz",
  "perl-5.22.1-RC4.tar.xz",
  "perl-5.26.1.tar.xz",
  "perl-5.27.2.tar.xz",
);

@allarchives = $self->ls();

ok(is_LsubsetR( [
    \@exp_gzips,
    \@allarchives,
] ), "ls(): No argument: Spot check .gz");

ok(is_LsubsetR( [
    \@exp_bzips,
    \@allarchives,
] ), "ls(): No argument: Spot check .bz2");

ok(is_LsubsetR( [
    \@exp_xzs,
    \@allarchives,
] ), "ls(): No argument: Spot check .xz");

@allarchives = $self->ls('gz');

ok(is_LsubsetR( [
    \@exp_gzips,
    \@allarchives,
] ), "ls(): Request 'gz' only: Spot check .gz");

ok(! is_LsubsetR( [
    \@exp_bzips,
    \@allarchives,
] ), "ls(): Request 'gz' only: Spot check .bz2");

ok(! is_LsubsetR( [
    \@exp_xzs,
    \@allarchives,
] ), "ls(): Request 'gz' only: Spot check .xz");


@allarchives = $self->ls('bz2');

ok(! is_LsubsetR( [
    \@exp_gzips,
    \@allarchives,
] ), "ls(): Request 'bz2' only: Spot check .gz");

ok(is_LsubsetR( [
    \@exp_bzips,
    \@allarchives,
] ), "ls(): Request 'bz2' only: Spot check .bz2");

ok(! is_LsubsetR( [
    \@exp_xzs,
    \@allarchives,
] ), "ls(): Request 'bz2' only: Spot check .xz");


@allarchives = $self->ls('xz');

ok(! is_LsubsetR( [
    \@exp_gzips,
    \@allarchives,
] ), "ls(): Request 'xz' only: Spot check .gz");

ok(! is_LsubsetR( [
    \@exp_bzips,
    \@allarchives,
] ), "ls(): Request 'xz' only: Spot check .bz2");

ok(is_LsubsetR( [
    \@exp_xzs,
    \@allarchives,
] ), "ls(): Request 'xz' only: Spot check .xz");

{
    local $@;
    my $bad_compression = 'foo';
    eval { @allarchives = $self->ls($bad_compression); };
    like($@, qr/ls\(\):\s+Bad compression format:\s+$bad_compression/,
        "ls(): Got expected error message for bad compression format");
}

