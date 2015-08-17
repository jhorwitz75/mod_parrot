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

ModParrot/APR/Pool.pir

=head1 SYNOPSIS

 $P0 = new ['ModParrot'; 'APR'; 'Pool']
 $P0.'cleanup_register'(my_cleanup_handler, data)
 $P0.'destroy'()

=head1 DESCRIPTION

This code implements the ModParrot;APR;Pool class.

=head2 Methods

=over 4

=cut

.namespace [ 'ModParrot'; 'APR'; 'Pool' ]

.sub _initialize :load
    .local pmc pool_class
    .local pmc func
    .local pmc lib

    null $S0
    loadlib lib, $S0

    newclass pool_class, [ 'ModParrot'; 'APR'; 'Pool' ]
    addattribute pool_class, 'apr_pool'

    # the parent attribute is only used for instantiation
    # see the "parent_get" method to query APR for the parent
    addattribute pool_class, 'parent'

    dlfunc func, lib, "apr_pool_create_ex", "iVppp"
    set_root_global [ 'APR'; 'NCI' ], "apr_pool_create_ex", func

    dlfunc func, lib, "apr_pool_clear", "vp"
    set_root_global [ 'APR'; 'NCI' ], "apr_pool_clear", func

    dlfunc func, lib, "apr_pool_destroy", "vp"
    set_root_global [ 'APR'; 'NCI' ], "apr_pool_destroy", func

    dlfunc func, lib, "apr_pool_parent_get", "pp"
    set_root_global [ 'APR'; 'NCI' ], "apr_pool_parent_get", func

    dlfunc func, lib, "apr_pool_tag", "vpt"
    set_root_global [ 'APR'; 'NCI' ], "apr_pool_tag", func
.end

.sub init :vtable :method
    .local pmc pool
    .local pmc apr_pool_create, null_ptr, nul

    apr_pool_create = get_root_global [ 'APR'; 'NCI' ], "apr_pool_create_ex"
    null_ptr = get_root_global [ 'ModParrot'; 'NCI' ], "null"
    nul = null_ptr()
    pool = new 'CPointer'
    $I0 = apr_pool_create(pool, nul, nul, nul)
    setattribute self, 'apr_pool', pool
  no_self:
.end

.sub init_pmc :vtable :method
    .param pmc attrs
    .local pmc pool, parent
    .local pmc pool_attr, parent_attr
    .local pmc apr_pool_create, null_ptr, nul

    pool_attr = getattribute self, 'apr_pool'
    parent_attr = getattribute self, 'parent'

    apr_pool_create = get_root_global [ 'APR'; 'NCI' ], "apr_pool_create_ex"
    null_ptr = get_root_global [ 'ModParrot'; 'NCI' ], "null"
    nul = null_ptr()

    if null parent_attr goto end_attr_check
    $S0 = typeof parent_attr
    if $S0 == 'ModParrot;APR;Pool' goto end_attr_check
    # XXX error out here!
  end_attr_check:
    unless null pool_attr goto done
    unless null parent_attr goto have_parent
    # XXX should never get here, else we'd be in init()
    goto done
  have_parent:
    pool = new 'CPointer'
    $P0 = getattribute parent_attr, 'apr_pool'
    $I0 = apr_pool_create(pool, $P0, nul, nul)
    setattribute self, 'apr_pool', pool
  done:
    .return()
.end

=item C<cleanup_register(PMC callback, PMC data)>

Registers a cleanup function that will be called when the pool is destroyed.
Note that C<data> is passed by reference.  It is up to the HLL to wrap this
method if pass-by-value is preferred.

=cut

.sub cleanup_register :method
    .param pmc handler_sub
    .param pmc data :optional
    .local pmc func, pool

    func = get_root_global [ 'ModParrot'; 'NCI' ], "register_pool_cleanup"
    pool = getattribute self, 'apr_pool'
    func(pool, handler_sub, data)
.end

=item C<clear()>

Clears the memory in a pool and runs cleanup handlers.  Also destroys any
subpools.

=cut

.sub clear :method
    .local pmc func, pool

    func = get_root_global [ 'APR'; 'NCI' ], "apr_pool_clear"
    pool = getattribute self, 'apr_pool'
    func(pool)
.end

=item C<destroy()>

Destroys the pool and runs cleanup handlers.  Also destroys any subpools.

=cut

.sub destroy :method
    .local pmc func, pool

    func = get_root_global [ 'APR'; 'NCI' ], "apr_pool_destroy"
    pool = getattribute self, 'apr_pool'
    func(pool)
.end

=item C<APR;Pool parent_get()>

Returns the pool's parent pool, or a null PMC if the pool has no parent.

=cut

.sub parent_get :method
    .local pmc func, pool, parent

    func = get_root_global [ 'APR'; 'NCI' ], "apr_pool_parent_get"
    pool = getattribute self, 'apr_pool'
    null parent
    $P0 = func(pool)
    if null $P0 goto return_pool
    $P1 = new 'Hash'
    $P1['apr_pool'] = $P0
    parent = new ['ModParrot'; 'APR'; 'Pool'], $P1
  return_pool:
    .return(parent)
.end

=item C<tag(STRING name)>

Sets the tag for a pool.  This is for C-level debugging, as there is no API
for retrieving the tag from a pool.

=cut

.sub tag :method
    .param string tag
    .local pmc func, pool

    func = get_root_global [ 'APR'; 'NCI' ], "apr_pool_tag"
    pool = getattribute self, 'apr_pool'
    func(pool, tag)
.end

=back

=head1 AUTHOR

Jeff Horwitz

=cut

