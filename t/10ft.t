
BEGIN { $^W = 1; }
use strict;
require 't/ft_test_util.pl';

use Test::More tests => 30;

use_ok( 'File::Transaction::Atomic' );

my $ft = File::Transaction::Atomic->new;
isa_ok($ft, 'File::Transaction::Atomic');

writefile('t/foo', "hic hic foo\nbump\n");
$ft->linewise_rewrite('t/foo', sub { s/foo/bar/g });
is( readfile('t/foo.tmp'), "hic hic bar\nbump\n", "linewise_rewrite makes t/foo.tmp" );

$ft->revert;
ok( ! -e 't/foo.tmp', "revert deletes t/foo.tmp" );
is( readfile('t/foo'), "hic hic foo\nbump\n", "revert leaves t/foo unchanged" );

$ft = File::Transaction::Atomic->new;
writefile('t/foo', "ping foo ping\n");
writefile('t/foo.tmp', "pong\n");
$ft->linewise_rewrite('t/foo', sub { s/foo/bar/g });
is( readfile('t/foo.tmp'), "ping bar ping\n", "linewise_rewrite overwrites stale t/foo.tmp" );
$ft->commit;
ok( ! -e 't/foo.tmp', "commit deletes t/foo.tmp" );
is( readfile('t/foo'), "ping bar ping\n", "commit updates t/foo" );

$ft = File::Transaction::Atomic->new;
writefile('t/foo', "foo foo foo\n");
writefile('t/foo.poing', "bar bar bar\n");
$ft->addfile('t/foo', 't/foo.poing');
$ft->revert;
ok( ! -e 't/foo.poing', "revert after addfile deletes tmpfile" );
is( readfile('t/foo'), "foo foo foo\n", "revert after addfile leaves t/foo unchanged" );

$ft = File::Transaction::Atomic->new;
writefile('t/foo', "foo foo foo\n");
writefile('t/foo.poing', "bar bar bar\n");
$ft->addfile('t/foo', 't/foo.poing');
$ft->commit;
ok( ! -e 't/foo.poing', "commit after addfile deletes tmpfile" );
is( readfile('t/foo'), "bar bar bar\n", "commit after addfile updates t/foo" );

$ft = File::Transaction::Atomic->new;
unlink 't/foo';
writefile('t/foo.poing', "bar bar bar\n");
$ft->addfile('t/foo', 't/foo.poing');
$ft->revert;
ok( ! -e 't/foo.poing', "revert after addfile no oldfile deletes tmpfile" );
ok( ! -e 't/foo', "revert after addfile no oldfile leaves oldfile absent" );

$ft = File::Transaction::Atomic->new;
unlink 't/foo';
writefile('t/foo.poing', "boing\n");
$ft->addfile('t/foo', 't/foo.poing');
$ft->commit;
ok( ! -e 't/foo.poing', "commit after addfile no oldfile deletes tmpfile" );
is( readfile('t/foo'), "boing\n", "commit after addfile no oldfile updates t/foo" );

$ft = File::Transaction::Atomic->new;
writefile('t/foo1', "wump wump foo\n");
writefile('t/foo2', "pong pong foo\n");
$ft->linewise_rewrite('t/foo1', sub { s/foo/bar/g });
eval { $ft->linewise_rewrite('t/foo2', sub { die "I broke" }); };
like( $@, '/I broke/', "linewise_rewrite propagates die" );
$ft->revert;
is( readfile('t/foo1'), "wump wump foo\n", "revert after die first file unchanged" );
is( readfile('t/foo2'), "pong pong foo\n", "revert after die second file unchanged" );
ok( ! -e 't/foo1.tmp', "revert after die first tmpfile removed" );
ok( ! -e 't/foo2.tmp', "revert after die second tmpfile removed" );

$ft = File::Transaction::Atomic->new;
writefile('t/foo', "wump wump foo\n");
$ft->linewise_rewrite('t/foo', sub { s/foo/bar/g });
eval { $ft->linewise_rewrite('t/x/y/z', sub { s/foo/bar/g }) };
ok( $@, "linewise_rewrite dies on file error" );
$ft->revert;
is( readfile('t/foo'), "wump wump foo\n", "revert after error file unchanged" );
ok( ! -e 't/foo.tmp', "revert after error tmpfile removed" );

$ft = File::Transaction::Atomic->new;
unlink 't/foo';
$ft->linewise_rewrite('t/foo', sub { die "this sub should never be called" });
$ft->commit;
ok( -e 't/foo' && -s 't/foo' == 0, "linewise_rewrite converts missing to empty" );

$ft = File::Transaction::Atomic->new('baz');
writefile('t/foo', "ding dong foo\n");
$ft->linewise_rewrite('t/foo', sub { s/foo/bar/g });
is( readfile('t/foobaz'), "ding dong bar\n", "linewise_rewrite honors tmpext" );
$ft->commit;
ok( ! -e 't/foobaz', "commit with tmpext deletes tmpfile" );
is( readfile('t/foo'), "ding dong bar\n", "commit with tmpext updates t/foo" );

$ft = File::Transaction::Atomic->new('bar');
writefile('t/foo', "dong ding foo\n");
$ft->commit;
ok( ! -e 't/foobar', "revert with tmpext deletes tmpfile" );
is( readfile('t/foo'), "dong ding foo\n", "revert with tmpext leaves t/foo unchanged" );

unlink qw(t/foo t/foo1 t/foo2 t/foobaz.old t/foo.tmp.old);

