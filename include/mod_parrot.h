/* $Id: mod_parrot.h 644 2009-06-16 00:02:37Z jhorwitz $ */

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

#ifndef _MODPARROT_H
#define _MODPARROT_H

#include "httpd.h"
#include "http_config.h"

/* apache handler name */
#define MODPARROT_MAGIC "parrot-code"

/* default HLL, if we can't determine from the request */
#define MODPARROT_DEFAULT_HLL "PIR"

/* default path to initialization bytecode */
#define MODPARROT_DEFAULT_INIT "mod_parrot.pbc"

/* string macros */
#define MAKE_PARROT_STRING(x) (Parrot_str_new(interp, x, strlen(x)))

/* context macros */
#define MODPARROT_CTX_ISLOCKED(x) (x->locked == 1)
#define MODPARROT_CTX_LOCK(x) (x->locked = 1)
#define MODPARROT_CTX_UNLOCK(x) (x->locked = 0)
#define MP_CTX_ANY (-1)

/* keys */
#define MP_KEY_CTX "modparrot-context"

/* we need to move things around to avoid this */
#include "modparrot_config.h"

/* globals! */
struct modparrot_globals
{
    apr_pool_t *pconf;
    apr_hash_t *module_hash;
    apr_array_header_t *module_array;
    apr_array_header_t *handler_modules[MP_HOOK_LAST];
    apr_hash_t *ctx_pool_hash;
    Parrot_Interp root_interp;
    server_rec *base_server;
    int is_started;
    int debug_level;
    int hard_thread_limit;
    int max_threads;
};
typedef struct modparrot_globals modparrot_globals;

/* per-interpreter context */
struct modparrot_context
{
    apr_array_header_t *ctx_pool; /* the pool containing this context */
    const char *ctx_pool_name;    /* name of the context pool */
    Parrot_Interp interp;         /* this context's interpreter */
    Parrot_Interp parent_interp;  /* parent interpreter */
    long count;                   /* number of interpreter invocations */
    int locked;                   /* 0=available, 1=in use */
    request_rec *r;               /* request_rec structure for this request */
    apr_pool_t *pool;             /* the pool most specific to this phase */
    apr_pool_t *pconf;
    apr_pool_t *plog;
    apr_pool_t *ptemp;
    apr_pool_t *pchild;
    server_rec *s;
    conn_rec *c;
    void *csd;
    modparrot_module_config *raw_srv_config;
    modparrot_module_config *raw_dir_config;
    int module_index;
};
typedef struct modparrot_context modparrot_context;

/* internal info for pool cleanup handlers */
struct modparrot_cleanup_info {
    module *module;      /* the HLL module that registered us */
    Parrot_PMC callback; /* callback subroutine */
    Parrot_PMC hll_data; /* a PMC to pass to the callback */
    apr_pool_t *pool;    /* the pool for which the cleanup was registered */
    server_rec *s;       /* used for context init */
};
typedef struct modparrot_cleanup_info modparrot_cleanup_info;

/* misc prototypes */
Parrot_Interp modparrot_init_interpreter(Parrot_Interp);
int modparrot_load_bytecode(Parrot_Interp, char *);
void modparrot_destroy_interpreter(Parrot_Interp);
int modparrot_call_sub(Parrot_Interp, char *, char *);
int modparrot_call_sub_Iv(Parrot_Interp, char *, char *, int *);
int modparrot_call_sub_IS(Parrot_Interp, char *, char *, int *, char *);
int modparrot_call_sub_IP(Parrot_Interp, char *, char *, int *, Parrot_PMC);
int modparrot_call_sub_IPS(Parrot_Interp, char *, char *, int *, Parrot_PMC,
    char *);
char *modparrot_backtrace(Parrot_Interp);
Parrot_PMC get_sub_pmc(Parrot_Interp , char *, char *);
Parrot_PMC modparrot_get_meta_handler(Parrot_Interp , char *, char *);
int modparrot_call_meta_handler_sub(Parrot_Interp, Parrot_PMC, int *,
    Parrot_PMC);
apr_array_header_t *mp_ctx_pool_init(apr_pool_t *, Parrot_Interp, int);
void mp_ctx_pool_destroy(apr_array_header_t *);
modparrot_context *reserve_ctx(apr_array_header_t *, int index);
void release_ctx(modparrot_context *);
modparrot_context *get_interp_ctx(Parrot_Interp);
void set_interp_ctx(Parrot_Interp, modparrot_context *);
modparrot_context *modparrot_startup(apr_pool_t *, server_rec *, Parrot_Interp, const char *);
void modparrot_load_file(Parrot_Interp, server_rec *, const char *);
module *modparrot_add_module(Parrot_Interp, apr_pool_t *, const char *, char *,
    Parrot_PMC, Parrot_PMC);
modparrot_context *modparrot_get_current_ctx(apr_pool_t *);
void modparrot_set_current_ctx(apr_pool_t *, modparrot_context *);
apr_size_t modparrot_request_read(request_rec *, char *, apr_size_t);
Parrot_PMC modparrot_wrap_apache_type(Parrot_Interp, char *, char *, void *);
apr_array_header_t *modparrot_get_named_ctx_pool(const char *);
void modparrot_set_named_ctx_pool(apr_pool_t *p, const char *,
    apr_array_header_t *);
const char *modparrot_get_ctx_pool_name(apr_array_header_t *);

/* macros for wrapping apache types */
#define modparrot_wrap_apr_pool(i, x) \
    (modparrot_wrap_apache_type(i, "ModParrot;APR;Pool", "apr_pool", x))

#define modparrot_wrap_conn_rec(i, x) \
    (modparrot_wrap_apache_type(i, "ModParrot;Apache;ConnRec", \
    "conn_rec", x))

#define modparrot_wrap_server_rec(i, x) \
    (modparrot_wrap_apache_type(i, "ModParrot;Apache;ServerRec", \
    "server_rec", x))

#define modparrot_wrap_cmd_parms(i, x) \
    (modparrot_wrap_apache_type(i, "ModParrot;Apache;CmdParms", \
    "cmd_parms", x))

#endif /* _MODPARROT_H */
