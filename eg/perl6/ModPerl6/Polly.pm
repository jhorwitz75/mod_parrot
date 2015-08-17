# $Id$

# This response handler outputs the query string from the URL.
# Example: http://example.com/perl6/polly?meep
#
# Usage:
#
# ParrotLibPath /path/to/eg/perl6:/path/to/parrot/runtime/parrot/library:/path/to/mod_parrot/lib
# ParrotLoadImmediate ModParrot/HLL/perl6.pbc
# <Location /perl6/polly>
#     SetHandler perl6-script
#     Perl6ResponseHandler ModPerl6::Polly
# </Location>
#
# Stop Apache
# Set the PARROT_RUNTIME environment variable to /path/to/parrot
# Set the PERL6LIB environment variable to /path/to/eg/perl6
# Start Apache

module ModPerl6::Polly;

use v6;
use Apache::Const;

sub handler($r)
{
    my $text = $r.args();
    if ($text ne "") {
        $r.puts("SQUAWK!  Polly says $text<p>");
    }
    $r.puts("Reload with a query string and Polly will repeat it.\n");
    return $Apache::Const::OK;
}
