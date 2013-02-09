use strictures 1;

package Pryll::AST::Variable::Lexical;
use Moo;

with 'Pryll::HasLocation';

has name => (is => 'ro', required => 1);

1;
