use strictures 1;

package Pryll::AST::Signature::Rest;
use Moo;

has is_named    => (is => 'ro');
has variable    => (is => 'ro', required => 1);

1;
