#Beispiel für Hash-Nutzung in userReadings:
# { my %rets = ("Error"  => "Error","0" => "ist aus","1" => "Standby","2" => "initialisiert","3" => "wird geladen","4" => "wird entladen","5" => "Fehler","6"  => "Leerlauf","7"  => "Leerlauf",);; my $val = ReadingsVal("SolarEdge", "Batt_State", "Error");; my $val = ReadingsVal("SolarEdge", "Batt_State", "Error");; $rets{$val};;}
