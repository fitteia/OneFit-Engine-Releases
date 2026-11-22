#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use FindBin qw($Bin);

# Exercise real Git repositories without network access or publication.
my $root = tempdir('ofe-release-test-XXXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $sequence = 0;
sub run {
    my ($cwd, @command) = @_;
    my $output = "$root/output-" . ++$sequence;
    my $pid = fork();
    die "fork: $!" unless defined $pid;
    if (!$pid) {
        chdir $cwd or die "chdir $cwd: $!";
        open STDOUT, '>', $output or die "open output: $!";
        open STDERR, '>&', \*STDOUT or die "redirect stderr: $!";
        exec @command;
        die "exec $command[0]: $!";
    }
    waitpid($pid, 0);
    my $status = $?;
    open my $fh, '<', $output or die "read output: $!";
    local $/;
    my $text = <$fh> // '';
    close $fh;
    return ($status & 127 ? 128 + ($status & 127) : $status >> 8, $text);
}
sub git {
    my ($cwd, @args) = @_;
    my ($code, $text) = run($cwd, 'git', @args);
    die "git @args failed: $text" if $code;
    chomp $text;
    return $text;
}
sub write_file {
    my ($path, $text) = @_;
    open my $fh, '>', $path or die "write $path: $!";
    print {$fh} $text;
    close $fh or die "close $path: $!";
}
sub read_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "read $path: $!";
    local $/;
    return <$fh> // '';
}
sub fixture {
    my $dir = tempdir('case-XXXXXXXX', DIR => $root);
    my $remote = "$dir/remote.git";
    my $repo = "$dir/repo";
    git($dir, 'init', '--bare', $remote);
    git($dir, 'init', '-b', 'main', $repo);
    git($repo, 'config', 'user.email', 'test@example.invalid');
    git($repo, 'config', 'user.name', 'Release test');
    git($repo, 'config', 'commit.gpgsign', 'false');
    git($repo, 'commit', '--allow-empty', '-m', 'first');
    my $first = git($repo, 'rev-parse', 'HEAD');
    git($repo, 'commit', '--allow-empty', '-m', 'second');
    my $second = git($repo, 'rev-parse', 'HEAD');
    git($repo, 'remote', 'add', 'origin', $remote);
    git($repo, 'push', 'origin', 'main');
    return ($dir, $repo, $remote, $first, $second);
}
sub check_tag {
    my ($remote, $tag, $expected, $missing) = @_;
    return run($root, 'bash', '-c',
        'source "$1"; check_release_tag "$2" "$3" "$4" "$5"',
        'test', "$Bin/check-release-tag.sh", $remote, $tag, $expected, $missing // 'required');
}
{
    my ($dir, $repo, $remote, $first, $second) = fixture();
    for my $tag ('light', 'annotated') {
        git($repo, 'tag', ($tag eq 'annotated' ? ('-a', '-m', 'release') : ()), $tag, $first);
        git($repo, 'push', 'origin', "refs/tags/$tag");
        my ($code, $text) = check_tag($remote, $tag, $first);
        is($code, 0, "$tag tag matches its commit") or diag $text;
        ($code, $text) = check_tag($remote, $tag, $second);
        isnt($code, 0, "$tag mismatch rejected");
        like($text, qr/publication stopped/, "$tag mismatch explains refusal");
    }
    my ($code) = check_tag($remote, 'missing', $second);
    isnt($code, 0, 'required missing tag rejected');
    ($code) = check_tag($remote, 'missing', $second, 'allow-missing');
    is($code, 0, 'new release may have no tag yet');
    ($code) = check_tag("$dir/absent.git", 'missing', $second, 'allow-missing');
    isnt($code, 0, 'unreachable remote never treated as missing tag');
}
sub publish {
    my ($remote_target, $final_target, $exists) = @_;
    my ($dir, $repo, $remote, $first, $second) = fixture();
    if ($remote_target) {
        git($repo, 'tag', 'suite-test', $remote_target eq 'first' ? $first : $second);
        git($repo, 'push', 'origin', 'refs/tags/suite-test');
    }
    make_path("$repo/scripts", "$repo/build/test", "$dir/bin");
    write_file("$repo/scripts/check-release-tag.sh", read_file("$Bin/check-release-tag.sh"));
    write_file("$dir/bin/gh", <<'STUB');
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
if [ "$1 $2" = 'release view' ]; then exit "$EXISTS_CODE"; fi
if [ "$1" = api ]; then echo "$FINAL_COMMIT"; fi
STUB
    chmod 0755, "$dir/bin/gh" or die "chmod: $!";
    my $source = read_file("$Bin/make-suite-release.sh");
    my $start = index($source, '# The release tag must hold');
    die 'publication gate not found' if $start < 0;
    my $gate = "set -euo pipefail\nsuite=suite-test\nhere_repo=test/repo\nstage=build/test\nall=asset\nprerelease=\n" . substr($source, $start);
    local $ENV{PATH} = "$dir/bin:$ENV{PATH}";
    local $ENV{CALLS} = "$dir/calls";
    local $ENV{FINAL_COMMIT} = ($final_target // '') eq 'first' ? $first : $second;
    local $ENV{EXISTS_CODE} = $exists ? '0' : '1';
    my ($code, $text) = run($repo, 'bash', '-c', $gate);
    return ($code, $text, -e "$dir/calls" ? read_file("$dir/calls") : '');
}
{
    my ($code, $text, $calls) = publish('first', undef, 1);
    isnt($code, 0, 'mismatched suite tag rejected');
    like($text, qr/publication stopped/, 'suite mismatch explains refusal');
    is($calls, '', 'no GitHub calls before mismatched tag rejection');
    ($code, $text, $calls) = publish('second', undef, 1);
    is($code, 0, 'matching release resumes') or diag $text;
    like($calls, qr/release upload/, 'matching release uploads assets');
    ($code, $text, $calls) = publish(undef, undef, 0);
    is($code, 0, 'new untagged release can be created') or diag $text;
    like($calls, qr/release create/, 'new release takes create path');
    ($code, $text, $calls) = publish('second', 'first', 1);
    isnt($code, 0, 'final verification mismatch fails');
    like($text, qr/Verification failed/, 'final mismatch reported');
}
done_testing();
