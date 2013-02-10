use strictures 1;

package Pryll::AST::Identifier;
use Moo;

with 'Pryll::HasLocation';

has value => (is => 'ro', required => 1);

1;
