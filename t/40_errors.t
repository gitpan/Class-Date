use Test;
use strict;
BEGIN { plan tests => 18; };
use Class::Date qw(:errors gmdate);

$Class::Date::DST_ADJUST=1;

ok(1);

$a = gmdate("195xwerf9");
ok !$a;
ok $a->error, E_UNPARSABLE;
ok $a->errstr, "Unparsable date or time: 195xwerf9\n";

$Class::Date::RANGE_CHECK=0;

$a = gmdate("2001-02-31");
ok $a, "2001-03-03";

$Class::Date::RANGE_CHECK=1;

$a = gmdate("2001-02-31");
ok !$a;
ok $a->error, E_RANGE;
ok $a->errstr, "Range check on date or time failed\n";

$a = gmdate("2006-2-6")->clone( year => -1);
ok !$a;
ok $a->error, E_INVALID;
ok $a->errstr, "Invalid date or time\n";

$a = new Class::Date(undef);
ok ! $a;
ok $a->error, E_UNDEFINED;
ok $a->errstr, "Undefined date object\n";

$a = gmdate("2006-2-6")->clone(month => 16);
ok !$a;
ok $a->error, E_INVALID;
ok $a->errstr, "Invalid date or time\n";

$a = gmdate("2001-05-04 07:09:09") + [1,-2,-4];
ok $a;
