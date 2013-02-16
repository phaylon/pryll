use strictures 1;

package Pryll::Compiler::Context;
use Moo;

has _lexical_ref => (
    is          => 'ro',
    init_arg    => undef,
    default     => sub { {} },
);

sub has_lexical {
    my ($self, $name) = @_;
    return exists $self->_lexical_ref->{$name};
}

sub add_lexical {
    my ($self, $name) = @_;
    die "Redeclaration of $name"
        if $self->has_lexical($name);
    $self->_lexical_ref->{$name} = 1;
    return 1;
}

1;
