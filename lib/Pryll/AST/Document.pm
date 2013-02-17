use strictures 1;

package Pryll::AST::Document;
use Moo;

has _parts_ref => (
    is          => 'ro',
    init_arg    => 'parts',
    default     => sub { [] },
);

sub parts { @{ $_[0]->_parts_ref } }

sub compile {
    my ($self, $ctx) = @_;
    return sprintf('(do { %s })',
        join('; ',
            'no warnings qw(void)',
            'require Scalar::Util',
            'require Pryll::Core',
            (map $ctx->compile_statement($_), $self->parts),
        ),
    );
}

1;
