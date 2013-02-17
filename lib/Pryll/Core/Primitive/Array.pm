use strictures 1;

package Pryll::Core::Primitive::Array;
use Pryll::Util qw( oneline );

sub compile_set {
    return oneline q!
        die "Array.set expects two arguments"
            unless @{ %(v_pos_arg) } == 2;
        %(v_object)->[%(v_pos_arg)->[0]] = %(v_pos_arg)->[1];
    !;
}

sub compile_get {
    return oneline q!
        die "Array.get expects one argument"
            unless @{ %(v_pos_arg) } == 1;
        %(v_object)->[%(v_pos_arg)->[0]];
    !;
}

sub compile_has {
    return oneline q!
        ( $#{ %(v_object) } >= %(v_pos_arg)->[0] ) ? 1 : 0;
    !;
}

sub compile_keys {
    return oneline q!
        [0 .. $#{ %(v_object) }];
    !;
}

sub compile_values {
    return oneline q!
        [@{ %(v_object) }];
    !;
}

sub compile_copy {
    return oneline q!
        [@{ %(v_object) }];
    !;
}

sub compile_size {
    return oneline q!
        scalar(@{ %(v_object) })
    !;
}

sub compile_delete {
    return oneline q!
        scalar(splice(@{ %(v_object) }, %(v_pos_arg)->[0], 1));
    !;
}

sub compile_shift {
    return oneline q!
        shift(@{ %(v_object) });
    !;
}

sub compile_unshift {
    return oneline q!
        unshift(@{ %(v_object) }, @{ %(v_pos_arg) });
        scalar(@{ %(v_pos_arg) });
    !;
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

sub run_has {
    my ($array, $pos) = @_;
    return( ($#$array >= $pos->[0]) ? 1 : 0 );
}

sub run_keys {
    my ($array, $pos) = @_;
    return [0 .. $#$array];
}

sub run_values {
    my ($array) = @_;
    return [@$array];
}

sub run_copy {
    my ($array) = @_;
    return [@$array];
}

sub run_size {
    my ($array) = @_;
    return scalar @$array;
}

sub run_delete {
    my ($array, $pos) = @_;
    return scalar splice @$array, $pos->[0], 1;
}

sub run_shift {
    my ($array) = @_;
    return shift @$array;
}

sub run_unshift {
    my ($array, $pos) = @_;
    unshift @$array, @$pos;
    return scalar @$pos;
}

1;
