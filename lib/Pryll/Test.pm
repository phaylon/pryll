use strictures 1;

package Pryll::Test;
use Exporter 'import';
use Test::More ();

use aliased 'Pryll::Compiler';
use aliased 'Pryll::Parser';
use aliased 'Pryll::Source';

our %EXPORT_TAGS = (
    ast     => [qw( parse_string )],
    compile => [qw( run_string )],
    cb      => [qw( cb_isa cb_attr cb_is cb_all cb_undef )],
);

our @EXPORT_OK = (
    qw( test_all grouped test_methods ),
    (map { (@$_) } values %EXPORT_TAGS),
);

sub cb_all {
    my (@checks) = @_;
    return sub {
        my ($value) = @_;
        $_->($value) for @checks;
        return 1;
    };
}

sub cb_isa {
    my ($class, $then) = @_;
    return sub {
        my ($value) = @_;
        Test::More::isa_ok($value, "Pryll::$class", 'AST node') and do {
            if ($then) {
                grouped('object tests', sub {
                    $value->$then;
                });
            }
        };
    };
}

sub cb_undef {
    return sub {
        my ($value) = @_;
        Test::More::ok(not(defined $value), "value is undefined");
    };
}

sub cb_is {
    my ($expected) = @_;
    return sub {
        my ($value) = @_;
        Test::More::is($value, $expected, "value is '$expected'");
    };
}

sub cb_attr {
    my ($getter, @tests) = @_;
    return sub {
        my ($value) = @_;
        grouped("testing $getter", sub {
            my @result = $value->$getter;
            Test::More::is(
                scalar(@result),
                scalar(@tests),
                'value count',
            );
            for my $idx (0 .. $#tests) {
                $tests[$idx]->($result[$idx]);
            }
            return 1;
        });
    };
}

sub test_methods {
    my ($group_title, $init, @tests) = @_;
    return map {
        my ($title, $method, $append, $expected) = @$_;
        ["static $group_title method $title",
         "my \$obj = $init; \$obj.$method$append",
         $expected,
        ],
        ["dynamic $group_title method $title",
         "my \$m = '$method'; my \$obj = $init; \$obj.\$m$append",
         $expected,
        ];
    } @tests;
}

sub test_all {
    my ($title, $code, @tests) = @_;
    grouped($title, sub {
        for my $test (@tests) {
            my ($name, @args) = @$test;
            grouped($name, sub { $code->(@args); return 1 });
        }
        return 1;
    });
}

sub grouped {
    my ($title, $code) = @_;
    return $code->()
        if $ENV{TEST_FLAT};
    Test::More::note($title);
    Test::More::subtest($title, sub {
        $code->();
        Test::More::done_testing;
    });
    return 1;
}

sub run_string {
    my ($string) = @_;
    my $result = Compiler->new->compile(
        parse_string($string),
    );
    Test::More::note("Compiled:\n" . $result->compiled)
        if $ENV{DEBUG_CODE};
    return $result->run;
}

sub parse_string {
    my ($string) = @_;
    return Parser->new->parse(
        Source->new(
            name => 'test code',
            body => $string,
        ),
    );
}

1;
