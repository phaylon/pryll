use strictures 1;

package Pryll::HasLocation;
use Moo::Role;

has location => (is => 'ro', required => 1);

1;
