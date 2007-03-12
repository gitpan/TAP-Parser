package TAP::Parser::Iterator;

use strict;
use vars qw($VERSION);

=head1 NAME

TAP::Parser::Iterator - Internal TAP::Parser Iterator

=head1 VERSION

Version 0.51

=cut

$VERSION = '0.51';

=head1 SYNOPSIS

  use TAP::Parser::Iterator;
  my $it = TAP::Parser::Iterator->new(\*TEST);
  my $it = TAP::Parser::Iterator->new(\@array);

  my $line = $it->next;

Originally ripped off from C<Test::Harness>.

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator wrapper for arrays and filehandles.

=head2 new()

Create an iterator.

=head2 next()

Iterate through it, of course.

=head2 next_raw()

Iterate raw input without applying any fixes for quirky input syntax.

=cut

sub new {
    my ( $proto, $thing ) = @_;

    my $ref = ref $thing;
    if ( $ref eq 'GLOB' || $ref eq 'IO::Handle' ) {

        # we may eventually allow a 'fast' switch which can read the entire
        # stream into an array.  This seems to speed things up by 10 to 12
        # per cent.  Should not be used with infinite streams.
        return TAP::Parser::Iterator::FH->new($thing);
    }
    elsif ( $ref eq 'ARRAY' ) {
        return TAP::Parser::Iterator::ARRAY->new($thing);
    }
    else {
        die "Can't iterate with a ", ref $thing;
    }
}

eval { require POSIX; &POSIX::WEXITSTATUS(0) };
if ($@) {
    *_wait2exit = sub { $_[1] >> 8 };
}
else {
    *_wait2exit = sub { POSIX::WEXITSTATUS( $_[1] ) }
}

package TAP::Parser::Iterator::FH;

use vars qw($VERSION @ISA);
@ISA     = 'TAP::Parser::Iterator';
$VERSION = '0.51';

sub new {
    my ( $class, $thing ) = @_;
    bless {
        fh   => $thing,
        exit => undef,
    }, $class;
}

##############################################################################

=head3 C<pid>

  my $pid = $source->pid;
  $source->pid($pid);

Getter/Setter for the pid of the process the filehandle reads from.  Only
makes sense when a filehandle is being used for the iterator.

=cut

sub pid {
    my $self = shift;
    return $self->{pid} unless @_;
    $self->{pid} = shift;
    return $self;
}

sub wait { $_[0]->{wait} }
sub exit { $_[0]->{exit} }

sub next_raw {
    my $self = shift;
    my $fh   = $self->{fh};

    if ( defined( my $line = <$fh> ) ) {
        chomp $line;
        return $line;
    }
    else {
        $self->_finish;
        return;
    }
}

sub next {
    my $self = shift;
    my $line = $self->next_raw;

    # vms nit:  When encountering 'not ok', vms often has the 'not' on a line
    # by itself:
    #   not
    #   ok 1 - 'I hate VMS'
    if ( defined $line && $line =~ /^\s*not\s*$/ ) {
        $line .= ( $self->next_raw || '' );
    }
    return $line;
}

sub _finish {
    my $self = shift;

    my $status = $?;

    # If we have a subprocess we need to wait for it to terminate
    if ( defined $self->{pid} ) {
        if ( $self->{pid} == waitpid( $self->{pid}, 0 ) ) {
            $status = $?;
        }
    }

    close $self->{fh};

    $self->{next} = undef;
    $self->{wait} = $status;
    $self->{exit} = $self->_wait2exit($status);
    return $self;
}

package TAP::Parser::Iterator::ARRAY;

use vars qw($VERSION @ISA);
@ISA     = 'TAP::Parser::Iterator';
$VERSION = '0.51';

sub new {
    my ( $class, $thing ) = @_;
    chomp @$thing;
    bless {
        idx   => 0,
        array => $thing,
        exit  => undef,
    }, $class;
}

sub wait { shift->exit }

sub exit {
    my $self = shift;
    return 0 if $self->{idx} >= @{ $self->{array} };
    return;
}

sub next {
    my $self = shift;
    return $self->{array}->[ $self->{idx}++ ];
}

sub next_raw { shift->next }

1;