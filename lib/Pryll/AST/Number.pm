use strictures 1;

package Pryll::AST::Number;
use Moo;

with 'Pryll::HasLocation';

has value => (is => 'ro');

sub compile {
    my ($self, $ctx) = @_;
    return $self->value;
}

1;
