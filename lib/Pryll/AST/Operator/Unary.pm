use strictures 1;

package Pryll::AST::Operator::Unary;
use Moo;

with 'Pryll::HasLocation';

has symbol  => (is => 'ro', required => 1);
has operand => (is => 'ro', required => 1);

1;
