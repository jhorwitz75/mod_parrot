# $Id$

.namespace [ 'TestAPI::server_rec' ]

.sub handler
    .param pmc r
    .local pmc ap_const, s
    .local string results

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    r.'puts'("1..1\n")

  START_1:
    s = r.'server'()
    $S0 = typeof s
    if $S0 == "ModParrot;Apache;ServerRec" goto OK_1
  NOT_OK_1:
    r.'puts'("not ")
  OK_1:
    r.'puts'("ok 1 - object\n")

    $I0 = ap_const['OK']
    .return($I0)
.end
