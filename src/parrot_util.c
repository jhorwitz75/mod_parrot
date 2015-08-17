/* $Id: parrot_util.c 644 2009-06-16 00:02:37Z jhorwitz $ */

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

#include <stdlib.h>
#include <apr_file_io.h>
#include "parrot/parrot.h"
#include "parrot/embed.h"
#include "parrot/extend.h"
#include "mod_parrot.h"
#include "../src/pmc/pmc_continuation.h"

static Parrot_PMC get_sub_pmc_s(Parrot_Interp interp, char *namespace, char *name)
{
    Parrot_PMC sub;

    if (namespace) {
        sub = Parrot_find_global_s(
            interp,
            MAKE_PARROT_STRING(namespace),
            MAKE_PARROT_STRING(name)
        );
    }
    else {
        Parrot_find_global_cur(
            interp,
            MAKE_PARROT_STRING(name)
        );
    }

    return(sub);
}

static Parrot_PMC get_sub_pmc_k(Parrot_Interp interp, char *hll, char *name)
{
    Parrot_PMC sub;
    Parrot_PMC namespace;
    int typenum;

    typenum = Parrot_PMC_typenum(interp, "ResizablePMCArray");
    namespace = (Parrot_PMC)Parrot_PMC_new(interp, typenum);
    Parrot_register_pmc(interp, namespace);
    Parrot_PMC_set_intval(interp, namespace, 3);
    Parrot_PMC_set_cstring_intkey(interp, namespace, 0, "ModParrot");
    Parrot_PMC_set_cstring_intkey(interp, namespace, 1, "HLL");
    Parrot_PMC_set_cstring_intkey(interp, namespace, 2, hll);

    sub = Parrot_find_global_k(interp, namespace, MAKE_PARROT_STRING(name));

    Parrot_unregister_pmc(interp, namespace);

    return(sub);
}

Parrot_PMC get_sub_pmc(Parrot_Interp interp, char *namespace, char *name)
{
    Parrot_PMC sub;

    /* check for sub in raw namespace */
    sub = get_sub_pmc_s(interp, namespace, name);
    if (!sub) {
        /* check for sub in mod_parrot HLL layer */
        sub = get_sub_pmc_k(interp, namespace, name);
    }
    return sub;
}

Parrot_Interp modparrot_init_interpreter(Parrot_Interp parent)
{
    Parrot_Interp interp;
    Parrot_PackFile pf;

    interp = Parrot_new(parent);
    pf = PackFile_new_dummy(interp, "mod_parrot_code");
    return(interp);
}

int modparrot_load_bytecode(Parrot_Interp interp, char *path)
{
    /* XXX what does this do on error? */
    Parrot_load_bytecode(interp, MAKE_PARROT_STRING(path));
    return(1);
}

/* stolen from parrot -- it's Parrot_exit() without the exit() */
/* we should be able to do this with a Parrot API call, but not yet */
static void modparrot_interp_cleanup(Parrot_Interp interp, int status)
{

    Parrot_block_GC_mark(interp);
    Parrot_block_GC_sweep(interp);

    handler_node_t *node = interp->exit_handler_list;
    while (node) {
        handler_node_t * const next = node->next;

        (node->function)(interp, status, node->arg);
        mem_sys_free(node);
        node = next;
    }
}

void modparrot_destroy_interpreter(Parrot_Interp interp)
{
    modparrot_interp_cleanup(interp, 0);
}

int modparrot_call_sub(Parrot_Interp interp, char *namespace, char *name)
{
    Parrot_PMC sub;

    sub = get_sub_pmc(interp, namespace, name);
    if (!sub) {
        return(0);
    }
    Parrot_call_sub(interp, sub, "v");
    return(1);
}

Parrot_PMC modparrot_get_meta_handler(Parrot_Interp interp, char *hll,
    char *name)
{
    Parrot_PMC sub;
    Parrot_PMC namespace;
    Parrot_PMC hllns;
    Parrot_PMC ourns;
    int typenum, hllid;

    typenum = Parrot_PMC_typenum(interp, "ResizablePMCArray");
    ourns = (Parrot_PMC)Parrot_PMC_new(interp, typenum);
    Parrot_register_pmc(interp, ourns);
    Parrot_PMC_set_intval(interp, ourns, 3);
    Parrot_PMC_set_cstring_intkey(interp, ourns, 0, "ModParrot");
    Parrot_PMC_set_cstring_intkey(interp, ourns, 1, "HLL");
    Parrot_PMC_set_cstring_intkey(interp, ourns, 2, hll);

    /* if PIR, use default namespace, else look in HLL namespace */
    if (!strcmp(hll, "PIR")) {
        namespace = ourns;
        sub = Parrot_find_global_k(interp, namespace, MAKE_PARROT_STRING(name));
    }
    else {
        /* XXX cache these during module creation */
        hllid = Parrot_get_HLL_id(interp, MAKE_PARROT_STRING(hll));
        hllns = Parrot_get_HLL_namespace(interp, hllid);
        namespace = Parrot_get_namespace_keyed(interp, hllns, ourns);
        sub = Parrot_find_global_n(interp, namespace, MAKE_PARROT_STRING(name));
    }

    Parrot_unregister_pmc(interp, namespace);

    return(sub);
}

int modparrot_call_meta_handler_sub(Parrot_Interp interp, Parrot_PMC sub,
    int *ret, Parrot_PMC ctx_pmc)
{
    *ret = Parrot_call_sub_ret_int(interp, sub, "IP", ctx_pmc);
    return(1);
}

int modparrot_call_sub_Iv(Parrot_Interp interp, char *namespace, char *name,
    int *ret)
{
    Parrot_PMC sub;

    sub = get_sub_pmc(interp, namespace, name);
    if (!sub) {
        return(0);
    }
    *ret = Parrot_call_sub_ret_int(interp, sub, "Iv");
    return(1);
}

int modparrot_call_sub_IS(Parrot_Interp interp, char *namespace, char *name,
    int *ret, char *arg)
{
    Parrot_PMC sub;

    sub = get_sub_pmc(interp, namespace, name);
    if (!sub) {
        return(0);
    }
    *ret = Parrot_call_sub_ret_int(interp, sub, "IS", MAKE_PARROT_STRING(arg));
    return(1);
}

int modparrot_call_sub_IP(Parrot_Interp interp, char *namespace, char *name,
    int *ret, Parrot_PMC pmc)
{
    Parrot_PMC sub;

    sub = get_sub_pmc(interp, namespace, name);
    if (!sub) {
        return(0);
    }
    *ret = Parrot_call_sub_ret_int(interp, sub, "IP", pmc);
    return(1);
}

int modparrot_call_sub_IPS(Parrot_Interp interp, char *namespace, char *name,
    int *ret, Parrot_PMC pmc, char *arg)
{
    Parrot_PMC sub;

    sub = get_sub_pmc(interp, namespace, name);
    if (!sub) {
        return(0);
    }
    *ret = Parrot_call_sub_ret_int(interp, sub, "IPS", pmc,
        MAKE_PARROT_STRING(arg));
    return(1);
}

/* adapted from Parrot's PDB_backtrace */
char *modparrot_backtrace(Parrot_Interp interp)
{
    STRING *str, *buf = NULL;
    PMC *sub;
    PMC *old = PMCNULL;
    int rec_level = 0;
    Parrot_Context *ctx = CONTEXT(interp);
    char *trace_string;

    /* information about the current sub */
    sub = interpinfo_p(interp, CURRENT_SUB);
    if (!PMC_IS_NULL(sub)) {
        str = Parrot_Context_infostr(interp, ctx);
        if (str)
            buf = Parrot_str_concat(interp, buf, str, 0);
    }

    /* backtrace: follow the continuation chain */
    while (1) {
        sub = ctx->current_cont;
        if (!sub)
            break;
        str = Parrot_Context_infostr(interp,
                    PMC_cont(sub)->to_ctx);
        if (!str)
            break;

        /* recursion detection */
        if (!PMC_IS_NULL(old) && PMC_cont(old) &&
            PMC_cont(old)->to_ctx->current_pc ==
            PMC_cont(sub)->to_ctx->current_pc &&
            PMC_cont(old)->to_ctx->current_sub ==
            PMC_cont(sub)->to_ctx->current_sub) {
            ++rec_level;
        } else if (rec_level != 0) {
            buf = Parrot_sprintf_c(interp, "... call repeated %d times\n",
                rec_level);
            buf = Parrot_str_concat(interp, buf, str, 0);
            rec_level = 0;
        }

        /* print the context description */
        if (rec_level == 0)
            buf = Parrot_str_concat(interp, buf, str, 0);

        /* get the next Continuation */
        ctx = PMC_cont(sub)->to_ctx;
        old = sub;
        if (!ctx)
            break;
    }
    if (rec_level != 0) {
        buf = Parrot_sprintf_c(interp,"... call repeated %d times\n",
            rec_level);
    }

    trace_string = Parrot_str_to_cstring(interp, buf);
    return(trace_string);
}

Parrot_PMC modparrot_wrap_apache_type(Parrot_Interp interp, char *classname,
    char *init_key, void *init_val)
{
    Parrot_PMC _class;
    Parrot_PMC obj;
    Parrot_PMC pointer_pmc;
    Parrot_PMC namespace;
    Parrot_PMC init;
    int typenum;

    namespace = Parrot_str_split(interp, string_from_literal(interp, ";"),
        Parrot_str_new(interp, classname, strlen(classname)));
    Parrot_register_pmc(interp, namespace);
    _class = Parrot_oo_get_class(interp, namespace);
    Parrot_unregister_pmc(interp, namespace);

    typenum = Parrot_PMC_typenum(interp, "UnManagedStruct");
    pointer_pmc = (Parrot_PMC)Parrot_PMC_new(interp, typenum);
    Parrot_PMC_set_pointer(interp, pointer_pmc, init_val);

    if (init_key && init_val) {
        typenum = Parrot_PMC_typenum(interp, "Hash");
        init = (Parrot_PMC)Parrot_PMC_new(interp, typenum);
        Parrot_register_pmc(interp, init);
        Parrot_PMC_set_pmc_keyed_str(interp, init,
            Parrot_str_new(interp, init_key, strlen(init_key)),
                pointer_pmc);
        obj = VTABLE_instantiate(interp, _class, init);
    }
    else {
        obj = VTABLE_instantiate(interp, _class, PMCNULL);
    }
    Parrot_unregister_pmc(interp, init);
    Parrot_unregister_pmc(interp, _class);

    /* NOTE: we leave it up to the caller to register the PMC */
    return(obj);
}
