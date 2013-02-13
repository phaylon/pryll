use strictures 1;

package Pryll::AST::Trait;
use Moo;

with qw(
    Pryll::HasLocation
    Pryll::AST::HasArguments
);

has name => (is => 'ro', required => 1);

1;
