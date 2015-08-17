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

Context.pir

=head1 SYNOPSIS

interp = new [ 'ModParrot'; 'Context' ]

=head1 DESCRIPTION

Context object for HLL handlers.

=head2 Methods

=cut

.namespace [ 'ModParrot'; 'Context' ]

.sub _initialize :load
    .local pmc context_class

    load_bytecode 'ModParrot/Interpreter.pbc'
    newclass context_class, [ 'ModParrot'; 'Context' ]
.end

=over 4

=item ModParrot::Interpreter C<interp()>

=over 4

Returns the current interpreter as a ModParrot::Interpreter object.

=back

=cut

.sub interp :method
    .local pmc mpi

    $P0 = get_class [ 'ModParrot'; 'Interpreter' ]
    mpi = new $P0

    .return(mpi)
.end

=item Apache::RequestRec request_rec()

=over 4

Returns the current Apache::RequestRec object.

=back

=cut

.sub request_rec :method
    .local pmc r

    $P0 = new [ 'ModParrot'; 'Apache'; 'RequestRec' ]

    .return($P0)
.end

=back

=item conf_pool

=cut

.sub conf_pool :method
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'conf_pool'
    $P1 = new 'Hash'
    $P1['apr_pool'] = $P0
    $P2 = new [ 'ModParrot'; 'APR'; 'Pool' ], $P1
    .return($P2)
.end

=item log_pool

=cut

.sub log_pool :method
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'log_pool'
    $P1 = new 'Hash'
    $P1['apr_pool'] = $P0
    $P2 = new [ 'ModParrot'; 'APR'; 'Pool' ], $P1
    .return($P2)
.end

=item temp_pool

=cut

.sub temp_pool :method
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'temp_pool'
    $P1 = new 'Hash'
    $P1['apr_pool'] = $P0
    $P2 = new [ 'ModParrot'; 'APR'; 'Pool' ], $P1
    .return($P2)
.end

=item child_pool

=cut

.sub child_pool :method
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'child_pool'
    $P1 = new 'Hash'
    $P1['apr_pool'] = $P0
    $P2 = new [ 'ModParrot'; 'APR'; 'Pool' ], $P1
    .return($P2)
.end

=item raw_srv_config

=cut

.sub raw_srv_config :method
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'raw_srv_config'
    $P1 = $P0()
    .return($P1)
.end

=item raw_dir_config

=cut

.sub raw_dir_config :method
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'raw_dir_config'
    $P1 = $P0()
    .return($P1)
.end

=item ctx_pool_name

=cut

.sub pool_name :method
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'ctx_pool_name'
    $S0 = $P0()
    .return($S0)
.end

=head1 TODO

=over 4

=item server_rec

=item conn_rec

=back

=head1 AUTHOR

Jeff Horwitz

=cut

