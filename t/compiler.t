use strictures 1;
use Test::More;

use Pryll::Test qw( :compile test_all test_methods :cb );

my $_test_ok = sub {
    my ($source, $expected) = @_;
    my $result = run_string($source);
    is_deeply($result, $expected, 'value');
};

test_all('numbers', $_test_ok,
    ['integer', '23', '23'],
    ['integer with separators', '23_500', '23500'],
    ['zero', '0', '0'],
    ['float', '2.5', '2.5'],
);

test_all('lexicals', $_test_ok,
    ['declaration', 'my $foo = 23', '23'],
    ['access', 'my $foo = 23; 17; $foo', '23'],
    ['no initialization', 'my $foo; 23; $foo', undef],
    ['multiple', 'my $foo = 23; my $bar = 17; $foo', '23'],
    ['chained', 'my $foo = my $bar = 23', '23'],
    ['chained first', 'my $foo = my $bar = 23; $foo', '23'],
    ['chained second', 'my $foo = my $bar = 23; $bar', '23'],
    ['assign', 'my $foo; $foo = 23; $foo', '23'],
    ['chained assign first',
        'my $foo; my $bar; $foo = $bar = 23; $foo', '23'],
    ['chained assign second',
        'my $foo; my $bar; $foo = $bar = 23; $bar', '23'],
);

test_all('arrays', $_test_ok,
    ['construction', '[23, 17]', [23, 17]],
    ['single element', '[23]', [23]],
    ['empty', '[]', []],
    ['slot read', '[2, 3, 4][1]', '3'],
    ['slot write', 'my $foo = [2, 3, 4]; $foo[1] = 7; $foo', [2, 7, 4]],
    ['write return', 'my $foo = [2, 3, 4]; $foo[1] = 7', '7'],
    test_methods('[2, 3, 4]',
        ['.get', 'get', '(1)', 3],
        ['.set', 'set', '(1, 7); $obj', [2, 7, 4]],
        ['.set return', 'set', '(1, 7)', '7'],
    ),
);

done_testing;
