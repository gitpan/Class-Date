package Class::Date;
use POSIX qw(floor);
use Exporter;
use strict;
use vars qw(@ISA @EXPORT_OK @PARSE_SCALAR_DATE $VERSION $DEBUG);
@ISA=qw(Exporter);
@EXPORT_OK=qw(date);

$VERSION='0.5';

use overload (
  '""'      => "as_scalar",
  '0+'      => "as_number",
  '+'       => "add",
  '-'       => "subs",
  '='       => "new",
  '<=>'     => "cmp",
  'cmp'     => "cmp",
  fallback  => 1,
);

sub date { Class::Date->new(@_) }

sub new { my ($class,$input)=@_;
  if (UNIVERSAL::isa($input,"Class::Date")) {
    return $class->new_copy($input);
  } elsif (UNIVERSAL::isa($input,'ARRAY')) {
    return $class->new_from_array($input);
  } elsif (UNIVERSAL::isa($input,'SCALAR')) {
    return $class->new_from_scalar($$input);
  } elsif (UNIVERSAL::isa($input,'HASH')) {
    return $class->new_from_hash($input);
  } elsif ($input && !ref($input)) {
    return $class->new_from_scalar($input);
  } else {
    return undef;
  }
}

sub new_copy { my ($class,$input)=@_;
  my $new_object=$$input;
  return bless(\$new_object,ref($class) || $class);
}

sub new_from_array { my ($class,$input)=@_;
  my $time=makedate(@$input);
  return bless(\$time,ref($class) || $class);
}

sub new_from_hash { my ($class,$input)=@_;
  $class->new_from_array( [$input->{year}||2000,$input->{month}||1,$input->{day}||1,
    $input->{hour} || 0, $input->{min} || 0, $input->{sec} || 0 ]);
}

sub new_from_scalar { my ($class,$input)=@_;
  my $date=$class->parse_scalar_date($input);
  return undef if !defined $date;
  return bless(\$date,ref($class) || $class);
}

sub parse_scalar_date_internal { my ($scalar)=@_;
  $_=$scalar;
  return undef if !$_;
  if (/^\s*(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\d*\s*$/) { # mysql timestamp
    my ($y,$m,$d,$hh,$mm,$ss)=($1,$2,$3,$4,$5,$6);
    return makedate($y,$m,$d,$hh,$mm,$ss)
  } elsif (/^\s*(\-?\d+)\s*$/) {                      # POSIX secs
    return $1;
  } elsif (m{ ^\s* ( \d{0,4} ) - ( \d\d? ) - ( \d\d? ) 
      ( \s+ ( \d\d? ) : ( \d\d? ) : ( \d\d? ) (\.\d+)? )? \s* $ }x) {
    my ($y,$m,$d,$hh,$mm,$ss)=($1,$2,$3,$5,$6,$7);    # ISO date
    return makedate($y,$m,$d,$hh,$mm,$ss);
  } else {
    return undef;
  };
}

sub makedate {
  my ($y,$m,$d,$hh,$mm,$ss)=@_[0,1,2,3,4,5];
  return POSIX::mktime($ss || 0,$mm || 0,$hh || 0,
    $d || 1,($m || 1)-1,($y || 2000)-1900,0,0,-1);
}

push @PARSE_SCALAR_DATE,\&parse_scalar_date_internal;

sub parse_scalar_date { my ($class,$scalar)=@_;
  for (my $i=0;$i<@PARSE_SCALAR_DATE;$i++) {
    my $ret=$PARSE_SCALAR_DATE[$i]->($scalar);
    return $ret if defined $ret;
  }
  return undef;
}

sub as_scalar { my ($obj)=@_;
  return sprintf "%04d-%02d-%02d %02d:%02d:%02d",@{ $obj->as_array };
}

sub as_array { my ($obj)=@_;
  my ($ss,$mm,$hh,$d,$m,$y)=localtime($$obj);
  $y+=1900;
  $m+=1;
  return [$y,$m,$d,$hh,$mm,$ss];
}

sub as_hash { my ($obj)=@_;
  my ($y,$m,$d,$hh,$mm,$ss)=@{ $obj->as_array };
  return {
    year  => $y,
    month => $m,
    day   => $d,
    hour  => $hh,
    min   => $mm,
    sec   => $ss,
    as_sec  => $$obj,
  }
}

sub as_number { my ($obj)=@_;
  return $$obj;
}

sub add { my ($obj1,$obj2)=@_;
  if (UNIVERSAL::isa($obj2,"Class::Date::Rel")) {
    return $obj1->add_reldate($obj2);
  } elsif (my $reldate=Class::Date::Rel->new($obj2)) { # is it a reldate?
    return $obj1->add_reldate($reldate);
  } else {
    return $obj1;
  }
}

sub add_reldate { my ($obj1,$obj2)=@_;
  my $result=$obj1->new_from_scalar($$obj1+$obj2->[2]) or return $obj1;
  if ($obj2->[0] || $obj2->[1]) { # if we need to add year or month
    my $res=$result->as_array;
    $res->[0]+=$obj2->[0];
    $res->[1]+=$obj2->[1];
    my $years=floor($res->[1]/12);
    $res->[1]-=12*$years;
    $res->[0]+=$years;
    $result=$obj1->new_from_array($res);
  }
  return $result;
}

sub subs { my ($obj1,$obj2,$reverse)=@_;
  return $obj2 if $reverse;
  if (UNIVERSAL::isa($obj2,"Class::Date")) {
    return Class::Date::Rel->new_from_scalar($$obj1-$$obj2);
  } elsif (UNIVERSAL::isa($obj2,"Class::Date::Rel")) {
    return $obj1->add_reldate(-$obj2);
  } elsif (my $reldate=Class::Date::Rel->new($obj2)) { # is it a reldate?
    return $obj1->add_reldate(-$reldate);
  } else {
    return $obj1;
  }
}

sub cmp { my ($obj1,$obj2,$reverse)=@_;
  my $rev_multiply=$reverse ? -1 : 1;
  if (UNIVERSAL::isa($obj2,"Class::Date")) {
    return ($$obj1 <=> $$obj2 ) * $rev_multiply;
  } else {
    my $date_obj=$obj1->new($obj2);
    return ( $$obj1 <=> undef ) * $rev_multiply if !defined $date_obj;
    return ( $$obj1 <=> $$date_obj ) * $rev_multiply;
  }
}

if (eval { require Date::Parse }) {
  sub parse_scalar_date_date_parse { my ($data)=@_;
    my ($ss,$mm,$hh,$day,$month,$year)=Date::Parse::strptime($data)
      or return undef;
    return makedate($year,$month,$day,$hh,$mm,$ss);
  }
  push @PARSE_SCALAR_DATE,\&parse_scalar_date_date_parse;
}

sub as_sec { ${ shift() } }

sub sec    { shift->as_array->[5] }
sub min    { shift->as_array->[4] }
sub hour   { shift->as_array->[3] }
sub day    { shift->as_array->[2] }
sub month  { shift->as_array->[1] }
sub year   { shift->as_array->[0] }

package Class::Date::Rel;
use strict;
use vars qw(@PARSE_SCALAR_REL_DATE $DEBUG);
use POSIX qw(floor);

use overload (
  '""'      => "as_scalar",
  '0+'      => 'as_number',
  '+'       => "add",
  'neg'     => "neg",
  '-'       => "subs",
  '='       => "new",
  'cmp'     => "cmp",
  '<=>'     => "cmp",
  fallback  => 1,
);

sub new { my ($class,$input)=@_;
  if (UNIVERSAL::isa($input,"Class::Date::Rel")) {
    return $class->new_copy($input);
  } elsif (UNIVERSAL::isa($input,'ARRAY')) {
    return $class->new_from_array($input);
  } elsif (UNIVERSAL::isa($input,'SCALAR')) {
    return $class->new_from_scalar($$input);
  } elsif (UNIVERSAL::isa($input,'HASH')) {
    return $class->new_from_hash($input);
  } elsif (defined $input && !ref($input)) {
    return $class->new_from_scalar($input);
  } else {
    return undef;
  }
}

sub new_copy { my ($class,$input)=@_;
  return bless([@$input],ref($class) || $class);
};

sub makereldate {
  my ($y,$m,$d,$hh,$mm,$ss)=@_;
  return [$y||0,$m||0,($ss||0)+60*(($mm||0)+60*(($hh||0)+24*($d||0)))];
}

sub new_from_array { my ($class,$input)=@_;
  return bless(makereldate(@$input),ref($class) || $class);
}

sub new_from_hash { my ($class,$input)=@_;
  $class->new_from_array( [$input->{year}||0, $input->{month}||0, $input->{day}||0,
    $input->{hour}||0, $input->{min}||0, $input->{sec}||0]);
}

sub new_from_scalar { my ($class,$input)=@_;
  my $date=$class->parse_scalar_rel_date($input);
  return undef if !defined $date;
  return bless($date,ref($class) || $class);
}

sub parse_scalar_rel_date_internal { my ($scalar)=@_;
  my ($y,$m,$d,$hh,$mm,$ss)=(0,0,0,0,0,0);
  return undef if !defined $scalar;
  return [0,0,$1] if $scalar =~ /^\s*(\d+)\s*$/;
  if ($scalar =~ m{ ^\s* ( \d{1,4} ) - ( \d\d? ) - ( \d\d? ) 
      ( \s+ ( \d\d? ) : ( \d\d? ) : ( \d\d? ) (\.\d+)? )? \s* $ }x ) {
    my ($y,$m,$d,$hh,$mm,$ss)=($1,$2,$3,$5,$6,$7);    # ISO date
    return makereldate($y,$m,$d,$hh,$mm,$ss);
  }
  $scalar =~ s{ \G \s* (\d+) \s* (Y|M|D|h|m|s) }{
    my ($num,$cmd)=($1,$2);
    if ($cmd eq 'Y') {
      $y=$num;
    } elsif ($cmd eq 'M') {
      $m=$num;
    } elsif ($cmd eq 'D') {
      $d=$num;
    } elsif ($cmd eq 'h') {
      $hh=$num;
    } elsif ($cmd eq 'm') {
      $mm=$num;
    } elsif ($cmd eq 's') {
      $ss=$num;
    }
    "";
  }gexi;
  return makereldate($y,$m,$d,$hh,$mm,$ss)
}

push @PARSE_SCALAR_REL_DATE,\&parse_scalar_rel_date_internal;

sub parse_scalar_rel_date { my ($class,$scalar)=@_;
  for (my $i=0;$i<@PARSE_SCALAR_REL_DATE;$i++) {
    my $ret=$PARSE_SCALAR_REL_DATE[$i]->($scalar);
    return $ret if defined $ret;
  }
  return undef;
}

sub add { my ($obj1,$obj2)=@_;
  if (UNIVERSAL::isa($obj2,"Class::Date")) {
    return $obj2->add($obj1);
  } elsif (my $reldate=$obj1->new($obj2)) {
    return $obj1->new_from_array([
      $obj1->[0]+$reldate->[0],
      $obj1->[1]+$reldate->[1],
      0,
      0,
      0,
      $obj1->[2]+$reldate->[2],
    ]);
  } else {
    return $obj1;
  }
}

sub subs { my ($obj1,$obj2,$reverse)=@_;
  return $obj2 if $reverse;
  if (my $reldate=$obj1->new($obj2)) {
    return $obj1->new_from_array([
      $obj1->[0]-$reldate->[0],
      $obj1->[1]-$reldate->[1],
      0,
      0,
      0,
      $obj1->[2]-$reldate->[2],
    ]);
  } else {
    return $obj1;
  }
}

sub neg { my ($obj1)=@_;
  return $obj1->new_from_array([
    -$obj1->[0],
    -$obj1->[1],
    0,
    0,
    0,
    -$obj1->[2],
  ]);
}

sub cmp { my ($obj1,$obj2,$reverse)=@_;
  my $rev_multiply=$reverse ? -1 : 1;
  if (UNIVERSAL::isa($obj2,"Class::Date::Rel")) {
    return ($obj1->as_number <=> $obj2->as_number) * $rev_multiply;
  } else {
    my $date_obj=$obj1->new($obj2);
    return ($obj1->as_number <=> undef) * $rev_multiply if !defined $date_obj;
    return ($obj1->as_number <=> $date_obj->as_number) * $rev_multiply;
  }
}

sub as_scalar { my ($obj)=@_;
  return sprintf "%04d-%02d-%02d %02d:%02d:%02d",@{ $obj->as_array };
}

sub as_array { my ($obj)=@_;
  my $sec=$obj->[2] % 60;
  my $val=floor($obj->[2]/60);
  my $min=$val % 60;
  $val=floor($val/60);
  my $hour= $val % 24;
  $val=floor($val/24);
  my $day= $val;
  return [$obj->[0],$obj->[1],$day,$hour,$min,$sec];
}

sub as_hash { my ($obj)=@_;
  my ($y,$m,$d,$hh,$mm,$ss)=@{ $obj->as_array };
  return {
    year  => $y,
    month => $m,
    day   => $d,
    hour  => $hh,
    min   => $mm,
    sec   => $ss,
    as_sec => $obj->as_sec,
    as_day => $obj->as_day,
  }
}

sub as_number { my ($obj)=@_;
  return $obj->[2]+60*60*24*(31*$obj->[1]+366*$obj->[0]);
}

sub as_sec { shift->[2] }
sub as_day { shift->as_sec/(24*60*60) }

sub sec    { shift->as_array->[5] }
sub min    { shift->as_array->[4] }
sub hour   { shift->as_array->[3] }
sub day    { shift->as_array->[2] }
sub month  { shift->[1] }
sub year   { shift->[0] }

__END__

=head1 NAME

Class::Date - Class for easy date manipulation

=head1 SYNOPSIS

  use Class::Date qw(date);
  
  # creating absolute date object
  $date = new Class::Date [$year,$month,$day,$hour,$min,$sec];
  $date = date [$year,$month,$day,$hour,$min,$sec]; 
    # "date" is an exportable function, the same as Class::Date->new
  $date = date { year => $year, month => $month, day => $day,
    hour => $hour, min => $min, sec => $sec };
  $date = date "2001-11-12 07:13:12";
  $date = date "2001-12-11";

  # creating relative date object
  # (normally you don't need to create this object explicitly)
  $reldate = new Class::Date::Rel "3Y 1M 3D 6h 2m 4s";
  $reldate = new Class::Date::Rel "6Y";
  $reldate = new Class::Date::Rel $secs;  # secs
  $reldate = new Class::Date::Rel [$year,$month,$day,$hour,$min,$sec];
  $reldate = new Class::Date::Rel { year => $year, month => $month, day => $day,
    hour => $hour, min => $min, sec => $sec };
  $reldate = new Class::Date::Rel "2001-11-12 07:13:12";
  $reldate = new Class::Date::Rel "2001-12-11";

  # getting values of an absolute date object
  print $date;
  print $date->year;
  print $date->month;
  print $date->day;
  print $date->hour;
  print $date->min;
  print $date->sec;
  print $date->as_sec; # UNIX time_t
  ($year,$month,$day,$hour,$min,$sec)=@{ $date->as_array };
  $hash=$date->as_hash;
  print $hash->{year}."-".$hash->{month}. ... 
        ... .$hash->{sec}." ".$hash->{as_sec};

  # getting values of a relative date object
  print $reldate;
  print $reldate->year;
  print $reldate->month;
  print $reldate->day;
  print $reldate->hour;
  print $reldate->min;
  print $reldate->sec;
  print $reldate->as_sec; # calculated from "sec","min","hour" and "day"
  print $reldate->as_day; # "as_sec" divided by 24*60*60, can be fractional!
  ($year,$month,$day,$hour,$min,$sec)=@{ $reldate->as_array };
  $hash=$reldate->as_hash;
  print $hash->{year}."-".$hash->{month}. ... 
        ... .$hash->{sec}." ".$hash->{as_sec};

  # arithmetic with dates:
  $new_date = $date+$reldate;
  $date2    = $date+'3Y';      # 3 Year
  $date3    = $date+[1,2,3];   # $date plus 1 year, 2 month, 3 days
  $date4    = $date+'3-1-5'    # $date plus 3 year, 1 month, 5 days

  $new_date = $date-$reldate;
  $date2    = $date-'3Y';      # 3 Year
  $date3    = $date-[1,2,3];   # $date minus 1 year, 2 month, 3 days
  $date4    = $date-'3-1-5'    # $date minus 3 year, 1 month, 5 days

  $new_reldate = $date1-$date2;
  $reldate2 = Class::Date->new('2000-11-12')-'2000-11-10';
  $reldate3    = $date3-'1977-11-10';

  $days_between = (Class::Date->new('2001-11-12')-'2001-07-04')->day;

  # comparison between absolute dates
  print $date1 > $date2 ? "I am older" : "I am younger";

  # comparison between relative dates
  print $reldate1 > $reldate2 ? "I am faster" : "I am slower";

=head1 DESCRIPTION

This module provides a date type for perl. You can create Class::Date objects 
for absolute dates, Class::Date::Rel objects for relative dates
and you can use "+", "-", "<" and ">" operators as with native perl data types. 

=head1 USAGE

If you want to use a date object, you need to do the following:

  - create a new object
  - do some operations (+, -, comparison)
  - get result back

=head2 Creating a new date object

You can create a date object by the "date" function, or by calling the 
Class::Date constructor (these are equivalent):

  $date1= date [2000,11,12];
  $date2= Class::Date->new([2000,11,12]);

The format of the accepted input date can be:

=over 4

=item [$year,$month,$day,$hour,$min,$sec]

An array reference with 6 elements. The missing elements have default
values (year: 2000, month, day: 1, hour, min, sec: 0)

=item { year => $year, month => $month, day => $day, hour => $hour, min => $min, sec => $sec }

A hash reference with the same 6 elements as above.

=item "YYYYMMDDhhmmss"

A mysql-style timestamp value, which consist of at least 14 digit.

=item "973897262"

A valid 32-bit integer: This is parsed as a unix time.

=item "YYYY-MM-DD hh::mm:ss"

A standard ISO date format. Additional ".fraction" part is ignored.

=item additional input formats

This module tries to load Date::Parse module, and if it find it then all 
these formats can be used as an input. Please refer to the Date::Parse
documentation (this part is not tested).

=back

=head2 Operations

=over 4

=item addition

You can add the following to a Class::Date object:

  - a valid Class::Date::Rel object
  - anything, that can be used for creating a new Class::Date::Rel object

It means that you don't need to create a new Class::Date::Rel object every
time when you add something to the Class::Date object, it creates them
automatically:

  $date= Class::Date->new('2001-12-11')+Class::Date::Rel->new('3Y');

is the same as:

  $date= date('2001-12-11')+'3Y';

You can provide a Class::Date::Rel object in the following form:

=over 4

=item array ref

The same format as seen in Class::Date format, except the default values are
different: all zero.

=item hash ref

The same format as seen in Class::Date format, except the default values are
different: all zero.

=item "973897262"

A valid 32-bit integer is parsed as seconds.

=item "YYYY-MM-DD hh::mm:ss"

A standard ISO date format, but this is parsed as relative date date and time,
so month, day and year can be zero (and defaults to zero).

=item "12Y 6M 6D 20h 12m 5s"

This special string can be used if you don't want to use the ISO format. This
string consists of whitespace separated tags, each tag consists of a number and
a unit. The units can be:

  Y: year
  M: month
  D: day
  h: hour
  m: min
  s: sec

The number and unit must be written with no space between them.

=back

=item substraction

The same rules are true for substraction, except you can substract 
two Class::Date object from each other, and you will get a Class::Date::Rel
object:

  $reldate=$date1-$date2;
  $reldate=date('2001-11-12 12:11:07')-date('2001-10-07 10:3:21');

In this case, the "month" and "year" field of the $reldate object will be 0,
and the other fields will contain the difference between two dates;

=item comparison

You can compare two Class::Date objects, or one Class::Date object and
another data, which can be used for creating a new Class::Data object.

It means that you don't need to bless both objects, one of them can be a
simple string, array ref, hash ref, etc (see how to create a date object).

  if ( date('2001-11-12') > date('2000-11-11') ) { ... }

or 

  if ( date('2001-11-12') > '2000-11-11' ) { ... }

=item Operations with Class::Date::Rel

You can do the operations mentioned above on the Class::Date::Rel objects also,
but do it only when you know what you are doing! You cannot compare two
different relative dates only if you use fixed length months and fixed length
years. The module currently uses a 366-day year and a 31-day month for the
comparison, but this is only used if you want to compare two relative date!

Every other cases (like date('2001-11-12')+'1M') the date value is incremented
with one month, not 31 days!

Virtually a relative date consist of 3 parts: "second","month" and "year".
Day, hour, min and sec all can be converted to the "second" value, but month
or year doesn't. This is why these are handled differently.

So keep it in mind: days, years and months are not convertible to each other
in Class::Date::Rel.

=back

=head2 Accessing data from a Class::Date and Class::Date::Rel object

You can use the following methods if you want to access parts of the data
which is stored in a Class::Date and Class::Date::Rel object:

  $x->year;
  $x->month;
  $x->day;
  $x->hour;
  $x->min;
  $x->sec;
  $x->as_sec;

$x->as_sec is a bit special in the case of Class::Date::Rel, because it 
contains only that parts of the object, which can be converted to second. year
and month cannot be converted, so these fields are not included.

$x->as_sec returns the seconds elapsed from the UNIX epoch in the case of a
Class::Date::Rel object, so there is no problem here.

If you want to get more than one part of the date, you can use the 
following methods:

  my ($y,$m,$d,$hh,$mm,$ss)=@{ $x->as_array }

or

  my $hashref= $x->as_hash;

Class::Date::Rel has a $x->as_day method, which is the same as $x-as_sec, but
divided by 24*60*60 to get the result in days, not in seconds.

=head1 INTERNALS

This module uses operator overloading very heavily. I've found it quite stable,
but I am afraid of it a bit.

Date::Class object is a scalar reference, which contains the UNIX timestamp
format of the date.

Date::Class::Rel object is an array reference, which contains year, month and
second information. I need to store it as an array ref, because array and month
values cannot be converted into seconds, because of our super calendar.

=head1 TODO

I personally think this module is quite usable right now, but it lacks the
"sugar" features, which can be found other Date-specific modules, like
business-date calculations, different date-style parsing, day-of-week, etc.

I don't want to write it again, but I may wrap that functionality around if
the specific module is available.

I have problems with the different style of date-parsing, because Date::Calc
has 2 different date-parsing function, Decode_Date_EU and Decode_Date_US. I
cannot use them, because I cannot decide which parser I can use (if I am
in the US or in EU).

Suggestions welcome.

=head1 BUGS

This module uses the POSIX functions for date and time calculations, so
it is not working for dates beyond 2038 and before 1902. I hope the someone will fix this with new
time_t in libc. If you really need dates over 2038, you need to completely
rewrite this module or use Date::Calc or other Date modules.

=head1 COPYRIGHT

Copyrigh (c) 2001 Szabó, Balázs (dLux)

All rights reserved. This program is free software; you can redistribute it 
and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

dLux (Szabó, Balázs) <dlux@kapu.hu>

=head1 SEE ALSO

perl(1).

