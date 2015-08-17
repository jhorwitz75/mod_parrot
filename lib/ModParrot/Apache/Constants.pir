# $Id: Constants.pir 456 2008-09-25 20:32:19Z jhorwitz $

# Copyright (c) 2004, 2005 Jeff Horwitz
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

Apache/Constants.pir

=head1 DESCRIPTION

Defines an ordered hash called C<table> in the C<Apache::Constants>
namespace containing various useful Apache constants.  This includes C<OK>,
C<DECLINED>, and HTTP status codes you should return from a handler.

This PIR code returns C<OK> from a handler:

 $P0 = get_root_global [ 'ModParrot'; 'Apache'; 'Constants'], 'table'
 $I0 = $P0['OK']

 .return($I0)
=head1 AUTHOR

Jeff Horwitz

=cut

.namespace [ 'ModParrot'; 'Apache'; 'Constants' ]

.include 'build/src/pir/ap_constants.pir'

.sub _initialize :load
    _init_const_table( )
.end
