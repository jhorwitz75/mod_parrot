# $Id$

.namespace [ 'TestAPI::context' ]

.sub handler
    .param pmc r
    .local pmc ctx, ap_const
    .local string results

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    r.'puts'("1..8\n")

  START_1:
    push_eh NOT_OK_1
    ctx = new [ 'ModParrot'; 'Context' ]
    pop_eh
    $S0 = typeof ctx
    if $S0 == "ModParrot;Context" goto OK_1
  NOT_OK_1:
    r.'puts'("not ")
  OK_1:
    r.'puts'("ok 1 - object\n")

  START_2:
    push_eh NOT_OK_2
    $P0 = ctx.'conf_pool'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == "ModParrot;APR;Pool" goto OK_2
  NOT_OK_2:
    r.'puts'("not ")
  OK_2:
    r.'puts'("ok 2 - conf_pool\n")

  START_3:
    push_eh NOT_OK_3
    $P0 = ctx.'log_pool'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == "ModParrot;APR;Pool" goto OK_3
  NOT_OK_3:
    r.'puts'("not ")
  OK_3:
    r.'puts'("ok 3 - log_pool\n")

  START_4:
    push_eh NOT_OK_4
    $P0 = ctx.'temp_pool'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == "ModParrot;APR;Pool" goto OK_4
  NOT_OK_4:
    r.'puts'("not ")
  OK_4:
    r.'puts'("ok 4 - temp_pool\n")

  START_5:
    push_eh NOT_OK_5
    $P0 = ctx.'child_pool'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == "ModParrot;APR;Pool" goto OK_5
  NOT_OK_5:
    r.'puts'("not ")
  OK_5:
    r.'puts'("ok 5 - child_pool\n")

  START_6:
    push_eh NOT_OK_6
    $P0 = ctx.'interp'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == "ModParrot;Interpreter" goto OK_6
  NOT_OK_6:
    r.'puts'("not ")
  OK_6:
    r.'puts'("ok 6 - interp\n")

  START_7:
    push_eh NOT_OK_7
    $P0 = ctx.'request_rec'()
    pop_eh
    $S0 = typeof $P0
    if $S0 == "ModParrot;Apache;RequestRec" goto OK_7
  NOT_OK_7:
    r.'puts'("not ")
  OK_7:
    r.'puts'("ok 7 - request_rec\n")

  START_8:
    push_eh NOT_OK_8
    $S0 = ctx.'pool_name'()
    pop_eh
    if $S0 == "default" goto OK_8
  NOT_OK_8:
    r.'puts'("not ")
  OK_8:
    r.'puts'("ok 8 - pool_name\n")

    $I0 = ap_const['OK']
    .return($I0)
.end

