use strictures 1;

package Pryll::AST::Variable::Lexical;
use Moo;

with 'Pryll::HasLocation';

has name => (is => 'ro', required => 1);

sub compile {
    my ($self, $ctx) = @_;
    return $self->render_storage;
}

sub compile_assign {
    my ($self, $ctx, $expr) = @_;
    return sprintf('scalar(undef(%s), %s = %s)',
        $self->render_typecache,
        $self->render_storage,
        $expr->compile($expr),
    );
}

sub compile_declare {
    my ($self, $ctx, $init_expr) = @_;
    my $init = $init_expr ? $init_expr->compile($ctx) : 'undef';
    return sprintf('scalar(my %s, my %s = %s)',
        $self->render_typecache,
        $self->render_storage,
        $init,
    );
}

sub render_typecache {
    my ($self) = @_;
    return join '_', '$lextype', $self->name;
}

sub render_storage {
    my ($self) = @_;
    return join '_', '$lexdata', $self->name;
}

1;
