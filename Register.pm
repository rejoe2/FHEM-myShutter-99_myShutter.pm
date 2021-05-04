# $Id$
package FHEM::Core::Timer::Register;
use strict;
use warnings;
use utf8;
use Carp qw( carp );
use Scalar::Util qw( weaken );

use version; our $VERSION = qv('1.0.0');

use Exporter qw(import);

our @EXPORT_OK = qw(setRegIntTimer deleteSingleRegIntTimer resetRegIntTimer deleteAllRegIntTimer);

sub setRegIntTimer {
    my $modifier = shift // carp q[No modifier name]            && return;
    my $time     = shift // carp q[No time specified]           && return;
    my $callback = shift // carp q[No function specified]       && return;
    my $hash     = shift // carp q[No hash reference specified] && return;
    my $initFlag = shift // 0;

    my $timerName = "$hash->{NAME}_$modifier";
    my $fnHash     = {
        HASH     => $hash,
        NAME     => $timerName,
        MODIFIER => $modifier
    };
    weaken($fnHash->{HASH});
    if ( defined( $hash->{TIMER}{$timerName} ) ) {
        ::Log3( $hash, 1, "[$hash->{NAME}] possible overwriting of timer $timerName - please delete it first" );
        ::stacktrace();
    }
    else {
        $hash->{TIMER}{$timerName} = $fnHash;
    }

    ::Log3( $hash, 5, "[$hash->{NAME}] setting  Timer: $timerName " . ::FmtDateTime($tim) );
    ::InternalTimer( $tim, $callback, $fnHash, $initFlag );
    return $fnHash;
}

sub deleteSingleRegIntTimer {
    my $modifier = shift // carp q[No modifier name]            && return;
    my $hash     = shift // carp q[No hash reference specified] && return;

    my $timerName = "$hash->{NAME}_$modifier";
    my $fnHash    = $hash->{TIMER}{$timerName};
    if ( defined($fnHash) ) {
        ::Log3( $hash, 5, "[$hash->{NAME}] removing Timer: $timerName" );
        ::RemoveInternalTimer($fnHash);
        delete $hash->{TIMER}{$timerName};
    }
    return;
}

sub resetRegIntTimer {
    my $modifier = shift // carp q[No modifier name]            && return;
    my $time     = shift // carp q[No time specified]           && return;
    my $callback = shift // carp q[No function specified]       && return;
    my $hash     = shift // carp q[No hash reference specified] && return;
    my $initFlag = shift // 0;

    deleteSingleRegIntTimer( $modifier, $hash );
    return setRegIntTimer ( $modifier, $time, $callback, $hash, $initFlag );
}

sub deleteAllRegIntTimer {
    my $hash     = shift // carp q[No hash reference specified] && return;

    for ( keys %{ $hash->{TIMER} } ) {
        deleteSingleRegisteredInternalTimer( $hash->{TIMER}{$_}{MODIFIER}, $hash );
    }
    return;
}

1;

__END__