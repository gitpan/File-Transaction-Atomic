
use strict;
BEGIN { $^W = 1; }

sub writefile {
    my ($filename, $contents) = @_;

    open WF, ">$filename" or die "open >$filename: $!";
    print WF $contents    or die "write to $filename: $!";
    close WF              or die "close $filename: $!";
}

sub readfile {
    my ($filename) = @_;

    open RF, "<$filename" or return undef;
    local $/;
    my $contents = <RF>;
    close RF;
    return $contents;
}

sub deldir {
    my ($dir) = @_;

    opendir D, $dir or die "opendir: $!";
    while( defined( my $f = readdir D) ) {
        next if $f eq '.'  or $f eq '..';
        next unless $f =~ /^([\w\.\-]+)$/;
        unlink "$dir/$1" or die "unlink [$dir/$1]: $!";
    }
    closedir D;
    rmdir $dir or die "rmdir: $!";
}

1;

