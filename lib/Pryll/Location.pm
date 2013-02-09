use strictures 1;

package Pryll::Location;
use Moo;

has name => (is => 'ro', required => 1);
has line => (is => 'ro', required => 1);
has char => (is => 'ro', required => 1);

1;
