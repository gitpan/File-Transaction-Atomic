#!perl -wT -I. -Iblib/lib
use strict;
require 't/ft_test_util.pl';

use Test::More tests => 10;

my $taint = substr $ENV{PATH}, 0, 0;
writefile('t/foo',      'this is foo');
writefile('t/foo.temp', 'this is foo.temp');

use_ok ( 'File::Transaction::Atomic' );

my $ft = File::Transaction::Atomic->new(".temp$taint");
eval { $ft->linewise_rewrite('t/foo', sub { s/foo/bar/ }) };
like( $@, '/Insecure dependency/', "tainted TMPEXT is fatal at rewrite" );
is( readfile('t/foo.temp'), 'this is foo.temp', "file not changed with tainted TMPEXT" );

-d 't/.work/new' and deldir('t/.work/new');
-d 't/.work' and deldir('t/.work');
$ft = File::Transaction::Atomic->new;
$ft->linewise_rewrite('t/foo', sub { s/foo/bar/ });
eval { $ft->commit("t/.work$taint") };
like( $@, '/Insecure dependency/', "tainted WORKDIR is fatal" );

mkdir 't/.work', 0700                or die "mkdir: $!";
mkdir 't/.work/new', 0700            or die "mkdir: $!";
symlink 'new', 't/.work/live'        or die "symlink: $!";
symlink 'x',   't/.work/live/t-sfoo' or die "symlink: $!";
$ft = File::Transaction::Atomic->new;
eval { $ft->commit("t/.work$taint") };
like( $@, '/Insecure dependency in unlink.*line 377\./',
          "tainted existing WORKDIR is fatal before doing anything" );
deldir('t/.work/new');
deldir('t/.work');

$ft = File::Transaction::Atomic->new;
$ft->linewise_rewrite('t/foo', sub { s/foo/bar/ });
eval { $ft->commit(undef, ".old$taint") };
like( $@, '/Insecure dependency/', "tainted OLDEXT is fatal" );

$ft = File::Transaction::Atomic->new;
$ft->linewise_rewrite('t/foo', sub { s/foo/bar/ });
eval { $ft->commit(undef, undef, ".lnk$taint") };
like( $@, '/Insecure dependency/', "tainted TMPLNKEXT is fatal" );

$ft = File::Transaction::Atomic->new;
$ft->addfile('t/foo', "t/foo.temp$taint");
eval { $ft->commit };
like( $@, '/Insecure dependency/', "tainted TMPFILE is fatal" );

$ft = File::Transaction::Atomic->new;
$ft->addfile("t/foo$taint", 't/foo.temp');
eval { $ft->commit };
like( $@, '/Insecure dependency/', "tainted OLDFILE is fatal" );

$ft = File::Transaction::Atomic->new;
eval { $ft->linewise_rewrite('t/foo', sub { system $_ }) };
like( $@, '/while running with \-T/', "old file contents tainted" );

unlink qw(t/foo t/foo.tmp t/foo.tmp.old t/foo.temp);

