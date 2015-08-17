# $Id$

.namespace [ 'TestAPI::modparrothandle' ]

.sub handler
    .param pmc r
    .local pmc fh, old, ap_const

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    r.'puts'("1..11\n")

  START_1:
    fh = new 'ModParrotHandle'
    $S0 = typeof fh
    if $S0 == "ModParrotHandle" goto OK_1
    r.'puts'("not ")
  OK_1:
    r.'puts'("ok 1 - object\n")

  START_2:
    push_eh NOT_OK_2
    fh.'open'(r, "w")
    pop_eh
    goto OK_2
  NOT_OK_2:
    r.'puts'("not ")
  OK_2:
    r.'puts'("ok 2 - open\n") 

  START_3:
    fh.'puts'("ok 3 - puts\n") 

  START_4:
    old = getstdout
    fh.'setstdout'()
    say "ok 4 - setstdout (ModParrotHandle)"

  START_5:
    fh.'setstdout'(old)
    print "not "
    r.'puts'("ok 5 - setstdout (reset to old stdout)\n")

  START_6:
    old = getstdin
    fh.'setstdin'()
    r.'puts'("ok 6 - setstdin (ModParrotHandle)\n")

  START_7:
    push_eh NOT_OK_7
    fh.'close'()
    pop_eh
    goto OK_7
  NOT_OK_7:
    r.'puts'("not ")
  OK_7:
    r.'puts'("ok 7 - close\n")

  START_8:
    fh.'open'(r, "r")
    $S0 = fh.'read'(1024)
    if $S0 == "" goto OK_8
    r.'puts'("not ")
  OK_8:
    r.'puts'("ok 8 - read\n")

  START_9:
    r.'puts'("not ok 9 - readline # TODO\n")

  START_10:
    push_eh NOT_OK_10
    $S0 = fh.'readall'('')
    pop_eh
    if $S0 == "" goto OK_10
  NOT_OK_10:
    r.'puts'("not ")
  OK_10:
    r.'puts'("ok 10 - readall\n")

  START_11:
    fh.'setstdin'(old)
    r.'puts'("ok 11 - setstdin (reset to old stdin)\n")

    $I0 = ap_const['OK']
    .return($I0)
.end

