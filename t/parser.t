use strictures 1;
use Test::More;

use Pryll::Test qw( :ast test_all :cb );

my $_test_ok = sub {
    my ($source, @tests) = @_;
    my $ast = parse_string($source);
    isa_ok($ast, 'Pryll::AST::Document', 'document object') and do {
        my @parts = $ast->parts;
        my $count = scalar @tests;
        is(scalar(@parts), scalar(@tests),
            "document part count is $count");
        for my $idx (0 .. $#tests) {
            $tests[$idx]->($parts[$idx]);
        }
    };
};

sub cb_binop {
    my ($symbol, $left, $right) = @_;
    return cb_isa(
        'AST::Operator::Binary',
        cb_all(
            cb_attr(symbol  => cb_is($symbol)),
            cb_attr(left    => $left),
            cb_attr(right   => $right),
        ),
    );
}

sub cb_num {
    return cb_isa(
        'AST::Number',
        cb_attr(value => cb_is(shift)),
    );
}

sub cb_lex_var {
    return cb_isa(
        'AST::Variable::Lexical',
        cb_attr(name => cb_is(shift)),
    );
}

test_all('document', $_test_ok,
    ['empty',           ''],
    ['single value',    '23',       cb_num('23')],
    ['two values',      '23;17',    cb_num('23'), cb_num('17')],
    ['two values (ws)', '23; 17',   cb_num('23'), cb_num('17')],
);

test_all('numbers', $_test_ok,
    ['simple integer',      '23',           cb_num('23')],
    ['integer zero',        '0',            cb_num('0')],
    ['integer separators',  '23_500',       cb_num('23500')],
    ['simple float',        '23.5',         cb_num('23.5')],
    ['float zero',          '0.0',          cb_num('0.0')],
    ['float below one',     '0.52',         cb_num('0.52')],
    ['float separators',    '23_500.23_5',  cb_num('23500.235')],
);

test_all('variables', $_test_ok,
    ['simple', '$foo', cb_lex_var('foo')],
);

test_all('operators', $_test_ok,
    ['low or', '23 or 17',
        cb_binop('or', cb_num(23), cb_num(17)),
    ],
    ['low_or (assoc)', '23 or 17 or 42',
        cb_binop('or',
            cb_binop('or', cb_num(23), cb_num(17)),
            cb_num(42),
        ),
    ],
);

done_testing;
