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

Apache/Module.pir

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

.namespace [ 'ModParrot'; 'Apache'; 'Module' ]

.sub _initialize :load
    .local pmc module_class
    .local pmc func
    .local pmc lib

    newclass module_class, [ 'ModParrot'; 'Apache'; 'Module' ]
    addattribute module_class, 'module'
.end

=head2 FUNCTIONS

=over 4

=item C<add(STRING name, STRING namespace, ARRAY cmds)>

=over 4

Creates a new Apache module and adds its directives to Apache.  This must be
called via ParrotLoadImmediate or another HLL-specific directive that causes
an early interpreter startup.

C<name> is the name of your module.  It should be unique.  HLLs should prepend
mdoule names with the name of the HLL to avoid conflicts.

C<namespace> is the namespace of your module under ModParrot;HLL.

C<cmds> is an array of hashes.  Each element of the array defines a
configuration directive.  The directive hash is defined as follows:

=over 4

C<name> - name of the directive

C<args_how> - defines how arguments are parsed:

=over 4

C<NO_ARGS>

C<TAKE1>

C<TAKE2>

C<TAKE3>

C<TAKE12>

C<TAKE23>

C<TAKE123>

C<RAW_ARGS>

C<FLAG>

=back

C<func> - a subroutine PMC to be called when the directive is encountered.

C<req_override> - the directive's configuration scope

=over 4

C<OR_NONE>

C<OR_LIMIT>

C<OR_OPTIONS>

C<OR_FILEINFO>

C<OR_AUTHCFG>

C<OR_INDEXES>

C<OR_UNSET>

C<ACCESS_CONF>

C<RSRC_CONF>

C<OR_ALL>

=back

C<errmsg> -the directive's usage statement

C<cmd_data> - a user-defined PMC to be passed back to the callback function.

=back

=back

=cut

.sub add
    .param string name
    .param string namespace
    .param pmc cmds
    .param pmc hooks
    .local pmc add_module

    add_module = get_root_global ['ModParrot'; 'NCI' ], "add_apache_module"
    add_module(name, namespace, cmds, hooks)
.end

=back

=over 4

=item C<get_config(STRING name, PMC per_dir_config)>

=over 4

Get the server or directory configuration PMC.

=cut

.sub get_config
    .param string name
    .param pmc per_dir_config :optional
    .param int is_directory :opt_flag
    .local pmc config, get_conf

    get_conf = get_root_global ['ModParrot'; 'NCI' ], "get_module_config"
    config = get_conf(name, per_dir_config, is_directory)

    # XXX rakudo doesn't deal with NULL PMCs very well -- need to wrap this
    if null config goto null_config
    goto return_config
  null_config:
    config = new 'Hash'

  return_config:
    .return(config)
.end

=back

=head1 AUTHOR

Jeff Horwitz

=cut
