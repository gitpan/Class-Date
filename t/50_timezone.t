use strict;
use warnings;
use Test::More;

plan tests => 11;

use Class::Date qw(date gmdate);
eval { require Env::C };
diag "Env::C version $Env::C::VERSION loaded" if not $@;

$Class::Date::DST_ADJUST=1;

ok(1);

# Class::Date::new

my $date1 = Class::Date->new([2002,05,04,0,1,2],'CET');
is $date1, "2002-05-04 00:01:02";
is $date1->tz, 'CET';
is $date1->tzdst, 'CEST';
is $date1->epoch, 1020463262;

my $date2 = $date1->to_tz('GMT');
is $date2, "2002-05-03 22:01:02";
is $date2->tz, 'GMT';
is $date2->tzdst, 'GMT';
is $date1->epoch, 1020463262;

my $date3 = $date1->clone(tz => 'GMT');
is $date3->epoch, 1020470462;
is $date3, gmdate([2002,05,04,0,1,2]);
