/* $Id$ */

/* Copyright (c) 2008 Jeff Horwitz
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "httpd.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_config.h"
#include "http_request.h"
#include "http_core.h"
#include "http_connection.h"
#include "http_main.h"
#include "mpm.h"
#include "apr_strings.h"

#include "parrot/parrot.h"
#include "parrot/embed.h"
#include "parrot/extend.h"

#include "mod_parrot.h"
#include "modparrot_config.h"
#include "modparrot_log.h"

AP_DECLARE_DATA extern module *ap_top_module;
extern module AP_MODULE_DECLARE_DATA parrot_module;
extern modparrot_globals mp_globals;

static apr_status_t modparrot_remove_module(void *data)
{
    module *modp = (module *)data;
    ap_remove_loaded_module(modp);
    return APR_SUCCESS;
}

static void modparrot_insert_module(module *modp)
{
    module *m;

    for (m = ap_top_module; m; m = m->next) {
        if (m == &parrot_module) {
            module *next = m->next;
            m->next = modp;
            modp->next = next;
            break;
        }
    }
}

static modparrot_module_config *modparrot_create_module_config(apr_pool_t *p)
{
    modparrot_module_config *cfg = (modparrot_module_config *)apr_pcalloc(p,
        sizeof(modparrot_module_config));
    return(cfg);
}

void *modparrot_module_srv_create(apr_pool_t *p, server_rec *s)
{
    modparrot_module_config *cfg = modparrot_create_module_config(p);
    return(cfg);
}

void *modparrot_module_srv_merge(apr_pool_t *p, void *base, void *new)
{
    modparrot_module_config *basecfg =(modparrot_module_config *)base;
    modparrot_module_config *newcfg =(modparrot_module_config *)new;
    modparrot_module_config *mergedcfg = modparrot_create_module_config(p);
    modparrot_srv_config *mpcfg =
        ap_get_module_config(mp_globals.base_server->module_config, &parrot_module);
    module *modp = apr_hash_get(mp_globals.module_hash, basecfg->name,
        APR_HASH_KEY_STRING);
    modparrot_module_info *minfo = modp->dynamic_load_handle;

    /* if we're here, then by definition we have a merge sub -- MAKE SURE! */
    assert(minfo->server_merge_sub);

    /* grab our current context.  the pool should be the config pool */
    modparrot_context *ctxp = modparrot_get_current_ctx(p);
    assert(ctxp);

    mergedcfg->name = basecfg->name; /* XXX should we copy this instead? */
    mergedcfg->minfo = basecfg->minfo;
    mergedcfg->ctx_pool_name = apr_pstrdup(p, newcfg->ctx_pool_name ?
        newcfg->ctx_pool_name : basecfg->ctx_pool_name);
    mergedcfg->ctx_pool = newcfg->ctx_pool ?
        newcfg->ctx_pool : basecfg->ctx_pool;

    /* unregister existing config */
    if (mergedcfg->cfg) {
        if (!PMC_IS_NULL(mergedcfg->cfg)) {
            Parrot_unregister_pmc(ctxp->interp, mergedcfg->cfg);
        }
    }

    /* call merge routine */
    MP_TRACE_m(mp_globals.base_server, "calling server_merge for module '%s'", modp->name);
    mergedcfg->cfg = Parrot_call_sub(ctxp->interp, minfo->server_merge_sub,
        "PPP", basecfg->cfg, newcfg->cfg);

    /* register merged config */
    if (!PMC_IS_NULL(mergedcfg->cfg)) {
        Parrot_register_pmc(ctxp->interp, mergedcfg->cfg);
    }

    return mergedcfg;
}

void *modparrot_module_dir_create(apr_pool_t *p, char *path)
{
    modparrot_module_config *cfg = modparrot_create_module_config(p);
    return(cfg);
}

void *modparrot_module_dir_merge(apr_pool_t *p, void *base, void *new)
{
    modparrot_module_config *basecfg =(modparrot_module_config *)base;
    modparrot_module_config *newcfg =(modparrot_module_config *)new;
    modparrot_module_config *mergedcfg = modparrot_create_module_config(p);
    modparrot_srv_config *mpcfg =
        ap_get_module_config(mp_globals.base_server->module_config, &parrot_module);
    module *modp = apr_hash_get(mp_globals.module_hash, basecfg->name,
        APR_HASH_KEY_STRING);
    modparrot_module_info *minfo = modp->dynamic_load_handle;

    /* if we're here, then by definition we have a merge sub -- MAKE SURE! */
    assert(minfo->dir_merge_sub);

    /* grab our current context.  we might be using the request pool before
     * we've begun the request phase, also check for the context bound to
     * the connection pool, which is the parent of the request pool */
    modparrot_context *ctxp = modparrot_get_current_ctx(p);
    if (!ctxp) ctxp = modparrot_get_current_ctx(apr_pool_parent_get(p));
    assert(ctxp);
    
    mergedcfg->name = basecfg->name; /* XXX should we copy this instead? */
    mergedcfg->minfo = basecfg->minfo;
    mergedcfg->ctx_pool_name = apr_pstrdup(p, newcfg->ctx_pool_name ?
        newcfg->ctx_pool_name : basecfg->ctx_pool_name);
    mergedcfg->ctx_pool = newcfg->ctx_pool ?
        newcfg->ctx_pool : basecfg->ctx_pool;

    /* unregister existing config */
    if (mergedcfg->cfg) {
        if (!PMC_IS_NULL(mergedcfg->cfg)) {
            Parrot_unregister_pmc(ctxp->interp, mergedcfg->cfg);
        }
    }

    /* call merge routine */
    MP_TRACE_m(mp_globals.base_server, "calling dir_merge for module '%s'", modp->name);
    mergedcfg->cfg = Parrot_call_sub(ctxp->interp, minfo->dir_merge_sub,
        "PPP", basecfg->cfg, newcfg->cfg);

    /* register merged config */
    if (!PMC_IS_NULL(mergedcfg->cfg)) {
        Parrot_register_pmc(ctxp->interp, mergedcfg->cfg);
    }
 
    return(mergedcfg);
}

static Parrot_PMC make_cmd_args_array(Parrot_Interp interp, apr_pool_t *p,
    int nargs, ...)
{
    va_list ap;
    Parrot_PMC args;
    int i=0, typenum;

    typenum = Parrot_PMC_typenum(interp, "ResizablePMCArray");
    args = (Parrot_PMC)Parrot_PMC_new(interp, typenum);
    Parrot_register_pmc(interp, args);
    Parrot_PMC_set_intval(interp, args, nargs);

    va_start(ap, nargs);
    for (i = 0; i < nargs; i++) {
        char *arg = va_arg(ap, char *);
        if (arg) {
            Parrot_PMC_set_cstring_intkey(interp, args, i, arg);
        }
        else {
            Parrot_PMC_set_pmc_intkey(interp, args, i, PMCNULL);
        }
    }
    va_end(ap);

    return(args);
}

static const char *modparrot_module_cmd_take123(cmd_parms *cmd, void *mconfig,
                                       const char *arg1,
                                       const char *arg2,
                                       const char *arg3)
{
    modparrot_context *ctxp;
    Parrot_PMC args;
    Parrot_PMC parms_pmc;
    modparrot_module_cmd_data *data = cmd->cmd->cmd_data;
    modparrot_module_info *minfo = data->modp->dynamic_load_handle;
    modparrot_module_config *srvcfg, *dircfg;
    const char *ctx_pool_name;
    int ret;

    MP_TRACE_m(cmd->server, \
               "in modparrot_module_cmd_take123 for directive '%s'", \
               cmd->directive->directive);

    /* mod_parrot specific stuff */
    if (!minfo->ctx_pool_name) {
        ctx_pool_name = modparrot_get_ctx_pool_name(minfo->ctx_pool);
        minfo->ctx_pool_name = ctx_pool_name;
    }
    else {
        ctx_pool_name = minfo->ctx_pool_name;
    }
    ctxp = modparrot_startup(cmd->temp_pool, cmd->server, NULL, ctx_pool_name);
    ctxp->pconf = cmd->pool;

    /* create a ModParrot;Apache;CmdParms object to pass to the handlers */
    parms_pmc = modparrot_wrap_cmd_parms(ctxp->interp, cmd);
    Parrot_register_pmc(ctxp->interp, parms_pmc);

    /* create/fetch module server config */
    srvcfg = (modparrot_module_config *)ap_get_module_config(
        cmd->server->module_config, data->modp);
    ctxp->raw_srv_config = srvcfg;
    if (srvcfg) {
        if (!srvcfg->cfg) {
            srvcfg->name = apr_pstrdup(cmd->pool, data->modp->name);
            if (minfo->server_create_sub) {
                MP_TRACE_m(cmd->server, \
                    "calling server_create for module '%s'", srvcfg->name);
                srvcfg->cfg = Parrot_call_sub(ctxp->interp,
                    minfo->server_create_sub, "PP", parms_pmc);
                if (!PMC_IS_NULL(srvcfg->cfg)) {
                    Parrot_register_pmc(ctxp->interp, srvcfg->cfg);
                }
            }
        }
    }

    /* create/fetch module directory config */
    dircfg = (modparrot_module_config *)mconfig;
    ctxp->raw_dir_config = dircfg;
    if (dircfg) {
        if (!dircfg->cfg) {
            dircfg->name = apr_pstrdup(cmd->pool, data->modp->name);
            if (minfo->dir_create_sub) {
                MP_TRACE_m(cmd->server, \
                    "calling dir_create for module '%s'", srvcfg->name);
                dircfg->cfg = Parrot_call_sub(ctxp->interp,
                    minfo->dir_create_sub, "PP", parms_pmc);
                if (!PMC_IS_NULL(dircfg->cfg)) {
                    Parrot_register_pmc(ctxp->interp, dircfg->cfg);
                }
            }
        }
    }

    args = make_cmd_args_array(ctxp->interp, cmd->pool, 3, arg1, arg2, arg3);

    ret = Parrot_call_sub_ret_int(ctxp->interp, data->func, "IPPP", parms_pmc,
        dircfg->cfg, args);

    /* we might not get a chance to clear these later, so do it now */
    ctxp->raw_srv_config = ctxp->raw_dir_config = NULL;

    Parrot_unregister_pmc(ctxp->interp, parms_pmc);

    return NULL;
}

static const char *modparrot_module_cmd_take1(cmd_parms *cmd, void *mconfig,
                                      const char *arg)
{
    return modparrot_module_cmd_take123(cmd, mconfig, arg, NULL, NULL);
}


static const char *modparrot_module_cmd_take2(cmd_parms *cmd, void *mconfig,
                                      const char *arg1, const char *arg2)
{
    return modparrot_module_cmd_take123(cmd, mconfig, arg1, arg2, NULL);
}

static const char *modparrot_module_cmd_no_args(cmd_parms *cmd, void *mconfig)
{
    return modparrot_module_cmd_take123(cmd, mconfig, NULL, NULL, NULL);
}

static const char *modparrot_module_cmd_flag(cmd_parms *cmd, void *mconfig,
                                             int flag)
{
    char buf[2];

    apr_snprintf(buf, sizeof(buf), "%d", flag);
    return modparrot_module_cmd_take123(cmd, mconfig, NULL, NULL, NULL);
}

#define modparrot_module_cmd_raw_args modparrot_module_cmd_take1
#define modparrot_module_cmd_iterate  modparrot_module_cmd_take1
#define modparrot_module_cmd_iterate2 modparrot_module_cmd_take2
#define modparrot_module_cmd_take12   modparrot_module_cmd_take2
#define modparrot_module_cmd_take23   modparrot_module_cmd_take123
#define modparrot_module_cmd_take3    modparrot_module_cmd_take123
#define modparrot_module_cmd_take13   modparrot_module_cmd_take123

static void register_meta_hooks(apr_pool_t *p)
{
    modparrot_srv_config *mpcfg;
    modparrot_module_config *cfg;
    modparrot_module_info *minfo;
    module *modp;
    int i;

    /* XXX does this also work for Apache >= 2.3 */
    static const char *aszSucc[] = { "mod_auth.c", NULL };

    /* initialize the index to 0 for the first module only */
    static int module_index = 0;

    /* this assumes we're called in the same order modules were added */
    mpcfg = ap_get_module_config(mp_globals.base_server->module_config,
        &parrot_module);
    modp = ((module **)mp_globals.module_array->elts)[module_index];
    minfo = modp->dynamic_load_handle;

    for (i = 0; i < MP_HOOK_LAST; i++) {
        if (minfo->hooks[i]) {
            int *pidx;
            /* add module to handler index so meta handlers know who we are */
            if (!mp_globals.handler_modules[i]) {
                mp_globals.handler_modules[i] =
                    apr_array_make(p, 1, sizeof(int));
            }
            pidx = (int *)apr_array_push(mp_globals.handler_modules[i]);
            *pidx = module_index;

            MP_TRACE_m(mp_globals.base_server, "registering hook %d for module '%s'", i, modp->name);

            /* register this hook with apache */
            switch(i) {
                case MP_HOOK_OPEN_LOGS:
                    ap_hook_open_logs(modparrot_meta_open_logs_handler, NULL,
                        NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_POST_CONFIG:
                    ap_hook_post_config(modparrot_meta_post_config_handler,
                        NULL, NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_CHILD_INIT:
                    ap_hook_child_init(modparrot_meta_child_init_handler, NULL,
                        NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_PRE_CONNECTION:
                    ap_hook_pre_connection(
                        modparrot_meta_pre_connection_handler, NULL, NULL,
                            APR_HOOK_FIRST);
                    break;
                case MP_HOOK_PROCESS_CONNECTION:
                    ap_hook_process_connection(
                        modparrot_meta_process_connection_handler, NULL, NULL,
                            APR_HOOK_FIRST);
                    break;
                case MP_HOOK_POST_READ_REQUEST:
                    ap_hook_post_read_request(
                        modparrot_meta_post_read_request_handler, NULL, NULL,
                            APR_HOOK_FIRST);
                    break;
                case MP_HOOK_MAP_TO_STORAGE:
                    ap_hook_map_to_storage(
                        modparrot_meta_map_to_storage_handler, NULL, NULL,
                            APR_HOOK_FIRST);
                    break;
                case MP_HOOK_TRANS:
                    ap_hook_translate_name(modparrot_meta_trans_handler, NULL,
                        NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_HEADER_PARSER:
                    ap_hook_header_parser(modparrot_meta_header_parser_handler,
                        NULL, NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_ACCESS:
                    ap_hook_access_checker(modparrot_meta_access_handler, NULL,
                        NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_AUTHEN:
                    ap_hook_check_user_id(modparrot_meta_authen_handler, NULL,
                        NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_AUTHZ:
                    ap_hook_auth_checker(modparrot_meta_authz_handler, NULL,
                        aszSucc, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_RESPONSE:
                    ap_hook_handler(modparrot_meta_response_handler, NULL,
                        NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_TYPE:
                    ap_hook_type_checker(modparrot_meta_type_handler, NULL,
                        NULL, APR_HOOK_FIRST);
                    break;
                case MP_HOOK_FIXUP:
                    ap_hook_fixups(modparrot_meta_fixup_handler, NULL, NULL,
                        APR_HOOK_FIRST);
                    break;
                case MP_HOOK_LOG:
                    ap_hook_log_transaction(modparrot_meta_log_handler, NULL,
                        NULL, APR_HOOK_FIRST);
                    break;
                default:
                    /* we should NEVER get here by definition */
                    break;
            }
        }
    }

    /* prepare for the next module */
    module_index++;
}

/* this is very leaky */
module *modparrot_add_module(Parrot_Interp interp, apr_pool_t *p,
                             const char *name,
                             char *namespace,
                             Parrot_PMC cmd_array,
                             Parrot_PMC hook_array)
{
    int i, num, hook_index, do_all=0;
    modparrot_srv_config *mpcfg;
    modparrot_module_info *minfo;
    Parrot_PMC sub;
    Parrot_PMC hpmc;
    module *modp;
    modparrot_context *ctxp = get_interp_ctx(interp);
    server_rec *s = ctxp->s;

    if (modp =
        apr_hash_get(mp_globals.module_hash, name, APR_HASH_KEY_STRING)) {
        MP_TRACE_m(s, "already added module '%s' - skipping", name);
        return(modp);
    }

    MP_TRACE_m(s, "adding module '%s'", name);

    modp = (module *)apr_pcalloc(p, sizeof(*modp));

    /* custom directives are optional */
    command_rec *cmds = NULL;
    if (PMC_IS_NULL(cmd_array)) {
        num = 0;
    }
    else {
        num = Parrot_PMC_get_intval(interp, cmd_array);
        if (num) {
            cmds = (command_rec *)apr_pcalloc(p, sizeof(command_rec)*(num+1));
        }
    }

    mpcfg = ap_get_module_config(s->module_config, &parrot_module);

    for (i = 0; i < num; i++) {
        Parrot_PMC val;
        Parrot_PMC cmd;
        modparrot_module_cmd_data *data =
            (modparrot_module_cmd_data *)apr_pcalloc(p,
                sizeof(modparrot_module_cmd_data));
        cmd = Parrot_PMC_get_pmc_keyed_int(interp, cmd_array, i);
        val = Parrot_PMC_get_pmc_keyed_str(interp, cmd,
                                        MAKE_PARROT_STRING("name"));
        cmds[i].name = Parrot_PMC_get_cstring(interp, val);

        val = Parrot_PMC_get_pmc_keyed_str(interp, cmd,
                                        MAKE_PARROT_STRING("args_how"));
        cmds[i].args_how = Parrot_PMC_get_intval(interp, val);

        switch(cmds[i].args_how) {
            case TAKE1:
                MP_INIT_CMD_TAKE1(cmds[i]);
                break;
            case TAKE2:
                MP_INIT_CMD_TAKE2(cmds[i]);
                break;
            case TAKE12:
                MP_INIT_CMD_TAKE12(cmds[i]);
                break;
            case TAKE3:
                MP_INIT_CMD_TAKE3(cmds[i]);
                break;
            case TAKE23:
                MP_INIT_CMD_TAKE23(cmds[i]);
                break;
            case TAKE123:
                MP_INIT_CMD_TAKE123(cmds[i]);
                break;
            case ITERATE:
                MP_INIT_CMD_ITERATE(cmds[i]);
                break;
            case ITERATE2:
                MP_INIT_CMD_ITERATE2(cmds[i]);
                break;
            case FLAG:
                MP_INIT_CMD_FLAG(cmds[i]);
                break;
            case NO_ARGS:
                MP_INIT_CMD_NO_ARGS(cmds[i]);
                break;
            case RAW_ARGS:
                MP_INIT_CMD_RAW_ARGS(cmds[i]);
                break;
            default: /* XXX how do we error out here??? */
                break;
        }

        val = Parrot_PMC_get_pmc_keyed_str(interp, cmd,
                                        MAKE_PARROT_STRING("req_override"));
        cmds[i].req_override = Parrot_PMC_get_intval(interp, val);

        val = Parrot_PMC_get_pmc_keyed_str(interp, cmd,
                                        MAKE_PARROT_STRING("errmsg"));
        cmds[i].errmsg = Parrot_PMC_get_cstring(interp, val);

        data->modp = modp;
        data->func = Parrot_PMC_get_pmc_keyed_str(interp, cmd,
                                        MAKE_PARROT_STRING("func"));
        if (PMC_IS_NULL(data->func)) {
            MPLOG_ERRORF(s, "callback not found for directive '%s'", \
               cmds[i].name);
            /* XXX is exit() the right thing to do here? */
            exit(1);
        }

        data->cmd_data = Parrot_PMC_get_pmc_keyed_str(interp, cmd,
                                        MAKE_PARROT_STRING("cmd_data"));
        cmds[i].cmd_data = data;

    MP_TRACE_m(s, "registered directive '%s' for module '%s'", cmds[i].name, name);
    }

    modp->version       = MODULE_MAGIC_NUMBER_MAJOR;
    modp->minor_version = MODULE_MAGIC_NUMBER_MINOR;
    modp->module_index  = -1;
    modp->name          = (char *)apr_pstrdup(p, name);
    modp->magic         = MODULE_MAGIC_COOKIE;

    minfo = apr_pcalloc(p, sizeof(modparrot_module_info));
    minfo->namespace = (char *)apr_pstrdup(p, namespace);
    minfo->ctx_pool_name = NULL;

    /* populate hook array for use by register_meta_hooks */
    num = Parrot_PMC_get_intval(interp, hook_array);
    if (num) {
        hpmc = Parrot_PMC_get_pmc_keyed_int(interp, hook_array, 0);
        hook_index = Parrot_PMC_get_intval(interp, hpmc);
        if (hook_index == MP_HOOK_ALL) {
            do_all = 1;
            for (i = 0; i < MP_HOOK_LAST; i++) {
                minfo->hooks[i] = 1;
            }
        }
    }
    for (i = 0; i < num && !do_all; i++) {
        hpmc = Parrot_PMC_get_pmc_keyed_int(interp, hook_array, i);
        hook_index = Parrot_PMC_get_intval(interp, hpmc);
        if (hook_index < 0 || hook_index >= MP_HOOK_LAST) {
            MPLOG_ERRORF(s, "invalid hook value in module '%s'", name);
	    /* XXX is exit() the right thing to do here? */
            exit(1);
        }
        minfo->hooks[hook_index] = 1;
    }
    modp->dynamic_load_handle = minfo;

    if (sub = modparrot_get_meta_handler(interp, namespace, "server_create")) {
        MP_TRACE_m(s, "registering server_create for module '%s'", name);
        modp->create_server_config = modparrot_module_srv_create;
        minfo->server_create_sub = sub;
    }
    if (sub = modparrot_get_meta_handler(interp, namespace, "server_merge")) {
        MP_TRACE_m(s, "registering server_merge for module '%s'", name);
        modp->merge_server_config = modparrot_module_srv_merge;
        minfo->server_merge_sub = sub;
    }
    if (sub = modparrot_get_meta_handler(interp, namespace, "dir_create")) {
        MP_TRACE_m(s, "registering dir_create for module '%s'", name);
        modp->create_dir_config = modparrot_module_dir_create;
        minfo->dir_create_sub = sub;
    }
    if (sub = modparrot_get_meta_handler(interp, namespace, "dir_merge")) {
        MP_TRACE_m(s, "registering dir_merge for module '%s'", name);
        modp->merge_dir_config = modparrot_module_dir_merge;
        minfo->dir_merge_sub = sub;
    }

    /* remember our context pool */
    minfo->ctx_pool = ctxp->ctx_pool;

    modp->cmds = cmds; /* our command vector */

    modp->register_hooks = register_meta_hooks;

    /* module_array lets us access modules in sequence */
    *(module **)apr_array_push(mp_globals.module_array) = modp;

    /* module_hash lets us access modules by name */
    apr_hash_set(mp_globals.module_hash, (char *)apr_pstrdup(p, modp->name),
        APR_HASH_KEY_STRING, modp);

    modparrot_insert_module(modp);

    ap_add_loaded_module(modp, p);

    MP_TRACE_m(s, "registration complete for module '%s'", name);

    apr_pool_cleanup_register(p, modp, modparrot_remove_module,
                              apr_pool_cleanup_null);

    return(modp);
}
