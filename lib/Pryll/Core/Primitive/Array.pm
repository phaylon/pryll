use strictures 1;

package Pryll::Core::Primitive::Array;
use Pryll::Util qw( oneline );

sub compile_set {
    return oneline q{
        die "Array.set expects two arguments"
            unless @{ %(v_pos_arg) } == 2;
        %(v_object)->[%(v_pos_arg)->[0]] = %(v_pos_arg)->[1];
    };
}

sub compile_get {
    return oneline q{
        die "Array.get expects one argument"
            unless @{ %(v_pos_arg) } == 1;
        %(v_object)->[%(v_pos_arg)->[0]];
    };
}

sub run_set {
    my ($array, $pos) = @_;
    $array->[$pos->[0]] = $pos->[1];
    return $pos->[1];
}

sub run_get {
    my ($array, $pos) = @_;
    return $array->[$pos->[0]];
}

1;
