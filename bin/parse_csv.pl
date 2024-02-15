#!/usr/bin/env perl
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
use Lingua::JA::Regular::Unicode qw( katakana2hiragana );
use Getopt::Long;

Readonly my $SIMPLE_KEY         => "simple";
Readonly my $MAP_SUB_KEY        => "csv_field_map";
Readonly my $MAKE_ICON_SUB_KEY  => "make_icon_path";

GetOptions(
    "setting=s" => \my $setting_filepath,
)
    or die usage( );
die "No [$setting_filepath] file found"
    unless -e $setting_filepath;

my $setting = do "$setting_filepath"
    or die $!;

my $map_sub = $setting->{ $MAP_SUB_KEY }
    or die <<END_DIE;
No map sub found in setting file
e.g.: $MAP_SUB_KEY => { some_csv_file => sub { return \@_[0, 1] } }
END_DIE

my $make_icon_sub = $setting->{ $MAKE_ICON_SUB_KEY }
    or die <<END_DIE;
No make icon sub found in setting file
e.g.: $MAKE_ICON_SUB_KEY => { my \$id = shift; return "images/\$id.png" }
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

        my $icon_path = $make_icon_sub->( $id, $basename );

        my %simple = (
            type    => $SIMPLE_KEY,
            value   => {
                id          => "$basename.$id",
                title       => "$value [$id]",
                indexes     => [ map { create_indexes( $_ ) } ( $value, $id ) ],
                icon_path   => $icon_path,
            },
        );

        say Data::Dumper->new( [ \%simple ] )->Terse( 1 )->Indent( 0 )->Sortkeys( 1 )->Dump( );
    }
}

exit;

sub create_indexes {
    my $value = shift;
    my %key_value;

    my $splitter = qr{[・\(\)（）「」【】]};
    my @tokens = split $splitter, $value;

    for my $token ( @tokens ) {
        next
            unless length $token;

        my %index = ( value => $token );
        $key_value{ $token } = \%index;

        my @sub_tokens = split m{(\p{Katakana}{2,}+)}, $token; # exclude single char token which where ー
        push @sub_tokens, split m{(\p{Hiragana}{2,}+)}, $token; # exclude single char token which where ー

        for my $sub_token ( @sub_tokens ) {
            my %sub_index = ( value => $sub_token );
            add_yomi( $sub_token, \%sub_index );

            $key_value{ $sub_token } = \%sub_index;
        }
    }

    my %index = ( value => $value );
    add_yomi( $value, \%index );

    $key_value{ $value } = \%index;

    delete @key_value{
        grep { m{\A (:?\p{Katakana}|\p{Hiragana}) \z}msx }
        keys %key_value
    };

    delete $key_value{ q{} };

    return values %key_value;
}

sub add_yomi {
    my( $key, $index_ref ) = @_;

    if ( $key =~ m/\A \p{Katakana}+ \z/msx ) {
        $index_ref->{yomi} = katakana2hiragana( $key );
    }
}

sub usage {
    return <<END_USAGE;
usage: $0 --setting <perl data path>
END_USAGE
}
