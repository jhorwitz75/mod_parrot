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

.namespace [ 'ModParrot'; 'HLL'; 'lolcode' ]

.sub __onload :anon :load
    .local pmc add_module, cmds, hooks, mp_const

    load_bytecode 'languages/lolcode/lolcode.pbc'
    load_bytecode 'CGI/QueryHash.pbc'
    load_bytecode 'ModParrot/Apache/RequestRec.pbc'
    load_bytecode 'ModParrot/Apache/Module.pbc'
    load_bytecode 'ModParrot/Constants.pbc'

    $P0 = new 'Hash'
    set_hll_global 'lolcode_registry', $P0

    # we have no directives, so this will remain empty
    cmds = new 'ResizablePMCArray'

    hooks = new 'ResizablePMCArray'
    mp_const = get_root_global [ 'ModParrot'; 'Constants' ], 'table'
    $I0 = mp_const['MP_HOOK_RESPONSE']
    hooks[0] = $I0
    add_module = get_hll_global [ 'ModParrot'; 'Apache'; 'Module' ], 'add'
    $P1 = add_module("modparrot_lolcode_module", "lolcode", cmds, hooks)
.end

.sub load
    .param string file
    .local pmc registry
    .local string source

    registry = get_hll_global 'lolcode_registry'
    $I0 = exists registry[file]
    if $I0 goto load_from_registry
    $P0 = open file, 'r'
    source = $P0.'readall'()
    close $P0
    $P1 = compreg 'lolcode'
    $P2 = $P1.'compile'(source)
    registry[file] = $P2
    goto return_code
  load_from_registry:
    $P2 = registry[file]
  return_code:
    .return($P2)
.end

# response handler
.sub response_handler
    .param pmc ctx
    .local string script_path
    .local string output
    .local string key
    .local pmc r
    .local pmc ap_const
    .local pmc interp, oldin, oldout
    .local pmc code
    .local pmc query_parse
    .local pmc query
    .local pmc q_iter
    .local int status

    # get apache constants
    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # is this LOLCODE?
    $S0 = r.'handler'()
    if $S0 == 'application/x-httpd-lolcode' goto have_lolcode
    status = ap_const['DECLINED']
    .return(status)

  have_lolcode:
    # get the interpreter object
    interp = ctx.'interp'()

    # tie I/O to the request
    oldout = interp.'stdout'(r)
    oldin = interp.'stdin'(r)

    # load the code
    script_path = r.'filename'()
    push_eh report_error
    code = load(script_path)
    pop_eh

    # set default content type
    r.'content_type'("text/html")

    # get the query string and store as the global 'ARGZ'
    $S0 = r.'args'()
    $P0 = new 'String'
    $P0 = $S0
    set_hll_global 'ARGZ', $P0

    # additionally, store each arg as a global, uppercasing the names
    # XXX lolcode bombs out when you use a variable that hasn't been declared
    #     or isn't set here.  caveat developer!
    unless $P0 goto query_loop_end
    query_parse = get_hll_global [ 'CGI'; 'QueryHash' ], 'parse'
    query = new 'Hash'
    query = query_parse($S0)
    q_iter = new 'Iterator', query
  query_loop:
    key = shift q_iter
    unless key goto query_loop_end
    $P0 = query[key]
    $S0 = key
    $S1 = upcase $S0
    set_hll_global $S1, $P0
    goto query_loop
  query_loop_end:

    r.'content_type'("text/html")
    push_eh report_error
    code()
    pop_eh
    status = ap_const['OK']
    goto return_status

  report_error:
    pop_eh
    get_results '0,0', $P0, $S0
    $S1 = script_path
    concat $S1, ": "
    concat $S1, $S0
    $I0 = ap_const['APLOG_ERR']
    r.'log_rerror'(script_path, 0, $I0, $S1)
    status = ap_const['HTTP_INTERNAL_SERVER_ERROR']

  return_status:
    # restore filehandles
    interp.'stdout'(oldout)
    interp.'stdin'(oldin)
    # return status code
    .return(status)
.end
