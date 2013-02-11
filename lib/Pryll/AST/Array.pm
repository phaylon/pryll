use strictures 1;

package Pryll::AST::Array;
use Moo;

with 'Pryll::HasLocation';

has _items_ref => (is => 'ro', init_arg => 'items', required => 1);

sub items { @{ $_[0]->_items_ref } }

1;
