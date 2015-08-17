/* $Id: modparrot_log.h 599 2009-02-01 16:42:05Z jhorwitz $ */

/* Copyright (c) 2005 Jeff Horwitz
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

#ifndef _MODPARROT_LOG_H
#define _MODPARROT_LOG_H

#define MPLOG_WARN(s, msg) \
    ap_log_error(APLOG_MARK, APLOG_WARNING, 0, s, "%s", msg)

#define MPLOG_WARNF(s, fmt, msg) \
    ap_log_error(APLOG_MARK, APLOG_WARNING, 0, s, fmt, msg)

#define MPLOG_ERROR(s, msg) \
    ap_log_error(APLOG_MARK, APLOG_ERR, 0, s, "%s", msg)

#define MPLOG_ERRORF(s, fmt, msg) \
    ap_log_error(APLOG_MARK, APLOG_ERR, 0, s, fmt, msg)

#define MPLOG_NOTICE(s, msg) \
    ap_log_error(APLOG_MARK, APLOG_NOTICE, 0, s, "%s", msg)

#define MPLOG_NOTICEF(s, fmt, msg) \
    ap_log_error(APLOG_MARK, APLOG_NOTICE, 0, s, fmt, msg)

#define MPLOG_DEBUG(s, msg) \
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, s, "%s", msg)

#define MPLOG_DEBUGF(s, fmt, msg) \
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, s, fmt, msg)

void modparrot_trace(server_rec *, const char *, ...);

#ifdef MODPARROT_DEBUG

#define MP_DEBUG_NONE 0
#define MP_DEBUG_MODULE 1
#define MP_DEBUG_CONTEXT 2
#define MP_DEBUG_HOOK 4
#define MP_DEBUG_PARROT 8
#define MP_DEBUG_HLL 16

#define MP_TRACE_h if (mp_globals.debug_level & MP_DEBUG_HOOK) modparrot_trace
#define MP_TRACE_c if (mp_globals.debug_level & MP_DEBUG_CONTEXT) modparrot_trace
#define MP_TRACE_p if (mp_globals.debug_level & MP_DEBUG_PARROT) modparrot_trace
#define MP_TRACE_m if (mp_globals.debug_level & MP_DEBUG_MODULE) modparrot_trace

#else /* MODPARROT_DEBUG */

#define MP_TRACE_h if (0) modparrot_trace
#define MP_TRACE_c if (0) modparrot_trace
#define MP_TRACE_p if (0) modparrot_trace
#define MP_TRACE_m if (0) modparrot_trace

#endif /* MODPARROT_DEBUG */

#endif /* _MODPARROT_LOG_H */
