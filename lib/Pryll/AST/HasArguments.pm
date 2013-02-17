use strictures 1;

package Pryll::AST::HasArguments;
use Moo::Role;

use aliased 'Pryll::AST::Arguments';

has arguments => (
    is          => 'ro',
    coerce      => sub {
        my ($value) = @_;
        return Arguments->new(items => $value)
            if ref($value) eq 'ARRAY';
        return $value;
    },
);

sub _render_positional_arguments {
    my ($self, $ctx) = @_;
    return sprintf('(%s)', join '||',
        $self->arguments
            ? $self->arguments->compile_positional($ctx)
            : (),
        '[]',
    );
}

sub _render_named_arguments {
    my ($self, $ctx) = @_;
    return sprintf('(%s)', join '||',
        $self->arguments
            ? $self->arguments->compile_named($ctx)
            : (),
        '{}',
    );
}

1;
