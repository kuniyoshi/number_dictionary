#!/usr/bin/env perl
use 5.10.0;
use utf8;
use strict;
use warnings;
use open qw( :utf8 :std );
use Data::Dumper;
use Readonly;

Readonly my $STATE_ENUM_NAME    => "enum_name";
Readonly my $STATE_COMMENT      => "comment";
Readonly my $STATE_SYMBOL       => "symbol";
Readonly my %WORK => (
    $STATE_ENUM_NAME    => \&parse_enum_name,
    $STATE_COMMENT      => \&parse_comment,
    $STATE_SYMBOL       => \&parse_symbol,
);

my $state = $STATE_ENUM_NAME;
my @terms;

while ( <> ) {
    chomp( my $line = $_ );
    my( $next, $result ) = $WORK{ $state }( $line );
    push @terms, $result
        if $result;
    $state = $next;
}

dump_result( @terms );

exit;

sub parse_enum_name {
    my $line = shift;

    if ( $line =~ m{\b enum \s+ (\w+) \s+ }msx ) {
        return $STATE_COMMENT, { name => $1 };
    }

    return $STATE_ENUM_NAME;
}

sub parse_comment {
    my $line = shift;

    if ( $line =~ m{\s [*] \s (.+) \z}msx ) {
        return $STATE_SYMBOL, $1;
    }

    if ( $line =~ m{ \} }msx ) {
        return $STATE_ENUM_NAME;
    }

    return $STATE_COMMENT;
}

sub parse_symbol {
    my $line = shift;

    if ( $line =~ m{\A \s* (\w+) \s+ [=] \s+ (.+) , \z}msx ) {
        return $STATE_COMMENT, [ $1, $2 ];
    }

    return $STATE_SYMBOL;
}

sub dump_result {
    my @terms = @_;

    my $name;
    my @symbols;
    my %group;

    while ( @terms ) {
        if ( ref $terms[0] eq ref {} ) {
            if ( $name ) {
                $group{ $name } = [ @symbols ];
                @symbols = ( );
            }

            my $ref = shift @terms;
            $name = $ref->{name};

            next;
        }

        die "No name own"
            unless $name;

        my $comment = shift @terms
            or die "Could not get comment";
        my $symbol_ref = shift @terms
            or die "Could not get symbol";
        my( $symbol, $value ) = @{ $symbol_ref };

        my %simple = (
            type    => "simple",
            value   => {
                id      => "$name.$symbol",
                title   => "$name.$comment ($symbol) [$value]",
                indexes => [
                    { value => $comment },
                    { value => $symbol },
                    { value => $value },
                ],
            }
        );

        say Data::Dumper->new( [ \%simple ] )->Terse( 1 )->Indent( 0 )->Sortkeys( 1 )->Dump( );

        push @symbols, { comment => $comment, symbol => $symbol_ref };
    }

    if ( $name && @symbols ) {
        $group{ $name } = \@symbols;
        @symbols = ( );
    }

    for my $name ( keys %group ) {
        my %record = (
            type    => "group",
            value   => {
                id      => $name,
                indexes => [ { value => $name } ],
                title   => $name,
                values  => [
                    map { { key => $_->{symbol}[0], value => $_->{symbol}[1] } } @{ $group{ $name } },
                ],
            },
        );

        say Data::Dumper->new( [ \%record ] )->Terse( 1 )->Indent( 0 )->Sortkeys( 1 )->Dump( );
    }
}
