# Copyright (c) 2005, 2007 Ian Joyce, Jeff Horwitz
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

package ModParrot::Config::Generator::ModParrotConstants;

use strict;
use warnings;

our $VERSION = '0.01';

use BaseGenerator;

use base 'ModParrot::Config::Generator::BaseGenerator';

sub run
{
    my $self = shift;

    my %constants = $self->parse();

    $self->generate_source(
        $self->to_string($constants{'config'}),
    );
}

sub parse
{
    my $self = shift;

    my %constants;

    # Get constants from modparrot_config.h
    open (MODPARROT_CONFIG_H, 'include/modparrot_config.h')
        or die $!;
    while (<MODPARROT_CONFIG_H>) {
        my $code;
        if (/#define\s+((?:MP|MODPARROT)_\w+)\s+(\d+)/) {
            $constants{'config'}{$1} = $2;
        }
        elsif (/enum\s+(\w+)\s+\{/) {
            $code = $_;
            unless ($code =~ /;\s*$/) {
                local $_;
                while (<MODPARROT_CONFIG_H>) {
                    $code .= $_;
                    last if /;\s*$/;
                }
            }
            $code =~ s:/\*.*?\*/::sg;
            $code =~ s/\s*=\s*\w+//g;
            $code =~ s/^[^\{]*\{//s;
            $code =~ s/\}[^;]*;?//s;
            $code =~ s/^\s*\n//gm;
            my $idx = 0;
            while ($code =~ /\b(\w+)\b,?/g) {
                $constants{'config'}{$1} = $idx++;
            }
        }
    }
    close MODPARROT_CONFIG_H;

    return %constants;
}

sub to_string
{
    my ($self, $constants) = @_;

    my $string = "";
  
    while (my ($k, $v) = each %$constants) {
        $string .= "    table[ \"$k\" ] = $v\n";
    }

    return $string;
}

sub generate_source
{
    my ($self, $config) = @_;

    my $template;
    {
        local $/ = undef;
        $template = <DATA>;
    }

    $template =~ s/%%CONFIG%%/$config/;

    $self->write_file('pir', 'mp_constants.pir', $template);
}

1;

__DATA__
.sub _init_const_table
    .local pmc table

    table = new 'Hash'

%%CONFIG%%

    set_root_global [ 'ModParrot'; 'Constants' ], 'table', table
.end

