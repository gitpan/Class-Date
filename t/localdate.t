use Test;
use strict;
BEGIN { 
  plan tests => 58;
};
use Class::Date qw(localdate date);

$Class::Date::DST_ADJUST=1;

ok(1);

# Class::Date::new

my $date1=Class::Date->new([2000,11,11,0,1,2]);
ok $date1,"2000-11-11 00:01:02";

my $date2=localdate [2000,10,5];
ok $date2,"2000-10-05 00:00:00";

my $date3=date({ 
  year => 2001, month => 03, day => 11, 
  hour =>   12,   min => 13, sec => 55
});
ok $date3,"2001-03-11 12:13:55";

my $date4=localdate({
  year => 2001, month => 03, day => 11
});
ok $date4,"2001-03-11 00:00:00";

my $date5=localdate("2001-2-21 13:11:10.123456");
ok $date5,"2001-02-21 13:11:10";

my $date6=localdate("2001-2-21 13:11:06");
ok $date6,"2001-02-21 13:11:06";

my $date7=localdate("2000-11-11 0:0:0");
ok $date7,"2000-11-11";

my $date8=localdate("2001011312220112");
ok $date8,"2001-01-13 12:22:01";

my $date9=localdate("2001-5-11");
ok $date9,"2001-05-11 00:00:00";

my $date10=$date9->new($date9);
ok $date10,"2001-05-11";

# Class::Date::Rel::new

my $reldate1=Class::Date::Rel->new('1D');
ok $reldate1,"0000-00-01 00:00:00";

my $reldate2=Class::Date::Rel->new('1Y 1M 15h 20m');
ok $reldate2,"0001-01-00 15:20:00";

my $reldate3=Class::Date::Rel->new('3Y 3M 5D 13h 20m 15s');
ok $reldate3,"0003-03-05 13:20:15";

my $reldate4=Class::Date::Rel->new({ year => 5, day => 7});
ok $reldate4,"0005-00-07 00:00:00";

my $reldate5=Class::Date::Rel->new({ 
  year => 9, month => 8,    day => 7,
  hour => 6, min   => 65,   sec => 55,
});
ok $reldate5,"0009-08-07 07:05:55";

my $reldate6=Class::Date::Rel->new([9,8,7,6,65,55]);
ok $reldate6,"0009-08-07 07:05:55";

my $reldate7=Class::Date::Rel->new("7-8-6 07:11:10");
ok $reldate7,"0007-08-06 07:11:10";

my $reldate8=$reldate5->new($reldate7);
ok $reldate8,"7Y 8M 6D 7h 11m 10s";

# Class::Date::add

ok $date1+$reldate1,"2000-11-12 00:01:02";
ok $date7+$reldate3,"2004-02-16 13:20:15";
ok $date1+"2Y","2002-11-11 00:01:02";
ok $date1+"2-0-0","2002-11-11 00:01:02";

# Class::Date::subs
  
ok $date1-$reldate1,"2000-11-10 00:01:02";
ok $date7-$reldate3+$reldate3,$date7;
ok $date3-$date1,'120D 12h 12m 53s';
ok $date1-'1D',"2000-11-10 0:1:2";
ok $date1-[0,0,1],"2000-11-10 0:1:2";

# Class::Date Comparison

ok $date1>$date2;
ok $date1>=$date1;
ok ! ($date1<"2000-01-01");
ok ! ("2000-01-01">$date1);
ok "2000-01-02" <=> $date1, -1;
ok "2001-01-02" cmp $date1,  1 ;
ok $date1 <=> "2000-01-02",  1;
ok $date1 cmp "2001-01-02", -1;

# Class::Date::Rel Comparison

ok $reldate1<$reldate2;
ok $reldate2<'2Y';
ok '2Y'<$reldate3;
ok '2Y' <=> $reldate3, -1;
ok $reldate3 <=> '2Y',  1;

# Class::Date field methods;

ok $date1->year,2000;
ok $date1->mon,11;
ok $date1->day,11;
ok $date1->hour,0;
ok $date1->min,1;
ok $date1->sec,2;

# Default values for hash initialization

my $date11=new Class::Date { year => 2001 };
ok $date11,"2001-01-01 00:00:00";

my $date12=new Class::Date { month => 2   };
ok $date12,"2000-02-01 00:00:00";

my $date13=localdate [1998];
ok $date13,"1998-01-01";

my $reldate9=Class::Date::Rel->new( { year => 4 });
ok $reldate9, "4-0-0 0:0:0";

my $reldate10=Class::Date::Rel->new( { month => 5 });
ok $reldate10, "0-5-0 0:0:0";

my ($y,$m,$d,$hh,$mm,$ss)=$date1->array;
ok $y,2000;
ok $m,11;
ok $d,11;
ok $hh,0;
ok $mm,1;
ok $ss,2;

