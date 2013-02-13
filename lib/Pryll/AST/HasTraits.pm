use strictures 1;

package Pryll::AST::HasTraits;
use Moo::Role;

has _traits_ref => (
    is          => 'ro',
    init_arg    => 'traits',
    default     => sub { [] },
    required    => 1,
);

sub traits { @{ $_[0]->_traits_ref } }

1;
