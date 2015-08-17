/* $Id: context.c 634 2009-04-27 21:29:41Z jhorwitz $ */

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
#include "http_request.h"
#include "http_core.h"
#include "http_connection.h"
#include "http_main.h"
#include "mpm.h"
#include "apr_strings.h"
#include "apr_thread_mutex.h"

#include "parrot/parrot.h"
#include "parrot/embed.h"
#include "parrot/extend.h"

#include "mod_parrot.h"
#include "modparrot_config.h"
#include "modparrot_log.h"

#ifdef MPM_IS_THREADED
apr_thread_mutex_t *ctx_pool_mutex;
#endif /* MPM_IS_THREADED */

/* APR_ARRAY_IDX seems to be missing in earlier apaches */
#ifndef APR_ARRAY_IDX
#define APR_ARRAY_IDX(ary,i,type) (((type*)(ary)->elts)[i])
#endif /* APR_ARRAY_IDX */

extern modparrot_globals mp_globals;

/* initialize pool of contexts */
apr_array_header_t * mp_ctx_pool_init(apr_pool_t *p,
    Parrot_Interp parent_interp, int num)
{
    int i;
    apr_array_header_t *ctx_pool;
    modparrot_context *ctx;

    MP_TRACE_c(mp_globals.base_server, "creating context pool of size %d", num);

    if (!(ctx_pool = apr_array_make(p, num, sizeof(modparrot_context)))) {
        return NULL;
    }

    for (i = 0; i < num; i++) {
        ctx = (*(modparrot_context **)apr_array_push(ctx_pool) =
            (modparrot_context *)apr_pcalloc(p, sizeof(modparrot_context)));
        ctx->ctx_pool = ctx_pool;
        ctx->ctx_pool_name = NULL;
        ctx->parent_interp = parent_interp;
    }

#ifdef MPM_IS_THREADED
    if (apr_thread_mutex_create(&ctx_pool_mutex, APR_THREAD_MUTEX_DEFAULT, p)
        != APR_SUCCESS) {
        return NULL;
    }
#endif /* MPM_IS_THREADED */
        
    MP_TRACE_c(mp_globals.base_server, "created context pool %p (size %d)", ctx_pool, num);

    return ctx_pool;
}

/* destroy pool of contexts */
void mp_ctx_pool_destroy(apr_array_header_t *ctx_pool)
{
    modparrot_context **ctxpp;

    if (!ctx_pool) return;

    MP_TRACE_c(mp_globals.base_server, "destroying context pool %p", ctx_pool);

    /* pop each context off the list and destroy its interpreter */
#ifdef MPM_IS_THREADED
    apr_thread_mutex_lock(ctx_pool_mutex);
#endif /* MPM_IS_THREADED */
    while ((ctxpp = apr_array_pop(ctx_pool))) {
        if ((*ctxpp)->interp) {
            modparrot_destroy_interpreter((*ctxpp)->interp);
            (*ctxpp)->interp = NULL;
        }
    }
#ifdef MPM_IS_THREADED
    apr_thread_mutex_unlock(ctx_pool_mutex);
    apr_thread_mutex_destroy(ctx_pool_mutex);
#endif /* MPM_IS_THREADED */

    /* apache will take care of destroying the actual context pool array */
}

/* destroy all context pools */
void mp_ctx_pool_destroy_all(void)
{
    apr_pool_t *p;
    apr_hash_index_t *idx;
    char *name = NULL;

    apr_pool_create(&p, NULL);

    for (idx = apr_hash_first(p, mp_globals.ctx_pool_hash); idx;
        idx = apr_hash_next(idx)) {
        const void *key;
        apr_ssize_t klen;
        void *val;
        apr_hash_this(idx, &key, &klen, &val);
        mp_ctx_pool_destroy((apr_array_header_t *)val);
    }

    apr_pool_destroy(p);
}

/* finds and reserves a context for use by a handler */
modparrot_context *reserve_ctx(apr_array_header_t *ctx_pool, int index)
{
#ifdef MPM_IS_THREADED
    int i;
#endif /* MPM_IS_THREADED */
    modparrot_context *ctxp = (modparrot_context *)NULL;

    if (!ctx_pool) return NULL;

    MP_TRACE_c(mp_globals.base_server, "reserving a context from pool %p", ctx_pool);

#ifdef MPM_IS_THREADED
    apr_thread_mutex_lock(ctx_pool_mutex);
    if (index == MP_CTX_ANY) {
        for (i = 0; i < ctx_pool->nelts; i++) {
            modparrot_context *c;
            c = ((modparrot_context **)ctx_pool->elts)[i];
            if (MODPARROT_CTX_ISLOCKED(c)) continue;
            MODPARROT_CTX_LOCK(c);
            ctxp = c;
            break;
        }
    }
    else {
        if (ctxp = ((modparrot_context **)ctx_pool->elts)[index]) {
            if (MODPARROT_CTX_ISLOCKED(ctxp)) {
                ctxp = NULL;
            }
            else {
                MODPARROT_CTX_LOCK(ctxp);
            }
        }
    }
    apr_thread_mutex_unlock(ctx_pool_mutex);
#else /* MPM_IS_THREADED */
    ctxp = ((modparrot_context **)ctx_pool->elts)[0];
    MODPARROT_CTX_LOCK(ctxp); /* no threads here, just for consistency */
#endif /* MPM_IS_THREADED */

    MP_TRACE_c(mp_globals.base_server, "reserved context %p from pool %p", ctxp, ctx_pool);

    return(ctxp);
}

/* releases a context back into the pool of available contexts */
void release_ctx(modparrot_context *ctxp)
{
    MP_TRACE_c(mp_globals.base_server, "releasing context %p", ctxp);
    MODPARROT_CTX_UNLOCK(ctxp);
}

void set_interp_ctx(Parrot_Interp interp, modparrot_context *ctx)
{
    Parrot_PMC p;
    int typenum;

    typenum = Parrot_PMC_typenum(interp, "UnManagedStruct");
    p = Parrot_PMC_new(interp, typenum);
    Parrot_register_pmc(interp, p);
    Parrot_PMC_set_pointer(interp, p, ctx);
    Parrot_store_global_s(
        interp,
        string_from_literal(interp, "_modparrot"), 
        string_from_literal(interp, "__context"),
        p
    );

    ctx->interp = interp;
}

modparrot_context *get_interp_ctx(Parrot_Interp interp)
{
    Parrot_PMC p;
    modparrot_context *ctx = (modparrot_context *)NULL;

    p = Parrot_find_global_s(
        interp, 
        string_from_literal(interp, "_modparrot"), 
        string_from_literal(interp, "__context")
    );
    if (p) {
        ctx = Parrot_PMC_get_pointer(interp, p);
    }

    return ctx;
}

modparrot_context *modparrot_get_current_ctx(apr_pool_t *p)
{
    modparrot_context *ctxp;
    assert(p);
    apr_pool_userdata_get((void **)&ctxp, MP_KEY_CTX, p);
    return(ctxp);
}

static apr_status_t modparrot_ctx_cleanup(void *data)
{
    Parrot_PMC p;
    modparrot_context *ctxp = (modparrot_context *)data;
    if (ctxp->interp) {
        p = Parrot_find_global_s(
            ctxp->interp,
            string_from_literal(ctxp->interp, "_modparrot"),
            string_from_literal(ctxp->interp, "__context")
        );
        Parrot_unregister_pmc(ctxp->interp, p);
    }
    release_ctx(ctxp);
}

void modparrot_set_current_ctx(apr_pool_t *p, modparrot_context *ctxp)
{
    MP_TRACE_c(mp_globals.base_server, "binding context %p to APR pool %p", ctxp, p);
    apr_pool_userdata_set(ctxp, MP_KEY_CTX, modparrot_ctx_cleanup, p);
}

void modparrot_set_named_ctx_pool(apr_pool_t *p, const char *name,
    apr_array_header_t *cp)
{
    apr_hash_set(mp_globals.ctx_pool_hash, apr_pstrdup(p, name),
        APR_HASH_KEY_STRING, cp);
    /* we always have 1 valid context, so use it to store the pool name */
    APR_ARRAY_IDX(cp, 0, modparrot_context *)->ctx_pool_name =
        (const char *)apr_pstrdup(p, name);
}

apr_array_header_t *modparrot_get_named_ctx_pool(const char *name)
{
    apr_array_header_t *cp;

    cp = apr_hash_get(mp_globals.ctx_pool_hash, name, APR_HASH_KEY_STRING);
    return cp;
}

const char *modparrot_get_ctx_pool_name(apr_array_header_t *cp)
{
    /* we always have 1 valid context, so use it to retreive the pool name */
    return APR_ARRAY_IDX(cp, 0, modparrot_context *)->ctx_pool_name;
}
