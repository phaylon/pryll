use strictures 1;

package Pryll::AST::Arguments;
use Moo;

has _items_ref => (
    is          => 'ro',
    init_arg    => 'items',
    required    => 1,
);

sub items { @{ $_[0]->_items_ref } }

sub compile_positional {
    my ($self, $ctx) = @_;
    return sprintf('[%s]', join ', ',
        map  { $_->compile($ctx) }
        grep { not $_->isa('Pryll::AST::Named') }
        $self->items,
    );
}

sub compile_named {
    my ($self, $ctx) = @_;
    return sprintf('(+{%s})', join ', ',
        map  { ($_->name->compile($ctx), $_->value->compile($ctx)) }
        grep { $_->isa('Pryll::AST::Named') }
        $self->items,
    );
}

1;
