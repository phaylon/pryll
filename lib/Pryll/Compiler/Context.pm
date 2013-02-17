use strictures 1;

package Pryll::Compiler::Context;
use Moo;
use Data::Dump qw( pp );

my $_is_final       = 'FINAL';
my $_is_declared    = 'DECLARE';

has parent => (
    is          => 'ro',
);

has index => (
    is          => 'ro',
    default     => sub { 0 },
);

has internal_index => (
    is          => 'ro',
    writer      => '_set_internal_index',
    default     => sub { 0 },
);

has _lexical_ref => (
    is          => 'ro',
    init_arg    => undef,
    default     => sub { {} },
);

sub make_internals { map $_[0]->make_internal($_), @_[1 .. $#_] }

sub make_internal {
    my ($self, $name) = @_;
    my $index = $self->internal_index;
    $self->_set_internal_index($index + 1);
    return sprintf 'I%d_%s', $index, $name;
}

sub _has_lexical {
    my ($self, $name) = @_;
    return $self->_lexical_ref->{$name} || 0;
}

sub ensure_known_lexical {
    my ($self, $name) = @_;
    die "Unknown variable"
        unless $self->known_lexical($name);
    return 1;
}

sub known_lexical {
    my ($self, $name) = @_;
    return 1
        if $self->_has_lexical($name) eq $_is_final;
    return $self->parent->known_lexical($name)
        if $self->parent;
    return 0;
}

sub add_lexical {
    my ($self, $name) = @_;
    die "Redeclaration of $name"
        if $self->_has_lexical($name);
    $self->_lexical_ref->{$name} = $_is_declared;
    return 1;
}

sub finalize_lexicals {
    my ($self) = @_;
    my $lex = $self->_lexical_ref;
    $lex->{$_} = $_is_final
        for keys %$lex;
    return 1;
}

sub compile_statement {
    my ($self, $ast) = @_;
    my $result = $ast->compile($self);
    $self->finalize_lexicals;
    return $result;
}

sub render_lexical_assign {
    my ($self, $name, $expr) = @_;
    return sprintf('(%s = %s)',
        $self->_lexical_storage($name),
        $expr->compile($self),
    );
}

sub render_lexical_declare {
    my ($self, $name, $init_expr) = @_;
    $self->add_lexical($name);
    return sprintf('(%s = %s)',
        $self->_lexical_storage($name),
        $init_expr ? $init_expr->compile($self) : '(undef)',
    );
}

sub render_lexical {
    my ($self, $name) = @_;
    return $self->_lexical_storage($name);
}

sub _lexical_storage {
    my ($self, $name) = @_;
    return sprintf('$LEX%d{%s}',
        $self->index,
        pp($name),
    );
}

sub compile_scope {
    my ($self, $ast) = @_;
    return sprintf('(do { my %%LEX%d; undef; %s })',
        $self->index,
        $ast->compile($self),
    );
}

1;
