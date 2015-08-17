/* $Id: modparrot_config.h 607 2009-02-07 21:05:14Z jhorwitz $ */

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

#ifndef _MODPARROT_CONFIG_H
#define _MODPARROT_CONFIG_H

#include "apr_tables.h"
#include "apr_hash.h"

/* per-server options */
#define MP_OPT_ENABLE 1
#define MP_OPT_PARENT 2
#define MP_OPT_TRACE_INIT 4

/* deal with absurdity from http_config.h */
#if defined(AP_HAVE_DESIGNATED_INITIALIZER) || defined(DOXYGEN)
#  define MP_INIT_CMD_TAKE1(c) (c.func.take1 = modparrot_module_cmd_take1)
#  define MP_INIT_CMD_TAKE2(c) (c.func.take2 = modparrot_module_cmd_take2)
#  define MP_INIT_CMD_TAKE12(c) (c.func.take2 = modparrot_module_cmd_take2)
#  define MP_INIT_CMD_TAKE3(c) (c.func.take3 = modparrot_module_cmd_take3)
#  define MP_INIT_CMD_TAKE23(c) (c.func.take3 = modparrot_module_cmd_take3)
#  define MP_INIT_CMD_TAKE123(c) (c.func.take3 = modparrot_module_cmd_take3)
#  define MP_INIT_CMD_RAW_ARGS(c) (c.func.raw_args = \
                                   modparrot_module_cmd_raw_args)
#  define MP_INIT_CMD_NO_ARGS(c) (c.func.no_args = modparrot_module_cmd_no_args)
#  define MP_INIT_CMD_ITERATE(c) (c.func.take1 = modparrot_module_cmd_iterate)
#  define MP_INIT_CMD_ITERATE2(c) (c.func.take2 = modparrot_module_cmd_iterate2)
#  define MP_INIT_CMD_FLAG(c) (c.func.flag = modparrot_module_cmd_flag)
#else /* (AP_HAVE_DESIGNATED_INITIALIZER) || defined(DOXYGEN) */
#  define MP_INIT_CMD_TAKE1(c) (c.func = modparrot_module_cmd_take1)
#  define MP_INIT_CMD_TAKE2(c) (c.func = modparrot_module_cmd_take2)
#  define MP_INIT_CMD_TAKE12(c) (c.func = modparrot_module_cmd_take2)
#  define MP_INIT_CMD_TAKE3(c) (c.func = modparrot_module_cmd_take3)
#  define MP_INIT_CMD_TAKE23(c) (c.func = modparrot_module_cmd_take3)
#  define MP_INIT_CMD_TAKE123(c) (c.func = modparrot_module_cmd_take3)
#  define MP_INIT_CMD_RAW_ARGS(c) (c.func = modparrot_module_cmd_raw_args)
#  define MP_INIT_CMD_NO_ARGS(c) (c.func = modparrot_module_cmd_no_args)
#  define MP_INIT_CMD_ITERATE(c) (c.func = modparrot_module_cmd_iterate)
#  define MP_INIT_CMD_ITERATE2(c) (c.func = modparrot_module_cmd_iterate2)
#  define MP_INIT_CMD_FLAG(c) (c.func = modparrot_module_cmd_flag)
#endif /* (AP_HAVE_DESIGNATED_INITIALIZER) || defined(DOXYGEN) */

/* hook types */
enum modparrot_hooks {
    /* server scope */
    MP_HOOK_OPEN_LOGS,
    MP_HOOK_POST_CONFIG,
    MP_HOOK_CHILD_INIT,
    MP_HOOK_PRE_CONNECTION,
    MP_HOOK_PROCESS_CONNECTION,
    MP_HOOK_POST_READ_REQUEST,
    MP_HOOK_MAP_TO_STORAGE,
    MP_HOOK_TRANS,

    /* directory scope */
    MP_HOOK_INPUT_FILTER,
    MP_HOOK_HEADER_PARSER,
    MP_HOOK_ACCESS,
    MP_HOOK_AUTHEN,
    MP_HOOK_AUTHZ,
    MP_HOOK_RESPONSE,
    MP_HOOK_OUTPUT_FILTER,
    MP_HOOK_TYPE,
    MP_HOOK_FIXUP,
    MP_HOOK_LOG,

    /* mark the end of the individual hooks */
    MP_HOOK_LAST,

    /* shortcut for all hooks */
    MP_HOOK_ALL
};

struct modparrot_module_info
{
    const char *ctx_pool_name; /* default context pool name for this module */
    apr_array_header_t *ctx_pool; /* cached pointer to default context pool */
    Parrot_PMC server_create_sub;
    Parrot_PMC server_merge_sub;
    Parrot_PMC dir_create_sub;
    Parrot_PMC dir_merge_sub;
    char *namespace; /* can be a real namespace or the name of an HLL */
    short hooks[MP_HOOK_LAST]; /* index is from modparrot_hooks enum */
};
typedef struct modparrot_module_info modparrot_module_info;

/* container for HLL server and directory configs */
struct modparrot_module_config
{
    char *name;
    modparrot_module_info *minfo;
    const char *ctx_pool_name; /* context pool name for this config */
    apr_array_header_t *ctx_pool; /* cached pointer to the context pool */
    Parrot_PMC cfg;
};
typedef struct modparrot_module_config modparrot_module_config;

struct modparrot_srv_config
{
    apr_pool_t *pool;
    apr_array_header_t *ctx_pool;
    int start_interp;
    int minspare_interp;
    int maxspare_interp;
    int max_interp;
    char *init_path;
    int trace_flags;
    int enable_option_flags;
    int disable_option_flags;
    int option_flags;
    char *include_path;
    char *dynext_path;
    char *lib_path;
    char *so_path;
    apr_array_header_t *preload;
};
typedef struct modparrot_srv_config modparrot_srv_config;

/* no directory config right now
 * struct modparrot_dir_config
 * {
 * };
 * typedef struct modparrot_dir_config modparrot_dir_config;
 */

struct modparrot_module_cmd_data
{
    module *modp;
    Parrot_PMC func;     /* parrot callback sub */
    Parrot_PMC cmd_data; /* directive-specific cmd_data */
};
typedef struct modparrot_module_cmd_data modparrot_module_cmd_data;

void modparrot_recalc_options(modparrot_srv_config *);

void *create_modparrot_srv_config(apr_pool_t *, server_rec *);
void *create_modparrot_dir_config(apr_pool_t *, char *path);
void *merge_modparrot_dir_config(apr_pool_t *, void *, void *);
void *merge_modparrot_srv_config(apr_pool_t *, void *, void *);

/* config directives */
const char *modparrot_cmd_init(cmd_parms *, void *, const char *);
const char *modparrot_cmd_trace(cmd_parms *, void *, const char *);
const char *modparrot_cmd_debug(cmd_parms *, void *, const char *);
const char *modparrot_cmd_language(cmd_parms *, void *, const char *);
const char *modparrot_cmd_load(cmd_parms *, void *, const char *);
const char *modparrot_cmd_load_immediate(cmd_parms *, void *, const char *, const char *);
const char *modparrot_cmd_include_path(cmd_parms *, void *, const char *);
const char *modparrot_cmd_lib_path(cmd_parms *, void *, const char *);
const char *modparrot_cmd_dynext_path(cmd_parms *, void *, const char *);
const char *modparrot_cmd_add_type(cmd_parms *, void *, const char *, const char *);
const char *modparrot_cmd_add_handler(cmd_parms *, void *, const char *, const char *);
const char *modparrot_cmd_options(cmd_parms *, void *, const char *);

/* handlers for HLL apache modules */
int modparrot_meta_open_logs_handler(apr_pool_t *, apr_pool_t *, apr_pool_t *,
    server_rec *);
int modparrot_meta_post_config_handler(apr_pool_t *, apr_pool_t *,
    apr_pool_t *, server_rec *);
void modparrot_meta_child_init_handler(apr_pool_t *, server_rec *s);
int modparrot_meta_pre_connection_handler(conn_rec *, void *);
int modparrot_meta_process_connection_handler(conn_rec *);
int modparrot_meta_map_to_storage_handler(request_rec *);
int modparrot_meta_trans_handler(request_rec *);
int modparrot_meta_post_read_request_handler(request_rec *);
int modparrot_meta_header_parser_handler(request_rec *);
int modparrot_meta_access_handler(request_rec *);
int modparrot_meta_authen_handler(request_rec *);
int modparrot_meta_authz_handler(request_rec *);
int modparrot_meta_response_handler(request_rec *);
int modparrot_meta_type_handler(request_rec *);
int modparrot_meta_fixup_handler(request_rec *);
int modparrot_meta_log_handler(request_rec *);

#endif /* _MODPARROT_CONFIG_H */
