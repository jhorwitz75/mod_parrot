# $Id: handlers.pir 455 2008-09-25 20:22:35Z jhorwitz $

.namespace [ 'ModParrot::Test::HelloWorld' ]

.sub handler
    .param pmc r
    .local pmc ap_const

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'
    $I0 = ap_const['OK']

    r.'puts'('Hello World')

    .return($I0)
.end

.namespace [ 'ModParrot::Test::get_basic_auth_pw' ]

.sub handler
    .param pmc r
    .local pmc ap_const

    r.'puts'("Access granted.")

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'
    $I0 = ap_const['OK']

    .return($I0)
.end

.namespace [ 'ModParrot::Test::AccessHandler' ]

.sub handler
    .param pmc r
    .local pmc ap_const

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'
    $I0 = ap_const['OK']

    $S0 = r.'args'( )
    if $S0 != 'ok' goto access_forbidden
    goto access_done

access_forbidden:
    $I0 = ap_const['HTTP_FORBIDDEN']

access_done:
    .return($I0)
.end

.namespace [ 'ModParrot::Test::AuthenHandler' ]

.sub handler
    .param pmc r
    .local pmc ap_const

    $P0 = r.'get_basic_auth_pw'( )
    $I0 = $P0[0]
    $S1 = $P0[1]

    $S0 = r.'user'( )

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    if $S0 != 'joeuser' goto auth_failed
    if $S1 != 'password' goto auth_failed
    $I0 = ap_const['OK']
    goto auth_done

auth_failed:
    r.'note_basic_auth_failure'( )
    $I0 = ap_const['HTTP_UNAUTHORIZED']

auth_done:
    .return($I0)
.end

.namespace [ 'ModParrot::Test::AuthzHandler' ]

.sub handler
    .param pmc r
    .local pmc ap_const

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'
    $I0 = ap_const['OK']

    $S0 = r.'args'( )
    if $S0 != 'ok' goto authz_forbidden
    goto authz_done

authz_forbidden:
    $I0 = ap_const['HTTP_FORBIDDEN']

authz_done:
    .return($I0)
.end
