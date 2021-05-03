# $Id$
package FHEM::Core::Timer::Helper2;
use strict;
use warnings;
use utf8;
use Carp qw( carp );
use Time::HiRes;

use version; our $VERSION = qv('1.0.0');

use Exporter qw(import);
 
our @EXPORT_OK = qw(setRegIntTimer deleteSingleRegIntTimer resetRegIntTimer deleteAllRegIntTimer renameAllRegIntTimer); 

sub setRegIntTimer {
    my $modifier = shift // carp q[No modifier name]               && return;
    my $time     = shift // carp q[No time specified]              && return;
    my $callback = shift // carp q[No function specified    ]      && return;
    my $hash     = shift // carp q[No hash to reference specified] && return;;
    my $initFlag = shift // 0;

    my $timerName = "$hash->{NAME}:$modifier";
    my $fnHash     = {
        time     => $tim,
        callback => $callback
    };
    if ( defined( $hash->{TIMER}{$timerName} ) ) {
        ::Log3( $hash, 1, "[$hash->{NAME}] possible overwriting of timer $timerName - please delete it first" );
        ::stacktrace();
    }
    else {
        $hash->{TIMER}{$timerName} = $fnHash;
    }

    ::Log3( $hash, 5, "[$hash->{NAME}] setting  Timer: $timerName " . ::FmtDateTime($tim) );
    ::InternalTimer( $tim, $callback, $timerName, $initFlag );
    return $fnHash;
}

sub deleteSingleRegIntTimer {
    my $modifier = shift // carp q[No modifier name]               && return;
    my $hash     = shift // carp q[No hash to reference specified] && return;;

    my $timerName = "$hash->{NAME}:$modifier";
    my $fnHash    = $hash->{TIMER}{$timerName};
    if ( defined($fnHash) ) {
        ::Log3( $hash, 5, "[$hash->{NAME}] removing Timer: $timerName" );
        ::RemoveInternalTimer($timerName);
        delete $hash->{TIMER}{$timerName};
    }
    return;
}

sub resetRegIntTimer {
    my $modifier = shift // carp q[No modifier name]               && return;
    my $time     = shift // carp q[No time specified]              && return;
    my $callback = shift // carp q[No function specified    ]      && return;
    my $hash     = shift // carp q[No hash to reference specified] && return;;
    my $initFlag = shift // 0;

    deleteSingleRegIntTimer( $modifier, $hash );
    return setRegIntTimer ( $modifier, $time, $callback, $hash, $initFlag );
}

sub deleteAllRegIntTimer {
    my $hash     = shift // carp q[No hash to reference specified] && return;;

    for ( keys %{ $hash->{TIMER} } ) {
        my ($oname, $modifier) = split m{:}xms;
        deleteSingleRegIntTimer( $modifier, $hash );
    }
    return;
}

sub renameAllRegIntTimer {
    my $hash     = shift // carp q[No hash to reference specified] && return;;
    my $newName  = shift // carp q[No new name specified] && return;
    my $oldName  = shift // carp q[No old name specified] && return;

    for ( keys %{ $hash->{TIMER} } ) {
        my $tim = $hash->{TIMER}{$_}->{time};
        my $callback = $hash->{TIMER}{$_}->{callback};
        ::RemoveInternalTimer($_);
        delete $hash->{TIMER}{$_};
        my ($oname, $modifier) = split m{:}xms;
        setRegisteredInternalTimer($modifier, $tim, $callback, $hash);
    }
    return;
}

1;

__END__