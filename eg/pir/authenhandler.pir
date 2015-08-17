# $Id: authenhandler.pir 467 2008-10-20 13:48:45Z jhorwitz $

# This is an authentication handler that grants access based on the password
# provided through HTTP basic authentication.  Any username with a password
# of 'squawk' will be allowed through.
#
# Usage:
#
# ParrotLoad /path/to/this/file
# <Directory /my/protected/directory>
#     AuthType Basic
#     AuthName "Parrot Auth"
#     ParrotAuthenHandler MyAuthHandler
#     Require valid-user
# </Directory>


.namespace [ 'MyAuthHandler' ]

.sub handler
    # request_rec object is the first argument
    .param pmc r

    .local pmc ap_const
    .local string pw
    .local int status

    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'

    $P0 = r.'get_basic_auth_pw'( )
    status = $P0[0]
    pw = $P0[1]

    if pw != 'squawk' goto auth_failure
    $I0 = ap_const['OK']
    goto auth_return_status

auth_failure:
    $I0 = ap_const['HTTP_UNAUTHORIZED']
    goto auth_return_status

auth_declined:
    $I0 = ap_const['DECLINED']
    goto auth_return_status

auth_return_status:
    .return($I0)
.end 
