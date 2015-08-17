#!/usr/bin/perl

# Copyright (c) 2005, 2007, 2008 Ian Joyce, Jeff Horwitz
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

use strict;
use warnings;
use Getopt::Long;

use lib qw(build/lib build/lib/Generator);

use Generator::ApacheConstants;
use Generator::ApacheRequestRec;
use Generator::ApacheServerRec;
use Generator::ModParrotConstants;

my $apache_include_dir = '/usr/local/apache2/include/';

GetOptions(
    'apache-include-dir=s' => \$apache_include_dir,
) || die 'Could not get command line args.';

# This is where the generated source lives.
eval {
    mkdir 'build/src';
    mkdir 'build/src/nci';
    mkdir 'build/src/pir';
};

if ($@ && $@ !~ /File exists/) {
    die 'Unable to create the directories needs to store the generated source: ' . $@;
}

my %args = (
   'apache_include_dir'  => $apache_include_dir . '/',
   'nci_src'             => 'build/src/nci/',
   'pir_src'             => 'build/src/pir/',
);

ModParrot::Config::Generator::ApacheConstants->new(%args)->run();
ModParrot::Config::Generator::ModParrotConstants->new(%args)->run();
ModParrot::Config::Generator::ApacheRequestRec->new(%args)->run();
ModParrot::Config::Generator::ApacheServerRec->new(%args)->run();
