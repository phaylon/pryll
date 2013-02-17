use strictures 1;

package Pryll::AST::Slot;
use Moo;

use aliased 'Pryll::AST::Identifier';
use aliased 'Pryll::AST::Operator::Method';

with qw(
    Pryll::HasLocation
    Pryll::AST::MethodTransform
);

has object => (is => 'ro', required => 1);
has slot   => (is => 'ro', required => 1);

sub compile_assign {
    my ($self, $ctx, $expr) = @_;
    return $self->_create_method_call(
        $ctx,
        $self->location,
        $self->object, 'set', $self->slot, $expr,
    );
}

sub compile {
    my ($self, $ctx) = @_;
    return $self->_create_method_call(
        $ctx,
        $self->location,
        $self->object, 'get', $self->slot,
    );
}

1;
