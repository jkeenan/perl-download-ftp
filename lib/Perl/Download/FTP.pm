package Perl::Download::FTP;
use strict;
use warnings;
use 5.10.1;
use Carp;
use Net::FTP;
our $VERSION = '0.01';
#use Data::Dump qw(dd pp);

=head1 NAME

Perl::Download::FTP - Identify Perl releases and download the most recent via FTP

=head1 SYNOPSIS

    use Perl::Download::FTP;

    $self = Perl::Download::FTP->new( {
        host        => 'ftp.cpan.org',
        dir         => '/pub/CPAN/src/5.0',
    } );

    @all_releases = $self->ls();

    $classified_releases = $self->classify_releases(\@all_releases);

    @prod = $self->list_production_releases();
    @dev  = $self->list_development_releases();
    @rc   = $self->list_rc_releases();

    $latest_prod    = $self->get_latest_prod_release();
    $latest_dev     = $self->get_latest_dev_release();
    $latest_rc      = $self->get_latest_rc_release();

=head1 DESCRIPTION

This library provides (a) methods for obtaining a list of all Perl 5 releases
which are available for FTP download; and (b) methods for obtaining the most
recent release.

=head2 Compression Formats

Perl releases have, over time, used three different compression formats:
C<gz>, C<bz2> and C<xz>.  C<gz> is the one that has been used in every
production, development and release candidate release, so that is the default
value in some of the methods below.

=head2 Testing

This library can only be truly tested by attempting live FTP connections and
downloads of Perl 5 source code tarballs.  Since testing over the internet
can be problematic when being conducted in an automatic manner or when the
user is behind a firewall, the test files under F<t/> will only be run live
when you say:

    export PERL_ALLOW_NETWORK_TESTING=1 && make test

Each test file further attempts to confirm the possibility of making an FTP
connection by using CPAN library Test::RequiresInternet.

=head1 METHODS

=head2 C<new()>

=over 4

=item * Purpose

Perl::Download::FTP constructor.

=item * Arguments

    $self = Perl::Download::FTP->new();

    $self = Perl::Download::FTP->new( {
        host        => 'ftp.cpan.org',
        dir         => '/pub/CPAN/src/5.0',
    } );

    $self = Perl::Download::FTP->new( {
        host        => 'ftp.cpan.org',
        dir         => '/pub/CPAN/src/5.0',
        Timeout     => 5,
    } );

Takes a hash reference with, typically, two elements:  C<host> and C<dir>.
Any options which can be passed to F<Net::FTP::new()> may also be passed as
key-value pairs.  When no argument is provided, the values shown above for
C<host> and C<dir> will be used.  You may enter values for any CPAN mirror
which provides FTP access.  (See L<https://www.cpan.org/SITES.html> and
L<http://mirrors.cpan.org/>.)

=item * Return Value

Perl::Download::FTP object.

=item * Comment

The method establishes an FTP connection to <host>, logs you in as an
anonymous user, and changes directory to C<dir>.

Wrapper around Net::FTP object.  You will get Net::FTP error messages at any
point of failure.  Uses FTP C<Passive> mode.

=back

=cut

sub new {
    my ($class, $args) = @_;
    $args //= {};
    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';

    my %default_args = (
        host    => 'ftp.cpan.org',
        dir     => '/pub/CPAN/src/5.0',
    );
    my %netftp_options = (
        Firewall        => undef,
        FirewallType    => undef,
        BlockSize       => 10240,
        Port            => undef,
        SSL             => undef,
        Timeout         => 120,
        Debug           => 0,
        Passive         => 1,
        Hash            => undef,
        LocalAddr       => undef,
        Domain          => undef,
    );
    my %permitted_args = map {$_ => 1} (
        keys %default_args,
        keys %netftp_options,
    );

    for my $k (keys %{$args}) {
        croak "Argument '$k' not permitted in constructor"
            unless $permitted_args{$k};
    }

    my $data;
    # Populate object starting with default host and directory
    while (my ($k,$v) = each %default_args) {
        $data->{$k} = $v;
    }
    # Then add Net::FTP plausible defaults
    while (my ($k,$v) = each %netftp_options) {
        $data->{$k} = $v;
    }
    # Then override with key-value pairs passed to new()
    while (my ($k,$v) = each %{$args}) {
        $data->{$k} = $v;
    }

    # For the Net::FTP constructor, we don't need 'dir' and 'host'
    # must be passed first; all other key-value pairs follow.
    my %passed_netftp_options;
    for my $k (keys %{$data}) {
        $passed_netftp_options{$k} = $data->{$k}
            unless ($k =~ m/^(host|dir)$/);
    }

    my $ftp = Net::FTP->new($data->{host}, %passed_netftp_options)
        or croak "Cannot connect to $data->{host}: $@";

    $ftp->login("anonymous",'-anonymous@')
        or croak "Cannot login ", $ftp->message;

    $ftp->cwd($data->{dir})
        or croak "Cannot change to working directory $data->{dir}", $ftp->message;

    $data->{ftp} = $ftp;

    my @compressions = (qw| gz bz2 xz |);
    $data->{eligible_compressions}  = { map { $_ => 1 } @compressions };
    $data->{compression_string}     = join('|' => @compressions);

    return bless $data, $class;
}

=head2 C<ls()>

=over 4

=item * Purpose

Identify all Perl releases.

=item * Arguments

    @all_releases = $self->ls();

Returns list of all Perl core tarballs on the FTP host.

    @all_gzipped_releases = $self->ls('gz');

Returns list of only those all tarballs on the FTP host which are compressed
in C<.gz> format.  Also available:  C<bz2>, C<xz>.

=item * Return Value

List of strings like:

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

    "perl-5.10.1.tar.bz2",
    "perl-5.12.2-RC1.tar.bz2",
    "perl-5.26.1-RC1.tar.bz2",
    "perl-5.27.0.tar.bz2",
    "perl-5.8.9.tar.bz2",

    "perl-5.21.10.tar.xz",
    "perl-5.21.6.tar.xz",
    "perl-5.22.0-RC1.tar.xz",
    "perl-5.22.0.tar.xz",
    "perl-5.22.1-RC4.tar.xz",
    "perl-5.26.1.tar.xz",
    "perl-5.27.2.tar.xz",

=back

=cut

=pod

    my @compressions = (qw| gz bz2 xz |);
    $data->{eligible_compressions}  = { map { $_ => 1 } @compressions };
    $data->{compression_string}     = join('|' => @compressions);

=cut

sub ls {
    my ($self, $compression) = @_;
    if (! defined $compression) {
        $compression = $self->{compression_string};
    }
    else {
        croak "ls():  Bad compression format:  $compression"
            unless $self->{eligible_compressions}{$compression};
    }
    return grep {
        /^perl
        (?:
            -5\.\d+\.\d+        # 5.6.0 and above
            |
            5\.00\d(_\d{2})?    # 5.003_007 thru 5.005
        )
        .*?                     # Account for RC and TRIAL
        \.tar                   # We only want tarballs
        \.(?:${compression})    # Compression format
        $/x
    } $self->{ftp}->ls();
}

=head2 C<classify_releases()>

=over 4

=item * Purpose

Categorize releases as production, development or RC (release candidate).

=item * Arguments

Reference to the array returned by C<ls()>.

=item * Return Value

Hash reference.

=item * Comment

=back

=cut

sub classify_releases {
    my ($self, $releases) = @_;

    my %versions;
    for my $tb (@{$releases}) {
        my ($major, $minor, $rc);
        if ($tb =~ m/^
            perl-5\.(\d+)
            \.(\d+)
            (?:-((?:TRIAL|RC)\d+))?
            \.tar\.(?:gz|bz2|xz)
            $/x) {
            ($major, $minor, $rc) = ($1,$2,$3);
            if ($major % 2 == 0) {
                unless (defined $rc) {
                    $versions{prod}{$tb} = {
                        tarball => $tb,
                        major   => $major,
                        minor   => $minor,
                    }
                }
                else {
                    $versions{rc}{$tb} = {
                        tarball => $tb,
                        major   => $major,
                        minor   => $minor,
                        rc      => $rc,
                    }
                }
            }
            else {
                $versions{dev}{$tb} = {
                    tarball => $tb,
                    major   => $major,
                    minor   => $minor,
                }
            }
        }
        elsif ($tb =~ m/^
            perl5\.
            (00\d)
            (?:_(\d{2}))?   # 5.003_007 thru 5.005; account for RC and TRIAL
            .*?
            \.tar           # We only want tarballs
            \.gz            # Compression format
            $/x
        ) {
            my $early_dev;
            ($major, $early_dev) = ($1,$2);
            $early_dev //= '';
            if (! $early_dev) {
                $versions{prod}{$tb} = {
                    tarball => $tb,
                    major   => $major,
                    minor   => '',
                }
            }
            else {
                $versions{dev}{$tb} = {
                    tarball => $tb,
                    major   => $major,
                    minor   => $early_dev,
                }
            }
        }
    }
    $self->{versions} = \%versions;
    #return \%versions;
}

sub _compression_check {
    my ($self, $compression) = @_;
    if (! defined $compression) {
        return 'gz';
    }
    else {
        croak "ls():  Bad compression format:  $compression"
            unless $self->{eligible_compressions}{$compression};
        return $compression;
    }
}

=head2 C<list_production_releases()>

=over 4

=item * Purpose

For a specified compression format, compose a list of all production releases
available on the server in descending logical order.  Example for C<gz> compressed tarballs:

    perl-5.26.1.tar.gz
    perl-5.26.0.tar.gz
    perl-5.24.3.tar.gz
    perl-5.24.2.tar.gz
    perl-5.24.1.tar.gz
    perl-5.24.0.tar.gz
    ...
    perl-5.6.1.tar.gz
    perl-5.6.0.tar.gz
    perl5.005.tar.gz
    perl5.004.tar.gz

=item * Arguments

    @prod = $self->list_production_releases('gz');

If no argument is provided, the method will default to reporting C<.gz> releases only.

=item * Return Value

List holding strings naming tarballs with the specified compression.

=back

=cut

sub list_production_releases {
    my ($self, $compression) = @_;
    $compression = $self->_compression_check($compression);

    return grep { /\.${compression}$/ } sort {
        $self->{versions}->{prod}{$b}{major} <=> $self->{versions}->{prod}{$a}{major} ||
        $self->{versions}->{prod}{$b}{minor} <=> $self->{versions}->{prod}{$a}{minor}
    } keys %{$self->{versions}->{prod}};
}

=head2 C<list_development_releases()>

=over 4

=item * Purpose

For a specified compression format, compose a list of all development releases
available on the server in descending logical order.  Example for C<gz> compressed tarballs:

    perl-5.27.5.tar.gz
    perl-5.27.4.tar.gz
    perl-5.27.3.tar.gz
    ...
    perl-5.7.2.tar.gz
    perl-5.7.1.tar.gz
    perl-5.7.0.tar.gz

=item * Arguments

    @dev = $self->list_development_releases('gz');

If no argument is provided, the method will default to reporting C<.gz> releases only.

=item * Return Value

List holding strings naming tarballs with the specified compression.

=back

=cut

sub list_development_releases {
    my ($self, $compression) = @_;
    $compression = $self->_compression_check($compression);

    return grep { /\.${compression}$/ } sort {
        $self->{versions}->{dev}{$b}{major} <=> $self->{versions}->{dev}{$a}{major} ||
        $self->{versions}->{dev}{$b}{minor} <=> $self->{versions}->{dev}{$a}{minor}
    } keys %{$self->{versions}->{dev}};
}

=head2 C<list_rc_releases()>

=over 4

=item * Purpose

For a specified compression format, compose a list of all release candidate (RC) or TRIAL releases
available on the server in descending logical order.  Example for C<gz> compressed tarballs:


=item * Arguments

    @rc = $self->list_rc_releases('gz');

If no argument is provided, the method will default to reporting C<.gz> releases only.

=item * Return Value

List holding strings naming tarballs with the specified compression.

=back

=cut

sub list_rc_releases {
    my ($self, $compression) = @_;
    $compression = $self->_compression_check($compression);

    return grep { /\.${compression}$/ } sort {
        $self->{versions}->{rc}{$b}{major} <=> $self->{versions}->{rc}{$a}{major} ||
        $self->{versions}->{rc}{$b}{minor} <=> $self->{versions}->{rc}{$a}{minor}
    } keys %{$self->{versions}->{rc}};
}

=head1 BUGS AND SUPPORT

Please report any bugs by mail to C<bug-Perl-Download-FTP@rt.cpan.org>
or through the web interface at L<http://rt.cpan.org>.

=head1 ACKNOWLEDGEMENTS

Thanks for feedback from Chad Granum, Kent Fredric and David Golden
in the perl.cpan.workers newsgroup.

=head1 AUTHOR

    James E Keenan
    CPAN ID: JKEENAN
    jkeenan@cpan.org
    http://thenceforward.net/perl

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

Copyright James E Keenan 2017.  All rights reserved.

=head1 SEE ALSO

perl(1).  Net::FTP(3).  Test::RequiresInternet(3).

=cut

1;
