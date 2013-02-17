use strictures 1;

package Pryll::AST::Variable::Lexical;
use Moo;

with 'Pryll::HasLocation';

has name => (is => 'ro', required => 1);

sub compile {
    my ($self, $ctx) = @_;
    $ctx->ensure_known_lexical($self->name);
    return $ctx->render_lexical($self->name);
}

sub compile_assign {
    my ($self, $ctx, $expr) = @_;
    $ctx->ensure_known_lexical($self->name);
    return $ctx->render_lexical_assign($self->name, $expr);
}

sub compile_declare {
    my ($self, $ctx, $init_expr) = @_;
    return $ctx->render_lexical_declare($self->name, $init_expr);
}

1;
