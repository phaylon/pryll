use strictures 1;

package Pryll::AST::Signature::Parameter;
use Moo;

with qw( Pryll::AST::HasTraits);

has is_named        => (is => 'ro');
has is_optional     => (is => 'ro');
has variable        => (is => 'ro', required => 1);
has init_expression => (is => 'ro');

1;
