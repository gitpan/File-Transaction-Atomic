
use strict;
BEGIN { $^W = 1; }
require 't/ft_test_util.pl';

use Test::More tests => 48;

use subs qw(
    File::Transaction::Atomic::link
    File::Transaction::Atomic::symlink
    File::Transaction::Atomic::unlink
    File::Transaction::Atomic::rename
    File::Transaction::Atomic::mkdir
    File::Transaction::Atomic::rmdir
);
use File::Transaction::Atomic;

use vars qw($fileop_count);
sub File::Transaction::Atomic::link {
    ok( files_consistent(), "valid state after $fileop_count fileops" );
    $fileop_count++;
    CORE::link($_[0], $_[1]);
}
sub File::Transaction::Atomic::symlink {
    ok( files_consistent(), "valid state after $fileop_count fileops" );
    $fileop_count++;
    CORE::symlink($_[0], $_[1]);
}
sub File::Transaction::Atomic::unlink {
    ok( files_consistent(), "valid state after $fileop_count fileops" );
    $fileop_count++;
    CORE::unlink(@_);
}
sub File::Transaction::Atomic::rename {
    ok( files_consistent(), "valid state after $fileop_count fileops" );
    $fileop_count++;
    CORE::rename($_[0], $_[1]);
}
sub File::Transaction::Atomic::mkdir {
    ok( files_consistent(), "valid state after $fileop_count fileops" );
    $fileop_count++;
    CORE::mkdir($_[0], $_[1]);
}
sub File::Transaction::Atomic::rmdir {
    ok( files_consistent(), "valid state after $fileop_count fileops" );
    $fileop_count++;
    CORE::rmdir($_[0]);
}

$fileop_count = 0;
my $commit_done = 0;

my $fta = setup_test_fta();
$fta->commit;

ok( files_consistent(), "valid state after last fileop" );
ok( $commit_done, "commit done after commit() call" );

deldir('t/xa');
    
sub setup_test_fta {
    -d 't/xa' and deldir('t/xa');
    mkdir 't/xa', 0755 or die "mkdir t/xa: $!";

    my $fta = File::Transaction::Atomic->new;

    # file one - normal
    writefile('t/xa/one', 'onefoo');
    $fta->linewise_rewrite('t/xa/one', sub { s/foo/bar/ });

    # file two - old file absent
    writefile('t/xa/two.tmp', 'twobar');
    $fta->addfile('t/xa/two', 't/xa/two.tmp');
    
    # file three - old file broken symlink
    writefile('t/xa/three.tmp', 'threebar');
    symlink('nonexistent', 't/xa/three') or die "symlink: $!";
    $fta->addfile('t/xa/three', 't/xa/three.tmp');

    # file four - old file good symlink
    writefile('t/xa/four.thefile', 'fourfoo');
    symlink('four.thefile', 't/xa/four') or die "symlink: $!";
    $fta->linewise_rewrite('t/xa/four', sub { s/foo/bar/ });
  
    return $fta;
}
    
sub files_consistent {
    my $one   = readfile('t/xa/one');
    my $two   = readfile('t/xa/two');
    my $three = readfile('t/xa/three');
    my $four  = readfile('t/xa/four');

    if ( $one eq 'onefoo' and
         ! defined($two)  and
         ! defined($three) and
         $four eq 'fourfoo'
       ) {    
         $commit_done and die "eek, commit reversed!";
         return 1;
    }

    if ( $one   eq 'onebar'   and
         $two   eq 'twobar'   and
         $three eq 'threebar' and
         $four  eq 'fourbar'
       ) {
         $commit_done = 1;
         return 1;
    }

    return 0;
}

