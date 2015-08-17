.namespace [ 'TestAPI::apr_pool' ]

.sub test_cleanup_handler
    .param pmc data
    .local pmc ap_const

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'
    printerr "in test cleanup handler "
    printerr "data="
    printerr data
    printerr "\n"
    $I0 = ap_const['OK']
    .return($I0)
.end

.sub test_cleanup_handler_no_data
    .local pmc ap_const

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'
    printerr "in test cleanup handler\n"
    $I0 = ap_const['OK']
    .return($I0)
.end

.sub handler
    .param pmc r
    .local pmc ap_const
    .local string results

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    r.'puts'("1..8\n")

  START_1:
    push_eh NOT_OK_1
    $P0 = new ['ModParrot'; 'APR'; 'Pool']
    pop_eh
    $S0 = typeof $P0
    if $S0 == 'ModParrot;APR;Pool' goto OK_1
  NOT_OK_1:
    r.'puts'("not ")
  OK_1:
    r.'puts'("ok 1 - create pool (no parent)\n")

  START_2:
    push_eh NOT_OK_2
    $P0.'clear'()
    pop_eh
    goto OK_2
  NOT_OK_2:
    r.'puts'("not ")
  OK_2:
    r.'puts'("ok 2 - clear pool\n")

  START_3:
    push_eh NOT_OK_3
    $P0.'destroy'()
    pop_eh
    goto OK_3
  NOT_OK_3:
    r.'puts'("not ")
  OK_3:
    r.'puts'("ok 3 - destroy pool\n")

  START_4:
    push_eh NOT_OK_4
    $P1 = r.'pool'()
    $P2 = new 'Hash'
    $P2['parent'] = $P1
    $P0 = new ['ModParrot'; 'APR'; 'Pool'], $P2
    pop_eh
    $S0 = typeof $P0
    if $S0 == 'ModParrot;APR;Pool' goto OK_4
  NOT_OK_4:
    r.'puts'("not ")
  OK_4:
    r.'puts'("ok 4 - create pool (with request pool parent)\n")

  START_5:
    push_eh NOT_OK_5
    $P0 = r.'pool'()
    $P1 = new 'String'
    $P1 = 'xyzzy'
    $P2 = get_global 'test_cleanup_handler'
    $P0.'cleanup_register'($P2, $P1)
    pop_eh
    goto OK_5
  NOT_OK_5:
    r.'puts'("not ")
  OK_5:
    r.'puts'("ok 5 - cleanup_register with data\n")

  START_6:
    push_eh NOT_OK_6
    $P0 = r.'pool'()
    $P1 = get_global 'test_cleanup_handler_no_data'
    $P0.'cleanup_register'($P1)
    pop_eh
    goto OK_6
  NOT_OK_6:
    r.'puts'("not ")
  OK_6:
    r.'puts'("ok 6 - cleanup_register with no data\n")
    
  START_7:
    push_eh NOT_OK_7
    $P0 = r.'pool'()
    $P0.'tag'('test')
    pop_eh
    goto OK_7
  NOT_OK_7:
    r.'puts'("not ")
  OK_7:
    r.'puts'("ok 7 - tag\n")

  START_8:
    push_eh NOT_OK_8
    $P0 = r.'pool'()
    $P1 = $P0.'parent_get'()
    pop_eh
    $S0 = typeof $P1
    if $S0 == 'ModParrot;APR;Pool' goto OK_8
  NOT_OK_8:
    r.'puts'("not ")
  OK_8:
    r.'puts'("ok 8 - parent_get\n")

    $I0 = ap_const['OK']
    .return($I0)
.end
