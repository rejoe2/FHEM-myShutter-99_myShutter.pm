##############################################
# $Id: myUtilsGeneralUse.pm 2020-10-12 Beta-User $
#

package main;

use strict;
use warnings;

sub
myUtilsGeneralUse_Initialize
{
  my $hash = shift;
}

# Enter you functions below _this_ line.

sub
mySwitchOffAfter {
  my $ondevice = shift // return;
  my $duration  = shift // "01:00:01";
  my $idname = "my_switchoff_".$ondevice;
  #fhem "sleep $duration $idname quiet;set $ondevice off"; 
  AnalyzeCommandChain(undef,"sleep $duration $idname quiet;set $ondevice off"); 

}

sub
myHHMMSS2sec
{
  my ($h,$m,$s) = split(":", shift);
  $m = 0 if(!$m);
  $s = 0 if(!$s);
  my $seconds = HOURSECONDS*$h+MINUTESECONDS*$m+$s;
  return $seconds;
}


#For presence messages via Telegram
#call: myTBotpresence($NAME,$EVTPART1)
sub myTBotpresence {
  my $name = shift;
  my $event = shift // return;
  my $msg = ReadingsVal($name,"msgText","none");
  my $target = getKeyValue($event);
  return undef if !$target;
  my $newState = "absent";
  CommandSet(undef,"$target T_last $msg");
  if ($msg =~ /^\/kurz.*/) {
    $newState = "absent" if ($msg =~ /^\/kurz.* Bin weg$/ or $msg =~ /^\/kurz 1$/);
    $newState = "present" if ($msg =~ /^\/kurz.* Zuhause$/ or $msg =~ /^\/kurz 2$/);
  }
  if ($newState =~ m/^(home|absent|present)$/) {
    CommandSet(undef,"$target T_status $newState");
    CommandSet(undef,"$target present") if $newState eq "present";
    my $checktimer = $target."_timerHK";
    my $hk_devices = AttrVal($target,"HT_Devices","devStrich0");
    if ($newState eq "present") {
      if ($msg =~ m/Komme/) {
        if (ReadingsVal("Heizperiode","state","off") eq "on")  {
          CommandCancel(undef,"$checktimer quiet");
          foreach my $setdevice (split (/,/,$hk_devices)) {
            CommandSet(undef,"$setdevice:FILTER=controlMode!=auto controlMode auto");
          }\
          AnalyzeCommandChain(undef,"sleep 03:00 $checktimer; set $hk_devices controlManu 18");
        }
      }
    } elsif ($newState eq "absent") {
      CommandSet(undef,"$target absent");
      if (ReadingsVal("Heizperiode","state","off") eq "on") {
        CommandSet(undef,"$hk_devices controlManu 18");
      }
    }
  }  
}

sub my_stairway_motion {
  my $dev = shift;
  my $event = shift // return;
  my $timeout = shift // 90;
  my $checktime = gettimeofday()+$timeout;

  if ($dev eq "Bewegungsmelder_Treppenhaus_EG") {
    return undef if ReadingsVal("Bewegungsmelder_Treppenhaus_Lichtlevel_EG","lux",0) > 20;
    my $setdevice = "Licht_Flur_Treppe";

    if(ReadingsAge($setdevice,"myLastPIR",10000) > 600 || ReadingsVal($setdevice,"myLastPIR","Bewegungsmelder_Treppenhaus_OG") ne "Bewegungsmelder_Treppenhaus_EG") {
    #EG-Lichter
    CommandSet(undef, "$setdevice on") if ReadingsVal($setdevice,"status","OFF") ne "ON";
    CommandSet(undef, "$setdevice brightness 163");
      readingsSingleUpdate($defs{$setdevice},"myLastPIR","$dev", 0);
    InternalTimer($checktime,"myTimeout_stairway_motion","$setdevice $dev");	
      
    #OG-Licht
    $setdevice = "Licht_Treppenhaus_OG";
    unless (ReadingsVal("$setdevice","state","off") =~ /on/) {
      CommandSet(undef, "$setdevice on : pct 25")  
    } elsif (ReadingsVal("$setdevice","brightness",0) < 80) {
      CommandSet(undef, "$setdevice brightness 40")  
    } 
    readingsSingleUpdate($defs{$setdevice},"myLastPIR","$dev", 0);
    return InternalTimer($checktime,"myTimeout_stairway_motion","$setdevice $dev");
    }
  } elsif ($dev eq "Bewegungsmelder_Treppenhaus_OG") {
    return undef if ReadingsVal("Bewegungsmelder_Treppenhaus_Lichtlevel_EG","lux",0) > 20;
    my $setdevice = "Licht_Flur_Treppe";

    if (ReadingsVal($setdevice,"status","OFF") eq "OFF") {
      CommandSet(undef, "$setdevice on");
      CommandSet(undef, "$setdevice brightness 60");
    } else {
      CommandSet(undef, "$setdevice brightness 60") if ReadingsVal($setdevice,"brightness",0) < 60;
    }
    readingsSingleUpdate($defs{$setdevice},"myLastPIR","$dev", 0);
    InternalTimer($checktime,"myTimeout_stairway_motion","$setdevice $dev");
  } 
}


sub myTimeout_stairway_motion {
  my ($name,$mdet) = split(' ',shift);
  #my $name = $hash->{NAME};
  if (ReadingsVal("$name","myLastPIR","none") eq $mdet) {
    CommandSet (undef,"$name off") ;
    CommandDeleteReading(undef, "$name myLastPIR");
  }
}

sub myCalendar2Holiday {
  my $calname    = shift // return;
  my $regexp     = shift // return;
  my $field      = shift // "summary";
  my $limit      = shift // 10;
  my $yearEndRe  = shift;
  my $targetname = shift // $calname;
  
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) =  localtime(gettimeofday());
  my @holidaysraw = split(/\n/,CommandGet(undef, qq($calname events format:custom="4 \$T1 \$T2 \$S" timeFormat:"%m-%d" limit:count=$limit filter:field($field)=~"$regexp")));
  my @holidays;
  for my $holiday (@holidaysraw) {
    if ($_ !~ m/$yearEndRe/) {
      push (@holidays, $_);
    } else { my @tokens = split (" ",$_);
      my $lines = "4 $tokens[1] 12-31 $tokens[3]";
      push (@holidays,$lines) if $month > 9;
      $lines = "4 01-01 $tokens[2] $tokens[3]";
      unshift (@holidays,$lines);
    }
  } 
  my $today = strftime "%d.%m.%y, %H:%M", localtime(time);;\
  unshift (@holidays, "# Created by at a_make_holiday on $today");
  FileWrite("./FHEM/${targetname}.holiday",@holidays);
}


1;
