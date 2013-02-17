use strictures 1;

package Pryll::AST::Operator::Method;
use Moo;
use Pryll::Util qw( compose pp oneline typeof block );

use aliased 'Pryll::Core::Primitive::Array';

with qw(
    Pryll::HasLocation
    Pryll::AST::HasArguments
);

has invocant    => (is => 'ro', required => 1);
has symbol      => (is => 'ro', required => 1);
has method      => (is => 'ro', required => 1);
has is_maybe    => (is => 'ro');
has is_chained  => (is => 'ro');

my @_primitive = (
    [Array, 'array'],
);

sub compile {
    my ($self, $ctx) = @_;
    if ($self->symbol eq '.') {
        return $self->_compile_method_call($ctx);
    }
    elsif ($self->symbol eq '.&') {
        return $self->_compile_method_ref($ctx);
    }
    else {
        die "Method op not implemented";
    }
}

sub is_static { $_[0]->method->isa('Pryll::AST::Bareword') }

sub _find_primitive_options {
    my ($self, $ctx) = @_;
    my $method = $self->method;
    return unless $method->isa('Pryll::AST::Bareword');
    my $name = $method->value;
    return map {
        my $handler = $_->[0]->can("compile_$name");
        $handler
            ? [$_->[1], $handler]
            : ();
    } @_primitive;
}

# foo.bar
# foo.$bar

sub _compile_method_call {
    my ($self, $ctx) = @_;
    my ($v_obj, $v_method, $v_pos, $v_nam)
        = $ctx->make_internals(qw( object method pos_arg nam_arg ));
    my ($v_m_type, $v_o_type, $v_found, $v_pack)
        = $ctx->make_internals(qw( method_type obj_type found package ));
    my %common = (
        v_object    => '$' . $v_obj,
        v_method    => '$' . $v_method,
        v_pos_arg   => '$' . $v_pos,
        v_nam_arg   => '$' . $v_nam,
        v_m_type    => '$' . $v_m_type,
        v_o_type    => '$' . $v_o_type,
        v_found     => '$' . $v_found,
        v_pack      => '$' . $v_pack,
        object_expr => $self->invocant->compile($ctx),
        method_expr => $self->_render_method($ctx),
        pos_arg     => $self->_render_positional_arguments($ctx),
        nam_arg     => $self->_render_named_arguments($ctx),
        method_type => typeof('$' . $v_method),
        object_type => typeof('$' . $v_obj),
        chain       => $self->is_chained ? '$' . $v_obj : '',
    );
    my $fail = $self->is_maybe
        ? sub { 'undef' }
        : sub { sprintf 'die("Method Call Error: " . %s)', pp(shift) };
    return oneline block compose(
        q!
            my %(v_object)  = %(object_expr);
            my %(v_method)  = %(method_expr);
            my %(v_pos_arg) = %(pos_arg);
            my %(v_nam_arg) = %(nam_arg);
            (do { %(call) });
            %(chain)
        !,
        %common,
        call => (
            $self->is_static
            ? $self->_compile_static_method_call($ctx, \%common, $fail)
            : $self->_compile_dynamic_method_call($ctx, \%common, $fail)
        ),
    );
}

sub _compile_dynamic_method_call {
    my ($self, $ctx, $common, $fail) = @_;
    return compose(
        q!
            my %(v_m_type) = %(method_type);
            (%(v_m_type) eq 'code')
                ? scalar(
                    %(v_method)->(
                        [%(v_object), @{ %(v_pos_arg) }],
                        %(v_nam_arg),
                    )
                ) :
            (%(v_m_type) eq 'scalar')
                ? (do {
                    my %(v_o_type) = %(object_type);
                    my %(v_pack)   = $Pryll::Core::_PRIMPACK{%(v_o_type)};
                    my %(v_found)  =
                        defined(%(v_pack))
                        ? (%(v_pack)->can('run_' . %(v_method)))
                        : (%(v_o_type) eq 'object')
                            ? (%(v_o_type)->can(%(v_method)))
                            : undef;
                    %(v_found)
                        ? scalar(%(v_found)->(
                            %(v_object),
                            %(v_pos_arg),
                            %(v_nam_arg),
                        )) :
                        %(fail_not_found);
                }) :
            die("Invalid method type '%(v_m_type)'")
        !,
        %$common,
        fail_not_found => $fail->('Method not found'),
    );
}

sub _compile_static_method_call {
    my ($self, $ctx, $common, $fail) = @_;
    my @primitives = $self->_find_primitive_options($ctx);
    return compose(
        q{
            my %(v_o_type) = (%(object_type));
            %(dispatch_static);
        },
        %$common,
        dispatch_static => join(' : ',
            (map {
                my ($type, $handler) = @$_;
                sprintf('(%s eq q(%s)) ? scalar(do { %s })',
                    compose('%(v_o_type)', %$common),
                    $type,
                    compose($handler->($self, $ctx), %$common),
                );
            } @primitives),
            compose(
                q{
                    (%(v_o_type) eq 'object') ? (do {
                        my %(v_found) = %(v_object)
                            ->can(%(v_method));
                        %(v_found) ? scalar(
                            %(v_found)->(
                                %(v_object),
                                %(v_pos_arg),
                                %(v_nam_arg),
                            )
                        ) : %(fail);
                    })
                },
                %$common,
                fail => $fail->('Method not found'),
            ),
            $fail->('Method not found'),
        ),
    );
}

sub _render_method {
    my ($self, $ctx) = @_;
    my $method = $self->method;
    return pp($method->value)
        if $method->isa('Pryll::AST::Bareword');
    return $method->compile($ctx);
}

1;
