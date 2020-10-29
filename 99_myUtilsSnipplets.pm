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

#https://forum.fhem.de/index.php/topic,29438.msg898855.html#msg898855
sub randomtime_with_realtime($;$)
{
  my ($MeH,$MeM,$MeS)=split(':',shift(@_));
  my $MeB=shift(@_);
  my $SGN = ($MeB<=>0);
 
  my $T   = (int($MeH*3600 + $MeM*60 + $MeS + ($MeB*60+$SGN)*rand()))%86400;
  # - rand erzeugt eine floating point Zahl, ist aber bei negativen Zahlen nicht eindeutig definiert,
  #   deshalb verwenden wir lieber -x*rand()
  # - int rundet in Richtung 0
  # - modulo sorgt auch bei neg. Zahlen dafür, dass das Ergebnis [0..86400] ist

  return sprintf("%2.2d:%2.2d:%2.2d",$T/3600,($T/60)%60,$T%60);
} 


https://forum.fhem.de/index.php/topic,76659.msg685644.html#msg685644
sub isInTime($) {

    my $dfi = shift;

    $dfi =~ s/{([^\x7d]*)}/$cmdFromAnalyze=$1; eval $1/ge; # Forum #69787
    my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
    my $dhms = sprintf("%s\@%02d:%02d:%02d", $wday, $hour, $min, $sec);
    foreach my $ft (split(" ", $dfi)) {
        my ($from, $to) = split("-", $ft);
        if(defined($from) && defined($to)) {
            $from = "$wday\@$from" if(index($from,"@") < 0);
            $to   = "$wday\@$to"   if(index($to,  "@") < 0);
            return 1 if($from le $dhms && $dhms le $to);
        }
    }
   
    return 0;
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
}

1;
