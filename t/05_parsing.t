use Test;
use strict;
BEGIN { plan tests => 7; };
use Class::Date qw(gmdate);

ok(1);

my $t = gmdate("2008-8-3T11:7:10");

ok $t->year, 2008;
ok $t->month, 8;
ok $t->day, 3;
ok $t->hour, 11;
ok $t->min, 7;
ok $t->second, 10;
