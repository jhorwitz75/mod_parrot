# $Id$
#
# Copyright (c) 2005, 2007, 2009 Ian Joyce, Jeff Horwitz
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

package ModParrot::Config::Generator::ApacheServerRec;

use strict;
use warnings;

our $VERSION = '0.01';

use Carp;
use BaseGenerator;

use base 'ModParrot::Config::Generator::BaseGenerator';

sub run 
{
    my $self = shift;

    my $map = $self->get_map('build/maps/httpd/server_rec.map');

    $self->build_attribs($map);

    $self->generate_c_source($map);
    $self->generate_pir_source($map);
    $self->generate_pir_dlfunc_source($map);
}

sub build_attribs
{
    my ($self, $map) = @_;

    foreach my $record (@$map) {
        if ($record->{'return_type'} eq 'int') {
            $record->{'sig'} = 'iJpii';
            $record->{'pir_type'} = 'int';
        }
        else {
            $record->{'sig'} = 'tJpti';
            $record->{'pir_type'} = 'string';
        }
    }
}

sub generate_pir_dlfunc_source
{
    my ($self, $map) = @_;

    my $source;

    foreach my $record (@$map) {
        $source .= $self->merge($self->get_dlfunc_template(), $record);
    }

    $self->write_file('pir', 'server_rec_dlfunc.pir', $source);
}

sub get_dlfunc_template
{
    my $template = <<'END'
dlfunc func, lib, "mpnci_server_rec_%%NAME%%", "%%SIG%%"
set_root_global [ 'ModParrot'; 'NCI' ], "server_rec_%%NAME%%", func

END
;

    return $template;
}

sub generate_c_source
{
    my ($self, $map) = @_;

    my $source;
    my $prototype;

    foreach my $record (@$map) {
        my $function = $self->get_c_function($record);
        $source .= $function;

        # This gets the prototype.
        $function =~ /(.*)/;
        $prototype .= "$1;\n";
    }

    $self->write_file('nci', 'server_rec.c', "$prototype\n$source");
}

sub generate_pir_source
{
    my ($self, $map) = @_;

    my $source;

    foreach my $record (@$map) {
        $source .= $self->get_pir_method($record);
    }

    $self->write_file('pir', 'server_rec.pir', $source);
}

sub get_pir_method
{
    my ($self, $record) = @_;

    my $template = $record->{'return_type'} eq 'int'
        ? $self->get_pir_int_template()
        : $self->get_pir_string_template();

    return $self->merge($template, $record);
}

sub get_pir_int_template
{
    my $self = shift;

    my $template = <<'END'
.sub %%NAME%% :method
    .param int data :optional
    .param int update :opt_flag
    .local pmc s
    .local pmc server_rec_%%NAME%%
    .local int %%NAME%%

    getattribute s, self, 'server_rec'

    server_rec_%%NAME%% = get_root_global [ 'ModParrot'; 'NCI' ], 'server_rec_%%NAME%%'
    %%NAME%% = server_rec_%%NAME%%( s , data, update )

    .return(%%NAME%%)
.end

END
;

    return $template;
}

sub get_pir_string_template
{
    my $self = shift;

    my $template = <<'END'
.sub %%NAME%% :method
    .param %%PIR_TYPE%% data :optional
    .param int update :opt_flag
    .local pmc s
    .local pmc server_rec_%%NAME%%
    .local %%PIR_TYPE%% %%NAME%%

    getattribute s, self, 'server_rec'

    if update goto call_it
    data = ""

call_it:
    server_rec_%%NAME%% = get_root_global [ 'ModParrot'; 'NCI' ], 'server_rec_%%NAME%%'
    %%NAME%% = server_rec_%%NAME%%( s , data, update )

    .return(%%NAME%%)
.end

END
;

    return $template;
}

sub get_c_function
{
    my ($self, $record) = @_;

    my @arguments = ('server_rec *s');
    if ($record->{'access'} eq 'rw') {
        push @arguments, $record->{'return_type'} . $record->{'name'};
    }
    else {
        confess "TODO: read only access to server_rec";
    }
    $record->{'args'} = join ', ', @arguments;

    my $template = $record->{'return_type'} eq 'int'
        ? $self->get_c_int_template()
        : $self->get_c_char_template();

    return $self->merge($template, $record);
}

sub get_c_int_template
{
    my $self = shift;

    my $template = <<'END'
%%RETURN_TYPE%% mpnci_server_rec_%%NAME%%(Parrot_Interp interp, server_rec *s, int %%NAME%%, int update)
{
    if (update == 1) {
        s->%%NAME%% = %%NAME%%;
    }
    return s->%%NAME%%;
}

END
;

    return $template;
}

sub get_c_char_template
{
    my $self = shift;

    my $template = <<'END'
%%RETURN_TYPE%%mpnci_server_rec_%%NAME%%(Parrot_Interp interp, server_rec *s, char *%%NAME%%, int update)
{
    if (update == 1) {
        modparrot_context *ctxp = get_interp_ctx(interp);
        s->%%NAME%% = (char *)apr_pstrdup(ctxp->pool, %%NAME%%);
    }
    return s->%%NAME%%;
}

END
;

    return $template;
}

1;
