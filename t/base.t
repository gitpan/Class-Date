print "1..6\n";

use Class::Date qw(now gmdate);
print "ok 1\n";

my $t = gmdate(315532800); # 00:00:00 1/1/1980

print "not " if ($t->year != 1980);
print "ok 2\n";

print "not " if ($t->hour);
print "ok 3\n";

print "not " if ($t->mon != 1);
print "ok 4\n";

print "not " unless now>"1970-1-1";
print "ok 5\n";

print "not " unless gmdate("now")>"1970-1-1";
print "ok 6\n";
