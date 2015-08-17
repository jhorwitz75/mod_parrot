# $Id: Table.pir 585 2009-01-06 22:43:59Z jhorwitz $

# Copyright (c) 2005, 2007 Jeff Horwitz
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

APR/Table.pir

=head1 SYNOPSIS

$P0 = r.'notes'()

$P0.set('foo', 'bar')

$S0 = $P0.get('foo')

=head1 DESCRIPTION

This class abstracts APR's apr_table_t type, used for the storage of key/value
tables in Apache.  Currently only operates on existing apr_table structures,
such as "notes" in Apache's request_rec structure.

=head2 Methods

=cut

.namespace [ 'ModParrot'; 'APR'; 'Table' ]

.sub _initialize :load
    .local pmc table_class
    .local pmc func
    .local pmc lib

    null $S0
    loadlib lib, $S0

    newclass table_class, [ 'ModParrot'; 'APR'; 'Table' ]
    addattribute table_class, 'apr_table'

    dlfunc func, lib, "apr_table_get", "tpt"
    set_root_global [ 'APR'; 'NCI' ], "apr_table_get", func

    dlfunc func, lib, "apr_table_set", "vptt"
    set_root_global [ 'APR'; 'NCI' ], "apr_table_set", func
.end

=item C<ModParrot::APR::Table get(STRING key)>

=over 4

Retrieve a value from the table by key.

=back

=cut

.sub get :method
    .param string key
    .local pmc t
    .local pmc apr_table_get
    .local string val
    .local int offset

    getattribute t, self, 'apr_table'
    apr_table_get = get_root_global [ 'APR'; 'NCI' ], 'apr_table_get'
    val = apr_table_get(t, key)

    .return(val)
.end

=item C<ModParrot::APR::Table set(STRING key, STRING value)>

=over 4

Set a value in the table.

=back

=cut

.sub set :method
    .param string key
    .param string val
    .local pmc t
    .local pmc apr_table_set
    .local int offset

    getattribute t, self, 'apr_table'
    apr_table_set = get_root_global [ 'APR'; 'NCI' ], 'apr_table_set'
    apr_table_set(t, key, val)
.end
    
=over 4

=cut

=back

=head1 AUTHOR

Jeff Horwitz

=cut

