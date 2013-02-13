use strictures 1;

package Pryll::AST::Lambda;
use Moo;

with qw(
    Pryll::HasLocation
    Pryll::AST::HasExpressions
    Pryll::AST::HasTraits
    Pryll::AST::HasSignature
);

1;
