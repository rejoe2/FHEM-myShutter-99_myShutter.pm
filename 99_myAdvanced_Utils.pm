##############################################
# $Id: myAdvanced_Utils.pm 2019-05-15 Beta-User $
#

package main;

use strict;
use warnings;

sub
myAdvanced_Utils_Initialize
{
  my $hash = shift;
}

# Enter you functions below _this_ line.

sub
myHHMMSS2sec
{
  my ($h,$m,$s) = split(":", shift);
  $m = 0 if(!$m);
  $s = 0 if(!$s);
  my $seconds = 3600*$h+60*$m+$s;
  return $seconds;
}

######## sendEmail für den Emailversand verwenden ############ 
#adopted version from https://wiki.fhem.de/wiki/E-Mail_senden#Raspberry_Pi
sub 
mySendEmail { 
 my ($rcpt, $subject, $text, $attach) = @_; 
 my $sender = getKeyValue("myEmailAddress"); # use {setKeyValue("myEmailAddress",'absender@account.de')} once in commandline to store the parameter 
 my $konto = getKeyValue("myEmailAccount"); # like before: {setKeyValue("myEmailAccount",'absender@account.de')} 
 my $passwrd = getKeyValue("myEmailPasswrd"); # like before: {setKeyValue("myEmailPasswrd","passwrd")}
 my $provider = getKeyValue("myEmailServer"); # like before: {setKeyValue("myEmailServer",'smtp.provider.de:587')}
 Log 1, "mySendEmail RCP: $rcpt, Subject: $subject, Text: $text";
 Log 1, "mySendEmail Anhang: $attach" if defined $attach;
 my $ret ="";
 if ($attach) { 
   $ret .= qx(sendemail -f $sender -t $rcpt -u $subject -m $text -a $attach -s $provider -xu $konto -xp $passwrd -o tls=auto -o message-charset=utf-8);
 } else {
   $ret .= qx(sendemail -f $sender -t $rcpt -u $subject -m $text -s $provider -xu $konto -xp $passwrd -o tls=auto -o message-charset=utf-8);
 }
 $ret =~ s,[\r\n]*,,g;    # remove CR from return-string 
 Log3( "mySendEmail", 3, "mySendEmail returned: $ret"); 
}


#found: https://forum.fhem.de/index.php/topic,85958.msg791048.html#msg791048
sub listInternalTimer {
    my $p = shift;
    my %cop;

    for my $e (@intAtA)
    {
        my $name = "";
        if (ref($e->{ARG}) eq "HASH") {
            if (exists($e->{ARG}{NAME}))
            {
                $name = $e->{ARG}{NAME};
            }
            elsif (exists($e->{ARG}{arg}))
            {
                $name = $e->{ARG}{arg};
            }           
        }
        elsif (ref($e->{ARG}) eq "REF" && exists(${$e->{ARG}}->{hash}))
        {
            $name = ${$e->{ARG}}->{hash}{NAME};
        }
        elsif (ref($e->{ARG}) ne "REF")
        {
            $name = $e->{ARG};
        }
        my $time = strftime('%d.%m.%Y %H:%M:%S', localtime($e->{TRIGGERTIME}));
        my $function = sprintf("%-25s %-25s", $name, $e->{FN});
        my $line = "<td>".$e->{atNr}."</td><td>".$time."</td><td>".$function."</td>";

        if ('f' eq $p)
        {
            $cop{$function." ".$e->{atNr}} = $line;
	    }
        elsif ('t' eq $p)
        {
            $cop{$time." ".$e->{atNr}} = $line;
	    }
        else
        {
            $cop{$name." ".$e->{atNr}} = $line;
	    }
    }

    my $ret = '<html><table width=50%>';
    $ret .= "<td><b>InternalTimer List</b></td>";
    $ret .= '</tr></tr>';
    $ret .= "<td><b>Number</b></td>";
    $ret .= "<td><b>Date/Time</b></td>";
    $ret .= "<td><b>Function</b></td>";
    $ret .= '</tr>';
   
    for my $k (sort keys %cop) {
        $ret .= "$cop{$k}";
        $ret .= '</tr>';
    }

    $ret .= '</table></html>';
    return $ret;
}

sub identifyMyBestGW {
  my $name = shift;
  my $maxReadingsAge = shift // AttrVal($name,"maxReadingsAge",600);
  my $hash = $defs{NAME};
  
  my @rssis = grep { $_ =~ /.*_RSSI/ } sort keys %{ $hash->{READINGS} }; 
  my $mintstamp = time() - $maxReadingsAge;
  my $bestGW = "unknown";
  my $bestGWold = ReadingsVal($name,"bestRecentGW","unknownGW");
  my $bestRSSI = -1000;
  my $currentRSSI = 0;
  for (@rssis) {
    if (ReadingsTimeStamp($name,$_,100) > $mintstamp) {
      $currentRSSI = ReadingsVal($name,$_,-1100);
      if ($currentRSSI > $bestRSSI) {
        $bestRSSI = $currentRSSI ;
        $bestGW = $_;
      }
      
    }
  }
  $bestGW =~ s/_.*//g;
  return "$bestGW" ne "$bestGWold" ? {bestRecentGW=>$bestGW} : undef;
}

sub myCalendar2Holiday {
  my $calname    = shift // return;
  my $regexp     = shift // return;
  my $targetname = shift // $calname;
  my $field      = shift // "summary";
  my $limit      = shift // 10;
  my $yearEndRe  = shift;
 
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) =  localtime(gettimeofday());
  my $getstring = $calname . ' events format:custom="4 $T1 $T2 $S $D" timeFormat:"%m-%d" limit:count=' . $limit." filter:field($field)=~\"$regexp\"";
  my @holidaysraw = split( /\n/, CommandGet( undef, "$getstring" ));
 
  my @holidays;
  my @singledays;
  for my $holiday (@holidaysraw) {
    my @tokens = split (" ",$holiday);
    #my @elements = split( " ", $holiday ); 
    my $duration = pop @tokens;
    
    my $severalDays = $duration =~ m,[0-9]+h, ? 0 : 1;
    
    $holiday = join(' ', @tokens);
    if (!$severalDays) {
      $tokens[0] = 1;
      splice @tokens, 2, 1;
      $holiday = join(' ', @tokens);
      push (@singledays, $holiday);
    } elsif ( !$yearEndRe || $holiday !~ m/$yearEndRe/) {
      push (@holidays, $holiday);
    } else { 
      $holiday = "4 $tokens[1] 12-31 $tokens[3]";
      push (@holidays,$holiday) if $month > 9;
      $holiday = "4 01-01 $tokens[2] $tokens[3]";
      unshift (@holidays,$holiday);
    }
  }
  push @holidays, @singledays;
  unshift (@holidays, "# get $getstring");
  my $today = strftime "%d.%m.%y, %H:%M", localtime(time);;\
  unshift (@holidays, "# Created by myCalendar2Holiday on $today");
  FileWrite("./FHEM/${targetname}.holiday",@holidays);
}
1;

__END__

=pod
=begin html

<a name="myAdvanced_Utils"></a>
<h3>myAdvanced_Utils</h3>
<ul>
  <b>listInternalTimer(;$)</b><br>
  <ul>
    <code>{ listInternalTimer("t") }</code>  -> shows InternalTimers sorted by time, earlier will be on top.
    <code>{ listInternalTimer("f") }</code>  -> sorts by function name.
    Without or all other arguments will show an unsorted list.
  </ul>
  <ul>
   
  </ul>
</ul>
=end html
=cut
