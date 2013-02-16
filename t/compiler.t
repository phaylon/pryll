use strictures 1;
use Test::More;

use Pryll::Test qw( :compile test_all :cb );

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

done_testing;
