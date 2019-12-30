##############################################
# $Id: myUtilsGeneralUse.pm 2019-10-30 Beta-User $
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
  return undef unless $target;
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

sub my_stairway_motion($$;$) {
  my ($dev,$event,$timeout) = @_;
  $timeout = 90 unless $timeout;
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
	  InternalTimer($checktime,"myTimeout_stairway_motion","$setdevice $dev");	
    
	}
  } elsif ($dev eq "Bewegungsmelder_Treppenhaus_OG") {
    return undef if ReadingsVal("Bewegungsmelder_Treppenhaus_Lichtlevel_EG","lux",0) > 20;
    my $setdevice = "Licht_Flur_Treppe";

#	  if(ReadingsAge($setdevice,"myLastPIR",10000) > 600 ) {
      if (ReadingsVal($setdevice,"status","OFF") eq "OFF") {
	    CommandSet(undef, "$setdevice on");
        CommandSet(undef, "$setdevice brightness 60");
      } else {
	    CommandSet(undef, "$setdevice brightness 60") if ReadingsVal($setdevice,"brightness",0) < 60;
	  }
	  readingsSingleUpdate($defs{$setdevice},"myLastPIR","$dev", 0);
      InternalTimer($checktime,"myTimeout_stairway_motion","$setdevice $dev");
#	}
  } 
}


sub myTimeout_stairway_motion ($) {
  my ($name,$mdet) = split(' ',shift(@_));
  #my $name = $hash->{NAME};
  if (ReadingsVal("$name","myLastPIR","none") eq $mdet) {
    CommandSet (undef,"$name off") ;
    CommandDeleteReading(undef, "$name myLastPIR");
  }
  
}

# https://forum.fhem.de/index.php/topic,33579.msg260382.html#msg260382
sub UntoggleDimmer($;$)
{
 my ($sender, $actor) = @_;
 my $val = ReadingsVal("$actor", "pct", 0);
 if (Value($sender) eq "toggle") {
                    $val = (Value($actor) eq "off")
                        ? 50 :
                          0}
 elsif ($val == 0) {$val = 100}
 else              {$val = ((int(($val-1)/10)+10)%10)*10} #Val = (int((val-1)/10))*10
 fhem ("set $actor pct $val");
 return;
}

# https://forum.fhem.de/index.php/topic,56784.msg482901.html#msg482901
# Du baust Dir in deiner "99_myUtils" eine Funktion welche den übergebenen Wert für pct anhand eines logarithmischen Verlaufes zurückgibt. Dabei gilt: 0 gibt 0 zurück und 100 gibt 100 zurück. Der Rest liegt nicht auf einer Geraden, sondern auf dem logarithmischen Verlauf. Diesen, von der Funktion zurückgebenen, Wert übergibts Du als pct an den Dimmer.

# set <name> pct {(pct2log(50)}

# SVG_log10($)
sub my_log10($) {
  my ($n) = @_;
  return 0 if( $n <= 0 );
  return log(1+$n)/log(10);

1;
