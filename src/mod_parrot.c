/* $Id: mod_parrot.c 644 2009-06-16 00:02:37Z jhorwitz $ */

/* Copyright (c) 2004, 2005, 2007, 2008 Jeff Horwitz
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

#include <string.h>

#include "apr_strings.h"

#include "httpd.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_config.h"
#include "http_request.h"
#include "http_core.h"
#include "http_connection.h"
#include "http_main.h"
#include "ap_mpm.h"

#include "parrot/parrot.h"
#include "parrot/embed.h"
#include "parrot/extend.h"

#define HAVE_LOCAL_DEBUG_LEVEL 1
#include "mod_parrot.h"
#include "modparrot_config.h"
#include "modparrot_log.h"

#define MODPARROT_VERSION "0.5"

#define NEXT_HANDLER_MODULE(x) (mp_globals.handler_modules[x] ? ((module **)mp_globals.module_array->elts)[((int *)mp_globals.handler_modules[x]->elts)[++(ctxp->module_index)]] : NULL);

/* a single structure for globals */
modparrot_globals mp_globals;

/* declare our module */
extern module AP_MODULE_DECLARE_DATA parrot_module;

void modparrot_init_globals(apr_pool_t *p)
{
    int i;

    mp_globals.pconf = p;
    mp_globals.is_started = 0;
    mp_globals.debug_level = 0;
    mp_globals.max_threads = 0;
    mp_globals.hard_thread_limit = 0;
    mp_globals.base_server = NULL;
    mp_globals.module_hash = apr_hash_make(p);
    mp_globals.module_array = apr_array_make(p, 1, sizeof(module *));;
    mp_globals.ctx_pool_hash = apr_hash_make(p);
    for (i = 0; i < MP_HOOK_LAST; i++) {
        mp_globals.handler_modules[i] = NULL;
    }
}

void modparrot_trace(server_rec *s, const char *fmt, ...)
{
    va_list ap;
    char log[1000];

    va_start(ap, fmt);
    vsnprintf(log, sizeof(log), fmt, ap);
    va_end(ap);
    MPLOG_DEBUG(s, log);
}

void modparrot_load_file(Parrot_Interp interp, server_rec *s, const char *file)
{
    int ret;

    char *ext = strrchr(file, '.');
    /* load any valid parrot files (PIR, PBC, PASM) */
    if (ext && (!strcmp(ext, ".pbc") || !strcmp(ext, ".pir") ||
        !strcmp(ext, ".pasm"))) {
        modparrot_load_bytecode(interp, (char *)file);
    }
    else {
        MPLOG_ERRORF(s, "'%s' is not a valid Parrot file", file);
    }
}

/* should we return something? */
static void modparrot_load_files(Parrot_Interp interp, server_rec *s,
                                 apr_array_header_t *files)
{
    int i, ret;

    for (i = 0; i < files->nelts; i++) {
        const char *path =
            ((char **)files->elts)[i];
        modparrot_load_file(interp, s, path);
    }
}

static Parrot_Interp modparrot_init(modparrot_context *ctx, server_rec *s)
{
    Parrot_Interp interp;
    modparrot_srv_config *cfg;
    int i;

    cfg = ap_get_module_config(s->module_config, &parrot_module);
    if (cfg->trace_flags == -1) cfg->trace_flags = 0;

    /* initialize interpreter */
    interp = modparrot_init_interpreter(mp_globals.root_interp);
    if (!mp_globals.root_interp) mp_globals.root_interp = interp;

    /* enable tracing */
    Parrot_set_trace(interp, (cfg->option_flags & MP_OPT_TRACE_INIT) ?
        cfg->trace_flags : 0);

    /* if appropriate, set path to mod_parrot module (for some dlopens) */
    if (cfg->so_path) {
        Parrot_PMC path;
        int typenum = Parrot_PMC_typenum(interp, "String");
        path = Parrot_PMC_new(interp, typenum);
        Parrot_register_pmc(interp, path);
        Parrot_PMC_set_cstring(interp, path, cfg->so_path);
        Parrot_store_global_s(
            interp,
            string_from_literal(interp, "_modparrot"),
            string_from_literal(interp, "__module_path"),
            path
        );
    }

    /* load the init code */
    modparrot_load_bytecode(interp,
        cfg->init_path ? cfg->init_path : MODPARROT_DEFAULT_INIT);

    /* set additional paths from apache config */
    if (cfg->include_path) {
        /* XXX set to "include_path" when tests & docs are updated */
        modparrot_call_sub_IS(interp, "ModParrot",
            "modparrot_set_lib_path", &i, cfg->include_path);
    }
    if (cfg->lib_path) {
        modparrot_call_sub_IS(interp, "ModParrot",
            "modparrot_set_lib_path", &i, cfg->lib_path);
    }
    if (cfg->dynext_path) {
        modparrot_call_sub_IS(interp, "ModParrot",
            "modparrot_set_dynext_path", &i, cfg->dynext_path);
    }

    /* initialize parrot side */
    modparrot_call_sub(interp, "ModParrot", "modparrot_init");

    /* set our context
     * Since there is a one-to-one relationship between threads and
     * interpreters, we can store our context as a global in each interpreter.
     */
    set_interp_ctx(interp, ctx);

    return(interp);
}

static apr_array_header_t *select_ctx_pool(module *modp, server_rec *s,
    ap_conf_vector_t *per_dir_config)
{
    modparrot_module_config *cfg;
    modparrot_module_info *minfo = modp->dynamic_load_handle;
    apr_array_header_t *cp;

    /* try section scope first */
    if (per_dir_config) {
        cfg = ap_get_module_config(per_dir_config, modp);
        if (cfg) {
            /* section pools might be dynamic, so always look up by name */
            if (cfg->ctx_pool_name) {
                MP_TRACE_c(s, "select_ctx_pool: using section pool '%s'", cfg->ctx_pool_name);
                cp = modparrot_get_named_ctx_pool(cfg->ctx_pool_name);
                if (!cp) {
                    /* XXX need a startup w/o init_ctx side-effect */
                    modparrot_context *ctxp = modparrot_startup(
                        mp_globals.pconf, s, NULL, cfg->ctx_pool_name);
                    release_ctx(ctxp);
                }
                return(cp);
            }
        }
    }

    /* now try server scope */
    cfg = ap_get_module_config(s->module_config, modp);
    if (cfg) {
        if (cfg->ctx_pool) {
            MP_TRACE_c(s, "select_ctx_pool: using server pool '%s'", cfg->ctx_pool_name);
            /* server pools are static, so return the cached pool */
            return(cfg->ctx_pool);
        }
    }

    /* fall back to the module's default pool */
    MP_TRACE_c(s, "select_ctx_pool: using module default pool");
    /* module pools are static, so return the cached pool */
    return(minfo->ctx_pool);
}

static modparrot_context *init_ctx(server_rec *s, apr_pool_t *p,
    apr_array_header_t *ctx_pool)
{
    Parrot_Interp interp;
    modparrot_context *ctxp = (modparrot_context *)NULL;
    modparrot_srv_config *cfg;

    cfg = ap_get_module_config(s->module_config, &parrot_module);

    /* grab the current context... */
    if (p) ctxp = modparrot_get_current_ctx(p);

    /* ...but ignore it if it doesn't belong to the requested context pool */
    if (ctxp && ctx_pool) {
        if (ctxp->ctx_pool != ctx_pool) ctxp = NULL;
    }

    if (!ctxp) {
        apr_array_header_t *cp = ctx_pool ? ctx_pool : cfg->ctx_pool;
        if ((ctxp = reserve_ctx(cp, MP_CTX_ANY))) {
            if (!ctxp->interp) {
                if (!(interp = modparrot_init(ctxp, s))) {
                    MPLOG_ERROR(s,
                        "init_ctx: interpreter initialization failed");
                    return (modparrot_context *)NULL;
                }
                ctxp->interp = interp;
            }
            else {
                interp = ctxp->interp;
            }

            /* remember this context for next time */
            if (p) modparrot_set_current_ctx(p, ctxp);
        }
        else {
            MPLOG_ERROR(s, "init_ctx: no free contexts");
        }
    }

    /* usually set s in a hook, but need it here for the config phase */
    if (ctxp) {
        ctxp->s = s;
    }

    MP_TRACE_c(s, "init_ctx: using context %p", ctxp);

    return(ctxp);
}

static modparrot_context *clone_ctx_state(modparrot_context *cur_ctxp,
    apr_array_header_t *new_ctx_pool, server_rec *s, apr_pool_t *p)
{
    modparrot_context *ctxp;

    /* don't clone from same pool, just return current context */
    if (cur_ctxp->ctx_pool == new_ctx_pool) return cur_ctxp;

    /* grab a context from the requested pool */
    if (!(ctxp = init_ctx(s, p, new_ctx_pool))) {
        MPLOG_ERROR(s, "context initialization failed");
        return NULL;
    }

    MP_TRACE_c(s, "cloning context %p -> %p", cur_ctxp, ctxp);

    /* copy relevant cached data from current context */
    ctxp->r = cur_ctxp->r;
    ctxp->s = cur_ctxp->s;
    ctxp->pconf = cur_ctxp->pconf;
    ctxp->plog = cur_ctxp->plog;
    ctxp->ptemp = cur_ctxp->ptemp;
    ctxp->pchild = cur_ctxp->pchild;
    ctxp->c = cur_ctxp->c;
    ctxp->csd = cur_ctxp->csd;
    ctxp->module_index = cur_ctxp->module_index;

    /* NOTE: caller must release the old context */

    return(ctxp);
}

/* public interface for starting an interpreter */
modparrot_context *modparrot_startup(apr_pool_t *p, server_rec *s,
    Parrot_Interp parent_interp, const char *pool_name)
{
    modparrot_context *ctxp;
    modparrot_srv_config *cfg;
    apr_array_header_t *ctx_pool = NULL;
    const char *name;

    cfg = ap_get_module_config(s->module_config, &parrot_module);

    if (!mp_globals.is_started) mp_globals.base_server = s;

    name = pool_name ? pool_name : "default";
    if (mp_globals.is_started) {
        ctx_pool = modparrot_get_named_ctx_pool(name);
    }

    if (!ctx_pool) {
        if (!(ctx_pool = mp_ctx_pool_init(p, parent_interp, 1))) {
            MPLOG_ERROR(s, "context pool creation failed");
            return NULL;
        }
        /* name the pool so we can reference it later */
        modparrot_set_named_ctx_pool(p, name, ctx_pool);
        MP_TRACE_c(s, "modparrot_startup: context pool %p is named '%s'", ctx_pool, name);

        /* if server doesn't have a context pool, assign this one */
        if (!cfg->ctx_pool) {
            cfg->ctx_pool = ctx_pool;
            MP_TRACE_c(s, "context pool %p (%s) is default for server %p", ctx_pool, name, s);
        }
    }

    MP_TRACE_c(s, "modparrot_startup: using context pool %p (%s)", ctx_pool, name);

    /* grab a context from the pool */
    if ((ctxp = init_ctx(s, p, ctx_pool))) {
        if (!mp_globals.is_started) {
            mp_globals.is_started = 1;
        }
    }
    else {
        MPLOG_ERROR(s, "context initialization failed");
        return NULL;
    }

    return(ctxp);
}

static int modparrot_call_meta_handler(Parrot_Interp interp, char *hll,
    char *hook, int *ret)
{
    Parrot_PMC ctx_class;
    Parrot_PMC ctx_pmc;
    Parrot_PMC namespace;
    Parrot_PMC sub;
    Parrot_Int typenum;
    int res;

    typenum = Parrot_PMC_typenum(interp, "ResizableStringArray");
    namespace = (Parrot_PMC)Parrot_PMC_new(interp, typenum);
    Parrot_register_pmc(interp, namespace);
    Parrot_PMC_set_intval(interp, namespace, 2);
    Parrot_PMC_set_cstring_intkey(interp, namespace, 0, "ModParrot");
    Parrot_PMC_set_cstring_intkey(interp, namespace, 1, "Context");
    ctx_class = Parrot_oo_get_class(interp, namespace);
    Parrot_unregister_pmc(interp, namespace);

    ctx_pmc = VTABLE_instantiate(interp, ctx_class, PMCNULL);
    Parrot_register_pmc(interp, ctx_pmc);

    if (!hll) hll = MODPARROT_DEFAULT_HLL;
    sub = modparrot_get_meta_handler(interp, hll, hook);
    res = modparrot_call_meta_handler_sub(interp, sub, ret, ctx_pmc);
    Parrot_unregister_pmc(interp, ctx_pmc);
    return res ? 1 : 0;
}

static int modparrot_request_phase_handler(request_rec *r)
{
    modparrot_context *ctxp;

    MP_TRACE_h(r->server, "in modparrot_request_phase_handler");

    /* initialize context */
    if (!(ctxp = init_ctx(r->server, r->connection->pool, NULL))) {
        MPLOG_ERROR(r->server, "context initialization failed");
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* we're FIRST, so reset the module index */
    ctxp->module_index = -1;

    /* set the most specific pool */
    ctxp->pool = r->pool;

    return DECLINED;
}

static int modparrot_pre_connection_handler(conn_rec *c, void *csd)
{
    modparrot_context *ctxp;

    MP_TRACE_h(c->base_server, "in modparrot_pre_connection_handler");

    /* initialize context */
    if (!(ctxp = init_ctx(c->base_server, c->pool, NULL))) {
        MPLOG_ERROR(c->base_server, "context initialization failed");
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* we're REALLY_FIRST, so reset the module index */
    ctxp->module_index = -1;

    /* set the most specific pool */
    ctxp->pool = c->pool;

    /* we only do setup */
    return DECLINED;
}

/* XXX if we're not doing anything here, don't register it! */
static apr_status_t modparrot_request_cleanup(void *data)
{
    return APR_SUCCESS;
}

apr_status_t modparrot_meta_cleanup_handler(void *data)
{
    modparrot_cleanup_info *ci = (modparrot_cleanup_info *)data;
    modparrot_context *ctxp;
    int status;

    /* initialize context */
    if (!(ctxp = init_ctx(ci->s, ci->pool, NULL))) {
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* call cleanup sub, passing HLL data from ci */
    status = Parrot_call_sub_ret_int(ctxp->interp, ci->callback, "IP",
        ci->hll_data ? ci->hll_data : PMCNULL);

    /* we don't need the data PMC anymore */
    if (!PMC_IS_NULL(data)) {
        Parrot_unregister_pmc(ctxp->interp, data);
    }

    return status;
}

#define MP_REQUEST_METAHANDLER(hname, henum, register_cleanup) \
    int modparrot_meta_##hname(request_rec *r) \
    { \
        modparrot_context *ctxp, *cloned; \
        modparrot_module_config *dircfg; \
        modparrot_srv_config *mpcfg; \
        module *modp; \
        modparrot_module_info *minfo; \
        Parrot_PMC sub; \
        int status; \
        MP_TRACE_h(r->server, "in modparrot_meta_%s", #hname); \
        /* initialize context */ \
        if (!(ctxp = init_ctx(r->server, r->connection->pool, NULL))) { \
            MPLOG_ERROR(r->server, "context initialization failed"); \
            return HTTP_INTERNAL_SERVER_ERROR; \
        } \
        /* decline if mod_parrot isn't enabled */ \
        mpcfg = ap_get_module_config(r->server->module_config, \
            &parrot_module); \
        /* get next module in line */ \
        if (!(mpcfg->option_flags & MP_OPT_ENABLE)) return DECLINED; \
        modp = NEXT_HANDLER_MODULE(henum); \
        cloned = clone_ctx_state(ctxp, \
            select_ctx_pool(modp, r->server, r->per_dir_config), r->server, \
                r->pool); \
        if (cloned != ctxp) { \
            release_ctx(ctxp); \
            ctxp = cloned; \
        } \
        /* take this opportunity to register the request cleanup handler \
         * here, as we may not handle any other part of the request until \
         * then. NOTE: this is mod_parrot internal only and NOT for HLLs. \
         */ \
        if (register_cleanup) { \
            /* XXX if callback doesn't do anything, don't register it! */ \
            apr_pool_cleanup_register(r->pool, r, \
                modparrot_request_cleanup, apr_pool_cleanup_null); \
        } \
        ctxp->r = r; \
        /* XXX does header_only check belong in the meta handler? */ \
        if (r->header_only) { \
            return OK; \
        } \
        /* get HLL config */ \
        minfo = (modparrot_module_info *)modp->dynamic_load_handle; \
        dircfg = (modparrot_module_config *)ap_get_module_config( \
            r->per_dir_config, modp); \
        /* call meta handler */ \
        MP_TRACE_h(r->server, "calling %s for %s", #hname, minfo->namespace); \
        if (!modparrot_call_meta_handler(ctxp->interp, minfo->namespace, \
            #hname , &status)) { \
            MPLOG_ERRORF(r->server, \
                #hname " not found in module '%s'", \
                modp->name); \
            status = HTTP_INTERNAL_SERVER_ERROR; \
        } \
        /* tell apache we're done */ \
        return status; \
    }

MP_REQUEST_METAHANDLER(post_read_request_handler, MP_HOOK_POST_READ_REQUEST, 1)
MP_REQUEST_METAHANDLER(map_to_storage_handler, MP_HOOK_MAP_TO_STORAGE, 0)
MP_REQUEST_METAHANDLER(trans_handler, MP_HOOK_TRANS, 0)
MP_REQUEST_METAHANDLER(header_parser_handler, MP_HOOK_HEADER_PARSER, 0)
MP_REQUEST_METAHANDLER(access_handler, MP_HOOK_ACCESS, 0)
MP_REQUEST_METAHANDLER(authen_handler, MP_HOOK_AUTHEN, 0)
MP_REQUEST_METAHANDLER(authz_handler, MP_HOOK_AUTHZ, 0)
MP_REQUEST_METAHANDLER(response_handler, MP_HOOK_RESPONSE, 0)
MP_REQUEST_METAHANDLER(type_handler, MP_HOOK_TYPE, 0)
MP_REQUEST_METAHANDLER(fixup_handler, MP_HOOK_FIXUP, 0)
MP_REQUEST_METAHANDLER(log_handler, MP_HOOK_LOG, 0)

int modparrot_meta_pre_connection_handler(conn_rec *c, void *csd)
{
    modparrot_context *ctxp, *cloned;
    modparrot_srv_config *mpcfg;
    module *modp;
    modparrot_module_info *minfo;
    Parrot_PMC sub;
    int status;

    MP_TRACE_h(c->base_server, "in modparrot_meta_pre_connection_handler");

    /* initialize context */
    if (!(ctxp = init_ctx(c->base_server, c->pool, NULL))) {
        MPLOG_ERROR(c->base_server, "context initialization failed");
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* decline if mod_parrot isn't enabled */
    mpcfg = ap_get_module_config(c->base_server->module_config, &parrot_module);
    if (!(mpcfg->option_flags & MP_OPT_ENABLE)) return DECLINED;

    /* get next module in line */
    modp = NEXT_HANDLER_MODULE(MP_HOOK_PRE_CONNECTION);

    cloned = clone_ctx_state(ctxp, select_ctx_pool(modp, c->base_server, NULL),
        c->base_server, c->pool);
    if (cloned != ctxp) {
        release_ctx(ctxp);
        ctxp = cloned;
    }

    ctxp->c = c;
    ctxp->csd = csd;

    /* get HLL config */
    minfo = (modparrot_module_info *)modp->dynamic_load_handle;
    /* call meta handler */
    MP_TRACE_h(c->base_server, "calling pre_connection_handler for %s", minfo->namespace); 
    if (!modparrot_call_meta_handler(ctxp->interp, minfo->namespace,
       "pre_connection_handler", &status)) {
        MPLOG_ERRORF(c->base_server,
            "no pre_connection metahandler found for module '%s'", modp->name);
        status = HTTP_INTERNAL_SERVER_ERROR;
    }

    /* tell apache we're done */
    return status;
}

static int modparrot_process_connection_handler(conn_rec *c)
{
    modparrot_context *ctxp;

    MP_TRACE_h(c->base_server, "in modparrot_process_connection_handler");

    /* initialize context */
    if (!(ctxp = init_ctx(c->base_server, c->pool, NULL))) {
        MPLOG_ERROR(c->base_server, "context initialization failed");
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* we're REALLY_FIRST, so reset the module index */
    ctxp->module_index = -1;

    /* set the most specific pool */
    ctxp->pool = c->pool;

    /* we only do setup */
    return DECLINED;
}

int modparrot_meta_process_connection_handler(conn_rec *c)
{
    modparrot_context *ctxp, *cloned;
    modparrot_srv_config *mpcfg;
    module *modp;
    modparrot_module_info *minfo;
    Parrot_PMC sub;
    int status;

    MP_TRACE_h(c->base_server, "in modparrot_meta_process_connection_handler");

    /* initialize context */
    if (!(ctxp = init_ctx(c->base_server, c->pool, NULL))) {
        MPLOG_ERROR(c->base_server, "context initialization failed");
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* decline if mod_parrot isn't enabled */
    mpcfg = ap_get_module_config(c->base_server->module_config, &parrot_module);
    if (!(mpcfg->option_flags & MP_OPT_ENABLE)) return DECLINED;

    /* get next module in line */
    modp = NEXT_HANDLER_MODULE(MP_HOOK_PROCESS_CONNECTION);

    cloned = clone_ctx_state(ctxp, select_ctx_pool(modp, c->base_server, NULL),
        c->base_server, c->pool);
    if (cloned != ctxp) {
        release_ctx(ctxp);
        ctxp = cloned;
    }

    ctxp->c = c;

    /* get HLL config */
    minfo = (modparrot_module_info *)modp->dynamic_load_handle;
    /* call meta handler */
    MP_TRACE_h(c->base_server, "calling process_connection_handler for %s", minfo->namespace); 
    if (!modparrot_call_meta_handler(ctxp->interp, minfo->namespace,
       "process_connection_handler", &status)) {
        MPLOG_ERRORF(c->base_server,
            "no process_connection metahandler found for module '%s'",
            modp->name);
        status = HTTP_INTERNAL_SERVER_ERROR;
    }

    /* tell apache we're done */
    return status;
}

static void modparrot_child_init_handler(apr_pool_t *p, server_rec *s)
{
    modparrot_context *ctxp;

    MP_TRACE_h(s, "in modparrot_child_init_handler");

    /* initialize context */
    if (!(ctxp = init_ctx(s, NULL, NULL))) {
        MPLOG_ERROR(s, "context initialization failed");
        return;
    }

    /* we're FIRST, so reset the module index */
    ctxp->module_index = -1;

    /* query apache mpm for thread limits */
#ifdef MPM_IS_THREADED
    ap_mpm_query(AP_MPMQ_HARD_LIMIT_THREADS, &mp_globals.hard_thread_limit);
    ap_mpm_query(AP_MPMQ_MAX_THREADS, &mp_globals.max_threads);
#else /* MPM_IS_THREADED */
    mp_globals.hard_thread_limit = 1;
    mp_globals.max_threads = 1;
#endif /* MPM_IS_THREADED */

    /* set the most specific pool */
    ctxp->pool = p;

    release_ctx(ctxp);
}

/* XXX - how do we notify apache of failures with a void return??? */
void modparrot_meta_child_init_handler(apr_pool_t *p, server_rec *s)
{
    modparrot_context *ctxp, *cloned;
    modparrot_srv_config *mpcfg;
    module *modp;
    modparrot_module_info *minfo;
    Parrot_PMC sub;
    int status;

    MP_TRACE_h(s, "in modparrot_meta_child_init_handler");

    /* initialize context */
    if (!(ctxp = init_ctx(s, NULL, NULL))) {
        MPLOG_ERROR(s, "context initialization failed");
        return;
    }

    /* decline if mod_parrot isn't enabled */
    mpcfg = ap_get_module_config(s->module_config, &parrot_module);
    if (!(mpcfg->option_flags & MP_OPT_ENABLE)) return;

    /* get next module in line */
    modp = NEXT_HANDLER_MODULE(MP_HOOK_CHILD_INIT);

    cloned = clone_ctx_state(ctxp, select_ctx_pool(modp, s, NULL), s, p);
    if (cloned != ctxp) {
        release_ctx(ctxp);
        ctxp = cloned;
    }

    ctxp->pchild = p;
    ctxp->s = s;

    /* get HLL config */
    minfo = (modparrot_module_info *)modp->dynamic_load_handle;
    /* call meta handler */
    MP_TRACE_h(s, "calling child_init_handler for %s", minfo->namespace);
    if (!modparrot_call_meta_handler(ctxp->interp, minfo->namespace,
       "child_init_handler", &status)) {
        MPLOG_ERRORF(s, "no child_init metahandler found for module '%s'",
            modp->name);
    }

    release_ctx(ctxp);
}

static int modparrot_post_config_handler(apr_pool_t *pconf, apr_pool_t *plog,
    apr_pool_t *ptemp, server_rec *s)
{
    modparrot_context *ctxp;

    MP_TRACE_h(s, "in modparrot_post_config_handler");

    /* add our version component */
    ap_add_version_component(pconf, "mod_parrot/" MODPARROT_VERSION);

    /* initialize context */
    if (!(ctxp = init_ctx(s, ptemp, NULL))) {
        MPLOG_ERROR(s, "context initialization failed");
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* we're FIRST, so reset the module index */
    ctxp->module_index = -1;

    /* set the most specific pool */
    ctxp->pool = pconf;

    /* we only do setup */
    return DECLINED;
}

int modparrot_meta_post_config_handler(apr_pool_t *pconf,
    apr_pool_t *plog, apr_pool_t *ptemp, server_rec *s)
{
    modparrot_context *ctxp, *cloned;
    modparrot_srv_config *mpcfg;
    module *modp;
    modparrot_module_info *minfo;
    Parrot_PMC sub;
    int status;

    MP_TRACE_h(s, "in modparrot_meta_post_config_handler");

    /* initialize context */
    if (!(ctxp = init_ctx(s, ptemp, NULL))) {
        MPLOG_ERROR(s, "context initialization failed");
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* decline if mod_parrot isn't enabled */
    mpcfg = ap_get_module_config(s->module_config, &parrot_module);
    if (!(mpcfg->option_flags & MP_OPT_ENABLE)) return DECLINED;

    /* get next module in line */
    modp = NEXT_HANDLER_MODULE(MP_HOOK_POST_CONFIG);

    cloned = clone_ctx_state(ctxp, select_ctx_pool(modp, s, NULL), s, ptemp);
    if (cloned != ctxp) {
        release_ctx(ctxp);
        ctxp = cloned;
    }

    ctxp->pconf = pconf;
    ctxp->plog = plog;
    ctxp->ptemp = ptemp;
    ctxp->s = s;

    /* get HLL config */
    minfo = (modparrot_module_info *)modp->dynamic_load_handle;
    /* call meta handler */
    MP_TRACE_h(s, "calling post_config_handler for %s", minfo->namespace);
    if (!modparrot_call_meta_handler(ctxp->interp, minfo->namespace,
       "post_config_handler", &status)) {
        MPLOG_ERRORF(s, "no post_config metahandler found for module '%s'",
            modp->name);
        status = HTTP_INTERNAL_SERVER_ERROR;
    }

    /* tell apache we're done */
    return status;
}

static int modparrot_open_logs_handler(apr_pool_t *pconf, apr_pool_t *plog,
    apr_pool_t *ptemp, server_rec *s)
{
    modparrot_context *ctxp;
    modparrot_srv_config *mpcfg;
    Parrot_Interp parent_interp;
    server_rec *vs;

    MP_TRACE_h(s, "in modparrot_open_logs_handler");
    /* get apache configs */
    mpcfg = ap_get_module_config(s->module_config, &parrot_module);

    if (mpcfg->option_flags & MP_OPT_ENABLE) {
        if (!(ctxp = modparrot_startup(ptemp, s, NULL, NULL))) {
            return HTTP_INTERNAL_SERVER_ERROR;
        }
        ctxp->pconf = pconf;
        parent_interp = ctxp->interp;

        /* we're FIRST, so reset the module index */
        ctxp->module_index = -1;

        /* set the most specific pool */
        ctxp->pool = pconf;

        /* load ParrotLoad files */
        modparrot_load_files(ctxp->interp, s, mpcfg->preload);

        /* if we weren't tracing the initialization phase, enable tracing now */
        if (!(mpcfg->option_flags & MP_OPT_TRACE_INIT)) {
            Parrot_set_trace(ctxp->interp, mpcfg->trace_flags);
        }
    }

    /* init per-server (MP_OPT_PARENT) or per-process (default) pools */
    for (vs = s->next; vs; vs = vs->next) {
        modparrot_srv_config *vscfg;
        modparrot_context *vsctxp;
        vscfg = ap_get_module_config(vs->module_config, &parrot_module);
        if (!(vscfg->option_flags & MP_OPT_ENABLE)) continue;
        if (vscfg->option_flags & MP_OPT_PARENT) {
            if (!(vsctxp = modparrot_startup(ptemp, vs, parent_interp, NULL))) {
                return HTTP_INTERNAL_SERVER_ERROR;
            }
            vsctxp->pconf = pconf;

            /* we're FIRST, so reset the module index */
            vsctxp->module_index = -1;

            /* set the most specific pool */
            ctxp->pool = pconf;

            /* load ParrotLoad files */
            modparrot_load_files(vsctxp->interp, vs, vscfg->preload);

            /* if we weren't tracing the initialization phase, enable tracing */
            if (!(vscfg->option_flags & MP_OPT_TRACE_INIT)) {
                Parrot_set_trace(vsctxp->interp, vscfg->trace_flags);
            }
        }
        else {
            /* XXX is this check redundant (MP_OPT_ENABLE is checked above) */
            if (vscfg->option_flags & MP_OPT_ENABLE) {
                vscfg->ctx_pool = mpcfg->ctx_pool;
            }
            else {
                MPLOG_ERROR(vs,
                "must use +Parent if mod_parrot is disabled in main server");
            }
        }
    }

    /* tell apache we're done -- open_logs handler must return OK */
    return OK;
}

int modparrot_meta_open_logs_handler(apr_pool_t *pconf,
    apr_pool_t *plog, apr_pool_t *ptemp, server_rec *s)
{
    apr_array_header_t *ctx_pool;
    modparrot_context *ctxp, *cloned;
    modparrot_srv_config *mpcfg;
    module *modp;
    modparrot_module_info *minfo;
    Parrot_PMC sub;
    server_rec *vs;
    int status;

    MP_TRACE_h(s, "in modparrot_meta_open_logs_handler (main server)");

    /* initialize context */
    if (!(ctxp = init_ctx(s, ptemp, NULL))) {
        MPLOG_ERROR(s, "context initialization failed");
        return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* get next module in line */
    modp = NEXT_HANDLER_MODULE(MP_HOOK_OPEN_LOGS);

    cloned = clone_ctx_state(ctxp, select_ctx_pool(modp, s, NULL), s, ptemp);
    if (cloned != ctxp) {
        release_ctx(ctxp);
        ctxp = cloned;
    }

    /* decline if mod_parrot isn't enabled -- but open_logs must return OK */
    mpcfg = ap_get_module_config(s->module_config, &parrot_module);
    if (!(mpcfg->option_flags & MP_OPT_ENABLE)) return OK;

    ctxp->pconf = pconf;
    ctxp->plog = plog;
    ctxp->ptemp = ptemp;
    ctxp->s = s;

    /* get HLL config */
    minfo = (modparrot_module_info *)modp->dynamic_load_handle;
    /* call meta handler */
    MP_TRACE_h(s, "calling open_logs_handler for %s", minfo->namespace);
    if (!modparrot_call_meta_handler(ctxp->interp, minfo->namespace,
       "open_logs_handler", &status)) {
        MPLOG_ERRORF(s, "no open_logs metahandler found for module '%s'",
            modp->name);
        status = HTTP_INTERNAL_SERVER_ERROR;
    }

    /* all open_logs handlers must return OK, so stop here if it didn't */
    if (status != OK) return status;

    /* now do the same thing with each virtual host */
    for (vs = s->next; vs; vs = vs->next) {
        modparrot_srv_config *vscfg;
        modparrot_module_config *cfg;

        vscfg = ap_get_module_config(vs->module_config, &parrot_module);
        if (!(vscfg->option_flags & MP_OPT_ENABLE)) continue;

        MP_TRACE_h(vs, "in modparrot_meta_open_logs_handler (s=%p)", vs);

        /* we duplicate some efforts here because we only find out about
         * named context pools configured from an HLL when we're already in
         * that HLL's meta handler. got that? */

        /* check for a per-server context pool */
        cfg = ap_get_module_config(vs->module_config, modp);
        if (cfg->ctx_pool_name) {
            MP_TRACE_c(vs, "server %p has a per-server context pool '%s'", vs, cfg->ctx_pool_name);
            if (!(ctxp = modparrot_startup(pconf, vs, NULL,
                cfg->ctx_pool_name))) {
                return HTTP_INTERNAL_SERVER_ERROR;
            }
            /* cache for later -- select_ctx_pool depends on it! */
            cfg->ctx_pool = ctxp->ctx_pool;
        }
        else {
            MP_TRACE_c(vs, "using default context pool for server %p", vs);
        }

        cloned = clone_ctx_state(ctxp,
            select_ctx_pool(modp, vs, NULL), vs, ptemp);
        if (cloned != ctxp) {
            release_ctx(ctxp);
            ctxp = cloned;
        }

        /* reset the server_rec, but everything else should be ok */
        ctxp->s = vs;

        /* load ParrotLoad files */
        modparrot_load_files(ctxp->interp, vs, vscfg->preload);

        /* if we weren't tracing the initialization phase, enable tracing */
        if (!(vscfg->option_flags & MP_OPT_TRACE_INIT)) {
            Parrot_set_trace(ctxp->interp, vscfg->trace_flags);
        }

        /* get HLL config */
        minfo = (modparrot_module_info *)modp->dynamic_load_handle;

        /* call meta handler */
        MP_TRACE_h(vs, "calling open_logs_handler for %s", minfo->namespace);
        if (!modparrot_call_meta_handler(ctxp->interp, minfo->namespace,
           "open_logs_handler", &status)) {
            MPLOG_ERRORF(vs, "no open_logs metahandler found for module '%s'",
                modp->name);
            status = HTTP_INTERNAL_SERVER_ERROR;
        }

        /* all open_logs handlers must return OK, so stop here if it didn't */
        if (status != OK) break;
    }

    /* tell apache we're done */
    return status;
}

static void register_hooks(apr_pool_t *p)
{
    MP_TRACE_h(mp_globals.base_server, "in register_hooks");

    /* initialize globals before we do anything else */
    modparrot_init_globals(p);

    /* this allows <IfDefine MODPARROT> blocks */
    *(char **)apr_array_push(ap_server_config_defines) =
        (char *)apr_pstrdup(p, "MODPARROT");

    /* register the various hooks.  all request phase hooks are handled by
     * modparrot_request_phase_handler, as the calling conventions and
     * and semantics of each hook in this phase are identical.
     */
    ap_hook_open_logs(modparrot_open_logs_handler, NULL, NULL, APR_HOOK_FIRST);
    ap_hook_post_config(modparrot_post_config_handler, NULL, NULL,
        APR_HOOK_FIRST);
    ap_hook_child_init(modparrot_child_init_handler, NULL, NULL,
        APR_HOOK_FIRST);
    ap_hook_pre_connection(modparrot_pre_connection_handler, NULL, NULL,
        APR_HOOK_FIRST);
    ap_hook_process_connection(modparrot_process_connection_handler, NULL,
        NULL, APR_HOOK_FIRST);
    ap_hook_map_to_storage(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_translate_name(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_post_read_request(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_header_parser(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_access_checker(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_check_user_id(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_auth_checker(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_handler(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_type_checker(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_fixups(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
    ap_hook_log_transaction(modparrot_request_phase_handler, NULL, NULL,
        APR_HOOK_REALLY_FIRST);
}

static const command_rec modparrot_cmds[] =
{
    AP_INIT_TAKE1(
        "ParrotInit",
        modparrot_cmd_init,
        NULL,
        RSRC_CONF,
        "modparrot initialization file"
    ),
    AP_INIT_TAKE1(
        "ParrotDebugLevel",
        modparrot_cmd_debug,
        NULL,
        RSRC_CONF,
        "set mod_parrot debugging level (default is 0)"
    ),
    AP_INIT_TAKE1(
        "ParrotTrace",
        modparrot_cmd_trace,
        NULL,
        RSRC_CONF,
        "set Parrot opcode tracing level (default is 0)"
    ),
    AP_INIT_ITERATE(
        "ParrotLoad",
        modparrot_cmd_load,
        NULL,
        RSRC_CONF,
        "preload Parrot code"
    ),
    AP_INIT_TAKE12(
        "ParrotLoadImmediate",
        modparrot_cmd_load_immediate,
        NULL,
        RSRC_CONF,
        "start interpreter early and load Parrot code"
    ),
    AP_INIT_TAKE1(
        "ParrotIncludePath",
        modparrot_cmd_include_path,
        NULL,
        RSRC_CONF,
        "set the Parrot include path"
    ),
    AP_INIT_TAKE1(
        "ParrotLibPath",
        modparrot_cmd_lib_path,
        NULL,
        RSRC_CONF,
        "set the Parrot library path"
    ),
    AP_INIT_TAKE1(
        "ParrotDynextPath",
        modparrot_cmd_dynext_path,
        NULL,
        RSRC_CONF,
        "set the Parrot dynext path"
    ),
    AP_INIT_ITERATE(
        "ParrotOptions",
        modparrot_cmd_options,
        NULL,
        RSRC_CONF,
        "set mod_parrot options"
    ),
    { NULL }
};

module AP_MODULE_DECLARE_DATA parrot_module =
{
    STANDARD20_MODULE_STUFF,
    NULL, /* create_modparrot_dir_config */
    NULL, /* merge_modparrot_dir_config */
    create_modparrot_srv_config,
    merge_modparrot_srv_config,
    modparrot_cmds,
    register_hooks
};
