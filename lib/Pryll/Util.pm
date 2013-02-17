use strictures 1;

package Pryll::Util;
use Data::Dump  ();
use Carp        qw( croak );
use Exporter    'import';

our @EXPORT_OK = qw( pp compose oneline typeof block );

sub pp { my $dump = Data::Dump::pp(shift); return $dump }

sub block { sprintf '(do { %s })', join ';', @_ }

sub typeof {
    my ($what) = @_;
    return join(' : ',
        "not(defined $what) ? 'undef'",
        "not(ref $what) ? 'scalar'",
        "(ref($what) eq 'ARRAY') ? 'array'",
        "(ref($what) eq 'HASH') ? 'hash'",
        "Scalar::Util::blessed($what) ? 'object'",
        "''",
    );
}

sub oneline {
    my ($string) = @_;
    $string =~ s{\s*\n+\s*}{ }g;
    return $string;
}

sub compose {
    my ($template, %arg) = @_;
    my $replace = sub {
        my ($name) = @_;
        croak "Missing template value '$name'"
            unless exists $arg{$name};
        return $arg{$name};
    };
    $template =~ s{\%\(([a-z_][a-z0-9_]*)\)}{$replace->($1)}ge;
    return $template;
}

1;
