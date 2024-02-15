#!/usr/bin/env perl
use 5.10.0;
use utf8;
use strict;
use warnings;
use open qw( :utf8 :std );
use Data::Dumper;
use Readonly;
use Template;
use Getopt::Long;

Readonly my $GROUP_KEY  => "group";
Readonly my $SIMPLE_KEY => "simple";

GetOptions(
    "template=s" => \my $template_filename
)
    or die usage( );

die "No [$template_filename] found"
    unless -e $template_filename;

my @simples;
my @groups;

while ( <> ) {
    chomp( my $line = $_ );
    my $record_ref = eval $line;

    die "Could not eval line[$line] : $@"
        if $@;

    my $type_key = $record_ref->{type}
        or die "No type key found : $line";

    die "Invalid type found : $line"
        if !( $type_key eq $GROUP_KEY || $type_key eq $SIMPLE_KEY );

    my $value_ref = $record_ref->{value}
        or die "No value found : $line";

    if ( $type_key eq $SIMPLE_KEY ) {
        push @simples, $value_ref;
    }

    if ( $type_key eq $GROUP_KEY ) {
        push @groups, $value_ref;
    }
}
#die Dumper [ \@simples, \@groups ];

my $template = Template->new( ENCODING => "utf-8" );
$template->process(
    $template_filename,
    {
        simples => \@simples,
        groups  => \@groups,
    },
    \my $output,
)
    or die $template->error;

say $output;

exit;

sub usage {
    return <<END_USAGE;
usage: $0 --template <template filename>
END_USAGE
}
