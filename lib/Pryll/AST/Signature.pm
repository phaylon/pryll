use strictures 1;

package Pryll::AST::Signature;
use Moo;

with 'Pryll::HasLocation';

has named_rest => (is => 'ro');

has _named_ref => (
    is          => 'ro',
    init_arg    => 'named',
    required    => 1,
);

sub named { @{ $_[0]->_named_ref } }

has positional_rest => (is => 'ro');

has _positional_ref => (
    is          => 'ro',
    init_arg    => 'positional',
    required    => 1,
);

sub positional { @{ $_[0]->_positional_ref } }

1;
