# $Id$

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

.namespace [ 'ModParrot'; 'HLL'; 'pipp' ]

.sub __onload :anon :load
    load_bytecode 'languages/pipp/pipp.pbc'
    load_bytecode 'CGI/QueryHash.pbc'
    load_bytecode 'ModParrot/Apache/RequestRec.pbc'
    load_bytecode 'ModParrot/Apache/Module.pbc'
    load_bytecode 'ModParrot/Constants.pbc'

    .local pmc add_module, cmds, hooks, mp_const

    mp_const = get_root_global [ 'ModParrot'; 'Constants' ], 'table'

    # we have no directives, so this will remain empty
    cmds = new 'ResizablePMCArray'

    hooks = new 'ResizablePMCArray'
    $I0 = mp_const['MP_HOOK_RESPONSE']
    hooks[0] = $I0
    add_module = get_hll_global [ 'ModParrot'; 'Apache'; 'Module' ], 'add'
    $P1 = add_module("modparrot_pipp_module", "pipp", cmds, hooks)
.end

.sub run_php_file
    .param string path

    $P0 = compreg 'Pipp'
    $P1 = $P0.'evalfiles'(path)

    .return($P1)
.end

# response handler
.sub response_handler
    .param pmc ctx
    .local string php_file
    .local pmc r
    .local pmc ap_const
    .local string args, data
    .local int status
    .local pmc query_parse
    .local pmc get_hash, post_hash
    .local pmc interp, oldin, oldout, newin, newout

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # is this PHP?
    $S0 = r.'handler'()
    if $S0 == 'application/x-httpd-php' goto have_php
    status = ap_const['DECLINED']
    .return(status)

  have_php:
    # get the interpreter object
    interp = ctx.'interp'()

    # parse query string (do this regardless of method)
    args = r.'args'()
    query_parse = get_hll_global [ 'CGI'; 'QueryHash' ], 'parse'
    get_hash = new 'Hash'
    get_hash = query_parse(args)
    set_root_global ['pipp'], '$_GET', get_hash

    # parse POST data
    $S0 = r.'method'()
    unless $S0 == 'POST' goto run_script
    $I0 = 0
    $I1 = 8192
    $P0 = new 'String'
    $P1 = new 'String'
  post_read_loop:
    $I0 = r.'read'($P0, $I1)
    $P1 .= $P0
    if $I0 == $I1 goto post_read_loop
    data = $P1
    post_hash = new 'Hash'
    post_hash = query_parse(data)
    set_root_global ['pipp'], '$_POST', post_hash
    
  run_script:
    php_file = r.'filename'()
    oldout = interp.'stdout'(r)
    oldin = interp.'stdin'(r)
    r.'content_type'("text/html")
    run_php_file(php_file)
    interp.'stdout'(oldout)
    interp.'stdin'(oldin)

    status = ap_const['OK']
    .return(status)
.end
