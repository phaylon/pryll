use strictures 1;

package Pryll::AST::Operator::Binary;
use Moo;

with 'Pryll::HasLocation';

has symbol  => (is => 'ro', required => 1);
has left    => (is => 'ro', required => 1);
has right   => (is => 'ro', required => 1);

1;
