package File::Transaction::Atomic;
use strict;

use vars qw($VERSION);
$VERSION = '0.03';
# $Rev: 37 $

use Cwd 'abs_path';
use DirHandle;
use File::Transaction;
use base qw(File::Transaction);

=head1 NAME

File::Transaction::Atomic - atomic change to a group of files

=head1 SYNOPSIS

  #
  # In this example, we wish to replace the word 'foo' with the
  # word 'bar' in several files, with no risk of ending up with
  # the replacement done in some files but not in others.
  #

  use File::Transaction::Atomic;

  my $ft = File::Transaction::Atomic->new;

  eval {
      foreach my $file (@list_of_file_names) {
          $ft->linewise_rewrite($file, sub {
               s#\bfoo\b#bar#g;
          });
      }
  };

  if ($@) {
      $ft->revert;
      die "update aborted: $@";
  }
  else {
      $ft->commit;
  }


=head1 DESCRIPTION

This class is a child of L<File::Transaction> that reimplements
the commit() method to give a truly atomic commit operation, at
the cost of greater overhead and dependence on C<UNIX> file
system semantics.

During the preparation for the commit, each file is atomically
replaced with a symbolic link that points to the same file under
another name.  The commit is only really atomic if those operations
are deemed not to constitute changes.

This module's commit() method performs roughly ten times as many
file and directory operations as that of L<File::Transaction>,
and the code here is much more complex (and hence more likely to
contain serious bugs) than that found in L<File::Transaction>.

You should only be using this module if the risk of a partial
commit described in L<File::Transaction> is unacceptable in your
application.

=head1 METHODS

=over

=item commit ( [WORKDIR] [,OLDEXT] [,TMPLNKEXT] )

Performs an atomic commit.

The commit() method needs to create a temporary work directory
and populate it with subdirectories and symlinks, and WORKDIR
gives the name of the directory to use.  If the WORKDIR directory
exists, the commit() method assumes that it was left over from a
previous invocation of the C<File::Transaction::Atomic> commit()
method that failed part way through, and tidies up accordingly.
The default workdir is F<.ftawork> in the current directory.

The OLDEXT parameter sets the string to append to the name of
each file to generate the name of a temporary additional hardlink
to each old version.  Any existing file of that name will be
removed.  The default OLDEXT is the TMPEXT value that was passed
to the object's constructor with C<.old> appended to it.

The TMPLNKEXT parameter sets the string to append to the name of
each file to generate a temporary name for the symlink that will
replace the live file during the preparation for the commit.
Any existing file of that name will be removed.  The default
TMPLNKEXT is the TMPEXT value that was passed to the object's
constructor with C<.lnk> appended to it.

=cut

sub commit {
    my ($self, $workdir, $oldext, $tmplnkext) = @_;
    defined $workdir   or $workdir   = '.ftawork';
    defined $oldext    or $oldext    = $self->{TMPEXT} . '.old';
    defined $tmplnkext or $tmplnkext = $self->{TMPEXT} . '.lnk';

    $workdir = $self->_abs_path($workdir);

    #
    # Tidy up any remnants of commit() calls that failed part
    # way through
    #
    if (-e $workdir) {
        $self->_render_workdir_unused($workdir);
        $self->_delete_workdir($workdir);
    }

    #
    # Prepare for commit
    #
    $self->_mkdir($workdir);
    $self->_mkdir("$workdir/old");
    $self->_mkdir("$workdir/new");
    $self->_symlink('new', "$workdir/tobe");
    $self->_symlink('old', "$workdir/live");

    foreach my $file (@{ $self->{FILES} }) {
        my $livefile = $self->_abs_path($file->{OLD});
        my $newfile  = $self->_abs_path($file->{TMP});
        my $linkname = $self->_encode_filename($livefile);

        $self->_symlink($newfile, "$workdir/new/$linkname");
        
        if (-e $livefile) {
            $self->_symlink("$livefile$oldext", "$workdir/old/$linkname");

            unlink "$livefile$oldext";
            $self->_link($livefile, "$livefile$oldext");
        }

        unlink "$livefile$tmplnkext";
        $self->_symlink("$workdir/live/$linkname", "$livefile$tmplnkext");
        $self->_rename("$livefile$tmplnkext", $livefile);
    }    

    #
    # Commit
    #
    $self->_rename("$workdir/tobe", "$workdir/live");

    #
    # Tidy up
    #
    foreach my $file (@{ $self->{FILES} }) {
        $self->_rename($file->{TMP}, $file->{OLD});
        unlink $file->{OLD} . $oldext;
    }
    $self->_delete_workdir($workdir);
}

=back

=head1 SECURITY CONCERNS

If the commit() method finds that the WORKDIR already exists,
then it trusts the contents of that WORKDIR to the extent that
a malicious WORKDIR could cause commit() to attempt to replace
any file on the system with any other file.  Thus it is a very
bad idea to do something like:

   $fta->commit('/tmp/ftawork');

since that would allow any local user to set up a fake
F</tmp/ftawork> and subvert the commit().

The default WORKDIR of F<.ftawork> is only safe if no untrusted
person can control the creation of files in your current working
directory.

=head1 HOW IT WORKS

The atomic commit works by first replacing each live file with
a symlink to a symlink to the old version, and then atomically
changing the target of another symlink with a rename() system
call, so that all live files suddenly become symlinks to
symlinks to their new versions.

This is best explained with an example: suppose the WORKDIR is
F</workdir> and the files to be updated are F</one/one> and
F</two/two>, with new versions F</one/one.tmp> and
F</two/two.tmp> respectively.

  /one/one       # old version of /one/one
  /one/one.tmp   # new version of /one/one
  /two/two       # old version of /two/two
  /two/two.tmp   # new version of /two/two

First, we do lots of preparation without making any change
to the files.  We create the F</workdir> directory, with
F<old> and F<new> subdirectories.  We make F</workdir/live>
a symbolic link to F<old>, and we make F</workdir/tobe> a
symbolic link to F<new>.  We populate the F<new> directory
with symbolic links to the new versions of the files.  We
create an extra hardlink to each of the old versions of the
files, and populate the F<old> directory with symbolic links
to those old versions.  We generate some symbolic links into
the F</workdir/live> path as well.

After all that, we have:

  /one/one           # old version of /one/one
  /one/one.tmp.old   # old version of /one/one
  /one/one.tmp       # new version of /one/one
  /one/one.tmp.lnk -> /workdir/live/1

  /two/two           # old version of /two/two
  /two/two.tmp.old   # old version of /two/two
  /two/two.tmp       # new version of /two/two
  /two/two.tmp.lnk -> /workdir/live/2

  /workdir
  /workdir/new
  /workdir/new/1 -> /one/one.tmp
  /workdir/new/2 -> /two/two.tmp
  /workdir/old
  /workdir/old/1 -> /one/one.tmp.old
  /workdir/old/2 -> /two/two.tmp.old
  /workdir/tobe -> new
  /workdir/live -> old

Now to start interfering with the files.  We do:

  rename('/one/one.tmp.lnk', '/one/one');

so now we have:

  /one/one -> /workdir/live/1
  /one/one.tmp.old   # old version of /one/one
  /one/one.tmp       # new version of /one/one

  /two/two           # old version of /two/two
  /two/two.tmp.old   # old version of /two/two
  /two/two.tmp       # new version of /two/two
  /two/two.tmp.lnk -> /workdir/live/2

  /workdir
  /workdir/new
  /workdir/new/1 -> /one/one.tmp
  /workdir/new/2 -> /two/two.tmp
  /workdir/old
  /workdir/old/1 -> /one/one.tmp.old
  /workdir/old/2 -> /two/two.tmp.old
  /workdir/tobe -> new
  /workdir/live -> old

The file F</one/one> has the same contents before and after
this rename, since it's now a symlink leading to F</one/one.tmp.old>
by a roundabout route.  If the Perl process dies at this point, we
still have the old versions of both files in place so transaction
semantics haven't been violated.

Next we do the same for the other file, giving us:

  /one/one -> /workdir/live/1
  /one/one.tmp.old   # old version of /one/one
  /one/one.tmp       # new version of /one/one

  /two/two -> /workdir/live/2
  /two/two.tmp.old   # old version of /two/two
  /two/two.tmp       # new version of /two/two

  /workdir
  /workdir/new
  /workdir/new/1 -> /one/one.tmp
  /workdir/new/2 -> /two/two.tmp
  /workdir/old
  /workdir/old/1 -> /one/one.tmp.old
  /workdir/old/2 -> /two/two.tmp.old
  /workdir/tobe -> new
  /workdir/live -> old

We still haven't changed either file.  Now for the commit operation:

  rename('/workdir/tobe', '/workdir/live');

If that rename succeeds then we have:

  /one/one -> /workdir/live/1
  /one/one.tmp.old   # old version of /one/one
  /one/one.tmp       # new version of /one/one

  /two/two -> /workdir/live/2
  /two/two.tmp.old   # old version of /two/two
  /two/two.tmp       # new version of /two/two

  /workdir
  /workdir/new
  /workdir/new/1 -> /one/one.tmp
  /workdir/new/2 -> /two/two.tmp
  /workdir/old
  /workdir/old/1 -> /one/one.tmp.old
  /workdir/old/2 -> /two/two.tmp.old
  /workdir/live -> new

... so now F</one/one> is a roundabout symlink to F</one/one.tmp>
and F</two/two> is a roundabout symlink to F</two/two.tmp>, and
the transaction is committed.  If the Perl process dies at this point, we
have the new versions of both files in place so transaction semantics
haven't been violated.

All that remains is to eliminate those symlink chains and tidy up a
bit:

  rename('/one/one.tmp', '/one/one');
  rename('/two/two.tmp', '/two/two');

and delete the F<.tmp.old> files and F</workdir> and we're done.

=head1 COMPLICATIONS

If the Perl process is killed or a rename() fails while either
of F</one/one> and F</two/two> are symlinks into F</workdir>,
then F</workdir> cannot be deleted or renamed without breaking the
chains of symlinks.

The commit() method needs code to eliminate any such chains before
deleting F</workdir> if it finds that F</workdir> already exists.
That code is implemented in the _render_workdir_unused() private
method, below.

To make things a bit easier for _render_workdir_unused(), the commit
method encodes the full paths to the old versions of the files into the
names of the symlinks in the F<old> and F<new> directories.  Slash
characters are replaced with C<-s> and minus characters are replaced
with C<-m>, so the F</workdir> contents in the example above would
actually be:

  /workdir
  /workdir/new
  /workdir/new/-sone-sone -> /one/one.tmp
  /workdir/new/-stwo-stwo -> /two/two.tmp
  /workdir/old
  /workdir/old/-sone-sone -> /one/one.tmp.old
  /workdir/old/-stwo-stwo -> /two/two.tmp.old
  /workdir/tobe -> new
  /workdir/live -> old

The filenames passed in to the addfile() method may be either absolute
or relative, as may the WORKDIR path.  Since relative symbolic links
are interpreted relative to the directory that holds the symlink rather
than the working directory of the process accessing it, this can lead
to complications.  To simplify matters, this module uses absolute paths
as the targets of all of the symlinks it creates other than the F<live>
and F<tobe> symlinks.

The old versions of the files may not exist.  In this case, the
commit() method installs a broken symlink as the live version of the
file before the commit, and this becomes a working symlink to the new
version at commit time.

=head1 PRIVATE METHODS

These methods should only be accessed from within this module.

=over

=item _render_workdir_unused ( WORKDIR )

Identifies and eliminates any symbolic link chains that lead into
the workdir WORKDIR and out again, so that WORKDIR can be safely
removed.

=cut

sub _render_workdir_unused {
    my ($self, $workdir) = @_;

    # This unlink is here in order to bring us to a crashing
    # halt before doing anything if $workdir is tainted.
    unlink "$workdir/tobe";

    my $d = DirHandle->new("$workdir/live") or return;
    while( defined (my $f = $d->read) ) {
        next if $f eq '.' or $f eq '..';

        my $realfile = readlink "$workdir/live/$f" or next;
        $realfile =~ m#^([^\0]+)$# or die "illegal filename";
        $realfile = $1;

        my $livefile = $self->_decode_linkname($f);
        $livefile =~ m#^([^\0]+)$# or die "illegal filename";
        $livefile = $1;

        next unless -l $livefile;

        if (not -e $livefile) {
            # A broken symlink.  This can happen if there is no
            # old version of the file and the commit() method
            # fails before the commit point.
            unlink $livefile or die "unlink [$livefile]: $!";
        }
        else {
            my $livestat = join ':', (stat $livefile)[0,1];
            my $realstat = join ':', (stat $realfile)[0,1];
            if ($livestat eq $realstat) {
                 # $livefile is a symlink to $realfile via $workdir 
                 $self->_rename($realfile, $livefile);
            }
        }
    }

    unlink "$workdir/live" or die "unlink [$workdir/live]: $!";
}

=item _delete_workdir ( WORKDIR )

Deletes a workdir that has already been rendered unused.

=cut

sub _delete_workdir {
    my ($self, $workdir) = @_;

    unlink "$workdir/tobe", "$workdir/live";
    foreach my $dir ("$workdir/old", "$workdir/new") {
        my $d = DirHandle->new($dir) or next;
        while( defined (my $f = $d->read) ) {
            next if $f eq '.' or $f eq '..';
            $f =~ m#^([^/\0]+)$# or die "illegal filename";
            $f = $1;
            unlink "$dir/$f" or die "unlink [$dir/$f]: $!";
        }
        rmdir $dir or die "rmdir [$dir]: $!";
    }

    rmdir $workdir or die "rmdir [$workdir]: $!";
}

=item _encode_filename ( FILENAME )

Encodes the full path to a file into a string that can be used
as the name of a symbolic link.

=cut

sub _encode_filename {
    my ($self, $filename) = @_;

    $filename =~ s#-#-m#g;
    $filename =~ s#/#-s#g;

    return $filename;
}

=item _decode_linkname ( LINKNAME )

Reverses the encoding performed by _encode_filename().

=cut
 
sub _decode_linkname {
    my ($self, $linkname) = @_;

    $linkname =~ s#-s#/#g;
    $linkname =~ s#-m#-#g;

    return $linkname;
}

=item _rename ( FROM, TO )

Performs a rename() system call, and dies on error.

=cut

sub _rename {
    my ($self, $from, $to) = @_;

    rename $from, $to or die "rename [$from] -> [$to]: $!";
}

=item _link ( FROM, TO )

Performs a link() system call, and dies on error.

=cut

sub _link {
    my ($self, $from, $to) = @_;

    link $from, $to or die "link [$from] -> [$to]: $!";
}

=item _symlink ( FROM, TO )

Performs a symlink() system call, and dies on error.

=cut

sub _symlink {
    my ($self, $from, $to) = @_;

    symlink $from, $to or die "symlink [$from] -> [$to]: $!";
}

=item _mkdir ( DIRNAME )

Creates directory DIRNAME with mode C<0700>.  Dies on error.

=cut

sub _mkdir {
    my ($self, $dir) = @_;

    mkdir $dir, 0700 or die "mkdir [$dir]: $!";
}

=item _abs_path ( FILENAME )

Returns an absolute path to the file FILENAME, which need not
exist.  The return value will be tainted if and only if
FILENAME is tainted.

=cut

sub _abs_path {
    my ($self, $filename) = @_;

    $filename = "./$filename" unless $filename =~ m#/#;
    $filename =~ s#^(.+)/##s;
    my $dirname = $1;

    -d $dirname or die "directory [$dirname] missing";
    
    abs_path($dirname) =~ /(.+)/s or die;
    return "$1/$filename";
}

=back

=head1 SEE ALSO

L<File::Transaction> for a leaner and more portable implementation,
lacking strict atomicity.

L<DBD::SQLite> for a completely different approach to transaction
semantics with atomic commit against filesystem backed data.

=head1 AUTHOR

Nick Cleaton E<lt>nick@cleaton.netE<gt>

=head1 COPYRIGHT

Copyright (C) 2002 Nick Cleaton.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

