use strictures 1;

package Pryll::Source;
use Moo;

has name => (is => 'ro', required => 1);
has body => (is => 'ro', required => 1);

1;
