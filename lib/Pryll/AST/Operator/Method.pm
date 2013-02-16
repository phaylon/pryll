use strictures 1;

package Pryll::AST::Operator::Method;
use Moo;

with qw(
    Pryll::HasLocation
    Pryll::AST::HasArguments
);

has invocant    => (is => 'ro', required => 1);
has symbol      => (is => 'ro', required => 1);
has method      => (is => 'ro', required => 1);
has is_maybe    => (is => 'ro');
has is_chained  => (is => 'ro');

1;
