# $Id: pir.pir 626 2009-04-12 14:32:52Z jhorwitz $

# Copyright (c) 2005, 2008 Jeff Horwitz
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
    load_bytecode 'ModParrot/Apache/Module.pbc'
    load_bytecode 'ModParrot/Constants.pbc'

    # register apache directives
    .local pmc add_module, cmds, hooks, mp_const

    mp_const = get_root_global [ 'ModParrot'; 'Constants' ], 'table'

    cmds = new 'ResizablePMCArray'

    $P0 = new_cmd('ParrotInterp', 'TAKE1', 'cmd_parrotinterp', 'RSRC_CONF', 'usage: ParrotInterp pool-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotOpenLogsHandler', 'TAKE1', 'cmd_parrotopenlogshandler', 'RSRC_CONF', 'usage: ParrotOpenLogsHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotPostConfigHandler', 'TAKE1', 'cmd_parrotpostconfighandler', 'RSRC_CONF', 'usage: ParrotPostConfigHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotChildInitHandler', 'TAKE1', 'cmd_parrotchildinithandler', 'RSRC_CONF', 'usage: ParrotChildInitHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotPreConnectionHandler', 'TAKE1', 'cmd_parrotpreconnectionhandler', 'RSRC_CONF', 'usage: ParrotPreConnectionHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotProcessConnectionHandler', 'TAKE1', 'cmd_parrotprocessconnectionhandler', 'RSRC_CONF', 'usage: ParrotProcessConnectionHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotMapToStorageHandler', 'TAKE1', 'cmd_parrotmaptostoragehandler', 'OR_AUTHCFG', 'usage: ParrotMapToStorageHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotTransHandler', 'TAKE1', 'cmd_parrottranshandler', 'OR_AUTHCFG', 'usage: ParrotTransHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotPostReadRequestHandler', 'TAKE1', 'cmd_parrotpostreadrequesthandler', 'OR_AUTHCFG', 'usage: ParrotPostReadRequestHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotHeaderParserHandler', 'TAKE1', 'cmd_parrotheaderparserhandler', 'OR_AUTHCFG', 'usage: ParrotHeaderParserHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotAccessHandler', 'TAKE1', 'cmd_parrotaccesshandler', 'OR_AUTHCFG', 'usage: ParrotAccessHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotAuthenHandler', 'TAKE1', 'cmd_parrotauthenhandler', 'OR_AUTHCFG', 'usage: ParrotAuthenHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotAuthzHandler', 'TAKE1', 'cmd_parrotauthzhandler', 'OR_AUTHCFG', 'usage: ParrotAuthzHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotResponseHandler', 'TAKE1', 'cmd_parrothandler', 'OR_AUTHCFG', 'usage: ParrotResponseHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotHandler', 'TAKE1', 'cmd_parrothandler', 'OR_AUTHCFG', 'usage: ParrotHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotTypeHandler', 'TAKE1', 'cmd_parrottypehandler', 'OR_AUTHCFG', 'usage: ParrotTypeHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotFixupHandler', 'TAKE1', 'cmd_parrotfixuphandler', 'OR_AUTHCFG', 'usage: ParrotFixupHandler handler-name')
    cmds.'push'($P0)
    $P0 = new_cmd('ParrotLogHandler', 'TAKE1', 'cmd_parrotloghandler', 'OR_AUTHCFG', 'usage: ParrotlogHandler handler-name')
    cmds.'push'($P0)

    # we want *all* the hooks
    hooks = new 'ResizablePMCArray'
    $I0 = mp_const['MP_HOOK_ALL']
    hooks[0] = $I0 
    add_module = get_hll_global [ 'ModParrot'; 'Apache'; 'Module' ], 'add'
    $P1 = add_module("modparrot_pir_module", "PIR", cmds, hooks)
.end

.sub new_cmd
    .param string name
    .param string how
    .param string func
    .param string override
    .param string errmsg
    .local pmc ap_const
    .local pmc cmd

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'
    
    cmd = new 'Hash'
    $P0 = new 'String'
    $P0 = name
    cmd['name'] = $P0
    $P0 = new 'Integer'
    $P0 = ap_const[how]
    cmd['args_how'] = $P0
    $P0 = get_hll_global [ 'ModParrot'; 'HLL'; 'PIR' ], func 
    cmd['func'] = $P0
    $P0 = new 'Integer'
    $P0 = ap_const[override]
    cmd['req_override'] = $P0
    $P0 = new 'String'
    $P0 = errmsg
    cmd['errmsg'] = $P0

    .return(cmd)
.end
    
.namespace [ 'ModParrot'; 'HLL'; 'PIR' ]

.sub server_create
    .param pmc parms
    $P0 = new 'Hash'
    .return($P0)
.end

.sub dir_create
    .param pmc parms
    $P0 = new 'Hash'
    .return($P0)
.end

# XXX implement merging

#.sub server_merge
#.end

.sub dir_merge
    .param pmc basecfg
    .param pmc newcfg

    .return(newcfg)
.end

.sub cmd_parrotinterp
    .param pmc parms
    .param pmc dircfg
    .param pmc args
    .local pmc ctx, cfg, set_pool

    ctx = new ['ModParrot'; 'Context']
    cfg = ctx.'raw_srv_config'()
    set_pool = get_root_global ['ModParrot'; 'NCI'], 'set_config_ctx_pool'
    $S0 = args[0]
    set_pool(cfg, $S0)
.end

.sub cmd_parrotopenlogshandler
    .param pmc parms
    .param pmc mconfig
    .param pmc args
    .local pmc cfg, get_config

    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $S0 = args[0]
    cfg['open_logs_handler'] = $S0
.end

.sub cmd_parrotpostconfighandler
    .param pmc parms
    .param pmc mconfig
    .param pmc args
    .local pmc cfg, get_config

    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $S0 = args[0]
    cfg['post_config_handler'] = $S0
.end

.sub cmd_parrotchildinithandler
    .param pmc parms
    .param pmc mconfig
    .param pmc args
    .local pmc cfg, get_config

    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $S0 = args[0]
    cfg['child_init_handler'] = $S0
.end

.sub cmd_parrotpreconnectionhandler
    .param pmc parms
    .param pmc mconfig
    .param pmc args
    .local pmc cfg, get_config

    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $S0 = args[0]
    cfg['pre_connection_handler'] = $S0
.end

.sub cmd_parrotprocessconnectionhandler
    .param pmc parms
    .param pmc mconfig
    .param pmc args
    .local pmc cfg, get_config

    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $S0 = args[0]
    cfg['process_connection_handler'] = $S0
.end

.sub cmd_parrotmaptostoragehandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['map_to_storage_handler'] = $S0
.end

.sub cmd_parrottranshandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['trans_handler'] = $S0
.end

.sub cmd_parrotpostreadrequesthandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['post_read_request_handler'] = $S0
.end

.sub cmd_parrotheaderparserhandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['header_parser_handler'] = $S0
.end

.sub cmd_parrotauthenhandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['authen_handler'] = $S0
.end

.sub cmd_parrotauthzhandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['authz_handler'] = $S0
.end

.sub cmd_parrotaccesshandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['access_handler'] = $S0
.end

.sub cmd_parrothandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['response_handler'] = $S0
.end

.sub cmd_parrottypehandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['type_handler'] = $S0
.end

.sub cmd_parrotfixuphandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['fixup_handler'] = $S0
.end

.sub cmd_parrotloghandler
    .param pmc parms
    .param pmc dircfg
    .param pmc args

    $S0 = args[0]
    dircfg['log_handler'] = $S0
.end

.sub load
    .param string path
    load_bytecode path
.end

# response handler
.sub response_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # decline if not our handler
    $S0 = r.'handler'()
    if $S0 == 'parrot-code' goto get_configs
    status = ap_const['DECLINED']
    goto return_status

  get_configs:
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['response_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # set our default content type
    r.'content_type'('text/html')
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

  return_status:
    .return(status)
.end

# authen handler
.sub authen_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['authen_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'

    status = handler(r)

    # return status code
    .return(status)
.end

# authz handler
.sub authz_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['authz_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)
.end

# access handler
.sub access_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['access_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)
.end

# open logs handler
.sub open_logs_handler
    .param pmc ctx
    .local pmc s, handler, cfg, get_config, ap_const, pconf, plog, ptemp, s
    .local pmc pconf, plog, ptemp
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')

    # decline if we have no handler in this section
    $S0 = cfg['open_logs_handler']
    if $S0 goto run_handler
    # open_logs handlers must return OK
    status = ap_const['OK']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'

    # get the pool objects
    pconf = ctx.'conf_pool'()
    plog = ctx.'log_pool'()
    ptemp = ctx.'temp_pool'()

    # get the server_rec object
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'server_rec'
    s = $P0()

    status = handler(pconf, plog, ptemp, s)

    # return status code
    .return(status)
.end

# post_config handler
.sub post_config_handler
    .param pmc ctx
    .local pmc s, handler, cfg, get_config, ap_const, pconf, plog, ptemp, s
    .local pmc pconf, plog, ptemp
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')

    # decline if we have no handler in this section
    $S0 = cfg['post_config_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'

    # get the pool objects
    pconf = ctx.'conf_pool'()
    plog = ctx.'log_pool'()
    ptemp = ctx.'temp_pool'()

    # get the server_rec object
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'server_rec'
    s = $P0()

    status = handler(pconf, plog, ptemp, s)

    # return status code
    .return(status)
.end

# child init handler
.sub child_init_handler
    .param pmc ctx
    .local pmc s, handler, cfg, get_config, ap_const, pchild, s
    .local pmc pconf, plog, ptemp
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')

    # decline if we have no handler in this section
    $S0 = cfg['child_init_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'

    # get the pool objects
    pchild = ctx.'child_pool'()

    # get the server_rec object
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'server_rec'
    s = $P0()

    status = handler(pchild, s)

    # return status code
    .return(status)
.end

# pre connection handler
.sub pre_connection_handler
    .param pmc ctx
    .local pmc s, handler, cfg, get_config, ap_const, c, csd
    .local pmc pconf, plog, ptemp
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')

    # decline if we have no handler in this section
    $S0 = cfg['pre_connection_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'

    # get the pool objects
    # XXX need access to these from the context!
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'conn_rec'
    c = $P0()
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'csd'
    csd = $P0()

    status = handler(c, csd)

    # return status code
    .return(status)
.end

# process connection handler
.sub process_connection_handler
    .param pmc ctx
    .local pmc s, handler, cfg, get_config, ap_const, c
    .local pmc pconf, plog, ptemp
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')

    # decline if we have no handler in this section
    $S0 = cfg['process_connection_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'

    # get the pool objects
    # XXX need access to these from the context!
    $P0 = get_root_global [ 'ModParrot'; 'NCI' ], 'conn_rec'
    c = $P0()

    status = handler(c)

    # return status code
    .return(status)

.end

# trans handler
.sub trans_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['trans_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)
.end

# fixup handler
.sub fixup_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['fixup_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)
.end

# type handler
.sub type_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['type_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)
.end

# log handler
.sub log_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['log_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)
.end

# map_to_storage handler
.sub map_to_storage_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['map_to_storage_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)
.end

# post_read_request handler
.sub post_read_request_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['post_read_request_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)

.end

# header_parser handler
.sub header_parser_handler
    .param pmc ctx
    .local pmc r, handler, cfg, dircfg, get_config, ap_const
    .local int status

    ap_const = get_root_global ['ModParrot'; 'Apache'; 'Constants'], 'table'

    # get the request_rec object
    r = ctx.'request_rec'()

    # get configs
    get_config = get_hll_global ['ModParrot'; 'Apache'; 'Module'], 'get_config'
    cfg = get_config('modparrot_pir_module')
    $P0 = r.'per_dir_config'()
    dircfg = get_config('modparrot_pir_module', $P0)

    # decline if we have no config in this section
    unless null dircfg goto get_handler
    status = ap_const['DECLINED']
    .return(status)

  get_handler:
    # decline if we have no handler in this section
    $S0 = dircfg['header_parser_handler']
    if $S0 goto run_handler
    status = ap_const['DECLINED']
    .return(status)

  run_handler:
    # find the handler sub and call it
    $P0 = split ';', $S0
    get_hll_global handler, $P0, 'handler'
    status = handler(r)

    # return status code
    .return(status)
.end
