
BEGIN { $^W = 1; }
use strict;
require 't/ft_test_util.pl';

use Test::More tests => 18;

use File::Transaction::Atomic;

-d 't/xr' and deldir('t/xr');

mkdir 't/xr', 0755 or die "mkdir: $!";
writefile('t/xr/foo',         'this is foo');
writefile('t/xr/foo.tmp',     'this is foo.tmp');
writefile('t/xr/foo.tmp.old', 'this is foo.tmp.old');
writefile('t/xr/foo.tmp.lnk', 'this is foo.tmp.lnk');

my $ft = File::Transaction::Atomic->new;
$ft->linewise_rewrite('t/xr/foo', sub { s/foo/bar/ });
$ft->commit;

ok( ! -e 't/xr/foo.tmp',     "commit blatted stray foo.tmp" );
ok( ! -e 't/xr/foo.tmp.lnk', "commit blatted stray foo.tmp.lnk" );
ok( ! -e 't/xr/foo.tmp.old', "commit blatted stray foo.tmp.old" );
is( readfile('t/xr/foo'), 'this is bar', "commit updated foo" );

unlink 't/xr/foo';
rmdir 't/xr' or die "rmdir: $!";


mkdir 't/xr', 0755 or die "mkdir: $!";
writefile('t/xr/foo',         'this is foo');
writefile('t/xr/foo.tmp',     'this is foo.tmp');
writefile('t/xr/foo.tmp.old', 'this is foo.tmp.old');
writefile('t/xr/foo.tmp.lnk', 'this is foo.tmp.lnk');

$ft = File::Transaction::Atomic->new(".baz");
$ft->linewise_rewrite('t/xr/foo', sub { s/foo/bar/ });
$ft->commit;

is( readfile('t/xr/foo.tmp'),     'this is foo.tmp',     ".baz commit left foo.tmp" );
is( readfile('t/xr/foo.tmp.old'), 'this is foo.tmp.old', ".baz commit left foo.tmp.old" );
is( readfile('t/xr/foo.tmp.lnk'), 'this is foo.tmp.lnk', ".baz commit left foo.tmp.lnk" );
is( readfile('t/xr/foo'),         'this is bar',         ".baz commit updated foo" );

unlink qw(t/xr/foo.tmp t/xr/foo.tmp.lnk t/xr/foo.tmp.old t/xr/foo);
rmdir 't/xr' or die "rmdir: $!";


mkdir 't/xr', 0755 or die "mkdir: $!";
writefile('t/xr/foo',         'this is foo');
writefile('t/xr/foo.tmp',     'this is foo.tmp');
writefile('t/xr/foo.tmp.old', 'this is foo.tmp.old');
writefile('t/xr/foo.tmp.lnk', 'this is foo.tmp.lnk');
writefile('t/xr/foo.ooold',   'this is foo.ooold');

$ft = File::Transaction::Atomic->new;
$ft->linewise_rewrite('t/xr/foo', sub { s/foo/bar/ });
$ft->commit(undef, '.ooold');

ok( ! -e 't/xr/foo.tmp',     "commit with OLDEXT blatted stray foo.tmp" );
ok( ! -e 't/xr/foo.ooold',   "commit with OLDEXT blatted stray foo.ooold" );
ok( ! -e 't/xr/foo.tmp.lnk', "commit with OLDEXT blatted stray foo.tmp.lnk" );
is( readfile('t/xr/foo.tmp.old'), 'this is foo.tmp.old', "commit with OLDEXT left foo.tmp.old" );
is( readfile('t/xr/foo'),         'this is bar',         "commit with OLDEXT updated foo" );

unlink qw(t/xr/foo t/xr/foo.tmp.old);
rmdir 't/xr' or die "rmdir: $!";


mkdir 't/xr', 0755 or die "mkdir: $!";
writefile('t/xr/foo',         'this is foo');
writefile('t/xr/foo.tmp',     'this is foo.tmp');
writefile('t/xr/foo.tmp.old', 'this is foo.tmp.old');
writefile('t/xr/foo.tmp.lnk', 'this is foo.tmp.lnk');
writefile('t/xr/foo.linky',   'this is foo.linky');

$ft = File::Transaction::Atomic->new;
$ft->linewise_rewrite('t/xr/foo', sub { s/foo/bar/ });
$ft->commit(undef, undef, '.linky');

ok( ! -e 't/xr/foo.tmp',     "commit with TMPLNKEXT blatted stray foo.tmp" );
ok( ! -e 't/xr/foo.tmp.old', "commit with TMPLNKEXT blatted stray foo.tmp.old" );
ok( ! -e 't/xr/foo.linky',   "commit with TMPLNKEXT blatted stray foo.linky" );
is( readfile('t/xr/foo.tmp.lnk'), 'this is foo.tmp.lnk', "commit with TMPLNKEXT left foo.tmp.lnk" );
is( readfile('t/xr/foo'),         'this is bar',         "commit with TMPLNKEXT updated foo" );

unlink qw(t/xr/foo t/xr/foo.tmp.lnk);
rmdir 't/xr' or die "rmdir: $!";

