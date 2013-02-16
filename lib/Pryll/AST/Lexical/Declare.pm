use strictures 1;

package Pryll::AST::Lexical::Declare;
use Moo;

with qw(
    Pryll::HasLocation
    Pryll::AST::HasTraits
);

has initialize => (is => 'ro');
has variable   => (is => 'ro', required => 1);

sub compile {
    my ($self, $ctx) = @_;
    return $self->variable->compile_declare(
        $ctx,
        $self->initialize,
    );
}

1;
