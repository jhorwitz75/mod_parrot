# $Id$

# This response handler outputs the number of times it's been invoked.
# Since each child process/thread gets its own interpreter, the value of 
# the counter may "jump" as you cycle through processes.  Enabling KeepAlive
# will lock you to a child process for a short period and provide a proper
# demonstration.
#
# Usage:
#
# ParrotLibPath /path/to/eg/perl6:/path/to/parrot/runtime/parrot/library:/path/to/mod_parrot/lib
# ParrotLoadImmediate ModParrot/HLL/perl6.pbc
# <Location /perl6/counter>
#     SetHandler perl6-script
#     Perl6ResponseHandler ModPerl6::Counter
# </Location>
#
# Stop Apache
# Set the PARROT_RUNTIME environment variable to /path/to/parrot
# Set the PERL6LIB environment variable to /path/to/eg/perl6
# Start Apache

module ModPerl6::Counter;

use v6;
use Apache::Const;

sub handler($r)
{
    our $x;
    unless ($x) {
        $x = 1;
    }
    $r.puts("Page views for this interpreter: $x\n");
    $x++;
    return $Apache::Const::OK;
}
