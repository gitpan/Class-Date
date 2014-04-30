use Test;
use strict;
BEGIN { 
  plan tests => 11;
};
use Class::Date qw(date gmdate);
eval { require Env::C };

$Class::Date::DST_ADJUST=1;

ok(1);

# Class::Date::new

my $date1=Class::Date->new([2002,05,04,0,1,2],'CET');
ok $date1, "2002-05-04 00:01:02";
ok $date1->tz, 'CET';
ok $date1->tzdst, 'CEST';
ok $date1->epoch, 1020463262;

my $date2 = $date1->to_tz('GMT');
ok $date2, "2002-05-03 22:01:02";
ok $date2->tz, 'GMT';
ok $date2->tzdst, 'GMT';
ok $date1->epoch, 1020463262;

my $date3 = $date1->clone(tz => 'GMT');
ok $date3->epoch, 1020470462;
ok $date3, gmdate([2002,05,04,0,1,2]);
