#!/usr/bin/perl

use strict;
use warnings;

use Errno qw(EAGAIN ECHILD EINTR EWOULDBLOCK);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use IO::Select;
use POSIX qw(WNOHANG _exit);
use Time::HiRes qw(CLOCK_MONOTONIC clock_gettime);

sub invalid_invocation {
    exit 1;
}

@ARGV >= 8 or invalid_invocation();
my (
    $timeout_option,
    $timeout_text,
    $grace_option,
    $grace_text,
    $maximum_output_option,
    $maximum_output_text,
    $separator,
) = splice @ARGV, 0, 7;

$timeout_option eq '--timeout-seconds' or invalid_invocation();
$grace_option eq '--term-grace-seconds' or invalid_invocation();
$maximum_output_option eq '--max-output-bytes' or invalid_invocation();
$separator eq '--' or invalid_invocation();
@ARGV >= 1 or invalid_invocation();

my $decimal_pattern = qr/\A(?:0|[1-9][0-9]*)(?:\.[0-9]+)?\z/;
$timeout_text =~ $decimal_pattern or invalid_invocation();
$grace_text =~ $decimal_pattern or invalid_invocation();
$maximum_output_text =~ /\A(?:0|[1-9][0-9]*)\z/
    or invalid_invocation();

my $timeout_seconds = 0 + $timeout_text;
my $termination_grace_seconds = 0 + $grace_text;
my $maximum_output_bytes = 0 + $maximum_output_text;

$timeout_seconds > 0 && $timeout_seconds <= 300
    or invalid_invocation();
$termination_grace_seconds > 0 &&
    $termination_grace_seconds <= 30
    or invalid_invocation();
$maximum_output_bytes >= 2 && $maximum_output_bytes <= 4_097
    or invalid_invocation();
$ARGV[0] =~ m{\A/} or invalid_invocation();

my @command = @ARGV;

%ENV = ();

pipe(my $output_reader, my $output_writer) or exit 1;
binmode($output_reader);
binmode($output_writer);
binmode(STDOUT);

my $reader_flags = fcntl($output_reader, F_GETFL, 0);
defined($reader_flags) or exit 1;
fcntl($output_reader, F_SETFL, $reader_flags | O_NONBLOCK)
    or exit 1;

my $interrupted = 0;
$SIG{CHLD} = 'DEFAULT';
$SIG{PIPE} = 'IGNORE';
for my $signal (qw(HUP INT TERM)) {
    $SIG{$signal} = sub {
        $interrupted = 1;
    };
}

my $child_pid = fork();
defined($child_pid) or exit 1;

if ($child_pid == 0) {
    $SIG{CHLD} = 'DEFAULT';
    $SIG{HUP} = 'DEFAULT';
    $SIG{INT} = 'DEFAULT';
    $SIG{PIPE} = 'DEFAULT';
    $SIG{TERM} = 'DEFAULT';

    close($output_reader);
    open(STDIN, '<', '/dev/null') or _exit(126);
    open(STDOUT, '>&', $output_writer) or _exit(126);
    open(STDERR, '>', '/dev/null') or _exit(126);
    close($output_writer);

    opendir(my $descriptor_directory, '/dev/fd') or _exit(126);
    my $descriptor_directory_fd = fileno($descriptor_directory);
    defined($descriptor_directory_fd) or _exit(126);
    my @inherited_descriptors = grep {
        /\A[0-9]+\z/ &&
            $_ >= 3 &&
            $_ != $descriptor_directory_fd
    } readdir($descriptor_directory);
    for my $descriptor (@inherited_descriptors) {
        POSIX::close(0 + $descriptor) == 0 or _exit(126);
    }
    closedir($descriptor_directory) or _exit(126);

    {
        no warnings 'exec';
        exec { $command[0] } @command;
    }
    _exit(127);
}

close($output_writer);

my $buffer = '';
my $read_chunk = '';
my $child_status;
my $child_reaped = 0;
my $output_eof = 0;
my $reader_open = 1;
my $failed = 0;
my $term_sent = 0;
my $kill_sent = 0;
my $termination_deadline;

sub wipe_scalar {
    return if !defined($_[0]) || length($_[0]) == 0;
    substr($_[0], 0, length($_[0]), "\0" x length($_[0]));
    $_[0] = '';
}

my $discard_output = sub {
    $failed = 1;
    wipe_scalar($buffer);
    wipe_scalar($read_chunk);
};

my $reap_without_blocking = sub {
    while (!$child_reaped) {
        my $waited_pid = waitpid($child_pid, WNOHANG);
        if ($waited_pid == $child_pid) {
            $child_status = $?;
            $child_reaped = 1;
            if ($child_status != 0) {
                $discard_output->();
            }
            return;
        }
        if ($waited_pid == 0) {
            return;
        }
        if ($! == EINTR) {
            next;
        }

        $child_reaped = 1;
        $discard_output->();
        return;
    }
};

my $begin_termination = sub {
    my ($now) = @_;
    $discard_output->();
    return if $child_reaped || $term_sent;

    kill('TERM', $child_pid);
    $term_sent = 1;
    $termination_deadline = $now + $termination_grace_seconds;
};

my $force_termination = sub {
    return if $child_reaped || $kill_sent;

    kill('KILL', $child_pid);
    $kill_sent = 1;
};

my $close_reader = sub {
    return if !$reader_open;
    close($output_reader);
    $reader_open = 0;
    $output_eof = 1;
};

my $read_once = sub {
    return 'closed' if !$reader_open;

    my $bytes_read = sysread(
        $output_reader,
        $read_chunk,
        $maximum_output_bytes + 1,
    );
    if (!defined($bytes_read)) {
        return 'retry' if $! == EINTR;
        return 'blocked' if $! == EAGAIN || $! == EWOULDBLOCK;
        return 'error';
    }
    if ($bytes_read == 0) {
        $close_reader->();
        return 'closed';
    }

    if (!$failed) {
        if (length($buffer) + $bytes_read > $maximum_output_bytes) {
            $discard_output->();
        } else {
            $buffer .= $read_chunk;
        }
    }
    wipe_scalar($read_chunk);
    return 'read';
};

my $loop_completed = eval {
    my $selector = IO::Select->new($output_reader);
    my $lookup_deadline =
        clock_gettime(CLOCK_MONOTONIC) + $timeout_seconds;

    while (!$child_reaped || !$output_eof) {
        $reap_without_blocking->();
        my $now = clock_gettime(CLOCK_MONOTONIC);

        if ($interrupted && !$failed) {
            $begin_termination->($now);
        }
        if (!$child_reaped && !$term_sent && $now >= $lookup_deadline) {
            $begin_termination->($now);
        }
        if (
            !$child_reaped &&
            $term_sent &&
            !$kill_sent &&
            $now >= $termination_deadline
        ) {
            $force_termination->();
        }

        my $read_result = $read_once->();
        if ($read_result eq 'error') {
            $begin_termination->($now);
        } elsif ($failed && !$term_sent && !$child_reaped) {
            $begin_termination->($now);
        }

        if ($child_reaped && !$output_eof &&
            $read_result eq 'blocked')
        {
            $discard_output->();
            $selector->remove($output_reader);
            $close_reader->();
        }

        last if $child_reaped && $output_eof;

        my $delay = 0.1;
        if (!$child_reaped) {
            my $next_deadline;
            if (!$term_sent) {
                $next_deadline = $lookup_deadline;
            } elsif (!$kill_sent) {
                $next_deadline = $termination_deadline;
            }
            if (defined($next_deadline)) {
                my $until_deadline = $next_deadline - $now;
                $until_deadline = 0 if $until_deadline < 0;
                $delay = $until_deadline if $until_deadline < $delay;
            } elsif ($kill_sent) {
                $delay = 0.05;
            }
        } else {
            $delay = 0;
        }

        if ($reader_open) {
            $selector->can_read($delay);
        } elsif ($delay > 0) {
            Time::HiRes::sleep($delay);
        }
    }

    1;
};

if (!$loop_completed) {
    $discard_output->();
}

if (!$child_reaped) {
    my $now = clock_gettime(CLOCK_MONOTONIC);
    if (!$term_sent) {
        $begin_termination->($now);
    }
    $close_reader->();

    while (!$child_reaped && !$kill_sent) {
        $reap_without_blocking->();
        last if $child_reaped;

        $now = clock_gettime(CLOCK_MONOTONIC);
        if ($now >= $termination_deadline) {
            $force_termination->();
            last;
        }
        my $delay = $termination_deadline - $now;
        $delay = 0.01 if $delay > 0.01;
        Time::HiRes::sleep($delay) if $delay > 0;
    }

    while (!$child_reaped) {
        my $waited_pid = waitpid($child_pid, 0);
        if ($waited_pid == $child_pid) {
            $child_status = $?;
            $child_reaped = 1;
            last;
        }
        next if $waited_pid == -1 && $! == EINTR;

        $child_reaped = 1;
        $discard_output->();
    }
}

$close_reader->();
wipe_scalar($read_chunk);

my $success =
    $loop_completed &&
    !$failed &&
    !$interrupted &&
    $child_reaped &&
    defined($child_status) &&
    $child_status == 0 &&
    length($buffer) >= 2 &&
    length($buffer) <= $maximum_output_bytes &&
    substr($buffer, -1, 1) eq "\n" &&
    index($buffer, "\0") == -1;

my $write_succeeded = 0;
if ($success) {
    my $offset = 0;
    my $length = length($buffer);
    $write_succeeded = 1;
    while ($offset < $length) {
        my $written = syswrite(
            STDOUT,
            $buffer,
            $length - $offset,
            $offset,
        );
        if (!defined($written)) {
            next if $! == EINTR;
            $write_succeeded = 0;
            last;
        }
        if ($written == 0) {
            $write_succeeded = 0;
            last;
        }
        $offset += $written;
    }
}

wipe_scalar($buffer);
exit($success && $write_succeeded ? 0 : 1);
