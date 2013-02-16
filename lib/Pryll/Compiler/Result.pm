use strictures 1;

package Pryll::Compiler::LOAD;
my $_LOAD = sub { eval shift };

package Pryll::Compiler::Result;
use Moo;

has compiled => (is => 'ro', required => 1);

sub run {
    my ($self) = @_;
    local $@;
    my $result = $self->compiled->$_LOAD;
    if ($@) {
        die "Error: $@";
    }
    return $result;
}

1;
