#!/usr/bin/env perl -s
use 5.10.0;
use utf8;
use strict;
use warnings;
use open qw( :utf8 :std );
use Data::Dumper;
use Readonly qw( Readonly );
use Text::CSV;
use Path::Class qw( file );
use File::Basename qw( basename );

Readonly my $SIMPLE_KEY     => "simple";
Readonly my $MAP_SUB_KEY    => "csv_field_map";

our $setting_filepath
    or die usage( );
die "No [$setting_filepath] file found"
    unless -e $setting_filepath;

my $setting = do "$setting_filepath"
    or die $!;

my $map_sub = $setting->{ $MAP_SUB_KEY }
    or die <<END_DIE;
No map sub found in setting file
e.g.: $MAP_SUB_KEY => { some_csv_file => sub { return \@_[1, 5, 3, 4] } }
END_DIE

for my $filepath ( @ARGV ) {
    die "No [$filepath] exists"
        unless -e $filepath;

    my $file = file( $filepath );
    my $basename = basename( $file->basename, qw( .csv ) );

    my $select_sub = $map_sub->{ $basename }
        or die die "No map rule of [$basename] found in [$MAP_SUB_KEY]";

    my $csv = Text::CSV->new( { binary => 1 } );

    my $is_in_value;

    for my $line ( $file->slurp( chomp => 1, iomode => "<:encoding(utf-8)" ) ) {
        next
            unless $line;
        next
            unless $is_in_value++;

        $csv->parse( $line );
        my @columns = $csv->fields;
        my( $id, $value ) = $select_sub->( @columns );
        die "Could not get data : $line"
            if !( defined $id ) || !( defined $value );

        my %simple = (
            type    => $SIMPLE_KEY,
            value   => {
                id      => "$basename.$id",
                title   => "$value [$id]",
                indexes => [ $value, $id ],
            },
        );

        say Data::Dumper->new( [ \%simple ] )->Terse( 1 )->Indent( 0 )->Sortkeys( 1 )->Dump( );
    }
}

exit;

sub usage {
    return <<END_USAGE;
usage: $0 -setting_filepath=<perl data path>
END_USAGE
}
