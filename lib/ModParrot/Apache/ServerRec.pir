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

Apache/ServerRec.pir

=head1 SYNOPSIS

=head1 DESCRIPTION

This code implements the ModParrot;Apache;ServerRec class, an encapsulation of
Apache's server_rec structure.
 
=head2 Methods

=over 4

=cut

.namespace [ 'ModParrot'; 'Apache'; 'ServerRec' ]

.sub _initialize :load
    .local pmc sr_class
    .local pmc func

    newclass sr_class, [ 'ModParrot'; 'Apache'; 'ServerRec' ]
    addattribute sr_class, 'server_rec'
.end

.include 'build/src/pir/server_rec.pir'

=head1 AUTHOR

Jeff Horwitz

=cut
