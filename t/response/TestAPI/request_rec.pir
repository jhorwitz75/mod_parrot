# $Id$

.namespace [ 'TestAPI::request_rec' ]

.sub handler
    .param pmc r
    .local pmc ap_const
    .local string results

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    r.'puts'("1..39\n")

  # XXX this should be fatal on failure
  START_1:
    $S0 = typeof r
    if $S0 == "ModParrot;Apache;RequestRec" goto OK_1
  NOT_OK_1:
    r.'puts'("not ")
  OK_1:
    r.'puts'("ok 1 - object\n")

  # XXX this should be fatal on failure
  START_2:
  OK_2:
    r.'puts'("ok 2 - puts()\n")

  # XXX failure here may cause all subsequent tests to fail
  START_3:
    push_eh NOT_OK_3
    $I0 = r.'write'("# testing 123\n", 14)
    pop_eh
    if $I0 == 14 goto OK_3
  NOT_OK_3:
    r.'puts'("not ")
  OK_3:
    r.'puts'("ok 3 - write()\n")

  START_4:
    push_eh NOT_OK_4
    $S0 = r.'content_type'()
    pop_eh
    # text/html is mod_parrot's default content type
    if $S0 == "text/html" goto OK_4
  NOT_OK_4:
    r.'puts'("not ")
  OK_4:
    r.'puts'("ok 4 - content_type get\n")

  START_5:
    push_eh NOT_OK_5
    r.'content_type'("text/html")
    pop_eh
    goto OK_5
  NOT_OK_5:
    r.'puts'("not ")
  OK_5:
    r.'puts'("ok 5 - content_type set\n")

  START_6:
    push_eh NOT_OK_6
    r.'args'("testing")
    $S0 = r.'args'()
    pop_eh
    if $S0 == "testing" goto OK_6
  NOT_OK_6:
    r.'puts'("not ")
  OK_6:
    r.'puts'("ok 6 - args()\n")
    
  START_7:
    push_eh NOT_OK_7
    r.'path_info'("/my/test/path")
    $S0 = r.'path_info'()
    pop_eh
    if $S0 == "/my/test/path" goto OK_7
  NOT_OK_7:
    r.'puts'("not ")
  OK_7:
    r.'puts'("ok 7 - pathinfo()\n")
    
  START_8:
    push_eh NOT_OK_8
    r.'hostname'("modparrot.example.com")
    $S0 = r.'hostname'()
    pop_eh
    if $S0 == "modparrot.example.com" goto OK_8
  NOT_OK_8:
    r.'puts'("not ")
  OK_8:
    r.'puts'("ok 8 - hostname()\n")
    
  START_9:
    $I0 = ap_const['APLOG_EMERG']
    push_eh NOT_OK_9
    r.'log_rerror'("test", 0, $I0, "mod_parrot test log")
    pop_eh
    goto OK_9
  NOT_OK_9:
    r.'puts'("not ")
  OK_9:
    r.'puts'("ok 9 - log_rerror()\n")

  START_10:
    push_eh NOT_OK_10
    # save original status -- we need it for the test client!
    $I0 = r.'status'()
    r.'status'(123)
    $I1 = r.'status'()
    pop_eh
    if $I1 == 123 goto OK_10
    pop_eh
  NOT_OK_10:
    r.'puts'("not ")
  OK_10:
    r.'puts'("ok 10 - status()\n")
    r.'status'($I0)

  START_11:
    push_eh NOT_OK_11
    $P0 = r.'notes'()
    $P0.'set'("modparrot_test", "test note")
    $P0 = r.'notes'()
    $S0 = $P0.'get'("modparrot_test")
    pop_eh
    if $S0 == "test note" goto OK_11
  NOT_OK_11:
    r.'puts'("not ")
  OK_11:
    r.'puts'("ok 11 - notes()\n")

  START_12:
    push_eh NOT_OK_12
    r.'uri'("/my/test/uri")
    $S0 = r.'uri'()
    pop_eh
    if $S0 == "/my/test/uri" goto OK_12
  NOT_OK_12:
    r.'puts'("not ")
  OK_12:
    r.'puts'("ok 12 - uri()\n")

  START_13:
    push_eh NOT_OK_13
    # save original handler
    $S0 = r.'handler'()
    r.'handler'("test-handler")
    $S1 = r.'handler'()
    pop_eh
    if $S1 == "test-handler" goto OK_13
  NOT_OK_13:
    r.'puts'("not ")
  OK_13:
    r.'puts'("ok 13 - handler()\n")
    r.'handler'($S0)

  START_14:
    push_eh NOT_OK_14
    r.'user'("testuser")
    $S0 = r.'user'()
    pop_eh
    if $S0 == "testuser" goto OK_14
  NOT_OK_14:
    r.'puts'("not ")
  OK_14:
    r.'puts'("ok 14 - user()\n")

  START_15:
    $P0 = new 'String'
    $P0 = "test PMC note"
    push_eh NOT_OK_15
    r.'pmc_notes'('modparrot_test_pmcnote_string', 'test PMC note')
    $P1 = r.'pmc_notes'('modparrot_test_pmcnote_string')
    pop_eh
    if $P1 == 'test PMC note' goto OK_15
  NOT_OK_15:
    r.'puts'("not ")
  OK_15:
    r.'puts'("ok 15 - pmc_notes() string value\n")

  START_16:
    $P0 = new 'Hash'
    $P1 = new 'String'
    $P1 = "test PMC note in a hash"
    $P0['test'] = $P1
    push_eh NOT_OK_16
    r.'pmc_notes'('modparrot_test_pmcnote_hash', $P0)
    $P1 = r.'pmc_notes'('modparrot_test_pmcnote_hash')
    pop_eh
    $P2 = $P1['test']
    if $P2 == 'test PMC note in a hash' goto OK_16
  NOT_OK_16:
    r.'puts'("not ")
  OK_16:
    r.'puts'("ok 16 - pmc_notes() hash value\n")

  START_17:
    push_eh NOT_OK_17
    r.'filename'("/my/test/file")
    $S0 = r.'filename'()
    pop_eh
    if $S0 == "/my/test/file" goto OK_17
  NOT_OK_17:
    r.'puts'("not ")
  OK_17:
    r.'puts'("ok 17 - filename()\n")

  START_18:
    push_eh NOT_OK_18
    r.'canonical_filename'("/my/test/file")
    $S0 = r.'canonical_filename'()
    pop_eh
    if $S0 == "/my/test/file" goto OK_18
  NOT_OK_18:
    r.'puts'("not ")
  OK_18:
    r.'puts'("ok 18 - canonical_filename()\n")

  START_19:
    push_eh NOT_OK_19
    $S0 = r.'auth_type'()
    pop_eh
    if $S0 == "" goto OK_19
  NOT_OK_19:
    r.'puts'("not ")
  OK_19:
    r.'puts'("ok 19 - auth_type()\n")

  START_20:
    push_eh NOT_OK_20
    $S0 = r.'auth_name'()
    pop_eh
    if $S0 == "" goto OK_20
  NOT_OK_20:
    r.'puts'("not ")
  OK_20:
    r.'puts'("ok 20 - auth_name()\n")

  START_21:
    push_eh NOT_OK_21
    $S0 = r.'the_request'()
    pop_eh
    goto OK_21
  NOT_OK_21:
    r.'puts'("not ")
  OK_21:
    r.'puts'("ok 21 - the_request()\n")

  START_22:
    push_eh NOT_OK_22
    $S0 = r.'protocol'()
    pop_eh
    goto OK_22
  NOT_OK_22:
    r.'puts'("not ")
  OK_22:
    r.'puts'("ok 22 - protocol()\n")

  START_23:
    push_eh NOT_OK_23
    r.'status_line'("200 mod_parrot test")
    $S0 = r.'status_line'()
    pop_eh
    if $S0 == "200 mod_parrot test" goto OK_23
  NOT_OK_23:
    r.'puts'("not ")
  OK_23:
    r.'puts'("ok 23 - status_line()\n")

  START_24:
    push_eh NOT_OK_24
    r.'content_encoding'("application/x-httpd-test")
    $S0 = r.'content_encoding'()
    pop_eh
    if $S0 == "application/x-httpd-test" goto OK_24
  NOT_OK_24:
    r.'puts'("not ")
  OK_24:
    r.'puts'("ok 24 - status_line()\n")

  START_25:
    push_eh NOT_OK_25
    r.'range'("bytes 123-455/456")
    $S0 = r.'range'()
    pop_eh
    if $S0 == "bytes 123-455/456" goto OK_25
  NOT_OK_25:
    r.'puts'("not ")
  OK_25:
    r.'puts'("ok 25 - range()\n")

  START_26:
    push_eh NOT_OK_26
    r.'vlist_validator'("foo")
    $S0 = r.'vlist_validator'()
    pop_eh
    if $S0 == "foo" goto OK_26
  NOT_OK_26:
    r.'puts'("not ")
  OK_26:
    r.'puts'("ok 26 - vlist_validator()\n")

  START_27:
    push_eh NOT_OK_27
    r.'unparsed_uri'("/my/unparsed/test/uri")
    $S0 = r.'unparsed_uri'()
    pop_eh
    if $S0 == "/my/unparsed/test/uri" goto OK_27
  NOT_OK_27:
    r.'puts'("not ")
  OK_27:
    r.'puts'("ok 27 - unparsed_uri()\n")

  START_28:
    push_eh NOT_OK_28
    $S0 = r.'custom_response'(403, 'The squirrels are tired')
    pop_eh
    goto OK_28
  NOT_OK_28:
    r.'puts'("not ")
  OK_28:
    r.'puts'("ok 28 - custom_response()\n")

  START_29:
    push_eh NOT_OK_29
    $I0 = r.'is_initial_req'()
    pop_eh
    goto OK_29
  NOT_OK_29:
    r.'puts'("not ")
  OK_29:
    r.'puts'("ok 29 - is_initial_req()\n")

  # this happens to set up auth environment for note_basic_auth_failure()
  START_30:
    push_eh NOT_OK_30
    $P0 = r.'get_basic_auth_pw'()
    pop_eh
    goto OK_30
  NOT_OK_30:
    r.'puts'("not ")
  OK_30:
    r.'puts'("ok 30 - get_basic_auth_pw()\n")

  # NOTE: this test will emit authentication headers, but we don't return
  # a 401 unauthorized status, so it shouldn't cause a problem
  START_31:
    push_eh NOT_OK_31
    r.'note_basic_auth_failure'()
    pop_eh
    goto OK_31
  NOT_OK_31:
    r.'puts'("not ")
  OK_31:
    r.'puts'("ok 31 - note_basic_auth_failure()\n")

  # XXX putc() "succeeds" but doesn't output the proper character
  START_32:
  #  push_eh NOT_OK_32
  #  r.'putc'('#')
  #  pop_eh
  #  r.'puts'("\n")
  #  goto OK_32
  #NOT_OK_32:
  #  r.'puts'("not ")
  #OK_32:
  #  r.'puts'("ok 32 - putc()\n")
  r.'puts'("not ok 32 - putc() # TODO succeeds with incorrect output\n")

  START_33:
    push_eh NOT_OK_33
    $S0 = r.'method'()
    pop_eh
    if $S0 == 'GET' goto OK_33
  NOT_OK_33:
    r.'puts'("not ")
  OK_33:
    r.'puts'("ok 33 - method()\n")

  START_34:
    push_eh NOT_OK_34
    $P0 = new 'String'
    $I0 = r.'read'($P0, 1024)
    pop_eh
    if $I0 == 0 goto OK_34
  NOT_OK_34:
    r.'puts'("not ")
  OK_34:
    r.'puts'("ok 34 - null read()\n")

  START_35:
    push_eh NOT_OK_35
    $P0 = r.'headers_in'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == 'ModParrot;APR;Table' goto OK_35
  NOT_OK_35:
    r.'puts'("not ")
  OK_35:
    r.'puts'("ok 35 - headers_in()\n")

  START_36:
    push_eh NOT_OK_36
    $P0 = r.'headers_out'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == 'ModParrot;APR;Table' goto OK_36
  NOT_OK_36:
    r.'puts'("not ")
  OK_36:
    r.'puts'("ok 36 - headers_in()\n")

  START_37:
    push_eh NOT_OK_37
    $P0 = r.'err_headers_out'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == 'ModParrot;APR;Table' goto OK_37
  NOT_OK_37:
    r.'puts'("not ")
  OK_37:
    r.'puts'("ok 37 - headers_in()\n")

  START_38:
    push_eh NOT_OK_38
    $P0 = r.'pool'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == 'ModParrot;APR;Pool' goto OK_38
  NOT_OK_38:
    r.'puts'("not ")
  OK_38:
    r.'puts'("ok 38 - pool()\n")

  START_39:
    push_eh NOT_OK_39
    $P0 = r.'server'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == 'ModParrot;Apache;ServerRec' goto OK_39
  NOT_OK_39:
    r.'puts'("not ")
  OK_39:
    r.'puts'("ok 39 - server()\n")

    # STILL TODO (not tested in original client-side tests)
    # assbackwards
    # proxyreq
    # header_only
    # proto_num
    # method_number
    # chunked
    # read_body
    # read_chunked
    # no_cache
    # no_local_copy
    # used_path_info
    # eos_sent
    # others, i'm sure

    $I0 = ap_const['OK']
    .return($I0)

.end
