#!/usr/bin/env perl -s
use 5.10.0;
use utf8;
use strict;
use warnings;
use open qw( :utf8 :std );
use Data::Dumper;
use Readonly;
use List::MoreUtils qw( zip );
use Template;

our $template_filename
    or die usage( );
die "No [$template_filename] found"
    unless -e $template_filename;

chomp( my $line = <> );
my @headers = split m{\t}, $line;

my @records;

while ( <> ) {
    chomp( my $line = $_ );
    my @colmuns = split m{\t}, $line;
    my %record = ( zip @headers, @colmuns );
    push @records, \%record;
}
#die Dumper \@records;

my @types = concrete_types( @records );
#die Dumper \@types;

my $template = Template->new( ENCODING => "utf-8" );
$template->process(
    $template_filename,
    { types => \@types },
    \my $output,
)
    or die $template->error;

say $output;

exit;

sub concrete_types {
    my @records = @_;
    my %type;

# tsv
# type / type_read / type_url / name / value / read
# MoveSpeedType / 移動速さ / https://example.com/ / Slow / 1 / 遅い

    READ_RECORDS:
    for my $record_ref ( @records ) {
        my $type_ref = $type{ $record_ref->{type} } //= { name => $record_ref->{type} };
        die <<END_DIE
type_read has no consistency,
it has changed from: $type_ref->{type_read} to: $record_ref->{type_read}.
END_DIE
            if $type_ref->{type_read} && $record_ref->{type_read} ne $type_ref->{type_read};

        $type_ref->{type_read} //= $record_ref->{type_read};

        die <<END_DIE
type_url has no consistency,
it has changed from: $type_ref->{type_url} to: $record_ref->{type_url}.
END_DIE
            if $type_ref->{type_url} && $record_ref->{type_url} ne $type_ref->{type_url};

        $type_ref->{type_url} //= $record_ref->{type_url};

#warn Dumper \$type_ref;

        my %value = (
            name    => $record_ref->{name},
            value   => $record_ref->{value},
            read    => $record_ref->{read},
        );

        my $values_ref = $type_ref->{values} //= [];
        push @{ $values_ref }, \%value;
    }

#warn Dumper \%type;

    CONCRETE_TYPES:
    for my $type_name ( keys %type ) {
        my $type_ref = $type{ $type_name };

        die "Invalid type found: " . Data::Dumper->new( [ $type_ref ] )->Terse( 1 )->Indent( 0 )->Dump( )
            if !$type_ref->{name}
                || !defined( $type_ref->{type_read} )
                || !defined( $type_ref->{type_url} );

        $type_ref->{id} = $type_ref->{name};
        $type_ref->{title} = $type_ref->{name};
        $type_ref->{read} = ( delete $type_ref->{type_read} ) || $type_ref->{name};
        $type_ref->{url} = delete $type_ref->{type_url};

        die "No values found in type: $type_ref->{name}."
            unless $type_ref->{values};

        CONCRETE_VALUES:
        for my $value_ref ( @{ $type_ref->{values} } ) {
            die "Invalid value found: " . Dumper( $value_ref )
                if !$value_ref->{name}
                    || !defined( $value_ref->{value} )
                    || !defined( $value_ref->{read} );

            $value_ref->{id} = $value_ref->{name},
            $value_ref->{title} = "$type_ref->{name}.$value_ref->{name}";
            $value_ref->{indexes} = [
                @{ $value_ref }{ qw( id value title ) },
            ];

            push @{ $value_ref->{indexes} }, $value_ref->{read}
                if $value_ref->{read};
        }
    }

    return values %type;
}

sub usage {
    return <<END_USAGE;
usage: $0 -template_filename=<template filename>
END_USAGE
}

__END__
(
    types   => [
        {
            id      => "MoveSpeedType",
            title   => "MoveSpeedType",
            name    => "MoveSpeedType",
            read    => "移動速さ",
            values  => [
                {
                    id      => "MoveSpeedType.Slow",
                    name    => "Slow",
                    title   => "MoveSpeedType.Slow",
                    value   => 1,
                    read    => "遅い",
                    indexes => [
                        qw( Slow 1 MoveSpeedType.Slow 遅い )
                    ],
                },
            ],
            url     => "https://example.com/",
        },
    ],
)
