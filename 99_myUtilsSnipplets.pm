###############################################
#weekprofile für Homematic- Templates (über HMinfo-Heizungstemplates) nutzen
#https://forum.fhem.de/index.php/topic,70494.0.html
#preparation
#define KG.HZ.Profile weekprofile
#define test1 weekprofile OG.SZ.Heizung_Clima

#############################
###  Thermostat kopieren  ###
#############################

#https://forum.fhem.de/index.php/topic,9900.msg62719.html#msg62719
sub TimeOffset {
  use Time::Local qw(timelocal);
  my $PtimeOrg = shift // "";
  my $Poffset  = shift // 0;

  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;

  $PtimeOrg = $hour.":".$min if $PtimeOrg !~ /[0-2][0-9]:[0-5][0-9]/ or substr($PtimeOrg,0,2) >= 24;

  my $TimeP     =  timelocal(0, substr($PtimeOrg,3,2), substr($PtimeOrg,0,2), $mday, $month, $year); 

  return strftime('%H:%M:%S', localtime($TimeP + $Poffset * 60));

}

sub kopieren {
    #Templatenamen aus dem Thermostat holen
    my $Name = AttrVal(InternalVal("test1","DEF",0),"tempListTmpl",1);
    #Profil aus dem Thermostat
    my $daten = fhem("get test1 profile_data master");
   
    #Profil zum Editor hinzufügen
    fhem("set KG.HZ.Profile profile_data ".$Name." ".$daten);
}

#code für userReaddings
# Das UserReading gehört zun Device "weekplan", aus dem Du über $name die Profildaten holst.
M_Info {
  my $confFile = "./FHEM/wochenplan-tempList.cfg";
  my $entit = fhem("get $name profile_names");
  my $ret="\#               bis   Soll bis   Soll bis   Soll bis   Soll\n";
  my @lines = split /,/, $entit;
  my @D = ("Sat","Sun","Mon","Tue","Wed","Thu","Fri");
  my ($text,$tmp)="";
  foreach my $Raum (@lines)  {
      $tmp = fhem("get $name profile_data $Raum");
      $text = decode_json($tmp);
      $ret.="entities:".$Raum."\n";
      for my $i (0..6) {
          $ret.="R_".$i."_tempList".$D[$i].">";
          for my $j (0..7) {
              if (defined $text->{$D[$i]}{'time'}[$j]) {
              $ret.=$text->{$D[$i]}{'time'}[$j]." ".$text->{$D[$i]}{'temp'}[$j]." ";
              } }
      $ret.="\n";
      }
  }
  open IMGFILE, '>'.$confFile;
  print IMGFILE $ret;
  close IMGFILE;
  return "HMinfo configTempFile written to $confFile"   
}

##################################################################

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

#own code, see https://forum.fhem.de/index.php/topic,115722.msg1100046.html#msg1100046
sub myDimUp_PctToMax {
  my $name   = shift // return;
  my $maxval = shift // 100;
  my $remote = shift;
  my $remotestop = shift // '1003';
 
  my $pct = ReadingsNum($name, 'pct', 0) +3;
  my $schalter = ReadingsVal($remote, "state", "");
  if ($pct < 103 && $schalter ne $remotestop) {
    fhem("set $name pct $pct");
    fhem("sleep 0.5;{myDimUp_PctToMax($name, 100, $remote, $remotestop)}");
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
