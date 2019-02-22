98_autocreate Zeile 495

{ NAME      => "MYSENSORS",
      matchList => ["cu.PL2303-0000(.*)", "cu.usbmodem(.*)",
                    "ttyUSB(.+)", "ttyACM(.+)", "serial(.+)", "ttyAMA(.+)" ],
      DeviceName=> "DEVICE\@115200",
      request   => pack("H*", "01030020dc06"),   # send heartbeat request
      response  => "^\x06.*",                    # heartbeat response
      define    => "MYSENSORS_PARAM MYSENSORS DEVICE\@115200", },

heartbeat request: !TSF:MSG:SEND,0-0-0-0,s=255,c=3,t=18,pt=0,l=1,sg=0,ft=0,st=NACK:M

sub parseMsg($) {
14	  my $txt = shift;
15	  if ($txt =~ /^(\d+);(\d+);(\d+);(\d+);(\d+);(.*)$/) {
16	    return { radioId => $1,
17	             childId => $2,
18	             cmd     => $3,
19	             ack     => $4,
20	             subType => $5,
21	             payload => $6 };

sendClientMessage($hash, cmd => C_INTERNAL, ack => 0, subType => I_HEARTBEAT_REQUEST);

{ NAME      => "SIGNALDuino",
      matchList => ["cu.PL2303-0000(.*)", "cu.usbmodem(.*)",
                    "ttyUSB(.+)", "ttyACM(.+)", "serial(.+)", "ttyAMA(.+)" ],
      DeviceName=> "DEVICE\@115200",
      request   => pack("H*", "01030020dc06"),   # Version? Init-string?
      response  => "^\x06.*",                    # heartbeat response
      define    => "SIGNALDUINO_PARAM SIGNALduino DEVICE\@57600", },

