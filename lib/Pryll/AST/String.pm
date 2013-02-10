use strictures 1;

package Pryll::AST::String;
use Moo;

with 'Pryll::HasLocation';

has value  => (is => 'ro', required => 1);

1;
