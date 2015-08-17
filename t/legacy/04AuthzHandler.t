use Apache::Test qw(:withtestmore);
use Apache::TestRequest;
use Apache::TestUtil qw(t_cmp);
use Test::More;

plan tests => 2, (need_lwp);

my ($content, $res);

# ParrotAuthzHandler
$res = GET '/parrot-test/ParrotAuthzHandler?ok',
    username => 'joeuser', password => 'password';
chomp($content = $res->content);
is($content, 'Hello World', 'authorization granted');

# ParrotAuthzHandler
$res = GET '/parrot-test/ParrotAuthzHandler?forbidden',
    username => 'joeuser', password => 'password';
chomp($content = $res->content);
like($content, qr/403/, 'authorization forbidden');
