# $Id$

# Copyright (c) 2008 Jeff Horwitz
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

=head1 NAME

Apache/CmdParms.pir

=head1 SYNOPSIS

.sub cmd_foo
    .param pmc parms
    .param pmc cfg
    .param pmc args
    .local pmc this_server_rec

    this_server_rec = parms.'server'()

    ...

.end

=head1 DESCRIPTION

This code implements the ModParrot;Apache;CmdParms class, an encapsulation of
Apache's cmd_parms structure.  It is passed to directive callbacks.
 
=head2 Methods

=over 4

=cut

# XXX How to write server side tests for this?

.namespace [ 'ModParrot'; 'Apache'; 'CmdParms' ]

.sub _initialize :load
    .local pmc cmd_class
    .local pmc func

    newclass cmd_class, [ 'ModParrot'; 'Apache'; 'CmdParms' ]
    addattribute cmd_class, 'cmd_parms'
.end

=item C<PMC server()>

Returs the ModParrot;Apache;ServerRec object associated with the command.

=cut

.sub server :method
    .local pmc func
    .local pmc cmd_parms_struct
    .local pmc server_struct
    .local pmc server

    func = get_root_global [ 'ModParrot'; 'NCI' ], 'cmd_parms_server'
    cmd_parms_struct = getattribute self, 'cmd_parms'
    server_struct = func(cmd_parms_struct)
    $P0 = new 'Hash'
    $P0['server_rec'] = server_struct
    server = new [ 'ModParrot'; 'Apache'; 'ServerRec' ], $P0

    .return(server)
.end

=item C<PMC pool()>

Returs the command's pool as a ModParrot;APR;Pool object.

=cut

.sub pool :method
    .local pmc func
    .local pmc cmd_parms_struct
    .local pmc apr_pool_struct
    .local pmc pool

    func = get_root_global [ 'ModParrot'; 'NCI' ], 'cmd_parms_pool'
    cmd_parms_struct = getattribute self, 'cmd_parms'
    apr_pool_struct = func(cmd_parms_struct)
    $P0 = new 'Hash'
    $P0['apr_pool'] = apr_pool_struct
    pool = new [ 'ModParrot'; 'APR'; 'Pool' ], $P0

    .return(pool)
.end

=item C<PMC temp_pool()>

Returs the command's temporary (config) pool as a ModParrot;APR;Pool object.

=cut

.sub temp_pool :method
    .local pmc func
    .local pmc cmd_parms_struct
    .local pmc apr_pool_struct
    .local pmc pool

    func = get_root_global [ 'ModParrot'; 'NCI' ], 'cmd_parms_temp_pool'
    cmd_parms_struct = getattribute self, 'cmd_parms'
    apr_pool_struct = func(cmd_parms_struct)
    $P0 = new 'Hash'
    $P0['apr_pool'] = apr_pool_struct
    pool = new [ 'ModParrot'; 'APR'; 'Pool' ], $P0

    .return(pool)
.end
 
=item C<PMC cmd()>

XXX UNIMPLEMENTED XXX

Returs the command associated with the CmdParms object as a
ModParrot;Apache;CommandRec object.

=cut

.sub cmd :method
    .local pmc func
    .local pmc cmd_parms_struct
    .local pmc command_struct
    .local pmc command

    func = get_root_global [ 'ModParrot'; 'NCI' ], 'cmd_parms_cmd'
    cmd_parms_struct = getattribute self, 'cmd_parms'
    command_struct = func(cmd_parms_struct)
    $P0 = new 'Hash'
    $P0['command_rec'] = command_struct
    command = new [ 'ModParrot'; 'Apache'; 'CommandRec' ], $P0

    .return(command)
.end

=head1 AUTHOR

Jeff Horwitz

=cut
