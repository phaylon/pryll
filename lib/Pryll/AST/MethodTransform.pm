use strictures 1;

package Pryll::AST::MethodTransform;
use Moo::Role;

use aliased 'Pryll::AST::Identifier';
use aliased 'Pryll::AST::Operator::Method';

sub _create_method_call {
    my ($self, $ctx, $location, $invocant, $method, @args) = @_;
    return Method->new(
        location    => $location,
        invocant    => $invocant,
        symbol      => '.',
        arguments   => \@args,
        method      => Identifier->new(
            location    => $location,
            value       => $method,
        ),
    )->compile($ctx);
}

1;
