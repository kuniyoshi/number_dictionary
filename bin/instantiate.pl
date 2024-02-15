#!/usr/bin/env perl
use 5.10.0;
use utf8;
use strict;
use warnings;
use open qw( :utf8 :std );
use Data::Dumper;
use Readonly;
use Template;
use FindBin;

Readonly my $SETTING_FILENAME => "setting.data";

my $setting_ref = do "$FindBin::Bin/$SETTING_FILENAME";

my $in = do { local $/; <> };
my $template = Template->new;
$template->process(
    \$in,
    $setting_ref,
    \my $output,
)
    or die $template->error;

say $output;

exit;

