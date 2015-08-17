/* $Id: modparrot_config.c 622 2009-03-01 17:03:55Z jhorwitz $ */

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

#include "httpd.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_config.h"
#include "apr_strings.h"

#include "parrot/parrot.h"
#include "parrot/embed.h"
#include "parrot/extend.h"

#include "mod_parrot.h"
#include "modparrot_config.h"
#include "modparrot_log.h"

#if (__FreeBSD__)
# include <dlfcn.h>
# include "apr_dso.h"
#endif /* (__FreeBSD__) */

#define GET_SERVER_CONFIG(x) \
 ((modparrot_srv_config *)ap_get_module_config(\
 x->server->module_config, &parrot_module))

#define DEFAULT_OPTION_FLAGS (MP_OPT_ENABLE)

extern module AP_MODULE_DECLARE_DATA parrot_module;
extern modparrot_globals mp_globals;

static apr_status_t modparrot_cleanup(void *data)
{
    modparrot_srv_config *cfg;
    server_rec *s = (server_rec *)data;
    int i;

    cfg = ap_get_module_config(s->module_config, &parrot_module);

    /* destroy context pools and interpreters */
    mp_ctx_pool_destroy_all();
    cfg->ctx_pool = NULL;
    mp_globals.is_started = 0;

    /* reset module configs so we recreate them on restart */
    for (i = 0; i < mp_globals.module_array->nelts; i++) {
        modparrot_module_config *modcfg;
        modcfg = ((modparrot_module_config **)mp_globals.module_array->elts)[i];
        modcfg->cfg = NULL;
    }
    return APR_SUCCESS;
}

void *create_modparrot_srv_config(apr_pool_t *p, server_rec *s)
{
    modparrot_srv_config *cfg;
    int i;

    cfg = (modparrot_srv_config *)apr_pcalloc(p, sizeof(modparrot_srv_config));
    cfg->ctx_pool = NULL;
    cfg->pool = p;
    cfg->trace_flags = -1; /* -1 == unspecified */
    cfg->enable_option_flags = 0; /* only used during configuration merge */
    cfg->disable_option_flags = 0; /* only used during configuration merge */
    cfg->option_flags = DEFAULT_OPTION_FLAGS; /* set default options here */
    cfg->init_path = NULL;
    cfg->preload = apr_array_make(p, 2, sizeof(char *));
    cfg->include_path = NULL;
    cfg->lib_path = NULL;
    cfg->dynext_path = NULL;

    /* unfortunately, some OS-specific stuff */
#if (__FreeBSD__)
    {
        apr_os_dso_handle_t *osdso;
        char origin[PATH_MAX];
        apr_os_dso_handle_get((void *)&osdso,
            parrot_module.dynamic_load_handle);
        if (dlinfo(osdso, RTLD_DI_ORIGIN, &origin) != -1) {
            /* we know it's a Unix variant, so we can assume '/' and .so */
            char *path = apr_pstrcat(p, origin, "/", "mod_parrot.so", NULL);
            cfg->so_path = path;
        }
        else {
            cfg->so_path = NULL;
            fprintf(stderr, "dlinfo: %s", dlerror());
        }
    }
#else /* (__FreeBSD__) */
    cfg->so_path = NULL;
#endif /* (__FreeBSD__) */

    /* if we will have our own pool, destroy context pool on cleanup */
    if (!s->is_virtual ||
        (s->is_virtual && (cfg->option_flags | MP_OPT_PARENT))) {
        apr_pool_cleanup_register(p, s, modparrot_cleanup,
            apr_pool_cleanup_null);
    }

    return (void *)cfg;
}

void *merge_modparrot_srv_config(apr_pool_t *p, void *base, void *new)
{
    int i;
    modparrot_srv_config *basecfg = (modparrot_srv_config *)base;
    modparrot_srv_config *newcfg = (modparrot_srv_config *)new;
    modparrot_srv_config *merged = (modparrot_srv_config *)
        apr_pcalloc(p, sizeof(modparrot_srv_config));

    /* create base config options from enable & disable flags */
    basecfg->option_flags |= basecfg->enable_option_flags;
    basecfg->option_flags &= ~(basecfg->disable_option_flags);

    /* create new config options from enable & disable flags */
    newcfg->option_flags |= newcfg->enable_option_flags;
    newcfg->option_flags &= ~(newcfg->disable_option_flags);

    /* merge options first since we make decisions based on them */
    if (newcfg->option_flags & MP_OPT_PARENT) {
        merged->option_flags = newcfg->option_flags;
    }
    else {
        merged->option_flags = basecfg->option_flags;
        merged->option_flags |= newcfg->enable_option_flags;
        merged->option_flags &= ~(newcfg->disable_option_flags);
    }

    /* inherit the init_path, since it's rare it will change for a vhost */
    merged->init_path = newcfg->init_path ?
        newcfg->init_path : basecfg->init_path;

    /* merges specific to the Parent option */
    if (newcfg->option_flags & MP_OPT_PARENT) {
        merged->trace_flags = newcfg->trace_flags;
        merged->preload = apr_array_copy(p, newcfg->preload);
        merged->include_path = newcfg->include_path;
        merged->lib_path = newcfg->lib_path;
        merged->dynext_path = newcfg->dynext_path;
    }
    else {
        /* just override the scalars */
        merged->include_path = newcfg->include_path ?
            newcfg->include_path : basecfg->include_path;
        merged->lib_path = newcfg->lib_path ?
            newcfg->lib_path : basecfg->lib_path;
        merged->dynext_path = newcfg->dynext_path ?
            newcfg->dynext_path : basecfg->dynext_path;
        merged->trace_flags = (newcfg->trace_flags != -1) ?
            newcfg->trace_flags : basecfg->trace_flags;

        /* but concat the arrays */
        merged->preload = apr_array_copy(p, basecfg->preload);
        apr_array_cat(merged->preload, newcfg->preload);
    }

    return (void *)merged;
}

/* calculate option bit vector from enabled and disabled bits */
void modparrot_recalc_options(modparrot_srv_config *cfg)
{
    cfg->option_flags |= cfg->enable_option_flags;
    cfg->option_flags &= ~(cfg->disable_option_flags);
}

/* set an option from ParrotOptions
 * this is not static so we can call it from a handler
 */
int modparrot_set_option(modparrot_srv_config *cfg, char *option, int enable)
{
    int *flags;

    flags = enable ? &(cfg->enable_option_flags) : &(cfg->disable_option_flags);

    if (!strncasecmp(option, "Parent", 6)) {
        *flags |= MP_OPT_PARENT;
    }
    else if (!strncasecmp(option, "Enable", 6)) {
        *flags |= MP_OPT_ENABLE;
    }
    else if (!strncasecmp(option, "TraceInit", 9)) {
        *flags |= MP_OPT_TRACE_INIT;
    }
    else {
        return 0;
    }

    modparrot_recalc_options(cfg);

    return 1;
}

const char *modparrot_cmd_debug(cmd_parms *cmd, void *mconfig, const char *f)
{
    if (cmd->server->is_virtual) {
        MPLOG_WARN(cmd->server, "WARNING: ignoring ParrotDebugLevel in VirtualHost");
    }
    else {
        mp_globals.debug_level = atoi(f);
    }

    return NULL;
}

const char *modparrot_cmd_trace(cmd_parms *cmd, void *mconfig, const char *f)
{
    modparrot_srv_config *cfg;
    int flags;

    cfg = GET_SERVER_CONFIG(cmd);
    flags = atoi(f);
    cfg->trace_flags = flags;
    return NULL;
}

const char *modparrot_cmd_load(cmd_parms *cmd, void *mconfig,
    const char *path)
{
    modparrot_srv_config *cfg;

    cfg = GET_SERVER_CONFIG(cmd);
    *(char **)apr_array_push(cfg->preload) = apr_pstrdup(cmd->pool, path);

    return NULL;
}

const char *modparrot_cmd_load_immediate(cmd_parms *cmd, void *mconfig,
    const char *path, const char *pool_name)
{
    modparrot_srv_config *cfg;
    modparrot_context *ctxp;

    cfg = GET_SERVER_CONFIG(cmd);

    /* this will start the interpreter if necessary and return a context */
    ctxp = modparrot_startup(cmd->temp_pool, cmd->server, NULL, pool_name);
    ctxp->pconf = cmd->pool;

    modparrot_load_file(ctxp->interp, cmd->server, path);

    /* push onto the preload array so other interpreters can see the HLL
     * module.  modparrot_add_module won't add the module to apache again,
     * and parrot *shouldn't* try to load the bytecode again for the same
     * interpreter.
     */
    *(char **)apr_array_push(cfg->preload) = apr_pstrdup(cmd->pool, path);

    return NULL;
}

const char *modparrot_cmd_init(cmd_parms *cmd, void *mconfig, const char *path)
{
    modparrot_srv_config *cfg;

    cfg = GET_SERVER_CONFIG(cmd);
    cfg->init_path = (char *)apr_pstrdup(cmd->pool, path);
    return NULL;
}

const char *modparrot_cmd_include_path(cmd_parms *cmd, void *mconfig, const char *path)
{
    modparrot_srv_config *cfg;

    cfg = GET_SERVER_CONFIG(cmd);
    cfg->include_path = (char *)apr_pstrdup(cmd->pool, path);
    return NULL;
}

const char *modparrot_cmd_lib_path(cmd_parms *cmd, void *mconfig, const char *path)
{
    modparrot_srv_config *cfg;

    cfg = GET_SERVER_CONFIG(cmd);
    cfg->lib_path = (char *)apr_pstrdup(cmd->pool, path);
    return NULL;
}

const char *modparrot_cmd_dynext_path(cmd_parms *cmd, void *mconfig, const char *path)
{
    modparrot_srv_config *cfg;

    cfg = GET_SERVER_CONFIG(cmd);
    cfg->dynext_path = (char *)apr_pstrdup(cmd->pool, path);
    return NULL;
}

const char *modparrot_cmd_options(cmd_parms *cmd, void *mconfig, const char *option)
{
    modparrot_srv_config *cfg;
    char *p, *errmsg = NULL;

    cfg = GET_SERVER_CONFIG(cmd);
    switch(option[0]) {
        case '+':
            p = (char *)(option+1);
            if (!modparrot_set_option(cfg, p, 1)) {
                errmsg = apr_psprintf(cfg->pool, "unknown option '%s'", p);
            }
            break;
        case '-':
            p = (char *)(option+1);
            if (!modparrot_set_option(cfg, p, 0)) {
                errmsg = apr_psprintf(cfg->pool, "unknown option '%s'", p);
            }
            break;
        default:
            errmsg = apr_psprintf(cfg->pool,
                "missing +/- modifier for option '%s'", option);
    }
    return errmsg;
}
