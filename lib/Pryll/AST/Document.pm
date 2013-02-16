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
    return sprintf(
        '(do { no warnings qw( void ); %s })',
        join('; ', map $_->compile($ctx), $self->parts),
    );
}

1;
