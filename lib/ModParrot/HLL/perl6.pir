# $Id: perl6.pir 644 2009-06-16 00:02:37Z jhorwitz $

# Copyright (c) 2007, 2008 Jeff Horwitz
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

.sub __onload :anon :load
    $P0 = get_hll_global 'P6metaclass'
    $P1 = get_class ['ModParrot'; 'Apache'; 'RequestRec']
    $P0.'register'($P1, 'name' => 'Apache;RequestRec', 'perl6' :named('hll'))
    $P1 = get_class ['ModParrot'; 'Apache'; 'ServerRec']
    $P0.'register'($P1, 'name' => 'Apache;ServerRec', 'perl6' :named('hll'))
    $P1 = get_class ['ModParrot'; 'Apache'; 'CmdParms']
    $P0.'register'($P1, 'name' => 'Apache;CmdParms', 'perl6' :named('hll'))
    $P1 = get_class ['ModParrot';'APR'; 'Pool']
    $P0.'register'($P1, 'name' => 'APR;Pool', 'perl6' :named('hll'))
    $P1 = get_class ['ModParrot';'APR'; 'Table']
    $P0.'register'($P1, 'name' => 'APR;Table', 'perl6' :named('hll'))
    $P1 = get_class ['ModParrot'; 'Interpreter']
    $P0.'register'($P1, 'perl6' :named('hll'))
    $P1 = get_class ['ModParrot'; 'Context']
    $P0.'register'($P1, 'perl6' :named('hll'))
    $P1 = get_class ['ModParrotHandle']
    $P0.'register'($P1, 'perl6' :named('hll'))

    load_bytecode 'languages/rakudo/perl6.pbc'

    # load mod_perl6.pm, which may be precompiled
    $P0 = compreg 'perl6'
    $P1 = $P0.'compile'('use mod_perl6')
    $P1()
.end

# declare namespace AFTER loading compiler
# otherwise we get method resolution errors
.namespace [ 'ModParrot'; 'HLL'; 'perl6' ]
