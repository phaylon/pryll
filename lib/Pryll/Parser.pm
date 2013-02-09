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
#    start => 'document',
    actions => 'Pryll::Parser::Actions',
    source => \q{

        :start ::= document

        document ::= document_part*
            separator => T_stmt_sep
            action => ast_document

        document_part ::= expression

        expression ::=
               atom
            || expression T_op_and_low expression
                action => ast_binop
            || expression T_op_or_low expression
                action => ast_binop

        atom ::=
               number       action => ast_number
            || T_lex_var    action => ast_lex_var

        number ::= T_integer | T_float

    },
#    rules => $_inflate->(
#        ['document', ['document_part'],
#            min         => 0,
#            separator   => 'T_stmt_sep',
#            action      => 'ast_document',
#        ],
#        ['document_part', ['expression']],
#        ['expression', ['atom']],
#
#        ['atom', ['number'],
#            action      => 'ast_number',
#        ],
#        ['atom', ['T_lex_var'],
#            action      => 'ast_lex_var',
#        ],
#        ['number', ['T_integer']],
#        ['number', ['T_float']],
#    ),
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
    ['or_low', 'or'],
    ['and_low', 'and'],
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

    sub ast_binop {
        my ($data, $left, $op, $right) = @_;
        my ($type, $value, $location) = @$op;
        return Operator::Binary->$_new_ast(
            symbol      => $value,
            left        => $left,
            right       => $right,
            location    => $location,
        );
    }

    sub ast_binop_left {
        my ($data, $left, $op, $right) = @_;
        my ($type, $value, $location) = @$op;
        return Operator::Binary->$_new_ast(
            symbol      => $value,
            left        => $left,
            right       => $right,
            location    => $location,
            assoc       => 'left',
        );
    }

    sub ast_document {
        my ($data, @parts) = @_;
        return Document->$_new_ast(parts => \@parts);
    }
};

1;
