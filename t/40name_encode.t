
use strict;
BEGIN { $^W = 1; }
require 't/ft_test_util.pl';

use Cwd 'abs_path';
use Test::More tests => 50;

use vars qw($fail);

use subs qw(File::Transaction::Atomic::rename);
use File::Transaction::Atomic;
sub File::Transaction::Atomic::rename {
    $fail and $_[0] =~ m#/tobe$# and $_[1] =~ m#/live$# and die;
    CORE::rename($_[0], $_[1]);
}

chdir 't' or die "chdir: $!";

my $woo = abs_path('.') . '/woo';
my $woohoo = abs_path('.') . '/woo-hoo';

my $ft = setup_ft();
$fail = 1;
eval { $ft->commit };
ok( $@, "commit with default workdir died" );


ok( -l '-',     "rel workdir pre-commit replaced - with symlink" );
ok( -l '--',    "rel workdir pre-commit replaced -- with symlink" );
ok( -l '-s',    "rel workdir pre-commit replaced -s with symlink" );
ok( -l '-m',    "rel workdir pre-commit replaced -m with symlink" );
ok( -l $woo,    "rel workdir pre-commit replaced woo with symlink" );
ok( -l $woohoo, "rel workdir pre-commit replaced woohoo with symlink" );
is( readfile('./-'),     '- foo',  "rel workdir pre-commit preserved - contents" );
is( readfile('./--'),    '-- foo', "rel workdir pre-commit preserved -- contents" );
is( readfile('./-s'),    '-s foo', "rel workdir pre-commit preserved -s contents" );
is( readfile('./-m'),    '-m foo', "rel workdir pre-commit preserved -m contents" );
is( readfile($woo),    'woo foo', "rel workdir pre-commit preserved woo contents" );
is( readfile($woohoo), 'woo-hoo foo', "rel workdir pre-commit preserved woohoo contents" );

$fail = 0;
File::Transaction::Atomic->new->commit;

ok( ! -l '-',     "rel workdir tidy de-symlinked -" );
ok( ! -l '--',    "rel workdir tidy de-symlinked --" );
ok( ! -l '-s',    "rel workdir tidy de-symlinked -s" );
ok( ! -l '-m',    "rel workdir tidy de-symlinked -m" );
ok( ! -l $woo,    "rel workdir tidy de-symlinked woo" );
ok( ! -l $woohoo, "rel workdir tidy de-symlinked woohoo" );
is( readfile('./-'),     '- foo',  "rel workdir tidy preserved - contents" );
is( readfile('./--'),    '-- foo', "rel workdir tidy preserved -- contents" );
is( readfile('./-s'),    '-s foo', "rel workdir tidy preserved -s contents" );
is( readfile('./-m'),    '-m foo', "rel workdir tidy preserved -m contents" );
is( readfile($woo),    'woo foo', "rel workdir tidy preserved woo contents" );
is( readfile($woohoo), 'woo-hoo foo', "rel workdir tidy preserved woohoo contents" );

$ft = setup_ft();
$fail = 1;
eval { $ft->commit(abs_path('.') . '/foo') };
ok( $@, "commit with absolute workdir died" );

ok( -l '-',     "abs workdir pre-commit replaced - with symlink" );
ok( -l '--',    "abs workdir pre-commit replaced -- with symlink" );
ok( -l '-s',    "abs workdir pre-commit replaced -s with symlink" );
ok( -l '-m',    "abs workdir pre-commit replaced -m with symlink" );
ok( -l $woo,    "abs workdir pre-commit replaced woo with symlink" );
ok( -l $woohoo, "abs workdir pre-commit replaced woohoo with symlink" );
is( readfile('./-'),     '- foo',  "abs workdir pre-commit preserved - contents" );
is( readfile('./--'),    '-- foo', "abs workdir pre-commit preserved -- contents" );
is( readfile('./-s'),    '-s foo', "abs workdir pre-commit preserved -s contents" );
is( readfile('./-m'),    '-m foo', "abs workdir pre-commit preserved -m contents" );
is( readfile($woo),    'woo foo', "abs workdir pre-commit preserved woo contents" );
is( readfile($woohoo), 'woo-hoo foo', "abs workdir pre-commit preserved woohoo contents" );

$fail = 0;
File::Transaction::Atomic->new->commit(abs_path('.') . '/foo');

ok( ! -l '-',     "abs workdir tidy de-symlinked -" );
ok( ! -l '--',    "abs workdir tidy de-symlinked --" );
ok( ! -l '-s',    "abs workdir tidy de-symlinked -s" );
ok( ! -l '-m',    "abs workdir tidy de-symlinked -m" );
ok( ! -l $woo,    "abs workdir tidy de-symlinked woo" );
ok( ! -l $woohoo, "abs workdir tidy de-symlinked woohoo" );
is( readfile('./-'),     '- foo',  "abs workdir tidy preserved - contents" );
is( readfile('./--'),    '-- foo', "abs workdir tidy preserved -- contents" );
is( readfile('./-s'),    '-s foo', "abs workdir tidy preserved -s contents" );
is( readfile('./-m'),    '-m foo', "abs workdir tidy preserved -m contents" );
is( readfile($woo),    'woo foo', "abs workdir tidy preserved woo contents" );
is( readfile($woohoo), 'woo-hoo foo', "abs workdir tidy preserved woohoo contents" );

unlink qw(- -.tmp -- --.tmp -s -s.tmp -m -m.tmp woo woo.tmp woo-hoo woo-hoo.tmp);

sub setup_ft {
    my $ft = File::Transaction::Atomic->new;

    writefile('./-', '- foo');
    $ft->linewise_rewrite('./-', sub { s/foo/bar/ });

    writefile('./--', '-- foo');
    $ft->linewise_rewrite('--', sub { s/foo/bar/ });

    writefile('./-s', '-s foo');
    $ft->linewise_rewrite('-s', sub { s/foo/bar/ });

    writefile('./-m', '-m foo');
    $ft->linewise_rewrite('-m', sub { s/foo/bar/ });

    writefile($woo, 'woo foo');
    $ft->linewise_rewrite($woo, sub { s/foo/bar/ });

    writefile($woohoo, 'woo-hoo foo');
    $ft->linewise_rewrite($woohoo, sub { s/foo/bar/ });

    return $ft;
}

