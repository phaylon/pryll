use strictures 1;

package Pryll::AST::Operator::Binary;
use Moo;

with 'Pryll::HasLocation';

has symbol  => (is => 'ro', required => 1);
has left    => (is => 'ro', required => 1);
has right   => (is => 'ro', required => 1);

my %_op = (
    '=' => '_compile_assign',
);

sub compile {
    my ($self, $ctx) = @_;
    my $method = $_op{ $self->symbol }
        or die "Unimplemented binop";
    return $self->$method($ctx);
}

sub _compile_assign {
    my ($self, $ctx) = @_;
    return $self->left->compile_assign($ctx, $self->right);
}

1;
