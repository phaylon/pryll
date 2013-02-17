use strictures 1;

package Pryll::AST::String;
use Moo;
use Pryll::Util qw( pp );

with 'Pryll::HasLocation';

has value  => (is => 'ro', required => 1);

sub compile {
    my ($self, $ctx) = @_;
    return pp($self->value);
}

1;
