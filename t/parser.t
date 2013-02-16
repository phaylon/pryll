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
            cb_attr(operand => $right),
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

sub cb_str {
    return cb_isa(
        'AST::String',
        cb_attr(value => cb_is(shift)),
    );
}

sub cb_slice_named {
    return cb_isa(
        'AST::Slice::Named',
        cb_attr(value => shift),
    );
}

sub cb_slice_list {
    return cb_isa(
        'AST::Slice::List',
        cb_attr(value => shift),
    );
}

sub cb_ident {
    return cb_isa(
        'AST::Identifier',
        cb_attr(value => cb_is(shift)),
    );
}

sub cb_hash {
    return cb_isa(
        'AST::Hash',
        cb_attr(items => @_),
    );
}

sub cb_array {
    return cb_isa(
        'AST::Array',
        cb_attr(items => @_),
    );
}

sub cb_bareword {
    return cb_isa(
        'AST::Bareword',
        cb_attr(value => cb_is(shift)),
    );
}

sub cb_named {
    my ($name, $value) = @_;
    return cb_isa(
        'AST::Named',
        cb_all(
            cb_attr(name  => $name),
            cb_attr(value => $value),
        ),
    );
}

sub cb_method {
    my ($op, $inv, $method, @args) = @_;
    return cb_isa(
        'AST::Operator::Method',
        cb_all(
            cb_attr(invocant    => $inv),
            cb_attr(symbol      => cb_is($op)),
            cb_attr(method      => $method),
            cb_attr(arguments   => @args),
        ),
    );
}

sub cb_lambda {
    my ($signature, $traits, @body) = @_;
    return cb_isa(
        'AST::Lambda',
        cb_all(
            cb_attr(signature   => $signature),
            cb_attr(traits      => @$traits),
            cb_attr(expressions => @body),
        ),
    );
}

sub cb_param_def { cb_attr(init_expression => shift) }
sub cb_param_pos { cb_attr(is_named => cb_is(0)) }
sub cb_param_nam { cb_attr(is_named => cb_is(1)) }
sub cb_param_req { cb_attr(is_optional => cb_is(0)) }
sub cb_param_opt { cb_attr(is_optional => cb_is(1)) }
sub cb_param_var { cb_attr(variable => cb_lex_var(shift)) }

sub cb_traits { cb_attr(traits => @_) }

sub cb_trait {
    my ($name, @args) = @_;
    return cb_isa(
        'AST::Trait',
        cb_all(
            cb_attr(name => cb_is($name)),
            cb_attr(arguments => @args),
        ),
    );
}

sub cb_param {
    my (@tests) = @_;
    return cb_isa(
        'AST::Signature::Parameter',
        cb_all(@tests),
    );
}

sub cb_signature {
    my ($pos, $nam) = @_;
    return cb_isa(
        'AST::Signature',
        cb_all(
            cb_attr(named => @{ $nam || [] }),
            cb_attr(positional => @{ $pos || [] }),
        ),
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
        [$name, "\$n$op", cb_unop($op, cb_lex_var('n'))];
    }   ['inc', '++'],
        ['dec', '--'],
    ),
    (map {
        my ($name, $op) = @$_;
        [$name, "$op 17", cb_unop($op, cb_num(17))];
    }   ['low not', 'not'],
        ['high not', '!'],
    ),
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
        ['high or', '||'], ['defined or', '//'],
        ['high and', '&&'],
        ['num lt', '<'], ['num gt', '>'],
        ['num le', '<='], ['num ge', '>='],
        ['str lt', 'lt'], ['str gt', 'gt'],
        ['str le', 'le'], ['str ge', 'ge'],
        ['concat', '~'],
        ['add', '+'], ['subtract', '-'],
        ['divide', '/'], ['multiply', '*'], ['modulus', 'mod'],
    ),
    (map {
        my ($name, $op) = @$_;
        ["named $name", "\$obj${op}foo",
            cb_method($op,
                cb_lex_var('obj'),
                cb_bareword('foo'),
            ),
        ],
        ["named $name with empty arglist", "\$obj${op}foo()",
            cb_method($op,
                cb_lex_var('obj'),
                cb_bareword('foo'),
            ),
        ],
        ["named $name with arglist", "\$obj${op}foo(23, 17)",
            cb_method($op,
                cb_lex_var('obj'),
                cb_bareword('foo'),
                cb_num(23),
                cb_num(17),
            ),
        ],
        ["named $name with named args", "\$obj${op}foo(x: 23, y: 17)",
            cb_method($op,
                cb_lex_var('obj'),
                cb_bareword('foo'),
                cb_named(cb_str('x'), cb_num(23)),
                cb_named(cb_str('y'), cb_num(17)),
            ),
        ],
        ["named $name with list slice", "\$obj${op}foo(\$x, \@\$foo)",
            cb_method($op,
                cb_lex_var('obj'),
                cb_bareword('foo'),
                cb_lex_var('x'),
                cb_slice_list(cb_lex_var('foo')),
            ),
        ],
        ["named $name with named slice", "\$obj${op}foo(\$x, \%\$foo)",
            cb_method($op,
                cb_lex_var('obj'),
                cb_bareword('foo'),
                cb_lex_var('x'),
                cb_slice_named(cb_lex_var('foo')),
            ),
        ],
        ["variable $name", "\$obj${op}\$foo",
            cb_method($op,
                cb_lex_var('obj'),
                cb_lex_var('foo'),
            ),
        ],
        ["variable $name with empty arglist", "\$obj${op}\$foo()",
            cb_method($op,
                cb_lex_var('obj'),
                cb_lex_var('foo'),
            ),
        ],
        ["variable $name with arglist", "\$obj${op}\$foo(23, 17)",
            cb_method($op,
                cb_lex_var('obj'),
                cb_lex_var('foo'),
                cb_num(23),
                cb_num(17),
            ),
        ],
        ["variable $name with named args", "\$obj${op}\$foo(x: 23, y: 17)",
            cb_method($op,
                cb_lex_var('obj'),
                cb_lex_var('foo'),
                cb_named(cb_str('x'), cb_num(23)),
                cb_named(cb_str('y'), cb_num(17)),
            ),
        ],
    }   ['method call', '.'],
        ['method ref', '.&'],
    ),
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
        [defor => '//'], [and => '&&'],
    ),
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
    ['high and vs. high or', '$x || $y && $z',
        cb_binop('||',
            cb_lex_var('x'),
            cb_binop('&&',
                cb_lex_var('y'),
                cb_lex_var('z'),
            ),
        ),
    ],
    ['equality vs. high and', '$a == $b && $c == $d',
        cb_binop('&&',
            cb_binop('==',
                cb_lex_var('a'),
                cb_lex_var('b'),
            ),
            cb_binop('==',
                cb_lex_var('c'),
                cb_lex_var('d'),
            ),
        ),
    ],
    ['high not vs. equality', '!$a eq $b',
        cb_binop('eq',
            cb_unop('!', cb_lex_var('a')),
            cb_lex_var('b'),
        ),
    ],
    ['concat vs. high not', '!$a ~ $b',
        cb_unop('!',
            cb_binop('~',
                cb_lex_var('a'),
                cb_lex_var('b'),
            ),
        ),
    ],
    ['low math vs. concat', '$x + $y ~ $a - $b',
        cb_binop('~',
            cb_binop('+',
                cb_lex_var('x'),
                cb_lex_var('y'),
            ),
            cb_binop('-',
                cb_lex_var('a'),
                cb_lex_var('b'),
            ),
        ),
    ],
    ['high math vs. low math', '$a * $b + $c / $d',
        cb_binop('+',
            cb_binop('*',
                cb_lex_var('a'),
                cb_lex_var('b'),
            ),
            cb_binop('/',
                cb_lex_var('c'),
                cb_lex_var('d'),
            ),
        ),
    ],
    ['stepping vs. high math', '$x++ * $y--',
        cb_binop('*',
            cb_unop('++', cb_lex_var('x')),
            cb_unop('--', cb_lex_var('y')),
        ),
    ],
);

test_all('groupings', $_test_ok,
    ['precedence', '(23 and 17) || 55',
        cb_binop('||',
            cb_binop('and',
                cb_num(23),
                cb_num(17),
            ),
            cb_num(55),
        ),
    ],
);

test_all('barewords', $_test_ok,
    ['namespaced', 'Foo::Bar::Baz', cb_ident('Foo::Bar::Baz')],
    ['bareword', 'foo', cb_ident('foo')],
    ['odd namespace', '_Foo23::_Bar::_4', cb_ident('_Foo23::_Bar::_4')],
    ['private bareword', '_foo', cb_ident('_foo')],
    ['private num bareword', '_23', cb_ident('_23')],
);

test_all('arrays', $_test_ok,
    ['simple', '[23, 17]', cb_array(cb_num(23), cb_num(17))],
    ['single', '[23]', cb_array(cb_num(23))],
    ['empty', '[]', cb_array()],
    ['slice in list', '[23, @$foo, 17]',
        cb_array(
            cb_num(23),
            cb_slice_list(cb_lex_var('foo')),
            cb_num(17),
        ),
    ],
);

test_all('hashes', $_test_ok,
    ['simple', '{ x: 23, y: 17 }',
        cb_hash(
            cb_named(cb_str('x'), cb_num(23)),
            cb_named(cb_str('y'), cb_num(17)),
        ),
    ],
    ['single', '{ x: 17 }', cb_hash(cb_named(cb_str('x'), cb_num(17)))],
    ['empty', '{}', cb_hash()],
    ['slice in hash', '{ x: 17, %$foo, y: 23 }',
        cb_hash(
            cb_named(cb_str('x'), cb_num(17)),
            cb_slice_named(cb_lex_var('foo')),
            cb_named(cb_str('y'), cb_num(23)),
        ),
    ],
);

test_all('lambda and signatures', $_test_ok,
    ['bare', 'lambda { 23 }', cb_lambda(cb_undef(), [], cb_num(23))],
    ['empty', 'lambda { }', cb_lambda(cb_undef(), [])],
    ['multiple statements', 'lambda { 23; 17 }',
        cb_lambda(cb_undef(), [], cb_num(23), cb_num(17)),
    ],
    ['with traits', 'lambda :x, :y(23) { 17 }',
        cb_lambda(
            cb_undef(),
            [cb_trait('x'), cb_trait('y', cb_num(23))],
            cb_num(17),
        ),
    ],
    ['with signature and traits', 'lambda ($n) :x, :y(23) { 17 }',
        cb_lambda(
            cb_signature(
                [cb_param(cb_param_var('n'))],
            ),
            [cb_trait('x'), cb_trait('y', cb_num(23))],
            cb_num(17),
        ),
    ],
    ['empty signature', 'lambda () { 23 }',
        cb_lambda(
            cb_signature(),
            [],
            cb_num(23),
        ),
    ],
    ['single positional parameter', 'lambda ($n) { 23 }',
        cb_lambda(
            cb_signature(
                [cb_param(cb_param_req, cb_param_var('n'), cb_traits)],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['multiple positional parameters', 'lambda ($n, $m) { 23 }',
        cb_lambda(
            cb_signature(
                [
                    cb_param(cb_param_req, cb_param_var('n'), cb_traits),
                    cb_param(cb_param_req, cb_param_var('m'), cb_traits),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['defaulted positional parameter', 'lambda ($n, $m = 17) { 23 }',
        cb_lambda(
            cb_signature(
                [
                    cb_param(cb_param_req, cb_param_var('n'), cb_traits),
                    cb_param(
                        cb_param_opt,
                        cb_param_var('m'),
                        cb_traits,
                        cb_param_def(cb_num(17)),
                    ),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['optional positional parameter', 'lambda ($n, $m?) { 23 }',
        cb_lambda(
            cb_signature(
                [
                    cb_param(cb_param_req, cb_param_var('n'), cb_traits),
                    cb_param(cb_param_opt, cb_param_var('m'), cb_traits),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['positional parameter with trait', 'lambda ($n :x, $m :y(3)) { 23 }',
        cb_lambda(
            cb_signature(
                [
                    cb_param(
                        cb_param_req,
                        cb_param_var('n'),
                        cb_traits(cb_trait('x')),
                    ),
                    cb_param(
                        cb_param_req,
                        cb_param_var('m'),
                        cb_traits(cb_trait('y', cb_num(3))),
                    ),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['positional parameter with multiple traits',
        'lambda ($n :x, :y(17), $m :y(3)) { 23 }',
        cb_lambda(
            cb_signature(
                [
                    cb_param(
                        cb_param_req,
                        cb_param_var('n'),
                        cb_traits(
                            cb_trait('x'),
                            cb_trait('y', cb_num(17)),
                        ),
                    ),
                    cb_param(
                        cb_param_req,
                        cb_param_var('m'),
                        cb_traits(cb_trait('y', cb_num(3))),
                    ),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['single named parameter', 'lambda (:$n) { 23 }',
        cb_lambda(
            cb_signature(
                [],
                [cb_param(cb_param_req, cb_param_var('n'), cb_traits)],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['multiple named parameters', 'lambda (:$n, :$m) { 23 }',
        cb_lambda(
            cb_signature(
                [],
                [
                    cb_param(cb_param_req, cb_param_var('n'), cb_traits),
                    cb_param(cb_param_req, cb_param_var('m'), cb_traits),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['optional named parameters', 'lambda (:$n?, :$m) { 23 }',
        cb_lambda(
            cb_signature(
                [],
                [
                    cb_param(cb_param_opt, cb_param_var('n'), cb_traits),
                    cb_param(cb_param_req, cb_param_var('m'), cb_traits),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['named parameters with traits',
        'lambda (:$n :x, :y(23), :$m :y(17)) { 23 }',
        cb_lambda(
            cb_signature(
                [],
                [
                    cb_param(
                        cb_param_req,
                        cb_param_var('n'),
                        cb_traits(
                            cb_trait('x'),
                            cb_trait('y', cb_num(23)),
                        ),
                    ),
                    cb_param(
                        cb_param_req,
                        cb_param_var('m'),
                        cb_traits(cb_trait('y', cb_num(17))),
                    ),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['defaulted named parameters', 'lambda (:$n = 17, :$m) { 23 }',
        cb_lambda(
            cb_signature(
                [],
                [
                    cb_param(
                        cb_param_opt,
                        cb_param_var('n'),
                        cb_traits,
                        cb_param_def(cb_num(17)),
                    ),
                    cb_param(cb_param_req, cb_param_var('m'), cb_traits),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
    ['mixed parameters', 'lambda ($n, :$m) { 23 }',
        cb_lambda(
            cb_signature(
                [
                    cb_param(cb_param_req, cb_param_var('n'), cb_traits),
                ],
                [
                    cb_param(cb_param_req, cb_param_var('m'), cb_traits),
                ],
            ),
            [],
            cb_num(23),
        ),
    ],
);

done_testing;
