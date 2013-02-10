use strictures 1;

package Pryll::AST::Named;
use Moo;

with 'Pryll::HasLocation';

has name  => (is => 'ro', required => 1);
has value => (is => 'ro', required => 1);

1;
