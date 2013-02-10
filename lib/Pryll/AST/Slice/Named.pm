use strictures 1;

package Pryll::AST::Slice::Named;
use Moo;

with 'Pryll::HasLocation';

has value => (is => 'ro', required => 1);

1;
