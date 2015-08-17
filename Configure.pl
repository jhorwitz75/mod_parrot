# $Id: Configure.pl 642 2009-06-09 15:45:27Z jhorwitz $

# Copyright (c) 2004, 2005, 2007 Jeff Horwitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# mod_parrot configuration script

use Getopt::Long;

# parts stolen from mod_perl
my %threaded_mpms = map { $_ => 1}
    qw(worker winnt beos mpmt_os2 netware leader perchild threadpool);

sub mpm_is_threaded
{
    return $threaded_mpms{$_[0]};
}

my $parrot_build_dir = '../parrot';
my $apxs = '/usr/local/apache/bin/apxs';
my $perl = $^X;

my $res = GetOptions(
    'parrot-build-dir=s' => \$parrot_build_dir,
    'apxs=s' => \$apxs
);

$res || die "error while parsing options";

sub parrot_config
{
    my $config = shift;
    my $value = `$parrot_build_dir/parrot_config $config`;
    chomp($value);
    return $value;
}

$| = 1;

print "\n";

# defines to pass to compiler
my $defines;

# debugging flags for developers
my $debug = $ENV{'MP_DEBUG'};

# apache configs
my $apache_include_dir = `$apxs -q INCLUDEDIR`;
my $apr_include_dir = `$apxs -q APR_INCLUDEDIR`;
my $apu_include_dir = `$apxs -q APU_INCLUDEDIR`;
my $ap_cflags = `$apxs -q CFLAGS`;
my $extra_cppflags = `$apxs -q EXTRA_CPPFLAGS`;
my $libexec_dir = `$apxs -q LIBEXECDIR`;
my $cc = `$apxs -q CC`;
my $libtool = `$apxs -q LIBTOOL`;

# discover mpm -- we don't use this yet, but we might
my $mpm = `$apxs -q MPM_NAME`;
$mpm or die "Couldn't find Apache MPM";
chomp($mpm);
print "Configuring mod_parrot for $mpm MPM.\n";

# we can't use the config verbatim -- apxs chokes on it, so we use what we can
chomp($ap_cflags);
my $cflags = " -I$parrot_build_dir/include -Iinclude $ap_cflags";
$cflags .= " -DMPM_IS_THREADED" if (mpm_is_threaded($mpm));
my $libs = parrot_config('libs') . " -lparrot";
my $blib_dir = parrot_config('blib_dir');
my $ldflags = parrot_config('libparrot_ldflags') .
    parrot_config('libparrot_linkflags') .
    " -R$parrot_build_dir/$blib_dir";

print "Generating Makefile...";
my $template;
{
    open(MAKEFILE_IN, "Makefile.in") or die $!;
    local $/;
    $template = <MAKEFILE_IN>;
    close(MAKEFILE_IN);
}
$template =~ s/\@CC\@/$cc/g;
$template =~ s/\@LIBTOOL\@/$libtool/g;
$template =~ s/\@DEFINES\@/$defines/g;
$template =~ s/\@CFLAGS\@/$cflags/g;
$template =~ s/\@DEBUG\@/$debug/g;
$template =~ s/\@EXTRA_CPPFLAGS\@/$extra_cppflags/g;
$template =~ s/\@LDFLAGS\@/$ldflags/g;
$template =~ s/\@LIBS\@/$libs/g;
$template =~ s/\@LIBEXECDIR\@/$libexec_dir/g;
$template =~ s/\@APXS\@/$apxs/g;
$template =~ s/\@PERL\@/$perl/g;
$template =~ s/\@PARROT_SOURCE\@/$parrot_build_dir/g;
$template =~ s/\@PARROT_BLIB_DIR\@/$parrot_build_dir\/$blib_dir/g;
$template =~ s/\@PARROT\@/$parrot_build_dir\/parrot/g;
$template =~ s/\@APACHE_INCLUDE_DIR\@/$apache_include_dir/g;
$template =~ s/\@APR_INCLUDE_DIR\@/$apr_include_dir/g;
$template =~ s/\@APU_INCLUDE_DIR\@/$apu_include_dir/g;
$template =~ s/\@CALLING_CONVENTIONS\@/$calling_conventions/g;
open(MAKEFILE, ">Makefile") or die $!;
print MAKEFILE $template;
close(MAKEFILE);
print "done.\n";

print "Creating testing infrastructure...";
eval "use Apache::Test 1.26";
unless ($@) {
    # don't use installed mod_parrot
    package ModParrot::TestRun;
    use base Apache::TestRunParrot;
    use Apache::TestConfigParrot;

    sub pre_configure
    {
        my $self = shift;
        Apache::TestConfig::autoconfig_skip_module_add('mod_parrot.c');
        $self->SUPER::pre_configure();
    }

    package main;
    use Apache::TestMM;
    push(@ARGV, '-apxs', $apxs);
    push(@ARGV, '-defines', "PARROT_BUILD_DIR=$parrot_build_dir");
    Apache::TestMM::filter_args();
    ModParrot::TestRun->generate_script();
    print "done.\n";
}
else {
    print "Apache::Test missing or earlier than 1.26.\n";
    print "Skipping test setup!\n";
}

print "\nType 'make' to build mod_parrot.\n\n";
