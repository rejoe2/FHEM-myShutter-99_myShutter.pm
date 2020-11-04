##############################################
# $Id: myUtils_MiLight.pm 2020-11-04 Beta-User $
#

package main;

use strict;
use warnings;

sub
myUtils_MiLight_Initialize
{
  my $hash = shift;
}

# Enter you functions below _this_ line.

sub milight_toggle_indirect {
  my $name = shift // return;
  my $Target_Devices = AttrVal($name,"Target_Device","devStrich0");
  my $dimmLevel;
  my $hash;
  for my $setdevice (split (/,/,$Target_Devices)) {
    $hash = $defs{$setdevice};
    if(lc(ReadingsVal($setdevice,"state","off")) eq "off") {
      CommandSet(undef, "$setdevice on");
      readingsSingleUpdate($hash,"myLastShort","1", 0);
      AnalyzeCommandChain(undef, "sleep 1; set $setdevice brightness 220");
    } elsif (ReadingsAge($setdevice,"myLastShort","100") < 3) {
       my $lastToggle = ReadingsNum($setdevice, "myLastShort","0");
       if ($lastToggle == 1) {
         readingsSingleUpdate($hash,"myLastShort","2",0);
         $dimmLevel = 110;
       } else {
         $dimmLevel = 45;
       }
       CommandSet(undef, "$setdevice brightness $dimmLevel");
    } else {
       readingsSingleUpdate($hash,"myLastShort","0",0);
       CommandSet(undef, "$setdevice off");
    }
  }
  return;
}

sub milight_dimm_indirect {
  my $name  = shift;
  my $event = shift // return;
  my $Target_Devices = AttrVal($name,"Target_Device","devStrich0");
  for my $setdevice (split (/,/,$Target_Devices)) {
    if ($event =~ m/LongRelease/) {
      CommandDeleteReading(undef,"-q $setdevice myLastdimmLevel");
    } else {
      milight_dimm($setdevice);
    }
  }
  return;
}

sub milight_dimm {
  my $Target_Device = shift // return;
  my $dimmDir = ReadingsVal($Target_Device,"myDimmDir","up");
  my $dimmLevel = ReadingsVal($Target_Device,"myLastdimmLevel",ReadingsNum($Target_Device,"brightness","255"));
  if ($dimmDir ne "up") { 
    if ($dimmLevel < 4) { 
      readingsSingleUpdate($defs{$Target_Device}, "myDimmDir", "up", 0);
    } else {
      $dimmLevel -= $dimmLevel < 30 ? 3 : $dimmLevel < 70 ? 5 : $dimmLevel < 120 ? 7 : 15;
    }
  } else {
    if ($dimmLevel > 244) {
      readingsSingleUpdate($defs{$Target_Device}, "myDimmDir", "down", 0);
    } else {
      $dimmLevel += $dimmLevel < 30 ?  3 : $dimmLevel < 70 ? 5 : $dimmLevel < 120 ? 7 : 15;
    }
  }
  CommandSet(undef, "$Target_Device brightness $dimmLevel");
  readingsSingleUpdate($defs{$Target_Device}, "myLastdimmLevel",$dimmLevel, 0);
}

sub milight_FUT_to_RGBW {
  my $name  = shift;
  my $Event = shift // return;
  my %ret; 
  if(length($Event) < 10000 && $Event =~ m/^\s*[{[].*[}\]]\s*$/s) {
        %ret = json2nameValue($Event);
  }
  my @parms; 
  if(!keys %ret) {
    $Event =~ s/://g;
    $Event = "state ".lc($Event) if $Event =~ m/OFF|ON/i;
    @parms = split  m{\s+}xms, $Event;     
    $ret{$parms[0]} = $parms[1];
  }
  for my $k (keys %ret) {
    my $string = qq($k $ret{$k});
  
    if($string =~ /OFF|ON/) {
      my $command = lc ($Event);
      CommandSet(undef, "$name $command");
    } elsif ($string =~ /brightness|hue/)  {
      $string =~ s/brightness/bri/g if (InternalVal($name,"TYPE","MQTT2_DEVICE") eq "HUEDevice"); 
      CommandSet(undef, "$name $string");
    } elsif ($string =~ /command set_white/)  {
      CommandSet(undef, "$name command Weiss");
    } else {

    }  
  }
}

sub milight_FUT_to_HUE {
  my $names  = shift;
  my $Event = shift // return;
  my $whitecol = shift // 'FFFFFF';
  my %ret; 
  if(length($Event) < 10000 && $Event =~ m/^\s*[{[].*[}\]]\s*$/s) {
        %ret = json2nameValue($Event);
  }
  my @parms; 
  if(!keys %ret) {
    $Event =~ s/://g;
    $Event = "state ".lc($Event) if $Event =~ m/OFF|ON/i;
    @parms = split  m{\s+}xms, $Event;     
    $ret{$parms[0]} = $parms[1];
  }
  
  my @devices = split m{\s+}xms, $names; 
  for my $name (@devices) {

    for my $k (keys %ret) {

      my $string = qq($k $ret{$k});
  
      if($string =~ m/OFF|ON/i) {
        my $command = $ret{$k};
        CommandSet(undef, "$name $command");
      }
  
      if ($string =~ /brightness/)  {
        $string =~ s/brightness/bri/g if (InternalVal($name,"TYPE","MQTT2_DEVICE") eq "HUEDevice"); 
        CommandSet(undef, "$name $string");
      }

      if ($string =~ /hue/)  {
        if (InternalVal($name,"TYPE","MQTT2_DEVICE") eq "HUEDevice") { 
          my $rgb = Color::hsv2hex($ret{$k},ReadingsVal($name,"sat",100)/100,sprintf("%.2f",ReadingsVal($name,"bri",255)/255));
          CommandSet(undef, "$name rgb $rgb");
        } else {
          CommandSet(undef, "$name $Event");
        }
      }
  
      if ($string =~ /saturation/)  {
        if (InternalVal($name,"TYPE","MQTT2_DEVICE") eq "HUEDevice") { 
          my $sat = int($ret{$k}*2.54);
          CommandSet(undef, "$name sat $sat");
        } else {
          CommandSet(undef, "$name $Event");
        }
      }
  
      if ($string =~ /command set_white/)  {
        if (InternalVal($name,"TYPE","MQTT2_DEVICE") eq "HUEDevice") {
          CommandSet(undef, "$name rgb $whitecol");
        } else { 
          CommandSet(undef, "$name command Weiss");
        }
      }

    } #end keys loop
  } #end devices loop
  return;
}

sub milight_to_MPD {
  my $name  = shift;
  my $event = shift // return;
  return {"CommandSet" => "$name not present, no command issued" } if ReadingsVal($name,"presence","absent") eq "absent";
  
  my $rets = json2nameValue($event);
  
  if (defined $rets->{state} && $rets->{state} =~ m/on/i) { 
    if (ReadingsVal($name,"state","play") =~ /pause|stop/) {
      CommandSet(undef, "$name play");      
      return { "CommandSet" => "$name play" };
    } else { 
      return { "CommandSet" => "$name already playing" };
    }
  }
  if (defined $rets->{state} && $rets->{state} =~ m/off/i) { 
    my $command = (ReadingsVal($name,"state","play") eq "pause" ) ? "stop" : "pause";
    CommandSet(undef, "$name $command");
    return { "CommandSet" => "$name $command" };
  }
  if (defined $rets->{brightness}) {
    my $level = int (round ($rets->{brightness}/2.55,0));
    CommandSet(undef, "$name volume $level");
    return { "CommandSet" => "$name volume $level" };
  }
  if (defined $rets->{command}) {
    if ($rets->{command} eq "mode_speed_up") {
      CommandSet(undef, "$name previous") ;
      return { "CommandSet" => "$name previous" } ;
    }
    if  ($rets->{command} eq "mode_speed_down") {
      CommandSet(undef, "$name next");
      return { "CommandSet" => "$name next" };
    }
    else {
      return { "CommandSet" => "$rets->{command} not assigned" };
    }
  }
  if (defined $rets->{mode}) {
    my $gainmode = CommandGet(undef, "$name mpdCMD replay_gain_status") =~ /album/ ? "auto" : "album"; 

    CommandSet(undef, "$name mpdCMD replay_gain_mode $gainmode");
    return { "CommandSet" => "$name mpdCMD replay_gain_mode $gainmode" };
  }
  if (defined $rets->{bulb_mode} && $rets->{bulb_mode} =~ m/white/) {
    my $consumer = CommandGet(undef, "$name mpdCMD status") =~ /consume. 0/ ? "1" : "0"; 
    CommandSet(undef, "$name mpdCMD consume $consumer");
    return { "CommandSet" => "$name mpdCMD consume $consumer" };
  }
  return;
}

sub milight_to_shutter {
  #foreach my $setdevice (split (/ /,$Target_Devices)) {
  my $name  = shift;
  my $event = shift // return;
  my $type = InternalVal($name,"TYPE","MQTT2_DEVICE"); 
  my $moving = ReadingsVal($name,"motor","stop") =~ /stop/ ? 0 : 1;
  $moving = 1 if (ReadingsNum($name,"power",0) > 1 && $type eq "ZWave");
  
  my $com = lc($event);
  my $now = gettimeofday;
  if (!$moving && $event =~ m/ON|OFF/) {
    if ($now - ReadingsVal($name, "myLastRCOnOff",$now) < 5) {
      CommandSetReading(undef,"$name myLastRCOnOff $now");
      return CommandSet(undef,"$name $com");

    } else {
      return CommandSetReading(undef,"$name myLastRCOnOff $now");
    } 
  } 
  if ($event =~ m/ON|OFF/) { 
    CommandSetReading(undef,"$name myLastRCOnOff $now");
    return CommandSet(undef,"$name stop");
  }
  if ($event =~ /brightness/) {
    my ($reading,$value) = split (/ /,$event);
    my $level = int (round ($value/2,55));
    $com = $type eq "ZWave" ? "dim" : "pct"; 
    $level = 99 if ($level == 100 && $type eq "ZWave");
    return CommandSet(undef, "$name $com $level");
  } 
  if ($event =~ /saturation/) {
    my ($reading,$value) = split (/ /,$event);
    my $slatname = $name;
    my $slatlevel = 100 - $value;
    $com = $type eq "ZWave" ? "dim" : "slats"; 
    $slatlevel = 99 if ($slatlevel == 100 && $type eq "ZWave");
    my ($def,$defnr) = split(" ", InternalVal($name,"DEF",$name));
    $defnr++;
    my @slatnames = devspec2array("DEF=$def".'.'.$defnr);
    $slatname = shift @slatnames;
    
    return CommandSet(undef, "$slatname $com $slatlevel");

  } 
  if ($event =~ /color_temp/) {
    my ($reading,$value) = split (/ /,$event);
    my $slatname = $name;
    my $slatlevel = 100 - ($value/(370-153))*100;
    $com = $type eq "ZWave" ? "dim" : "slats"; 
    $slatlevel = 99 if ($slatlevel == 100 && $type eq "ZWave");
    my ($def,$defnr) = split(" ", InternalVal($name,"DEF",$name));
    $defnr++;
    my @slatnames = devspec2array("DEF=$def".'.'.$defnr);
    $slatname = shift @slatnames;
    
    return CommandSet(undef, "$slatname $com $slatlevel");
  }
  return;
}

sub milight_to_shutter2 {
  my $name  = shift;
  my $event = shift // return;
  my $type = InternalVal($name,"TYPE","MQTT2_DEVICE"); 
  my $moving = ReadingsVal($name,"motor","stop") =~ /stop/ ? 0 : 1;
  $moving = 1 if ReadingsNum($name,"power",0) > 1 && $type eq "ZWave";

  my $rets = json2nameValue($event);
  
  my $com = "off";
  my $now = gettimeofday;
  if (!$moving && defined $rets->{state} && $rets->{state} =~ m/on|off/i) {
    if ($now - ReadingsVal($name, "myLastRCOnOff",$now) < 5) {
      CommandSetReading(undef,"$name myLastRCOnOff $now");
      my $level = $rets->{state} =~ m/off/i ? 0 : 100;
      $com = $type eq "ZWave" ? "dim" : "pct"; 
      $level = 99 if ($level == 100 && $type eq "ZWave");
      CommandSet(undef, "$name $com $level");
      return { "CommandSet" => "$name $com $level" };
    } 
    return CommandSetReading(undef,"$name myLastRCOnOff $now"); 
  } 
  if (defined $rets->{state} && $rets->{state} =~ m/on|off/i) { 
    CommandSetReading(undef,"$name myLastRCOnOff $now");
    CommandSet(undef,"$name stop");
    return { "CommandSet" => "$name stop" };
  }
  if (defined $rets->{brightness}) {
    my $level = int (round ($rets->{brightness}/2.55,0));
    $com = $type eq "ZWave" ? "dim" : "pct"; 
    $level = 99 if ($level == 100 && $type eq "ZWave");
    CommandSet(undef, "$name $com $level");
    return { "CommandSet" => "$name $com $level" };
  } 
  if (defined $rets->{saturation}) {
    my $slatname = $name;
    my $slatlevel = 100 - $rets->{saturation};
    $com = $type eq "ZWave" ? "dim" : "slats"; 
    $slatlevel = 99 if ($slatlevel == 100 && $type eq "ZWave");
    my ($def,$defnr) = split(" ", InternalVal($name,"DEF",$name));
    $defnr++;
    my @slatnames = devspec2array("DEF=$def".'.'.$defnr);
    $slatname = shift @slatnames;
    
    CommandSet(undef, "$slatname $com $slatlevel");
    return { "CommandSet" => "$slatname $com $slatlevel" };

  } 
  if (defined $rets->{color_temp}) {
    my $slatname = $name;
    my $slatlevel = 100 - ($rets->{color_temp}/(370-153))*100;
    $com = $type eq "ZWave" ? "dim" : "slats"; 
    $slatlevel = 99 if ($slatlevel == 100 && $type eq "ZWave");
    my ($def,$defnr) = split(" ", InternalVal($name,"DEF",$name));
    $defnr++;
    my @slatnames = devspec2array("DEF=$def".'.'.$defnr);
    $slatname = shift @slatnames;
    CommandSet(undef, "$slatname $com $slatlevel");
    return { "CommandSet" => "$slatname $com $slatlevel" };
  }
  return;
}

sub milight_Deckenlichter {
  my $Event = shift // return;
  if ($Event =~ /mode_speed_up/){
    return CommandSet(undef, "Licht_WoZi_Hinten_Aussen toggle");
  } 
  if ($Event =~ /mode_speed_down/){
    return CommandSet(undef, "Licht_WoZi_Vorn_Aussen toggle");
  } 
  if ($Event =~ /command: set_white/){
    return CommandSet(undef, "Licht_WoZi_Vorn_Mitte toggle");
  } 
  if ($Event =~ /mode: [0-8]/){
    return CommandSet(undef, "Licht_WoZi_Hinten_Mitte toggle");
  } else {
    my @ondevs = devspec2array("Licht_WoZi_(Hinten|Vorn)_(Aussen|Mitte):FILTER=state=on");
    if (@ondevs) {
      CommandSet(undef, "Licht_WoZi_(Hinten|Vorn)_(Aussen|Mitte):FILTER=state=on off") if ($Event eq "OFF");
    } else {
      CommandSet(undef, "Licht_WoZi_Vorn_Aussen on");
    } 
  }
  return;
}

sub milight_4_Lights_matrix {
  my $event = shift;
  my $devA  = shift // return;
  my $devB  = shift // $devA;
  my $devC  = shift // $devB;
  my $devD  = shift // $devC;
  
  my $rets = json2nameValue($event);
  
  if (defined $rets->{command}) {
    if ($rets->{command} eq "mode_speed_up") {
	  CommandSet(undef, "$devC toggle") ;
	  return { "CommandSet" => "$devC toggle" } ;
	}
    if  ($rets->{command} eq "mode_speed_down") {
	  CommandSet(undef, "$devA toggle");
	  return { "CommandSet" => "$devA toggle" };
    }
	if ($rets->{command} eq "set_white") {
	  CommandSet(undef, "$devB toggle");
	  return { "CommandSet" => "$devB toggle" };
	}
  } 
  if (defined $rets->{mode}) {
    CommandSet(undef, "$devD toggle");
    return { "CommandSet" => "$devD toggle" };
  } else {
    my @ondevs = devspec2array("($devA|$devB|$devC|$devD):FILTER=state=on");
    if (@ondevs) {
      CommandSet(undef, "($devA|$devB|$devC|$devD):FILTER=state=on off") if (defined $rets->{state} && $rets->{state} eq "OFF");
	  defined $rets->{state} && $rets->{state} eq "OFF" ? return { "CommandSet" => "($devA|$devB|$devC|$devD):FILTER=state=on off" } : return { "CommandSet" => "nothing to do, all already off" };
    } else {
      CommandSet(undef, "$devA on");
	  return { "CommandSet" => "$devA on" };
    } 
  }
  return;
}

1;


=pod
=begin html

<a name="myUtils_MiLight"></a>
<h3>myUtils_MiLight</h3>
<ul>
  <b>Routines to handle remote control signals in MiLight context</b><br> 
  All MiLight hardware (bulbs and remotes) are represented by MQTT2_DEVICE using a esp8266_milight_hub as described here: https://github.com/sidoh/esp8266_milight_hub.<br>
  This pieces of code offer options to build links between MiLight@MQTT2_DEVICE and "other" FHEM devices (e.g. HUE bulbs, shutter devices, Homematic remotes) and can also be used to built an indirect bridge between V6 remotes and V5 bulbs.
</ul>
<ul>
  <b>Routines to use MiLight remotes as input device</b><br>
  NOTE: As one has to press the "on" button to activate a specific layer of the remote, often the first "on" command received will be ignored. You have to press the key twice within a few seconds in these cases. This is especially the case, when controlling other devices than lights to avoid unexpected or unintended behaviour (like starting a music player when only reduction of volume is intended as first step).  <br><br>
  All remote keys are configured as seperate MQTT2_DEVICE instances like this one:<br>
  <code>defmod MiLight_RC1_0 MQTT2_DEVICE milight_0xABCD_0<br>
  attr MiLight_RC1_0 readingList milight/updates/0xABCD/fut089/0:.* { json2nameValue($EVENT) }\<br>
  milight/states/0xABCD/fut089/0:.* {}</code><br><br>
  The Perl routines typically are called from within a notify listining to just one of the MQTT2_DEVICEs, not all of the buttons might be used:<br>
  <code>defmod n_MiLight_RC1_1 notify MiLight_RC1_1:(ON|OFF|(brightness|command|bulb_mode|hue|mode|saturation).*) {milight_to_MPD("myHueDevice",$EVENT)}</code><br>
  <code>defmod n_MiLight_RC1_0 notify MiLight_RC1_0:(ON|OFF|(brightness|command|bulb_mode|mode).*) {milight_to_MPD("myMPD",$EVENT)}</code><br>
  Typically the device to switch and the $EVENT are handed over to the routines, in case it's just one parameter, it's $EVENT only.<br><br>
<ul>
  <b>milight_FUT_to_RGBW($$)</b><br>
  Allows indirect control of 
  <li>other MiLight devices using a different protocol or </li> 
  <li>other light devices. Especially HUEDevice should work also for brightness and hue commands.</li> 
</ul><br>
<ul>
  <b>milight_to_shutter($$)</b><br>
  Allows control of shutter devices. Tested with following devices:<br>
  <li>HM-LC-Bl1PBU-FM as CUL_HM, shutters only</li> 
  <li>ZWave actor FGR-223 in venetian mode - lamella position can be controlled via saturation slider</li> <br>
</ul><br>
<ul>
  <b>milight_Deckenlichter ($)</b><br>
  Allows control of a group of 4 channels of on/off devices.<br>
</ul><br>
<ul>
  <b>milight_to_MPD($$)</b><br>
  Allows control of a MusicPlayerDeamon - basics like play, pause, stop and volume.<br>
  Additionally toggle two replay gain modes and "consumer" setting.
</ul>
<ul>
  <br><br>
  <b>Routines to use other remote types to control MiLight bulbs</b><br>
  <code>milight_dimm_indirect($$)</code> and <code>milight_toggle_indirect($)</code> are intended for the use in notify code to derive commands to one or multiple bulbs. Parameter typically is $NAME or $EVTPART0.<br>
  To get the logical link, e.g. from a button to a specific bulb, a userattr value is used, multiple bulbs have to be comma-separated.<br>
</ul>
<ul>
 Examples: 
</ul>
<ul>
  <code>attr Schalter_Spuele_Btn_04 userattr Target_Device<br>attr Schalter_Spuele_Btn_04 Target_Device Licht_Essen</code><br>
  This way, one notify can be used to derive actions on various devices
</ul>
<ul>
  <code>defmod MiLight_dimm notify Schalter_Spuele_Btn_0[124]:Long..*[\d]+_[\d]+.\(to.VCCU\) {milight_dimm_indirect($NAME,$EVENT)}<br>defmod MiLight_toggle notify Schalter_Spuele_Btn_0[124]:Short.[\d]+_[\d]+.\(to.VCCU\) {milight_toggle_indirect($NAME)}</code><br>
</ul>
</ul>
<ul>
<pre>defmod MiLight_RC_WZ MQTT2_DEVICE milight_0x5D47_0
attr MiLight_RC_WZ DbLogExclude .*
attr MiLight_RC_WZ IODev MQTT2_FHEM_Server
attr MiLight_RC_WZ group Remote
attr MiLight_RC_WZ readingList milight/updates/0x5D47/fut089/0:.* { milight_to_MPD('myMPD',$EVENT) }\
milight/updates/0x5D47/fut089/1:.* { milight_FUT_to_RGBW('Licht_Stehlampe_links',$EVENT) }\
milight/updates/0x5D47/fut089/2:.* { milight_FUT_to_RGBW('Licht_Stehlampe_rechts',$EVENT) }\
milight/updates/0x5D47/fut089/3:.* { milight_4_Lights_matrix($EVENT, 'Licht_WoZi_Vorn_Aussen', 'Licht_WoZi_Vorn_Mitte', 'Licht_WoZi_Hinten_Aussen', 'Licht_WoZi_Hinten_Mitte') }\
milight/updates/0x5D47/fut089/4:.* { milight_to_shutter2('Jalousie_WZ',$EVENT) }\
milight/updates/0x5D47/fut089/5:.* { milight_to_shutter2('Rollladen_WZ_SSO',$EVENT) }\
milight/updates/0x5D47/fut089/6:.* { milight_to_shutter2('Rollladen_WZ_SSW',$EVENT) }\
milight/updates/0x5D47/fut089/7:.* {}\
milight/updates/0x5D47/fut089/8:.* {}\
milight/states/0x5D47/fut089/[0-8]:.* {}
</pre>
</ul>
=end html
=cut
