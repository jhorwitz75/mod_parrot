# $Id: handler.pir 467 2008-10-20 13:48:45Z jhorwitz $

# This is a simple response handler that outputs its query string.
#
# Usage:
#
# ParrotLoad /path/to/this/file
# <Location /testhandler>
#     SetHandler parrot-code
#     ParrotHandler Handler
# </Location>

# handler namespace is used for ParrotHandler in httpd.conf
.namespace [ 'Handler' ]

.sub handler
    # request_rec object is the first argument
    .param pmc r

    .local pmc ap_const

    # send some output
    r.'puts'("You said ")
    $S0 = r.'args'( )
    r.'puts'($S0)

    # tell apache we're finished
    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'
    $I0 = ap_const['OK']
    .return($I0)
.end
