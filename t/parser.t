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

sub cb_unop {
    my ($symbol, $right) = @_;
    return cb_isa(
        'AST::Operator::Unary',
        cb_all(
            cb_attr(symbol  => cb_is($symbol)),
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
    ['low not', 'not 17', cb_unop('not', cb_num(17))],
    ['assign', '$x = 23', cb_binop('=', cb_lex_var('x'), cb_num(23))],
    ['assign (assoc)', '$x = $y = 23',
        cb_binop('=',
            cb_lex_var('x'),
            cb_binop('=',
                cb_lex_var('y'),
                cb_num(23),
            ),
        ),
    ],
    (map {
        my ($name, $op) = @$_;
        [$name, "23 $op 17", cb_binop($op, cb_num(23), cb_num(17))],
        ["$name (assoc)", "23 $op 17 $op 42",
            cb_binop($op,
                cb_binop($op, cb_num(23), cb_num(17)),
                cb_num(42),
            ),
        ];
    }   ['low or', 'or'], ['low and', 'and'],
        ['high or', '||'], ['defined or', '//'], ['high and', '&&']),
    (map {
        my ($name, $op) = @$_;
        ["assign $name", "\$x $op= 23",
            cb_binop('=',
                cb_lex_var('x'),
                cb_binop($op,
                    cb_lex_var('x'),
                    cb_num(23),
                ),
            ),
        ],
        ["assign $name (assoc)", "\$x $op= \$y $op= 23",
            cb_binop('=',
                cb_lex_var('x'),
                cb_binop($op,
                    cb_lex_var('x'),
                    cb_binop('=',
                        cb_lex_var('y'),
                        cb_binop($op,
                            cb_lex_var('y'),
                            cb_num(23),
                        ),
                    ),
                ),
            ),
        ];
    }   [add => '+'], [sub => '-'], [mul => '*'],
        [div => '/'], [concat => '~'], [or => '||'],
        [defor => '//'], [and => '&&']),
);

test_all('operator precedence', $_test_ok,
    ['low and vs. low or', '23 and 17 or 45',
        cb_binop('or',
            cb_binop('and', cb_num(23), cb_num(17)),
            cb_num(45),
        ),
    ],
    ['low or vs. low and', '23 or 17 and 45',
        cb_binop('or',
            cb_num(23),
            cb_binop('and', cb_num(17), cb_num(45)),
        ),
    ],
    ['low and vs. low not', 'not $x and not $y',
        cb_binop('and',
            cb_unop('not', cb_lex_var('x')),
            cb_unop('not', cb_lex_var('y')),
        ),
    ],
    ['low not vs. assign', 'not $x = $y',
        cb_unop('not',
            cb_binop('=',
                cb_lex_var('x'),
                cb_lex_var('y'),
            ),
        ),
    ],
    ['high or vs. assign', '$x = $y || $z',
        cb_binop('=',
            cb_lex_var('x'),
            cb_binop('||',
                cb_lex_var('y'),
                cb_lex_var('z'),
            ),
        ),
    ],
    ['defined or vs. assign', '$x = $y // $z',
        cb_binop('=',
            cb_lex_var('x'),
            cb_binop('//',
                cb_lex_var('y'),
                cb_lex_var('z'),
            ),
        ),
    ],
);

done_testing;
