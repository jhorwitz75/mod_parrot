# $Id$

# This is a response handler to dump interpreter info, including interpinfo
# statistics and search paths.  It might be useful to somebody.
#
# Usage:
#
# In /path/to/apache/bin/envvars, add:
#
# PARROT_RUNTIME=/path/to/parrot
# export PARROT_RUNTIME
#
# Stop and start apache (don't use restart).
#
# In httpd.conf:
#
# ParrotLoad /path/to/this/file
# <Location /parrot-status>
#     SetHandler parrot-code
#     ParrotHandler Interpinfo
# </Location>

.namespace [ 'Interpinfo' ]

.include 'interpinfo.pasm'
.include 'iglobals.pasm'

.sub print_row
    .param pmc r
    .param string key
    .param string value

    $S0 = "<tr><td>"
    concat $S0, key
    concat $S0, "</td><td>"
    concat $S0, value
    concat $S0, "</td></tr>\n"
    r.'puts'($S0)
.end

.sub handler
    # request_rec object is the first argument
    .param pmc r

    r.'puts'("<html><title>Parrot interpreter statistics</title>\n<body>\n")
    r.'puts'("<h1>Parrot interpreter statistics</h1>\n")
    r.'puts'("<table>\n")

    $P0 = new ['ModParrot'; 'Context']
    $S0 = $P0.'pool_name'()
    print_row(r, "POOL NAME", $S0)

    $I0 = interpinfo .INTERPINFO_TOTAL_MEM_ALLOC
    $S0 = $I0
    print_row(r, "TOTAL_MEM_ALLOC", $S0)

    $I0 = interpinfo .INTERPINFO_GC_MARK_RUNS
    $S0 = $I0
    print_row(r, "GC_MARK_RUNS", $S0)

    $I0 = interpinfo .INTERPINFO_GC_COLLECT_RUNS
    $S0 = $I0
    print_row(r, "GC_COLLECT_RUNS", $S0)

    $I0 = interpinfo .INTERPINFO_ACTIVE_PMCS
    $S0 = $I0
    print_row(r, "ACTIVE_PMCS", $S0)

    $I0 = interpinfo .INTERPINFO_ACTIVE_BUFFERS
    $S0 = $I0
    print_row(r, "ACTIVE_BUFFERS", $S0)

    $I0 = interpinfo .INTERPINFO_TOTAL_PMCS
    $S0 = $I0
    print_row(r, "TOTAL_PMCS", $S0)

    $I0 = interpinfo .INTERPINFO_TOTAL_BUFFERS
    $S0 = $I0
    print_row(r, "TOTAL_BUFFERS", $S0)

    $I0 = interpinfo .INTERPINFO_HEADER_ALLOCS_SINCE_COLLECT
    $S0 = $I0
    print_row(r, "HEADER_ALLOCS_SINCE_COLLECT", $S0)

    $I0 = interpinfo .INTERPINFO_MEM_ALLOCS_SINCE_COLLECT
    $S0 = $I0
    print_row(r, "MEM_ALLOCS_SINCE_COLLECT", $S0)

    $I0 = interpinfo .INTERPINFO_TOTAL_COPIED
    $S0 = $I0
    print_row(r, "TOTAL_COPIED", $S0)

    $I0 = interpinfo .INTERPINFO_IMPATIENT_PMCS
    $S0 = $I0
    print_row(r, "IMPATIENT_PMCS", $S0)

    $I0 = interpinfo .INTERPINFO_GC_LAZY_MARK_RUNS
    $S0 = $I0
    print_row(r, "GC_LAZY_MARK_RUNS", $S0)

    $I0 = interpinfo .INTERPINFO_EXTENDED_PMCS
    $S0 = $I0
    print_row(r, "EXTENDED_PMCS", $S0)

    $S0 = interpinfo .INTERPINFO_RUNTIME_PREFIX
    print_row(r, "RUNTIME_PREFIX", $S0)

    .local pmc interp, lib_paths
    .local string include_paths, library_paths, dynext_paths
    interp = getinterp
    lib_paths = interp[.IGLOBALS_LIB_PATHS]
    $P0 = lib_paths[0]
    include_paths = join '<br>', $P0
    $P0 = lib_paths[1]
    library_paths = join '<br>', $P0
    $P0 = lib_paths[2]
    dynext_paths = join '<br>', $P0

    $S0 = "<tr valign=\"top\"><td>INCLUDE PATH</td><td>"
    concat $S0, include_paths
    concat $S0, "</td></tr>\n"
    r.'puts'($S0)

    $S0 = "<tr valign=\"top\"><td>LIBRARY PATH</td><td>"
    concat $S0, library_paths
    concat $S0, "</td></tr>\n"
    r.'puts'($S0)

    $S0 = "<tr valign=\"top\"><td>DYNEXT PATH</td><td>"
    concat $S0, dynext_paths
    concat $S0, "</td></tr>\n"
    r.'puts'($S0)

    r.'puts'("</table>\n</body></html>\n")

    # tell apache we're finished
    .local pmc ap_const
    ap_const = get_root_global [ 'ModParrot'; 'Apache'; 'Constants' ], 'table'
    $I0 = ap_const['OK']
    .return($I0)
.end
