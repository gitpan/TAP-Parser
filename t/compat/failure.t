#!/usr/bin/perl -w

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', 'lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

use Test::More tests => 6;
use File::Spec;

BEGIN {
    use_ok('TAP::Harness::Compatible');
}

TODO: {
    todo_skip 'Harness compatibility incomplete', 5;
    local $TODO = 'Harness compatibility incomplete';
    my $died;
    sub prepare_for_death { $died = 0; }
    sub signal_death      { $died = 1; }

    my $Curdir = File::Spec->curdir;
    my $SAMPLE_TESTS =
      $ENV{PERL_CORE}
      ? File::Spec->catdir( $Curdir, 'lib', 'sample-tests' )
      : File::Spec->catdir( $Curdir, 't',   'sample-tests' );

    PASSING: {
        local $SIG{__DIE__} = \&signal_death;
        prepare_for_death();
        eval { _runtests( File::Spec->catfile( $SAMPLE_TESTS, "simple" ) ) };
        ok( !$@, "simple lives" );
        is( $died, 0, "Death never happened" );
    }

    FAILING: {
        local $SIG{__DIE__} = \&signal_death;
        prepare_for_death();
        eval { _runtests( File::Spec->catfile( $SAMPLE_TESTS, "too_many" ) ) };
        ok( $@, "$@" );
        ok( $@ =~ m[Failed 1/1], "too_many dies" );
        is( $died, 1, "Death happened" );
    }
}

sub _runtests {
    my (@tests) = @_;
    my $old_val = $ENV{PERL_TEST_HARNESS_DUMP_TAP};
    $ENV{PERL_TEST_HARNESS_DUMP_TAP} = 0;
    runtests(@tests);
    $ENV{PERL_TEST_HARNESS_DUMP_TAP} = $old_val;
}
