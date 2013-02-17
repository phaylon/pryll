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
    lambda
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

        document ::= document_parts END_OF_STREAM
            action => passthrough

        document_parts ::= document_part*
            separator => T_stmt_sep
            action => ast_document

        document_part ::= expression

        expression ::=
               atom
            | syntax
            || expression T_op_method method
                    method_call_maybe
                    method_call_chain
                    (T_par_left) arguments (T_par_right)
                action => ast_method
            |  expression T_op_method method
                    method_call_maybe
                    method_call_chain
                action => ast_method
            || slot
                action => passthrough
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

        slot ::= expression T_brack_left expression T_brack_right
            action => ast_slot

        method_call_maybe ::= T_op_qmark | nothing

        method_call_chain ::= T_op_emark | nothing

        syntax ::=
                syntax_lambda
            |   syntax_my

        syntax_my ::=
            T_kw_my variable traits assign_opt
                action => ast_lex_my

        syntax_lambda ::= T_kw_lambda signature_opt traits block
                action => ast_lambda

        signature_opt ::= signature | nothing

        signature ::= T_par_left signature_params T_par_right
            action => ast_signature

        signature_params ::= signature_param*
            separator => T_op_list_sep
            action => ast_list

        signature_param ::=
               colon_opt variable qmark_opt traits assign_opt
                action => ast_signature_param
            |  T_op_slice_list variable
                action => ast_signature_rest_pos
            |  T_op_slice_named variable
                action => ast_signature_rest_named

        colon_opt ::= T_op_colon | nothing

        qmark_opt ::= T_op_qmark | nothing

        assign_opt ::= assign | nothing

        assign ::= T_op_assign expression
            action => ast_assign

        nothing ::=

        traits ::= trait*
            separator => T_op_list_sep
            action => ast_list

        trait ::= T_op_colon bareword trait_arguments_opt
            action => ast_trait

        trait_arguments_opt ::= trait_arguments | nothing

        trait_arguments ::= T_par_left arguments T_par_right
            action => ast_trait_arguments

        block ::= T_brac_left block_body T_brac_right
            action => ast_block

        block_body ::= expression*
            separator => T_stmt_sep
            action => ast_list

        method ::= variable | bareword

        assignable ::= variable | slot

        arguments ::= argument_item*
            separator => T_op_list_sep
            action => ast_arguments

        argument_item ::= named_item | list_item

        array_init ::= list_item*
            separator => T_op_list_sep
            action => ast_list

        hash_init ::= named_item*
            separator => T_op_list_sep
            action => ast_list

        list_item ::= expression | slice_list
        named_item ::= named_val | slice_named

        slice_list  ::= T_op_slice_list expression
            action => ast_slice_list
        slice_named ::= T_op_slice_named expression
            action => ast_slice_named

        named_val ::= expression T_op_colon expression
            action => ast_named_val

        op_assign ::= T_op_assign | T_op_assign_sc

        atom ::=
               number
                action => ast_number
            |  string
                action => ast_string
            |  T_op_math_low number
                action => ast_signed_number
            |  T_identifier
                action => ast_identifier
            |  T_lex_var    
                action => ast_lex_var
            |  T_par_left expression T_par_right
                action => ast_grouping
            | T_brack_left array_init T_brack_right
                action => ast_array
            | T_brac_left hash_init T_brac_right
                action => ast_hash

        variable ::= T_lex_var action => ast_lex_var
        bareword ::= T_bareword action => ast_bareword
#        identifier ::= T_identifier action => ast_identifier

        number ::= T_integer | T_float
        string ::= T_str_single | T_str_double

    },
});

$_grammar->precompute;

my %_retry_token = (
    bareword        => 'identifier',
    op_not_high     => 'op_emark',
);

sub parse {
    my ($self, $source) = @_;
    return Document->$_new_ast(name => $source->name)
        unless length $source->body;
    my $recog = Marpa::R2::Recognizer->new({ grammar => $_grammar });
    my $tokens = $self->_tokens_for($source);
    for my $token (@$tokens) {
        my $type = $token->[0];
        my $value = $token->[1];
        my $ok = $recog->read('T_' . $type, $token);
        unless (defined $ok) {
            if (my $retry = $_retry_token{$type}) {
                $ok = $recog->read(
                    'T_' . $retry,
                    [$retry, @{ $token }[1, 2]],
                );
            }
        }
        die sprintf('Unable to parse %s (%s)', $token->[0], $token->[1])
            unless defined $ok;
    }
    my $ok = $recog->read('END_OF_STREAM')
        or die "Unexpected end";
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
    ['math_high',   '*', '/', 'mod'],
    ['method',      '.&', '.'],
    ['list_sep',    ','],
    ['slice_list',  '@'],
    ['slice_named', '%'],
    ['colon',       ':'],
    ['qmark',       '?'],
);

my @_tokens = (
    ['par_left',    '('],
    ['par_right',   ')'],
    ['brack_left',  '['],
    ['brack_right', ']'],
    ['brac_left',   '{'],
    ['brac_right',  '}'],
    (map { ["kw_$_", qr{\Q$_\E}] } @_keywords),
    (map {
        my ($name, @symbols) = @$_;
        ["op_$name", map qr{$_}, join '|', map {
            my $follow = m{[a-z0-9_]$}
                ? qr{(?![a-z0-9_])}
                : '';
            qr{\Q$_\E$follow}
        } @symbols];
    } @_operators),
    ['identifier',  qr{ $_rx_bareword (?: :: $_rx_bareword )+ }x],
    ['bareword',    $_rx_bareword],
    ['lex_var',     qr{ \$ $_rx_bareword }x],
    ['float',       qr{ $_rx_int [.] $_rx_int }x],
    ['integer',     $_rx_int],
    ['stmt_sep',    ';'],
    ['whitespace',  qr{\s}],
    ['str_single',  qr{'.*?(?<!\\)'}],
    ['str_double',  qr{".*?(?<!\\)"}],
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
            unless (ref $pattern) {
                $pattern = qr{\Q$pattern\E};
            }
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

    sub passthrough { $_[1] }

    sub ast_list {
        my ($data, @items) = @_;
        return \@items;
    }

    sub ast_block {
        my ($data, $l_op, $body, $r_op) = @_;
        return $body;
    }

    sub ast_trait_arguments {
        my ($data, $l_op, $arguments, $r_op) = @_;
        return $arguments;
    }

    sub ast_arguments {
        my ($data, @arguments) = @_;
        return Arguments->$_new_ast(
            items       => \@arguments,
        );
    }

    my %_escape_sequence = (
        t => "\t",
        n => "\n",
        r => "\r",
        b => "\b",
    );

    sub ast_string {
        my ($data, $string) = @_;
        my ($type, $value, $location) = @$string;
        if ($value =~ s{^'(.+)'$}{$1}) {
            $value =~ s{\\'}{'}g;
        }
        elsif ($value =~ s{^"(.+)"$}{$1}) {
            $value =~ s{\\"}{"}g;
            $value =~ s{\\([tnrb])}{$_escape_sequence{$1}}ge;
        }
        else {
            die "Malformed string";
        }
        return String->$_new_ast(
            location    => $location,
            value       => $value,
        );
    }

    sub ast_trait {
        my ($data, $op, $name, $arguments) = @_;
        my ($type, $value, $location) = @$op;
        return Trait->$_new_ast(
            location    => $location,
            name        => $name->value,
            arguments   => $arguments || [],
        );
    }

    sub ast_lambda {
        my ($data, $kw, $signature, $traits, $body) = @_;
        my ($type, $value, $location) = @$kw;
        return Lambda->$_new_ast(
            location    => $location,
            expressions => $body,
            signature   => $signature,
            traits      => $traits || [],
        );
    }

    sub ast_lex_my {
        my ($data, $kw, $variable, $traits, $assign) = @_;
        my ($type, $value, $location) = @$kw;
        return Lexical::Declare->$_new_ast(
            location    => $location,
            variable    => $variable,
            traits      => $traits || [],
            initialize  => $assign,
        );
    }

    sub ast_assign {
        my ($data, $op, $expr) = @_;
        return $expr;
    }

    sub ast_signature_rest_named { signature_rest(1, @_) }
    sub ast_signature_rest_pos   { signature_rest(0, @_) }

    sub signature_rest {
        my ($is_named, $data, $op, $variable) = @_;
        return Signature::Rest->$_new_ast(
            is_named    => $is_named,
            variable    => $variable,
        );
    }

    sub ast_signature {
        my ($data, $l_op, $params, $r_op) = @_;
        my ($type, $value, $location) = @$l_op;
        my (@named, @positional, %rest);
        my $seen_named;
        my $seen_optional;
        my %seen_rest;
        for my $param (@{ $params || [] }) {
            if ($param->$_isa('Pryll::AST::Signature::Rest')) {
                my $p_type = $param->is_named ? 'named' : 'positional';
                die "Cannot have more than one $p_type rest parameter"
                    if $seen_rest{$p_type};
                $seen_rest{$p_type} = 1;
                $rest{"${p_type}_rest"} = $param;
            }
            else {
                die "Parameters can't come after rest parameters"
                    if keys %seen_rest;
                if ($param->is_named) {
                    $seen_named = 1;
                    push @named, $param;
                }
                else {
                    die "Positionals can't come after named parameters"
                        if $seen_named;
                    if ($param->is_optional) {
                        $seen_optional = 1;
                    }
                    else {
                        die "Requireds can't come after optionals"
                            if $seen_optional;
                    }
                    push @positional, $param;
                }
            }
        }
        return Signature->$_new_ast(
            location    => $location,
            named       => \@named,
            positional  => \@positional,
            %rest,
        );
    }

    sub ast_signature_param {
        my ($data, $is_named, $variable, $is_opt, $traits, $expr) = @_;
        return Signature::Parameter->$_new_ast(
            is_named        => $is_named ? 1 : 0,
            is_optional     => $is_opt ? 1 : $expr ? 1 : 0,
            variable        => $variable,
            init_expression => $expr,
            traits          => $traits || [],
        );
    }

    sub ast_named_val {
        my ($data, $name, $op, $expr) = @_;
        my ($type, $value, $location) = @$op;
        if ($name->$_isa('Pryll::AST::Identifier')) {
            return Named->$_new_ast(
                location    => $location,
                value       => $expr,
                name        => String->$_new_ast(
                    location    => $name->location,
                    value       => $name->value,
                ),
            );
        }
        else {
            return Named->$_new_ast(
                location    => $location,
                name        => $name,
                value       => $expr,
            );
        }
    }

    sub ast_hash {
        my ($data, $l_op, $list, $r_op) = @_;
        my ($type, $value, $location) = @$l_op;
        return Hash->$_new_ast(
            location    => $location,
            items       => $list,
        );
    }

    sub ast_array {
        my ($data, $l_op, $list, $r_op) = @_;
        my ($type, $value, $location) = @$l_op;
        return Array->$_new_ast(
            location    => $location,
            items       => $list,
        );
    }

    sub ast_signed_number {
        my ($data, $sign, $number) = @_;
        return ast_number($data, [
            $number->[0],
            $sign->[1] . $number->[1],
            $sign->[2],
        ]);
    }

    sub ast_number {
        my ($data, $token) = @_;
        my ($type, $value, $location) = @$token;
        $value =~ s{_}{}g;
        return Number->$_new_ast(
            value       => $value,
            location    => $location,
        );
    }

    sub ast_slice_named {
        my ($data, $op, $expr) = @_;
        my ($type, $value, $location) = @$op;
        return Slice::Named->$_new_ast(
            location => $location,
            value    => $expr,
        );
    }

    sub ast_slice_list {
        my ($data, $op, $expr) = @_;
        my ($type, $value, $location) = @$op;
        return Slice::List->$_new_ast(
            location => $location,
            value    => $expr,
        );
    }

    sub ast_slot {
        my ($self, $item, $l_op, $slot, $r_op) = @_;
        my ($type, $value, $location) = @$l_op;
        return Slot->$_new_ast(
            location    => $location,
            object      => $item,
            slot        => $slot,
        );;
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

    sub ast_identifier {
        my ($data, $token) = @_;
        my ($type, $value, $location) = @$token;
        return Identifier->$_new_ast(
            value       => $value,
            location    => $location,
        );
    }

    sub ast_bareword {
        my ($data, $token) = @_;
        my ($type, $value, $location) = @$token;
        return Bareword->$_new_ast(
            value       => $value,
            location    => $location,
        );
    }

    sub ast_method {
        my ($data, $invocant, $op, $method, $maybe, $chain, $args) = @_;
        my ($type, $value, $location) = @$op;
        return Operator::Method->$_new_ast(
            invocant    => $invocant,
            method      => $method,
            arguments   => $args || [],
            symbol      => $value,
            location    => $location,
            is_maybe    => $maybe ? 1 : 0,
            is_chained  => $chain ? 1 : 0,
        );
    }

    sub ast_grouping {
        my ($data, $l_par, $expr, $r_par) = @_;
        return $expr;
    }

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
