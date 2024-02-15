#!/usr/bin/env perl
use 5.10.0;
use utf8;
use strict;
use warnings;
use open qw( :utf8 :std );
use Data::Dumper;
use Path::Class qw( file dir );
use Text::CSV;
use Readonly;
use File::Basename qw( basename );
use Getopt::Long;

Readonly my $BASE_DIR_KEY       => "icon_base_dir";
Readonly my $MAKE_ICON_SUB_KEY  => "make_icon_path";
Readonly my $MAP_SUB_KEY        => "csv_field_map";
Readonly my $OUTPUT_DIR         => "dictionary/OtherResources";

GetOptions(
    "setting=s" => \my $setting_filepath,
)
    or die usage( );

die "No [$setting_filepath] file found"
    unless -e $setting_filepath;

my $setting = do "$setting_filepath"
    or die $!;

my $icon_base_dir = $setting->{ $BASE_DIR_KEY }
    or die <<END_DIE;
No icon base dir found in setting file
e.g.: $BASE_DIR_KEY => "base/path/to/icon"
END_DIE
my $make_icon_sub = $setting->{ $MAKE_ICON_SUB_KEY }
    or die <<END_DIE;
No make icon sub found in setting file
e.g.: $MAKE_ICON_SUB_KEY => { my \$id = shift; return "images/\$id.png" }
END_DIE

my $map_sub = $setting->{ $MAP_SUB_KEY }
    or die <<END_DIE;
No map sub found in setting file
e.g.: $MAP_SUB_KEY => { some_csv_file => sub { return \@_[0, 1] } }
END_DIE

my $source_dir = dir( $icon_base_dir );
my $output_dir = dir( $OUTPUT_DIR );

for my $filepath ( @ARGV ) {
    die "No [$filepath] exists"
        unless -e $filepath;

    my $file = file( $filepath );
    my $basename = basename( $file->basename, qw( .csv ) );

    my $select_sub = $map_sub->{ $basename }
        or die die "No map rule of [$basename] found in [$MAP_SUB_KEY]";

    my $csv = Text::CSV->new( { binary => 1 } );

    for my $line ( $file->slurp( chomp => 1, iomode => "<:encoding(utf-8)" ) ) {
        $csv->parse( $line );
        my @columns = $csv->fields;
        my( $id, undef ) = $select_sub->( @columns );

        my $icon_path = $make_icon_sub->( $id, $basename )
            or next;

        my $icon_file = $source_dir->file( $icon_path );
        next
            unless -e $icon_file;

        my $output_file = $output_dir->file( $icon_path );
        $output_file->dir->mkpath;

        `ln -f $icon_file $output_file`;
        die $!
            if $?;
    }
}

exit;

sub usage {
    return <<END_USAGE;
usage: $0 --setting <perl data path>
END_USAGE
}
