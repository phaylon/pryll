use strictures 1;

package Pryll::AST::HasExpressions;
use Moo::Role;

has _expressions_ref => (
    is          => 'ro',
    init_arg    => 'expressions',
    default     => sub { [] },
);

sub expressions { @{ $_[0]->_expressions_ref } }

1;
