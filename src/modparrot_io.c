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

#include "parrot/parrot.h"
#include "parrot/embed.h"
#include "parrot/extend.h"

#include "mod_parrot.h"
#include "modparrot_config.h"
#include "modparrot_log.h"

/* stolen and adapted from mod_perl2's modperl_request_read */
apr_size_t modparrot_request_read(request_rec *r, char *buffer, apr_size_t len)
{
    apr_size_t total = 0;
    apr_size_t wanted = len;
    int seen_eos = 0;
    char *tmp = buffer;
    apr_bucket_brigade *bb;

    if (len <= 0) {
        return 0;
    }

    bb = apr_brigade_create(r->pool, r->connection->bucket_alloc);
    if (bb == NULL) {
        r->connection->keepalive = AP_CONN_CLOSE;
        MPLOG_ERROR(r->server, "modparrot_request_read: "
                               "failed to create bucket brigade");
        return 0 ;
    }

    do {
        apr_size_t read;
        apr_status_t rc;

        rc = ap_get_brigade(r->input_filters, bb, AP_MODE_READBYTES,
                            APR_BLOCK_READ, len);
        if (rc != APR_SUCCESS) {
            r->connection->keepalive = AP_CONN_CLOSE;
            apr_brigade_destroy(bb);
            MPLOG_ERROR(r->server, "modparrot_request_read: "
                                   "failed to get bucket brigade");
        }

        if (APR_BRIGADE_EMPTY(bb)) {
            apr_brigade_destroy(bb);
            MPLOG_ERROR(r->server, "modparrot_request_read: "
                       "Aborting read from client. "
                       "One of the input filters is broken. "
                       "It returned an empty bucket brigade for "
                       "the APR_BLOCK_READ mode request");
        }

        if (APR_BUCKET_IS_EOS(APR_BRIGADE_LAST(bb))) {
            seen_eos = 1;
        }

        read = len;
        rc = apr_brigade_flatten(bb, tmp, &read);
        if (rc != APR_SUCCESS) {
            apr_brigade_destroy(bb);
            MPLOG_ERROR(r->server, "modparrot_request_read: "
                                   "apr_brigade_flatten failed");
        }

        total += read;
        tmp   += read;
        len   -= read;

        apr_brigade_cleanup(bb);

    } while (len > 0 && !seen_eos);

    apr_brigade_destroy(bb);

    return total;
}
