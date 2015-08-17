/* $Id: nci.c 618 2009-03-01 15:32:10Z jhorwitz $ */

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

/* This file is for mod_parrot specific functions that should be callable from
 * parrot via NCI. Every function should be prefixed with mpnci_. */

#include "httpd.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_config.h"
#include "apr_strings.h"
#include "apr_hash.h"

#include "parrot/parrot.h"
#include "parrot/embed.h"
#include "parrot/extend.h"

#include "mod_parrot.h"
#include "modparrot_config.h"

#include "../build/src/nci/request_rec.c"
#include "../build/src/nci/server_rec.c"

extern module AP_MODULE_DECLARE_DATA parrot_module;
extern modparrot_globals mp_globals;

/* used from PIR to pass C-style NULLs to NCI functions */
void *mpnci_null(void)
{
    return (void *)NULL;
}

request_rec *mpnci_request_rec(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->r);
}

struct ap_conf_vector_t *mpnci_request_rec_per_dir_config(Parrot_Interp interp,
    request_rec *r)
{
    return(r->per_dir_config);
}

server_rec *mpnci_request_rec_server(Parrot_Interp interp,
    request_rec *r)
{
    return(r->server);
}

apr_pool_t *mpnci_conf_pool(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->pconf);
}

apr_pool_t *mpnci_temp_pool(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->ptemp);
}

apr_pool_t *mpnci_log_pool(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->plog);
}

apr_pool_t *mpnci_child_pool(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->pchild);
}

server_rec *mpnci_server_rec(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->s);
}

conn_rec *mpnci_conn_rec(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->c);
}

conn_rec *mpnci_csd(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->csd);
}

modparrot_module_config *mpnci_raw_srv_config(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->raw_srv_config);
}

modparrot_module_config *mpnci_raw_dir_config(Parrot_Interp interp)
{
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    return(ctxp->raw_dir_config);
}

const char *mpnci_ctx_pool_name(Parrot_Interp interp)
{
    modparrot_context *ctxp;
    const char *name;

    ctxp = get_interp_ctx(interp);
    name = modparrot_get_ctx_pool_name(ctxp->ctx_pool);
    return(name);
}

request_rec *mpnci_request_rec_main(Parrot_Interp interp, request_rec *r)
{
    return(r->main);
}

request_rec *mpnci_request_rec_next(Parrot_Interp interp, request_rec *r)
{
    return(r->next);
}

request_rec *mpnci_request_rec_prev(Parrot_Interp interp, request_rec *r)
{
    return(r->prev);
}

apr_table_t *mpnci_request_rec_notes(Parrot_Interp interp, request_rec *r)
{
    return(r->notes);
}

apr_table_t *mpnci_request_rec_headers_in(Parrot_Interp interp, request_rec *r)
{
    return(r->headers_in);
}

apr_table_t *mpnci_request_rec_headers_out(Parrot_Interp interp, request_rec *r)
{
    return(r->headers_out);
}

apr_table_t *mpnci_request_rec_err_headers_out(Parrot_Interp interp,
                                               request_rec *r)
{
    return(r->err_headers_out);
}

/* We implement ap_get_basic_auth_pw as a wrapper because there is no NCI
 * signature type that handles the function's char ** password parameter.
 * Instead, we return the results in a PMC array passed in from the caller.
 */
int mpnci_request_rec_get_basic_auth_pw(Parrot_Interp interp, request_rec *r,
    Parrot_PMC results)
{
    int status;
    char *pw = NULL;
    Parrot_String spw;
    modparrot_context *ctxp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return HTTP_INTERNAL_SERVER_ERROR;
    status = ap_get_basic_auth_pw(r, (const char **)&pw);
    spw = Parrot_new_string(ctxp->interp,
        pw ? pw : "", pw ? strlen(pw) : 0, "iso-8859-1", 0);
    Parrot_PMC_set_intval_intkey(interp, results, 0, status);
    Parrot_PMC_set_string_intkey(interp, results, 1, spw);
    return(status);
} 

int mpnci_rwrite(Parrot_Interp interp, Parrot_PMC p, int size, request_rec *r)
{
    modparrot_context *ctxp;
    Parrot_Int plen;
    int len;
    char *buf;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return 0;

    buf = Parrot_PMC_get_cstringn(ctxp->interp, p, &plen);
    len = ap_rwrite(buf, (plen < size) ? len : size, r);
    Parrot_str_free_cstring(buf);

    return(len);
}

size_t mpnci_request_read(Parrot_Interp interp, Parrot_PMC pbuf, size_t len,
    request_rec *r)
{
    modparrot_context *ctxp;
    Parrot_Interp interpreter;
    char *buf;
    int bytes;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return 0;
    interpreter = ctxp->interp;

    /* buf should be freed by apache when the request pool is destroyed */
    buf = apr_pcalloc(r->pool, len);
    bytes = modparrot_request_read(r, buf, len);
    Parrot_PMC_set_cstringn(interp, pbuf, buf, bytes);

    return(bytes);
}

char *mpnci_backtrace(Parrot_Interp interp)
{
    return (char *)modparrot_backtrace(interp);
}

void mpnci_ap_log_rerror(Parrot_Interp interp, char *file, int line, int level,
    apr_status_t status, request_rec *r, char *msg)
{
    ap_log_rerror(file, line, level, status, r, "%s", msg);
}

module *mpnci_add_apache_module(Parrot_Interp interp,
                                const char *name,
                                char *namespace,
                                Parrot_PMC cmd_array,
                                Parrot_PMC hook_array)
{
    modparrot_context *ctxp;
    module *modp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;
    modp = modparrot_add_module(interp, ctxp->pconf, name, namespace, 
        cmd_array, hook_array);
    return(modp);
}

Parrot_PMC mpnci_get_module_config(Parrot_Interp interp, char *name,
    ap_conf_vector_t *per_dir_config, int is_directory)
{
    modparrot_context *ctxp;
    modparrot_srv_config *mpcfg;
    modparrot_module_config *cfg;
    module *modp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return NULL;

    mpcfg = ap_get_module_config(ctxp->s->module_config, &parrot_module);
    modp = apr_hash_get(mp_globals.module_hash, name, APR_HASH_KEY_STRING);
    if (!modp) {
        return(NULL);
    }

    if (is_directory) {
        /* possibly do more here if not in a request */
        cfg = ap_get_module_config(ctxp->r->per_dir_config, modp);
    }
    else {
        cfg = ap_get_module_config(ctxp->s->module_config, modp);
    }

    /* return the PMC cfg inside the modparrot_module_config struct. if we
     * have no directives in the section, we'll have no dircfg, so we should
     * return PMCNULL.
     */
    return cfg ? cfg->cfg : PMCNULL;
}
 
server_rec *mpnci_cmd_parms_server(Parrot_Interp interp, cmd_parms *cmd)
{
    return(cmd->server);
}

apr_pool_t *mpnci_cmd_parms_pool(Parrot_Interp interp, cmd_parms *cmd)
{
    return(cmd->pool);
}

apr_pool_t *mpnci_cmd_parms_temp_pool(Parrot_Interp interp, cmd_parms *cmd)
{
    return(cmd->temp_pool);
}

const command_rec *mpnci_cmd_parms_cmd(Parrot_Interp interp, cmd_parms *cmd)
{
    return(cmd->cmd);
}

apr_pool_t *mpnci_request_rec_pool(Parrot_Interp interp, request_rec *r)
{
    return(r->pool);
}

apr_status_t modparrot_meta_cleanup_handler(void *);
void mpnci_register_pool_cleanup(Parrot_Interp interp, apr_pool_t *p,
    Parrot_PMC sub, Parrot_PMC data)
{
    modparrot_cleanup_info *ci;
    modparrot_context *ctxp;
    modparrot_srv_config *cfg;
    module *modp;

    ctxp = get_interp_ctx(interp);
    if (!ctxp) return;

    /* get current module */
    cfg = ap_get_module_config(ctxp->s->module_config, &parrot_module);
    modp = ((module **)mp_globals.module_array->elts)[ctxp->module_index];

    /* register the data PMC b/c it will likely go out of scope in the HLL */
    if (!PMC_IS_NULL(data)) {
        Parrot_register_pmc(interp, data);
    }

    /* populate cleanup info */
    ci = apr_pcalloc(p, sizeof(modparrot_cleanup_info));
    ci->module = modp;
    ci->callback = sub;
    ci->hll_data = data;
    ci->s = ctxp->s;
    ci->pool = p;

    /* register the handler */
    apr_pool_cleanup_register(p, ci, modparrot_meta_cleanup_handler, NULL);
}

void mpnci_set_config_ctx_pool(Parrot_Interp interp,
    modparrot_module_config *cfg, char *pool_name)
{
    modparrot_context *ctxp = get_interp_ctx(interp);
    cfg->ctx_pool_name = (char *)apr_pstrdup(ctxp->pconf, pool_name);
}
