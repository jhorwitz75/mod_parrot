use Test::More;
use File::Spec;

# get NCI signatures
open(NCI, 'call_list.txt') or die $!;
my @sigs = grep(!/^#/, <NCI>);
close(NCI);

plan tests => scalar @sigs + 1;

# test parrot path
# WOW, what a kludge.  We load Apache::Test to find the parrot build directory,
# but since this will conflict with Test::More, we do it in a closure using
# require.
my $parrot_build_dir;
my $defines;
{
    require Apache::Test;
    $defines = Apache::Test::vars('defines');
}
if (defined($defines) && $defines =~ /PARROT_BUILD_DIR=(.+)/) {
    $parrot_build_dir = $1;
}
if (!defined($parrot_build_dir) || system("$parrot_build_dir/parrot -V")) {
    print "Bail Out! Parrot executable not found";
    exit(0);
}
pass("find parrot executable");

# test each signature
my @bad;
my $nci_sig_test = File::Spec->catfile(qw(t src nci_sig_test.pir));
foreach my $sig (@sigs) {
    $sig =~ s/\s//g;
    if (system("$parrot_build_dir/parrot", $nci_sig_test, $sig)) {
        push(@bad, $sig);
        fail($sig);
    }
    else {
        pass($sig);
    }
}

if ($#bad > -1) {
    print "Bail Out! Parrot is missing NCI signatures: ", join(', ', @bad),"\n";
}
