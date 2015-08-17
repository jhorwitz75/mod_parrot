# $Id$

.namespace [ 'TestAPI::interpreter' ]

.sub handler
    .param pmc r
    .local pmc mpi, ap_const
    .local string results

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    r.'puts'("1..7\n")

  START_1:
    mpi = new [ 'ModParrot'; 'Interpreter' ]
    $S0 = typeof mpi
    if $S0 == "ModParrot;Interpreter" goto OK_1
    r.'puts'("not ")
  OK_1:
    r.'puts'("ok 1 - object\n")

  START_2:
    $P0 = mpi.'include_path'()
    $S0 = typeof $P0
    if $S0 == "ResizableStringArray" goto OK_2
    r.'puts'("not ")
  OK_2:
    r.'puts'("ok 2 - object\n")

  START_3:
    $P0 = mpi.'include_path_str'()
    $S0 = typeof $P0
    if $S0 == "String" goto OK_3
    r.'puts'("not ")
  OK_3:
    r.'puts'("ok 3 - object\n")

  START_4:
    $P0 = mpi.'library_path'()
    $S0 = typeof $P0
    if $S0 == "ResizableStringArray" goto OK_4
    r.'puts'("not ")
  OK_4:
    r.'puts'("ok 4 - object\n")

  START_5:
    $P0 = mpi.'library_path_str'()
    $S0 = typeof $P0
    if $S0 == "String" goto OK_5
    r.'puts'("not ")
  OK_5:
    r.'puts'("ok 5 - object\n")

  START_6:
    $P0 = mpi.'dynext_path'()
    $S0 = typeof $P0
    if $S0 == "ResizableStringArray" goto OK_6
    r.'puts'("not ")
  OK_6:
    r.'puts'("ok 6 - object\n")

  START_7:
    $P0 = mpi.'dynext_path_str'()
    $S0 = typeof $P0
    if $S0 == "String" goto OK_7
    r.'puts'("not ")
  OK_7:
    r.'puts'("ok 7 - object\n")

    $I0 = ap_const['OK']
    .return($I0)
.end

