use Test;
use strict;
BEGIN { plan tests => 12; };
use Class::Date qw(:errors gmdate);

$Class::Date::DST_ADJUST=1;

ok(1);

$a = gmdate("195xwerf9");
ok !$a;
ok $a->error, E_UNPARSABLE;

$Class::Date::RANGE_CHECK=0;

$a = gmdate("2001-02-31");
ok $a, "2001-03-03";

$Class::Date::RANGE_CHECK=1;

$a = gmdate("2001-02-31");
ok !$a;
ok $a->error, E_RANGE;

$a = gmdate("2006-2-6")->set( year => -1);
ok !$a;
ok $a->error, E_INVALID;

$a = new Class::Date(undef);
ok ! $a;
ok $a->error, E_UNDEFINED;

$a = gmdate("2006-2-6")->set(month => 16);
ok !$a;
ok $a->error, E_INVALID;

