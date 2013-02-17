use strictures 1;

package Pryll::Compiler;
use Moo;

use aliased 'Pryll::Compiler::Result';
use aliased 'Pryll::Compiler::Context';

sub compile {
    my ($self, $ast) = @_;
    my $ctx = Context->new;
    my $compiled = $ctx->compile_scope($ast);
    return Result->new(compiled => $compiled);
}

1;
