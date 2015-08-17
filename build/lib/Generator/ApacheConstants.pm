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

package ModParrot::Config::Generator::ApacheConstants;

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
        $self->to_string($constants{'handler'}),
        $self->to_string($constants{'http'}),
        $self->to_string($constants{'log'}),
        $self->to_string($constants{'config'}),
    );
}

sub parse
{
    my $self = shift;

    my %constants;

    # Get constants from $APACHE/include/httpd.h
    open (HTTPD_H, $self->{'apache_include_dir'} . 'httpd.h') or die $!;

    while (<HTTPD_H>) {
        if (/#define\s+(HTTP_\w+)\s+(\d+)/) {
            $constants{'http'}{$1} = $2;
            next;
        }

        if (/#define\s+(DECLINED|OK|DONE)\s+(-?\d+)/) {
            $constants{'handler'}{$1} = $2;
            next;
        }
    }

    close HTTPD_H;

    # Get constants from $APACHE/include/http_log.h
    open (HTTP_LOG_H, $self->{'apache_include_dir'} . 'http_log.h') or die $!;
    while (<HTTP_LOG_H>) {
        if (/#define\s+(APLOG_\w+)\s+(\d+)/) {
            $constants{'log'}{$1} = $2;
        }
    }
    close HTTP_LOG_H;

    # Get constants from $APACHE/include/http_config.h
    open (HTTP_CONFIG_H, $self->{'apache_include_dir'} . 'http_config.h')
        or die $!;
    while (<HTTP_CONFIG_H>) {
        my $code;
        if (/#define\s+(OR_\w+|RSRC_CONF|EXEC_ON_READ)\s+(\d+)/) {
            $constants{'config'}{$1} = $2;
        }
        elsif (/enum\s+(\w+)\s+\{/) {
            $code = $_;
            unless ($code =~ /;\s*$/) {
                local $_;
                while (<HTTP_CONFIG_H>) {
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
    close HTTP_CONFIG_H;

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
    my ($self, $handler, $http, $log, $config) = @_;

    my $template;
    {
        local $/ = undef;
        $template = <DATA>;
    }

    $template =~ s/%%HANDLER%%/$handler/;
    $template =~ s/%%HTTP%%/$http/;
    $template =~ s/%%LOG%%/$log/;
    $template =~ s/%%CONFIG%%/$config/;

    $self->write_file('pir', 'ap_constants.pir', $template);
}

1;

__DATA__
.sub _init_const_table
    .local pmc table

    table = new 'Hash'

    # Handler Responses
%%HANDLER%%

    # HTTP Response Codes
%%HTTP%%

    # Log Severities
%%LOG%%

    # Apache Config
%%CONFIG%%
    $I0 = table[ "OR_LIMIT" ]
    $I1 = table[ "OR_OPTIONS" ]
    $I0 |= $I1
    $I1 = table[ "OR_FILEINFO" ]
    $I0 |= $I1
    $I1 = table[ "OR_AUTHCFG" ]
    $I0 |= $I1
    $I1 = table[ "OR_INDEXES" ]
    $I0 |= $I1
    table[ "OR_ALL" ] = $I0

    set_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table', table
.end

