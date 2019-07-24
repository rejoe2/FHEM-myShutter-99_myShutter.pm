##############################################
# $Id: myAdvanced_Utils.pm 2019-07-24 Beta-User $
#

package main;

use strict;
use warnings;
use POSIX;

sub
myAdvanced_Utils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

######## sendemail für den Emailversand verwenden ############ 
#adopted version from https://wiki.fhem.de/wiki/E-Mail_senden#Raspberry_Pi
sub 
mySendEmail ($$$;$) { 
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
 Log 1, "mySendEmail returned: $ret"; 
}


#found: https://forum.fhem.de/index.php/topic,85958.msg791048.html#msg791048
sub listInternalTimer(;$) {
    my ($p) = @_;
    my %cop;

    foreach my $e (@intAtA)
    {
        my $name = "";
        if (ref($e->{ARG}) eq "HASH")
        {
            if (exists($e->{ARG}{NAME}))
            {
                $name = $e->{ARG}{NAME};
            }
            elsif (exists($e->{ARG}{arg}))
            {
                $name = $e->{ARG}{arg};
            }           
        }
        elsif ((ref($e->{ARG}) eq "REF") && exists(${$e->{ARG}}->{hash}))
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

        if ($p && $ p eq 'f')
        {
            $cop{$function} = $line;
	}
        elsif ($p && $ p eq 't')
        {
            $cop{$time} = $line;
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
   
    foreach my $k (sort keys %cop) {
        $ret .= "$cop{$k}";
        $ret .= '</tr>';
    }

    $ret .= '</table></html>';
    return $ret;
}

1;

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
