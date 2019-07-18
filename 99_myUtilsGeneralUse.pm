##############################################
# $Id: myUtilsGeneralUse.pm 2019-07-18 Beta-User $
#

package main;

use strict;
use warnings;
use POSIX;

sub
myUtilsGeneralUse_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub
mySwitchOffAfter($;$) {
  my ($ondevice,$duration) = @_;
  #Alternative writing (will modify @_):
  #my $ondevice = shift(@_);
  #my $duration = shift(@_);

  #can also be written as: $duration = "01:00:01" if !defined $duration;
  $duration = "01:00:01" unless defined $duration;
  #further possible notation:  $duration = $duration//"01:00:01";

  #gleichbedeutend mit 'fhem "defmod my_switchoff_$ondevice at +$duration set $ondevice off"'
  #CommandDefMod(undef,"my_switchoff_$ondevice at +$duration set $ondevice off");
  my $idname = "my_switchoff_".$ondevice;
  #fhem "sleep $duration $idname quiet;set $ondevice off"; 
  AnalyzeCommandChain(undef,"sleep $duration $idname quiet;set $ondevice off"); 

}

sub
myHHMMSS2sec($)
{
  my ($h,$m,$s) = split(":", shift);
  $m = 0 if(!$m);
  $s = 0 if(!$s);
  my $seconds = HOURSECONDS*$h+MINUTESECONDS*$m+$s;
  return $seconds;
}


#For presence messages via Telegram
#call: myTBotpresence($NAME,$EVTPART1)
sub myTBotpresence($$) {
  my ($name,$event) = @_;
  my $msg = ReadingsVal($name,"msgText","none");
  my $target = getKeyValue($event);
  my $newState = "absent";
  CommandSet(undef,"$target T_last $msg");
  if ($msg =~ /^\/kurz.*/) {
    $newState = "absent" if ($msg =~ /^\/kurz.* Bin weg$/ or $msg =~ /^\/kurz 1$/);
    $newState = "present" if ($msg =~ /^\/kurz.* Zuhause$/ or $msg =~ /^\/kurz 2$/);
  }
  if ($newState =~ /^(home|absent|present)$/) {
    CommandSet(undef,"$target T_status $newState");
    CommandSet(undef,"$target present") if ($newState =~ /^present$/);
    my $checktimer = $target."_timerHK";
    my $hk_devices = AttrVal($target,"HT_Devices","devStrich0");
    if ($newState eq "present") {
      if ($msg =~ /Komme/) {
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

1;
