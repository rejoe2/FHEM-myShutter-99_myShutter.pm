#Beispiel für Hash-Nutzung in userReadings:
# { my %rets = ("Error"  => "Error","0" => "ist aus","1" => "Standby","2" => "initialisiert","3" => "wird geladen","4" => "wird entladen","5" => "Fehler","6"  => "Leerlauf","7"  => "Leerlauf",);; my $val = ReadingsVal("SolarEdge", "Batt_State", "Error");; my $val = ReadingsVal("SolarEdge", "Batt_State", "Error");; $rets{$val};;}

#https://forum.fhem.de/index.php/topic,115067.msg1093484.html#msg1093484
sub incrementHerdLicht() {
  my $pct = ReadingsNum("KuecheHerdLichtLinks", "pct", "");
  my $schalter = ReadingsVal("SchalterHerdLicht", "state", "");
  #Log 1,"incrementHerdLicht : pct ".$pct." schalter ".$schalter;
  if ($pct < 100 && $schalter ne "1003") {
    fhem("set KuecheHerdLichtLinks dimUp;sleep 0.2;set KuecheHerdLichtRechts dimUp");
    fhem("sleep 0.5;{incrementHerdLicht()}");
  }
}
