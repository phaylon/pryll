use strictures 1;

package Pryll::AST::HasArguments;
use Moo::Role;

has _arguments_ref => (
    is          => 'ro',
    init_arg    => 'arguments',
    default     => sub { [] },
);

sub arguments { @{ $_[0]->_arguments_ref } }

1;
