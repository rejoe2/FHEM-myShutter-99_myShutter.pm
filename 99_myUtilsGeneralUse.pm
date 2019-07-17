defmod rr_xn_telegramStateMessage notify PresenceBot:msgPeerId:.* {\
my $msg = ReadingsVal($NAME,"msgText","none");;\
my $target = getKeyValue($EVTPART1);;\
my $newState = "absent";;\
fhem "set $target T_last $msg";;\
if ($msg =~ /^\/kurz.*/) {\
  $newState = "absent" if ($msg =~ /^\/kurz.* Bin weg$/ or $msg =~ /^\/kurz 1$/);;\
  $newState = "present" if ($msg =~ /^\/kurz.* Zuhause$/ or $msg =~ /^\/kurz 2$/);;\
}\
if ($msg =~ /^(home|absent|present)$/) {\
  CommandSet(undef,"$target T_status $newState");;\
  my $checktimer = $target."_timerHK";;\
  my $hk_devices = AttrVal($target,"HT_Devices","devStrich0");;\
  if ($newState eq "present") {\
    if ($message =~ /Komme/) {\
      if (ReadingsVal("Heizperiode","state","off") eq "on")  {\
        fhem "delete $checktimer" if defined ($main::defs{$checktimer});;\
        foreach my $setdevice (split (/,/,$hk_devices)) {\
          CommandSet(undef,"$setdevice:FILTER=controlMode!=auto controlMode auto");;\
        }\
        fhem "define $checktimer at +03:00:00 set $hk_devices controlManu 18";;\
      }\
    }\
  } elsif ($newState eq "absent") {\
    CommandSet(undef,"$target absent");;\
    if (ReadingsVal("Heizperiode","state","off") eq "on") {\
      CommandSet(undef,"$hk_devices controlManu 18");;\
    }\
  }\
}


defmod rr_xn_telegramStateMessage notify PresenceBot:msgPeerId:.* {myTBotpresence($NAME,$EVTPART1)}

#V1
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
  if ($msg =~ /^(home|absent|present)$/) {
    CommandSet(undef,"$target T_status $newState");
    my $checktimer = $target."_timerHK";
    my $hk_devices = AttrVal($target,"HT_Devices","devStrich0");
    if ($newState eq "present") {
      if ($message =~ /Komme/) {
        if (ReadingsVal("Heizperiode","state","off") eq "on")  {
          fhem "delete $checktimer" if defined ($main::defs{$checktimer});
          foreach my $setdevice (split (/,/,$hk_devices)) {
            CommandSet(undef,"$setdevice:FILTER=controlMode!=auto controlMode auto");
          }\
          fhem "define $checktimer at +03:00:00 set $hk_devices controlManu 18";
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

#V2 - sleep
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
  if ($msg =~ /^(home|absent|present)$/) {
    CommandSet(undef,"$target T_status $newState");
    my $checktimer = $target."_timerHK";
    my $hk_devices = AttrVal($target,"HT_Devices","devStrich0");
    if ($newState eq "present") {
      if ($message =~ /Komme/) {
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
