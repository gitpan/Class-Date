package Class::Date;

# $Id: Date.pm,v 1.2 2001/04/05 11:22:24 dlux Exp $

use strict;
use vars qw(
  $VERSION @EXPORT_OK $DATE_FORMAT $DST_ADJUST @NEW_FROM_SCALAR
);
use Carp;
use UNIVERSAL qw(isa);

use base qw(Exporter DynaLoader);
BEGIN { @EXPORT_OK = qw( date localdate gmdate $DATE_FORMAT cs_mon cs_sec ) }

$VERSION = '0.90';
Class::Date->bootstrap($VERSION);

$DST_ADJUST = 1;
$DATE_FORMAT="%Y-%m-%d %H:%M:%S";

# constants for Class::Date fields
use constant c_year  =>  0;
use constant c_mon   =>  1;
use constant c_day   =>  2;
use constant c_hour  =>  3;
use constant c_min   =>  4;
use constant c_sec   =>  5;
use constant c_wday  =>  6;
use constant c_yday  =>  7;
use constant c_isdst =>  8;
use constant c_epoch =>  9;
use constant c_isgmt => 10;
# constants for Class::Date::Rel fields
use constant cs_mon => 0;
use constant cs_sec => 1;

# this method is used to determine what is the package name of the relative
# time class. It is used at the operators. You unly need to redefine it if
# you want to derive both Class::Date and Class::Date::Rel.
# Look at the ClassDate in the Class::Date::Rel package also.
use constant ClassDateRel => "Class::Date::Rel";

use overload 
  '""'     => "string",
  '-'      => "subtract",
  '+'      => "add",
  '<=>'    => "compare",
  'cmp'    => "compare",
  fallback => 1;

sub date ($;$) { my ($date,$isgmt)=@_;
  return __PACKAGE__ -> new($date,$isgmt);
}

sub localdate ($) { date($_[0] || time,0) }

sub gmdate    ($) { date($_[0] || time,1) }


sub new { my ($proto,$time,$isgmt)=@_;
  my $class = ref($proto) || $proto;
  
  if (defined($time) && isa(ref($proto), __PACKAGE__ )) {
    $isgmt=$proto->[c_isgmt];
  }
  if (isa($time, __PACKAGE__ )) {
    return $class->new_copy($time,$isgmt);
  } elsif (isa($time,'Class::Date::Rel')) {
    return $class->new_from_scalar($time,$isgmt);
  } elsif (ref($time) eq 'ARRAY') {
    return $class->new_from_array($time,$isgmt);
  } elsif (ref($time) eq 'SCALAR') {
    return $class->new_from_scalar($$time,$isgmt);
  } elsif (ref($time) eq 'HASH') {
    return $class->new_from_hash($time,$isgmt);
  } else {
    return $class->new_from_scalar($time,$isgmt);
  }
}

sub new_copy { my ($s,$input,$isgmt)=@_;
  my $new_object=[ @$input ];
  # we don't mind $isgmt!
  return bless($new_object, ref($s) || $s);
}


sub new_from_array { my ($s,$time,$isgmt) = @_;
  my ($y,$m,$d,$hh,$mm,$ss,$dst) = @$time;
  my $obj= [
    ($y||2000)-1900, ($m||1)-1, $d||1,
    $hh||0         , $mm||0   , $ss||0
  ];
  $obj->[c_isgmt]=$isgmt;
  bless $obj,'Class::Date';
  $obj->_recalc_from_struct;
  return $obj;
}

sub new_from_hash { my ($s,$time,$isgmt) = @_;
  $s->new_from_array(_array_from_hash($time),$isgmt);
}

sub _array_from_hash { my ($val)=@_;
  [
    $val->{year} || ($val->{_year} ? $val->{_year} + 1900 : 0 ), 
    $val->{month} || $val->{mon} || ( $val->{_mon} ? $val->{_mon} + 1 : 0 ), 
    $val->{day_of_month}   || $val->{mday} || $val->{day},
    $val->{hour},
    $val->{minute} || $val->{min},
    $val->{second} || $val->{sec},
  ];
}

sub new_from_scalar { my ($s,$time,$isgmt)=@_;
  for (my $i=0;$i<@NEW_FROM_SCALAR;$i++) {
    my $ret=$NEW_FROM_SCALAR[$i]->($s,$time,$isgmt);
    return $ret if defined $ret;
  }
  return undef;
}

sub new_from_scalar_internal { my ($s,$time,$isgmt) = @_;
  return undef if !$time;
        
  if ($time =~ /^\s*(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\d*\s*$/) { 
    # mysql timestamp
    my ($y,$m,$d,$hh,$mm,$ss)=($1,$2,$3,$4,$5,$6);
    return $s->new_from_array([$y,$m,$d,$hh,$mm,$ss],$isgmt);
  } elsif ($time =~ /^\s*( \-? \d+ (\.\d* )? )\s*$/x) {
    # epoch secs
    my $obj=bless [],'Class::Date';
    $obj->[c_epoch]=$1;
    $obj->[c_isgmt]=$isgmt;
    $obj->_recalc_from_epoch;
    return $obj;
  } elsif ($time =~ m{ ^\s* ( \d{0,4} ) - ( \d\d? ) - ( \d\d? ) 
     ( \s+ ( \d\d? ) : ( \d\d? ) : ( \d\d? ) (\.\d+)? )? }x) {
    my ($y,$m,$d,$hh,$mm,$ss)=($1,$2,$3,$5,$6,$7);
    # ISO date
    return $s->new_from_array([$y,$m,$d,$hh,$mm,$ss],$isgmt);
  }
  else {
    return undef;
  }
}

push @NEW_FROM_SCALAR,\&new_from_scalar_internal;

if (eval { require Date::Parse }) {
  sub new_from_scalar_date_parse { my ($s,$data,$isgmt)=@_;
    my ($ss,$mm,$hh,$day,$month,$year)=
      Date::Parse::strptime($data, $isgmt ?  ('GMT') : ())
      or return undef;
    return $s->new_from_array([$year,$month,$day,$hh,$mm,$ss]);
  }
  push @NEW_FROM_SCALAR,\&new_from_scalar_date_parse;
}


sub _recalc_from_struct { my ($s) = @_;
  $s->[c_isdst] = -1;
  $s->[c_wday]  = 0;
  $s->[c_yday]  = 0;
  $s->[c_epoch] = 0; # these are required to suppress warinngs;
  $s->[c_epoch] = $s->strftime('%s');
  $s->[c_epoch]+= $s->tzoffset if $s->[c_isgmt];
  $s->_recalc_from_epoch;
}

sub _recalc_from_epoch { my ($s) = @_;
  @{$s}[c_year..c_isdst]= ( $s->[c_isgmt] ? 
    (gmtime($s->[c_epoch])) : localtime($s->[c_epoch]))[5,4,3,2,1,0,6,7,8];
}

sub year     { shift->[c_year]  +1900 }
sub _year    { shift->[c_year]  }
sub yr       { shift->[c_year]  % 100 }
sub mon      { shift->[c_mon]   +1 }
*month       = *mon;
sub _mon     { shift->[c_mon]   }
*_month      = *_mon;
sub day      { shift->[c_day]   }
*day_of_month= *mday = *day;
sub hour     { shift->[c_hour]  }
sub min      { shift->[c_min]   }
*minute      = *min;
sub sec      { shift->[c_sec]   }
*second      = *sec;
sub wday     { shift->[c_wday]  + 1 }
sub _wday    { shift->[c_wday]  }
*day_of_week = *_wday;
sub yday     { shift->[c_yday]  }
*day_of_year = *yday;
sub isdst    { shift->[c_isdst] }
*daylight_savings = \&isdst;
sub epoch    { shift->[c_epoch] }
*as_sec      = *epoch; # for compatibility
sub monname  { shift->strftime('%B') }
*monthname   = *monname;
sub wdayname { shift->strftime('%A') }
*day_of_weekname= *wdayname;
sub hms      { sprintf('%02d:%02d:%02d', @{ shift() }[c_hour,c_min,c_sec]) }

sub ymd { my ($s)=@_;
  sprintf('%04d/%02d/%02d', $s->year, $s->mon, $s->[c_day])
}

sub mdy { my ($s)=@_;
  sprintf('%02d/%02d/%04d', $s->mon, $s->[c_day], $s->year)
}

sub dmy { my ($s)=@_;
  sprintf('%02d/%02d/%04d', $s->[c_day], $s->mon, $s->year)
}

sub array { return ( @{ shift() }[c_year..c_sec] ) }

sub aref { return \( shift() -> array() ) }
*as_array = *aref;

sub struct {
  return ( @{ shift() }
    [c_sec,c_min,c_hour,c_day,c_mon,c_year,c_wday,c_yday,c_isdst] )
}

sub sref { return \( shift() -> struct() ) }

sub href { my ($s)=@_;
  my @struct=$s->struct;
  my $h={};
  foreach my $key (qw(sec min hour day month year wday yday isdst epoch)) {
    $h->{key}=shift @struct;
  }
  return $h;
}

*as_hash=*href;

sub hash { return %{ shift->href } }

# Thanks to Tony Olekshy <olekshy@cs.ualberta.ca> for this algorithm
sub tzoffset { my ($s)=@_;
  my $epoch = $s->[c_epoch];
  my $j = sub { # Tweaked Julian day number algorithm.
    my ($s,$n,$h,$d,$m,$y) = @_; $m += 1; $y += 1900;
    # Standard Julian day number algorithm without constant.
    my $y1 = $m > 2 ? $y : $y - 1;
    my $m1 = $m > 2 ? $m + 1 : $m + 13;
    my $day = int(365.25 * $y1) + int(30.6001 * $m1) + $d;
    # Modify to include hours/mins/secs in floating portion.
    return $day + ($h + ($n + $s / 60) / 60) / 24;
  };
  # Compute floating offset in hours.
  my $delta = 24 * (&$j(localtime $epoch) - &$j(gmtime $epoch));
  # Return value in seconds rounded to nearest minute.
  return int($delta * 60 + ($delta >= 0 ? 0.5 : -0.5)) * 60;
}

sub strftime { my ($s,$format)=@_;
  $format ||= "%a, %d %b %Y %H:%M:%S %Z";
  return strftime_xs($format,$s->struct);
}

sub string { my ($s) = @_;
  $s->strftime($DATE_FORMAT);
}

sub subtract { my ($s,$rhs)=@_;
  if (isa(ref($rhs), __PACKAGE__ )) {
    my $dst_adjust = 0;
    $dst_adjust = 60*60*( $s->[c_isdst]-$rhs->[c_isdst] ) if $DST_ADJUST;
    return $s->ClassDateRel->new($s->[c_epoch]-$rhs->[c_epoch]+$dst_adjust);
  } elsif ($rhs) {
    return $s->add(-$rhs);
  } else {
    return $s;
  }
}

sub add { my ($s,$rhs)=@_;
  $rhs=$s->ClassDateRel->new($rhs) if !isa($rhs,'Class::Date::Rel');
	
  return $s if !isa($rhs,'Class::Date::Rel');

  # adding seconds
  my $retval= $rhs->[cs_sec] ? 
    $s->new_from_scalar($s->[c_epoch]+$rhs->[cs_sec],$s->[c_isgmt]) :
    $s->new_copy($s);

  # adding months
  if ($rhs->[cs_mon]) {
    $retval->[c_mon]+=$rhs->[cs_mon];
    my $year_diff= $retval->[c_mon]>0 ? # instead of POSIX::floor
      int ($retval->[c_mon]/12) :
      int (($retval->[c_mon]-11)/12);
    $retval->[c_mon]  -= 12*$year_diff;
    $retval->[c_year] += $year_diff;
    $retval->_recalc_from_struct;
  }
  
  # adjust DST if necessary
  if ( $DST_ADJUST && (my $dstdiff=$retval->[c_isdst]-$s->[c_isdst]))  {
    $retval->[c_epoch] -= $dstdiff*60*60;
    $retval->_recalc_from_epoch;
  }
  
  # sigh! We finished!
  return $retval;
}

sub trunc { my ($s)=@_;
  $s->new_from_array([@{$s}[c_year,c_mon,c_day],0,0,0],$s->[c_isgmt]);
  $s->[c_sec]=0;
  $s->[c_min]=0;
  $s->[c_hour]=0;
  $s->_recalc_from_struct;
  $s;
}

*truncate = *trunc;

sub get_epochs {
  my ($lhs,$rhs,$reverse)=@_;
  if (!isa(ref($rhs), __PACKAGE__ )) {
    $rhs = $lhs->new($rhs);
  }
  return $rhs->epoch, $lhs->epoch if $reverse;
  return $lhs->epoch, $rhs->epoch;
}

sub compare {
  my ($lhs, $rhs)=get_epochs(@_);
  return $lhs <=> $rhs;
}

package Class::Date::Rel;
use strict;
use vars qw(@NEW_FROM_SCALAR);
use UNIVERSAL qw(isa);

use constant SEC_PER_MONTH => 2_629_744;

# see the ClassDateRel const in package Class::Date
use constant ClassDate => "Class::Date";

BEGIN { Class::Date->import qw(cs_mon cs_sec) };

use overload 
  '0+'  => "sec",
  '""'  => "sec",
  '<=>' => "compare",
  'cmp' => "compare",
  '+'   => "add",
  'neg' => "neg",
  fallback => 1;
                
sub new { my ($proto,$val)=@_;
  my $class = ref($proto) || $proto;
  if (isa(ref($val), __PACKAGE__ )) {
    return $class->new_copy($val);
  } elsif (ref($val) eq 'ARRAY') {
    return $class->new_from_array($val);
  } elsif (ref($val) eq 'HASH') {
    return $class->new_from_hash($val);
  } elsif (ref($val) eq 'SCALAR') {
    return $class->new_from_scalar($$val);
  } else {
    return $class->new_from_scalar($val);
  };
}

sub new_copy { my ($s,$val)=@_;
  return bless([@$val], ref($s)||$s);
}

sub new_from_array { my ($s,$val) = @_;
  my ($y,$m,$d,$hh,$mm,$ss) = @$val;
  return bless([ ($y || 0) * 12 + $m , ($ss || 0) + 
    60*(($mm || 0) + 60*(($hh || 0) + 24* ($d || 0))) ], ref($s)||$s);
}

sub new_from_hash { my ($s,$val) = @_;
  $s->new_from_array(Class::Date::_array_from_hash($val));
}

sub new_from_scalar { my ($s,$val)=@_;
  for (my $i=0;$i<@NEW_FROM_SCALAR;$i++) {
    my $ret=$NEW_FROM_SCALAR[$i]->($s,$val);
    return $ret if defined $ret;
  }
  return undef;
}

sub new_from_scalar_internal { my ($s,$val)=@_;
  return undef if !defined $val;
  return bless([0,$1],ref($s) || $s) 
    if $val =~ / ^ \s* ( \-? \d+ ( \. \d* )? ) \s* $/x;

  if ($val =~ m{ ^\s* ( \d{1,4} ) - ( \d\d? ) - ( \d\d? ) 
      ( \s+ ( \d\d? ) : ( \d\d? ) : ( \d\d? ) (\.\d+)? )? }x ) {
    # ISO date
    my ($y,$m,$d,$hh,$mm,$ss)=($1,$2,$3,$5,$6,$7);
    return $s->new_from_array([$y,$m,$d,$hh,$mm,$ss]);
  }

  my ($y,$m,$d,$hh,$mm,$ss)=(0,0,0,0,0,0);
  $val =~ s{ \G \s* ( \-? \d+) \s* (Y|M|D|h|m|s) }{
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
  return $s->new_from_array([$y,$m,$d,$hh,$mm,$ss]);
}

push @NEW_FROM_SCALAR,\&new_from_scalar_internal;

sub compare { my ($s,$val2,$reverse) = @_;
  my $rev_multiply=$reverse ? -1 : 1;
  if (isa($val2, __PACKAGE__ )) {
    return ($s->sec <=> $val2->sec) * $rev_multiply;
  } else {
    my $date_obj=$s->new($val2);
    return ($s->sec <=> 0) * $rev_multiply if !defined $date_obj;
    return ($s->sec <=> $date_obj->sec) * $rev_multiply;
  }
}

sub add { my ($s,$val2)=@_;
  if (my $reldate=$s->new($val2)) {
    my $months=$s->[cs_mon] + $reldate->[cs_mon];
    my $secs  =$s->[cs_sec] + $reldate->[cs_sec];
    return $s->new_from_hash({ month => $months, sec => $secs }) if $months;
    return $secs;
  } else {
    return $s;
  }
}

sub neg { my ($s)=@_;
  return $s->new_from_hash({
      month => -$s->[cs_mon],
      sec   => -$s->[cs_sec]
  });
}

sub year     { shift->sec / (SEC_PER_MONTH*12) }
sub mon      { shift->sec / SEC_PER_MONTH }
*month       = *mon;
sub day      { shift->sec / (60*60*24) }
sub hour     { shift->sec / (60*60)  }
sub min      { shift->sec / 60  }
*minute      = *min;
sub sec { my ($s)=@_; $s->[cs_sec] + SEC_PER_MONTH * $s->[cs_mon]; }
*second      = *sec;

sub sec_part { shift->[cs_sec] }
*second_part = *sec_part;
sub mon_part { shift->[cs_mon] } 
*month_part  = *mon_part;

1;
__END__

=head1 NAME

Class::Date - Class for easy date and time manipulation

=head1 SYNOPSIS

  use Class::Date qw(date localdate gmdate $DATE_FORMAT);
  
  # creating absolute date object (local time)
  $date = new Class::Date [$year,$month,$day,$hour,$min,$sec];
  $date = date [$year,$month,$day,$hour,$min,$sec]; 
    # "date" is an exportable function, the same as Class::Date->new
  $date = date { year => $year, month => $month, day => $day,
    hour => $hour, min => $min, sec => $sec };
  $date = date "2001-11-12 07:13:12";
  $date = localdate "2001-12-11";
  ...

  # creating absolute date object (GMT)
  $date = new Class::Date [$year,$month,$day,$hour,$min,$sec],1;
  $date = gmtime "2001-11-12 17:13";
  ...

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
  $date;              # prints the date in default output format (see below)
  $date->year;        # year, e.g: 2001
  $date->_year;       # year - 1900, e.g. 101
  $date->yr;          # 2-digit year 0-99, e.g 1
  $date->mon;         # month 1..12
  $date->month;       # same as prev.
  $date->_mon;        # month 0..11
  $date->_month;      # same as prev.
  $date->day;         # day of month
  $date->mday;        # day of month
  $date->day_of_month;# same as prev.
  $date->hour;
  $date->min;
  $date->minute;      # same as prev.
  $date->sec;
  $date->second;      # same as prev.
  $date->wday;        # 1 = Sunday
  $date->_wday;       # 0 = Sunday
  $date->day_of_week; # same as prev.
  $date->yday;        
  $date->day_of_year; # same as prev.
  $date->isdst;       # DST?
  $date->daylight_savings; # same as prev.
  $date->epoch;       # UNIX time_t
  $date->monname;     # name of month, eg: March
  $date->monthname;   # same as prev.
  $date->wdayname;    # Thursday
  $date->day_of_weekname; # same as prev.
  $date->hms          # 01:23:45
  $date->ymd          # 2000/02/29
  $date->mdy          # 02/29/2000
  $date->dmy          # 29/02/2000
  $date->string       # 2000-02-29 12:21:11 (format can be changed, look below)
  "$date"             # same as prev.
  $date->tzoffset     # timezone-offset
  $date->strftime($format) # POSIX strftime (without the huge POSIX.pm)

  ($year,$month,$day,$hour,$min,$sec)=$date->array;
  ($year,$month,$day,$hour,$min,$sec)=@{ $date->aref };

  ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=$date->struct;
  ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=@{ $date->sref };

  $hash=$date->href;
  print $hash->{year}."-".$hash->{month}. ... $hash->{sec} ... ;
  
  %hash=$date->hash;

  # date format changes
  {
    local $Class::Date::DATE_FORMAT="%Y%m%d%H%M%S";
    print $date       # result: 20011222000000
    $Class::Date::DATE_FORMAT=undef;
    print $date       # result: Thu Oct 13 04:54:34 1994
    $Class::Date::DATE_FORMAT="%Y/%m/%d"
    print $date       # result: 1994/10/13
  }

  # adjusting DST in calculations  (see the doc)
  $Class::Date::DST_ADJUST = 1; # this is the default
  $Class::Date::DST_ADJUST = 0;

  # getting values of a relative date object
  $reldate;              # reldate in seconds (assumed 1 month = 2_629_744 secs)
  $reldate->year;
  $reldate->mon;
  $reldate->month;       # same as prev.
  $reldate->day;
  $reldate->hour;
  $reldate->min;
  $reldate->minute;      # same as prev.
  $reldate->sec;         # same as $reldate
  $reldate->second;      # same as prev.
  $reldate->sec_part;    # "second" part of the relative date
  $reldate->mon_part;    # "month"  part of the relative date

  # arithmetic with dates:
  print date([2001,12,11,4,5,6])->truncate; 
                               # will print "2001-12-11"
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

This module is intended to provide a general-purpose date and datetime type
for perl. You have a Class::Date class for absolute date and datetime, and have 
a Class::Date::Rel class for relative dates.

You can use "+", "-", "<" and ">" operators as with native perl data types.

=head1 USAGE

If you want to use a date object, you need to do the following:

  - create a new object
  - do some operations (+, -, comparison)
  - get result back

=head2 Creating a new date object

You can create a date object by the "date", "localdate" or "gmdate" function, 
or by calling the Class::Date constructor.

"date" and "Class::Date->new" are equivalent, both has two arguments: The
date and if the second argument is true then the date interpreted as GMT not
local.

  $date1= date [2000,11,12];
  $date2= Class::Date->new([2000,06,11,13,11,22],1);

"localdate $x" is equivalent to "date $x", "gmdate $x" is equivalent to
"date $x,1":

  $date1= localdate [2000,11,12];
  $date2= gmdate [2000,4,2,3,33,33];

  $date = localdate(time);

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

In this case, the "month" field of the $reldate object will be 0,
and the other fields will contain the difference between two dates;

=item comparison

You can compare two Class::Date objects, or one Class::Date object and
another data, which can be used for creating a new Class::Data object.

It means that you don't need to bless both objects, one of them can be a
simple string, array ref, hash ref, etc (see how to create a date object).

  if ( date('2001-11-12') > date('2000-11-11') ) { ... }

or 

  if ( date('2001-11-12') > '2000-11-11' ) { ... }

=item truncate

You can chop the time value from this object (set hour, min and sec to 0)
with the "truncate" or "trunc" method. It does not modify the specified
object, it returns with a new one.

=item Operations with Class::Date::Rel

The Class::Date::Rel object consists of a month part and a day part. Most
people only use the "day" part of it. If you use both part, then you can get
these parts with the "sec_part" and "mon_part" method. If you use "sec",
"month", etc. methods or if you use this object in a mathematical conent,
then this object is converted to one number, which is interpreted as second.
The conversion is based on a 30.436 days month. Don't use it too often,
because it is confusing...

If you use Class::Date::Rel in an expression with other Class::Date or
Class::Date::Rel objects, then it does what is expected: 

  date('2001-11-12')+'1M' will be '2001-12-12'

and

  date('1996-02-11')+'2M' will be '1996-04-11'

=back

=head2 Accessing data from a Class::Date and Class::Date::Rel object

You can use the methods methods described at the top of the document 
if you want to access parts of the data
which is stored in a Class::Date and Class::Date::Rel object.

=head1 DST_ADJUST

$DST_ADJUST is an importable variable, and is a very important configuration
option.

If it is set to true (default), then it adjusts the date and time when the
operation switches the border of DST. You will see the difference if you run
this code:

  $Class::Date::DST_ADJUST=0;
  for (my $date=localdate("2000-06-11");$date<"2001-4-5";$date+='1D') {
    print $date."\n";
  }

  $Class::Date::DST_ADJUST=1;
  for (my $date=localdate("2000-06-11");$date<"2001-4-5";$date+='1D') {
    print $date."\n";
  }

=head1 INTERNALS

This module uses operator overloading very heavily. I've found it quite stable,
but I am afraid of it a bit.

Date::Class object is an array reference.

Date::Class::Rel object is an array reference, which contains month and
second information. I need to store it as an array ref, because array and month
values cannot be converted into seconds, because of our super calendar.

You can add code references to the @Class::Date::NEW_FROM_SCALAR and
@Class::Date::Rel::NEW_FROM_SCALAR. These arrays are iterated through when a
scalar-format date must be parsed. These arrays only have one or two values
at initialization. The parameters which the code references got are the same 
as the "new" method of each class. In this way, you can personalize the date
parses as you want.

As of 0.90, the Class::Date has been rewritten. A lot of code and design
decision has been borrowed from Matt Sergeant's Time::Object, and there will
be some incompatibility with the previous public version (0.5). I tried to
keep compatibility methods in Class::Date. If you have problems regarding
this, please drop me an email with the description of the problem, and I will
set the compatibility back.

As of 0.90 this code is in alpha status, and
I want to release the beta versions (0.91-) soon, and then I want to release the
version 1.0 if no bugs can be found in that period.

=head1 BUGS

This module uses the POSIX functions for date and time calculations, so
it is not working for dates beyond 2038 and before 1902. I hope that someone 
will fix this with new time_t in libc. If you really need dates over 2038, 
you need to completely rewrite this module or use Date::Calc or other date 
modules.

=head1 COPYRIGHT

Copyright (c) 2001 Szabó, Balázs (dLux)

All rights reserved. This program is free software; you can redistribute it 
and/or modify it under the same terms as Perl itself.

Portions Copiright (c) Matt Sergeant

=head1 AUTHOR

  dLux (Szabó, Balázs) <dlux@kapu.hu>

=head1 CREDITS

  Lots of code are borrowed from the Time::Object module by 
    Matt Sergeant <matt@sergeant.org>

=head1 SEE ALSO

perl, Time::Object, Date::Calc.

