# $Id

.sub main :main
    .param pmc args
    .local string sig
    .local pmc nul

    null nul
    sig = args[1]

    # this will panic if sig is not found, but it should be a fatal test
    # failure anyway, so no big deal
    dlfunc $P0, nul, "Parrot_new", sig
.end
