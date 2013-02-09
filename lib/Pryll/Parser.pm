use strictures 1;

package Pryll::Parser;
use Moo;
use Marpa::R2;
use Module::Runtime qw( use_module );

use aliased 'Pryll::Location';

my $LOG = sub { print "@_\n" };

my $_new_ast = sub {
    my ($class, %arg) = @_;
    return use_module(join '::', 'Pryll::AST', $class)->new(%arg);
};

my @_keywords = qw(
    my
);

my $_inflate = sub {
    return [ map {
        my ($lhs, $rhs, @args) = @$_;
        { lhs => $lhs, rhs => $rhs, @args };
    } @_ ];
};

my $_grammar = Marpa::R2::Grammar->new({
    actions => 'Pryll::Parser::Actions',
    source => \q{

        :start ::= document

        document ::= document_part*
            separator => T_stmt_sep
            action => ast_document

        document_part ::= expression

        expression ::=
               atom
            || assignable T_op_step
                action => ast_unop_post
                assoc => left
            || expression T_op_math_high expression
                action => ast_binop
            || expression T_op_math_low expression
                action => ast_binop
            || expression T_op_concat expression
                action => ast_binop
            || T_op_not_high expression
                action => ast_unop_pre
                assoc => right
            || expression T_op_diff expression
                action => ast_binop
            || expression T_op_equal expression
                action => ast_binop
            || expression T_op_and_high expression
                action => ast_binop
            || expression T_op_or_high expression
                action => ast_binop
            || assignable op_assign expression
                action => ast_binop
                assoc => right
            || T_op_not_low expression
                action => ast_unop_pre
                assoc => right
            || expression T_op_and_low expression
                action => ast_binop
            || expression T_op_or_low expression
                action => ast_binop

        op_diff ::= op_diff_tail+
        op_diff_tail ::= T_op_diff expression

        assignable ::= variable

        op_assign ::= T_op_assign | T_op_assign_sc

        atom ::=
               number       action => ast_number
            |  T_lex_var    action => ast_lex_var

        variable ::= T_lex_var action => ast_lex_var

        number ::= T_integer | T_float

    },
});

$_grammar->precompute;

sub parse {
    my ($self, $source) = @_;
    return Document->$_new_ast(name => $source->name)
        unless length $source->body;
    my $recog = Marpa::R2::Recognizer->new({ grammar => $_grammar });
    my $tokens = $self->_tokens_for($source);
    for my $token (@$tokens) {
        $recog->read('T_' . $token->[0], $token);
    }
    my $value = $recog->value;
    die "Unable to parse"
        unless defined $value;
    return $$value;
}

my $_find_location = sub {
    my ($source, $rest) = @_;
    my $original = $source->body;
    $original =~ s{\Q$rest\E$}{}
        or die "Original and rest string differ";
    my @lines = split m{\n}, $original;
    @lines = ('')
        unless @lines;
    return Location->new(
        name => $source->name,
        line => scalar(@lines),
        char => length($lines[-1]) + 1,
    );
};

my $_rx_int         = qr{ [0-9]+ (?: _ [0-9]+)* }x;
my $_rx_bareword    = qr{ [a-z_] [a-z0-9_]* }ix;

my @_operators = (
    ['or_low',      'or'],
    ['and_low',     'and'],
    ['not_low',     'not'],
    ['assign_sc',   '+=', '-=', '*=', '/=', '~=', '||=', '//=', '&&='],
    ['or_high',     '||', '//'],
    ['and_high',    '&&'],
    ['equal',       '==', '!=', 'eq', 'ne', '<=>', 'cmp', '~~'],
    ['diff',        '>=', '<=', '>', '<', 'gt', 'lt', 'ge', 'le'],
    ['step',        '++', '--'],
    ['assign',      '='],
    ['concat',      '~'],
    ['not_high',    '!'],
    ['math_low',    '+', '-'],
    ['math_high',   '*', '/', '%'],
);

my @_tokens = (
    (map { [$_, qr{\Q$_\E}] } @_keywords),
    (map {
        my ($name, @symbols) = @$_;
        ["op_$name", map qr{$_}, join '|', map qr{\Q$_\E}, @symbols];
    } @_operators),
    ['bareword',    $_rx_bareword],
    ['lex_var',     qr{ \$ $_rx_bareword }x],
    ['float',       qr{ $_rx_int [.] $_rx_int }x],
    ['integer',     $_rx_int],
    ['stmt_sep',    qr{;}],
    ['whitespace',  qr{\s}],
);

my %_discard_token = (
    whitespace => 1,
);

sub _tokens_for {
    my ($self, $source) = @_;
    my $string = $source->body;
    my @found;
    SCAN: while (length $string) {
        my $location = $_find_location->($source, $string);
        TOKEN: for my $token (@_tokens) {
            my ($name, $pattern) = @$token;
            if ($string =~ s{^($pattern)}{}) {
                unless ($_discard_token{$name}) {
                    push @found, [$name, $1, $location];
                }
                next SCAN;
            }
        }
        die "Unable to scan: $string";
    }
    return \@found;
}

do {
    package Pryll::Parser::Actions;
    use Safe::Isa;

    sub ast_number {
        my ($data, $token) = @_;
        my ($type, $value, $location) = @$token;
        $value =~ s{_}{}g;
        return Number->$_new_ast(
            value       => $value,
            location    => $location,
        );
    }

    sub ast_lex_var {
        my ($data, $token) = @_;
        my ($type, $value, $location) = @$token;
        $value =~ s{^\$}{};
        return Variable::Lexical->$_new_ast(
            name        => $value,
            location    => $location,
        );
    }

    my %_binop_shortcut = (
        '+='    => ['=', '+'],
        '-='    => ['=', '-'],
        '*='    => ['=', '*'],
        '/='    => ['=', '/'],
        '~='    => ['=', '~'],
        '||='   => ['=', '||'],
        '//='   => ['=', '//'],
        '&&='   => ['=', '&&'],
    );

    sub ast_binop {
        my ($data, $left, $op, $right) = @_;
        my ($type, $value, $location) = @$op;
        if (defined( my $newop = $_binop_shortcut{$value} )) {
            my ($outer, $inner) = @$newop;
            return Operator::Binary->$_new_ast(
                symbol      => $outer,
                left        => $left,
                location    => $location,
                right       => Operator::Binary->$_new_ast(
                    symbol      => $inner,
                    left        => $left,
                    location    => $location,
                    right       => $right,
                ),
            );
        }
        return Operator::Binary->$_new_ast(
            symbol      => $value,
            left        => $left,
            right       => $right,
            location    => $location,
        );
    }

    sub ast_unop_post {
        my ($data, $left, $op) = @_;
        return ast_unop_pre($data, $op, $left);
    }

    sub ast_unop_pre {
        my ($data, $op, $right) = @_;
        my ($type, $value, $location) = @$op;
        return Operator::Unary->$_new_ast(
            symbol      => $value,
            operand     => $right,
            location    => $location,
        );
    }

    my %_seqop_category => (
        (map { ($_, 'num') } '>', '<', '>=', '<='),
        (map { ($_, 'str') } 'gt', 'lt', 'ge', 'le'),
    );

    sub ast_document {
        my ($data, @parts) = @_;
        return Document->$_new_ast(parts => \@parts);
    }

    sub ast_test {
        my ($data, @rest) = @_;
        use Data::Dump qw( pp );        
        return [@rest];
    }
};

1;
