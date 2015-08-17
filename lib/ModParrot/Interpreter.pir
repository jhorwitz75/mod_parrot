# $Id$

# Copyright (c) 2007 Jeff Horwitz
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

Interpreter.pir

=head1 SYNOPSIS

interp = new [ 'ModParrot'; Interpreter' ]

=head1 DESCRIPTION

Interpreter introspection for mod_parrot handlers.

=head2 Methods

=cut

.namespace [ 'ModParrot'; 'Interpreter' ]

.include 'interpinfo.pasm'
.include 'iglobals.pasm'

.sub _initialize :load
    .local pmc interp_class

    newclass interp_class, [ 'ModParrot'; 'Interpreter' ]
.end

=over 4

=item C<include_path()>

=item C<include_path_str()>

=over 4

Returns Parrot's include search path as an array, or a colon-delimited string
if using include_path_str().  Unless you really know what you're doing, you
probably want to use C<library_path()> instead.

=back

=cut

.sub include_path :method
    .local pmc interp

    interp = getinterp
    $P0 = interp[.IGLOBALS_LIB_PATHS]
    $P1 = $P0[0]
    .return($P1)
.end

.sub include_path_str :method
    .local pmc interp

    interp = getinterp
    $P0 = interp[.IGLOBALS_LIB_PATHS]
    $P1 = $P0[0]
    $S0 = join ':', $P1
    .return($S0)
.end

=item C<library_path()>

=item C<library_path_str()>

=over 4

Returns Parrot's library search path as an array, or a colon-delimited string
if using library_path_str().

=back

=cut

.sub library_path :method
    .local pmc interp

    interp = getinterp
    $P0 = interp[.IGLOBALS_LIB_PATHS]
    $P1 = $P0[1]
    .return($P1)
.end

.sub library_path_str :method
    .local pmc interp

    interp = getinterp
    $P0 = interp[.IGLOBALS_LIB_PATHS]
    $P1 = $P0[1]
    $S0 = join ':', $P1
    .return($S0)
.end

=item C<dynext_path()>

=item C<dynext_path_str()>

=over 4

Returns Parrot's dynamic extension search path as an array, or a
colon-delimited string if using dynext_path_str().

=back

=cut

.sub dynext_path :method
    .local pmc interp

    interp = getinterp
    $P0 = interp[.IGLOBALS_LIB_PATHS]
    $P1 = $P0[2]
    .return($P1)
.end

.sub dynext_path_str :method
    .local pmc interp

    interp = getinterp
    $P0 = interp[.IGLOBALS_LIB_PATHS]
    $P1 = $P0[2]
    $S0 = join ':', $P1
    .return($S0)
.end

=item C<PMC stdout(PMC handle :optional)>

=over 4

With no arguments, returns the current stdout.

If C<handle> is provided, this method will assign it to stdout.  If the
C<handle> is a ModParrot;Apache;RequestRec object, a new ModParrotHandle will
be created and tied to stdout.  FileHandles and ModParrotHandles will be
assigned directly to stdout.  After assignment, returns the previous stdout.

=back

=cut

.sub stdout :method
    .param pmc handle :optional
    .param int got_handle :opt_flag
    .local pmc stdout, fh

    stdout = getstdout
    unless got_handle goto done
    $I0 = isa handle, ['ModParrot';'Apache';'RequestRec']
    if $I0 goto have_r
    $I0 = isa handle, ['FileHandle']
    if $I0 goto have_filehandle
    $I0 = isa handle, ['ModParrotHandle']
    if $I0 goto have_modparrothandle
    $P0 = new 'Exception'
    $P0 = 'Cannot set stdout to an incompatible PMC'
    throw $P0

  have_r:
    fh = new 'ModParrotHandle'
    fh.'open'(handle, 'w')
    fh.'setstdout'(fh)
    goto done

  have_filehandle:
    fh = new 'ModParrotHandle'
    fh.'setstdout'(handle)
    goto done

  have_modparrothandle:
    handle.'setstdout'()

  done:
    .return(stdout)
.end 

=item C<PMC stdin(PMC handle :optional)>

=over 4

With no arguments, returns the current stdin.

If C<handle> is provided, this method will assign it to stdin.  If the
C<handle> is a ModParrot;Apache;RequestRec object, a new ModParrotHandle will
be created and tied to stdin.  FileHandles and ModParrotHandles will be
assigned directly to stdin.  After assignment, returns the previous stdin.

=back

=cut

.sub stdin :method
    .param pmc handle :optional
    .param int got_handle :opt_flag
    .local pmc stdin, fh

    stdin = getstdin
    unless got_handle goto done
    $I0 = isa handle, ['ModParrot';'Apache';'RequestRec']
    if $I0 goto have_r
    $I0 = isa handle, ['FileHandle']
    if $I0 goto have_filehandle
    $I0 = isa handle, ['ModParrotHandle']
    if $I0 goto have_modparrothandle
    $P0 = new 'Exception'
    $P0 = 'Cannot set stdin to an incompatible PMC'
    throw $P0

  have_r:
    fh = new 'ModParrotHandle'
    fh.'open'(handle, 'r')
    fh.'setstdin'(fh)
    goto done

  have_filehandle:
    fh = new 'ModParrotHandle'
    fh.'setstdin'(handle)
    goto done

  have_modparrothandle:
    handle.'setstdin'()

  done:
    .return(stdin)
.end

=back

=head1 AUTHOR

Jeff Horwitz

=cut

