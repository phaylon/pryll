use strictures 1;

package Pryll::AST::Number;
use Moo;

with 'Pryll::HasLocation';

has value => (is => 'ro');

1;
