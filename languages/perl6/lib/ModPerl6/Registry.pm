# $Id$

module ModPerl6::Registry;

use v6;

# for perl 6 functionality not yet supported by rakudo
use ModPerl6::Fudge;
use Apache::Const;

our %registry;
regex header_regex { ^^ ([\w|'-']+) ':' <ws> (\N+) $$ };

sub gen_module_name($path)
{
    my $name = $path;
    # sanitize the module name
    $name .= subst(/<-alnum>/, '_', :global);
    return "ModPerl6::Registry::script_$name";
}

# this is temporary until mod_parrot supports output filters
sub parse_headers($r, $in)
{
    my $headers_done = 0;
    return $in if $r.notes.get('modperl6-parsed-headers');
    my $out = '';
    my $headers_out = $r.headers_out();
    for $in.split(/\n/) -> $line {
        if ($line eq '') {
            if ($headers_done) {
                $out ~= "\n";
            }
        }
        elsif (!$headers_done && $line ~~ /<header_regex>/) {
            my $key = ~$<header_regex>[0];
            my $val = ~$<header_regex>[1];
            given $key.lc {
                when 'content-type' { $r.content_type($val); }
                default { $headers_out.set($key, $val); }
            }
        }
        # this will catch non-headers as well as the blank line postamble
        else {
            unless ($headers_done) {
                $r.notes.set('modperl6-parsed-headers', 'yes');
                $headers_done = 1;
            }
            if ($line.chars) {
                $out ~= $line ~ "\n";
            }
        }
    }
    return $out;
}

sub handler($r)
{
    my %cfg = Apache::Module::get_config("modparrot_perl6_module");
    my %dircfg = Apache::Module::get_config(
        "modparrot_perl6_module", $r.per_dir_config());

    my $script = $r.filename();
    unless (%registry{$script}) {
        my $data = slurp $script;
        my $mod = gen_module_name($script);
        my $code = "module $mod; sub reg__handler \{ $data \}";
        eval $code;
        if ($!) {
            $r.log_rerror($script, 0, 0, $!);
            return $Apache::Const::HTTP_INTERNAL_SERVER_ERROR;
        }
        %registry{$script} = $mod;
        %registry{$mod} = $script;
    }

    # grab interesting stuff from headers
    my $headers_in = $r.headers_in();
    my $content_length = $headers_in.get('Content-Length');
    my $cookies = $headers_in.get('Cookie');

    # set environment variables expected by CGI scripts
    # XXX use %*ENV when Rakudo RT #61412 is fixed
    my $args = $r.args();
    my $uri = $args ?? ($r.uri() ~ '?' ~ $args) !! $r.uri();
    ModPerl6::Fudge::setenv('MODPERL6', 1);
    ModPerl6::Fudge::setenv('QUERY_STRING', $args);
    ModPerl6::Fudge::setenv('PATH_INFO', $r.path_info);
    ModPerl6::Fudge::setenv('REQUEST_METHOD', $r.method);
    ModPerl6::Fudge::setenv('REQUEST_URI', $uri);
    ModPerl6::Fudge::setenv('CONTENT_LENGTH', $content_length);
    ModPerl6::Fudge::setenv('HTTP_COOKIE', $cookies);
    ModPerl6::Fudge::setenv('SERVER_NAME', $r.hostname);
    ## XXX requires server_rec
    #ModPerl6::Fudge::setenv('SERVER_PORT', $server_port);

    my $do_headers = %dircfg<options><parseheaders>;

    my $mod = %registry{$script};

    # tie I/O to $r, saving the old filehandles
    my $mpi = ::ModParrot::Interpreter.new();
    my $stdin = $mpi.stdin($r);
    my $stdout = $mpi.stdout($r);
    $*IN := $mpi.stdin;
    $*OUT := $mpi.stdout;

    # run our code
    #::($mod)::_handler();
    my $res = ModPerl6::Fudge::call_sub_with_namespace($mod, 'reg__handler');

    # restore I/O filehandles
    $mpi.stdin($stdin);
    $mpi.stdout($stdout);
    $*IN := $stdin;
    $*OUT := $stdout;

    return $Apache::Const::OK;
}
