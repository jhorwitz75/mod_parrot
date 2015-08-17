use Apache::Test qw(:withtestmore);
use Apache::TestRequest;
use Apache::TestUtil qw(t_cmp);
use Test::More;

my $content;

plan tests =>2, (need_lwp);

my $res = GET '/parrot-test/ParrotAccessHandler?ok';
chomp($content = $res->content);
is($content, 'Hello World', 'Access Allowed');

$res = GET '/parrot-test/ParrotAccessHandler?forbidden';
chomp($content = $res->content);
like($content, qr/403/, 'Access Forbidden');
