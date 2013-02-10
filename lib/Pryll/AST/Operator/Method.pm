use strictures 1;

package Pryll::AST::Operator::Method;
use Moo;

with 'Pryll::HasLocation';

has invocant  => (is => 'ro', required => 1);
has symbol    => (is => 'ro', required => 1);
has method    => (is => 'ro', required => 1);

has _arguments_ref => (
    is          => 'ro',
    init_arg    => 'arguments',
    required    => 1,
);

sub arguments { @{ $_[0]->_arguments_ref } }

1;
