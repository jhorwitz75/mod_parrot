# $Id$

# Copyright (c) 2007, 2008 Jeff Horwitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module ModParrot::HLL::perl6;

use v6;
use ModParrot::Const;
use Apache::Const;
use Apache::Module;

# for perl 6 functionality not yet supported by rakudo
use ModPerl6::Fudge;

our %loaded_modules;
our %valid_options = <
    enable
    parseheaders
>.map({($_,1)});
our @server_phases = <open_logs post_config child_init pre_connection
     process_connection post_read_request map_to_storage trans>;
our @dir_phases = <header_parser access authen authz response type fixup log
         cleanup>;

sub load($handler)
{
    unless (%loaded_modules{$handler}) {
        use $handler;
        %loaded_modules{$handler} = 1;
    }
}

sub server_create($parms)
{
    my %cfg;

    # preloading
    %cfg<preloaded_modules> = [];
    %cfg<postconfig_requires> = [];

    return %cfg;
}

sub dir_create($parms)
{
    my %cfg;

    # options set with Perl6Options
    %cfg<options> = {
        parseheaders => False,
    };

    return %cfg;
}

sub server_merge(%base, %new)
{
    my %merged;

    # XXX what to do with preloaded modules & postconfig requires???

    # merge handlers -- never inherit
    for @server_phases.map({$_ ~ '_handler'}) -> $h {
        %merged{$h} = %new{$h};
    }

    return %merged;
}

sub dir_merge(%base, %new)
{
    my %merged;

    # merge options -- inherit only if not set
    %merged<options> = {};
    for %valid_options.keys -> $k {
        %merged<options>{$k} = %new<options>.exists($k) ??
            %new<options>{$k} !! %base<options>{$k};
    }

    # merge handlers -- never inherit
    for @dir_phases.map({$_ ~ '_handler'}) -> $h {
        %merged{$h} = %new{$h};
    }

    return %merged;
}

# XXX should cache the handler form during configuration
sub call_handler($handler, *@args)
{
    my $res;

    return $Apache::Const::DECLINED unless defined($handler);

    # resolve a method handler
    my ($class, $method) = split('.', $handler);
    # i'd like to run this later with the other forms, but the calling
    # conventions are different for methods so just run it here
    if ($method) {
        load($class);
        # XXX unfudge when namespace interpolation works
        $res = ModPerl6::Fudge::call_class_method($class, $method, |@args);
        return $res;
    }

    # resolve a literal $handler()
    # do this first so we don't load() until we need to
    my @names = split('::', $handler);
    my $subname = @names.pop;
    my $ns = join('::', @names);

    # XXX unfudge when namespace interpolation works
    # resolve_sub MUST return a failure if name exists but it's not a sub
    my $sub = ModPerl6::Fudge::resolve_sub($ns, $subname);

    unless ($sub.defined) {
        # load $handler and try $handler::handler() (common convention)
        load($handler);
        # XXX unfudge when namespace interpolation works
        $sub = ModPerl6::Fudge::resolve_sub($handler, 'handler');
    }

    # everything falls down to this block -- run the handler
    if ($sub.defined) {
        $res = $sub(|@args);
        return $res;
    }
    else { 
        # nothing worked -- return an error
        # XXX should also log something here
        $res = $Apache::Const::HTTP_INTERNAL_SERVER_ERROR;
    }

    return $Apache::Const::HTTP_INTERNAL_SERVER_ERROR;
}
 
sub header_parser_handler($ctx)
{
    my $r = $ctx.request_rec();
    my %cfg = Apache::Module::get_config("modparrot_perl6_module");
    my %dircfg = Apache::Module::get_config("modparrot_perl6_module",
        $r.per_dir_config());

    # first phase that has a dir config, so register any cleanup handlers
    if (%dircfg<cleanup_handler>) {
        $r.pool.cleanup_register(&cleanup_handler, %dircfg<cleanup_handler>);
    }

    # back to the post_read_request handler
    my $handler = %dircfg<header_parser_handler>;
    unless ($handler) {
        return $Apache::Const::OK;
    }

    my $status = call_handler($handler, $r);
    return $status;
}

sub response_handler($ctx)
{
    my $r = $ctx.request_rec();

    unless ($r.handler() ~~ any(<modperl6 perl6-script>)) {
        return $Apache::Const::DECLINED;
    }

    my %cfg = Apache::Module::get_config("modparrot_perl6_module");
    my %dircfg = Apache::Module::get_config("modparrot_perl6_module",
        $r.per_dir_config());

    my $handler = %dircfg<response_handler>;

    $r.content_type('text/html');
    my $status = call_handler($handler, $r);
    return $status;
}

sub open_logs_handler($ctx)
{
    return $Apache::Const::OK;
}

sub post_config_handler($ctx)
{
    my $conf_pool = $ctx.conf_pool();
    my $log_pool = $ctx.log_pool();
    my $temp_pool = $ctx.temp_pool();

    # XXX uncomment when server_rec is implemented
    #my $s = $ctx.server_rec();
    my $s = undef;

    my %cfg = Apache::Module::get_config("modparrot_perl6_module");

    # preload modules
    # NOTE: Perl6Module is a directory scope directive
    for %cfg<preloaded_modules>.values -> $m {
        use $m;
    }

    # load postconfig requires
    for %cfg<postconfig_requires>.values -> $r {
        require $r;
    }

    my $handler = %cfg<post_config_handler>;
    unless ($handler) {
        return $Apache::Const::OK;
    }

    # run the postconfig handler
    my $status = call_handler($handler, $conf_pool, $log_pool, $temp_pool, $s);
    return $status;
}

sub cleanup_handler($handler)
{
    my $status = call_handler($handler);
    return $status;
}

sub cmd_perl6openlogshandler($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    %cfg<open_logs_handler> = @args[0];
}

sub cmd_perl6postconfighandler($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    %cfg<post_config_handler> = @args[0];
}

sub cmd_perl6childinithandler($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    %cfg<child_init_handler> = @args[0];
}

sub cmd_perl6preconnectionhandler($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    %cfg<pre_connection_handler> = @args[0];
}

sub cmd_perl6processconnectionhandler($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    %cfg<process_connection_handler> = @args[0];
}

sub cmd_perl6postreadrequesthandler($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    %cfg<post_read_request_handler> = @args[0];
}

sub cmd_perl6maptostoragehandler($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    %cfg<map_to_storage_handler> = @args[0];
}

sub cmd_perl6transhandler($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    %cfg<trans_handler> = @args[0];
}

sub cmd_perl6headerparserhandler($parms, %dircfg, @args)
{
    %dircfg<header_parser_handler> = @args[0];
}

sub cmd_perl6accesshandler($parms, %dircfg, @args)
{
    %dircfg<access_handler> = @args[0];
}

sub cmd_perl6authenhandler($parms, %dircfg, @args)
{
    %dircfg<authen_handler> = @args[0];
}

sub cmd_perl6authzhandler($parms, %dircfg, @args)
{
    %dircfg<authz_handler> = @args[0];
}

sub cmd_perl6responsehandler($parms, %dircfg, @args)
{
    %dircfg<response_handler> = @args[0];
}

sub cmd_perl6typehandler($parms, %dircfg, @args)
{
    %dircfg<type_handler> = @args[0];
}

sub cmd_perl6fixuphandler($parms, %dircfg, @args)
{
    %dircfg<fixup_handler> = @args[0];
}

sub cmd_perl6loghandler($parms, %dircfg, @args)
{
    %dircfg<log_handler> = @args[0];
}

sub cmd_perl6cleanuphandler($parms, %dircfg, @args)
{
    %dircfg<cleanup_handler> = @args[0];
} 

sub cmd_perl6module($parms, %mconfig, @args)
{
    my %cfg := Apache::Module::get_config("modparrot_perl6_module");
    push(%cfg<preloaded_modules>, @args[0]);
}

sub cmd_perl6options($parms, %mconfig, @args)
{
    if (@args[0] ~~ /(\+|\-)(.+)/) {
        my $modifier = ~$0;
        my $option = (~$1).lc;
        my $val = ($modifier eq '+');
	if (%valid_options{$option}) {
                %mconfig<options>{$option} = $val; 
        }
        else {
            default { die "invalid option '$option'"; }
        }
    }
    else {
        die "missing modifier prefix (+ or -)";
    }
}

# register configuration directives
my @cmds = (
    {
        'name' => 'Perl6Options',
        'args_how' => $Apache::Const::ITERATE,
        'func' => &cmd_perl6options,
        'req_override' => $Apache::Const::OR_ALL,
        'errmsg' => 'usage: Perl6Options [+/-]option ...'
    },
    {
        'name' => 'Perl6Module',
        'args_how' => $Apache::Const::TAKE1,
        'func' => &cmd_perl6module,
        'req_override' => $Apache::Const::OR_ALL,
        'errmsg' => 'usage: Perl6Module module'
    },
    {
        'name' => 'Perl6PostConfigHandler',
        'args_how' => $Apache::Const::TAKE1,
        'func' => &cmd_perl6postconfighandler,
        'req_override' => $Apache::Const::RSRC_CONF,
        'errmsg' => 'usage: Perl6PostConfigHandler handler-name'
    },
    {
        'name' => 'Perl6ResponseHandler',
        'args_how' => $Apache::Const::TAKE1,
        'func' => &cmd_perl6responsehandler,
        'req_override' => $Apache::Const::OR_AUTHCFG,
        'errmsg' => 'usage: Perl6ResponseHandler handler-name'
    },
    {
        'name' => 'Perl6HeaderParserHandler',
        'args_how' => $Apache::Const::TAKE1,
        'func' => &cmd_perl6headerparserhandler,
        'req_override' => $Apache::Const::OR_AUTHCFG,
        'errmsg' => 'usage: Perl6HeaderParserHandler handler-name'
    },
    {
        'name' => 'Perl6CleanupHandler',
        'args_how' => $Apache::Const::TAKE1,
        'func' => &cmd_perl6cleanuphandler,
        'req_override' => $Apache::Const::OR_AUTHCFG,
        'errmsg' => 'usage: Perl6CleanupHandler handler-name'
    }
);

# register hooks
my @hooks = (
    $ModParrot::Const::MP_HOOK_OPEN_LOGS,
    $ModParrot::Const::MP_HOOK_POST_CONFIG,
    $ModParrot::Const::MP_HOOK_HEADER_PARSER,
    $ModParrot::Const::MP_HOOK_RESPONSE
);

Apache::Module::add(
    'modparrot_perl6_module',
    'perl6',
    @cmds,
    @hooks
);
