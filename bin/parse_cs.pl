#!/usr/bin/env perl
use 5.10.0;
use utf8;
use strict;
use warnings;
use open qw( :utf8 :std );
use Data::Dumper;
use Readonly;

Readonly my @HEADERS => qw(
    type
    type_read
    type_url
    name
    value
    read
);

Readonly my $STATE_WAIT_ENUM        => "wait_enum";
Readonly my $STATE_IN_ENUM_SUMMARY  => "in_enum_summary";
Readonly my $STATE_IN_ENUM          => "in_enum";
Readonly my $STATE_IN_VALUE_SUMMARY => "in_value_summary";
Readonly my $STATE_WAIT_VALUE       => "wait_value";
Readonly my $STATE_IN_VALUE         => "in_value";
Readonly my $STATE_END_ENUM         => "end_enum";
Readonly my %STATE => (
    map { ( $_, $_ ) }
    (
        $STATE_WAIT_ENUM,
        $STATE_IN_ENUM_SUMMARY,
        $STATE_IN_ENUM,
        $STATE_IN_VALUE_SUMMARY,
        $STATE_WAIT_VALUE,
        $STATE_IN_VALUE,
        $STATE_END_ENUM,
    ),
);

my $state = $STATE{ $STATE_WAIT_ENUM };
my %type;
my %processor = (
    $STATE_WAIT_ENUM        => \&process_wait_enum,
    $STATE_IN_ENUM_SUMMARY  => \&process_in_enum_summary,
    $STATE_IN_ENUM          => \&process_in_enum,
    $STATE_IN_VALUE_SUMMARY => \&process_in_value_summary,
    $STATE_WAIT_VALUE       => \&process_wait_value,
    $STATE_IN_VALUE         => \&process_in_value,
    $STATE_END_ENUM         => \&process_end_enum,
);

say join "\t", @HEADERS;

while ( <> ) {
    chomp( my $line = $_ );
    my $did_consume;
    my $safety_counter;

#warn "\$state $state";
#warn "\$line: $line";
    while ( !$did_consume ) {
        ( $did_consume, $state ) = $processor{ $state }( $line, $state, \%type );
#warn "\$new state $state";

        if ( $safety_counter++ > 30 ) {
            die "Could not parse";
        }
    }

    if ( $state eq $STATE{ $STATE_END_ENUM } ) {
#warn Dumper \%type;
        my @rows = format_type( %type );
        print map { $_, "\n" } @rows;

        %type = ( );

        $state = $STATE_WAIT_ENUM;
    }
}

exit;

sub format_type {
    my %type = @_;
    my @rows;

    my $type_name = $type{name}
        or die "No name found in ", Dumper \%type;
    my $type_read = $type{read};
    my $values_ref = $type{values}
        or die "No values found in ", Dumper \%type;

    for my $value_ref ( @{ $values_ref } ) {
        die "Invalid value found: ", Dumper $value_ref
            if !$value_ref->{name}
                || !$value_ref->{value};

        my $value_read = $value_ref->{read};

        my @columns = (
            $type_name,
            $type_read,
            "no_url_for_now",
            @{ $value_ref }{ qw( name value read ) },
        );

        push @rows, join "\t", map { $_ //= q{} } @columns;
    }

    return @rows;
}

sub process_end_enum {
    my( $line, $state, $type_ref ) = @_;
    my $did_consume;
    my $next = $state;

    $did_consume++;

    return( ( $did_consume, $next ) );
}

sub process_in_value {
    my( $line, $state, $type_ref ) = @_;
    my $did_consume;
    my $next = $state;

    if ( $line =~ m{ (\w+) \s* [=] \s* (\d+) , }msx ) {
        my $values_ref = ( $type_ref->{values} //= [] );
        my( $name, $value ) = ( $1, $2 );
        my $read = delete $type_ref->{work_space};
        $read =~ s{です}{};

        my %value = (
            name => $name,
            value => $value,
        );

        $value{read} = $read
            if $read;

        push @{ $values_ref }, \%value;

        $next = $STATE_IN_ENUM;
    }

    $did_consume++;

    return( ( $did_consume, $next ) );
}

sub process_wait_value {
    my( $line, $state, $type_ref ) = @_;
    my $did_consume;
    my $next = $state;

    $did_consume++;

    if ( $line =~ m{ \w+ \s* [=] \s* \d+ , }msx ) {
        $next = $STATE_IN_VALUE;
        undef $did_consume;
    }

    return( ( $did_consume, $next ) );
}

sub process_in_value_summary {
    my( $line, $state, $type_ref ) = @_;
    my $did_consume;
    my $next = $state;

    if ( $line =~ m{ /// \s+ </summary> }msx ) {
        $next = $STATE_WAIT_VALUE;
    }
    elsif ( $line =~ m{ /// \s* (.*) }msx && $1 ) {
        my $summary = $type_ref->{work_space} || q{};
        $summary = $summary . $1;
        $type_ref->{work_space} = $summary;
    }

    $did_consume++;

    return( ( $did_consume, $next ) );
}

sub process_in_enum {
    my( $line, $state, $type_ref ) = @_;
    my $did_consume;
    my $next = $state;

    delete $type_ref->{work_space};

    $did_consume++;

    if ( $line =~ m{ /// \s+ <summary> }msx ) {
        $next = $STATE_IN_VALUE_SUMMARY;
    }

    if ( $line =~ m{ \w+ \s* [=] \s* \d+ , }msx ) {
        $next = $STATE_IN_VALUE;
        undef $did_consume;
    }

    if ( $line =~ m/ [}] /msx ) {
        $next = $STATE_END_ENUM;
        undef $did_consume;
    }

    return( ( $did_consume, $next ) );
}

sub process_in_enum_summary {
    my( $line, $state, $type_ref ) = @_;
    my $did_consume;
    my $next = $state;

    if ( $line =~ m{ /// \s* </summary> }msx ) {
        $next = $STATE_WAIT_ENUM;
    }
    elsif ( $line =~ m{ /// (.*) }msx && $1 ) {
        my $summary = $type_ref->{summary} || q{};
        $summary = $summary . $1;
        $type_ref->{summary} = $summary;
    }

    $did_consume++;

    return( ( $did_consume, $next ) );
}

sub process_wait_enum {
    my( $line, $state, $type_ref ) = @_;
    my $did_consume;
    my $next = $state;

    if ( $line =~ m{ \b enum \s+ (\w+) }msx ) {
        $type_ref->{name} = $1;
        $next = $STATE_IN_ENUM;
    }

    if ( $line =~ m{ /// \s* <summary> }msx ) {
        $next = $STATE_IN_ENUM_SUMMARY;
    }

    $did_consume++;

    return( ( $did_consume, $next ) );
}
