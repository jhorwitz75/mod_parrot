# $Id: RequestRec.pir 585 2009-01-06 22:43:59Z jhorwitz $

# Copyright (c) 2004, 2005, 2008 Jeff Horwitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 NAME

Apache/RequestRec.pir

=head1 SYNOPSIS

 .local pmc r

 r = new [ 'ModParrot'; 'Apache'; 'RequestRec' ]

 r.'content_type'("text/html")
 r.'puts'("Hello world")

=head1 DESCRIPTION

This code implements the ModParrot;Apache;RequestRec class, an encapsulation of
Apache's request_rec structure.  It is modeled after mod_perl's
Apache::RequestRec class, but is in no way tied to mod_perl.
 
=head2 Methods

=over 4

=cut

.namespace [ 'ModParrot'; 'Apache'; 'RequestRec' ]

.sub _initialize :load
    .local pmc rr_class
    .local pmc func
    .local pmc lib

    load_bytecode "ModParrot/Apache/ServerRec.pbc"
    load_bytecode "ModParrot/APR/Pool.pbc"

    null $S0
    loadlib lib, $S0

    newclass rr_class, [ 'ModParrot'; 'Apache'; 'RequestRec' ]
    addattribute rr_class, 'r'
    addattribute rr_class, 'pmc_notes'

    dlfunc func, lib, "ap_rputs", "itp"
    set_root_global [ 'Apache'; 'NCI' ], "ap_rputs", func

    dlfunc func, lib, "ap_rputc", "iip"
    set_root_global [ 'Apache'; 'NCI' ], "ap_rputc", func

    dlfunc func, lib, "ap_is_initial_req", "ip"
    set_root_global [ 'Apache'; 'NCI' ], "ap_is_initial_req", func

    dlfunc func, lib, "ap_auth_type", "tp"
    set_root_global [ 'Apache'; 'NCI' ], "ap_auth_type", func

    dlfunc func, lib, "ap_auth_name", "tp"
    set_root_global [ 'Apache'; 'NCI' ], "ap_auth_name", func

    dlfunc func, lib, "ap_note_basic_auth_failure", "vp"
    set_root_global [ 'Apache'; 'NCI' ], "ap_note_basic_auth_failure", func

    dlfunc func, lib, "ap_custom_response", "vpit"
    set_root_global [ 'Apache'; 'NCI' ], "ap_custom_response", func
.end

.sub init :vtable :method
    .local pmc request_rec
    .local pmc r
    .local pmc pmc_notes

    request_rec = get_root_global [ 'ModParrot'; 'NCI' ], 'request_rec'
    r = request_rec( )
    setattribute self, 'r', r

    pmc_notes = new 'Hash'
    setattribute self, 'pmc_notes', pmc_notes
.end

#.sub init_pmc :vtable :method
#    .param pmc r
#
#    setattribute self, 'r', r
#.end

.include 'build/src/pir/request_rec.pir'

=item C<puts(STRING str)>

=over 4

Outputs a string into the HTTP content.  No return value.

=back

=cut

.sub puts :method
    .param string data
    .local pmc r
    .local pmc ap_rputs

    getattribute r, self, 'r'
    ap_rputs = get_root_global [ 'Apache'; 'NCI' ], 'ap_rputs'
    ap_rputs( data, r )
.end

=item C<putc(INT int)>

=over 4

Outputs an int into the HTTP content.  No return value.

=back

=cut

.sub putc :method
    .param int data
    .local pmc r
    .local pmc ap_rputc

    getattribute r, self, 'r'
    ap_rputc = get_root_global [ 'Apache'; 'NCI' ], 'ap_rputc'
    ap_rputc( data, r )
.end

=item C<INT read(PMC buf, INT len)>

=over 4

Reads len bytes of data from the HTTP stream into a PMC.  Returns the number
of bytes read.

=back

=cut

.sub read :method
    .param pmc buf
    .param int len
    .local pmc r
    .local pmc request_read
    .local int bytes

    getattribute r, self, 'r'
    request_read = get_root_global [ 'ModParrot'; 'NCI' ], 'request_read'
    bytes = request_read( buf, len, r )
    .return(bytes)
.end

=item C<INT write(pmc, size)>

=over 4

Writes data from a PMC of size C<size> into the HTTP content.  Returns the
number of bytes written.

THIS METHOD IS EXPERIMENTAL!

=back

=cut

.sub write :method
    .param pmc data
    .param int size
    .local pmc r
    .local pmc ap_rwrite
    .local int bytes

    getattribute r, self, 'r'
    ap_rwrite = get_root_global [ 'ModParrot'; 'NCI' ], 'rwrite'
    bytes = ap_rwrite( data, size, r )

    .return(bytes)
.end

=item C<STRING filename([STRING filename])>

=over 4

Get or set the local filename corresponding to the request's URI.

=back

=cut

.sub filename :method
    .param string f :optional
    .param int update_r :opt_flag
    .local pmc r
    .local pmc request_rec_filename
    .local string filename

    getattribute r, self, 'r'
    request_rec_filename = get_root_global [ 'ModParrot'; 'NCI' ], 'request_rec_filename'
    if update_r == 1 goto CALL_NCI
    f = ""

CALL_NCI:
    filename = request_rec_filename( r, f, update_r )

    .return(filename)
.end

=item C<log_rerror(STRING file, INT line, INT level, STRING msg)>

=over 4

Send a log to Apache's error log.  C<file> and C<line> are the file and line
number where the logging event occured, and should be set by the targeting
language.  C<level> is one of the Apache log levels, which can be found in
ModParrot;Apache;Constants (with the C<APLOG_> prefix).  C<data> is the actual
log message to be written into the error log.

=back

=cut

.sub log_rerror :method
    .param string file
    .param int line
    .param int level
    .param string msg 
    .local pmc r
    .local pmc ap_log_rerror

    getattribute r, self, 'r'
    ap_log_rerror = get_root_global [ 'ModParrot'; 'NCI' ], 'ap_log_rerror'
    ap_log_rerror( file, line, level, 0, r, msg )
.end

=item C<ARRAY get_basic_auth_pw()>

=over 4

Returns the authentication status and password from the current request in an
array PMC.  Also populates the C<user> field of Apache's C<request_rec>
structure, which can be requested with the C<user> method.

=back

=cut

.sub get_basic_auth_pw :method
    .local pmc r
    .local pmc request_rec_get_basic_auth_pw
    .local string pw
    .local int status
    .local pmc results

    getattribute r, self, 'r'
    request_rec_get_basic_auth_pw = get_root_global [ 'ModParrot'; 'NCI' ], 'request_rec_get_basic_auth_pw'

    results = new 'Array'
    results = 2
    status = request_rec_get_basic_auth_pw( r, results )

    .return(results)
.end

=item C<INT is_initial_req()>

=over 4

Returns 1 if the request is not a subrequest or internal redirect, and 0
otherwise.

=back

=cut

.sub is_initial_req :method
    .local pmc r
    .local pmc ap_is_initial_req

    getattribute r, self, 'r'

    ap_is_initial_req = get_root_global [ 'Apache'; 'NCI' ], 'ap_is_initial_req'
    $I0 = ap_is_initial_req( r )

    .return($I0)
.end

=item C<STRING auth_name()>

=over 4

Returns the authentication name for the request (C<AuthName> Apache directive).

=back

=cut

.sub auth_name :method
    .local pmc r
    .local pmc ap_auth_name

    getattribute r, self, 'r'

    ap_auth_name = get_root_global [ 'Apache'; 'NCI' ], 'ap_auth_name'
    $S0 = ap_auth_name( r )

    .return($S0)
.end

=item C<note_basic_auth_failure()>

=over 4

Sets headers to request authentication from the client.  This method only works
for basic authentication.
 
=back

=cut

.sub note_basic_auth_failure :method
    .local pmc r
    .local pmc ap_note_basic_auth_failure

    getattribute r, self, 'r'

    ap_note_basic_auth_failure = get_root_global [ 'Apache'; 'NCI' ], 'ap_note_basic_auth_failure'
    ap_note_basic_auth_failure( r )
.end

=item C<STRING auth_type()>

=over 4

Returns the authentication type for the request (C<AuthType> Apache directive).

=back

=cut

.sub auth_type :method
    .local pmc r
    .local pmc ap_auth_type

    getattribute r, self, 'r'

    ap_auth_type = get_root_global [ 'Apache'; 'NCI' ], 'ap_auth_type'
    $S0 = ap_auth_type( r )

    .return($S0)
.end

=item C<PMC notes()>

=over 4

Returns the request's notes table as an ModParrot;APR;Table object.

=back

=cut

.sub notes :method
    .local pmc r
    .local pmc notes
    .local pmc t
    .local pmc request_rec_notes
 
    getattribute r, self, 'r'

    request_rec_notes = get_root_global [ 'ModParrot'; 'NCI' ], 'request_rec_notes'
    notes = request_rec_notes( r )

    $P0 = get_class [ 'ModParrot'; 'APR'; 'Table' ]
    $P1 = new 'Hash'
    $P1['apr_table'] = notes
    t = new $P0, $P1

    .return(t)
.end

=item C<PMC main()>

=over 4

Returns the the main request at the top of the chain.

=back

=cut

.sub main :method
    .local pmc r
    .local pmc main_r
    .local pmc request_rec_main

    getattribute r, self, 'r'

    request_rec_main = get_root_global [ 'ModParrot'; 'NCI' ], 'request_rec_main'
    main_r = request_rec_main( r )

    .return(main_r)
.end

=item C<PMC next()>

=over 4

Returns the the redirected request if this is an external redirect.

=back

=cut

.sub next :method
    .local pmc r
    .local pmc next_r
    .local pmc request_rec_next

    getattribute r, self, 'r'

    request_rec_next = get_root_global [ 'ModParrot'; 'NCI' ], 'request_rec_next'
    next_r = request_rec_next( r )

    .return(next_r)
.end

=item C<PMC prev()>

=over 4

Returns the the previous request if this is an internal redirect.

=back

=cut

.sub prev :method
    .local pmc r
    .local pmc prev_r
    .local pmc request_rec_prev

    getattribute r, self, 'r'

    request_rec_prev = get_root_global [ 'ModParrot'; 'NCI' ], 'request_rec_prev'
    $P0 = get_class [ 'ModParrot'; 'Apache'; 'RequestRec' ]
    $P1 = request_rec_prev( r )
    $P2 = new 'Hash'
    $P2['r'] = $P1
    prev_r = new $P0, $P2

    .return(prev_r)
.end

=item C<custom_response(INT status, STRING response)>

=over 4

Set a custom response for a particular status.  The response can be either a
string to send back to the client or a URI.

=back

=cut

.sub custom_response :method
    .param int status
    .param string response
    .local pmc r
    .local pmc ap_custom_response

    getattribute r, self, 'r'

    ap_custom_response = get_root_global [ 'Apache'; 'NCI' ], 'ap_custom_response'
    ap_custom_response(r, status, response)
.end

=back

=item C<PMC pmc_notes()>

=over 4

Get or set a PMC note.  Use this for storing notes more complex than a string.
Only mod_parrot languages have access to PMC notes.

=back

=cut

.sub pmc_notes :method
    .param string key
    .param pmc val :optional
    .param int update_val :opt_flag
    .local pmc pmc_notes

    getattribute pmc_notes, self, 'pmc_notes'

    if update_val == 0 goto FETCH_VAL
    pmc_notes[key] = val

FETCH_VAL:
    val = pmc_notes[key]

    .return(val)
.end

=back

=item C<PMC per_dir_config()>

=over 4

Retrieve the per-directory configuration vector for this request.  This PMC
is opaque and should only be passed to other methods.

=back

=cut

.sub per_dir_config :method
    .local pmc dircfg
    .local pmc get_config
    .local pmc r

    get_config = get_root_global ['ModParrot'; 'NCI'], 'request_rec_per_dir_config'
    getattribute r, self, 'r'
    dircfg = get_config(r)

    .return(dircfg)
.end

=back

=item C<PMC headers_in()>

=over 4

Return the request headers as an APR;Table object.

=back

=cut

.sub headers_in :method
    .local pmc headers, table, func, r

    func = get_root_global ['ModParrot'; 'NCI'], 'request_rec_headers_in'
    getattribute r, self, 'r'
    headers = func(r)

    $P0 = get_class [ 'ModParrot'; 'APR'; 'Table' ]
    $P1 = new 'Hash'
    $P1['apr_table'] = headers
    table = new $P0, $P1

    .return(table)
.end

=item C<PMC headers_out()>

=over 4

Return the response headers as an APR;Table object.

=back

=cut

.sub headers_out :method
    .local pmc headers, table, func, r

    func = get_root_global ['ModParrot'; 'NCI'], 'request_rec_headers_out'
    getattribute r, self, 'r'
    headers = func(r)

    $P0 = get_class [ 'ModParrot'; 'APR'; 'Table' ]
    $P1 = new 'Hash'
    $P1['apr_table'] = headers
    table = new $P0, $P1

    .return(table)
.end

=item C<PMC err_headers_out()>

=over 4

Return the non-200 response headers as an APR;Table object.  Persists across
internal redirects.

=back

=cut

.sub err_headers_out :method
    .local pmc headers, table, func, r

    func = get_root_global ['ModParrot'; 'NCI'], 'request_rec_err_headers_out'
    getattribute r, self, 'r'
    headers = func(r)

    $P0 = get_class [ 'ModParrot'; 'APR'; 'Table' ]
    $P1 = new 'Hash'
    $P1['apr_table'] = headers
    table = new $P0, $P1

    .return(table)
.end

=item C<ModParrot;APR;Pool pool()>

=over 4

Returns the request pool as a ModParrot;APR;Pool object.

=back

=cut

.sub pool :method
    .local pmc p, pool, func, r

    func = get_root_global ['ModParrot'; 'NCI'], 'request_rec_pool'
    getattribute r, self, 'r'
    p = func(r)

    $P0 = get_class [ 'ModParrot'; 'APR'; 'Pool' ]
    $P1 = new 'Hash'
    $P1['apr_pool'] = p
    pool = new $P0, $P1

    .return(pool)
.end

=item C<ModParrot;Apache;ServerRec server()>

=over 4

Returns the request's server object.

=back

=cut

.sub server :method
    .local pmc r, s, func

    func = get_root_global [ 'ModParrot'; 'NCI' ], 'request_rec_server'
    getattribute r, self, 'r'
    s = func(r)
    $P0 = get_class [ 'ModParrot'; 'Apache'; 'ServerRec' ]
    $P1 = new 'Hash'
    $P1['server_rec'] = s
    $P2 = new $P0, $P1

    .return($P2)
.end

=back

=head1 AUTHOR

Jeff Horwitz

=cut
